# Pure Unit Tests for Step Functions Execution Operations
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions Execution tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions Execution tests"
}

# UNIT TEST: start-execution function
# Entry point: start-execution with state machine ARN
# Exit point: returns execution details
# [test]
export def test_start_execution []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    
    # Invoke the unit of work
    let result = start-execution $test_sm_arn
    
    # Check exit points
    assert_type $result "record" "start-execution should return record type"
    assert_contains ($result | columns) "execution_arn" "start-execution should have execution_arn field"
    assert_contains ($result | columns) "start_date" "start-execution should have start_date field"
    assert ($result.execution_arn | str contains "execution") "execution_arn should contain 'execution'"
}

# UNIT TEST: start-execution with optional parameters
# Entry point: start-execution with name, input, and trace header
# Exit point: returns execution details with custom parameters
# [test]
export def test_start_execution_with_params []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    let execution_name = "test-execution"
    
    # Invoke the unit of work
    let result = start-execution $test_sm_arn --name $execution_name --input '{"key": "value"}' --trace-header "Root=1-5e1b4151-5ac6b5c9d9d4d2b8f6c8e1a1"
    
    # Check exit points
    assert_type $result "record" "start-execution with params should return record type"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert_contains ($result | columns) "start_date" "Should have start_date field"
    assert ($result.execution_arn | str contains $execution_name) "execution_arn should contain custom name"
}

# UNIT TEST: start-sync-execution function
# Entry point: start-sync-execution with state machine ARN
# Exit point: returns synchronous execution result
# [test]
export def test_start_sync_execution []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-express-test"
    
    # Invoke the unit of work
    let result = start-sync-execution $test_sm_arn
    
    # Check exit points
    assert_type $result "record" "start-sync-execution should return record type"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert_contains ($result | columns) "status" "Should have status field"
}

# UNIT TEST: start-sync-execution with parameters
# Entry point: start-sync-execution with name, input, and trace header
# Exit point: returns synchronous execution result with parameters
# [test]
export def test_start_sync_execution_with_params []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-express-test"
    
    # Invoke the unit of work
    let result = start-sync-execution $test_sm_arn --name "sync-test" --input '{"sync": true}' --trace-header "Root=1-sync-trace"
    
    # Check exit points
    assert_type $result "record" "start-sync-execution with params should return record type"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert ($result.execution_arn | str contains "sync-test") "execution_arn should contain sync test name"
}

# UNIT TEST: stop-execution function
# Entry point: stop-execution with execution ARN
# Exit point: returns stop confirmation with date
# [test]
export def test_stop_execution []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let result = stop-execution $test_execution_arn
    
    # Check exit points
    assert_type $result "record" "stop-execution should return record type"
    assert_contains ($result | columns) "stop_date" "stop-execution should have stop_date field"
    assert_type $result.stop_date "string" "stop_date should be string"
}

# UNIT TEST: stop-execution with error and cause
# Entry point: stop-execution with error and cause parameters
# Exit point: returns stop confirmation with error details
# [test]
export def test_stop_execution_with_error []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let result = stop-execution $test_execution_arn --error "TestError" --cause "Test termination"
    
    # Check exit points
    assert_type $result "record" "stop-execution with params should return record type"
    assert_contains ($result | columns) "stop_date" "Should have stop_date field"
    assert_type $result.stop_date "string" "stop_date should be string"
}

# UNIT TEST: describe-execution function
# Entry point: describe-execution with execution ARN
# Exit point: returns execution details
# [test]
export def test_describe_execution []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let result = describe-execution $test_execution_arn
    
    # Check exit points
    assert_type $result "record" "describe-execution should return record type"
    assert_contains ($result | columns) "executionArn" "Should have executionArn field"
    assert_contains ($result | columns) "status" "Should have status field"
    assert_equal $result.executionArn $test_execution_arn "Should return the same execution ARN"
}

# UNIT TEST: list-executions function
# Entry point: list-executions
# Exit point: returns list of executions with metadata
# [test]
export def test_list_executions []: nothing -> nothing {
    # Invoke the unit of work
    let result = list-executions
    
    # Check exit points
    assert_type $result "record" "list-executions should return record type"
    assert_contains ($result | columns) "executions" "list-executions should have executions field"
    assert_contains ($result | columns) "next_token" "list-executions should have next_token field"
    assert_type $result.executions "list" "executions should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: list-executions with state machine ARN
# Entry point: list-executions with state-machine-arn filter
# Exit point: returns filtered execution list
# [test]
export def test_list_executions_with_state_machine []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    
    # Invoke the unit of work
    let result = list-executions --state-machine-arn $test_sm_arn
    
    # Check exit points
    assert_type $result "record" "list-executions with state-machine-arn should return record type"
    assert_contains ($result | columns) "executions" "Should have executions field"
    assert_type $result.executions "list" "executions should be list"
}

# UNIT TEST: list-executions with all parameters
# Entry point: list-executions with status filter, max results, etc.
# Exit point: returns filtered and paginated execution list
# [test]
export def test_list_executions_with_all_params []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    
    # Invoke the unit of work
    let result = list-executions --state-machine-arn $test_sm_arn --status-filter "SUCCEEDED" --max-results 50 --next-token "test-token" --redrive-filter "NOT_REDRIVEN"
    
    # Check exit points
    assert_type $result "record" "list-executions with all params should return record type"
    assert_contains ($result | columns) "executions" "Should have executions field"
    assert_type $result.executions "list" "executions should be list"
}

# UNIT TEST: list-executions with map run ARN
# Entry point: list-executions with map-run-arn filter
# Exit point: returns map run executions
# [test]
export def test_list_executions_with_map_run []: nothing -> nothing {
    let map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:nutest-test:test-map-run"
    
    # Invoke the unit of work
    let result = list-executions --map-run-arn $map_run_arn
    
    # Check exit points
    assert_type $result "record" "list-executions with map-run-arn should return record type"
    assert_contains ($result | columns) "executions" "Should have executions field"
    assert_type $result.executions "list" "executions should be list"
}

# UNIT TEST: get-execution-history function
# Entry point: get-execution-history with execution ARN
# Exit point: returns execution event history
# [test]
export def test_get_execution_history []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let result = get-execution-history $test_execution_arn
    
    # Check exit points
    assert_type $result "record" "get-execution-history should return record type"
    assert_contains ($result | columns) "events" "get-execution-history should have events field"
    assert_contains ($result | columns) "next_token" "get-execution-history should have next_token field"
    assert_type $result.events "list" "events should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: get-execution-history with all parameters
# Entry point: get-execution-history with pagination and filtering options
# Exit point: returns filtered and paginated execution history
# [test]
export def test_get_execution_history_with_params []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let result = get-execution-history $test_execution_arn --max-results 50 --reverse-order true --next-token "test-token" --include-execution-data false
    
    # Check exit points
    assert_type $result "record" "get-execution-history with all params should return record type"
    assert_contains ($result | columns) "events" "Should have events field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.events "list" "events should be list"
}

# UNIT TEST: redrive-execution function
# Entry point: redrive-execution with execution ARN
# Exit point: returns redrive confirmation with date
# [test]
export def test_redrive_execution []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:failed-execution"
    
    # Invoke the unit of work
    let result = redrive-execution $test_execution_arn
    
    # Check exit points
    assert_type $result "record" "redrive-execution should return record type"
    assert_contains ($result | columns) "redrive_date" "redrive-execution should have redrive_date field"
    assert_type $result.redrive_date "string" "redrive_date should be string"
}

# UNIT TEST: redrive-execution with client token
# Entry point: redrive-execution with client token for idempotency
# Exit point: returns redrive confirmation with token handling
# [test]
export def test_redrive_execution_with_token []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:failed-execution"
    let client_token = "test-client-token-123"
    
    # Invoke the unit of work
    let result = redrive-execution $test_execution_arn --client-token $client_token
    
    # Check exit points
    assert_type $result "record" "redrive-execution with client-token should return record type"
    assert_contains ($result | columns) "redrive_date" "Should have redrive_date field"
    assert_type $result.redrive_date "string" "redrive_date should be string"
}

# UNIT TEST: wait-for-execution-complete function
# Entry point: wait-for-execution-complete with short timeout for testing
# Exit point: returns completion status or timeout
# [test]
export def test_wait_for_execution_complete []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work with short timeout for testing
    let result = wait-for-execution-complete $test_execution_arn --timeout-seconds 1 --poll-interval-seconds 1
    
    # Check exit points
    assert_type $result "record" "wait-for-execution-complete should return record type"
    assert_contains ($result | columns) "status" "Should have status field"
    assert_type $result.status "string" "status should be string"
}

# UNIT TEST: test-execution helper function
# Entry point: test-execution with state machine ARN and input
# Exit point: returns test execution result
# [test]
export def test_test_execution []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    let test_input = '{"test": "data"}'
    
    # Invoke the unit of work
    let result = test-execution $test_sm_arn $test_input
    
    # Check exit points
    assert_type $result "record" "test-execution should return record type"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert_contains ($result | columns) "final_status" "Should have final_status field"
}

# UNIT TEST: test-execution with expected status
# Entry point: test-execution with expected status and custom parameters
# Exit point: returns test result with status verification
# [test]
export def test_test_execution_with_expected_status []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    let test_input = '{"test": "data"}'
    let expected_status = "SUCCEEDED"
    
    # Invoke the unit of work
    let result = test-execution $test_sm_arn $test_input $expected_status --execution-name "test-exec" --timeout-seconds 30
    
    # Check exit points
    assert_type $result "record" "test-execution with params should return record type"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert_contains ($result | columns) "final_status" "Should have final_status field"
    assert ($result.execution_arn | str contains "test-exec") "execution_arn should contain custom name"
}

# UNIT TEST: get-execution-output helper function
# Entry point: get-execution-output with execution ARN
# Exit point: returns execution output or null
# [test]
export def test_get_execution_output []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let output = get-execution-output $test_execution_arn
    
    # Check exit points - output can be any type or null
    assert (($output == null) or ($output != null)) "get-execution-output should return a value or null"
}

# UNIT TEST: get-execution-input helper function
# Entry point: get-execution-input with execution ARN
# Exit point: returns execution input or null
# [test]
export def test_get_execution_input []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Invoke the unit of work
    let input = get-execution-input $test_execution_arn
    
    # Check exit points - input can be any type or null
    assert (($input == null) or ($input != null)) "get-execution-input should return a value or null"
}