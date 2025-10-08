# Performance Metrics Implementation
# Collects and analyzes cache performance metrics
# Provides hit rates, response times, and efficiency analytics

# Get metrics state file path (supports test isolation)
def get-metrics-file [] {
    if "AWS_CACHE_TEST_SUFFIX" in $env {
        $"/tmp/aws_cli_nushell_metrics_state_($env.AWS_CACHE_TEST_SUFFIX).json"
    } else {
        "/tmp/aws_cli_nushell_metrics_state.json"
    }
}

# Initialize empty metrics state
def empty-metrics [] {
    {
        cache_hits: 0,
        cache_misses: 0,
        total_requests: 0,
        response_times: [],
        cache_hit_times: [],
        cache_miss_times: [],
        service_metrics: {},
        operation_metrics: {},
        start_time: (date now),
        thresholds: {
            max_cache_miss_rate: 0.8,
            max_avg_response_time: 500ms,
            min_cache_hit_rate: 0.3
        }
    }
}

# Load metrics state from persistent storage
def load-metrics-state [] {
    let metrics_file = get-metrics-file
    if ($metrics_file | path exists) {
        try {
            open $metrics_file
        } catch {
            empty-metrics
        }
    } else {
        empty-metrics
    }
}

# Save metrics state to persistent storage
def save-metrics-state [metrics: record] {
    let metrics_file = get-metrics-file
    $metrics | to json | save -f $metrics_file
}

# Initialize performance metrics tracking
export def init-performance-metrics [] {
    let initial_metrics = empty-metrics
    save-metrics-state $initial_metrics
    $initial_metrics
}

# Record a cache hit
export def record-cache-hit [
    service: string,
    operation: string
] {
    let metrics = load-metrics-state
    
    let updated_metrics = $metrics 
        | upsert cache_hits ($metrics.cache_hits + 1)
        | upsert total_requests ($metrics.total_requests + 1)
    
    # Update service-level metrics
    let service_key = $service
    let service_stats = if $service_key in $updated_metrics.service_metrics {
        $updated_metrics.service_metrics | get $service_key
    } else {
        {hits: 0, misses: 0, operations: {}}
    }
    let updated_service_stats = $service_stats | upsert hits ($service_stats.hits + 1)
    
    # Update operation-level metrics
    let op_key = $"($service):($operation)"
    let op_stats = if $op_key in $updated_metrics.operation_metrics {
        $updated_metrics.operation_metrics | get $op_key
    } else {
        {hits: 0, misses: 0}
    }
    let updated_op_stats = $op_stats | upsert hits ($op_stats.hits + 1)
    
    let final_metrics = $updated_metrics
        | upsert service_metrics ($updated_metrics.service_metrics | upsert $service_key $updated_service_stats)
        | upsert operation_metrics ($updated_metrics.operation_metrics | upsert $op_key $updated_op_stats)
    
    save-metrics-state $final_metrics
}

# Record a cache miss
export def record-cache-miss [
    service: string,
    operation: string
] {
    let metrics = load-metrics-state
    
    let updated_metrics = $metrics 
        | upsert cache_misses ($metrics.cache_misses + 1)
        | upsert total_requests ($metrics.total_requests + 1)
    
    # Update service-level metrics
    let service_key = $service
    let service_stats = if $service_key in $updated_metrics.service_metrics {
        $updated_metrics.service_metrics | get $service_key
    } else {
        {hits: 0, misses: 0, operations: {}}
    }
    let updated_service_stats = $service_stats | upsert misses ($service_stats.misses + 1)
    
    # Update operation-level metrics
    let op_key = $"($service):($operation)"
    let op_stats = if $op_key in $updated_metrics.operation_metrics {
        $updated_metrics.operation_metrics | get $op_key
    } else {
        {hits: 0, misses: 0}
    }
    let updated_op_stats = $op_stats | upsert misses ($op_stats.misses + 1)
    
    let final_metrics = $updated_metrics
        | upsert service_metrics ($updated_metrics.service_metrics | upsert $service_key $updated_service_stats)
        | upsert operation_metrics ($updated_metrics.operation_metrics | upsert $op_key $updated_op_stats)
    
    save-metrics-state $final_metrics
}

# Record operation timing
export def record-operation-timing [
    service: string,
    operation: string,
    response_time: duration,
    was_cache_hit: bool
] {
    let metrics = load-metrics-state
    
    let updated_response_times = $metrics.response_times | append $response_time
    let updated_metrics = if $was_cache_hit {
        let updated_hit_times = $metrics.cache_hit_times | append $response_time
        $metrics 
            | upsert response_times $updated_response_times
            | upsert cache_hit_times $updated_hit_times
    } else {
        let updated_miss_times = $metrics.cache_miss_times | append $response_time
        $metrics 
            | upsert response_times $updated_response_times
            | upsert cache_miss_times $updated_miss_times
    }
    
    save-metrics-state $updated_metrics
}

# Record cache storage metrics
export def record-cache-storage [
    cache_type: string,
    used_bytes: int,
    total_bytes: int
] {
    let metrics = load-metrics-state
    
    let storage_key = $"($cache_type)_storage"
    let storage_metrics = {
        used: $used_bytes,
        total: $total_bytes,
        utilization: ($used_bytes / $total_bytes),
        timestamp: (date now)
    }
    
    let updated_metrics = $metrics | upsert $storage_key $storage_metrics
    save-metrics-state $updated_metrics
}

# Get overall performance metrics
export def get-performance-metrics [] {
    let metrics = load-metrics-state
    
    let cache_hit_rate = if $metrics.total_requests > 0 {
        $metrics.cache_hits / $metrics.total_requests
    } else {
        0.0
    }
    
    let avg_response_time = if ($metrics.response_times | length) > 0 {
        $metrics.response_times | math avg
    } else {
        0ms
    }
    
    let cache_hit_avg_time = if ($metrics.cache_hit_times | length) > 0 {
        $metrics.cache_hit_times | math avg
    } else {
        0ms
    }
    
    let cache_miss_avg_time = if ($metrics.cache_miss_times | length) > 0 {
        $metrics.cache_miss_times | math avg
    } else {
        0ms
    }
    
    {
        cache_hit_rate: $cache_hit_rate,
        total_requests: $metrics.total_requests,
        cache_hits: $metrics.cache_hits,
        cache_misses: $metrics.cache_misses,
        avg_response_time: $avg_response_time,
        cache_hit_avg_time: $cache_hit_avg_time,
        cache_miss_avg_time: $cache_miss_avg_time,
        uptime: ((date now) - ($metrics.start_time | into datetime))
    }
}

# Get service-level metrics
export def get-service-metrics [
    service: string
] {
    let metrics = load-metrics-state
    
    if $service in $metrics.service_metrics {
        let service_stats = $metrics.service_metrics | get $service
        let total_requests = $service_stats.hits + $service_stats.misses
        let hit_rate = if $total_requests > 0 {
            $service_stats.hits / $total_requests
        } else {
            0.0
        }
        
        {
            service: $service,
            cache_hits: $service_stats.hits,
            cache_misses: $service_stats.misses,
            total_requests: $total_requests,
            cache_hit_rate: $hit_rate
        }
    } else {
        {
            service: $service,
            cache_hits: 0,
            cache_misses: 0,
            total_requests: 0,
            cache_hit_rate: 0.0
        }
    }
}

# Get operation-level metrics
export def get-operation-metrics [
    service: string,
    operation: string
] {
    let metrics = load-metrics-state
    let op_key = $"($service):($operation)"
    
    if $op_key in $metrics.operation_metrics {
        let op_stats = $metrics.operation_metrics | get $op_key
        let total_requests = $op_stats.hits + $op_stats.misses
        let hit_rate = if $total_requests > 0 {
            $op_stats.hits / $total_requests
        } else {
            0.0
        }
        
        {
            service: $service,
            operation: $operation,
            cache_hits: $op_stats.hits,
            cache_misses: $op_stats.misses,
            total_requests: $total_requests,
            cache_hit_rate: $hit_rate
        }
    } else {
        {
            service: $service,
            operation: $operation,
            cache_hits: 0,
            cache_misses: 0,
            total_requests: 0,
            cache_hit_rate: 0.0
        }
    }
}

# Get cache efficiency metrics
export def get-cache-efficiency-metrics [] {
    let metrics = load-metrics-state
    
    let memory_util = if "memory_storage" in $metrics {
        $metrics.memory_storage.utilization
    } else {
        0.0
    }
    
    let disk_util = if "disk_storage" in $metrics {
        $metrics.disk_storage.utilization
    } else {
        0.0
    }
    
    # Calculate time saved by caching
    let time_saved = if ($metrics.cache_hit_times | length) > 0 and ($metrics.cache_miss_times | length) > 0 {
        let avg_miss_time = $metrics.cache_miss_times | math avg
        let avg_hit_time = $metrics.cache_hit_times | math avg
        let savings_per_hit = $avg_miss_time - $avg_hit_time
        $savings_per_hit * $metrics.cache_hits
    } else {
        0ms
    }
    
    {
        memory_utilization: $memory_util,
        disk_utilization: $disk_util,
        time_saved: $time_saved,
        storage_efficiency: (($memory_util + $disk_util) / 2)
    }
}

# Get metrics for a specific time window
export def get-metrics-for-window [
    window: duration
] {
    # For simplicity, return current metrics
    # In a real implementation, we'd filter by timestamp
    let current_time = date now
    let window_start = $current_time - $window
    
    # For now, return all metrics as if they're in the window
    # In a production system, we'd store timestamped entries
    get-performance-metrics
}

# Set performance alert thresholds
export def set-performance-thresholds [
    thresholds: record
] {
    let metrics = load-metrics-state
    let updated_metrics = $metrics | upsert thresholds $thresholds
    save-metrics-state $updated_metrics
}

# Get performance alerts
export def get-performance-alerts [] {
    let metrics = load-metrics-state
    let current_metrics = get-performance-metrics
    let thresholds = $metrics.thresholds
    
    mut alerts = []
    
    # Check miss rate
    let miss_rate = if $current_metrics.total_requests > 0 {
        $current_metrics.cache_misses / $current_metrics.total_requests
    } else {
        0.0
    }
    
    if $miss_rate > $thresholds.max_cache_miss_rate {
        $alerts = ($alerts | append {
            type: "high_miss_rate",
            severity: "warning",
            message: $"Cache miss rate ($miss_rate) exceeds threshold ($thresholds.max_cache_miss_rate)",
            current_miss_rate: $miss_rate,
            threshold: $thresholds.max_cache_miss_rate
        })
    }
    
    # Check response time
    if $current_metrics.avg_response_time > $thresholds.max_avg_response_time {
        $alerts = ($alerts | append {
            type: "high_response_time",
            severity: "warning", 
            message: $"Average response time ($current_metrics.avg_response_time) exceeds threshold ($thresholds.max_avg_response_time)",
            current_time: $current_metrics.avg_response_time,
            threshold: $thresholds.max_avg_response_time
        })
    }
    
    # Check hit rate
    if $current_metrics.cache_hit_rate < $thresholds.min_cache_hit_rate {
        $alerts = ($alerts | append {
            type: "low_hit_rate",
            severity: "warning",
            message: $"Cache hit rate ($current_metrics.cache_hit_rate) below threshold ($thresholds.min_cache_hit_rate)",
            current_hit_rate: $current_metrics.cache_hit_rate,
            threshold: $thresholds.min_cache_hit_rate
        })
    }
    
    $alerts
}

# Export metrics as JSON
export def export-metrics-as-json [] {
    let metrics = get-performance-metrics
    $metrics | to json
}

# Export metrics as CSV
export def export-metrics-as-csv [] {
    let metrics = get-performance-metrics
    let csv_header = "metric,value"
    let csv_rows = [
        $"cache_hit_rate,($metrics.cache_hit_rate)",
        $"total_requests,($metrics.total_requests)",
        $"cache_hits,($metrics.cache_hits)",
        $"cache_misses,($metrics.cache_misses)",
        $"avg_response_time,($metrics.avg_response_time)"
    ]
    ([$csv_header] | append $csv_rows) | str join "\n"
}

# Export metrics in Prometheus format
export def export-metrics-as-prometheus [] {
    let metrics = get-performance-metrics
    [
        $"# HELP cache_hit_rate Cache hit rate percentage",
        $"# TYPE cache_hit_rate gauge",
        $"cache_hit_rate ($metrics.cache_hit_rate)",
        $"# HELP cache_requests_total Total cache requests",
        $"# TYPE cache_requests_total counter", 
        $"cache_requests_total ($metrics.total_requests)",
        $"# HELP cache_hits_total Total cache hits",
        $"# TYPE cache_hits_total counter",
        $"cache_hits_total ($metrics.cache_hits)"
    ] | str join "\n"
}

# Reset performance metrics
export def reset-performance-metrics [] {
    let fresh_metrics = empty-metrics
    save-metrics-state $fresh_metrics
}

# Save performance metrics to file
export def save-performance-metrics [] {
    # Already persistent, but this could backup to a different location
    let metrics = load-metrics-state
    let backup_file = $"/tmp/aws_metrics_backup_(date now | format date %Y%m%d_%H%M%S).json"
    $metrics | to json | save $backup_file
    $backup_file
}

# Load performance metrics from file
export def load-performance-metrics [] {
    # Metrics are automatically loaded from persistent storage
    load-metrics-state
}