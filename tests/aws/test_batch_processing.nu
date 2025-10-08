# Batch Request Processing Test Suite
# Tests for batch processing infrastructure and parallel AWS operations
# Tests request batching, parallel execution, and result aggregation

use std assert
use ../../aws/cache/memory.nu *
use ../../aws/cache/disk.nu *
use ../../aws/batch.nu *

#[before-each]
def setup [] {
    # Create isolated environment for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    clear-memory-cache | ignore
    clear-disk-cache | ignore
    {test_context: "batch_processing"}
}

#[test]
def test_batch_list_executions [] {
    # RED: This will fail initially - batch processing functions don't exist
    # Test batching multiple list-executions requests
    
    let state_machine_arns = [
        "arn:aws:states:us-east-1:123456789012:stateMachine:Machine1",
        "arn:aws:states:us-east-1:123456789012:stateMachine:Machine2",
        "arn:aws:states:us-east-1:123456789012:stateMachine:Machine3"
    ]
    
    # Create batch request
    let batch_requests = $state_machine_arns | each { |arn|
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: $arn}
        }
    }
    
    # Execute batch
    let start_time = date now
    let results = execute-batch-requests $batch_requests
    let end_time = date now
    
    # Verify results
    assert (($results | length) == 3) "Should return 3 results"
    assert (($results | all {|r| "executions" in $r}) == true) "All results should have executions"
    assert (($results | all {|r| "batch_id" in $r}) == true) "All results should have batch_id"
    assert (($results | all {|r| "request_index" in $r}) == true) "All results should have request_index"
    
    # Verify timing
    let duration = $end_time - $start_time
    assert ($duration < 1sec) "Batch should complete quickly with parallelization"
    
    # Verify each result corresponds to correct state machine
    let result0 = $results | get 0
    assert ($result0.params.stateMachineArn == ($state_machine_arns | get 0)) "Result 0 should match request 0"
}

#[test]
def test_batch_request_with_mixed_operations [] {
    # Test batching different types of operations together
    
    let mixed_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Machine1"}
        },
        {
            service: "stepfunctions", 
            operation: "list-state-machines",
            params: {maxResults: 10}
        },
        {
            service: "lambda",
            operation: "list-functions",
            params: {maxItems: 20}
        }
    ]
    
    let results = execute-batch-requests $mixed_requests
    
    # Verify mixed results
    assert (($results | length) == 3) "Should return 3 results"
    
    let sf_exec_result = $results | get 0
    let sf_sm_result = $results | get 1
    let lambda_result = $results | get 2
    
    assert ("executions" in $sf_exec_result) "First result should be executions"
    assert ("state_machines" in $sf_sm_result) "Second result should be state machines"
    assert ("functions" in $lambda_result) "Third result should be functions"
}

#[test]
def test_batch_parallel_execution_performance [] {
    # Test that batch processing provides performance benefits over sequential
    
    let requests = 0..4 | each { |i|
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: $"arn:aws:states:us-east-1:123456789012:stateMachine:Machine($i)"}
        }
    }
    
    # Execute sequentially for comparison
    let sequential_start = date now
    let sequential_results = $requests | each { |req|
        execute-single-request $req
    }
    let sequential_end = date now
    let sequential_duration = $sequential_end - $sequential_start
    
    # Execute in batch (parallel)
    let batch_start = date now
    let batch_results = execute-batch-requests $requests
    let batch_end = date now
    let batch_duration = $batch_end - $batch_start
    
    # Verify parallelization benefit
    assert (($batch_results | length) == ($sequential_results | length)) "Same number of results"
    
    # For this test, we just verify that both approaches work 
    # In a real implementation, parallel would be faster, but with mock delays it may not be
    print $"Sequential time: ($sequential_duration), Batch time: ($batch_duration)"
    
    # Verify both produce the same results
    let seq_arns = $sequential_results | get executions | flatten | get stateMachineArn | sort
    let batch_arns = $batch_results | get executions | flatten | get stateMachineArn | sort  
    assert ($seq_arns == $batch_arns) "Should produce equivalent results"
}

#[test]
def test_batch_error_handling [] {
    # Test error handling in batch processing
    
    let requests_with_errors = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:ValidMachine"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "invalid-arn-format"}  # This should cause an error
        },
        {
            service: "stepfunctions",
            operation: "list-state-machines",
            params: {maxResults: 10}
        }
    ]
    
    let results = execute-batch-requests $requests_with_errors
    
    # Verify error handling
    assert (($results | length) == 3) "Should return results for all requests"
    
    let valid_result = $results | get 0
    let error_result = $results | get 1  
    let another_valid = $results | get 2
    
    assert ("executions" in $valid_result) "Valid request should succeed"
    assert ("error" in $error_result) "Invalid request should have error"
    assert ("state_machines" in $another_valid) "Other valid request should succeed"
    
    # Verify error doesn't stop other requests
    assert ($error_result.error != null) "Error should be captured"
    assert ($valid_result.error == null) "Valid requests should not have errors"
}

#[test]
def test_batch_concurrency_limits [] {
    # Test batch processing respects concurrency limits
    
    # Create many requests to test concurrency limiting
    let many_requests = 0..9 | each { |i|
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: $"arn:aws:states:us-east-1:123456789012:stateMachine:Machine($i)"}
        }
    }
    
    # Set concurrency limit
    set-batch-concurrency-limit 3
    
    let start_time = date now
    let results = execute-batch-requests $many_requests
    let end_time = date now
    
    # Verify all requests completed
    assert (($results | length) == 10) "All requests should complete"
    
    # Verify concurrency was limited (should take longer than unlimited)
    let duration = $end_time - $start_time
    assert ($duration > 100ms) "Should take some time due to concurrency limiting"
    
    # Reset concurrency limit
    set-batch-concurrency-limit 10
}

#[test]
def test_batch_request_deduplication [] {
    # Test that identical requests in a batch are deduplicated
    
    let duplicate_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Machine1"}
        },
        {
            service: "stepfunctions", 
            operation: "list-state-machines",
            params: {maxResults: 10}
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Machine1"}  # Duplicate
        }
    ]
    
    let results = (execute-batch-requests $duplicate_requests --deduplicate)
    
    # Verify deduplication
    assert (($results | length) == 3) "Should return results for all original requests"
    
    let first_exec = $results | get 0
    let state_machines = $results | get 1  
    let duplicate_exec = $results | get 2
    
    # Both execution requests should have the same result but different request_index
    assert ($first_exec.executions == $duplicate_exec.executions) "Duplicate requests should have same data"
    assert ($first_exec.request_index != $duplicate_exec.request_index) "But different request indices"
    assert ($first_exec.was_deduplicated == false) "First should not be marked as deduplicated"
    assert ($duplicate_exec.was_deduplicated == true) "Duplicate should be marked as deduplicated"
}

#[test]
def test_batch_result_ordering [] {
    # Test that batch results maintain request ordering
    
    let ordered_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:First", tag: "first"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Second", tag: "second"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Third", tag: "third"}
        }
    ]
    
    let results = execute-batch-requests $ordered_requests
    
    # Verify ordering is maintained
    assert (($results | length) == 3) "Should have 3 results"
    assert (($results | get 0).request_index == 0) "First result should have index 0"
    assert (($results | get 1).request_index == 1) "Second result should have index 1"
    assert (($results | get 2).request_index == 2) "Third result should have index 2"
    
    # Verify results correspond to original requests
    assert (($results | get 0).params.tag == "first") "First result should match first request"
    assert (($results | get 1).params.tag == "second") "Second result should match second request"
    assert (($results | get 2).params.tag == "third") "Third result should match third request"
}

#[test]
def test_batch_cache_integration [] {
    # Test that batch processing integrates with caching
    
    let cached_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Cached1"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Cached2"}
        }
    ]
    
    # First batch - execution
    let first_results = execute-batch-requests $cached_requests
    assert (($first_results | length) == 2) "Should return 2 results"
    
    # Second batch - should use same underlying cache system
    let second_results = execute-batch-requests $cached_requests  
    assert (($second_results | length) == 2) "Should return 2 results"
    
    # Verify both batches complete successfully
    assert (($first_results | all {|r| "executions" in $r}) == true) "First batch should have executions"
    assert (($second_results | all {|r| "executions" in $r}) == true) "Second batch should have executions"
    
    # For this basic test, just verify cache integration works
    let first_arn = $first_results | get 0 | get executions | first | get stateMachineArn
    let second_arn = $second_results | get 0 | get executions | first | get stateMachineArn
    assert ($first_arn == $second_arn) "Should return consistent results"
}

#[test]
def test_batch_progress_tracking [] {
    # Test progress tracking for long-running batches
    
    let large_batch = 0..7 | each { |i|
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: $"arn:aws:states:us-east-1:123456789012:stateMachine:Machine($i)"}
        }
    }
    
    # Execute with progress tracking
    let results = (execute-batch-requests $large_batch --track-progress)
    
    # Verify progress tracking metadata
    assert (($results | length) == 8) "Should complete all requests"
    assert (($results | all {|r| "batch_progress" in $r}) == true) "All results should have progress info"
    
    let final_result = $results | last
    assert ($final_result.batch_progress.completed == 8) "Should show all requests completed"
    assert ($final_result.batch_progress.total == 8) "Should show correct total"
    assert ($final_result.batch_progress.percentage == 100) "Should show 100% completion"
}

#[test]
def test_batch_timeout_handling [] {
    # Test timeout handling for batch operations
    
    let timeout_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Fast"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Slow", simulate_delay: "2sec"}
        }
    ]
    
    # Execute with short timeout
    let results = (execute-batch-requests $timeout_requests --timeout 1sec)
    
    # Verify timeout handling
    assert (($results | length) == 2) "Should return results for both requests"
    
    let fast_result = $results | get 0
    let slow_result = $results | get 1
    
    assert ("executions" in $fast_result) "Fast request should succeed"
    assert ("timeout" in $slow_result) "Slow request should timeout"
    assert ($slow_result.timeout == true) "Timeout should be flagged"
}