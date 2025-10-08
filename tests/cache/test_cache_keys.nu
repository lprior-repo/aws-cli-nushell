# Cache Key Generation Test Suite
# Tests for cache key generation with profile/region scoping

use std assert
use ../../aws/cache/keys.nu *

#[before-each]
def setup [] {
    # Set up test environment
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    {test_context: "cache_keys"}
}

#[test]
def test_cache_key_basic_generation [] {
    # RED: This will fail initially as cache-key function doesn't exist
    # Ensure environment is set for this test
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    
    let key = cache-key "s3" "ListBuckets" {}
    
    assert ($key != null) "Cache key should be generated"
    assert (($key | str length) > 0) "Cache key should not be empty"
    assert ($key | str contains "test-profile") "Key should include profile"
    assert ($key | str contains "us-east-1") "Key should include region"
    assert ($key | str contains "s3") "Key should include service"
    assert ($key | str contains "ListBuckets") "Key should include operation"
}

#[test]
def test_cache_key_with_parameters [] {
    # Test cache key generation with parameters
    let params = {
        Bucket: "test-bucket",
        Prefix: "logs/",
        MaxKeys: 100
    }
    
    let key = cache-key "s3" "ListObjectsV2" $params
    
    assert ($key | str contains "s3") "Key should include service"
    assert ($key | str contains "ListObjectsV2") "Key should include operation"
    # Parameters should be hashed into the key
    assert (($key | str length) > 50) "Key should be longer with parameters"
}

#[test]
def test_cache_key_different_params_different_keys [] {
    # Test that different parameters produce different keys
    let params1 = {Bucket: "bucket1", Prefix: "logs/"}
    let params2 = {Bucket: "bucket2", Prefix: "logs/"}
    
    let key1 = cache-key "s3" "ListObjectsV2" $params1
    let key2 = cache-key "s3" "ListObjectsV2" $params2
    
    assert ($key1 != $key2) "Different parameters should produce different keys"
}

#[test]
def test_cache_key_same_params_same_keys [] {
    # Test that identical parameters produce identical keys
    let params = {Bucket: "test-bucket", MaxKeys: 100}
    
    let key1 = cache-key "s3" "ListObjectsV2" $params
    let key2 = cache-key "s3" "ListObjectsV2" $params
    
    assert ($key1 == $key2) "Identical parameters should produce identical keys"
}

#[test]
def test_cache_key_profile_isolation [] {
    # Test that different profiles produce different keys
    let params = {Bucket: "test-bucket"}
    
    let key1 = cache-key "s3" "ListObjects" $params --profile "profile1"
    let key2 = cache-key "s3" "ListObjects" $params --profile "profile2"
    
    assert ($key1 != $key2) "Different profiles should produce different keys"
    assert ($key1 | str contains "profile1") "Key1 should contain profile1"
    assert ($key2 | str contains "profile2") "Key2 should contain profile2"
}

#[test]
def test_cache_key_region_isolation [] {
    # Test that different regions produce different keys
    let params = {Bucket: "test-bucket"}
    
    let key1 = cache-key "s3" "ListObjects" $params --region "us-east-1"
    let key2 = cache-key "s3" "ListObjects" $params --region "us-west-2"
    
    assert ($key1 != $key2) "Different regions should produce different keys"
    assert ($key1 | str contains "us-east-1") "Key1 should contain us-east-1"
    assert ($key2 | str contains "us-west-2") "Key2 should contain us-west-2"
}

#[test]
def test_cache_key_default_values [] {
    # Test that default profile and region are used when not specified
    # Set environment for this test
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    
    let key = cache-key "ec2" "DescribeInstances" {}
    
    assert ($key | str contains $env.AWS_PROFILE) "Should use default profile"
    assert ($key | str contains $env.AWS_DEFAULT_REGION) "Should use default region"
}

#[test]
def test_cache_key_empty_params [] {
    # Test cache key generation with empty parameters
    let key = cache-key "iam" "ListUsers" {}
    
    assert ($key != null) "Should handle empty parameters"
    assert (($key | str length) > 20) "Key should still be substantial"
}

#[test]
def test_cache_key_deterministic [] {
    # Test that cache key generation is deterministic
    let params = {
        Filters: [
            {Name: "instance-state-name", Values: ["running"]},
            {Name: "tag:Environment", Values: ["prod"]}
        ]
    }
    
    # Generate key multiple times
    let keys = 0..5 | each {|_| cache-key "ec2" "DescribeInstances" $params}
    
    # All keys should be identical
    let unique_keys = $keys | uniq
    assert (($unique_keys | length) == 1) "Cache key generation should be deterministic"
}

#[test]
def test_cache_key_complex_nested_params [] {
    # Test with complex nested parameter structures
    let complex_params = {
        Filters: [
            {
                Name: "tag:Application",
                Values: ["web-app", "api-service"]
            },
            {
                Name: "instance-type", 
                Values: ["t3.micro", "t3.small"]
            }
        ],
        MaxResults: 50,
        NextToken: "eyJ0ZXN0IjoidG9rZW4ifQ=="
    }
    
    let key = cache-key "ec2" "DescribeInstances" $complex_params
    
    assert ($key != null) "Should handle complex nested parameters"
    assert (($key | str length) > 50) "Complex params should produce substantial key"
}

#[test]
def test_parameter_hash_consistency [] {
    # Test that parameter hashing is consistent
    let params = {a: 1, b: 2, c: 3}
    
    let hash1 = generate-param-hash $params
    let hash2 = generate-param-hash $params
    
    assert ($hash1 == $hash2) "Parameter hashing should be consistent"
    assert (($hash1 | str length) == 32) "Should produce MD5-length hash"
}

#[test]
def test_parameter_hash_different_order_same_result [] {
    # Test that parameter order doesn't affect hash (if we normalize)
    let params1 = {bucket: "test", prefix: "logs", maxkeys: 100}
    let params2 = {maxkeys: 100, bucket: "test", prefix: "logs"}
    
    let hash1 = generate-param-hash $params1
    let hash2 = generate-param-hash $params2
    
    # This tests our normalization - params should hash the same regardless of order
    assert ($hash1 == $hash2) "Parameter hash should be order-independent"
}