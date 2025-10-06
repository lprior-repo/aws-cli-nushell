#!/usr/bin/env nu

# Simple AWS Test Runner using nutest
use nutest/nutest/mod.nu

def main [
    --service (-s): string = "dynamodb"  # Service to test
] {
    print $"🧪 Testing AWS ($service | str upcase) module"
    print "=" * 40
    
    # Set mock mode for the service
    match $service {
        "dynamodb" => { $env.DYNAMODB_MOCK_MODE = "true" },
        "lambda" => { $env.LAMBDA_MOCK_MODE = "true" },
        "ecs" => { $env.ECS_MOCK_MODE = "true" },
        "iam" => { $env.IAM_MOCK_MODE = "true" },
        "s3api" => { $env.S3API_MOCK_MODE = "true" },
        "events" => { $env.EVENTS_MOCK_MODE = "true" },
        "rds" => { $env.RDS_MOCK_MODE = "true" },
        _ => { print $"Unknown service: ($service)" }
    }
    
    let test_file = $"tests/aws/test_($service).nu"
    
    if not ($test_file | path exists) {
        print $"❌ Test file not found: ($test_file)"
        return
    }
    
    print $"✅ Mock mode activated"
    print $"🔍 Running tests from: ($test_file)"
    print ""
    
    try {
        # Run nutest on the specific test file
        let results = (nutest run-tests $test_file --display table --returns table)
        
        print "📊 Test Results:"
        $results | table
        
        # Summary
        let total = ($results | length)
        let passed = ($results | where result == "PASS" | length)
        let failed = ($results | where result == "FAIL" | length)
        
        print $"\n📈 Summary: ($passed)/($total) passed"
        
        if $failed > 0 {
            print "❌ Some tests failed"
        } else {
            print "✅ All tests passed!"
        }
        
        return $results
        
    } catch { |error|
        print $"❌ Error running tests: ($error.msg)"
    }
}