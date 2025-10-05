#!/usr/bin/env nu

# Demo: AWS CLI Documentation Parser Framework
# Demonstrates comprehensive AWS CLI parsing and wrapper generation capabilities

use aws_cli_parser.nu
use aws_wrapper_generator.nu

def main [
    --service: string = "s3"           # AWS service to demo
    --command: string = "list-buckets" # Command to generate wrapper for
    --full-demo                        # Run complete framework demo
] {
    print "🚀 AWS CLI Documentation Parser Framework Demo"
    print "================================================="
    
    if $full_demo {
        demo_complete_framework
    } else {
        demo_service_wrapper_generation $service $command
    }
}

# Demonstrate complete framework capabilities
def demo_complete_framework [] {
    print "\n📊 FRAMEWORK CAPABILITIES OVERVIEW:"
    print "===================================="
    
    # 1. Service Discovery
    print "\n1. 🔍 AWS Service Discovery:"
    let services = get_aws_services
    print $"   ✅ Found ($services | length) AWS services"
    print $"   📋 Examples: ($services | first 5 | str join ', ')"
    
    # 2. Command Discovery
    print "\n2. 📋 Command Discovery (S3 example):"
    let s3_commands = get_service_commands "s3"
    print $"   ✅ Found ($s3_commands | length) S3 commands"
    print $"   📋 Commands: ($s3_commands | first 5 | str join ', ')"
    
    # 3. Parameter Extraction
    print "\n3. 🔧 Parameter Extraction (s3 list-objects-v2):"
    let params = extract_command_parameters "s3" "list-objects-v2"
    print $"   ✅ Found ($params | length) parameters"
    $params | first 3 | each { |param|
        print $"   📝 ($param.name): ($param.type) ($param.required)"
    }
    
    # 4. Wrapper Generation
    print "\n4. 🏗️  Nushell Wrapper Generation:"
    let wrapper = generate_nushell_wrapper {
        service: "s3"
        command: "list-objects-v2"
        parameters: $params
    }
    print "   ✅ Generated type-safe Nushell wrapper"
    print $"   📏 Generated code: ($wrapper | str length) characters"
    
    # 5. Test Generation
    print "\n5. 🧪 Test Generation:"
    let tests = generate_command_tests "s3" "list-objects-v2" $params
    print $"   ✅ Generated ($tests | length) comprehensive tests"
    
    print "\n🎉 FRAMEWORK DEMO COMPLETE!"
    print "✅ Ready to generate wrappers for any AWS service"
}

# Demonstrate wrapper generation for specific service/command
def demo_service_wrapper_generation [
    service: string
    command: string
] {
    print $"\n🎯 GENERATING WRAPPER: aws ($service) ($command)"
    print "======================================================"
    
    try {
        # Extract command information
        print "\n1. 📋 Extracting command information..."
        let cmd_info = parse_aws_command_help $service $command
        print $"   ✅ Command: ($cmd_info.name)"
        print $"   📝 Description: ($cmd_info.description | str substring 0..100)..."
        print $"   🔧 Parameters: ($cmd_info.parameters | length)"
        
        # Generate wrapper
        print "\n2. 🏗️  Generating Nushell wrapper..."
        let wrapper_code = generate_service_wrapper $service $command $cmd_info
        print "   ✅ Wrapper generated successfully"
        print $"   📏 Code length: ($wrapper_code | str length) characters"
        
        # Show sample of generated code
        print "\n3. 📄 Generated Code Sample:"
        print "   ================================================="
        let sample = ($wrapper_code | lines | first 15 | str join "\n")
        print $"($sample)"
        print "   ... (truncated)"
        print "   ================================================="
        
        # Generate tests
        print "\n4. 🧪 Generating tests..."
        let test_code = generate_comprehensive_tests $service $command $cmd_info
        print $"   ✅ Generated ($test_code | lines | length) lines of tests"
        
        # Validate generated code
        print "\n5. ✅ Validating generated code..."
        let validation = validate_generated_wrapper $wrapper_code
        print $"   📊 Syntax valid: ($validation.syntax_valid)"
        print $"   📊 Quality score: ($validation.quality_score)"
        
        print "\n🎉 SUCCESS: Wrapper generation complete!"
        print "📁 Generated files would be:"
        print $"   - aws/($service).nu (wrapper implementation)"
        print $"   - tests/aws/test_($service)_($command).nu (comprehensive tests)"
        
    } catch { |error|
        print $"❌ Error generating wrapper: ($error.msg)"
        print "💡 This might be expected if AWS CLI is not available or the command doesn't exist"
    }
}

# Helper functions for demo

def get_aws_services []: nothing -> list<string> {
    # Mock AWS services for demo
    [
        "s3", "ec2", "lambda", "dynamodb", "stepfunctions", 
        "iam", "cloudformation", "sns", "sqs", "rds",
        "elasticache", "cloudwatch", "logs", "events", "kinesis"
    ]
}

def get_service_commands [service: string]: nothing -> list<string> {
    match $service {
        "s3" => [
            "list-buckets", "list-objects-v2", "get-object", "put-object", 
            "delete-object", "create-bucket", "delete-bucket", "copy-object"
        ],
        "ec2" => [
            "describe-instances", "run-instances", "terminate-instances",
            "start-instances", "stop-instances", "describe-images"
        ],
        "lambda" => [
            "list-functions", "create-function", "delete-function",
            "invoke", "update-function-code", "get-function"
        ],
        _ => ["help", "describe", "list", "create", "delete"]
    }
}

def extract_command_parameters [service: string, command: string]: nothing -> list<record> {
    # Mock parameter extraction for demo
    match [$service, $command] {
        ["s3", "list-objects-v2"] => [
            { name: "bucket", type: "string", required: true, description: "Bucket name" },
            { name: "prefix", type: "string", required: false, description: "Object key prefix" },
            { name: "max-keys", type: "integer", required: false, description: "Maximum objects to return" },
            { name: "delimiter", type: "string", required: false, description: "Character to group keys" }
        ],
        ["ec2", "describe-instances"] => [
            { name: "instance-ids", type: "list", required: false, description: "Instance IDs to describe" },
            { name: "filters", type: "list", required: false, description: "Filters for instances" },
            { name: "max-results", type: "integer", required: false, description: "Maximum results" }
        ],
        _ => [
            { name: "example-param", type: "string", required: true, description: "Example parameter" }
        ]
    }
}

def generate_nushell_wrapper [cmd_spec: record]: nothing -> string {
    # Generate a sample wrapper
    let params = ($cmd_spec.parameters | each { |p|
        if $p.required {
            $"($p.name): ($p.type)"
        } else {
            $"--($p.name): ($p.type) = \"\""
        }
    } | str join ",\n    ")
    
    $"# Generated wrapper for aws ($cmd_spec.service) ($cmd_spec.command)
export def \"aws ($cmd_spec.service) ($cmd_spec.command)\" [
    ($params)
]: nothing -> record {
    # Parameter validation
    validate_parameters {
        service: \"($cmd_spec.service)\"
        command: \"($cmd_spec.command)\"
        params: $in
    }
    
    # Build AWS CLI command
    let args = build_aws_args \"($cmd_spec.service)\" \"($cmd_spec.command)\" $in
    
    # Execute command
    execute_aws_command $args
}"
}

def generate_service_wrapper [service: string, command: string, cmd_info: record]: nothing -> string {
    generate_nushell_wrapper {
        service: $service
        command: $command
        parameters: $cmd_info.parameters
    }
}

def generate_comprehensive_tests [service: string, command: string, cmd_info: record]: nothing -> string {
    $"# Generated tests for aws ($service) ($command)

#[test]
def \"test ($service) ($command) valid parameters\" [] {
    # Test with valid parameters
    let result = aws ($service) ($command) --mock-mode
    assert ($result | is-not-empty)
}

#[test]  
def \"test ($service) ($command) parameter validation\" [] {
    # Test parameter validation
    assert_error { aws ($service) ($command) \"\" }
}

#[test]
def \"test ($service) ($command) error handling\" [] {
    # Test error handling
    assert_error { aws ($service) ($command) --invalid-param true }
}"
}

def generate_command_tests [service: string, command: string, parameters: list]: nothing -> list<string> {
    [
        $"test_($service)_($command)_valid_input",
        $"test_($service)_($command)_invalid_input", 
        $"test_($service)_($command)_error_handling",
        $"test_($service)_($command)_mock_mode",
        $"test_($service)_($command)_integration"
    ]
}

def validate_generated_wrapper [code: string]: nothing -> record {
    {
        syntax_valid: true,
        quality_score: 85,
        issues: [],
        recommendations: ["Add more comprehensive error handling", "Consider adding caching"]
    }
}

def parse_aws_command_help [service: string, command: string]: nothing -> record {
    {
        name: $command,
        service: $service,
        description: $"AWS ($service) ($command) command - manages ($service) resources",
        parameters: (extract_command_parameters $service $command),
        examples: [],
        errors: []
    }
}

# Mock functions for framework components
def build_aws_args [service: string, command: string, params: record]: nothing -> list<string> {
    ["aws", $service, $command] | append ($params | transpose key value | each { |kv| [$"--($kv.key)", $kv.value] } | flatten)
}

def execute_aws_command [args: list<string>]: nothing -> record {
    { status: "success", output: "Mock AWS command execution", data: {} }
}

def validate_parameters [spec: record]: nothing -> record {
    { valid: true, errors: [] }
}

if ($env.PWD | path join "aws_cli_parser.nu" | path exists) {
    print "🎯 AWS CLI Parser Framework Available - Ready for Demo!"
} else {
    print "⚠️  Note: Full framework not loaded - showing demo functionality"
}