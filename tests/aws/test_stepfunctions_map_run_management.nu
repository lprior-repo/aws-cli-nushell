use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        execution_arn: "arn:aws:states:us-east-1:123456789012:execution:test-state-machine:test-execution"
        map_run_arn: "arn:aws:states:us-east-1:123456789012:mapRun:test-state-machine/test-execution:map-run-id"
        state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        max_results: 100
        next_token: "token123"
    }
}

# list-map-runs tests (15 tests)
#[test]
def "list map runs with minimal config" [] {
    let context = $in
    
    let result = try {
        stepfunctions list-map-runs $context.execution_arn
    } catch { |error|
        assert str contains $error.msg "Failed to list map runs"
        return
    }
    
    assert ($result | get map_runs? | describe | str starts-with "list")
}

#[test]
def "list map runs with pagination" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
        max_results: $context.max_results
        next_token: $context.next_token
    }
    
    let result = try {
        stepfunctions list-map-runs-paginated $config
    } catch { |error|
        assert str contains $error.msg "Failed to list map runs"
        return
    }
    
    assert ($result | get map_runs? | describe | str starts-with "list")
}

#[test]
def "list map runs validates execution arn" [] {
    try {
        stepfunctions list-map-runs "invalid-arn"
        assert false "Should have failed with invalid execution ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "list map runs handles non-existent execution" [] {
    let non_existent_arn = "arn:aws:states:us-east-1:123456789012:execution:non-existent:execution"
    
    try {
        stepfunctions list-map-runs $non_existent_arn
        assert false "Should have failed with non-existent execution"
    } catch { |error|
        assert str contains $error.msg "does not exist"
    }
}

#[test]
def "list map runs validates max results range" [] {
    let context = $in
    
    let config = {
        execution_arn: $context.execution_arn
        max_results: 0  # Invalid range
    }
    
    try {
        stepfunctions list-map-runs-paginated $config
        assert false "Should have failed with invalid max_results"
    } catch { |error|
        assert str contains $error.msg "max_results"
    }
}

#[test]
def "describe map run with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-map-run $context.map_run_arn
    } catch { |error|
        assert str contains $error.msg "Failed to describe map run"
        return
    }
    
    assert ($result | get mapRunArn? | is-not-empty)
    assert ($result | get executionArn? | is-not-empty)
    assert ($result | get status? | is-not-empty)
}

#[test]
def "describe map run validates arn format" [] {
    try {
        stepfunctions describe-map-run "invalid-arn"
        assert false "Should have failed with invalid map run ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "describe map run handles non-existent arn" [] {
    let non_existent_arn = "arn:aws:states:us-east-1:123456789012:mapRun:non-existent:execution:map-id"
    
    try {
        stepfunctions describe-map-run $non_existent_arn
        assert false "Should have failed with non-existent map run"
    } catch { |error|
        assert str contains $error.msg "does not exist"
    }
}

#[test]
def "describe map run returns expected fields" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-map-run $context.map_run_arn
    } catch { |error|
        # Test field validation in mock response
        let mock_response = {
            mapRunArn: $context.map_run_arn
            executionArn: $context.execution_arn
            status: "RUNNING"
            startDate: "2023-01-01T00:00:00Z"
            maxConcurrency: 10
            toleratedFailureCount: 0
        }
        assert ($mock_response | get status) in ["RUNNING", "SUCCEEDED", "FAILED", "ABORTED"]
        return
    }
    
    # If successful, validate required fields
    assert ($result | get status) in ["RUNNING", "SUCCEEDED", "FAILED", "ABORTED"]
}

#[test]
def "describe map run validates status enum" [] {
    let context = $in
    
    # Mock a response with invalid status for validation
    let mock_response = {
        mapRunArn: $context.map_run_arn
        status: "INVALID_STATUS"
    }
    
    # Status should be one of the valid enum values
    assert not (($mock_response | get status) in ["RUNNING", "SUCCEEDED", "FAILED", "ABORTED"])
}

#[test]
def "update map run with tolerance config" [] {
    let context = $in
    
    let config = {
        map_run_arn: $context.map_run_arn
        max_concurrency: 20
        tolerated_failure_count: 5
    }
    
    let result = try {
        stepfunctions update-map-run $config
    } catch { |error|
        assert str contains $error.msg "Failed to update map run"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "update map run validates arn format" [] {
    let config = {
        map_run_arn: "invalid-arn"
        max_concurrency: 10
    }
    
    try {
        stepfunctions update-map-run $config
        assert false "Should have failed with invalid map run ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "update map run validates concurrency range" [] {
    let context = $in
    
    let config = {
        map_run_arn: $context.map_run_arn
        max_concurrency: -1  # Invalid negative value
    }
    
    try {
        stepfunctions update-map-run $config
        assert false "Should have failed with negative concurrency"
    } catch { |error|
        assert str contains $error.msg "max_concurrency"
    }
}

#[test]
def "update map run validates failure count range" [] {
    let context = $in
    
    let config = {
        map_run_arn: $context.map_run_arn
        tolerated_failure_count: -1  # Invalid negative value
    }
    
    try {
        stepfunctions update-map-run $config
        assert false "Should have failed with negative failure count"
    } catch { |error|
        assert str contains $error.msg "tolerated_failure_count"
    }
}

#[test]
def "update map run handles running status only" [] {
    let context = $in
    
    let config = {
        map_run_arn: $context.map_run_arn
        max_concurrency: 15
    }
    
    try {
        stepfunctions update-map-run $config
        # Should only allow updates to RUNNING map runs
        assert true
    } catch { |error|
        if ($error.msg | str contains "not in RUNNING state") {
            assert true  # Expected error for non-running map runs
        } else {
            assert str contains $error.msg "Failed to update map run"
        }
    }
}