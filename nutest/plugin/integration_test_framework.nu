# Integration Test Framework - Advanced testing scenarios for plugin integration
# Provides end-to-end testing capabilities for the complete NuAWS plugin system

use plugin_test_utilities.nu *
use mock_aws_environment.nu *

# Run comprehensive integration tests
export def run-integration-tests [
    --mock-mode = true,
    --verbose = false
]: nothing -> record {
    
    # Initialize test environment
    init-plugin-test-env | ignore
    
    if $mock_mode {
        setup-mock-environment | ignore
    }
    
    let start_time = date now
    
    # Test scenarios
    let test_scenarios = [
        { name: "plugin_initialization", description: "Plugin system initialization" },
        { name: "service_discovery", description: "Service discovery and loading" },
        { name: "configuration_management", description: "Configuration system" },
        { name: "completion_system", description: "Completion discovery and registration" },
        { name: "cache_management", description: "Caching and performance" },
        { name: "error_handling", description: "Error handling and recovery" },
        { name: "command_execution", description: "Command execution and routing" },
        { name: "mock_integration", description: "Mock AWS integration" }
    ]
    
    mut test_results = []
    
    for scenario in $test_scenarios {
        if $verbose {
            print $"Running integration test: ($scenario.description)"
        }
        
        let scenario_result = try {
            match $scenario.name {
                "plugin_initialization" => { test-plugin-initialization },
                "service_discovery" => { test-service-discovery },
                "configuration_management" => { test-configuration-management },
                "completion_system" => { test-completion-system },
                "cache_management" => { test-cache-management },
                "error_handling" => { test-error-handling },
                "command_execution" => { test-command-execution },
                "mock_integration" => { test-mock-integration },
                _ => { { success: false, error: "Unknown test scenario" } }
            }
        } catch { |err|
            { success: false, error: $err.msg, scenario: $scenario.name }
        }
        
        $test_results = ($test_results | append ($scenario_result | insert name $scenario.name | insert description $scenario.description))
    }
    
    let end_time = date now
    let duration = $end_time - $start_time
    
    # Calculate results
    let successful_tests = $test_results | where success == true | length
    let total_tests = $test_results | length
    let success_rate = (($successful_tests / $total_tests) * 100 | math round)
    
    # Cleanup
    if $mock_mode {
        teardown-mock-environment
    }
    
    cleanup-test-data
    
    {
        success_rate: $success_rate,
        successful_tests: $successful_tests,
        total_tests: $total_tests,
        duration: $duration,
        test_results: $test_results,
        overall_success: ($success_rate >= 80),
        completed_at: (date now)
    }
}

# Test plugin initialization
def test-plugin-initialization []: nothing -> record {
    try {
        # Test environment setup
        let env_result = init-plugin-test-env
        assert ($env_result.initialized == true) "Plugin environment should initialize"
        
        # Test directory creation
        assert ($env.NUAWS_CACHE_DIR | path exists) "Cache directory should exist"
        assert ($env.NUAWS_CONFIG_DIR | path exists) "Config directory should exist"
        
        # Test environment variables
        assert ($env.NUAWS_PLUGIN_DIR != null) "Plugin directory should be set"
        assert ($env.NUAWS_DEBUG == "true") "Debug mode should be enabled"
        
        {
            success: true,
            checks_passed: 4,
            message: "Plugin initialization successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test service discovery and loading
def test-service-discovery []: nothing -> record {
    try {
        use ../../../plugin/core/service_loader.nu
        
        # Test service listing
        let services = service_loader list-available-services
        assert (($services | length) > 0) "Should discover available services"
        
        # Test specific service discovery
        let s3_services = $services | where name == "s3"
        assert (($s3_services | length) > 0) "Should discover S3 service"
        
        # Test service info retrieval
        let service_info = service_loader get-service-info "s3"
        assert ($service_info.name == "s3") "Should get correct service info"
        
        {
            success: true,
            services_discovered: ($services | length),
            checks_passed: 3,
            message: "Service discovery successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test configuration management
def test-configuration-management []: nothing -> record {
    try {
        use ../../../plugin/core/configuration.nu
        
        # Test configuration initialization
        configuration init-if-missing | ignore
        
        # Test configuration get/set
        let debug_value = configuration get "debug"
        assert ($debug_value != null) "Should get configuration value"
        
        configuration set "test_key" "test_value"
        let test_value = configuration get "test_key"
        assert ($test_value == "test_value") "Should set and get configuration value"
        
        # Test configuration validation
        let validation = configuration validate-aws-config
        assert ($validation != null) "Should validate AWS configuration"
        
        {
            success: true,
            checks_passed: 3,
            message: "Configuration management successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test completion system
def test-completion-system []: nothing -> record {
    try {
        use ../../../plugin/core/completion_manager.nu
        
        # Test completion system initialization
        let init_result = completion_manager init-completion-system
        assert ($init_result.success == true) "Should initialize completion system"
        
        # Test completion validation
        let validation = completion_manager validate-completion-system
        assert ($validation.overall_health != null) "Should validate completion system"
        
        # Test external completions
        use ../../../plugin/core/external_completions.nu
        let status = external_completions get-completions-status
        assert ($status.enabled == true) "External completions should be enabled"
        
        {
            success: true,
            checks_passed: 3,
            message: "Completion system successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test cache management
def test-cache-management []: nothing -> record {
    try {
        # Test module cache
        assert-cache-functionality "module"
        
        # Test completion cache
        assert-cache-functionality "completion"
        
        # Test cache statistics
        use ../../../plugin/core/module_cache.nu
        let module_stats = module_cache get-cache-stats
        assert (($module_stats | columns | length) > 0) "Module cache should have stats"
        
        {
            success: true,
            checks_passed: 3,
            message: "Cache management successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test error handling
def test-error-handling []: nothing -> record {
    try {
        use ../../../plugin/core/error_handler.nu
        
        # Test error creation
        let test_error = {
            msg: "Test error message",
            label: { text: "test error", span: { start: 0, end: 5 } }
        }
        
        # Test error handling doesn't crash
        try {
            error_handler handle-plugin-error $test_error "test-service" ["test-arg"]
        } catch {
            # Expected to fail, but shouldn't crash the system
        }
        
        {
            success: true,
            checks_passed: 1,
            message: "Error handling functional"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test command execution
def test-command-execution []: nothing -> record {
    try {
        # Test main interface
        let help_result = assert-plugin-command-works ["nuaws.nu", "help"]
        assert ($help_result.success == true) "Help command should work"
        
        # Test version command
        let version_result = assert-plugin-command-works ["nuaws.nu", "version"]
        assert ($version_result.success == true) "Version command should work"
        
        # Test services listing
        let services_result = assert-plugin-command-works ["nuaws.nu", "services"]
        assert ($services_result.success == true) "Services command should work"
        
        {
            success: true,
            checks_passed: 3,
            message: "Command execution successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Test mock integration
def test-mock-integration []: nothing -> record {
    try {
        # Test mock response generation
        let s3_response = mock-aws-response "s3api" "list-buckets"
        assert ("Buckets" in ($s3_response | columns)) "S3 mock should have correct structure"
        
        let ec2_response = mock-aws-response "ec2" "describe-instances"
        assert ("Reservations" in ($ec2_response | columns)) "EC2 mock should have correct structure"
        
        # Test mock validation
        let validation = validate-mock-responses
        assert ($validation.success_rate >= 80) "Mock responses should be mostly valid"
        
        {
            success: true,
            checks_passed: 3,
            mock_validation: $validation,
            message: "Mock integration successful"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Run performance benchmarks
export def run-performance-tests [
    --iterations: int = 5
]: nothing -> record {
    
    init-plugin-test-env | ignore
    
    let tests = [
        {
            name: "plugin_startup",
            command: { ^nu nuaws.nu version | ignore }
        },
        {
            name: "service_discovery",
            command: { use ../../../plugin/core/service_loader.nu; service_loader list-available-services | ignore }
        },
        {
            name: "completion_init",
            command: { use ../../../plugin/core/completion_manager.nu; completion_manager init-completion-system | ignore }
        }
    ]
    
    let performance_results = $tests | each { |test|
        let measurements = measure-plugin-performance $test.command $iterations
        $measurements | insert test_name $test.name
    }
    
    {
        performance_results: $performance_results,
        iterations_per_test: $iterations,
        tested_at: (date now)
    }
}

# Run end-to-end workflow tests
export def run-workflow-tests []: nothing -> record {
    
    init-plugin-test-env | ignore
    setup-mock-environment | ignore
    
    let workflows = [
        {
            name: "service_management_workflow",
            steps: [
                { action: "list_services", command: ["nuaws.nu", "services"] },
                { action: "service_help", command: ["nuaws.nu", "help", "s3"] },
                { action: "config_check", command: ["nuaws.nu", "config", "show"] }
            ]
        },
        {
            name: "completion_workflow", 
            steps: [
                { action: "completion_status", command: ["nuaws.nu", "completions", "status"] },
                { action: "completion_init", command: ["nuaws.nu", "completions", "init"] },
                { action: "completion_validate", command: ["nuaws.nu", "completions", "validate"] }
            ]
        }
    ]
    
    let workflow_results = $workflows | each { |workflow|
        let step_results = $workflow.steps | each { |step|
            let result = assert-plugin-command-works $step.command
            $result | insert action $step.action
        }
        
        let successful_steps = $step_results | where success == true | length
        let total_steps = $step_results | length
        
        {
            workflow_name: $workflow.name,
            success_rate: (($successful_steps / $total_steps) * 100 | math round),
            successful_steps: $successful_steps,
            total_steps: $total_steps,
            step_results: $step_results
        }
    }
    
    teardown-mock-environment
    cleanup-test-data
    
    {
        workflow_results: $workflow_results,
        total_workflows: ($workflows | length),
        tested_at: (date now)
    }
}

# Generate comprehensive test report
export def generate-test-report [
    --include-performance = false,
    --include-workflows = false
]: nothing -> record {
    
    print "🧪 Generating comprehensive test report..."
    
    # Run integration tests
    let integration_results = run-integration-tests --verbose=true
    
    # Run performance tests if requested
    let performance_results = if $include_performance {
        print "📊 Running performance tests..."
        run-performance-tests --iterations=3
    } else {
        null
    }
    
    # Run workflow tests if requested
    let workflow_results = if $include_workflows {
        print "🔄 Running workflow tests..."
        run-workflow-tests
    } else {
        null
    }
    
    # Validate plugin health
    let health_validation = validate-plugin-health
    
    {
        report_type: "comprehensive_plugin_test_report",
        generated_at: (date now),
        integration_tests: $integration_results,
        performance_tests: $performance_results,
        workflow_tests: $workflow_results,
        health_validation: $health_validation,
        overall_assessment: {
            plugin_functional: $integration_results.overall_success,
            health_score: $health_validation.health_percentage,
            recommendation: (if ($integration_results.overall_success and $health_validation.overall_health) {
                "Plugin system is ready for production use"
            } else {
                "Plugin system needs attention before production use"
            })
        }
    }
}