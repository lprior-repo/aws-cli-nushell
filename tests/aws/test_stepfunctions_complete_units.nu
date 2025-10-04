# Complete Unit Tests for All Remaining Step Functions Commands
# Each test invokes a function through its entry point and checks one exit point
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up complete Step Functions unit tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up complete Step Functions unit tests"
}

# UNIT TEST: describe-state-machine function returns record
# Entry point: describe-state-machine(arn)
# Exit point: returns record type
# [test]
export def test_describe_state_machine_returns_record []: nothing -> nothing {
    let result = describe-state-machine "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "describe-state-machine should return record"
}

# UNIT TEST: describe-state-machine function has required fields
# Entry point: describe-state-machine(arn)
# Exit point: result contains stateMachineArn field
# [test]
export def test_describe_state_machine_has_arn_field []: nothing -> nothing {
    let result = describe-state-machine "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "stateMachineArn" "Should have stateMachineArn field"
}

# UNIT TEST: delete-state-machine function returns nothing
# Entry point: delete-state-machine(arn)
# Exit point: returns nothing type
# [test]
export def test_delete_state_machine_returns_nothing []: nothing -> nothing {
    let result = delete-state-machine "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "nothing" "delete-state-machine should return nothing"
}

# UNIT TEST: update-state-machine function returns record
# Entry point: update-state-machine(arn)
# Exit point: returns record type
# [test]
export def test_update_state_machine_returns_record []: nothing -> nothing {
    let result = update-state-machine "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "update-state-machine should return record"
}

# UNIT TEST: start-sync-execution function returns record
# Entry point: start-sync-execution(arn)
# Exit point: returns record type
# [test]
export def test_start_sync_execution_returns_record []: nothing -> nothing {
    let result = start-sync-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "start-sync-execution should return record"
}

# UNIT TEST: start-sync-execution function has executionArn field
# Entry point: start-sync-execution(arn)
# Exit point: result contains executionArn field
# [test]
export def test_start_sync_execution_has_execution_arn []: nothing -> nothing {
    let result = start-sync-execution "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "executionArn" "Should have executionArn field"
}

# UNIT TEST: stop-execution function returns record
# Entry point: stop-execution(arn)
# Exit point: returns record type
# [test]
export def test_stop_execution_returns_record []: nothing -> nothing {
    let result = stop-execution "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_type $result "record" "stop-execution should return record"
}

# UNIT TEST: stop-execution function has stop_date field
# Entry point: stop-execution(arn)
# Exit point: result contains stop_date field
# [test]
export def test_stop_execution_has_stop_date []: nothing -> nothing {
    let result = stop-execution "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_contains ($result | columns) "stop_date" "Should have stop_date field"
}

# UNIT TEST: describe-execution function returns record
# Entry point: describe-execution(arn)
# Exit point: returns record type
# [test]
export def test_describe_execution_returns_record []: nothing -> nothing {
    let result = describe-execution "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_type $result "record" "describe-execution should return record"
}

# UNIT TEST: list-executions function returns record
# Entry point: list-executions(--state-machine-arn arn)
# Exit point: returns record type
# [test]
export def test_list_executions_returns_record []: nothing -> nothing {
    let result = list-executions --state-machine-arn "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "list-executions should return record"
}

# UNIT TEST: list-executions function has executions field
# Entry point: list-executions(--state-machine-arn arn)
# Exit point: result contains executions field
# [test]
export def test_list_executions_has_executions_field []: nothing -> nothing {
    let result = list-executions --state-machine-arn "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "executions" "Should have executions field"
}

# UNIT TEST: get-execution-history function returns record
# Entry point: get-execution-history(arn)
# Exit point: returns record type
# [test]
export def test_get_execution_history_returns_record []: nothing -> nothing {
    let result = get-execution-history "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_type $result "record" "get-execution-history should return record"
}

# UNIT TEST: get-execution-history function has events field
# Entry point: get-execution-history(arn)
# Exit point: result contains events field
# [test]
export def test_get_execution_history_has_events []: nothing -> nothing {
    let result = get-execution-history "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_contains ($result | columns) "events" "Should have events field"
}

# UNIT TEST: send-task-success function returns nothing
# Entry point: send-task-success(token, output)
# Exit point: returns nothing type
# [test]
export def test_send_task_success_returns_nothing []: nothing -> nothing {
    let result = send-task-success "test-token" "{\"result\": \"success\"}"
    assert_type $result "nothing" "send-task-success should return nothing"
}

# UNIT TEST: send-task-failure function returns nothing
# Entry point: send-task-failure(token)
# Exit point: returns nothing type
# [test]
export def test_send_task_failure_returns_nothing []: nothing -> nothing {
    let result = send-task-failure "test-token"
    assert_type $result "nothing" "send-task-failure should return nothing"
}

# UNIT TEST: send-task-heartbeat function returns nothing
# Entry point: send-task-heartbeat(token)
# Exit point: returns nothing type
# [test]
export def test_send_task_heartbeat_returns_nothing []: nothing -> nothing {
    let result = send-task-heartbeat "test-token"
    assert_type $result "nothing" "send-task-heartbeat should return nothing"
}

# UNIT TEST: delete-activity function returns nothing
# Entry point: delete-activity(arn)
# Exit point: returns nothing type
# [test]
export def test_delete_activity_returns_nothing []: nothing -> nothing {
    let result = delete-activity "arn:aws:states:us-east-1:123456789012:activity:test"
    assert_type $result "nothing" "delete-activity should return nothing"
}

# UNIT TEST: describe-activity function returns record
# Entry point: describe-activity(arn)
# Exit point: returns record type
# [test]
export def test_describe_activity_returns_record []: nothing -> nothing {
    let result = describe-activity "arn:aws:states:us-east-1:123456789012:activity:test"
    assert_type $result "record" "describe-activity should return record"
}

# UNIT TEST: describe-activity function has activityArn field
# Entry point: describe-activity(arn)
# Exit point: result contains activityArn field
# [test]
export def test_describe_activity_has_activity_arn []: nothing -> nothing {
    let result = describe-activity "arn:aws:states:us-east-1:123456789012:activity:test"
    assert_contains ($result | columns) "activityArn" "Should have activityArn field"
}

# UNIT TEST: get-activity-task function returns record
# Entry point: get-activity-task(arn)
# Exit point: returns record type
# [test]
export def test_get_activity_task_returns_record []: nothing -> nothing {
    let result = get-activity-task "arn:aws:states:us-east-1:123456789012:activity:test"
    assert_type $result "record" "get-activity-task should return record"
}

# UNIT TEST: tag-resource function returns nothing
# Entry point: tag-resource(arn, tags)
# Exit point: returns nothing type
# [test]
export def test_tag_resource_returns_nothing []: nothing -> nothing {
    let tags = [{"key": "Environment", "value": "Test"}]
    let result = tag-resource "arn:aws:states:us-east-1:123456789012:stateMachine:test" $tags
    assert_type $result "nothing" "tag-resource should return nothing"
}

# UNIT TEST: untag-resource function returns nothing
# Entry point: untag-resource(arn, tag_keys)
# Exit point: returns nothing type
# [test]
export def test_untag_resource_returns_nothing []: nothing -> nothing {
    let result = untag-resource "arn:aws:states:us-east-1:123456789012:stateMachine:test" ["Environment"]
    assert_type $result "nothing" "untag-resource should return nothing"
}

# UNIT TEST: list-tags-for-resource function returns record
# Entry point: list-tags-for-resource(arn)
# Exit point: returns record type
# [test]
export def test_list_tags_for_resource_returns_record []: nothing -> nothing {
    let result = list-tags-for-resource "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "list-tags-for-resource should return record"
}

# UNIT TEST: list-tags-for-resource function has tags field
# Entry point: list-tags-for-resource(arn)
# Exit point: result contains tags field
# [test]
export def test_list_tags_for_resource_has_tags []: nothing -> nothing {
    let result = list-tags-for-resource "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "tags" "Should have tags field"
}

# UNIT TEST: publish-state-machine-version function returns record
# Entry point: publish-state-machine-version(arn)
# Exit point: returns record type
# [test]
export def test_publish_version_returns_record []: nothing -> nothing {
    let result = publish-state-machine-version "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "publish-state-machine-version should return record"
}

# UNIT TEST: publish-state-machine-version function has version arn field
# Entry point: publish-state-machine-version(arn)
# Exit point: result contains state_machine_version_arn field
# [test]
export def test_publish_version_has_version_arn []: nothing -> nothing {
    let result = publish-state-machine-version "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "state_machine_version_arn" "Should have state_machine_version_arn field"
}

# UNIT TEST: list-state-machine-versions function returns record
# Entry point: list-state-machine-versions(arn)
# Exit point: returns record type
# [test]
export def test_list_versions_returns_record []: nothing -> nothing {
    let result = list-state-machine-versions "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "list-state-machine-versions should return record"
}

# UNIT TEST: list-state-machine-versions function has versions field
# Entry point: list-state-machine-versions(arn)
# Exit point: result contains state_machine_versions field
# [test]
export def test_list_versions_has_versions_field []: nothing -> nothing {
    let result = list-state-machine-versions "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "state_machine_versions" "Should have state_machine_versions field"
}

# UNIT TEST: delete-state-machine-version function returns nothing
# Entry point: delete-state-machine-version(arn)
# Exit point: returns nothing type
# [test]
export def test_delete_version_returns_nothing []: nothing -> nothing {
    let result = delete-state-machine-version "arn:aws:states:us-east-1:123456789012:stateMachine:test:1"
    assert_type $result "nothing" "delete-state-machine-version should return nothing"
}

# UNIT TEST: create-state-machine-alias function returns record
# Entry point: create-state-machine-alias(name, routing)
# Exit point: returns record type
# [test]
export def test_create_alias_returns_record []: nothing -> nothing {
    let routing = [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}]
    let result = create-state-machine-alias "test-alias" $routing
    assert_type $result "record" "create-state-machine-alias should return record"
}

# UNIT TEST: create-state-machine-alias function has alias arn field
# Entry point: create-state-machine-alias(name, routing)
# Exit point: result contains state_machine_alias_arn field
# [test]
export def test_create_alias_has_alias_arn []: nothing -> nothing {
    let routing = [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}]
    let result = create-state-machine-alias "test-alias" $routing
    assert_contains ($result | columns) "state_machine_alias_arn" "Should have state_machine_alias_arn field"
}

# UNIT TEST: describe-state-machine-alias function returns record
# Entry point: describe-state-machine-alias(arn)
# Exit point: returns record type
# [test]
export def test_describe_alias_returns_record []: nothing -> nothing {
    let result = describe-state-machine-alias "arn:aws:states:us-east-1:123456789012:stateMachine:test:alias"
    assert_type $result "record" "describe-state-machine-alias should return record"
}

# UNIT TEST: update-state-machine-alias function returns record
# Entry point: update-state-machine-alias(arn)
# Exit point: returns record type
# [test]
export def test_update_alias_returns_record []: nothing -> nothing {
    let result = update-state-machine-alias "arn:aws:states:us-east-1:123456789012:stateMachine:test:alias"
    assert_type $result "record" "update-state-machine-alias should return record"
}

# UNIT TEST: delete-state-machine-alias function returns nothing
# Entry point: delete-state-machine-alias(arn)
# Exit point: returns nothing type
# [test]
export def test_delete_alias_returns_nothing []: nothing -> nothing {
    let result = delete-state-machine-alias "arn:aws:states:us-east-1:123456789012:stateMachine:test:alias"
    assert_type $result "nothing" "delete-state-machine-alias should return nothing"
}

# UNIT TEST: list-state-machine-aliases function returns record
# Entry point: list-state-machine-aliases(arn)
# Exit point: returns record type
# [test]
export def test_list_aliases_returns_record []: nothing -> nothing {
    let result = list-state-machine-aliases "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_type $result "record" "list-state-machine-aliases should return record"
}

# UNIT TEST: list-state-machine-aliases function has aliases field
# Entry point: list-state-machine-aliases(arn)
# Exit point: result contains state_machine_aliases field
# [test]
export def test_list_aliases_has_aliases_field []: nothing -> nothing {
    let result = list-state-machine-aliases "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    assert_contains ($result | columns) "state_machine_aliases" "Should have state_machine_aliases field"
}

# UNIT TEST: describe-state-machine-for-execution function returns record
# Entry point: describe-state-machine-for-execution(arn)
# Exit point: returns record type
# [test]
export def test_describe_sm_for_execution_returns_record []: nothing -> nothing {
    let result = describe-state-machine-for-execution "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_type $result "record" "describe-state-machine-for-execution should return record"
}

# UNIT TEST: list-map-runs function returns record
# Entry point: list-map-runs(arn)
# Exit point: returns record type
# [test]
export def test_list_map_runs_returns_record []: nothing -> nothing {
    let result = list-map-runs "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_type $result "record" "list-map-runs should return record"
}

# UNIT TEST: describe-map-run function returns record
# Entry point: describe-map-run(arn)
# Exit point: returns record type
# [test]
export def test_describe_map_run_returns_record []: nothing -> nothing {
    let result = describe-map-run "arn:aws:states:us-east-1:123456789012:mapRun:test:run"
    assert_type $result "record" "describe-map-run should return record"
}

# UNIT TEST: update-map-run function returns nothing
# Entry point: update-map-run(arn)
# Exit point: returns nothing type
# [test]
export def test_update_map_run_returns_nothing []: nothing -> nothing {
    let result = update-map-run "arn:aws:states:us-east-1:123456789012:mapRun:test:run"
    assert_type $result "nothing" "update-map-run should return nothing"
}

# UNIT TEST: redrive-execution function returns record
# Entry point: redrive-execution(arn)
# Exit point: returns record type
# [test]
export def test_redrive_execution_returns_record []: nothing -> nothing {
    let result = redrive-execution "arn:aws:states:us-east-1:123456789012:execution:test:exec"
    assert_type $result "record" "redrive-execution should return record"
}

# UNIT TEST: create-test-state-machine function returns record
# Entry point: create-test-state-machine(name, role_arn)
# Exit point: returns record type
# [test]
export def test_create_test_state_machine_returns_record []: nothing -> nothing {
    let result = create-test-state-machine "test-helper" "arn:aws:iam::123456789012:role/TestRole"
    assert_type $result "record" "create-test-state-machine should return record"
}

# UNIT TEST: create-test-state-machine function has state machine arn
# Entry point: create-test-state-machine(name, role_arn)
# Exit point: result contains state_machine_arn field
# [test]
export def test_create_test_state_machine_has_arn []: nothing -> nothing {
    let result = create-test-state-machine "test-helper" "arn:aws:iam::123456789012:role/TestRole"
    assert_contains ($result | columns) "state_machine_arn" "Should have state_machine_arn field"
}

# UNIT TEST: test-stepfunctions-integration function returns record
# Entry point: test-stepfunctions-integration()
# Exit point: returns record type
# [test]
export def test_stepfunctions_integration_returns_record []: nothing -> nothing {
    let result = test-stepfunctions-integration
    assert_type $result "record" "test-stepfunctions-integration should return record"
}

# UNIT TEST: Function consistency - all create functions follow same pattern
# Entry point: create functions with consistent parameters
# Exit point: all return records with ARN fields
# [test]
export def test_create_functions_consistency []: nothing -> nothing {
    let sm_result = create-state-machine "test" '{"StartAt":"Pass","States":{"Pass":{"Type":"Pass","End":true}}}' "arn:aws:iam::123456789012:role/Test"
    let activity_result = create-activity "test-activity"
    let alias_result = create-state-machine-alias "test-alias" [{"stateMachineVersionArn": "arn:aws:states:us-east-1:123456789012:stateMachine:test:1", "weight": 100}]
    
    # All create functions should return records
    assert_type $sm_result "record" "create-state-machine should return record"
    assert_type $activity_result "record" "create-activity should return record"
    assert_type $alias_result "record" "create-state-machine-alias should return record"
    
    # All should have ARN fields (with appropriate names)
    assert_contains ($sm_result | columns) "state_machine_arn" "create-state-machine should have ARN field"
    assert_contains ($activity_result | columns) "activity_arn" "create-activity should have ARN field"
    assert_contains ($alias_result | columns) "state_machine_alias_arn" "create-state-machine-alias should have ARN field"
}

# UNIT TEST: Function consistency - all list functions follow same pattern
# Entry point: list functions
# Exit point: all return records with list fields and next_token
# [test]
export def test_list_functions_consistency []: nothing -> nothing {
    let machines = list-state-machines
    let activities = list-activities
    let executions = list-executions --state-machine-arn "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    let versions = list-state-machine-versions "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    let aliases = list-state-machine-aliases "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    
    # All list functions should return records
    assert_type $machines "record" "list-state-machines should return record"
    assert_type $activities "record" "list-activities should return record"
    assert_type $executions "record" "list-executions should return record"
    assert_type $versions "record" "list-state-machine-versions should return record"
    assert_type $aliases "record" "list-state-machine-aliases should return record"
    
    # All should have next_token for pagination
    assert_type $machines.next_token "string" "list-state-machines should have next_token"
    assert_type $activities.next_token "string" "list-activities should have next_token"
    assert_type $executions.next_token "string" "list-executions should have next_token"
    assert_type $versions.next_token "string" "list-state-machine-versions should have next_token"
    assert_type $aliases.next_token "string" "list-state-machine-aliases should have next_token"
}

# UNIT TEST: Function consistency - all delete functions follow same pattern
# Entry point: delete functions
# Exit point: all return nothing type
# [test]
export def test_delete_functions_consistency []: nothing -> nothing {
    let sm_result = delete-state-machine "arn:aws:states:us-east-1:123456789012:stateMachine:test"
    let activity_result = delete-activity "arn:aws:states:us-east-1:123456789012:activity:test"
    let version_result = delete-state-machine-version "arn:aws:states:us-east-1:123456789012:stateMachine:test:1"
    let alias_result = delete-state-machine-alias "arn:aws:states:us-east-1:123456789012:stateMachine:test:alias"
    
    # All delete functions should return nothing
    assert_type $sm_result "nothing" "delete-state-machine should return nothing"
    assert_type $activity_result "nothing" "delete-activity should return nothing"
    assert_type $version_result "nothing" "delete-state-machine-version should return nothing"
    assert_type $alias_result "nothing" "delete-state-machine-alias should return nothing"
}