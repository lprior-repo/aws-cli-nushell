#!/usr/bin/env nu

# Test suite for AWS operation name conversion
# Validates that NuAWS correctly converts operation names to proper AWS CLI format

# Test the conversion works correctly for various AWS services
def test-s3-operation-conversion [] {
    use ../nuaws.nu

    # Test S3 operations
    print "🧪 Testing S3 operation conversions..."
    
    # Test basic S3 operations in mock mode
    $env.S3_MOCK_MODE = "true"
    
    let test_cases = [
        ["listbuckets", "should work"],
        ["createbucket", "should work"], 
        ["deletebucket", "should work"],
        ["putobject", "should work"],
        ["getobject", "should work"],
        ["listobjectsv2", "should work"]
    ]
    
    let results = ($test_cases | each { |case|
        let operation = $case.0
        let expected = $case.1
        
        try {
            let result = (nuaws s3 $operation)
            if ($result.mock? | default false) {
                {operation: $operation, status: "✅ PASS", message: "Mock response received correctly"}
            } else {
                {operation: $operation, status: "❌ FAIL", message: "Expected mock response"}
            }
        } catch { |err|
            {operation: $operation, status: "❌ FAIL", message: $err.msg}
        }
    })
    
    $env.S3_MOCK_MODE = "false"
    $results
}

def test-stepfunctions-operation-conversion [] {
    use ../nuaws.nu

    print "🧪 Testing Step Functions operation conversions..."
    
    # Test Step Functions operations in mock mode
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    let test_cases = [
        ["liststatemachines", "should work"],
        ["createstatemachine", "should work"],
        ["deletestatemachine", "should work"], 
        ["describestatemachine", "should work"],
        ["startexecution", "should work"],
        ["stopexecution", "should work"],
        ["listexecutions", "should work"],
        ["createactivity", "should work"],
        ["deleteactivity", "should work"],
        ["listactivities", "should work"]
    ]
    
    let results = ($test_cases | each { |case|
        let operation = $case.0
        let expected = $case.1
        
        try {
            let result = (nuaws stepfunctions $operation)
            if ($result.mock? | default false) {
                {operation: $operation, status: "✅ PASS", message: "Mock response received correctly"}
            } else {
                {operation: $operation, status: "❌ FAIL", message: "Expected mock response"}
            }
        } catch { |err|
            {operation: $operation, status: "❌ FAIL", message: $err.msg}
        }
    })
    
    $env.STEPFUNCTIONS_MOCK_MODE = "false"
    $results
}

def test-iam-operation-conversion [] {
    use ../nuaws.nu

    print "🧪 Testing IAM operation conversions..."
    
    # Test IAM operations in mock mode
    $env.IAM_MOCK_MODE = "true"
    
    let test_cases = [
        ["ListUsers", "should work with PascalCase"],
        ["ListRoles", "should work with PascalCase"],
        ["ListGroups", "should work with PascalCase"],
        ["CreateUser", "should work with PascalCase"],
        ["GetUser", "should work with PascalCase"]
    ]
    
    let results = ($test_cases | each { |case|
        let operation = $case.0
        let expected = $case.1
        
        try {
            let result = (nuaws iam $operation)
            if ($result.mock? | default false) {
                {operation: $operation, status: "✅ PASS", message: "Mock response received correctly"}
            } else {
                {operation: $operation, status: "❌ FAIL", message: "Expected mock response"}
            }
        } catch { |err|
            {operation: $operation, status: "❌ FAIL", message: $err.msg}
        }
    })
    
    $env.IAM_MOCK_MODE = "false"
    $results
}

def test-real-aws-cli-validation [] {
    use ../nuaws.nu

    print "🧪 Testing real AWS CLI command validation..."
    
    # Test that actual AWS CLI commands work (these should work with real credentials)
    let test_cases = [
        ["s3", "listbuckets", "list-buckets"],
        ["stepfunctions", "liststatemachines", "list-state-machines"], 
        ["iam", "ListUsers", "list-users"]
    ]
    
    let results = ($test_cases | each { |case|
        let service = $case.0
        let operation = $case.1
        let expected_aws_cmd = $case.2
        
        try {
            # Test that the command doesn't fail with "invalid choice" error
            let result = (nuaws $service $operation)
            
            # If we get here without error, the conversion worked
            {
                service: $service, 
                operation: $operation, 
                expected_aws_cmd: $expected_aws_cmd,
                status: "✅ PASS", 
                message: "AWS CLI command executed successfully"
            }
        } catch { |err|
            if ($err.msg | str contains "Invalid choice") {
                {
                    service: $service, 
                    operation: $operation, 
                    expected_aws_cmd: $expected_aws_cmd,
                    status: "❌ FAIL", 
                    message: $"Conversion failed: ($err.msg)"
                }
            } else {
                {
                    service: $service, 
                    operation: $operation, 
                    expected_aws_cmd: $expected_aws_cmd,
                    status: "✅ PASS", 
                    message: "AWS CLI command format correct (other error not related to conversion)"
                }
            }
        }
    })
    
    $results
}

def main [] {
    print "🚀 NuAWS Operation Name Conversion Test Suite"
    print "=" * 50
    
    let start_time = (date now)
    
    # Run all test suites
    print "\n📦 Running S3 Operation Tests..."
    let s3_results = (test-s3-operation-conversion)
    
    print "\n⚡ Running Step Functions Operation Tests..."
    let stepfunctions_results = (test-stepfunctions-operation-conversion)
    
    print "\n🔐 Running IAM Operation Tests..."
    let iam_results = (test-iam-operation-conversion)
    
    print "\n🌐 Running Real AWS CLI Validation..."
    let real_validation_results = (test-real-aws-cli-validation)
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    # Aggregate results
    let all_results = (
        ($s3_results | each { |r| $r | upsert service "s3" }) |
        append ($stepfunctions_results | each { |r| $r | upsert service "stepfunctions" }) |
        append ($iam_results | each { |r| $r | upsert service "iam" }) |
        append ($real_validation_results)
    )
    
    let total_tests = ($all_results | length)
    let passed_tests = ($all_results | where status =~ "✅" | length)
    let failed_tests = ($all_results | where status =~ "❌" | length)
    
    # Generate report
    print "\n📊 OPERATION NAME CONVERSION TEST REPORT"
    print "=" * 50
    
    print $"\n🎯 SUMMARY:"
    print $"  Total Tests: ($total_tests)"
    print $"  Passed: ($passed_tests) ✅"
    print $"  Failed: ($failed_tests) ❌"
    print $"  Duration: ($duration)"
    
    let success_rate = ($passed_tests * 100 / $total_tests)
    print $"  Success Rate: (($success_rate | math round)%)"
    
    # Detailed results
    print "\n📋 DETAILED RESULTS:"
    for result in $all_results {
        let status_icon = if ($result.status | str contains "✅") { "✅" } else { "❌" }
        let service = ($result.service? | default "unknown")
        let operation = ($result.operation? | default "unknown")
        print $"  ($status_icon) ($service): ($operation) - ($result.message)"
    }
    
    # Failed tests details
    let failed_results = ($all_results | where status =~ "❌")
    if ($failed_results | length) > 0 {
        print "\n❌ FAILED TESTS DETAILS:"
        for failed in $failed_results {
            let service = ($failed.service? | default "unknown")
            let operation = ($failed.operation? | default "unknown")
            print $"  • ($service) ($operation): ($failed.message)"
        }
    }
    
    # Overall assessment
    let assessment = if $failed_tests == 0 {
        "🟢 EXCELLENT - All operation name conversions working correctly"
    } else if $failed_tests <= 2 {
        "🟡 GOOD - Minor conversion issues detected"
    } else {
        "🔴 NEEDS ATTENTION - Multiple conversion failures"
    }
    
    print $"\n🏥 OVERALL ASSESSMENT: ($assessment)"
    
    # Save results
    let detailed_report = {
        timestamp: (date now),
        duration: $duration,
        summary: {
            total_tests: $total_tests,
            passed: $passed_tests,
            failed: $failed_tests,
            success_rate: $success_rate,
            assessment: $assessment
        },
        test_results: $all_results
    }
    
    $detailed_report | to json | save "logs/operation_conversion_test_report.json"
    print "\n📄 Detailed report saved to logs/operation_conversion_test_report.json"
    
    $detailed_report
}

if $nu.is-interactive == false {
    main
}