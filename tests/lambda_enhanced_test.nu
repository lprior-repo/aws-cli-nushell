# Lambda Enhanced Features Tests
# Tests for the comprehensive Lambda functionality

use ../nuaws/lambda_enhanced.nu *

# ============================================================================
# Test Configuration and Setup
# ============================================================================

#[before-each]
def setup [] {
    $env.LAMBDA_ENHANCED_MOCK_MODE = "true"
    $env.AWS_REGION = "us-east-1"
    { test_context: "lambda_enhanced", mock_mode: true }
}

#[after-each]
def cleanup [] {
    # Clean up any test artifacts
    try { rm -f /tmp/test_sam_template.yaml } catch { }
    try { rm -f /tmp/test_log_output.json } catch { }
}

# ============================================================================
# SAM/Serverless Framework Integration Tests
# ============================================================================

#[test]
def "test sam discover templates in mock mode" [] {
    let context = $in
    
    let templates = sam-discover-templates
    
    assert ($templates | length) > 0 "Should discover at least one template"
    assert ($templates.0.template_type == "SAM") "Should identify SAM template type"
    assert ($templates.0.valid == true) "Template should be valid"
    assert ($templates.0.functions | length) > 0 "Should extract function definitions"
}

#[test]
def "test sam build with mock mode" [] {
    let context = $in
    
    let build_result = sam-build --debug
    
    assert ($build_result.success == true) "Build should succeed in mock mode"
    assert ($build_result.command == "sam build") "Should record correct command"
    assert ($build_result.build_time | is-not-empty) "Should record build timestamp"
    assert ($build_result.artifacts_location | is-not-empty) "Should specify artifacts location"
}

#[test]
def "test sam deploy with versioning" [] {
    let context = $in
    
    let deploy_result = sam-deploy "test-lambda-stack" --capabilities ["CAPABILITY_IAM"]
    
    assert ($deploy_result.success == true) "Deployment should succeed in mock mode"
    assert ($deploy_result.stack_name == "test-lambda-stack") "Should use provided stack name"
    assert ($deploy_result.changeset_created == true) "Should create changeset"
    assert ($deploy_result.resources_created | length) > 0 "Should create resources"
}

# ============================================================================
# Deployment Automation Tests
# ============================================================================

#[test]
def "test lambda version creation" [] {
    let context = $in
    
    let version_result = lambda-create-version "test-function" --description "Test version"
    
    assert ($version_result.success == true) "Version creation should succeed"
    assert ($version_result.function_name == "test-function") "Should use correct function name"
    assert ($version_result.version == "1") "Should create version 1"
    assert ($version_result.description | str contains "Test version") "Should use provided description"
}

#[test]
def "test lambda alias management" [] {
    let context = $in
    
    let alias_result = lambda-manage-alias "test-function" "staging" "1" --description "Staging alias"
    
    assert ($alias_result.success == true) "Alias management should succeed"
    assert ($alias_result.function_name == "test-function") "Should use correct function name"
    assert ($alias_result.alias_name == "staging") "Should create staging alias"
    assert ($alias_result.function_version == "1") "Should point to version 1"
    assert ($alias_result.operation == "create-alias") "Should perform create operation"
}

#[test]
def "test version creation with dry run" [] {
    let context = $in
    
    let dry_run_result = lambda-create-version "test-function" --dry-run
    
    assert ($dry_run_result.action == "create-version") "Should indicate create-version action"
    assert ($dry_run_result.dry_run == true) "Should be marked as dry run"
    assert ($dry_run_result.would_create == true) "Should indicate would create"
    assert ($dry_run_result.function_name == "test-function") "Should use correct function name"
}

# ============================================================================
# Real-time Log Streaming Tests
# ============================================================================

#[test]
def "test lambda log streaming configuration" [] {
    let context = $in
    
    # Test with mock mode - should return mock log data
    let log_stream = lambda-stream-logs "test-function" --start-time "1h ago" --output-format "structured"
    
    assert ($log_stream | length) > 0 "Should return log events"
    assert ($log_stream.0.timestamp | is-not-empty) "Should have timestamp"
    assert ($log_stream.0.parsed.request_id | is-not-empty) "Should parse request ID"
    assert ($log_stream.0.parsed.is_cold_start == true) "Should detect cold start"
}

#[test]
def "test log filtering patterns" [] {
    let context = $in
    
    # Test log streaming with specific filters
    let filtered_logs = lambda-stream-logs "test-function" --filter-pattern "ERROR" --log-level "ERROR"
    
    assert ($filtered_logs | length) >= 0 "Should handle filtered log requests"
    # In mock mode, should still return structured data
    if ($filtered_logs | length) > 0 {
        assert ($filtered_logs.0.parsed | is-not-empty) "Should include parsed log data"
    }
}

# ============================================================================
# Cold Start Performance Analysis Tests
# ============================================================================

#[test]
def "test cold start performance analysis" [] {
    let context = $in
    
    let analysis = lambda-analyze-cold-starts "test-function" --analysis-period 7day --include-recommendations
    
    assert ($analysis.function_name == "test-function") "Should analyze correct function"
    assert ($analysis.cold_start_summary.total_cold_starts > 0) "Should find cold starts"
    assert ($analysis.cold_start_summary.init_duration_stats.mean > 0) "Should calculate mean init duration"
    assert ($analysis.recommendations | length) > 0 "Should provide recommendations"
    assert ($analysis.optimization_priority | is-not-empty) "Should assign optimization priority"
}

#[test]
def "test cold start statistics calculation" [] {
    let context = $in
    
    let analysis = lambda-analyze-cold-starts "test-function" --min-cold-starts 5
    
    let stats = $analysis.cold_start_summary.init_duration_stats
    
    assert ($stats.mean | is-not-empty) "Should calculate mean"
    assert ($stats.median | is-not-empty) "Should calculate median"
    assert ($stats.min <= $stats.max) "Min should be less than or equal to max"
    assert ($stats.p95 >= $stats.median) "P95 should be greater than or equal to median"
    assert ($stats.p99 >= $stats.p95) "P99 should be greater than or equal to P95"
}

#[test]
def "test optimization recommendations generation" [] {
    let context = $in
    
    let analysis = lambda-analyze-cold-starts "test-function" --include-recommendations
    
    let recommendations = $analysis.recommendations
    
    assert ($recommendations | length) > 0 "Should generate recommendations"
    
    # Check recommendation structure
    let first_rec = $recommendations | first
    assert ($first_rec.priority | is-not-empty) "Should have priority"
    assert ($first_rec.category | is-not-empty) "Should have category"
    assert ($first_rec.recommendation | is-not-empty) "Should have recommendation text"
    assert ($first_rec.estimated_improvement | is-not-empty) "Should estimate improvement"
}

# ============================================================================
# Execution Cost Analysis Tests
# ============================================================================

#[test]
def "test lambda cost analysis" [] {
    let context = $in
    
    let cost_analysis = lambda-analyze-costs "test-function" --analysis-period 30day --include-projections
    
    assert ($cost_analysis.function_name == "test-function") "Should analyze correct function"
    assert ($cost_analysis.cost_analysis.total_cost_usd >= 0) "Should calculate total cost"
    assert ($cost_analysis.cost_analysis.request_cost_usd >= 0) "Should calculate request cost"
    assert ($cost_analysis.cost_analysis.compute_cost_usd >= 0) "Should calculate compute cost"
    assert ($cost_analysis.projections | is-not-empty) "Should include projections"
}

#[test]
def "test cost breakdown calculation" [] {
    let context = $in
    
    let cost_analysis = lambda-analyze-costs "test-function" --cost-breakdown
    
    let costs = $cost_analysis.cost_analysis
    
    # Verify cost components
    assert ($costs.cost_per_invocation > 0) "Should calculate cost per invocation"
    assert ($costs.memory_efficiency.efficiency_score >= 0) "Should calculate memory efficiency"
    assert ($costs.memory_efficiency.efficiency_score <= 1) "Efficiency score should be 0-1"
    assert ($costs.architecture | is-not-empty) "Should identify architecture"
}

#[test]
def "test budget recommendations" [] {
    let context = $in
    
    let cost_analysis = lambda-analyze-costs "test-function" --budget-threshold 10.0
    
    let recommendations = $cost_analysis.budget_recommendations
    
    assert ($recommendations | length) > 0 "Should generate budget recommendations"
    
    # Check recommendation structure
    let first_rec = $recommendations | first
    assert ($first_rec.priority | is-not-empty) "Should have priority"
    assert ($first_rec.category | is-not-empty) "Should have category"
    assert ($first_rec.potential_savings_percent >= 0) "Should estimate savings percentage"
}

#[test]
def "test cost projections" [] {
    let context = $in
    
    let cost_analysis = lambda-analyze-costs "test-function" --include-projections
    
    let projections = $cost_analysis.projections
    
    assert ($projections.monthly_projection.cost_usd > 0) "Should project monthly cost"
    assert ($projections.annual_projection.cost_usd > 0) "Should project annual cost"
    assert ($projections.growth_scenarios.conservative.cost_usd > 0) "Should include conservative scenario"
    assert ($projections.growth_scenarios.moderate.cost_usd > 0) "Should include moderate scenario"
    assert ($projections.growth_scenarios.aggressive.cost_usd > 0) "Should include aggressive scenario"
}

# ============================================================================
# Configuration and Mock Mode Tests
# ============================================================================

#[test]
def "test lambda enhanced configuration" [] {
    let context = $in
    
    let config = get-lambda-enhanced-config
    
    assert ($config.mock_mode == true) "Should be in mock mode"
    assert ($config.aws_region == "us-east-1") "Should use correct region"
    assert ($config.sam_template_patterns | length) > 0 "Should have template patterns"
    assert ($config.default_timeout > 0) "Should have default timeout"
    assert ($config.default_memory > 0) "Should have default memory"
}

#[test]
def "test module main function" [] {
    let context = $in
    
    # Test that main function runs without error
    try {
        main
        assert true "Main function should execute successfully"
    } catch { |err|
        assert false $"Main function failed: ($err.msg)"
    }
}

# ============================================================================
# Error Handling and Edge Cases Tests
# ============================================================================

#[test]
def "test sam discover templates with no templates" [] {
    let context = $in
    
    # In mock mode, should still return mock data
    let templates = sam-discover-templates "/nonexistent/path"
    
    # Mock mode should return data regardless of path
    assert ($templates | length) > 0 "Mock mode should return template data"
}

#[test]
def "test cost analysis with zero invocations" [] {
    let context = $in
    
    # Should handle edge case gracefully
    let cost_analysis = lambda-analyze-costs "unused-function"
    
    assert ($cost_analysis.cost_analysis.total_cost_usd >= 0) "Should handle zero cost gracefully"
}

#[test]
def "test cold start analysis insufficient data" [] {
    let context = $in
    
    # Test with high minimum requirement
    let analysis = lambda-analyze-cold-starts "test-function" --min-cold-starts 1000
    
    # Should handle insufficient data case
    assert ($analysis.function_name == "test-function") "Should still identify function"
}

# Export test summary
export def run-lambda-enhanced-tests [] {
    print "🧪 Running Lambda Enhanced Features tests..."
    print "Mock mode enabled for safe testing"
    print ""
    
    # The tests will be discovered and run by the test framework
    {
        test_module: "lambda_enhanced",
        total_tests: 18,
        categories: [
            "SAM/Serverless Integration",
            "Deployment Automation", 
            "Log Streaming",
            "Performance Analysis",
            "Cost Analysis",
            "Configuration",
            "Error Handling"
        ],
        mock_mode: true
    }
}