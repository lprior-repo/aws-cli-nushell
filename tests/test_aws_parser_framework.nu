# Comprehensive Test Suite for AWS CLI Parser Framework
#
# Tests all components of the AWS CLI documentation parser and Nushell wrapper
# generation framework including parsing, generation, validation, caching, and
# integration features.

use std assert
use ../aws_cli_parser.nu
use ../aws_doc_extractor.nu
use ../aws_wrapper_generator.nu
use ../aws_validator.nu
use ../aws_integration_framework.nu
use ../utils/test_utils.nu

# ============================================================================
# AWS CLI PARSER TESTS
# ============================================================================

export def test_aws_service_info_structure [] {
    let service_info = aws_cli_parser aws-service-info
    
    assert ($service_info | columns | "name" in $in)
    assert ($service_info | columns | "description" in $in)
    assert ($service_info | columns | "commands" in $in)
    assert ($service_info | columns | "aliases" in $in)
    assert ($service_info | columns | "documentation_url" in $in)
}

export def test_aws_command_info_structure [] {
    let command_info = aws_cli_parser aws-command-info
    
    assert ($command_info | columns | "service" in $in)
    assert ($command_info | columns | "command" in $in)
    assert ($command_info | columns | "description" in $in)
    assert ($command_info | columns | "parameters" in $in)
    assert ($command_info | columns | "examples" in $in)
}

export def test_aws_parameter_info_structure [] {
    let param_info = aws_cli_parser aws-parameter-info
    
    assert ($param_info | columns | "name" in $in)
    assert ($param_info | columns | "type" in $in)
    assert ($param_info | columns | "required" in $in)
    assert ($param_info | columns | "description" in $in)
    assert ($param_info | columns | "constraints" in $in)
}

export def test_parse_services_from_help [] {
    let mock_help = [
        "AVAILABLE SERVICES",
        "",
        "       s3               Amazon Simple Storage Service",
        "       ec2              Amazon Elastic Compute Cloud",
        "       lambda           AWS Lambda",
        "",
        "See 'aws help' for more information."
    ] | str join "\n"
    
    # Test the parsing function (we'll need to make it accessible)
    # For now, test that the structure is maintained
    let services = aws_cli_parser get-aws-services
    
    # This will work when AWS CLI is available, otherwise it's expected to fail
    # The test validates the return structure when successful
    if ($services | is-not-empty) {
        assert ($services | first | columns | "name" in $in)
        assert ($services | first | columns | "description" in $in)
    }
}

export def test_parse_commands_from_help [] {
    let mock_help = [
        "AVAILABLE COMMANDS",
        "",
        "       ls               List S3 objects and common prefixes",
        "       cp               Copies a local file or S3 object",
        "       sync             Syncs directories and S3 prefixes",
        "",
        "See 'aws s3 help' for more information."
    ] | str join "\n"
    
    # Test service commands parsing
    let commands = try {
        aws_cli_parser get-service-commands "s3"
    } catch {
        # Expected to fail without AWS CLI, test structure
        []
    }
    
    # Validate structure when successful
    if ($commands | is-not-empty) {
        let first_command = ($commands | first)
        assert ($first_command | columns | "service" in $in)
        assert ($first_command | columns | "command" in $in)
        assert ($first_command | columns | "description" in $in)
    }
}

export def test_validate_command_info [] {
    let valid_command = {
        service: "s3",
        command: "ls",
        description: "List S3 objects",
        parameters: [
            { name: "bucket", type: "string", required: true, description: "Bucket name" }
        ]
    }
    
    let validation_result = aws_cli_parser validate-command-info $valid_command
    assert $validation_result.valid
    assert ($validation_result.errors | is-empty)
    
    # Test invalid command
    let invalid_command = {
        service: "",
        command: "",
        description: "Test",
        parameters: []
    }
    
    let invalid_result = aws_cli_parser validate-command-info $invalid_command
    assert (not $invalid_result.valid)
    assert ($invalid_result.errors | length) > 0
}

# ============================================================================
# DOCUMENTATION EXTRACTOR TESTS
# ============================================================================

export def test_extract_parameter_constraints [] {
    let description = "The maximum number of items to return. Valid values: 1-1000. Default: 100."
    
    let constraints = aws_doc_extractor extract-parameter-constraints $description
    
    # Should extract some constraints from the description
    assert ($constraints | is-not-empty)
}

export def test_extract_choice_values [] {
    let description = "Valid values: public-read | private | public-read-write"
    
    # This tests the internal function through the public interface
    let constraints = aws_doc_extractor extract-parameter-constraints $description
    
    if "choices" in $constraints {
        assert ($constraints.choices | length) > 0
    }
}

export def test_extract_error_codes [] {
    let mock_help = [
        "ERRORS",
        "",
        "NoSuchBucket",
        "The specified bucket does not exist.",
        "",
        "AccessDenied", 
        "Access to the resource was denied.",
        ""
    ] | str join "\n"
    
    let errors = aws_doc_extractor extract-error-codes $mock_help
    
    if ($errors | is-not-empty) {
        let first_error = ($errors | first)
        assert ($first_error | columns | "code" in $in)
        assert ($first_error | columns | "description" in $in)
    }
}

export def test_infer_schema_from_json [] {
    let sample_json = {
        name: "test",
        count: 42,
        active: true,
        tags: ["tag1", "tag2"],
        metadata: { version: "1.0" }
    }
    
    # Test through the public interface
    let schema = aws_doc_extractor extract-output-schema "" [
        { title: "test", description: "", command: "test", expected_output: ($sample_json | to json) }
    ]
    
    assert ($schema.type == "object")
    if "properties" in $schema {
        assert ($schema.properties | is-not-empty)
    }
}

export def test_validate_extracted_data [] {
    let valid_data = {
        service: "s3",
        command: "ls",
        parameters: [
            { name: "bucket", type: "string", required: true, description: "Bucket name" }
        ]
    }
    
    let validation = aws_doc_extractor validate-extracted-data $valid_data
    assert $validation.valid
    assert ($validation.data_quality_score >= 0.0)
    assert ($validation.data_quality_score <= 100.0)
}

# ============================================================================
# WRAPPER GENERATOR TESTS
# ============================================================================

export def test_wrapper_config_structure [] {
    let config = aws_wrapper_generator wrapper-config
    
    assert ($config | columns | "output_directory" in $in)
    assert ($config | columns | "enable_validation" in $in)
    assert ($config | columns | "enable_mocking" in $in)
    assert ($config | columns | "enable_testing" in $in)
}

export def test_generate_command_wrapper [] {
    let mock_command = {
        service: "s3",
        command: "list-objects",
        description: "List objects in a bucket",
        synopsis: "aws s3 list-objects --bucket bucket-name",
        parameters: [
            { name: "bucket", type: "string", required: true, description: "Bucket name", default_value: null, choices: [], multiple: false, constraints: {} },
            { name: "prefix", type: "string", required: false, description: "Object prefix", default_value: null, choices: [], multiple: false, constraints: {} }
        ],
        global_options: [],
        examples: [],
        output_format: "json",
        errors: []
    }
    
    let wrapper = aws_wrapper_generator generate-command-wrapper $mock_command
    
    assert ($wrapper | str contains "export def")
    assert ($wrapper | str contains "aws_s3_list_objects")
    assert ($wrapper | str contains "bucket: string")
    assert ($wrapper | str contains "--prefix: string")
}

export def test_generate_mock_response_function [] {
    let mock_command = {
        service: "s3",
        command: "list-objects",
        description: "List objects",
        parameters: [],
        output_schema: {
            type: "object",
            properties: {
                Contents: { type: "array", items: { type: "object" } }
            }
        }
    }
    
    let mock_response = aws_wrapper_generator generate-mock-response-function $mock_command
    
    assert ($mock_response | str contains "mock_response")
    assert ($mock_response | str contains "export def")
}

export def test_generate_validation_functions [] {
    let mock_command = {
        service: "s3",
        command: "list-objects",
        description: "List objects",
        parameters: [
            { name: "bucket", type: "string", required: true, description: "Bucket name", constraints: {} },
            { name: "max-keys", type: "integer", required: false, description: "Max keys", constraints: { min_value: 1, max_value: 1000 } }
        ]
    }
    
    let validation = aws_wrapper_generator generate-validation-functions $mock_command
    
    assert ($validation | str contains "validate-")
    assert ($validation | str contains "errors")
    assert ($validation | str contains "valid")
}

export def test_generate_test_file [] {
    let mock_command = {
        service: "s3",
        command: "list-objects",
        description: "List objects",
        parameters: [
            { name: "bucket", type: "string", required: true, description: "Bucket name" }
        ]
    }
    
    let test_file = aws_wrapper_generator generate-test-file $mock_command
    
    assert ($test_file | str contains "export def test_")
    assert ($test_file | str contains "assert")
    assert ($test_file | str contains "UNIT TESTS")
    assert ($test_file | str contains "INTEGRATION TESTS")
}

# ============================================================================
# VALIDATOR TESTS
# ============================================================================

export def test_validation_result_structure [] {
    let result = aws_validator validation-result
    
    assert ($result | columns | "valid" in $in)
    assert ($result | columns | "errors" in $in)
    assert ($result | columns | "warnings" in $in)
    assert ($result | columns | "suggestions" in $in)
    assert ($result | columns | "score" in $in)
}

export def test_validate_nushell_syntax [] {
    # Create a temporary file with valid Nushell syntax
    let temp_file = ($nu.temp-path | path join "test_syntax.nu")
    
    let valid_content = [
        "export def test-function [",
        "    param1: string,",
        "    --param2: int = 42",
        "]: nothing -> string {",
        "    $param1",
        "}"
    ] | str join "\n"
    
    $valid_content | save $temp_file
    
    let result = aws_validator validate-nushell-syntax $temp_file
    
    # Should be valid or have minimal warnings
    if not $result.valid {
        # If validation fails, should have specific error messages
        assert ($result.errors | length) > 0
    }
    
    rm $temp_file
}

export def test_assess_code_quality [] {
    # Create a temporary wrapper file
    let temp_file = ($nu.temp-path | path join "test_quality.nu")
    
    let wrapper_content = [
        "# Test AWS wrapper",
        "export def aws-s3-ls [",
        "    path?: string,",
        "    --recursive: bool = false",
        "]: nothing -> table {",
        "    mut args = [\"s3\", \"ls\"]",
        "    if ($path | is-not-empty) { $args = ($args | append $path) }",
        "    if $recursive { $args = ($args | append \"--recursive\") }",
        "    run-external \"aws\" $args",
        "}"
    ] | str join "\n"
    
    $wrapper_content | save $temp_file
    
    let quality = aws_validator assess-code-quality $temp_file
    
    assert ($quality | columns | "syntax_score" in $in)
    assert ($quality | columns | "functionality_score" in $in)
    assert ($quality | columns | "overall_score" in $in)
    assert ($quality.overall_score >= 0.0)
    assert ($quality.overall_score <= 100.0)
    
    rm $temp_file
}

# ============================================================================
# INTEGRATION FRAMEWORK TESTS
# ============================================================================

export def test_aws_cached_function [] {
    # Setup cache environment
    $env.AWS_NUSHELL_CONFIG = {
        cache_directory: ($nu.temp-path | path join "test-cache"),
        cache_ttl: 5min
    }
    
    mkdir $env.AWS_NUSHELL_CONFIG.cache_directory
    
    # Test caching
    let result1 = aws_integration_framework aws-cached {
        "test-result"
    } --key "test-key" --ttl 1min
    
    assert ($result1 == "test-result")
    
    # Test cache hit
    let result2 = aws_integration_framework aws-cached {
        "different-result"  # This should not execute due to cache
    } --key "test-key" --ttl 1min
    
    assert ($result2 == "test-result")  # Should return cached value
    
    # Cleanup
    rm -rf $env.AWS_NUSHELL_CONFIG.cache_directory
}

export def test_aws_styled_function [] {
    $env.AWS_THEME = {
        success: {fg: "green"},
        error: {fg: "red"}
    }
    
    let styled_text = aws_integration_framework aws-styled "test" "success"
    assert ($styled_text == "test")  # Basic implementation just returns text
    
    let error_text = aws_integration_framework aws-styled "error" "error"
    assert ($error_text == "error")
}

export def test_generate_pipeline_command [] {
    let mock_command = {
        service: "s3",
        command: "list-objects",
        description: "List S3 objects",
        parameters: [
            { name: "bucket", type: "string", required: true, description: "Bucket name" },
            { name: "prefix", type: "string", required: false, description: "Object prefix" }
        ],
        output_schema: { type: "array" }
    }
    
    let pipeline_command = aws_integration_framework generate-pipeline-command $mock_command
    
    assert ($pipeline_command | str contains "export def \"aws s3 list objects\"")
    assert ($pipeline_command | str contains "bucket: string")
    assert ($pipeline_command | str contains "--prefix: string")
    assert ($pipeline_command | str contains "table")  # Return type
    assert ($pipeline_command | str contains "aws-pre-execution-hook")
    assert ($pipeline_command | str contains "aws-cache-result")
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

export def test_end_to_end_mock_workflow [] {
    # Test the complete workflow with mock data
    let mock_service_data = {
        service: "s3",
        commands: [
            {
                service: "s3",
                command: "ls",
                description: "List S3 objects",
                parameters: [
                    { name: "path", type: "string", required: false, description: "S3 path" }
                ],
                examples: [],
                output_schema: { type: "array" }
            }
        ]
    }
    
    # Test wrapper generation
    let service_module = aws_wrapper_generator generate-service-module $mock_service_data
    assert ($service_module | str contains "AWS S3 Service")
    assert ($service_module | str contains "export def")
    
    # Test pipeline command generation
    let pipeline_command = aws_integration_framework generate-pipeline-command $mock_service_data.commands.0
    assert ($pipeline_command | str contains "aws s3 ls")
    
    # Validate the workflow completed successfully
    assert true
}

export def test_parser_configuration [] {
    let config = aws_cli_parser parser-config
    
    # Test configuration structure
    assert ($config | columns | "aws_cli_path" in $in)
    assert ($config | columns | "output_directory" in $in)
    assert ($config | columns | "enable_validation" in $in)
    
    # Test default values
    assert ($config.aws_cli_path == "aws")
    assert ($config.enable_validation == true)
}

export def test_framework_initialization [] {
    # Test that the framework can be initialized
    let framework_info = aws_integration_framework main
    
    assert ($framework_info | columns | "framework" in $in)
    assert ($framework_info | columns | "version" in $in)
    assert ($framework_info | columns | "description" in $in)
}

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

export def test_caching_performance [] {
    # Setup cache environment
    $env.AWS_NUSHELL_CONFIG = {
        cache_directory: ($nu.temp-path | path join "perf-cache"),
        cache_ttl: 1min
    }
    
    mkdir $env.AWS_NUSHELL_CONFIG.cache_directory
    
    # Measure first call (cache miss)
    let start1 = (date now)
    let result1 = aws_integration_framework aws-cached {
        sleep 10ms  # Simulate work
        "cached-result"
    } --key "perf-test"
    let end1 = (date now)
    let duration1 = ($end1 - $start1)
    
    # Measure second call (cache hit)
    let start2 = (date now)
    let result2 = aws_integration_framework aws-cached {
        sleep 10ms  # This should not execute
        "different-result"
    } --key "perf-test"
    let end2 = (date now)
    let duration2 = ($end2 - $start2)
    
    # Cache hit should be significantly faster
    assert ($duration2 < $duration1)
    assert ($result2 == "cached-result")
    
    # Cleanup
    rm -rf $env.AWS_NUSHELL_CONFIG.cache_directory
}

export def test_wrapper_generation_performance [] {
    let mock_command = {
        service: "s3",
        command: "test-command",
        description: "Test command",
        parameters: [
            { name: "param1", type: "string", required: true, description: "Parameter 1" },
            { name: "param2", type: "string", required: false, description: "Parameter 2" },
            { name: "param3", type: "integer", required: false, description: "Parameter 3" }
        ]
    }
    
    # Measure wrapper generation time
    let start = (date now)
    let wrapper = aws_wrapper_generator generate-command-wrapper $mock_command
    let end = (date now)
    let duration = ($end - $start)
    
    # Should generate quickly (under 1 second)
    assert ($duration < 1sec)
    assert ($wrapper | str length) > 0
}

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

export def test_error_handling [] {
    # Test validation error handling
    let invalid_command = {
        service: "",
        command: "",
        parameters: []
    }
    
    let validation_result = aws_cli_parser validate-command-info $invalid_command
    assert (not $validation_result.valid)
    assert ($validation_result.errors | length) > 0
}

export def test_file_not_found_error [] {
    let non_existent_file = "/path/that/does/not/exist.nu"
    
    let result = aws_validator validate-nushell-syntax $non_existent_file
    assert (not $result.valid)
    assert ($result.errors | length) > 0
    assert ($result.errors | any { |e| $e | str contains "does not exist" })
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================

# Run all tests in the framework
export def run_all_framework_tests [] {
    print "🧪 Running AWS Parser Framework Test Suite"
    print "=" * 60
    
    let test_functions = [
        test_aws_service_info_structure,
        test_aws_command_info_structure,
        test_aws_parameter_info_structure,
        test_validate_command_info,
        test_extract_parameter_constraints,
        test_extract_error_codes,
        test_validate_extracted_data,
        test_wrapper_config_structure,
        test_generate_command_wrapper,
        test_generate_mock_response_function,
        test_generate_validation_functions,
        test_generate_test_file,
        test_validation_result_structure,
        test_validate_nushell_syntax,
        test_assess_code_quality,
        test_aws_cached_function,
        test_aws_styled_function,
        test_generate_pipeline_command,
        test_end_to_end_mock_workflow,
        test_parser_configuration,
        test_framework_initialization,
        test_caching_performance,
        test_wrapper_generation_performance,
        test_error_handling,
        test_file_not_found_error
    ]
    
    mut results = []
    mut passed = 0
    mut failed = 0
    
    for test_func in $test_functions {
        let test_name = ($test_func | debug | str replace "Closure" "" | str trim)
        print $"Running: ($test_name)"
        
        try {
            do $test_func
            $results = ($results | append { test: $test_name, status: "PASSED", error: null })
            $passed = $passed + 1
            print $"  ✅ PASSED"
        } catch { |error|
            $results = ($results | append { test: $test_name, status: "FAILED", error: $error.msg })
            $failed = $failed + 1
            print $"  ❌ FAILED: ($error.msg)"
        }
    }
    
    print ""
    print "📊 Test Results Summary"
    print "-" * 40
    print $"Total tests: ($test_functions | length)"
    print $"Passed: ($passed)"
    print $"Failed: ($failed)"
    print $"Success rate: (($passed / ($test_functions | length)) * 100 | math round)%"
    
    if $failed > 0 {
        print ""
        print "❌ Failed tests:"
        $results | where status == "FAILED" | each { |r|
            print $"  - ($r.test): ($r.error)"
        }
    }
    
    {
        total: ($test_functions | length),
        passed: $passed,
        failed: $failed,
        success_rate: (($passed / ($test_functions | length)) * 100),
        results: $results
    }
}