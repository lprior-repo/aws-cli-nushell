# Adaptive Concurrency Algorithm Implementation
# Intelligently adjusts concurrency levels based on system performance and response characteristics
# Provides dynamic scaling, performance monitoring, and adaptive optimization

use cache/memory.nu *
use cache/metrics.nu *
use batch.nu execute-single-request

# Service-specific concurrency profiles with rate limits and characteristics
const SERVICE_PROFILES = {
    stepfunctions: {
        max_recommended: 8,
        baseline_latency: 200ms,
        rate_limit_factor: 0.7,
        latency_sensitivity: "high",
        error_threshold: 0.15,
        scaling_strategy: "conservative"
    },
    lambda: {
        max_recommended: 25,
        baseline_latency: 100ms,
        rate_limit_factor: 0.9,
        latency_sensitivity: "medium",
        error_threshold: 0.10,
        scaling_strategy: "aggressive"
    },
    s3: {
        max_recommended: 50,
        baseline_latency: 80ms,
        rate_limit_factor: 0.95,
        latency_sensitivity: "low",
        error_threshold: 0.05,
        scaling_strategy: "aggressive"
    }
}

# Estimate initial concurrency based on system characteristics
export def estimate-initial-concurrency [system_profile: record] {
    let cpu_factor = [($system_profile.cpu_cores / 4), 2.0] | math min
    let memory_factor = [($system_profile.available_memory / 8000), 2.0] | math min
    let network_factor = [($system_profile.network_bandwidth / 500), 2.0] | math min
    
    # Get service-specific baseline
    let service_profile = if $system_profile.target_service in $SERVICE_PROFILES {
        $SERVICE_PROFILES | get $system_profile.target_service
    } else {
        $SERVICE_PROFILES.lambda  # Default fallback
    }
    
    let base_concurrency = $service_profile.max_recommended * 0.3
    let system_multiplier = ($cpu_factor + $memory_factor + $network_factor) / 3.0
    let estimated_concurrency = ($base_concurrency * $system_multiplier) | math round
    
    let clamped_concurrency = [[$estimated_concurrency, 2] | math max, $service_profile.max_recommended] | math min
    
    {
        concurrency: $clamped_concurrency,
        reasoning: $"Based on ($system_profile.cpu_cores) cpu cores, ($system_profile.available_memory)MB memory, ($system_profile.network_bandwidth)Mbps network",
        confidence: 0.75,
        factors: {
            cpu_factor: $cpu_factor,
            memory_factor: $memory_factor,
            network_factor: $network_factor,
            service_baseline: $base_concurrency
        }
    }
}

# Calculate concurrency adjustment based on performance history
export def calculate-concurrency-adjustment [performance_history: list<record>] {
    if ($performance_history | length) < 2 {
        return {
            recommended_concurrency: 4,
            adjustment_confidence: 0.3,
            trend_analysis: {throughput_trend: "insufficient_data", error_trend: "insufficient_data"}
        }
    }
    
    # Analyze throughput trend
    let throughputs = $performance_history | get throughput
    let max_throughput = $throughputs | math max
    let last_throughput = $throughputs | last
    let first_throughput = $throughputs | first
    
    let throughput_trend = if $last_throughput > ($max_throughput * 0.8) and $last_throughput < ($max_throughput * 1.05) {
        "plateauing"
    } else if $last_throughput > $first_throughput {
        "increasing"
    } else {
        "decreasing"
    }
    
    # Analyze error trend
    let error_rates = $performance_history | get error_rate
    let error_trend = if ($error_rates | last) > ($error_rates | first) {
        "increasing"
    } else {
        "decreasing"
    }
    
    # Find optimal point (highest throughput with acceptable error rate)
    let acceptable_entries = $performance_history | where error_rate <= 0.15
    let optimal_entry = if ($acceptable_entries | length) > 0 {
        $acceptable_entries | sort-by throughput -r | first
    } else {
        $performance_history | sort-by error_rate | first
    }
    
    let confidence = if $error_trend == "increasing" and $throughput_trend == "plateauing" {
        0.9
    } else if $error_trend == "decreasing" and $throughput_trend == "increasing" {
        0.8
    } else if $throughput_trend == "plateauing" {
        0.75
    } else if $throughput_trend == "increasing" {
        0.75
    } else {
        0.6
    }
    
    {
        recommended_concurrency: $optimal_entry.concurrency,
        adjustment_confidence: $confidence,
        trend_analysis: {
            throughput_trend: $throughput_trend,
            error_trend: $error_trend
        },
        optimal_point: $optimal_entry
    }
}

# Get service-specific concurrency profile
export def get-service-concurrency-profile [service: string] {
    if $service in $SERVICE_PROFILES {
        $SERVICE_PROFILES | get $service
    } else {
        # Return default profile for unknown services
        {
            max_recommended: 10,
            baseline_latency: 150ms,
            rate_limit_factor: 0.8,
            latency_sensitivity: "medium",
            error_threshold: 0.12,
            scaling_strategy: "moderate"
        }
    }
}

# Evaluate error rate throttling decisions
export def evaluate-error-rate-throttling [scenario: record] {
    let current_error_rate = $scenario.recent_metrics | get error_rate | math max
    let error_threshold = $scenario.error_threshold
    
    let severity = if $current_error_rate >= ($error_threshold * 1.5) {
        "high"
    } else if $current_error_rate > $error_threshold {
        "medium"
    } else {
        "low"
    }
    
    let action = if $current_error_rate > $error_threshold {
        "reduce"
    } else {
        "maintain"
    }
    
    let reduction_factor = match $severity {
        "high" => 0.5,   # Reduce by 50%
        "medium" => 0.7, # Reduce by 30%
        _ => 1.0         # No reduction
    }
    
    let new_concurrency = [(($scenario.current_concurrency * $reduction_factor) | math round), 1] | math max
    
    let cooldown_period = match $severity {
        "high" => 30sec,
        "medium" => 15sec,
        _ => 5sec
    }
    
    {
        action: $action,
        severity: $severity,
        new_concurrency: $new_concurrency,
        current_error_rate: $current_error_rate,
        cooldown_period: $cooldown_period,
        reasoning: $"Error rate ($current_error_rate) exceeds threshold ($error_threshold)"
    }
}

# Analyze latency-based scaling decisions
export def analyze-latency-scaling [metrics: list<record>] {
    if ($metrics | length) < 2 {
        return {
            recommendation: "maintain",
            confidence: 0.3,
            optimal_concurrency: 4
        }
    }
    
    # Calculate latency degradation
    let latencies = $metrics | get avg_latency
    let first_latency = $latencies | first
    let last_latency = $latencies | last
    let degradation_ratio = $last_latency / $first_latency
    
    let recommendation = if $degradation_ratio > 2.0 {
        "scale_down"
    } else if $degradation_ratio < 1.5 {
        "scale_up"
    } else {
        "maintain"
    }
    
    # Find optimal concurrency (lowest latency that's not an outlier)
    let sorted_by_latency = $metrics | sort-by avg_latency
    let optimal_metric = $sorted_by_latency | first
    
    let confidence = if $degradation_ratio > 2.0 or $degradation_ratio < 1.5 {
        0.9
    } else {
        0.6
    }
    
    let result = {
        recommendation: $recommendation,
        confidence: $confidence,
        optimal_concurrency: $optimal_metric.concurrency,
        latency_analysis: {
            degradation_ratio: $degradation_ratio,
            first_latency: $first_latency,
            last_latency: $last_latency
        }
    }
    
    if $degradation_ratio > 1.5 {
        $result | merge {latency_degradation: true}
    } else {
        $result
    }
}

# Create adaptive concurrency controller
export def create-adaptive-concurrency-controller [config: record] {
    {
        current_concurrency: $config.initial_concurrency,
        config: $config,
        metrics_history: [],
        adjustment_rules: {
            max_error_rate: 0.15,
            max_latency_increase: 2.0,
            min_throughput_increase: 0.1
        },
        last_adjustment: null,
        adjustment_count: 0,
        created_at: (date now)
    }
}

# Update concurrency controller with new performance data
export def update-concurrency-controller [controller: record, performance_update: record] {
    let updated_history = $controller.metrics_history | append ($performance_update | merge {timestamp: (date now)})
    let limited_history = if ($updated_history | length) > 10 {
        $updated_history | last 10
    } else {
        $updated_history
    }
    
    # Decide if adjustment is needed
    let should_adjust = ($updated_history | length) >= 3 and (
        $performance_update.error_rate > $controller.adjustment_rules.max_error_rate or
        ($performance_update.avg_response_time > (300ms)) or
        ($performance_update.throughput < 10.0)
    )
    
    let updated_controller = $controller | merge {
        metrics_history: $limited_history
    }
    
    if $should_adjust {
        let adjustment_decision = if $performance_update.error_rate > $controller.adjustment_rules.max_error_rate {
            {
                new_concurrency: ([($controller.current_concurrency - 2), 1] | math max),
                reason: "High error rate",
                direction: "decrease"
            }
        } else if $performance_update.avg_response_time > 400ms {
            {
                new_concurrency: ([($controller.current_concurrency - 1), 1] | math max),
                reason: "High latency",
                direction: "decrease"
            }
        } else {
            {
                new_concurrency: ([($controller.current_concurrency + 1), $controller.config.max_concurrency] | math min),
                reason: "Performance improvement opportunity",
                direction: "increase"
            }
        }
        
        $updated_controller | merge {
            current_concurrency: $adjustment_decision.new_concurrency,
            last_adjustment: ($adjustment_decision | merge {
                timestamp: (date now),
                from_concurrency: $controller.current_concurrency
            }),
            adjustment_count: ($controller.adjustment_count + 1)
        }
    } else {
        $updated_controller
    }
}

# Handle concurrency burst scenarios
export def handle-concurrency-burst [scenario: record] {
    let burst_intensity = $scenario.burst_requests / $scenario.baseline_requests
    let time_pressure = 10sec / $scenario.time_window  # Higher pressure for shorter windows
    
    # Calculate burst concurrency based on intensity and time pressure
    let burst_multiplier = [($burst_intensity * $time_pressure), 5.0] | math min
    let burst_concurrency = [(($scenario.current_concurrency * $burst_multiplier) | math round), 20] | math min
    
    let burst_strategy = if $burst_intensity > 3.0 {
        "aggressive_scaling"
    } else if $burst_intensity > 2.0 {
        "moderate_scaling"
    } else {
        "conservative_scaling"
    }
    
    {
        burst_concurrency: $burst_concurrency,
        burst_strategy: $burst_strategy,
        burst_duration: ($scenario.time_window * 1.5),  # Allow some overhead
        cooldown_strategy: "gradual_reduction",
        recovery_plan: {
            cooldown_duration: 30sec,
            target_concurrency: $scenario.current_concurrency,
            gradual_reduction: true
        },
        risk_assessment: {
            overload_risk: (if $burst_intensity > 4.0 { "high" } else { "medium" }),
            recommended_monitoring: "intensive"
        }
    }
}

# Analyze concurrency patterns from historical data
export def analyze-concurrency-patterns [historical_data: list<record>] {
    let patterns = $historical_data | each { |data|
        {
            period: $data.time_period,
            recommended_concurrency: $data.optimal_concurrency,
            confidence: $data.success_rate,
            sample_size: 1  # Simplified for this implementation
        }
    }
    
    let recommendations = $patterns | each { |pattern|
        {
            time_period: $pattern.period,
            concurrency_recommendation: $pattern.recommended_concurrency,
            confidence_level: $pattern.confidence,
            usage_notes: $"Optimal for ($pattern.period) workloads"
        }
    }
    
    {
        time_patterns: $patterns,
        recommendations: $recommendations,
        pattern_confidence: 0.8,
        learning_quality: "good"
    }
}

# Create adaptive circuit breaker
export def create-adaptive-circuit-breaker [config: record] {
    {
        state: "closed",
        failure_count: 0,
        success_count: 0,
        last_failure_time: null,
        config: $config,
        concurrency_impact: {
            action: "allow",
            multiplier: 1.0
        }
    }
}

# Record request failure in circuit breaker
export def record-request-failure [breaker: record] {
    let new_failure_count = $breaker.failure_count + 1
    let should_open = $new_failure_count >= $breaker.config.failure_threshold
    
    if $should_open {
        $breaker | merge {
            state: "open",
            failure_count: $new_failure_count,
            last_failure_time: (date now),
            concurrency_impact: {
                action: "suspend",
                multiplier: 0.0,
                reason: "Circuit breaker open due to failures"
            }
        }
    } else {
        $breaker | merge {
            failure_count: $new_failure_count,
            last_failure_time: (date now)
        }
    }
}

# Analyze resource constraints for concurrency decisions
export def analyze-resource-constraints [resource_snapshot: record] {
    # Analyze each resource constraint
    let cpu_constraint = {
        severity: (if $resource_snapshot.cpu_usage > 70 { "high" } else if $resource_snapshot.cpu_usage > 50 { "medium" } else { "low" }),
        utilization: $resource_snapshot.cpu_usage,
        recommended_limit: (if $resource_snapshot.cpu_usage > 70 { 4 } else if $resource_snapshot.cpu_usage > 50 { 8 } else { 15 })
    }
    
    let memory_constraint = {
        severity: (if $resource_snapshot.memory_usage > 85 { "high" } else if $resource_snapshot.memory_usage > 70 { "medium" } else { "low" }),
        utilization: $resource_snapshot.memory_usage,
        recommended_limit: (if $resource_snapshot.memory_usage > 85 { 3 } else if $resource_snapshot.memory_usage > 70 { 6 } else { 12 })
    }
    
    let network_constraint = {
        severity: (if $resource_snapshot.network_utilization > 90 { "high" } else if $resource_snapshot.network_utilization > 70 { "medium" } else { "low" }),
        utilization: $resource_snapshot.network_utilization,
        recommended_limit: (if $resource_snapshot.network_utilization > 90 { 5 } else if $resource_snapshot.network_utilization > 70 { 10 } else { 20 })
    }
    
    # Find most limiting resource
    let limits = [$cpu_constraint.recommended_limit, $memory_constraint.recommended_limit, $network_constraint.recommended_limit]
    let min_limit = $limits | math min
    
    let limiting_resource = if $min_limit == $cpu_constraint.recommended_limit {
        "cpu"
    } else if $min_limit == $memory_constraint.recommended_limit {
        "memory"  
    } else {
        "network"
    }
    
    {
        cpu_constraint: $cpu_constraint,
        memory_constraint: $memory_constraint,
        network_constraint: $network_constraint,
        recommended_concurrency: $min_limit,
        limiting_resource: $limiting_resource,
        overall_health: (if $min_limit < 5 { "poor" } else if $min_limit < 10 { "fair" } else { "good" })
    }
}

# Execute batch with adaptive concurrency
export def execute-batch-with-adaptive-concurrency [
    requests: list<record>,
    --initial-concurrency: int = 4
] {
    let start_time = date now
    mut current_concurrency = $initial_concurrency
    mut concurrency_adjustments = []
    mut all_results = []
    
    # Process requests in chunks, adapting concurrency based on performance
    let total_requests = $requests | length
    let chunk_size = $current_concurrency * 3  # Process 3x concurrency at a time
    let chunks = $requests | chunks $chunk_size
    
    for chunk in $chunks {
        let chunk_start = date now
        
        # Execute chunk with current concurrency level
        let chunk_results = $chunk | chunks $current_concurrency | each { |concurrency_group|
            $concurrency_group | par-each { |request|
                let request_start = date now
                let result = try {
                    execute-single-request $request
                } catch { |err|
                    {
                        error: $err.msg,
                        success: false,
                        request: $request
                    }
                }
                let request_end = date now
                $result | merge {
                    response_time: ($request_end - $request_start),
                    timestamp: $request_end
                }
            }
        } | flatten
        
        $all_results = ($all_results | append $chunk_results)
        
        let chunk_end = date now
        let chunk_duration = $chunk_end - $chunk_start
        
        # Analyze chunk performance and adjust concurrency
        let error_rate = ($chunk_results | where success == false | length) / ($chunk_results | length)
        let avg_response_time = $chunk_results | get response_time | math avg
        let throughput = ($chunk_results | length) / ($chunk_duration | into int) * 1000  # requests per second
        
        # Decide concurrency adjustment
        let new_concurrency = if $error_rate > 0.15 {
            # High error rate - reduce concurrency
            [($current_concurrency - 2), 1] | math max
        } else if $avg_response_time > 500ms {
            # High latency - reduce concurrency
            [($current_concurrency - 1), 1] | math max
        } else if $error_rate < 0.05 and $avg_response_time < 200ms {
            # Good performance - increase concurrency
            [($current_concurrency + 1), 15] | math min
        } else {
            $current_concurrency
        }
        
        # Record adjustment if changed
        if $new_concurrency != $current_concurrency {
            $concurrency_adjustments = ($concurrency_adjustments | append {
                from_concurrency: $current_concurrency,
                to_concurrency: $new_concurrency,
                reason: (if $error_rate > 0.15 { "high_error_rate" } else if $avg_response_time > 500ms { "high_latency" } else { "performance_optimization" }),
                timestamp: $chunk_end,
                performance_metrics: {
                    error_rate: $error_rate,
                    avg_response_time: $avg_response_time,
                    throughput: $throughput
                }
            })
            $current_concurrency = $new_concurrency
        }
    }
    
    let end_time = date now
    let total_duration = $end_time - $start_time
    
    {
        results: $all_results,
        concurrency_adjustments: $concurrency_adjustments,
        final_concurrency: $current_concurrency,
        performance_metrics: {
            total_requests: $total_requests,
            total_duration: $total_duration,
            final_error_rate: (($all_results | where success == false | length) / $total_requests),
            avg_throughput: ($total_requests / ($total_duration | into int) * 1000)
        },
        adaptive_summary: {
            started_with: $initial_concurrency,
            ended_with: $current_concurrency,
            adjustments_made: ($concurrency_adjustments | length),
            performance_trend: (if $current_concurrency > $initial_concurrency { "improving" } else if $current_concurrency < $initial_concurrency { "degrading" } else { "stable" })
        }
    }
}