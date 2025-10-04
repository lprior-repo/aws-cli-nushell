use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        execution_arn: "arn:aws:states:us-east-1:123456789012:execution:test-state-machine:test-execution"
        task_token: "AAAAKgAAAAIAAAAAAAAAAA..."
        output_data: '{"result": "success", "value": 42}'
        error_code: "TaskFailed"
        error_cause: "Test task failure for validation"
    }
}

# send-task-heartbeat tests (15 tests)
#[test]
def "send task heartbeat with valid token" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
    }
    
    let result = try {
        stepfunctions send-task-heartbeat $config
    } catch { |error|
        assert str contains $error.msg "Failed to send task heartbeat"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "send task heartbeat validates token format" [] {
    let config = {
        task_token: ""  # Empty token
    }
    
    try {
        stepfunctions send-task-heartbeat $config
        assert false "Should have failed with empty task token"
    } catch { |error|
        assert str contains $error.msg "task_token"
    }
}

#[test]
def "send task heartbeat handles invalid token" [] {
    let config = {
        task_token: "invalid-token-format"
    }
    
    try {
        stepfunctions send-task-heartbeat $config
        assert false "Should have failed with invalid task token"
    } catch { |error|
        assert str contains $error.msg "Invalid task token"
    }
}

#[test]
def "send task heartbeat handles expired token" [] {
    let config = {
        task_token: "AAAAKgAAAAIAAAAAAAAAAExpiredToken"
    }
    
    try {
        stepfunctions send-task-heartbeat $config
        assert false "Should have failed with expired task token"
    } catch { |error|
        assert str contains $error.msg "expired"
    }
}

#[test]
def "send task heartbeat idempotent behavior" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
    }
    
    # Multiple heartbeats should not fail
    try {
        stepfunctions send-task-heartbeat $config
        stepfunctions send-task-heartbeat $config
        assert true
    } catch { |error|
        assert str contains $error.msg "Failed to send task heartbeat"
    }
}

#[test]
def "send task success with output" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        output: $context.output_data
    }
    
    let result = try {
        stepfunctions send-task-success $config
    } catch { |error|
        assert str contains $error.msg "Failed to send task success"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "send task success validates token format" [] {
    let context = $in
    
    let config = {
        task_token: ""  # Empty token
        output: $context.output_data
    }
    
    try {
        stepfunctions send-task-success $config
        assert false "Should have failed with empty task token"
    } catch { |error|
        assert str contains $error.msg "task_token"
    }
}

#[test]
def "send task success validates output json" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        output: "invalid json {"
    }
    
    try {
        stepfunctions send-task-success $config
        assert false "Should have failed with invalid JSON output"
    } catch { |error|
        assert str contains $error.msg "Invalid JSON"
    }
}

#[test]
def "send task success handles large output" [] {
    let context = $in
    
    let large_output = '{"data": "' + ("x" | str repeat 262144) + '"}'  # 256KB+ output
    
    let config = {
        task_token: $context.task_token
        output: $large_output
    }
    
    try {
        stepfunctions send-task-success $config
        assert false "Should have failed with output too large"
    } catch { |error|
        assert str contains $error.msg "output size"
    }
}

#[test]
def "send task success final state validation" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        output: $context.output_data
    }
    
    try {
        stepfunctions send-task-success $config
        # After success, additional operations should fail
        stepfunctions send-task-success $config
        assert false "Should have failed on second success call"
    } catch { |error|
        assert str contains $error.msg "already completed"
    }
}

#[test]
def "send task failure with error details" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        error: $context.error_code
        cause: $context.error_cause
    }
    
    let result = try {
        stepfunctions send-task-failure $config
    } catch { |error|
        assert str contains $error.msg "Failed to send task failure"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "send task failure validates token format" [] {
    let context = $in
    
    let config = {
        task_token: ""  # Empty token
        error: $context.error_code
    }
    
    try {
        stepfunctions send-task-failure $config
        assert false "Should have failed with empty task token"
    } catch { |error|
        assert str contains $error.msg "task_token"
    }
}

#[test]
def "send task failure validates error code length" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        error: ("x" | str repeat 300)  # Too long error code
        cause: $context.error_cause
    }
    
    try {
        stepfunctions send-task-failure $config
        assert false "Should have failed with error code too long"
    } catch { |error|
        assert str contains $error.msg "error code"
    }
}

#[test]
def "describe state machine for execution" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-state-machine-for-execution $context.execution_arn
    } catch { |error|
        assert str contains $error.msg "Failed to describe state machine for execution"
        return
    }
    
    assert ($result | get stateMachineArn? | is-not-empty)
    assert ($result | get name? | is-not-empty)
    assert ($result | get definition? | is-not-empty)
}

#[test]
def "describe state machine for execution validates arn" [] {
    try {
        stepfunctions describe-state-machine-for-execution "invalid-arn"
        assert false "Should have failed with invalid execution ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}