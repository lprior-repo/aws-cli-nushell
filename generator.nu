# Universal AWS Generator - Unified System
# One module to rule them all - generates all AWS services with external completions

# ============================================================================
# Core Generator Functions
# ============================================================================

# Generate complete AWS service module with all operations and external completions
export def generate-aws-service [
    service: string,           # AWS service name (e.g., "s3", "ec2", "lambda")
    --use-schema(-s): string,  # Path to service schema JSON file  
    --output(-o): string,      # Output directory (default: current)
    --with-completions(-c),    # Generate external completions
    --with-tests(-t)          # Generate test suite
]: nothing -> record {
    print $"🚀 Generating AWS ($service) service module..."
    
    let service_info = if ($use_schema | is-empty) {
        discover-service-from-cli $service
    } else {
        load-service-schema $use_schema
    }
    
    let output_dir = $output | default "."
    let module_content = build-unified-service-module $service $service_info $with_completions
    let test_content = if $with_tests { build-test-suite $service $service_info } else { "" }
    
    # Write unified service module
    let module_path = $"($output_dir)/($service).nu"
    $module_content | save --force $module_path
    
    # Write test suite if requested
    if $with_tests {
        let test_path = $"($output_dir)/test_($service).nu"
        $test_content | save --force $test_path
    }
    
    # Write completions if requested
    if $with_completions {
        let completion_content = build-external-completions $service $service_info
        let completion_path = $"($output_dir)/completions_($service).nu"
        $completion_content | save --force $completion_path
    }
    
    {
        service: $service,
        operations_count: ($service_info.operations | length),
        module_path: $module_path,
        completions_generated: $with_completions,
        tests_generated: $with_tests,
        timestamp: (date now)
    }
}

# ============================================================================
# Service Discovery and Schema Loading
# ============================================================================

# Load service schema from JSON file
def load-service-schema [schema_path: string]: nothing -> record {
    print $"📄 Loading schema from ($schema_path)..."
    
    try {
        let schema_content = (open $schema_path)
        let operations = extract-operations-from-schema $schema_content
        
        {
            service: ($schema_path | path basename | str replace ".json" ""),
            source: "schema_file", 
            operations: $operations,
            schema: $schema_content,
            timestamp: (date now)
        }
    } catch { |err|
        print $"Error details: ($err)"
        error make {
            msg: $"Failed to load schema from: ($schema_path) - ($err.msg)",
            label: { text: "Schema loading failed", span: (metadata $schema_path).span }
        }
    }
}

# Extract operations from JSON schema
def extract-operations-from-schema [schema: record]: nothing -> list<record> {
    if "operations" in ($schema | columns) {
        let operations = $schema.operations
        if ($operations | describe) =~ "^record" {
            # Handle object format (e.g., AWS Service Model format)
            $operations | transpose key value | each { |item|
                {
                    name: ($item.key | str downcase),
                    description: ($item.value.documentation? | default ""),
                    parameters: [],
                    input_shape: ($item.value.input?.shape? | default {}),
                    output_shape: ($item.value.output?.shape? | default {})
                }
            }
        } else {
            # Handle array format (e.g., our custom format)
            $operations | each { |op|
                {
                    name: $op.name,
                    description: ($op.description? | default ""),
                    parameters: ($op.parameters? | default []),
                    input_shape: ($op.input_shape? | default {}),
                    output_shape: ($op.output_shape? | default {})
                }
            }
        }
    } else {
        []
    }
}

# Discover AWS service operations from CLI help
def discover-service-from-cli [service: string]: nothing -> record {
    print $"📡 Discovering operations for AWS ($service)..."
    
    try {
        let help_output = (aws $service help | lines)
        let operations = parse-operations-from-help $help_output
        
        {
            service: $service,
            source: "cli_help",
            operations: $operations,
            timestamp: (date now)
        }
    } catch {
        error make {
            msg: $"Failed to discover operations for service: ($service)",
            label: { text: "Service discovery failed", span: (metadata $service).span }
        }
    }
}

# Parse operations from AWS CLI help output
export def parse-operations-from-help [help_lines: list<string>]: nothing -> list<record> {
    # Handle both normal and doubled-character formatting
    # Look for variations: "Available Commands", "AVAILABLE COMMANDS", "AAVVAAIILLAABBLLEE CCOOMMMMAANNDDSS"
    let matches = ($help_lines | enumerate | where { |item|
        let line = $item.item
        # Remove backspace formatting (^H characters) used for bold text
        let clean_line = ($line | str replace --all "\u{08}" "")
        # Check for normal case variations and doubled character formatting
        (($clean_line | str contains "Available Commands") or
         ($clean_line | str contains "AVAILABLE COMMANDS") or
         ($clean_line | str contains "AAVVAAIILLAABBLLEE CCOOMMMMAANNDDSS") or
         ($line | str contains "Available Commands") or
         ($line | str contains "AVAILABLE COMMANDS"))
    })
    
    let operations_start = if ($matches | is-empty) { -1 } else { $matches | get index | first }
    
    if $operations_start == -1 {
        return []
    }
    
    $help_lines 
    | skip ($operations_start + 1)
    | take 100  # Increased limit for services with many commands
    | where ($it | str trim | str length) > 0
    | where { |line|
        # Look for lines that start with whitespace and contain "+o " prefix (might have backspace chars)
        let clean_line = ($line | str replace --all "\u{08}" "")
        ($line | str starts-with " ") and (($line | str contains "+o ") or ($clean_line | str contains "+o "))
    }
    | each { |line|
        # Clean backspace characters first
        let clean_line = ($line | str replace --all "\u{08}" "" | str trim)
        # Remove the "+o " prefix and extract command name
        if ($clean_line | str starts-with "+o ") {
            let command_part = ($clean_line | str replace "+o " "")
            let parts = ($command_part | split row " " | where ($it | str length) > 0)
            if ($parts | length) >= 1 {
                {
                    name: ($parts | first),
                    description: ($parts | skip 1 | str join " "),
                    parameters: []
                }
            }
        }
    }
    | where ($it.name | str length) > 0
}

# ============================================================================
# Unified Module Generation
# ============================================================================

# Build complete service module with all operations and helper functions
def build-unified-service-module [
    service: string,
    service_info: record,
    with_completions: bool
]: nothing -> string {
    let header = build-module-header $service $service_info
    let helper_functions = generate-helper-functions $service
    let operations = ($service_info.operations | each { |op| build-operation-function $service $op $with_completions })
    let footer = build-module-footer $service
    
    $header + "\n\n" + $helper_functions + "\n\n" + ($operations | str join "\n\n") + "\n\n" + $footer
}

# Build module header with metadata and imports
def build-module-header [service: string, service_info: record]: nothing -> string {
    let operation_count = ($service_info.operations | length)
    let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")
    
    [
        $"# AWS ($service | str upcase) Service Module",
        "# Generated by Universal AWS Generator",
        $"# Operations: ($operation_count)",
        $"# Generated: ($timestamp)",
        $"# Source: ($service_info.source)",
        "",
        "# Configure mock mode for testing",
        "# Note: Mock mode can be enabled by setting environment variable",
        "",
        "# Service metadata",
        $"export def \"aws ($service) info\" []: nothing -> record {",
        "    {",
        $"        service: \"($service)\",",
        $"        operations_count: ($operation_count),",
        $"        generated_at: \"($timestamp)\",",
        "        mock_mode: false",
        "    }",
        "}"
    ] | str join "\n"
}

# Build individual operation function
def build-operation-function [
    service: string,
    operation: record,
    with_completions: bool
]: nothing -> string {
    # Map service name to correct AWS CLI service
    let aws_service = map-service-to-aws-cli $service
    let function_name = $"aws ($service) ($operation.name | str replace '_' '-')"
    let parameters = build-parameter-list $operation.parameters $with_completions
    let description = ($operation.description | default $"AWS ($service) ($operation.name) operation")
    
    let error_template = $"AWS CLI error in ($service) ($operation.name)"
    [
        $"# ($description)",
        $"export def \"($function_name)\" [($parameters)]: nothing -> any {",
        "    # Check if in mock mode",
        $"    let mock_env_var = \"($service | str upcase)_MOCK_MODE\"",
        "    let mock_mode = try { $env | get $mock_env_var | into bool } catch { false }",
        "    ",
        "    if $mock_mode {",
        "        # Return mock response",
        "        {",
        "            mock: true,",
        $"            service: \"($service)\",",
        $"            operation: \"($operation.name)\",",
        $"            message: \"Mock response for ($service) ($operation.name)\"",
        "        }",
        "    } else {",
        "        # Execute AWS CLI with enhanced error handling and span awareness",
        "        try {",
        $"            let result = aws ($aws_service) ($operation.name) | from json",
        "            # Apply response data transformation",
        "            $result | transform-aws-response",
        "        } catch { |err|",
        "            # Enhanced AWS error mapping with specific error codes",
        "            let aws_error = parse-aws-error $err",
        "            error make {",
        "                msg: $\"AWS ($service) error: { $aws_error.message }\",",
        "                label: {",
        "                    text: $\"($aws_error.code): ($aws_error.suggestion)\",",
        "                    span: (metadata $err).span",
        "                },",
        "                help: $\"Use 'aws ($service) help ($operation.name)' for more information\"",
        "            }",
        "        }",
        "    }",
        "}"
    ] | str join "\n"
}

# Map service name to correct AWS CLI service
def map-service-to-aws-cli [service: string]: nothing -> string {
    match $service {
        "s3" => "s3api"     # S3 API operations use s3api, not s3
        _ => $service       # All other services use their name directly
    }
}

# Build parameter list with external completions
def build-parameter-list [
    parameters: list<record>,
    with_completions: bool
]: nothing -> string {
    if ($parameters | is-empty) {
        return ""
    }
    
    let param_strings = ($parameters | each { |param|
        build-parameter-string $param $with_completions
    })
    
    "\n    " + ($param_strings | str join ",\n    ") + "\n"
}

# Build individual parameter with enhanced type annotations and completion
def build-parameter-string [
    param: record,
    with_completions: bool
]: nothing -> string {
    let param_name = ($param.name | str replace '-' '_')
    let type_info = map-aws-type-to-nushell ($param.type? | default "string")
    let is_required = ($param.required? | default false)
    let description = ($param.description? | default $"AWS parameter: ($param.name)")
    
    # Enhanced parameter with inline documentation
    let base_param = if $is_required {
        $"($param_name): ($type_info.nushell_type) # ($description)"
    } else {
        $"--($param.name | str replace '_' '-'): ($type_info.nushell_type) # ($description)"
    }
    
    if $with_completions and (should-have-completion $param) {
        let completion_func = get-completion-function $param
        $"($base_param)@($completion_func)"
    } else {
        $base_param
    }
}

# Enhanced AWS type mapping with comprehensive annotations
def map-aws-type-to-nushell [aws_type: string]: nothing -> record {
    let type_info = match ($aws_type | str downcase) {
        "string" => { nushell_type: "string", constraints: [], validation: "str length" },
        "integer" | "int" | "long" => { nushell_type: "int", constraints: [], validation: "into int" },
        "boolean" | "bool" => { nushell_type: "bool", constraints: [], validation: "into bool" }, 
        "timestamp" | "datetime" => { nushell_type: "datetime", constraints: [], validation: "into datetime" },
        "double" | "float" => { nushell_type: "float", constraints: [], validation: "into float" },
        "blob" | "binary" => { nushell_type: "binary", constraints: [], validation: "into binary" },
        "list" => { nushell_type: "list<string>", constraints: [], validation: "into list" },
        "structure" | "object" => { nushell_type: "record", constraints: [], validation: "into record" },
        _ => { nushell_type: "string", constraints: [], validation: "str length" }
    }
    
    $type_info | upsert documentation (get-type-documentation $aws_type)
}

# Generate comprehensive type documentation
def get-type-documentation [aws_type: string]: nothing -> string {
    match ($aws_type | str downcase) {
        "string" => "AWS String type - text data with UTF-8 encoding",
        "integer" | "int" | "long" => "AWS Integer type - numeric data (32/64-bit)",
        "boolean" | "bool" => "AWS Boolean type - true/false values", 
        "timestamp" | "datetime" => "AWS Timestamp type - ISO 8601 datetime format",
        "double" | "float" => "AWS Float type - decimal numeric data",
        "blob" | "binary" => "AWS Blob type - binary data (base64 encoded)",
        "list" => "AWS List type - ordered collection of items",
        "structure" | "object" => "AWS Structure type - key-value record data",
        _ => $"AWS ($aws_type) type - specialized AWS data structure"
    }
}

# Check if parameter should have completion
def should-have-completion [param: record]: nothing -> bool {
    let param_name = ($param.name | str downcase)
    let completable_patterns = [
        "bucket", "key", "role", "policy", "user", "group", "instance", 
        "volume", "vpc", "subnet", "security-group", "function", "layer",
        "table", "stream", "cluster", "database", "arn", "region"
    ]
    
    $completable_patterns | any { |pattern| $param_name | str contains $pattern }
}

# Get completion function name for parameter
def get-completion-function [param: record]: nothing -> string {
    let param_name = ($param.name | str downcase)
    
    match true {
        ($param_name | str contains "bucket") => "nu-complete aws s3 buckets",
        ($param_name | str contains "role") => "nu-complete aws iam roles",
        ($param_name | str contains "user") => "nu-complete aws iam users", 
        ($param_name | str contains "instance") => "nu-complete aws ec2 instances",
        ($param_name | str contains "function") => "nu-complete aws lambda functions",
        ($param_name | str contains "region") => "nu-complete aws regions",
        _ => $"nu-complete aws ($param_name | str replace '-' ' ')"
    }
}

# Build module footer
def build-module-footer [service: string]: nothing -> string {
    $"# AWS ($service | str upcase) Service Module - End
# Use 'aws ($service) info' to get service information
# Use 'help aws ($service)' to see available operations"
}

# ============================================================================
# Response Transformation and Error Handling Enhancement
# ============================================================================

# Generate AWS error parsing and response transformation functions
def generate-helper-functions [service: string]: nothing -> string {
    [
        "# Enhanced AWS error parsing with specific error code mapping",
        "def parse-aws-error [err: record]: nothing -> record {",
        "    let error_msg = ($err.msg | default \"Unknown AWS error\")",
        "    let aws_error_patterns = {",
        "        \"AccessDenied\": { code: \"ACCESS_DENIED\", suggestion: \"Check IAM permissions\" },",
        "        \"InvalidParameter\": { code: \"INVALID_PARAMETER\", suggestion: \"Verify parameter values\" },",
        "        \"ResourceNotFound\": { code: \"NOT_FOUND\", suggestion: \"Check resource existence\" },",
        "        \"ThrottlingException\": { code: \"THROTTLED\", suggestion: \"Reduce request rate\" },",
        "        \"ServiceUnavailable\": { code: \"SERVICE_ERROR\", suggestion: \"Retry after delay\" }",
        "    }",
        "    ",
        "    let matched_error = ($aws_error_patterns | transpose key value | where ($error_msg | str contains $it.key) | first)",
        "    ",
        "    if ($matched_error | is-empty) {",
        "        { code: \"UNKNOWN_ERROR\", message: $error_msg, suggestion: \"Check AWS documentation\" }",
        "    } else {",
        "        $matched_error.value | upsert message $error_msg",
        "    }",
        "}",
        "",
        "# Transform AWS responses to Nushell-optimized data structures",
        "def transform-aws-response []: record -> record {",
        "    let response = $in",
        "    # Convert PascalCase to snake_case for field names",
        "    $response | transform-field-names | add-computed-fields",
        "}",
        "",
        "# Convert AWS PascalCase field names to Nushell snake_case",
        "def transform-field-names []: record -> record {",
        "    let input = $in",
        "    $input | transpose key value | each { |item|",
        "        let snake_key = ($item.key | str replace --all --regex '([A-Z])' '_$1' | str downcase | str replace --regex '^_' '')",
        "        { $snake_key: $item.value }",
        "    } | reduce --fold {} { |item, acc| $acc | merge $item }",
        "}",
        "",
        "# Add computed fields commonly used in Nushell pipelines",
        "def add-computed-fields []: record -> record {",
        "    let input = $in",
        "    # Add timestamp conversions and computed fields",
        "    $input | upsert computed_at (date now)",
        "}",
        "",
        "# Validate function signature and parameters",
        "def validate-aws-parameters [params: record, operation: string]: nothing -> nothing {",
        "    # Parameter validation based on AWS constraints",
        "    let required_params = get-required-parameters $operation",
        "    ",
        "    $required_params | each { |req_param|",
        "        if not ($req_param in ($params | columns)) {",
        "            error make {",
        "                msg: $\"Missing required parameter: ($req_param)\",",
        "                label: { text: \"Parameter validation failed\", span: (metadata $params).span }",
        "            }",
        "        }",
        "    }",
        "}",
        "",
        "# Get required parameters for operation (extend with schema data)",
        "def get-required-parameters [operation: string]: nothing -> list<string> {",
        "    # This would be populated from AWS schema data",
        "    []",
        "}",
        ""
    ] | str join "\n"
}

# ============================================================================
# External Completions Generation
# ============================================================================

# Build external completions for service
def build-external-completions [
    service: string,
    service_info: record
]: nothing -> string {
    let header = $"# External completions for AWS ($service | str upcase)
# Generated by Universal AWS Generator

"
    
    let completion_functions = generate-completion-functions $service
    
    $header + $completion_functions
}

# Generate all completion functions for a service
def generate-completion-functions [service: string]: nothing -> string {
    match $service {
        "s3" => generate-s3-completions,
        "ec2" => generate-ec2-completions,
        "iam" => generate-iam-completions,
        "lambda" => generate-lambda-completions,
        _ => (generate-generic-completions $service)
    }
}

# Generate S3-specific completions
def generate-s3-completions []: nothing -> string {
    $"# S3 bucket completion
export def \"nu-complete aws s3 buckets\" []: nothing -> list<string> {
    try {
        aws s3api list-buckets | from json | get Buckets | get Name
    } catch {
        []
    }
}

# S3 object completion  
export def \"nu-complete aws s3 objects\" [bucket: string]: nothing -> list<string> {
    try {
        aws s3api list-objects-v2 --bucket $bucket | from json | get Contents?.Key? | default []
    } catch {
        []
    }
}

# S3 regions completion
export def \"nu-complete aws regions\" []: nothing -> list<string> {
    [\"us-east-1\", \"us-west-1\", \"us-west-2\", \"eu-west-1\", \"eu-central-1\", \"ap-southeast-1\"]
}"
}

# Generate EC2-specific completions  
def generate-ec2-completions []: nothing -> string {
    $"# EC2 instance completion
export def \"nu-complete aws ec2 instances\" []: nothing -> list<string> {
    try {
        aws ec2 describe-instances | from json | get Reservations | flatten | get Instances | get InstanceId
    } catch {
        []
    }
}

# EC2 VPC completion
export def \"nu-complete aws ec2 vpcs\" []: nothing -> list<string> {
    try {
        aws ec2 describe-vpcs | from json | get Vpcs | get VpcId  
    } catch {
        []
    }
}"
}

# Generate IAM-specific completions
def generate-iam-completions []: nothing -> string {
    $"# IAM user completion
export def \"nu-complete aws iam users\" []: nothing -> list<string> {
    try {
        aws iam list-users | from json | get Users | get UserName
    } catch {
        []
    }
}

# IAM role completion
export def \"nu-complete aws iam roles\" []: nothing -> list<string> {
    try {
        aws iam list-roles | from json | get Roles | get RoleName
    } catch {
        []
    }
}"
}

# Generate Lambda-specific completions
def generate-lambda-completions []: nothing -> string {
    $"# Lambda function completion
export def \"nu-complete aws lambda functions\" []: nothing -> list<string> {
    try {
        aws lambda list-functions | from json | get Functions | get FunctionName
    } catch {
        []
    }
}"
}

# Generate generic completions for other services
def generate-generic-completions [service: string]: nothing -> string {
    $"# Generic completions for ($service)
export def \"nu-complete aws ($service) resources\" []: nothing -> list<string> {
    try {
        # Generic resource completion - extend as needed
        []
    } catch {
        []
    }
}"
}

# ============================================================================
# Test Suite Generation
# ============================================================================

# Build test suite for service
def build-test-suite [
    service: string,
    service_info: record
]: nothing -> string {
    let header = build-test-header $service
    let tests = ($service_info.operations | each { |op| build-operation-test $service $op })
    
    $header + "\n\n" + ($tests | str join "\n\n")
}

# Build test file header
def build-test-header [service: string]: nothing -> string {
    $"# Tests for AWS ($service | str upcase) Service Module
# Generated by Universal AWS Generator

use nutest

#[before-each]
def setup [] {
    $env.($service | str upcase)_MOCK_MODE = true
    { service: \"($service)\" }
}

#[after-each]  
def cleanup [] {
    $env.($service | str upcase)_MOCK_MODE = false
}"
}

# Build test for individual operation
def build-operation-test [service: string, operation: record]: nothing -> string {
    let test_name = $"test aws ($service) ($operation.name)"
    let function_call = $"aws ($service) ($operation.name | str replace '_' '-')"
    
    [
        "#[test]",
        $"def \"($test_name)\" [] {",
        "    let context = $in",
        $"    let result = (($function_call))",
        "    ",
        "    # Basic test - just ensure function runs",
        "    assert ($result | describe | str contains \"record\") \"Should return a record\"",
        "}"
    ] | str join "\n"
}

# Generate all AWS services from schemas directory
export def generate-all-services [
    schemas_dir: string = "schemas",
    --output(-o): string = ".",
    --with-completions(-c),
    --with-tests(-t)
]: nothing -> list<record> {
    print "🌟 Generating all AWS services..."
    
    let schema_files = (ls $"($schemas_dir)/*.json" | get name)
    
    $schema_files | each { |schema_file|
        let service_name = ($schema_file | path basename | str replace ".json" "")
        generate-aws-service $service_name --use-schema $schema_file --output $output --with-completions=$with_completions --with-tests=$with_tests
    }
}