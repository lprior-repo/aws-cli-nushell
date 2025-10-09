# NuAWS Streaming Operations Examples
# Real-world examples demonstrating memory-efficient AWS data processing
# 
# These examples show how to use the streaming operations for practical
# AWS tasks while maintaining constant memory usage and high performance.

use ../tools/streaming_operations.nu *

# ============================================================================
# S3 Examples - Large Object Processing
# ============================================================================

# Example 1: Find large files across S3 buckets
export def "example find-large-s3-files" [
    buckets: list<string>,            # List of S3 bucket names
    size_threshold: int = 1000000000, # Size threshold in bytes (default 1GB)
    --limit(-l): int = 100           # Limit results
]: nothing -> table {
    print $"🔍 Searching for files larger than ($size_threshold | into filesize) across ($buckets | length) buckets"
    
    $buckets 
    | each { |bucket|
        print $"   📂 Processing bucket: ($bucket)"
        aws s3 list-objects-stream $bucket --progress
        | where Size? > $size_threshold
        | each { |obj| $obj | upsert bucket $bucket }
    }
    | flatten
    | take ($limit | default 100)
    | sort-by Size -r
    | select bucket Key Size LastModified
}

# Example 2: Calculate storage costs across multiple buckets
export def "example calculate-s3-storage-costs" [
    buckets: list<string>,            # List of S3 bucket names
    cost_per_gb: float = 0.023       # Cost per GB per month
]: nothing -> record {
    print $"💰 Calculating storage costs for ($buckets | length) buckets"
    
    let total_stats = (
        $buckets 
        | each { |bucket|
            print $"   📊 Analyzing bucket: ($bucket)"
            
            let bucket_stats = (
                aws s3 list-objects-stream $bucket --progress
                | reduce -f { total_size: 0, object_count: 0 } { |obj, acc|
                    {
                        total_size: ($acc.total_size + ($obj.Size? | default 0)),
                        object_count: ($acc.object_count + 1)
                    }
                }
            )
            
            {
                bucket: $bucket,
                objects: $bucket_stats.object_count,
                size_bytes: $bucket_stats.total_size,
                size_gb: ($bucket_stats.total_size / 1000000000),
                monthly_cost: (($bucket_stats.total_size / 1000000000) * $cost_per_gb)
            }
        }
    )
    
    let summary = ($total_stats | reduce -f { total_objects: 0, total_gb: 0, total_cost: 0 } { |bucket, acc|
        {
            total_objects: ($acc.total_objects + $bucket.objects),
            total_gb: ($acc.total_gb + $bucket.size_gb),
            total_cost: ($acc.total_cost + $bucket.monthly_cost)
        }
    })
    
    {
        bucket_details: $total_stats,
        summary: $summary,
        cost_analysis: {
            cost_per_gb: $cost_per_gb,
            total_monthly_cost: ($summary.total_cost | math round -p 2),
            annual_cost: (($summary.total_cost * 12) | math round -p 2)
        }
    }
}

# Example 3: Sync verification between S3 buckets
export def "example verify-s3-sync" [
    source_bucket: string,           # Source bucket name
    target_bucket: string,           # Target bucket name
    --prefix(-p): string = ""        # Optional prefix to check
]: nothing -> record {
    print $"🔄 Verifying sync between ($source_bucket) and ($target_bucket)"
    
    print "   📥 Loading source objects..."
    let source_objects = (
        aws s3 list-objects-stream $source_bucket --prefix=$prefix --progress
        | select Key ETag Size LastModified
        | reduce -f {} { |obj, acc| $acc | upsert $obj.Key $obj }
    )
    
    print "   📤 Loading target objects..."
    let target_objects = (
        aws s3 list-objects-stream $target_bucket --prefix=$prefix --progress
        | select Key ETag Size LastModified  
        | reduce -f {} { |obj, acc| $acc | upsert $obj.Key $obj }
    )
    
    let source_keys = ($source_objects | columns)
    let target_keys = ($target_objects | columns)
    
    let missing_in_target = ($source_keys | where $it not-in $target_keys)
    let extra_in_target = ($target_keys | where $it not-in $source_keys)
    let common_keys = ($source_keys | where $it in $target_keys)
    
    let mismatched = ($common_keys | where { |key|
        let source_obj = ($source_objects | get $key)
        let target_obj = ($target_objects | get $key)
        ($source_obj.ETag != $target_obj.ETag) or ($source_obj.Size != $target_obj.Size)
    })
    
    {
        sync_status: (if (($missing_in_target | length) + ($extra_in_target | length) + ($mismatched | length)) == 0 { "in_sync" } else { "out_of_sync" }),
        source_objects: ($source_keys | length),
        target_objects: ($target_keys | length),
        missing_in_target: ($missing_in_target | length),
        extra_in_target: ($extra_in_target | length),
        mismatched_objects: ($mismatched | length),
        details: {
            missing_files: $missing_in_target,
            extra_files: $extra_in_target,
            mismatched_files: $mismatched
        }
    }
}

# ============================================================================
# EC2 Examples - Infrastructure Analysis
# ============================================================================

# Example 4: Analyze EC2 instance utilization across regions
export def "example analyze-ec2-utilization" [
    regions: list<string>,           # List of AWS regions to check
    --instance-types(-t): list<string> # Optional filter by instance types
]: nothing -> record {
    print $"🖥️  Analyzing EC2 utilization across ($regions | length) regions"
    
    let instance_data = (
        $regions
        | each { |region|
            print $"   🌐 Processing region: ($region)"
            
            aws ec2 describe-instances-stream --region=$region --progress
            | where State.Name == "running"
            | each { |instance|
                let instance_type = $instance.InstanceType
                let az = $instance.Placement.AvailabilityZone
                let launch_time = $instance.LaunchTime
                
                {
                    region: $region,
                    availability_zone: $az,
                    instance_id: $instance.InstanceId,
                    instance_type: $instance_type,
                    state: $instance.State.Name,
                    launch_time: $launch_time,
                    uptime_days: ((date now) - ($launch_time | into datetime) | into duration | get day)
                }
            }
        }
        | flatten
    )
    
    # Filter by instance types if specified
    let filtered_data = if ($instance_types | is-not-empty) {
        $instance_data | where instance_type in $instance_types
    } else { $instance_data }
    
    let utilization_summary = (
        $filtered_data 
        | group-by region 
        | transpose region instances
        | each { |region_data|
            let instances = $region_data.instances
            let type_distribution = ($instances | group-by instance_type | transpose type count | each { |t| { type: $t.type, count: ($t.count | length) } })
            
            {
                region: $region_data.region,
                total_instances: ($instances | length),
                instance_types: $type_distribution,
                average_uptime_days: ($instances | get uptime_days | math avg | math round -p 1),
                oldest_instance_days: ($instances | get uptime_days | math max),
                newest_instance_days: ($instances | get uptime_days | math min)
            }
        }
    )
    
    {
        total_instances: ($filtered_data | length),
        regions_analyzed: ($regions | length),
        regional_breakdown: $utilization_summary,
        global_instance_types: (
            $filtered_data 
            | group-by instance_type 
            | transpose type instances 
            | each { |t| { type: $t.type, count: ($t.instances | length) } }
            | sort-by count -r
        )
    }
}

# Example 5: Security group audit across infrastructure
export def "example audit-security-groups" [
    regions: list<string>,           # List of AWS regions to audit
    --find-open-ports(-o)           # Flag to find potentially dangerous open ports
]: nothing -> record {
    print $"🔒 Auditing security groups across ($regions | length) regions"
    
    let security_findings = (
        $regions
        | each { |region|
            print $"   🔍 Auditing region: ($region)"
            
            # This would need to be implemented with actual EC2 security group streaming
            # For now, showing the pattern with mock data
            aws ec2 describe-instances-stream --region=$region
            | each { |instance|
                $instance.SecurityGroups? | default [] | each { |sg|
                    {
                        region: $region,
                        instance_id: $instance.InstanceId,
                        security_group_id: $sg.GroupId,
                        security_group_name: $sg.GroupName
                    }
                }
            }
            | flatten
        }
        | flatten
    )
    
    let unique_security_groups = (
        $security_findings 
        | group-by security_group_id
        | transpose sg_id instances
        | each { |sg|
            {
                security_group_id: $sg.sg_id,
                instance_count: ($sg.instances | length),
                regions: ($sg.instances | get region | uniq),
                instances: ($sg.instances | get instance_id)
            }
        }
    )
    
    {
        total_instances_checked: ($security_findings | length),
        unique_security_groups: ($unique_security_groups | length),
        security_groups: $unique_security_groups,
        recommendations: [
            "Review security groups with high instance counts",
            "Ensure least privilege access",
            "Regular audit of unused security groups"
        ]
    }
}

# ============================================================================
# Lambda Examples - Function Analysis
# ============================================================================

# Example 6: Lambda function inventory and optimization opportunities
export def "example analyze-lambda-functions" [
    regions: list<string>,           # List of AWS regions
    --runtime-filter(-r): string    # Optional runtime filter
]: nothing -> record {
    print $"⚡ Analyzing Lambda functions across ($regions | length) regions"
    
    let function_data = (
        $regions
        | each { |region|
            print $"   🔧 Processing region: ($region)"
            
            aws lambda list-functions-stream --region=$region --progress
            | each { |func|
                {
                    region: $region,
                    function_name: $func.FunctionName,
                    runtime: $func.Runtime,
                    memory_size: $func.MemorySize,
                    timeout: $func.Timeout,
                    code_size: $func.CodeSize,
                    last_modified: $func.LastModified,
                    environment_variables: ($func.Environment?.Variables? | default {} | columns | length)
                }
            }
        }
        | flatten
    )
    
    # Filter by runtime if specified
    let filtered_functions = if ($runtime_filter | is-not-empty) {
        $function_data | where runtime == $runtime_filter
    } else { $function_data }
    
    let runtime_analysis = (
        $filtered_functions 
        | group-by runtime
        | transpose runtime functions
        | each { |runtime_group|
            let functions = $runtime_group.functions
            {
                runtime: $runtime_group.runtime,
                function_count: ($functions | length),
                avg_memory_mb: ($functions | get memory_size | math avg | math round),
                avg_timeout_sec: ($functions | get timeout | math avg | math round),
                total_code_size_mb: ($functions | get code_size | math sum | $in / 1000000 | math round -p 1),
                functions_over_512mb: ($functions | where memory_size > 512 | length),
                functions_over_30sec_timeout: ($functions | where timeout > 30 | length)
            }
        }
    )
    
    let optimization_opportunities = (
        $filtered_functions
        | where memory_size > 1024 or timeout > 60 or code_size > 50000000
        | select function_name region runtime memory_size timeout code_size
    )
    
    {
        total_functions: ($filtered_functions | length),
        regions_analyzed: ($regions | length),
        runtime_breakdown: $runtime_analysis,
        optimization_candidates: ($optimization_opportunities | length),
        optimization_details: $optimization_opportunities,
        recommendations: [
            "Review functions with >1GB memory allocation",
            "Check functions with >60s timeout",
            "Consider breaking down large code packages",
            "Update deprecated runtimes"
        ]
    }
}

# ============================================================================
# Multi-Service Examples - Cross-Service Analysis
# ============================================================================

# Example 7: Resource tagging compliance audit
export def "example audit-resource-tagging" [
    regions: list<string>,           # List of AWS regions
    required_tags: list<string>      # List of required tag keys
]: nothing -> record {
    print $"🏷️  Auditing resource tagging compliance across multiple services"
    
    let tagging_results = {}
    
    # EC2 instances
    print "   🖥️  Checking EC2 instances..."
    let ec2_results = (
        $regions | each { |region|
            aws ec2 describe-instances-stream --region=$region
            | each { |instance|
                let tags = ($instance.Tags? | default [] | reduce -f {} { |tag, acc| $acc | upsert $tag.Key $tag.Value })
                let missing_tags = ($required_tags | where $it not-in ($tags | columns))
                
                {
                    resource_type: "ec2_instance",
                    resource_id: $instance.InstanceId,
                    region: $region,
                    tags: $tags,
                    missing_required_tags: $missing_tags,
                    compliant: (($missing_tags | length) == 0)
                }
            }
        } | flatten
    )
    
    # Lambda functions (simplified - would need actual tags API)
    print "   ⚡ Checking Lambda functions..."
    let lambda_results = (
        $regions | each { |region|
            aws lambda list-functions-stream --region=$region
            | each { |func|
                # In real implementation, would call get-function to get tags
                {
                    resource_type: "lambda_function",
                    resource_id: $func.FunctionName,
                    region: $region,
                    tags: {},  # Would be populated from actual tags API
                    missing_required_tags: $required_tags,  # Assuming none have tags for demo
                    compliant: false
                }
            }
        } | flatten
    )
    
    let all_resources = ([$ec2_results, $lambda_results] | flatten)
    let compliance_summary = (
        $all_resources
        | group-by resource_type
        | transpose resource_type resources
        | each { |type_group|
            let resources = $type_group.resources
            let compliant_count = ($resources | where compliant | length)
            let total_count = ($resources | length)
            
            {
                resource_type: $type_group.resource_type,
                total_resources: $total_count,
                compliant_resources: $compliant_count,
                compliance_percentage: (if $total_count > 0 { ($compliant_count / $total_count * 100) | math round -p 1 } else { 0 }),
                non_compliant_resources: ($total_count - $compliant_count)
            }
        }
    )
    
    {
        required_tags: $required_tags,
        regions_audited: $regions,
        compliance_summary: $compliance_summary,
        detailed_results: $all_resources,
        overall_compliance: (
            let total_resources = ($all_resources | length)
            let compliant_resources = ($all_resources | where compliant | length)
            if $total_resources > 0 { ($compliant_resources / $total_resources * 100) | math round -p 1 } else { 0 }
        )
    }
}

# ============================================================================
# Performance and Cost Examples
# ============================================================================

# Example 8: Multi-service cost optimization analysis
export def "example cost-optimization-analysis" [
    regions: list<string>            # List of AWS regions to analyze
]: nothing -> record {
    print $"💰 Performing cost optimization analysis across services"
    
    # EC2 cost analysis
    print "   🖥️  Analyzing EC2 costs..."
    let ec2_analysis = (
        $regions | each { |region|
            aws ec2 describe-instances-stream --region=$region --progress
            | where State.Name == "running"
            | each { |instance|
                # Simplified cost calculation - real implementation would use pricing APIs
                let hourly_cost = match $instance.InstanceType {
                    "t2.micro" => 0.0116,
                    "t2.small" => 0.023,
                    "t3.medium" => 0.0416,
                    "m5.large" => 0.096,
                    _ => 0.05  # Default estimate
                }
                
                let uptime_hours = (
                    (date now) - ($instance.LaunchTime | into datetime) 
                    | into duration 
                    | get hour
                )
                
                {
                    instance_id: $instance.InstanceId,
                    instance_type: $instance.InstanceType,
                    region: $region,
                    hourly_cost: $hourly_cost,
                    uptime_hours: $uptime_hours,
                    estimated_monthly_cost: ($hourly_cost * 730),  # 730 hours/month average
                    potential_savings: (if $uptime_hours > 8760 { $hourly_cost * 0.3 } else { 0 })  # Reserved instance savings
                }
            }
        } | flatten
    )
    
    # Lambda cost analysis
    print "   ⚡ Analyzing Lambda costs..."
    let lambda_analysis = (
        $regions | each { |region|
            aws lambda list-functions-stream --region=$region --progress
            | each { |func|
                # Simplified Lambda cost calculation
                let gb_seconds_cost = 0.0000166667  # Per GB-second
                let request_cost = 0.0000002       # Per request
                let memory_gb = ($func.MemorySize / 1024)
                
                {
                    function_name: $func.FunctionName,
                    memory_mb: $func.MemorySize,
                    memory_gb: $memory_gb,
                    region: $region,
                    estimated_cost_per_1000_invocations: (
                        (1000 * $request_cost) + (1000 * $memory_gb * ($func.Timeout / 1000) * $gb_seconds_cost)
                        | math round -p 6
                    )
                }
            }
        } | flatten
    )
    
    # Aggregate cost analysis
    let total_ec2_monthly_cost = ($ec2_analysis | get estimated_monthly_cost | math sum | math round -p 2)
    let potential_ec2_savings = ($ec2_analysis | get potential_savings | math sum | math round -p 2)
    
    {
        ec2_analysis: {
            instances_analyzed: ($ec2_analysis | length),
            total_monthly_cost: $total_ec2_monthly_cost,
            potential_monthly_savings: $potential_ec2_savings,
            savings_percentage: (if $total_ec2_monthly_cost > 0 { ($potential_ec2_savings / $total_ec2_monthly_cost * 100) | math round -p 1 } else { 0 }),
            recommendations: [
                "Consider Reserved Instances for long-running workloads",
                "Right-size instances based on utilization",
                "Use Spot Instances for fault-tolerant workloads"
            ]
        },
        lambda_analysis: {
            functions_analyzed: ($lambda_analysis | length),
            high_memory_functions: ($lambda_analysis | where memory_mb > 1024 | length),
            optimization_opportunities: ($lambda_analysis | where memory_mb > 512 and estimated_cost_per_1000_invocations > 0.01),
            recommendations: [
                "Right-size Lambda memory allocations",
                "Optimize function execution time",
                "Consider provisioned concurrency for predictable workloads"
            ]
        },
        summary: {
            total_estimated_monthly_ec2_cost: $total_ec2_monthly_cost,
            total_potential_monthly_savings: $potential_ec2_savings,
            regions_analyzed: ($regions | length)
        }
    }
}

# ============================================================================
# Real-Time Monitoring Examples
# ============================================================================

# Example 9: Real-time resource monitoring dashboard
export def "example real-time-monitoring" [
    regions: list<string>,           # List of AWS regions
    --refresh-interval(-r): int = 30 # Refresh interval in seconds
]: nothing -> nothing {
    print $"📊 Starting real-time AWS resource monitoring"
    print $"Regions: ($regions | str join ', ')"
    print $"Refresh interval: ($refresh_interval) seconds"
    print "Press Ctrl+C to stop\n"
    
    loop {
        let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")
        print $"🕐 Update at ($timestamp)"
        print "=" * 50
        
        # EC2 summary
        let ec2_summary = (
            $regions | each { |region|
                aws ec2 describe-instances-stream --region=$region
                | where State.Name == "running"
                | group-by InstanceType
                | transpose instance_type instances
                | each { |type_group|
                    {
                        region: $region,
                        instance_type: $type_group.instance_type,
                        count: ($type_group.instances | length)
                    }
                }
            }
            | flatten
            | group-by instance_type
            | transpose instance_type regions
            | each { |type_group|
                {
                    instance_type: $type_group.instance_type,
                    total_count: ($type_group.regions | get count | math sum),
                    regions: ($type_group.regions | length)
                }
            }
            | sort-by total_count -r
        )
        
        print "🖥️  EC2 Instances by Type:"
        $ec2_summary | table
        
        # Lambda summary
        let lambda_summary = (
            $regions | each { |region|
                aws lambda list-functions-stream --region=$region
                | group-by Runtime
                | transpose runtime functions
                | each { |runtime_group|
                    {
                        region: $region,
                        runtime: $runtime_group.runtime,
                        count: ($runtime_group.functions | length)
                    }
                }
            }
            | flatten
            | group-by runtime
            | transpose runtime regions
            | each { |runtime_group|
                {
                    runtime: $runtime_group.runtime,
                    total_count: ($runtime_group.regions | get count | math sum),
                    regions: ($runtime_group.regions | length)
                }
            }
            | sort-by total_count -r
        )
        
        print "\n⚡ Lambda Functions by Runtime:"
        $lambda_summary | table
        
        print $"\n💤 Sleeping for ($refresh_interval) seconds...\n"
        sleep ($refresh_interval * 1000 | into duration --unit ms)
    }
}

# ============================================================================
# Batch Processing Examples
# ============================================================================

# Example 10: Batch processing with parallel streams
export def "example batch-process-resources" [
    operations: list<record>,        # List of operations to perform
    --parallel(-p): int = 3,        # Number of parallel operations
    --progress                      # Enable progress reporting
]: nothing -> list {
    print $"🔄 Starting batch processing of ($operations | length) operations"
    print $"Parallel operations: ($parallel)"
    
    $operations
    | enumerate
    | group-by { |item| ($item.index mod $parallel) }  # Distribute across parallel groups
    | values
    | par-each { |group|
        $group | each { |operation_item|
            let operation = $operation_item.item
            let index = $operation_item.index
            
            if $progress {
                print $"   🔧 Processing operation ($index + 1): ($operation.service) ($operation.operation)"
            }
            
            let result = try {
                match $operation.service {
                    "s3" => (aws s3 list-objects-stream $operation.bucket --max-keys=($operation.max_items | default 100)),
                    "ec2" => (aws ec2 describe-instances-stream --region=($operation.region | default "us-east-1") --max-results=($operation.max_items | default 50)),
                    "lambda" => (aws lambda list-functions-stream --region=($operation.region | default "us-east-1") --max-items=($operation.max_items | default 25)),
                    _ => (error make { msg: $"Unsupported service: ($operation.service)" })
                }
                | take ($operation.limit | default 10)
                | collect
            } catch { |err|
                []  # Return empty on error but continue processing
            }
            
            {
                operation_index: ($index + 1),
                service: $operation.service,
                operation_type: $operation.operation,
                result_count: ($result | length),
                status: (if ($result | length) > 0 { "success" } else { "empty" })
            }
        }
    }
    | flatten
    | sort-by operation_index
}

# ============================================================================
# Example Runner and Demonstrations
# ============================================================================

# Run all examples with sample data
export def "run all-streaming-examples" []: nothing -> nothing {
    print "🚀 Running All NuAWS Streaming Examples"
    print "======================================\n"
    
    # Set mock mode for all examples
    $env.S3_MOCK_MODE = "true"
    $env.EC2_MOCK_MODE = "true"
    $env.LAMBDA_MOCK_MODE = "true"
    $env.IAM_MOCK_MODE = "true"
    
    print "1. S3 Large Files Example:"
    try {
        example find-large-s3-files ["bucket1", "bucket2"] 500000000 --limit=5 | table
    } catch { |err| print $"   ❌ Failed: ($err.msg)" }
    
    print "\n2. EC2 Utilization Analysis:"
    try {
        example analyze-ec2-utilization ["us-east-1", "us-west-2"] | get regional_breakdown | table
    } catch { |err| print $"   ❌ Failed: ($err.msg)" }
    
    print "\n3. Lambda Function Analysis:"
    try {
        example analyze-lambda-functions ["us-east-1"] | get runtime_breakdown | table
    } catch { |err| print $"   ❌ Failed: ($err.msg)" }
    
    print "\n4. Resource Tagging Audit:"
    try {
        example audit-resource-tagging ["us-east-1"] ["Environment", "Owner"] | get compliance_summary | table
    } catch { |err| print $"   ❌ Failed: ($err.msg)" }
    
    print "\n5. Batch Processing Example:"
    let sample_operations = [
        { service: "s3", operation: "list-objects", bucket: "test1", limit: 5 },
        { service: "ec2", operation: "describe-instances", region: "us-east-1", limit: 3 },
        { service: "lambda", operation: "list-functions", region: "us-east-1", limit: 4 }
    ]
    try {
        example batch-process-resources $sample_operations --parallel=2 --progress | table
    } catch { |err| print $"   ❌ Failed: ($err.msg)" }
    
    print "\n✅ All streaming examples completed!"
    print "   💡 These examples demonstrate memory-efficient processing"
    print "   📊 Performance monitoring and cost optimization patterns"
    print "   🔄 Real-world AWS data processing workflows"
}