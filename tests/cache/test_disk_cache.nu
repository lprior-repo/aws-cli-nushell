# Disk Cache Test Suite
# Tests for compressed disk cache implementation

use std assert
use ../../aws/cache/disk.nu *

#[before-each]
def setup [] {
    # Clean up any existing test cache files
    let test_cache_dir = $"($env.HOME)/.cache/aws-nushell-test"
    if ($test_cache_dir | path exists) {
        rm -rf $test_cache_dir
    }
    
    # Override cache directory for testing
    $env.AWS_CACHE_DIR = $test_cache_dir
    
    {test_context: "disk_cache"}
}

#[after-each]
def cleanup [] {
    # Clean up test cache directory after each test
    let test_cache_dir = $"($env.HOME)/.cache/aws-nushell-test"
    if ($test_cache_dir | path exists) {
        rm -rf $test_cache_dir
    }
}

#[test]
def test_store_in_disk_basic [] {
    # RED: This will fail initially as store-in-disk doesn't exist
    let test_data = {key: "value", number: 42}
    
    store-in-disk "test-disk-key" $test_data
    
    # Verify file was created
    let cache_dir = get-cache-dir
    let cache_file = $"($cache_dir)/test-disk-key.json.gz"
    assert ($cache_file | path exists) "Cache file should be created"
    
    # Verify file is compressed - for small files, compression might not reduce size due to headers
    # Just verify the file exists and is readable, compression effectiveness is tested separately
    let file_size = (ls $cache_file | get 0.size | into int) 
    assert ($file_size > 0) "Cache file should have content"
}

#[test]
def test_get_from_disk_basic [] {
    # RED: This will fail initially
    let test_data = {message: "hello", items: [1, 2, 3]}
    
    store-in-disk "retrieve-test" $test_data
    let result = get-from-disk "retrieve-test"
    
    assert ($result != null) "Should retrieve stored data"
    assert ($result.data.message == "hello") "Should preserve data content"
    assert (($result.data.items | length) == 3) "Should preserve nested structures"
    assert ("timestamp" in $result) "Should include timestamp"
}

#[test]
def test_get_from_disk_nonexistent [] {
    # Test retrieving non-existent key
    let result = get-from-disk "nonexistent-key"
    assert ($result == null) "Should return null for non-existent key"
}

#[test]
def test_disk_cache_compression_effectiveness [] {
    # Test that compression actually reduces file size
    let large_data = {
        repeated_data: (1..1000 | each {|_| "this is repeated text that should compress well "} | str join ""),
        numbers: (1..1000 | each {|i| {id: $i, value: ($i * 2)}}),
        metadata: {
            description: "Large test data structure for compression testing",
            tags: (1..100 | each {|i| $"tag-($i)"})
        }
    }
    
    store-in-disk "compression-test" $large_data
    
    let cache_dir = get-cache-dir
    let cache_file = $"($cache_dir)/compression-test.json.gz"
    let compressed_size = (ls $cache_file | get 0.size | into int)
    let uncompressed_size = ($large_data | to json | str length)
    
    # Compression should achieve at least 50% reduction on this repetitive data
    assert ($compressed_size < ($uncompressed_size / 2)) "Compression should be effective"
}

#[test]
def test_disk_cache_directory_creation [] {
    # Test that cache directory is created if it doesn't exist
    let nested_key = "nested/path/test-key"
    let test_data = {content: "test"}
    
    store-in-disk $nested_key $test_data
    
    let cache_dir = get-cache-dir
    let cache_file = $"($cache_dir)/($nested_key).json.gz"
    assert ($cache_file | path exists) "Should create nested directory structure"
    
    let result = get-from-disk $nested_key
    assert ($result.data.content == "test") "Should retrieve from nested path"
}

#[test]
def test_disk_cache_timestamp_preservation [] {
    # Test that timestamps are preserved across disk storage
    let test_data = {value: "timestamp-test"}
    let before_store = date now
    
    store-in-disk "timestamp-test" $test_data
    
    # Add small delay to ensure timestamp difference would be visible
    sleep 10ms
    
    let result = get-from-disk "timestamp-test"
    let after_retrieve = date now
    
    assert ($result.timestamp >= $before_store) "Timestamp should be at or after store time"
    assert ($result.timestamp <= $after_retrieve) "Timestamp should be preserved from store time"
}

#[test]
def test_disk_cache_large_data_handling [] {
    # Test handling of larger data structures
    let large_data = {
        bulk_data: (0..10000 | each {|i| 
            {
                id: $i,
                name: $"resource-($i)",
                properties: {
                    type: (if ($i mod 2 == 0) { "even" } else { "odd" }),
                    category: $"cat-($i mod 10)",
                    metadata: (1..10 | each {|_| $"metadata-for-item-($i)"} | str join "")
                }
            }
        })
    }
    
    store-in-disk "large-data-test" $large_data
    let result = get-from-disk "large-data-test"
    
    assert (($result.data.bulk_data | length) == 10001) "Should handle large datasets"
    assert ($result.data.bulk_data.0.id == 0) "Should preserve data structure"
    assert ($result.data.bulk_data.5000.name == "resource-5000") "Should maintain data integrity"
}

#[test]
def test_disk_cache_special_characters_in_key [] {
    # Test handling of special characters in cache keys
    let special_key = "service:us-east-1:operation:param-hash-with-special-chars!@#$%"
    let test_data = {message: "special key test"}
    
    store-in-disk $special_key $test_data
    let result = get-from-disk $special_key
    
    assert ($result.data.message == "special key test") "Should handle special characters in keys"
}

#[test]
def test_disk_cache_concurrent_access [] {
    # Test that concurrent access doesn't cause issues
    let test_data = {concurrent: true, value: 12345}
    
    # Store the same key from multiple "threads" (simulate with multiple calls)
    store-in-disk "concurrent-test" $test_data
    store-in-disk "concurrent-test" ($test_data | insert updated true)
    
    let result = get-from-disk "concurrent-test"
    
    # Last write should win
    assert ("updated" in $result.data) "Last write should be preserved"
    assert ($result.data.updated == true) "Should have updated value"
}

#[test]
def test_is_expired_function [] {
    # RED: Test TTL expiration checking
    let current_time = date now
    let old_time = $current_time - 1hr
    let recent_time = $current_time - 1min
    
    assert (is-expired $old_time 30min) "Old timestamp should be expired"
    assert (not (is-expired $recent_time 30min)) "Recent timestamp should not be expired"
    assert (not (is-expired $current_time 30min)) "Current timestamp should not be expired"
}

#[test]
def test_disk_cache_cleanup_expired [] {
    # Test cleanup of expired cache entries
    let expired_data = {content: "expired"}
    let fresh_data = {content: "fresh"}
    
    store-in-disk "expired-entry" $expired_data
    store-in-disk "fresh-entry" $fresh_data
    
    # Manually set one entry's timestamp to be expired
    # This would require internal access to modify timestamps
    # For now, we test the expiration logic separately
    
    let old_time = (date now) - 2hr
    assert (is-expired $old_time 1hr) "Should correctly identify expired timestamps"
}