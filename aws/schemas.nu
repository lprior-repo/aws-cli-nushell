# AWS CLI Nushell Schemas
# Consistent output schemas across all AWS commands

# ============================================================================
# CORE SCHEMA DEFINITIONS
# ============================================================================

# Base AWS resource schema
export def aws-resource-schema []: nothing -> record {
    {
        arn: "",
        name: "",
        creation_date: "",
        status: "",
        region: "",
        account_id: "",
        metadata: {
            last_updated: "",
            tags: [],
            processing_duration: 0ms
        }
    }
}

# Pagination schema for list operations
export def pagination-schema []: nothing -> record {
    {
        items: [],
        next_token: "",
        has_more: false,
        total_count: 0,
        page_size: 0
    }
}

# Operation result schema
export def operation-result-schema []: nothing -> record {
    {
        success: true,
        operation: "",
        timestamp: "",
        result: {},
        error: null,
        duration: 0ms
    }
}

# ============================================================================
# STEP FUNCTIONS SCHEMAS
# ============================================================================

# Step Functions execution schema
export def stepfunctions-execution-schema []: nothing -> record {
    {
        execution_arn: "",
        state_machine_arn: "",
        name: "",
        status: "",
        start_date: "",
        stop_date: null,
        input: "",
        output: "",
        error: null,
        cause: null,
        metadata: {
            region: "",
            account_id: "",
            duration_ms: 0,
            event_count: 0
        }
    }
}

# Step Functions state machine schema
export def stepfunctions-state-machine-schema []: nothing -> record {
    {
        state_machine_arn: "",
        name: "",
        definition: "",
        role_arn: "",
        type: "",
        status: "",
        creation_date: "",
        update_date: null,
        logging_configuration: {},
        tracing_configuration: {},
        metadata: {
            region: "",
            account_id: "",
            version: "",
            revision_id: ""
        }
    }
}

# Step Functions activity schema
export def stepfunctions-activity-schema []: nothing -> record {
    {
        activity_arn: "",
        name: "",
        creation_date: "",
        metadata: {
            region: "",
            account_id: ""
        }
    }
}

# Step Functions map run schema
export def stepfunctions-map-run-schema []: nothing -> record {
    {
        map_run_arn: "",
        execution_arn: "",
        status: "",
        start_date: "",
        stop_date: null,
        max_concurrency: 0,
        tolerated_failure_percentage: 0.0,
        tolerated_failure_count: 0,
        item_counts: {
            pending: 0,
            running: 0,
            succeeded: 0,
            failed: 0,
            timed_out: 0,
            aborted: 0,
            total: 0,
            results_written: 0
        },
        execution_counts: {
            pending: 0,
            running: 0,
            succeeded: 0,
            failed: 0,
            timed_out: 0,
            aborted: 0,
            total: 0,
            results_written: 0
        }
    }
}

# ============================================================================
# IAM SCHEMAS
# ============================================================================

# IAM role schema
export def iam-role-schema []: nothing -> record {
    {
        role_arn: "",
        role_name: "",
        path: "/",
        role_id: "",
        creation_date: "",
        assume_role_policy_document: "",
        description: "",
        max_session_duration: 3600,
        permissions_boundary: null,
        tags: [],
        metadata: {
            account_id: "",
            last_used: null
        }
    }
}

# IAM policy schema
export def iam-policy-schema []: nothing -> record {
    {
        policy_arn: "",
        policy_name: "",
        policy_id: "",
        path: "/",
        default_version_id: "",
        attachment_count: 0,
        permissions_boundary_usage_count: 0,
        is_attachable: true,
        description: "",
        creation_date: "",
        update_date: "",
        tags: []
    }
}

# ============================================================================
# LAMBDA SCHEMAS
# ============================================================================

# Lambda function schema
export def lambda-function-schema []: nothing -> record {
    {
        function_name: "",
        function_arn: "",
        runtime: "",
        role: "",
        handler: "",
        code_size: 0,
        description: "",
        timeout: 3,
        memory_size: 128,
        last_modified: "",
        code_sha256: "",
        version: "",
        environment: {
            variables: {}
        },
        tracing_config: {
            mode: "PassThrough"
        },
        layers: [],
        state: "",
        state_reason: "",
        state_reason_code: "",
        last_update_status: "",
        package_type: "Zip",
        architectures: ["x86_64"],
        ephemeral_storage: {
            size: 512
        },
        metadata: {
            region: "",
            account_id: ""
        }
    }
}

# ============================================================================
# S3 SCHEMAS
# ============================================================================

# S3 bucket schema
export def s3-bucket-schema []: nothing -> record {
    {
        bucket_name: "",
        creation_date: "",
        region: "",
        versioning: {
            status: "Suspended"
        },
        encryption: {
            server_side_encryption_configuration: {}
        },
        public_access_block: {
            block_public_acls: true,
            ignore_public_acls: true,
            block_public_policy: true,
            restrict_public_buckets: true
        },
        tags: [],
        metadata: {
            account_id: "",
            object_count: 0,
            size_bytes: 0
        }
    }
}

# S3 object schema
export def s3-object-schema []: nothing -> record {
    {
        key: "",
        last_modified: "",
        etag: "",
        size: 0,
        storage_class: "STANDARD",
        owner: {
            id: "",
            display_name: ""
        },
        metadata: {
            bucket: "",
            content_type: "",
            server_side_encryption: null
        }
    }
}

# ============================================================================
# SCHEMA VALIDATION FUNCTIONS
# ============================================================================

# Validate data against schema
export def validate-against-schema [
    schema: record,
    --strict: bool = false
]: [record -> record] {
    let data = $in
    
    # Check required fields
    let missing_fields = $schema | columns | where { |field|
        not ($field in ($data | columns))
    }
    
    if ($missing_fields | length) > 0 and $strict {
        error make {
            msg: $"Missing required fields: (($missing_fields | str join ', '))",
            label: { text: "Schema Validation Error" },
            help: "Add missing fields to match the expected schema"
        }
    }
    
    # Validate field types
    let type_errors = $schema | items { |field, expected_type|
        if $field in ($data | columns) {
            let actual_value = $data | get $field
            let actual_type = $actual_value | describe
            
            let type_matches = match $expected_type {
                "string" => ($actual_type == "string"),
                "int" => ($actual_type in ["int", "float"]),
                "float" => ($actual_type in ["int", "float"]),
                "bool" => ($actual_type == "bool"),
                "list" => ($actual_type | str starts-with "list"),
                "record" => ($actual_type == "record"),
                "datetime" => ($actual_type in ["string", "date"]),
                "any" => true,
                _ => ($actual_type == $expected_type)
            }
            
            if not $type_matches {
                {
                    field: $field,
                    expected: $expected_type,
                    actual: $actual_type
                }
            } else {
                null
            }
        } else {
            null
        }
    } | where { |x| $x != null }
    
    if ($type_errors | length) > 0 {
        let error_msg = $type_errors | each { |err|
            $"($err.field): expected ($err.expected), got ($err.actual)"
        } | str join ", "
        
        error make {
            msg: $"Type validation errors: ($error_msg)",
            label: { text: "Schema Type Error" },
            help: "Convert fields to match expected types"
        }
    }
    
    {
        valid: true,
        data: $data,
        missing_fields: $missing_fields,
        type_errors: $type_errors
    }
}

# Normalize data to match schema
export def normalize-to-schema [
    schema: record
]: [record -> record] {
    let data = $in
    
    # Start with schema structure and merge in actual data
    $schema | merge $data | items { |field, value|
        # Handle special field transformations
        let normalized_value = match $field {
            "creation_date" | "start_date" | "stop_date" | "last_modified" | "update_date" => {
                if ($value | describe) == "string" and ($value != "" and $value != null) {
                    try { $value | into datetime | format date '%Y-%m-%d %H:%M:%S' } catch { $value }
                } else { $value }
            },
            "duration_ms" => {
                if ($value | describe) in ["int", "float"] {
                    $value
                } else {
                    0
                }
            },
            "tags" => {
                if ($value | describe) == "list" {
                    $value
                } else {
                    []
                }
            },
            _ => $value
        }
        
        { $field: $normalized_value }
    } | reduce { |it, acc| $acc | merge $it }
}

# ============================================================================
# DATA TRANSFORMATION UTILITIES
# ============================================================================

# Transform AWS CLI output to normalized schema
export def transform-aws-output [
    output_type: string
]: [any -> record] {
    let data = $in
    
    match $output_type {
        "stepfunctions-execution" => {
            let schema = stepfunctions-execution-schema
            
            $data | merge {
                execution_arn: ($data.executionArn? | default ""),
                state_machine_arn: ($data.stateMachineArn? | default ""),
                name: ($data.name? | default ""),
                status: ($data.status? | default ""),
                start_date: ($data.startDate? | default ""),
                stop_date: ($data.stopDate? | default null),
                input: ($data.input? | default ""),
                output: ($data.output? | default ""),
                error: ($data.error? | default null),
                cause: ($data.cause? | default null),
                metadata: {
                    region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
                    account_id: (extract-account-id ($data.executionArn? | default "")),
                    duration_ms: (calculate-duration ($data.startDate? | default "") ($data.stopDate? | default "")),
                    event_count: 0
                }
            } | normalize-to-schema $schema
        },
        "stepfunctions-state-machine" => {
            let schema = stepfunctions-state-machine-schema
            
            $data | merge {
                state_machine_arn: ($data.stateMachineArn? | default ""),
                name: ($data.name? | default ""),
                definition: ($data.definition? | default ""),
                role_arn: ($data.roleArn? | default ""),
                type: ($data.type? | default ""),
                status: ($data.status? | default ""),
                creation_date: ($data.creationDate? | default ""),
                update_date: ($data.updateDate? | default null),
                logging_configuration: ($data.loggingConfiguration? | default {}),
                tracing_configuration: ($data.tracingConfiguration? | default {}),
                metadata: {
                    region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
                    account_id: (extract-account-id ($data.stateMachineArn? | default "")),
                    version: ($data.version? | default ""),
                    revision_id: ($data.revisionId? | default "")
                }
            } | normalize-to-schema $schema
        },
        "lambda-function" => {
            let schema = lambda-function-schema
            
            $data | merge {
                function_name: ($data.FunctionName? | default ""),
                function_arn: ($data.FunctionArn? | default ""),
                runtime: ($data.Runtime? | default ""),
                role: ($data.Role? | default ""),
                handler: ($data.Handler? | default ""),
                code_size: ($data.CodeSize? | default 0),
                description: ($data.Description? | default ""),
                timeout: ($data.Timeout? | default 3),
                memory_size: ($data.MemorySize? | default 128),
                last_modified: ($data.LastModified? | default ""),
                metadata: {
                    region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
                    account_id: (extract-account-id ($data.FunctionArn? | default ""))
                }
            } | normalize-to-schema $schema
        },
        _ => $data
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Extract account ID from ARN
def extract-account-id [arn: string]: string -> string {
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

# Calculate duration between start and stop times
def calculate-duration [start: string, stop: string]: [string, string] -> int {
    if ($start == "" or $stop == "" or $stop == null) {
        return 0
    }
    
    try {
        let start_time = $start | into datetime
        let stop_time = $stop | into datetime
        let duration = $stop_time - $start_time
        $duration | into int | math abs / 1000000  # Convert to milliseconds
    } catch {
        0
    }
}

# Create standardized list response
export def create-list-response [
    items: list,
    next_token: string = "",
    --item-type: string = "items"
]: [list, string -> record] {
    let schema = pagination-schema
    
    {
        items: $items,
        next_token: $next_token,
        has_more: ($next_token != ""),
        total_count: ($items | length),
        page_size: ($items | length),
        item_type: $item_type
    } | normalize-to-schema $schema
}

# Create standardized operation result
export def create-operation-result [
    operation: string,
    result: any,
    --error: string = "",
    --duration: duration = 0ms
]: [string, any -> record] {
    let schema = operation-result-schema
    
    {
        success: ($error == ""),
        operation: $operation,
        timestamp: (date now | format date '%Y-%m-%d %H:%M:%S UTC'),
        result: $result,
        error: (if $error == "" { null } else { $error }),
        duration: $duration
    } | normalize-to-schema $schema
}