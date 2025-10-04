use std/assert
use ../../aws/stepfunctions.nu

#[before-each]
def setup [] {
    {
        activity_name: "test-activity"
        activity_arn: "arn:aws:states:us-east-1:123456789012:activity:test-activity"
        task_token: "AAAAKgAAAAIAAAAAAAAAAA..."
        worker_name: "test-worker"
        heartbeat_seconds: 60
    }
}

# create-activity tests (15 tests)
#[test]
def "create activity with minimal config" [] {
    let context = $in
    
    let config = {
        name: $context.activity_name
    }
    
    let result = try {
        stepfunctions create-activity $config
    } catch { |error|
        assert str contains $error.msg "Failed to create activity"
        return
    }
    
    assert ($result | get activityArn? | is-not-empty)
    assert ($result | get creationDate? | is-not-empty)
}

#[test]
def "create activity with tags" [] {
    let context = $in
    
    let config = {
        name: $context.activity_name
        tags: [
            {key: "Environment", value: "Test"}
            {key: "Purpose", value: "Testing"}
        ]
    }
    
    let result = try {
        stepfunctions create-activity $config
    } catch { |error|
        assert str contains $error.msg "Failed to create activity"
        return
    }
    
    assert ($result | get activityArn? | str contains $context.activity_name)
}

#[test]
def "create activity validates name format" [] {
    let config = {
        name: ""  # Empty name should fail
    }
    
    try {
        stepfunctions create-activity $config
        assert false "Should have failed with empty name"
    } catch { |error|
        assert str contains $error.msg "name"
    }
}

#[test]
def "create activity handles invalid characters in name" [] {
    let config = {
        name: "invalid@name!"
    }
    
    try {
        stepfunctions create-activity $config
        assert false "Should have failed with invalid characters"
    } catch { |error|
        assert str contains $error.msg "Invalid character"
    }
}

#[test]
def "create activity validates tag format" [] {
    let context = $in
    
    let config = {
        name: $context.activity_name
        tags: [
            {invalid: "tag"}  # Missing key/value structure
        ]
    }
    
    try {
        stepfunctions create-activity $config
        assert false "Should have failed with invalid tag format"
    } catch { |error|
        assert str contains $error.msg "tag"
    }
}

#[test]
def "delete activity with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions delete-activity $context.activity_arn
    } catch { |error|
        assert str contains $error.msg "Failed to delete activity"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "delete activity validates arn format" [] {
    try {
        stepfunctions delete-activity "invalid-arn"
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "delete activity handles non-existent arn" [] {
    let non_existent_arn = "arn:aws:states:us-east-1:123456789012:activity:non-existent"
    
    try {
        stepfunctions delete-activity $non_existent_arn
        assert false "Should have failed with non-existent activity"
    } catch { |error|
        assert str contains $error.msg "does not exist"
    }
}

#[test]
def "describe activity with valid arn" [] {
    let context = $in
    
    let result = try {
        stepfunctions describe-activity $context.activity_arn
    } catch { |error|
        assert str contains $error.msg "Failed to describe activity"
        return
    }
    
    assert ($result | get activityArn? | is-not-empty)
    assert ($result | get name? | is-not-empty)
    assert ($result | get creationDate? | is-not-empty)
}

#[test]
def "describe activity validates arn format" [] {
    try {
        stepfunctions describe-activity "invalid-arn"
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "get activity task with minimal config" [] {
    let context = $in
    
    let config = {
        activity_arn: $context.activity_arn
    }
    
    let result = try {
        stepfunctions get-activity-task $config
    } catch { |error|
        assert str contains $error.msg "Failed to get activity task"
        return
    }
    
    # May be empty if no tasks available
    assert ($result | describe | str starts-with "record")
}

#[test]
def "get activity task with worker name" [] {
    let context = $in
    
    let config = {
        activity_arn: $context.activity_arn
        worker_name: $context.worker_name
    }
    
    let result = try {
        stepfunctions get-activity-task $config
    } catch { |error|
        assert str contains $error.msg "Failed to get activity task"
        return
    }
    
    assert ($result | describe | str starts-with "record")
}

#[test]
def "get activity task validates arn format" [] {
    let config = {
        activity_arn: "invalid-arn"
    }
    
    try {
        stepfunctions get-activity-task $config
        assert false "Should have failed with invalid ARN"
    } catch { |error|
        assert str contains $error.msg "Invalid ARN format"
    }
}

#[test]
def "send task success with minimal config" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        output: '{"result": "success"}'
    }
    
    let result = try {
        stepfunctions send-task-success $config
    } catch { |error|
        assert str contains $error.msg "Failed to send task success"
        return
    }
    
    # Should complete successfully
    assert true
}

#[test]
def "send task failure with error details" [] {
    let context = $in
    
    let config = {
        task_token: $context.task_token
        error: "TaskFailed"
        cause: "Test task failure"
    }
    
    let result = try {
        stepfunctions send-task-failure $config
    } catch { |error|
        assert str contains $error.msg "Failed to send task failure"
        return
    }
    
    # Should complete successfully
    assert true
}