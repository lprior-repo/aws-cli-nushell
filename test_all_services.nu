#!/usr/bin/env nu

# Comprehensive AWS Services Test Suite
# Tests all AWS modules using nutest with table output

use nutest/nutest/mod.nu

def main [
    --ci: bool = false           # CI mode - fail on any test failure
    --report: string = ""        # Generate test report (junit, json)
    --verbose (-v): bool = false # Verbose output
] {
    print "🚀 AWS CLI Nushell Framework - Complete Test Suite"
    print "=" * 60
    
    # Set all mock modes for safe testing
    $env.DYNAMODB_MOCK_MODE = "true"
    $env.LAMBDA_MOCK_MODE = "true"
    $env.ECS_MOCK_MODE = "true"
    $env.IAM_MOCK_MODE = "true"
    $env.S3API_MOCK_MODE = "true"
    $env.EVENTS_MOCK_MODE = "true"
    $env.RDS_MOCK_MODE = "true"
    $env.EC2_MOCK_MODE = "true"
    $env.APIGATEWAY_MOCK_MODE = "true"
    $env.CLOUDFORMATION_MOCK_MODE = "true"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    print "✅ Mock mode activated for all AWS services"
    print "🧪 Running comprehensive test suite..."
    print ""
    
    # Configure nutest options
    let nutest_options = [
        "--display", "table",
        "--returns", "table"
    ]
    
    let additional_options = if $ci { 
        $nutest_options | append ["--fail"] 
    } else { 
        $nutest_options 
    }
    
    let final_options = if $report != "" {
        match $report {
            "junit" => ($additional_options | append ["--report", "{type: junit, path: \"test-results.xml\"}"]),
            "json" => ($additional_options | append ["--report", "{type: json, path: \"test-results.json\"}"]),
            _ => $additional_options
        }
    } else {
        $additional_options
    }
    
    # Run all tests in the tests/aws directory
    try {
        print "🔄 Executing nutest with options:"
        print $"   ($final_options | str join ' ')"
        print ""
        
        let test_results = (nutest run-tests "tests/aws/" ...$final_options)
        
        print "\n📊 TEST RESULTS SUMMARY"
        print "=" * 60
        
        # Display results in table format
        $test_results | table -i
        
        # Generate summary statistics
        let total_tests = ($test_results | length)
        let passed_tests = ($test_results | where result == "PASS" | length)
        let failed_tests = ($test_results | where result == "FAIL" | length)
        let skipped_tests = ($test_results | where result == "SKIP" | length)
        
        print "\n📈 Summary Statistics:"
        [
            {metric: "Total Tests", value: $total_tests, percentage: "100%"},
            {metric: "✅ Passed", value: $passed_tests, percentage: $"(($passed_tests / $total_tests) * 100 | math round)%"},
            {metric: "❌ Failed", value: $failed_tests, percentage: $"(($failed_tests / $total_tests) * 100 | math round)%"},
            {metric: "⏭️ Skipped", value: $skipped_tests, percentage: $"(($skipped_tests / $total_tests) * 100 | math round)%"}
        ] | table -i
        
        # Show service breakdown
        print "\n🔍 Service Breakdown:"
        $test_results 
        | group-by suite 
        | transpose service tests
        | each { |row|
            let service_tests = $row.tests
            let service_passed = ($service_tests | where result == "PASS" | length)
            let service_total = ($service_tests | length)
            {
                service: ($row.service | str replace "test_" "" | str upcase),
                total: $service_total,
                passed: $service_passed,
                success_rate: $"(($service_passed / $service_total) * 100 | math round)%"
            }
        } | table -i
        
        if $verbose and $failed_tests > 0 {
            print "\n🔍 Failed Test Details:"
            $test_results | where result == "FAIL" | each { |test|
                print $"❌ ($test.suite) - ($test.test): ($test.output)"
            }
        }
        
        # Final status
        if $failed_tests == 0 {
            print "\n🎉 ALL TESTS PASSED! AWS modules are working correctly."
        } else {
            print $"\n⚠️  ($failed_tests) tests failed. Review results above."
        }
        
        if $report != "" {
            print $"\n📄 Test report generated: test-results.($report)"
        }
        
        return $test_results
        
    } catch { |error|
        print $"❌ Error running tests: ($error.msg)"
        
        if $ci {
            exit 1
        }
        
        return []
    }
}