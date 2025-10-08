#!/usr/bin/env nu
# NuAWS - Native Nushell AWS CLI Plugin
# Main entry point providing unified `nuaws` command with service routing

# Import core plugin modules
use plugin/core/service_loader.nu
use plugin/core/configuration.nu
use plugin/core/error_handler.nu
use plugin/core/service_manager.nu
use plugin/core/completion_manager.nu

# Environment setup for plugin
export-env {
    # Plugin configuration
    $env.NUAWS_PLUGIN_DIR = $"(pwd)/plugin"
    $env.NUAWS_CACHE_DIR = $"($env.HOME)/.nuaws/cache"
    $env.NUAWS_CONFIG_DIR = $"($env.HOME)/.nuaws"
    
    # AWS environment defaults (inherit from existing AWS CLI config)
    $env.AWS_PROFILE = ($env.AWS_PROFILE? | default "default")
    $env.AWS_DEFAULT_REGION = ($env.AWS_DEFAULT_REGION? | default "us-east-1")
    
    # Plugin behavior configuration
    $env.NUAWS_LAZY_LOADING = ($env.NUAWS_LAZY_LOADING? | default "true")
    $env.NUAWS_COMPLETION_CACHE_TTL = ($env.NUAWS_COMPLETION_CACHE_TTL? | default "300")
    $env.NUAWS_DEBUG = ($env.NUAWS_DEBUG? | default "false")
    
    # Initialize plugin system state if not already done
    if "NUAWS_SERVICE_REGISTRY" not-in $env {
        $env.NUAWS_SERVICE_REGISTRY = {}
    }
    if "NUAWS_MODULE_CACHE" not-in $env {
        $env.NUAWS_MODULE_CACHE = {}
    }
    if "NUAWS_MODULE_CACHE_ENTRIES" not-in $env {
        $env.NUAWS_MODULE_CACHE_ENTRIES = {}
    }
    if "NUAWS_VALIDATION_CACHE" not-in $env {
        $env.NUAWS_VALIDATION_CACHE = {}
    }
    if "NUAWS_CACHE_STATS" not-in $env {
        $env.NUAWS_CACHE_STATS = {
            hits: 0,
            misses: 0,
            evictions: 0,
            created: (date now),
            last_cleanup: (date now)
        }
    }
}

# Main nuaws command - unified entry point for all AWS operations
export def main [
    service?: string@"nu-complete nuaws services",  # AWS service name
    ...args: string  # Service operation and parameters
] {
    # Initialize plugin environment
    initialize-nuaws-environment
    
    # Display help if no arguments
    if ($service | is-empty) {
        show-nuaws-help
        return
    }
    
    # Handle special commands
    match $service {
        "help" => {
            if ($args | length) > 0 {
                show-service-help $args.0
            } else {
                show-nuaws-help
            }
            return
        },
        "version" => {
            show-nuaws-version
            return
        },
        "config" => {
            handle-config-command $args
            return
        },
        "cache" => {
            handle-cache-command $args
            return
        },
        "services" | "list" => {
            if ($args | length) > 0 {
                handle-services-command $args
            } else {
                show-services-list
            }
            return
        },
        "service" => {
            handle-service-command $args
            return
        },
        "completions" => {
            handle-completions-command $args
            return
        }
    }
    
    # Route to AWS service
    try {
        route-to-service $service $args
    } catch { |err|
        handle-nuaws-error $err $service $args
    }
}

# Initialize plugin environment and directories
def initialize-nuaws-environment [] {
    # Create necessary directories
    mkdir $env.NUAWS_CACHE_DIR
    mkdir $env.NUAWS_CONFIG_DIR
    
    # Initialize configuration if not exists
    configuration init-if-missing
}

# Display main help information
def show-nuaws-help [] {
    print $"
╔══════════════════════════════════════════════════════════════╗
║                          NuAWS                               ║
║        Native Nushell AWS CLI Plugin - v1.0.0               ║
╚══════════════════════════════════════════════════════════════╝

USAGE:
    nuaws <service> <operation> [options]

CORE FEATURES:
    ✓ 100% AWS CLI compatible
    ✓ Type-safe parameters with validation
    ✓ External completions for AWS resources
    ✓ Native Nushell pipeline integration
    ✓ Structured error messages
    ✓ Dynamic service loading

AVAILABLE SERVICES:"
    
    # Display available services with error handling
    try { 
        service_loader list-available-services | each {|s| 
            let status = if $s.loaded { "✓" } else { " " }
            let source_icon = match $s.source {
                "module" => "📦",
                "legacy" => "📁", 
                "existing" => "✅",
                "generated" => "🏗️ ",
                "discovered" => "🔍",
                _ => "❓"
            }
            $"    ($status) ($source_icon) ($s.name) - ($s.description)"
        } | str join "\n" | print
    } catch { 
        print "    Error loading service list - try: nuaws help"
    }
    
    print $"
SPECIAL COMMANDS:
    nuaws help [service]                     # Show help
    nuaws services                           # List all available services
    nuaws service <action> [options]        # Manage service modules
    nuaws version                            # Show version info
    nuaws config <action> [options]         # Manage configuration
    nuaws cache <action> [options]          # Manage cache
    nuaws completions <action> [options]    # Manage AWS resource completions

EXAMPLES:
    nuaws s3 ls                              # List S3 buckets
    nuaws ec2 describe-instances             # Describe EC2 instances
    nuaws iam list-users | where user_name =~ admin  # Filter users
    help nuaws s3 ls                         # Get detailed help

GETTING STARTED:
    1. Ensure AWS CLI is configured: aws configure
    2. Try: nuaws s3 ls
    3. For help: nuaws help s3

CONFIGURATION:
    AWS credentials and regions are inherited from AWS CLI configuration.
    Plugin settings: ($env.NUAWS_CONFIG_DIR)/config.nuon

For more information: https://github.com/your-repo/nuaws"
}

# Show detailed services list
def show-services-list [] {
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║                    Available AWS Services                    ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    
    try {
        let services = service_loader list-available-services
        
        print $"Total Services: ($services | length)"
        print ""
        
        # Group by source type
        let sources = $services | group-by source
        
        for source_group in ($sources | transpose source_type services) {
            let source_name = match $source_group.source_type {
                "module" => "📦 Plugin Modules",
                "legacy" => "📁 Legacy Modules", 
                "existing" => "✅ Existing Modules",
                "generated" => "🏗️  Generated Modules",
                "discovered" => "🔍 Discovered Services",
                _ => $"❓ ($source_group.source_type | str title-case)"
            }
            
            print $"($source_name): ($source_group.services | length)"
            $source_group.services | each {|s|
                let status = if $s.loaded { "✓" } else { " " }
                print $"  ($status) ($s.name) - ($s.description)"
            } | ignore
            print ""
        }
        
        print "Legend:"
        print "  ✓ = Currently loaded in memory"
        print "  📦 = Native plugin module"
        print "  📁 = Legacy module (aws/ directory)"
        print "  ✅ = Existing implementation"
        print "  🏗️  = Can be auto-generated"
        print "  🔍 = Discovered from AWS CLI"
        print ""
        print "Usage: nuaws <service> <operation> [args...]"
        
    } catch { |err|
        print $"Error loading services: ($err.msg)"
        print "Try: aws help | grep -A 20 'Available services:'"
    }
}

# Show version information
def show-nuaws-version [] {
    print "NuAWS Native Nushell AWS CLI Plugin"
    print "Version: 1.0.0"
    print "Nushell Version: ($version.version)"
    print ""
    print "AWS CLI Integration:"
    try {
        aws --version
    } catch {
        print "  ⚠️  AWS CLI not found - install from: https://aws.amazon.com/cli/"
    }
    print ""
    print "Plugin Directory: ($env.NUAWS_PLUGIN_DIR)"
    print "Cache Directory: ($env.NUAWS_CACHE_DIR)"
    print "Configuration: ($env.NUAWS_CONFIG_DIR)"
}

# Show help for specific service
def show-service-help [service: string] {
    try {
        let service_info = service_loader get-service-info $service
        print $"
╔══════════════════════════════════════════════════════════════╗
║  AWS Service: ($service)
╚══════════════════════════════════════════════════════════════╝

($service_info.description)

AVAILABLE OPERATIONS: ($service_info.operations | length)"
        
        # Print operations list
        $service_info.operations | each {|op| 
            let desc = $op.description? | default '' | str substring 0..50
            $"  • ($op.name) - ($desc)(if ($desc | str length) > 50 { '...' } else { '' })"
        } | str join "\n" | print
        
        print $"
USAGE:
    nuaws ($service) <operation> [options]

EXAMPLES:"
        
        # Print examples based on available operations
        if ($service_info.operations | length) > 0 {
            let first_op = $service_info.operations | first | get name
            print $"    nuaws ($service) ($first_op)"
            print $"    help nuaws ($service) ($first_op)"
        } else {
            print $"    nuaws ($service) help                       # Show service help"
            print $"    aws ($service) help                         # AWS CLI help"
        }
        
        print $"
GETTING DETAILED HELP:
    nuaws ($service) help                        # Service-specific help
    nuaws ($service) <operation> --help          # Operation help
    aws ($service) help                          # Full AWS CLI help"
    } catch { |err|
        print $"Service '($service)' not found or not loaded."
        print ""
        
        # Try to show if this is a valid AWS service by checking AWS CLI
        try {
            print "Checking AWS CLI for this service..."
            aws $service help | head -10 | each { |line| print $"  ($line)" } | ignore
            print ""
            print $"Service exists in AWS CLI. Try generating: nuaws ($service) help"
        } catch {
            print "This doesn't appear to be a valid AWS service."
            print ""
            print "Available services:"
            try {
                service_loader list-available-services | each {|s| 
                    let status = if $s.loaded { "✓" } else { " " }
                    $"  ($status) ($s.name) - ($s.description)"
                } | str join "\n" | print
            } catch {
                print "  Error loading service list"
            }
        }
    }
}

# Handle configuration commands
def handle-config-command [args: list] {
    match ($args | get 0? | default "show") {
        "show" => { configuration show },
        "set" => { 
            if ($args | length) >= 3 {
                configuration set $args.1 $args.2
            } else {
                print "Usage: nuaws config set <key> <value>"
                print ""
                print "Available configuration keys:"
                print "  lazy_loading: true|false          # Enable lazy service loading"
                print "  completion_cache_ttl: <seconds>   # Cache TTL for completions"
                print "  debug: true|false                 # Enable debug output"
                print "  max_completion_items: <number>    # Max completion suggestions"
                print "  service_timeout: <seconds>        # Service operation timeout"
                print "  auto_generate_missing: true|false # Auto-generate missing services"
                print "  preferred_output_format: table|json|yaml # Default output format"
                print "  cache_completions: true|false     # Enable completion caching"
                print "  warm_cache_on_startup: true|false # Pre-warm caches on startup"
            }
        },
        "get" => {
            if ($args | length) >= 2 {
                try {
                    let value = configuration get $args.1
                    print $"($args.1) = ($value)"
                } catch { |err|
                    print $"Error: ($err.msg)"
                }
            } else {
                print "Usage: nuaws config get <key>"
                print "Available keys: lazy_loading, completion_cache_ttl, debug, max_completion_items, service_timeout, auto_generate_missing, preferred_output_format, cache_completions, warm_cache_on_startup"
            }
        },
        "reset" => { 
            print "Resetting configuration to defaults..."
            configuration reset 
        },
        "validate" => {
            print "Validating NuAWS and AWS configuration..."
            let validation = configuration validate-aws-config
            
            print $"AWS CLI installed: ($validation.aws_cli_installed)"
            print $"Credentials configured: ($validation.credentials_configured)"
            print $"Region configured: ($validation.region_configured)"
            print $"Identity accessible: ($validation.identity_accessible)"
            
            if ($validation.errors | length) > 0 {
                print ""
                print "Issues found:"
                $validation.errors | each { |error| print $"  ❌ ($error)" } | ignore
            } else {
                print ""
                print "✅ All configuration checks passed!"
            }
        },
        "path" => {
            print $"Configuration file: ($env.NUAWS_CONFIG_DIR)/config.nuon"
            print $"Cache directory: ($env.NUAWS_CACHE_DIR)"
            print $"Plugin directory: ($env.NUAWS_PLUGIN_DIR)"
        },
        _ => {
            print "Available config commands:"
            print "  show      # Show current configuration"
            print "  set       # Set configuration value"
            print "  get       # Get configuration value"
            print "  reset     # Reset to defaults"
            print "  validate  # Validate AWS configuration"
            print "  path      # Show configuration paths"
        }
    }
}

# Handle cache commands
def handle-cache-command [args: list] {
    match ($args | get 0? | default "info") {
        "info" => { show-cache-info },
        "clear" => { clear-cache },
        "warm" => { warm-cache ($args | skip 1) },
        "stats" => { 
            use plugin/core/module_cache.nu
            module_cache get-cache-stats 
        },
        "details" => { 
            use plugin/core/module_cache.nu
            module_cache get-cache-details 
        },
        "cleanup" => { 
            use plugin/core/module_cache.nu
            module_cache cleanup-cache 
        },
        "tune" => { 
            use plugin/core/module_cache.nu
            module_cache auto-tune-cache 
        },
        "maintain" => { 
            use plugin/core/module_cache.nu
            module_cache maintain-cache 
        },
        _ => {
            print "Available cache commands:"
            print "  info                     # Show basic cache information"
            print "  stats                    # Show detailed cache statistics"
            print "  details                  # Show cache entry details"
            print "  clear                    # Clear all caches"
            print "  warm <services...>       # Pre-warm cache with services"
            print "  cleanup                  # Clean expired cache entries"
            print "  tune                     # Auto-tune cache configuration"
            print "  maintain                 # Run cache maintenance"
        }
    }
}

# Show cache information
def show-cache-info [] {
    let cache_dir = $env.NUAWS_CACHE_DIR
    let cache_size = try { 
        du $cache_dir | get apparent 
    } catch { 
        0 
    }
    
    print $"Cache Directory: ($cache_dir)"
    print $"Cache Size: ($cache_size)"
    print $"TTL: ($env.NUAWS_COMPLETION_CACHE_TTL) seconds"
    print ""
    
    # Show cached items
    try {
        let cached_files = ls $cache_dir | where type == file
        if ($cached_files | length) > 0 {
            print "Cached Completions:"
            $cached_files | select name modified | print
        } else {
            print "No cached completions"
        }
    } catch {
        print "Cache directory not accessible"
    }
}

# Clear completion cache
def clear-cache [] {
    try {
        rm -rf $"($env.NUAWS_CACHE_DIR)/*"
        print "✅ Cache cleared"
    } catch {
        print "❌ Failed to clear cache"
    }
}

# Warm cache for specific services
def warm-cache [services: list] {
    if ($services | length) == 0 {
        print "Usage: nuaws cache warm <service1> [service2] ..."
        return
    }
    
    print "🔥 Warming cache for services..."
    for service in $services {
        print $"  Warming ($service)..."
        try {
            service_loader warm-service-cache $service
            print $"  ✅ ($service) cache warmed"
        } catch { |err|
            print $"  ❌ ($service) failed: ($err.msg)"
        }
    }
}

# Route command to appropriate service
def route-to-service [service: string, args: list] {
    # Check for service help request
    if ($args | length) == 0 {
        # Show service help if no operation specified
        show-service-help $service
        return
    }
    
    let operation = $args.0
    let operation_args = $args | skip 1
    
    # Load service module dynamically (this will generate if needed)
    try {
        let service_module = service_loader load-service $service
    } catch { |err|
        # If service loading fails, try direct AWS CLI forwarding
        if ($env.NUAWS_DEBUG == "true") {
            print $"⚠️  Service loading failed, forwarding to AWS CLI: ($err.msg)"
        }
        
        try {
            aws $service ...$args
        } catch { |cli_err|
            error make {
                msg: $"Service '($service)' not available and AWS CLI forwarding failed",
                label: {
                    text: "service unavailable",
                    span: (metadata $service).span
                },
                help: $"
Check if '($service)' is a valid AWS service:
  aws ($service) help

Available services:
  nuaws help    # list all available services
"
            }
        }
        return
    }
    
    # Execute the service operation (handles both module operations and CLI forwarding)
    service_loader execute-operation $service $operation $operation_args
}

# Handle nuaws-specific errors
def handle-nuaws-error [err: record, service: string, args: list] {
    error_handler handle-plugin-error $err $service $args
}

# Handle services command with subcommands
def handle-services-command [args: list] {
    match ($args | get 0? | default "list") {
        "list" => {
            let filter = $args | get 1?
            let sort_by = $args | get 2? | default "name"
            service_manager list-services --filter=$filter --sort-by=$sort_by | table
        },
        "report" => {
            service_manager service-report
        },
        "validate" => {
            service_manager bulk-validate-services --fix-issues=false
        },
        "validate-fix" => {
            service_manager bulk-validate-services --fix-issues=true
        },
        _ => {
            print "Available services commands:"
            print "  list [filter] [sort_by]  # List services with optional filter"
            print "  report                   # Generate service statistics report"
            print "  validate                 # Validate all service modules"
            print "  validate-fix             # Validate and attempt to fix issues"
        }
    }
}

# Handle service management commands
def handle-service-command [args: list] {
    match ($args | get 0? | default "help") {
        "create" => {
            if ($args | length) >= 2 {
                let service_name = $args.1
                let type = $args | get 2? | default "generated"
                service_manager create-service $service_name --type=$type
            } else {
                print "Usage: nuaws service create <service_name> [type]"
                print "Types: generated, native, legacy, passthrough"
            }
        },
        "delete" => {
            if ($args | length) >= 2 {
                let service_name = $args.1
                let force = ($args | get 2? | default "false") == "true"
                service_manager delete-service $service_name --force=$force
            } else {
                print "Usage: nuaws service delete <service_name> [force]"
            }
        },
        "regenerate" => {
            if ($args | length) >= 2 {
                let service_name = $args.1
                service_manager regenerate-service $service_name --force=false --backup=true
            } else {
                print "Usage: nuaws service regenerate <service_name>"
            }
        },
        "validate" => {
            if ($args | length) >= 2 {
                let service_name = $args.1
                service_manager validate-service $service_name
            } else {
                print "Usage: nuaws service validate <service_name>"
            }
        },
        "inspect" => {
            if ($args | length) >= 2 {
                let service_name = $args.1
                service_manager inspect-service $service_name
            } else {
                print "Usage: nuaws service inspect <service_name>"
            }
        },
        _ => {
            print "Available service management commands:"
            print "  create <name> [type]     # Create new service module"
            print "  delete <name> [force]    # Delete service module"
            print "  regenerate <name>        # Regenerate service module"
            print "  validate <name>          # Validate service module"
            print "  inspect <name>           # Get detailed service information"
        }
    }
}

# Handle completions command with subcommands
def handle-completions-command [args: list] {
    match ($args | get 0? | default "status") {
        "status" => {
            completion_manager completion-system-report
        },
        "init" => {
            completion_manager init-completion-system
        },
        "validate" => {
            completion_manager validate-completion-system
        },
        "optimize" => {
            completion_manager optimize-completions
        },
        "generate-script" => {
            let output_file = $args | get 1? | default "nuaws_completions.nu"
            completion_manager generate-completion-script --output-file=$output_file
        },
        "list" => {
            completion_manager list-completion-usage | table
        },
        "test" => {
            let service = $args | get 1? | default "s3"
            let resource = $args | get 2? | default "buckets"
            use plugin/core/external_completions.nu
            external_completions test-completions --service=$service --resource=$resource
        },
        "maintain" => {
            completion_manager maintain-completion-system
        },
        "enable" => {
            use plugin/core/external_completions.nu
            external_completions set-completions-enabled true
        },
        "disable" => {
            use plugin/core/external_completions.nu
            external_completions set-completions-enabled false
        },
        "register" => {
            if ($args | length) >= 2 {
                let service_name = $args.1
                completion_manager register-service-completions $service_name
            } else {
                print "Usage: nuaws completions register <service_name>"
            }
        },
        _ => {
            print "Available completions commands:"
            print "  status                       # Show completion system status"
            print "  init                         # Initialize completion system"
            print "  validate                     # Validate completion system health"
            print "  optimize                     # Optimize completion performance"
            print "  generate-script [file]       # Generate completion script for Nushell"
            print "  list                         # List completion usage statistics"
            print "  test [service] [resource]    # Test completion functionality"
            print "  maintain                     # Run full maintenance cycle"
            print "  enable                       # Enable external completions"
            print "  disable                      # Disable external completions"
            print "  register <service>           # Register completions for service"
        }
    }
}

# External completion for nuaws services
export def "nu-complete nuaws services" [] {
    try {
        service_loader list-available-services | get name
    } catch {
        # Fallback list if service loader not available
        ["s3", "ec2", "iam", "lambda", "stepfunctions", "dynamodb"]
    }
}