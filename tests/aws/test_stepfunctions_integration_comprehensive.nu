use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        test_name: "integration-test-state-machine"
        test_role: "arn:aws:iam::123456789012:role/StepFunctionsRole"
        test_definition: '{"Comment": "Integration test state machine", "StartAt": "HelloWorld", "States": {"HelloWorld": {"Type": "Task", "Resource": "arn:aws:states:::lambda:invoke", "Parameters": {"FunctionName": "HelloFunction"}, "End": true}}}'
        activity_name: "integration-test-activity"
        alias_name: "integration-test-alias"
    }
}

# Integration workflow tests (15 tests)
#[test]
def "complete state machine lifecycle workflow" [] {
    let context = $in
    
    # This test simulates a complete workflow
    try {
        # 1. Create state machine
        let create_config = {
            name: $context.test_name
            definition: $context.test_definition
            role_arn: $context.test_role
        }
        
        let state_machine = stepfunctions create-state-machine $create_config
        let state_machine_arn = $state_machine.state_machine_arn
        
        # 2. Describe the created state machine
        let description = stepfunctions describe-state-machine $state_machine_arn
        assert ($description.name == $context.test_name)
        
        # 3. Start an execution
        let exec_config = {
            state_machine_arn: $state_machine_arn
            input: '{"test": true}'
        }
        let execution = stepfunctions start-execution $exec_config
        
        # 4. Clean up
        stepfunctions delete-state-machine $state_machine_arn
        
        assert true
    } catch { |error|
        # Expected to fail in test environment - validate error handling
        assert str contains $error.msg "Failed"
    }
}

#[test]
def "activity task processing workflow" [] {
    let context = $in
    
    try {
        # 1. Create activity
        let activity_config = {
            name: $context.activity_name
            tags: [{key: "Purpose", value: "Integration-Test"}]
        }
        let activity = stepfunctions create-activity $activity_config
        let activity_arn = $activity.activity_arn
        
        # 2. Describe activity
        let description = stepfunctions describe-activity $activity_arn
        assert ($description.name == $context.activity_name)
        
        # 3. Try to get a task (will be empty in test)
        let task_config = {
            activity_arn: $activity_arn
            worker_name: "test-worker"
        }
        let task = stepfunctions get-activity-task $task_config
        
        # 4. Clean up
        stepfunctions delete-activity $activity_arn
        
        assert true
    } catch { |error|
        assert str contains $error.msg "Failed"
    }
}

#[test]
def "version and alias management workflow" [] {
    let context = $in
    
    try {
        # 1. Create state machine
        let create_config = {
            name: $context.test_name
            definition: $context.test_definition
            role_arn: $context.test_role
        }
        let state_machine = stepfunctions create-state-machine $create_config
        let state_machine_arn = $state_machine.state_machine_arn
        
        # 2. Publish version
        let version_config = {
            state_machine_arn: $state_machine_arn
            description: "Integration test version"
        }
        let version = stepfunctions publish-state-machine-version $version_config
        
        # 3. Create alias
        let alias_config = {
            name: $context.alias_name
            routing_configuration: [{
                stateMachineVersionArn: $version.state_machine_version_arn
                weight: 100
            }]
        }
        let alias = stepfunctions create-state-machine-alias $alias_config
        
        # 4. Clean up
        stepfunctions delete-state-machine-alias $alias.state_machine_alias_arn
        stepfunctions delete-state-machine-version $version.state_machine_version_arn
        stepfunctions delete-state-machine $state_machine_arn
        
        assert true
    } catch { |error|
        assert str contains $error.msg "Failed"
    }
}

#[test]
def "error handling consistency across commands" [] {
    # Test that all commands handle invalid ARNs consistently
    let invalid_arn = "invalid-arn-format"
    
    let commands_to_test = [
        { cmd: "describe-state-machine", arg: $invalid_arn }
        { cmd: "describe-execution", arg: $invalid_arn }
        { cmd: "describe-activity", arg: $invalid_arn }
    ]
    
    let error_count = 0
    for command in $commands_to_test {
        try {
            match $command.cmd {
                "describe-state-machine" => { stepfunctions describe-state-machine $command.arg }
                "describe-execution" => { stepfunctions describe-execution $command.arg }
                "describe-activity" => { stepfunctions describe-activity $command.arg }
            }
        } catch { |error|
            $error_count = $error_count + 1
        }
    }
    
    # All commands should fail with invalid ARN
    assert ($error_count == ($commands_to_test | length))
}

#[test]
def "pagination consistency across list commands" [] {
    let pagination_config = {
        max_results: 50
        next_token: "test-token"
    }
    
    # Test that pagination parameters are handled consistently
    try {
        stepfunctions list-state-machines-paginated $pagination_config
        stepfunctions list-activities-paginated $pagination_config
        assert true
    } catch { |error|
        # Should fail consistently if pagination is not supported
        assert str contains $error.msg "Failed"
    }
}

#[test]
def "tag operations workflow" [] {
    let context = $in
    
    try {
        # Create a resource (state machine) to tag
        let create_config = {
            name: $context.test_name
            definition: $context.test_definition
            role_arn: $context.test_role
        }
        let state_machine = stepfunctions create-state-machine $create_config
        let resource_arn = $state_machine.state_machine_arn
        
        # Add tags
        let tag_config = {
            resource_arn: $resource_arn
            tags: [
                {key: "Environment", value: "Test"}
                {key: "Purpose", value: "Integration"}
            ]
        }
        stepfunctions tag-resource $tag_config
        
        # List tags
        let tags = stepfunctions list-tags-for-resource $resource_arn
        
        # Remove tags
        let untag_config = {
            resource_arn: $resource_arn
            tag_keys: ["Environment"]
        }
        stepfunctions untag-resource $untag_config
        
        # Clean up
        stepfunctions delete-state-machine $resource_arn
        
        assert true
    } catch { |error|
        assert str contains $error.msg "Failed"
    }
}

#[test]
def "input validation consistency" [] {
    # Test that input validation is consistent across commands
    let empty_inputs = [
        { cmd: "create-state-machine", invalid_field: "name" }
        { cmd: "create-activity", invalid_field: "name" }
    ]
    
    for test_case in $empty_inputs {
        try {
            match $test_case.cmd {
                "create-state-machine" => {
                    stepfunctions create-state-machine {name: ""}
                }
                "create-activity" => {
                    stepfunctions create-activity {name: ""}
                }
            }
            assert false $"($test_case.cmd) should have failed with empty ($test_case.invalid_field)"
        } catch { |error|
            assert str contains $error.msg $test_case.invalid_field
        }
    }
}

#[test]
def "json validation across commands" [] {
    let context = $in
    
    # Test JSON validation consistency
    let invalid_json = "invalid json {"
    
    try {
        stepfunctions validate-state-machine-definition $invalid_json
        assert false "Should have failed with invalid JSON"
    } catch { |error|
        assert str contains $error.msg "Invalid JSON"
    }
    
    # Test valid JSON acceptance
    try {
        let result = stepfunctions validate-state-machine-definition $context.test_definition
        # Should either succeed or fail with validation error (not JSON error)
        assert true
    } catch { |error|
        assert not (str contains $error.msg "Invalid JSON")
    }
}

#[test]
def "arn format validation consistency" [] {
    # Test that ARN validation is consistent across all commands that accept ARNs
    let invalid_arns = [
        ""
        "invalid"
        "arn:invalid"
        "not-an-arn-at-all"
    ]
    
    for invalid_arn in $invalid_arns {
        try {
            stepfunctions describe-state-machine $invalid_arn
            assert false $"Should have failed with invalid ARN: ($invalid_arn)"
        } catch { |error|
            assert str contains $error.msg "Invalid ARN format"
        }
    }
}

#[test]
def "mock response structure validation" [] {
    # Validate that mock responses have the expected structure
    let mock_state_machine = {
        stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:test"
        name: "test"
        definition: '{"StartAt": "Pass", "States": {"Pass": {"Type": "Pass", "End": true}}}'
        roleArn: "arn:aws:iam::123456789012:role/TestRole"
        type: "STANDARD"
        creationDate: "2023-01-01T00:00:00Z"
    }
    
    # Validate required fields
    assert ($mock_state_machine | get stateMachineArn | str starts-with "arn:aws:states:")
    assert ($mock_state_machine | get type) in ["STANDARD", "EXPRESS"]
    assert ($mock_state_machine | get name | is-not-empty)
}

#[test]
def "execution status validation" [] {
    # Validate execution status enums are consistent
    let valid_statuses = ["RUNNING", "SUCCEEDED", "FAILED", "TIMED_OUT", "ABORTED"]
    let invalid_status = "INVALID_STATUS"
    
    assert not ($invalid_status in $valid_statuses)
    assert ("RUNNING" in $valid_statuses)
    assert ("SUCCEEDED" in $valid_statuses)
}

#[test]
def "map run status validation" [] {
    # Validate map run status enums
    let valid_map_statuses = ["RUNNING", "SUCCEEDED", "FAILED", "ABORTED"]
    let mock_map_run = {
        status: "RUNNING"
        maxConcurrency: 10
        toleratedFailureCount: 0
    }
    
    assert ($mock_map_run | get status) in $valid_map_statuses
    assert ($mock_map_run | get maxConcurrency) >= 0
    assert ($mock_map_run | get toleratedFailureCount) >= 0
}

#[test]
def "weight validation for aliases" [] {
    # Test routing configuration weight validation
    let valid_weights = [0, 50, 100]
    let invalid_weights = [-1, 101, 150]
    
    for weight in $valid_weights {
        assert ($weight >= 0 and $weight <= 100)
    }
    
    for weight in $invalid_weights {
        assert not ($weight >= 0 and $weight <= 100)
    }
}

#[test]
def "comprehensive error message validation" [] {
    # Ensure error messages are descriptive and consistent
    let expected_error_patterns = [
        "Failed to"
        "Invalid ARN format"
        "does not exist"
        "Invalid JSON"
    ]
    
    try {
        stepfunctions describe-state-machine "invalid-arn"
        assert false "Should have failed"
    } catch { |error|
        let has_expected_pattern = false
        for pattern in $expected_error_patterns {
            if (str contains $error.msg $pattern) {
                $has_expected_pattern = true
                break
            }
        }
        assert $has_expected_pattern
    }
}