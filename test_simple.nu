#!/usr/bin/env nu

# Simple test to verify basic functionality
# This is a simplified version to test our syntax fixes

use aws_cli_parser.nu

def test-basic-parsing []: nothing -> nothing {
    print "Testing basic parsing functionality..."
    
    # Create test help text
    let test_help = "
NAME
    aws dynamodb batch-get-item

DESCRIPTION
    The BatchGetItem operation returns the attributes of one or more items.

SYNOPSIS
    aws dynamodb batch-get-item
    --request-items <value>
    [--return-consumed-capacity <value>]
    [--cli-input-json <value>]

OPTIONS
    --request-items (map)
        A map of one or more table names.

    --return-consumed-capacity (string)
        Determines the level of detail.

    --cli-input-json (string)
        Reads arguments from the JSON string provided.
"
    
    try {
        let result = (parse-command-details "dynamodb" "batch-get-item" $test_help)
        print $"✅ Parsing successful. Found ($result.parameters | length) parameters"
        
        # Validate basic structure
        if ($result.service == "dynamodb") and ($result.command == "batch-get-item") {
            print "✅ Service and command correctly parsed"
        } else {
            print "❌ Service or command parsing failed"
        }
        
        if ($result.parameters | length) > 0 {
            print "✅ Parameters extracted successfully"
        } else {
            print "❌ No parameters found"
        }
        
    } catch { |error|
        print $"❌ Error during parsing: ($error.msg)"
    }
}

def main []: nothing -> nothing {
    print "🧪 Running simple AWS CLI parser test"
    print "======================================="
    
    test-basic-parsing
    
    print ""
    print "✅ Test completed!"
}