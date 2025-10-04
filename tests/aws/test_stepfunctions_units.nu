# Pure Unit Tests for Step Functions Framework
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions unit tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions unit tests"
}

# UNIT TEST: stepfunctions-config function
# Entry point: stepfunctions-config
# Exit point: returns record with specific structure
# [test]
export def test_stepfunctions_config_unit []: nothing -> nothing {
    # Invoke the unit of work
    let result = stepfunctions-config
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_equal $result.name "" "name should be empty string"
    assert_equal $result.definition "" "definition should be empty string" 
    assert_equal $result.role_arn "" "role_arn should be empty string"
    assert_equal $result.type "STANDARD" "type should be STANDARD"
    assert_type $result.logging_configuration "record" "logging_configuration should be record"
    assert_type $result.tracing_configuration "record" "tracing_configuration should be record"
    assert_type $result.tags "list" "tags should be list"
}

# UNIT TEST: list-state-machines function
# Entry point: list-state-machines with parameters
# Exit point: returns record with specific structure
# [test]
export def test_list_state_machines_unit []: nothing -> nothing {
    # Invoke the unit of work with default parameters
    let result = list-state-machines
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machines" "Should have state_machines field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.state_machines "list" "state_machines should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: list-state-machines with custom parameters
# Entry point: list-state-machines with specific max-results
# Exit point: returns same structure regardless of parameters
# [test]
export def test_list_state_machines_with_params_unit []: nothing -> nothing {
    # Invoke the unit of work with custom parameters
    let result = list-state-machines --max-results 50 --next-token "test-token"
    
    # Check exit points (structure should be identical)
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machines" "Should have state_machines field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.state_machines "list" "state_machines should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: create-state-machine function
# Entry point: create-state-machine with required parameters
# Exit point: returns record with ARN and creation date
# [test]
export def test_create_state_machine_unit []: nothing -> nothing {
    # Test inputs
    let name = "test-state-machine"
    let definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    let role_arn = "arn:aws:iam::123456789012:role/TestRole"
    
    # Invoke the unit of work
    let result = create-state-machine $name $definition $role_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert_type $result.state_machine_arn "string" "state_machine_arn should be string"
    assert_type $result.creation_date "string" "creation_date should be string"
    
    # Verify output contains expected name
    assert ($result.state_machine_arn | str contains $name) "ARN should contain the state machine name"
}

# UNIT TEST: create-state-machine with optional parameters
# Entry point: create-state-machine with all optional parameters
# Exit point: returns same structure with additional parameter handling
# [test]
export def test_create_state_machine_with_options_unit []: nothing -> nothing {
    # Test inputs with optional parameters
    let name = "test-state-machine-options"
    let definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    let role_arn = "arn:aws:iam::123456789012:role/TestRole"
    let tags = [{"Key": "Environment", "Value": "Test"}]
    let logging_config = {"level": "ALL"}
    
    # Invoke the unit of work
    let result = create-state-machine $name $definition $role_arn --type "EXPRESS" --tags $tags --logging-configuration $logging_config --publish true --version-description "Test version"
    
    # Check exit points (structure should be identical)
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert ($result.state_machine_arn | str contains $name) "ARN should contain the state machine name"
}

# UNIT TEST: describe-state-machine function
# Entry point: describe-state-machine with ARN
# Exit point: returns detailed state machine information
# [test]
export def test_describe_state_machine_unit []: nothing -> nothing {
    # Test input
    let test_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    
    # Invoke the unit of work
    let result = describe-state-machine $test_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "stateMachineArn" "Should have stateMachineArn field"
    assert_contains ($result | columns) "name" "Should have name field"
    assert_contains ($result | columns) "status" "Should have status field"
    assert_contains ($result | columns) "definition" "Should have definition field"
    assert_equal $result.stateMachineArn $test_arn "Should return the same ARN"
    assert_type $result.definition "string" "definition should be string"
}

# UNIT TEST: start-execution function
# Entry point: start-execution with state machine ARN
# Exit point: returns execution ARN and start date
# [test]
export def test_start_execution_unit []: nothing -> nothing {
    # Test input
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    
    # Invoke the unit of work
    let result = start-execution $sm_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert_contains ($result | columns) "start_date" "Should have start_date field"
    assert_type $result.execution_arn "string" "execution_arn should be string"
    assert_type $result.start_date "string" "start_date should be string"
    
    # Verify output structure
    assert ($result.execution_arn | str contains "execution") "execution_arn should contain 'execution'"
}

# UNIT TEST: start-execution with custom parameters
# Entry point: start-execution with name and input
# Exit point: returns execution details with custom parameters
# [test]
export def test_start_execution_with_params_unit []: nothing -> nothing {
    # Test inputs
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    let exec_name = "custom-execution"
    let input_data = '{"test": "data", "number": 42}'
    
    # Invoke the unit of work
    let result = start-execution $sm_arn --name $exec_name --input $input_data
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "execution_arn" "Should have execution_arn field"
    assert_contains ($result | columns) "start_date" "Should have start_date field"
    
    # Verify custom name is reflected in ARN
    assert ($result.execution_arn | str contains $exec_name) "execution_arn should contain custom name"
}

# UNIT TEST: validate-state-machine-definition function
# Entry point: validate-state-machine-definition with valid JSON
# Exit point: returns validation result and diagnostics
# [test]
export def test_validate_definition_unit []: nothing -> nothing {
    # Test input - valid state machine definition
    let valid_definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    
    # Invoke the unit of work
    let result = validate-state-machine-definition $valid_definition
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "result" "Should have result field"
    assert_contains ($result | columns) "diagnostics" "Should have diagnostics field"
    assert_type $result.result "string" "result should be string"
    assert_type $result.diagnostics "list" "diagnostics should be list"
    assert_equal $result.result "OK" "Valid definition should return OK"
}

# UNIT TEST: validate-state-machine-definition with type parameter
# Entry point: validate-state-machine-definition with EXPRESS type
# Exit point: returns same structure regardless of type
# [test]
export def test_validate_definition_with_type_unit []: nothing -> nothing {
    # Test inputs
    let valid_definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    let machine_type = "EXPRESS"
    
    # Invoke the unit of work
    let result = validate-state-machine-definition $valid_definition --type $machine_type
    
    # Check exit points (structure should be identical)
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "result" "Should have result field"
    assert_contains ($result | columns) "diagnostics" "Should have diagnostics field"
    assert_equal $result.result "OK" "Valid definition should return OK regardless of type"
}

# UNIT TEST: create-activity function
# Entry point: create-activity with name
# Exit point: returns activity ARN and creation date
# [test]
export def test_create_activity_unit []: nothing -> nothing {
    # Test input
    let activity_name = "test-activity"
    
    # Invoke the unit of work
    let result = create-activity $activity_name
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "activity_arn" "Should have activity_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert_type $result.activity_arn "string" "activity_arn should be string"
    assert_type $result.creation_date "string" "creation_date should be string"
    
    # Verify output contains expected name
    assert ($result.activity_arn | str contains $activity_name) "ARN should contain the activity name"
}

# UNIT TEST: list-activities function
# Entry point: list-activities
# Exit point: returns list of activities with metadata
# [test]
export def test_list_activities_unit []: nothing -> nothing {
    # Invoke the unit of work
    let result = list-activities
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "activities" "Should have activities field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.activities "list" "activities should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: test-state function
# Entry point: test-state with state definition and role
# Exit point: returns test execution result
# [test]
export def test_test_state_unit []: nothing -> nothing {
    # Test inputs
    let state_definition = '{"Type":"Pass","Result":"Hello World","End":true}'
    let role_arn = "arn:aws:iam::123456789012:role/TestRole"
    
    # Invoke the unit of work
    let result = test-state $state_definition $role_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "output" "Should have output field"
    assert_contains ($result | columns) "status" "Should have status field"
    assert_type $result.output "string" "output should be string"
    assert_type $result.status "string" "status should be string"
}

# UNIT TEST: Idempotency test - same inputs should produce same outputs
# Entry point: Multiple calls with identical parameters
# Exit point: Verify consistent results
# [test]
export def test_idempotency_unit []: nothing -> nothing {
    # Test inputs
    let name = "idempotent-test"
    let definition = '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}'
    let role_arn = "arn:aws:iam::123456789012:role/TestRole"
    
    # Invoke the unit of work multiple times
    let result1 = create-state-machine $name $definition $role_arn
    let result2 = create-state-machine $name $definition $role_arn
    let result3 = create-state-machine $name $definition $role_arn
    
    # Check exit points - all results should have same structure
    assert_type $result1 "record" "First call should return record"
    assert_type $result2 "record" "Second call should return record"
    assert_type $result3 "record" "Third call should return record"
    
    # Verify consistent field presence (ARNs may differ but structure is same)
    assert_contains ($result1 | columns) "state_machine_arn" "Result1 should have state_machine_arn"
    assert_contains ($result2 | columns) "state_machine_arn" "Result2 should have state_machine_arn"
    assert_contains ($result3 | columns) "state_machine_arn" "Result3 should have state_machine_arn"
    
    # Verify consistent field types
    assert_type $result1.state_machine_arn "string" "Result1 ARN should be string"
    assert_type $result2.state_machine_arn "string" "Result2 ARN should be string"
    assert_type $result3.state_machine_arn "string" "Result3 ARN should be string"
}

# UNIT TEST: Edge case - empty optional parameters
# Entry point: Functions with empty/default optional parameters
# Exit point: Verify graceful handling
# [test]
export def test_empty_parameters_unit []: nothing -> nothing {
    # Test inputs with empty optional parameters
    let result1 = list-state-machines --max-results 100 --next-token ""
    let result2 = start-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test" --name "" --input "{}"
    
    # Check exit points - should handle empty parameters gracefully
    assert_type $result1 "record" "Should handle empty next-token"
    assert_type $result2 "record" "Should handle empty name and input"
    
    # Verify required fields are still present
    assert_contains ($result1 | columns) "state_machines" "Should have state_machines field"
    assert_contains ($result2 | columns) "execution_arn" "Should have execution_arn field"
}

# UNIT TEST: Input validation through output verification
# Entry point: Functions with various input types
# Exit point: Verify output structure reflects input handling
# [test]
export def test_input_validation_unit []: nothing -> nothing {
    # Test different input types and verify outputs
    
    # String inputs
    let config = stepfunctions-config
    assert_type $config.name "string" "String fields should be strings"
    
    # Integer inputs  
    let list_result = list-state-machines --max-results 42
    assert_type $list_result "record" "Should handle integer max-results"
    
    # Record inputs
    let logging_config = {"level": "ERROR"}
    let create_result = create-state-machine "input-test" "{}" "arn:aws:iam::123456789012:role/Test" --logging-configuration $logging_config
    assert_type $create_result "record" "Should handle record inputs"
    
    # List inputs
    let tags = [{"Key": "Test", "Value": "Unit"}]
    let tagged_result = create-state-machine "tagged-test" "{}" "arn:aws:iam::123456789012:role/Test" --tags $tags
    assert_type $tagged_result "record" "Should handle list inputs"
}

# UNIT TEST: Function composition and data flow
# Entry point: Chain of function calls
# Exit point: Verify data flows correctly between functions
# [test]
export def test_function_composition_unit []: nothing -> nothing {
    # Test data flow: config -> create -> describe -> start
    
    # 1. Get configuration
    let config = stepfunctions-config
    
    # 2. Create state machine using config structure
    let created = create-state-machine "composition-test" '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test" --type $config.type
    
    # 3. Describe the created state machine
    let described = describe-state-machine $created.state_machine_arn
    
    # 4. Start execution
    let execution = start-execution $described.stateMachineArn
    
    # Check exit points at each step
    assert_type $config "record" "Config should be record"
    assert_type $created "record" "Created should be record"
    assert_type $described "record" "Described should be record" 
    assert_type $execution "record" "Execution should be record"
    
    # Verify data flow consistency
    assert_equal $described.stateMachineArn $created.state_machine_arn "ARNs should match between create and describe"
}

# UNIT TEST: Return type consistency
# Entry point: All list functions
# Exit point: Verify consistent list return patterns
# [test]
export def test_return_type_consistency_unit []: nothing -> nothing {
    # Test all list functions return consistent structure
    let state_machines = list-state-machines
    let activities = list-activities
    let executions = list-executions --state-machine-arn "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    
    # All list functions should return records with list fields
    assert_type $state_machines "record" "list-state-machines should return record"
    assert_type $activities "record" "list-activities should return record"
    assert_type $executions "record" "list-executions should return record"
    
    # All should have their respective list fields
    assert_type $state_machines.state_machines "list" "state_machines field should be list"
    assert_type $activities.activities "list" "activities field should be list"
    assert_type $executions.executions "list" "executions field should be list"
    
    # All should have next_token for pagination
    assert_type $state_machines.next_token "string" "state_machines should have next_token"
    assert_type $activities.next_token "string" "activities should have next_token"
    assert_type $executions.next_token "string" "executions should have next_token"
}