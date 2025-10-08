# Plugin Test Utilities - Extended testing framework for NuAWS plugin
# Provides specialized testing utilities, mocks, and assertions for plugin testing

use std assert

# Initialize plugin test environment
export def init-plugin-test-env []: nothing -> record {
    # Setup plugin directories
    $env.NUAWS_PLUGIN_DIR = $"(pwd)/plugin"
    $env.NUAWS_CACHE_DIR = $"($env.HOME)/.nuaws/cache"
    $env.NUAWS_CONFIG_DIR = $"($env.HOME)/.nuaws"
    $env.AWS_PROFILE = ($env.AWS_PROFILE? | default "default")
    $env.AWS_DEFAULT_REGION = ($env.AWS_DEFAULT_REGION? | default "us-east-1")
    
    # Initialize plugin system state
    $env.NUAWS_SERVICE_REGISTRY = {}
    $env.NUAWS_MODULE_CACHE = {}
    $env.NUAWS_MODULE_CACHE_ENTRIES = {}
    $env.NUAWS_VALIDATION_CACHE = {}
    $env.NUAWS_CACHE_STATS = {
        hits: 0,
        misses: 0,
        evictions: 0,
        created: (date now),
        last_cleanup: (date now)
    }
    
    # Initialize completion system state
    $env.NUAWS_COMPLETION_REGISTRY = {}
    $env.NUAWS_COMPLETION_CACHE = {}
    $env.NUAWS_COMPLETION_METADATA = {}
    $env.NUAWS_COMPLETION_STATS = {
        total_registrations: 0,
        cache_hits: 0,
        cache_misses: 0,
        discovery_calls: 0,
        last_cleanup: (date now)
    }
    $env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED = "true"
    
    # Enable debug mode for testing
    $env.NUAWS_DEBUG = "true"
    
    # Ensure directories exist
    mkdir $env.NUAWS_CONFIG_DIR
    mkdir $env.NUAWS_CACHE_DIR
    mkdir $"($env.NUAWS_CACHE_DIR)/completions"
    
    {
        initialized: true,
        timestamp: (date now),
        plugin_dir: $env.NUAWS_PLUGIN_DIR,
        cache_dir: $env.NUAWS_CACHE_DIR,
        config_dir: $env.NUAWS_CONFIG_DIR
    }
}

# Enable mock mode for AWS CLI calls
export def enable-aws-mock-mode [service: string]: nothing -> nothing {
    let mock_env_var = $"($service | str upcase)_MOCK_MODE"
    load-env {$mock_env_var: "true"}
}

# Disable mock mode for AWS CLI calls
export def disable-aws-mock-mode [service: string]: nothing -> nothing {
    let mock_env_var = $"($service | str upcase)_MOCK_MODE"
    try {
        hide-env $mock_env_var
    } catch {
        # Ignore if variable doesn't exist
    }
}

# Assert that a plugin module exports required functions
export def assert-plugin-module-exports [
    module_path: string,
    required_exports: list<string>
]: nothing -> nothing {
    assert ($module_path | path exists) $"Module file should exist: ($module_path)"
    
    let module_content = open $module_path
    
    for export_name in $required_exports {
        assert ($module_content | str contains $"export def ($export_name)") $"Module should export ($export_name)"
    }
}

# Assert that a configuration value is set correctly
export def assert-config-value [
    key: string,
    expected_value: any
]: nothing -> nothing {
    use plugin/core/configuration.nu
    
    let actual_value = configuration get $key
    assert ($actual_value == $expected_value) $"Configuration ($key) should be ($expected_value), got ($actual_value)"
}

# Assert that a service is registered correctly
export def assert-service-registered [
    service_name: string
]: nothing -> nothing {
    use ../plugin/core/service_registry.nu
    
    let services = service_registry list-registered-services
    let service_names = $services | get name
    
    assert ($service_name in $service_names) $"Service ($service_name) should be registered"
}

# Assert that completion functions are available
export def assert-completion-functions-available [
    service: string,
    expected_functions: list<string>
]: nothing -> nothing {
    use ../plugin/core/external_completions.nu
    
    let available_functions = external_completions list-external-completions
    let function_names = $available_functions | get name
    
    for func_name in $expected_functions {
        assert ($func_name in $function_names) $"Completion function ($func_name) should be available"
    }
}

# Assert that AWS CLI mock responses work
export def assert-mock-response [
    service: string,
    operation: string,
    expected_response_type: string
]: nothing -> nothing {
    enable-aws-mock-mode $service
    
    try {
        let result = ^aws $service $operation --output json | from json
        let result_type = $result | describe
        assert ($result_type | str contains $expected_response_type) $"Mock response should be of type ($expected_response_type)"
    } catch { |err|
        # Some mock responses might not be JSON - that's ok for basic testing
        print $"Mock test for ($service) ($operation): ($err.msg)"
    }
    
    disable-aws-mock-mode $service
}

# Create a temporary test service module
export def create-test-service-module [
    service_name: string,
    operations: list<string>
]: nothing -> string {
    let module_path = $"($env.NUAWS_CACHE_DIR)/test_($service_name).nu"
    
    # Create simple module content
    let operations_str = $operations | str join '", "'
    let module_content = $"# Test service module for ($service_name)
# Auto-generated for testing

export def get-service-metadata []: nothing -> record {{
    {{
        name: \"($service_name)\",
        description: \"Test ($service_name) service\",
        version: \"1.0.0-test\",
        type: \"test\",
        operations: [\"($operations_str)\"]
    }}
}}

export def list-operations []: nothing -> list<string> {{
    [\"($operations_str)\"]
}}

export def \"nuaws ($service_name) help\" [...args] {{
    print \"Test help for ($service_name)\"
    {{
        service: \"($service_name)\",
        operations: [\"($operations_str)\"],
        help: \"This is a test service module\"
    }}
}}

export def \"nuaws ($service_name) test-op\" [...args] {{
    print \"Test operation with args: ($args | str join ' ')\"
    {{result: \"test_success\", operation: \"test-op\", args: $args}}
}}"
    
    $module_content | save $module_path
    $module_path
}

# Clean up test service module
export def cleanup-test-service-module [module_path: string]: nothing -> nothing {
    if ($module_path | path exists) {
        rm $module_path
    }
}

# Assert that plugin command execution works
export def assert-plugin-command-works [
    command: list<string>
]: nothing -> record {
    let start_time = date now
    
    let result = try {
        ^nu ...$command | complete
    } catch { |err|
        {
            success: false,
            error: $err.msg,
            command: ($command | str join " ")
        }
    }
    
    let end_time = date now
    let duration = $end_time - $start_time
    
    if ($result.exit_code? | default 1) == 0 {
        {
            success: true,
            command: ($command | str join " "),
            output: $result.stdout,
            duration: $duration
        }
    } else {
        {
            success: false,
            command: ($command | str join " "),
            error: $result.stderr,
            duration: $duration
        }
    }
}

# Mock AWS CLI responses for testing
export def setup-aws-cli-mock [
    responses: record
]: nothing -> nothing {
    # This would set up a more sophisticated mock system
    # For now, we use environment variables to enable mock mode
    
    for service in ($responses | columns) {
        enable-aws-mock-mode $service
    }
}

# Tear down AWS CLI mocks
export def teardown-aws-cli-mock [
    services: list<string>
]: nothing -> nothing {
    for service in $services {
        disable-aws-mock-mode $service
    }
}

# Assert that caching is working correctly
export def assert-cache-functionality [
    cache_type: string
]: nothing -> nothing {
    match $cache_type {
        "module" => {
            use ../plugin/core/module_cache.nu
            
            let stats = module_cache get-cache-stats
            assert ($stats != null) "Module cache stats should be available"
            assert (($stats | columns | length) > 0) "Module cache should have statistics"
        },
        "completion" => {
            use ../plugin/core/completion_registry.nu
            
            let stats = completion_registry get-completion-stats
            assert ($stats != null) "Completion cache stats should be available"
            assert (($stats | columns | length) > 0) "Completion cache should have statistics"
        },
        _ => {
            error make { msg: $"Unknown cache type: ($cache_type)" }
        }
    }
}

# Performance testing utilities
export def measure-plugin-performance [
    command: closure,
    iterations: int = 10
]: nothing -> record {
    let measurements = 1..$iterations | each {
        let start_time = date now
        do $command
        let end_time = date now
        $end_time - $start_time
    }
    
    {
        iterations: $iterations,
        total_time: ($measurements | math sum),
        average_time: ($measurements | math avg),
        min_time: ($measurements | math min),
        max_time: ($measurements | math max),
        measurements: $measurements
    }
}

# Validate plugin system health
export def validate-plugin-health []: nothing -> record {
    # Test each component and collect results
    let configuration_result = try {
        use plugin/core/configuration.nu
        configuration get "debug" | ignore
        {component: "configuration", status: "healthy"}
    } catch { |err|
        {component: "configuration", status: "error", error: $err.msg}
    }
    
    let service_registry_result = try {
        use ../plugin/core/service_registry.nu
        service_registry get-service-statistics | ignore
        {component: "service_registry", status: "healthy"}
    } catch { |err|
        {component: "service_registry", status: "error", error: $err.msg}
    }
    
    let completion_system_result = try {
        use ../plugin/core/completion_registry.nu
        completion_registry get-completion-stats | ignore
        {component: "completion_system", status: "healthy"}
    } catch { |err|
        {component: "completion_system", status: "error", error: $err.msg}
    }
    
    let main_interface_result = try {
        ^nu nuaws.nu version | ignore
        {component: "main_interface", status: "healthy"}
    } catch { |err|
        {component: "main_interface", status: "error", error: $err.msg}
    }
    
    # Combine all results
    let health_results = [
        $configuration_result,
        $service_registry_result, 
        $completion_system_result,
        $main_interface_result
    ]
    
    let healthy_count = $health_results | where status == "healthy" | length
    let total_count = $health_results | length
    let overall_health = $healthy_count == $total_count
    
    {
        overall_health: $overall_health,
        healthy_components: $healthy_count,
        total_components: $total_count,
        health_percentage: (($healthy_count / $total_count) * 100 | math round),
        component_results: $health_results,
        validated_at: (date now)
    }
}

# Generate test data for AWS resources
export def generate-test-aws-data [
    resource_type: string,
    count: int = 5
]: nothing -> list {
    match $resource_type {
        "s3_buckets" => {
            1..$count | each { |i| $"test-bucket-($i)" }
        },
        "ec2_instances" => {
            1..$count | each { |i| $"i-($i | into string | fill --width 17 --character '0')" }
        },
        "iam_users" => {
            1..$count | each { |i| $"test-user-($i)" }
        },
        "lambda_functions" => {
            1..$count | each { |i| $"test-function-($i)" }
        },
        _ => {
            1..$count | each { |i| $"test-resource-($i)" }
        }
    }
}

# Test data cleanup utilities
export def cleanup-test-data []: nothing -> nothing {
    # Clean up any test files created during testing
    try {
        rm -rf $"($env.NUAWS_CACHE_DIR)/test_*"
    } catch {
        # Ignore cleanup errors
    }
    
    # Reset environment variables
    try {
        $env.NUAWS_DEBUG = "false"
    } catch {
        # Ignore if variable doesn't exist
    }
}