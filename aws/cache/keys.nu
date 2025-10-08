# Cache Key Generation
# Generates scoped cache keys including AWS profile and region
# Ensures cache isolation across different AWS contexts

# Generate cache key with profile/region scoping
export def cache-key [
    service: string,
    operation: string,
    params: record,
    --profile: string = "",
    --region: string = ""
] {
    # Use default values if environment variables are not set
    let effective_profile = if ($profile | is-empty) { 
        if "AWS_PROFILE" in $env { $env.AWS_PROFILE } else { "default" }
    } else { 
        $profile 
    }
    let effective_region = if ($region | is-empty) { 
        if "AWS_DEFAULT_REGION" in $env { $env.AWS_DEFAULT_REGION } else { "us-east-1" }
    } else { 
        $region 
    }
    
    # Generate hash of parameters to ensure uniqueness
    let param_hash = generate-param-hash $params
    
    # Construct cache key with all components
    $"($effective_profile):($effective_region):($service):($operation):($param_hash)"
}

# Generate consistent hash of parameters
export def generate-param-hash [
    params: record
] {
    # Convert parameters to normalized JSON and hash
    # Sort keys to ensure consistent ordering
    if ($params | is-empty) {
        return "empty-params"
    }
    
    # Sort record keys to ensure order independence
    let sorted_params = ($params 
        | transpose key value 
        | sort-by key 
        | reduce -f {} {|item, acc| $acc | upsert $item.key $item.value })
    
    let normalized_json = $sorted_params | to json --raw
    
    # Use Nushell's built-in hash function to generate MD5
    $normalized_json | hash md5
}

# Parse cache key to extract components
export def parse-cache-key [
    key: string
] {
    let parts = $key | split row ":"
    
    if ($parts | length) != 5 {
        error make {
            msg: "Invalid cache key format",
            label: {
                text: "Cache key must have format: profile:region:service:operation:param_hash",
                span: (metadata $key).span
            }
        }
    }
    
    {
        profile: ($parts | get 0),
        region: ($parts | get 1),
        service: ($parts | get 2),
        operation: ($parts | get 3),
        param_hash: ($parts | get 4)
    }
}

# Generate cache key for AWS resource identification
export def resource-cache-key [
    service: string,
    resource_type: string,
    identifier: string,
    --profile: string = "",
    --region: string = ""
] {
    let effective_profile = if ($profile | is-empty) { 
        if "AWS_PROFILE" in $env { $env.AWS_PROFILE } else { "default" }
    } else { 
        $profile 
    }
    let effective_region = if ($region | is-empty) { 
        if "AWS_DEFAULT_REGION" in $env { $env.AWS_DEFAULT_REGION } else { "us-east-1" }
    } else { 
        $region 
    }
    
    $"resource:($effective_profile):($effective_region):($service):($resource_type):($identifier)"
}

# Check if cache key matches a pattern (for invalidation)
export def cache-key-matches-pattern [
    key: string,
    pattern: string
] {
    # Use Nushell's glob-style pattern matching
    $key | str contains $pattern
}

# Extract service from cache key
export def get-service-from-cache-key [
    key: string
] {
    let parsed = parse-cache-key $key
    $parsed.service
}

# Extract region from cache key  
export def get-region-from-cache-key [
    key: string
] {
    let parsed = parse-cache-key $key
    $parsed.region
}

# Extract profile from cache key
export def get-profile-from-cache-key [
    key: string
] {
    let parsed = parse-cache-key $key
    $parsed.profile
}

# Generate cache key for batch operations
export def batch-cache-key [
    service: string,
    operation: string,
    batch_identifier: string,
    --profile: string = "",
    --region: string = ""
] {
    let effective_profile = if ($profile | is-empty) { 
        if "AWS_PROFILE" in $env { $env.AWS_PROFILE } else { "default" }
    } else { 
        $profile 
    }
    let effective_region = if ($region | is-empty) { 
        if "AWS_DEFAULT_REGION" in $env { $env.AWS_DEFAULT_REGION } else { "us-east-1" }
    } else { 
        $region 
    }
    
    $"batch:($effective_profile):($effective_region):($service):($operation):($batch_identifier)"
}

# Normalize parameter record for consistent hashing
def normalize-params [
    params: record
] {
    # Sort keys and convert to consistent JSON representation
    let sorted_params = $params | transpose key value | sort-by key | transpose -r -d
    $sorted_params | to json --raw
}