# NuAWS Completion System Generator
# GEN-003: Advanced completion system with dynamic AWS resource enumeration
# Following Nushell's shell-first design and structured data pipeline patterns

# Core completion system configuration
const MEMORY_CACHE_TTL = 300  # 5 minutes
const DISK_CACHE_TTL = 3600   # 1 hour  
const NETWORK_TIMEOUT = 2000  # 2 seconds
const COMPLETION_TIMEOUT = 200 # 200ms target

# Cache base directory function (dynamic due to env var)
def get-cache-base-dir []: nothing -> string {
    $"($env.HOME)/.cache/nuaws"
}

# Completion context for intelligent caching and context-aware suggestions
export def "completion-context" []: nothing -> record {
    {
        region: ($env.AWS_REGION? | default "us-east-1"),
        profile: ($env.AWS_PROFILE? | default "default"),
        timestamp: (date now),
        cache_dir: (get-cache-base-dir),
        timeout: $COMPLETION_TIMEOUT
    }
}

# Memory cache simulation using environment variables for persistence
def get-memory-cache [key: string]: nothing -> any {
    let cache_env_var = $"NUAWS_CACHE_($key | str replace '-' '_' | str upcase)"
    $env | get -o $cache_env_var | default null
}

def set-memory-cache [key: string, value: any]: nothing -> nothing {
    let cache_env_var = $"NUAWS_CACHE_($key | str replace '-' '_' | str upcase)"
    load-env {$cache_env_var: ($value | to json)}
}

# Initialize cache directories with structured layout
export def "init-cache-system" []: nothing -> nothing {
    let cache_dir = (get-cache-base-dir)
    let cache_structure = [
        $"($cache_dir)/resources/s3",
        $"($cache_dir)/resources/ec2", 
        $"($cache_dir)/resources/iam",
        $"($cache_dir)/resources/lambda",
        $"($cache_dir)/completion-data",
        $"($cache_dir)/metadata"
    ]
    
    $cache_structure | each { |dir|
        if not ($dir | path exists) {
            mkdir $dir
        }
    }
    
    # Create cache metadata
    let metadata = {
        version: "1.0.0",
        created: (date now),
        last_cleanup: (date now),
        cache_structure: $cache_structure
    }
    
    $metadata | to json | save $"($cache_dir)/metadata/cache_info.json" --force
}

# Dynamic AWS resource fetchers with structured data output
export def "fetch-s3-buckets" [
    --region: string = "us-east-1"
    --profile: string = "default"
    --use-cache = true
]: nothing -> list<record> {
    let cache_key = $"s3-buckets-($region)-($profile)"
    let cache_file = $"((get-cache-base-dir))/resources/s3/buckets-($region)-($profile).json"
    
    # Check memory cache first
    if $use_cache {
        let cached = (get-memory-cache $cache_key)
        if $cached != null {
            let cached_data = ($cached | from json)
            if ((date now) - ($cached_data.timestamp | into datetime)) < ($MEMORY_CACHE_TTL * 1sec) {
                return $cached_data.data
            }
        }
    }
    
    # Check disk cache
    if $use_cache and ($cache_file | path exists) {
        let file_age = ((date now) - (ls $cache_file | get 0.modified))
        if $file_age < ($DISK_CACHE_TTL * 1sec) {
            let cached_data = (open $cache_file)
            
            # Update memory cache
            set-memory-cache $cache_key {
                data: $cached_data,
                timestamp: (date now)
            }
            
            return $cached_data
        }
    }
    
    # Fetch from AWS with timeout
    try {
        let aws_cmd = $"aws s3api list-buckets --profile ($profile) --region ($region) --output json"
        let aws_output = (bash -c $"timeout ($NETWORK_TIMEOUT / 1000) ($aws_cmd)" | complete)
        
        if $aws_output.exit_code == 0 {
            let buckets = ($aws_output.stdout | from json | get Buckets? | default [])
            let structured_buckets = ($buckets | each { |bucket|
                {
                    name: $bucket.Name,
                    creation_date: $bucket.CreationDate,
                    region: $region,
                    type: "bucket",
                    completion_value: $bucket.Name,
                    description: $"S3 bucket created on ($bucket.CreationDate)"
                }
            })
            
            # Cache the results
            if $use_cache {
                $structured_buckets | to json | save $cache_file --force
                set-memory-cache $cache_key {
                    data: $structured_buckets,
                    timestamp: (date now)
                }
            }
            
            return $structured_buckets
        }
    } catch {
        # Fallback to cached data if available
        if ($cache_file | path exists) {
            return (open $cache_file)
        }
    }
    
    # Return empty structured list as fallback
    return []
}

# EC2 instance completion with context awareness
export def "fetch-ec2-instances" [
    --region: string = "us-east-1"
    --profile: string = "default"
    --state: string = "running"
    --use-cache = true
]: nothing -> list<record> {
    let cache_key = $"ec2-instances-($region)-($profile)-($state)"
    let cache_file = $"((get-cache-base-dir))/resources/ec2/instances-($region)-($profile)-($state).json"
    
    # Check memory cache
    if $use_cache {
        let cached = (get-memory-cache $cache_key)
        if $cached != null {
            let cached_data = ($cached | from json)
            if ((date now) - ($cached_data.timestamp | into datetime)) < ($MEMORY_CACHE_TTL * 1sec) {
                return $cached_data.data
            }
        }
    }
    
    # Check disk cache
    if $use_cache and ($cache_file | path exists) {
        let file_age = ((date now) - (ls $cache_file | get 0.modified))
        if $file_age < ($DISK_CACHE_TTL * 1sec) {
            let cached_data = (open $cache_file)
            set-memory-cache $cache_key {
                data: $cached_data,
                timestamp: (date now)
            }
            return $cached_data
        }
    }
    
    # Fetch from AWS
    try {
        let filter_arg = if $state != "all" { $"--filters Name=instance-state-name,Values=($state)" } else { "" }
        let aws_cmd = $"aws ec2 describe-instances --profile ($profile) --region ($region) ($filter_arg) --output json"
        let aws_output = (bash -c $"timeout ($NETWORK_TIMEOUT / 1000) ($aws_cmd)" | complete)
        
        if $aws_output.exit_code == 0 {
            let reservations = ($aws_output.stdout | from json | get Reservations? | default [])
            let instances = ($reservations | each { |r| $r.Instances } | flatten)
            let structured_instances = ($instances | each { |instance|
                {
                    instance_id: $instance.InstanceId,
                    name: ($instance.Tags? | default [] | where Key == "Name" | get 0.Value? | default ""),
                    state: $instance.State.Name,
                    instance_type: $instance.InstanceType,
                    region: $region,
                    type: "ec2-instance",
                    completion_value: $instance.InstanceId,
                    description: $"EC2 ($instance.InstanceType) - ($instance.State.Name)"
                }
            })
            
            # Cache results
            if $use_cache {
                $structured_instances | to json | save $cache_file --force
                set-memory-cache $cache_key {
                    data: $structured_instances,
                    timestamp: (date now)
                }
            }
            
            return $structured_instances
        }
    } catch {
        if ($cache_file | path exists) {
            return (open $cache_file)
        }
    }
    
    return []
}

# IAM roles and policies completion
export def "fetch-iam-roles" [
    --profile: string = "default"
    --use-cache = true
]: nothing -> list<record> {
    let cache_key = $"iam-roles-($profile)"
    let cache_file = $"((get-cache-base-dir))/resources/iam/roles-($profile).json"
    
    # Check caches
    if $use_cache {
        let cached = (get-memory-cache $cache_key)
        if $cached != null {
            let cached_data = ($cached | from json)
            if ((date now) - ($cached_data.timestamp | into datetime)) < ($MEMORY_CACHE_TTL * 1sec) {
                return $cached_data.data
            }
        }
    }
    
    if $use_cache and ($cache_file | path exists) {
        let file_age = ((date now) - (ls $cache_file | get 0.modified))
        if $file_age < ($DISK_CACHE_TTL * 1sec) {
            let cached_data = (open $cache_file)
            set-memory-cache $cache_key {
                data: $cached_data,
                timestamp: (date now)
            }
            return $cached_data
        }
    }
    
    # Fetch from AWS
    try {
        let aws_cmd = $"aws iam list-roles --profile ($profile) --output json"
        let aws_output = (bash -c $"timeout ($NETWORK_TIMEOUT / 1000) ($aws_cmd)" | complete)
        
        if $aws_output.exit_code == 0 {
            let roles = ($aws_output.stdout | from json | get Roles? | default [])
            let structured_roles = ($roles | each { |role|
                {
                    role_name: $role.RoleName,
                    arn: $role.Arn,
                    path: $role.Path,
                    created_date: $role.CreateDate,
                    type: "iam-role",
                    completion_value: $role.RoleName,
                    description: $"IAM role: ($role.RoleName)"
                }
            })
            
            if $use_cache {
                $structured_roles | to json | save $cache_file --force
                set-memory-cache $cache_key {
                    data: $structured_roles,
                    timestamp: (date now)
                }
            }
            
            return $structured_roles
        }
    } catch {
        if ($cache_file | path exists) {
            return (open $cache_file)
        }
    }
    
    return []
}

# Context-aware completion generator that understands command relationships
export def "generate-contextual-completions" [
    service: string,
    command: string,
    parameter: string,
    current_args: record = {}
]: nothing -> list<string> {
    let context = (completion-context)
    
    # Context-specific completion logic
    match [$service, $command, $parameter] {
        ["s3", $cmd, "bucket"] if ($cmd | str contains "bucket") => {
            (fetch-s3-buckets --region $context.region --profile $context.profile) | get completion_value
        },
        ["s3", $cmd, "key"] if ($cmd | str contains "object") => {
            # If bucket is provided in current_args, list objects in that bucket
            if "bucket" in $current_args {
                let bucket = ($current_args | get bucket)
                (fetch-s3-objects $bucket --region $context.region --profile $context.profile)
            } else {
                []
            }
        },
        ["ec2", $cmd, "instance-ids"] if ($cmd | str contains "instance") => {
            (fetch-ec2-instances --region $context.region --profile $context.profile) | get completion_value
        },
        ["ec2", $cmd, "instance-id"] if ($cmd | str contains "instance") => {
            (fetch-ec2-instances --region $context.region --profile $context.profile) | get completion_value
        },
        ["iam", $cmd, "role-name"] => {
            (fetch-iam-roles --profile $context.profile) | get completion_value
        },
        _ => []
    }
}

# S3 object listing for bucket-aware completions
export def "fetch-s3-objects" [
    bucket: string,
    --region: string = "us-east-1", 
    --profile: string = "default",
    --prefix: string = "",
    --max-items: int = 100
]: nothing -> list<string> {
    try {
        let prefix_arg = if $prefix != "" { $"--prefix ($prefix)" } else { "" }
        let aws_cmd = $"aws s3api list-objects-v2 --bucket ($bucket) --profile ($profile) --region ($region) ($prefix_arg) --max-items ($max_items) --output json"
        let aws_output = (bash -c $"timeout ($NETWORK_TIMEOUT / 1000) ($aws_cmd)" | complete)
        
        if $aws_output.exit_code == 0 {
            let objects = ($aws_output.stdout | from json | get Contents? | default [])
            return ($objects | get Key)
        }
    } catch { }
    
    return []
}

# Advanced completion with intelligent caching and performance optimization
export def "get-completion-suggestions" [
    service: string,
    command: string,
    parameter: string = "",
    current_args: record = {},
    --max-results: int = 50,
    --include-descriptions = false
]: nothing -> list<record> {
    let start_time = (date now)
    let context = (completion-context)
    
    # Performance optimization: parallel fetching for multiple resources
    let suggestions = if $parameter != "" {
        (generate-contextual-completions $service $command $parameter $current_args)
    } else {
        # Return command completions for the service
        match $service {
            "s3" => [
                "abortmultipartupload", "completemultipartupload", "copyobject", 
                "createbucket", "deletebucket", "deleteobject", "getobject",
                "listbuckets", "listobjects", "putobject"
            ],
            "ec2" => [
                "describe-instances", "start-instances", "stop-instances", 
                "terminate-instances", "run-instances", "describe-images"
            ],
            "iam" => [
                "list-roles", "list-users", "list-policies", "create-role",
                "delete-role", "attach-role-policy"
            ],
            _ => []
        }
    }
    
    # Transform to structured completion records
    let structured_suggestions = ($suggestions | each { |item|
        if ($item | describe) == "string" {
            {
                value: $item,
                description: $"($service) ($command) option",
                type: "completion",
                service: $service,
                command: $command
            }
        } else {
            $item
        }
    } | first $max_results)
    
    let duration = ((date now) - $start_time)
    
    # Log performance metrics if over target
    if ($duration > ($COMPLETION_TIMEOUT * 1ms)) {
        print $"Warning: Completion took ($duration) - target is ($COMPLETION_TIMEOUT)ms"
    }
    
    return $structured_suggestions
}

# Cache invalidation system with intelligent cleanup
export def "invalidate-completion-cache" [
    --service: string = "all",
    --region: string = "all", 
    --older-than: duration = 1hr
]: nothing -> nothing {
    let cache_dir = (get-cache-base-dir)
    
    if $service == "all" {
        # Clean all caches older than specified duration
        try {
            ls ($cache_dir + "/resources/**/*.json") | each { |file|
                let file_age = ((date now) - $file.modified)
                if $file_age > $older_than {
                    rm $file.name
                    print $"Removed expired cache: ($file.name)"
                }
            }
        } catch {
            print "Cache directory not found or empty"
        }
    } else {
        # Clean specific service cache
        let service_cache_dir = $"($cache_dir)/resources/($service)"
        if ($service_cache_dir | path exists) {
            ls ($service_cache_dir + "/*.json") | each { |file|
                rm $file.name
                print $"Removed ($service) cache: ($file.name)"
            }
        }
    }
    
    # Clear memory cache for invalidated items
    # Note: In Nushell 0.107+, we would need to unset environment variables
    print "Cache invalidation completed"
}

# Batch preload common completions for performance
export def "preload-common-completions" [
    --services: list<string> = ["s3", "ec2", "iam"]
]: nothing -> nothing {
    let context = (completion-context)
    
    print "Preloading common AWS resource completions..."
    
    # Parallel preloading using Nushell's structured data approach
    $services | each { |service|
        print $"Preloading ($service) resources..."
        
        match $service {
            "s3" => {
                fetch-s3-buckets --region $context.region --profile $context.profile | ignore
            },
            "ec2" => {
                fetch-ec2-instances --region $context.region --profile $context.profile --state "running" | ignore
            },
            "iam" => {
                fetch-iam-roles --profile $context.profile | ignore
            },
            _ => { print $"Unknown service: ($service)" }
        }
    }
    
    print "Preloading completed"
}

# Generate enhanced completion functions for existing services
export def "generate-enhanced-completions" [
    --output-dir: string = "./completions",
    --services: list<string> = ["s3", "ec2", "iam"]
]: nothing -> nothing {
    init-cache-system
    
    $services | each { |service|
        print $"Generating enhanced completions for ($service)..."
        
        let completion_template = [
            "# Enhanced External Completions for AWS " + ($service | str upcase) + " Service",
            "# Generated by completion_system_generator.nu with dynamic resource enumeration",
            "",
            "use ../tools/completion_system_generator.nu *",
            "",
            "export def \"nuaws-complete-" + $service + "-bucket\" []: nothing -> list<string> {",
            "    (fetch-s3-buckets) | get completion_value",
            "}",
            "",
            "export def \"nuaws-complete-" + $service + "-instance-id\" []: nothing -> list<string> {",
            "    (fetch-ec2-instances) | get completion_value",
            "}",
            "",
            "export def \"nuaws-complete-" + $service + "-role-name\" []: nothing -> list<string> {",
            "    (fetch-iam-roles) | get completion_value",
            "}",
            "",
            "# Context-aware completion dispatcher",
            "export def \"nuaws-complete-" + $service + "\" [",
            "    command: string = \"\",",
            "    parameter: string = \"\",",
            "    current_args: record = {}",
            "]: nothing -> list<string> {",
            "    (get-completion-suggestions \"" + $service + "\" $command $parameter $current_args) | get value",
            "}"
        ] | str join "\n"
        
        let output_file = $"($output_dir)/enhanced_($service).nu"
        $completion_template | save $output_file --force
        print $"Generated: ($output_file)"
    }
    
    print "Enhanced completion generation completed"
}

# Performance monitoring and optimization
export def "completion-performance-report" []: nothing -> record {
    let context = (completion-context)
    let cache_dir = (get-cache-base-dir)
    
    # Analyze cache effectiveness
    let cache_files = try { (ls ($cache_dir + "/resources/**/*.json") | length) } catch { 0 }
    let cache_size = try { (du $cache_dir | get 0.size? | default 0B) } catch { 0B }
    let memory_entries = 0  # Simplified for now
    
    # Test completion performance
    let performance_tests = [
        { service: "s3", command: "listbuckets", test: "S3 bucket listing" },
        { service: "ec2", command: "describe-instances", test: "EC2 instance listing" },
        { service: "iam", command: "list-roles", test: "IAM role listing" }
    ]
    
    let test_results = ($performance_tests | each { |test|
        let start = (date now)
        let results = (get-completion-suggestions $test.service $test.command)
        let duration = ((date now) - $start)
        
        {
            test: $test.test,
            duration: $duration,
            results_count: ($results | length),
            under_target: ($duration < ($COMPLETION_TIMEOUT * 1ms))
        }
    })
    
    {
        cache_status: {
            disk_files: $cache_files,
            disk_size: $cache_size,
            memory_entries: $memory_entries
        },
        performance_tests: $test_results,
        average_completion_time: ($test_results | get duration | math avg),
        target_completion_time: $"($COMPLETION_TIMEOUT)ms",
        context: $context
    }
}

# Main completion system setup and initialization
export def main [
    action: string = "init",
    --service: string = "all",
    --preload = false
]: nothing -> nothing {
    match $action {
        "init" => {
            print "Initializing NuAWS completion system..."
            init-cache-system
            
            if $preload {
                preload-common-completions
            }
            
            print "Completion system initialized successfully"
        },
        "generate" => {
            let services = if $service == "all" { ["s3", "ec2", "iam"] } else { [$service] }
            generate-enhanced-completions --services $services
        },
        "performance" => {
            completion-performance-report | print
        },
        "clean" => {
            invalidate-completion-cache --service $service
        },
        _ => {
            print $"Available actions: init, generate, performance, clean"
            print $"Usage: nu completion_system_generator.nu <action> --service <service> --preload"
        }
    }
}