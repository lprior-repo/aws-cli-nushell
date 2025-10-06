#!/usr/bin/env nu

# AWS Modules Test Runner with Table Output
# Integrates nutest framework to test all AWS modules

use nutest/nutest/mod.nu

def main [
    --service (-s): string = "all"     # Specific service to test (all, dynamodb, lambda, ecs, iam)
    --format (-f): string = "table"    # Output format (table, json, summary)
    --verbose (-v)                     # Verbose output
] {
    print "🧪 AWS Modules Test Suite"
    print "=========================="
    
    let available_services = ["dynamodb", "lambda", "ecs", "iam"]
    let services_to_test = if $service == "all" { 
        $available_services 
    } else { 
        [$service] 
    }
    
    print $"Testing services: ($services_to_test | str join ', ')"
    print $"Output format: ($format)"
    print ""
    
    mut all_results = []
    
    for service in $services_to_test {
        print $"🔍 Testing ($service | str upcase) module..."
        
        let test_file = $"tests/aws/test_($service).nu"
        
        if not ($test_file | path exists) {
            print $"⚠️  Test file not found: ($test_file)"
            continue
        }
        
        try {
            # Run nutest on the specific service test file
            let test_results = (nutest run-tests $test_file --no-fail)
            
            # Transform results for our table format
            let service_results = ($test_results | each { |result|
                {
                    service: ($service | str upcase),
                    test_name: $result.name,
                    status: (if $result.pass { "✅ PASS" } else { "❌ FAIL" }),
                    duration: ($result.duration? | default "0ms"),
                    error: ($result.error? | default "")
                }
            })
            
            $all_results = ($all_results | append $service_results)
            
            let passed = ($service_results | where status == "✅ PASS" | length)
            let failed = ($service_results | where status == "❌ FAIL" | length)
            
            print $"   Results: ($passed) passed, ($failed) failed"
            
        } catch { |error|
            print $"❌ Error testing ($service): ($error.msg)"
            
            $all_results = ($all_results | append {
                service: ($service | str upcase),
                test_name: "Test execution failed",
                status: "❌ ERROR",
                duration: "0ms",
                error: $error.msg
            })
        }
    }
    
    print "\n============================================================"
    print "📊 TEST RESULTS SUMMARY"
    print "============================================================"
    
    # Output results based on format
    match $format {
        "table" => {
            print ""
            $all_results | table
            
            print "\n📈 Summary Statistics:"
            let total_tests = ($all_results | length)
            let passed_tests = ($all_results | where status == "✅ PASS" | length)
            let failed_tests = ($all_results | where status == "❌ FAIL" | length)
            let error_tests = ($all_results | where status == "❌ ERROR" | length)
            
            [
                {metric: "Total Tests", value: $total_tests},
                {metric: "Passed", value: $passed_tests},
                {metric: "Failed", value: $failed_tests},
                {metric: "Errors", value: $error_tests},
                {metric: "Success Rate", value: $"(($passed_tests / $total_tests) * 100 | math round)%"}
            ] | table
        },
        "json" => {
            $all_results | to json
        },
        "summary" => {
            let total_tests = ($all_results | length)
            let passed_tests = ($all_results | where status == "✅ PASS" | length)
            let failed_tests = ($all_results | where status == "❌ FAIL" | length)
            
            print $"Total: ($total_tests) | Passed: ($passed_tests) | Failed: ($failed_tests)"
            print $"Success Rate: (($passed_tests / $total_tests) * 100 | math round)%"
        }
    }
    
    if $verbose and ($all_results | where status != "✅ PASS" | length) > 0 {
        print "\n🔍 Failed/Error Test Details:"
        $all_results | where status != "✅ PASS" | each { |result|
            print $"❌ ($result.service) - ($result.test_name): ($result.error)"
        }
    }
    
    print "\n✅ AWS Module testing complete!"
    
    # Return structured data for further processing
    $all_results
}