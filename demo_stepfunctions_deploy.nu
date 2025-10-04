#!/usr/bin/env nu

# Demo script to deploy and destroy a Step Function with type safety
use aws/stepfunctions.nu

def main [] {
    print "🚀 AWS Step Functions Demo with Type Safety"
    print "=========================================="
    
    # Enable mock mode for demonstration
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    
    print "🧪 Mock mode enabled - no actual AWS resources will be created"
    
    print "\n📝 Step 1: Create a state machine with validation"
    
    # Test input validation first
    let invalid_arn = "invalid-arn"
    print $"Testing validation with invalid ARN: ($invalid_arn)"
    
    try {
        stepfunctions create-state-machine "test-sm" '{"invalid": "json"}' $invalid_arn
    } catch { |error|
        print $"✅ Validation caught error: ($error.msg)"
    }
    
    print "\n✨ Step 2: Create state machine with valid inputs"
    
    # Valid inputs with type safety
    let state_machine_name = "demo-state-machine"
    let definition = {
        Comment: "A Hello World example"
        StartAt: "HelloWorld"
        States: {
            HelloWorld: {
                Type: "Pass"
                Result: "Hello World!"
                End: true
            }
        }
    } | to json
    
    let role_arn = "arn:aws:iam::123456789012:role/MyRole"
    
    print $"Creating state machine: ($state_machine_name)"
    print $"Definition: ($definition)"
    print $"Role ARN: ($role_arn)"
    
    let create_result = stepfunctions create-state-machine $state_machine_name $definition $role_arn
    print $"✅ Created state machine: ($create_result.state_machine_arn)"
    
    print "\n🏃 Step 3: Start an execution"
    
    let execution_input = '{"message": "Hello from Step Functions!"}'
    let execution_name = "demo-execution"
    
    let execution_result = stepfunctions start-execution $create_result.state_machine_arn --input $execution_input --name $execution_name
    print $"✅ Started execution: ($execution_result.execution_arn)"
    
    print "\n📋 Step 4: Describe the execution"
    
    let describe_result = stepfunctions describe-execution $execution_result.execution_arn
    print $"📊 Execution status: ($describe_result.status)"
    print $"⏰ Start date: ($describe_result.start_date)"
    
    print "\n🔍 Step 5: List state machines"
    
    let list_result = stepfunctions list-state-machines
    print $"📝 Found ($list_result.state_machines | length) state machines"
    
    print "\n🧹 Step 6: Clean up - Stop execution and delete state machine"
    
    # Stop execution if it's still running
    try {
        stepfunctions stop-execution $execution_result.execution_arn
        print "🛑 Stopped execution"
    } catch { |error|
        print $"ℹ️  Execution already completed: ($error.msg)"
    }
    
    # Delete the state machine
    stepfunctions delete-state-machine $create_result.state_machine_arn
    print "🗑️  Deleted state machine"
    
    print "\n✅ Demo completed successfully!"
    print "🔒 All operations used type-safe validation and error handling"
    print "🧪 Mock mode was enabled - no actual AWS resources were created"
}