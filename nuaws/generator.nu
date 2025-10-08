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
def parse-operations-from-help [help_lines: list<string>]: nothing -> list<record> {
    let matches = ($help_lines | enumerate | where ($it.item | str contains "Available Commands"))
    let operations_start = if ($matches | is-empty) { -1 } else { $matches | get index | first }
    
    if $operations_start == -1 {
        return []
    }
    
    $help_lines 
    | skip ($operations_start + 1)
    | take 50  # Reasonable limit
    | where ($it | str trim | str length) > 0
    | where ($it | str starts-with " ")
    | each { |line|
        let trimmed = ($line | str trim)
        let parts = ($trimmed | split row " " | where ($it | str length) > 0)
        if ($parts | length) >= 1 {
            {
                name: ($parts | first),
                description: ($parts | skip 1 | str join " "),
                parameters: []
            }
        }
    }
    | where ($it.name | str length) > 0
}

# ============================================================================
# Unified Module Generation
# ============================================================================

# Build complete service module with all operations
def build-unified-service-module [
    service: string,
    service_info: record,
    with_completions: bool
]: nothing -> string {
    let header = build-module-header $service $service_info
    let operations = ($service_info.operations | each { |op| build-operation-function $service $op $with_completions })
    let footer = build-module-footer $service
    
    $header + "\n\n" + ($operations | str join "\n\n") + "\n\n" + $footer
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
        "        # Execute AWS CLI with error handling",
        "        try {",
        $"            aws ($aws_service) ($operation.name) | from json",
        "        } catch { |err|",
        "            error make {",
        "                msg: $\"AWS CLI error: { $err.msg }\",",
        "                label: {",
        "                    text: \"AWS operation failed\",",
        "                    span: (metadata $err).span",
        "                }",
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

# Build individual parameter with type and completion
def build-parameter-string [
    param: record,
    with_completions: bool
]: nothing -> string {
    let param_name = ($param.name | str replace '-' '_')
    let param_type = map-aws-type-to-nushell ($param.type? | default "string")
    let is_required = ($param.required? | default false)
    
    let base_param = if $is_required {
        $"($param_name): ($param_type)"
    } else {
        $"--($param.name | str replace '_' '-'): ($param_type)"
    }
    
    if $with_completions and (should-have-completion $param) {
        let completion_func = get-completion-function $param
        $"($base_param)@($completion_func)"
    } else {
        $base_param
    }
}

# Map AWS types to Nushell types
def map-aws-type-to-nushell [aws_type: string]: nothing -> string {
    match ($aws_type | str downcase) {
        "string" => "string",
        "integer" | "int" | "long" => "int",
        "boolean" | "bool" => "bool", 
        "timestamp" | "datetime" => "datetime",
        "double" | "float" => "float",
        "blob" | "binary" => "binary",
        "list" => "list<string>",
        "structure" | "object" => "record",
        _ => "string"
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