# AWS CLI Nushell Improved Usage Examples
# Demonstrates the enhanced pipeline-first approach and quick wins

use ../aws/stepfunctions_improved.nu
use ../aws/completions.nu
use ../aws/error_handling.nu
use ../aws/schemas.nu
use ../test_helpers.nu

# ============================================================================
# PIPELINE-FIRST COMMAND USAGE EXAMPLES
# ============================================================================

# Example 1: Pipeline-aware start-execution
export def demo-pipeline-start-execution []: nothing -> nothing {
    print "🚀 Demo: Pipeline-aware start-execution"
    
    # Set mock mode for demo
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    # Single execution
    print "\n📝 Single execution:"
    "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine" 
    | stepfunctions_improved start-execution --input '{"test": true}'
    | print
    
    # Batch execution
    print "\n📝 Batch execution:"
    [
        "arn:aws:states:us-east-1:123456789012:stateMachine:Machine1",
        "arn:aws:states:us-east-1:123456789012:stateMachine:Machine2",
        "arn:aws:states:us-east-1:123456789012:stateMachine:Machine3"
    ] 
    | stepfunctions_improved start-execution --input '{"batch": true}'
    | print
}

# Example 2: Chained pipeline operations
export def demo-chained-operations []: nothing -> nothing {
    print "🔗 Demo: Chained pipeline operations"
    
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    # Complex pipeline: list → filter → transform → validate
    stepfunctions_improved list-state-machines --format raw
    | get stateMachines
    | where type == "STANDARD"
    | get stateMachineArn
    | stepfunctions_improved list-executions --status "SUCCEEDED"
    | stepfunctions_improved executions-to-table
    | print
}

# Example 3: Error handling with recovery
export def demo-error-handling []: nothing -> nothing {
    print "⚠️  Demo: Enhanced error handling"
    
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    # Test error handling pipeline
    try {
        # This would normally fail with invalid ARN
        "invalid-arn" | stepfunctions_improved start-execution
    } catch { |err|
        print $"Caught error: ($err.msg)"
        print $"Error help: ($err.help)"
        print $"AWS context: ($err.aws_context)"
    }
    
    # Resilient batch operation
    [
        "arn:aws:states:us-east-1:123456789012:stateMachine:Valid",
        "invalid-arn",
        "arn:aws:states:us-east-1:123456789012:stateMachine:Another"
    ]
    | stepfunctions_improved resilient-list-executions --continue-on-error
    | print
}

# ============================================================================
# DYNAMIC COMPLETIONS DEMO
# ============================================================================

export def demo-completions []: nothing -> nothing {
    print "🎯 Demo: Dynamic completions"
    
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    print "\n📋 Available state machine ARNs:"
    completions complete-state-machine-arns | print
    
    print "\n📋 Available execution ARNs:"
    completions complete-execution-arns | print
    
    print "\n📋 Available execution statuses:"
    completions complete-execution-statuses | print
    
    print "\n📋 Available AWS regions:"
    completions complete-aws-regions | print
}

# ============================================================================
# SCHEMA VALIDATION DEMO
# ============================================================================

export def demo-schema-validation []: nothing -> nothing {
    print "📏 Demo: Schema validation"
    
    # Test data with correct schema
    let valid_execution = {
        execution_arn: "arn:aws:states:us-east-1:123456789012:execution:test:exec1",
        state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test",
        name: "exec1",
        status: "SUCCEEDED",
        start_date: "2024-01-01T10:00:00Z",
        stop_date: "2024-01-01T10:05:00Z"
    }
    
    print "\n✅ Valid execution schema:"
    $valid_execution 
    | schemas validate-against-schema (schemas stepfunctions-execution-schema)
    | print
    
    # Test data transformation
    print "\n🔄 AWS CLI output transformation:"
    let aws_cli_output = {
        executionArn: "arn:aws:states:us-east-1:123456789012:execution:test:exec1",
        stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:test",
        name: "exec1",
        status: "SUCCEEDED",
        startDate: "2024-01-01T10:00:00Z",
        stopDate: "2024-01-01T10:05:00Z"
    }
    
    $aws_cli_output 
    | schemas transform-aws-output "stepfunctions-execution"
    | print
}

# ============================================================================
# PIPELINE-AWARE TESTING DEMO
# ============================================================================

export def demo-pipeline-testing []: nothing -> nothing {
    print "🧪 Demo: Pipeline-aware testing"
    
    # Generate test data
    print "\n📊 Generated test executions:"
    let test_executions = test_helpers generate-test-executions 5 --status "SUCCEEDED"
    $test_executions | print
    
    # Test schema validation
    print "\n🔍 Schema validation test:"
    $test_executions 
    | each { |exec| 
        $exec | test_helpers assert-schema (schemas stepfunctions-execution-schema)
    }
    | print
    
    # Test pipeline assertions
    print "\n✅ Pipeline assertions:"
    $test_executions
    | test_helpers assert-length 5
    | ignore
    
    $test_executions
    | test_helpers assert-all { |exec| $exec.status == "SUCCEEDED" }
    | ignore
    
    print "All tests passed! ✅"
}

# ============================================================================
# PERFORMANCE DEMO
# ============================================================================

export def demo-performance []: nothing -> nothing {
    print "⚡ Demo: Performance improvements"
    
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    # Benchmark pipeline operations
    print "\n📈 Benchmarking pipeline performance:"
    let test_data = ["arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"]
    
    let benchmark_result = test_helpers benchmark-pipeline {
        stepfunctions_improved start-execution --input "{}"
    } $test_data --iterations 50
    
    print $"Average time: ($benchmark_result.average_time | format duration ms)"
    print $"Throughput: ($benchmark_result.throughput_per_second) ops/sec"
}

# ============================================================================
# INTEGRATION TEST SCENARIO
# ============================================================================

export def demo-integration-test []: nothing -> nothing {
    print "🔬 Demo: Integration test scenario"
    
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    let test_scenarios = [
        {
            name: "Start and monitor execution",
            setup: { 
                { state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine" }
            },
            test: { |setup|
                $setup.state_machine_arn 
                | stepfunctions_improved start-execution --input '{"test": true}'
                | get execution_arn
                | stepfunctions_improved describe-execution
            },
            teardown: { |setup| 
                print $"Cleanup for ($setup.state_machine_arn)"
            }
        },
        {
            name: "List and filter executions",
            setup: { 
                { state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine" }
            },
            test: { |setup|
                $setup.state_machine_arn
                | stepfunctions_improved list-executions --status "SUCCEEDED"
                | stepfunctions_improved filter-executions-by-status "SUCCEEDED"
            },
            teardown: { |setup| 
                print $"Cleanup completed"
            }
        }
    ]
    
    let results = test_helpers run-test-scenarios $test_scenarios
    print ($results | test_helpers generate-test-report --format "markdown")
}

# ============================================================================
# COMPLETE DEMO RUNNER
# ============================================================================

export def run-all-demos []: nothing -> nothing {
    print "🎉 Running all AWS CLI Nushell improvement demos\n"
    
    demo-pipeline-start-execution
    print "\n" + ("=" * 50) + "\n"
    
    demo-chained-operations  
    print "\n" + ("=" * 50) + "\n"
    
    demo-error-handling
    print "\n" + ("=" * 50) + "\n"
    
    demo-completions
    print "\n" + ("=" * 50) + "\n"
    
    demo-schema-validation
    print "\n" + ("=" * 50) + "\n"
    
    demo-pipeline-testing
    print "\n" + ("=" * 50) + "\n"
    
    demo-performance
    print "\n" + ("=" * 50) + "\n"
    
    demo-integration-test
    print "\n" + ("=" * 50) + "\n"
    
    print "🏁 All demos completed successfully!"
}

# ============================================================================
# MIGRATION GUIDE EXAMPLE
# ============================================================================

export def show-migration-comparison []: nothing -> nothing {
    print "🔄 Migration from old to new patterns\n"
    
    print "❌ OLD PATTERN (Parameter-based):"
    print "  start-execution \"arn:aws:states:...\" --input '{\"test\": true}'"
    print "  describe-execution \"arn:aws:states:...execution:...\""
    print ""
    
    print "✅ NEW PATTERN (Pipeline-based):"
    print "  \"arn:aws:states:...\" | start-execution --input '{\"test\": true}'"
    print "  \"arn:aws:states:...execution:...\" | describe-execution"
    print ""
    
    print "🚀 ADVANCED PIPELINE USAGE:"
    print "  list-state-machines | get stateMachines.stateMachineArn | start-execution --input '{}'"
    print "  [\"arn1\", \"arn2\", \"arn3\"] | start-execution | each { describe-execution }"
    print "  executions | filter-executions-by-status \"RUNNING\" | executions-to-table"
    print ""
    
    print "💡 BENEFITS:"
    print "  - Natural Nushell pipeline composition"
    print "  - Batch operations support"
    print "  - Consistent data transformations"
    print "  - Better error handling and recovery"
    print "  - Dynamic completions"
    print "  - Schema validation"
}

# Usage examples:
# nu examples/improved_usage.nu run-all-demos
# nu examples/improved_usage.nu show-migration-comparison