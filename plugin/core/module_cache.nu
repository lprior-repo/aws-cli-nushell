# Module Cache - Advanced caching system for service modules
# Provides intelligent caching, dependency tracking, and performance optimization

use configuration.nu

# Cache entry structure
def cache-entry-schema []: nothing -> record {
    {
        module_name: "string",
        module_path: "string", 
        loaded_module: "any",
        metadata: "record",
        load_time: "datetime",
        last_accessed: "datetime",
        access_count: "int",
        file_hash: "string",
        dependencies: "list",
        cache_version: "string",
        performance_metrics: "record"
    }
}

# Performance metrics structure
def performance-metrics-schema []: nothing -> record {
    {
        load_duration: "duration",
        memory_usage: "int",
        initialization_time: "duration",
        last_execution_time: "duration",
        total_execution_time: "duration",
        error_count: "int",
        success_count: "int"
    }
}

# Cache configuration
const CACHE_CONFIG = {
    max_entries: 50,
    ttl_seconds: 3600,
    cleanup_interval: 300,
    performance_tracking: true,
    dependency_tracking: true,
    auto_refresh: true
}

# Global cache state
export-env {
    $env.NUAWS_MODULE_CACHE_ENTRIES = {}
    $env.NUAWS_CACHE_STATS = {
        hits: 0,
        misses: 0,
        evictions: 0,
        last_cleanup: (date now)
    }
}

# Calculate file hash for cache invalidation
def calculate-file-hash [file_path: string]: nothing -> string {
    if ($file_path | path exists) {
        try {
            # Use file size and modification time as a simple hash
            let file_info = ls $file_path | first
            $"($file_info.size)-($file_info.modified | date to-timezone utc | format date '%Y%m%d%H%M%S')"
        } catch {
            "unknown"
        }
    } else {
        "missing"
    }
}

# Load module with comprehensive caching
export def load-module-cached [
    module_name: string,
    module_path: string,
    --force-reload = false,
    --track-performance = true
]: nothing -> any {
    
    let start_time = date now
    let current_hash = calculate-file-hash $module_path
    
    # Check if module is in cache and still valid
    if not $force_reload and $module_name in $env.NUAWS_MODULE_CACHE_ENTRIES {
        let cache_entry = $env.NUAWS_MODULE_CACHE_ENTRIES | get $module_name
        
        # Validate cache entry
        if ($cache_entry.file_hash == $current_hash) and ($cache_entry.module_path == $module_path) {
            # Cache hit - update access statistics
            mut updated_entry = $cache_entry
            $updated_entry.last_accessed = (date now)
            $updated_entry.access_count = $updated_entry.access_count + 1
            
            $env.NUAWS_MODULE_CACHE_ENTRIES = ($env.NUAWS_MODULE_CACHE_ENTRIES | upsert $module_name $updated_entry)
            
            # Update cache statistics
            $env.NUAWS_CACHE_STATS.hits = $env.NUAWS_CACHE_STATS.hits + 1
            
            if ($env.NUAWS_DEBUG == "true") {
                let load_time = (date now) - $start_time
                print $"📦 Cache hit for ($module_name) (($load_time))"
            }
            
            return $cache_entry.loaded_module
        } else {
            # Cache miss due to file change
            if ($env.NUAWS_DEBUG == "true") {
                print $"🔄 Cache invalidated for ($module_name) - file changed"
            }
        }
    }
    
    # Cache miss - load module
    $env.NUAWS_CACHE_STATS.misses = $env.NUAWS_CACHE_STATS.misses + 1
    
    let load_start = date now
    
    try {
        # For now, we'll simulate loading by checking if the file exists and is readable
        # In a real implementation, we'd need to use a different approach since `use` requires literal paths
        if not ($module_path | path exists) {
            error make { msg: $"Module file does not exist: ($module_path)" }
        }
        
        # Simulate a loaded module structure
        let loaded_module = {
            path: $module_path,
            loaded: true,
            timestamp: (date now)
        }
        let load_duration = (date now) - $load_start
        
        # Get module metadata (simulated for testing)
        let metadata = {
            name: $module_name,
            description: $"Module ($module_name)",
            version: "1.0.0",
            type: "cached_simulation"
        }
        
        # Analyze dependencies if tracking is enabled
        let dependencies = if $CACHE_CONFIG.dependency_tracking {
            analyze-module-dependencies $module_path
        } else {
            []
        }
        
        # Create performance metrics
        let performance_metrics = if $track_performance {
            {
                load_duration: $load_duration,
                memory_usage: 0, # Would need system-specific implementation
                initialization_time: $load_duration,
                last_execution_time: 0ms,
                total_execution_time: 0ms,
                error_count: 0,
                success_count: 1
            }
        } else {
            {}
        }
        
        # Create cache entry
        let cache_entry = {
            module_name: $module_name,
            module_path: $module_path,
            loaded_module: $loaded_module,
            metadata: $metadata,
            load_time: (date now),
            last_accessed: (date now),
            access_count: 1,
            file_hash: $current_hash,
            dependencies: $dependencies,
            cache_version: "1.0",
            performance_metrics: $performance_metrics
        }
        
        # Add to cache with eviction if needed
        add-to-cache $module_name $cache_entry
        
        if ($env.NUAWS_DEBUG == "true") {
            let total_time = (date now) - $start_time
            print $"📥 Loaded and cached ($module_name) (($total_time))"
        }
        
        return $loaded_module
        
    } catch { |err|
        if ($env.NUAWS_DEBUG == "true") {
            print $"❌ Failed to load module ($module_name): ($err.msg)"
        }
        
        error make {
            msg: $"Failed to load module '($module_name)': ($err.msg)"
        }
    }
}

# Add entry to cache with eviction policy
def add-to-cache [module_name: string, cache_entry: record]: nothing -> nothing {
    # Check if cache is full
    let current_size = ($env.NUAWS_MODULE_CACHE_ENTRIES | columns | length)
    
    if $current_size >= $CACHE_CONFIG.max_entries {
        # Evict least recently used entry
        let lru_entry = $env.NUAWS_MODULE_CACHE_ENTRIES 
            | transpose name entry 
            | sort-by {|item| $item.entry.last_accessed} 
            | first
        
        $env.NUAWS_MODULE_CACHE_ENTRIES = ($env.NUAWS_MODULE_CACHE_ENTRIES | reject $lru_entry.name)
        $env.NUAWS_CACHE_STATS.evictions = $env.NUAWS_CACHE_STATS.evictions + 1
        
        if ($env.NUAWS_DEBUG == "true") {
            print $"🗑️  Evicted ($lru_entry.name) from cache (LRU)"
        }
    }
    
    # Add new entry
    $env.NUAWS_MODULE_CACHE_ENTRIES = ($env.NUAWS_MODULE_CACHE_ENTRIES | insert $module_name $cache_entry)
}

# Analyze module dependencies
def analyze-module-dependencies [module_path: string]: nothing -> list<string> {
    try {
        let content = open $module_path
        
        # Parse 'use' statements to find dependencies
        let use_lines = $content | lines | where {|line| $line | str starts-with "use "}
        
        $use_lines | each {|line|
            # Extract module name from 'use module_name.nu' format
            let parts = $line | str replace "use " "" | str trim | split row " " | first
            $parts | str replace ".nu" ""
        }
    } catch {
        []
    }
}

# Get cached module if available
export def get-cached-module [module_name: string]: nothing -> any {
    if $module_name in $env.NUAWS_MODULE_CACHE_ENTRIES {
        let cache_entry = $env.NUAWS_MODULE_CACHE_ENTRIES | get $module_name
        
        # Update access statistics
        mut updated_entry = $cache_entry
        $updated_entry.last_accessed = (date now)
        $updated_entry.access_count = $updated_entry.access_count + 1
        
        $env.NUAWS_MODULE_CACHE_ENTRIES = ($env.NUAWS_MODULE_CACHE_ENTRIES | upsert $module_name $updated_entry)
        $env.NUAWS_CACHE_STATS.hits = $env.NUAWS_CACHE_STATS.hits + 1
        
        $cache_entry.loaded_module
    } else {
        null
    }
}

# Check if module is cached
export def is-module-cached [module_name: string]: nothing -> bool {
    $module_name in $env.NUAWS_MODULE_CACHE_ENTRIES
}

# Remove module from cache
export def evict-module [module_name: string]: nothing -> bool {
    if $module_name in $env.NUAWS_MODULE_CACHE_ENTRIES {
        $env.NUAWS_MODULE_CACHE_ENTRIES = ($env.NUAWS_MODULE_CACHE_ENTRIES | reject $module_name)
        $env.NUAWS_CACHE_STATS.evictions = $env.NUAWS_CACHE_STATS.evictions + 1
        true
    } else {
        false
    }
}

# Clear entire cache
export def clear-cache []: nothing -> record {
    let cleared_count = ($env.NUAWS_MODULE_CACHE_ENTRIES | columns | length)
    $env.NUAWS_MODULE_CACHE_ENTRIES = {}
    
    # Reset statistics
    $env.NUAWS_CACHE_STATS = {
        hits: 0,
        misses: 0,
        evictions: 0,
        last_cleanup: (date now)
    }
    
    {
        cleared_entries: $cleared_count,
        timestamp: (date now)
    }
}

# Get cache statistics
export def get-cache-stats []: nothing -> record {
    let total_requests = $env.NUAWS_CACHE_STATS.hits + $env.NUAWS_CACHE_STATS.misses
    let hit_rate = if $total_requests > 0 { 
        ($env.NUAWS_CACHE_STATS.hits / $total_requests * 100) | math round 
    } else { 
        0 
    }
    
    {
        entries: ($env.NUAWS_MODULE_CACHE_ENTRIES | columns | length),
        max_entries: $CACHE_CONFIG.max_entries,
        hits: $env.NUAWS_CACHE_STATS.hits,
        misses: $env.NUAWS_CACHE_STATS.misses,
        evictions: $env.NUAWS_CACHE_STATS.evictions,
        hit_rate: $"($hit_rate)%",
        total_requests: $total_requests,
        last_cleanup: $env.NUAWS_CACHE_STATS.last_cleanup
    }
}

# Get detailed cache information
export def get-cache-details []: nothing -> table {
    $env.NUAWS_MODULE_CACHE_ENTRIES 
    | transpose name entry 
    | each {|item|
        {
            module: $item.name,
            path: $item.entry.module_path,
            loaded: $item.entry.load_time,
            last_accessed: $item.entry.last_accessed,
            access_count: $item.entry.access_count,
            age: ((date now) - $item.entry.load_time),
            type: ($item.entry.metadata.type? | default "unknown"),
            dependencies: ($item.entry.dependencies | length),
            load_time: ($item.entry.performance_metrics.load_duration? | default 0ms)
        }
    }
    | sort-by last_accessed --reverse
}

# Cleanup expired cache entries
export def cleanup-cache []: nothing -> record {
    let current_time = date now
    let ttl = ($CACHE_CONFIG.ttl_seconds | into duration --unit sec)
    
    let entries_to_remove = $env.NUAWS_MODULE_CACHE_ENTRIES 
        | transpose name entry 
        | where {|item| ($current_time - $item.entry.load_time) > $ttl}
        | get name
    
    for entry in $entries_to_remove {
        $env.NUAWS_MODULE_CACHE_ENTRIES = ($env.NUAWS_MODULE_CACHE_ENTRIES | reject $entry)
    }
    
    $env.NUAWS_CACHE_STATS.last_cleanup = $current_time
    
    {
        cleaned_entries: ($entries_to_remove | length),
        remaining_entries: ($env.NUAWS_MODULE_CACHE_ENTRIES | columns | length),
        cleanup_time: $current_time
    }
}

# Warm cache with frequently used modules
export def warm-cache [modules: list<string>]: nothing -> record {
    # Process each module and collect results
    let results = $modules | each { |module_name|
        try {
            # Try to determine module path
            let module_path = match $module_name {
                "stepfunctions" => "aws/stepfunctions.nu",
                _ => $"plugin/services/($module_name).nu"
            }
            
            if ($module_path | path exists) {
                load-module-cached $module_name $module_path | ignore
                {module: $module_name, status: "warmed", reason: null}
            } else {
                {module: $module_name, status: "failed", reason: "File not found"}
            }
        } catch { |err|
            {module: $module_name, status: "failed", reason: $err.msg}
        }
    }
    
    # Separate warmed and failed modules
    let warmed = $results | where status == "warmed" | get module
    let failed = $results | where status == "failed" | select module reason
    
    {
        warmed: $warmed,
        failed: $failed,
        total_warmed: ($warmed | length),
        timestamp: (date now)
    }
}

# Auto-tune cache configuration based on usage patterns
export def auto-tune-cache []: nothing -> record {
    let stats = get-cache-stats
    let details = get-cache-details
    
    mut recommendations = []
    mut applied_changes = []
    
    # Analyze hit rate
    let hit_rate_num = $stats.hit_rate | str replace "%" "" | into float
    
    if $hit_rate_num < 60 {
        $recommendations = ($recommendations | append "Consider increasing cache size")
        
        # Auto-increase cache size if hit rate is low
        if $CACHE_CONFIG.max_entries < 100 {
            # This would require updating the constant, which isn't possible in Nushell
            # In a real implementation, we'd store config in a mutable global
            $applied_changes = ($applied_changes | append "Recommended cache size increase")
        }
    }
    
    # Analyze access patterns
    let avg_access_count = $details | each {|d| $d.access_count} | math avg
    let high_access_modules = $details | where access_count > ($avg_access_count * 2)
    
    if ($high_access_modules | length) > 0 {
        $recommendations = ($recommendations | append $"Consider keeping high-usage modules: ($high_access_modules | get module | str join ', ')")
    }
    
    # Analyze load times
    let slow_modules = $details | where load_time > 100ms
    if ($slow_modules | length) > 0 {
        $recommendations = ($recommendations | append $"Slow loading modules found: ($slow_modules | get module | str join ', ')")
    }
    
    {
        current_stats: $stats,
        recommendations: $recommendations,
        applied_changes: $applied_changes,
        high_usage_modules: ($high_access_modules | get module? | default []),
        analysis_time: (date now)
    }
}

# Background cache maintenance (would be called periodically)
export def maintain-cache []: nothing -> record {
    let cleanup_result = cleanup-cache
    let tune_result = auto-tune-cache
    
    {
        cleanup: $cleanup_result,
        tuning: $tune_result,
        maintenance_time: (date now)
    }
}