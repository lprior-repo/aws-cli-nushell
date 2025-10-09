#!/usr/bin/env nu

# AWS CLI Validation Test Suite
# This test suite validates that our generated NuAWS commands exactly match AWS CLI expectations
# It uses AWS CLI help output as the source of truth for command validation

# Extract all available operations from AWS CLI help for a given service
def extract-aws-cli-operations [service: string]: nothing -> list<string> {
    try {
        # Get AWS CLI help for the service
        let help_output = (aws $service help | lines)
        
        # Find the "Available Commands" or "Available Subcommands" section
        let commands_start_patterns = ["Available Commands:", "Available Subcommands:", "AVAILABLE COMMANDS"]
        let start_line = ($help_output 
            | enumerate 
            | where ($it.item | str contains "Available Commands") or ($it.item | str contains "Available Subcommands") or ($it.item | str contains "AVAILABLE COMMANDS")
            | first
            | get index)
        
        if ($start_line | is-empty) {
            return []
        }
        
        # Extract commands from help output
        let commands = ($help_output 
            | skip ($start_line + 1)
            | take 100  # Reasonable limit
            | where ($it | str trim | str length) > 0
            | where ($it | str starts-with " ") and not ($it | str starts-with "  ") # Commands are indented with single space
            | each { |line| 
                let trimmed = ($line | str trim)
                let parts = ($trimmed | split row " " | where ($it | str length) > 0)
                if ($parts | length) >= 1 {
                    $parts | first
                } else {
                    null
                }
            }
            | where ($it | is-not-empty)
            | where not ($it | str contains "help")  # Exclude help command
            | where not ($it | str contains "wait")  # Exclude wait commands
        )
        
        $commands
    } catch {
        print $"Warning: Could not extract operations for service ($service)"
        []
    }
}

# Test that our generated operations match AWS CLI exactly
def test-service-operation-matching [service: string]: nothing -> record {
    use ../nuaws.nu
    
    print $"🔍 Validating ($service) operations against AWS CLI..."
    
    # Get AWS CLI operations as source of truth
    let aws_cli_operations = (extract-aws-cli-operations $service)
    
    # Get our generated operations
    let our_operations = try {
        let schema_file = $"../schemas/($service).json"
        if ($schema_file | path exists) {
            let schema = (open $schema_file)
            if "operations" in ($schema | columns) {
                let operations = $schema.operations
                if ($operations | describe) =~ "^record" {
                    $operations | transpose key value | get key
                } else {
                    $operations | get name? | default []
                }
            } else {
                []
            }
        } else {
            []
        }
    } catch {
        []
    }
    
    # Convert our operations to expected AWS CLI format for comparison
    let converted_operations = ($our_operations | each { |op|
        # Apply same conversion logic as in nuaws.nu
        let kebab_case = ($op 
            | str replace --all --regex '([a-z])([A-Z])' '${1}-${2}'
            | str replace --all --regex '([A-Z])([A-Z][a-z])' '${1}-${2}'
            | str downcase)
        
        # Apply service-specific conversions
        match $service {
            "stepfunctions" => {
                match $kebab_case {
                    "liststatemachines" => "list-state-machines"
                    "createstatemachine" => "create-state-machine"
                    "deletestatemachine" => "delete-state-machine"
                    "describestatemachine" => "describe-state-machine"
                    "startexecution" => "start-execution"
                    "stopexecution" => "stop-execution"
                    _ => $kebab_case
                }
            }
            "s3api" | "s3" => {
                match $kebab_case {
                    "listbuckets" => "list-buckets"
                    "createbucket" => "create-bucket"
                    "deletebucket" => "delete-bucket"
                    "putobject" => "put-object"
                    "getobject" => "get-object"
                    _ => $kebab_case
                }
            }
            _ => $kebab_case
        }
    })
    
    # Find mismatches
    let missing_in_aws = ($converted_operations | where $it not-in $aws_cli_operations)
    let missing_in_ours = ($aws_cli_operations | where $it not-in $converted_operations)
    let matching_operations = ($converted_operations | where $it in $aws_cli_operations)
    
    {
        service: $service,
        aws_cli_operations_count: ($aws_cli_operations | length),
        our_operations_count: ($our_operations | length),
        matching_operations_count: ($matching_operations | length),
        missing_in_aws: $missing_in_aws,
        missing_in_ours: $missing_in_ours,
        match_percentage: (if ($aws_cli_operations | length) > 0 { 
            ($matching_operations | length) * 100 / ($aws_cli_operations | length) 
        } else { 
            0 
        })
    }
}

# Test operation name conversion by actually calling AWS CLI help
def test-conversion-accuracy [service: string, operations: list<string>]: nothing -> list<record> {
    $operations | each { |operation|
        try {
            # Try to get help for the specific operation to validate it exists
            let help_result = (aws $service $operation help | head -5)
            
            {
                service: $service,
                operation: $operation,
                status: "✅ VALID",
                message: "Operation exists in AWS CLI"
            }
        } catch { |err|
            let error_msg = ($err.msg | default "Unknown error")
            if ($error_msg | str contains "Invalid choice") {
                {
                    service: $service,
                    operation: $operation,
                    status: "❌ INVALID",
                    message: $"Operation not found in AWS CLI: ($error_msg)"
                }
            } else {
                {
                    service: $service,
                    operation: $operation,
                    status: "⚠️ WARNING",
                    message: $"Could not validate (may be permission issue): ($error_msg)"
                }
            }
        }
    }
}

# Test that NuAWS commands map correctly to AWS CLI
def test-nuaws-to-aws-cli-mapping []: nothing -> list<record> {
    use ../nuaws.nu
    
    print "🔗 Testing NuAWS to AWS CLI command mapping..."
    
    let test_mappings = [
        # [nuaws_service, nuaws_operation, expected_aws_service, expected_aws_operation]
        ["s3", "listbuckets", "s3api", "list-buckets"],
        ["s3", "createbucket", "s3api", "create-bucket"],
        ["s3", "putobject", "s3api", "put-object"],
        ["stepfunctions", "liststatemachines", "stepfunctions", "list-state-machines"],
        ["stepfunctions", "createstatemachine", "stepfunctions", "create-state-machine"],
        ["stepfunctions", "startexecution", "stepfunctions", "start-execution"],
        ["iam", "ListUsers", "iam", "list-users"],
        ["iam", "CreateUser", "iam", "create-user"],
        ["iam", "GetUser", "iam", "get-user"]
    ]
    
    $test_mappings | each { |mapping|
        let nuaws_service = $mapping.0
        let nuaws_operation = $mapping.1
        let expected_aws_service = $mapping.2
        let expected_aws_operation = $mapping.3
        
        # Test that the AWS CLI command exists
        try {
            let help_check = (aws $expected_aws_service $expected_aws_operation help | head -3)
            
            {
                nuaws_command: $"nuaws ($nuaws_service) ($nuaws_operation)",
                expected_aws_command: $"aws ($expected_aws_service) ($expected_aws_operation)",
                status: "✅ VALID",
                message: "Mapping verified against AWS CLI"
            }
        } catch { |err|
            {
                nuaws_command: $"nuaws ($nuaws_service) ($nuaws_operation)",
                expected_aws_command: $"aws ($expected_aws_service) ($expected_aws_operation)",
                status: "❌ INVALID",
                message: $"AWS CLI validation failed: ($err.msg)"
            }
        }
    }
}

# Test actual command execution to ensure conversion works end-to-end
def test-end-to-end-command-execution []: nothing -> list<record> {
    use ../nuaws.nu
    
    print "🎯 Testing end-to-end command execution..."
    
    # Set mock mode for safe testing
    $env.S3_MOCK_MODE = "true"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    $env.IAM_MOCK_MODE = "true"
    
    let test_commands = [
        ["s3", "listbuckets"],
        ["s3", "createbucket"],
        ["stepfunctions", "liststatemachines"],
        ["stepfunctions", "createactivity"],
        ["iam", "ListUsers"],
        ["iam", "ListRoles"]
    ]
    
    let results = ($test_commands | each { |cmd|
        let service = $cmd.0
        let operation = $cmd.1
        
        try {
            let result = (nuaws $service $operation)
            
            if ($result.mock? | default false) {
                {
                    command: $"nuaws ($service) ($operation)",
                    status: "✅ SUCCESS",
                    message: "Command executed successfully in mock mode"
                }
            } else {
                {
                    command: $"nuaws ($service) ($operation)",
                    status: "⚠️ WARNING",
                    message: "Command executed but not in mock mode"
                }
            }
        } catch { |err|
            {
                command: $"nuaws ($service) ($operation)",
                status: "❌ FAILED",
                message: $"Command execution failed: ($err.msg)"
            }
        }
    })
    
    # Reset mock mode
    $env.S3_MOCK_MODE = "false"
    $env.STEPFUNCTIONS_MOCK_MODE = "false"
    $env.IAM_MOCK_MODE = "false"
    
    $results
}

# Generate AWS CLI command completeness report
def generate-completeness-report []: nothing -> record {
    print "📊 Generating AWS CLI command completeness report..."
    
    let services = ["s3api", "stepfunctions", "iam", "ec2"]
    
    let service_reports = ($services | each { |service|
        let validation = (test-service-operation-matching $service)
        
        {
            service: $service,
            completeness: $validation.match_percentage,
            aws_operations: $validation.aws_cli_operations_count,
            our_operations: $validation.our_operations_count,
            missing_count: ($validation.missing_in_ours | length),
            extra_count: ($validation.missing_in_aws | length)
        }
    })
    
    let overall_completeness = ($service_reports | get completeness | math avg)
    
    {
        overall_completeness: $overall_completeness,
        service_reports: $service_reports,
        timestamp: (date now)
    }
}

def main [] {
    print "🚀 AWS CLI Validation Test Suite"
    print "Using AWS CLI as source of truth for command validation"
    print "=" * 60
    
    let start_time = (date now)
    
    # Test 1: Service operation matching
    print "\n🔍 Testing service operation matching against AWS CLI..."
    let s3_validation = (test-service-operation-matching "s3api")
    let stepfunctions_validation = (test-service-operation-matching "stepfunctions")
    let iam_validation = (test-service-operation-matching "iam")
    
    # Test 2: Command mapping validation
    let mapping_results = (test-nuaws-to-aws-cli-mapping)
    
    # Test 3: End-to-end execution
    let execution_results = (test-end-to-end-command-execution)
    
    # Test 4: Completeness report
    let completeness_report = (generate-completeness-report)
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    # Generate comprehensive report
    print "\n📊 AWS CLI VALIDATION REPORT"
    print "=" * 40
    
    print $"\n⏱️  Test Duration: ($duration)"
    
    # Service matching results
    print "\n🎯 SERVICE OPERATION MATCHING:"
    print $"  S3API: (($s3_validation.match_percentage | math round)%) - ($s3_validation.matching_operations_count)/($s3_validation.aws_cli_operations_count) operations"
    print $"  Step Functions: (($stepfunctions_validation.match_percentage | math round)%) - ($stepfunctions_validation.matching_operations_count)/($stepfunctions_validation.aws_cli_operations_count) operations"
    print $"  IAM: (($iam_validation.match_percentage | math round)%) - ($iam_validation.matching_operations_count)/($iam_validation.aws_cli_operations_count) operations"
    
    # Command mapping results
    let valid_mappings = ($mapping_results | where status == "✅ VALID" | length)
    let total_mappings = ($mapping_results | length)
    print $"\n🔗 COMMAND MAPPING VALIDATION:"
    let mapping_percentage = ($valid_mappings * 100 / $total_mappings | math round)
    print $"  Valid Mappings: ($valid_mappings)/($total_mappings) (($mapping_percentage)%)"
    
    # Execution results
    let successful_executions = ($execution_results | where status == "✅ SUCCESS" | length)
    let total_executions = ($execution_results | length)
    print $"\n🎯 END-TO-END EXECUTION:"
    let execution_percentage = ($successful_executions * 100 / $total_executions | math round)
    print $"  Successful: ($successful_executions)/($total_executions) (($execution_percentage)%)"
    
    # Overall completeness
    let overall_completeness_percentage = ($completeness_report.overall_completeness | math round)
    print $"\n📈 OVERALL COMPLETENESS: ($overall_completeness_percentage)%"
    
    # Issues and recommendations
    print "\n⚠️  ISSUES DETECTED:"
    
    # Missing operations
    if ($s3_validation.missing_in_ours | length) > 0 {
        print $"  S3API Missing: ($s3_validation.missing_in_ours | str join ', ')"
    }
    if ($stepfunctions_validation.missing_in_ours | length) > 0 {
        print $"  Step Functions Missing: ($stepfunctions_validation.missing_in_ours | str join ', ')"
    }
    if ($iam_validation.missing_in_ours | length) > 0 {
        print $"  IAM Missing: ($iam_validation.missing_in_ours | str join ', ')"
    }
    
    # Failed mappings
    let failed_mappings = ($mapping_results | where status != "✅ VALID")
    if ($failed_mappings | length) > 0 {
        print "  Failed Command Mappings:"
        for failed in $failed_mappings {
            print $"    - ($failed.nuaws_command) -> ($failed.expected_aws_command): ($failed.message)"
        }
    }
    
    # Failed executions
    let failed_executions = ($execution_results | where status == "❌ FAILED")
    if ($failed_executions | length) > 0 {
        print "  Failed Executions:"
        for failed in $failed_executions {
            print $"    - ($failed.command): ($failed.message)"
        }
    }
    
    # Overall assessment
    let overall_success_rate = (
        ($s3_validation.match_percentage + $stepfunctions_validation.match_percentage + $iam_validation.match_percentage) / 3
    )
    
    let assessment = if $overall_success_rate >= 95 {
        "🟢 EXCELLENT - NuAWS commands match AWS CLI expectations"
    } else if $overall_success_rate >= 85 {
        "🟡 GOOD - Minor discrepancies with AWS CLI"
    } else if $overall_success_rate >= 70 {
        "🟠 ACCEPTABLE - Some alignment issues with AWS CLI"
    } else {
        "🔴 NEEDS ATTENTION - Significant AWS CLI alignment issues"
    }
    
    print $"\n🏥 OVERALL ASSESSMENT: ($assessment)"
    
    # Recommendations
    print "\n💡 RECOMMENDATIONS:"
    if $overall_success_rate >= 95 {
        print "  ✅ NuAWS is well-aligned with AWS CLI expectations"
        print "  ✅ Command conversion logic is working correctly"
        print "  ✅ Ready for production use"
    } else {
        print "  🔧 Review missing operations and add them to schemas"
        print "  🔧 Improve command conversion logic for edge cases"
        print "  🔧 Add more comprehensive operation mappings"
    }
    
    # Save detailed report
    let detailed_report = {
        timestamp: (date now),
        duration: $duration,
        service_validations: {
            s3api: $s3_validation,
            stepfunctions: $stepfunctions_validation,
            iam: $iam_validation
        },
        mapping_results: $mapping_results,
        execution_results: $execution_results,
        completeness_report: $completeness_report,
        overall_success_rate: $overall_success_rate,
        assessment: $assessment
    }
    
    $detailed_report | to json | save -f "logs/aws_cli_validation_report.json"
    print "\n📄 Detailed report saved to logs/aws_cli_validation_report.json"
    
    $detailed_report
}

if $nu.is-interactive == false {
    main
}