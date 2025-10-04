# AWS Lambda testing utilities
#
# Provides type-safe wrappers for AWS Lambda operations with comprehensive
# testing capabilities including function invocation, log retrieval, and
# configuration management.

use ../utils/test_utils.nu

# Lambda function configuration record type
export def lambda-config []: nothing -> record {
    {
        function_name: "",
        runtime: "",
        handler: "",
        role: "",
        code: {},
        environment: {},
        timeout: 30,
        memory_size: 128,
        dead_letter_config: {},
        vpc_config: {},
        layers: []
    }
}

# Invoke Lambda function with type-safe payload handling
export def invoke-function [
    --name: string,
    --payload: string = "{}",
    --invocation-type: string = "RequestResponse",
    --log-type: string = "None",
    --qualifier: string = "$LATEST"
]: nothing -> record<status_code: int, payload: any, log_result: string, executed_version: string> {
    let temp_file = $"/tmp/lambda_payload_(random chars --length 8).json"
    $payload | save $temp_file
    
    let result = try {
        let aws_result = run-external "aws" [
            "lambda", "invoke",
            "--function-name", $name,
            "--payload", $"file://($temp_file)",
            "--invocation-type", $invocation_type,
            "--log-type", $log_type,
            "--qualifier", $qualifier,
            $"/tmp/lambda_response_(random chars --length 8).json"
        ] | from json
        
        let response_file = $"/tmp/lambda_response_(random chars --length 8).json"
        let payload_result = if ($response_file | path exists) {
            try { open $response_file | from json } catch { open $response_file }
        } else { null }
        
        {
            status_code: $aws_result.StatusCode,
            payload: $payload_result,
            log_result: ($aws_result.LogResult? | default ""),
            executed_version: ($aws_result.ExecutedVersion? | default "$LATEST")
        }
    } catch { |error|
        error make {
            msg: $"Lambda function invocation failed: ($name)",
            label: { text: $error.msg }
        }
    } finally {
        if ($temp_file | path exists) { rm $temp_file }
    }
    
    $result
}

# Get Lambda function configuration
export def get-function [
    name: string,
    --qualifier: string = "$LATEST"
]: nothing -> record {
    let result = try {
        run-external "aws" [
            "lambda", "get-function",
            "--function-name", $name,
            "--qualifier", $qualifier
        ] | from json
    } catch { |error|
        error make {
            msg: $"Failed to get Lambda function: ($name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# List Lambda functions with optional filtering
export def list-functions [
    --max-items: int = 50,
    --function-version: string = "ALL"
]: nothing -> list<record> {
    let result = try {
        run-external "aws" [
            "lambda", "list-functions",
            "--max-items", ($max_items | into string),
            "--function-version", $function_version
        ] | from json
    } catch { |error|
        error make {
            msg: "Failed to list Lambda functions",
            label: { text: $error.msg }
        }
    }
    
    $result.Functions? | default []
}

# Get Lambda function logs from CloudWatch
export def get-function-logs [
    name: string,
    --start-time: string,
    --end-time: string,
    --filter-pattern: string = "",
    --limit: int = 100
]: nothing -> list<record> {
    let log_group = $"/aws/lambda/($name)"
    
    let args = [
        "logs", "filter-log-events",
        "--log-group-name", $log_group,
        "--limit", ($limit | into string)
    ]
    
    let args = if ($start_time != null) {
        $args | append ["--start-time", $start_time]
    } else { $args }
    
    let args = if ($end_time != null) {
        $args | append ["--end-time", $end_time]
    } else { $args }
    
    let args = if ($filter_pattern != "") {
        $args | append ["--filter-pattern", $filter_pattern]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to get logs for Lambda function: ($name)",
            label: { text: $error.msg }
        }
    }
    
    $result.events? | default []
}

# Update Lambda function code
export def update-function-code [
    name: string,
    --zip-file: string,
    --s3-bucket: string,
    --s3-key: string,
    --s3-object-version: string,
    --image-uri: string
]: nothing -> record {
    let args = ["lambda", "update-function-code", "--function-name", $name]
    
    let args = if ($zip_file != null) {
        $args | append ["--zip-file", $"fileb://($zip_file)"]
    } else { $args }
    
    let args = if ($s3_bucket != null and $s3_key != null) {
        $args | append ["--s3-bucket", $s3_bucket, "--s3-key", $s3_key]
    } else { $args }
    
    let args = if ($s3_object_version != null) {
        $args | append ["--s3-object-version", $s3_object_version]
    } else { $args }
    
    let args = if ($image_uri != null) {
        $args | append ["--image-uri", $image_uri]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to update Lambda function code: ($name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Create Lambda function for testing
export def create-test-function [
    name: string,
    runtime: string,
    handler: string,
    role: string,
    zip_file: string,
    --environment: record = {},
    --timeout: int = 30,
    --memory-size: int = 128,
    --tags: record = {}
]: nothing -> record {
    let env_vars = if ($environment | is-empty) {
        []
    } else {
        ["--environment", ($"Variables=" + ($environment | transpose key value | each { |row| $"($row.key)=($row.value)" } | str join ","))]
    }
    
    let tag_list = if ($tags | is-empty) {
        []
    } else {
        ["--tags", ($tags | transpose key value | each { |row| $"($row.key)=($row.value)" } | str join ",")]
    }
    
    let args = [
        "lambda", "create-function",
        "--function-name", $name,
        "--runtime", $runtime,
        "--role", $role,
        "--handler", $handler,
        "--zip-file", $"fileb://($zip_file)",
        "--timeout", ($timeout | into string),
        "--memory-size", ($memory_size | into string)
    ] | append $env_vars | append $tag_list
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to create Lambda function: ($name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Delete Lambda function
export def delete-function [
    name: string,
    --qualifier: string = "$LATEST"
]: nothing -> nothing {
    try {
        run-external "aws" [
            "lambda", "delete-function",
            "--function-name", $name,
            "--qualifier", $qualifier
        ]
    } catch { |error|
        error make {
            msg: $"Failed to delete Lambda function: ($name)",
            label: { text: $error.msg }
        }
    }
}

# Wait for Lambda function to be active
export def wait-for-function-active [
    name: string,
    --max-attempts: int = 30
]: nothing -> nothing {
    try {
        run-external "aws" [
            "lambda", "wait", "function-active",
            "--function-name", $name,
            "--cli-read-timeout", "300"
        ]
    } catch { |error|
        error make {
            msg: $"Timeout waiting for Lambda function to be active: ($name)",
            label: { text: $error.msg }
        }
    }
}

# Test Lambda function with assertions
export def test-function-invocation [
    name: string,
    payload: string,
    expected_status: int = 200,
    --assertion-closure: closure
]: nothing -> record {
    let result = invoke-function --name $name --payload $payload
    
    assert_equal $result.status_code $expected_status $"Lambda function ($name) should return status ($expected_status)"
    
    if ($assertion_closure != null) {
        do $assertion_closure $result
    }
    
    $result
}