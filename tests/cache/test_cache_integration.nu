# Cache Integration Test Suite
# Tests for cache-aware AWS operation wrappers
# Tests TTL, cache hits/misses, and AWS integration

use std assert
use ../../aws/cache/memory.nu *
use ../../aws/cache/disk.nu *
use ../../aws/cache/keys.nu *
use ../../aws/cache/operations.nu *

#[before-each]
def setup [] {
    # Create isolated cache for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    # Enable mock mode for Step Functions
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    clear-memory-cache | ignore
    {test_context: "cache_integration"}
}

#[test]
def test_cached_list_executions_cache_miss [] {
    # RED: This will fail initially - cache-aware wrapper doesn't exist
    # Test first call (cache miss) - should call AWS and cache result
    
    let start_time = date now
    let result = cached-list-executions --state-machine-arn "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    let end_time = date now
    
    # Verify result structure
    assert ($result != null) "Should return result"
    assert ("executions" in $result) "Should have executions field"
    assert ("cached" in $result) "Should indicate cache status"
    assert ($result.cached == false) "First call should be cache miss"
    assert ("cache_key" in $result) "Should include cache key"
    
    # Verify cache key format
    let expected_key_prefix = "test-profile:us-east-1:stepfunctions:list-executions"
    assert ($result.cache_key | str starts-with $expected_key_prefix) "Cache key should follow format"
    
    # Verify timing (should take some time for AWS call)
    let duration = $end_time - $start_time
    # Mock calls should be very fast, but let's just verify it completes
    assert ($duration >= 0ms) "Call should complete"
}

#[test]
def test_cached_list_executions_cache_hit [] {
    # Test second call (cache hit) - should return cached result much faster
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    
    # First call - populate cache
    let first_result = cached-list-executions --state-machine-arn $state_machine_arn
    
    # Second call - should hit cache
    let start_time = date now
    let second_result = cached-list-executions --state-machine-arn $state_machine_arn
    let end_time = date now
    
    # Verify cache hit
    assert ($second_result.cached == true) "Second call should be cache hit"
    assert ($second_result.cache_key == $first_result.cache_key) "Cache keys should match"
    
    # Verify data consistency
    assert ($second_result.executions == $first_result.executions) "Cached data should match original"
    
    # Cache hits should be very fast
    let duration = $end_time - $start_time
    assert ($duration < 100ms) "Cache hit should be very fast"
}

#[test]
def test_cached_list_executions_different_params [] {
    # Test that different parameters produce cache misses
    let arn1 = "arn:aws:states:us-east-1:123456789012:stateMachine:Machine1"
    let arn2 = "arn:aws:states:us-east-1:123456789012:stateMachine:Machine2"
    
    let result1 = cached-list-executions --state-machine-arn $arn1
    let result2 = cached-list-executions --state-machine-arn $arn2
    
    # Both should be cache misses with different keys
    assert ($result1.cached == false) "First call should be cache miss"
    assert ($result2.cached == false) "Different params should be cache miss"
    assert ($result1.cache_key != $result2.cache_key) "Different params should have different cache keys"
}

#[test]
def test_cached_list_executions_ttl_expiration [] {
    # RED: Test TTL expiration - cached data should expire and refresh
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    
    # First call with very short TTL (1 second)
    let first_result = cached-list-executions --state-machine-arn $state_machine_arn --ttl 1sec
    assert ($first_result.cached == false) "First call should be cache miss"
    
    # Immediate second call should hit cache
    let second_result = cached-list-executions --state-machine-arn $state_machine_arn --ttl 1sec
    assert ($second_result.cached == true) "Immediate second call should be cache hit"
    
    # Wait for TTL to expire
    sleep 1.5sec
    
    # Third call should be cache miss due to expiration
    let third_result = cached-list-executions --state-machine-arn $state_machine_arn --ttl 1sec
    assert ($third_result.cached == false) "Call after TTL expiration should be cache miss"
}

#[test]
def test_cached_list_state_machines_basic [] {
    # RED: Test another operation to ensure pattern works for multiple operations
    
    let result = cached-list-state-machines --max-results 10
    
    assert ($result != null) "Should return result"
    assert ("state_machines" in $result) "Should have state_machines field"
    assert ("cached" in $result) "Should indicate cache status"
    assert ($result.cached == false) "First call should be cache miss"
    
    # Verify cache key
    let expected_key_prefix = "test-profile:us-east-1:stepfunctions:list-state-machines"
    assert ($result.cache_key | str starts-with $expected_key_prefix) "Cache key should follow format"
}

#[test]
def test_cached_operations_multilevel_cache [] {
    # RED: Test that cache-aware operations use both memory and disk cache
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    
    # First call - should populate both memory and disk cache
    let first_result = cached-list-executions --state-machine-arn $state_machine_arn
    
    # Clear memory cache but leave disk cache
    clear-memory-cache | ignore
    
    # Second call - should hit disk cache and populate memory cache
    let second_result = cached-list-executions --state-machine-arn $state_machine_arn
    assert ($second_result.cached == true) "Should hit disk cache"
    assert ($second_result.cache_key == $first_result.cache_key) "Cache keys should match"
    
    # Third call - should hit memory cache
    let third_result = cached-list-executions --state-machine-arn $state_machine_arn
    assert ($third_result.cached == true) "Should hit memory cache"
}

#[test]
def test_cache_error_handling [] {
    # RED: Test that AWS errors are not cached
    # This requires simulating an AWS error condition
    
    # Use invalid parameters that would cause AWS error
    let result = try {
        cached-list-executions --state-machine-arn "invalid-arn-format"
    } catch { |error|
        # Errors should not be cached
        {error: $error.msg, cached: false}
    }
    
    # Verify error handling
    if "error" in $result {
        assert ($result.cached == false) "Errors should not be cached"
    } else {
        # If the call succeeded (in mock mode), verify it wasn't cached as error
        assert ($result.cached == false) "Invalid calls should still be cache miss"
    }
}

#[test]
def test_cache_profile_region_isolation [] {
    # RED: Test that different AWS profiles/regions are isolated in cache
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    
    # Call with first profile/region
    $env.AWS_PROFILE = "profile1"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    let result1 = cached-list-executions --state-machine-arn $state_machine_arn
    
    # Call with second profile/region - should be cache miss
    $env.AWS_PROFILE = "profile2"
    $env.AWS_DEFAULT_REGION = "us-west-2"
    let result2 = cached-list-executions --state-machine-arn $state_machine_arn
    
    assert ($result1.cached == false) "First call should be cache miss"
    assert ($result2.cached == false) "Different profile/region should be cache miss"
    assert ($result1.cache_key != $result2.cache_key) "Different contexts should have different cache keys"
}

#[test]
def test_cache_performance_metrics [] {
    # RED: Test that cache operations provide performance metrics
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    
    let result = cached-list-executions --state-machine-arn $state_machine_arn
    
    # Verify performance metrics are included
    assert ("timing" in $result) "Should include timing information"
    assert ("cache_lookup_time" in $result.timing) "Should track cache lookup time"
    assert ("aws_call_time" in $result.timing) "Should track AWS call time"
    assert ("cache_store_time" in $result.timing) "Should track cache store time"
    
    # Verify timing values are reasonable
    assert ($result.timing.cache_lookup_time >= 0ms) "Cache lookup time should be non-negative"
    assert ($result.timing.aws_call_time >= 0ms) "AWS call time should be non-negative" 
    assert ($result.timing.cache_store_time >= 0ms) "Cache store time should be non-negative"
}