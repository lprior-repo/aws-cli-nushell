# Connection Pooling and Resource Management Implementation
# Provides intelligent connection management, pooling, and resource lifecycle optimization
# Supports connection reuse, pool sizing, health monitoring, and multi-service management

use cache/memory.nu *
use cache/metrics.nu *
use adaptive_concurrency.nu analyze-resource-constraints

# Default connection pool configuration
const DEFAULT_POOL_CONFIG = {
    max_connections: 10,
    min_connections: 2,
    connection_timeout: 30sec,
    idle_timeout: 300sec,
    health_check_interval: 60sec,
    scale_up_threshold: 0.8,
    scale_down_threshold: 0.3,
    connection_lifetime: 600sec,
    cleanup_interval: 60sec,
    optimization_interval: 300sec,
    resource_threshold: 0.8,
    error_threshold: 0.2,
    circuit_breaker_enabled: true,
    resource_aware: true,
    metrics_collection_interval: 30sec
}

# Create a new connection pool with specified configuration
export def create-connection-pool [config: record] {
    let pool_config = $DEFAULT_POOL_CONFIG | merge $config
    let creation_time = date now
    
    {
        config: $pool_config,
        max_connections: $pool_config.max_connections,
        min_connections: $pool_config.min_connections,
        current_connections: 0,
        active_connections: 0,
        available_connections: 0,
        connections: [],
        created_at: $creation_time,
        last_optimization: $creation_time,
        pool_statistics: {
            total_acquisitions: 0,
            total_releases: 0,
            total_created: 0,
            total_destroyed: 0,
            total_health_checks: 0,
            average_acquisition_time: 0ms,
            pool_efficiency: 1.0,
            connection_reuse_rate: 0.0
        },
        service: $pool_config.service,
        circuit_breaker: {
            state: "closed",
            failure_count: 0,
            last_failure: null
        }
    }
}

# Acquire a connection from the pool
export def acquire-connection [pool: record] {
    let acquisition_start = date now
    
    # Check if pool has available connections
    if $pool.available_connections > 0 {
        # Reuse existing connection
        let connection_id = $"conn-($pool.pool_statistics.total_acquisitions)"
        let updated_pool = $pool | merge {
            active_connections: ($pool.active_connections + 1),
            available_connections: ($pool.available_connections - 1),
            pool_statistics: ($pool.pool_statistics | merge {
                total_acquisitions: ($pool.pool_statistics.total_acquisitions + 1)
            })
        }
        
        {
            success: true,
            connection_id: $connection_id,
            acquired_at: (date now),
            acquisition_time: ((date now) - $acquisition_start),
            updated_pool: $updated_pool,
            connection_source: "reused"
        }
    } else if $pool.current_connections < $pool.max_connections {
        # Create new connection
        let connection_id = $"conn-($pool.pool_statistics.total_created)"
        let new_connection = {
            connection_id: $connection_id,
            created_at: (date now),
            last_used: (date now),
            status: "active",
            health_score: 1.0,
            usage_count: 1
        }
        
        let updated_connections = $pool.connections | append $new_connection
        let updated_pool = $pool | merge {
            current_connections: ($pool.current_connections + 1),
            active_connections: ($pool.active_connections + 1),
            connections: $updated_connections,
            pool_statistics: ($pool.pool_statistics | merge {
                total_acquisitions: ($pool.pool_statistics.total_acquisitions + 1),
                total_created: ($pool.pool_statistics.total_created + 1)
            })
        }
        
        {
            success: true,
            connection_id: $connection_id,
            acquired_at: (date now),
            acquisition_time: ((date now) - $acquisition_start),
            updated_pool: $updated_pool,
            connection_source: "created"
        }
    } else {
        # Pool exhausted
        {
            success: false,
            error: "Pool exhausted: no available connections",
            acquired_at: (date now),
            acquisition_time: ((date now) - $acquisition_start),
            updated_pool: $pool,
            connection_source: "none"
        }
    }
}

# Release a connection back to the pool
export def release-connection [pool: record, connection_id: string] {
    let release_start = date now
    
    # Find the connection
    let connection_exists = ($pool.connections | where connection_id == $connection_id | length) > 0
    
    if $connection_exists {
        # Update connection status
        let updated_connections = $pool.connections | each { |conn|
            if $conn.connection_id == $connection_id {
                $conn | merge {
                    last_used: (date now),
                    status: "idle",
                    usage_count: ($conn.usage_count + 1)
                }
            } else {
                $conn
            }
        }
        
        let updated_pool = $pool | merge {
            active_connections: ($pool.active_connections - 1),
            available_connections: ($pool.available_connections + 1),
            connections: $updated_connections,
            pool_statistics: ($pool.pool_statistics | merge {
                total_releases: ($pool.pool_statistics.total_releases + 1)
            })
        }
        
        {
            success: true,
            connection_id: $connection_id,
            released_at: (date now),
            release_time: ((date now) - $release_start),
            updated_pool: $updated_pool
        }
    } else {
        {
            success: false,
            error: $"Connection ($connection_id) not found in pool",
            released_at: (date now),
            release_time: ((date now) - $release_start),
            updated_pool: $pool
        }
    }
}

# Evaluate if pool should be scaled up or down
export def evaluate-pool-scaling [pool: record, pending_requests: list<record>] {
    let demand = $pending_requests | length
    let current_utilization = if $pool.max_connections > 0 {
        $pool.active_connections / $pool.max_connections
    } else {
        0.0
    }
    
    # Consider demand pressure alongside current utilization
    let demand_pressure = if $pool.current_connections > 0 {
        $demand / $pool.current_connections
    } else {
        $demand  # If no connections, demand pressure is just the demand
    }
    
    let scale_up_threshold = $pool.config.scale_up_threshold
    let scale_down_threshold = $pool.config.scale_down_threshold
    
    let action = if $current_utilization >= $scale_up_threshold or $demand_pressure > 2 {
        "scale_up"
    } else if $current_utilization <= $scale_down_threshold and $demand_pressure < 1 {
        "scale_down"
    } else {
        "maintain"
    }
    
    let target_size = match $action {
        "scale_up" => {
            let new_size = $pool.current_connections + ($demand / 2) | math round
            ([$new_size, $pool.max_connections] | math min)
        },
        "scale_down" => {
            let new_size = $pool.current_connections - 1
            ([$new_size, $pool.min_connections] | math max)
        },
        _ => ([$pool.current_connections, $pool.min_connections] | math max)
    }
    
    {
        action: $action,
        target_size: $target_size,
        current_utilization: $current_utilization,
        demand: $demand,
        reasoning: $"Current utilization: ($current_utilization), threshold: ($scale_up_threshold)/($scale_down_threshold)"
    }
}

# Perform health check on connections
export def perform-health-check [pool: record, connections: list<record>] {
    let check_time = date now
    let health_threshold = $pool.config.idle_timeout
    
    mut healthy_connections = []
    mut unhealthy_connections = []
    mut recovery_actions = []
    
    for connection in $connections {
        let time_since_use = $check_time - $connection.last_used
        let is_healthy = $connection.status == "healthy" and $time_since_use < $health_threshold
        
        if $is_healthy {
            $healthy_connections = ($healthy_connections | append $connection)
        } else {
            $unhealthy_connections = ($unhealthy_connections | append $connection)
            $recovery_actions = ($recovery_actions | append {
                connection_id: $connection.connection_id,
                action: "reconnect",
                reason: (if $connection.status == "unhealthy" { "Connection marked unhealthy" } else { "Connection idle too long" })
            })
        }
    }
    
    {
        healthy_connections: $healthy_connections,
        unhealthy_connections: $unhealthy_connections,
        recovery_actions: $recovery_actions,
        health_check_time: $check_time,
        overall_health_score: (($healthy_connections | length) / ($connections | length))
    }
}

# Evaluate connection lifecycle and cleanup needs
export def evaluate-connection-lifecycle [pool: record, connections: list<record>] {
    let current_time = date now
    let lifetime_threshold = $pool.config.connection_lifetime
    
    mut expired_connections = []
    mut active_connections = []
    mut cleanup_actions = []
    
    for connection in $connections {
        let connection_age = $current_time - $connection.created_at
        let is_expired = $connection_age > $lifetime_threshold
        
        if $is_expired and $connection.status != "active" {
            $expired_connections = ($expired_connections | append $connection)
            $cleanup_actions = ($cleanup_actions | append {
                connection_id: $connection.connection_id,
                action: "cleanup",
                reason: $"Connection exceeded lifetime threshold (($connection_age) > ($lifetime_threshold))"
            })
        } else {
            $active_connections = ($active_connections | append $connection)
        }
    }
    
    {
        expired_connections: $expired_connections,
        active_connections: $active_connections,
        cleanup_actions: $cleanup_actions,
        lifecycle_check_time: $current_time
    }
}

# Optimize connection pool based on usage history
export def optimize-connection-pool [config: record, usage_history: list<record>] {
    let optimization_time = date now
    
    # Analyze usage patterns
    let avg_active_connections = $usage_history | get active_connections | math avg
    let peak_active_connections = $usage_history | get active_connections | math max
    let avg_request_count = $usage_history | get request_count | math avg
    
    # Calculate optimal pool size
    let optimal_size = ($peak_active_connections * 1.2) | math round
    let clamped_optimal = ([[$optimal_size, $config.min_connections] | math max, $config.max_connections] | math min)
    
    # Calculate efficiency score
    let utilization_efficiency = $avg_active_connections / $config.max_connections
    let throughput_efficiency = if $avg_request_count > 0 {
        [($avg_request_count / $config.max_connections), 1.0] | math min
    } else {
        0.5
    }
    let efficiency_score = ($utilization_efficiency + $throughput_efficiency) / 2.0
    
    {
        recommended_config: {
            optimal_size: $clamped_optimal,
            recommended_min: ([$config.min_connections, ($avg_active_connections * 0.5) | math round] | math min),
            recommended_max: ([$config.max_connections, ($peak_active_connections * 1.5) | math round] | math max)
        },
        optimization_reasoning: $"Based on average usage: ($avg_active_connections), peak: ($peak_active_connections)",
        efficiency_score: $efficiency_score,
        usage_analysis: {
            average_active: $avg_active_connections,
            peak_active: $peak_active_connections,
            average_requests: $avg_request_count
        },
        optimization_time: $optimization_time
    }
}

# Create multi-service connection pool
export def create-multi-service-connection-pool [service_configs: record] {
    let creation_time = date now
    mut service_pools = {}
    
    for service in ($service_configs | items {|service, config| {service: $service, config: $config}}) {
        let service_name = $service.service
        let service_config = $service.config | merge {service: $service_name}
        let pool = create-connection-pool $service_config
        $service_pools = ($service_pools | merge {$service_name: $pool})
    }
    
    {
        service_pools: $service_pools,
        created_at: $creation_time,
        global_statistics: {
            total_pools: ($service_configs | items {|k,v| $k} | length),
            total_max_connections: ($service_configs | values | get max_connections | math sum),
            total_min_connections: ($service_configs | values | get min_connections | math sum)
        },
        resource_allocation: {
            memory_per_service: {},
            cpu_per_service: {},
            network_per_service: {}
        }
    }
}

# Balance resources across multiple services
export def balance-cross-service-resources [multi_pool: record] {
    let balancing_time = date now
    let service_pools = $multi_pool.service_pools
    
    mut rebalancing_actions = []
    mut service_utilizations = []
    
    for service in ($service_pools | items {|service, pool| {service: $service, pool: $pool}}) {
        let service_name = $service.service
        let pool = $service.pool
        let utilization = if $pool.max_connections > 0 {
            $pool.active_connections / $pool.max_connections
        } else {
            0.0
        }
        
        $service_utilizations = ($service_utilizations | append {
            service: $service_name,
            utilization: $utilization,
            active_connections: $pool.active_connections,
            max_connections: $pool.max_connections
        })
        
        if $utilization > 0.9 {
            $rebalancing_actions = ($rebalancing_actions | append {
                service: $service_name,
                action: "increase_allocation",
                priority: "high",
                reason: $"High utilization: ($utilization)"
            })
        } else if $utilization < 0.2 {
            $rebalancing_actions = ($rebalancing_actions | append {
                service: $service_name,
                action: "decrease_allocation",
                priority: "low",
                reason: $"Low utilization: ($utilization)"
            })
        }
    }
    
    let overall_efficiency = $service_utilizations | get utilization | math avg
    
    {
        rebalancing_actions: $rebalancing_actions,
        resource_efficiency: $overall_efficiency,
        service_utilizations: $service_utilizations,
        balancing_time: $balancing_time
    }
}

# Collect performance metrics for connection pool
export def collect-pool-metrics [pool: record, usage_events: list<record>] {
    let metrics_time = date now
    
    # Calculate acquisition metrics
    let acquisition_events = $usage_events | where event == "connection_acquired"
    let avg_acquisition_time = if ($acquisition_events | length) > 0 {
        $acquisition_events | get duration | math avg
    } else {
        0ms
    }
    
    # Calculate utilization metrics
    let current_utilization = if $pool.max_connections > 0 {
        $pool.active_connections / $pool.max_connections
    } else {
        0.0
    }
    
    # Calculate performance metrics
    let pool_efficiency = if $pool.current_connections > 0 {
        $pool.active_connections / $pool.current_connections
    } else {
        1.0
    }
    
    let connection_reuse_rate = if $pool.pool_statistics.total_acquisitions > 0 {
        ($pool.pool_statistics.total_acquisitions - $pool.pool_statistics.total_created) / $pool.pool_statistics.total_acquisitions
    } else {
        0.0
    }
    
    # Health metrics
    let health_events = $usage_events | where event == "health_check_passed"
    let health_success_rate = if ($usage_events | where event =~ "health_check" | length) > 0 {
        ($health_events | length) / ($usage_events | where event =~ "health_check" | length)
    } else {
        1.0
    }
    
    {
        acquisition_metrics: {
            average_acquisition_time: $avg_acquisition_time,
            total_acquisitions: $pool.pool_statistics.total_acquisitions,
            total_releases: $pool.pool_statistics.total_releases
        },
        utilization_metrics: {
            current_utilization: $current_utilization,
            active_connections: $pool.active_connections,
            available_connections: $pool.available_connections,
            max_connections: $pool.max_connections
        },
        performance_metrics: {
            average_acquisition_time: $avg_acquisition_time,
            pool_efficiency: $pool_efficiency,
            connection_reuse_rate: $connection_reuse_rate
        },
        health_metrics: {
            health_success_rate: $health_success_rate,
            total_health_checks: ($usage_events | where event =~ "health_check" | length)
        },
        collection_time: $metrics_time
    }
}

# Handle connection errors and recovery
export def handle-connection-errors [pool: record, error_scenarios: list<record>] {
    let error_analysis_time = date now
    
    # Analyze error patterns
    let total_errors = $error_scenarios | get frequency | math sum
    let critical_errors = $error_scenarios | where impact == "critical" | get frequency | math sum
    let high_errors = $error_scenarios | where impact == "high" | get frequency | math sum
    
    let error_rate = if $pool.pool_statistics.total_acquisitions > 0 {
        $total_errors / $pool.pool_statistics.total_acquisitions
    } else {
        0.0
    }
    
    # Determine circuit breaker state
    let circuit_breaker_state = if $error_rate > $pool.config.error_threshold {
        "open"
    } else if $error_rate > ($pool.config.error_threshold * 0.5) {
        "half_open"
    } else {
        "closed"
    }
    
    # Generate recovery strategy
    mut immediate_actions = []
    mut preventive_measures = []
    
    if $critical_errors > 0 {
        $immediate_actions = ($immediate_actions | append "halt_new_connections")
        $immediate_actions = ($immediate_actions | append "perform_health_check_all")
    }
    
    if $high_errors > 2 {
        $immediate_actions = ($immediate_actions | append "reduce_pool_size")
        $preventive_measures = ($preventive_measures | append "increase_health_check_frequency")
    }
    
    if $error_rate > $pool.config.error_threshold {
        $preventive_measures = ($preventive_measures | append "implement_connection_retry")
        $preventive_measures = ($preventive_measures | append "add_connection_validation")
    }
    
    {
        error_analysis: {
            total_errors: $total_errors,
            error_rate: $error_rate,
            critical_errors: $critical_errors,
            high_errors: $high_errors,
            error_breakdown: $error_scenarios
        },
        recovery_strategy: {
            immediate_actions: $immediate_actions,
            preventive_measures: $preventive_measures
        },
        circuit_breaker_state: $circuit_breaker_state,
        analysis_time: $error_analysis_time
    }
}

# Analyze resource constraints for pool sizing
export def analyze-resource-constraints-for-pool [pool_config: record, system_resources: record] {
    let analysis_time = date now
    
    # Calculate resource-based limits
    let memory_limit = ($system_resources.available_memory / 100) | math round  # ~100MB per connection
    let fd_limit = ($system_resources.max_file_descriptors - $system_resources.open_file_descriptors) / 2  # Conservative estimate
    let cpu_limit = if $system_resources.cpu_utilization > 80 {
        5  # Conservative when CPU is high
    } else {
        15  # More generous when CPU is available
    }
    
    # Find most limiting factor
    let resource_limits = [$memory_limit, $fd_limit, $cpu_limit]
    let most_limiting = $resource_limits | math min
    let recommended_size = ([$most_limiting, $pool_config.max_connections] | math min)
    
    # Identify limiting factors
    mut limiting_factors = []
    if $memory_limit == $most_limiting {
        $limiting_factors = ($limiting_factors | append "memory")
    }
    if $fd_limit == $most_limiting {
        $limiting_factors = ($limiting_factors | append "file_descriptors") 
    }
    if $cpu_limit == $most_limiting {
        $limiting_factors = ($limiting_factors | append "cpu_utilization")
    }
    
    {
        resource_limits: {
            memory_based_limit: $memory_limit,
            fd_based_limit: $fd_limit,
            cpu_based_limit: $cpu_limit
        },
        recommended_pool_size: $recommended_size,
        limiting_factors: $limiting_factors,
        resource_efficiency: {
            memory_efficiency: ($system_resources.available_memory / 16000),
            cpu_efficiency: ((100 - $system_resources.cpu_utilization) / 100),
            fd_efficiency: (($system_resources.max_file_descriptors - $system_resources.open_file_descriptors) / $system_resources.max_file_descriptors)
        },
        analysis_time: $analysis_time
    }
}