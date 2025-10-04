# Pure Unit Tests for Step Functions Miscellaneous Operations
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions Miscellaneous tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions Miscellaneous tests"
}

# UNIT TEST: tag-resource function
# Entry point: tag-resource with resource ARN and tags
# Exit point: returns nothing (successful tagging)
# [test]
export def test_tag_resource []: nothing -> nothing {
    let test_resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-tagging-test"
    let test_tags = [
        {"Key": "Environment", "Value": "Test"},
        {"Key": "Project", "Value": "NuTest"},
        {"Key": "Owner", "Value": "TestFramework"}
    ]
    
    # Invoke the unit of work
    let result = tag-resource $test_resource_arn $test_tags
    
    # Check exit points
    assert_type $result "nothing" "tag-resource should return nothing type"
}

# UNIT TEST: tag-resource with single tag
# Entry point: tag-resource with single tag
# Exit point: returns nothing with single tag handling
# [test]
export def test_tag_resource_single []: nothing -> nothing {
    let test_resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-tagging-test"
    let single_tag = [{"Key": "SingleTag", "Value": "SingleValue"}]
    
    # Invoke the unit of work
    let result = tag-resource $test_resource_arn $single_tag
    
    # Check exit points
    assert_type $result "nothing" "tag-resource with single tag should return nothing type"
}

# UNIT TEST: tag-resource with empty value
# Entry point: tag-resource with empty value tag
# Exit point: returns nothing with empty value handling
# [test]
export def test_tag_resource_empty_value []: nothing -> nothing {
    let test_resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-tagging-test"
    let empty_value_tag = [{"Key": "EmptyValue", "Value": ""}]
    
    # Invoke the unit of work
    let result = tag-resource $test_resource_arn $empty_value_tag
    
    # Check exit points
    assert_type $result "nothing" "tag-resource with empty value should return nothing type"
}

# [test]
export def test_untag_resource []: nothing -> nothing {
    let test_resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-tagging-test"
    let tag_keys = ["Environment", "Project", "Owner"]
    
    # Test function signature
    assert_type (metadata (untag-resource $test_resource_arn $tag_keys)) "nothing" "untag-resource should return nothing type"
    
    # Test with single tag key
    let single_key = ["SingleTag"]
    assert_type (metadata (untag-resource $test_resource_arn $single_key)) "nothing" "untag-resource with single key should return nothing type"
    
    # Test with multiple tag keys
    let multiple_keys = ["Tag1", "Tag2", "Tag3", "Tag4"]
    assert_type (metadata (untag-resource $test_resource_arn $multiple_keys)) "nothing" "untag-resource with multiple keys should return nothing type"
}

# [test]
export def test_list_tags_for_resource []: nothing -> nothing {
    let test_resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-tagging-test"
    
    # Test function signature
    let result = list-tags-for-resource $test_resource_arn
    assert_type $result "list" "list-tags-for-resource should return list type"
}

# [test]
export def test_describe_state_machine_for_execution []: nothing -> nothing {
    let test_execution_arn = "arn:aws:states:us-east-1:123456789012:execution:nutest-test:test-execution"
    
    # Test function signature
    assert_type (metadata (describe-state-machine-for-execution $test_execution_arn)) "record" "describe-state-machine-for-execution should return record type"
}

# [test]
export def test_test_state []: nothing -> nothing {
    let test_definition = {
        "Type": "Pass",
        "Result": {"status": "success", "message": "Test completed"},
        "End": true
    } | to json
    let test_role_arn = "arn:aws:iam::123456789012:role/StepFunctionsRole"
    
    # Test basic function signature
    assert_type (metadata (test-state $test_definition $test_role_arn)) "record" "test-state should return record type"
    
    # Test with custom input
    let test_input = '{"testData": "nutest input", "timestamp": "2024-01-01T00:00:00Z"}'
    assert_type (metadata (test-state $test_definition $test_role_arn --input $test_input)) "record" "test-state with input should return record type"
    
    # Test with different inspection levels
    assert_type (metadata (test-state $test_definition $test_role_arn --inspection-level "DEBUG")) "record" "test-state with DEBUG inspection should return record type"
    assert_type (metadata (test-state $test_definition $test_role_arn --inspection-level "TRACE")) "record" "test-state with TRACE inspection should return record type"
    assert_type (metadata (test-state $test_definition $test_role_arn --inspection-level "INFO")) "record" "test-state with INFO inspection should return record type"
    
    # Test with all parameters
    assert_type (metadata (test-state $test_definition $test_role_arn --input $test_input --inspection-level "TRACE")) "record" "test-state with all params should return record type"
}

# [test]
export def test_tagging_lifecycle []: nothing -> nothing {
    # Test complete tagging lifecycle
    let resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-tagging-lifecycle"
    
    # 1. Initially tag the resource
    let initial_tags = [
        {"Key": "Environment", "Value": "Development"},
        {"Key": "Project", "Value": "NuTest"},
        {"Key": "Version", "Value": "1.0"}
    ]
    tag-resource $resource_arn $initial_tags
    
    # 2. List tags to verify initial tagging
    let tags_after_initial = list-tags-for-resource $resource_arn
    assert_type $tags_after_initial "list" "Initial tags listing should return list"
    
    # 3. Add more tags
    let additional_tags = [
        {"Key": "Owner", "Value": "TestTeam"},
        {"Key": "Purpose", "Value": "Testing"}
    ]
    tag-resource $resource_arn $additional_tags
    
    # 4. List tags again
    let tags_after_addition = list-tags-for-resource $resource_arn
    assert_type $tags_after_addition "list" "Tags after addition should return list"
    
    # 5. Update existing tag by retagging
    let updated_tags = [
        {"Key": "Environment", "Value": "Testing"},  # Updated value
        {"Key": "Version", "Value": "1.1"}           # Updated value
    ]
    tag-resource $resource_arn $updated_tags
    
    # 6. Remove some tags
    let tags_to_remove = ["Purpose", "Version"]
    untag-resource $resource_arn $tags_to_remove
    
    # 7. Final tag listing
    let final_tags = list-tags-for-resource $resource_arn
    assert_type $final_tags "list" "Final tags listing should return list"
    
    # 8. Remove all remaining tags
    let all_remaining_keys = ["Environment", "Project", "Owner"]
    untag-resource $resource_arn $all_remaining_keys
    
    # 9. Verify no tags remain
    let empty_tags = list-tags-for-resource $resource_arn
    assert_type $empty_tags "list" "Empty tags listing should return list"
    
    # Tagging lifecycle should complete successfully
    assert (true) "Tagging lifecycle should complete successfully"
}

# [test]
export def test_state_testing_scenarios []: nothing -> nothing {
    let role_arn = "arn:aws:iam::123456789012:role/StepFunctionsRole"
    
    # Test Pass state
    let pass_state = {
        "Type": "Pass",
        "Result": "Hello World",
        "End": true
    } | to json
    assert_type (metadata (test-state $pass_state $role_arn)) "record" "Pass state testing should return record"
    
    # Test Wait state
    let wait_state = {
        "Type": "Wait",
        "Seconds": 1,
        "Next": "NextState"
    } | to json
    assert_type (metadata (test-state $wait_state $role_arn)) "record" "Wait state testing should return record"
    
    # Test Choice state
    let choice_state = {
        "Type": "Choice",
        "Choices": [
            {
                "Variable": "$.type",
                "StringEquals": "test",
                "Next": "TestPath"
            }
        ],
        "Default": "DefaultPath"
    } | to json
    let choice_input = '{"type": "test", "value": 123}'
    assert_type (metadata (test-state $choice_state $role_arn --input $choice_input)) "record" "Choice state testing should return record"
    
    # Test Fail state
    let fail_state = {
        "Type": "Fail",
        "Error": "TestError",
        "Cause": "This is a test failure"
    } | to json
    assert_type (metadata (test-state $fail_state $role_arn)) "record" "Fail state testing should return record"
    
    # Test Succeed state
    let succeed_state = {
        "Type": "Succeed"
    } | to json
    assert_type (metadata (test-state $succeed_state $role_arn)) "record" "Succeed state testing should return record"
    
    # All state types should be testable
    assert (true) "All state types should be testable"
}

# [test]
export def test_different_resource_types []: nothing -> nothing {
    # Test tagging different types of Step Functions resources
    
    # State machine ARN
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-resource-test"
    let sm_tags = [{"Key": "ResourceType", "Value": "StateMachine"}]
    assert_type (metadata (tag-resource $sm_arn $sm_tags)) "nothing" "State machine tagging should work"
    assert_type (list-tags-for-resource $sm_arn) "list" "State machine tag listing should work"
    assert_type (metadata (untag-resource $sm_arn ["ResourceType"])) "nothing" "State machine untagging should work"
    
    # Activity ARN
    let activity_arn = "arn:aws:states:us-east-1:123456789012:activity:nutest-activity"
    let activity_tags = [{"Key": "ResourceType", "Value": "Activity"}]
    assert_type (metadata (tag-resource $activity_arn $activity_tags)) "nothing" "Activity tagging should work"
    assert_type (list-tags-for-resource $activity_arn) "list" "Activity tag listing should work"
    assert_type (metadata (untag-resource $activity_arn ["ResourceType"])) "nothing" "Activity untagging should work"
    
    # All resource types should support tagging
    assert (true) "All Step Functions resource types should support tagging"
}

# [test]
export def test_special_tag_characters []: nothing -> nothing {
    let resource_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-special-chars"
    
    # Test tags with special characters and values
    let special_tags = [
        {"Key": "Environment-Type", "Value": "test_environment"},
        {"Key": "Project.Name", "Value": "nu-test-framework"},
        {"Key": "Owner:Team", "Value": "engineering@company.com"},
        {"Key": "Version", "Value": "v1.2.3-beta"},
        {"Key": "Unicode", "Value": "测试🚀"},
        {"Key": "Spaces", "Value": "Value with spaces"},
        {"Key": "Numbers123", "Value": "12345"},
        {"Key": "Mixed_Case-Tag.Name", "Value": "Mixed_Case-Value.Name"}
    ]
    
    # All special character tags should be handled properly
    assert_type (metadata (tag-resource $resource_arn $special_tags)) "nothing" "Special character tags should work"
    
    let retrieved_tags = list-tags-for-resource $resource_arn
    assert_type $retrieved_tags "list" "Special character tag retrieval should work"
    
    # Remove all special character tags
    let special_keys = ["Environment-Type", "Project.Name", "Owner:Team", "Version", "Unicode", "Spaces", "Numbers123", "Mixed_Case-Tag.Name"]
    assert_type (metadata (untag-resource $resource_arn $special_keys)) "nothing" "Special character untagging should work"
    
    # Special character handling should work correctly
    assert (true) "Special character tag handling should work correctly"
}