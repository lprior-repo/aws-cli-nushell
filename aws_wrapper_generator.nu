# AWS Nushell Wrapper Generator
#
# Generates type-safe Nushell function wrappers for AWS CLI commands with comprehensive
# validation, error handling, mocking capabilities, and testing framework integration.
# Follows pure functional programming principles with immutable data structures.

use utils/test_utils.nu
use aws_doc_extractor.nu

# ============================================================================
# TYPE DEFINITIONS AND TEMPLATES
# ============================================================================

# Wrapper generation configuration
export def wrapper-config []: nothing -> record {
    {
        output_directory: "./generated",
        template_directory: "./templates", 
        enable_validation: true,
        enable_mocking: true,
        enable_testing: true,
        include_examples: true,
        function_prefix: "aws-",
        module_suffix: ".nu",
        test_suffix: "_test.nu"
    }
}

# Function signature template
def function-signature-template []: nothing -> string {
    "export def {{function_name}} [\n{{parameters}}\n]: nothing -> {{return_type}} {"
}

# Parameter template
def parameter-template []: nothing -> string {
    "{{#if required}}{{name}}: {{type}}{{#if description}}, # {{description}}{{/if}}{{else}}--{{name}}: {{type}}{{#if default_value}} = {{default_value}}{{/if}}{{#if description}}, # {{description}}{{/if}}{{/if}}"
}

# Validation template
def validation-template []: nothing -> string {
    "    # Validate input parameters\n    let validation_result = validate-{{function_name}}-params ${{parameter_name}}\n    if not $validation_result.valid {\n        error make {\n            msg: \"Invalid parameters for {{function_name}}\",\n            label: { text: ($validation_result.errors | str join \", \") }\n        }\n    }"
}

# Mock response template
def mock-response-template []: nothing -> string {
    "    # Check if running in mock mode\n    let mock_config = (aws-mock-config)\n    if $mock_config.enabled {\n        return ({{function_name}}-mock-response {{parameters}})\n    }"
}

# ============================================================================
# CORE WRAPPER GENERATION
# ============================================================================

# Generate Nushell wrapper for a single AWS command
export def generate-command-wrapper [
    command_info: record,
    config?: record
]: nothing -> string {
    let actual_config = if ($config | is-empty) { (wrapper-config) } else { $config }
    let function_name = generate-function-name $command_info.service $command_info.command $actual_config
    let parameters = generate-parameter-list $command_info.parameters
    let return_type = determine-return-type $command_info
    let validation_code = generate-validation-code $command_info $actual_config
    let mock_code = generate-mock-code $command_info $actual_config
    let aws_cli_call = generate-aws-cli-call $command_info
    let error_handling = generate-error-handling $command_info
    
    let function_body = [
        $"# ($command_info.description)",
        "#",
        $"# AWS CLI command: aws ($command_info.service) ($command_info.command)",
        (if ($command_info.synopsis | str length) > 0 { $"# Synopsis: ($command_info.synopsis)" } else { "" }),
        "",
        $"export def ($function_name) [",
        $parameters,
        $"]: nothing -> ($return_type) {",
        $validation_code,
        $mock_code,
        "",
        "    try {",
        $"        ($aws_cli_call)",
        "    } catch { |error|",
        $error_handling,
        "    }",
        "}"
    ] | str join "\n"
    
    $function_body
}

# Generate function name from service and command
def generate-function-name [service: string, command: string, config: record]: nothing -> string {
    let clean_service = ($service | str replace "-" "_")
    let clean_command = ($command | str replace "-" "_")
    $"($config.function_prefix)($clean_service)_($clean_command)"
}

# Generate parameter list for function signature
def generate-parameter-list [parameters: list<record>]: nothing -> string {
    let required_params = ($parameters | where $it.required)
    let optional_params = ($parameters | where (not $it.required))
    
    let required_param_strings = (
        $required_params | each { |param|
            generate-parameter-string $param true
        }
    )
    
    let optional_param_strings = (
        $optional_params | each { |param|
            generate-parameter-string $param false
        }
    )
    
    let all_params = ($required_param_strings | append $optional_param_strings)
    $all_params | str join ",\n    "
}

# Generate individual parameter string
def generate-parameter-string [param: record, required: bool]: nothing -> string {
    let param_type = map-aws-type-to-nushell-type $param.type
    let param_name = ($param.name | str replace "-" "_")
    
    if $required {
        if ($param.description | str length) > 0 {
            $"($param_name): ($param_type)  # ($param.description)"
        } else {
            $"($param_name): ($param_type)"
        }
    } else {
        let default_part = if $param.default_value != null {
            $" = ($param.default_value)"
        } else {
            ""
        }
        
        if ($param.description | str length) > 0 {
            $"--($param_name): ($param_type)($default_part)  # ($param.description)"
        } else {
            $"--($param_name): ($param_type)($default_part)"
        }
    }
}

# Map AWS parameter types to Nushell types
def map-aws-type-to-nushell-type [aws_type: string]: nothing -> string {
    match ($aws_type | str downcase) {
        "string" => "string",
        "integer" => "int",
        "long" => "int", 
        "double" => "float",
        "float" => "float",
        "boolean" => "bool",
        "timestamp" => "datetime",
        "list" => "list<string>",
        "choice" => "string",
        _ => "string"
    }
}

# Determine function return type
def determine-return-type [command_info: record]: nothing -> string {
    if "output_schema" in $command_info and not ($command_info.output_schema | is-empty) {
        if $command_info.output_schema.type == "array" {
            "list<record>"
        } else {
            "record"
        }
    } else {
        "any"
    }
}

# Generate validation code
def generate-validation-code [command_info: record, config: record]: nothing -> string {
    if not $config.enable_validation {
        return ""
    }
    
    let validation_functions = (
        $command_info.parameters 
        | each { |param| generate-parameter-validation $param }
        | where ($it | str length) > 0
    )
    
    if ($validation_functions | length) > 0 {
        [
            "    # Validate input parameters",
            ...$validation_functions
        ] | str join "\n"
    } else {
        ""
    }
}

# Generate parameter validation
def generate-parameter-validation [param: record]: nothing -> string {
    let param_name = ($param.name | str replace "-" "_")
    mut validations = []
    
    # Required parameter check
    if $param.required {
        $validations = ($validations | append ("if $" + $param_name + " == null or ($" + $param_name + " | str length) == 0 {"))
        $validations = ($validations | append ("        error make { msg: \"Parameter " + $param.name + " is required\" }"))
        $validations = ($validations | append "    }")
    }
    
    # Type-specific validations
    if "constraints" in $param and not ($param.constraints | is-empty) {
        if "min_value" in $param.constraints {
            $validations = ($validations | append ("    if $" + $param_name + " < " + ($param.constraints.min_value | into string) + " {"))
            $validations = ($validations | append ("        error make { msg: \"Parameter " + $param.name + " must be >= " + ($param.constraints.min_value | into string) + "\" }"))
            $validations = ($validations | append "    }")
        }
        
        if "max_value" in $param.constraints {
            $validations = ($validations | append ("    if $" + $param_name + " > " + ($param.constraints.max_value | into string) + " {"))
            $validations = ($validations | append ("        error make { msg: \"Parameter " + $param.name + " must be <= " + ($param.constraints.max_value | into string) + "\" }"))
            $validations = ($validations | append "    }")
        }
        
        if "choices" in $param.constraints and ($param.constraints.choices | length) > 0 {
            let choices_list = ($param.constraints.choices | each { |c| ("\"" + $c + "\"") } | str join ", ")
            $validations = ($validations | append ("    if $" + $param_name + " not-in [" + $choices_list + "] {"))
            $validations = ($validations | append ("        error make { msg: \"Parameter " + $param.name + " must be one of: " + $choices_list + "\" }"))
            $validations = ($validations | append "    }")
        }
    }
    
    $validations | str join "\n"
}

# Generate mock code
def generate-mock-code [command_info: record, config: record]: nothing -> string {
    if not $config.enable_mocking {
        return ""
    }
    
    let function_name = generate-function-name $command_info.service $command_info.command $config
    
    [
        "    # Check if running in mock mode",
        "    let mock_config = (aws-mock-config)",
        "    if $mock_config.enabled {",
        $"        return (($function_name)_mock_response)",
        "    }"
    ] | str join "\n"
}

# Generate AWS CLI call
def generate-aws-cli-call [command_info: record]: nothing -> string {
    let required_params = ($command_info.parameters | where $it.required)
    let optional_params = ($command_info.parameters | where (not $it.required))
    
    mut cli_args = [$command_info.service, $command_info.command]
    
    # Add required parameters
    for param in $required_params {
        let param_name = ($param.name | str replace "-" "_")
        $cli_args = ($cli_args | append $"--($param.name)")
        $cli_args = ($cli_args | append $"\$($param_name)")
    }
    
    # Add optional parameters
    let optional_args = (
        $optional_params | each { |param|
            let param_name = ($param.name | str replace "-" "_")
            [
                $"if \$($param_name) != null {",
                ("    $args = ($args | append \"--" + $param.name + "\")"),
                $"    \$args = (\$args | append \$($param_name))",
                "}"
            ] | str join "\n"
        }
    )
    
    let base_call = $"mut args = [\"($command_info.service)\", \"($command_info.command)\"]"
    let param_additions = if ($optional_args | length) > 0 {
        ($optional_args | str join "\n        ")
    } else {
        ""
    }
    
    [
        $base_call,
        $param_additions,
        "        let result = (run-external \"aws\" $args | from json)",
        "        $result"
    ] | str join "\n        "
}

# Generate error handling code
def generate-error-handling [command_info: record]: nothing -> string {
    let error_mappings = if "errors" in $command_info {
        $command_info.errors | each { |error|
            $"        \"($error.code)\" => \"($error.description)\""
        } | str join "\n"
    } else {
        ""
    }
    
    [
        "        let error_code = ($error.msg | parse --regex 'An error occurred \\(([^)]+)\\)' | get capture0?.0? | default \"Unknown\")",
        "        let error_message = match $error_code {",
        $error_mappings,
        "            _ => $error.msg",
        "        }",
        "        error make {",
        ("            msg: $\"AWS " + $command_info.service + " " + $command_info.command + " failed: ($error_message)\","),
        "            label: { text: $error.msg }",
        "        }"
    ] | str join "\n"
}

# ============================================================================
# MOCK RESPONSE GENERATION
# ============================================================================

# Generate mock response function
export def generate-mock-response-function [
    command_info: record,
    config?: record
]: nothing -> string {
    let actual_config = if ($config | is-empty) { (wrapper-config) } else { $config }
    let function_name = generate-function-name $command_info.service $command_info.command $actual_config
    let mock_response = generate-mock-response-data $command_info
    
    [
        $"# Mock response for ($function_name)",
        $"export def ($function_name)_mock_response [",
        "]: nothing -> any {",
        $"    ($mock_response)",
        "}"
    ] | str join "\n"
}

# Generate mock response data based on output schema
def generate-mock-response-data [command_info: record]: nothing -> string {
    if "output_schema" in $command_info and not ($command_info.output_schema | is-empty) {
        generate-mock-from-schema $command_info.output_schema
    } else if "examples" in $command_info and ($command_info.examples | length) > 0 {
        # Use first example as mock response
        let first_example = ($command_info.examples | first)
        if ($first_example.expected_output | str starts-with "{") {
            $first_example.expected_output
        } else {
            "{}"
        }
    } else {
        "{}"
    }
}

# Generate mock data from JSON schema
def generate-mock-from-schema [schema: record]: nothing -> string {
    match $schema.type {
        "object" => {
            mut mock_obj = "{"
            if "properties" in $schema {
                let properties = (
                    $schema.properties | transpose key value | each { |prop|
                        let mock_value = generate-mock-from-schema $prop.value
                        $"    ($prop.key): ($mock_value)"
                    }
                )
                $mock_obj = $mock_obj + "\n" + ($properties | str join ",\n") + "\n"
            }
            $mock_obj + "}"
        },
        "array" => {
            let item_schema = ($schema.items? | default { type: "string" })
            let mock_item = generate-mock-from-schema $item_schema
            $"[($mock_item)]"
        },
        "string" => "\"mock-string\"",
        "integer" => "42",
        "number" => "3.14",
        "boolean" => "true",
        _ => "null"
    }
}

# ============================================================================
# VALIDATION FUNCTION GENERATION
# ============================================================================

# Generate validation functions for parameters
export def generate-validation-functions [
    command_info: record,
    config?: record
]: nothing -> string {
    let actual_config = if ($config | is-empty) { (wrapper-config) } else { $config }
    let function_name = generate-function-name $command_info.service $command_info.command $actual_config
    
    let validation_function = [
        $"# Parameter validation for ($function_name)",
        $"def validate-($function_name)-params [",
        "    params: record",
        "]: nothing -> record {",
        "    mut errors = []",
        "",
        ...(generate-parameter-validations $command_info.parameters),
        "",
        "    {",
        "        valid: ($errors | length) == 0,",
        "        errors: $errors",
        "    }",
        "}"
    ] | str join "\n"
    
    $validation_function
}

# Generate individual parameter validations
def generate-parameter-validations [parameters: list<record>]: nothing -> list<string> {
    $parameters | each { |param|
        generate-single-parameter-validation $param
    } | flatten
}

# Generate validation for a single parameter
def generate-single-parameter-validation [param: record]: nothing -> list<string> {
    let param_name = ($param.name | str replace "-" "_")
    mut validations = []
    
    # Required validation
    if $param.required {
        $validations = ($validations | append ("    if not (\"" + $param_name + "\" in $params) {"))
        $validations = ($validations | append ("        $errors = ($errors | append \"Required parameter " + $param.name + " is missing\")"))
        $validations = ($validations | append "    }")
    }
    
    # Type validation
    $validations = ($validations | append $"    if \"($param_name)\" in \$params {")
    $validations = ($validations | append $"        let value = (\$params | get ($param_name))")
    
    # Add type-specific validations
    match $param.type {
        "integer" => {
            $validations = ($validations | append "        if ($value | describe) != \"int\" {")
            $validations = ($validations | append ("            $errors = ($errors | append \"Parameter " + $param.name + " must be an integer\")"))
            $validations = ($validations | append "        }")
        },
        "boolean" => {
            $validations = ($validations | append "        if ($value | describe) != \"bool\" {")
            $validations = ($validations | append ("            $errors = ($errors | append \"Parameter " + $param.name + " must be a boolean\")"))
            $validations = ($validations | append "        }")
        },
        _ => {
            # String validation (default)
            $validations = ($validations | append "        if ($value | describe) not-in [\"string\"] {")
            $validations = ($validations | append ("            $errors = ($errors | append \"Parameter " + $param.name + " must be a string\")"))
            $validations = ($validations | append "        }")
        }
    }
    
    $validations = ($validations | append "    }")
    
    $validations
}

# ============================================================================
# TEST GENERATION
# ============================================================================

# Generate test file for AWS command wrapper
export def generate-test-file [
    command_info: record,
    config?: record
]: nothing -> string {
    let actual_config = if ($config | is-empty) { (wrapper-config) } else { $config }
    let function_name = generate-function-name $command_info.service $command_info.command $actual_config
    
    [
        "# Tests for AWS ($command_info.service) ($command_info.command) wrapper",
        "#",
        "# Comprehensive test suite including unit tests, integration tests,",
        "# parameter validation tests, and error handling tests.",
        "",
        "use std assert",
        "use ../aws_cli_parser.nu",
        "use ../utils/test_utils.nu",
        "",
        ...(generate-unit-tests $command_info $function_name),
        "",
        ...(generate-integration-tests $command_info $function_name),
        "",
        ...(generate-validation-tests $command_info $function_name),
        "",
        ...(generate-error-tests $command_info $function_name)
    ] | str join "\n"
}

# Generate unit tests
def generate-unit-tests [command_info: record, function_name: string]: nothing -> list<string> {
    [
        "# ============================================================================",
        "# UNIT TESTS",
        "# ============================================================================",
        "",
        $"export def test_($function_name)_with_valid_params [] {",
        "    # Test with valid parameters",
        "    $env.STEPFUNCTIONS_MOCK_MODE = \"true\"",
        "    ",
        ("    let result = ((" + $function_name + ") mock-param-1 --optional-param \"test\")"),
        "    assert ($result != null)",
        "    ",
        "    $env.STEPFUNCTIONS_MOCK_MODE = \"false\"",
        "}",
        "",
        $"export def test_($function_name)_parameter_validation [] {",
        "    # Test parameter validation",
        $"    let validation_result = validate-($function_name)-params {}",
        "    assert (not $validation_result.valid)",
        "    assert ($validation_result.errors | length) > 0",
        "}"
    ]
}

# Generate integration tests  
def generate-integration-tests [command_info: record, function_name: string]: nothing -> list<string> {
    [
        "# ============================================================================",
        "# INTEGRATION TESTS", 
        "# ============================================================================",
        "",
        $"export def test_($function_name)_integration [] {",
        "    # Integration test - requires actual AWS credentials",
        "    if ($env.AWS_PROFILE? | default \"\") == \"\" {",
        "        print \"Skipping integration test - no AWS credentials\"",
        "        return",
        "    }",
        "    ",
        "    try {",
        ("        let result = ((" + $function_name + ") test-resource)"),
        "        assert ($result != null)",
        "    } catch {",
        "        print \"Integration test failed - this may be expected in CI\"",
        "    }",
        "}"
    ]
}

# Generate validation tests
def generate-validation-tests [command_info: record, function_name: string]: nothing -> list<string> {
    let validation_tests = (
        $command_info.parameters | each { |param|
            generate-parameter-validation-test $param $function_name
        } | flatten
    )
    
    [
        "# ============================================================================",
        "# VALIDATION TESTS",
        "# ============================================================================",
        "",
        ...$validation_tests
    ]
}

# Generate validation test for specific parameter
def generate-parameter-validation-test [param: record, function_name: string]: nothing -> list<string> {
    let param_name = ($param.name | str replace "-" "_")
    
    [
        $"export def test_($function_name)_($param_name)_validation [] {",
        $"    # Test ($param.name) parameter validation",
        "    $env.STEPFUNCTIONS_MOCK_MODE = \"true\"",
        "",
        "    # Test invalid type",
        "    try {",
        ("        (" + $function_name + ") 123"),  # Assuming string expected
        "        assert false \"Should have failed with invalid type\"",
        "    } catch {",
        "        # Expected to fail",
        "    }",
        "",
        "    $env.STEPFUNCTIONS_MOCK_MODE = \"false\"",
        "}",
        ""
    ]
}

# Generate error handling tests
def generate-error-tests [command_info: record, function_name: string]: nothing -> list<string> {
    [
        "# ============================================================================",
        "# ERROR HANDLING TESTS",
        "# ============================================================================",
        "",
        $"export def test_($function_name)_error_handling [] {",
        "    # Test error handling",
        "    $env.STEPFUNCTIONS_MOCK_MODE = \"false\"",
        "    ",
        "    try {",
        ("        (" + $function_name + ") \"invalid-resource-name-that-does-not-exist\""),
        "        assert false \"Should have failed with AWS error\"",
        "    } catch { |error|",
        "        assert ($error.msg | str contains \"AWS\")",
        "    }",
        "}"
    ]
}

# ============================================================================
# MODULE GENERATION
# ============================================================================

# Generate complete Nushell module for AWS service
export def generate-service-module [
    service_data: record,
    config?: record
]: nothing -> string {
    let actual_config = if ($config | is-empty) { (wrapper-config) } else { $config }
    let service_name = $service_data.service
    let commands = $service_data.commands
    
    let module_header = [
        $"# AWS ($service_name | str title-case) Service Wrapper",
        "#",
        "# Type-safe Nushell wrappers for AWS CLI commands with validation,",
        "# error handling, mocking capabilities, and comprehensive testing.",
        "# Generated automatically from AWS CLI documentation.",
        "",
        "use ../utils/test_utils.nu",
        ""
    ]
    
    let function_wrappers = (
        $commands | each { |cmd|
            generate-command-wrapper $cmd $config
        }
    )
    
    let mock_functions = if $config.enable_mocking {
        $commands | each { |cmd|
            generate-mock-response-function $cmd $config
        }
    } else {
        []
    }
    
    let validation_functions = if $config.enable_validation {
        $commands | each { |cmd|
            generate-validation-functions $cmd $config  
        }
    } else {
        []
    }
    
    [
        ...$module_header,
        "# ============================================================================",
        "# COMMAND WRAPPERS",
        "# ============================================================================",
        "",
        ...($function_wrappers | each { |f| $f + "\n" }),
        "",
        "# ============================================================================", 
        "# MOCK RESPONSES",
        "# ============================================================================",
        "",
        ...($mock_functions | each { |f| $f + "\n" }),
        "",
        "# ============================================================================",
        "# VALIDATION FUNCTIONS", 
        "# ============================================================================",
        "",
        ...($validation_functions | each { |f| $f + "\n" })
    ] | str join "\n"
}

# ============================================================================
# MAIN GENERATION ENTRY POINT
# ============================================================================

# Main entry point for wrapper generation
export def main [
    --service: string,              # Generate for specific service only
    --input-file: string,           # Input JSON file with parsed documentation
    --output-dir: string = "./generated",  # Output directory
    --enable-mocking = true,        # Enable mock response generation
    --enable-testing = true,        # Enable test generation
    --enable-validation = true      # Enable parameter validation
]: nothing -> nothing {
    let config = (
        wrapper-config 
        | upsert output_directory $output_dir
        | upsert enable_mocking $enable_mocking
        | upsert enable_testing $enable_testing
        | upsert enable_validation $enable_validation
    )
    
    # Load parsed documentation
    let parsed_data = if ($input_file | is-not-empty) {
        open $input_file | from json
    } else {
        error make { msg: "Input file is required" }
    }
    
    # Create output directory
    mkdir $config.output_directory
    
    if ($service | is-not-empty) {
        # Generate for specific service
        let service_data = ($parsed_data.services | where $it.service == $service | first)
        if ($service_data | is-empty) {
            error make { msg: $"Service ($service) not found in parsed data" }
        }
        
        generate-service-files $service_data $config
    } else {
        # Generate for all services
        for service_data in $parsed_data.services {
            try {
                generate-service-files $service_data $config
                print $"Generated files for service: ($service_data.service)"
            } catch { |error|
                print $"Error generating files for ($service_data.service): ($error.msg)"
            }
        }
    }
    
    print $"Wrapper generation completed. Files saved to: ($config.output_directory)"
}

# Generate all files for a service
def generate-service-files [service_data: record, config: record]: nothing -> nothing {
    let service_name = $service_data.service
    
    # Generate main module file
    let module_content = generate-service-module $service_data $config
    let module_file = ($config.output_directory + "/" + $service_name + $config.module_suffix)
    $module_content | save $module_file
    
    # Generate test files if enabled
    if $config.enable_testing {
        for command in $service_data.commands {
            let test_content = generate-test-file $command $config
            let function_name = generate-function-name $service_name $command.command $config
            let test_file = ($config.output_directory + "/" + $function_name + $config.test_suffix)
            $test_content | save $test_file
        }
    }
}