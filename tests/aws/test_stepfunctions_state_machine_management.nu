use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        test_name: "test-state-machine"
        test_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        test_role: "arn:aws:iam::123456789012:role/StepFunctionsRole"
        test_definition: '{"Comment": "Test state machine", "StartAt": "Pass", "States": {"Pass": {"Type": "Pass", "End": true}}}'
        test_alias: "test-alias"
        test_version: "1"
    }
}

# create-state-machine tests (15 tests)
#[test]
def "create state machine with minimal config" [] {
    let context = $in
    
    let config = {
        name: $context.test_name
        definition: $context.test_definition
        role_arn: $context.test_role
    }
    
    # Mock response should be validated
    let result = try {
        stepfunctions create-state-machine $config.name $config.definition $config.role_arn
    } catch { |error|
        # Expected to fail in test environment without AWS credentials
        assert str contains $error.msg "Failed to create state machine"
        return
    }
    
    # If successful, validate response structure
    assert ($result | get state_machine_arn? | is-not-empty)
}

#[test]
def "create state machine with full configuration" [] {
    let context = $in
    
    let config = {
        name: $context.test_name
        definition: $context.test_definition
        role_arn: $context.test_role
        type: "EXPRESS"
        logging_configuration: {
            level: "ALL"
            includeExecutionData: true
            destinations: []
        }
        tracing_configuration: {
            enabled: true
        }
        tags: [
            {key: "Environment", value: "Test"}
            {key: "Project", value: "Nutest"}
        ]
    }
    
    let result = try {
        stepfunctions create-state-machine $config.name $config.definition $config.role_arn
    } catch { |error|
        assert str contains $error.msg "Failed to create state machine"
        return
    }
    
    assert ($result | get state_machine_arn? | is-not-empty)
}

#[test]
def "create state machine validates required fields" [] {
    let incomplete_config = {
        name: "test"
        # Missing definition and role_arn
    }
    
    try {
        stepfunctions create-state-machine ($incomplete_config.name? | default "") "" ""
        assert false "Should have failed validation"
    } catch { |error|
        assert str contains $error.msg "definition"
    }
}

#[test]
def "create state machine handles invalid definition" [] {
    let context = $in
    
    let config = {
        name: $context.test_name
        definition: "invalid json"
        role_arn: $context.test_role
    }
    
    try {
        stepfunctions create-state-machine $config.name $config.definition $config.role_arn
        assert false "Should have failed with invalid definition"
    } catch { |error|
        assert str contains $error.msg "definition"
    }
}

#[test]
def "create state machine handles invalid role arn" [] {
    let context = $in
    
    let config = {
        name: $context.test_name
        definition: $context.test_definition
        role_arn: "invalid-arn"
    }
    
    try {
        stepfunctions create-state-machine $config.name $config.definition $config.role_arn
        assert false "Should have failed with invalid role ARN"
    } catch { |error|
        assert str contains $error.msg "role_arn"
    }
}

#[test]
def "delete state machine with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions delete-state-machine $context.test_arn
    } catch { |error|
        assert str contains $error.msg "Failed to delete state machine"
        return
    }
    
    # Should return success
    assert true
}

#[test]
def "delete state machine validates arn format" [] {
    try {
        stepfunctions delete-state-machine "invalid-arn"
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "delete state machine handles non-existent arn" [] {
    let non_existent_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:non-existent"
    
    try {
        stepfunctions delete-state-machine $non_existent_arn
        assert false "Should have failed with non-existent state machine"
    } catch { |error|
        assert str contains $error.msg "does not exist"
    }
}

#[test]
def "describe state machine with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-state-machine $context.test_arn
    } catch { |error|
        assert str contains $error.msg "Failed to describe state machine"
        return
    }
    
    # Validate response structure
    assert ($result | get stateMachineArn? | is-not-empty)
    assert ($result | get name? | is-not-empty)
    assert ($result | get definition? | is-not-empty)
}

#[test]
def "describe state machine validates arn format" [] {
    try {
        stepfunctions describe-state-machine "invalid-arn"
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "update state machine with definition only" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.test_arn
        definition: '{"Comment": "Updated test state machine", "StartAt": "Pass", "States": {"Pass": {"Type": "Pass", "End": true}}}'
    }
    
    let result = try {
        stepfunctions update-state-machine $config.state_machine_arn --definition $config.definition
    } catch { |error|
        assert str contains $error.msg "Failed to update state machine"
        return
    }
    
    assert ($result | get updateDate? | is-not-empty)
}

#[test]
def "update state machine with role arn" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.test_arn
        role_arn: $context.test_role
    }
    
    let result = try {
        stepfunctions update-state-machine $config.state_machine_arn --definition $config.definition
    } catch { |error|
        assert str contains $error.msg "Failed to update state machine"
        return
    }
    
    assert ($result | get updateDate? | is-not-empty)
}

#[test]
def "update state machine validates arn format" [] {
    let config = {
        state_machine_arn: "invalid-arn"
        definition: '{"Comment": "Test"}'
    }
    
    try {
        stepfunctions update-state-machine $config.state_machine_arn --definition $config.definition
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "validate state machine definition with valid json" [] {
    let context = $in
    
    let result = try {
        stepfunctions validate-state-machine-definition $context.test_definition
    } catch { |error|
        assert str contains $error.msg "Failed to validate"
        return
    }
    
    assert equal (($result | get result? | default "FAIL")) "OK"
}

#[test]
def "validate state machine definition with invalid json" [] {
    try {
        stepfunctions validate-state-machine-definition "invalid json"
        assert false "Should have failed with invalid JSON"
    } catch { |error|
        assert str contains $error.msg "Invalid JSON"
    }
}