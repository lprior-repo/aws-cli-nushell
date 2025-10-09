#!/usr/bin/env nu

# Simple AWS CLI Nushell Build System
# Focuses on auto-generation capabilities using core generators

export def main [
    --service (-s): string,           # Generate specific service (e.g., "s3", "ec2")
    --all (-a),                      # Generate all services
    --with-completions (-c),         # Include external completions
    --with-tests (-t),               # Include test suites
    --output (-o): string = ".",     # Output directory
    --clean                          # Clean generated files first
] {
    print "🚀 AWS CLI Nushell Build System"
    print "================================="
    
    if $clean {
        clean-generated-files
    }
    
    if $all {
        generate-all-services $output $with_completions $with_tests
    } else if ($service | is-not-empty) {
        generate-service $service $output $with_completions $with_tests
    } else {
        show-usage
    }
}

# Generate a specific AWS service
def generate-service [
    service: string,
    output_dir: string,
    with_completions: bool,
    with_tests: bool
] {
    print $"📦 Generating AWS ($service) service..."
    
    # Use the universal generator
    use generator.nu generate-aws-service
    let result = (generate-aws-service $service --output $output_dir --with-completions=$with_completions --with-tests=$with_tests)
    
    print $"✅ Generated ($result.operations_count) operations for ($service)"
    if $with_completions {
        print "✅ Generated external completions"
    }
    if $with_tests {
        print "✅ Generated test suite"
    }
    
    $result
}

# Generate all available services
def generate-all-services [
    output_dir: string,
    with_completions: bool,
    with_tests: bool
] {
    print "🌟 Generating all AWS services..."
    
    # Common AWS services that should work with AWS CLI
    let services = [
        "s3",
        "ec2", 
        "iam",
        "lambda",
        "dynamodb",
        "stepfunctions",
        "rds",
        "cloudformation",
        "sns",
        "sqs"
    ]
    
    let results = ($services | each { |service|
        try {
            generate-service $service $output_dir $with_completions $with_tests
        } catch { |err|
            print $"❌ Failed to generate ($service): ($err.msg)"
            {
                service: $service,
                operations_count: 0,
                status: "failed",
                error: $err.msg
            }
        }
    })
    
    let successful = ($results | where status != "failed" | length)
    let total = ($results | length)
    
    print $"📊 Generation Summary: ($successful)/($total) services completed"
    $results
}

# Clean generated files
def clean-generated-files [] {
    print "🧹 Cleaning generated files..."
    
    # Remove generated service modules
    try { rm -rf aws/ } catch { }
    try { rm -rf modules/ } catch { }
    try { rm -rf completions/ } catch { }
    try { rm -rf tests/aws/ } catch { }
    
    print "✅ Cleaned generated files"
}

# Show usage information
def show-usage [] {
    print "Usage:"
    print "  nu build.nu --service s3                    # Generate S3 service"
    print "  nu build.nu --all                          # Generate all services"
    print "  nu build.nu --service ec2 --with-completions # Generate with completions"
    print "  nu build.nu --clean                        # Clean generated files"
    print ""
    print "Available generators:"
    print "  - Universal AWS Generator (generator.nu)"
    print "  - Type System Generator (type_system_generator.nu)"
    print "  - Completion System Generator (completion_system_generator.nu)"
    print "  - Command Extractor (aws_cli_command_extractor.nu)"
}

# Add schema pulling functionality with multiple sources
export def pull-aws-schemas [
    --service (-s): string,          # Pull schema for specific service
    --all (-a),                     # Pull all service schemas
    --source: string = "cli"        # Source: "cli" (AWS CLI help), "boto3" (botocore models), or "both"
] {
    print "📡 Pulling AWS service schemas..."
    
    match $source {
        "cli" => { pull-schemas-from-cli $service $all }
        "boto3" => { pull-schemas-from-boto3 $service $all }
        "both" => { 
            pull-schemas-from-cli $service $all
            pull-schemas-from-boto3 $service $all
        }
        _ => {
            print $"❌ Unknown source: ($source)"
            print "Available sources: cli, boto3, both"
        }
    }
}

# Pull schemas from AWS CLI help output
def pull-schemas-from-cli [
    service: string,
    all_services: bool
] {
    mkdir schemas
    
    if $all_services {
        let services = ["s3", "ec2", "iam", "lambda", "dynamodb", "stepfunctions", "rds", "sns", "sqs"]
        $services | each { |svc| extract-service-schema $svc }
    } else if ($service | is-not-empty) {
        extract-service-schema $service
    } else {
        print "❌ Please specify --service or --all"
    }
}

# Extract schema for a single service from CLI
def extract-service-schema [service: string] {
    print $"📄 Extracting schema for ($service)..."
    
    use aws_cli_command_extractor.nu generate-operation-list
    let operation_data = (generate-operation-list $service)
    
    if $operation_data.status == "success" {
        let schema = {
            service: $service,
            source: "aws_cli_help",
            extracted_at: (date now),
            operations: $operation_data.operations
        }
        
        let schema_file = $"schemas/($service).json"
        $schema | to json | save --force $schema_file
        print $"✅ Saved schema to ($schema_file)"
    } else {
        print $"❌ Failed to extract schema for ($service)"
    }
}

# Pull schemas from botocore/boto3 models (if available)
def pull-schemas-from-boto3 [
    service: string,
    all_services: bool
] {
    mkdir schemas
    
    # Check if Python and boto3 are available
    let python_available = try { 
        ^python3 -c "import boto3, botocore; print('ok')" | str trim
    } catch { "" }
    
    if $python_available != "ok" {
        print "❌ Python3 with boto3/botocore not available"
        print "💡 Install with: pip install boto3 botocore"
        print "💡 This provides more detailed type information than CLI help"
        return
    }
    
    print "✅ Python3 with boto3/botocore detected"
    
    if $all_services {
        extract-all-boto3-schemas
    } else if ($service | is-not-empty) {
        extract-boto3-schema $service
    } else {
        print "❌ Please specify --service or --all"
    }
}

# Extract all available boto3 service schemas
def extract-all-boto3-schemas [] {
    print "📡 Extracting all boto3 service schemas..."
    
    let python_script = '
import boto3
import json
from botocore.loaders import Loader

# Get the botocore data loader
loader = Loader()

# Get list of available services
services = loader.list_available_services(type_name="service-2")
print(json.dumps({"services": services[:20]}))  # Limit to first 20 to avoid overwhelming
'
    
    let services_data = try {
        $python_script | ^python3 | from json
    } catch {
        print "❌ Failed to get boto3 service list"
        return
    }
    
    print $"📊 Found ($services_data.services | length) boto3 services"
    
    $services_data.services | each { |svc| extract-boto3-schema $svc }
}

# Extract detailed schema for a specific service using boto3
def extract-boto3-schema [service: string] {
    print $"📄 Extracting boto3 schema for ($service)..."
    
    let python_script = $'
import boto3
import json
from botocore.loaders import Loader

try:
    # Get the botocore data loader
    loader = Loader()
    
    # Load the service model
    service_model = loader.load_service_model("($service)", "service-2")
    
    # Extract operations
    operations = []
    if "operations" in service_model:
        for op_name, op_data in service_model["operations"].items():
            operation = {
                "name": op_name,
                "description": op_data.get("documentation", ""),
                "input_shape": op_data.get("input", {}).get("shape", ""),
                "output_shape": op_data.get("output", {}).get("shape", ""),
                "errors": [err.get("shape", "") for err in op_data.get("errors", [])]
            }
            operations.append(operation)
    
    # Extract shapes (type definitions)
    shapes = service_model.get("shapes", {})
    
    schema = {
        "service": "($service)",
        "source": "boto3_botocore",
        "version": service_model.get("metadata", {}).get("apiVersion", ""),
        "protocol": service_model.get("metadata", {}).get("protocol", ""),
        "operations": operations,
        "shapes": shapes
    }
    
    print(json.dumps(schema, indent=2))
    
except Exception as e:
    print(json.dumps({"error": str(e), "service": "($service)"}))
'
    
    let schema_result = try {
        $python_script | ^python3 | from json
    } catch { |err|
        print $"❌ Failed to extract boto3 schema for ($service): ($err.msg)"
        return
    }
    
    if "error" in ($schema_result | columns) {
        print $"❌ boto3 error for ($service): ($schema_result.error)"
        return
    }
    
    # Save the detailed schema
    let schema_file = $"schemas/($service)_boto3.json"
    $schema_result | to json | save --force $schema_file
    print $"✅ Saved detailed boto3 schema to ($schema_file)"
    
    # Show summary
    let ops_count = ($schema_result.operations | length)
    let shapes_count = ($schema_result.shapes | length)
    print $"📊 ($service): ($ops_count) operations, ($shapes_count) type definitions"
}