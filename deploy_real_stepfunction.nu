#!/usr/bin/env nu

# Real AWS Step Functions deployment with type safety
# Requirements: AWS CLI configured with valid credentials
use aws/stepfunctions.nu

def main [--dry-run] {
    print "🚀 AWS Step Functions Real Deployment"
    print "====================================="
    
    if $dry_run {
        $env.STEPFUNCTIONS_MOCK_MODE = "true"
        print "🧪 DRY RUN MODE: Mock responses only, no real AWS resources created"
    } else {
        $env.STEPFUNCTIONS_MOCK_MODE = "false"
        print "⚠️  LIVE MODE: Real AWS resources will be created"
        print "   Make sure AWS CLI is configured with valid credentials"
    }
    
    # Step Function configuration with type safety
    let state_machine_name = "nutest-demo-state-machine"
    let role_arn = "arn:aws:iam::294022175841:role/StepFunctionsExecutionRole"  # Update with detected account
    
    # Type-safe state machine definition
    let definition = {
        Comment: "A simple Hello World Step Function"
        StartAt: "HelloWorld"
        States: {
            HelloWorld: {
                Type: "Pass"
                Result: {
                    message: "Hello from NuTest Step Functions!"
                    timestamp: "2025-10-04"
                    framework: "nutest"
                }
                End: true
            }
        }
    } | to json
    
    print $"\n📋 Configuration:"
    print $"   State Machine: ($state_machine_name)"
    print $"   Role ARN: ($role_arn)"
    print $"   Definition: ($definition | from json | to yaml)"
    
    try {
        print "\n🏗️  Step 1: Creating state machine..."
        
        # Type-safe creation with validation
        let create_result = stepfunctions create-state-machine $state_machine_name $definition $role_arn --type "STANDARD"
        print $"✅ Created: ($create_result.stateMachineArn)"
        
        print "\n🏃 Step 2: Starting execution..."
        
        # Type-safe execution with input validation
        let execution_input = {
            user: "demo-user"
            action: "test-deployment"
            timestamp: (date now | format date "%Y-%m-%d %H:%M:%S")
        } | to json
        
        let execution_name = $"demo-execution-(date now | format date "%Y%m%d-%H%M%S")"
        let execution_result = stepfunctions start-execution $create_result.stateMachineArn --input $execution_input --name $execution_name
        print $"✅ Started: ($execution_result.executionArn)"
        
        print "\n⏳ Step 3: Waiting for execution to complete..."
        
        # Poll execution status with type safety
        mut attempts = 0
        mut status = "RUNNING"
        
        while $status == "RUNNING" and $attempts < 30 {
            sleep 2sec
            let describe_result = stepfunctions describe-execution $execution_result.executionArn
            $status = $describe_result.status
            $attempts = $attempts + 1
            print $"   Status: ($status) (attempt ($attempts)/30)"
        }
        
        print "\n📊 Step 4: Final execution details..."
        let final_result = stepfunctions describe-execution $execution_result.executionArn
        print $"   📊 Status: ($final_result.status)"
        print $"   ⏰ Start: ($final_result.startDate)"
        print $"   🏁 End: ($final_result.stopDate? | default "N/A")"
        
        if $final_result.output? != null {
            print $"   📤 Output: ($final_result.output)"
        }
        
        print "\n🗑️  Step 5: Cleanup..."
        
        if not $dry_run {
            print "⚠️  Would you like to delete the state machine? (y/N)"
            let response = input
            if ($response | str downcase) == "y" {
                stepfunctions delete-state-machine $create_result.stateMachineArn
                print "✅ State machine deleted"
            } else {
                print "ℹ️  State machine preserved"
                print $"   To delete later: aws stepfunctions delete-state-machine --state-machine-arn ($create_result.stateMachineArn)"
            }
        } else {
            print "🧪 Mock mode: No real resources to clean up"
        }
        
        print "\n🎉 Deployment completed successfully!"
        
    } catch { |error|
        print $"\n❌ Error occurred: ($error.msg)"
        print "🔧 Troubleshooting tips:"
        print "   1. Ensure AWS CLI is configured: aws configure"
        print "   2. Verify IAM permissions for Step Functions"
        print "   3. Update the role ARN in the script"
        print "   4. Run with --dry-run flag to test without AWS"
        
        if not $dry_run {
            print $"\n🧪 To test locally: nu deploy_real_stepfunction.nu --dry-run"
        }
    }
}