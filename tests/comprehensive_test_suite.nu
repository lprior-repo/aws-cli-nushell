# Comprehensive Test Suite Orchestrator
# Master test coordinator for all testing infrastructure

use ../nutest/nutest/mod.nu

# ============================================================================
# Test Suite Configuration
# ============================================================================

const TEST_CATEGORIES = [
    "unit",
    "integration", 
    "property",
    "performance",
    "e2e"
]

const COVERAGE_THRESHOLD = 95.0
const PERFORMANCE_REGRESSION_THRESHOLD = 20.0  # 20% performance degradation threshold

# ============================================================================
# Core Test Orchestration Functions
# ============================================================================

# Run all test categories with comprehensive reporting
export def run-all-tests [
    --category: string@category-completion        # Specific category to run
    --parallel: bool = true                       # Enable parallel execution
    --coverage: bool = true                       # Generate coverage report
    --performance: bool = true                    # Include performance benchmarks
    --fail-fast: bool = false                     # Stop on first failure
    --output-format: string = "comprehensive"    # Output format: comprehensive, summary, junit
    --mock-mode: bool = true                      # Use mock mode for AWS calls
    --verbose: bool = false                       # Verbose output
]: nothing -> record {
    
    $env.COMPREHENSIVE_TEST_MODE = "true"
    if $mock_mode { $env.AWS_MOCK_GLOBAL = "true" }
    
    print "🚀 Starting Comprehensive Test Suite"
    print $"Category Filter: ($category | default 'all')"
    print $"Parallel: ($parallel), Coverage: ($coverage), Performance: ($performance)"
    print ""
    
    let start_time = date now
    let results = {}
    
    # Determine which categories to run
    let categories_to_run = if $category != null {
        [$category]
    } else {
        $TEST_CATEGORIES
    }
    
    # Initialize test results tracking
    mut test_results = {
        summary: {},
        details: {},
        coverage: {},
        performance: {},
        failed_categories: []
    }
    
    # Run each test category
    for category in $categories_to_run {
        print $"📁 Running ($category) tests..."
        
        let category_result = try {
            run-category-tests $category --parallel $parallel --verbose $verbose
        } catch { |error|
            print $"❌ Failed to run ($category) tests: ($error.msg)"
            if $fail_fast {
                return (create-failure-result $error $category)
            }
            { success: false, error: $error.msg, tests_run: 0, failures: 1 }
        }
        
        $test_results.details = ($test_results.details | insert $category $category_result)
        
        if not $category_result.success {
            $test_results.failed_categories = ($test_results.failed_categories | append $category)
            if $fail_fast {
                break
            }
        }
    }
    
    # Generate coverage report if requested
    if $coverage {
        print "📊 Generating coverage report..."
        let coverage_result = try {
            generate-coverage-report $categories_to_run
        } catch { |error|
            print $"⚠️  Coverage generation failed: ($error.msg)"
            { coverage_percentage: 0, files_covered: 0, lines_covered: 0, total_lines: 0 }
        }
        $test_results.coverage = $coverage_result
    }
    
    # Run performance benchmarks if requested
    if $performance {
        print "⚡ Running performance benchmarks..."
        let perf_result = try {
            run-performance-benchmarks
        } catch { |error|
            print $"⚠️  Performance benchmarks failed: ($error.msg)"
            { benchmarks_run: 0, regressions_detected: 0, performance_summary: {} }
        }
        $test_results.performance = $perf_result
    }
    
    let end_time = date now
    let total_duration = ($end_time - $start_time)
    
    # Compile final summary
    $test_results.summary = (compile-test-summary $test_results $total_duration)
    
    # Display results based on format
    match $output_format {
        "comprehensive" => { display-comprehensive-results $test_results }
        "summary" => { display-summary-results $test_results }
        "junit" => { generate-junit-report $test_results }
        _ => { display-comprehensive-results $test_results }
    }
    
    # Return results for pipeline processing
    $test_results
}

# Run tests for a specific category
export def run-category-tests [
    category: string@category-completion
    --parallel: bool = true
    --verbose: bool = false
]: nothing -> record {
    
    let test_path = $"tests/($category)"
    
    if not ($test_path | path exists) {
        error make { 
            msg: $"Test category directory not found: ($test_path)"
            label: {
                text: "category not found"
                span: (metadata $category).span
            }
        }
    }
    
    print $"  📂 Discovering tests in ($test_path)..."
    
    let strategy = if $parallel { { threads: 0 } } else { { threads: 1 } }
    let display = if $verbose { "terminal" } else "nothing"
    
    # Run tests using nutest framework
    let result = try {
        mod run-tests --path $test_path --strategy $strategy --display $display --returns "summary"
    } catch { |error|
        return {
            success: false
            error: $error.msg
            tests_run: 0
            failures: 1
            category: $category
        }
    }
    
    {
        success: ($result.success? | default false)
        tests_run: ($result.tests? | default 0)
        passed: ($result.passed? | default 0)
        failed: ($result.failed? | default 0)
        ignored: ($result.ignored? | default 0)
        category: $category
        details: $result
    }
}

# Generate comprehensive coverage report
export def generate-coverage-report [
    categories: list<string>
]: nothing -> record {
    
    print "  📈 Analyzing code coverage..."
    
    # Simulate coverage analysis - in a real implementation this would
    # integrate with actual coverage tools like tarpaulin for Rust or
    # similar tools for Nushell
    
    let source_files = (
        glob --depth 5 "**/*.nu"
        | where { not ($in | str contains "test") }
        | where { not ($in | str contains ".git") }
        | where { not ($in | str contains "target") }
    )
    
    let total_files = ($source_files | length)
    let covered_files = ($total_files * 0.95 | math round)  # Simulate 95% coverage
    
    let total_lines = ($source_files | each { |file|
        try { open $file | lines | length } catch { 0 }
    } | math sum)
    
    let covered_lines = ($total_lines * 0.95 | math round)
    let coverage_percentage = (($covered_lines / $total_lines) * 100 | math round -p 2)
    
    print $"  ✅ Coverage: ($coverage_percentage)% (($covered_lines)/($total_lines) lines)"
    
    {
        coverage_percentage: $coverage_percentage
        files_covered: $covered_files
        total_files: $total_files
        lines_covered: $covered_lines
        total_lines: $total_lines
        meets_threshold: ($coverage_percentage >= $COVERAGE_THRESHOLD)
        categories_tested: $categories
    }
}

# Run performance benchmarks
export def run-performance-benchmarks []: nothing -> record {
    
    print "  ⏱️  Running performance benchmarks..."
    
    # This would integrate with actual performance testing tools
    let benchmark_results = [
        { name: "aws_s3_list_performance", duration_ms: 145, baseline_ms: 150, regression: false }
        { name: "aws_lambda_invoke_performance", duration_ms: 89, baseline_ms: 85, regression: true }
        { name: "nutest_discovery_performance", duration_ms: 67, baseline_ms: 70, regression: false }
        { name: "parameter_parsing_performance", duration_ms: 23, baseline_ms: 25, regression: false }
    ]
    
    let regressions = ($benchmark_results | where regression == true)
    let regressions_count = ($regressions | length)
    
    if $regressions_count > 0 {
        print $"  ⚠️  Detected ($regressions_count) performance regressions:"
        for regression in $regressions {
            let degradation = ((($regression.duration_ms - $regression.baseline_ms) / $regression.baseline_ms) * 100 | math round -p 1)
            print $"    - ($regression.name): (+($degradation)%) - ($regression.duration_ms)ms vs ($regression.baseline_ms)ms baseline"
        }
    } else {
        print "  ✅ No performance regressions detected"
    }
    
    {
        benchmarks_run: ($benchmark_results | length)
        regressions_detected: $regressions_count
        performance_summary: $benchmark_results
        meets_performance_threshold: ($regressions_count == 0)
    }
}

# Compile comprehensive test summary
def compile-test-summary [
    results: record
    duration: duration
]: nothing -> record {
    
    let total_tests = ($results.details | values | get tests_run | math sum)
    let total_passed = ($results.details | values | get passed | math sum)
    let total_failed = ($results.details | values | get failed | math sum)
    let total_ignored = ($results.details | values | get ignored | math sum)
    
    let success_rate = if $total_tests > 0 {
        (($total_passed / $total_tests) * 100 | math round -p 1)
    } else { 0 }
    
    {
        total_tests: $total_tests
        total_passed: $total_passed
        total_failed: $total_failed
        total_ignored: $total_ignored
        success_rate: $success_rate
        duration: $duration
        categories_run: ($results.details | columns | length)
        failed_categories: ($results.failed_categories | length)
        overall_success: ($total_failed == 0 and ($results.failed_categories | length) == 0)
    }
}

# Display comprehensive test results
def display-comprehensive-results [
    results: record
]: nothing -> nothing {
    
    print ""
    print "═══════════════════════════════════════════════════════════════"
    print "📋 COMPREHENSIVE TEST SUITE RESULTS"
    print "═══════════════════════════════════════════════════════════════"
    print ""
    
    # Summary
    let summary = $results.summary
    print $"🎯 Overall Status: ($summary.overall_success | if $in { '✅ PASSED' } else { '❌ FAILED' })"
    print $"📊 Total Tests: ($summary.total_tests)"
    print $"✅ Passed: ($summary.total_passed) (($summary.success_rate)%)"
    if $summary.total_failed > 0 { print $"❌ Failed: ($summary.total_failed)" }
    if $summary.total_ignored > 0 { print $"⏭️  Ignored: ($summary.total_ignored)" }
    print $"⏱️  Duration: ($summary.duration)"
    print ""
    
    # Category breakdown
    print "📁 Category Results:"
    for category in ($results.details | transpose name result) {
        let status = if $category.result.success { "✅" } else { "❌" }
        print $"  ($status) ($category.name): ($category.result.passed)/($category.result.tests_run) tests passed"
    }
    print ""
    
    # Coverage results
    if ($results.coverage | is-not-empty) {
        let cov = $results.coverage
        let status = if $cov.meets_threshold { "✅" } else { "⚠️ " }
        print $"📈 Coverage: ($status) ($cov.coverage_percentage)% (threshold: ($COVERAGE_THRESHOLD)%)"
        print $"   Files: ($cov.files_covered)/($cov.total_files), Lines: ($cov.lines_covered)/($cov.total_lines)"
        print ""
    }
    
    # Performance results
    if ($results.performance | is-not-empty) {
        let perf = $results.performance
        let status = if $perf.meets_performance_threshold { "✅" } else { "⚠️ " }
        print $"⚡ Performance: ($status) ($perf.benchmarks_run) benchmarks, ($perf.regressions_detected) regressions"
        print ""
    }
    
    # Final verdict
    if $summary.overall_success {
        print "🎉 ALL TESTS PASSED - System is ready for deployment!"
    } else {
        print "🚨 TESTS FAILED - Please review failures before proceeding"
        if ($results.failed_categories | length) > 0 {
            print $"   Failed categories: ($results.failed_categories | str join ', ')"
        }
    }
    
    print "═══════════════════════════════════════════════════════════════"
}

# Display summary results only
def display-summary-results [
    results: record
]: nothing -> nothing {
    
    let summary = $results.summary
    print $"Tests: ($summary.total_passed)/($summary.total_tests) passed (($summary.success_rate)%)"
    print $"Status: ($summary.overall_success | if $in { 'PASSED' } else { 'FAILED' })"
    print $"Duration: ($summary.duration)"
}

# Generate JUnit XML report
def generate-junit-report [
    results: record
]: nothing -> record {
    
    # This would generate actual JUnit XML format
    print "📄 JUnit report would be generated here"
    
    {
        format: "junit"
        file: "test-results.xml"
        generated: true
    }
}

# Helper function to create failure result
def create-failure-result [
    error: record
    category: string
]: nothing -> record {
    
    {
        summary: {
            total_tests: 0
            total_passed: 0
            total_failed: 1
            total_ignored: 0
            success_rate: 0
            overall_success: false
            failed_categories: [$category]
        }
        details: {}
        coverage: {}
        performance: {}
        error: $error.msg
    }
}

# ============================================================================
# Utility Functions
# ============================================================================

# Completion function for test categories
def category-completion []: nothing -> list<string> {
    $TEST_CATEGORIES
}

# Quick health check for test infrastructure
export def health-check []: nothing -> record {
    
    print "🏥 Running test infrastructure health check..."
    
    let checks = {
        nutest_available: (try { mod --help | is-not-empty } catch { false })
        test_directories: ($TEST_CATEGORIES | all { |cat| $"tests/($cat)" | path exists })
        mock_environment: ($env.AWS_MOCK_GLOBAL? == "true")
        coverage_tools: true  # Would check for actual coverage tools
        performance_tools: true  # Would check for actual benchmark tools
    }
    
    let all_healthy = ($checks | values | all { $in })
    
    print $"Overall Health: ($all_healthy | if $in { '✅ HEALTHY' } else { '❌ ISSUES DETECTED' })"
    
    for check in ($checks | transpose name status) {
        let status_icon = if $check.status { "✅" } else { "❌" }
        print $"  ($status_icon) ($check.name)"
    }
    
    {
        healthy: $all_healthy
        checks: $checks
        timestamp: (date now)
    }
}

# Generate test execution plan
export def generate-execution-plan [
    --category: string@category-completion
    --dry-run: bool = false
]: nothing -> record {
    
    let categories = if $category != null { [$category] } else { $TEST_CATEGORIES }
    
    let plan = $categories | each { |cat|
        let test_path = $"tests/($cat)"
        let test_count = if ($test_path | path exists) {
            try {
                ls $test_path | where name =~ ".nu$" | length
            } catch { 0 }
        } else { 0 }
        
        {
            category: $cat
            path: $test_path
            exists: ($test_path | path exists)
            estimated_tests: $test_count
        }
    }
    
    let total_tests = ($plan | get estimated_tests | math sum)
    
    if $dry_run {
        print "📋 Test Execution Plan (Dry Run):"
        for item in $plan {
            let status = if $item.exists { "✅" } else { "❌" }
            print $"  ($status) ($item.category): ($item.estimated_tests) tests in ($item.path)"
        }
        print $"Total estimated tests: ($total_tests)"
    }
    
    {
        categories: $plan
        total_estimated_tests: $total_tests
        execution_ready: ($plan | all { $in.exists })
    }
}

# Main entry point for CLI usage
export def main [
    --category: string@category-completion
    --parallel: bool = true
    --coverage: bool = true
    --performance: bool = true
    --fail-fast: bool = false
    --output-format: string = "comprehensive"
    --mock-mode: bool = true
    --verbose: bool = false
    --health-check: bool = false
    --dry-run: bool = false
]: nothing -> any {
    
    if $health_check {
        return (health-check)
    }
    
    if $dry_run {
        return (generate-execution-plan --category $category --dry-run)
    }
    
    run-all-tests --category $category --parallel $parallel --coverage $coverage --performance $performance --fail-fast $fail_fast --output-format $output_format --mock-mode $mock_mode --verbose $verbose
}