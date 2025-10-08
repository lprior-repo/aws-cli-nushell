# Request Deduplication System Test Suite
# Tests for advanced request deduplication beyond basic batch functionality
# Tests smart deduplication strategies, cache-aware deduplication, and duplicate detection

use std assert
use ../../aws/cache/memory.nu *
use ../../aws/cache/disk.nu *
use ../../aws/batch.nu *
use ../../aws/deduplication.nu *

#[before-each]
def setup [] {
    # Create isolated environment for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    clear-memory-cache | ignore
    clear-disk-cache | ignore
    {test_context: "request_deduplication"}
}

#[test]
def test_advanced_deduplication_with_parameter_ordering [] {
    # RED: This will fail initially - advanced deduplication functions don't exist
    # Test that requests with same parameters in different order are deduplicated
    
    let requests_with_different_param_order = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Test", maxResults: 10}
        },
        {
            service: "stepfunctions", 
            operation: "list-executions",
            params: {maxResults: 10, stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Test"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Other", maxResults: 10}
        }
    ]
    
    let deduplicated = deduplicate-requests $requests_with_different_param_order
    
    # Should detect that first two requests are identical despite parameter order
    assert (($deduplicated.unique_requests | length) == 2) "Should deduplicate identical requests with different param order"
    assert (($deduplicated.duplicate_mapping | length) == 3) "Should track all original request mappings"
    
    let first_duplicate = $deduplicated.duplicate_mapping | where original_index == 1 | first
    assert ($first_duplicate.maps_to_index == 0) "Second request should map to first request"
}

#[test]
def test_semantic_deduplication [] {
    # Test deduplication based on semantic equivalence, not just exact matching
    
    let semantically_similar = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Test", maxResults: 100}
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Test"}  # maxResults defaults to 100
        }
    ]
    
    let deduplicated = deduplicate-requests-semantically $semantically_similar
    
    # Should detect semantic equivalence (missing maxResults = default 100)
    assert (($deduplicated.unique_requests | length) == 1) "Should deduplicate semantically equivalent requests"
    assert ($deduplicated.deduplication_strategy == "semantic") "Should use semantic deduplication strategy"
}

#[test]
def test_cache_aware_deduplication [] {
    # Test deduplication that considers cached vs non-cached requests
    
    # Pre-populate cache with one request
    let cached_request = {
        service: "stepfunctions",
        operation: "list-executions",
        params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Cached"}
    }
    
    # Simulate cache hit by executing once
    execute-single-request $cached_request | ignore
    
    let mixed_requests = [
        $cached_request,  # This should be in cache
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:NotCached"}
        },
        $cached_request   # Duplicate of cached request
    ]
    
    let deduplicated = deduplicate-requests-cache-aware $mixed_requests
    
    # Should prioritize cache hits and deduplicate accordingly
    assert (($deduplicated.cache_hits | length) == 2) "Should identify 2 cache hit opportunities"
    assert (($deduplicated.cache_misses | length) == 1) "Should identify 1 cache miss"
    assert (($deduplicated.execution_plan.cached_first == true)) "Should prioritize cached requests"
}

#[test]
def test_duplicate_detection_strategies [] {
    # Test different strategies for detecting duplicate requests
    
    let requests_with_various_duplicates = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:A"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:A"}  # Exact duplicate
        },
        {
            service: "stepfunctions", 
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:A", maxResults: 100}  # Default value explicit
        },
        {
            service: "lambda",
            operation: "list-functions",
            params: {}
        }
    ]
    
    # Test exact matching strategy
    let exact_dedup = detect-duplicates $requests_with_various_duplicates --strategy "exact"
    assert (($exact_dedup.duplicates | length) == 1) "Exact strategy should find 1 duplicate pair"
    
    # Test semantic matching strategy  
    let semantic_dedup = detect-duplicates $requests_with_various_duplicates --strategy "semantic"
    assert (($semantic_dedup.duplicates | length) == 2) "Semantic strategy should find 2 duplicate pairs"
    
    # Test hash-based strategy
    let hash_dedup = detect-duplicates $requests_with_various_duplicates --strategy "hash"
    assert (($hash_dedup.algorithm == "content_hash")) "Should use content hashing algorithm"
}

#[test]
def test_deduplication_performance_metrics [] {
    # Test performance tracking for deduplication operations
    
    let large_request_set = 0..49 | each { |i|
        let arn_suffix = if ($i mod 5) == 0 { "Duplicate" } else { $"Unique($i)" }
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: $"arn:aws:states:us-east-1:123456789012:stateMachine:($arn_suffix)"}
        }
    }
    
    let dedup_start = date now
    let deduplicated = deduplicate-requests-with-metrics $large_request_set
    let dedup_end = date now
    
    # Verify performance metrics
    assert ("metrics" in $deduplicated) "Should include performance metrics"
    assert ("deduplication_time" in $deduplicated.metrics) "Should track deduplication time"
    assert ("requests_processed" in $deduplicated.metrics) "Should track requests processed"
    assert ("duplicates_found" in $deduplicated.metrics) "Should track duplicates found"
    
    # Should find 9 duplicates (indices 5,10,15,20,25,30,35,40,45 duplicate index 0)
    assert ($deduplicated.metrics.duplicates_found == 9) "Should find 9 duplicate requests"
    assert ($deduplicated.metrics.requests_processed == 50) "Should process all 50 requests"
    assert ($deduplicated.metrics.deduplication_time < 1sec) "Should complete quickly"
}

#[test] 
def test_cross_service_deduplication [] {
    # Test deduplication across different AWS services
    
    let cross_service_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Test"}
        },
        {
            service: "lambda",
            operation: "list-functions", 
            params: {}
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Test"}  # Duplicate cross-service
        },
        {
            service: "lambda",
            operation: "list-functions",
            params: {}  # Duplicate cross-service
        }
    ]
    
    let deduplicated = deduplicate-cross-service-requests $cross_service_requests
    
    # Should deduplicate within each service
    assert (($deduplicated.by_service.stepfunctions | length) == 1) "Should dedupe stepfunctions requests"
    assert (($deduplicated.by_service.lambda | length) == 1) "Should dedupe lambda requests"
    assert (($deduplicated.total_unique | length) == 2) "Should have 2 unique requests total"
    assert ($deduplicated.cross_service_duplicates == 2) "Should identify 2 cross-service duplicates"
}

#[test]
def test_intelligent_deduplication_with_caching [] {
    # Test intelligent deduplication that optimizes for cache efficiency
    
    let requests_with_cache_potential = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Popular"}
        },
        {
            service: "stepfunctions",
            operation: "list-state-machines",
            params: {}
        },
        {
            service: "stepfunctions", 
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Popular"}  # Duplicate
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Rare"}
        }
    ]
    
    let intelligent_dedup = deduplicate-intelligently $requests_with_cache_potential
    
    # Should optimize execution order for cache efficiency
    assert ($intelligent_dedup.optimization_strategy == "cache_first") "Should use cache-first strategy"
    assert (($intelligent_dedup.execution_order | first).operation == "list-executions") "Should prioritize frequently requested operations"
    assert (($intelligent_dedup.cache_efficiency_score > 0.7)) "Should achieve high cache efficiency"
}

#[test]
def test_deduplication_with_temporal_considerations [] {
    # Test deduplication considering time-based factors
    
    let time_sensitive_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:TimeSensitive"},
            timestamp: (date now)
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:TimeSensitive"},
            timestamp: ((date now) + 10sec)  # Same request but later timestamp
        }
    ]
    
    let temporal_dedup = deduplicate-with-temporal-awareness $time_sensitive_requests --freshness-threshold 5sec
    
    # Should treat as different requests due to temporal distance
    assert (($temporal_dedup.unique_requests | length) == 2) "Should keep both requests due to temporal distance"
    assert ($temporal_dedup.temporal_strategy == "freshness_based") "Should use freshness-based temporal strategy"
    
    let close_temporal_dedup = deduplicate-with-temporal-awareness $time_sensitive_requests --freshness-threshold 30sec
    
    # Should deduplicate when within freshness threshold
    assert (($close_temporal_dedup.unique_requests | length) == 1) "Should deduplicate when within freshness threshold"
}

#[test]
def test_deduplication_result_consolidation [] {
    # Test consolidating results from deduplicated requests
    
    let duplicate_requests = [
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Consolidate"}
        },
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Consolidate"}  # Duplicate
        },
        {
            service: "stepfunctions",
            operation: "list-executions", 
            params: {stateMachineArn: "arn:aws:states:us-east-1:123456789012:stateMachine:Consolidate"}  # Another duplicate
        }
    ]
    
    # Execute with deduplication
    let dedup_results = execute-deduplicated-requests $duplicate_requests
    
    # Should execute only once but return results for all original requests
    assert (($dedup_results.execution_count == 1)) "Should execute only once"
    assert (($dedup_results.results | length) == 3) "Should return results for all 3 original requests"
    assert (($dedup_results.all_results_identical == true)) "All results should be identical"
    
    # Verify result mapping
    let result_0 = $dedup_results.results | get 0
    let result_1 = $dedup_results.results | get 1
    let result_2 = $dedup_results.results | get 2
    
    assert ($result_0.executions == $result_1.executions) "Results 0 and 1 should be identical"
    assert ($result_1.executions == $result_2.executions) "Results 1 and 2 should be identical"
    assert ($result_0.was_deduplicated == false) "First result should not be marked as deduplicated"
    assert ($result_1.was_deduplicated == true) "Second result should be marked as deduplicated"
    assert ($result_2.was_deduplicated == true) "Third result should be marked as deduplicated"
}