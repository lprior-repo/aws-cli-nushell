# EC2 Enhanced Features for NuAWS
# Comprehensive EC2 lifecycle management, security analysis, cost optimization,
# CloudWatch metrics integration, and VPC network topology analysis
#
# This module provides pure functional programming patterns with streaming operations,
# comprehensive error handling with spans, and Nushell-native data structures
# optimized for pipeline operations.

use errors.nu *
use functional.nu *

# ============================================================================
# Core EC2 Enhanced Configuration and Types
# ============================================================================

# EC2 Enhanced configuration with mock support
export def get-ec2-enhanced-config []: nothing -> record {
    {
        mock_mode: ($env.EC2_ENHANCED_MOCK_MODE? | default false | into bool),
        aws_region: ($env.AWS_REGION? | default "us-east-1"),
        max_concurrent_operations: ($env.EC2_MAX_CONCURRENT? | default 10 | into int),
        cloudwatch_metrics_enabled: true,
        cost_optimization_enabled: true,
        security_analysis_enabled: true,
        vpc_topology_enabled: true,
        streaming_chunk_size: ($env.EC2_STREAM_CHUNK_SIZE? | default 50 | into int),
        cache_ttl_seconds: ($env.EC2_CACHE_TTL? | default 300 | into int)
    }
}

# Instance lifecycle states for type safety
def get-instance-lifecycle-states []: nothing -> list<string> {
    ["pending", "running", "shutting-down", "terminated", "stopping", "stopped"]
}

# Security group rule analysis types
def get-security-analysis-types []: nothing -> list<string> {
    ["excessive-permissions", "unused-groups", "insecure-protocols", "wide-open-access", "redundant-rules"]
}

# Cost optimization recommendation types  
def get-cost-optimization-types []: nothing -> list<string> {
    ["rightsizing", "scheduling", "reserved-instances", "spot-instances", "storage-optimization"]
}

# ============================================================================
# Instance Lifecycle Management
# ============================================================================

# Start EC2 instances with batch operations and streaming support
export def "ec2 start-instances-enhanced" [
    instance_ids: list<string>,              # List of instance IDs to start
    --batch-size(-b): int = 10,             # Batch size for operations
    --wait(-w),                             # Wait for instances to reach running state
    --dry-run(-d),                          # Perform dry run without actual changes
    --span: any                             # Optional span for error reporting
]: nothing -> table<instance_id: string, previous_state: string, current_state: string, result: string> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-start-instances $instance_ids $batch_size $wait $dry_run)
    }
    
    # Validate instance IDs format
    $instance_ids | each { |id|
        if not ($id | str starts-with "i-") {
            make-aws-error "VALIDATION" "InvalidInstanceId" 
                $"Invalid instance ID format: ($id)" 
                "start-instances-enhanced" "ec2" --span $span
        }
    }
    
    # Process instances in batches with streaming
    let total_batches = (($instance_ids | length) / $batch_size | math ceil)
    
    $instance_ids 
    | chunks $batch_size 
    | enumerate 
    | each { |batch|
        print $"Processing batch ($batch.index + 1)/($total_batches) with ($batch.item | length) instances..."
        
        try {
            let batch_result = if $dry_run {
                perform-start-instances-dry-run $batch.item
            } else {
                perform-start-instances-batch $batch.item $wait
            }
            
            $batch_result | each { |result|
                $result | upsert batch_number ($batch.index + 1)
            }
        } catch { |err|
            make-aws-error "RESOURCE" "BatchOperationFailed" 
                $"Failed to process batch ($batch.index + 1): ($err.msg)" 
                "start-instances-enhanced" "ec2" --span $span
        }
    } 
    | flatten
    | select instance_id previous_state current_state result
}

# Stop EC2 instances with batch operations and streaming support
export def "ec2 stop-instances-enhanced" [
    instance_ids: list<string>,              # List of instance IDs to stop
    --batch-size(-b): int = 10,             # Batch size for operations
    --force(-f),                            # Force stop instances
    --wait(-w),                             # Wait for instances to reach stopped state
    --dry-run(-d),                          # Perform dry run without actual changes
    --span: any                             # Optional span for error reporting
]: nothing -> table<instance_id: string, previous_state: string, current_state: string, result: string> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-stop-instances $instance_ids $batch_size $force $wait $dry_run)
    }
    
    # Validate instance IDs and check current states
    let instance_states = get-instance-states $instance_ids
    let invalid_states = $instance_states | where current_state in ["terminated", "terminating"]
    
    if ($invalid_states | length) > 0 {
        let invalid_ids = $invalid_states | get instance_id | str join ", "
        make-aws-error "RESOURCE" "InvalidInstanceState" 
            $"Cannot stop instances in invalid states: ($invalid_ids)" 
            "stop-instances-enhanced" "ec2" --span $span
    }
    
    # Process instances in batches
    $instance_ids 
    | chunks $batch_size 
    | enumerate 
    | each { |batch|
        print $"Stopping batch ($batch.index + 1) with ($batch.item | length) instances..."
        
        try {
            if $dry_run {
                perform-stop-instances-dry-run $batch.item $force
            } else {
                perform-stop-instances-batch $batch.item $force $wait
            }
        } catch { |err|
            make-aws-error "RESOURCE" "BatchOperationFailed" 
                $"Failed to stop batch ($batch.index + 1): ($err.msg)" 
                "stop-instances-enhanced" "ec2" --span $span
        }
    } 
    | flatten
    | select instance_id previous_state current_state result
}

# Terminate EC2 instances with enhanced safety checks
export def "ec2 terminate-instances-enhanced" [
    instance_ids: list<string>,              # List of instance IDs to terminate
    --batch-size(-b): int = 10,             # Batch size for operations
    --disable-api-termination-check,        # Skip API termination protection check
    --force(-f),                            # Skip confirmation prompts
    --dry-run(-d),                          # Perform dry run without actual changes
    --span: any                             # Optional span for error reporting
]: nothing -> table<instance_id: string, previous_state: string, current_state: string, result: string, warnings: list<string>> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-terminate-instances $instance_ids $batch_size $disable_api_termination_check $force $dry_run)
    }
    
    # Enhanced safety checks before termination
    let safety_checks = perform-termination-safety-checks $instance_ids $disable_api_termination_check
    let protected_instances = $safety_checks | where api_termination_enabled == false | get instance_id
    
    if ($protected_instances | length) > 0 and not $disable_api_termination_check {
        let protected_ids = $protected_instances | str join ", "
        make-aws-error "AUTHORIZATION" "OperationNotPermitted" 
            $"Instances have termination protection enabled: ($protected_ids)" 
            "terminate-instances-enhanced" "ec2" --span $span
    }
    
    # Confirmation prompt for non-force mode
    if not $force and not $dry_run {
        print $"⚠️  WARNING: This will permanently terminate ($instance_ids | length) instances"
        let confirm = input "Type 'DELETE' to confirm termination: "
        if $confirm != "DELETE" {
            return [{
                instance_id: "cancelled",
                previous_state: "N/A", 
                current_state: "N/A",
                result: "operation_cancelled",
                warnings: ["Operation cancelled by user"]
            }]
        }
    }
    
    # Process termination in batches
    $instance_ids 
    | chunks $batch_size 
    | enumerate 
    | each { |batch|
        print $"Terminating batch ($batch.index + 1) with ($batch.item | length) instances..."
        
        try {
            if $dry_run {
                perform-terminate-instances-dry-run $batch.item
            } else {
                perform-terminate-instances-batch $batch.item
            }
        } catch { |err|
            make-aws-error "RESOURCE" "BatchOperationFailed" 
                $"Failed to terminate batch ($batch.index + 1): ($err.msg)" 
                "terminate-instances-enhanced" "ec2" --span $span
        }
    } 
    | flatten
    | select instance_id previous_state current_state result warnings
}

# ============================================================================
# Security Group Analysis and Optimization
# ============================================================================

# Analyze security groups for potential security issues and optimization opportunities
export def "ec2 analyze-security-groups" [
    --group-ids(-g): list<string> = [],     # Specific security group IDs to analyze
    --vpc-id(-v): string,                   # Analyze security groups in specific VPC
    --analysis-types(-a): list<string> = [], # Types of analysis to perform
    --severity-threshold(-s): string = "medium", # Minimum severity to report (low, medium, high, critical)
    --output-format(-o): string = "table",  # Output format (table, json, detailed)
    --span: any                             # Optional span for error reporting
]: nothing -> table<group_id: string, group_name: string, issue_type: string, severity: string, description: string, recommendation: string> {
    let config = get-ec2-enhanced-config
    
    if not $config.security_analysis_enabled {
        make-aws-error "VALIDATION" "FeatureDisabled" 
            "Security analysis is disabled in configuration" 
            "analyze-security-groups" "ec2" --span $span
    }
    
    if $config.mock_mode {
        return (mock-security-group-analysis $group_ids $vpc_id $analysis_types $severity_threshold)
    }
    
    # Get security groups to analyze
    let target_groups = if ($group_ids | length) > 0 {
        get-security-groups-by-ids $group_ids
    } else if ($vpc_id | is-not-empty) {
        get-security-groups-by-vpc $vpc_id
    } else {
        get-all-security-groups
    }
    
    # Determine analysis types to perform
    let analysis_to_run = if ($analysis_types | length) > 0 {
        $analysis_types
    } else {
        get-security-analysis-types
    }
    
    print $"Analyzing ($target_groups | length) security groups with ($analysis_to_run | length) analysis types..."
    
    # Perform security analysis with streaming processing
    $target_groups 
    | chunks ($config.streaming_chunk_size)
    | each { |chunk|
        $chunk | par-each { |sg|
            analyze-security-group-issues $sg $analysis_to_run $severity_threshold
        } --threads ($config.max_concurrent_operations)
    }
    | flatten
    | where severity in (get-severity-levels-above $severity_threshold)
    | sort-by severity group_id
    | format-security-analysis-output $output_format
}

# Generate security group optimization recommendations
export def "ec2 optimize-security-groups" [
    --group-ids(-g): list<string> = [],     # Specific security group IDs to optimize
    --vpc-id(-v): string,                   # Optimize security groups in specific VPC
    --optimization-types(-t): list<string> = [], # Types of optimizations to suggest
    --cost-impact(-c),                      # Include cost impact analysis
    --implementation-plan(-p),              # Generate step-by-step implementation plan
    --span: any                             # Optional span for error reporting
]: nothing -> table<group_id: string, optimization_type: string, current_state: string, recommended_state: string, estimated_risk: string, estimated_savings: string, implementation_steps: list<string>> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-security-group-optimization $group_ids $vpc_id $optimization_types $cost_impact)
    }
    
    # Get security groups for optimization
    let target_groups = if ($group_ids | length) > 0 {
        get-security-groups-by-ids $group_ids
    } else if ($vpc_id | is-not-empty) {
        get-security-groups-by-vpc $vpc_id
    } else {
        get-all-security-groups
    }
    
    # Generate optimization recommendations
    $target_groups 
    | par-each { |sg|
        generate-security-group-optimizations $sg $optimization_types $cost_impact $implementation_plan
    } --threads ($config.max_concurrent_operations)
    | flatten
    | sort-by estimated_savings group_id
}

# ============================================================================
# Cost Optimization Recommendations
# ============================================================================

# Analyze EC2 instances for cost optimization opportunities
export def "ec2 analyze-cost-optimization" [
    --instance-ids(-i): list<string> = [], # Specific instances to analyze
    --region(-r): string,                  # Analyze instances in specific region
    --optimization-types(-t): list<string> = [], # Types of cost optimizations
    --lookback-days(-l): int = 30,         # Days of historical data to analyze
    --savings-threshold(-s): int = 10,     # Minimum percentage savings to recommend
    --include-scheduling(-c),              # Include scheduling recommendations
    --include-rightsizing(-z),             # Include rightsizing recommendations
    --span: any                            # Optional span for error reporting
]: nothing -> table<instance_id: string, instance_type: string, optimization_type: string, current_monthly_cost: float, estimated_monthly_cost: float, estimated_savings: float, confidence: string, recommendation: string> {
    let config = get-ec2-enhanced-config
    
    if not $config.cost_optimization_enabled {
        make-aws-error "VALIDATION" "FeatureDisabled" 
            "Cost optimization analysis is disabled in configuration" 
            "analyze-cost-optimization" "ec2" --span $span
    }
    
    if $config.mock_mode {
        return (mock-cost-optimization-analysis $instance_ids $region $optimization_types $lookback_days $savings_threshold)
    }
    
    # Get instances for cost analysis
    let target_instances = get-instances-for-cost-analysis $instance_ids $region
    
    # Get CloudWatch metrics for the lookback period
    let metrics_data = get-cloudwatch-metrics-for-instances $target_instances $lookback_days
    
    # Determine optimization types to analyze
    let optimization_to_run = if ($optimization_types | length) > 0 {
        $optimization_types
    } else {
        get-cost-optimization-types
    }
    
    print $"Analyzing ($target_instances | length) instances for cost optimization over ($lookback_days) days..."
    
    # Perform cost optimization analysis
    $target_instances 
    | par-each { |instance|
        let instance_metrics = $metrics_data | where instance_id == $instance.instance_id
        analyze-instance-cost-optimization $instance $instance_metrics $optimization_to_run $savings_threshold $include_scheduling $include_rightsizing
    } --threads ($config.max_concurrent_operations)
    | flatten
    | where estimated_savings >= $savings_threshold
    | sort-by estimated_savings --reverse
}

# Generate instance type recommendations based on utilization patterns
export def "ec2 recommend-instance-types" [
    --instance-ids(-i): list<string> = [], # Specific instances to analyze
    --cpu-threshold(-c): float = 70.0,    # CPU utilization threshold percentage
    --memory-threshold(-m): float = 80.0, # Memory utilization threshold percentage
    --network-threshold(-n): float = 50.0, # Network utilization threshold percentage
    --lookback-days(-l): int = 14,         # Days of metrics data to analyze
    --include-burstable(-b),               # Include burstable instance types
    --family-preference(-f): list<string> = [], # Preferred instance families
    --span: any                            # Optional span for error reporting
]: nothing -> table<instance_id: string, current_type: string, recommended_type: string, reason: string, cpu_utilization: float, memory_utilization: float, estimated_cost_change: float, confidence: string> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-instance-type-recommendations $instance_ids $cpu_threshold $memory_threshold $network_threshold $lookback_days)
    }
    
    # Get instances and their utilization metrics
    let target_instances = if ($instance_ids | length) > 0 {
        get-instances-by-ids $instance_ids
    } else {
        get-all-running-instances
    }
    
    print $"Analyzing instance type recommendations for ($target_instances | length) instances..."
    
    # Analyze each instance with streaming processing
    $target_instances 
    | chunks ($config.streaming_chunk_size)
    | each { |chunk|
        $chunk | par-each { |instance|
            analyze-instance-type-recommendation $instance $cpu_threshold $memory_threshold $network_threshold $lookback_days $include_burstable $family_preference
        } --threads ($config.max_concurrent_operations)
    }
    | flatten
    | sort-by estimated_cost_change
}

# ============================================================================
# CloudWatch Metrics Integration and Alerting
# ============================================================================

# Get comprehensive CloudWatch metrics for EC2 instances with streaming support
export def "ec2 get-cloudwatch-metrics" [
    instance_ids: list<string>,             # List of instance IDs
    --metric-names(-m): list<string> = [],  # Specific metrics to retrieve
    --start-time(-s): string,               # Start time (ISO 8601 format)
    --end-time(-e): string,                 # End time (ISO 8601 format)
    --period(-p): int = 300,                # Period in seconds
    --statistics(-t): list<string> = ["Average"], # Statistics to retrieve
    --namespace(-n): string = "AWS/EC2",    # CloudWatch namespace
    --streaming(-r),                        # Enable streaming for large datasets
    --span: any                             # Optional span for error reporting
]: nothing -> table<instance_id: string, metric_name: string, timestamp: datetime, value: float, unit: string, statistic: string> {
    let config = get-ec2-enhanced-config
    
    if not $config.cloudwatch_metrics_enabled {
        make-aws-error "VALIDATION" "FeatureDisabled" 
            "CloudWatch metrics integration is disabled in configuration" 
            "get-cloudwatch-metrics" "ec2" --span $span
    }
    
    if $config.mock_mode {
        return (mock-cloudwatch-metrics $instance_ids $metric_names $start_time $end_time $period $statistics)
    }
    
    # Validate time range
    let time_range = validate-time-range $start_time $end_time
    
    # Determine metrics to retrieve
    let metrics_to_get = if ($metric_names | length) > 0 {
        $metric_names
    } else {
        get-default-ec2-metrics
    }
    
    print $"Retrieving CloudWatch metrics for ($instance_ids | length) instances, ($metrics_to_get | length) metrics..."
    
    # Process instances and metrics with streaming if enabled
    if $streaming {
        $instance_ids 
        | chunks ($config.streaming_chunk_size)
        | each { |instance_chunk|
            print $"Processing metrics for chunk of ($instance_chunk | length) instances..."
            
            $instance_chunk | par-each { |instance_id|
                $metrics_to_get | each { |metric_name|
                    get-cloudwatch-metric-data $instance_id $metric_name $time_range.start $time_range.end $period $statistics $namespace
                }
            } --threads ($config.max_concurrent_operations)
        }
        | flatten
    } else {
        $instance_ids | par-each { |instance_id|
            $metrics_to_get | each { |metric_name|
                get-cloudwatch-metric-data $instance_id $metric_name $time_range.start $time_range.end $period $statistics $namespace
            }
        } --threads ($config.max_concurrent_operations)
        | flatten
    }
    | sort-by instance_id metric_name timestamp
}

# Create CloudWatch alarms for EC2 instances with intelligent thresholds
export def "ec2 create-cloudwatch-alarms" [
    instance_ids: list<string>,             # List of instance IDs
    --alarm-configurations(-c): list<record> = [], # Custom alarm configurations
    --notification-topic(-t): string,       # SNS topic for notifications
    --auto-scaling-integration(-a),         # Integrate with Auto Scaling
    --cost-anomaly-detection(-d),           # Enable cost anomaly detection
    --intelligent-thresholds(-i),           # Use ML-based threshold detection
    --dry-run(-r),                          # Preview alarms without creating
    --span: any                             # Optional span for error reporting
]: nothing -> table<instance_id: string, alarm_name: string, metric_name: string, threshold: float, comparison_operator: string, alarm_arn: string, status: string> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-cloudwatch-alarms $instance_ids $alarm_configurations $notification_topic $auto_scaling_integration $dry_run)
    }
    
    # Generate alarm configurations if not provided
    let alarm_configs = if ($alarm_configurations | length) > 0 {
        $alarm_configurations
    } else {
        generate-default-alarm-configurations $instance_ids $intelligent_thresholds
    }
    
    print $"Creating CloudWatch alarms for ($instance_ids | length) instances with ($alarm_configs | length) configurations..."
    
    # Create alarms with batch processing
    $instance_ids | par-each { |instance_id|
        $alarm_configs | each { |config|
            create-cloudwatch-alarm-for-instance $instance_id $config $notification_topic $dry_run
        }
    } --threads ($config.max_concurrent_operations)
    | flatten
    | sort-by instance_id alarm_name
}

# ============================================================================
# VPC Network Topology Analysis and Visualization
# ============================================================================

# Analyze VPC network topology and generate visual representation
export def "ec2 analyze-vpc-topology" [
    --vpc-ids(-v): list<string> = [],       # Specific VPC IDs to analyze
    --include-subnets(-s),                  # Include subnet analysis
    --include-route-tables(-r),             # Include route table analysis
    --include-security-groups(-g),          # Include security group relationships
    --include-network-acls(-n),             # Include network ACL analysis
    --output-format(-o): string = "text",   # Output format (text, json, graphviz, mermaid)
    --show-cross-vpc(-c),                   # Show cross-VPC connections
    --network-path-analysis(-p),            # Perform network path analysis
    --span: any                             # Optional span for error reporting
]: nothing -> record<topology: record, analysis: record, visualization: string> {
    let config = get-ec2-enhanced-config
    
    if not $config.vpc_topology_enabled {
        make-aws-error "VALIDATION" "FeatureDisabled" 
            "VPC topology analysis is disabled in configuration" 
            "analyze-vpc-topology" "ec2" --span $span
    }
    
    if $config.mock_mode {
        return (mock-vpc-topology-analysis $vpc_ids $include_subnets $include_route_tables $include_security_groups $output_format)
    }
    
    # Get VPCs to analyze
    let target_vpcs = if ($vpc_ids | length) > 0 {
        get-vpcs-by-ids $vpc_ids
    } else {
        get-all-vpcs
    }
    
    print $"Analyzing network topology for ($target_vpcs | length) VPCs..."
    
    # Collect topology data with parallel processing
    let topology_data = $target_vpcs | par-each { |vpc|
        collect-vpc-topology-data $vpc $include_subnets $include_route_tables $include_security_groups $include_network_acls $show_cross_vpc
    } --threads ($config.max_concurrent_operations)
    
    # Perform network analysis
    let analysis_results = analyze-network-topology $topology_data $network_path_analysis
    
    # Generate visualization based on output format
    let visualization = generate-topology-visualization $topology_data $analysis_results $output_format
    
    {
        topology: (consolidate-topology-data $topology_data),
        analysis: $analysis_results,
        visualization: $visualization,
        generated_at: (date now),
        vpc_count: ($target_vpcs | length)
    }
}

# Analyze network security and compliance for VPC topology
export def "ec2 analyze-network-security" [
    --vpc-ids(-v): list<string> = [],       # Specific VPC IDs to analyze
    --security-standards(-s): list<string> = [], # Security standards to check against
    --compliance-frameworks(-c): list<string> = [], # Compliance frameworks
    --risk-threshold(-r): string = "medium", # Minimum risk level to report
    --generate-remediation(-g),             # Generate remediation recommendations
    --network-segmentation-analysis(-n),   # Analyze network segmentation
    --span: any                             # Optional span for error reporting
]: nothing -> table<vpc_id: string, finding_type: string, severity: string, description: string, affected_resources: list<string>, remediation: string, compliance_impact: string> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return (mock-network-security-analysis $vpc_ids $security_standards $compliance_frameworks $risk_threshold)
    }
    
    # Get VPCs for security analysis
    let target_vpcs = if ($vpc_ids | length) > 0 {
        get-vpcs-by-ids $vpc_ids
    } else {
        get-all-vpcs
    }
    
    print $"Analyzing network security for ($target_vpcs | length) VPCs..."
    
    # Perform security analysis with streaming processing
    $target_vpcs 
    | chunks ($config.streaming_chunk_size)
    | each { |vpc_chunk|
        $vpc_chunk | par-each { |vpc|
            analyze-vpc-network-security $vpc $security_standards $compliance_frameworks $risk_threshold $generate_remediation $network_segmentation_analysis
        } --threads ($config.max_concurrent_operations)
    }
    | flatten
    | where severity in (get-severity-levels-above $risk_threshold)
    | sort-by severity vpc_id
}

# ============================================================================
# Helper Functions for Instance Lifecycle Management
# ============================================================================

# Get current states for a list of instances
def get-instance-states [instance_ids: list<string>]: nothing -> table<instance_id: string, current_state: string> {
    let config = get-ec2-enhanced-config
    
    if $config.mock_mode {
        return ($instance_ids | each { |id|
            {
                instance_id: $id,
                current_state: (["running", "stopped", "pending"] | get (random int 0..2))
            }
        })
    }
    
    try {
        ^aws ec2 describe-instances 
            --instance-ids ...$instance_ids 
            --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' 
            --output json
        | from json 
        | flatten 
        | each { |item|
            {
                instance_id: $item.0,
                current_state: $item.1
            }
        }
    } catch { |err|
        make-aws-error "RESOURCE" "DescribeInstancesFailed" 
            $"Failed to get instance states: ($err.msg)" 
            "get-instance-states" "ec2"
    }
}

# Perform start instances batch operation
def perform-start-instances-batch [instance_ids: list<string>, wait: bool]: nothing -> list<record> {
    let start_result = try {
        ^aws ec2 start-instances --instance-ids ...$instance_ids --output json | from json
    } catch { |err|
        make-aws-error "RESOURCE" "StartInstancesFailed" 
            $"Failed to start instances: ($err.msg)" 
            "perform-start-instances-batch" "ec2"
    }
    
    let initial_results = $start_result.StartingInstances | each { |instance|
        {
            instance_id: $instance.InstanceId,
            previous_state: $instance.PreviousState.Name,
            current_state: $instance.CurrentState.Name,
            result: "start_initiated"
        }
    }
    
    if $wait {
        print "Waiting for instances to reach running state..."
        try {
            ^aws ec2 wait instance-running --instance-ids ...$instance_ids
            $initial_results | each { |result|
                $result | upsert current_state "running" | upsert result "started_successfully"
            }
        } catch { |err|
            $initial_results | each { |result|
                $result | upsert result "start_timeout" | upsert error $err.msg
            }
        }
    } else {
        $initial_results
    }
}

# Perform stop instances batch operation
def perform-stop-instances-batch [instance_ids: list<string>, force: bool, wait: bool]: nothing -> list<record> {
    let stop_args = if $force { ["--force"] } else { [] }
    
    let stop_result = try {
        ^aws ec2 stop-instances --instance-ids ...$instance_ids ...$stop_args --output json | from json
    } catch { |err|
        make-aws-error "RESOURCE" "StopInstancesFailed" 
            $"Failed to stop instances: ($err.msg)" 
            "perform-stop-instances-batch" "ec2"
    }
    
    let initial_results = $stop_result.StoppingInstances | each { |instance|
        {
            instance_id: $instance.InstanceId,
            previous_state: $instance.PreviousState.Name,
            current_state: $instance.CurrentState.Name,
            result: "stop_initiated"
        }
    }
    
    if $wait {
        print "Waiting for instances to reach stopped state..."
        try {
            ^aws ec2 wait instance-stopped --instance-ids ...$instance_ids
            $initial_results | each { |result|
                $result | upsert current_state "stopped" | upsert result "stopped_successfully"
            }
        } catch { |err|
            $initial_results | each { |result|
                $result | upsert result "stop_timeout" | upsert error $err.msg
            }
        }
    } else {
        $initial_results
    }
}

# Perform termination safety checks
def perform-termination-safety-checks [instance_ids: list<string>, skip_api_check: bool]: nothing -> table<instance_id: string, api_termination_enabled: bool, has_important_tags: bool, is_production: bool> {
    $instance_ids | each { |id|
        let instance_details = try {
            ^aws ec2 describe-instance-attribute --instance-id $id --attribute disableApiTermination --output json | from json
        } catch { |err|
            { DisableApiTermination: { Value: false } }
        }
        
        let instance_tags = try {
            ^aws ec2 describe-tags --filters "Name=resource-id,Values=($id)" --output json | from json | get Tags
        } catch { |err|
            []
        }
        
        let api_termination_disabled = $instance_details.DisableApiTermination.Value
        let has_important_tags = ($instance_tags | any { |tag| $tag.Key in ["Environment", "Project", "CostCenter"] and $tag.Value =~ "prod" })
        let is_production = ($instance_tags | any { |tag| $tag.Key == "Environment" and ($tag.Value | str downcase) == "production" })
        
        {
            instance_id: $id,
            api_termination_enabled: (not $api_termination_disabled),
            has_important_tags: $has_important_tags,
            is_production: $is_production
        }
    }
}

# ============================================================================
# Mock Functions for Testing
# ============================================================================

# Mock start instances operation
def mock-start-instances [instance_ids: list<string>, batch_size: int, wait: bool, dry_run: bool]: nothing -> table<instance_id: string, previous_state: string, current_state: string, result: string> {
    $instance_ids | each { |id|
        {
            instance_id: $id,
            previous_state: "stopped",
            current_state: (if $dry_run { "stopped" } else if $wait { "running" } else { "pending" }),
            result: (if $dry_run { "dry_run_successful" } else if $wait { "started_successfully" } else { "start_initiated" }),
            mock: true
        }
    }
}

# Mock stop instances operation
def mock-stop-instances [instance_ids: list<string>, batch_size: int, force: bool, wait: bool, dry_run: bool]: nothing -> table<instance_id: string, previous_state: string, current_state: string, result: string> {
    $instance_ids | each { |id|
        {
            instance_id: $id,
            previous_state: "running",
            current_state: (if $dry_run { "running" } else if $wait { "stopped" } else { "stopping" }),
            result: (if $dry_run { "dry_run_successful" } else if $wait { "stopped_successfully" } else { "stop_initiated" }),
            mock: true
        }
    }
}

# Mock terminate instances operation
def mock-terminate-instances [instance_ids: list<string>, batch_size: int, disable_api_check: bool, force: bool, dry_run: bool]: nothing -> table<instance_id: string, previous_state: string, current_state: string, result: string, warnings: list<string>> {
    $instance_ids | each { |id|
        {
            instance_id: $id,
            previous_state: "running",
            current_state: (if $dry_run { "running" } else { "shutting-down" }),
            result: (if $dry_run { "dry_run_successful" } else { "termination_initiated" }),
            warnings: (if $dry_run { ["This is a dry run"] } else { [] }),
            mock: true
        }
    }
}

# Mock security group analysis
def mock-security-group-analysis [group_ids: list<string>, vpc_id: string, analysis_types: list<string>, severity_threshold: string]: nothing -> table<group_id: string, group_name: string, issue_type: string, severity: string, description: string, recommendation: string> {
    let mock_groups = if ($group_ids | length) > 0 { $group_ids } else { ["sg-mock1", "sg-mock2", "sg-mock3"] }
    
    $mock_groups | each { |group_id|
        [
            {
                group_id: $group_id,
                group_name: $"mock-sg-($group_id | str substring 3..)",
                issue_type: "wide-open-access",
                severity: "high",
                description: "Security group allows inbound access from 0.0.0.0/0 on port 22",
                recommendation: "Restrict SSH access to specific IP ranges",
                mock: true
            },
            {
                group_id: $group_id,
                group_name: $"mock-sg-($group_id | str substring 3..)",
                issue_type: "excessive-permissions",
                severity: "medium",
                description: "Security group has more permissions than necessary",
                recommendation: "Review and remove unused rules",
                mock: true
            }
        ]
    } | flatten
}

# Mock cost optimization analysis
def mock-cost-optimization-analysis [instance_ids: list<string>, region: string, optimization_types: list<string>, lookback_days: int, savings_threshold: int]: nothing -> table<instance_id: string, instance_type: string, optimization_type: string, current_monthly_cost: float, estimated_monthly_cost: float, estimated_savings: float, confidence: string, recommendation: string> {
    let mock_instances = if ($instance_ids | length) > 0 { $instance_ids } else { ["i-mock1", "i-mock2", "i-mock3"] }
    
    $mock_instances | each { |instance_id|
        {
            instance_id: $instance_id,
            instance_type: "m5.large",
            optimization_type: "rightsizing",
            current_monthly_cost: 69.36,
            estimated_monthly_cost: 34.68,
            estimated_savings: 50.0,
            confidence: "high",
            recommendation: "Downsize to m5.medium based on low CPU utilization",
            mock: true
        }
    }
}

# Mock CloudWatch metrics
def mock-cloudwatch-metrics [instance_ids: list<string>, metric_names: list<string>, start_time: string, end_time: string, period: int, statistics: list<string>]: nothing -> table<instance_id: string, metric_name: string, timestamp: datetime, value: float, unit: string, statistic: string> {
    let mock_instances = if ($instance_ids | length) > 0 { $instance_ids } else { ["i-mock1", "i-mock2"] }
    let mock_metrics = if ($metric_names | length) > 0 { $metric_names } else { ["CPUUtilization", "NetworkIn", "NetworkOut"] }
    
    $mock_instances | each { |instance_id|
        $mock_metrics | each { |metric_name|
            [
                {
                    instance_id: $instance_id,
                    metric_name: $metric_name,
                    timestamp: (date now | date to-timezone UTC),
                    value: (random float 0..100),
                    unit: (if $metric_name == "CPUUtilization" { "Percent" } else { "Bytes" }),
                    statistic: "Average",
                    mock: true
                }
            ]
        }
    } | flatten
}

# Mock VPC topology analysis
def mock-vpc-topology-analysis [vpc_ids: list<string>, include_subnets: bool, include_route_tables: bool, include_security_groups: bool, output_format: string]: nothing -> record<topology: record, analysis: record, visualization: string> {
    {
        topology: {
            vpcs: (if ($vpc_ids | length) > 0 { $vpc_ids } else { ["vpc-mock1", "vpc-mock2"] }),
            subnets: (if $include_subnets { ["subnet-mock1", "subnet-mock2"] } else { [] }),
            route_tables: (if $include_route_tables { ["rtb-mock1", "rtb-mock2"] } else { [] }),
            security_groups: (if $include_security_groups { ["sg-mock1", "sg-mock2"] } else { [] }),
            mock: true
        },
        analysis: {
            connectivity_score: 85,
            security_score: 78,
            redundancy_score: 92,
            recommendations: ["Enable VPC Flow Logs", "Review security group rules"],
            mock: true
        },
        visualization: (match $output_format {
            "json" => '{"vpcs": ["vpc-mock1"], "mock": true}',
            "graphviz" => 'digraph VPC { vpc1 -> subnet1; subnet1 -> instance1; }',
            "mermaid" => 'graph TD; VPC1 --> Subnet1; Subnet1 --> Instance1;',
            _ => "VPC Topology (Mock Mode)\n├── vpc-mock1\n│   ├── subnet-mock1\n│   └── subnet-mock2\n└── Security Groups: sg-mock1, sg-mock2"
        }),
        generated_at: (date now),
        vpc_count: 2,
        mock: true
    }
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get severity levels above a threshold
def get-severity-levels-above [threshold: string]: nothing -> list<string> {
    let all_levels = ["low", "medium", "high", "critical"]
    let threshold_index = $all_levels | enumerate | where item == $threshold | get index | first
    $all_levels | skip $threshold_index
}

# Validate time range for CloudWatch queries
def validate-time-range [start_time: string, end_time: string]: nothing -> record<start: string, end: string> {
    let default_end = (date now | format date '%Y-%m-%dT%H:%M:%SZ')
    let default_start = (date now | date add -24hr | format date '%Y-%m-%dT%H:%M:%SZ')
    
    {
        start: (if ($start_time | is-empty) { $default_start } else { $start_time }),
        end: (if ($end_time | is-empty) { $default_end } else { $end_time })
    }
}

# Get default EC2 metrics for CloudWatch
def get-default-ec2-metrics []: nothing -> list<string> {
    ["CPUUtilization", "NetworkIn", "NetworkOut", "DiskReadBytes", "DiskWriteBytes", "DiskReadOps", "DiskWriteOps"]
}

# Convert data to chunks for streaming processing
def chunks [size: int] {
    let input = $in
    let total = ($input | length)
    
    if $total <= $size {
        [$input]
    } else {
        0..<($total / $size | math ceil) | each { |i|
            let start = $i * $size
            let end = (($start + $size) | math min $total)
            $input | skip $start | first ($end - $start)
        }
    }
}

# Export main functions for external use
export def "ec2 enhanced info" []: nothing -> record {
    {
        module: "EC2 Enhanced Features",
        version: "1.0.0",
        description: "Comprehensive EC2 lifecycle management, security analysis, cost optimization, CloudWatch integration, and VPC topology analysis",
        functions: [
            "ec2 start-instances-enhanced",
            "ec2 stop-instances-enhanced", 
            "ec2 terminate-instances-enhanced",
            "ec2 analyze-security-groups",
            "ec2 optimize-security-groups",
            "ec2 analyze-cost-optimization",
            "ec2 recommend-instance-types",
            "ec2 get-cloudwatch-metrics",
            "ec2 create-cloudwatch-alarms",
            "ec2 analyze-vpc-topology",
            "ec2 analyze-network-security"
        ],
        features: [
            "Instance lifecycle management with batch operations",
            "Security group analysis and optimization",
            "Cost optimization recommendations",
            "CloudWatch metrics integration and alerting",
            "VPC network topology analysis and visualization",
            "Streaming operations for large datasets",
            "Comprehensive error handling with spans",
            "Mock mode support for testing",
            "Pure functional programming patterns"
        ],
        configuration: (get-ec2-enhanced-config)
    }
}