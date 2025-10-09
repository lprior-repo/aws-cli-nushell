#!/usr/bin/env nu

# Simple and reliable AWS CLI command extractor

# Extract commands from AWS CLI help output
def extract-commands [service: string]: nothing -> list<string> {
    try {
        print $"📡 Extracting AWS CLI commands for ($service)..."
        
        # Get help output and clean backspace characters (used for terminal formatting)
        let help_lines = (aws $service help | lines | each { |line| $line | str replace --all '\b' '' })
        
        # Find lines that match the AWS CLI command pattern: "       +o command-name"
        let command_lines = ($help_lines 
            | where { |line| $line | str trim | str starts-with "+o " }
            | each { |line|
                # Extract the command name after "+o "
                let trimmed = ($line | str trim)
                $trimmed | str replace "+o " "" | str trim
            }
            | where { |cmd| ($cmd | is-not-empty) and ($cmd != "help") }
        )
        
        print $"✅ Found ($command_lines | length) commands for ($service)"
        $command_lines
        
    } catch { |err|
        print $"❌ Failed to extract commands for ($service): ($err.msg)"
        []
    }
}

# Test extraction for Step Functions
def test-stepfunctions [] {
    print "🧪 Testing Step Functions command extraction..."
    let commands = (extract-commands "stepfunctions")
    
    print "\n📋 Step Functions Commands:"
    for cmd in $commands {
        print $"  - ($cmd)"
    }
    
    $commands
}

# Test extraction for multiple services
def test-all-services [] {
    let services = ["stepfunctions", "s3api", "iam", "lambda", "dynamodb"]
    
    $services | each { |service|
        let commands = (extract-commands $service)
        {
            service: $service,
            command_count: ($commands | length),
            commands: $commands,
            sample: ($commands | first 3)
        }
    }
}

# Generate NuAWS operations file based on real AWS CLI commands
def generate-nuaws-operations [service: string]: nothing -> nothing {
    let commands = (extract-commands $service)
    
    if ($commands | is-empty) {
        print $"❌ No commands found for ($service)"
        return
    }
    
    print $"🔧 Generating NuAWS operations for ($service) with ($commands | length) commands..."
    
    # Create operations data structure
    let operations_data = {
        service: $service,
        generated_at: (date now),
        source: "aws_cli_help",
        command_count: ($commands | length),
        operations: ($commands | each { |cmd|
            {
                name: $cmd,
                aws_command: $cmd,
                description: $"AWS ($service) ($cmd) operation"
            }
        })
    }
    
    # Save to schema file
    let schema_file = $"../schemas/($service)_aws_cli.json"
    $operations_data | to json | save --force $schema_file
    
    print $"💾 Saved ($commands | length) operations to ($schema_file)"
    
    # Show sample operations
    print "\n📋 Sample operations:"
    for cmd in ($commands | first 5) {
        print $"  nuaws ($service) ($cmd)"
    }
}

def main [] {
    print "🚀 AWS CLI Command Extractor"
    print "Extract real AWS CLI commands for 1:1 matching"
    print "=" * 50
    
    # Test Step Functions first
    print "\n🧪 Testing Step Functions extraction..."
    let stepfunctions_commands = (test-stepfunctions)
    
    if ($stepfunctions_commands | length) > 0 {
        print "\n🎯 SUCCESS! Step Functions commands extracted correctly."
        print "These are the exact AWS CLI commands that should be available in NuAWS:"
        
        # Generate operations file
        generate-nuaws-operations "stepfunctions"
        
        print "\n💡 You can now use commands like:"
        print "  nuaws stepfunctions list-state-machines"
        print "  nuaws stepfunctions create-state-machine"
        print "  nuaws stepfunctions start-execution"
        
    } else {
        print "❌ Failed to extract Step Functions commands"
    }
    
    print "\n🔄 Testing other services..."
    let all_results = (test-all-services)
    
    print "\n📊 EXTRACTION RESULTS:"
    print ($all_results | select service command_count sample | table)
    
    print "\n🎯 NEXT STEPS:"
    print "1. Update NuAWS router to use these exact command names"
    print "2. Remove operation name conversion logic"  
    print "3. Use AWS CLI commands directly: nuaws <service> <aws-cli-command>"
}

if $nu.is-interactive == false {
    main
}