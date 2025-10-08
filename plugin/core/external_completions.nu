# External Completions - Nushell external completion interface for AWS resources
# Provides the "nu-complete" functions that Nushell calls for command completion

use completion_registry.nu

# Initialize external completions system
export-env {
    $env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED = ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED? | default "true")
}

# Auto-initialization function
def init-auto-completions [] {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "true") {
        try {
            completion_registry auto-register-standard-completions | ignore
        } catch {
            # Silently ignore initialization errors
        }
    }
}

# S3 Bucket Completions
export def "nu-complete aws s3 buckets" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "s3" "buckets"
    } catch {
        []
    }
}

export def "nu-complete aws s3api buckets" []: nothing -> list<string> {
    nu-complete aws s3 buckets
}

# EC2 Instance Completions
export def "nu-complete aws ec2 instances" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "ec2" "instances" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

export def "nu-complete aws ec2 vpcs" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "ec2" "vpcs" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

export def "nu-complete aws ec2 subnets" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "ec2" "subnets" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

export def "nu-complete aws ec2 security-groups" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "ec2" "security-groups" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

export def "nu-complete aws ec2 key-pairs" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "ec2" "key-pairs" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

# IAM Resource Completions
export def "nu-complete aws iam users" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "iam" "users"
    } catch {
        []
    }
}

export def "nu-complete aws iam roles" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "iam" "roles"
    } catch {
        []
    }
}

export def "nu-complete aws iam policies" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "iam" "policies"
    } catch {
        []
    }
}

# Lambda Function Completions
export def "nu-complete aws lambda functions" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "lambda" "functions" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

# DynamoDB Table Completions
export def "nu-complete aws dynamodb tables" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "dynamodb" "tables" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

# RDS Instance Completions
export def "nu-complete aws rds instances" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "rds" "instances" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

export def "nu-complete aws rds clusters" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry discover-aws-resources "rds" "clusters" --region=($env.AWS_DEFAULT_REGION? | default "us-east-1")
    } catch {
        []
    }
}

# AWS Regions Completion (static but useful)
export def "nu-complete aws regions" []: nothing -> list<string> {
    [
        "us-east-1", "us-east-2", "us-west-1", "us-west-2",
        "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1", "eu-north-1",
        "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "ap-northeast-2", "ap-south-1",
        "sa-east-1", "ca-central-1", "af-south-1", "ap-east-1", "ap-southeast-3",
        "eu-south-1", "me-south-1"
    ]
}

# AWS Availability Zones (dynamic based on region)
export def "nu-complete aws availability-zones" []: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        let region = $env.AWS_DEFAULT_REGION? | default "us-east-1"
        aws ec2 describe-availability-zones --region $region | from json | get AvailabilityZones | get ZoneName
    } catch {
        []
    }
}

# Generic completion function that can be used by service modules
export def "nu-complete nuaws service-completion" [
    service: string,
    operation: string, 
    parameter: string
]: nothing -> list<string> {
    if ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED == "false") {
        return []
    }
    
    try {
        completion_registry get-completions $service $operation $parameter
    } catch {
        []
    }
}

# List all available completion functions
export def list-external-completions []: nothing -> table {
    [
        {name: "nu-complete aws s3 buckets", description: "S3 bucket names", service: "s3"},
        {name: "nu-complete aws s3api buckets", description: "S3 bucket names (s3api)", service: "s3"},
        {name: "nu-complete aws ec2 instances", description: "EC2 instance IDs", service: "ec2"},
        {name: "nu-complete aws ec2 vpcs", description: "VPC IDs", service: "ec2"},
        {name: "nu-complete aws ec2 subnets", description: "Subnet IDs", service: "ec2"},
        {name: "nu-complete aws ec2 security-groups", description: "Security Group IDs", service: "ec2"},
        {name: "nu-complete aws ec2 key-pairs", description: "Key Pair names", service: "ec2"},
        {name: "nu-complete aws iam users", description: "IAM user names", service: "iam"},
        {name: "nu-complete aws iam roles", description: "IAM role names", service: "iam"},
        {name: "nu-complete aws iam policies", description: "IAM policy names", service: "iam"},
        {name: "nu-complete aws lambda functions", description: "Lambda function names", service: "lambda"},
        {name: "nu-complete aws dynamodb tables", description: "DynamoDB table names", service: "dynamodb"},
        {name: "nu-complete aws rds instances", description: "RDS instance identifiers", service: "rds"},
        {name: "nu-complete aws rds clusters", description: "RDS cluster identifiers", service: "rds"},
        {name: "nu-complete aws regions", description: "AWS region names", service: "core"},
        {name: "nu-complete aws availability-zones", description: "Availability zone names", service: "core"},
        {name: "nu-complete nuaws service-completion", description: "Generic service completion", service: "nuaws"}
    ]
}

# Test completion functionality
export def test-completions [
    --service: string = "s3",
    --resource: string = "buckets"
]: nothing -> record {
    
    print $"Testing completion for ($service) ($resource)..."
    
    let start_time = date now
    
    let completions = try {
        completion_registry discover-aws-resources $service $resource
    } catch { |err|
        return {
            success: false,
            error: $err.msg,
            service: $service,
            resource: $resource
        }
    }
    
    let end_time = date now
    let duration = $end_time - $start_time
    
    {
        success: true,
        service: $service,
        resource: $resource,
        completion_count: ($completions | length),
        duration: $duration,
        sample_completions: ($completions | first 5),
        all_completions: $completions
    }
}

# Enable/disable external completions
export def set-completions-enabled [enabled: bool]: nothing -> record {
    $env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED = (if $enabled { "true" } else { "false" })
    
    {
        success: true,
        enabled: $enabled,
        message: $"External completions (if $enabled { 'enabled' } else { 'disabled' })"
    }
}

# Get external completions status
export def get-completions-status []: nothing -> record {
    let enabled = ($env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED? | default "true") == "true"
    let stats = try { completion_registry get-completion-stats } catch { {} }
    
    {
        enabled: $enabled,
        available_functions: (list-external-completions | length),
        registry_stats: $stats,
        cache_ttl: (try { configuration get "completion_cache_ttl" } catch { 300 }),
        aws_region: ($env.AWS_DEFAULT_REGION? | default "us-east-1")
    }
}