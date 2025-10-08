# Error Handler - Nushell-native error handling for AWS operations
# Provides structured error messages with helpful suggestions and context

# AWS error categories and patterns
const AWS_ERROR_CATEGORIES = {
    authentication: [
        "InvalidAccessKeyId",
        "SignatureDoesNotMatch", 
        "ExpiredToken",
        "AccessDenied",
        "InvalidClientTokenId",
        "NoCredentialsError"
    ],
    authorization: [
        "UnauthorizedOperation",
        "AccessDenied",
        "Forbidden",
        "InsufficientPrivileges"
    ],
    validation: [
        "ValidationException",
        "InvalidParameterValue",
        "InvalidParameterCombination",
        "MissingParameter",
        "InvalidRequest"
    ],
    not_found: [
        "NoSuchBucket",
        "NoSuchKey",
        "ResourceNotFoundException",
        "InvalidInstanceID.NotFound",
        "NoSuchEntity"
    ],
    quota_limits: [
        "LimitExceededException",
        "RequestLimitExceeded",
        "ThrottlingException",
        "TooManyRequestsException",
        "ServiceQuotaExceededException"
    ],
    resource_conflict: [
        "ResourceAlreadyExists",
        "BucketAlreadyExists",
        "EntityAlreadyExists",
        "ConditionalCheckFailedException"
    ],
    service_issues: [
        "ServiceUnavailable",
        "InternalError",
        "InternalFailure",
        "RequestTimeout"
    ]
}

# Handle plugin-specific errors
export def handle-plugin-error [
    err: record,
    service: string,
    args: list
] {
    let error_context = {
        type: "plugin",
        service: $service,
        args: $args,
        original_error: $err
    }
    
    # Determine error type
    match $err.msg {
        $msg if ($msg | str contains "not found") => {
            make-service-not-found-error $error_context
        },
        $msg if ($msg | str contains "Failed to load") => {
            make-service-loading-error $error_context
        },
        _ => {
            make-generic-plugin-error $error_context
        }
    }
}

# Handle AWS service operation errors
export def handle-service-error [
    err: record,
    service: string,
    operation: string,
    args: list
] {
    let error_context = {
        type: "service",
        service: $service,
        operation: $operation,
        args: $args,
        original_error: $err
    }
    
    # Parse AWS error if possible
    let aws_error = parse-aws-error $err.msg
    let error_category = classify-aws-error $aws_error.code
    
    # Route to appropriate error handler
    match $error_category {
        "authentication" => { make-authentication-error $error_context $aws_error },
        "authorization" => { make-authorization-error $error_context $aws_error },
        "validation" => { make-validation-error $error_context $aws_error },
        "not_found" => { make-not-found-error $error_context $aws_error },
        "quota_limits" => { make-quota-error $error_context $aws_error },
        "resource_conflict" => { make-conflict-error $error_context $aws_error },
        "service_issues" => { make-service-error $error_context $aws_error },
        _ => { make-generic-aws-error $error_context $aws_error }
    }
}

# Handle direct AWS CLI errors
export def handle-aws-cli-error [
    err: record,
    service: string,
    args: list
] {
    let error_context = {
        type: "aws_cli",
        service: $service,
        args: $args,
        original_error: $err
    }
    
    # Parse AWS CLI error
    let aws_error = parse-aws-error $err.msg
    let error_category = classify-aws-error $aws_error.code
    
    # Handle based on category
    match $error_category {
        "authentication" => { make-authentication-error $error_context $aws_error },
        "validation" => { make-validation-error $error_context $aws_error },
        _ => { make-generic-aws-error $error_context $aws_error }
    }
}

# Parse AWS error messages
def parse-aws-error [error_message: string]: nothing -> record {
    # Try to extract structured AWS error information
    let parsed = $error_message | parse --regex "An error occurred \\((?P<code>[^)]+)\\) when calling the (?P<operation>\\w+) operation: (?P<message>.+)"
    
    if ($parsed | length) > 0 {
        $parsed | first
    } else {
        # Try alternative formats
        let simple_parse = $error_message | parse --regex "(?P<code>\\w+): (?P<message>.+)"
        
        if ($simple_parse | length) > 0 {
            ($simple_parse | first) | insert operation "unknown"
        } else {
            {
                code: "UnknownError",
                operation: "unknown",
                message: $error_message
            }
        }
    }
}

# Classify AWS error by category
def classify-aws-error [error_code: string]: nothing -> string {
    for category in ($AWS_ERROR_CATEGORIES | transpose category codes) {
        if $error_code in $category.codes {
            return $category.category
        }
    }
    
    "unknown"
}

# Authentication error handler
def make-authentication-error [context: record, aws_error: record] {
    error make {
        msg: $"🔐 AWS Authentication Error: ($aws_error.code): ($aws_error.message)",
        help: $"
Authentication failed. Your AWS credentials are invalid or expired.

Possible solutions:
  1. Check AWS credentials: aws configure list
  2. Verify access keys: cat ~/.aws/credentials
  3. Check assumed role: aws sts get-caller-identity
  4. Verify IAM permissions for ($context.service):($aws_error.operation)
  5. Update credentials: aws configure
  
Environment variables:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN

Documentation: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html"
    }
}

# Authorization error handler
def make-authorization-error [context: record, aws_error: record] {
    error make {
        msg: $"🚫 AWS Authorization Error: ($aws_error.code): ($aws_error.message)",
        help: $"
You don't have permission to perform this operation.

Required permissions for ($context.service):($aws_error.operation):
  - Check IAM policies attached to your user/role
  - Verify resource-based policies (bucket policies, etc.)
  - Ensure you're in the correct AWS account/region

To diagnose:
  1. Check your identity: aws sts get-caller-identity
  2. Review IAM policies: aws iam list-attached-user-policies --user-name YOUR_USER
  3. Test permissions: aws iam simulate-principal-policy

IAM Policy Simulator: https://policysim.aws.amazon.com/"
    }
}

# Validation error handler
def make-validation-error [context: record, aws_error: record] {
    let command = (["nuaws", $context.service, $context.operation] | append $context.args | str join " ")
    
    error make {
        msg: $"❌ Invalid Parameters: ($aws_error.message)",
        label: {
            text: $"($aws_error.code) - Check parameter values",
            span: {start: 0, end: 10}
        },
        help: $"
The parameters provided are invalid or incomplete.

Command attempted: ($command)

Common issues:
  1. Missing required parameters
  2. Invalid parameter format (ARNs, IDs, regions)
  3. Incorrect parameter types (string vs integer)
  4. Parameter value constraints violated

To fix:
  1. Check parameter syntax: help nuaws ($context.service) ($context.operation?)
  2. Validate required parameters are provided
  3. Verify parameter formats match AWS requirements
  4. Check service documentation for constraints

Example:
  nuaws ($context.service) ($context.operation?) --help"
    }
}

# Resource not found error handler
def make-not-found-error [context: record, aws_error: record] {
    let suggestions = get-resource-suggestions $context.service $aws_error.code
    
    error make {
        msg: $"🔍 Resource Not Found: ($aws_error.message)",
        label: {
            text: $"($aws_error.code) - Resource doesn't exist",
            span: {start: 0, end: 10}
        },
        help: $"
The requested resource doesn't exist or you don't have permission to view it.

Possible causes:
  1. Wrong region - Current: ($env.AWS_DEFAULT_REGION? | default 'not set')
  2. Resource was deleted or never created
  3. Typo in resource identifier
  4. Insufficient permissions to view the resource
  5. Wrong AWS account

($suggestions)"
    }
}

# Quota/throttling error handler
def make-quota-error [context: record, aws_error: record] {
    error make {
        msg: $"⏸️  Rate Limit / Quota Exceeded: ($aws_error.message)",
        label: {
            text: $"($aws_error.code) - Too many requests or quota exceeded",
            span: {start: 0, end: 10}
        },
        help: $"
You've exceeded the API rate limit or service quota.

Solutions:
  1. Wait and retry (AWS implements exponential backoff)
  2. Reduce request frequency in scripts
  3. Use pagination with smaller page sizes
  4. Request a service quota increase if needed

For scripts:
  - Implement exponential backoff
  - Use batch operations where available
  - Add delays between requests

Service Quotas Console: https://console.aws.amazon.com/servicequotas/
Rate limiting docs: https://docs.aws.amazon.com/general/latest/gr/api-retries.html"
    }
}

# Resource conflict error handler
def make-conflict-error [context: record, aws_error: record] {
    error make {
        msg: $"⚠️  Resource Conflict: ($aws_error.message)",
        label: {
            text: $"($aws_error.code) - Resource already exists or conflict",
            span: {start: 0, end: 10}
        },
        help: $"
The resource you're trying to create already exists or there's a conflict.

Options:
  1. Use a different name/identifier
  2. Delete the existing resource first
  3. Update the existing resource instead of creating new
  4. Check if you're in the right AWS account/region

To list existing resources:
  nuaws ($context.service) list-*    # or describe-*
  nuaws ($context.service) help      # see available list operations"
    }
}

# Service issues error handler
def make-service-error [context: record, aws_error: record] {
    error make {
        msg: $"🔧 AWS Service Issue: ($aws_error.message)",
        label: {
            text: $"($aws_error.code) - AWS service temporarily unavailable",
            span: {start: 0, end: 10}
        },
        help: $"
AWS service is experiencing issues. This is typically temporary.

Actions:
  1. Wait a few minutes and try again
  2. Check AWS Service Health Dashboard
  3. Try a different AWS region if urgent
  4. Implement retry logic in scripts

AWS Service Health: https://status.aws.amazon.com/
Current region: ($env.AWS_DEFAULT_REGION? | default 'not set')"
    }
}

# Service not found error handler
def make-service-not-found-error [context: record] {
    error make {
        msg: $"Service '($context.service)' not found",
        label: {
            text: "unknown AWS service",
            span: {start: 0, end: 10}
        },
        help: $"
The service '($context.service)' is not available or not loaded.

Available services:
  nuaws help    # list all available services

If this is a valid AWS service, it may need to be generated:
  1. The service might not be implemented yet
  2. Try the AWS CLI directly: aws ($context.service) help
  3. Report missing services for implementation"
    }
}

# Service loading error handler
def make-service-loading-error [context: record] {
    error make {
        msg: $"Failed to load service '($context.service)'",
        label: {
            text: "service loading failed",
            span: {start: 0, end: 10}
        },
        help: $"
Could not load the AWS service module.

Possible causes:
  1. Service module file is corrupted
  2. Missing dependencies
  3. Syntax errors in generated code

Troubleshooting:
  1. Try regenerating: nuaws cache clear
  2. Check debug output: NUAWS_DEBUG=true nuaws ($context.service) help
  3. Use AWS CLI directly: aws ($context.service) help

Error details: ($context.original_error.msg)"
    }
}

# Generic plugin error handler
def make-generic-plugin-error [context: record] {
    error make {
        msg: $"NuAWS Plugin Error: ($context.original_error.msg)",
        label: {
            text: "plugin error",
            span: {start: 0, end: 10}
        },
        help: $"
An internal plugin error occurred.

Troubleshooting:
  1. Enable debug mode: NUAWS_DEBUG=true
  2. Check configuration: nuaws config show
  3. Reset plugin: nuaws config reset
  4. Clear cache: nuaws cache clear

If the error persists, please report it with:
  - Command that failed: nuaws ($context.service) ($context.args | str join ' ')
  - Nushell version: version
  - Plugin version: nuaws version"
    }
}

# Generic AWS error handler
def make-generic-aws-error [context: record, aws_error: record] {
    error make {
        msg: $"💥 AWS Error: ($aws_error.message)",
        label: {
            text: $"($aws_error.code)",
            span: {start: 0, end: 10}
        },
        help: $"
An AWS error occurred that we don't have specific handling for.

Error details:
  Service: ($context.service)
  Operation: ($aws_error.operation)
  Error Code: ($aws_error.code)

For more information:
  - AWS CLI docs: aws ($context.service) ($context.operation?) help
  - AWS service docs: https://docs.aws.amazon.com/($context.service)/
  - Search error: https://www.google.com/search?q=AWS+($aws_error.code)

If this is a common error, please report it for better handling."
    }
}

# Get resource-specific suggestions
def get-resource-suggestions [service: string, error_code: string]: nothing -> string {
    match $service {
        "s3" => "Try: nuaws s3 ls  # to list all buckets",
        "ec2" => $"Try: nuaws ec2 describe-instances --region ($env.AWS_DEFAULT_REGION? | default 'us-east-1')",
        "lambda" => "Try: nuaws lambda list-functions",
        "iam" => "Try: nuaws iam list-users  # or list-roles",
        "dynamodb" => "Try: nuaws dynamodb list-tables",
        _ => $"Try: nuaws ($service) help  # to see available operations"
    }
}