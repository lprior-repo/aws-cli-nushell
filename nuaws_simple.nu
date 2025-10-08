# NuAWS - Native Nushell AWS CLI Plugin
# Simplified module interface for easy integration
# Compatible with Nushell 0.107.0

# Core plugin functionality
export def "nuaws version" [] {
    {
        version: "1.0.0-alpha",
        build_date: "2025-01-08",
        nushell_version: $nu.version,
        plugin_type: "native_module"
    }
}

export def "nuaws help" [] {
    print "NuAWS - Native Nushell AWS CLI Plugin"
    print "======================================"
    print ""
    print "Usage: nuaws <command> [args...]"
    print ""
    print "Core Commands:"
    print "  version                 Show plugin version"
    print "  help                    Show this help message"
    print "  init                    Initialize plugin system"
    print "  status                  Show plugin system status"
    print ""
    print "Module Usage:"
    print "  use nuaws_simple.nu     # Import all functions"
    print "  nuaws init              # Initialize the system"
    print "  nuaws status            # Check system health"
    print ""
    print "Testing Framework:"
    print "  use nutest/plugin/mod.nu as testing"
    print "  testing run-plugin-tests"
    print ""
    print "Core Components:"
    print "  plugin/core/            # Core infrastructure"
    print "  nutest/plugin/          # Testing framework"
    print "  aws/                    # AWS service modules"
}

export def "nuaws init" [
    --force = false,
    --with-completions = true,
    --with-cache = true
] {
    # Initialize core directories
    let config_dir = $"($env.HOME)/.nuaws"
    let cache_dir = $"($config_dir)/cache"
    
    if not ($config_dir | path exists) or $force {
        mkdir $config_dir
        mkdir $cache_dir
        mkdir $"($cache_dir)/completions"
        print "✅ Plugin directories created"
    }
    
    # Set environment variables
    load-env {
        NUAWS_PLUGIN_DIR: "plugin",
        NUAWS_CACHE_DIR: $cache_dir,
        NUAWS_CONFIG_DIR: $config_dir,
        NUAWS_DEBUG: "false"
    }
    
    print "🚀 NuAWS Plugin System Initialized"
    print ""
    print "Available components:"
    print "  • Core plugin infrastructure (plugin/core/)"
    print "  • Testing framework (nutest/plugin/)"
    print "  • AWS service modules (aws/)"
    print ""
    print "Next steps:"
    print "  nuaws status            # Check system health"
    print "  use plugin/core/service_registry.nu; service_registry list-registered-services"
    
    {
        initialized: true,
        timestamp: (date now),
        config_dir: $config_dir,
        cache_dir: $cache_dir
    }
}

export def "nuaws status" [] {
    let config_dir = $env.NUAWS_CONFIG_DIR? | default $"($env.HOME)/.nuaws"
    let cache_dir = $env.NUAWS_CACHE_DIR? | default $"($config_dir)/cache"
    
    let system_health = {
        directories_exist: (($config_dir | path exists) and ($cache_dir | path exists)),
        plugin_dir: ($env.NUAWS_PLUGIN_DIR? | default "not_set"),
        cache_dir: $cache_dir,
        config_dir: $config_dir,
        debug_mode: ($env.NUAWS_DEBUG? | default "false")
    }
    
    print "NuAWS Plugin System Status"
    print "=========================="
    print $"Directories: (if $system_health.directories_exist { '✅' } else { '❌' })"
    print $"Plugin Dir: ($system_health.plugin_dir)"
    print $"Cache Dir: ($system_health.cache_dir)"
    print $"Config Dir: ($system_health.config_dir)"
    print $"Debug Mode: ($system_health.debug_mode)"
    
    # Check core components
    let core_components = [
        "plugin/core/configuration.nu",
        "plugin/core/service_registry.nu", 
        "plugin/core/module_cache.nu",
        "plugin/core/completion_registry.nu"
    ]
    
    print ""
    print "Core Components:"
    for component in $core_components {
        let exists = $component | path exists
        let status = if $exists { "✅" } else { "❌" }
        print $"  ($status) ($component)"
    }
    
    # Check testing framework
    let test_components = [
        "nutest/plugin/mod.nu",
        "nutest/plugin/plugin_test_utilities.nu",
        "nutest/plugin/mock_aws_environment.nu"
    ]
    
    print ""
    print "Testing Framework:"
    for component in $test_components {
        let exists = $component | path exists
        let status = if $exists { "✅" } else { "❌" }
        print $"  ($status) ($component)"
    }
    
    # Check AWS services
    if ("aws" | path exists) {
        let aws_services = ls aws | where type == file and name =~ '\\.nu$'
        print ""
        print $"AWS Services: ($aws_services | length) discovered"
        if ($aws_services | length) > 0 {
            for service in $aws_services {
                let parsed_path = $service.name | path parse
                let service_name = $parsed_path.stem
                print $"  • ($service_name)"
            }
        }
    }
    
    $system_health
}

# Core module access functions
export def "nuaws core" [subcommand: string, ...args] {
    match $subcommand {
        "config" => {
            use plugin/core/configuration.nu
            if ($args | length) > 0 {
                match $args.0 {
                    "show" => { configuration show },
                    "get" => { 
                        if ($args | length) > 1 {
                            configuration get $args.1 
                        } else {
                            print "Usage: nuaws core config get <key>"
                        }
                    },
                    "set" => { 
                        if ($args | length) > 2 {
                            configuration set $args.1 $args.2 
                        } else {
                            print "Usage: nuaws core config set <key> <value>"
                        }
                    },
                    _ => { print "Available actions: show, get, set" }
                }
            } else {
                configuration show
            }
        },
        "services" => {
            use plugin/core/service_registry.nu
            if ($args | length) > 0 {
                match $args.0 {
                    "list" => { service_registry list-registered-services },
                    "stats" => { service_registry get-service-statistics },
                    _ => { print "Available actions: list, stats" }
                }
            } else {
                service_registry list-registered-services
            }
        },
        "cache" => {
            use plugin/core/module_cache.nu
            if ($args | length) > 0 {
                match $args.0 {
                    "status" => { module_cache get-cache-stats },
                    "clear" => { module_cache clear-cache },
                    "cleanup" => { module_cache cleanup-cache },
                    _ => { print "Available actions: status, clear, cleanup" }
                }
            } else {
                module_cache get-cache-stats
            }
        },
        _ => {
            print "Available core commands: config, services, cache"
        }
    }
}

# Testing framework access
export def "nuaws test" [subcommand: string, ...args] {
    match $subcommand {
        "health" => {
            use nutest/plugin/plugin_test_utilities.nu
            plugin_test_utilities validate-plugin-health
        },
        "mock" => {
            use nutest/plugin/mock_aws_environment.nu
            mock_aws_environment validate-mock-responses
        },
        "run" => {
            use nutest/plugin/mod.nu
            if ($args | length) > 0 {
                mod run-plugin-tests --path=$args.0
            } else {
                mod run-plugin-tests
            }
        },
        _ => {
            print "Available test commands: health, mock, run"
            print "Usage:"
            print "  nuaws test health       # Check plugin health"
            print "  nuaws test mock         # Test mock environment"
            print "  nuaws test run [path]   # Run plugin tests"
        }
    }
}

# AWS service access
export def "nuaws aws" [service?: string, ...args] {
    if $service == null {
        if ("aws" | path exists) {
            let aws_services = ls aws | where type == file and name =~ '\\.nu$'
            print "Available AWS services:"
            for service_file in $aws_services {
                let parsed_path = $service_file.name | path parse
                let service_name = $parsed_path.stem
                print $"  • ($service_name)"
            }
        } else {
            print "No AWS services directory found. Create 'aws/' directory with service modules."
        }
        return
    }
    
    let service_path = $"aws/($service).nu"
    if ($service_path | path exists) {
        if ($args | length) > 0 {
            let command = $args | str join " "
            ^nu -c $"source ($service_path); nuaws ($service) ($command)"
        } else {
            ^nu -c $"source ($service_path); nuaws ($service) help"
        }
    } else {
        print $"Service '($service)' not found at ($service_path)"
        nuaws aws
    }
}

# Main entry point function
export def main [subcommand?: string, ...args] {
    match $subcommand {
        null | "help" => { nuaws help },
        "version" => { nuaws version },
        "init" => { 
            if ($args | length) > 0 {
                # Handle arguments manually since we can't spread
                let force_flag = "--force" in $args
                let no_completions = "--no-completions" in $args or "--with-completions=false" in $args
                let no_cache = "--no-cache" in $args or "--with-cache=false" in $args
                nuaws init --force=$force_flag --with-completions=(not $no_completions) --with-cache=(not $no_cache)
            } else {
                nuaws init
            }
        },
        "status" => { nuaws status },
        "core" => { 
            if ($args | length) > 0 {
                let rest_args = $args | skip 1
                if ($rest_args | length) > 0 {
                    nuaws core $args.0 $rest_args.0 ($rest_args | skip 1 | str join " ")
                } else {
                    nuaws core $args.0
                }
            } else {
                nuaws core "help"
            }
        },
        "test" => { 
            if ($args | length) > 0 {
                let rest_args = $args | skip 1
                if ($rest_args | length) > 0 {
                    nuaws test $args.0 $rest_args.0
                } else {
                    nuaws test $args.0
                }
            } else {
                nuaws test "help"
            }
        },
        "aws" => { 
            if ($args | length) > 0 {
                let rest_args = $args | skip 1
                if ($rest_args | length) > 0 {
                    nuaws aws $args.0 ($rest_args | str join " ")
                } else {
                    nuaws aws $args.0
                }
            } else {
                nuaws aws
            }
        },
        _ => {
            # Try to route as AWS service directly
            if ($args | length) > 0 {
                nuaws aws $subcommand ($args | str join " ")
            } else {
                nuaws aws $subcommand
            }
        }
    }
}

# Convenient aliases
export alias aws = main
export alias nuaws-plugin = main