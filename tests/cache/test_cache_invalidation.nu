# Cache Invalidation Test Suite
# Tests for pattern-based cache invalidation functionality
# Tests invalidation by service, operation, resource, and custom patterns

use std assert
use ../../aws/cache/memory.nu *
use ../../aws/cache/disk.nu *
use ../../aws/cache/keys.nu *
use ../../aws/cache/invalidation.nu *

#[before-each]
def setup [] {
    # Create isolated cache for each test
    $env.AWS_CACHE_TEST_SUFFIX = (random chars -l 8)
    $env.AWS_PROFILE = "test-profile"
    $env.AWS_DEFAULT_REGION = "us-east-1"
    $env.STEPFUNCTIONS_MOCK_MODE = "true"
    clear-memory-cache | ignore
    clear-disk-cache | ignore
    {test_context: "cache_invalidation"}
}

#[test]
def test_invalidate_by_service_pattern [] {
    # RED: This will fail initially - invalidation functions don't exist
    # Test invalidating all cache entries for a specific service
    
    # Store some test data in cache
    let test_data1 = {executions: [{name: "exec1"}]}
    let test_data2 = {stateMachines: [{name: "sm1"}]}
    let test_data3 = {instances: [{id: "i-123"}]}
    
    let key1 = cache-key "stepfunctions" "list-executions" {arn: "test1"}
    let key2 = cache-key "stepfunctions" "list-state-machines" {}
    let key3 = cache-key "ec2" "describe-instances" {}
    
    store-in-memory $key1 $test_data1 | ignore
    store-in-memory $key2 $test_data2 | ignore
    store-in-memory $key3 $test_data3 | ignore
    
    store-in-disk $key1 $test_data1 | ignore
    store-in-disk $key2 $test_data2 | ignore
    store-in-disk $key3 $test_data3 | ignore
    
    # Verify all entries exist
    assert ((get-from-memory $key1) != null) "StepFunctions exec entry should exist"
    assert ((get-from-memory $key2) != null) "StepFunctions SM entry should exist"
    assert ((get-from-memory $key3) != null) "EC2 entry should exist"
    
    # Invalidate all stepfunctions entries
    invalidate-cache-by-service "stepfunctions"
    
    # Verify stepfunctions entries are gone but EC2 remains
    assert ((try { get-from-memory $key1 } catch { null }) == null) "StepFunctions exec entry should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "StepFunctions SM entry should be invalidated"
    assert ((get-from-memory $key3) != null) "EC2 entry should remain"
}

#[test]
def test_invalidate_by_service_operation_pattern [] {
    # Test invalidating cache entries for specific service and operation
    
    let test_data1 = {executions: [{name: "exec1"}]}
    let test_data2 = {executions: [{name: "exec2"}]}
    let test_data3 = {stateMachines: [{name: "sm1"}]}
    
    let key1 = cache-key "stepfunctions" "list-executions" {arn: "test1"}
    let key2 = cache-key "stepfunctions" "list-executions" {arn: "test2"}
    let key3 = cache-key "stepfunctions" "list-state-machines" {}
    
    store-in-memory $key1 $test_data1 | ignore
    store-in-memory $key2 $test_data2 | ignore
    store-in-memory $key3 $test_data3 | ignore
    
    # Invalidate only list-executions
    invalidate-cache-by-operation "stepfunctions" "list-executions"
    
    # Verify list-executions entries are gone but list-state-machines remains
    assert ((try { get-from-memory $key1 } catch { null }) == null) "Execution entry 1 should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "Execution entry 2 should be invalidated"
    assert ((get-from-memory $key3) != null) "State machines entry should remain"
}

#[test]
def test_invalidate_by_resource_pattern [] {
    # Test invalidating cache entries related to a specific resource
    
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    let execution_arn = "arn:aws:states:us-east-1:123456789012:execution:TestMachine:exec1"
    
    let test_data1 = {executions: [{arn: $execution_arn}]}
    let test_data2 = {execution: {arn: $execution_arn}}
    let test_data3 = {stateMachines: [{arn: $state_machine_arn}]}
    
    let key1 = cache-key "stepfunctions" "list-executions" {stateMachineArn: $state_machine_arn}
    let key2 = cache-key "stepfunctions" "describe-execution" {executionArn: $execution_arn}
    let key3 = cache-key "stepfunctions" "list-state-machines" {}
    
    store-in-memory $key1 $test_data1 | ignore
    store-in-memory $key2 $test_data2 | ignore
    store-in-memory $key3 $test_data3 | ignore
    
    # Invalidate entries related to the specific state machine
    invalidate-cache-by-resource "stepfunctions" "stateMachine" "TestMachine"
    
    # Verify related entries are gone
    assert ((try { get-from-memory $key1 } catch { null }) == null) "Related execution list should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "Related execution should be invalidated"
    assert ((get-from-memory $key3) != null) "Unrelated state machines list should remain"
}

#[test]
def test_invalidate_by_custom_pattern [] {
    # Test invalidating cache entries matching custom patterns
    
    let test_data1 = {data: "value1"}
    let test_data2 = {data: "value2"}
    let test_data3 = {data: "value3"}
    
    let key1 = cache-key "s3" "list-objects" {bucket: "my-bucket", prefix: "logs/"}
    let key2 = cache-key "s3" "list-objects" {bucket: "my-bucket", prefix: "images/"}
    let key3 = cache-key "s3" "get-object" {bucket: "other-bucket", key: "file.txt"}
    
    store-in-memory $key1 $test_data1 | ignore
    store-in-memory $key2 $test_data2 | ignore
    store-in-memory $key3 $test_data3 | ignore
    
    # Invalidate entries containing "my-bucket"
    invalidate-cache-by-pattern "*my-bucket*"
    
    # Verify bucket-specific entries are gone
    assert ((try { get-from-memory $key1 } catch { null }) == null) "My-bucket entry 1 should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "My-bucket entry 2 should be invalidated"
    assert ((get-from-memory $key3) != null) "Other-bucket entry should remain"
}

#[test]
def test_invalidate_expired_entries [] {
    # Test invalidating only expired cache entries
    
    let test_data = {data: "test"}
    let key1 = cache-key "service" "operation1" {}
    let key2 = cache-key "service" "operation2" {}
    
    # Store entries with different timestamps
    store-in-memory $key1 $test_data | ignore
    store-in-memory $key2 $test_data | ignore
    
    # Wait briefly then invalidate expired entries (with very short TTL)
    sleep 0.1sec
    invalidate-expired-cache 50ms
    
    # All entries should be invalidated as expired
    assert ((try { get-from-memory $key1 } catch { null }) == null) "Expired entry 1 should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "Expired entry 2 should be invalidated"
}

#[test]
def test_invalidate_by_profile_region [] {
    # Test invalidating cache entries for specific profile/region combinations
    
    let test_data = {data: "test"}
    
    # Create keys with different profiles/regions
    let key1 = cache-key "s3" "list-buckets" {} --profile "profile1" --region "us-east-1"
    let key2 = cache-key "s3" "list-buckets" {} --profile "profile2" --region "us-east-1"
    let key3 = cache-key "s3" "list-buckets" {} --profile "profile1" --region "us-west-2"
    
    store-in-memory $key1 $test_data | ignore
    store-in-memory $key2 $test_data | ignore
    store-in-memory $key3 $test_data | ignore
    
    # Invalidate entries for profile1 only
    invalidate-cache-by-profile "profile1"
    
    # Verify profile1 entries are gone but profile2 remains
    assert ((try { get-from-memory $key1 } catch { null }) == null) "Profile1 us-east-1 entry should be invalidated"
    assert ((try { get-from-memory $key3 } catch { null }) == null) "Profile1 us-west-2 entry should be invalidated"
    assert ((get-from-memory $key2) != null) "Profile2 entry should remain"
}

#[test]
def test_cascade_invalidation [] {
    # Test cascading invalidation - when a resource changes, invalidate related caches
    
    let state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:TestMachine"
    let execution_arn = "arn:aws:states:us-east-1:123456789012:execution:TestMachine:exec1"
    
    let test_data1 = {executions: []}
    let test_data2 = {execution: {}}
    let test_data3 = {stateMachines: []}
    
    let key1 = cache-key "stepfunctions" "list-executions" {stateMachineArn: $state_machine_arn}
    let key2 = cache-key "stepfunctions" "describe-execution" {executionArn: $execution_arn}
    let key3 = cache-key "stepfunctions" "list-state-machines" {}
    
    store-in-memory $key1 $test_data1 | ignore
    store-in-memory $key2 $test_data2 | ignore
    store-in-memory $key3 $test_data3 | ignore
    
    # Trigger cascade invalidation when state machine is updated
    cascade-invalidate-on-resource-change "stepfunctions" "stateMachine" $state_machine_arn
    
    # Verify cascading invalidation
    assert ((try { get-from-memory $key1 } catch { null }) == null) "Related executions list should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "Related execution should be invalidated" 
    assert ((try { get-from-memory $key3 } catch { null }) == null) "State machines list should be invalidated"
}

#[test]
def test_selective_invalidation_preserves_unrelated [] {
    # Test that selective invalidation preserves unrelated cache entries
    
    let test_data = {data: "test"}
    
    # Create a mix of related and unrelated entries
    let key1 = cache-key "stepfunctions" "list-executions" {arn: "test1"}
    let key2 = cache-key "stepfunctions" "list-state-machines" {}
    let key3 = cache-key "lambda" "list-functions" {}
    let key4 = cache-key "ec2" "describe-instances" {}
    let key5 = cache-key "s3" "list-buckets" {}
    
    # Store all entries
    [key1, key2, key3, key4, key5] | each {|key| store-in-memory $key $test_data | ignore}
    
    # Invalidate only stepfunctions
    invalidate-cache-by-service "stepfunctions"
    
    # Verify selective invalidation
    assert ((try { get-from-memory $key1 } catch { null }) == null) "StepFunctions exec should be invalidated"
    assert ((try { get-from-memory $key2 } catch { null }) == null) "StepFunctions SM should be invalidated"
    assert ((get-from-memory $key3) != null) "Lambda should remain"
    assert ((get-from-memory $key4) != null) "EC2 should remain"
    assert ((get-from-memory $key5) != null) "S3 should remain"
}

#[test]
def test_invalidation_affects_both_memory_and_disk [] {
    # Test that invalidation affects both memory and disk caches
    
    let test_data = {data: "test"}
    let key = cache-key "stepfunctions" "list-executions" {arn: "test"}
    
    # Store in both caches
    store-in-memory $key $test_data | ignore
    store-in-disk $key $test_data | ignore
    
    # Verify both exist
    assert ((get-from-memory $key) != null) "Memory entry should exist"
    assert ((get-from-disk $key) != null) "Disk entry should exist"
    
    # Invalidate by service
    invalidate-cache-by-service "stepfunctions"
    
    # Verify both are gone
    assert ((try { get-from-memory $key } catch { null }) == null) "Memory entry should be invalidated"
    assert ((try { get-from-disk $key } catch { null }) == null) "Disk entry should be invalidated"
}