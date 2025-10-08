# Pipeline-Aware Test Helpers for AWS CLI Nushell
# Enhanced testing utilities following Nushell's pipeline philosophy

use aws/error_handling.nu

# ============================================================================
# PIPELINE-BASED ASSERTION SYSTEM
# ============================================================================

# Pipeline-based assertion that validates data structure
export def assert-schema [
    expected_schema: record
]: [any -> bool] {
    let actual = $in
    
    # Validate each field in the expected schema
    $expected_schema 
    | items { |key, expected_type|
        let actual_value = try { $actual | get $key } catch { null }
        
        if $actual_value == null {
            error make {
                msg: $"Missing required field: ($key)",
                label: { text: "Schema Validation Error" },
                help: $"Add the required field '($key)' to the data structure"
            }
        }
        
        let actual_type = $actual_value | describe
        
        # Handle flexible type checking
        let type_matches = match $expected_type {
            "string" => ($actual_type == "string"),
            "int" => ($actual_type in ["int", "float"]),
            "float" => ($actual_type in ["int", "float"]),
            "bool" => ($actual_type == "bool"),
            "list" => ($actual_type | str starts-with "list"),
            "record" => ($actual_type == "record"),
            "datetime" => ($actual_type in ["string", "date"]),
            "any" => true,
            _ => ($actual_type == $expected_type)
        }
        
        if not $type_matches {
            error make {
                msg: $"Schema mismatch for field '($key)': expected ($expected_type), got ($actual_type)",
                label: { text: "Type Validation Error" },
                help: $"Convert field '($key)' to type ($expected_type)"
            }
        }
    }
    | ignore
    
    true
}

# Assert that pipeline output contains expected values
export def assert-contains [
    expected_values: list<any>
]: [any -> bool] {
    let actual = $in
    
    $expected_values | each { |expected|
        if not ($actual | any { |item| $item == $expected }) {
            error make {
                msg: $"Expected value not found: ($expected)",
                label: { text: "Assertion Error" },
                help: "Check that the pipeline produces the expected values"
            }
        }
    } | ignore
    
    true
}

# Assert pipeline output length
export def assert-length [
    expected_length: int
]: [list<any> -> bool] {
    let actual = $in
    let actual_length = $actual | length
    
    if $actual_length != $expected_length {
        error make {
            msg: $"Length mismatch: expected ($expected_length), got ($actual_length)",
            label: { text: "Length Assertion Error" },
            help: "Check the pipeline logic that generates the list"
        }
    }
    
    true
}

# Assert that all items in pipeline satisfy a condition
export def assert-all [
    condition: closure
]: [list<any> -> bool] {
    let items = $in
    
    let failed_items = $items | enumerate | where { |item| 
        not (do $condition $item.item)
    }
    
    if ($failed_items | length) > 0 {
        let indices = $failed_items | get index | str join ", "
        error make {
            msg: $"Condition failed for items at indices: ($indices)",
            label: { text: "Conditional Assertion Error" },
            help: "Check the condition logic and input data"
        }
    }
    
    true
}

# Assert that pipeline output is empty
export def assert-empty []: [any -> bool] {
    let data = $in
    
    let is_empty = match ($data | describe) {
        "list" => ($data | length) == 0,
        "string" => ($data | str length) == 0,
        "record" => ($data | columns | length) == 0,
        "nothing" => true,
        _ => false
    }
    
    if not $is_empty {
        error make {
            msg: "Expected empty data but got non-empty result",
            label: { text: "Empty Assertion Error" },
            help: "Check pipeline logic that should produce empty results"
        }
    }
    
    true
}

# Assert that pipeline output is not empty
export def assert-not-empty []: [any -> bool] {
    let data = $in
    
    let is_empty = match ($data | describe) {
        "list" => ($data | length) == 0,
        "string" => ($data | str length) == 0,
        "record" => ($data | columns | length) == 0,
        "nothing" => true,
        _ => false
    }
    
    if $is_empty {
        error make {
            msg: "Expected non-empty data but got empty result",
            label: { text: "Non-Empty Assertion Error" },
            help: "Check pipeline logic that should produce data"
        }
    }
    
    true
}

# ============================================================================
# AWS-SPECIFIC TEST HELPERS
# ============================================================================

# Assert AWS ARN format
export def assert-aws-arn [
    resource_type?: string
]: [string -> bool] {
    let arn = $in
    
    if not ($arn | str starts-with "arn:aws:") {
        error make {
            msg: $"Invalid ARN format: ($arn)",
            label: { text: "ARN Validation Error" },
            help: "ARN must start with 'arn:aws:'"
        }
    }
    
    let arn_parts = $arn | split row ":"
    if ($arn_parts | length) < 6 {
        error make {
            msg: $"ARN has insufficient parts: ($arn)",
            label: { text: "ARN Structure Error" },
            help: "ARN must have format: arn:partition:service:region:account:resource"
        }
    }
    
    if ($resource_type != null) and not ($arn | str contains $resource_type) {
        error make {
            msg: $"ARN does not contain expected resource type '($resource_type)': ($arn)",
            label: { text: "ARN Resource Type Error" },
            help: $"Check that ARN contains resource type '($resource_type)'"
        }
    }
    
    true
}

# Assert Step Functions execution status
export def assert-execution-status [
    expected_status: string
]: [record -> bool] {
    let execution = $in
    
    let actual_status = $execution.status? | default ""
    
    if $actual_status != $expected_status {
        error make {
            msg: $"Execution status mismatch: expected ($expected_status), got ($actual_status)",
            label: { text: "Execution Status Error" },
            help: "Check execution state and expected status"
        }
    }
    
    true
}

# Assert AWS timestamp format
export def assert-aws-timestamp []: [string -> bool] {
    let timestamp = $in
    
    try {
        $timestamp | into datetime | ignore
    } catch {
        error make {
            msg: $"Invalid AWS timestamp format: ($timestamp)",
            label: { text: "Timestamp Format Error" },
            help: "AWS timestamps should be in ISO 8601 format"
        }
    }
    
    true
}

# ============================================================================
# MOCK DATA GENERATORS FOR TESTING
# ============================================================================

# Generate test execution data
export def generate-test-executions [
    count: int = 5,
    --status: string = "SUCCEEDED",
    --state-machine-arn: string = "arn:aws:states:us-east-1:123456789012:stateMachine:TestStateMachine"
]: [nothing -> list<record>] {
    0..($count - 1) | each { |i|
        {
            executionArn: $"arn:aws:states:us-east-1:123456789012:execution:TestStateMachine:test-exec-($i)",
            stateMachineArn: $state_machine_arn,
            name: $"test-exec-($i)",
            status: $status,
            startDate: (date now | format date '%Y-%m-%dT%H:%M:%S.%3fZ'),
            stopDate: (date now | format date '%Y-%m-%dT%H:%M:%S.%3fZ'),
            input: '{"test": true}',
            output: $'{"result": "test-($i)-complete"}'
        }
    }
}

# Generate test state machine data
export def generate-test-state-machines [
    count: int = 3,
    --type: string = "STANDARD"
]: [nothing -> list<record>] {
    0..($count - 1) | each { |i|
        {
            stateMachineArn: $"arn:aws:states:us-east-1:123456789012:stateMachine:TestStateMachine-($i)",
            name: $"TestStateMachine-($i)",
            type: $type,
            status: "ACTIVE",
            creationDate: (date now | format date '%Y-%m-%dT%H:%M:%S.%3fZ'),
            definition: '{"Comment": "Test state machine", "StartAt": "Pass", "States": {"Pass": {"Type": "Pass", "End": true}}}',
            roleArn: "arn:aws:iam::123456789012:role/StepFunctionsRole"
        }
    }
}

# Generate test activity data
export def generate-test-activities [
    count: int = 2
]: [nothing -> list<record>] {
    0..($count - 1) | each { |i|
        {
            activityArn: $"arn:aws:states:us-east-1:123456789012:activity:TestActivity-($i)",
            name: $"TestActivity-($i)",
            creationDate: (date now | format date '%Y-%m-%dT%H:%M:%S.%3fZ')
        }
    }
}

# ============================================================================
# TEST SCENARIO BUILDERS
# ============================================================================

# Create a test scenario with setup and teardown
export def test-scenario [
    name: string,
    setup: closure,
    test: closure,
    teardown: closure
]: [string, closure, closure, closure -> record] {
    print $"🧪 Running test scenario: ($name)"
    
    let start_time = date now
    
    try {
        # Setup phase
        print "  📋 Setup phase..."
        let setup_result = do $setup
        
        # Test phase
        print "  🔬 Test phase..."
        let test_result = $setup_result | do $test
        
        # Teardown phase
        print "  🧹 Teardown phase..."
        do $teardown $setup_result
        
        let end_time = date now
        let duration = $end_time - $start_time
        
        print $"  ✅ Test passed in ($duration | format duration ms)"
        
        {
            name: $name,
            status: "PASSED",
            duration: $duration,
            result: $test_result
        }
    } catch { |err|
        print $"  ❌ Test failed: ($err.msg)"
        
        # Attempt teardown even on failure
        try {
            print "  🧹 Cleanup after failure..."
            do $teardown {}
        } catch {
            print "  ⚠️  Cleanup failed"
        }
        
        {
            name: $name,
            status: "FAILED",
            error: $err.msg,
            duration: (date now) - $start_time
        }
    }
}

# Run multiple test scenarios
export def run-test-scenarios [
    scenarios: list<record>
]: [list<record> -> record] {
    print $"🚀 Running ($scenarios | length) test scenarios"
    
    let results = $scenarios | each { |scenario|
        test-scenario $scenario.name $scenario.setup $scenario.test $scenario.teardown
    }
    
    let passed = $results | where status == "PASSED" | length
    let failed = $results | where status == "FAILED" | length
    
    print $"\n📊 Test Results:"
    print $"  ✅ Passed: ($passed)"
    print $"  ❌ Failed: ($failed)"
    print $"  📈 Success Rate: (($passed * 100) / ($passed + $failed))%"
    
    {
        total: ($scenarios | length),
        passed: $passed,
        failed: $failed,
        success_rate: (($passed * 100) / ($passed + $failed)),
        results: $results
    }
}

# ============================================================================
# INTEGRATION TEST HELPERS
# ============================================================================

# Test a complete AWS pipeline operation
export def test-aws-pipeline [
    operation_name: string,
    pipeline: closure,
    expected_schema: record,
    test_data: any
]: [string, closure, record, any -> record] {
    print $"🔗 Testing AWS pipeline: ($operation_name)"
    
    try {
        let result = $test_data | do $pipeline
        $result | assert-schema $expected_schema | ignore
        
        {
            operation: $operation_name,
            status: "SUCCESS",
            result: $result
        }
    } catch { |err|
        {
            operation: $operation_name,
            status: "FAILED",
            error: $err.msg
        }
    }
}

# Performance test for pipeline operations
export def benchmark-pipeline [
    pipeline: closure,
    test_data: any,
    --iterations: int = 100
]: [closure, any -> record] {
    print $"⏱️  Benchmarking pipeline with ($iterations) iterations"
    
    let times = 0..($iterations - 1) | each { |i|
        let start = date now
        $test_data | do $pipeline | ignore
        let end = date now
        $end - $start
    }
    
    let total_time = $times | reduce { |it, acc| $acc + $it }
    let avg_time = $total_time / $iterations
    let min_time = $times | math min
    let max_time = $times | math max
    
    {
        iterations: $iterations,
        total_time: $total_time,
        average_time: $avg_time,
        min_time: $min_time,
        max_time: $max_time,
        throughput_per_second: (1000000000 / ($avg_time | into int))
    }
}

# ============================================================================
# TEST REPORTING
# ============================================================================

# Generate test report
export def generate-test-report [
    test_results: record,
    --format: string = "markdown"
]: [record -> string] {
    match $format {
        "markdown" => {
            let report = [
                "# AWS CLI Nushell Test Report",
                "",
                $"## Summary",
                $"- **Total Tests**: ($test_results.total)",
                $"- **Passed**: ($test_results.passed) ✅",
                $"- **Failed**: ($test_results.failed) ❌",
                $"- **Success Rate**: ($test_results.success_rate)%",
                "",
                "## Detailed Results",
                ""
            ] | str join "\n"
            
            let details = $test_results.results | each { |result|
                if $result.status == "PASSED" {
                    $"### ✅ ($result.name)\n- Duration: ($result.duration | format duration ms)\n"
                } else {
                    $"### ❌ ($result.name)\n- Error: ($result.error)\n- Duration: ($result.duration | format duration ms)\n"
                }
            } | str join "\n"
            
            $report + $details
        },
        "json" => ($test_results | to json),
        _ => ($test_results | table | to text)
    }
}