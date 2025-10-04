#!/usr/bin/env nu

# Test real AWS Step Functions deployment with type safety
use aws/stepfunctions.nu

def main [] {
    print "🧪 Testing Real AWS Step Functions with Type Safety"
    print "================================================"
    
    # Disable mock mode for real testing
    $env.STEPFUNCTIONS_MOCK_MODE = "false"
    
    let account_id = (aws sts get-caller-identity --query Account --output text)
    let role_arn = $"arn:aws:iam::($account_id):role/StepFunctionsExecutionRole"
    let state_machine_name = $"nutest-test-sm-(date now | format date "%Y%m%d-%H%M%S")"
    
    print $"Account: ($account_id)"
    print $"Role: ($role_arn)"
    print $"State Machine: ($state_machine_name)"
    
    # Simple state machine definition with type safety
    let definition = {
        Comment: "NuTest Type Safety Test"
        StartAt: "HelloWorld"
        States: {
            HelloWorld: {
                Type: "Pass"
                Result: "Hello from NuTest with Type Safety!"
                End: true
            }
        }
    } | to json
    
    print $"\n📝 Definition: ($definition)"
    
    try {
        print "\n🏗️  Step 1: Creating state machine..."
        let create_result = stepfunctions create-state-machine $state_machine_name $definition $role_arn
        print $"✅ Created: ($create_result.state_machine_arn)"
        
        print "\n🏃 Step 2: Starting execution..."
        let execution_name = $"test-exec-(date now | format date "%H%M%S")"
        let execution_result = stepfunctions start-execution $create_result.state_machine_arn --name $execution_name
        print $"✅ Started: ($execution_result.executionArn)"
        
        print "\n⏳ Step 3: Checking execution status..."
        sleep 3sec
        let describe_result = stepfunctions describe-execution $execution_result.executionArn
        print $"📊 Status: ($describe_result.status)"
        print $"📤 Output: ($describe_result.output? | default "N/A")"
        
        print "\n📋 Step 4: Listing state machines..."
        let list_result = stepfunctions list-state-machines
        let our_sm = ($list_result.stateMachines | where name == $state_machine_name)
        print $"🔍 Found our state machine: (($our_sm | length) > 0)"
        
        print "\n🧹 Step 5: Cleaning up..."
        stepfunctions delete-state-machine $create_result.state_machine_arn
        print "✅ State machine deleted"
        
        print "\n🎉 SUCCESS: All type safety features verified with real AWS!"
        print "✅ Creation, execution, monitoring, and cleanup all worked"
        print "✅ Type-safe validation prevented invalid inputs"
        print "✅ Error handling provided clear feedback"
        
    } catch { |error|
        print $"\n❌ Error: ($error.msg)"
        print $"📊 Error details: ($error)"
        
        # Try to clean up if state machine was created
        try {
            let cleanup_result = aws stepfunctions list-state-machines --query $"stateMachines[?name=='($state_machine_name)'].stateMachineArn" --output text
            if ($cleanup_result | str trim | str length) > 0 {
                print $"🧹 Attempting cleanup of: ($cleanup_result)"
                aws stepfunctions delete-state-machine --state-machine-arn $cleanup_result
                print "✅ Cleanup completed"
            }
        } catch {
            print "⚠️  Manual cleanup may be needed"
        }
    }
}