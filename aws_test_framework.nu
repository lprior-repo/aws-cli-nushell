#!/usr/bin/env nu

# AWS Module Test Framework - Direct Implementation
# Provides table output for testing all AWS modules

def main [
    --service (-s): string = "all"     # Service to test (all, dynamodb, lambda, ecs, iam, s3api, events, rds)
    --format (-f): string = "table"    # Output format (table, json, summary)
    --verbose (-v)                     # Verbose output
    --mock (-m)                        # Use mock mode (default: true)
] {
    print "🚀 AWS CLI Nushell Framework - Test Suite"
    print "=" * 50
    
    # Available services with their test functions
    let available_services = {
        dynamodb: [
            "list-tables", "create-table", "describe-table", 
            "put-item", "get-item", "scan", "query", "delete-table"
        ],
        lambda: [
            "list-functions", "create-function", "invoke", 
            "update-function-code", "delete-function", "get-function", "list-layers"
        ],
        ecs: [
            "list-clusters", "create-cluster", "create-service", 
            "list-services", "describe-clusters", "run-task", "delete-cluster"
        ],
        iam: [
            "list-users", "create-user", "attach-group-policy"
        ],
        s3api: [
            "list-buckets", "create-bucket", "put-object", "get-object", "delete-bucket"
        ],
        events: [
            "list-rules", "put-rule", "put-events", "delete-rule"
        ],
        rds: [
            "describe-db-instances", "create-db-instance", "delete-db-instance"
        ]
    }
    
    let services_to_test = if $service == "all" { 
        ($available_services | columns)
    } else { 
        [$service] 
    }
    
    print $"Testing services: ($services_to_test | str join ', ')"
    print $"Mock mode: (if $mock { 'enabled' } else { 'disabled' })"
    print ""
    
    # Set mock modes if enabled
    if $mock {
        $env.DYNAMODB_MOCK_MODE = "true"
        $env.LAMBDA_MOCK_MODE = "true"
        $env.ECS_MOCK_MODE = "true"
        $env.IAM_MOCK_MODE = "true"
        $env.S3API_MOCK_MODE = "true"
        $env.EVENTS_MOCK_MODE = "true"
        $env.RDS_MOCK_MODE = "true"
    }
    
    let test_results = ($services_to_test | each { |svc|
        if $svc not-in ($available_services | columns) {
            print $"⚠️  Unknown service: ($svc)"
            return []
        }
        
        print $"🔍 Testing ($svc | str upcase) module..."
        
        try {
            # Import the service module
            let module_path = $"./aws/($svc).nu"
            
            if not ($module_path | path exists) {
                print $"   ❌ Module not found: ($module_path)"
                return [{
                    service: ($svc | str upcase),
                    test_name: "Module load",
                    status: "❌ FAIL",
                    duration: "0ms",
                    error: "Module file not found"
                }]
            }
            
            # Test functions for this service
            let service_tests = ($available_services | get $svc)
            let function_results = ($service_tests | each { |test_func|
                let full_command = $"aws ($svc) ($test_func)"
                
                try {
                    print $"   Testing: ($test_func)"
                    
                    # Use nu to execute the command dynamically
                    let start_time = (date now)
                    let result = (nu -c $"use ($module_path) *; \(($full_command)\)")
                    let end_time = (date now)
                    let duration = (($end_time - $start_time) | format duration sec)
                    
                    # Check if result contains mock flag (indicates success in mock mode)
                    if ($result | get mock? | default false) == true {
                        {
                            service: ($svc | str upcase),
                            test_name: $test_func,
                            status: "✅ PASS",
                            duration: $duration,
                            error: ""
                        }
                    } else if not $mock {
                        # Real mode - any valid response is good
                        {
                            service: ($svc | str upcase),
                            test_name: $test_func,
                            status: "✅ PASS",
                            duration: $duration,
                            error: ""
                        }
                    } else {
                        {
                            service: ($svc | str upcase),
                            test_name: $test_func,
                            status: "❌ FAIL",
                            duration: $duration,
                            error: "No mock flag found"
                        }
                    }
                } catch { |error|
                    {
                        service: ($svc | str upcase),
                        test_name: $test_func,
                        status: "❌ FAIL",
                        duration: "0ms",
                        error: $error.msg
                    }
                }
            })
            
            let passed = ($function_results | where status == "✅ PASS" | length)
            let total = ($function_results | length)
            print $"   Results: ($passed)/($total) passed"
            
            $function_results
            
        } catch { |error|
            print $"   ❌ Error testing service: ($error.msg)"
            [{
                service: ($svc | str upcase),
                test_name: "Service test",
                status: "❌ ERROR",
                duration: "0ms",
                error: $error.msg
            }]
        }
    } | flatten)
    
    print "\n============================================================"
    print "📊 TEST RESULTS SUMMARY"
    print "============================================================"
    
    # Output results based on format
    match $format {
        "table" => {
            print ""
            $test_results | table
            
            print "\n📈 Summary Statistics:"
            let total_tests = ($test_results | length)
            let passed_tests = ($test_results | where status == "✅ PASS" | length)
            let failed_tests = ($test_results | where status == "❌ FAIL" | length)
            let error_tests = ($test_results | where status == "❌ ERROR" | length)
            
            [
                {metric: "Total Tests", value: $total_tests},
                {metric: "✅ Passed", value: $passed_tests},
                {metric: "❌ Failed", value: $failed_tests},
                {metric: "🚫 Errors", value: $error_tests},
                {metric: "Success Rate", value: $"(($passed_tests / $total_tests) * 100 | math round)%"}
            ] | table
            
            # Service breakdown
            print "\n🔍 Service Breakdown:"
            $test_results 
            | group-by service 
            | transpose service tests
            | each { |row|
                let service_tests = $row.tests
                let service_passed = ($service_tests | where status == "✅ PASS" | length)
                let service_total = ($service_tests | length)
                {
                    service: $row.service,
                    total: $service_total,
                    passed: $service_passed,
                    success_rate: $"(($service_passed / $service_total) * 100 | math round)%"
                }
            } | table
        },
        "json" => {
            $test_results | to json
        },
        "summary" => {
            let total_tests = ($test_results | length)
            let passed_tests = ($test_results | where status == "✅ PASS" | length)
            let failed_tests = ($test_results | where status == "❌ FAIL" | length)
            
            print $"Total: ($total_tests) | Passed: ($passed_tests) | Failed: ($failed_tests)"
            print $"Success Rate: (($passed_tests / $total_tests) * 100 | math round)%"
        }
    }
    
    if $verbose and ($test_results | where status != "✅ PASS" | length) > 0 {
        print "\n🔍 Failed/Error Test Details:"
        $test_results | where status != "✅ PASS" | each { |result|
            print $"❌ ($result.service) - ($result.test_name): ($result.error)"
        }
    }
    
    let failed_count = ($test_results | where status != "✅ PASS" | length)
    if $failed_count == 0 {
        print "\n🎉 ALL TESTS PASSED! AWS modules are working correctly."
    } else {
        print $"\n⚠️  ($failed_count) tests failed or had errors."
    }
    
    # Return structured data for further processing
    $test_results
}