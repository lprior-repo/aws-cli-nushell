# Plugin Testing Module - Main entry point for NuAWS plugin testing framework
# Extends nutest framework with plugin-specific testing capabilities

export use plugin_test_utilities.nu *
export use mock_aws_environment.nu *
export use integration_test_framework.nu *
export use plugin_test_discovery.nu *

# Run plugin tests with enhanced discovery and execution
export def run-plugin-tests [
    --path: string,                           # Location of tests (defaults to current directory)
    --pattern: string,                        # Test file pattern (defaults to plugin patterns)
    --mock-mode = true,                       # Enable AWS CLI mocking
    --include-integration = true,             # Include integration tests
    --include-performance = false,            # Include performance tests
    --strategy: string = "parallel",          # Execution strategy (parallel/sequential)
    --display: string = "terminal",           # Display mode
    --verbose = false,                        # Verbose output
    --report-file: string                     # Save detailed report to file
]: nothing -> record {
    
    print "🧪 Starting NuAWS Plugin Test Suite"
    print "=" * 50
    
    let start_time = date now
    
    # Initialize plugin test environment
    print "🔧 Initializing plugin test environment..."
    let env_init = init-plugin-test-env
    
    if $mock_mode {
        print "🎭 Setting up mock AWS environment..."
        setup-mock-environment | ignore
    }
    
    # Discover plugin tests
    print $"🔍 Discovering plugin tests in ($path | default 'current directory')..."
    let test_suites = discover-plugin-tests --path=$path --pattern=$pattern --include-integration=$include_integration --include-performance=$include_performance
    
    if ($test_suites | length) == 0 {
        return {
            success: false,
            message: "No plugin tests discovered",
            test_suites: [],
            discovery_path: ($path | default $env.PWD)
        }
    }
    
    print $"📋 Discovered ($test_suites | length) test suites with ($test_suites | each { |s| $s.tests | length } | math sum) tests"
    
    # Create test execution plan
    let test_plan = create-plugin-test-plan $test_suites --strategy=$strategy
    print $"⏱️  Estimated execution time: ($test_plan.estimated_duration)"
    
    if $verbose {
        print "Test execution plan:"
        $test_plan.execution_phases | each { |phase|
            print $"  Phase ($phase.phase): ($phase.name) - ($phase.types | str join ', ')"
        } | ignore
    }
    
    # Execute tests according to plan
    print "🚀 Executing plugin tests..."
    let execution_results = execute-plugin-test-plan $test_plan $test_suites --display=$display --verbose=$verbose
    
    # Generate summary
    let end_time = date now
    let total_duration = $end_time - $start_time
    
    let summary = create-test-summary $execution_results $total_duration
    
    # Cleanup
    if $mock_mode {
        teardown-mock-environment
    }
    cleanup-test-data
    
    # Display results
    display-test-results $summary $display
    
    # Save report if requested
    if $report_file != null {
        let detailed_report = create-detailed-report $summary $test_plan $execution_results
        $detailed_report | to json | save $report_file
        print $"📄 Detailed report saved to: ($report_file)"
    }
    
    $summary
}

# Execute plugin test plan
def execute-plugin-test-plan [
    test_plan: record,
    test_suites: table,
    --display: string = "terminal",
    --verbose = false
]: nothing -> record {
    
    mut phase_results = []
    
    for phase in $test_plan.execution_phases {
        if $verbose {
            print $"📍 Executing Phase ($phase.phase): ($phase.name)"
        }
        
        # Get tests for this phase
        let phase_tests = $test_suites | each { |suite|
            let matching_tests = $suite.tests | where type in $phase.types
            if ($matching_tests | length) > 0 {
                $suite | update tests $matching_tests
            } else {
                null
            }
        } | where $it != null
        
        if ($phase_tests | length) > 0 {
            let phase_result = execute-test-phase $phase $phase_tests --verbose=$verbose
            $phase_results = ($phase_results | append $phase_result)
        }
    }
    
    {
        phase_results: $phase_results,
        executed_at: (date now)
    }
}

# Execute a single test phase
def execute-test-phase [
    phase: record,
    test_suites: table,
    --verbose = false
]: nothing -> record {
    
    let phase_start = date now
    
    mut suite_results = []
    
    if $phase.parallel {
        # Execute suites in parallel
        $suite_results = ($test_suites | par-each { |suite|
            execute-test-suite $suite --verbose=$verbose
        })
    } else {
        # Execute suites sequentially
        for suite in $test_suites {
            let suite_result = execute-test-suite $suite --verbose=$verbose
            $suite_results = ($suite_results | append $suite_result)
        }
    }
    
    let phase_end = date now
    let phase_duration = $phase_end - $phase_start
    
    let successful_suites = $suite_results | where overall_success == true | length
    let total_suites = $suite_results | length
    
    {
        phase: $phase.phase,
        name: $phase.name,
        duration: $phase_duration,
        successful_suites: $successful_suites,
        total_suites: $total_suites,
        success_rate: (if $total_suites > 0 { ($successful_suites / $total_suites) * 100 | math round } else { 0 }),
        suite_results: $suite_results
    }
}

# Execute a single test suite
def execute-test-suite [
    suite: record,
    --verbose = false
]: nothing -> record {
    
    if $verbose {
        print $"  🧪 Running suite: ($suite.name)"
    }
    
    let suite_start = date now
    
    mut test_results = []
    
    for test in $suite.tests {
        let test_result = execute-single-test $suite $test --verbose=$verbose
        $test_results = ($test_results | append $test_result)
    }
    
    let suite_end = date now
    let suite_duration = $suite_end - $suite_start
    
    let successful_tests = $test_results | where success == true | length
    let total_tests = $test_results | length
    
    {
        suite_name: $suite.name,
        suite_path: $suite.path,
        duration: $suite_duration,
        successful_tests: $successful_tests,
        total_tests: $total_tests,
        success_rate: (if $total_tests > 0 { ($successful_tests / $total_tests) * 100 | math round } else { 0 }),
        overall_success: ($successful_tests == $total_tests),
        test_results: $test_results,
        plugin_metadata: ($suite.plugin_metadata? | default {})
    }
}

# Execute a single test
def execute-single-test [
    suite: record,
    test: record, 
    --verbose = false
]: nothing -> record {
    
    if $verbose {
        print $"    ▶️  ($test.name)"
    }
    
    let test_start = date now
    
    # Setup test requirements
    let setup_result = setup-test-requirements $test.requirements
    
    let test_result = if $setup_result.success {
        try {
            # Execute the test by sourcing the file and calling the function
            let execution_command = $"source ($suite.path); ($test.name)"
            let result = ^$nu.current-exe --no-config-file --commands $execution_command | complete
            
            if $result.exit_code == 0 {
                {
                    success: true,
                    output: $result.stdout,
                    duration: ((date now) - $test_start)
                }
            } else {
                {
                    success: false,
                    error: $result.stderr,
                    output: $result.stdout,
                    duration: ((date now) - $test_start)
                }
            }
        } catch { |err|
            {
                success: false,
                error: $err.msg,
                duration: ((date now) - $test_start)
            }
        }
    } else {
        {
            success: false,
            error: $"Test setup failed: ($setup_result.error)",
            duration: ((date now) - $test_start)
        }
    }
    
    # Cleanup test requirements
    cleanup-test-requirements $test.requirements
    
    $test_result | insert test_name $test.name
              | insert test_type $test.type
              | insert test_tags ($test.tags? | default [])
}

# Setup test requirements
def setup-test-requirements [requirements: record]: nothing -> record {
    try {
        # Setup required AWS services in mock mode
        for service in ($requirements.aws_services? | default []) {
            if $requirements.requires_mock {
                enable-aws-mock-mode $service
            }
        }
        
        {
            success: true,
            message: "Test requirements setup completed"
        }
    } catch { |err|
        {
            success: false,
            error: $err.msg
        }
    }
}

# Cleanup test requirements  
def cleanup-test-requirements [requirements: record]: nothing -> nothing {
    try {
        # Cleanup AWS service mocks
        for service in ($requirements.aws_services? | default []) {
            if $requirements.requires_mock {
                disable-aws-mock-mode $service
            }
        }
    } catch {
        # Ignore cleanup errors
    }
}

# Create test summary
def create-test-summary [
    execution_results: record,
    total_duration: duration
]: nothing -> record {
    
    let all_suite_results = $execution_results.phase_results | each { |phase| $phase.suite_results } | flatten
    let all_test_results = $all_suite_results | each { |suite| $suite.test_results } | flatten
    
    let total_tests = $all_test_results | length
    let successful_tests = $all_test_results | where success == true | length
    let failed_tests = $all_test_results | where success == false | length
    
    let total_suites = $all_suite_results | length
    let successful_suites = $all_suite_results | where overall_success == true | length
    
    let success_rate = if $total_tests > 0 { 
        ($successful_tests / $total_tests) * 100 | math round 
    } else { 
        0 
    }
    
    # Group results by test type
    let results_by_type = $all_test_results | group-by test_type | transpose type results | each { |group|
        let type_successful = $group.results | where success == true | length
        let type_total = $group.results | length
        
        {
            type: $group.type,
            total: $type_total,
            successful: $type_successful,
            success_rate: (if $type_total > 0 { ($type_successful / $type_total) * 100 | math round } else { 0 })
        }
    }
    
    {
        overall_success: ($success_rate >= 80),
        success_rate: $success_rate,
        total_tests: $total_tests,
        successful_tests: $successful_tests,
        failed_tests: $failed_tests,
        total_suites: $total_suites,
        successful_suites: $successful_suites,
        total_duration: $total_duration,
        results_by_type: $results_by_type,
        execution_results: $execution_results,
        summary_created_at: (date now)
    }
}

# Display test results
def display-test-results [
    summary: record,
    display: string
]: nothing -> nothing {
    
    print "\n📊 Plugin Test Results Summary"
    print "=" * 50
    
    let status_icon = if $summary.overall_success { "✅" } else { "❌" }
    print $"($status_icon) Overall Success: ($summary.overall_success)"
    print $"📈 Success Rate: ($summary.success_rate)%"
    print $"🧪 Tests: ($summary.successful_tests)/($summary.total_tests) passed"
    print $"📦 Suites: ($summary.successful_suites)/($summary.total_suites) passed"
    print $"⏱️  Duration: ($summary.total_duration)"
    
    if ($summary.results_by_type | length) > 0 {
        print "\n📋 Results by Test Type:"
        $summary.results_by_type | each { |type_result|
            let type_icon = if $type_result.success_rate >= 80 { "✅" } else { "⚠️" }
            print $"  ($type_icon) ($type_result.type): ($type_result.successful)/($type_result.total) - ($type_result.success_rate)%"
        } | ignore
    }
    
    if $summary.failed_tests > 0 {
        print "\n❌ Failed Tests:"
        let failed_tests = $summary.execution_results.phase_results 
            | each { |phase| $phase.suite_results } 
            | flatten
            | each { |suite| $suite.test_results } 
            | flatten
            | where success == false
        
        $failed_tests | each { |test|
            print $"  • ($test.test_name) - ($test.error? | default 'Unknown error')"
        } | ignore
    }
    
    print $"\n🎉 Plugin testing completed at (date now | format date '%Y-%m-%d %H:%M:%S')"
}

# Create detailed report
def create-detailed-report [
    summary: record,
    test_plan: record,
    execution_results: record
]: nothing -> record {
    
    {
        report_type: "nuaws_plugin_test_report",
        generated_at: (date now),
        summary: $summary,
        test_plan: $test_plan,
        execution_results: $execution_results,
        environment: {
            plugin_dir: $env.NUAWS_PLUGIN_DIR,
            cache_dir: $env.NUAWS_CACHE_DIR,
            nushell_version: $nu.version,
            os: (sys | get host.name),
            architecture: (sys | get host.arch)
        }
    }
}

# Quick plugin health check
export def plugin-health-check []: nothing -> record {
    print "🩺 Running quick plugin health check..."
    
    init-plugin-test-env | ignore
    let health_result = validate-plugin-health
    
    let status_icon = if $health_result.overall_health { "✅" } else { "❌" }
    print $"($status_icon) Plugin Health: ($health_result.health_percentage)%"
    
    cleanup-test-data
    
    $health_result
}