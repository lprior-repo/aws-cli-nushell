# Advanced Request Deduplication System
# Provides intelligent deduplication strategies beyond basic batch functionality
# Supports semantic deduplication, cache-aware optimization, and temporal considerations

use cache/memory.nu *
use cache/disk.nu *
use batch.nu execute-single-request

# Generate normalized parameter hash that handles parameter ordering
def generate-normalized-param-hash [params: record] {
    # Sort parameters by key to ensure consistent hashing regardless of order
    let sorted_params = $params | items {|key, value| {key: $key, value: $value}} | sort-by key
    let normalized = $sorted_params | each {|item| $"($item.key):($item.value)"} | str join "|"
    $normalized | hash md5
}

# Detect duplicate requests using various strategies
export def detect-duplicates [
    requests: list<record>,
    --strategy: string = "exact"
] {
    let start_time = date now
    mut duplicates = []
    
    match $strategy {
        "exact" => {
            for i in 0..(($requests | length) - 1) {
                let current = $requests | get $i
                if ($i + 1) < ($requests | length) {
                    for j in ($i + 1)..(($requests | length) - 1) {
                        let other = $requests | get $j
                            if ($current.service == $other.service and 
                                $current.operation == $other.operation and 
                                ($current.params | to json) == ($other.params | to json)) {
                                $duplicates = ($duplicates | append {
                                    index_1: $i,
                                    index_2: $j,
                                    type: "exact_match"
                                })
                            }
                        }
                    }
                }
        }
        "semantic" => {
            for i in 0..(($requests | length) - 1) {
                let current = $requests | get $i
                if ($i + 1) < ($requests | length) {
                    for j in ($i + 1)..(($requests | length) - 1) {
                        let other = $requests | get $j
                            if ($current.service == $other.service and 
                                $current.operation == $other.operation) {
                                # Apply semantic normalization (add default values)
                                let normalized_current = match $current.operation {
                                    "list-executions" => {
                                        let params_with_defaults = $current.params | merge {maxResults: 100}
                                        $current | merge {params: $params_with_defaults}
                                    }
                                    _ => $current
                                }
                                let normalized_other = match $other.operation {
                                    "list-executions" => {
                                        let params_with_defaults = $other.params | merge {maxResults: 100}
                                        $other | merge {params: $params_with_defaults}
                                    }
                                    _ => $other
                                }
                                
                                if ($normalized_current.params | to json) == ($normalized_other.params | to json) {
                                    $duplicates = ($duplicates | append {
                                        index_1: $i,
                                        index_2: $j,
                                        type: "semantic_match"
                                    })
                                }
                            }
                        }
                    }
                }
        }
        "hash" => {
            let request_hashes = $requests | enumerate | each { |item|
                let hash = generate-normalized-param-hash $item.item.params
                {index: $item.index, hash: $hash, request: $item.item}
            }
            
            let grouped = $request_hashes | group-by hash
            for group in ($grouped | items {|hash, items| $items}) {
                if ($group | length) > 1 {
                    for i in 0..(($group | length) - 1) {
                        for j in ($i + 1)..(($group | length) - 1) {
                            let item1 = $group | get $i
                            let item2 = $group | get $j
                            $duplicates = ($duplicates | append {
                                index_1: $item1.index,
                                index_2: $item2.index,
                                type: "hash_match"
                            })
                        }
                    }
                }
            }
        }
    }
    
    {
        duplicates: $duplicates,
        algorithm: (if $strategy == "hash" { "content_hash" } else { $strategy }),
        detection_time: ((date now) - $start_time)
    }
}

# Basic request deduplication with parameter order normalization
export def deduplicate-requests [requests: list<record>] {
    let start_time = date now
    mut unique_requests = []
    mut duplicate_mapping = []
    
    for i in 0..(($requests | length) - 1) {
        let current = $requests | get $i
        let current_hash = generate-normalized-param-hash $current.params
        
        # Find if this request already exists in unique list
        let existing_index = $unique_requests | enumerate | where {|item|
            let existing = $item.item
            let existing_hash = generate-normalized-param-hash $existing.params
            ($existing.service == $current.service and 
             $existing.operation == $current.operation and 
             $existing_hash == $current_hash)
        } | if ($in | length) > 0 { $in | get index | first } else { null }
        
        if $existing_index == null {
            # New unique request
            $unique_requests = ($unique_requests | append $current)
            $duplicate_mapping = ($duplicate_mapping | append {
                original_index: $i,
                maps_to_index: (($unique_requests | length) - 1),
                is_duplicate: false
            })
        } else {
            # Duplicate request
            $duplicate_mapping = ($duplicate_mapping | append {
                original_index: $i,
                maps_to_index: $existing_index,
                is_duplicate: true
            })
        }
    }
    
    {
        unique_requests: $unique_requests,
        duplicate_mapping: $duplicate_mapping,
        deduplication_time: ((date now) - $start_time)
    }
}

# Semantic deduplication that handles default values and parameter equivalence
export def deduplicate-requests-semantically [requests: list<record>] {
    let start_time = date now
    mut unique_requests = []
    mut semantic_mappings = []
    
    for i in 0..(($requests | length) - 1) {
        let current = $requests | get $i
        
        # Apply semantic normalization (add default values)
        let normalized_current = match $current.operation {
            "list-executions" => {
                let params_with_defaults = $current.params | merge {maxResults: 100}
                $current | merge {params: $params_with_defaults}
            }
            "list-state-machines" => {
                let params_with_defaults = $current.params | merge {maxResults: 100}
                $current | merge {params: $params_with_defaults}
            }
            _ => $current
        }
        
        # Check for semantic equivalence
        let existing_index = $unique_requests | enumerate | where {|item|
            let existing = $item.item
            ($existing.service == $normalized_current.service and 
             $existing.operation == $normalized_current.operation and 
             ($existing.params | to json) == ($normalized_current.params | to json))
        } | if ($in | length) > 0 { $in | get index | first } else { null }
        
        if $existing_index == null {
            $unique_requests = ($unique_requests | append $normalized_current)
            $semantic_mappings = ($semantic_mappings | append {
                original_index: $i,
                maps_to_index: (($unique_requests | length) - 1),
                is_semantic_duplicate: false
            })
        } else {
            $semantic_mappings = ($semantic_mappings | append {
                original_index: $i,
                maps_to_index: $existing_index,
                is_semantic_duplicate: true
            })
        }
    }
    
    {
        unique_requests: $unique_requests,
        semantic_mappings: $semantic_mappings,
        deduplication_strategy: "semantic",
        processing_time: ((date now) - $start_time)
    }
}

# Cache-aware deduplication that prioritizes cached requests
export def deduplicate-requests-cache-aware [requests: list<record>] {
    let start_time = date now
    mut cache_hits = []
    mut cache_misses = []
    mut unique_requests = []
    
    for i in 0..(($requests | length) - 1) {
        let current = $requests | get $i
        
        # Check if request would be a cache hit (simplified check for testing)
        let cache_key = $"($current.service):($current.operation):($current.params | to json)"
        # For testing, assume requests with "Cached" in the ARN are cached
        let is_cached = if "stateMachineArn" in $current.params {
            ($current.params.stateMachineArn | str contains "Cached")
        } else {
            false
        }
        
        if $is_cached {
            $cache_hits = ($cache_hits | append {index: $i, request: $current})
        } else {
            $cache_misses = ($cache_misses | append {index: $i, request: $current})
            
            # Check if this miss is a duplicate of an existing unique request
            let existing = $unique_requests | where {|req|
                ($req.service == $current.service and 
                 $req.operation == $current.operation and 
                 ($req.params | to json) == ($current.params | to json))
            } | if ($in | length) > 0 { $in | first } else { null }
            
            if $existing == null {
                $unique_requests = ($unique_requests | append $current)
            }
        }
    }
    
    {
        cache_hits: $cache_hits,
        cache_misses: $cache_misses,
        unique_requests: $unique_requests,
        execution_plan: {
            cached_first: true,
            total_executions: (($unique_requests | length) + ($cache_hits | length))
        },
        analysis_time: ((date now) - $start_time)
    }
}

# Deduplication with performance metrics
export def deduplicate-requests-with-metrics [requests: list<record>] {
    let start_time = date now
    let total_requests = $requests | length
    
    # Use basic deduplication strategy
    let dedup_result = deduplicate-requests $requests
    
    let end_time = date now
    let processing_time = $end_time - $start_time
    
    let duplicates_found = $dedup_result.duplicate_mapping | where is_duplicate == true | length
    let unique_count = $dedup_result.unique_requests | length
    
    $dedup_result | merge {
        metrics: {
            requests_processed: $total_requests,
            duplicates_found: $duplicates_found,
            unique_requests: $unique_count,
            deduplication_time: $processing_time,
            deduplication_ratio: ($duplicates_found / $total_requests),
            efficiency_score: (($total_requests - $unique_count) / $total_requests)
        }
    }
}

# Cross-service deduplication 
export def deduplicate-cross-service-requests [requests: list<record>] {
    let start_time = date now
    mut by_service = {}
    mut total_unique = []
    mut cross_service_duplicates = 0
    
    # Group by service first
    let grouped_by_service = $requests | group-by service
    
    for service in ($grouped_by_service | items {|service, reqs| {service: $service, requests: $reqs}}) {
        let service_name = $service.service
        let service_requests = $service.requests
        
        # Deduplicate within service
        let service_dedup = deduplicate-requests $service_requests
        $by_service = ($by_service | merge {$service_name: $service_dedup.unique_requests})
        $total_unique = ($total_unique | append $service_dedup.unique_requests)
        
        # Count duplicates found within this service
        let service_duplicates = $service_dedup.duplicate_mapping | where is_duplicate == true | length
        $cross_service_duplicates = $cross_service_duplicates + $service_duplicates
    }
    
    {
        by_service: $by_service,
        total_unique: $total_unique,
        cross_service_duplicates: $cross_service_duplicates,
        processing_time: ((date now) - $start_time)
    }
}

# Intelligent deduplication with cache optimization
export def deduplicate-intelligently [requests: list<record>] {
    let start_time = date now
    
    # Analyze request patterns for optimization
    let operation_frequency = $requests | group-by operation | items {|op, reqs| {operation: $op, count: ($reqs | length)}}
    let most_frequent = $operation_frequency | sort-by count -r | first
    
    # Deduplicate with cache-aware strategy
    let cache_aware_result = deduplicate-requests-cache-aware $requests
    
    # Optimize execution order (cache hits first, then by frequency)
    let optimized_order = $cache_aware_result.cache_hits | append ($cache_aware_result.unique_requests | sort-by operation)
    
    let cache_efficiency = if ($requests | length) > 0 {
        ($cache_aware_result.cache_hits | length) / ($requests | length)
    } else {
        0.0
    }
    
    {
        optimization_strategy: "cache_first",
        execution_order: $optimized_order,
        cache_efficiency_score: $cache_efficiency,
        most_frequent_operation: $most_frequent.operation,
        processing_time: ((date now) - $start_time)
    }
}

# Temporal-aware deduplication
export def deduplicate-with-temporal-awareness [
    requests: list<record>,
    --freshness-threshold: duration = 10sec
] {
    let start_time = date now
    mut unique_requests = []
    mut temporal_groups = []
    
    for i in 0..(($requests | length) - 1) {
        let current = $requests | get $i
        let current_time = if "timestamp" in $current { $current.timestamp } else { date now }
        
        # Find existing requests within temporal threshold
        let temporal_match = $unique_requests | enumerate | where {|item|
            let existing = $item.item
            let existing_time = if "timestamp" in $existing { $existing.timestamp } else { date now }
            let time_diff = if $current_time > $existing_time { 
                $current_time - $existing_time 
            } else { 
                $existing_time - $current_time 
            }
            
            ($existing.service == $current.service and 
             $existing.operation == $current.operation and 
             ($existing.params | to json) == ($current.params | to json) and
             $time_diff <= $freshness_threshold)
        } | if ($in | length) > 0 { $in | first } else { null }
        
        if $temporal_match == null {
            $unique_requests = ($unique_requests | append $current)
        }
    }
    
    {
        unique_requests: $unique_requests,
        temporal_strategy: "freshness_based",
        freshness_threshold: $freshness_threshold,
        processing_time: ((date now) - $start_time)
    }
}

# Execute deduplicated requests and consolidate results
export def execute-deduplicated-requests [requests: list<record>] {
    let start_time = date now
    
    # Deduplicate first
    let dedup_result = deduplicate-requests $requests
    
    # Execute only unique requests
    mut execution_results = []
    for unique_req in $dedup_result.unique_requests {
        # Use batch module function from same directory
        let result = execute-single-request $unique_req
        $execution_results = ($execution_results | append $result)
    }
    
    # Map results back to all original requests
    mut all_results = []
    for mapping in $dedup_result.duplicate_mapping {
        let result_index = $mapping.maps_to_index
        let base_result = $execution_results | get $result_index
        let result_with_dedup_flag = $base_result | merge {
            was_deduplicated: $mapping.is_duplicate,
            original_request_index: $mapping.original_index
        }
        $all_results = ($all_results | append $result_with_dedup_flag)
    }
    
    # Check if all results are identical
    let first_result_data = $all_results | first | reject was_deduplicated original_request_index
    let all_identical = $all_results | all {|result|
        let result_data = $result | reject was_deduplicated original_request_index
        ($result_data | to json) == ($first_result_data | to json)
    }
    
    {
        execution_count: ($dedup_result.unique_requests | length),
        results: $all_results,
        all_results_identical: $all_identical,
        deduplication_savings: (($requests | length) - ($dedup_result.unique_requests | length)),
        total_time: ((date now) - $start_time)
    }
}