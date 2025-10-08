# Completion Registry - AWS Resource Discovery and Completion Management
# Provides intelligent completion discovery, caching, and registration for AWS resources

use configuration.nu
use error_handler.nu

# Initialize completion registry environment
export-env {
    $env.NUAWS_COMPLETION_REGISTRY = {}
    $env.NUAWS_COMPLETION_CACHE = {}
    $env.NUAWS_COMPLETION_METADATA = {}
    $env.NUAWS_COMPLETION_STATS = {
        total_registrations: 0,
        cache_hits: 0,
        cache_misses: 0,
        discovery_calls: 0,
        last_cleanup: (date now)
    }
}

# Register a completion function for a service operation
export def register-completion [
    service_name: string,
    operation_name: string,
    parameter_name: string,
    completion_function: string,
    --cache-ttl: int = 300,
    --priority: int = 100,
    --description: string = ""
]: nothing -> record {
    
    let completion_key = build-completion-key $service_name $operation_name $parameter_name
    
    let completion_entry = {
        service: $service_name,
        operation: $operation_name,
        parameter: $parameter_name,
        function: $completion_function,
        cache_ttl: $cache_ttl,
        priority: $priority,
        description: $description,
        registered_at: (date now),
        usage_count: 0,
        last_used: null,
        cache_key: $completion_key
    }
    
    # Store in registry
    $env.NUAWS_COMPLETION_REGISTRY = ($env.NUAWS_COMPLETION_REGISTRY | insert $completion_key $completion_entry)
    
    # Update statistics
    let current_stats = $env.NUAWS_COMPLETION_STATS
    $env.NUAWS_COMPLETION_STATS = ($current_stats | update total_registrations ($current_stats.total_registrations + 1))
    
    {
        success: true,
        completion_key: $completion_key,
        message: $"Completion registered for ($service_name) ($operation_name) --($parameter_name)"
    }
}

# Discover AWS resources for completion
export def discover-aws-resources [
    service_name: string,
    resource_type: string,
    --region: string,
    --force-refresh = false
]: nothing -> list {
    
    let cache_key = $"($service_name):($resource_type):($region | default 'default')"
    let cache_ttl = configuration get "completion_cache_ttl" | into int
    
    # Check cache first unless force refresh
    if not $force_refresh {
        let cached_result = get-cached-completion $cache_key
        if $cached_result != null {
            update-completion-stats "cache_hits"
            return $cached_result.data
        }
    }
    
    # Record cache miss
    update-completion-stats "cache_misses"
    update-completion-stats "discovery_calls"
    
    # Discover resources based on service and type
    let discovered_resources = match [$service_name, $resource_type] {
        ["s3", "buckets"] => { discover-s3-buckets },
        ["s3", "objects"] => { discover-s3-objects $region },
        ["ec2", "instances"] => { discover-ec2-instances $region },
        ["ec2", "vpcs"] => { discover-ec2-vpcs $region },
        ["ec2", "subnets"] => { discover-ec2-subnets $region },
        ["ec2", "security-groups"] => { discover-ec2-security-groups $region },
        ["ec2", "key-pairs"] => { discover-ec2-key-pairs $region },
        ["ec2", "images"] => { discover-ec2-images $region },
        ["iam", "users"] => { discover-iam-users },
        ["iam", "roles"] => { discover-iam-roles },
        ["iam", "policies"] => { discover-iam-policies },
        ["lambda", "functions"] => { discover-lambda-functions $region },
        ["dynamodb", "tables"] => { discover-dynamodb-tables $region },
        ["rds", "instances"] => { discover-rds-instances $region },
        ["rds", "clusters"] => { discover-rds-clusters $region },
        _ => { [] }
    }
    
    # Cache the result
    let cache_entry = {
        data: $discovered_resources,
        cached_at: (date now),
        expires_at: ((date now) + ($cache_ttl * 1sec)),
        cache_key: $cache_key,
        resource_count: ($discovered_resources | length)
    }
    
    $env.NUAWS_COMPLETION_CACHE = ($env.NUAWS_COMPLETION_CACHE | insert $cache_key $cache_entry)
    
    $discovered_resources
}

# Get cached completion data
export def get-cached-completion [cache_key: string]: nothing -> any {
    if $cache_key in $env.NUAWS_COMPLETION_CACHE {
        let cache_entry = $env.NUAWS_COMPLETION_CACHE | get $cache_key
        
        # Check if cache entry has expired
        if (date now) < $cache_entry.expires_at {
            return $cache_entry
        } else {
            # Remove expired entry
            $env.NUAWS_COMPLETION_CACHE = ($env.NUAWS_COMPLETION_CACHE | reject $cache_key)
        }
    }
    
    null
}

# List all registered completions
export def list-completions [
    --service: string,
    --operation: string,
    --parameter: string
]: nothing -> table {
    
    let completions = $env.NUAWS_COMPLETION_REGISTRY | transpose key entry | each { |item|
        $item.entry | insert completion_key $item.key
    }
    
    # Apply filters
    mut filtered = $completions
    
    if $service != null {
        $filtered = ($filtered | where service == $service)
    }
    
    if $operation != null {
        $filtered = ($filtered | where operation == $operation)
    }
    
    if $parameter != null {
        $filtered = ($filtered | where parameter == $parameter)
    }
    
    $filtered | sort-by service operation parameter
}

# Get completion suggestions for a specific context
export def get-completions [
    service_name: string,
    operation_name: string,
    parameter_name: string,
    --partial: string = "",
    --limit: int = 50
]: nothing -> list {
    
    let completion_key = build-completion-key $service_name $operation_name $parameter_name
    
    # Check if completion is registered
    if $completion_key not-in $env.NUAWS_COMPLETION_REGISTRY {
        return []
    }
    
    let completion_entry = $env.NUAWS_COMPLETION_REGISTRY | get $completion_key
    
    # Update usage statistics
    let updated_entry = $completion_entry 
        | update usage_count ($completion_entry.usage_count + 1)
        | update last_used (date now)
    
    $env.NUAWS_COMPLETION_REGISTRY = ($env.NUAWS_COMPLETION_REGISTRY | update $completion_key $updated_entry)
    
    # Execute completion function
    let completion_function = $completion_entry.function
    
    try {
        let raw_completions = match $completion_function {
            "discover-s3-buckets" => { discover-aws-resources $service_name "buckets" },
            "discover-ec2-instances" => { discover-aws-resources $service_name "instances" },
            "discover-iam-users" => { discover-aws-resources $service_name "users" },
            "discover-lambda-functions" => { discover-aws-resources $service_name "functions" },
            _ => { [] }
        }
        
        # Filter by partial match if provided
        let filtered_completions = if ($partial | str length) > 0 {
            $raw_completions | where ($it | str contains $partial)
        } else {
            $raw_completions
        }
        
        # Limit results
        $filtered_completions | first $limit
        
    } catch {
        []
    }
}

# Auto-register completions for well-known AWS services
export def auto-register-standard-completions []: nothing -> record {
    mut registration_count = 0
    
    # S3 completions
    register-completion "s3" "ls" "bucket" "discover-s3-buckets" --description="S3 bucket names" | ignore
    register-completion "s3" "cp" "source" "discover-s3-buckets" --description="S3 source buckets" | ignore
    register-completion "s3" "cp" "destination" "discover-s3-buckets" --description="S3 destination buckets" | ignore
    register-completion "s3" "sync" "source" "discover-s3-buckets" --description="S3 sync source" | ignore
    register-completion "s3" "sync" "destination" "discover-s3-buckets" --description="S3 sync destination" | ignore
    $registration_count = $registration_count + 5
    
    # EC2 completions
    register-completion "ec2" "describe-instances" "instance-ids" "discover-ec2-instances" --description="EC2 instance IDs" | ignore
    register-completion "ec2" "terminate-instances" "instance-ids" "discover-ec2-instances" --description="EC2 instances to terminate" | ignore
    register-completion "ec2" "start-instances" "instance-ids" "discover-ec2-instances" --description="EC2 instances to start" | ignore
    register-completion "ec2" "stop-instances" "instance-ids" "discover-ec2-instances" --description="EC2 instances to stop" | ignore
    register-completion "ec2" "describe-vpcs" "vpc-ids" "discover-ec2-vpcs" --description="VPC IDs" | ignore
    $registration_count = $registration_count + 5
    
    # IAM completions
    register-completion "iam" "get-user" "user-name" "discover-iam-users" --description="IAM user names" | ignore
    register-completion "iam" "delete-user" "user-name" "discover-iam-users" --description="IAM users to delete" | ignore
    register-completion "iam" "get-role" "role-name" "discover-iam-roles" --description="IAM role names" | ignore
    register-completion "iam" "delete-role" "role-name" "discover-iam-roles" --description="IAM roles to delete" | ignore
    $registration_count = $registration_count + 4
    
    # Lambda completions
    register-completion "lambda" "invoke" "function-name" "discover-lambda-functions" --description="Lambda function names" | ignore
    register-completion "lambda" "delete-function" "function-name" "discover-lambda-functions" --description="Lambda functions to delete" | ignore
    register-completion "lambda" "get-function" "function-name" "discover-lambda-functions" --description="Lambda function names" | ignore
    $registration_count = $registration_count + 3
    
    {
        success: true,
        registered_completions: $registration_count,
        message: $"Auto-registered ($registration_count) standard completions"
    }
}

# Clear completion cache
export def clear-completion-cache [
    --service: string,
    --resource-type: string
]: nothing -> record {
    
    if $service != null {
        # Clear cache for specific service
        let keys_to_remove = $env.NUAWS_COMPLETION_CACHE 
            | transpose key entry 
            | where ($it.key | str starts-with $"($service):")
            | get key
        
        for key in $keys_to_remove {
            $env.NUAWS_COMPLETION_CACHE = ($env.NUAWS_COMPLETION_CACHE | reject $key)
        }
        
        {
            success: true,
            cleared_entries: ($keys_to_remove | length),
            message: $"Cleared completion cache for service: ($service)"
        }
    } else {
        # Clear all cache
        let total_entries = $env.NUAWS_COMPLETION_CACHE | columns | length
        $env.NUAWS_COMPLETION_CACHE = {}
        
        {
            success: true,
            cleared_entries: $total_entries,
            message: "Cleared all completion cache"
        }
    }
}

# Get completion registry statistics
export def get-completion-stats []: nothing -> record {
    let cache_entries = $env.NUAWS_COMPLETION_CACHE | columns | length
    let total_cache_size = $env.NUAWS_COMPLETION_CACHE 
        | transpose key entry 
        | each {|item| $item.entry.resource_count} 
        | math sum
    
    let registry_entries = $env.NUAWS_COMPLETION_REGISTRY | columns | length
    
    let most_used_completions = $env.NUAWS_COMPLETION_REGISTRY 
        | transpose key entry 
        | sort-by entry.usage_count 
        | reverse 
        | first 5
        | each {|item| {
            completion: $"($item.entry.service) ($item.entry.operation) --($item.entry.parameter)",
            usage_count: $item.entry.usage_count
        }}
    
    $env.NUAWS_COMPLETION_STATS | insert registry_entries $registry_entries
        | insert cache_entries $cache_entries
        | insert total_cached_resources $total_cache_size
        | insert most_used_completions $most_used_completions
}

# Helper function to build completion keys
def build-completion-key [service: string, operation: string, parameter: string]: nothing -> string {
    $"($service):($operation):($parameter)"
}

# Helper function to update completion statistics
def update-completion-stats [stat_name: string]: nothing -> nothing {
    let current_stats = $env.NUAWS_COMPLETION_STATS
    let current_value = $current_stats | get $stat_name
    $env.NUAWS_COMPLETION_STATS = ($current_stats | update $stat_name ($current_value + 1))
}

# AWS Resource Discovery Functions

def discover-s3-buckets []: nothing -> list {
    try {
        aws s3api list-buckets | from json | get Buckets | each { |bucket| $bucket.Name }
    } catch {
        []
    }
}

def discover-s3-objects [prefix: string]: nothing -> list {
    try {
        # This would need bucket context - simplified for now
        []
    } catch {
        []
    }
}

def discover-ec2-instances [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws ec2 describe-instances ...$region_arg 
            | from json 
            | get Reservations 
            | flatten 
            | each { |reservation| $reservation.Instances }
            | flatten 
            | each { |instance| $instance.InstanceId }
    } catch {
        []
    }
}

def discover-ec2-vpcs [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws ec2 describe-vpcs ...$region_arg | from json | get Vpcs | each { |vpc| $vpc.VpcId }
    } catch {
        []
    }
}

def discover-ec2-subnets [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws ec2 describe-subnets ...$region_arg | from json | get Subnets | each { |subnet| $subnet.SubnetId }
    } catch {
        []
    }
}

def discover-ec2-security-groups [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws ec2 describe-security-groups ...$region_arg | from json | get SecurityGroups | each { |sg| $sg.GroupId }
    } catch {
        []
    }
}

def discover-ec2-key-pairs [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws ec2 describe-key-pairs ...$region_arg | from json | get KeyPairs | each { |kp| $kp.KeyName }
    } catch {
        []
    }
}

def discover-ec2-images [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        # Limit to owner's AMIs for performance
        aws ec2 describe-images --owners self ...$region_arg | from json | get Images | each { |img| $img.ImageId }
    } catch {
        []
    }
}

def discover-iam-users []: nothing -> list {
    try {
        aws iam list-users | from json | get Users | each { |user| $user.UserName }
    } catch {
        []
    }
}

def discover-iam-roles []: nothing -> list {
    try {
        aws iam list-roles | from json | get Roles | each { |role| $role.RoleName }
    } catch {
        []
    }
}

def discover-iam-policies []: nothing -> list {
    try {
        aws iam list-policies --scope Local | from json | get Policies | each { |policy| $policy.PolicyName }
    } catch {
        []
    }
}

def discover-lambda-functions [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws lambda list-functions ...$region_arg | from json | get Functions | each { |func| $func.FunctionName }
    } catch {
        []
    }
}

def discover-dynamodb-tables [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws dynamodb list-tables ...$region_arg | from json | get TableNames
    } catch {
        []
    }
}

def discover-rds-instances [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws rds describe-db-instances ...$region_arg | from json | get DBInstances | each { |db| $db.DBInstanceIdentifier }
    } catch {
        []
    }
}

def discover-rds-clusters [region: string]: nothing -> list {
    try {
        let region_arg = if $region != null { ["--region", $region] } else { [] }
        aws rds describe-db-clusters ...$region_arg | from json | get DBClusters | each { |cluster| $cluster.DBClusterIdentifier }
    } catch {
        []
    }
}