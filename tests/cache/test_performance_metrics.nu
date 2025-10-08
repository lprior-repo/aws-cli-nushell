# Performance Metrics Test Suite
# Tests for performance metrics collection and reporting
# Tests cache hit rates, response times, and performance analytics

use std assert
use ../../aws/cache/memory.nu *
use ../../aws/cache/disk.nu *
use ../../aws/cache/keys.nu *
use ../../aws/cache/metrics.nu *

#[before-each]
def setup [] {
    # Create isolated cache for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    clear-memory-cache | ignore
    clear-disk-cache | ignore
    {test_context: "performance_metrics"}
}

#[test]
def test_cache_hit_rate_calculation [] {
    # RED: This will fail initially - metrics functions don't exist
    # Test cache hit rate calculation over multiple operations
    
    # Initialize metrics tracking
    init-performance-metrics
    
    # Simulate cache misses
    record-cache-miss "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    record-cache-miss "lambda" "list-functions"
    
    # Simulate cache hits
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-hit "lambda" "list-functions"
    
    # Get metrics
    let metrics = get-performance-metrics
    
    # Verify hit rate calculation (4 hits out of 6 total = 66.67%)
    assert ($metrics.cache_hit_rate >= 0.66) "Hit rate should be approximately 66%"
    assert ($metrics.cache_hit_rate <= 0.67) "Hit rate should be approximately 66%"
    assert ($metrics.total_requests == 6) "Total requests should be 6"
    assert ($metrics.cache_hits == 3) "Cache hits should be 3"
    assert ($metrics.cache_misses == 3) "Cache misses should be 3"
}

#[test]
def test_response_time_tracking [] {
    # Test tracking of response times for different operation types
    
    init-performance-metrics
    
    # Record response times
    record-operation-timing "stepfunctions" "list-executions" 150ms false
    record-operation-timing "stepfunctions" "list-executions" 25ms true
    record-operation-timing "stepfunctions" "list-state-machines" 200ms false
    record-operation-timing "stepfunctions" "list-state-machines" 15ms true
    
    let metrics = get-performance-metrics
    
    # Verify timing metrics
    assert ("avg_response_time" in $metrics) "Should track average response time"
    assert ("cache_hit_avg_time" in $metrics) "Should track cache hit average time"
    assert ("cache_miss_avg_time" in $metrics) "Should track cache miss average time"
    
    # Cache hits should be faster than misses
    assert ($metrics.cache_hit_avg_time < $metrics.cache_miss_avg_time) "Cache hits should be faster than misses"
    
    # Check reasonable ranges
    assert ($metrics.cache_hit_avg_time >= 15ms) "Cache hit time should be at least 15ms"
    assert ($metrics.cache_hit_avg_time <= 30ms) "Cache hit time should be at most 30ms"
    assert ($metrics.cache_miss_avg_time >= 150ms) "Cache miss time should be at least 150ms"
}

#[test]
def test_service_level_metrics [] {
    # Test metrics broken down by service
    
    init-performance-metrics
    
    # Record metrics for different services
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-hit "stepfunctions" "list-state-machines"
    record-cache-miss "stepfunctions" "describe-execution"
    
    record-cache-hit "lambda" "list-functions"
    record-cache-miss "lambda" "get-function"
    record-cache-miss "lambda" "list-layers"
    
    record-cache-hit "s3" "list-buckets"
    
    let metrics = get-service-metrics "stepfunctions"
    
    # Verify service-specific metrics
    assert ($metrics.service == "stepfunctions") "Should return stepfunctions metrics"
    assert ($metrics.cache_hits == 2) "StepFunctions should have 2 hits"
    assert ($metrics.cache_misses == 1) "StepFunctions should have 1 miss"
    assert ($metrics.cache_hit_rate >= 0.66) "StepFunctions hit rate should be ~66%"
    
    let lambda_metrics = get-service-metrics "lambda"
    assert ($lambda_metrics.cache_hits == 1) "Lambda should have 1 hit"
    assert ($lambda_metrics.cache_misses == 2) "Lambda should have 2 misses"
}

#[test]
def test_operation_level_metrics [] {
    # Test metrics broken down by operation
    
    init-performance-metrics
    
    # Record multiple calls to same operation
    record-cache-miss "stepfunctions" "list-executions"
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-hit "stepfunctions" "list-executions"
    
    # Record calls to different operation
    record-cache-miss "stepfunctions" "list-state-machines"
    record-cache-miss "stepfunctions" "list-state-machines"
    
    let exec_metrics = get-operation-metrics "stepfunctions" "list-executions"
    
    # Verify operation-specific metrics
    assert ($exec_metrics.operation == "list-executions") "Should return list-executions metrics"
    assert ($exec_metrics.cache_hits == 3) "list-executions should have 3 hits"
    assert ($exec_metrics.cache_misses == 1) "list-executions should have 1 miss"
    assert ($exec_metrics.cache_hit_rate == 0.75) "list-executions hit rate should be 75%"
    
    let sm_metrics = get-operation-metrics "stepfunctions" "list-state-machines"
    assert ($sm_metrics.cache_hits == 0) "list-state-machines should have 0 hits"
    assert ($sm_metrics.cache_misses == 2) "list-state-machines should have 2 misses"
    assert ($sm_metrics.cache_hit_rate == 0.0) "list-state-machines hit rate should be 0%"
}

#[test]
def test_cache_efficiency_metrics [] {
    # Test cache efficiency and utilization metrics
    
    init-performance-metrics
    
    # Simulate various cache operations
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    record-operation-timing "stepfunctions" "list-executions" 20ms true
    record-operation-timing "stepfunctions" "list-state-machines" 180ms false
    
    # Record cache storage metrics
    record-cache-storage "memory" 512 1024
    record-cache-storage "disk" 2048 10240
    
    let efficiency = get-cache-efficiency-metrics
    
    # Verify efficiency metrics
    assert ("memory_utilization" in $efficiency) "Should track memory utilization"
    assert ("disk_utilization" in $efficiency) "Should track disk utilization"
    assert ("time_saved" in $efficiency) "Should calculate time saved by caching"
    assert ("storage_efficiency" in $efficiency) "Should track storage efficiency"
    
    # Check memory utilization (512/1024 = 50%)
    assert ($efficiency.memory_utilization == 0.5) "Memory utilization should be 50%"
    
    # Check disk utilization (2048/10240 = 20%)
    assert ($efficiency.disk_utilization == 0.2) "Disk utilization should be 20%"
    
    # Time saved should be positive (180ms - 20ms = 160ms saved)
    assert ($efficiency.time_saved >= 150ms) "Should show time savings from cache hits"
}

#[test]
def test_metrics_time_window [] {
    # Test metrics over specific time windows
    
    init-performance-metrics
    
    # Record some initial metrics
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    
    # Wait briefly
    sleep 0.1sec
    
    # Record more metrics
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-hit "stepfunctions" "list-executions"
    
    # Get metrics for last 1 second
    let recent_metrics = get-metrics-for-window 1sec
    
    # Verify time-windowed metrics
    assert ($recent_metrics.cache_hits == 3) "Should include all hits in window"
    assert ($recent_metrics.cache_misses == 1) "Should include all misses in window"
    
    # Get metrics for very short window
    let very_recent = get-metrics-for-window 50ms
    
    # Should only include the last two hits
    assert ($very_recent.cache_hits == 2) "Should include only recent hits"
    assert ($very_recent.cache_misses == 0) "Should not include older misses"
}

#[test]
def test_performance_alerts [] {
    # Test performance alerting thresholds
    
    init-performance-metrics
    
    # Configure alert thresholds
    set-performance-thresholds {
        max_cache_miss_rate: 0.5,
        max_avg_response_time: 100ms,
        min_cache_hit_rate: 0.7
    }
    
    # Simulate poor performance (high miss rate)
    record-cache-miss "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    record-cache-miss "lambda" "list-functions"
    record-cache-hit "s3" "list-buckets"
    
    let alerts = get-performance-alerts
    
    # Verify alert generation
    assert (($alerts | length) > 0) "Should generate performance alerts"
    
    let miss_rate_alert = $alerts | where type == "high_miss_rate" | first
    assert ($miss_rate_alert.severity == "warning") "Should alert on high miss rate"
    assert ("current_miss_rate" in $miss_rate_alert) "Should include current miss rate"
}

#[test]
def test_metrics_export [] {
    # Test exporting metrics in various formats
    
    init-performance-metrics
    
    # Record some sample data
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    record-operation-timing "stepfunctions" "list-executions" 25ms true
    record-operation-timing "stepfunctions" "list-state-machines" 150ms false
    
    # Export in different formats
    let json_export = export-metrics-as-json
    let csv_export = export-metrics-as-csv
    let prometheus_export = export-metrics-as-prometheus
    
    # Verify exports
    assert (($json_export | from json | length) > 0) "JSON export should contain metrics"
    assert (($csv_export | lines | length) > 1) "CSV export should have header and data"
    assert ($prometheus_export | str contains "cache_hit_rate") "Prometheus export should contain metrics"
}

#[test]
def test_metrics_reset [] {
    # Test resetting metrics collection
    
    init-performance-metrics
    
    # Record some metrics
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    
    let metrics_before = get-performance-metrics
    assert ($metrics_before.total_requests == 2) "Should have recorded requests"
    
    # Reset metrics
    reset-performance-metrics
    
    let metrics_after = get-performance-metrics
    assert ($metrics_after.total_requests == 0) "Should have reset to zero"
    assert ($metrics_after.cache_hits == 0) "Should have reset hits to zero"
    assert ($metrics_after.cache_misses == 0) "Should have reset misses to zero"
}

#[test]
def test_metrics_persistence [] {
    # Test metrics persistence across sessions
    
    init-performance-metrics
    
    # Record some metrics
    record-cache-hit "stepfunctions" "list-executions"
    record-cache-miss "stepfunctions" "list-state-machines"
    
    # Save metrics
    save-performance-metrics
    
    # Simulate restart by resetting in-memory state
    reset-performance-metrics
    
    let metrics_empty = get-performance-metrics
    assert ($metrics_empty.total_requests == 0) "Should be empty after reset"
    
    # Load metrics
    load-performance-metrics
    
    let metrics_loaded = get-performance-metrics
    assert ($metrics_loaded.total_requests == 2) "Should restore saved metrics"
    assert ($metrics_loaded.cache_hits == 1) "Should restore hit count"
    assert ($metrics_loaded.cache_misses == 1) "Should restore miss count"
}