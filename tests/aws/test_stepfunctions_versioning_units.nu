# Pure Unit Tests for Step Functions Versioning Operations
# Each test invokes a unit of work and checks its exit points

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions versioning unit tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions versioning unit tests"
}

# UNIT TEST: publish-state-machine-version function
# Entry point: publish-state-machine-version with ARN
# Exit point: returns version ARN and creation date
# [test]
export def test_publish_version_unit []: nothing -> nothing {
    # Test input
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    
    # Invoke the unit of work
    let result = publish-state-machine-version $sm_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_version_arn" "Should have state_machine_version_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert_type $result.state_machine_version_arn "string" "state_machine_version_arn should be string"
    assert_type $result.creation_date "string" "creation_date should be string"
    
    # Verify version ARN format
    assert ($result.state_machine_version_arn | str contains "stateMachine") "Version ARN should contain stateMachine"
}

# UNIT TEST: publish-state-machine-version with description
# Entry point: publish-state-machine-version with description parameter
# Exit point: returns same structure with description handling
# [test]
export def test_publish_version_with_description_unit []: nothing -> nothing {
    # Test inputs
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    let description = "Unit test version"
    
    # Invoke the unit of work
    let result = publish-state-machine-version $sm_arn --description $description
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_version_arn" "Should have state_machine_version_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert_type $result.state_machine_version_arn "string" "ARN should be string"
}

# UNIT TEST: list-state-machine-versions function
# Entry point: list-state-machine-versions with ARN
# Exit point: returns list of versions with metadata
# [test]
export def test_list_versions_unit []: nothing -> nothing {
    # Test input
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    
    # Invoke the unit of work
    let result = list-state-machine-versions $sm_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_versions" "Should have state_machine_versions field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.state_machine_versions "list" "state_machine_versions should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: create-state-machine-alias function
# Entry point: create-state-machine-alias with routing configuration
# Exit point: returns alias ARN and creation date
# [test]
export def test_create_alias_unit []: nothing -> nothing {
    # Test inputs
    let alias_name = "test-alias"
    let routing_config = [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}]
    
    # Invoke the unit of work
    let result = create-state-machine-alias $alias_name $routing_config
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_alias_arn" "Should have state_machine_alias_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert_type $result.state_machine_alias_arn "string" "alias ARN should be string"
    assert_type $result.creation_date "string" "creation_date should be string"
    
    # Verify alias ARN contains the name
    assert ($result.state_machine_alias_arn | str contains $alias_name) "Alias ARN should contain alias name"
}

# UNIT TEST: create-state-machine-alias with description
# Entry point: create-state-machine-alias with optional description
# Exit point: returns same structure with description handling
# [test]
export def test_create_alias_with_description_unit []: nothing -> nothing {
    # Test inputs
    let alias_name = "test-alias-desc"
    let routing_config = [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}]
    let description = "Unit test alias"
    
    # Invoke the unit of work
    let result = create-state-machine-alias $alias_name $routing_config --description $description
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_alias_arn" "Should have alias ARN field"
    assert_type $result.state_machine_alias_arn "string" "ARN should be string"
}

# UNIT TEST: describe-state-machine-alias function
# Entry point: describe-state-machine-alias with ARN
# Exit point: returns alias details
# [test]
export def test_describe_alias_unit []: nothing -> nothing {
    # Test input
    let alias_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test:test-alias"
    
    # Invoke the unit of work
    let result = describe-state-machine-alias $alias_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "stateMachineAliasArn" "Should have stateMachineAliasArn field"
    assert_contains ($result | columns) "name" "Should have name field"
    assert_contains ($result | columns) "creationDate" "Should have creationDate field"
    assert_equal $result.stateMachineAliasArn $alias_arn "Should return the same ARN"
}

# UNIT TEST: update-state-machine-alias function
# Entry point: update-state-machine-alias with new routing
# Exit point: returns update confirmation
# [test]
export def test_update_alias_unit []: nothing -> nothing {
    # Test inputs
    let alias_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test:test-alias"
    let new_routing = [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 100}]
    
    # Invoke the unit of work
    let result = update-state-machine-alias $alias_arn --routing-configuration $new_routing
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "update_date" "Should have update_date field"
    assert_type $result.update_date "string" "update_date should be string"
}

# UNIT TEST: list-state-machine-aliases function
# Entry point: list-state-machine-aliases with state machine ARN
# Exit point: returns list of aliases
# [test]
export def test_list_aliases_unit []: nothing -> nothing {
    # Test input
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:test-machine"
    
    # Invoke the unit of work
    let result = list-state-machine-aliases $sm_arn
    
    # Check exit points
    assert_type $result "record" "Should return a record"
    assert_contains ($result | columns) "state_machine_aliases" "Should have state_machine_aliases field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.state_machine_aliases "list" "aliases should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: Routing configuration validation
# Entry point: create-state-machine-alias with various routing configs
# Exit point: verify handling of different routing patterns
# [test]
export def test_routing_configuration_patterns_unit []: nothing -> nothing {
    # Single version routing
    let single_routing = [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}]
    let result1 = create-state-machine-alias "single-routing" $single_routing
    assert_type $result1 "record" "Single routing should work"
    
    # Multi-version routing
    let multi_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 80},
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 20}
    ]
    let result2 = create-state-machine-alias "multi-routing" $multi_routing
    assert_type $result2 "record" "Multi routing should work"
    
    # Equal split routing
    let equal_routing = [
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 50},
        {"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:2", "weight": 50}
    ]
    let result3 = create-state-machine-alias "equal-routing" $equal_routing
    assert_type $result3 "record" "Equal routing should work"
    
    # All results should have consistent structure
    assert_contains ($result1 | columns) "state_machine_alias_arn" "Single routing result should have ARN"
    assert_contains ($result2 | columns) "state_machine_alias_arn" "Multi routing result should have ARN"
    assert_contains ($result3 | columns) "state_machine_alias_arn" "Equal routing result should have ARN"
}

# UNIT TEST: Version ARN format consistency
# Entry point: publish-state-machine-version multiple times
# Exit point: verify consistent ARN format patterns
# [test]
export def test_version_arn_format_unit []: nothing -> nothing {
    # Test with different state machine ARNs
    let sm_arn1 = "arn:aws:states:us-east-1:123456789012:stateMachine:machine1"
    let sm_arn2 = "arn:aws:states:us-west-2:123456789012:stateMachine:machine2"
    let sm_arn3 = "arn:aws:states:eu-west-1:987654321098:stateMachine:machine3"
    
    # Invoke the unit of work
    let version1 = publish-state-machine-version $sm_arn1
    let version2 = publish-state-machine-version $sm_arn2
    let version3 = publish-state-machine-version $sm_arn3
    
    # Check exit points - all should follow same ARN pattern
    assert ($version1.state_machine_version_arn | str contains "us-east-1") "Version1 should contain region"
    assert ($version2.state_machine_version_arn | str contains "us-west-2") "Version2 should contain region"
    assert ($version3.state_machine_version_arn | str contains "eu-west-1") "Version3 should contain region"
    
    assert ($version1.state_machine_version_arn | str contains "123456789012") "Version1 should contain account"
    assert ($version2.state_machine_version_arn | str contains "123456789012") "Version2 should contain account"
    assert ($version3.state_machine_version_arn | str contains "987654321098") "Version3 should contain account"
    
    assert ($version1.state_machine_version_arn | str contains "machine1") "Version1 should contain machine name"
    assert ($version2.state_machine_version_arn | str contains "machine2") "Version2 should contain machine name"
    assert ($version3.state_machine_version_arn | str contains "machine3") "Version3 should contain machine name"
}

# UNIT TEST: Alias lifecycle consistency
# Entry point: Complete alias lifecycle operations
# Exit point: verify data consistency through lifecycle
# [test]
export def test_alias_lifecycle_consistency_unit []: nothing -> nothing {
    # Setup test data
    let sm_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:lifecycle-test"
    let alias_name = "lifecycle-alias"
    
    # 1. Publish version
    let version = publish-state-machine-version $sm_arn
    assert_type $version "record" "Version publish should return record"
    
    # 2. Create alias
    let routing = [{"stateMachineVersionArn": $version.state_machine_version_arn, "weight": 100}]
    let alias = create-state-machine-alias $alias_name $routing
    assert_type $alias "record" "Alias creation should return record"
    
    # 3. Describe alias
    let described = describe-state-machine-alias $alias.state_machine_alias_arn
    assert_type $described "record" "Alias description should return record"
    
    # 4. Update alias
    let updated = update-state-machine-alias $alias.state_machine_alias_arn --description "Updated description"
    assert_type $updated "record" "Alias update should return record"
    
    # Verify consistency throughout lifecycle
    assert ($described.stateMachineAliasArn == $alias.state_machine_alias_arn) "ARNs should be consistent"
    assert_contains ($updated | columns) "update_date" "Update should have update_date"
}