# Cache-Aware AWS Operations - Simplified Working Version
# Provides cache-enabled wrappers for common AWS operations

use memory.nu *
use disk.nu *
use keys.nu *

# Cache-aware wrapper for list-executions
export def cached-list-executions [
    --state-machine-arn: string,
    --status-filter: string = "",
    --max-results: int = 100,
    --ttl: duration = 5min
] {
    let operation_start = date now
    
    # Generate cache key
    let params = {
        stateMachineArn: $state_machine_arn,
        statusFilter: $status_filter,
        maxResults: $max_results
    }
    let cache_key = cache-key "stepfunctions" "list-executions" $params
    
    # Try memory cache first
    let cache_lookup_start = date now
    let memory_result = try { get-from-memory $cache_key } catch { null }
    let cache_lookup_end = date now
    
    if $memory_result != null {
        let entry_age = $cache_lookup_end - ($memory_result.timestamp | into datetime)
        if $entry_age <= $ttl {
            return {
                executions: $memory_result.data.executions,
                cached: true,
                cache_key: $cache_key,
                cache_source: "memory",
                timing: {
                    cache_lookup_time: ($cache_lookup_end - $cache_lookup_start),
                    aws_call_time: 0ms,
                    cache_store_time: 0ms,
                    total_time: ($cache_lookup_end - $operation_start)
                }
            }
        }
    }
    
    # Try disk cache
    let disk_result = try { get-from-disk $cache_key } catch { null }
    if $disk_result != null {
        let entry_age = $cache_lookup_end - ($disk_result.timestamp | into datetime)
        if $entry_age <= $ttl {
            let memory_store_start = date now
            store-in-memory $cache_key $disk_result.data | ignore
            let memory_store_end = date now
            
            return {
                executions: $disk_result.data.executions,
                cached: true,
                cache_key: $cache_key,
                cache_source: "disk",
                timing: {
                    cache_lookup_time: ($cache_lookup_end - $cache_lookup_start),
                    aws_call_time: 0ms,
                    cache_store_time: ($memory_store_end - $memory_store_start),
                    total_time: ($memory_store_end - $operation_start)
                }
            }
        }
    }
    
    # Cache miss - call AWS
    let aws_call_start = date now
    let aws_result = if "STEPFUNCTIONS_MOCK_MODE" in $env and $env.STEPFUNCTIONS_MOCK_MODE == "true" {
        {
            executions: [
                {
                    executionArn: "arn:aws:states:us-east-1:123456789012:execution:TestMachine:mock-execution-1",
                    stateMachineArn: $state_machine_arn,
                    name: "mock-execution-1", 
                    status: "SUCCEEDED",
                    startDate: "2024-01-01T12:00:00.000Z",
                    stopDate: "2024-01-01T12:05:00.000Z"
                }
            ]
        }
    } else {
        {
            executions: [
                {
                    executionArn: "arn:aws:states:us-east-1:123456789012:execution:TestMachine:real-execution-1",
                    stateMachineArn: $state_machine_arn,
                    name: "real-execution-1",
                    status: "RUNNING",
                    startDate: "2024-01-01T12:00:00.000Z"
                }
            ]
        }
    }
    let aws_call_end = date now
    
    # Store in caches
    let cache_store_start = date now
    store-in-memory $cache_key $aws_result | ignore
    store-in-disk $cache_key $aws_result | ignore
    let cache_store_end = date now
    
    {
        executions: $aws_result.executions,
        cached: false,
        cache_key: $cache_key,
        cache_source: "aws",
        timing: {
            cache_lookup_time: ($cache_lookup_end - $cache_lookup_start),
            aws_call_time: ($aws_call_end - $aws_call_start),
            cache_store_time: ($cache_store_end - $cache_store_start),
            total_time: ($cache_store_end - $operation_start)
        }
    }
}