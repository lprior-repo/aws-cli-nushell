#!/usr/bin/env nu

# AWS CLI Command Extractor
# Extracts available commands directly from AWS CLI help output
# This ensures 1:1 matching with what AWS CLI actually offers

# Extract available commands from AWS CLI help for a service
export def extract-aws-commands [service: string]: nothing -> list<string> {
    try {
        print $"📡 Extracting commands for AWS ($service) from CLI help..."
        
        # Get AWS CLI help output
        let help_output = (aws $service help | lines)
        
        # Find the "Available Commands" section
        let commands_section_patterns = [
            "Available Commands",
            "Available Subcommands", 
            "AVAILABLE COMMANDS"
        ]
        
        let start_idx = ($help_output 
            | enumerate 
            | where { |line| 
                $commands_section_patterns | any { |pattern| $line.item | str contains $pattern }
            }
            | first
            | get index
        )
        
        if ($start_idx | is-empty) {
            print $"⚠️  No 'Available Commands' section found for ($service)"
            return []
        }
        
        # Extract commands from the help output
        let commands = ($help_output 
            | skip ($start_idx + 1)
            | take 100  # Reasonable limit to avoid processing entire help
            | where ($it | str trim | str length) > 0
            | where ($it | str starts-with " +o ") or ($it | str starts-with "       +o ")  # AWS CLI format
            | each { |line|
                # Extract command name after "+o "
                let trimmed = ($line | str trim)
                if ($trimmed | str starts-with "+o ") {
                    $trimmed | str replace "+o " "" | str trim
                } else {
                    null
                }
            }
            | where ($it | is-not-empty)
            | where not ($it | str contains "help")  # Exclude help command
            | where not ($it | str contains "wait")  # Exclude wait commands typically
        )
        
        print $"✅ Found ($commands | length) commands for ($service)"
        $commands
        
    } catch { |err|
        print $"❌ Failed to extract commands for ($service): ($err.msg)"
        []
    }
}

# Generate operation list for NuAWS based on real AWS CLI commands
export def generate-operation-list [service: string]: nothing -> record {
    let aws_commands = (extract-aws-commands $service)
    
    if ($aws_commands | is-empty) {
        return {
            service: $service,
            commands: [],
            count: 0,
            status: "failed"
        }
    }
    
    # Create operation records
    let operations = ($aws_commands | each { |cmd|
        {
            name: $cmd,
            aws_command: $cmd,
            description: $"AWS ($service) ($cmd) operation"
        }
    })
    
    {
        service: $service,
        commands: $aws_commands,
        operations: $operations,
        count: ($aws_commands | length),
        status: "success"
    }
}

# Update NuAWS to use real AWS CLI commands for a service
export def update-nuaws-operations [service: string]: nothing -> record {
    print $"🔄 Updating NuAWS operations for ($service) with real AWS CLI commands..."
    
    let operation_list = (generate-operation-list $service)
    
    if $operation_list.status == "failed" {
        return $operation_list
    }
    
    # Create a schema-like structure for NuAWS
    let nuaws_schema = {
        service: $service,
        version: (date now | format date "%Y-%m-%d"),
        source: "aws_cli_help",
        operations: $operation_list.operations
    }
    
    # Save the schema
    let schema_file = $"schemas/($service)_cli.json"
    $nuaws_schema | to json | save --force $schema_file
    
    print $"💾 Saved AWS CLI commands to ($schema_file)"
    
    {
        service: $service,
        schema_file: $schema_file,
        commands_extracted: $operation_list.count,
        commands: $operation_list.commands,
        status: "success"
    }
}

# Validate that NuAWS operations match AWS CLI exactly
export def validate-operations-match [service: string]: nothing -> record {
    print $"🔍 Validating NuAWS operations match AWS CLI for ($service)..."
    
    # Get AWS CLI commands
    let aws_commands = (extract-aws-commands $service)
    
    # Get current NuAWS operations
    let nuaws_operations = try {
        use ../nuaws.nu
        nuaws $service help | get operations? | default []
    } catch {
        []
    }
    
    # Compare
    let missing_from_nuaws = ($aws_commands | where $it not-in $nuaws_operations)
    let extra_in_nuaws = ($nuaws_operations | where $it not-in $aws_commands)
    let matching = ($aws_commands | where $it in $nuaws_operations)
    
    let match_percentage = if ($aws_commands | length) > 0 {
        ($matching | length) * 100 / ($aws_commands | length)
    } else {
        0
    }
    
    {
        service: $service,
        aws_commands_count: ($aws_commands | length),
        nuaws_operations_count: ($nuaws_operations | length),
        matching_count: ($matching | length),
        match_percentage: $match_percentage,
        missing_from_nuaws: $missing_from_nuaws,
        extra_in_nuaws: $extra_in_nuaws,
        aws_commands: $aws_commands,
        status: (if $match_percentage >= 95 { "excellent" } else if $match_percentage >= 80 { "good" } else { "needs_work" })
    }
}

# Test AWS CLI command extraction for multiple services  
export def test-extraction []: nothing -> table {
    let services = ["stepfunctions", "s3api", "iam", "lambda", "dynamodb", "events"]
    
    print "🧪 Testing AWS CLI command extraction for multiple services..."
    
    $services | each { |service|
        let result = (generate-operation-list $service)
        
        {
            service: $service,
            status: $result.status,
            command_count: $result.count,
            sample_commands: ($result.commands | first 3 | str join ", ")
        }
    }
}

def main [] {
    print "🚀 AWS CLI Command Extractor Tool"
    print "Extract real AWS CLI commands for perfect NuAWS integration"
    print "=" * 60
    
    let start_time = (date now)
    
    # Test extraction
    print "\n🧪 Testing command extraction..."
    let test_results = (test-extraction)
    
    print "\n📊 EXTRACTION TEST RESULTS:"
    print ($test_results | table)
    
    # Example: Update Step Functions
    print "\n🔄 Example: Updating Step Functions operations..."
    let stepfunctions_result = (update-nuaws-operations "stepfunctions")
    
    if $stepfunctions_result.status == "success" {
        print $"✅ Step Functions: ($stepfunctions_result.commands_extracted) commands extracted"
        print "Sample commands:"
        for cmd in ($stepfunctions_result.commands | first 5) {
            print $"  - ($cmd)"
        }
    }
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    print $"\n⏱️  Total Duration: ($duration)"
    print "\n💡 USAGE:"
    print "  extract-aws-commands <service>     # Extract commands for a service"
    print "  update-nuaws-operations <service>  # Update NuAWS with real commands"
    print "  validate-operations-match <service> # Validate NuAWS matches AWS CLI"
    
    print "\n🎯 NEXT STEPS:"
    print "1. Run 'update-nuaws-operations' for each service you want to update"
    print "2. Update the NuAWS router to use these exact command names"
    print "3. Validate with 'validate-operations-match' for each service"
}

if $nu.is-interactive == false {
    main
}