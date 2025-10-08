# Service Module Interface - Standard contract for AWS service modules
# Defines the required interface that all service modules must implement

# Service module metadata structure
export def service-metadata-schema []: nothing -> record {
    {
        name: "string",           # Service name (e.g., "s3", "ec2")
        description: "string",    # Human-readable description
        version: "string",        # Module version
        aws_service_id: "string", # Official AWS service identifier
        generated: "bool",        # Whether this module was auto-generated
        generated_at: "datetime", # When the module was generated (if applicable)
        generator_version: "string", # Version of generator used
        type: "string",          # Module type: "native", "generated", "legacy", "passthrough"
        capabilities: "list",     # List of supported capabilities
        requires_auth: "bool",    # Whether service requires AWS authentication
        supports_mock: "bool",    # Whether service supports mock mode
        operations_count: "int",  # Number of operations available
        last_updated: "datetime", # Last update timestamp
        dependencies: "list"      # List of required dependencies
    }
}

# Operation metadata structure
export def operation-metadata-schema []: nothing -> record {
    {
        name: "string",              # Operation name (e.g., "list-buckets")
        description: "string",       # Human-readable description
        aws_operation: "string",     # AWS CLI operation name
        category: "string",          # Operation category: "list", "create", "delete", "describe", "update"
        parameters: "list",          # List of parameter definitions
        returns: "string",           # Return type description
        examples: "list",            # Usage examples
        requires_auth: "bool",       # Whether operation requires authentication
        supports_mock: "bool",       # Whether operation supports mock mode
        destructive: "bool",         # Whether operation modifies resources
        streaming: "bool",           # Whether operation supports streaming
        pagination: "bool",          # Whether operation supports pagination
        completion_sources: "list"   # List of completion source definitions
    }
}

# Parameter definition structure
export def parameter-schema []: nothing -> record {
    {
        name: "string",           # Parameter name
        type: "string",           # Nushell type (string, int, bool, etc.)
        required: "bool",         # Whether parameter is required
        description: "string",    # Parameter description
        aws_name: "string",       # AWS CLI parameter name
        default: "any",           # Default value (if any)
        validation: "record",     # Validation rules
        completion: "record",     # Completion configuration
        examples: "list"          # Example values
    }
}

# Completion source definition
export def completion-source-schema []: nothing -> record {
    {
        name: "string",           # Completion source name
        type: "string",           # Type: "aws_resource", "static", "dynamic", "file"
        aws_command: "string",    # AWS CLI command to fetch completions
        cache_ttl: "int",         # Cache time-to-live in seconds
        depends_on: "list",       # Parameters this completion depends on
        filter: "string",         # Filter expression for results
        transform: "string"       # Transform expression for results
    }
}

# Validation rules structure
export def validation-schema []: nothing -> record {
    {
        pattern: "string",        # Regex pattern (if applicable)
        min_length: "int",        # Minimum length
        max_length: "int",        # Maximum length
        min_value: "number",      # Minimum numeric value
        max_value: "number",      # Maximum numeric value
        allowed_values: "list",   # List of allowed values
        custom_validator: "string" # Custom validation function name
    }
}

# Required functions that every service module must export
export def required-exports []: nothing -> list<string> {
    [
        "get-service-metadata",      # Returns service metadata
        "get-operations",            # Returns list of operations
        "get-operation-metadata",    # Returns metadata for specific operation
        "list-operation-names",      # Returns list of operation names
        "has-operation",             # Checks if operation exists
        "validate-operation-params", # Validates parameters for operation
        "get-completions",           # Gets completions for parameter
        "execute-operation",         # Executes an operation
        "get-mock-response",         # Returns mock response (if mock supported)
        "warm-completions"           # Pre-warms completion cache
    ]
}

# Optional functions that service modules may export
export def optional-exports []: nothing -> list<string> {
    [
        "get-service-status",        # Returns service health/status
        "get-service-limits",        # Returns service quotas/limits
        "get-cost-estimate",         # Estimates operation costs
        "get-security-analysis",     # Security analysis for operation
        "get-best-practices",        # Best practices recommendations
        "transform-output",          # Custom output transformation
        "handle-errors",             # Custom error handling
        "pre-execute-hook",          # Pre-execution hook
        "post-execute-hook"          # Post-execution hook
    ]
}

# Standard capability flags
export def standard-capabilities []: nothing -> list<string> {
    [
        "list_operations",           # Can list available operations
        "describe_operations",       # Can describe operations in detail
        "parameter_validation",      # Validates parameters before execution
        "external_completions",      # Provides external completions
        "mock_responses",            # Supports mock mode
        "streaming_output",          # Supports streaming large results
        "pagination",                # Supports paginated results
        "bulk_operations",           # Supports bulk/batch operations
        "cost_estimation",           # Can estimate operation costs
        "security_analysis",         # Can analyze security implications
        "error_recovery",            # Has advanced error recovery
        "caching",                   # Supports result caching
        "transformation",            # Supports output transformation
        "hooks"                      # Supports pre/post execution hooks
    ]
}

# Validate service module interface compliance
export def validate-service-module [module_path: string]: nothing -> record {
    # Base validation result structure
    let base_result = {
        compliant: false,
        errors: [],
        warnings: [],
        missing_exports: [],
        metadata_issues: [],
        capabilities: []
    }
    
    # Perform validation and collect results
    let validation = try {
        # Check if file exists
        if not ($module_path | path exists) {
            {
                success: false,
                errors: [$"Module file does not exist: ($module_path)"],
                missing_exports: [],
                metadata_issues: [],
                capabilities: []
            }
        } else {
            # Read module content for basic validation
            let content = open $module_path
            
            # Check required exports by searching for export definitions
            let required = required-exports
            let missing_exports = $required | where {|export_name|
                not ($content | str contains $export_name)
            }
            
            # Check for get-service-metadata function and extract metadata info
            let metadata_result = if ($content | str contains "export def get-service-metadata") {
                let capabilities = if ($content | str contains "capabilities:") {
                    ["basic_validation"]
                } else {
                    []
                }
                {has_metadata: true, capabilities: $capabilities, issues: []}
            } else {
                {has_metadata: false, capabilities: [], issues: ["Missing get-service-metadata function"]}
            }
            
            {
                success: true,
                errors: [],
                missing_exports: $missing_exports,
                metadata_issues: $metadata_result.issues,
                capabilities: $metadata_result.capabilities
            }
        }
    } catch { |err|
        {
            success: false,
            errors: [$"Failed to validate module: ($err.msg)"],
            missing_exports: [],
            metadata_issues: [],
            capabilities: []
        }
    }
    
    # Build final result
    {
        compliant: (($validation.missing_exports | length) == 0 and ($validation.metadata_issues | length) == 0 and $validation.success),
        errors: $validation.errors,
        warnings: [],
        missing_exports: $validation.missing_exports,
        metadata_issues: $validation.metadata_issues,
        capabilities: $validation.capabilities
    }
}

# Generate service module template - simplified version
export def generate-service-template [
    service_name: string,
    --type: string = "generated",
    --with-mock = true,
    --with-completions = true
]: nothing -> string {
    let lines = [
        $"# AWS ($service_name) Service Module",
        $"# Auto-generated service module template for ($service_name)",
        "",
        "# Service metadata",
        "export def get-service-metadata []: nothing -> record {",
        "    {",
        $"        name: \"($service_name)\",",
        $"        description: \"AWS ($service_name) service\",",
        "        version: \"1.0.0\",",
        $"        aws_service_id: \"($service_name)\",",
        $"        generated: ($type == (char dq)generated(char dq)),",
        "        generated_at: (date now),",
        "        generator_version: \"1.0.0\",",
        $"        type: \"($type)\",",
        "        capabilities: [\"list_operations\", \"parameter_validation\"],",
        "        requires_auth: true,",
        $"        supports_mock: ($with_mock),",
        "        operations_count: 0,",
        "        last_updated: (date now),",
        "        dependencies: []",
        "    }",
        "}",
        "",
        "# Required interface functions",
        "export def get-operations []: nothing -> list<record> { [] }",
        "export def list-operation-names []: nothing -> list<string> { [] }",
        "export def has-operation [operation_name: string]: nothing -> bool { false }",
        "export def get-operation-metadata [operation_name: string]: nothing -> record { {} }",
        "export def validate-operation-params [operation_name: string, params: record]: nothing -> record { {valid: true, errors: [], warnings: []} }",
        "export def get-completions [operation_name: string, param_name: string, context: record]: nothing -> list<string> { [] }",
        "export def execute-operation [operation_name: string, params: record]: nothing -> any { {mock: true} }",
        "export def get-mock-response [operation_name: string, params: record]: nothing -> any { {mock: true, service: \\\"test\\\"} }",
        "export def warm-completions []: nothing -> nothing { }"
    ]
    
    $lines | str join "\n"
}

# Create service module contract validator
export def create-contract-validator [service_name: string]: nothing -> string {
    let lines = [
        $"# Contract validator for ($service_name) service module",
        "# This validates that the service module implements the required interface",
        "",
        "use service_interface.nu",
        "",
        $"export def validate-($service_name)-module []: nothing -> record {",
        $"    let module_path = \"../services/($service_name).nu\"",
        "    service_interface validate-service-module $module_path",
        "}",
        "",
        $"export def test-($service_name)-interface []: nothing -> nothing {",
        $"    let validation = validate-($service_name)-module",
        "    ",
        "    if $validation.compliant {",
        $"        print \"✅ ($service_name) module interface is compliant\"",
        "    } else {",
        $"        print \"❌ ($service_name) module interface has issues:\"",
        "        if ($validation.missing_exports | length) > 0 {",
        "            print \"  Missing exports: \" + ($validation.missing_exports | str join \", \")",
        "        }",
        "        if ($validation.metadata_issues | length) > 0 {",
        "            print \"  Metadata issues: \" + ($validation.metadata_issues | str join \", \")",
        "        }",
        "        if ($validation.errors | length) > 0 {",
        "            print \"  Errors: \" + ($validation.errors | str join \", \")",
        "        }",
        "    }",
        "}"
    ]
    
    $lines | str join "\n"
}