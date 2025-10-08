# AWS CLI Nushell Error Handling
# Standardized error handling using Nushell's native error system

# ============================================================================
# NUSHELL-NATIVE ERROR PATTERNS
# ============================================================================

# Enhanced AWS call with comprehensive Nushell-native error handling
export def enhanced-aws-call [
    operation: string,
    args: list<string>,
    --mock-response: closure = { {} }
]: nothing -> any {
    let config = {
        mock_mode: (($env.STEPFUNCTIONS_MOCK_MODE? | default "false") == "true"),
        region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
        profile: ($env.AWS_PROFILE? | default "default")
    }
    
    if $config.mock_mode {
        # Return mock response in test mode
        do $mock_response
    } else {
        # Execute real AWS CLI call with enhanced error handling
        try {
            ^aws ...$args | from json
        } catch { |err|
            # Parse AWS CLI error and create structured Nushell error
            let aws_error = parse-aws-cli-error $err $operation $args
            error make $aws_error
        }
    }
}

# Parse AWS CLI error output into structured format
def parse-aws-cli-error [
    error: record,
    operation: string,
    args: list<string>
]: record -> record {
    let error_msg = $error.msg? | default ""
    
    # Extract AWS-specific error information
    let aws_error_code = if ($error_msg | str contains "AccessDenied") {
        "AccessDenied"
    } else if ($error_msg | str contains "InvalidParameterValue") {
        "InvalidParameterValue"
    } else if ($error_msg | str contains "ResourceNotFound") {
        "ResourceNotFound"
    } else if ($error_msg | str contains "ThrottlingException") {
        "ThrottlingException"
    } else if ($error_msg | str contains "ValidationException") {
        "ValidationException"
    } else if ($error_msg | str contains "ServiceUnavailable") {
        "ServiceUnavailable"
    } else {
        "UnknownError"
    }
    
    # Create structured error with context
    {
        msg: $"AWS ($operation) failed: ($error_msg)",
        label: {
            text: $"AWS Error: ($aws_error_code)",
            span: (metadata $args).span?
        },
        help: get-error-help $aws_error_code $operation,
        aws_context: {
            operation: $operation,
            error_code: $aws_error_code,
            args: $args,
            original_error: $error_msg,
            region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
            profile: ($env.AWS_PROFILE? | default "default")
        }
    }
}

# Get helpful error messages based on error type
def get-error-help [
    error_code: string,
    operation: string
]: [string, string] -> string {
    match $error_code {
        "AccessDenied" => $"Check your AWS credentials and IAM permissions for ($operation)",
        "InvalidParameterValue" => $"Verify the parameters passed to ($operation) are valid",
        "ResourceNotFound" => $"The requested resource does not exist or has been deleted",
        "ThrottlingException" => "Request rate exceeded, try again with exponential backoff",
        "ValidationException" => $"Input validation failed for ($operation), check parameter format",
        "ServiceUnavailable" => "AWS service is temporarily unavailable, try again later",
        _ => $"See AWS documentation for ($operation) command"
    }
}

# ============================================================================
# ERROR RECOVERY PATTERNS
# ============================================================================

# Resilient AWS operation with automatic retry
export def resilient-aws-call [
    operation: string,
    args: list<string>,
    --max-retries: int = 3,
    --backoff-base: int = 2,
    --mock-response: closure = { {} }
]: nothing -> any {
    def attempt-call [
        attempt: int,
        max_retries: int,
        backoff_base: int,
        operation: string,
        args: list<string>,
        mock_response: closure
    ]: [int, int, int, string, list<string>, closure] -> any {
        try {
            enhanced-aws-call $operation $args --mock-response $mock_response
        } catch { |err|
            if $attempt >= $max_retries {
                error propagate $err
            }
            
            # Check if error is retryable
            let is_retryable = is-retryable-error $err
            if not $is_retryable {
                error propagate $err
            }
            
            # Calculate backoff delay
            let delay = ($backoff_base ** $attempt)
            print $"Retrying ($operation) in ($delay) seconds... (attempt ($attempt + 1)/($max_retries + 1))"
            sleep ($delay | into duration --unit sec)
            
            attempt-call ($attempt + 1) $max_retries $backoff_base $operation $args $mock_response
        }
    }
    
    attempt-call 0 $max_retries $backoff_base $operation $args $mock_response
}

# Check if an error is retryable
def is-retryable-error [error: record]: record -> bool {
    let error_code = $error.aws_context?.error_code? | default ""
    $error_code in ["ThrottlingException", "ServiceUnavailable", "InternalServerError"]
}

# ============================================================================
# VALIDATION ERROR SYSTEM
# ============================================================================

# Create validation error with detailed context
export def create-validation-error [
    field: string,
    value: any,
    constraint: string,
    --context: record = {}
]: [string, any, string] -> record {
    {
        msg: $"Validation failed for field '($field)': ($constraint)",
        label: {
            text: "Validation Error",
            span: (metadata $value).span?
        },
        help: $"Check the ($field) parameter format and constraints",
        validation_context: {
            field: $field,
            value: $value,
            constraint: $constraint,
            additional_context: $context
        }
    }
}

# Aggregate multiple validation errors
export def aggregate-validation-errors [
    errors: list<record>
]: list<record> -> record {
    if ($errors | length) == 0 {
        return { valid: true, errors: [] }
    }
    
    let error_messages = $errors | each { |err| $err.msg } | str join ", "
    {
        msg: $"Multiple validation errors: ($error_messages)",
        label: {
            text: "Validation Errors",
            span: null
        },
        help: "Fix all validation errors before retrying",
        validation_context: {
            error_count: ($errors | length),
            individual_errors: $errors
        },
        valid: false,
        errors: $errors
    }
}

# ============================================================================
# PIPELINE ERROR HANDLING
# ============================================================================

# Error-aware pipeline operation
export def pipeline-safe [
    operation: closure,
    --continue-on-error = false,
    --error-handler: closure = { |err| $err }
]: [any -> any] {
    let input_data = $in
    
    try {
        $input_data | do $operation
    } catch { |err|
        if $continue_on_error {
            do $error_handler $err
        } else {
            error propagate $err
        }
    }
}

# Batch operation with individual error handling
export def batch-safe [
    operation: closure,
    --continue-on-error = true
]: [list<any> -> list<record>] {
    $in | each { |item|
        try {
            let result = $item | do $operation
            {
                success: true,
                item: $item,
                result: $result,
                error: null
            }
        } catch { |err|
            if $continue_on_error {
                {
                    success: false,
                    item: $item,
                    result: null,
                    error: $err.msg
                }
            } else {
                error propagate $err
            }
        }
    }
}

# ============================================================================
# ERROR CONTEXT HELPERS
# ============================================================================

# Add operation context to errors
export def with-operation-context [
    operation: string,
    operation_args: record = {}
]: [any -> any] {
    let input_data = $in
    
    try {
        $input_data
    } catch { |err|
        let enhanced_error = $err | merge {
            operation_context: {
                operation: $operation,
                args: $operation_args,
                timestamp: (date now | format date '%Y-%m-%d %H:%M:%S UTC')
            }
        }
        error make $enhanced_error
    }
}

# Add AWS resource context to errors
export def with-aws-context [
    resource_type: string,
    resource_arn: string = ""
]: [any -> any] {
    let input_data = $in
    
    try {
        $input_data
    } catch { |err|
        let enhanced_error = $err | merge {
            aws_resource_context: {
                resource_type: $resource_type,
                resource_arn: $resource_arn,
                region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
                account_id: extract-account-id-from-arn $resource_arn
            }
        }
        error make $enhanced_error
    }
}

# Extract account ID from ARN
def extract-account-id-from-arn [arn: string]: string -> string {
    if ($arn | str starts-with "arn:aws:") {
        let parts = $arn | split row ":"
        if ($parts | length) >= 5 {
            $parts | get 4
        } else {
            ""
        }
    } else {
        ""
    }
}

# ============================================================================
# ERROR LOGGING AND REPORTING
# ============================================================================

# Log error with structured information
export def log-error [
    error: record,
    --log-level: string = "ERROR"
]: record -> nothing {
    let log_entry = {
        timestamp: (date now | format date '%Y-%m-%d %H:%M:%S UTC'),
        level: $log_level,
        message: $error.msg,
        operation: ($error.aws_context?.operation? | default "unknown"),
        error_code: ($error.aws_context?.error_code? | default "unknown"),
        region: ($error.aws_context?.region? | default "unknown"),
        context: $error
    }
    
    # In a real implementation, this would write to a log file or send to a logging service
    print $"[$log_level] ($log_entry.timestamp): ($log_entry.message)"
    
    # Save to error log file
    let log_file = $"($env.HOME)/.cache/nuaws/errors.jsonl"
    mkdir ($log_file | path dirname)
    $log_entry | to json | save --append $log_file
}

# Get recent error logs
export def get-error-logs [
    --count: int = 10,
    --level: string = ""
]: nothing -> list<record> {
    let log_file = $"($env.HOME)/.cache/nuaws/errors.jsonl"
    
    if not ($log_file | path exists) {
        return []
    }
    
    let logs = open $log_file 
        | lines 
        | each { |line| $line | from json }
        | if ($level != "") { where level == $level } else { $in }
        | last $count
        | reverse
    
    $logs
}

# ============================================================================
# ERROR TESTING HELPERS
# ============================================================================

# Simulate AWS errors for testing
export def simulate-aws-error [
    error_type: string,
    operation: string = "test-operation"
]: [string, string] -> nothing {
    let error_map = {
        "access_denied": "An error occurred (AccessDenied) when calling the operation: User not authorized",
        "resource_not_found": "An error occurred (ResourceNotFoundException) when calling the operation: Resource not found",
        "validation": "An error occurred (ValidationException) when calling the operation: Invalid parameter value",
        "throttling": "An error occurred (ThrottlingException) when calling the operation: Rate exceeded",
        "service_unavailable": "An error occurred (ServiceUnavailableException) when calling the operation: Service temporarily unavailable"
    }
    
    let error_msg = $error_map | get $error_type | default "Unknown error"
    let mock_error = { msg: $error_msg }
    let structured_error = parse-aws-cli-error $mock_error $operation ["test", "command"]
    
    error make $structured_error
}

# Test error handling pipeline
export def test-error-handling [
    test_closure: closure
]: closure -> record {
    try {
        do $test_closure
        { success: true, error: null }
    } catch { |err|
        { success: false, error: $err }
    }
}