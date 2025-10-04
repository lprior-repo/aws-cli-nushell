# Pure Unit Tests for Step Functions - Isolated, Idempotent, Input/Output Testing
# Each test invokes a function through its entry point and checks one exit point

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up pure unit tests for Step Functions"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up pure unit tests for Step Functions"
}

# Unit Test: stepfunctions-config function returns correct structure
# Entry point: stepfunctions-config()
# Exit point: returns record with required fields
# [test]
export def test_stepfunctions_config_returns_record []: nothing -> nothing {
    let result = stepfunctions-config
    assert_type $result "record" "stepfunctions-config should return record type"
}

# Unit Test: stepfunctions-config function returns default type
# Entry point: stepfunctions-config()
# Exit point: type field equals "STANDARD"
# [test]
export def test_stepfunctions_config_default_type []: nothing -> nothing {
    let result = stepfunctions-config
    assert_equal $result.type "STANDARD" "Default type should be STANDARD"
}

# Unit Test: stepfunctions-config function returns empty name
# Entry point: stepfunctions-config()
# Exit point: name field is empty string
# [test]
export def test_stepfunctions_config_empty_name []: nothing -> nothing {
    let result = stepfunctions-config
    assert_equal $result.name "" "Default name should be empty"
}

# Unit Test: list-state-machines function returns record
# Entry point: list-state-machines()
# Exit point: returns record type
# [test]
export def test_list_state_machines_returns_record []: nothing -> nothing {
    let result = list-state-machines
    assert_type $result "record" "list-state-machines should return record"
}

# Unit Test: list-state-machines function has state_machines field
# Entry point: list-state-machines()
# Exit point: result contains state_machines field
# [test]
export def test_list_state_machines_has_state_machines_field []: nothing -> nothing {
    let result = list-state-machines
    assert_contains ($result | columns) "state_machines" "Should have state_machines field"
}

# Unit Test: list-state-machines function state_machines field is list
# Entry point: list-state-machines()
# Exit point: state_machines field is list type
# [test]
export def test_list_state_machines_state_machines_is_list []: nothing -> nothing {
    let result = list-state-machines
    assert_type $result.state_machines "list" "state_machines field should be list"
}

# Unit Test: list-state-machines function with max-results parameter
# Entry point: list-state-machines(--max-results 10)
# Exit point: returns record type
# [test]
export def test_list_state_machines_with_max_results []: nothing -> nothing {
    let result = list-state-machines --max-results 10
    assert_type $result "record" "list-state-machines with max-results should return record"
}

# Unit Test: create-state-machine function returns record
# Entry point: create-state-machine(name, definition, role_arn)
# Exit point: returns record type
# [test]
export def test_create_state_machine_returns_record []: nothing -> nothing {
    let result = create-state-machine "test" '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test"
    assert_type $result "record" "create-state-machine should return record"
}

# Unit Test: create-state-machine function has state_machine_arn field
# Entry point: create-state-machine(name, definition, role_arn)
# Exit point: result contains state_machine_arn field
# [test]
export def test_create_state_machine_has_arn_field []: nothing -> nothing {
    let result = create-state-machine "test" '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
}

# Unit Test: create-state-machine function arn contains machine name
# Entry point: create-state-machine("unit-test-name", definition, role_arn)
# Exit point: state_machine_arn contains the input name
# [test]
export def test_create_state_machine_arn_contains_name []: nothing -> nothing {
    let machine_name = "unit-test-name"
    let result = create-state-machine $machine_name '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test"
    assert ($result.state_machine_arn | str contains $machine_name) "ARN should contain machine name"
}

# Unit Test: start-execution function returns record
# Entry point: start-execution(state_machine_arn)
# Exit point: returns record type
# [test]
export def test_start_execution_returns_record []: nothing -> nothing {
    let result = start-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "start-execution should return record"
}

# Unit Test: start-execution function has execution_arn field
# Entry point: start-execution(state_machine_arn)
# Exit point: result contains execution_arn field
# [test]
export def test_start_execution_has_execution_arn []: nothing -> nothing {
    let result = start-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
}

# Unit Test: start-execution function execution_arn is string
# Entry point: start-execution(state_machine_arn)
# Exit point: execution_arn field is string type
# [test]
export def test_start_execution_arn_is_string []: nothing -> nothing {
    let result = start-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result.execution_arn "string" "execution_arn should be string"
}

# Unit Test: validate-state-machine-definition function returns record
# Entry point: validate-state-machine-definition(definition)
# Exit point: returns record type
# [test]
export def test_validate_definition_returns_record []: nothing -> nothing {
    let result = validate-state-machine-definition '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    assert_type $result "record" "validate-state-machine-definition should return record"
}

# Unit Test: validate-state-machine-definition function has result field
# Entry point: validate-state-machine-definition(definition)
# Exit point: result contains result field
# [test]
export def test_validate_definition_has_result_field []: nothing -> nothing {
    let result = validate-state-machine-definition '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    assert_contains ($result | columns) "result" "Should have result field"
}

# Unit Test: validate-state-machine-definition function result is OK
# Entry point: validate-state-machine-definition(valid_definition)
# Exit point: result field equals "OK"
# [test]
export def test_validate_definition_result_is_ok []: nothing -> nothing {
    let result = validate-state-machine-definition '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    assert_equal $result.result "OK" "Valid definition should return OK"
}

# Unit Test: create-activity function returns record
# Entry point: create-activity(name)
# Exit point: returns record type
# [test]
export def test_create_activity_returns_record []: nothing -> nothing {
    let result = create-activity "test-activity"
    assert_type $result "record" "create-activity should return record"
}

# Unit Test: create-activity function has activity_arn field
# Entry point: create-activity(name)
# Exit point: result contains activity_arn field
# [test]
export def test_create_activity_has_arn_field []: nothing -> nothing {
    let result = create-activity "test-activity"
    assert_contains ($result | columns) "activity_arn" "Should have activity_arn field"
}

# Unit Test: create-activity function arn contains activity name
# Entry point: create-activity("unit-test-activity")
# Exit point: activity_arn contains the input name
# [test]
export def test_create_activity_arn_contains_name []: nothing -> nothing {
    let activity_name = "unit-test-activity"
    let result = create-activity $activity_name
    assert ($result.activity_arn | str contains $activity_name) "ARN should contain activity name"
}

# Unit Test: list-activities function returns record
# Entry point: list-activities()
# Exit point: returns record type
# [test]
export def test_list_activities_returns_record []: nothing -> nothing {
    let result = list-activities
    assert_type $result "record" "list-activities should return record"
}

# Unit Test: list-activities function has activities field
# Entry point: list-activities()
# Exit point: result contains activities field
# [test]
export def test_list_activities_has_activities_field []: nothing -> nothing {
    let result = list-activities
    assert_contains ($result | columns) "activities" "Should have activities field"
}

# Unit Test: test-state function returns record
# Entry point: test-state(definition, role_arn)
# Exit point: returns record type
# [test]
export def test_test_state_returns_record []: nothing -> nothing {
    let result = test-state '{"Type":"Pass","End":true}' "arn:aws:iam::123456789012:role/Test"
    assert_type $result "record" "test-state should return record"
}

# Unit Test: test-state function has status field
# Entry point: test-state(definition, role_arn)
# Exit point: result contains status field
# [test]
export def test_test_state_has_status_field []: nothing -> nothing {
    let result = test-state '{"Type":"Pass","End":true}' "arn:aws:iam::123456789012:role/Test"
    assert_contains ($result | columns) "status" "Should have status field"
}

# Unit Test: test-state function status is SUCCEEDED
# Entry point: test-state(valid_pass_state, role_arn)
# Exit point: status field equals "SUCCEEDED"
# [test]
export def test_test_state_status_succeeded []: nothing -> nothing {
    let result = test-state '{"Type":"Pass","End":true}' "arn:aws:iam::123456789012:role/Test"
    assert_equal $result.status "SUCCEEDED" "Pass state should succeed"
}

# Unit Test: Function idempotency - same input produces same output
# Entry point: stepfunctions-config() called multiple times
# Exit point: all calls return identical results
# [test]
export def test_function_idempotency []: nothing -> nothing {
    let result1 = stepfunctions-config
    let result2 = stepfunctions-config
    let result3 = stepfunctions-config
    
    assert_equal $result1.type $result2.type "Multiple calls should return same type"
    assert_equal $result2.type $result3.type "Multiple calls should return same type"
    assert_equal $result1.name $result2.name "Multiple calls should return same name"
}

# Unit Test: Function isolation - calls don't affect each other
# Entry point: multiple different functions called in sequence
# Exit point: each function returns expected type independently
# [test]
export def test_function_isolation []: nothing -> nothing {
    let config = stepfunctions-config
    let machines = list-state-machines
    let activities = list-activities
    
    # Each function should work independently
    assert_type $config "record" "Config function should work independently"
    assert_type $machines "record" "Machines function should work independently"
    assert_type $activities "record" "Activities function should work independently"
    
    # Functions should maintain their specific fields
    assert_equal $config.type "STANDARD" "Config should maintain its properties"
    assert_type $machines.state_machines "list" "Machines should maintain its properties"
    assert_type $activities.activities "list" "Activities should maintain its properties"
}

# Unit Test: Parameter handling - optional parameters work correctly
# Entry point: function with optional parameters
# Exit point: function handles optional parameters correctly
# [test]
export def test_optional_parameters []: nothing -> nothing {
    # Test with default parameters
    let default_result = list-state-machines
    assert_type $default_result "record" "Should work with default parameters"
    
    # Test with optional parameters provided
    let with_params = list-state-machines --max-results 5 --next-token "test"
    assert_type $with_params "record" "Should work with optional parameters"
    
    # Both should return same structure
    assert_equal ($default_result | describe) ($with_params | describe) "Should return same structure regardless of optional params"
}

# Unit Test: Type consistency - functions return consistent types
# Entry point: same function called with different valid inputs
# Exit point: return type structure is consistent
# [test]
export def test_type_consistency []: nothing -> nothing {
    let result1 = create-state-machine "test1" '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test"
    let result2 = create-state-machine "test2" '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test"
    
    # Same function should return same type structure
    assert_equal ($result1 | describe) ($result2 | describe) "Same function should return consistent types"
    
    # Should have same fields
    assert_contains ($result1 | columns) "state_machine_arn" "Result1 should have required fields"
    assert_contains ($result2 | columns) "state_machine_arn" "Result2 should have required fields"
    assert_contains ($result1 | columns) "creation_date" "Result1 should have required fields"
    assert_contains ($result2 | columns) "creation_date" "Result2 should have required fields"
}

# Unit Test: Edge case handling - empty strings
# Entry point: function with minimal valid inputs
# Exit point: function handles edge cases gracefully
# [test]
export def test_edge_case_empty_strings []: nothing -> nothing {
    # Test start-execution with empty optional parameters
    let result = start-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test" --name "" --input "{}"
    assert_type $result "record" "Should handle empty optional strings"
    assert_contains ($result | columns) "execution_arn" "Should still return required fields"
}

# Unit Test: Boundary values - max results
# Entry point: list-state-machines with large max-results
# Exit point: function handles large values correctly
# [test]
export def test_boundary_max_results []: nothing -> nothing {
    let result = list-state-machines --max-results 1000
    assert_type $result "record" "Should handle large max-results"
    assert_type $result.state_machines "list" "Should still return list type"
}

# Unit Test: Return value structure - all list functions follow pattern
# Entry point: various list functions
# Exit point: all return records with list field and next_token
# [test]
export def test_list_function_pattern []: nothing -> nothing {
    let machines = list-state-machines
    let activities = list-activities
    
    # All list functions should follow same pattern
    assert_type $machines "record" "List functions should return records"
    assert_type $activities "record" "List functions should return records"
    
    assert_type $machines.next_token "string" "List functions should have next_token"
    assert_type $activities.next_token "string" "List functions should have next_token"
    
    assert_type $machines.state_machines "list" "List functions should have list field"
    assert_type $activities.activities "list" "List functions should have list field"
}