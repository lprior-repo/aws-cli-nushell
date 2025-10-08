# Memory Cache Test Suite
# Tests for LRU memory cache implementation following TDD principles

use std assert
use ../../aws/cache/memory.nu *

#[before-each]
def setup [] {
    # Create isolated cache file for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    # Initialize clean cache state for each test
    clear-memory-cache | ignore
    {test_context: "memory_cache"}
}

#[test]
def test_init_memory_cache [] {
    # RED: This test will fail initially as the function doesn't exist
    let cache_result = init-memory-cache
    
    assert ($cache_result != null) "Memory cache should be initialized"
    assert ("entries" in $cache_result) "Cache should have entries field"
    assert ("order" in $cache_result) "Cache should have order field for LRU"
    assert ("max_size" in $cache_result) "Cache should have max_size field"
    assert ($cache_result.entries == {}) "Cache entries should start empty"
    assert ($cache_result.order == []) "Cache order should start empty"
}

#[test]  
def test_store_in_memory_basic [] {
    # RED: This test will fail initially
    init-memory-cache
    
    store-in-memory "test-key" "test-value"
    
    let result = get-from-memory "test-key"
    assert ($result != null) "Should retrieve stored value"
    assert ($result.data == "test-value") "Should return correct value"
    assert ("timestamp" in $result) "Should include timestamp"
}

#[test]
def test_store_in_memory_complex_data [] {
    # Test with complex data structures
    init-memory-cache
    
    let complex_data = {
        id: 123,
        name: "test-resource",
        tags: [{key: "Environment", value: "test"}],
        metadata: {created: "2023-01-01", size: 1024}
    }
    
    store-in-memory "complex-key" $complex_data
    
    let result = get-from-memory "complex-key"
    assert ($result.data.id == 123) "Should store complex data correctly"
    assert ($result.data.name == "test-resource") "Should maintain data integrity"
    assert (($result.data.tags | length) == 1) "Should preserve nested structures"
}

#[test]
def test_lru_eviction_basic [] {
    # RED: Test LRU eviction with small cache size
    init-memory-cache-with-size 3 | ignore
    
    # Fill cache to capacity
    store-in-memory "key1" "value1"
    store-in-memory "key2" "value2" 
    store-in-memory "key3" "value3"
    
    let cache_after_fill = get-memory-cache-stats
    assert ($cache_after_fill.size == 3) "Cache should be at capacity"
    
    # Add fourth item, should evict first
    store-in-memory "key4" "value4"
    
    let cache_after_eviction = get-memory-cache-stats
    assert ($cache_after_eviction.size == 3) "Cache should maintain max size"
    let result1 = get-from-memory "key1"
    assert ($result1 == null) "Oldest item should be evicted"
    let result4 = get-from-memory "key4" 
    assert ($result4 != null) "New item should be present"
}

#[test]
def test_lru_access_updates_order [] {
    # Test that accessing an item updates its position in LRU order
    init-memory-cache-with-size 3 | ignore
    
    store-in-memory "key1" "value1"
    store-in-memory "key2" "value2"
    store-in-memory "key3" "value3"
    
    # Access key1 to move it to end of LRU order
    get-from-memory "key1" | ignore
    
    # Add new item, key2 should be evicted (now oldest)
    store-in-memory "key4" "value4"
    
    let result2 = get-from-memory "key2"
    assert ($result2 == null) "key2 should be evicted"
    let result1_check = get-from-memory "key1"
    assert ($result1_check != null) "key1 should remain (recently accessed)"
    let result3 = get-from-memory "key3"
    assert ($result3 != null) "key3 should remain"
    let result4_check = get-from-memory "key4"
    assert ($result4_check != null) "key4 should be present"
}

#[test]
def test_get_from_memory_nonexistent [] {
    # Test retrieving non-existent key
    init-memory-cache
    
    let result = get-from-memory "nonexistent-key"
    assert ($result == null) "Should return null for non-existent key"
}

#[test]
def test_memory_cache_timestamp_tracking [] {
    # Test that timestamps are properly recorded
    init-memory-cache
    
    let before = date now
    store-in-memory "timestamped-key" "value"
    let after = date now
    
    let result = get-from-memory "timestamped-key"
    assert ($result.timestamp >= $before) "Timestamp should be after store time"
    assert ($result.timestamp <= $after) "Timestamp should be reasonable"
}

#[test]
def test_memory_cache_update_existing_key [] {
    # Test updating an existing key
    init-memory-cache
    
    store-in-memory "update-key" "original-value"
    let original_result = get-from-memory "update-key"
    
    sleep 1ms  # Ensure different timestamp
    store-in-memory "update-key" "updated-value"
    let updated_result = get-from-memory "update-key"
    
    assert ($updated_result.data == "updated-value") "Value should be updated"
    assert ($updated_result.timestamp > $original_result.timestamp) "Timestamp should be newer"
}

#[test]
def test_memory_cache_size_tracking [] {
    # Test that cache tracks its current size
    init-memory-cache
    
    let initial_size = get-memory-cache-size
    assert ($initial_size == 0) "Initial size should be zero"
    
    store-in-memory "size-test-1" "value1"
    let size1 = get-memory-cache-size
    assert ($size1 == 1) "Size should increment"
    
    store-in-memory "size-test-2" "value2"
    let size2 = get-memory-cache-size
    assert ($size2 == 2) "Size should continue incrementing"
    
    store-in-memory "size-test-1" "updated-value"  # Update existing
    let final_size = get-memory-cache-size
    assert ($final_size == 2) "Size should not change on update"
}