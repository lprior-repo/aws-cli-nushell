# Configuration Management - Plugin settings and AWS configuration
# Handles plugin configuration, AWS credentials delegation, and user preferences

# Default configuration values
const DEFAULT_CONFIG = {
    lazy_loading: true,
    completion_cache_ttl: 300,
    debug: false,
    max_completion_items: 50,
    service_timeout: 30,
    auto_generate_missing: true,
    preferred_output_format: "table",
    cache_completions: true,
    warm_cache_on_startup: false
}

# Get configuration file path
def get-config-path []: nothing -> string {
    let config_dir = ($env.NUAWS_CONFIG_DIR? | default $"($env.HOME)/.nuaws")
    $"($config_dir)/config.nuon"
}

# Initialize configuration if missing
export def init-if-missing []: nothing -> nothing {
    let config_path = get-config-path
    
    if not ($config_path | path exists) {
        print "🔧 Initializing NuAWS configuration..."
        $DEFAULT_CONFIG | save $config_path
        print $"✅ Configuration created at: ($config_path)"
    }
}

# Show current configuration
export def show []: nothing -> nothing {
    let config = load-config
    
    print "╔══════════════════════════════════════════════════════════════╗"
    print "║                    NuAWS Configuration                       ║"
    print "╚══════════════════════════════════════════════════════════════╝"
    print ""
    
    print "Plugin Settings:"
    $config | transpose key value | each { |item|
        print $"  ($item.key): ($item.value)"
    } | ignore
    
    print ""
    print "AWS Configuration (inherited from AWS CLI):"
    show-aws-config
    
    print ""
    print $"Configuration file: (get-config-path)"
}

# Get a configuration value
export def get [key: string]: nothing -> any {
    let config = load-config
    
    # Temporary fix for get command issues
    match $key {
        "lazy_loading" => $config.lazy_loading,
        "completion_cache_ttl" => $config.completion_cache_ttl,
        "debug" => $config.debug,
        "max_completion_items" => $config.max_completion_items,
        "service_timeout" => $config.service_timeout,
        "auto_generate_missing" => $config.auto_generate_missing,
        "preferred_output_format" => $config.preferred_output_format,
        "cache_completions" => $config.cache_completions,
        "warm_cache_on_startup" => $config.warm_cache_on_startup,
        _ => {
            error make {
                msg: $"Configuration key '($key)' not found",
                help: $"Available keys: lazy_loading, completion_cache_ttl, debug, max_completion_items, service_timeout, auto_generate_missing, preferred_output_format, cache_completions, warm_cache_on_startup"
            }
        }
    }
}

# Set a configuration value
export def set [key: string, value: any]: nothing -> nothing {
    mut config = load-config
    
    # Validate configuration key
    if $key not-in ($DEFAULT_CONFIG | columns) {
        error make {
            msg: $"Invalid configuration key '($key)'",
            help: $"Valid keys: ($DEFAULT_CONFIG | columns | str join ', ')"
        }
    }
    
    # Type validation based on default values
    let expected_type = match $key {
        "lazy_loading" => "bool",
        "completion_cache_ttl" => "int",
        "debug" => "bool", 
        "max_completion_items" => "int",
        "service_timeout" => "int",
        "auto_generate_missing" => "bool",
        "preferred_output_format" => "string",
        "cache_completions" => "bool",
        "warm_cache_on_startup" => "bool",
        _ => "string"
    }
    let actual_type = ($value | describe)
    
    if $expected_type != $actual_type {
        # Try to convert compatible types
        let converted_value = match [$expected_type, $actual_type] {
            ["bool", "string"] => ($value | into bool),
            ["int", "string"] => ($value | into int),
            ["float", "string"] => ($value | into float),
            _ => $value
        }
        
        $config = ($config | upsert $key $converted_value)
    } else {
        $config = ($config | upsert $key $value)
    }
    
    # Save updated configuration
    $config | save --force (get-config-path)
    
    print $"✅ Set ($key) = ($value)"
    
    # Update environment variables if needed
    update-environment-from-config $config
}

# Reset configuration to defaults
export def reset []: nothing -> nothing {
    $DEFAULT_CONFIG | save --force (get-config-path)
    print "✅ Configuration reset to defaults"
    
    # Update environment
    update-environment-from-config $DEFAULT_CONFIG
}

# Load current configuration with fallback to defaults
def load-config []: nothing -> record {
    let config_path = get-config-path
    
    if ($config_path | path exists) {
        try {
            let user_config = open $config_path
            # Merge with defaults to ensure all keys exist
            $DEFAULT_CONFIG | merge $user_config
        } catch {
            print $"⚠️  Error loading config, using defaults"
            $DEFAULT_CONFIG
        }
    } else {
        $DEFAULT_CONFIG
    }
}

# Update environment variables from configuration
def update-environment-from-config [config: record]: nothing -> nothing {
    $env.NUAWS_LAZY_LOADING = ($config.lazy_loading | into string)
    $env.NUAWS_COMPLETION_CACHE_TTL = ($config.completion_cache_ttl | into string)
    $env.NUAWS_DEBUG = ($config.debug | into string)
}

# Show AWS CLI configuration (inherited)
def show-aws-config []: nothing -> nothing {
    try {
        print "AWS CLI Profile Information:"
        aws configure list | lines | each { |line|
            if ($line | str length) > 0 and not ($line | str starts-with "    ") {
                print $"  ($line)"
            }
        } | ignore
        
        print ""
        print "Current AWS Identity:"
        let identity = aws sts get-caller-identity | from json
        print $"  Account: ($identity.Account)"
        print $"  User/Role: ($identity.Arn)"
        print $"  User ID: ($identity.UserId)"
        
    } catch { |err|
        print "  ⚠️  AWS CLI not configured or not accessible"
        print $"  Error: ($err.msg)"
        print ""
        print "  To configure AWS CLI:"
        print "    aws configure"
        print "  Or set environment variables:"
        print "    export AWS_ACCESS_KEY_ID=your_key"
        print "    export AWS_SECRET_ACCESS_KEY=your_secret"
        print "    export AWS_DEFAULT_REGION=us-east-1"
    }
}

# Validate AWS CLI configuration
export def validate-aws-config []: nothing -> record {
    # Initialize base validation result
    let base_result = {
        aws_cli_installed: false,
        credentials_configured: false,
        region_configured: false,
        identity_accessible: false,
        errors: []
    }
    
    # Check AWS CLI installation
    let cli_check = try {
        aws --version | ignore
        {installed: true, error: null}
    } catch {
        {installed: false, error: "AWS CLI not installed"}
    }
    
    # Check credentials
    let creds_check = try {
        aws configure list | ignore
        {configured: true, error: null}
    } catch {
        {configured: false, error: "AWS credentials not configured"}
    }
    
    # Check region
    let region_check = try {
        let region = aws configure get region
        if ($region | str length) > 0 {
            {configured: true, error: null}
        } else {
            {configured: false, error: "AWS region not configured"}
        }
    } catch {
        {configured: false, error: "Cannot determine AWS region"}
    }
    
    # Check identity
    let identity_check = try {
        aws sts get-caller-identity | from json | ignore
        {accessible: true, error: null}
    } catch {
        {accessible: false, error: "Cannot access AWS identity (check credentials)"}
    }
    
    # Collect all errors
    let all_errors = [
        $cli_check.error,
        $creds_check.error,
        $region_check.error,
        $identity_check.error
    ] | where {|x| $x != null}
    
    # Build final result
    {
        aws_cli_installed: $cli_check.installed,
        credentials_configured: $creds_check.configured,
        region_configured: $region_check.configured,
        identity_accessible: $identity_check.accessible,
        errors: $all_errors
    }
}

# Get AWS profile information
export def get-aws-profile []: nothing -> record {
    try {
        let profile_name = $env.AWS_PROFILE? | default "default"
        let region = try { aws configure get region } catch { "unknown" }
        let identity = try { aws sts get-caller-identity | from json } catch { null }
        
        {
            profile_name: $profile_name,
            region: $region,
            identity: $identity,
            credentials_file: $"($env.HOME)/.aws/credentials",
            config_file: $"($env.HOME)/.aws/config"
        }
    } catch {
        {
            profile_name: "unknown",
            region: "unknown",
            identity: null,
            error: "AWS configuration not accessible"
        }
    }
}

# Note: Configuration initialization is handled by the main plugin
# to avoid issues with environment variables during module loading