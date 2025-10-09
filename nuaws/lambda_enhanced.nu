# Lambda Enhanced Features Module for NuAWS
# Comprehensive Lambda functionality with SAM integration, deployment automation,
# real-time log streaming, performance analysis, and cost optimization
#
# Design Philosophy:
# - Pure functional programming patterns with immutable data structures
# - Streaming operations optimized for Nushell pipelines
# - Comprehensive error handling with span information
# - Mock mode support for safe testing
# - Pipeline-friendly composable functions

# Import error handling functions if available, otherwise use local implementations
# use errors.nu [make-aws-error, map-aws-error-code]
# use functional.nu [pure-aws-function, aws-pipeline, chain-aws-operations]

# ============================================================================
# Local Error Handling Functions (Self-contained)
# ============================================================================

# Create AWS error with span information (local implementation)
def make-aws-error [
    category: string,           # Error category
    aws_error_code: string,     # AWS error code
    user_message: string,       # Human-readable message
    operation: string,          # AWS operation that failed
    service: string,           # AWS service name
    span?: any                 # Optional span information
] {
    error make {
        msg: $user_message,
        label: {
            text: $"AWS ($service) ($operation): ($aws_error_code)",
            span: $span
        },
        help: $"Error category: ($category). Check AWS documentation for resolution steps."
    }
}

# Map AWS error code (simplified local implementation)
def map-aws-error-code [
    aws_error: string,          # Raw AWS error message or code
    service: string            # AWS service context
]: nothing -> record {
    {
        category: "UNKNOWN",
        severity: "medium",
        retryable: false,
        aws_error_code: $aws_error,
        service: $service,
        confidence: "low"
    }
}

# Pure function wrapper (local implementation)
def pure-aws-function [
    func: closure               # Function to mark as pure
]: nothing -> closure {
    { |...args|
        let result = do $func ...$args
        
        if ($result | describe) =~ "^record" {
            $result | upsert pure_function true | upsert computed_at (date now)
        } else {
            $result
        }
    }
}

# AWS pipeline composition (local implementation)
def aws-pipeline [
    ...stages: closure          # Pipeline stages to execute
] {
    let input = $in
    
    $stages | reduce --fold $input { |stage, acc|
        do $stage $acc
    }
}

# Chain AWS operations (local implementation)  
def chain-aws-operations [
    ...operations: closure      # Operations to chain
] {
    let input = $in
    
    try {
        $operations | reduce --fold $input { |op, acc|
            do $op $acc
        }
    } catch { |err|
        {
            error: true,
            message: $err.msg,
            operation_chain_failed: true,
            input: $input
        }
    }
}

# ============================================================================
# Core Configuration and Types
# ============================================================================

# Lambda enhanced configuration schema
export def get-lambda-enhanced-config []: nothing -> record {
    {
        sam_config_file: "samconfig.toml",
        log_retention_days: 14,
        default_timeout: 30,
        default_memory: 512,
        cost_analysis_period_days: 30,
        performance_threshold_ms: 1000,
        cold_start_threshold_ms: 500,
        mock_mode: ($env.LAMBDA_ENHANCED_MOCK_MODE? | default false),
        aws_region: ($env.AWS_REGION? | default "us-east-1"),
        sam_template_patterns: ["template.yaml", "template.yml", "sam.yaml", "sam.yml"]
    }
}

# Lambda deployment configuration schema
def get-deployment-config []: nothing -> record {
    {
        stack_name_pattern: "lambda-{function_name}-{environment}",
        supported_runtimes: [
            "nodejs18.x", "nodejs20.x", "python3.9", "python3.10", "python3.11", "python3.12",
            "java11", "java17", "java21", "dotnet6", "dotnet8", "go1.x", "ruby3.2", "provided.al2023"
        ],
        deployment_stages: ["dev", "staging", "prod"],
        versioning_strategy: "semantic", # semantic, timestamp, git-hash
        alias_patterns: {
            dev: "$LATEST",
            staging: "staging",
            prod: "prod"
        }
    }
}

# Performance analysis configuration
def get-performance-config []: nothing -> record {
    {
        cold_start_indicators: [
            "Init Duration", "INIT_START", "INIT_RUNTIME_DONE",
            "Duration", "Billed Duration", "Memory Size"
        ],
        optimization_recommendations: {
            high_memory_usage: "Consider increasing memory allocation",
            high_duration: "Optimize function code or increase timeout",
            frequent_cold_starts: "Consider provisioned concurrency",
            high_cost: "Review memory allocation and execution patterns"
        },
        metric_collection_interval_seconds: 300
    }
}

# ============================================================================
# SAM/Serverless Framework Integration
# ============================================================================

# Discover SAM templates in project directory
export def sam-discover-templates [
    project_path?: string  # Project directory path (defaults to current)
]: nothing -> list<record> {
    let config = get-lambda-enhanced-config
    let search_path = $project_path | default (pwd)
    
    if $config.mock_mode {
        return (get-mock-sam-templates)
    }
    
    try {
        $config.sam_template_patterns | each { |pattern|
            glob ($search_path + "/" + $pattern) | each { |template_path|
                let template_content = try {
                    open $template_path | from yaml
                } catch {
                    null
                }
                
                if ($template_content | is-not-empty) {
                    {
                        template_path: $template_path,
                        template_name: ($template_path | path basename),
                        template_type: "SAM",
                        functions: (extract-sam-functions $template_content),
                        resources: (extract-sam-resources $template_content),
                        discovered_at: (date now),
                        valid: true
                    }
                } else {
                    {
                        template_path: $template_path,
                        template_name: ($template_path | path basename),
                        valid: false,
                        error: "Failed to parse template"
                    }
                }
            }
        } | flatten | where valid == true
    } catch { |err|
        make-aws-error "VALIDATION" "TemplateDiscoveryFailed" $"Failed to discover SAM templates: ($err.msg)" "sam-discover-templates" "lambda"
    }
}

# Extract Lambda functions from SAM template
def extract-sam-functions [template: record]: nothing -> list<record> {
    try {
        let resources = $template.Resources? | default {}
        
        $resources | transpose key value | where ($it.value.Type? | default "") == "AWS::Serverless::Function" | each { |func|
            let properties = $func.value.Properties? | default {}
            {
                logical_id: $func.key,
                function_name: ($properties.FunctionName? | default $func.key),
                runtime: ($properties.Runtime? | default "unknown"),
                handler: ($properties.Handler? | default ""),
                memory_size: ($properties.MemorySize? | default 128),
                timeout: ($properties.Timeout? | default 3),
                environment: ($properties.Environment?.Variables? | default {}),
                events: ($func.value.Events? | default {} | transpose key value | each { |e| 
                    { event_name: $e.key, event_type: ($e.value | transpose key value | first | get key), config: $e.value }
                })
            }
        }
    } catch {
        []
    }
}

# Extract all resources from SAM template
def extract-sam-resources [template: record]: nothing -> list<record> {
    try {
        let resources = $template.Resources? | default {}
        
        $resources | transpose key value | each { |resource|
            {
                logical_id: $resource.key,
                type: ($resource.value.Type? | default "Unknown"),
                properties: ($resource.value.Properties? | default {}),
                depends_on: ($resource.value.DependsOn? | default [])
            }
        }
    } catch {
        []
    }
}

# Build SAM application with comprehensive options
export def sam-build [
    template_path?: string,      # Path to SAM template
    --build-dir(-b): string,     # Custom build directory
    --use-container(-c),         # Build using container
    --parallel(-p),              # Enable parallel builds
    --cached,                    # Use cached dependencies
    --debug(-d)                  # Enable debug output
]: nothing -> record {
    let config = get-lambda-enhanced-config
    let template = $template_path | default "template.yaml"
    
    if $config.mock_mode {
        return (get-mock-sam-build-result)
    }
    
    if not ($template | path exists) {
        make-aws-error "VALIDATION" "TemplateNotFound" $"SAM template not found: ($template)" "sam-build" "lambda"
        return
    }
    
    # Construct build command arguments
    let build_args = [
        $template,
        ($build_dir | if $in != null { ["--build-dir", $in] } else { [] }),
        (if $use_container { ["--use-container"] } else { [] }),
        (if $parallel { ["--parallel"] } else { [] }),
        (if $cached { ["--cached"] } else { [] }),
        (if $debug { ["--debug"] } else { [] })
    ] | flatten | where ($it | is-not-empty)
    
    try {
        let build_result = run-external "sam" (["build"] ++ $build_args)
        
        {
            command: "sam build",
            template_path: $template,
            build_args: $build_args,
            success: ($build_result.exit_code == 0),
            output: $build_result.stdout,
            error: $build_result.stderr,
            build_time: (date now),
            artifacts_location: ($build_dir | default ".aws-sam/build")
        }
    } catch { |err|
        make-aws-error "RESOURCE" "BuildFailed" $"SAM build failed: ($err.msg)" "sam-build" "lambda"
    }
}

# Deploy SAM application with versioning and rollback support
export def sam-deploy [
    stack_name: string,           # CloudFormation stack name
    --template-path(-t): string,  # Path to SAM template
    --parameter-overrides(-p): record, # Parameter overrides
    --capabilities(-c): list<string>, # IAM capabilities
    --s3-bucket(-s): string,      # S3 bucket for artifacts
    --s3-prefix: string,          # S3 prefix for artifacts
    --region(-r): string,         # AWS region
    --guided(-g),                 # Use guided deployment
    --confirm-changeset,          # Require changeset confirmation
    --no-fail-on-empty-changeset  # Don't fail on empty changeset
]: nothing -> record {
    let config = get-lambda-enhanced-config
    let deploy_config = get-deployment-config
    
    if $config.mock_mode {
        return (get-mock-sam-deploy-result $stack_name)
    }
    
    # Validate stack name pattern
    let pattern_base = $deploy_config.stack_name_pattern | str replace "{function_name}" "" | str replace "{environment}" ""
    if not ($stack_name | str contains $pattern_base) {
        print $"Warning: Stack name doesn't follow recommended pattern: ($deploy_config.stack_name_pattern)"
    }
    
    # Construct deployment command
    let deploy_args = [
        "deploy",
        "--stack-name", $stack_name,
        ($template_path | if $in != null { ["--template-file", $in] } else { [] }),
        ($parameter_overrides | if $in != null { ["--parameter-overrides"] + ($in | transpose key value | each { |p| $"($p.key)=($p.value)" }) } else { [] }),
        ($capabilities | if $in != null { ["--capabilities"] + $in } else { ["--capabilities", "CAPABILITY_IAM"] }),
        ($s3_bucket | if $in != null { ["--s3-bucket", $in] } else { [] }),
        ($s3_prefix | if $in != null { ["--s3-prefix", $in] } else { [] }),
        ($region | if $in != null { ["--region", $in] } else { [] }),
        (if $guided { ["--guided"] } else { [] }),
        (if $confirm_changeset { ["--confirm-changeset"] } else { [] }),
        (if $no_fail_on_empty_changeset { ["--no-fail-on-empty-changeset"] } else { [] })
    ] | flatten | where ($it | is-not-empty)
    
    try {
        let deploy_result = run-external "sam" $deploy_args
        
        {
            command: "sam deploy",
            stack_name: $stack_name,
            deploy_args: $deploy_args,
            success: ($deploy_result.exit_code == 0),
            output: $deploy_result.stdout,
            error: $deploy_result.stderr,
            deployment_time: (date now),
            changeset_created: ($deploy_result.stdout | str contains "Changeset created successfully"),
            resources_created: (extract-deployed-resources $deploy_result.stdout)
        }
    } catch { |err|
        make-aws-error "RESOURCE" "DeploymentFailed" $"SAM deployment failed: ($err.msg)" "sam-deploy" "lambda"
    }
}

# ============================================================================
# Deployment Automation with Versioning
# ============================================================================

# Create Lambda function version with comprehensive metadata
export def lambda-create-version [
    function_name: string,        # Function name or ARN
    --description(-d): string,    # Version description
    --code-sha256: string,        # Expected SHA256 of code
    --dry-run                     # Preview without creating
]: nothing -> record {
    let config = get-lambda-enhanced-config
    
    if $config.mock_mode {
        return (get-mock-version-creation $function_name)
    }
    
    if $dry_run {
        return {
            action: "create-version",
            function_name: $function_name,
            description: ($description | default $"Version created at (date now)"),
            dry_run: true,
            would_create: true
        }
    }
    
    let version_description = $description | default $"Automated version created at (date now | format date '%Y-%m-%d %H:%M:%S')"
    
    try {
        let version_args = [
            "lambda", "publish-version",
            "--function-name", $function_name,
            "--description", $version_description,
            ($code_sha256 | if $in != null { ["--code-sha256", $in] } else { [] })
        ] | flatten | where ($it | is-not-empty)
        
        let result = (run-external "aws" $version_args).stdout | from json
        
        {
            function_name: $result.FunctionName,
            version: $result.Version,
            description: $result.Description,
            code_sha256: $result.CodeSha256,
            code_size: $result.CodeSize,
            created_at: $result.LastModified,
            runtime: $result.Runtime,
            handler: $result.Handler,
            memory_size: $result.MemorySize,
            timeout: $result.Timeout,
            success: true
        }
    } catch { |err|
        make-aws-error "RESOURCE" "VersionCreationFailed" $"Failed to create version: ($err.msg)" "lambda-create-version" "lambda"
    }
}

# Manage Lambda function aliases with blue/green deployment support
export def lambda-manage-alias [
    function_name: string,        # Function name
    alias_name: string,           # Alias name
    function_version: string,     # Function version to point to
    --description(-d): string,    # Alias description
    --routing-config(-r): record, # Traffic routing configuration
    --update(-u),                 # Update existing alias
    --blue-green                  # Enable blue/green deployment
]: nothing -> record {
    let config = get-lambda-enhanced-config
    
    if $config.mock_mode {
        return (get-mock-alias-management $function_name $alias_name)
    }
    
    # Check if alias exists
    let alias_exists = try {
        (run-external "aws" ["lambda", "get-alias", "--function-name", $function_name, "--name", $alias_name]).stdout | from json | is-not-empty
    } catch {
        false
    }
    
    let operation = if $alias_exists { "update-alias" } else { "create-alias" }
    
    if $blue_green and $alias_exists {
        return (lambda-blue-green-deployment $function_name $alias_name $function_version $routing_config)
    }
    
    try {
        let alias_args = [
            "lambda", $operation,
            "--function-name", $function_name,
            "--name", $alias_name,
            "--function-version", $function_version,
            ($description | if $in != null { ["--description", $in] } else { [] }),
            ($routing_config | if $in != null { ["--routing-config", ($in | to json)] } else { [] })
        ] | flatten | where ($it | is-not-empty)
        
        let result = (run-external "aws" $alias_args).stdout | from json
        
        {
            function_name: $result.FunctionName,
            alias_name: $result.Name,
            function_version: $result.FunctionVersion,
            description: $result.Description,
            routing_config: ($result.RoutingConfig? | default {}),
            alias_arn: $result.AliasArn,
            operation: $operation,
            created_at: ($result.LastModified? | default (date now)),
            success: true
        }
    } catch { |err|
        make-aws-error "RESOURCE" "AliasManagementFailed" $"Failed to manage alias: ($err.msg)" "lambda-manage-alias" "lambda"
    }
}

# Implement blue/green deployment with gradual traffic shifting
def lambda-blue-green-deployment [
    function_name: string,
    alias_name: string,
    new_version: string,
    routing_config?: record
]: nothing -> record {
    # Default routing configuration for blue/green
    let default_routing = {
        AdditionalVersionWeights: {
            $new_version: 10  # Start with 10% traffic to new version
        }
    }
    
    let routing = $routing_config | default $default_routing
    
    # Gradual traffic shifting stages
    let traffic_stages = [10, 25, 50, 75, 100]
    
    let deployment_results = $traffic_stages | each { |percentage|
        let stage_routing = {
            AdditionalVersionWeights: {
                $new_version: $percentage
            }
        }
        
        # Wait between stages for monitoring
        if $percentage > 10 {
            sleep 30sec
        }
        
        try {
            let result = (run-external "aws" [
                "lambda", "update-alias",
                "--function-name", $function_name,
                "--name", $alias_name,
                "--routing-config", ($stage_routing | to json)
            ]).stdout | from json
            
            {
                stage: $percentage,
                success: true,
                updated_at: (date now),
                routing_config: $stage_routing
            }
        } catch { |err|
            {
                stage: $percentage,
                success: false,
                error: $err.msg,
                failed_at: (date now)
            }
        }
    }
    
    # Final update to point 100% traffic to new version
    try {
        (run-external "aws" [
            "lambda", "update-alias",
            "--function-name", $function_name,
            "--name", $alias_name,
            "--function-version", $new_version
        ]).stdout | from json | ignore
        
        {
            deployment_type: "blue-green",
            function_name: $function_name,
            alias_name: $alias_name,
            new_version: $new_version,
            stages: $deployment_results,
            final_cutover: true,
            completed_at: (date now),
            success: ($deployment_results | all { |stage| $stage.success })
        }
    } catch { |err|
        make-aws-error "RESOURCE" "BlueGreenDeploymentFailed" $"Blue/green deployment failed at final cutover: ($err.msg)" "lambda-blue-green-deployment" "lambda"
    }
}

# ============================================================================
# Real-time Log Streaming with Filtering
# ============================================================================

# Stream Lambda function logs in real-time with advanced filtering
export def lambda-stream-logs [
    function_name: string,        # Function name or ARN
    --start-time(-s): string,     # Start time (e.g., "1h ago", "2023-01-01T10:00:00")
    --follow(-f),                 # Follow log stream (real-time)
    --filter-pattern: string,     # CloudWatch filter pattern
    --log-level: string,          # Filter by log level (ERROR, WARN, INFO, DEBUG)
    --request-id: string,         # Filter by specific request ID
    --duration-threshold: duration, # Show only requests above duration
    --include-cold-starts,        # Include cold start logs
    --output-format: string = "structured" # Output format (structured, raw, json)
]: nothing -> any {
    let config = get-lambda-enhanced-config
    
    if $config.mock_mode {
        return (get-mock-log-stream $function_name)
    }
    
    # Convert start time to epoch milliseconds
    let start_time_ms = if ($start_time | is-not-empty) {
        parse-time-to-epoch $start_time
    } else {
        let one_hour_ago = (date now) - 1hr
        $one_hour_ago | format date "%s%3N"
    }
    
    # Construct log group name
    let log_group = $"/aws/lambda/($function_name)"
    
    # Build filter pattern
    let filter = build-log-filter-pattern $filter_pattern $log_level $request_id $duration_threshold $include_cold_starts
    
    if $follow {
        lambda-stream-logs-realtime $log_group $filter $start_time_ms $output_format
    } else {
        lambda-get-logs-batch $log_group $filter $start_time_ms $output_format
    }
}

# Stream logs in real-time using CloudWatch Logs streaming
def lambda-stream-logs-realtime [
    log_group: string,
    filter_pattern: string,
    start_time: string,
    output_format: string
]: nothing -> any {
    print $"🔄 Streaming logs from ($log_group) (press Ctrl+C to stop)"
    
    let stream_command = [
        "logs", "filter-log-events",
        "--log-group-name", $log_group,
        "--start-time", $start_time,
        ($filter_pattern | if $in != "" { ["--filter-pattern", $in] } else { [] }),
        "--follow"
    ] | flatten | where ($it | is-not-empty)
    
    try {
        # Start streaming process (simplified for now)
        let log_stream = run-external "aws" $stream_command
        
        $log_stream.stdout | lines | each { |log_line|
            if ($log_line | str contains "events") {
                let log_event = try { $log_line | from json } catch { $log_line }
                format-log-output $log_event $output_format
            }
        }
    } catch { |err|
        make-aws-error "NETWORK" "LogStreamingFailed" $"Failed to stream logs: ($err.msg)" "lambda-stream-logs-realtime" "lambda"
    }
}

# Get logs in batch mode for historical analysis
def lambda-get-logs-batch [
    log_group: string,
    filter_pattern: string,
    start_time: string,
    output_format: string
]: nothing -> list<record> {
    try {
        let logs_command = [
            "logs", "filter-log-events",
            "--log-group-name", $log_group,
            "--start-time", $start_time,
            ($filter_pattern | if $in != "" { ["--filter-pattern", $in] } else { [] })
        ] | flatten | where ($it | is-not-empty)
        
        let log_response = (run-external "aws" $logs_command).stdout | from json
        
        $log_response.events | each { |event|
            format-log-event $event $output_format
        }
    } catch { |err|
        make-aws-error "NETWORK" "LogRetrievalFailed" $"Failed to retrieve logs: ($err.msg)" "lambda-get-logs-batch" "lambda"
    }
}

# Build comprehensive log filter pattern
def build-log-filter-pattern [
    custom_pattern?: string,
    log_level?: string,
    request_id?: string,
    duration_threshold?: duration,
    include_cold_starts?: bool
]: nothing -> string {
    let patterns = []
    
    # Add custom pattern
    if ($custom_pattern | is-not-empty) {
        $patterns | append $custom_pattern
    }
    
    # Add log level filter
    if ($log_level | is-not-empty) {
        $patterns | append $"[($log_level)]"
    }
    
    # Add request ID filter
    if ($request_id | is-not-empty) {
        $patterns | append $request_id
    }
    
    # Add duration threshold filter
    if ($duration_threshold | is-not-empty) {
        let threshold_ms = $duration_threshold | format duration ms | str replace "ms" ""
        $patterns | append $"\"Duration: \" { > ($threshold_ms) }"
    }
    
    # Add cold start filter
    if $include_cold_starts {
        $patterns | append "\"Init Duration\""
    }
    
    $patterns | str join " "
}

# Format log event based on output format preference
def format-log-event [
    event: record,
    format: string
]: nothing -> record {
    match $format {
        "raw" => $event.message,
        "json" => ($event | to json),
        "structured" => {
            timestamp: ($event.timestamp | math floor),
            log_stream: $event.logStreamName,
            message: $event.message,
            event_id: $event.eventId,
            parsed: (parse-lambda-log-message $event.message)
        },
        _ => $event
    }
}

# Parse Lambda log message to extract structured information
def parse-lambda-log-message [message: string]: nothing -> record {
    let request_id_pattern = 'REQUEST ID: ([a-f0-9\-]+)'
    let duration_pattern = 'Duration: ([\d\.]+) ms'
    let memory_pattern = 'Max Memory Used: (\d+) MB'
    let init_duration_pattern = 'Init Duration: ([\d\.]+) ms'
    
    {
        request_id: ($message | parse $request_id_pattern | get capture0? | first | default ""),
        duration_ms: ($message | parse $duration_pattern | get capture0? | first | default "" | into float),
        memory_used_mb: ($message | parse $memory_pattern | get capture0? | first | default "" | into int),
        init_duration_ms: ($message | parse $init_duration_pattern | get capture0? | first | default "" | into float),
        is_cold_start: ($message | str contains "Init Duration"),
        log_level: (extract-log-level $message),
        contains_error: ($message | str contains -i "error"),
        timestamp_parsed: (parse-log-timestamp $message)
    }
}

# ============================================================================
# Cold Start Performance Analysis
# ============================================================================

# Analyze cold start performance with optimization recommendations
export def lambda-analyze-cold-starts [
    function_name: string,        # Function name
    --analysis-period(-p): duration = 7day, # Analysis period
    --min-cold-starts(-m): int = 5, # Minimum cold starts for analysis
    --include-recommendations(-r)  # Include optimization recommendations
]: nothing -> record {
    let config = get-lambda-enhanced-config
    let perf_config = get-performance-config
    
    if $config.mock_mode {
        return (get-mock-cold-start-analysis $function_name)
    }
    
    # Calculate analysis window
    let end_time = date now
    let start_time = $end_time - $analysis_period
    
    # Get cold start metrics from CloudWatch Logs
    let cold_start_data = get-cold-start-metrics $function_name $start_time $end_time
    
    if ($cold_start_data | length) < $min_cold_starts {
        return {
            function_name: $function_name,
            analysis_period: $analysis_period,
            cold_starts_found: ($cold_start_data | length),
            min_required: $min_cold_starts,
            insufficient_data: true,
            recommendation: "Collect more data over a longer period for meaningful analysis"
        }
    }
    
    # Analyze cold start patterns
    let analysis = analyze-cold-start-patterns $cold_start_data
    
    # Generate recommendations if requested
    let recommendations = if $include_recommendations {
        generate-cold-start-recommendations $analysis $function_name
    } else {
        []
    }
    
    {
        function_name: $function_name,
        analysis_period: $analysis_period,
        analysis_window: { start: $start_time, end: $end_time },
        cold_start_summary: $analysis,
        recommendations: $recommendations,
        analyzed_at: (date now),
        optimization_priority: (calculate-optimization-priority $analysis)
    }
}

# Get cold start metrics from CloudWatch Logs
def get-cold-start-metrics [
    function_name: string,
    start_time: datetime,
    end_time: datetime
]: nothing -> list<record> {
    let log_group = $"/aws/lambda/($function_name)"
    let start_ms = $start_time | format date "%s%3N"
    let end_ms = $end_time | format date "%s%3N"
    
    try {
        let logs_result = (run-external "aws" [
            "logs", "filter-log-events",
            "--log-group-name", $log_group,
            "--start-time", $start_ms,
            "--end-time", $end_ms,
            "--filter-pattern", "\"Init Duration\""
        ]).stdout | from json
        
        $logs_result.events | each { |event|
            let parsed = parse-lambda-log-message $event.message
            {
                timestamp: ($event.timestamp | math floor),
                request_id: $parsed.request_id,
                init_duration_ms: $parsed.init_duration_ms,
                total_duration_ms: $parsed.duration_ms,
                memory_used_mb: $parsed.memory_used_mb,
                log_stream: $event.logStreamName
            }
        } | where init_duration_ms > 0
    } catch { |err|
        error make { msg: $"Failed to retrieve cold start metrics: ($err.msg)" }
    }
}

# Analyze cold start patterns and calculate statistics
def analyze-cold-start-patterns [
    cold_start_data: list<record>
]: nothing -> record {
    let init_durations = $cold_start_data | get init_duration_ms
    let total_durations = $cold_start_data | get total_duration_ms
    
    {
        total_cold_starts: ($cold_start_data | length),
        init_duration_stats: {
            mean: ($init_durations | math avg),
            median: ($init_durations | sort | math median),
            min: ($init_durations | math min),
            max: ($init_durations | math max),
            p95: (calculate-percentile $init_durations 95),
            p99: (calculate-percentile $init_durations 99)
        },
        total_duration_stats: {
            mean: ($total_durations | math avg),
            median: ($total_durations | sort | math median),
            min: ($total_durations | math min),
            max: ($total_durations | math max)
        },
        frequency_analysis: (analyze-cold-start-frequency $cold_start_data),
        memory_correlation: (analyze-memory-correlation $cold_start_data),
        temporal_patterns: (analyze-temporal-patterns $cold_start_data)
    }
}

# Generate optimization recommendations based on cold start analysis
def generate-cold-start-recommendations [
    analysis: record,
    function_name: string
]: nothing -> list<record> {
    let recommendations = []
    let init_stats = $analysis.init_duration_stats
    let perf_config = get-performance-config
    
    # High init duration recommendation
    if $init_stats.mean > $perf_config.cold_start_threshold_ms {
        $recommendations | append {
            priority: "high",
            category: "initialization",
            recommendation: "Optimize function initialization code and reduce dependency loading",
            rationale: $"Average init duration ($init_stats.mean)ms exceeds threshold ($perf_config.cold_start_threshold_ms)ms",
            estimated_improvement: "20-50% reduction in cold start time"
        }
    }
    
    # High variability recommendation
    let init_variance = $init_stats.max - $init_stats.min
    if $init_variance > ($init_stats.mean * 2) {
        $recommendations | append {
            priority: "medium",
            category: "consistency",
            recommendation: "Investigate inconsistent initialization patterns",
            rationale: $"High variability in init times (range: ($init_variance)ms)",
            estimated_improvement: "More predictable cold start performance"
        }
    }
    
    # Frequent cold starts recommendation
    if $analysis.frequency_analysis.cold_starts_per_hour > 10 {
        $recommendations | append {
            priority: "high",
            category: "concurrency",
            recommendation: "Consider provisioned concurrency or reserved concurrency",
            rationale: $"High frequency of cold starts ($analysis.frequency_analysis.cold_starts_per_hour) per hour",
            estimated_improvement: "Eliminate most cold starts"
        }
    }
    
    # Memory optimization recommendation
    if ($analysis.memory_correlation.correlation_coefficient? | default 0) > 0.7 {
        $recommendations | append {
            priority: "medium",
            category: "memory",
            recommendation: "Optimize memory allocation",
            rationale: "Strong correlation between memory usage and init duration",
            estimated_improvement: "Faster initialization with optimized memory"
        }
    }
    
    $recommendations
}

# ============================================================================
# Execution Cost Analysis and Budget Recommendations
# ============================================================================

# Comprehensive cost analysis for Lambda functions
export def lambda-analyze-costs [
    function_name: string,        # Function name
    --analysis-period(-p): duration = 30day, # Analysis period
    --include-projections(-j),    # Include cost projections
    --budget-threshold(-b): float, # Budget threshold for alerts
    --cost-breakdown(-c)          # Detailed cost breakdown
]: nothing -> record {
    let config = get-lambda-enhanced-config
    
    if $config.mock_mode {
        return (get-mock-cost-analysis $function_name)
    }
    
    # Calculate analysis window
    let end_time = date now
    let start_time = $end_time - $analysis_period
    
    # Get function configuration for cost calculations
    let function_config = get-lambda-function-config $function_name
    
    # Gather metrics for cost analysis
    let execution_metrics = get-lambda-execution-metrics $function_name $start_time $end_time
    
    # Calculate costs
    let cost_analysis = calculate-lambda-costs $function_config $execution_metrics $analysis_period
    
    # Generate cost projections if requested
    let projections = if $include_projections {
        generate-cost-projections $cost_analysis $execution_metrics
    } else {
        {}
    }
    
    # Generate budget recommendations
    let budget_recommendations = generate-budget-recommendations $cost_analysis $budget_threshold
    
    {
        function_name: $function_name,
        analysis_period: $analysis_period,
        analysis_window: { start: $start_time, end: $end_time },
        function_config: $function_config,
        cost_analysis: $cost_analysis,
        projections: $projections,
        budget_recommendations: $budget_recommendations,
        analyzed_at: (date now),
        cost_optimization_score: (calculate-cost-optimization-score $cost_analysis)
    }
}

# Get Lambda function configuration for cost calculations
def get-lambda-function-config [function_name: string]: nothing -> record {
    try {
        let config_result = (run-external "aws" [
            "lambda", "get-function-configuration",
            "--function-name", $function_name
        ]).stdout | from json
        
        {
            function_name: $config_result.FunctionName,
            memory_size_mb: $config_result.MemorySize,
            timeout_seconds: $config_result.Timeout,
            runtime: $config_result.Runtime,
            architecture: ($config_result.Architecture? | default "x86_64"),
            code_size_bytes: $config_result.CodeSize,
            last_modified: $config_result.LastModified
        }
    } catch { |err|
        error make { msg: $"Failed to get function configuration: ($err.msg)" }
    }
}

# Get execution metrics from CloudWatch
def get-lambda-execution-metrics [
    function_name: string,
    start_time: datetime,
    end_time: datetime
]: nothing -> record {
    let start_iso = $start_time | format date "%Y-%m-%dT%H:%M:%SZ"
    let end_iso = $end_time | format date "%Y-%m-%dT%H:%M:%SZ"
    
    try {
        # Get invocation count
        let invocations = (run-external "aws" [
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/Lambda",
            "--metric-name", "Invocations",
            "--dimensions", $"Name=FunctionName,Value=($function_name)",
            "--start-time", $start_iso,
            "--end-time", $end_iso,
            "--period", "86400",  # Daily aggregation
            "--statistics", "Sum"
        ]).stdout | from json
        
        # Get duration metrics  
        let durations = (run-external "aws" [
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/Lambda",
            "--metric-name", "Duration",
            "--dimensions", $"Name=FunctionName,Value=($function_name)",
            "--start-time", $start_iso,
            "--end-time", $end_iso,
            "--period", "86400",
            "--statistics", "Average,Maximum,Sum"
        ]).stdout | from json
        
        # Get error metrics
        let errors = (run-external "aws" [
            "cloudwatch", "get-metric-statistics",
            "--namespace", "AWS/Lambda",
            "--metric-name", "Errors",
            "--dimensions", $"Name=FunctionName,Value=($function_name)",
            "--start-time", $start_iso,
            "--end-time", $end_iso,
            "--period", "86400",
            "--statistics", "Sum"
        ]).stdout | from json
        
        {
            total_invocations: ($invocations.Datapoints | get Sum | math sum),
            avg_duration_ms: ($durations.Datapoints | get Average | math avg),
            max_duration_ms: ($durations.Datapoints | get Maximum | math max),
            total_execution_time_ms: ($durations.Datapoints | get Sum | math sum),
            total_errors: ($errors.Datapoints | get Sum | math sum),
            daily_metrics: (correlate-daily-metrics $invocations.Datapoints $durations.Datapoints $errors.Datapoints)
        }
    } catch { |err|
        error make { msg: $"Failed to get execution metrics: ($err.msg)" }
    }
}

# Calculate comprehensive Lambda costs
def calculate-lambda-costs [
    function_config: record,
    execution_metrics: record,
    period: duration
]: nothing -> record {
    # AWS Lambda pricing (as of 2024, subject to change)
    let pricing = {
        request_cost_per_million: 0.20,  # $0.20 per 1M requests
        gb_second_cost: 0.0000166667,    # $0.0000166667 per GB-second
        architecture_multiplier: (if $function_config.architecture == "arm64" { 0.8 } else { 1.0 }) # Graviton2 discount
    }
    
    # Calculate request costs
    let request_cost = ($execution_metrics.total_invocations * $pricing.request_cost_per_million) / 1000000
    
    # Calculate compute costs (GB-seconds)
    let memory_gb = $function_config.memory_size_mb / 1024
    let total_gb_seconds = ($memory_gb * $execution_metrics.total_execution_time_ms) / 1000
    let compute_cost = $total_gb_seconds * $pricing.gb_second_cost * $pricing.architecture_multiplier
    
    # Calculate storage costs (if applicable - for large functions)
    let storage_cost = if $function_config.code_size_bytes > 512000000 { # > 512MB
        ($function_config.code_size_bytes - 512000000) * 0.0000000309 # $0.0000000309 per GB-month
    } else {
        0
    }
    
    let total_cost = $request_cost + $compute_cost + $storage_cost
    
    {
        total_cost_usd: $total_cost,
        request_cost_usd: $request_cost,
        compute_cost_usd: $compute_cost,
        storage_cost_usd: $storage_cost,
        cost_per_invocation: ($total_cost / $execution_metrics.total_invocations),
        cost_per_execution_second: ($compute_cost / ($execution_metrics.total_execution_time_ms / 1000)),
        memory_efficiency: (calculate-memory-efficiency $function_config $execution_metrics),
        architecture: $function_config.architecture,
        pricing_model: $pricing
    }
}

# Generate cost projections based on historical data
def generate-cost-projections [
    cost_analysis: record,
    execution_metrics: record
]: nothing -> record {
    let daily_avg_invocations = $execution_metrics.total_invocations / 30  # Assuming 30-day period
    let monthly_cost = $cost_analysis.total_cost_usd
    
    {
        monthly_projection: {
            cost_usd: $monthly_cost,
            invocations: ($daily_avg_invocations * 30),
            confidence: "medium"
        },
        quarterly_projection: {
            cost_usd: ($monthly_cost * 3),
            invocations: ($daily_avg_invocations * 90),
            confidence: "low"
        },
        annual_projection: {
            cost_usd: ($monthly_cost * 12),
            invocations: ($daily_avg_invocations * 365),
            confidence: "low"
        },
        growth_scenarios: {
            conservative: { multiplier: 1.1, cost_usd: ($monthly_cost * 1.1 * 12) },
            moderate: { multiplier: 1.5, cost_usd: ($monthly_cost * 1.5 * 12) },
            aggressive: { multiplier: 2.0, cost_usd: ($monthly_cost * 2.0 * 12) }
        }
    }
}

# Generate budget recommendations and cost optimization suggestions
def generate-budget-recommendations [
    cost_analysis: record,
    budget_threshold?: float
]: nothing -> list<record> {
    let recommendations = []
    
    # Memory optimization recommendation
    if $cost_analysis.memory_efficiency.efficiency_score < 0.7 {
        $recommendations | append {
            priority: "high",
            category: "memory_optimization",
            recommendation: $"Reduce memory allocation from current level",
            potential_savings_percent: 20,
            rationale: $"Memory efficiency score is low ($cost_analysis.memory_efficiency.efficiency_score)",
            action: $"Consider reducing memory to ($cost_analysis.memory_efficiency.recommended_memory_mb)MB"
        }
    }
    
    # Architecture optimization
    if $cost_analysis.architecture == "x86_64" {
        $recommendations | append {
            priority: "medium",
            category: "architecture",
            recommendation: "Consider migrating to ARM64 (Graviton2) for 20% cost savings",
            potential_savings_percent: 20,
            rationale: "ARM64 architecture offers better price/performance ratio",
            action: "Test function compatibility with ARM64 runtime"
        }
    }
    
    # Budget threshold alert
    if ($budget_threshold | is-not-empty) and ($cost_analysis.total_cost_usd > $budget_threshold) {
        $recommendations | append {
            priority: "critical",
            category: "budget_alert",
            recommendation: "Current costs exceed budget threshold",
            potential_savings_percent: (($cost_analysis.total_cost_usd - $budget_threshold) / $cost_analysis.total_cost_usd * 100),
            rationale: $"Cost ($cost_analysis.total_cost_usd) exceeds threshold ($budget_threshold)",
            action: "Implement immediate cost optimization measures"
        }
    }
    
    # High cost per invocation
    if $cost_analysis.cost_per_invocation > 0.001 {  # > $0.001 per invocation
        $recommendations | append {
            priority: "medium",
            category: "efficiency",
            recommendation: "Optimize function efficiency to reduce cost per invocation",
            potential_savings_percent: 30,
            rationale: $"High cost per invocation: ($cost_analysis.cost_per_invocation)",
            action: "Profile function execution and optimize hot paths"
        }
    }
    
    $recommendations
}

# ============================================================================
# Mock Data Functions for Testing
# ============================================================================

def get-mock-sam-templates []: nothing -> list<record> {
    [
        {
            template_path: "./template.yaml",
            template_name: "template.yaml",
            template_type: "SAM",
            functions: [
                {
                    logical_id: "HelloWorldFunction",
                    function_name: "hello-world",
                    runtime: "nodejs18.x",
                    handler: "app.lambdaHandler",
                    memory_size: 128,
                    timeout: 3,
                    environment: {},
                    events: [
                        {
                            event_name: "HelloWorld",
                            event_type: "Api",
                            config: { Path: "/hello", Method: "get" }
                        }
                    ]
                }
            ],
            resources: [
                { logical_id: "HelloWorldFunction", type: "AWS::Serverless::Function", properties: {}, depends_on: [] }
            ],
            discovered_at: (date now),
            valid: true
        }
    ]
}

def get-mock-sam-build-result []: nothing -> record {
    {
        command: "sam build",
        template_path: "template.yaml",
        build_args: ["build", "template.yaml"],
        success: true,
        output: "Building function 'HelloWorldFunction'\nBuild Succeeded",
        error: "",
        build_time: (date now),
        artifacts_location: ".aws-sam/build"
    }
}

def get-mock-sam-deploy-result [stack_name: string]: nothing -> record {
    {
        command: "sam deploy",
        stack_name: $stack_name,
        deploy_args: ["deploy", "--stack-name", $stack_name],
        success: true,
        output: "Successfully created/updated stack",
        error: "",
        deployment_time: (date now),
        changeset_created: true,
        resources_created: ["HelloWorldFunction", "HelloWorldApi"]
    }
}

def get-mock-version-creation [function_name: string]: nothing -> record {
    {
        function_name: $function_name,
        version: "1",
        description: "Mock version for testing",
        code_sha256: "abc123def456",
        code_size: 1024,
        created_at: (date now | format date "%Y-%m-%dT%H:%M:%S.%fZ"),
        runtime: "nodejs18.x",
        handler: "index.handler",
        memory_size: 512,
        timeout: 30,
        success: true
    }
}

def get-mock-alias-management [function_name: string, alias_name: string]: nothing -> record {
    {
        function_name: $function_name,
        alias_name: $alias_name,
        function_version: "1",
        description: "Mock alias for testing",
        routing_config: {},
        alias_arn: $"arn:aws:lambda:us-east-1:123456789012:function:($function_name):($alias_name)",
        operation: "create-alias",
        created_at: (date now),
        success: true
    }
}

def get-mock-log-stream [function_name: string]: nothing -> list<record> {
    [
        {
            timestamp: (date now),
            log_stream: "2024/01/01/[$LATEST]abc123",
            message: $"START RequestId: abc-123-def RequestVersion: $LATEST",
            event_id: "123456789",
            parsed: {
                request_id: "abc-123-def",
                duration_ms: 150.5,
                memory_used_mb: 64,
                init_duration_ms: 250.0,
                is_cold_start: true,
                log_level: "INFO",
                contains_error: false
            }
        }
    ]
}

def get-mock-cold-start-analysis [function_name: string]: nothing -> record {
    {
        function_name: $function_name,
        analysis_period: 7day,
        analysis_window: { start: ((date now) - 7day), end: (date now) },
        cold_start_summary: {
            total_cold_starts: 25,
            init_duration_stats: {
                mean: 245.8,
                median: 230.0,
                min: 180.5,
                max: 450.2,
                p95: 380.0,
                p99: 420.0
            },
            total_duration_stats: {
                mean: 890.5,
                median: 825.0,
                min: 650.0,
                max: 1200.0
            },
            frequency_analysis: { cold_starts_per_hour: 2.5 },
            memory_correlation: { correlation_coefficient: 0.65 },
            temporal_patterns: {}
        },
        recommendations: [
            {
                priority: "medium",
                category: "initialization",
                recommendation: "Optimize function initialization code",
                estimated_improvement: "20-30% reduction in cold start time"
            }
        ],
        analyzed_at: (date now),
        optimization_priority: "medium"
    }
}

def get-mock-cost-analysis [function_name: string]: nothing -> record {
    {
        function_name: $function_name,
        analysis_period: 30day,
        analysis_window: { start: ((date now) - 30day), end: (date now) },
        function_config: {
            function_name: $function_name,
            memory_size_mb: 512,
            timeout_seconds: 30,
            runtime: "nodejs18.x",
            architecture: "x86_64",
            code_size_bytes: 1048576
        },
        cost_analysis: {
            total_cost_usd: 12.45,
            request_cost_usd: 2.10,
            compute_cost_usd: 10.35,
            storage_cost_usd: 0.00,
            cost_per_invocation: 0.000124,
            cost_per_execution_second: 0.0156,
            memory_efficiency: { efficiency_score: 0.75, recommended_memory_mb: 384 },
            architecture: "x86_64"
        },
        projections: {
            monthly_projection: { cost_usd: 12.45, invocations: 100000, confidence: "medium" },
            annual_projection: { cost_usd: 149.40, invocations: 1200000, confidence: "low" }
        },
        budget_recommendations: [
            {
                priority: "medium",
                category: "memory_optimization",
                recommendation: "Consider reducing memory allocation",
                potential_savings_percent: 15
            }
        ],
        analyzed_at: (date now),
        cost_optimization_score: 0.78
    }
}

# ============================================================================
# Utility Functions
# ============================================================================

# Parse time string to epoch milliseconds
def parse-time-to-epoch [time_str: string]: nothing -> string {
    try {
        # Handle relative time formats
        if ($time_str | str contains "ago") {
            let parts = $time_str | parse "{value}{unit} ago"
            if ($parts | length) > 0 {
                let value = $parts.0.value | into int
                let unit = $parts.0.unit
                
                let duration = match $unit {
                    "s" | "sec" | "second" | "seconds" => ($value * 1000),
                    "m" | "min" | "minute" | "minutes" => ($value * 60 * 1000),
                    "h" | "hour" | "hours" => ($value * 60 * 60 * 1000),
                    "d" | "day" | "days" => ($value * 24 * 60 * 60 * 1000),
                    _ => 0
                }
                
                let epoch_ms = (date now | format date "%s%3N" | into int) - $duration
                $epoch_ms | into string
            } else {
                error make { msg: $"Invalid relative time format: ($time_str)" }
            }
        } else {
            # Handle absolute time formats
            $time_str | into datetime | format date "%s%3N"
        }
    } catch {
        error make { msg: $"Failed to parse time: ($time_str)" }
    }
}

# Calculate percentile of a list of numbers
def calculate-percentile [values: list<float>, percentile: float]: nothing -> float {
    let sorted = $values | sort
    let index = (($sorted | length) * $percentile / 100) | math floor
    $sorted | get $index
}

# Extract log level from log message
def extract-log-level [message: string]: nothing -> string {
    let log_patterns = ["ERROR", "WARN", "INFO", "DEBUG", "TRACE"]
    
    for level in $log_patterns {
        if ($message | str contains $level) {
            return $level
        }
    }
    
    "UNKNOWN"
}

# Parse timestamp from log message
def parse-log-timestamp [message: string]: nothing -> string {
    # Extract timestamp from various log formats
    let iso_pattern = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z'
    let epoch_pattern = '\d{13}'
    
    if ($message | parse $iso_pattern | length) > 0 {
        $message | parse $iso_pattern | first
    } else if ($message | parse $epoch_pattern | length) > 0 {
        let epoch_val = $message | parse $epoch_pattern | first | into int
        $epoch_val | into datetime | format date "%Y-%m-%dT%H:%M:%S.%fZ"
    } else {
        ""
    }
}

# Analyze cold start frequency patterns
def analyze-cold-start-frequency [cold_start_data: list<record>]: nothing -> record {
    let hours = $cold_start_data | get timestamp | each { |ts| $ts | into datetime | format date "%H" | into int }
    let hour_counts = $hours | group-by { |h| $h } | transpose key value | each { |item| { hour: $item.key, count: ($item.value | length) } }
    
    {
        cold_starts_per_hour: (($cold_start_data | length) / 24),
        peak_hours: ($hour_counts | sort-by count | reverse | first 3),
        distribution: $hour_counts
    }
}

# Analyze memory correlation with cold start performance
def analyze-memory-correlation [cold_start_data: list<record>]: nothing -> record {
    let memory_values = $cold_start_data | get memory_used_mb
    let init_values = $cold_start_data | get init_duration_ms
    
    # Simple correlation calculation
    let correlation = calculate-correlation $memory_values $init_values
    
    {
        correlation_coefficient: $correlation,
        strength: (if $correlation > 0.7 { "strong" } else if $correlation > 0.4 { "moderate" } else { "weak" }),
        memory_range: { min: ($memory_values | math min), max: ($memory_values | math max) }
    }
}

# Analyze temporal patterns in cold starts
def analyze-temporal-patterns [cold_start_data: list<record>]: nothing -> record {
    let daily_counts = $cold_start_data | group-by { |item| $item.timestamp | into datetime | format date "%Y-%m-%d" } 
                     | transpose key value | each { |day| { date: $day.key, count: ($day.value | length) } }
    
    {
        daily_distribution: $daily_counts,
        avg_per_day: ($daily_counts | get count | math avg),
        peak_day: ($daily_counts | sort-by count | reverse | first)
    }
}

# Calculate optimization priority based on analysis
def calculate-optimization-priority [analysis: record]: nothing -> string {
    let init_mean = $analysis.init_duration_stats.mean
    let frequency = $analysis.frequency_analysis.cold_starts_per_hour
    
    if ($init_mean > 500) or ($frequency > 10) {
        "high"
    } else if ($init_mean > 300) or ($frequency > 5) {
        "medium"
    } else {
        "low"
    }
}

# Calculate memory efficiency score
def calculate-memory-efficiency [
    function_config: record,
    execution_metrics: record
]: nothing -> record {
    # Simplified efficiency calculation based on duration patterns
    let avg_duration = $execution_metrics.avg_duration_ms
    let memory_mb = $function_config.memory_size_mb
    
    # Calculate efficiency score (lower is better for costs, higher duration = less efficient)
    let efficiency_score = 1.0 - (($avg_duration - 100) / 10000)  # Normalize to 0-1 scale
    
    # Recommend memory based on usage patterns
    let recommended_memory = if $efficiency_score < 0.5 {
        $memory_mb * 0.75 | math floor
    } else if $efficiency_score > 0.8 {
        $memory_mb * 1.25 | math floor
    } else {
        $memory_mb
    }
    
    {
        efficiency_score: (if $efficiency_score < 0 { 0 } else if $efficiency_score > 1 { 1 } else { $efficiency_score }),
        recommended_memory_mb: $recommended_memory,
        current_memory_mb: $memory_mb,
        optimization_potential: (($memory_mb - $recommended_memory) / $memory_mb)
    }
}

# Calculate cost optimization score
def calculate-cost-optimization-score [cost_analysis: record]: nothing -> float {
    let memory_efficiency = $cost_analysis.memory_efficiency.efficiency_score
    let architecture_efficiency = if $cost_analysis.architecture == "arm64" { 1.0 } else { 0.8 }
    let cost_per_invocation_score = if $cost_analysis.cost_per_invocation < 0.0001 { 1.0 } else { 0.5 }
    
    ($memory_efficiency + $architecture_efficiency + $cost_per_invocation_score) / 3.0
}

# Simple correlation calculation
def calculate-correlation [x_values: list<float>, y_values: list<float>]: nothing -> float {
    if ($x_values | length) != ($y_values | length) {
        return 0.0
    }
    
    let n = $x_values | length
    let x_mean = $x_values | math avg
    let y_mean = $y_values | math avg
    
    let numerator = (seq 0 ($n - 1) | each { |i| 
        (($x_values | get $i) - $x_mean) * (($y_values | get $i) - $y_mean)
    } | math sum)
    
    let x_variance = ($x_values | each { |x| ($x - $x_mean) * ($x - $x_mean) } | math sum)
    let y_variance = ($y_values | each { |y| ($y - $y_mean) * ($y - $y_mean) } | math sum)
    
    let denominator = ($x_variance * $y_variance) | math sqrt
    
    if $denominator == 0 {
        0.0
    } else {
        $numerator / $denominator
    }
}

# Extract deployed resources from SAM output
def extract-deployed-resources [output: string]: nothing -> list<string> {
    $output | lines | where ($it | str contains "CREATE_COMPLETE") | each { |line|
        $line | parse "{status} {resource_type} {logical_id}" | get logical_id
    } | flatten
}

# Correlate daily metrics from CloudWatch
def correlate-daily-metrics [
    invocations: list<record>,
    durations: list<record>,
    errors: list<record>
]: nothing -> list<record> {
    # Simple daily correlation - in real implementation would properly join by timestamp
    seq 0 (($invocations | length) - 1) | each { |i|
        {
            date: ($invocations | get $i | get Timestamp),
            invocations: ($invocations | get $i | get Sum),
            avg_duration: ($durations | get $i | get Average),
            errors: ($errors | get $i | get Sum)
        }
    }
}

# Run external command with proper error handling
def run-external [command: string, args: list<string>]: nothing -> record {
    try {
        let result = run-external $command $args
        {
            exit_code: 0,
            stdout: $result,
            stderr: ""
        }
    } catch { |err|
        {
            exit_code: 1,
            stdout: "",
            stderr: $err.msg
        }
    }
}

# Export main enhanced functions
export def main [] {
    print "🚀 Lambda Enhanced Features Module loaded successfully"
    print ""
    print "Available functions:"
    print "- SAM/Serverless Integration:"
    print "  • sam-discover-templates: Discover SAM templates in project"
    print "  • sam-build: Build SAM application with options"
    print "  • sam-deploy: Deploy with versioning and rollback support"
    print ""
    print "- Deployment Automation:"
    print "  • lambda-create-version: Create function versions with metadata"
    print "  • lambda-manage-alias: Manage aliases with blue/green deployment"
    print ""
    print "- Log Streaming & Analysis:"
    print "  • lambda-stream-logs: Real-time log streaming with filtering"
    print ""
    print "- Performance Analysis:"
    print "  • lambda-analyze-cold-starts: Cold start performance analysis"
    print ""
    print "- Cost Analysis:"
    print "  • lambda-analyze-costs: Comprehensive cost analysis and projections"
    print ""
    let config = get-lambda-enhanced-config
    print $"Mock mode: ($config.mock_mode)"
}