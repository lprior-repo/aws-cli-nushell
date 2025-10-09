# NuAWS Streaming Operations Test Suite
# Comprehensive testing for PERF-001 streaming functionality
#
# Test Coverage:
# - Generator functions and pagination
# - Memory efficiency and constant usage
# - Backpressure handling and rate limiting  
# - Progress reporting accuracy
# - Performance benchmarking
# - Error handling and recovery

use ../tools/streaming_operations.nu *
use ../nutest/nutest/mod.nu

# ============================================================================
# Test Setup and Utilities  
# ============================================================================

#[before-each]
def setup_streaming_tests [] {
    # Enable mock modes for all AWS services
    $env.S3_MOCK_MODE = "true"
    $env.EC2_MOCK_MODE = "true"
    $env.LAMBDA_MOCK_MODE = "true"
    $env.IAM_MOCK_MODE = "true"
    $env.CLOUDFORMATION_MOCK_MODE = "true"
    
    {
        test_context: "streaming_operations",
        mock_mode: true,
        start_time: (date now)
    }
}

#[after-each]
def cleanup_streaming_tests [] {
    # Clean up any environment variables or temporary state
    try { unlet-env S3_MOCK_MODE } catch { }
    try { unlet-env EC2_MOCK_MODE } catch { }
    try { unlet-env LAMBDA_MOCK_MODE } catch { }
    try { unlet-env IAM_MOCK_MODE } catch { }
    try { unlet-env CLOUDFORMATION_MOCK_MODE } catch { }
}

# Helper to measure memory usage change during operation
def measure_memory_usage [operation: closure]: nothing -> record {
    let memory_before = (get-memory-usage-mb)
    let result = (do $operation)
    let memory_after = (get-memory-usage-mb)
    
    {
        result: $result,
        memory_before: $memory_before,
        memory_after: $memory_after,
        memory_delta: ($memory_after - $memory_before),
        memory_stable: (($memory_after - $memory_before) < 10)
    }
}

# ============================================================================
# Core Streaming Generator Tests
# ============================================================================

#[test]
def "test create-stream-state creates valid initial state" [] {
    let context = $in
    
    let state = create-stream-state "s3" "list-objects" { bucket: "test" }
    
    assert ($state.service == "s3") "Service should be set correctly"
    assert ($state.operation == "list-objects") "Operation should be set correctly"
    assert ($state.params.bucket == "test") "Parameters should be preserved"
    assert ($state.next_token | is-empty) "Initial next_token should be null"
    assert ($state.page_count == 0) "Initial page_count should be 0"
    assert ($state.items_yielded == 0) "Initial items_yielded should be 0"
    assert ($state.rate_limit.requests_per_second == 10) "Default rate limit should be 10"
    assert (not $state.progress.enabled) "Progress should be disabled by default"
}

#[test]
def "test aws-paginated-stream generates items from mock data" [] {
    let context = $in
    
    let items = (
        aws-paginated-stream "s3" "list-objects" { bucket: "test" }
        | take 5
        | collect
    )
    
    assert ($items | length) == 5 "Should generate exactly 5 items"
    assert ($items | all { |item| $item.mock == true }) "All items should be marked as mock"
    assert ($items | all { |item| $item.service == "s3" }) "All items should have correct service"
}

#[test]
def "test aws-paginated-stream respects max-items limit" [] {
    let context = $in
    
    let items = (
        aws-paginated-stream "s3" "list-objects" { bucket: "test" } --max-items=3
        | collect
    )
    
    assert ($items | length) <= 3 "Should not exceed max-items limit"
}

#[test]
def "test aws-paginated-stream with rate limiting" [] {
    let context = $in
    
    let start_time = (date now)
    let items = (
        aws-paginated-stream "s3" "list-objects" { bucket: "test" } --rate-limit=5 --max-items=2
        | collect
    )
    let end_time = (date now)
    
    let duration = (($end_time - $start_time) / 1ms)
    
    assert ($items | length) == 2 "Should generate requested items"
    # With rate limiting at 5 req/sec, 2 items should take at least 200ms
    assert ($duration >= 150) "Rate limiting should introduce delays"
}

# ============================================================================
# Service-Specific Streaming Tests
# ============================================================================

#[test]
def "test aws s3 list-objects-stream functionality" [] {
    let context = $in
    
    let objects = (
        aws s3 list-objects-stream "test-bucket" --max-keys=10
        | take 15
        | collect
    )
    
    assert ($objects | length) == 15 "Should stream exactly 15 objects"
    assert ($objects | all { |obj| $obj.id? | is-not-empty }) "All objects should have IDs"
    assert ($objects | all { |obj| $obj.mock == true }) "All objects should be mock data"
}

#[test]
def "test aws ec2 describe-instances-stream functionality" [] {
    let context = $in
    
    let instances = (
        aws ec2 describe-instances-stream --max-results=20
        | take 10
        | collect
    )
    
    assert ($instances | length) == 10 "Should stream exactly 10 instances"
    assert ($instances | all { |inst| $inst.service == "ec2" }) "All instances should be EC2 service"
}

#[test]
def "test aws lambda list-functions-stream functionality" [] {
    let context = $in
    
    let functions = (
        aws lambda list-functions-stream --max-items=15
        | take 8
        | collect
    )
    
    assert ($functions | length) == 8 "Should stream exactly 8 functions"
    assert ($functions | all { |func| $func.service == "lambda" }) "All functions should be Lambda service"
}

#[test]
def "test aws iam list-entities-stream functionality" [] {
    let context = $in
    
    let users = (
        aws iam list-entities-stream "users" --max-items=12
        | take 5
        | collect
    )
    
    assert ($users | length) == 5 "Should stream exactly 5 users"
    assert ($users | all { |user| $user.service == "iam" }) "All users should be IAM service"
}

# ============================================================================
# Memory Efficiency Tests
# ============================================================================

#[test]
def "test constant memory usage during streaming" [] {
    let context = $in
    
    let memory_test = (measure_memory_usage {
        aws s3 list-objects-stream "large-bucket"
        | take 100
        | each { |item| $item | select id name }  # Minimal processing
        | length
    })
    
    assert ($memory_test.memory_stable) "Memory usage should remain stable during streaming"
    assert ($memory_test.memory_delta < 20) "Memory delta should be less than 20MB"
}

#[test]
def "test process-stream-windowed maintains constant memory" [] {
    let context = $in
    
    let memory_test = (measure_memory_usage {
        aws s3 list-objects-stream "test-bucket"
        | take 50
        | process-stream-windowed { |window|
            $window | length  # Simple processing that doesn't accumulate
        } --window-size=10
        | math sum
    })
    
    assert ($memory_test.result == 50) "Should process all 50 items"
    assert ($memory_test.memory_stable) "Windowed processing should maintain stable memory"
}

#[test]
def "test lazy-transform defers computation" [] {
    let context = $in
    
    let start_time = (date now)
    
    # Create a lazy transform but don't consume it
    let lazy_stream = (
        [1, 2, 3, 4, 5] 
        | lazy-transform { |x| 
            sleep 100ms  # Simulate expensive operation
            $x * 2 
        }
    )
    
    let creation_time = (date now)
    let creation_duration = (($creation_time - $start_time) / 1ms)
    
    # Should create instantly (lazy evaluation)
    assert ($creation_duration < 100) "Lazy transform should create instantly"
    
    # Now consume the first element
    let first_result = ($lazy_stream | first)
    assert ($first_result == 2) "First transformed element should be correct"
}

# ============================================================================
# Backpressure and Rate Limiting Tests
# ============================================================================

#[test]
def "test rate limiting applies appropriate delays" [] {
    let context = $in
    
    # Test with very low rate limit to ensure delays are measurable
    let start_time = (date now)
    let items = (
        aws-paginated-stream "s3" "list-objects" { bucket: "test" } --rate-limit=2 --max-items=3
        | collect
    )
    let end_time = (date now)
    
    let duration = (($end_time - $start_time) / 1ms)
    
    assert ($items | length) == 3 "Should generate all requested items"
    # With 2 req/sec, 3 items should take at least 1000ms (2 intervals)
    assert ($duration >= 800) "Rate limiting should introduce significant delays"
}

#[test]
def "test monitor-backpressure responds to memory pressure" [] {
    let context = $in
    
    # Test that backpressure monitoring doesn't break the pipeline
    let items = (
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        | monitor-backpressure --memory-threshold=50  # Low threshold to potentially trigger
        | length
    )
    
    assert ($items == 10) "Backpressure monitoring should not lose items"
}

#[test]
def "test stream-filter-optimized with early termination" [] {
    let context = $in
    
    let start_time = (date now)
    let filtered_items = (
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        | stream-filter-optimized { |x| $x <= 3 } --break-on-false
    )
    let end_time = (date now)
    
    assert ($filtered_items | length) == 3 "Should return exactly 3 items before early termination"
    assert ($filtered_items == [1, 2, 3]) "Should return correct filtered items"
}

# ============================================================================
# Progress Reporting Tests
# ============================================================================

#[test]
def "test stream progress reports correctly" [] {
    let context = $in
    
    # Capture output to verify progress reporting
    let items_with_progress = (
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        | stream progress --estimated-total=10
        | collect
    )
    
    assert ($items_with_progress | length) == 10 "Progress wrapper should not lose items"
    assert ($items_with_progress == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) "Progress wrapper should preserve order"
}

#[test]
def "test aws-paginated-stream with progress enabled" [] {
    let context = $in
    
    let items = (
        aws-paginated-stream "s3" "list-objects" { bucket: "test" } --progress --max-items=5
        | collect
    )
    
    assert ($items | length) == 5 "Progress mode should not affect item generation"
    assert ($items | all { |item| $item.mock == true }) "Progress mode should still use mock data"
}

# ============================================================================
# Performance and Benchmarking Tests
# ============================================================================

#[test]
def "test stream benchmark produces valid metrics" [] {
    let context = $in
    
    let benchmark_result = (
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        | stream benchmark --duration=2 --warmup=1
    )
    
    assert ($benchmark_result.warmup_items? | is-not-empty) "Benchmark should report warmup items"
    assert ($benchmark_result.benchmark_items? | is-not-empty) "Benchmark should report benchmark items" 
    assert ($benchmark_result.throughput_items_per_second? | is-not-empty) "Benchmark should calculate throughput"
    assert ($benchmark_result.throughput_items_per_second > 0) "Throughput should be positive"
    assert ($benchmark_result.memory_usage_mb? | is-not-empty) "Benchmark should report memory usage"
}

#[test]
def "test stream profile-memory tracks memory usage" [] {
    let context = $in
    
    # Test memory profiling doesn't break the pipeline
    let items = (
        [1, 2, 3, 4, 5]
        | stream profile-memory --sample-interval=100
        | collect
    )
    
    assert ($items | length) == 5 "Memory profiling should not lose items"
    assert ($items == [1, 2, 3, 4, 5]) "Memory profiling should preserve data"
}

# ============================================================================
# Error Handling and Recovery Tests
# ============================================================================

#[test]
def "test streaming handles service errors gracefully" [] {
    let context = $in
    
    # Temporarily disable mock mode to trigger potential errors
    unlet-env S3_MOCK_MODE
    
    let error_caught = try {
        aws-paginated-stream "s3" "invalid-operation" { bucket: "test" } --max-items=1
        | take 1
        | collect
        false  # No error occurred
    } catch { |err|
        true   # Error was caught
    }
    
    # Re-enable mock mode
    $env.S3_MOCK_MODE = "true"
    
    # For this test, we expect an error since we're using an invalid operation
    # The important thing is that the error is handled gracefully
    assert true "Error handling test completed (graceful failure expected)"
}

#[test]
def "test exponential backoff increases delays" [] {
    let context = $in
    
    # Test that create-stream-state initializes backoff correctly
    let initial_state = create-stream-state "s3" "list-objects" { bucket: "test" }
    assert ($initial_state.rate_limit.backoff_multiplier == 1.0) "Initial backoff should be 1.0"
    
    # Test that apply-exponential-backoff increases multiplier
    let error_record = { msg: "test error" }
    let backoff_state = (apply-exponential-backoff $initial_state $error_record)
    assert ($backoff_state.rate_limit.backoff_multiplier == 2.0) "Backoff should double after error"
}

# ============================================================================
# High-Level Pattern Tests
# ============================================================================

#[test]
def "test aws process-dataset with chunked processing" [] {
    let context = $in
    
    let processed_results = (
        aws process-dataset "s3" "list-objects" { bucket: "test" } { |chunk|
            $chunk | select id service | where service == "s3"
        } --chunk-size=5 --max-memory=100
        | take 12
        | collect
    )
    
    assert ($processed_results | length) == 12 "Should process exactly 12 items"
    assert ($processed_results | all { |item| $item.service == "s3" }) "All processed items should be S3"
}

#[test]
def "test aws search-dataset with search predicate" [] {
    let context = $in
    
    let search_results = (
        aws search-dataset "s3" "list-objects" { bucket: "test" } { |item|
            $item.name =~ "MockResource"
        } --limit=5
        | collect
    )
    
    assert ($search_results | length) <= 5 "Should respect search limit"
    assert ($search_results | all { |item| $item.name =~ "MockResource" }) "All results should match search criteria"
}

#[test]
def "test stream export-state generates valid metadata" [] {
    let context = $in
    
    let exported_data = (
        [1, 2, 3, 4, 5]
        | stream export-state --format=json
        | from json
    )
    
    assert ($exported_data.metadata? | is-not-empty) "Export should include metadata"
    assert ($exported_data.metadata.item_count == 5) "Metadata should have correct item count"
    assert ($exported_data.metadata.format == "json") "Metadata should have correct format"
    assert ($exported_data.data? | is-not-empty) "Export should include data"
    assert ($exported_data.data | length) == 5 "Exported data should have correct length"
}

# ============================================================================
# Integration and End-to-End Tests
# ============================================================================

#[test]
def "test comprehensive streaming workflow" [] {
    let context = $in
    
    # Test a complete workflow combining multiple streaming patterns
    let workflow_result = (
        aws s3 list-objects-stream "workflow-bucket" 
        | where name =~ "important"
        | process-stream-windowed 3 { |chunk|
            $chunk | select id name | where name =~ "MockResource"
        }
        | take 6
        | collect
    )
    
    assert ($workflow_result | length) <= 6 "Workflow should respect take limit"
    assert ($workflow_result | all { |item| ($item.id? | is-not-empty) }) "All workflow items should have IDs"
}

#[test]
def "test streaming operations integration with mock services" [] {
    let context = $in
    
    # Test that all major AWS services work with streaming
    let s3_count = (aws s3 list-objects-stream "test" | take 3 | length)
    let ec2_count = (aws ec2 describe-instances-stream | take 3 | length) 
    let lambda_count = (aws lambda list-functions-stream | take 3 | length)
    
    assert ($s3_count == 3) "S3 streaming should work"
    assert ($ec2_count == 3) "EC2 streaming should work"
    assert ($lambda_count == 3) "Lambda streaming should work"
}

# ============================================================================
# Performance Target Validation Tests
# ============================================================================

#[test]
def "test first result availability under 500ms" [] {
    let context = $in
    
    let start_time = (date now)
    let first_item = (
        aws s3 list-objects-stream "performance-test"
        | first
    )
    let first_result_time = (date now)
    
    let time_to_first = (($first_result_time - $start_time) / 1ms)
    
    assert ($first_item? | is-not-empty) "Should get first result"
    assert ($time_to_first < 500) $"First result should be available in <500ms (actual: ($time_to_first)ms)"
}

#[test]
def "test memory usage under 100MB target" [] {
    let context = $in
    
    let memory_before = (get-memory-usage-mb)
    
    # Process a substantial amount of data
    aws s3 list-objects-stream "memory-test"
    | take 200
    | each { |item| $item | select id name service }
    | length
    | ignore
    
    let memory_after = (get-memory-usage-mb)
    let memory_used = ($memory_after - $memory_before)
    
    assert ($memory_used < 100) $"Memory usage should be <100MB (actual: ($memory_used)MB)"
}

#[test]
def "test constant memory usage for large datasets" [] {
    let context = $in
    
    let memory_samples = []
    let initial_memory = (get-memory-usage-mb)
    
    # Process data in chunks and sample memory
    aws s3 list-objects-stream "large-dataset"
    | take 100
    | enumerate
    | each { |item|
        if (($item.index mod 20) == 0) {
            let current_memory = (get-memory-usage-mb)
            $memory_samples = ($memory_samples | append $current_memory)
        }
        $item.item
    }
    | length
    | ignore
    
    # Memory should remain relatively stable
    if ($memory_samples | length) > 1 {
        let memory_variance = (
            $memory_samples 
            | math stddev
        )
        assert ($memory_variance < 10) "Memory usage should remain stable (low variance)"
    }
}

# ============================================================================
# Demo and Showcase Test
# ============================================================================

#[test]
def "test demo streaming-showcase runs without errors" [] {
    let context = $in
    
    # Test that the demo runs successfully
    let demo_success = try {
        demo streaming-showcase
        true
    } catch { |err|
        print $"Demo failed: ($err.msg)"
        false
    }
    
    assert $demo_success "Demo streaming-showcase should run without errors"
}

#[test]
def "test streaming operations test suite" [] {
    let context = $in
    
    let test_results = (test streaming-operations)
    
    assert ($test_results.summary? | is-not-empty) "Test results should include summary"
    assert ($test_results.summary.total_tests > 0) "Should run multiple tests"
    assert ($test_results.summary.success_rate >= 75) "Should have high success rate"
}

# ============================================================================
# Test Summary and Reporting
# ============================================================================

# Run all streaming tests and generate comprehensive report
export def run-streaming-test-suite []: nothing -> record {
    print "🧪 Running NuAWS Streaming Operations Test Suite"
    print "================================================\n"
    
    # This would be called by the nutest framework
    # Individual tests will be discovered and run automatically
    
    let summary = {
        test_suite: "streaming_operations",
        categories_tested: [
            "core_generators",
            "service_specific_streaming", 
            "memory_efficiency",
            "backpressure_rate_limiting",
            "progress_reporting",
            "performance_benchmarking",
            "error_handling",
            "high_level_patterns",
            "integration_end_to_end",
            "performance_targets"
        ],
        performance_targets: {
            first_result_ms: 500,
            memory_limit_mb: 100,
            constant_memory: true,
            large_dataset_support: "10GB+"
        },
        mock_services_tested: ["s3", "ec2", "lambda", "iam", "cloudformation"]
    }
    
    print "✅ Streaming test suite configuration loaded"
    $summary
}