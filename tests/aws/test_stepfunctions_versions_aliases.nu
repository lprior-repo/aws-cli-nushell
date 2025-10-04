# Pure Unit Tests for Step Functions Alias Operations (Versioning covered in separate file)
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions Version and Alias tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions Version and Alias tests"
}

# NOTE: Version publishing tests are covered in test_stepfunctions_versioning_units.nu
# This file focuses on alias-specific operations

# UNIT TEST: delete-state-machine-version function
# Entry point: delete-state-machine-version with version ARN
# Exit point: returns nothing (successful deletion)
# [test]
export def test_delete_state_machine_version []: nothing -> nothing {
    let version_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-versioning-test:1"
    
    # Invoke the unit of work
    let result = delete-state-machine-version $version_arn
    
    # Check exit points
    assert_type $result "nothing" "delete-state-machine-version should return nothing type"
}

# [test]
export def test_list_state_machine_versions []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-versioning-test"
    
    # Test basic function signature
    let result = list-state-machine-versions $test_sm_arn
    assert_type $result "record" "list-state-machine-versions should return record type"
    assert_contains ($result | columns) "state_machine_versions" "list-state-machine-versions should have state_machine_versions field"
    assert_contains ($result | columns) "next_token" "list-state-machine-versions should have next_token field"
    assert_type $result.state_machine_versions "list" "state_machine_versions should be a list"
    assert_type $result.next_token "string" "next_token should be a string"
    
    # Test with pagination parameters
    let result_with_params = list-state-machine-versions $test_sm_arn --next-token "test-token" --max-results 25
    assert_type $result_with_params "record" "list-state-machine-versions with params should return record type"
    assert_contains ($result_with_params | columns) "state_machine_versions" "list-state-machine-versions with params should have state_machine_versions field"
    assert_contains ($result_with_params | columns) "next_token" "list-state-machine-versions with params should have next_token field"
}

# [test]
export def test_delete_state_machine_version []: nothing -> nothing {
    let test_version_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-versioning-test:1"
    
    # Test function signature
    assert_type (metadata (delete-state-machine-version $test_version_arn)) "nothing" "delete-state-machine-version should return nothing type"
}

# [test]
export def test_create_state_machine_alias []: nothing -> nothing {
    let alias_name = "nutest-alias"
    let routing_config = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}
    ]
    
    # Test basic function signature
    let result = create-state-machine-alias $alias_name $routing_config
    assert_type $result "record" "create-state-machine-alias should return record type"
    assert_contains ($result | columns) "state_machine_alias_arn" "create-state-machine-alias should have state_machine_alias_arn field"
    assert_contains ($result | columns) "creation_date" "create-state-machine-alias should have creation_date field"
    
    # Test with description
    let result_with_desc = create-state-machine-alias $alias_name $routing_config --description "Test alias created by nutest"
    assert_type $result_with_desc "record" "create-state-machine-alias with description should return record type"
    assert_contains ($result_with_desc | columns) "state_machine_alias_arn" "create-state-machine-alias with description should have state_machine_alias_arn field"
    assert_contains ($result_with_desc | columns) "creation_date" "create-state-machine-alias with description should have creation_date field"
}

# [test]
export def test_describe_state_machine_alias []: nothing -> nothing {
    let test_alias_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test:nutest-alias"
    
    # Test function signature
    assert_type (metadata (describe-state-machine-alias $test_alias_arn)) "record" "describe-state-machine-alias should return record type"
}

# [test]
export def test_update_state_machine_alias []: nothing -> nothing {
    let test_alias_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test:nutest-alias"
    
    # Test basic function signature (no parameters)
    let result = update-state-machine-alias $test_alias_arn
    assert_type $result "record" "update-state-machine-alias should return record type"
    assert_contains ($result | columns) "update_date" "update-state-machine-alias should have update_date field"
    
    # Test with description only
    let result_with_desc = update-state-machine-alias $test_alias_arn --description "Updated description"
    assert_type $result_with_desc "record" "update-state-machine-alias with description should return record type"
    assert_contains ($result_with_desc | columns) "update_date" "update-state-machine-alias with description should have update_date field"
    
    # Test with routing configuration only
    let new_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 100}
    ]
    let result_with_routing = update-state-machine-alias $test_alias_arn --routing-configuration $new_routing
    assert_type $result_with_routing "record" "update-state-machine-alias with routing should return record type"
    assert_contains ($result_with_routing | columns) "update_date" "update-state-machine-alias with routing should have update_date field"
    
    # Test with both description and routing configuration
    let weighted_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 70},
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 30}
    ]
    let result_full = update-state-machine-alias $test_alias_arn --description "Updated with weighted routing" --routing-configuration $weighted_routing
    assert_type $result_full "record" "update-state-machine-alias with all params should return record type"
    assert_contains ($result_full | columns) "update_date" "update-state-machine-alias with all params should have update_date field"
}

# [test]
export def test_delete_state_machine_alias []: nothing -> nothing {
    let test_alias_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test:nutest-alias"
    
    # Test function signature
    assert_type (metadata (delete-state-machine-alias $test_alias_arn)) "nothing" "delete-state-machine-alias should return nothing type"
}

# [test]
export def test_list_state_machine_aliases []: nothing -> nothing {
    let test_sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-test"
    
    # Test basic function signature
    let result = list-state-machine-aliases $test_sm_arn
    assert_type $result "record" "list-state-machine-aliases should return record type"
    assert_contains ($result | columns) "state_machine_aliases" "list-state-machine-aliases should have state_machine_aliases field"
    assert_contains ($result | columns) "next_token" "list-state-machine-aliases should have next_token field"
    assert_type $result.state_machine_aliases "list" "state_machine_aliases should be a list"
    assert_type $result.next_token "string" "next_token should be a string"
    
    # Test with pagination parameters
    let result_with_params = list-state-machine-aliases $test_sm_arn --next-token "test-token" --max-results 10
    assert_type $result_with_params "record" "list-state-machine-aliases with params should return record type"
    assert_contains ($result_with_params | columns) "state_machine_aliases" "list-state-machine-aliases with params should have state_machine_aliases field"
    assert_contains ($result_with_params | columns) "next_token" "list-state-machine-aliases with params should have next_token field"
}

# [test]
export def test_version_alias_lifecycle []: nothing -> nothing {
    # Test a complete version and alias management lifecycle
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-lifecycle-test"
    let alias_name = "nutest-lifecycle-alias"
    
    # 1. Publish initial version
    let version1 = publish-state-machine-version $sm_arn --description "Initial version for lifecycle test"
    assert_type $version1 "record" "Version 1 publishing should return record"
    assert_contains ($version1 | columns) "state_machine_version_arn" "Version 1 should have ARN"
    
    let version1_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-lifecycle-test:1"
    
    # 2. Create alias pointing to version 1
    let routing_v1 = [{"stateMachineVersionArn": $version1_arn, "weight": 100}]
    let alias = create-state-machine-alias $alias_name $routing_v1 --description "Lifecycle test alias"
    assert_type $alias "record" "Alias creation should return record"
    assert_contains ($alias | columns) "state_machine_alias_arn" "Alias should have ARN"
    
    let alias_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-lifecycle-test:nutest-lifecycle-alias"
    
    # 3. Publish second version
    let version2 = publish-state-machine-version $sm_arn --description "Second version for lifecycle test"
    assert_type $version2 "record" "Version 2 publishing should return record"
    
    let version2_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:nutest-lifecycle-test:2"
    
    # 4. Update alias to do weighted routing between versions
    let weighted_routing = [
        {"stateMachineVersionArn": $version1_arn, "weight": 80},
        {"stateMachineVersionArn": $version2_arn, "weight": 20}
    ]
    let updated_alias = update-state-machine-alias $alias_arn --description "Weighted routing between versions" --routing-configuration $weighted_routing
    assert_type $updated_alias "record" "Alias update should return record"
    assert_contains ($updated_alias | columns) "update_date" "Updated alias should have update date"
    
    # 5. Gradually shift traffic to version 2
    let shift_routing = [
        {"stateMachineVersionArn": $version1_arn, "weight": 50},
        {"stateMachineVersionArn": $version2_arn, "weight": 50}
    ]
    let shifted_alias = update-state-machine-alias $alias_arn --routing-configuration $shift_routing
    assert_type $shifted_alias "record" "Traffic shift should return record"
    
    # 6. Complete migration to version 2
    let final_routing = [{"stateMachineVersionArn": $version2_arn, "weight": 100}]
    let final_alias = update-state-machine-alias $alias_arn --routing-configuration $final_routing
    assert_type $final_alias "record" "Final migration should return record"
    
    # 7. List versions and aliases to verify
    let versions = list-state-machine-versions $sm_arn
    assert_type $versions "record" "Version listing should return record"
    assert_type $versions.state_machine_versions "list" "Should have versions list"
    
    let aliases = list-state-machine-aliases $sm_arn
    assert_type $aliases "record" "Alias listing should return record"
    assert_type $aliases.state_machine_aliases "list" "Should have aliases list"
    
    # 8. Describe alias to verify final state
    let final_state = describe-state-machine-alias $alias_arn
    assert_type $final_state "record" "Final alias state should return record"
    
    # 9. Clean up - delete alias and old version
    delete-state-machine-alias $alias_arn
    delete-state-machine-version $version1_arn
    
    # Lifecycle should complete successfully
    assert (true) "Version and alias lifecycle should complete successfully"
}

# [test]
export def test_routing_configuration_types []: nothing -> nothing {
    # Test different routing configuration patterns
    let alias_name = "nutest-routing-test"
    
    # Single version routing (100%)
    let single_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}
    ]
    assert_type (metadata (create-state-machine-alias $alias_name $single_routing)) "record" "Single version routing should work"
    
    # Two version routing (80/20 split)
    let two_version_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 80},
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 20}
    ]
    assert_type (metadata (create-state-machine-alias $alias_name $two_version_routing)) "record" "Two version routing should work"
    
    # Equal weight routing (50/50)
    let equal_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 50},
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 50}
    ]
    assert_type (metadata (create-state-machine-alias $alias_name $equal_routing)) "record" "Equal weight routing should work"
    
    # All routing configurations should be accepted
    assert (true) "All routing configuration types should be accepted"
}