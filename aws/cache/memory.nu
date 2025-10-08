# Memory Cache Implementation
# LRU (Least Recently Used) memory cache with configurable size limits
# Uses file-based state persistence for compatibility with Nushell 0.107.0

# Default configuration
const MEMORY_CACHE_SIZE = 1000

# Get cache state file path (supports test isolation)
def get-cache-file [] {
    if "AWS_CACHE_TEST_SUFFIX" in $env {
        $"/tmp/aws_cli_nushell_cache_state_($env.AWS_CACHE_TEST_SUFFIX).json"
    } else {
        "/tmp/aws_cli_nushell_cache_state.json"
    }
}

# Initialize empty cache state
def empty-cache [] {
    {
        entries: {},
        order: [],
        max_size: $MEMORY_CACHE_SIZE
    }
}

# Load cache state from persistent storage
def load-cache-state [] {
    let cache_file = get-cache-file
    if ($cache_file | path exists) {
        try {
            open $cache_file
        } catch {
            empty-cache
        }
    } else {
        empty-cache
    }
}

# Save cache state to persistent storage
def save-cache-state [cache: record] {
    let cache_file = get-cache-file
    $cache | to json | save -f $cache_file
}

# Get current cache state - always returns a valid cache structure
def get-cache [] {
    let loaded_cache = load-cache-state
    # Ensure we always have a valid cache structure
    if ($loaded_cache == null) or (($loaded_cache | describe) == "nothing") {
        empty-cache
    } else {
        $loaded_cache
    }
}

# Initialize memory cache - creates clean state
export def init-memory-cache [] {
    let cache_state = empty-cache
    save-cache-state $cache_state
    $cache_state
}

# Store data in memory cache with LRU eviction
export def store-in-memory [
    key: string,
    data: any
] {
    let cache = get-cache
    let timestamp = date now
    
    # Create cache entry with timestamp
    let entry = {
        data: $data,
        timestamp: $timestamp
    }
    
    # Remove key from current position if it exists
    let updated_order = if $key in $cache.entries {
        $cache.order | where $it != $key
    } else {
        $cache.order
    }
    
    # Add key to end of order (most recently used)
    let new_order = $updated_order | append $key
    
    # Check if we need to evict (only if adding new key)
    let is_new_key = $key not-in $cache.entries
    let final_order_and_entries = if $is_new_key and ($new_order | length) > $cache.max_size {
        # Evict least recently used (first in order)
        let evict_key = $new_order | first
        let remaining_order = $new_order | skip 1
        
        # Return evicted entries and final order
        {
            entries: ($cache.entries | reject $evict_key),
            order: $remaining_order
        }
    } else {
        {
            entries: $cache.entries,
            order: $new_order
        }
    }
    
    # Update cache with new/updated entry and order
    let updated_cache = {
        entries: ($final_order_and_entries.entries | upsert $key $entry),
        order: $final_order_and_entries.order,
        max_size: $cache.max_size
    }
    
    save-cache-state $updated_cache
    $updated_cache
}

# Retrieve data from memory cache
export def get-from-memory [
    key: string
] {
    let cache = get-cache
    
    if $key not-in $cache.entries {
        return null
    }
    
    # Update LRU order - move accessed key to end
    let updated_order = ($cache.order | where $it != $key) | append $key
    let updated_cache = ($cache | upsert order $updated_order)
    save-cache-state $updated_cache
    
    # Return the cached entry
    $cache.entries | get $key
}

# Get current memory cache size
export def get-memory-cache-size [] {
    let cache = get-cache
    if ($cache.entries == {}) {
        0
    } else {
        $cache.entries | columns | length
    }
}

# Check if cache entry is expired based on TTL
export def is-expired [
    timestamp: datetime,
    ttl: duration
] {
    let current_time = date now
    let age = $current_time - $timestamp
    $age > $ttl
}

# Clear memory cache (for testing)
export def clear-memory-cache [] {
    let cleared_cache = empty-cache
    save-cache-state $cleared_cache
    $cleared_cache
}

# Initialize memory cache with custom max size (for testing)
export def init-memory-cache-with-size [max_size: int] {
    let cache_state = {
        entries: {},
        order: [],
        max_size: $max_size
    }
    save-cache-state $cache_state
    $cache_state
}

# Get memory cache statistics
export def get-memory-cache-stats [] {
    let cache = get-cache
    {
        size: ($cache.entries | columns | length),
        max_size: $cache.max_size,
        entries: ($cache.entries | transpose key value | each {|entry| {
            key: $entry.key,
            timestamp: $entry.value.timestamp,
            size_estimate: ($entry.value.data | to json | str length)
        }})
    }
}