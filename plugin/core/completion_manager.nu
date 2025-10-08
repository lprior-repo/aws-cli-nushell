# Completion Manager - High-level completion system management
# Coordinates completion registry, external completions, and service integration

use completion_registry.nu
use external_completions.nu
use configuration.nu
use error_handler.nu

# Initialize completion management system
export def init-completion-system []: nothing -> record {
    # Ensure completion directories exist
    let completion_dir = $"($env.NUAWS_CACHE_DIR)/completions"
    mkdir $completion_dir
    
    # Auto-register standard completions
    let registration_result = completion_registry auto-register-standard-completions
    
    # Initialize external completions if enabled
    let external_status = external_completions get-completions-status
    
    {
        success: true,
        completion_cache_dir: $completion_dir,
        registration_result: $registration_result,
        external_completions: $external_status,
        initialized_at: (date now)
    }
}

# Generate completion script for Nushell integration
export def generate-completion-script [
    --output-file: string = "nuaws_completions.nu"
]: nothing -> record {
    
    let completion_functions = external_completions list-external-completions
    
    let script_header = $"# NuAWS External Completions
# Auto-generated completion functions for AWS resources
# Generated at: (date now)
#
# To use these completions, source this file in your Nushell config:
# source ($output_file)

"
    
    let function_definitions = $completion_functions | each { |func|
        let func_name = $func.name
        let description = $func.description
        let service = $func.service
        
        $"# ($description)
export def \"($func_name)\" []: nothing -> list<string> {
    try {
        use ($env.NUAWS_PLUGIN_DIR)/core/external_completions.nu
        external_completions ($func_name | str replace 'nu-complete ' '')
    } catch {
        []
    }
}

"
    } | str join ""
    
    let full_script = $script_header + $function_definitions
    
    # Write the script file
    $full_script | save $output_file
    
    {
        success: true,
        output_file: $output_file,
        function_count: ($completion_functions | length),
        script_size: ($full_script | str length),
        message: $"Generated completion script with ($completion_functions | length) functions"
    }
}

# Validate completion system health
export def validate-completion-system []: nothing -> record {
    # Test completion registry
    let registry_result = try {
        let registry_stats = completion_registry get-completion-stats
        {
            component: "completion_registry",
            status: "healthy",
            details: $registry_stats
        }
    } catch { |err|
        {
            component: "completion_registry", 
            status: "error",
            error: $err.msg
        }
    }
    
    # Test external completions
    let external_result = try {
        let external_status = external_completions get-completions-status
        {
            component: "external_completions",
            status: "healthy", 
            details: $external_status
        }
    } catch { |err|
        {
            component: "external_completions",
            status: "error", 
            error: $err.msg
        }
    }
    
    # Test AWS CLI connectivity
    let aws_cli_result = try {
        aws sts get-caller-identity | from json | ignore
        {
            component: "aws_cli_connectivity",
            status: "healthy",
            details: "AWS CLI accessible"
        }
    } catch { |err|
        {
            component: "aws_cli_connectivity",
            status: "warning",
            error: $err.msg,
            message: "AWS CLI not accessible - completions may not work"
        }
    }
    
    # Test sample completion
    let completion_test_result = try {
        let test_result = external_completions test-completions --service="s3" --resource="buckets"
        if $test_result.success {
            {
                component: "sample_completion_test",
                status: "healthy",
                details: $test_result
            }
        } else {
            {
                component: "sample_completion_test",
                status: "warning",
                error: $test_result.error
            }
        }
    } catch { |err|
        {
            component: "sample_completion_test",
            status: "error",
            error: $err.msg
        }
    }
    
    let validation_results = [$registry_result, $external_result, $aws_cli_result, $completion_test_result]
    let overall_health = ($validation_results | where status == "error" | length) == 0
    
    {
        overall_health: $overall_health,
        validation_results: $validation_results,
        healthy_components: ($validation_results | where status == "healthy" | length),
        warning_components: ($validation_results | where status == "warning" | length), 
        error_components: ($validation_results | where status == "error" | length),
        validated_at: (date now)
    }
}

# Optimize completion performance
export def optimize-completions [
    --warm-common-resources = true,
    --cleanup-expired-cache = true,
    --tune-cache-settings = true
]: nothing -> record {
    
    # Cleanup expired cache entries
    let cleanup_results = if $cleanup_expired_cache {
        try {
            let cleanup_result = completion_registry clear-completion-cache
            [{
                step: "cache_cleanup",
                status: "completed",
                result: $cleanup_result
            }]
        } catch { |err|
            [{
                step: "cache_cleanup",
                status: "failed", 
                error: $err.msg
            }]
        }
    } else {
        []
    }
    
    # Warm common resource caches
    let warming_results = if $warm_common_resources {
        let common_resources = [
            ["s3", "buckets"],
            ["ec2", "instances"],
            ["iam", "users"],
            ["lambda", "functions"]
        ]
        
        $common_resources | each { |resource_pair|
            let service = $resource_pair.0
            let resource = $resource_pair.1
            
            try {
                completion_registry discover-aws-resources $service $resource | ignore
                {
                    step: $"warm_($service)_($resource)",
                    status: "completed"
                }
            } catch { |err|
                {
                    step: $"warm_($service)_($resource)",
                    status: "failed",
                    error: $err.msg
                }
            }
        }
    } else {
        []
    }
    
    # Tune cache settings based on usage patterns
    let tuning_results = if $tune_cache_settings {
        try {
            let stats = completion_registry get-completion-stats
            let hit_rate = if $stats.cache_hits + $stats.cache_misses > 0 {
                ($stats.cache_hits / ($stats.cache_hits + $stats.cache_misses)) * 100
            } else {
                0
            }
            
            # Adjust TTL based on hit rate
            let current_ttl = configuration get "completion_cache_ttl" | into int
            let new_ttl = if $hit_rate > 80 {
                # High hit rate, increase TTL
                $current_ttl * 1.2 | math round
            } else if $hit_rate < 50 {
                # Low hit rate, decrease TTL
                $current_ttl * 0.8 | math round
            } else {
                $current_ttl
            }
            
            if $new_ttl != $current_ttl {
                configuration set "completion_cache_ttl" ($new_ttl | into string)
                [{
                    step: "cache_ttl_tuning",
                    status: "completed",
                    old_ttl: $current_ttl,
                    new_ttl: $new_ttl,
                    hit_rate: $hit_rate
                }]
            } else {
                [{
                    step: "cache_ttl_tuning", 
                    status: "no_change_needed",
                    hit_rate: $hit_rate
                }]
            }
        } catch { |err|
            [{
                step: "cache_ttl_tuning",
                status: "failed",
                error: $err.msg
            }]
        }
    } else {
        []
    }
    
    let optimization_results = $cleanup_results | append $warming_results | append $tuning_results
    
    {
        success: true,
        optimization_steps: ($optimization_results | length),
        completed_steps: ($optimization_results | where status == "completed" | length),
        failed_steps: ($optimization_results | where status == "failed" | length),
        results: $optimization_results,
        optimized_at: (date now)
    }
}

# Register completions for a new service module
export def register-service-completions [
    service_name: string,
    --auto-discover = true
]: nothing -> record {
    
    if not $auto_discover {
        return {
            success: false,
            message: "Manual completion registration not yet implemented"
        }
    }
    
    # Auto-discover and register completions based on common patterns
    let common_completions = [
        # S3-like operations
        ["ls", "bucket", "discover-s3-buckets"],
        ["cp", "source", "discover-s3-buckets"],
        ["cp", "destination", "discover-s3-buckets"],
        
        # EC2-like operations  
        ["describe-instances", "instance-ids", "discover-ec2-instances"],
        ["terminate-instances", "instance-ids", "discover-ec2-instances"],
        ["start-instances", "instance-ids", "discover-ec2-instances"],
        ["stop-instances", "instance-ids", "discover-ec2-instances"],
        
        # IAM-like operations
        ["get-user", "user-name", "discover-iam-users"],
        ["delete-user", "user-name", "discover-iam-users"],
        ["get-role", "role-name", "discover-iam-roles"],
        ["delete-role", "role-name", "discover-iam-roles"],
        
        # Lambda-like operations
        ["invoke", "function-name", "discover-lambda-functions"],
        ["delete-function", "function-name", "discover-lambda-functions"],
        ["get-function", "function-name", "discover-lambda-functions"]
    ]
    
    let registration_results = $common_completions | each { |completion_pattern|
        let operation = $completion_pattern.0
        let parameter = $completion_pattern.1
        let function_name = $completion_pattern.2
        
        # Adjust function name for the specific service
        let service_function = $function_name | str replace "discover-" $"discover-($service_name)-"
        
        try {
            completion_registry register-completion $service_name $operation $parameter $service_function --description=$"Auto-registered for ($service_name)"
        } catch { |err|
            {
                success: false,
                operation: $operation,
                parameter: $parameter,
                error: $err.msg
            }
        }
    }
    
    let registered_count = $registration_results | where success == true | length
    
    {
        success: ($registered_count > 0),
        service: $service_name,
        registered_completions: $registered_count,
        total_attempted: ($common_completions | length),
        registration_results: $registration_results,
        message: $"Registered ($registered_count) completions for ($service_name)"
    }
}

# Get comprehensive completion system report
export def completion-system-report []: nothing -> record {
    let registry_stats = try { completion_registry get-completion-stats } catch { {} }
    let external_status = try { external_completions get-completions-status } catch { {} }
    let validation = validate-completion-system
    
    {
        system_health: $validation.overall_health,
        registry_statistics: $registry_stats,
        external_completions_status: $external_status,
        validation_details: $validation,
        cache_directory: $"($env.NUAWS_CACHE_DIR)/completions",
        configuration: {
            cache_ttl: (try { configuration get "completion_cache_ttl" } catch { "300" }),
            external_enabled: ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED? | default "true"),
            aws_region: ($env.AWS_DEFAULT_REGION? | default "us-east-1")
        },
        report_generated_at: (date now)
    }
}

# List all completion functions with their usage statistics
export def list-completion-usage []: nothing -> table {
    let registry_completions = try { 
        completion_registry list-completions | select service operation parameter usage_count last_used
    } catch { 
        [] 
    }
    
    let external_functions = external_completions list-external-completions | select name service description
    
    # Combine information
    $external_functions | each { |func|
        let matching_registry = $registry_completions | where service == $func.service
        
        {
            name: $func.name,
            service: $func.service,
            description: $func.description,
            registered_count: ($matching_registry | length),
            total_usage: ($matching_registry | each { |r| $r.usage_count } | math sum),
            last_used: ($matching_registry | each { |r| $r.last_used } | where $it != null | math max)
        }
    }
}

# Cleanup and maintenance operations
export def maintain-completion-system []: nothing -> record {
    # Run optimization with all options enabled
    let optimization = optimize-completions --warm-common-resources=true --cleanup-expired-cache=true --tune-cache-settings=true
    
    # Generate fresh completion script
    let script_generation = generate-completion-script
    
    # Validate system health
    let validation = validate-completion-system
    
    {
        maintenance_completed: true,
        optimization_result: $optimization,
        script_generation_result: $script_generation,
        validation_result: $validation,
        maintenance_performed_at: (date now)
    }
}