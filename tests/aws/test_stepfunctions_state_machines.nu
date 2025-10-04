# Pure Unit Tests for Step Functions State Machine Operations
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions State Machine tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions State Machine tests"
}

# UNIT TEST: create-state-machine function
# Entry point: create-state-machine with required parameters
# Exit point: returns record with state_machine_arn and creation_date
# [test]
export def test_create_state_machine []: nothing -> nothing {
    let test_name = "nutest-sm-create-test"
    let test_definition = {
        "Comment": "Test state machine for nutest",
        "StartAt": "HelloWorld",
        "States": {
            "HelloWorld": {
                "Type": "Pass",
                "Result": "Hello World!",
                "End": true
            }
        }
    } | to json
    let test_role_arn = "arn:aws:iam::123456789012:role/StepFunctionsRole"
    
    # Invoke the unit of work
    let result = create-state-machine $test_name $test_definition $test_role_arn
    
    # Check exit points
    assert_type $result "record" "create-state-machine should return record type"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert ($result.state_machine_arn | str contains $test_name) "ARN should contain state machine name"
}

# UNIT TEST: create-state-machine with optional parameters
# Entry point: create-state-machine with EXPRESS type and tags
# Exit point: returns same structure with parameter handling
# [test]
export def test_create_state_machine_with_options []: nothing -> nothing {
    let test_name = "nutest-sm-express-test"
    let test_definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    let test_role_arn = "arn:aws:iam::123456789012:role/StepFunctionsRole"
    let tags = [{"Key": "Environment", "Value": "Test"}]
    
    # Invoke the unit of work
    let result = create-state-machine $test_name $test_definition $test_role_arn --type "EXPRESS" --tags $tags
    
    # Check exit points
    assert_type $result "record" "create-state-machine with optional params should return record type"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
    assert ($result.state_machine_arn | str contains $test_name) "ARN should contain state machine name"
}

# UNIT TEST: describe-state-machine function
# Entry point: describe-state-machine with ARN
# Exit point: returns detailed state machine information
# [test]
export def test_describe_state_machine []: nothing -> nothing {
    let test_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    
    # Invoke the unit of work
    let result = describe-state-machine $test_arn
    
    # Check exit points
    assert_type $result "record" "describe-state-machine should return record type"
    assert_contains ($result | columns) "stateMachineArn" "Should have stateMachineArn field"
    assert_contains ($result | columns) "name" "Should have name field"
    assert_contains ($result | columns) "status" "Should have status field"
    assert_equal $result.stateMachineArn $test_arn "Should return the same ARN"
}

# UNIT TEST: update-state-machine function
# Entry point: update-state-machine with ARN and definition
# Exit point: returns update confirmation with date
# [test]
export def test_update_state_machine []: nothing -> nothing {
    let test_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    let new_definition = {
        "Comment": "Updated test state machine",
        "StartAt": "UpdatedPass",
        "States": {
            "UpdatedPass": {
                "Type": "Pass",
                "Result": "Updated!",
                "End": true
            }
        }
    } | to json
    
    # Invoke the unit of work
    let result = update-state-machine $test_arn --definition $new_definition
    
    # Check exit points
    assert_type $result "record" "update-state-machine should return record type"
    assert_contains ($result | columns) "update_date" "Should have update_date field"
    assert_type $result.update_date "string" "update_date should be string"
}

# UNIT TEST: update-state-machine with all optional parameters
# Entry point: update-state-machine with logging, tracing, and publish
# Exit point: returns same structure with parameter handling
# [test]
export def test_update_state_machine_with_all_params []: nothing -> nothing {
    let test_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    let new_definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    let logging_config = {"level": "ALL", "includeExecutionData": true}
    let tracing_config = {"enabled": true}
    
    # Invoke the unit of work
    let result = update-state-machine $test_arn --definition $new_definition --logging-configuration $logging_config --tracing-configuration $tracing_config --publish true
    
    # Check exit points
    assert_type $result "record" "update-state-machine with all params should return record type"
    assert_contains ($result | columns) "update_date" "Should have update_date field"
}

# UNIT TEST: delete-state-machine function
# Entry point: delete-state-machine with ARN
# Exit point: returns nothing (successful deletion)
# [test]
export def test_delete_state_machine []: nothing -> nothing {
    let test_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    
    # Invoke the unit of work
    let result = delete-state-machine $test_arn
    
    # Check exit points
    assert_type $result "nothing" "delete-state-machine should return nothing type"
}

# [test]
export def test_list_state_machines []: nothing -> nothing {
    # Test function exists and has correct signature
    let result = list-state-machines
    assert_type $result "record" "list-state-machines should return record type"
    assert_contains ($result | columns) "state_machines" "list-state-machines should have state_machines field"
    assert_contains ($result | columns) "next_token" "list-state-machines should have next_token field"
    
    # Test with parameters
    let result_with_params = list-state-machines --max-results 50 --next-token "test-token"
    assert_type $result_with_params "record" "list-state-machines with params should return record type"
}

# [test]
export def test_validate_state_machine_definition []: nothing -> nothing {
    let valid_definition = {
        "Comment": "A valid test state machine",
        "StartAt": "Pass",
        "States": {
            "Pass": {
                "Type": "Pass",
                "End": true
            }
        }
    } | to json
    
    let invalid_definition = {
        "Comment": "Invalid - missing StartAt",
        "States": {
            "Pass": {
                "Type": "Pass",
                "End": true
            }
        }
    } | to json
    
    # Test function exists and has correct signature
    let valid_result = validate-state-machine-definition $valid_definition
    assert_type $valid_result "record" "validate-state-machine-definition should return record type"
    assert_contains ($valid_result | columns) "result" "validate-state-machine-definition should have result field"
    assert_contains ($valid_result | columns) "diagnostics" "validate-state-machine-definition should have diagnostics field"
    
    # Test with type parameter
    let result_with_type = validate-state-machine-definition $valid_definition --type "EXPRESS"
    assert_type $result_with_type "record" "validate-state-machine-definition with type should return record type"
    
    # Test invalid definition (should still return proper structure)
    let invalid_result = validate-state-machine-definition $invalid_definition
    assert_type $invalid_result "record" "validate-state-machine-definition with invalid def should return record type"
}

# UNIT TEST: stepfunctions-config function
# Entry point: stepfunctions-config
# Exit point: returns configuration record with default values
# [test]
export def test_stepfunctions_config []: nothing -> nothing {
    # Invoke the unit of work
    let config = stepfunctions-config
    
    # Check exit points
    assert_type $config "record" "stepfunctions-config should return record type"
    
    # Check required fields exist
    let expected_fields = ["name", "definition", "role_arn", "type", "logging_configuration", "tracing_configuration", "tags"]
    for field in $expected_fields {
        assert_contains ($config | columns) $field $"stepfunctions-config should have ($field) field"
    }
    
    # Check default values
    assert_equal $config.type "STANDARD" "stepfunctions-config should have STANDARD as default type"
    assert_equal $config.name "" "stepfunctions-config should have empty name as default"
    assert_equal $config.definition "" "stepfunctions-config should have empty definition as default"
    assert_equal $config.role_arn "" "stepfunctions-config should have empty role_arn as default"
}

# UNIT TEST: create-test-state-machine helper function
# Entry point: create-test-state-machine with name and role
# Exit point: returns created state machine record
# [test]
export def test_create_test_state_machine []: nothing -> nothing {
    let test_name = "nutest-helper-test"
    let test_role_arn = "arn:aws:iam::123456789012:role/StepFunctionsRole"
    
    # Invoke the unit of work
    let result = create-test-state-machine $test_name $test_role_arn
    
    # Check exit points
    assert_type $result "record" "create-test-state-machine should return record type"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
    assert ($result.state_machine_arn | str contains $test_name) "ARN should contain test name"
}

# UNIT TEST: create-test-state-machine with custom definition
# Entry point: create-test-state-machine with custom definition and tags
# Exit point: returns created state machine with custom parameters
# [test]
export def test_create_test_state_machine_custom []: nothing -> nothing {
    let test_name = "nutest-custom-helper"
    let test_role_arn = "arn:aws:iam::123456789012:role/StepFunctionsRole"
    let custom_definition = {
        "Comment": "Custom test definition",
        "StartAt": "Custom",
        "States": {
            "Custom": {
                "Type": "Pass",
                "Result": "Custom result",
                "End": true
            }
        }
    } | to json
    let tags = [{"Key": "Test", "Value": "CustomHelper"}]
    
    # Invoke the unit of work
    let result = create-test-state-machine $test_name $test_role_arn --definition $custom_definition --tags $tags
    
    # Check exit points
    assert_type $result "record" "create-test-state-machine with custom params should return record type"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
    assert ($result.state_machine_arn | str contains $test_name) "ARN should contain test name"
}