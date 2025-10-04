use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        execution_arn: "arn:aws:states:us-east-1:123456789012:execution:test-state-machine:test-execution"
        execution_name: "test-execution"
        test_input: '{"test": "data"}'
        trace_header: "Root=1-5e1b4151-899ea6670f7b9dd6b5b39e34"
    }
}

# start-execution tests (15 tests)
#[test]
def "start execution with minimal config" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
    }
    
    let result = try {
        stepfunctions start-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to start execution"
        return
    }
    
    assert ($result | get executionArn? | is-not-empty)
    assert ($result | get startDate? | is-not-empty)
}

#[test]
def "start execution with custom name" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        name: $context.execution_name
    }
    
    let result = try {
        stepfunctions start-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to start execution"
        return
    }
    
    assert ($result | get executionArn? | str contains $context.execution_name)
}

#[test]
def "start execution with input data" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        input: $context.test_input
    }
    
    let result = try {
        stepfunctions start-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to start execution"
        return
    }
    
    assert ($result | get executionArn? | is-not-empty)
}

#[test]
def "start execution with trace header" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        trace_header: $context.trace_header
    }
    
    let result = try {
        stepfunctions start-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to start execution"
        return
    }
    
    assert ($result | get executionArn? | is-not-empty)
}

#[test]
def "start execution validates state machine arn" [] {
    let config = {
        state_machine_arn: "invalid-arn"
    }
    
    try {
        stepfunctions start-execution $config
        assert false "Should have failed with invalid state machine ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "start sync execution with minimal config" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
    }
    
    let result = try {
        stepfunctions start-sync-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to start sync execution"
        return
    }
    
    assert ($result | get executionArn? | is-not-empty)
    assert ($result | get status? | is-not-empty)
}

#[test]
def "start sync execution with input" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        input: $context.test_input
    }
    
    let result = try {
        stepfunctions start-sync-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to start sync execution"
        return
    }
    
    assert ($result | get status? | is-not-empty)
}

#[test]
def "start sync execution validates arn format" [] {
    let config = {
        state_machine_arn: "invalid-arn"
    }
    
    try {
        stepfunctions start-sync-execution $config
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "stop execution with valid arn" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
    }
    
    let result = try {
        stepfunctions stop-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to stop execution"
        return
    }
    
    assert ($result | get stopDate? | is-not-empty)
}

#[test]
def "stop execution with cause and error" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
        cause: "Test termination"
        error: "TestError"
    }
    
    let result = try {
        stepfunctions stop-execution $config
    } catch { |error|
        assert str contains $error.msg "Failed to stop execution"
        return
    }
    
    assert ($result | get stopDate? | is-not-empty)
}

#[test]
def "stop execution validates arn format" [] {
    let config = {
        execution_arn: "invalid-arn"
    }
    
    try {
        stepfunctions stop-execution $config
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "describe execution with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-execution $context.execution_arn
    } catch { |error|
        assert str contains $error.msg "Failed to describe execution"
        return
    }
    
    assert ($result | get executionArn? | is-not-empty)
    assert ($result | get stateMachineArn? | is-not-empty)
    assert ($result | get status? | is-not-empty)
}

#[test]
def "describe execution validates arn format" [] {
    try {
        stepfunctions describe-execution "invalid-arn"
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "get execution history with basic params" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
    }
    
    let result = try {
        stepfunctions get-execution-history $config
    } catch { |error|
        assert str contains $error.msg "Failed to get execution history"
        return
    }
    
    assert ($result | get events? | describe | str starts-with "list")
}

#[test]
def "get execution history with filtering" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
        max_results: 50
        reverse_order: true
        include_execution_data: false
    }
    
    let result = try {
        stepfunctions get-execution-history $config
    } catch { |error|
        assert str contains $error.msg "Failed to get execution history"
        return
    }
    
    assert ($result | get events? | describe | str starts-with "list")
}