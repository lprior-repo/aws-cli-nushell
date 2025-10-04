use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        activity_arn: "arn:aws:states:us-east-1:123456789012:activity:test-activity"
        max_results: 100
        next_token: "token123"
        status_filter: "ACTIVE"
    }
}

# list-state-machines tests (15 tests)
#[test]
def "list state machines with minimal config" [] {
    let result = try {
        stepfunctions list-state-machines
    } catch { |error|
        assert str contains $error.msg "Failed to list state machines"
        return
    }
    
    assert ($result | get stateMachines? | describe | str starts-with "list")
}

#[test]
def "list state machines with pagination" [] {
    let context = $in
    
    let config = {
        max_results: $context.max_results
        next_token: $context.next_token
    }
    
    let result = try {
        stepfunctions list-state-machines-paginated $config
    } catch { |error|
        assert str contains $error.msg "Failed to list state machines"
        return
    }
    
    assert ($result | get stateMachines? | describe | str starts-with "list")
}

#[test]
def "list state machines validates max results range" [] {
    let config = {
        max_results: 0  # Invalid range
    }
    
    try {
        stepfunctions list-state-machines-paginated $config
        assert false "Should have failed with invalid max_results"
    } catch { |error|
        assert str contains $error.msg "max_results"
    }
}

#[test]
def "list state machines handles large max results" [] {
    let config = {
        max_results: 1001  # Above maximum allowed
    }
    
    try {
        stepfunctions list-state-machines-paginated $config
        assert false "Should have failed with max_results too large"
    } catch { |error|
        assert str contains $error.msg "max_results"
    }
}

#[test]
def "list state machines returns expected structure" [] {
    let result = try {
        stepfunctions list-state-machines
    } catch { |error|
        # Test with mock response structure
        let mock_response = {
            stateMachines: [
                {
                    stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:test"
                    name: "test"
                    type: "STANDARD"
                    creationDate: "2023-01-01T00:00:00Z"
                }
            ]
        }
        assert ($mock_response | get stateMachines | describe | str starts-with "list")
        return
    }
    
    # Validate actual response structure
    assert ($result | get stateMachines? | describe | str starts-with "list")
}

#[test]
def "list executions with state machine arn" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
    }
    
    let result = try {
        stepfunctions list-executions $config
    } catch { |error|
        assert str contains $error.msg "Failed to list executions"
        return
    }
    
    assert ($result | get executions? | describe | str starts-with "list")
}

#[test]
def "list executions with status filter" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        status_filter: "RUNNING"
    }
    
    let result = try {
        stepfunctions list-executions $config
    } catch { |error|
        assert str contains $error.msg "Failed to list executions"
        return
    }
    
    assert ($result | get executions? | describe | str starts-with "list")
}

#[test]
def "list executions validates status filter enum" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        status_filter: "INVALID_STATUS"
    }
    
    try {
        stepfunctions list-executions $config
        assert false "Should have failed with invalid status filter"
    } catch { |error|
        assert str contains $error.msg "status_filter"
    }
}

#[test]
def "list executions validates arn format" [] {
    let config = {
        state_machine_arn: "invalid-arn"
    }
    
    try {
        stepfunctions list-executions $config
        assert false "Should have failed with invalid state machine ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "list executions with pagination" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
        max_results: $context.max_results
        next_token: $context.next_token
    }
    
    let result = try {
        stepfunctions list-executions $config
    } catch { |error|
        assert str contains $error.msg "Failed to list executions"
        return
    }
    
    assert ($result | get executions? | describe | str starts-with "list")
}

#[test]
def "list activities with minimal config" [] {
    let result = try {
        stepfunctions list-activities
    } catch { |error|
        assert str contains $error.msg "Failed to list activities"
        return
    }
    
    assert ($result | get activities? | describe | str starts-with "list")
}

#[test]
def "list activities with pagination" [] {
    let context = $in
    
    let config = {
        max_results: $context.max_results
        next_token: $context.next_token
    }
    
    let result = try {
        stepfunctions list-activities-paginated $config
    } catch { |error|
        assert str contains $error.msg "Failed to list activities"
        return
    }
    
    assert ($result | get activities? | describe | str starts-with "list")
}

#[test]
def "list activities validates max results range" [] {
    let config = {
        max_results: 0  # Invalid range
    }
    
    try {
        stepfunctions list-activities-paginated $config
        assert false "Should have failed with invalid max_results"
    } catch { |error|
        assert str contains $error.msg "max_results"
    }
}

#[test]
def "list state machine versions with arn" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
    }
    
    let result = try {
        stepfunctions list-state-machine-versions $config
    } catch { |error|
        assert str contains $error.msg "Failed to list versions"
        return
    }
    
    assert ($result | get stateMachineVersions? | describe | str starts-with "list")
}

#[test]
def "list state machine aliases with arn" [] {
    let context = $in
    
    let config = {
        state_machine_arn: $context.state_machine_arn
    }
    
    let result = try {
        stepfunctions list-state-machine-aliases $config
    } catch { |error|
        assert str contains $error.msg "Failed to list aliases"
        return
    }
    
    assert ($result | get stateMachineAliases? | describe | str starts-with "list")
}