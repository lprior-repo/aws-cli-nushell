# Span-Aware Error Handling System for AWS Operations
# Enhanced error handling with actionable resolution and span information

# ============================================================================
# Core Error Types and Structures
# ============================================================================

# AWS Error categories with specific handling
export def get-aws-error-categories []: nothing -> record {
    {
        "AUTHENTICATION": {
            description: "AWS credential or authentication issues",
            common_causes: ["expired credentials", "invalid access keys", "missing IAM permissions"],
            resolution_steps: ["Check AWS credentials", "Verify IAM permissions", "Refresh session tokens"]
        },
        "AUTHORIZATION": {
            description: "AWS permission and authorization failures", 
            common_causes: ["insufficient IAM permissions", "policy restrictions", "resource access denied"],
            resolution_steps: ["Review IAM policies", "Check resource-based policies", "Verify cross-account access"]
        },
        "RESOURCE": {
            description: "AWS resource state and existence issues",
            common_causes: ["resource not found", "resource in wrong state", "resource limits exceeded"],
            resolution_steps: ["Verify resource existence", "Check resource state", "Review service limits"]
        },
        "NETWORK": {
            description: "AWS network connectivity and communication issues",
            common_causes: ["network timeouts", "connectivity issues", "endpoint unavailable"],
            resolution_steps: ["Check network connectivity", "Verify endpoint URLs", "Review security groups"]
        },
        "THROTTLING": {
            description: "AWS API rate limiting and throttling",
            common_causes: ["too many requests", "burst capacity exceeded", "concurrent limit reached"],
            resolution_steps: ["Implement exponential backoff", "Reduce request rate", "Use batch operations"]
        },
        "VALIDATION": {
            description: "AWS parameter and input validation failures",
            common_causes: ["invalid parameter values", "missing required parameters", "format errors"],
            resolution_steps: ["Check parameter formats", "Verify required parameters", "Review API documentation"]
        }
    }
}

# Create comprehensive AWS error with span information
export def make-aws-error [
    category: string,           # Error category from above
    aws_error_code: string,     # Specific AWS error code
    user_message: string,       # Human-readable message
    operation: string,          # AWS operation that failed
    service: string,           # AWS service name
    span?: any,                # Optional span information
    --context(-c): record = {}  # Additional context
]: nothing -> nothing {
    let error_categories = get-aws-error-categories
    let category_info = $error_categories | get $category --ignore-errors | default {
        description: "Unknown error category",
        resolution_steps: ["Check AWS documentation"]
    }
    
    let enhanced_context = $context | upsert aws_service $service | upsert aws_operation $operation
    
    let error_details = {
        category: $category,
        aws_error_code: $aws_error_code,
        service: $service,
        operation: $operation,
        description: $category_info.description,
        resolution_steps: $category_info.resolution_steps,
        context: $enhanced_context,
        timestamp: (date now),
        request_id: (generate-request-id)
    }
    
    error make {
        msg: $user_message,
        label: {
            text: $"AWS ($service) ($operation): ($aws_error_code)",
            span: $span
        },
        help: ($category_info.resolution_steps | str join " → "),
        custom: $error_details
    }
}

# Generate unique request ID for error tracking
def generate-request-id []: nothing -> string {
    $"nuaws-((date now | format date '%Y%m%d%H%M%S')-((random chars --length 8)))"
}

# ============================================================================
# AWS Error Code Mapping and Analysis
# ============================================================================

# Comprehensive AWS error code mapping
export def map-aws-error-code [
    aws_error: string,          # Raw AWS error message or code
    service: string            # AWS service context
]: nothing -> record {
    let error_patterns = {
        # Authentication Errors
        "InvalidAccessKeyId": { category: "AUTHENTICATION", severity: "high", retryable: false },
        "SignatureDoesNotMatch": { category: "AUTHENTICATION", severity: "high", retryable: false },
        "TokenRefreshRequired": { category: "AUTHENTICATION", severity: "medium", retryable: true },
        "ExpiredToken": { category: "AUTHENTICATION", severity: "medium", retryable: true },
        
        # Authorization Errors  
        "AccessDenied": { category: "AUTHORIZATION", severity: "high", retryable: false },
        "Forbidden": { category: "AUTHORIZATION", severity: "high", retryable: false },
        "UnauthorizedOperation": { category: "AUTHORIZATION", severity: "high", retryable: false },
        "InsufficientPrivileges": { category: "AUTHORIZATION", severity: "high", retryable: false },
        
        # Resource Errors
        "ResourceNotFound": { category: "RESOURCE", severity: "medium", retryable: false },
        "NoSuchBucket": { category: "RESOURCE", severity: "medium", retryable: false },
        "NoSuchKey": { category: "RESOURCE", severity: "low", retryable: false },
        "InvalidResourceState": { category: "RESOURCE", severity: "medium", retryable: true },
        
        # Network Errors
        "RequestTimeout": { category: "NETWORK", severity: "medium", retryable: true },
        "ServiceUnavailable": { category: "NETWORK", severity: "high", retryable: true },
        "NetworkingError": { category: "NETWORK", severity: "medium", retryable: true },
        
        # Throttling Errors
        "ThrottlingException": { category: "THROTTLING", severity: "medium", retryable: true },
        "RequestLimitExceeded": { category: "THROTTLING", severity: "medium", retryable: true },
        "TooManyRequestsException": { category: "THROTTLING", severity: "medium", retryable: true },
        
        # Validation Errors
        "InvalidParameterValue": { category: "VALIDATION", severity: "medium", retryable: false },
        "MissingParameter": { category: "VALIDATION", severity: "medium", retryable: false },
        "ValidationException": { category: "VALIDATION", severity: "medium", retryable: false }
    }
    
    # Try to match error patterns
    let matched_pattern = $error_patterns | transpose key value | where ($aws_error | str contains $it.key) | first
    
    if ($matched_pattern | is-empty) {
        # Default unknown error mapping
        {
            category: "UNKNOWN",
            severity: "medium",
            retryable: false,
            aws_error_code: $aws_error,
            service: $service,
            confidence: "low"
        }
    } else {
        $matched_pattern.value | upsert aws_error_code $matched_pattern.key | upsert service $service | upsert confidence "high"
    }
}

# ============================================================================
# Interactive Error Resolution
# ============================================================================

# Create interactive error resolution workflow
export def resolve-aws-error [
    error_details: record,      # Error details from make-aws-error
    --interactive(-i),          # Enable interactive mode
    --auto-retry(-r): int = 0   # Number of automatic retries
]: nothing -> record {
    let resolution_plan = create-resolution-plan $error_details
    
    if $interactive {
        interactive-error-resolution $error_details $resolution_plan
    } else {
        automatic-error-resolution $error_details $resolution_plan $auto_retry
    }
}

# Create step-by-step resolution plan
def create-resolution-plan [error_details: record]: nothing -> record {
    let category = $error_details.category
    let aws_error_code = $error_details.aws_error_code
    let service = $error_details.service
    
    let base_steps = match $category {
        "AUTHENTICATION" => [
            "Verify AWS credentials configuration",
            "Check credential expiration",
            "Test with aws sts get-caller-identity",
            "Refresh authentication if needed"
        ],
        "AUTHORIZATION" => [
            "Review IAM policy permissions", 
            "Check resource-based policies",
            "Verify policy attachment",
            "Test with minimal required permissions"
        ],
        "RESOURCE" => [
            "Verify resource existence",
            "Check resource region/availability",
            "Review resource state",
            "Confirm resource naming/identifiers"
        ],
        "THROTTLING" => [
            "Implement exponential backoff",
            "Reduce concurrent requests",
            "Use batch operations where possible",
            "Monitor API usage patterns"
        ],
        _ => [
            "Review AWS documentation",
            "Check service status",
            "Verify operation parameters",
            "Contact AWS support if needed"
        ]
    }
    
    {
        category: $category,
        service: $service,
        aws_error_code: $aws_error_code,
        steps: $base_steps,
        estimated_time: "5-15 minutes",
        difficulty: (if $category in ["AUTHENTICATION", "AUTHORIZATION"] { "medium" } else { "low" }),
        automation_available: ($category in ["THROTTLING", "NETWORK"])
    }
}

# Interactive error resolution with user prompts
def interactive-error-resolution [
    error_details: record,
    resolution_plan: record
]: nothing -> record {
    print $"🔍 AWS Error Resolution Assistant"
    print $"Service: ($error_details.service) | Operation: ($error_details.operation)"
    print $"Error: ($error_details.aws_error_code)"
    print $"Category: ($resolution_plan.category) | Difficulty: ($resolution_plan.difficulty)"
    print ""
    
    let user_choice = input $"Would you like guided resolution? (y/n/auto): "
    
    match $user_choice {
        "y" | "yes" => guided-resolution $error_details $resolution_plan,
        "auto" => automatic-error-resolution $error_details $resolution_plan 3,
        _ => {
            print "Resolution steps:"
            $resolution_plan.steps | enumerate | each { |step|
                print $"  ($step.index + 1). ($step.item)"
            }
            { resolution_method: "manual", steps_provided: true }
        }
    }
}

# Guided step-by-step resolution
def guided-resolution [
    error_details: record,
    resolution_plan: record
]: nothing -> record {
    let completed_steps = []
    
    for step in ($resolution_plan.steps | enumerate) {
        print $"Step ($step.index + 1)/($resolution_plan.steps | length): ($step.item)"
        let step_result = input "Completed? (y/n/skip): "
        
        let step_status = match $step_result {
            "y" | "yes" => "completed",
            "skip" => "skipped", 
            _ => "failed"
        }
        
        $completed_steps | append {
            step: ($step.index + 1),
            description: $step.item,
            status: $step_status,
            completed_at: (date now)
        }
        
        if $step_status == "completed" {
            let retry_choice = input "Try the operation again? (y/n): "
            if $retry_choice in ["y", "yes"] {
                return {
                    resolution_method: "guided",
                    completed_steps: $completed_steps,
                    should_retry: true,
                    retry_recommended: true
                }
            }
        }
    }
    
    {
        resolution_method: "guided",
        completed_steps: $completed_steps,
        should_retry: false,
        all_steps_completed: (($completed_steps | where status == "completed") | length) == ($resolution_plan.steps | length)
    }
}

# Automatic error resolution with retries
def automatic-error-resolution [
    error_details: record,
    resolution_plan: record,
    max_retries: int
]: nothing -> record {
    if not $resolution_plan.automation_available {
        return {
            resolution_method: "automatic",
            automated: false,
            reason: "No automation available for this error category",
            manual_steps_required: true
        }
    }
    
    let retry_strategy = match $error_details.category {
        "THROTTLING" => { initial_delay: 1000, multiplier: 2, max_delay: 30000 },
        "NETWORK" => { initial_delay: 500, multiplier: 1.5, max_delay: 10000 },
        _ => { initial_delay: 1000, multiplier: 1, max_delay: 1000 }
    }
    
    {
        resolution_method: "automatic",
        automated: true,
        retry_strategy: $retry_strategy,
        max_retries: $max_retries,
        category: $error_details.category
    }
}

# ============================================================================
# Error Analytics and Reporting
# ============================================================================

# Collect error analytics for pattern detection
export def collect-error-analytics [
    error_details: record,      # Error information
    --persist(-p): string       # Optional file to persist analytics
]: nothing -> record {
    let analytics = {
        timestamp: (date now),
        service: $error_details.service,
        operation: $error_details.operation,
        category: $error_details.category,
        aws_error_code: $error_details.aws_error_code,
        request_id: $error_details.request_id,
        user_agent: "nuaws-cli",
        session_id: (get-session-id),
        context: $error_details.context
    }
    
    if ($persist | is-not-empty) {
        $analytics | to json | save --append $persist
    }
    
    $analytics
}

# Get current session ID for analytics
def get-session-id []: nothing -> string {
    try {
        $env.NUAWS_SESSION_ID? | default (
            $"session-((date now | format date '%Y%m%d%H%M%S'))"
        )
    } catch {
        $"session-((date now | format date '%Y%m%d%H%M%S'))"
    }
}

# Analyze error patterns and suggest optimizations
export def analyze-error-patterns [
    analytics_file: string      # File containing error analytics
]: nothing -> record {
    let error_data = try {
        open $analytics_file | lines | each { |line| $line | from json }
    } catch {
        error make { msg: $"Failed to read analytics file: ($analytics_file)" }
    }
    
    let total_errors = ($error_data | length)
    let by_category = $error_data | group-by category | transpose key value | each { |item|
        { category: $item.key, count: ($item.value | length), percentage: (($item.value | length) * 100 / $total_errors) }
    }
    let by_service = $error_data | group-by service | transpose key value | each { |item|
        { service: $item.key, count: ($item.value | length) }
    }
    
    let recommendations = generate-error-recommendations $by_category $by_service
    
    {
        total_errors: $total_errors,
        analysis_period: {
            start: ($error_data | get timestamp | math min),
            end: ($error_data | get timestamp | math max)
        },
        by_category: $by_category,
        by_service: $by_service,
        recommendations: $recommendations,
        analyzed_at: (date now)
    }
}

# Generate recommendations based on error patterns
def generate-error-recommendations [
    by_category: list<record>,
    by_service: list<record>
]: nothing -> list<string> {
    let recommendations = []
    
    # Check for high authentication errors
    let auth_errors = $by_category | where category == "AUTHENTICATION" | first
    if ($auth_errors.percentage? | default 0) > 20 {
        $recommendations | append "Consider implementing credential refresh automation"
    }
    
    # Check for high throttling errors
    let throttle_errors = $by_category | where category == "THROTTLING" | first  
    if ($throttle_errors.percentage? | default 0) > 15 {
        $recommendations | append "Implement exponential backoff and request batching"
    }
    
    # Check for service-specific issues
    let high_error_services = $by_service | where count > 10 | get service
    if ($high_error_services | is-not-empty) {
        $recommendations | append $"Review configuration for services: ($high_error_services | str join ', ')"
    }
    
    if ($recommendations | is-empty) {
        ["Error patterns appear normal - no specific recommendations"]
    } else {
        $recommendations
    }
}