# Cache Invalidation Implementation
# Pattern-based cache invalidation for memory and disk caches
# Supports service, operation, resource, profile, and custom pattern invalidation

use memory.nu *
use disk.nu *
use keys.nu *

# Invalidate all cache entries for a specific service
export def invalidate-cache-by-service [
    service: string
] {
    # Invalidate memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        let parsed_key = try { parse-cache-key $key } catch { {service: ""} }
        $parsed_key.service != $service
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate disk cache entries
    invalidate-disk-cache-by-pattern $service
}

# Invalidate cache entries for specific service and operation
export def invalidate-cache-by-operation [
    service: string,
    operation: string
] {
    # Invalidate memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        let parsed_key = try { parse-cache-key $key } catch { {service: "", operation: ""} }
        not ($parsed_key.service == $service and $parsed_key.operation == $operation)
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate disk cache entries
    invalidate-disk-cache-by-pattern $"($service):($operation)"
}

# Invalidate cache entries related to a specific resource
export def invalidate-cache-by-resource [
    service: string,
    resource_type: string,
    resource_identifier: string
] {
    # Create pattern to match resource-related cache keys
    let resource_pattern = $resource_identifier
    
    # Invalidate memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        not ($key | str contains $resource_pattern)
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate disk cache entries
    invalidate-disk-cache-by-pattern $resource_pattern
}

# Invalidate cache entries matching a custom pattern
export def invalidate-cache-by-pattern [
    pattern: string
] {
    # Convert glob pattern to simple string matching for now
    let match_pattern = $pattern | str replace "*" "" | str replace "?" ""
    
    # Invalidate memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        not ($key | str contains $match_pattern)
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate disk cache entries
    invalidate-disk-cache-by-pattern $match_pattern
}

# Invalidate expired cache entries based on TTL
export def invalidate-expired-cache [
    max_age: duration
] {
    let current_time = date now
    
    # Invalidate expired memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        let entry_age = $current_time - ($value.timestamp | into datetime)
        $entry_age <= $max_age
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate expired disk cache entries
    invalidate-expired-disk-cache $max_age
}

# Invalidate cache entries for a specific profile
export def invalidate-cache-by-profile [
    profile: string
] {
    # Invalidate memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        let parsed_key = try { parse-cache-key $key } catch { {profile: ""} }
        $parsed_key.profile != $profile
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate disk cache entries
    invalidate-disk-cache-by-pattern $profile
}

# Invalidate cache entries for a specific region
export def invalidate-cache-by-region [
    region: string
] {
    # Invalidate memory cache entries
    let memory_state = try { load-cache-state } catch { return }
    let filtered_entries = $memory_state.entries | items {|key, value|
        let parsed_key = try { parse-cache-key $key } catch { {region: ""} }
        $parsed_key.region != $region
    }
    let new_state = $memory_state | upsert entries $filtered_entries
    save-cache-state $new_state
    
    # Invalidate disk cache entries
    invalidate-disk-cache-by-pattern $region
}

# Cascade invalidation when a resource changes
export def cascade-invalidate-on-resource-change [
    service: string,
    resource_type: string,
    resource_arn: string
] {
    # Extract resource identifier from ARN
    let resource_parts = $resource_arn | split row ":"
    let resource_name = if ($resource_parts | length) >= 6 {
        $resource_parts | get 5 | split row "/" | last
    } else {
        $resource_arn
    }
    
    # For Step Functions, invalidate related caches
    if $service == "stepfunctions" {
        match $resource_type {
            "stateMachine" => {
                # Invalidate all Step Functions caches as they might be related
                invalidate-cache-by-service "stepfunctions"
            }
            "execution" => {
                # Invalidate execution-related caches
                invalidate-cache-by-pattern $"*($resource_name)*"
            }
            _ => {
                # Default: invalidate by resource name
                invalidate-cache-by-resource $service $resource_type $resource_name
            }
        }
    } else {
        # Default cascade behavior
        invalidate-cache-by-resource $service $resource_type $resource_name
    }
}

# Helper: Invalidate disk cache entries by pattern
def invalidate-disk-cache-by-pattern [
    pattern: string
] {
    let cache_dir = get-cache-dir
    
    # Only proceed if cache directory exists
    if not ($cache_dir | path exists) {
        return
    }
    
    # Get all cache files and filter by pattern
    let cache_files = try {
        ls $cache_dir | where type == file | where name ends-with ".json.gz"
    } catch {
        []
    }
    
    # Remove files matching pattern
    $cache_files | each {|file|
        let filename = $file.name | path basename | str replace ".json.gz" ""
        if ($filename | str contains $pattern) {
            try { rm $file.name } catch { }
        }
    }
}

# Helper: Invalidate expired disk cache entries
def invalidate-expired-disk-cache [
    max_age: duration
] {
    let cache_dir = get-cache-dir
    let current_time = date now
    
    # Only proceed if cache directory exists
    if not ($cache_dir | path exists) {
        return
    }
    
    # Get all cache files
    let cache_files = try {
        ls $cache_dir | where type == file | where name ends-with ".json.gz"
    } catch {
        []
    }
    
    # Check each file for expiration
    $cache_files | each {|file|
        let cache_data = try {
            # Try to read and parse the cache file
            let content = try {
                # Attempt to decompress and read
                let decompressed = try {
                    gunzip --stdout $file.name
                } catch {
                    # Fallback: read directly if not actually compressed
                    open $file.name
                }
                $decompressed | from json
            } catch {
                null
            }
            $content
        } catch {
            null
        }
        
        if $cache_data != null and "timestamp" in $cache_data {
            let entry_age = $current_time - ($cache_data.timestamp | into datetime)
            if $entry_age > $max_age {
                try { rm $file.name } catch { }
            }
        }
    }
}

# Get invalidation statistics
export def get-invalidation-stats [] {
    let memory_stats = try { get-memory-cache-stats } catch { {entries: 0} }
    let disk_stats = try { get-disk-cache-stats } catch { {entries: 0} }
    
    {
        memory_entries: $memory_stats.entries,
        disk_entries: $disk_stats.entries,
        last_invalidation: null,  # Could be tracked if needed
        total_invalidations: null  # Could be tracked if needed
    }
}

# Batch invalidation operations
export def batch-invalidate [
    operations: list<record>
] {
    $operations | each {|op|
        match $op.type {
            "service" => { invalidate-cache-by-service $op.service }
            "operation" => { invalidate-cache-by-operation $op.service $op.operation }
            "resource" => { invalidate-cache-by-resource $op.service $op.resource_type $op.resource_id }
            "pattern" => { invalidate-cache-by-pattern $op.pattern }
            "profile" => { invalidate-cache-by-profile $op.profile }
            "region" => { invalidate-cache-by-region $op.region }
            "expired" => { invalidate-expired-cache $op.max_age }
            _ => { print $"Unknown invalidation type: ($op.type)" }
        }
    }
}

# Smart invalidation based on AWS operation type
export def smart-invalidate [
    service: string,
    operation: string,
    resource_info: record = {}
] {
    # Determine invalidation strategy based on operation type
    if ($operation | str starts-with "create") or ($operation | str starts-with "put") or ($operation | str starts-with "update") {
        # Create/Update operations - invalidate related list operations
        invalidate-cache-by-service $service
    } else if ($operation | str starts-with "delete") {
        # Delete operations - invalidate everything for the service
        invalidate-cache-by-service $service
    } else if ($operation | str starts-with "start") or ($operation | str starts-with "stop") {
        # State change operations - invalidate specific resource
        if "arn" in $resource_info {
            cascade-invalidate-on-resource-change $service "resource" $resource_info.arn
        } else {
            invalidate-cache-by-service $service
        }
    } else {
        # Read operations - usually don't need invalidation
        # But can invalidate expired entries
        invalidate-expired-cache 1hr
    }
}