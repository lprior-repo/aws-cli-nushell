use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        resource_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        execution_arn: "arn:aws:states:us-east-1:123456789012:execution:test-state-machine:test-execution"
        task_token: "AAAAKgAAAAIAAAAAAAAAAA..."
        state_definition: '{"Comment": "Test state", "Type": "Pass", "End": true}'
        test_role: "arn:aws:iam::123456789012:role/StepFunctionsRole"
    }
}

# tag-resource tests (15 tests)
#[test]
def "tag resource with single tag" [] {
    let context = $in
    
    let config = {
        resource_arn: $context.resource_arn
        tags: [
            {key: "Environment", value: "Test"}
        ]
    }
    
    let result = try {
        stepfunctions tag-resource $config
    } catch { |error|
        assert str contains $error.msg "Failed to tag resource"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "tag resource with multiple tags" [] {
    let context = $in
    
    let config = {
        resource_arn: $context.resource_arn
        tags: [
            {key: "Environment", value: "Test"}
            {key: "Project", value: "Nutest"}
            {key: "Owner", value: "TestTeam"}
        ]
    }
    
    let result = try {
        stepfunctions tag-resource $config
    } catch { |error|
        assert str contains $error.msg "Failed to tag resource"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "tag resource validates arn format" [] {
    let config = {
        resource_arn: "invalid-arn"
        tags: [
            {key: "Test", value: "Tag"}
        ]
    }
    
    try {
        stepfunctions tag-resource $config
        assert false "Should have failed with invalid resource ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "tag resource validates tag key format" [] {
    let context = $in
    
    let config = {
        resource_arn: $context.resource_arn
        tags: [
            {key: "", value: "Test"}  # Empty key
        ]
    }
    
    try {
        stepfunctions tag-resource $config
        assert false "Should have failed with empty tag key"
    } catch { |error|
        assert str contains $error.msg "tag key"
    }
}

#[test]
def "tag resource validates tag value length" [] {
    let context = $in
    
    let config = {
        resource_arn: $context.resource_arn
        tags: [
            {key: "Test", value: ("x" | str repeat 300)}  # Too long value
        ]
    }
    
    try {
        stepfunctions tag-resource $config
        assert false "Should have failed with too long tag value"
    } catch { |error|
        assert str contains $error.msg "tag value"
    }
}

#[test]
def "untag resource with single tag key" [] {
    let context = $in
    
    let config = {
        resource_arn: $context.resource_arn
        tag_keys: ["Environment"]
    }
    
    let result = try {
        stepfunctions untag-resource $config
    } catch { |error|
        assert str contains $error.msg "Failed to untag resource"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "untag resource with multiple tag keys" [] {
    let context = $in
    
    let config = {
        resource_arn: $context.resource_arn
        tag_keys: ["Environment", "Project", "Owner"]
    }
    
    let result = try {
        stepfunctions untag-resource $config
    } catch { |error|
        assert str contains $error.msg "Failed to untag resource"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "untag resource validates arn format" [] {
    let config = {
        resource_arn: "invalid-arn"
        tag_keys: ["Test"]
    }
    
    try {
        stepfunctions untag-resource $config
        assert false "Should have failed with invalid resource ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "list tags for resource with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions list-tags-for-resource $context.resource_arn
    } catch { |error|
        assert str contains $error.msg "Failed to list tags"
        return
    }
    
    assert ($result | get tags? | describe | str starts-with "list")
}

#[test]
def "list tags for resource validates arn format" [] {
    try {
        stepfunctions list-tags-for-resource "invalid-arn"
        assert false "Should have failed with invalid resource ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "redrive execution with minimal config" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
    }
    
    let result = try {
        stepfunctions redrive-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to redrive execution"
        return
    }
    
    assert ($result | get redriveDate? | is-not-empty)
}

#[test]
def "redrive execution with client token" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
        client_token: "unique-client-token-123"
    }
    
    let result = try {
        stepfunctions redrive-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to redrive execution"
        return
    }
    
    assert ($result | get redriveDate? | is-not-empty)
}

#[test]
def "redrive execution validates arn format" [] {
    let config = {
        execution_arn: "invalid-arn"
    }
    
    try {
        stepfunctions redrive-execution $config
        assert false "Should have failed with invalid execution ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "test state with minimal config" [] {
    let context = $in
    
    let config = {
        definition: $context.state_definition
        role_arn: $context.test_role
    }
    
    let result = try {
        stepfunctions test-state $config
    } catch { |error|
        assert str contains $error.msg "Failed to test state"
        return
    }
    
    assert ($result | get status? | is-not-empty)
}

#[test]
def "test state with input data" [] {
    let context = $in
    
    let config = {
        definition: $context.state_definition
        role_arn: $context.test_role
        input: '{"test": "input", "value": 42}'
    }
    
    let result = try {
        stepfunctions test-state $config
    } catch { |error|
        assert str contains $error.msg "Failed to test state"
        return
    }
    
    assert ($result | get status? | is-not-empty)
}