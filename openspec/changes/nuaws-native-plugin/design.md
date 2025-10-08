# Native Nushell AWS Plugin Design

## Architecture Overview

This design transforms the current AWS CLI wrapper approach into a comprehensive plugin system that provides native Nushell integration while building upon existing foundations.

## Current System Analysis

### Strengths to Preserve
- **Universal Generator Pattern**: Single generator creates complete service implementations
- **Type-Safe Parameter Generation**: Real AWS schema → Nushell function signatures  
- **Mock-First Testing**: Environment variable toggles for safe development
- **TDD Methodology**: 555+ tests with comprehensive coverage
- **Pure Functional Design**: Immutable data, composable functions

### Gaps to Address
- **Fragmented Command Structure**: Individual service modules vs unified namespace
- **Manual Discovery**: No automatic service/command discovery mechanism
- **Limited Pipeline Integration**: Basic AWS CLI wrapping vs native Nushell patterns
- **Static Completions**: No live AWS resource completion system
- **Inconsistent Entry Points**: Multiple scripts vs single plugin interface

## Plugin Architecture Design

### 1. Core Plugin System

#### Entry Point Router (`nuaws_core.nu`)
```nushell
# Main entry point for all AWS operations
export def main [
    service?: string@"nu-complete aws services"  # Optional service name
    ...args: any                                 # Service-specific arguments
]: nothing -> any {
    
    # Handle service discovery and help
    if ($service | is-empty) {
        return (show-services-help)
    }
    
    # Route to appropriate service module
    let service_module = (load-service-module $service)
    let command_args = ($args | skip 1)  # Remove service name from args
    
    # Execute service command with full argument forwarding
    $service_module | invoke $args.0 ...$command_args
}

# Service discovery and lazy loading
def load-service-module [service: string]: nothing -> module {
    let module_path = $"services/($service).nu"
    
    # Cache check for performance
    if (is-module-cached $service) {
        return (get-cached-module $service)
    }
    
    # Generate module if not exists
    if not ($module_path | path exists) {
        generate-service-module $service
    }
    
    # Load and cache module
    let module = (use $module_path)
    cache-module $service $module
    return $module
}
```

#### Service Module Template
```nushell
# Generated service module (e.g., services/s3.nu)
export def "list-buckets" [
    --max-buckets: int = 1000
]: nothing -> table<name: string, creation_date: datetime> {
    validate-aws-credentials
    
    if (get-mock-mode "s3") {
        return (get-mock-s3-buckets)
    }
    
    aws s3api list-buckets 
    | get buckets 
    | select name creation_date
    | into datetime creation_date
}

export def "get-object" [
    bucket: string@"nu-complete s3 buckets"
    key: string@"nu-complete s3 objects"
    --version-id: string
    --range: string
]: nothing -> record {
    # Type-safe parameter validation
    validate-s3-bucket-name $bucket
    validate-s3-object-key $key
    
    # Build AWS CLI command with validated parameters
    let cmd = [
        "aws" "s3api" "get-object"
        "--bucket" $bucket
        "--key" $key
    ]
    
    # Add optional parameters
    let cmd = if ($version_id | is-not-empty) {
        $cmd ++ ["--version-id" $version_id]
    } else { $cmd }
    
    # Execute with error handling
    try {
        run-external ...$cmd | from json
    } catch { |e|
        error make {
            msg: $"Failed to get S3 object: ($e.msg)"
            label: {
                text: "S3 operation failed"
                span: (metadata $bucket).span
            }
        }
    }
}
```

### 2. External Completion System

#### Dynamic Resource Discovery
```nushell
# External completion for AWS services
export def "nu-complete aws services" []: nothing -> list<string> {
    # Return list of available/generated services
    let services_dir = "services"
    ls $services_dir 
    | get name 
    | path basename 
    | str replace ".nu" ""
}

# Live AWS resource completions
export def "nu-complete s3 buckets" []: nothing -> list<string> {
    if (get-mock-mode "s3") {
        return ["mock-bucket-1", "mock-bucket-2", "test-data-bucket"]
    }
    
    # Cache completion results for performance
    let cache_key = "s3-buckets"
    let cached = (get-completion-cache $cache_key)
    
    if ($cached | is-not-empty) and (is-cache-valid $cached) {
        return $cached.data
    }
    
    # Fetch fresh data
    let buckets = try {
        aws s3api list-buckets | get buckets.name
    } catch {
        # Fallback to empty list on error
        []
    }
    
    # Update cache
    set-completion-cache $cache_key $buckets
    return $buckets
}

# Context-aware object completions
export def "nu-complete s3 objects" [
    context: record  # Contains current command context
]: nothing -> list<string> {
    # Extract bucket from context (positional parameter)
    let bucket = try {
        $context.positional | get 0
    } catch {
        return []  # No bucket specified yet
    }
    
    if (get-mock-mode "s3") {
        return ["mock-object-1.txt", "data/mock-file.json", "images/test.png"]
    }
    
    # Get objects for specific bucket
    try {
        aws s3api list-objects-v2 --bucket $bucket 
        | get contents.key 
        | first 50  # Limit for performance
    } catch {
        []
    }
}
```

#### Completion Caching System
```nushell
# Completion performance optimization
def get-completion-cache [key: string]: nothing -> record {
    let cache_file = $"($env.HOME)/.nuaws/completion_cache/($key).json"
    
    if ($cache_file | path exists) {
        try {
            open $cache_file
        } catch {
            { data: [], timestamp: 0 }
        }
    } else {
        { data: [], timestamp: 0 }
    }
}

def set-completion-cache [key: string, data: list]: nothing -> nothing {
    let cache_dir = $"($env.HOME)/.nuaws/completion_cache"
    mkdir $cache_dir
    
    let cache_data = {
        data: $data,
        timestamp: (date now | date to-record | get timestamp),
        ttl_seconds: 300  # 5 minute cache
    }
    
    $cache_data | save $"($cache_dir)/($key).json"
}

def is-cache-valid [cache: record]: nothing -> bool {
    let now = (date now | date to-record | get timestamp)
    let age = ($now - $cache.timestamp)
    ($age < $cache.ttl_seconds)
}
```

### 3. Enhanced Universal Generator

#### Plugin-Aware Generation
```nushell
# Enhanced generator for plugin compatibility
export def generate-plugin-service [
    service_name: string
    --output-dir: string = "services"
]: nothing -> record {
    
    # Extract AWS service schema
    let schema = (extract-aws-service-schema $service_name)
    
    # Generate plugin-compatible module
    let module_content = (build-plugin-module $service_name $schema)
    
    # Generate external completions
    let completion_content = (build-completion-module $service_name $schema)
    
    # Write generated files
    let module_file = $"($output_dir)/($service_name).nu"
    let completion_file = $"completions/($service_name)_completions.nu"
    
    $module_content | save $module_file
    $completion_content | save $completion_file
    
    return {
        service: $service_name,
        module_file: $module_file,
        completion_file: $completion_file,
        operations: ($schema.operations | length),
        generated_at: (date now)
    }
}

# Build plugin module from AWS schema
def build-plugin-module [
    service_name: string, 
    schema: record
]: nothing -> string {
    
    let operations = $schema.operations
    
    # Generate function definitions for each operation
    let functions = ($operations | items | each { |item|
        let op_name = $item.key
        let op_schema = $item.value
        
        build-operation-function $service_name $op_name $op_schema
    })
    
    # Combine into module template
    build-module-template $service_name $functions
}

def build-operation-function [
    service: string,
    operation: string, 
    schema: record
]: nothing -> string {
    
    # Convert operation name to kebab-case
    let func_name = (to-kebab-case $operation)
    
    # Generate type-safe parameters
    let params = (build-function-parameters $schema.input)
    
    # Generate return type
    let return_type = (build-return-type $schema.output)
    
    # Generate function body
    let body = (build-function-body $service $operation $schema)
    
    # Combine into function definition
    $"export def \"($func_name)\" [($params)]: nothing -> ($return_type) {
    ($body)
}"
}
```

### 4. Pipeline Integration Patterns

#### Native Nushell Data Structures
```nushell
# Optimize for Nushell pipeline usage
def optimize-return-type [aws_schema: record]: nothing -> string {
    match $aws_schema.type {
        "array" => {
            # Prefer table<> over list<record<>>
            if (is-record-array $aws_schema) {
                let columns = (extract-table-columns $aws_schema.items)
                $"table<($columns | str join ', ')>"
            } else {
                $"list<($convert-type $aws_schema.items)>"
            }
        },
        "object" => "record",
        "string" => "string",
        "number" => "int",
        "boolean" => "bool",
        _ => "any"
    }
}

# Pipeline-friendly error handling
def pipeline-safe-aws-call [
    service: string,
    operation: string,
    params: record
]: nothing -> any {
    
    try {
        # Execute AWS operation
        let result = (execute-aws-operation $service $operation $params)
        
        # Transform to Nushell-native format
        transform-aws-response $result
        
    } catch { |error|
        # Create structured error for pipeline context
        error make {
            msg: $"AWS ($service) ($operation) failed: ($error.msg)",
            label: {
                text: "AWS operation error",
                span: (metadata $params).span
            },
            help: $"Try: nuaws ($service) help ($operation)"
        }
    }
}
```

#### Performance Optimizations
```nushell
# Lazy loading for large operations
def lazy-load-large-result [
    operation: closure,
    threshold: int = 1000
]: nothing -> table {
    
    # Stream results for large datasets
    let first_batch = ($operation | invoke)
    
    if ($first_batch | length) > $threshold {
        # Return streaming table for large results
        create-streaming-table $operation
    } else {
        # Return complete table for small results
        $first_batch
    }
}

# Batch processing for bulk operations
def batch-aws-operations [
    operations: list,
    batch_size: int = 10
]: nothing -> list {
    
    $operations 
    | chunks $batch_size 
    | par-each { |batch|
        $batch | each { |op| 
            execute-aws-operation $op.service $op.operation $op.params 
        }
    }
    | flatten
}
```

## Integration Points

### 1. Existing System Compatibility

#### Schema Processing Pipeline
```
Current: aws_openapi_extractor.nu → real-schemas/*.json
Enhanced: aws_openapi_extractor.nu → real-schemas/*.json → plugin_generator.nu → services/*.nu
```

#### Testing Framework Integration
```nushell
# Extend nutest for plugin testing
#[test]
def "test nuaws s3 list-buckets" [] {
    $env.S3_MOCK_MODE = "true"
    
    let result = (nuaws s3 list-buckets)
    
    assert_type $result "table"
    assert_contains ($result | columns) "name"
    assert_contains ($result | columns) "creation_date"
}

#[test]  
def "test external completion s3 buckets" [] {
    $env.S3_MOCK_MODE = "true"
    
    let completions = (nu-complete s3 buckets)
    
    assert_type $completions "list"
    assert_greater_than ($completions | length) 0
}
```

### 2. Migration Strategy

#### Phase 1: Core Infrastructure
- Create `nuaws_core.nu` entry point with service routing
- Implement service loading and caching system
- Build external completion framework
- Establish plugin testing patterns

#### Phase 2: Generator Enhancement  
- Upgrade `universal_aws_generator.nu` for plugin output
- Add completion generation capabilities
- Create module templates for consistent structure
- Implement performance optimizations

#### Phase 3: Service Migration
- Convert existing Step Functions module to plugin format
- Generate core services (S3, EC2, IAM, Lambda)
- Implement comprehensive external completions
- Optimize caching and performance

#### Phase 4: Ecosystem Integration
- Documentation and examples
- Performance benchmarking
- Community feedback integration
- Plugin distribution mechanisms

### 3. Quality Assurance

#### Test Coverage Strategy
```nushell
# Plugin-specific test patterns
export def test-plugin-service [service: string]: nothing -> record {
    # Test service loading
    assert_no_error { load-service-module $service }
    
    # Test command discovery  
    let commands = (discover-service-commands $service)
    assert_greater_than ($commands | length) 0
    
    # Test external completions
    let completions = (test-service-completions $service)
    assert_type $completions "list"
    
    return {
        service: $service,
        commands: ($commands | length),
        completions_working: ($completions | length) > 0,
        test_status: "passed"
    }
}
```

## Risk Mitigation Implementation

### Schema Extraction Resilience

#### Multi-Source Schema Extraction
```nushell
# Prioritized schema sources with fallbacks
def extract-service-schema [service: string]: nothing -> record {
    # Priority 1: botocore schemas (structured, stable)
    let botocore_schema = try {
        extract-botocore-schema $service
    } catch { null }
    
    # Priority 2: Existing OpenAPI specs (if available)
    let openapi_schema = try {
        extract-openapi-schema $service
    } catch { null }
    
    # Priority 3: CLI help (supplementary, descriptions only)
    let cli_help_data = try {
        extract-cli-help-data $service
    } catch { null }
    
    # Merge with validation
    merge-and-validate-schemas $botocore_schema $openapi_schema $cli_help_data
}

# Schema validation to detect breaking changes
def validate-schema-consistency [
    current_schema: record,
    previous_schema: record
]: nothing -> record {
    let operation_diff = compare-operations $current_schema $previous_schema
    let parameter_diff = compare-parameters $current_schema $previous_schema
    
    # Fail if significant regression
    if ($operation_diff.missing_count / $previous_schema.operation_count) > 0.1 {
        error make {
            msg: $"Schema extraction failed: Missing ($operation_diff.missing_count) operations"
            help: "CLI help format may have changed. Check extraction logic."
        }
    }
    
    {
        status: "valid",
        operation_changes: $operation_diff,
        parameter_changes: $parameter_diff
    }
}
```

#### Canary Test System
```nushell
# Critical service monitoring
def run-canary-tests []: nothing -> record {
    let critical_services = ["s3", "ec2", "iam", "lambda"]
    
    $critical_services | each { |service|
        let test_result = try {
            # Test help parsing
            let help_data = aws $service help | parse-help-services
            
            # Validate expected structure
            assert ($help_data | length) > 0
            assert ("operations" in $help_data)
            
            { service: $service, status: "pass", timestamp: (date now) }
        } catch { |err|
            { 
                service: $service, 
                status: "fail", 
                error: $err.msg,
                timestamp: (date now)
            }
        }
    } | compact
}
```

### Complex Parameter Handling

#### JSON Parameter Processing
```nushell
# Handle JSON parameters with automatic conversion
def process-json-parameter [
    param_name: string,
    param_value: any
]: nothing -> string {
    match ($param_value | describe) {
        "record" => ($param_value | to json --compact),
        "string" => {
            # Validate if already JSON
            try {
                $param_value | from json | ignore
                $param_value
            } catch {
                # Treat as literal string
                $param_value | to json
            }
        },
        _ => ($param_value | to json --compact)
    }
}

# File path parameter handling  
def process-file-parameter [
    param_value: string
]: nothing -> string {
    if ($param_value | str starts-with "file://") {
        $param_value
    } else if ($param_value | path exists) {
        $"file://($param_value | path expand)"
    } else {
        error make {
            msg: $"File not found: ($param_value)",
            help: "Provide a valid file path or file:// URI"
        }
    }
}
```

### Performance Monitoring and Optimization

#### Lazy Loading Implementation
```nushell
# Service module lazy loading
def load-service-on-demand [service: string]: nothing -> module {
    let cache_key = $"service_($service)"
    
    # Check if already loaded
    if ($cache_key in $env.NUAWS_MODULE_CACHE) {
        return $env.NUAWS_MODULE_CACHE | get $cache_key
    }
    
    # Load and cache module
    let start_time = date now
    let module = use $"services/($service).nu"
    let load_time = (date now) - $start_time
    
    # Monitor loading performance
    if $load_time > 100ms {
        print $"Warning: Slow service load for ($service): ($load_time)"
    }
    
    # Cache for future use
    $env.NUAWS_MODULE_CACHE = ($env.NUAWS_MODULE_CACHE | insert $cache_key $module)
    
    $module
}

# Performance benchmarking
def benchmark-command-performance [
    service: string,
    operation: string,
    iterations: int = 10
]: nothing -> record {
    let native_times = 1..$iterations | each {
        let start = date now
        aws $service $operation --help | ignore
        (date now) - $start
    }
    
    let nuaws_times = 1..$iterations | each {
        let start = date now
        nuaws $service $operation --help | ignore
        (date now) - $start
    }
    
    {
        service: $service,
        operation: $operation,
        native_avg: ($native_times | math avg),
        nuaws_avg: ($nuaws_times | math avg),
        overhead: ($nuaws_times | math avg) - ($native_times | math avg),
        acceptable: (($nuaws_times | math avg) - ($native_times | math avg)) < 100ms
    }
}
```

### Authentication Delegation Pattern

#### Zero-Touch Authentication
```nushell
# Complete delegation to AWS CLI
def execute-aws-command [
    service: string,
    operation: string,
    parameters: record
]: nothing -> any {
    # Build command exactly as AWS CLI expects
    mut cmd = ["aws", $service, $operation]
    
    # Add parameters without modification
    for param in ($parameters | items) {
        $cmd = ($cmd | append ["--($param.key)", $param.value])
    }
    
    # Execute with complete environment inheritance
    let result = run-external "aws" ...$cmd 
        | complete
    
    # Only handle formatting, never authentication
    if $result.exit_code == 0 {
        $result.stdout | from json | convert-aws-types
    } else {
        handle-aws-error $result.stderr $service $operation
    }
}
```

This design maintains the project's strengths while creating a unified, native Nushell experience that positions `nuaws` as the definitive AWS CLI for the Nushell ecosystem. The risk mitigation strategies ensure robustness and maintainability while preserving the core benefits of the plugin architecture.