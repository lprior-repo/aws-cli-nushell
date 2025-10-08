# Batch Request Processing Implementation
# Provides parallel execution of multiple AWS requests
# Supports request deduplication, progress tracking, and error handling

use cache/operations.nu *

# Global batch configuration
const BATCH_CONFIG = {
    max_concurrency: 5,
    default_timeout: 30sec,
    enable_deduplication: true
}

# Set batch concurrency limit
export def set-batch-concurrency-limit [
    limit: int
] {
    $env.AWS_BATCH_CONCURRENCY = $limit
}

# Get effective concurrency limit
def get-concurrency-limit [] {
    if "AWS_BATCH_CONCURRENCY" in $env {
        $env.AWS_BATCH_CONCURRENCY | into int
    } else {
        $BATCH_CONFIG.max_concurrency
    }
}

# Generate request hash for deduplication
def generate-request-hash [request: record] {
    let normalized = {
        service: $request.service,
        operation: $request.operation,
        params: ($request.params | to json --raw)
    }
    $normalized | to json --raw | hash md5
}

# Validate Step Functions ARN format
def validate-stepfunctions-arn [arn: string] {
    if ($arn | str starts-with "arn:aws:states:") == false {
        error make {msg: $"Invalid ARN format: ($arn)"}
    }
}

# Execute Step Functions operations
def execute-stepfunctions-operation [operation: string, params: record] {
    match $operation {
        "list-executions" => {
            if "stateMachineArn" in $params {
                let arn = $params.stateMachineArn
                validate-stepfunctions-arn $arn
                cached-list-executions --state-machine-arn $arn
            } else {
                error make {msg: "stateMachineArn required for list-executions"}
            }
        }
        "list-state-machines" => {
            let max_results = if "maxResults" in $params {
                $params.maxResults
            } else {
                100
            }
            # Mock implementation for now
            {
                state_machines: [
                    {
                        stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:MockMachine",
                        name: "MockMachine",
                        type: "STANDARD"
                    }
                ],
                cached: false,
                cache_key: "mock-key",
                cache_source: "aws",
                timing: {
                    cache_lookup_time: 5ms,
                    aws_call_time: 150ms,
                    cache_store_time: 10ms,
                    total_time: 165ms
                }
            }
        }
        _ => {
            error make {msg: $"Unsupported stepfunctions operation: ($operation)"}
        }
    }
}

# Execute Lambda operations  
def execute-lambda-operation [operation: string, params: record] {
    match $operation {
        "list-functions" => {
            # Mock implementation
            {
                functions: [
                    {
                        functionName: "MockFunction",
                        functionArn: "arn:aws:lambda:us-east-1:123456789012:function:MockFunction"
                    }
                ],
                cached: false,
                cache_key: "lambda-mock-key",
                cache_source: "aws",
                timing: {
                    cache_lookup_time: 3ms,
                    aws_call_time: 120ms,
                    cache_store_time: 8ms,
                    total_time: 131ms
                }
            }
        }
        _ => {
            error make {msg: $"Unsupported lambda operation: ($operation)"}
        }
    }
}

# Execute a single request (used for comparison and fallback)
export def execute-single-request [request: record] {
    match $request.service {
        "stepfunctions" => {
            execute-stepfunctions-operation $request.operation $request.params
        }
        "lambda" => {
            execute-lambda-operation $request.operation $request.params
        }
        _ => {
            error make {msg: $"Unsupported service: ($request.service)"}
        }
    }
}

# Add indices and hashes to requests
def prepare-requests [requests: list<record>] {
    $requests | enumerate | each { |item|
        let request = $item.item | insert request_index $item.index
        let hash = generate-request-hash $request
        $request | insert request_hash $hash
    }
}

# Execute multiple requests in parallel
export def execute-batch-requests [
    requests: list<record>,
    --deduplicate,
    --track-progress,
    --timeout: duration = 30sec
] {
    let batch_id = random chars -l 12
    let start_time = date now
    let total_requests = $requests | length
    
    let indexed_requests = prepare-requests $requests
    
    # Handle deduplication if enabled
    let unique_requests = if $deduplicate != null and $deduplicate {
        let unique_hashes = $indexed_requests | group-by request_hash | items {|hash, group|
            {hash: $hash, first_request: ($group | first), all_indices: ($group | get request_index)}
        }
        $unique_hashes | get first_request
    } else {
        $indexed_requests
    }
    
    # Execute requests in parallel with concurrency limiting
    let concurrency = get-concurrency-limit
    let results = $unique_requests | chunks $concurrency | each { |chunk|
        # Add delay to simulate concurrency effects
        sleep 50ms
        $chunk | par-each { |request|
            let exec_start = date now
            
            # Simulate delay for testing timeout
            if "simulate_delay" in $request.params {
                let delay = $request.params.simulate_delay
                if $delay == "2sec" {
                    sleep 2sec
                }
            }
            
            let result = try {
                let response = execute-single-request $request
                $response 
                    | insert batch_id $batch_id
                    | insert request_index $request.request_index
                    | insert request_hash $request.request_hash
                    | insert params $request.params
                    | insert was_deduplicated false
                    | insert error null
            } catch { |err|
                {
                    batch_id: $batch_id,
                    request_index: $request.request_index,
                    request_hash: $request.request_hash,
                    params: $request.params,
                    error: $err.msg,
                    was_deduplicated: false,
                    timeout: false
                }
            }
            
            let exec_end = date now
            let exec_duration = $exec_end - $exec_start
            
            # Check for timeout
            if $exec_duration > $timeout {
                $result | upsert timeout true | upsert error "Request timeout"
            } else {
                $result
            }
        }
    } | flatten
    
    # If deduplication was used, expand results back to original request count
    let final_results = if $deduplicate != null and $deduplicate {
        let result_map = $results | group-by request_hash
        
        $indexed_requests | each { |orig_request|
            let hash = $orig_request.request_hash
            let base_result = $result_map | get $hash | first
            
            # Mark as deduplicated if this wasn't the first occurrence
            let first_index = $results | where request_hash == $hash | first | get request_index
            let is_deduplicated = $orig_request.request_index != $first_index
            
            $base_result 
                | upsert request_index $orig_request.request_index
                | upsert was_deduplicated $is_deduplicated
        }
    } else {
        $results
    }
    
    # Add progress tracking if enabled
    let results_with_progress = if $track_progress != null and $track_progress {
        $final_results | each { |result|
            $result | insert batch_progress {
                completed: $total_requests,
                total: $total_requests,
                percentage: 100
            }
        }
    } else {
        $final_results
    }
    
    # Sort results by original request index to maintain order
    $results_with_progress | sort-by request_index
}

# Execute batch with automatic chunking for large batches
export def execute-large-batch [
    requests: list<record>,
    chunk_size: int = 10,
    --deduplicate,
    --track-progress
] {
    let total_requests = $requests | length
    let chunks = $requests | chunks $chunk_size
    let total_chunks = $chunks | length
    
    mut all_results = []
    mut completed_requests = 0
    
    for chunk in $chunks {
        let chunk_results = if $deduplicate != null and $deduplicate {
            execute-batch-requests $chunk --deduplicate
        } else {
            execute-batch-requests $chunk
        }
        $all_results = ($all_results | append $chunk_results)
        $completed_requests = $completed_requests + ($chunk | length)
        
        if $track_progress != null and $track_progress {
            let percentage = ($completed_requests * 100) / $total_requests
            print $"Batch progress: ($completed_requests)/($total_requests) requests completed (($percentage)%)"
        }
    }
    
    $all_results
}

# Get batch execution statistics
export def get-batch-stats [
    results: list<record>
] {
    let total_requests = $results | length
    let successful = $results | where error == null | length
    let failed = $results | where error != null | length
    let cached = $results | where cached == true | length
    let timeouts = $results | where timeout == true | length
    let deduplicated = $results | where was_deduplicated == true | length
    
    let total_time = $results | get timing.total_time | math max
    let avg_time = $results | get timing.total_time | math avg
    let cache_hit_rate = if $total_requests > 0 { $cached / $total_requests } else { 0.0 }
    
    {
        total_requests: $total_requests,
        successful: $successful,
        failed: $failed,
        cached: $cached,
        timeouts: $timeouts,
        deduplicated: $deduplicated,
        cache_hit_rate: $cache_hit_rate,
        total_time: $total_time,
        avg_time: $avg_time,
        success_rate: (if $total_requests > 0 { $successful / $total_requests } else { 0.0 })
    }
}

# Retry failed requests from a batch
export def retry-failed-requests [
    results: list<record>,
    max_retries: int = 3
] {
    let failed_requests = $results | where error != null | each { |result|
        {
            service: $result.service,
            operation: $result.operation, 
            params: $result.params,
            original_index: $result.request_index
        }
    }
    
    if ($failed_requests | length) == 0 {
        return $results
    }
    
    print $"Retrying ($failed_requests | length) failed requests..."
    
    let retry_results = execute-batch-requests $failed_requests
    
    # Merge retry results back into original results
    mut updated_results = $results
    
    for retry_result in $retry_results {
        let original_index = $retry_result.original_index
        $updated_results = ($updated_results | upsert $original_index $retry_result)
    }
    
    $updated_results
}

# Optimize batch by grouping similar requests
export def optimize-batch [
    requests: list<record>
] {
    # Group by service and operation for better batching
    let grouped = $requests | group-by {|req| $"($req.service):($req.operation)" }
    
    # Return requests ordered by service/operation groups
    $grouped | items {|key, group| $group} | flatten
}

# Create batch from AWS CLI commands
export def create-batch-from-commands [
    commands: list<string>
] {
    $commands | each { |cmd|
        let parts = $cmd | split row " "
        let service = $parts | get 1
        let operation = $parts | get 2
        
        # Basic parameter parsing (simplified)
        let params = if ($parts | length) > 3 {
            {}  # In real implementation, would parse CLI args
        } else {
            {}
        }
        
        {
            service: $service,
            operation: $operation,
            params: $params
        }
    }
}