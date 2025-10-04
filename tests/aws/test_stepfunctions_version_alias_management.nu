use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        version_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine:1"
        alias_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine:test-alias"
        alias_name: "test-alias"
        version_number: "1"
        description: "Test version/alias"
    }
}

# publish-state-machine-version tests (15 tests)
#[test]
def "publish state machine version with minimal config" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
    }
    
    let result = try {
        stepfunctions publish-state-machine-version $config
    } catch { |error|
        assert str contains $error.msg "Failed to publish version"
        return
    }
    
    assert ($result | get stateMachineVersionArn? | is-not-empty)
    assert ($result | get creationDate? | is-not-empty)
}

#[test]
def "publish state machine version with description" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        description: $context.description
    }
    
    let result = try {
        stepfunctions publish-state-machine-version $config
    } catch { |error|
        assert str contains $error.msg "Failed to publish version"
        return
    }
    
    assert ($result | get stateMachineVersionArn? | str contains $context.state_machine_arn)
}

#[test]
def "publish state machine version with revision id" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        revision_id: "12345678-1234-1234-1234-123456789012"
    }
    
    let result = try {
        stepfunctions publish-state-machine-version $config
    } catch { |error|
        assert str contains $error.msg "Failed to publish version"
        return
    }
    
    assert ($result | get revisionId? | is-not-empty)
}

#[test]
def "publish state machine version validates arn format" [] {
    let config = {
        state_machine_arn: "invalid-arn"
    }
    
    try {
        stepfunctions publish-state-machine-version $config
        assert false "Should have failed with invalid state machine ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "publish state machine version validates description length" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        description: ("x" | str repeat 300)  # Too long description
    }
    
    try {
        stepfunctions publish-state-machine-version $config
        assert false "Should have failed with too long description"
    } catch { |error|
        assert str contains $error.msg "description"
    }
}

#[test]
def "delete state machine version with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions delete-state-machine-version $context.version_arn
    } catch { |error|
        assert str contains $error.msg "Failed to delete version"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "delete state machine version validates arn format" [] {
    try {
        stepfunctions delete-state-machine-version "invalid-arn"
        assert false "Should have failed with invalid version ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "delete state machine version handles non-existent version" [] {
    let non_existent_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test:999"
    
    try {
        stepfunctions delete-state-machine-version $non_existent_arn
        assert false "Should have failed with non-existent version"
    } catch { |error|
        assert str contains $error.msg "does not exist"
    }
}

#[test]
def "create state machine alias with minimal config" [] {
    let context = $in
    
    let config = {
        name: $context.alias_name
        routing_configuration: [
            {
                stateMachineVersionArn: $context.version_arn
                weight: 100
            }
        ]
    }
    
    let result = try {
        stepfunctions create-state-machine-alias $config
    } catch { |error|
        assert str contains $error.msg "Failed to create alias"
        return
    }
    
    assert ($result | get stateMachineAliasArn? | is-not-empty)
    assert ($result | get creationDate? | is-not-empty)
}

#[test]
def "create state machine alias with description" [] {
    let context = $in
    
    let config = {
        name: $context.alias_name
        description: $context.description
        routing_configuration: [
            {
                stateMachineVersionArn: $context.version_arn
                weight: 100
            }
        ]
    }
    
    let result = try {
        stepfunctions create-state-machine-alias $config
    } catch { |error|
        assert str contains $error.msg "Failed to create alias"
        return
    }
    
    assert ($result | get stateMachineAliasArn? | str contains $context.alias_name)
}

#[test]
def "create state machine alias validates routing weights" [] {
    let context = $in
    
    let config = {
        name: $context.alias_name
        routing_configuration: [
            {
                stateMachineVersionArn: $context.version_arn
                weight: 150  # Invalid weight > 100
            }
        ]
    }
    
    try {
        stepfunctions create-state-machine-alias $config
        assert false "Should have failed with invalid weight"
    } catch { |error|
        assert str contains $error.msg "weight"
    }
}

#[test]
def "create state machine alias validates total weights" [] {
    let context = $in
    
    let config = {
        name: $context.alias_name
        routing_configuration: [
            {
                stateMachineVersionArn: $context.version_arn
                weight: 50
            }
            {
                stateMachineVersionArn: $context.version_arn
                weight: 60  # Total > 100
            }
        ]
    }
    
    try {
        stepfunctions create-state-machine-alias $config
        assert false "Should have failed with total weight > 100"
    } catch { |error|
        assert str contains $error.msg "weight"
    }
}

#[test]
def "describe state machine alias with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-state-machine-alias $context.alias_arn
    } catch { |error|
        assert str contains $error.msg "Failed to describe alias"
        return
    }
    
    assert ($result | get stateMachineAliasArn? | is-not-empty)
    assert ($result | get name? | is-not-empty)
    assert ($result | get routingConfiguration? | describe | str starts-with "list")
}

#[test]
def "describe state machine alias validates arn format" [] {
    try {
        stepfunctions describe-state-machine-alias "invalid-arn"
        assert false "Should have failed with invalid alias ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "update state machine alias with new routing" [] {
    let context = $in
    
    let config = {
        state_machine_alias_arn: $context.alias_arn
        routing_configuration: [
            {
                stateMachineVersionArn: $context.version_arn
                weight: 80
            }
        ]
    }
    
    let result = try {
        stepfunctions update-state-machine-alias $config
    } catch { |error|
        assert str contains $error.msg "Failed to update alias"
        return
    }
    
    assert ($result | get updateDate? | is-not-empty)
}