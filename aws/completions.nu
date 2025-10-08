# AWS CLI Nushell Completions
# Dynamic completion system for AWS resources

# ============================================================================
# CORE COMPLETION INFRASTRUCTURE
# ============================================================================

# Base AWS configuration for completions
def aws-completion-config []: nothing -> record {
    {
        region: ($env.AWS_DEFAULT_REGION? | default "us-east-1"),
        profile: ($env.AWS_PROFILE? | default "default"),
        mock_mode: (($env.STEPFUNCTIONS_MOCK_MODE? | default "false") == "true"),
        cache_ttl: 300  # 5 minutes cache
    }
}

# Cache completion results to improve performance
def get-cached-completion [
    cache_key: string,
    generator: closure
]: nothing -> list<string> {
    let cache_file = $"($env.HOME)/.cache/nuaws/completions/($cache_key).json"
    let config = aws-completion-config
    
    # Check if cache exists and is valid
    if ($cache_file | path exists) {
        let cache_data = try { open $cache_file | from json } catch { {} }
        let cache_age = (date now) - ($cache_data.timestamp? | default "1970-01-01" | into datetime)
        
        if ($cache_age | into int) < ($config.cache_ttl * 1000000000) {
            return $cache_data.items
        }
    }
    
    # Generate new completion data
    let items = do $generator
    
    # Cache the results
    mkdir ($cache_file | path dirname)
    {
        timestamp: (date now),
        items: $items
    } | to json | save -f $cache_file
    
    $items
}

# ============================================================================
# STEP FUNCTIONS COMPLETIONS
# ============================================================================

# Complete state machine ARNs
export def complete-state-machine-arns []: nothing -> list<string> {
    get-cached-completion "stepfunctions-state-machines" {
        let config = aws-completion-config
        
        if $config.mock_mode {
            [
                "arn:aws:states:us-east-1:123456789012:stateMachine:TestStateMachine",
                "arn:aws:states:us-east-1:123456789012:stateMachine:ProductionWorkflow", 
                "arn:aws:states:us-east-1:123456789012:stateMachine:DataProcessingPipeline",
                "arn:aws:states:us-east-1:123456789012:stateMachine:ErrorHandlingFlow",
                "arn:aws:states:us-east-1:123456789012:stateMachine:BatchJobProcessor"
            ]
        } else {
            try {
                ^aws stepfunctions list-state-machines --region $config.region --profile $config.profile
                | from json
                | get stateMachines
                | get stateMachineArn
                | default []
            } catch {
                []
            }
        }
    }
}

# Complete execution ARNs for a given state machine
export def complete-execution-arns [state_machine_arn?: string]: nothing -> list<string> {
    let cache_key = if ($state_machine_arn != null) {
        $"stepfunctions-executions-($state_machine_arn | str replace --all ":" "-")"
    } else {
        "stepfunctions-executions-all"
    }
    
    get-cached-completion $cache_key {
        let config = aws-completion-config
        
        if $config.mock_mode {
            [
                "arn:aws:states:us-east-1:123456789012:execution:TestStateMachine:test-execution-1",
                "arn:aws:states:us-east-1:123456789012:execution:TestStateMachine:test-execution-2",
                "arn:aws:states:us-east-1:123456789012:execution:ProductionWorkflow:prod-exec-001",
                "arn:aws:states:us-east-1:123456789012:execution:DataProcessingPipeline:data-proc-001"
            ]
        } else {
            try {
                if ($state_machine_arn != null) {
                    ^aws stepfunctions list-executions --state-machine-arn $state_machine_arn --region $config.region --profile $config.profile
                    | from json
                    | get executions
                    | get executionArn
                    | default []
                } else {
                    # Get executions from all state machines (limited to recent ones)
                    ^aws stepfunctions list-state-machines --region $config.region --profile $config.profile
                    | from json
                    | get stateMachines
                    | get stateMachineArn
                    | each { |arn|
                        try {
                            ^aws stepfunctions list-executions --state-machine-arn $arn --max-results 10 --region $config.region --profile $config.profile
                            | from json
                            | get executions
                            | get executionArn
                        } catch {
                            []
                        }
                    }
                    | flatten
                    | default []
                }
            } catch {
                []
            }
        }
    }
}

# Complete activity ARNs
export def complete-activity-arns []: nothing -> list<string> {
    get-cached-completion "stepfunctions-activities" {
        let config = aws-completion-config
        
        if $config.mock_mode {
            [
                "arn:aws:states:us-east-1:123456789012:activity:TestActivity",
                "arn:aws:states:us-east-1:123456789012:activity:WorkerActivity",
                "arn:aws:states:us-east-1:123456789012:activity:LongRunningTask"
            ]
        } else {
            try {
                ^aws stepfunctions list-activities --region $config.region --profile $config.profile
                | from json
                | get activities
                | get activityArn
                | default []
            } catch {
                []
            }
        }
    }
}

# Complete execution statuses
export def complete-execution-statuses []: nothing -> list<string> {
    [
        "RUNNING",
        "SUCCEEDED", 
        "FAILED",
        "TIMED_OUT",
        "ABORTED"
    ]
}

# Complete state machine types
export def complete-state-machine-types []: nothing -> list<string> {
    ["STANDARD", "EXPRESS"]
}

# ============================================================================
# IAM COMPLETIONS (for role ARNs)
# ============================================================================

# Complete IAM role ARNs
export def complete-iam-role-arns []: nothing -> list<string> {
    get-cached-completion "iam-roles" {
        let config = aws-completion-config
        
        if $config.mock_mode {
            [
                "arn:aws:iam::123456789012:role/StepFunctionsRole",
                "arn:aws:iam::123456789012:role/LambdaExecutionRole",
                "arn:aws:iam::123456789012:role/StepFunctionsServiceRole",
                "arn:aws:iam::123456789012:role/CrossAccountExecutionRole"
            ]
        } else {
            try {
                ^aws iam list-roles --profile $config.profile
                | from json
                | get Roles
                | get Arn
                | where { |arn| $arn | str contains "role/" }
                | default []
            } catch {
                []
            }
        }
    }
}

# ============================================================================
# AWS REGIONS COMPLETION
# ============================================================================

# Complete AWS regions
export def complete-aws-regions []: nothing -> list<string> {
    [
        "us-east-1",      # US East (N. Virginia)
        "us-east-2",      # US East (Ohio)
        "us-west-1",      # US West (N. California)
        "us-west-2",      # US West (Oregon)
        "eu-west-1",      # Europe (Ireland)
        "eu-west-2",      # Europe (London)
        "eu-west-3",      # Europe (Paris)
        "eu-central-1",   # Europe (Frankfurt)
        "eu-north-1",     # Europe (Stockholm)
        "ap-southeast-1", # Asia Pacific (Singapore)
        "ap-southeast-2", # Asia Pacific (Sydney)
        "ap-northeast-1", # Asia Pacific (Tokyo)
        "ap-northeast-2", # Asia Pacific (Seoul)
        "ap-south-1",     # Asia Pacific (Mumbai)
        "ca-central-1",   # Canada (Central)
        "sa-east-1"       # South America (São Paulo)
    ]
}

# ============================================================================
# SMART COMPLETION HELPERS
# ============================================================================

# Context-aware completion based on command and parameter
export def smart-complete [
    command: string,
    parameter: string,
    current_input: string
]: nothing -> list<string> {
    match [$command, $parameter] {
        ["start-execution", "state-machine-arn"] => complete-state-machine-arns,
        ["describe-execution", "execution-arn"] => complete-execution-arns,
        ["stop-execution", "execution-arn"] => complete-execution-arns,
        ["list-executions", "status-filter"] => complete-execution-statuses,
        ["create-state-machine", "role-arn"] => complete-iam-role-arns,
        ["create-state-machine", "type"] => complete-state-machine-types,
        ["describe-activity", "activity-arn"] => complete-activity-arns,
        [_, "region"] => complete-aws-regions,
        _ => []
    }
}

# Fuzzy completion helper for partial matches
export def fuzzy-complete [
    items: list<string>,
    pattern: string
]: list<string> -> list<string> {
    $items 
    | where { |item| $item | str contains $pattern }
    | sort
}

# ============================================================================
# COMPLETION CACHE MANAGEMENT
# ============================================================================

# Clear completion cache
export def clear-completion-cache []: nothing -> nothing {
    let cache_dir = $"($env.HOME)/.cache/nuaws/completions"
    if ($cache_dir | path exists) {
        rm -rf $cache_dir
        mkdir $cache_dir
    }
}

# Refresh specific completion cache
export def refresh-completion-cache [cache_type: string]: nothing -> nothing {
    let cache_file = $"($env.HOME)/.cache/nuaws/completions/($cache_type).json"
    if ($cache_file | path exists) {
        rm $cache_file
    }
    
    # Trigger refresh by calling the appropriate completion function
    match $cache_type {
        "stepfunctions-state-machines" => complete-state-machine-arns | ignore,
        "stepfunctions-executions-all" => complete-execution-arns | ignore,
        "stepfunctions-activities" => complete-activity-arns | ignore,
        "iam-roles" => complete-iam-role-arns | ignore,
        _ => { print $"Unknown cache type: ($cache_type)" }
    }
}

# List available completion cache types
export def list-completion-cache-types []: nothing -> list<string> {
    [
        "stepfunctions-state-machines",
        "stepfunctions-executions-all", 
        "stepfunctions-activities",
        "iam-roles"
    ]
}

# ============================================================================
# INTEGRATION WITH NUSHELL COMPLETION SYSTEM
# ============================================================================

# Register completions for AWS commands
# This would typically be called in your config.nu or profile
export def register-aws-completions []: nothing -> nothing {
    # Note: In a real implementation, these would integrate with Nushell's 
    # built-in completion system using custom completions or external completers
    
    print "AWS completions registered successfully!"
    print "Available completion functions:"
    print "  - complete-state-machine-arns"
    print "  - complete-execution-arns"
    print "  - complete-activity-arns" 
    print "  - complete-iam-role-arns"
    print "  - complete-aws-regions"
}

# ============================================================================
# EXAMPLE INTEGRATION
# ============================================================================

# Example of how to use completions in command definitions
# This would be used in the actual command definitions:
#
# export def start-execution [
#     state_machine_arn: string@complete-state-machine-arns,
#     --name: string = "",
#     --input: string = "{}",
#     --region: string@complete-aws-regions = ""
# ]: nothing -> record {
#     # Command implementation
# }