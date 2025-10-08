#!/usr/bin/env nu
# Enhanced Universal AWS Generator - Plugin-Aware Code Generation
# Integrates with type-safe parameter generation system for complete service module creation

use src/parameter_generation.nu
use plugin/core/service_registry.nu
use plugin/core/configuration.nu

# Generator configuration
const GENERATOR_CONFIG = {
    output_format: "plugin",
    template_version: "2.0",
    include_completions: true,
    include_tests: true,
    include_documentation: true,
    validate_output: true
}

# Generate a complete AWS service plugin module
export def main [
    service_name: string,         # AWS service name (e.g., "s3", "ec2")
    --output-dir: string = "plugin/services",  # Output directory for generated module
    --template: string = "standard",           # Module template to use
    --config: record = {},                     # Custom configuration overrides
    --validate,                               # Validate generated output
    --dry-run                                 # Preview without writing files
]: nothing -> record {
    
    print $"🔧 Generating AWS ($service_name) plugin module..."
    
    # Initialize configuration
    let generator_config = ($config | merge-generator-config)
    
    # Step 1: Discover service operations and schema
    print "📋 Discovering service operations..."
    let service_spec = discover-service-operations $service_name
    
    if ($service_spec.operations | length) == 0 {
        return {
            success: false,
            error: $"No operations found for service: ($service_name)",
            service: $service_name
        }
    }
    
    print $"   Found ($service_spec.operations | length) operations"
    
    # Step 2: Generate plugin module structure
    print "🏗️  Generating module structure..."
    let module_content = generate-plugin-module $service_name $service_spec $generator_config
    
    # Step 3: Generate external completion functions
    print "🔄 Generating completion functions..."
    let completion_content = generate-completion-functions $service_name $service_spec $generator_config
    
    # Step 4: Generate tests
    print "🧪 Generating test suite..."
    let test_content = generate-test-suite $service_name $service_spec $generator_config
    
    # Step 5: Validate generated content
    if $validate {
        print "✅ Validating generated content..."
        let validation = validate-generated-module $module_content $completion_content $test_content
        if not $validation.success {
            return {
                success: false,
                error: $"Validation failed: ($validation.error)",
                service: $service_name,
                validation: $validation
            }
        }
    }
    
    # Step 6: Write files (if not dry-run)
    if not $dry_run {
        print "💾 Writing module files..."
        let write_result = write-plugin-module $service_name $module_content $completion_content $test_content $output_dir
        
        if not $write_result.success {
            return {
                success: false,
                error: $"Failed to write files: ($write_result.error)",
                service: $service_name
            }
        }
        
        print $"✨ Successfully generated ($service_name) plugin module at ($write_result.module_path)"
        
        # Register with plugin system
        try {
            service_registry register-service $service_name $write_result.module_path
            print "📝 Registered with plugin system"
        } catch { |err|
            print $"⚠️  Warning: Could not register with plugin system: ($err.msg)"
        }
        
        return {
            success: true,
            service: $service_name,
            module_path: $write_result.module_path,
            operations_count: ($service_spec.operations | length),
            completions_count: ($completion_content.functions | length),
            tests_count: ($test_content.tests | length),
            files_written: $write_result.files_written,
            generator_config: $generator_config
        }
    } else {
        return {
            success: true,
            service: $service_name,
            dry_run: true,
            operations_count: ($service_spec.operations | length),
            preview: {
                module_lines: ($module_content | str length),
                completion_functions: ($completion_content.functions | length),
                test_count: ($test_content.tests | length)
            },
            generator_config: $generator_config
        }
    }
}

# Merge user configuration with defaults
def merge-generator-config []: record -> record {
    let config = $in
    $GENERATOR_CONFIG | merge $config
}

# Discover AWS service operations using AWS CLI help
def discover-service-operations [service_name: string] {
    print $"   Fetching ($service_name) operations from AWS CLI..."
    
    # Get AWS CLI help for the service
    let help_result = try {
        aws $service_name help | complete
    } catch { |err|
        return {
            success: false,
            error: $"Failed to get AWS CLI help for ($service_name): ($err.msg)",
            operations: []
        }
    }
    
    if $help_result.exit_code != 0 {
        return {
            success: false,
            error: $"AWS CLI help failed for ($service_name): ($help_result.stderr)",
            operations: []
        }
    }
    
    # Parse operations from help output
    let operations = parse-aws-cli-help $help_result.stdout $service_name
    print $"   DEBUG: Found ($operations | length) operations: ($operations | get name | str join ', ')"
    
    # Get detailed operation schemas
    let detailed_operations = $operations | each { |op|
        get-operation-schema $service_name $op.name
    }
    
    {
        success: true,
        service: $service_name,
        operations: $detailed_operations,
        help_raw: $help_result.stdout
    }
}

# Parse AWS CLI help output to extract operations
def parse-aws-cli-help [help_text: string, service_name: string] {
    # Extract Available Commands section - handle both normal and doubled character formats
    let commands_section = $help_text 
        | lines 
        | skip until {|line| ($line | str contains "AVAILABLE COMMANDS") or ($line | str contains "AAVVAAIILLAABBLLEE CCOOMMMMAANNDDSS")}
        | drop 1
        | take until {|line| ($line | str trim | str length) == 0 or ($line | str starts-with "GLOBAL OPTIONS")}
        | where {|line| $line | str trim | str length > 0}
    
    print $"   DEBUG: Commands section has ($commands_section | length) lines"
    if ($commands_section | length) > 0 {
        print $"   DEBUG: First few lines: ($commands_section | first 3 | str join ' | ')"
    }
    
    $commands_section | each { |line|
        let trimmed = $line | str trim
        
        # Handle bullet point format (+o command-name)
        if ($trimmed | str starts-with "+o ") {
            let command_name = $trimmed | str replace "+o " "" | str trim
            {
                name: $command_name,
                description: ""
            }
        } else {
            # Handle regular format (command-name description)
            let parts = $trimmed | split row " " | where {|part| $part | str length > 0}
            if ($parts | length) > 0 and not ($parts.0 | str starts-with " ") {
                {
                    name: $parts.0,
                    description: (if ($parts | length) > 1 { $parts | skip 1 | str join " " } else { "" })
                }
            }
        }
    } | where {|op| $op != null and $op.name | str length > 0}
}

# Get detailed schema for a specific operation
def get-operation-schema [service_name: string, operation_name: string] {
    print $"      Getting schema for ($service_name) ($operation_name)..."
    
    let help_result = try {
        aws $service_name $operation_name help | complete
    } catch { |err|
        print $"      Warning: Could not get help for ($operation_name): ($err.msg)"
        return {
            name: $operation_name,
            parameters: [],
            description: "",
            error: $err.msg
        }
    }
    
    if $help_result.exit_code != 0 {
        print $"      Warning: Help failed for ($operation_name): ($help_result.stderr)"
        return {
            name: $operation_name,
            parameters: [],
            description: "",
            error: $help_result.stderr
        }
    }
    
    # Parse operation details using parameter generation system
    let parsed_schema = try {
        parameter_generation parse-aws-operation-help $help_result.stdout $service_name $operation_name
    } catch { |err|
        print $"      Warning: Schema parsing failed for ($operation_name): ($err.msg)"
        return {
            name: $operation_name,
            parameters: [],
            description: "",
            parse_error: $err.msg,
            help_raw: $help_result.stdout
        }
    }
    
    $parsed_schema
}

# Generate complete plugin module using type-safe parameter generation
def generate-plugin-module [service_name: string, service_spec: record, config: record] {
    print $"   Generating module structure for ($service_name)..."
    
    # Generate module header
    let module_header = generate-module-header $service_name $service_spec $config
    
    # Generate service metadata function
    let metadata_function = generate-service-metadata $service_name $service_spec
    
    # Generate all operation functions using parameter generation system
    let operation_functions = $service_spec.operations | each { |operation|
        try {
            parameter_generation generate-function-signature $operation
        } catch { |err|
            print $"      Warning: Failed to generate function for ($operation.name): ($err.msg)"
            generate-fallback-function $operation $service_name
        }
    }
    
    # Generate service helpers and utilities
    let service_helpers = generate-service-helpers $service_name $config
    
    # Assemble complete module
    let module_content = [
        $module_header,
        $metadata_function,
        "",
        "# Generated AWS Operations",
        "",
        ($operation_functions | str join "\n\n"),
        "",
        $service_helpers
    ] | str join "\n"
    
    {
        content: $module_content,
        functions: $operation_functions,
        metadata: {
            service: $service_name,
            operations_count: ($service_spec.operations | length),
            generated_at: (date now | format date '%Y-%m-%d %H:%M:%S'),
            generator_version: $config.template_version
        }
    }
}

# Generate module header with imports and documentation
def generate-module-header [service_name: string, service_spec: record, config: record] {
    let service_title = $service_name | str title-case
    
    $"# AWS ($service_title) Service Plugin Module
# Generated by NuAWS Universal Generator v($config.template_version)
# Service: ($service_name)
# Operations: ($service_spec.operations | length)
# Generated: (date now | format date '%Y-%m-%d %H:%M:%S')

use ../core/error_handler.nu
use ../core/configuration.nu
use ../../aws/cache/mod.nu as cache

# Service configuration
const SERVICE_NAME = \"($service_name)\"
const SERVICE_VERSION = \"2024-01-01\"
const MOCK_MODE_ENV = \"($service_name | str upcase)_MOCK_MODE\""
}

# Generate service metadata function  
def generate-service-metadata [service_name: string, service_spec: record] {
    let service_description = match $service_name {
        "s3" => "Amazon Simple Storage Service - Object storage",
        "ec2" => "Amazon Elastic Compute Cloud - Virtual servers", 
        "iam" => "AWS Identity and Access Management - User and permission management",
        "lambda" => "AWS Lambda - Serverless compute",
        "dynamodb" => "Amazon DynamoDB - NoSQL database",
        "stepfunctions" => "AWS Step Functions - Workflow orchestration",
        "rds" => "Amazon Relational Database Service - Managed databases",
        _ => $"AWS ($service_name | str title-case) Service"
    }
    
    $"# Get service metadata for plugin system
export def get-service-metadata []: nothing -> record {
    {
        name: \"($service_name)\",
        description: \"($service_description)\",
        version: SERVICE_VERSION,
        operations: ($service_spec.operations | length),
        capabilities: [\"completions\", \"caching\", \"mock\"],
        generated_at: \"(date now | format date '%Y-%m-%d %H:%M:%S')\",
        plugin_version: \"2.0\"
    }
}"
}

# Generate fallback function for operations that failed to parse
def generate-fallback-function [operation: record, service_name: string] {
    $"# ($operation.name) - Basic fallback implementation
export def ($operation.name | str kebab-case) [
    ...args: any  # Accept any arguments
]: nothing -> any {
    let cmd_args = \\$args | where {|arg| \\$arg != null} | each {|arg| \\$\"\\\\\"(\\$arg)\\\\\"\"}
    
    if (\\$env.($service_name | str upcase)_MOCK_MODE? | default false) {
        {
            mock: true,
            operation: \"($operation.name)\",
            service: \"($service_name)\",
            result: \"mock-response\"
        }
    } else {
        aws ($service_name) ($operation.name) ...(\\$cmd_args) | from json
    }
}"
}

# Generate service helper functions
def generate-service-helpers [service_name: string, config: record] {
    $"# Service helper functions

# Check if service is in mock mode
def is-mock-mode []: nothing -> bool {
    \\$env.MOCK_MODE_ENV? | default false
}

# Execute AWS CLI command with error handling
def execute-aws-command [
    operation: string,
    args: list<string> = []
] {
    if (is-mock-mode) {
        generate-mock-response \\$operation \\$args
    } else {
        try {
            aws SERVICE_NAME \\$operation ...\\$args | from json
        } catch { |err|
            error_handler create-aws-error {
                service: SERVICE_NAME,
                operation: \\$operation,
                error: \\$err.msg,
                args: \\$args
            }
        }
    }
}

# Generate mock response for testing
def generate-mock-response [
    operation: string,
    args: list<string>
] {
    {
        mock: true,
        service: SERVICE_NAME,
        operation: \\$operation,
        timestamp: (date now),
        result: \"mock-data-for-\" + \\$operation
    }
}"
}

# Generate external completion functions
def generate-completion-functions [service_name: string, service_spec: record, config: record] {
    print $"   Generating completion functions for ($service_name)..."
    
    # Extract resource types from operations
    let resource_types = extract-resource-types $service_spec.operations
    
    # Generate completion functions for each resource type
    let completion_functions = $resource_types | each { |resource|
        generate-resource-completion-function $service_name $resource
    }
    
    {
        functions: $completion_functions,
        resource_types: $resource_types,
        content: ($completion_functions | str join "\n\n")
    }
}

# Extract resource types from operations (buckets, instances, etc.)
def extract-resource-types [operations: list<record>] {
    let patterns = [
        "bucket", "object", "instance", "volume", "security-group", "vpc", 
        "subnet", "user", "role", "policy", "function", "layer", "table",
        "state-machine", "execution", "database", "cluster"
    ]
    
    $operations | each { |op|
        $patterns | where { |pattern| $op.name | str contains $pattern }
    } | flatten | uniq
}

# Generate completion function for a resource type
def generate-resource-completion-function [service_name: string, resource_type: string] {
    $"# External completion for ($service_name) ($resource_type)
export def \"nu-complete ($service_name) ($resource_type)\" []: nothing -> list<string> {
    if (\\$env.($service_name | str upcase)_MOCK_MODE? | default false) {
        [\"mock-($resource_type)-1\", \"mock-($resource_type)-2\", \"mock-($resource_type)-3\"]
    } else {
        try {
            # This would be replaced with actual AWS API calls to discover resources
            aws ($service_name) list-($resource_type)s --query \"($resource_type | str title-case)s[].Name\" --output text 
                | lines 
                | where {|line| \\$line | str trim | str length > 0}
        } catch {
            []
        }
    }
}"
}

# Generate test suite for the module
def generate-test-suite [service_name: string, service_spec: record, config: record] {
    print $"   Generating test suite for ($service_name)..."
    
    let test_header = $"# ($service_name | str title-case) Service Plugin Tests
# Generated test suite for AWS ($service_name) service plugin

use std/assert
use ../../($service_name).nu

#[before-each]
def setup [] {
    \\$env.($service_name | str upcase)_MOCK_MODE = true
    \\$env.AWS_REGION = \"us-east-1\"
    \\$env.AWS_ACCOUNT_ID = \"123456789012\"
    
    {
        test_context: \"($service_name)_service\",
        mock_mode: true
    }
}"
    
    # Generate basic tests for each operation
    let operation_tests = $service_spec.operations | each { |operation|
        generate-operation-test $service_name $operation
    } | take 10  # Limit to first 10 operations to keep file manageable
    
    let test_content = [
        $test_header,
        "",
        ($operation_tests | str join "\n\n"),
        "",
        generate-service-metadata-test $service_name
    ] | str join "\n"
    
    {
        content: $test_content,
        tests: $operation_tests,
        test_count: (($operation_tests | length) + 1)
    }
}

# Generate test for a specific operation
def generate-operation-test [service_name: string, operation: record] {
    let function_name = $operation.name | str kebab-case
    
    [
        "#[test]",
        ("def \"test " + $service_name + " " + $function_name + " mock mode\" [] {"),
        "    let context = $in",
        "",
        ("    let result = " + $function_name),
        "    assert ($result.mock == true) \"Should return mock response in test mode\"",
        ("    assert ($result.service == \"" + $service_name + "\") \"Should identify correct service\""),
        ("    assert ($result.operation == \"" + $operation.name + "\") \"Should identify correct operation\""),
        "}"
    ] | str join "\n"
}

# Generate service metadata test
def generate-service-metadata-test [service_name: string] {
    [
        "#[test]",
        ("def \"test " + $service_name + " service metadata\" [] {"),
        "    let metadata = get-service-metadata",
        "",
        ("    assert ($metadata.name == \"" + $service_name + "\") \"Service name should match\""),
        "    assert ($metadata.operations > 0) \"Should have operations defined\"",
        "    assert (\"completions\" in $metadata.capabilities) \"Should support completions\"",
        "    assert (\"mock\" in $metadata.capabilities) \"Should support mock mode\"",
        "}"
    ] | str join "\n"
}

# Validate generated module content
def validate-generated-module [module_content: record, completion_content: record, test_content: record] {
    let validation_errors = []
    
    # Validate module syntax
    let module_result = try {
        nu --check -c $module_content.content
        {success: true, error: null}
    } catch { |err|
        {success: false, error: $"Module syntax error: ($err.msg)"}
    }
    
    # Validate completions syntax
    let completion_result = try {
        nu --check -c $completion_content.content
        {success: true, error: null}
    } catch { |err|
        {success: false, error: $"Completion syntax error: ($err.msg)"}
    }
    
    # Validate test syntax
    let test_result = try {
        nu --check -c $test_content.content
        {success: true, error: null}
    } catch { |err|
        {success: false, error: $"Test syntax error: ($err.msg)"}
    }
    
    # Collect all errors
    let syntax_errors = [
        $module_result.error,
        $completion_result.error, 
        $test_result.error
    ] | where {|x| $x != null}
    
    # Check for required exports
    let metadata_errors = if not ($module_content.content | str contains "export def get-service-metadata") {
        ["Missing required get-service-metadata export"]
    } else {
        []
    }
    
    let all_errors = ($validation_errors | append $syntax_errors | append $metadata_errors)
    
    {
        success: (($all_errors | length) == 0),
        syntax_valid: ($module_result.success and $completion_result.success and $test_result.success),
        errors: $all_errors
    }
}

# Write generated files to disk
def write-plugin-module [
    service_name: string,
    module_content: record,
    completion_content: record, 
    test_content: record,
    output_dir: string
] {
    
    # Ensure output directory exists
    if not ($output_dir | path exists) {
        mkdir $output_dir
    }
    
    let module_path = $"($output_dir)/($service_name).nu"
    let completion_path = $"($output_dir)/completions/($service_name).nu"
    let test_path = $"tests/plugin/services/test_($service_name).nu"
    
    mut written_files = []
    
    # Write main module
    try {
        $module_content.content | save $module_path
        $written_files = ($written_files | append $module_path)
    } catch { |err|
        return {
            success: false,
            error: $"Failed to write module file: ($err.msg)"
        }
    }
    
    # Write completions (create directory if needed)
    try {
        let completion_dir = $completion_path | path dirname
        if not ($completion_dir | path exists) {
            mkdir $completion_dir
        }
        $completion_content.content | save $completion_path
        $written_files = ($written_files | append $completion_path)
    } catch { |err|
        return {
            success: false,
            error: $"Failed to write completion file: ($err.msg)"
        }
    }
    
    # Write tests (create directory if needed)
    try {
        let test_dir = $test_path | path dirname
        if not ($test_dir | path exists) {
            mkdir $test_dir
        }
        $test_content.content | save $test_path
        $written_files = ($written_files | append $test_path)
    } catch { |err|
        return {
            success: false,
            error: $"Failed to write test file: ($err.msg)"
        }
    }
    
    {
        success: true,
        module_path: $module_path,
        files_written: $written_files
    }
}

# List available AWS services for generation
export def list-available-services []: nothing -> list<string> {
    [
        "s3", "ec2", "iam", "lambda", "dynamodb", "stepfunctions", "rds", 
        "eks", "ecs", "cloudformation", "route53", "cloudfront", "apigateway",
        "sns", "sqs", "kinesis", "glue", "athena", "redshift", "elasticache"
    ]
}

# Show generation progress and statistics
export def show-generation-stats [
    service_name: string,
    result: record
] {
    if $result.success {
        print $"✅ Successfully generated ($service_name) service plugin"
        print $"   📊 Operations: ($result.operations_count)"
        print $"   🔄 Completions: ($result.completions_count)"
        print $"   🧪 Tests: ($result.tests_count)"
        print $"   📁 Files: ($result.files_written | length)"
        if "module_path" in $result {
            print $"   📝 Module: ($result.module_path)"
        }
    } else {
        print $"❌ Failed to generate ($service_name) service plugin"
        print $"   Error: ($result.error)"
    }
}