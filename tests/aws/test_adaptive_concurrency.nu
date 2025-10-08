# Adaptive Concurrency Algorithm Test Suite
# Tests for intelligent concurrency adjustment based on system performance
# Tests dynamic scaling, performance monitoring, and adaptive optimization

use std assert
use ../../aws/cache/memory.nu *
use ../../aws/cache/disk.nu *
use ../../aws/batch.nu *
use ../../aws/adaptive_concurrency.nu *

#[before-each]
def setup [] {
    # Create isolated environment for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    clear-memory-cache | ignore
    clear-disk-cache | ignore
    {test_context: "adaptive_concurrency"}
}

#[test]
def test_initial_concurrency_estimation [] {
    # RED: This will fail initially - adaptive concurrency functions don't exist
    # Test that the system can estimate optimal initial concurrency based on system characteristics
    
    let system_profile = {
        cpu_cores: 8,
        available_memory: 16000,  # MB
        network_bandwidth: 1000,  # Mbps
        target_service: "stepfunctions"
    }
    
    let initial_estimate = estimate-initial-concurrency $system_profile
    
    # Should provide reasonable initial estimate based on system resources
    assert ($initial_estimate.concurrency > 1) "Should suggest more than 1 concurrent request"
    assert ($initial_estimate.concurrency <= 20) "Should not exceed reasonable upper bound"
    assert ("reasoning" in $initial_estimate) "Should explain estimation reasoning"
    assert ("confidence" in $initial_estimate) "Should provide confidence level"
    
    # Verify reasoning includes system factors
    assert ($initial_estimate.reasoning | str contains "cpu") "Should consider CPU in reasoning"
    assert ($initial_estimate.confidence >= 0.5) "Should have reasonable confidence"
}

#[test]
def test_performance_based_concurrency_adjustment [] {
    # Test adaptive adjustment based on observed performance metrics
    
    let performance_history = [
        {concurrency: 2, avg_response_time: 150ms, error_rate: 0.0, throughput: 13.3},
        {concurrency: 4, avg_response_time: 180ms, error_rate: 0.05, throughput: 22.2},
        {concurrency: 6, avg_response_time: 250ms, error_rate: 0.1, throughput: 24.0},
        {concurrency: 8, avg_response_time: 400ms, error_rate: 0.2, throughput: 20.0}
    ]
    
    let adjustment = calculate-concurrency-adjustment $performance_history
    
    # Should detect that optimal concurrency is around 4-6 based on throughput vs errors
    assert ($adjustment.recommended_concurrency >= 4) "Should recommend at least 4"
    assert ($adjustment.recommended_concurrency <= 6) "Should not exceed 6 due to rising errors"
    assert ("trend_analysis" in $adjustment) "Should analyze performance trends"
    assert ($adjustment.adjustment_confidence > 0.7) "Should be confident in adjustment"
    
    # Should identify performance plateau and error threshold
    assert ($adjustment.trend_analysis.throughput_trend == "plateauing") "Should detect throughput plateau"
    assert ($adjustment.trend_analysis.error_trend == "increasing") "Should detect rising error rate"
}

#[test]
def test_real_time_concurrency_adaptation [] {
    # Test real-time adaptation during batch execution
    
    let large_batch = 0..19 | each { |i|
        {
            service: "stepfunctions",
            operation: "list-executions",
            params: {stateMachineArn: $"arn:aws:states:us-east-1:123456789012:stateMachine:Adaptive($i)"}
        }
    }
    
    # Execute with adaptive concurrency enabled
    let adaptive_result = execute-batch-with-adaptive-concurrency $large_batch --initial-concurrency 3
    
    # Verify adaptive behavior
    assert ("concurrency_adjustments" in $adaptive_result) "Should track concurrency changes"
    assert ("final_concurrency" in $adaptive_result) "Should report final concurrency level"
    assert ("performance_metrics" in $adaptive_result) "Should collect performance data"
    
    let adjustments = $adaptive_result.concurrency_adjustments
    assert (($adjustments | length) > 0) "Should make at least one adjustment"
    
    # Verify each adjustment has proper reasoning
    for adjustment in $adjustments {
        assert ("from_concurrency" in $adjustment) "Should track previous concurrency"
        assert ("to_concurrency" in $adjustment) "Should track new concurrency"
        assert ("reason" in $adjustment) "Should explain adjustment reason"
        assert ("timestamp" in $adjustment) "Should timestamp adjustments"
    }
}

#[test]
def test_service_specific_concurrency_profiles [] {
    # Test that different AWS services have different optimal concurrency patterns
    
    let stepfunctions_profile = get-service-concurrency-profile "stepfunctions"
    let lambda_profile = get-service-concurrency-profile "lambda"
    let s3_profile = get-service-concurrency-profile "s3"
    
    # Different services should have different characteristics
    assert ($stepfunctions_profile.max_recommended != $lambda_profile.max_recommended) "Services should have different limits"
    assert ("rate_limit_factor" in $stepfunctions_profile) "Should include rate limiting info"
    assert ("latency_sensitivity" in $lambda_profile) "Should include latency characteristics"
    
    # Step Functions typically has lower concurrency due to rate limits
    assert ($stepfunctions_profile.max_recommended <= 10) "Step Functions should have conservative limits"
    # Lambda can typically handle higher concurrency
    assert ($lambda_profile.max_recommended >= 20) "Lambda should support higher concurrency"
    
    # Verify profile completeness
    for profile in [$stepfunctions_profile, $lambda_profile, $s3_profile] {
        assert ("baseline_latency" in $profile) "Should have baseline latency"
        assert ("error_threshold" in $profile) "Should define error thresholds"
        assert ("scaling_strategy" in $profile) "Should specify scaling approach"
    }
}

#[test]
def test_error_rate_throttling [] {
    # Test that concurrency reduces when error rates exceed thresholds
    
    let high_error_scenario = {
        current_concurrency: 10,
        recent_metrics: [
            {error_rate: 0.15, response_time: 300ms, timestamp: (date now)},
            {error_rate: 0.22, response_time: 450ms, timestamp: ((date now) - 1sec)},
            {error_rate: 0.30, response_time: 600ms, timestamp: ((date now) - 2sec)}
        ],
        error_threshold: 0.20
    }
    
    let throttling_decision = evaluate-error-rate-throttling $high_error_scenario
    
    # Should aggressively reduce concurrency due to high error rate
    assert ($throttling_decision.action == "reduce") "Should decide to reduce concurrency"
    assert ($throttling_decision.new_concurrency < $high_error_scenario.current_concurrency) "Should lower concurrency"
    assert ($throttling_decision.severity == "high") "Should recognize high error severity"
    
    # Should provide specific reduction amount
    let reduction = $high_error_scenario.current_concurrency - $throttling_decision.new_concurrency
    assert ($reduction >= 3) "Should make significant reduction for high error rate"
    
    assert ("cooldown_period" in $throttling_decision) "Should specify cooldown period"
    assert ($throttling_decision.cooldown_period >= 10sec) "Should have reasonable cooldown"
}

#[test]
def test_latency_based_scaling [] {
    # Test concurrency adjustment based on response latency patterns
    
    let latency_scenarios = [
        {
            name: "low_latency",
            metrics: [
                {concurrency: 2, avg_latency: 100ms, p95_latency: 150ms},
                {concurrency: 4, avg_latency: 120ms, p95_latency: 180ms},
                {concurrency: 6, avg_latency: 140ms, p95_latency: 220ms}
            ]
        },
        {
            name: "degrading_latency", 
            metrics: [
                {concurrency: 2, avg_latency: 200ms, p95_latency: 300ms},
                {concurrency: 4, avg_latency: 400ms, p95_latency: 600ms},
                {concurrency: 6, avg_latency: 800ms, p95_latency: 1200ms}
            ]
        }
    ]
    
    for scenario in $latency_scenarios {
        let scaling_decision = analyze-latency-scaling $scenario.metrics
        
        if $scenario.name == "low_latency" {
            # Should allow scaling up with good latency
            assert ($scaling_decision.recommendation == "scale_up") "Should recommend scaling up for good latency"
            assert ($scaling_decision.confidence > 0.8) "Should be confident with consistent latency"
        } else {
            # Should recommend scaling down with degrading latency
            assert ($scaling_decision.recommendation == "scale_down") "Should recommend scaling down for poor latency"
            assert ("latency_degradation" in $scaling_decision) "Should detect latency degradation"
        }
        
        assert ("optimal_concurrency" in $scaling_decision) "Should suggest optimal level"
    }
}

#[test]
def test_adaptive_concurrency_controller [] {
    # Test the main adaptive concurrency controller that coordinates all adjustments
    
    let controller_config = {
        initial_concurrency: 4,
        adjustment_sensitivity: 0.7,  # How quickly to respond to changes
        max_concurrency: 15,
        min_concurrency: 1,
        measurement_window: 30sec
    }
    
    let controller = create-adaptive-concurrency-controller $controller_config
    
    # Verify controller initialization
    assert ($controller.current_concurrency == 4) "Should start with initial concurrency"
    assert ("metrics_history" in $controller) "Should track metrics history"
    assert ("adjustment_rules" in $controller) "Should have adjustment rules"
    
    # Simulate feeding performance data to controller
    let performance_update = {
        avg_response_time: 250ms,
        error_rate: 0.08,
        throughput: 18.5,
        p95_latency: 400ms,
        active_requests: 4
    }
    
    let updated_controller = update-concurrency-controller $controller $performance_update
    
    # Controller should make intelligent decisions
    assert ("last_adjustment" in $updated_controller) "Should track last adjustment"
    assert (($updated_controller.metrics_history | length) > 0) "Should accumulate metrics"
    
    # Verify adjustment logic
    if ($updated_controller.current_concurrency != $controller.current_concurrency) {
        assert ("adjustment_reason" in $updated_controller.last_adjustment) "Should explain adjustments"
    }
}

#[test]
def test_concurrency_burst_handling [] {
    # Test handling of sudden load spikes and burst scenarios
    
    let burst_scenario = {
        baseline_requests: 10,
        burst_requests: 50,
        current_concurrency: 3,
        time_window: 5sec
    }
    
    let burst_response = handle-concurrency-burst $burst_scenario
    
    # Should dynamically scale up for burst
    assert ($burst_response.burst_concurrency > $burst_scenario.current_concurrency) "Should increase concurrency for burst"
    assert ("burst_strategy" in $burst_response) "Should specify burst handling strategy"
    assert ("recovery_plan" in $burst_response) "Should plan recovery after burst"
    
    # Should be conservative to avoid overwhelming service
    assert ($burst_response.burst_concurrency <= 20) "Should not exceed reasonable burst limit"
    
    # Verify temporal aspects
    assert ("burst_duration" in $burst_response) "Should estimate burst duration"
    assert ("cooldown_strategy" in $burst_response) "Should plan post-burst cooldown"
}

#[test]
def test_concurrency_learning_system [] {
    # Test that the system learns optimal patterns over time
    
    let historical_data = [
        # Morning pattern - lower concurrency works well
        {time_period: "morning", optimal_concurrency: 3, success_rate: 0.98},
        # Afternoon pattern - higher concurrency needed
        {time_period: "afternoon", optimal_concurrency: 8, success_rate: 0.95},
        # Evening pattern - moderate concurrency
        {time_period: "evening", optimal_concurrency: 5, success_rate: 0.97}
    ]
    
    let learned_patterns = analyze-concurrency-patterns $historical_data
    
    # Should identify time-based patterns
    assert ("time_patterns" in $learned_patterns) "Should recognize time-based patterns"
    assert ("recommendations" in $learned_patterns) "Should provide pattern-based recommendations"
    
    let time_patterns = $learned_patterns.time_patterns
    assert (($time_patterns | length) == 3) "Should identify all three time periods"
    
    # Should recommend different concurrency for different times
    let morning_rec = $time_patterns | where period == "morning" | first
    let afternoon_rec = $time_patterns | where period == "afternoon" | first
    
    assert ($morning_rec.recommended_concurrency != $afternoon_rec.recommended_concurrency) "Should have different recommendations"
    assert ("confidence" in $morning_rec) "Should provide confidence levels"
}

#[test]
def test_circuit_breaker_integration [] {
    # Test integration with circuit breaker patterns for fault tolerance
    
    let circuit_config = {
        failure_threshold: 5,
        recovery_timeout: 30sec,
        half_open_test_requests: 2
    }
    
    let circuit_breaker = create-adaptive-circuit-breaker $circuit_config
    
    # Test normal operation
    assert ($circuit_breaker.state == "closed") "Should start in closed state"
    assert ($circuit_breaker.failure_count == 0) "Should start with zero failures"
    
    # Simulate failures
    mut updated_breaker = $circuit_breaker
    for i in 0..6 {
        $updated_breaker = (record-request-failure $updated_breaker)
    }
    
    # Should open circuit after threshold failures
    assert ($updated_breaker.state == "open") "Should open after threshold failures"
    assert ("concurrency_impact" in $updated_breaker) "Should affect concurrency decisions"
    
    # Should reduce concurrency when circuit is open
    assert ($updated_breaker.concurrency_impact.action == "suspend") "Should suspend when circuit open"
}

#[test]
def test_resource_aware_concurrency [] {
    # Test concurrency adjustment based on available system resources
    
    let resource_snapshot = {
        cpu_usage: 75.5,      # percentage
        memory_usage: 60.2,   # percentage  
        network_utilization: 45.0,  # percentage
        disk_io_wait: 8.5,    # percentage
        available_file_descriptors: 800
    }
    
    let resource_analysis = analyze-resource-constraints $resource_snapshot
    
    # Should consider all resource factors
    assert ("cpu_constraint" in $resource_analysis) "Should analyze CPU constraints"
    assert ("memory_constraint" in $resource_analysis) "Should analyze memory constraints"
    assert ("network_constraint" in $resource_analysis) "Should analyze network constraints"
    
    # Should provide resource-aware concurrency recommendation
    assert ("recommended_concurrency" in $resource_analysis) "Should recommend concurrency level"
    assert ("limiting_resource" in $resource_analysis) "Should identify bottleneck resource"
    
    # With high CPU usage, should be conservative
    if $resource_snapshot.cpu_usage > 70 {
        assert ($resource_analysis.cpu_constraint.severity == "high") "Should detect high CPU usage"
        assert ($resource_analysis.recommended_concurrency <= 8) "Should be conservative with high CPU"
    }
}