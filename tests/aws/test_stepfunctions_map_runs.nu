# Pure Unit Tests for Step Functions Map Run Operations
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions Map Run tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions Map Run tests"
}

# UNIT TEST: list-map-runs function
# Entry point: list-map-runs with execution ARN
# Exit point: returns list of map runs with metadata
# [test]
export def test_list_map_runs []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-map-test:test-execution"
    
    # Invoke the unit of work
    let result = list-map-runs $test_execution_arn
    
    # Check exit points
    assert_type $result "record" "list-map-runs should return record type"
    assert_contains ($result | columns) "map_runs" "list-map-runs should have map_runs field"
    assert_contains ($result | columns) "next_token" "list-map-runs should have next_token field"
    assert_type $result.map_runs "list" "map_runs field should be a list"
    assert_type $result.next_token "string" "next_token field should be a string"
}

# UNIT TEST: describe-map-run function
# Entry point: describe-map-run with map run ARN
# Exit point: returns map run details
# [test]
export def test_describe_map_run []: nothing -> nothing {
    let test_map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:nutest-map-test:test-map-run:12345678-1234-1234-1234-123456789012"
    
    # Invoke the unit of work
    let result = describe-map-run $test_map_run_arn
    
    # Check exit points
    assert_type $result "record" "describe-map-run should return record type"
    assert_contains ($result | columns) "mapRunArn" "Should have mapRunArn field"
    assert_contains ($result | columns) "executionArn" "Should have executionArn field"
    assert_contains ($result | columns) "status" "Should have status field"
    assert_equal $result.mapRunArn $test_map_run_arn "Should return the same map run ARN"
}

# UNIT TEST: update-map-run function
# Entry point: update-map-run with map run ARN
# Exit point: returns nothing (successful update)
# [test]
export def test_update_map_run []: nothing -> nothing {
    let test_map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:nutest-map-test:test-map-run:12345678-1234-1234-1234-123456789012"
    
    # Invoke the unit of work
    let result = update-map-run $test_map_run_arn
    
    # Check exit points
    assert_type $result "nothing" "update-map-run should return nothing type"
}

# UNIT TEST: update-map-run with max-concurrency
# Entry point: update-map-run with max-concurrency parameter
# Exit point: returns nothing with concurrency update
# [test]
export def test_update_map_run_with_concurrency []: nothing -> nothing {
    let test_map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:nutest-map-test:test-map-run:12345678-1234-1234-1234-123456789012"
    
    # Invoke the unit of work
    let result = update-map-run $test_map_run_arn --max-concurrency 10
    
    # Check exit points
    assert_type $result "nothing" "update-map-run with max-concurrency should return nothing type"
}

# UNIT TEST: update-map-run with failure tolerance
# Entry point: update-map-run with failure tolerance parameters
# Exit point: returns nothing with failure tolerance update
# [test]
export def test_update_map_run_with_failure_tolerance []: nothing -> nothing {
    let test_map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:nutest-map-test:test-map-run:12345678-1234-1234-1234-123456789012"
    
    # Invoke the unit of work
    let result = update-map-run $test_map_run_arn --tolerated-failure-percentage 5.0 --tolerated-failure-count 3
    
    # Check exit points
    assert_type $result "nothing" "update-map-run with failure tolerance should return nothing type"
}

# UNIT TEST: Map run workflow composition
# Entry point: Complete map run management functions
# Exit point: Verify data flow consistency through workflow
# [test]
export def test_map_run_workflow []: nothing -> nothing {
    let execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-map-workflow:test-execution"
    let map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:nutest-map-workflow:test-map-run:12345678-1234-1234-1234-123456789012"
    
    # 1. List map runs for execution
    let map_runs = list-map-runs $execution_arn
    assert_type $map_runs "record" "Map runs listing should return record"
    assert_contains ($map_runs | columns) "map_runs" "Should have map_runs field"
    assert_type $map_runs.map_runs "list" "map_runs should be a list"
    
    # 2. Describe a specific map run
    let map_run_details = describe-map-run $map_run_arn
    assert_type $map_run_details "record" "Map run description should return record"
    assert_contains ($map_run_details | columns) "mapRunArn" "Should have mapRunArn field"
    
    # 3. Update map run configuration
    let update1 = update-map-run $map_run_arn --max-concurrency 5 --tolerated-failure-percentage 2.0 --tolerated-failure-count 1
    assert_type $update1 "nothing" "First update should complete"
    
    # 4. Update with higher concurrency
    let update2 = update-map-run $map_run_arn --max-concurrency 20
    assert_type $update2 "nothing" "Second update should complete"
    
    # 5. Update with higher failure tolerance
    let update3 = update-map-run $map_run_arn --tolerated-failure-percentage 15.0 --tolerated-failure-count 10
    assert_type $update3 "nothing" "Third update should complete"
    
    # Verify ARN consistency
    assert_equal $map_run_details.mapRunArn $map_run_arn "ARNs should match"
}

# UNIT TEST: update-map-run parameter handling
# Entry point: update-map-run with various parameter values
# Exit point: returns nothing for all valid parameter combinations
# [test]
export def test_map_run_parameter_validation []: nothing -> nothing {
    let test_map_run_arn = "arn:aws:states:us-east-1:123456789012:mapRun:test:validation:12345678-1234-1234-1234-123456789012"
    
    # Test zero values
    let result1 = update-map-run $test_map_run_arn --max-concurrency 0 --tolerated-failure-percentage 0.0 --tolerated-failure-count 0
    assert_type $result1 "nothing" "Should handle zero values"
    
    # Test positive values
    let result2 = update-map-run $test_map_run_arn --max-concurrency 1 --tolerated-failure-percentage 0.1 --tolerated-failure-count 1
    assert_type $result2 "nothing" "Should handle positive values"
    
    # Test maximum percentage (100%)
    let result3 = update-map-run $test_map_run_arn --tolerated-failure-percentage 100.0
    assert_type $result3 "nothing" "Should handle maximum percentage"
    
    # Test high values
    let result4 = update-map-run $test_map_run_arn --max-concurrency 1000 --tolerated-failure-count 9999
    assert_type $result4 "nothing" "Should handle high values"
}

# UNIT TEST: ARN format handling
# Entry point: map run functions with different ARN formats
# Exit point: all functions accept valid ARN formats
# [test]
export def test_map_run_arn_formats []: nothing -> nothing {
    # Test different valid ARN formats for map runs
    let standard_arn = "arn:aws:states:us-east-1:123456789012:mapRun:TestStateMachine:execution-name:12345678-1234-1234-1234-123456789012"
    let complex_arn = "arn:aws:states:eu-west-1:999999999999:mapRun:Complex-State-Machine-Name:complex_execution_name_with_underscores:87654321-4321-4321-4321-210987654321"
    
    # Test standard ARN format
    let desc1 = describe-map-run $standard_arn
    assert_type $desc1 "record" "Standard ARN format should be accepted"
    assert_equal $desc1.mapRunArn $standard_arn "Should return same standard ARN"
    
    # Test complex ARN format
    let desc2 = describe-map-run $complex_arn
    assert_type $desc2 "record" "Complex ARN format should be accepted"
    assert_equal $desc2.mapRunArn $complex_arn "Should return same complex ARN"
    
    # Test updates with both formats
    let update1 = update-map-run $standard_arn
    assert_type $update1 "nothing" "Standard ARN format should work for updates"
    
    let update2 = update-map-run $complex_arn
    assert_type $update2 "nothing" "Complex ARN format should work for updates"
}