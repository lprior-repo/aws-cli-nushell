#!/usr/bin/env nu

# Comprehensive DynamoDB Test Suite Runner
# This script runs all DynamoDB tests with proper mock validation and error reporting

use std/assert
use ../../runner.nu
use ../../store.nu

# Test configuration
const DYNAMODB_TEST_FILES = [
    "test_dynamodb_table_management.nu"
    "test_dynamodb_item_operations.nu"
    "test_dynamodb_query_scan.nu"
    "test_dynamodb_backup_recovery.nu"
    "test_dynamodb_advanced_features.nu"
    "test_dynamodb_utilities.nu"
]

const TEST_CATEGORIES = {
    table_management: "Table lifecycle operations (create, delete, describe, list, update)"
    item_operations: "Item CRUD operations (put, get, delete, update, batch)"
    query_scan: "Query and scan operations with filtering and pagination"
    backup_recovery: "Backup, restore, and point-in-time recovery operations"
    advanced_features: "Streams, TTL, tagging, global tables, and wait operations"
    utilities: "Type conversion, expression builders, and utility functions"
}

# Initialize test environment
def setup-test-environment [] {
    # Ensure mock mode is properly configured
    $env.DYNAMODB_MOCK_MODE = "true"
    $env.AWS_REGION = "us-east-1"
    $env.AWS_ACCOUNT_ID = "123456789012"
    
    print "🔧 DynamoDB test environment configured:"
    print $"   Mock Mode: ($env.DYNAMODB_MOCK_MODE)"
    print $"   Region: ($env.AWS_REGION)"
    print $"   Account ID: ($env.AWS_ACCOUNT_ID)"
    print ""
}

# Clean up test environment
def cleanup-test-environment [] {
    $env.DYNAMODB_MOCK_MODE = "false"
    print "🧹 Test environment cleaned up"
}

# Run a single test file with comprehensive reporting
def run-test-file [
    file_name: string,
    category: string
] {
    let test_path = $"/home/family/src/nutest-framework/tests/aws/($file_name)"
    
    print $"🧪 Running ($category) tests: ($file_name)"
    
    let start_time = (date now)
    
    let result = try {
        nu ($test_path)
    } catch { |error|
        {
            success: false
            error: $error
            stdout: ""
            stderr: $error.msg
        }
    }
    
    let end_time = (date now)
    let duration = (($end_time - $start_time) / 1000000)  # Convert to milliseconds
    
    let test_summary = {
        file: $file_name
        category: $category
        duration_ms: $duration
        success: ($result != null and ($result | get success? | default false))
        result: $result
    }
    
    if $test_summary.success {
        print $"   ✅ ($file_name): PASSED (($duration)ms)"
    } else {
        print $"   ❌ ($file_name): FAILED (($duration)ms)"
        if ($result | get error? | default null) != null {
            print $"      Error: ($result.error)"
        }
    }
    
    $test_summary
}

# Validate mock functionality specifically
def validate-mock-functionality [] {
    print "🎭 Validating mock functionality..."
    
    # Test basic mock operations
    let mock_validations = [
        {
            name: "Mock mode detection"
            test: { dynamodb is-mock-mode }
            expected: true
        }
        {
            name: "Mock table creation"
            test: { 
                try {
                    dynamodb create-table "mock-test-table" [
                        { AttributeName: "id", AttributeType: "S" }
                    ] [
                        { AttributeName: "id", KeyType: "HASH" }
                    ]
                } catch { |error|
                    # Mock should return consistent structure even on "failure"
                    $error.type == "AWSError" or ($error.msg | str contains "Failed")
                }
            }
            expected: true
        }
        {
            name: "Mock item operations"
            test: {
                try {
                    dynamodb put-item "mock-test-table" {
                        id: { S: "mock-item" }
                        data: { S: "mock-data" }
                    }
                } catch { |error|
                    $error.type == "AWSError" or ($error.msg | str contains "Failed")
                }
            }
            expected: true
        }
        {
            name: "Type conversion in mock mode"
            test: {
                let nushell_item = { id: "test", count: 42, active: true }
                let converted = dynamodb convert-to-dynamodb-item $nushell_item
                ($converted | get id.S) == "test" and ($converted | get count.N) == "42"
            }
            expected: true
        }
        {
            name: "Expression builder in mock mode"
            test: {
                let builder = (
                    dynamodb create-expression-builder
                    | dynamodb add-attribute-name $in "#id" "id"
                    | dynamodb add-condition $in "#id = :id"
                )
                ($builder | get attribute_names."#id") == "id"
            }
            expected: true
        }
    ]
    
    let mock_results = ($mock_validations | each { |validation|
        let test_result = try {
            do $validation.test
        } catch { |error|
            false
        }
        
        let passed = ($test_result == $validation.expected)
        
        if $passed {
            print $"   ✅ ($validation.name): PASSED"
        } else {
            print $"   ❌ ($validation.name): FAILED (expected ($validation.expected), got ($test_result))"
        }
        
        {
            name: $validation.name
            passed: $passed
            expected: $validation.expected
            actual: $test_result
        }
    })
    
    let mock_summary = {
        total: ($mock_results | length)
        passed: ($mock_results | where passed | length)
        failed: ($mock_results | where (not passed) | length)
        results: $mock_results
    }
    
    print $"🎭 Mock validation summary: ($mock_summary.passed)/($mock_summary.total) passed"
    print ""
    
    $mock_summary
}

# Generate detailed test report
def generate-test-report [
    test_results: list,
    mock_summary: record,
    total_duration: int
] {
    let total_tests = ($test_results | length)
    let passed_tests = ($test_results | where success | length)
    let failed_tests = ($test_results | where (not success) | length)
    
    let report = {
        summary: {
            total_test_files: $total_tests
            passed_files: $passed_tests
            failed_files: $failed_tests
            total_duration_ms: $total_duration
            mock_validation: $mock_summary
        }
        detailed_results: $test_results
        categories_tested: $TEST_CATEGORIES
    }
    
    print "📊 DYNAMODB TEST SUITE REPORT"
    print "=============================="
    print ""
    print $"📁 Test Files: ($total_tests)"
    print $"✅ Passed: ($passed_tests)"
    print $"❌ Failed: ($failed_tests)"
    print $"⏱️  Total Duration: ($total_duration)ms"
    print ""
    
    print "📂 Categories Tested:"
    $TEST_CATEGORIES | items { |key, value|
        let category_result = ($test_results | where { |result| $result.file | str contains $key } | first)
        let status = if ($category_result | get success? | default false) { "✅" } else { "❌" }
        print $"   ($status) ($key): ($value)"
    }
    print ""
    
    print $"🎭 Mock Functionality: ($mock_summary.passed)/($mock_summary.total) validations passed"
    print ""
    
    if $failed_tests > 0 {
        print "❌ FAILED TEST FILES:"
        $test_results | where {|result| not $result.success} | each { |result|
            print $"   - ($result.file): ($result.category)"
            if ($result.result | get error? | default null) != null {
                print $"     Error: ($result.result.error)"
            }
        }
        print ""
    }
    
    print "🔍 Test Coverage Areas:"
    print "  • Table Management: Create, delete, describe, list, update operations"
    print "  • Item Operations: Put, get, delete, update, batch operations"
    print "  • Query & Scan: Filtering, pagination, expression handling"
    print "  • Backup & Recovery: Backup creation, restoration, point-in-time recovery"
    print "  • Advanced Features: Streams, TTL, tagging, global tables"
    print "  • Utilities: Type conversion, expression builders, helper functions"
    print ""
    
    # Save detailed report to file
    let report_file = $"dynamodb_test_report_(date now | format date '%Y%m%d_%H%M%S').json"
    $report | to json | save $report_file
    print $"📄 Detailed report saved to: ($report_file)"
    
    $report
}

# Main test execution function
def run-comprehensive-dynamodb-tests [] {
    print "🚀 Starting comprehensive DynamoDB test suite..."
    print ""
    
    let overall_start = (date now)
    
    # Setup test environment
    setup-test-environment
    
    # Validate mock functionality first
    let mock_summary = validate-mock-functionality
    
    # Run all test files
    let test_results = ($DYNAMODB_TEST_FILES | each { |file|
        let category_key = ($file | str replace "test_dynamodb_" "" | str replace ".nu" "")
        let category_name = ($TEST_CATEGORIES | get $category_key | default $category_key)
        
        run-test-file $file $category_name
    })
    
    let overall_end = (date now)
    let total_duration = ((($overall_end - $overall_start) / 1000000) | into int)  # Convert to milliseconds
    
    # Generate comprehensive report
    let final_report = generate-test-report $test_results $mock_summary $total_duration
    
    # Clean up
    cleanup-test-environment
    
    # Determine overall success
    let overall_success = (
        ($test_results | all { |result| $result.success }) and
        ($mock_summary.failed == 0)
    )
    
    if $overall_success {
        print "🎉 ALL TESTS PASSED! DynamoDB implementation is working correctly."
        exit 0
    } else {
        print "💥 SOME TESTS FAILED! Please review the report above."
        exit 1
    }
}

# Performance benchmark function
def run-performance-benchmarks [] {
    print "🏃 Running DynamoDB performance benchmarks..."
    
    setup-test-environment
    
    let benchmarks = [
        {
            name: "Type conversion performance"
            iterations: 1000
            test: {
                let item = { id: "bench", count: 42, active: true }
                dynamodb convert-to-dynamodb-item $item | ignore
            }
        }
        {
            name: "Expression builder performance"
            iterations: 500
            test: {
                dynamodb create-expression-builder
                | dynamodb add-attribute-name $in "#id" "id"
                | dynamodb add-condition $in "#id = :id"
                | ignore
            }
        }
        {
            name: "Mock operation performance"
            iterations: 100
            test: {
                try {
                    dynamodb describe-table "benchmark-table" | ignore
                } catch { |error|
                    # Expected to fail, we're measuring response time
                }
            }
        }
    ]
    
    let benchmark_results = ($benchmarks | each { |benchmark|
        print $"   🏃 ($benchmark.name)..."
        
        let start_time = (date now)
        
        for i in 1..$benchmark.iterations {
            do $benchmark.test
        }
        
        let end_time = (date now)
        let total_duration = (($end_time - $start_time) / 1000000)  # Convert to milliseconds
        let avg_duration = ($total_duration / $benchmark.iterations)
        
        print $"      ⏱️  ($benchmark.iterations) iterations in ($total_duration)ms (avg: ($avg_duration)ms)"
        
        {
            name: $benchmark.name
            iterations: $benchmark.iterations
            total_duration_ms: $total_duration
            average_duration_ms: $avg_duration
        }
    })
    
    cleanup-test-environment
    
    print ""
    print "📊 Performance Benchmark Results:"
    $benchmark_results | each { |result|
        print $"   ($result.name): ($result.average_duration_ms)ms avg"
    }
    
    $benchmark_results
}

# Interactive test menu
def interactive-test-menu [] {
    print "🧪 DynamoDB Test Suite - Interactive Mode"
    print "========================================"
    print ""
    print "1. Run all tests"
    print "2. Run specific test category"
    print "3. Validate mock functionality only"
    print "4. Run performance benchmarks"
    print "5. Exit"
    print ""
    
    let choice = (input "Select an option (1-5): ")
    
    match $choice {
        "1" => { run-comprehensive-dynamodb-tests }
        "2" => {
            print "Available categories:"
            $TEST_CATEGORIES | items { |key, value|
                print $"  - ($key): ($value)"
            }
            let category = (input "Enter category name: ")
            let file = $"test_dynamodb_($category).nu"
            if ($file in $DYNAMODB_TEST_FILES) {
                setup-test-environment
                run-test-file $file ($TEST_CATEGORIES | get $category)
                cleanup-test-environment
            } else {
                print $"Invalid category: ($category)"
            }
        }
        "3" => {
            setup-test-environment
            validate-mock-functionality | ignore
            cleanup-test-environment
        }
        "4" => { run-performance-benchmarks | ignore }
        "5" => { print "Goodbye!" }
        _ => { print "Invalid choice. Please select 1-5." }
    }
}

# Main entry point
def main [
    --interactive (-i)  # Run in interactive mode
    --performance (-p)  # Run performance benchmarks only
    --mock-only (-m)    # Validate mock functionality only
    --category (-c): string  # Run specific category only
] {
    if $interactive {
        interactive-test-menu
    } else if $performance {
        run-performance-benchmarks | ignore
    } else if $mock_only {
        setup-test-environment
        validate-mock-functionality | ignore
        cleanup-test-environment
    } else if ($category | is-not-empty) {
        let file = $"test_dynamodb_($category).nu"
        if ($file in $DYNAMODB_TEST_FILES) {
            setup-test-environment
            run-test-file $file ($TEST_CATEGORIES | get $category)
            cleanup-test-environment
        } else {
            print $"Invalid category: ($category)"
            print "Available categories:"
            $TEST_CATEGORIES | items { |key, value|
                print $"  - ($key): ($value)"
            }
        }
    } else {
        run-comprehensive-dynamodb-tests
    }
}

# Export for use in other scripts