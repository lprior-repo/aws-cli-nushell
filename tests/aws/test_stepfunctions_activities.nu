# Pure Unit Tests for Step Functions Activity Operations
# Each test invokes a unit of work and checks its exit points
# Tests are isolated, idempotent, and focus on inputs/outputs

use ../../aws/stepfunctions_testing.nu *
use ../../utils/test_utils.nu *

# [before-all]
export def setup_all []: nothing -> nothing {
    print "Setting up Step Functions Activity tests"
}

# [after-all]
export def teardown_all []: nothing -> nothing {
    print "Cleaning up Step Functions Activity tests"
}

# UNIT TEST: create-activity function
# Entry point: create-activity with name
# Exit point: returns activity ARN and creation date
# [test]
export def test_create_activity []: nothing -> nothing {
    let test_name = "nutest-activity-test"
    
    # Invoke the unit of work
    let result = create-activity $test_name
    
    # Check exit points
    assert_type $result "record" "create-activity should return record type"
    assert_contains ($result | columns) "activity_arn" "create-activity should have activity_arn field"
    assert_contains ($result | columns) "creation_date" "create-activity should have creation_date field"
    assert ($result.activity_arn | str contains $test_name) "ARN should contain activity name"
    assert_type $result.activity_arn "string" "activity_arn should be string"
    assert_type $result.creation_date "string" "creation_date should be string"
}

# UNIT TEST: create-activity with tags
# Entry point: create-activity with tags parameter
# Exit point: returns activity with tag handling
# [test]
export def test_create_activity_with_tags []: nothing -> nothing {
    let test_name = "nutest-activity-tagged"
    let tags = [{"Key": "Environment", "Value": "Test"}, {"Key": "Purpose", "Value": "NuTest"}]
    
    # Invoke the unit of work
    let result = create-activity $test_name --tags $tags
    
    # Check exit points
    assert_type $result "record" "create-activity with tags should return record type"
    assert_contains ($result | columns) "activity_arn" "Should have activity_arn field"
    assert_contains ($result | columns) "creation_date" "Should have creation_date field"
    assert ($result.activity_arn | str contains $test_name) "ARN should contain activity name"
}

# UNIT TEST: delete-activity function
# Entry point: delete-activity with activity ARN
# Exit point: returns nothing (successful deletion)
# [test]
export def test_delete_activity []: nothing -> nothing {
    let test_activity_arn = "arn:aws:states:us-east-1:123456789012:activity:nutest-activity-test"
    
    # Invoke the unit of work
    let result = delete-activity $test_activity_arn
    
    # Check exit points
    assert_type $result "nothing" "delete-activity should return nothing type"
}

# UNIT TEST: describe-activity function
# Entry point: describe-activity with activity ARN
# Exit point: returns activity details
# [test]
export def test_describe_activity []: nothing -> nothing {
    let test_activity_arn = "arn:aws:states:us-east-1:123456789012:activity:nutest-activity-test"
    
    # Invoke the unit of work
    let result = describe-activity $test_activity_arn
    
    # Check exit points
    assert_type $result "record" "describe-activity should return record type"
    assert_contains ($result | columns) "activityArn" "Should have activityArn field"
    assert_contains ($result | columns) "name" "Should have name field"
    assert_contains ($result | columns) "creationDate" "Should have creationDate field"
    assert_equal $result.activityArn $test_activity_arn "Should return the same activity ARN"
}

# UNIT TEST: list-activities function
# Entry point: list-activities
# Exit point: returns list of activities with metadata
# [test]
export def test_list_activities []: nothing -> nothing {
    # Invoke the unit of work
    let result = list-activities
    
    # Check exit points
    assert_type $result "record" "list-activities should return record type"
    assert_contains ($result | columns) "activities" "list-activities should have activities field"
    assert_contains ($result | columns) "next_token" "list-activities should have next_token field"
    assert_type $result.activities "list" "activities should be list"
    assert_type $result.next_token "string" "next_token should be string"
}

# UNIT TEST: list-activities with parameters
# Entry point: list-activities with max-results and next-token
# Exit point: returns paginated activity list
# [test]
export def test_list_activities_with_params []: nothing -> nothing {
    # Invoke the unit of work
    let result = list-activities --max-results 50 --next-token "test-token"
    
    # Check exit points
    assert_type $result "record" "list-activities with params should return record type"
    assert_contains ($result | columns) "activities" "Should have activities field"
    assert_contains ($result | columns) "next_token" "Should have next_token field"
    assert_type $result.activities "list" "activities should be list"
}

# UNIT TEST: get-activity-task function
# Entry point: get-activity-task with activity ARN
# Exit point: returns task token and input
# [test]
export def test_get_activity_task []: nothing -> nothing {
    let test_activity_arn = "arn:aws:states:us-east-1:123456789012:activity:nutest-activity-test"
    
    # Invoke the unit of work
    let result = get-activity-task $test_activity_arn
    
    # Check exit points
    assert_type $result "record" "get-activity-task should return record type"
    assert_contains ($result | columns) "task_token" "get-activity-task should have task_token field"
    assert_contains ($result | columns) "input" "get-activity-task should have input field"
    assert_type $result.task_token "string" "task_token should be string"
    assert_type $result.input "string" "input should be string"
}

# UNIT TEST: get-activity-task with worker name
# Entry point: get-activity-task with worker-name parameter
# Exit point: returns task with worker identification
# [test]
export def test_get_activity_task_with_worker []: nothing -> nothing {
    let test_activity_arn = "arn:aws:states:us-east-1:123456789012:activity:nutest-activity-test"
    let worker_name = "nutest-worker-1"
    
    # Invoke the unit of work
    let result = get-activity-task $test_activity_arn --worker-name $worker_name
    
    # Check exit points
    assert_type $result "record" "get-activity-task with worker-name should return record type"
    assert_contains ($result | columns) "task_token" "Should have task_token field"
    assert_contains ($result | columns) "input" "Should have input field"
    assert_type $result.task_token "string" "task_token should be string"
}

# UNIT TEST: send-task-success function
# Entry point: send-task-success with task token and output
# Exit point: returns nothing (successful completion)
# [test]
export def test_send_task_success []: nothing -> nothing {
    let test_task_token = "AAAAKgAAAAIAAAAAAAAAAQYyOTAyN2E4NC1hMGE4LTQzOWQtOGJjMy0zNjY4MmY5MDk3Y2EAAAAA"
    let test_output = '{"result": "success", "data": "test completed"}'
    
    # Invoke the unit of work
    let result = send-task-success $test_task_token $test_output
    
    # Check exit points
    assert_type $result "nothing" "send-task-success should return nothing type"
}

# UNIT TEST: send-task-failure function
# Entry point: send-task-failure with task token
# Exit point: returns nothing (failure reported)
# [test]
export def test_send_task_failure []: nothing -> nothing {
    let test_task_token = "AAAAKgAAAAIAAAAAAAAAAQYyOTAyN2E4NC1hMGE4LTQzOWQtOGJjMy0zNjY4MmY5MDk3Y2EAAAAA"
    
    # Invoke the unit of work
    let result = send-task-failure $test_task_token
    
    # Check exit points
    assert_type $result "nothing" "send-task-failure should return nothing type"
}

# UNIT TEST: send-task-failure with error and cause
# Entry point: send-task-failure with error and cause parameters
# Exit point: returns nothing with error details
# [test]
export def test_send_task_failure_with_error []: nothing -> nothing {
    let test_task_token = "AAAAKgAAAAIAAAAAAAAAAQYyOTAyN2E4NC1hMGE4LTQzOWQtOGJjMy0zNjY4MmY5MDk3Y2EAAAAA"
    
    # Invoke the unit of work
    let result = send-task-failure $test_task_token --error "TestError" --cause "Test failure for nutest"
    
    # Check exit points
    assert_type $result "nothing" "send-task-failure with params should return nothing type"
}

# UNIT TEST: send-task-heartbeat function
# Entry point: send-task-heartbeat with task token
# Exit point: returns nothing (heartbeat sent)
# [test]
export def test_send_task_heartbeat []: nothing -> nothing {
    let test_task_token = "AAAAKgAAAAIAAAAAAAAAAQYyOTAyN2E4NC1hMGE4LTQzOWQtOGJjMy0zNjY4MmY5MDk3Y2EAAAAA"
    
    # Invoke the unit of work
    let result = send-task-heartbeat $test_task_token
    
    # Check exit points
    assert_type $result "nothing" "send-task-heartbeat should return nothing type"
}

# UNIT TEST: Activity lifecycle composition
# Entry point: Complete activity workflow functions
# Exit point: Verify data flow consistency through lifecycle
# [test]
export def test_activity_lifecycle []: nothing -> nothing {
    let activity_name = "nutest-lifecycle-activity"
    let tags = [{"Key": "Test", "Value": "Lifecycle"}]
    
    # 1. Create activity
    let create_result = create-activity $activity_name --tags $tags
    assert_type $create_result "record" "Activity creation should return record"
    assert_contains ($create_result | columns) "activity_arn" "Created activity should have ARN"
    
    # 2. Describe activity using the created ARN
    let describe_result = describe-activity $create_result.activity_arn
    assert_type $describe_result "record" "Activity description should return record"
    assert_equal $describe_result.activityArn $create_result.activity_arn "ARNs should match between create and describe"
    
    # 3. Get task (returns mock data for testing)
    let task_result = get-activity-task $create_result.activity_arn --worker-name "nutest-worker"
    assert_type $task_result "record" "Getting activity task should return record"
    assert_contains ($task_result | columns) "task_token" "Task should have token"
    
    # 4. Send task success
    let task_output = '{"processed": true, "timestamp": "2024-01-01T00:00:00Z"}'
    let success_result = send-task-success $task_result.task_token $task_output
    assert_type $success_result "nothing" "Task success should complete"
    
    # 5. Send task heartbeat 
    let heartbeat_result = send-task-heartbeat $task_result.task_token
    assert_type $heartbeat_result "nothing" "Task heartbeat should complete"
    
    # 6. Delete activity
    let delete_result = delete-activity $create_result.activity_arn
    assert_type $delete_result "nothing" "Activity deletion should complete"
}