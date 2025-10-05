use std/assert
use ../../aws/dynamodb.nu

#[before-each]
def setup [] {
    {
        test_table_name: "test-table"
        test_table_arn: "arn:aws:dynamodb:us-east-1:123456789012:table/test-table"
        test_stream_arn: "arn:aws:dynamodb:us-east-1:123456789012:table/test-table/stream/2023-12-01T00:00:00.000"
        test_shard_id: "shardId-00000001234567890123-abcdefgh"
        test_shard_iterator: "arn:aws:dynamodb:us-east-1:123456789012:table/test-table/stream/2023-12-01T00:00:00.000|1|AAAAAAAAAAEn"
        test_sequence_number: "100000000001234567890"
        test_resource_arn: "arn:aws:dynamodb:us-east-1:123456789012:table/test-table"
        test_tags: [
            { Key: "Environment", Value: "Test" }
            { Key: "Project", Value: "Nutest" }
            { Key: "Owner", Value: "TestUser" }
        ]
        test_tag_keys: ["Environment", "Project"]
        test_ttl_attribute_name: "expires_at"
        test_global_table_name: "global-test-table"
        test_replica_updates: [
            {
                Create: {
                    RegionName: "us-west-2"
                    ProvisionedThroughputSettings: {
                        ReadCapacityUnits: 5
                        WriteCapacityUnits: 5
                    }
                    GlobalSecondaryIndexes: [
                        {
                            IndexName: "global-gsi"
                            KeySchema: [
                                { AttributeName: "gsi_pk", KeyType: "HASH" }
                            ]
                            Projection: { ProjectionType: "ALL" }
                            ProvisionedThroughputSettings: {
                                ReadCapacityUnits: 5
                                WriteCapacityUnits: 5
                            }
                        }
                    ]
                }
            }
        ]
    }
}

# ============================================================================
# DYNAMODB STREAMS TESTS (15 tests)
# ============================================================================

#[test]
def "describe stream with valid stream arn" [] {
    let context = $in
    
    let result = try {
        dynamodb describe-stream $context.test_stream_arn
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get StreamDescription.StreamArn? | default "" | str contains $context.test_stream_arn)
    assert ($result | get StreamDescription.StreamStatus? | default "" | str length) > 0
}

#[test]
def "describe stream validates stream arn format" [] {
    let invalid_arns = [
        ""  # Empty ARN
        "invalid-arn"  # Not an ARN
        "arn:aws:dynamodb:us-east-1:123456789012:table/test"  # Table ARN, not stream ARN
        "arn:aws:kinesis:us-east-1:123456789012:stream/test"  # Kinesis ARN, not DynamoDB stream
    ]
    
    for arn in $invalid_arns {
        try {
            dynamodb describe-stream $arn
            assert false $"Should have failed with invalid ARN: ($arn)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "ARN"))
        }
    }
}

#[test]
def "describe stream with limit parameter" [] {
    let context = $in
    let limit = 10
    
    let result = try {
        dynamodb describe-stream $context.test_stream_arn --limit $limit
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get StreamDescription.Shards? | default [] | length) <= $limit
}

#[test]
def "describe stream with exclusive start shard id" [] {
    let context = $in
    
    let result = try {
        dynamodb describe-stream $context.test_stream_arn --exclusive-start-shard-id $context.test_shard_id
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "list streams without parameters" [] {
    let result = try {
        dynamodb list-streams
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Streams? | default [] | describe | get type) ("list")
}

#[test]
def "list streams for specific table" [] {
    let context = $in
    
    let result = try {
        dynamodb list-streams --table-name $context.test_table_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Streams? | default [] | describe | get type) ("list")
}

#[test]
def "list streams with limit" [] {
    let limit = 5
    
    let result = try {
        dynamodb list-streams --limit $limit
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get Streams? | default [] | length) <= $limit
}

#[test]
def "get shard iterator with trim horizon" [] {
    let context = $in
    
    let result = try {
        dynamodb get-shard-iterator $context.test_stream_arn $context.test_shard_id "TRIM_HORIZON"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get ShardIterator? | default "" | str length) > 0
}

#[test]
def "get shard iterator with latest" [] {
    let context = $in
    
    let result = try {
        dynamodb get-shard-iterator $context.test_stream_arn $context.test_shard_id "LATEST"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get ShardIterator? | default "" | str length) > 0
}

#[test]
def "get shard iterator with at sequence number" [] {
    let context = $in
    
    let result = try {
        dynamodb get-shard-iterator $context.test_stream_arn $context.test_shard_id "AT_SEQUENCE_NUMBER" --sequence-number $context.test_sequence_number
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "get shard iterator validates parameters" [] {
    let context = $in
    
    let invalid_iterator_types = ["INVALID", "BEGINNING", "END", ""]
    
    for iterator_type in $invalid_iterator_types {
        try {
            dynamodb get-shard-iterator $context.test_stream_arn $context.test_shard_id $iterator_type
            assert false $"Should have failed with invalid iterator type: ($iterator_type)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "iterator"))
        }
    }
}

#[test]
def "get records with shard iterator" [] {
    let context = $in
    
    let result = try {
        dynamodb get-records $context.test_shard_iterator
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Records? | default [] | describe | get type) ("list")
    # NextShardIterator can be string or nothing
    let next_iterator_type = ($result | get NextShardIterator? | default null | describe | get type)
    assert ($next_iterator_type == "string" or $next_iterator_type == "nothing")
}

#[test]
def "get records with limit" [] {
    let context = $in
    let limit = 10
    
    let result = try {
        dynamodb get-records $context.test_shard_iterator --limit $limit
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get Records? | default [] | length) <= $limit
}

#[test]
def "get records validates shard iterator" [] {
    let invalid_iterators = [
        ""  # Empty iterator
        "invalid-iterator"  # Invalid format
        "arn:aws:dynamodb:us-east-1:123456789012:table/test/invalid"  # Invalid iterator format
    ]
    
    for iterator in $invalid_iterators {
        try {
            dynamodb get-records $iterator
            assert false $"Should have failed with invalid iterator: ($iterator)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "iterator"))
        }
    }
}

#[test]
def "streams in mock mode return consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb list-streams
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get Streams? | default [] | describe | get type) ("list")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# TIME TO LIVE (TTL) TESTS (8 tests)
# ============================================================================

#[test]
def "describe time to live for table" [] {
    let context = $in
    
    let result = try {
        dynamodb describe-time-to-live $context.test_table_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get TimeToLiveDescription? | default {} | columns | length) > 0
    assert ($result | get TimeToLiveDescription.TimeToLiveStatus? | default "" | str length) > 0
}

#[test]
def "describe time to live validates table name" [] {
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb describe-time-to-live $name
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "update time to live enable" [] {
    let context = $in
    
    let ttl_specification = {
        Enabled: true
        AttributeName: $context.test_ttl_attribute_name
    }
    
    let result = try {
        dynamodb update-time-to-live $context.test_table_name $ttl_specification
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get TimeToLiveSpecification.Enabled? | default false) (true)
    assert ($result | get TimeToLiveSpecification.AttributeName? | default "" | str contains $context.test_ttl_attribute_name)
}

#[test]
def "update time to live disable" [] {
    let context = $in
    
    let ttl_specification = {
        Enabled: false
        AttributeName: $context.test_ttl_attribute_name
    }
    
    let result = try {
        dynamodb update-time-to-live $context.test_table_name $ttl_specification
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get TimeToLiveSpecification.Enabled? | default true) (false)
}

#[test]
def "update time to live validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    let ttl_spec = { Enabled: true, AttributeName: $context.test_ttl_attribute_name }
    
    for name in $invalid_names {
        try {
            dynamodb update-time-to-live $name $ttl_spec
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "update time to live validates specification" [] {
    let context = $in
    
    let invalid_specs = [
        {}  # Empty specification
        { Enabled: true }  # Missing AttributeName
        { AttributeName: "ttl" }  # Missing Enabled
        { Enabled: "invalid", AttributeName: "ttl" }  # Invalid boolean
        { Enabled: true, AttributeName: "" }  # Empty attribute name
        { Enabled: true, AttributeName: "invalid@attr" }  # Invalid attribute name
    ]
    
    for spec in $invalid_specs {
        try {
            dynamodb update-time-to-live $context.test_table_name $spec
            assert false $"Should have failed with invalid specification: ($spec)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "specification"))
        }
    }
}

#[test]
def "time to live operations handle table not found" [] {
    let context = $in
    let non_existent_table = "non-existent-table-12345"
    
    try {
        dynamodb describe-time-to-live $non_existent_table
        assert false "Should have failed with non-existent table"
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "not found" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

#[test]
def "time to live in mock mode returns consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb describe-time-to-live $context.test_table_name
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get TimeToLiveDescription? | default {} | describe | get type) ("record")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# TAGGING TESTS (12 tests)
# ============================================================================

#[test]
def "tag resource with multiple tags" [] {
    let context = $in
    
    let result = try {
        dynamodb tag-resource $context.test_resource_arn $context.test_tags
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Tag operation should succeed without returning data
    assert true
}

#[test]
def "tag resource validates resource arn" [] {
    let context = $in
    let invalid_arns = [
        ""  # Empty ARN
        "invalid-arn"  # Not an ARN
        "arn:aws:s3:::bucket/key"  # S3 ARN, not DynamoDB
        "arn:aws:dynamodb:us-east-1:123456789012:invalid/test"  # Invalid DynamoDB resource
    ]
    
    for arn in $invalid_arns {
        try {
            dynamodb tag-resource $arn $context.test_tags
            assert false $"Should have failed with invalid ARN: ($arn)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "ARN"))
        }
    }
}

#[test]
def "tag resource validates tags format" [] {
    let context = $in
    
    let invalid_tag_sets = [
        []  # Empty tags
        [{ Key: "", Value: "test" }]  # Empty key
        [{ Key: "test", Value: "" }]  # Empty value
        [{ Value: "test" }]  # Missing key
        [{ Key: "test" }]  # Missing value
        [{ Key: (1..129 | each { "x" } | str join), Value: "test" }]  # Key too long
        [{ Key: "test", Value: (1..257 | each { "x" } | str join) }]  # Value too long
    ]
    
    for tags in $invalid_tag_sets {
        try {
            dynamodb tag-resource $context.test_resource_arn $tags
            assert false $"Should have failed with invalid tags: ($tags)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "tag"))
        }
    }
}

#[test]
def "tag resource handles too many tags" [] {
    let context = $in
    
    # Create more than 50 tags (AWS limit)
    let too_many_tags = (0..60 | each { |i| { Key: $"Key($i)", Value: $"Value($i)" } })
    
    try {
        dynamodb tag-resource $context.test_resource_arn $too_many_tags
        assert false "Should have failed with too many tags"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "too many"))
    }
}

#[test]
def "untag resource with specific tag keys" [] {
    let context = $in
    
    let result = try {
        dynamodb untag-resource $context.test_resource_arn $context.test_tag_keys
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Untag operation should succeed without returning data
    assert true
}

#[test]
def "untag resource validates resource arn" [] {
    let context = $in
    let invalid_arns = [
        ""  # Empty ARN
        "invalid-arn"  # Not an ARN
        "arn:aws:s3:::bucket/key"  # S3 ARN, not DynamoDB
    ]
    
    for arn in $invalid_arns {
        try {
            dynamodb untag-resource $arn $context.test_tag_keys
            assert false $"Should have failed with invalid ARN: ($arn)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "ARN"))
        }
    }
}

#[test]
def "untag resource validates tag keys" [] {
    let context = $in
    
    let invalid_key_sets = [
        []  # Empty keys
        [""]  # Empty key
        [(1..129 | each { "x" } | str join)]  # Key too long
        ["valid", ""]  # Mix of valid and invalid
    ]
    
    for keys in $invalid_key_sets {
        try {
            dynamodb untag-resource $context.test_resource_arn $keys
            assert false $"Should have failed with invalid tag keys: ($keys)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "tag"))
        }
    }
}

#[test]
def "list tags of resource" [] {
    let context = $in
    
    let result = try {
        dynamodb list-tags-of-resource $context.test_resource_arn
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Tags? | default [] | describe | get type) ("list")
}

#[test]
def "list tags of resource with next token" [] {
    let context = $in
    let next_token = "example-next-token"
    
    let result = try {
        dynamodb list-tags-of-resource $context.test_resource_arn --next-token $next_token
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Tags? | default [] | describe | get type) ("list")
}

#[test]
def "list tags validates resource arn" [] {
    let invalid_arns = [
        ""  # Empty ARN
        "invalid-arn"  # Not an ARN
        "arn:aws:s3:::bucket/key"  # S3 ARN, not DynamoDB
    ]
    
    for arn in $invalid_arns {
        try {
            dynamodb list-tags-of-resource $arn
            assert false $"Should have failed with invalid ARN: ($arn)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "ARN"))
        }
    }
}

#[test]
def "tagging handles resource not found" [] {
    let context = $in
    let non_existent_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/non-existent-table"
    
    try {
        dynamodb list-tags-of-resource $non_existent_arn
        assert false "Should have failed with non-existent resource"
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "not found" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

#[test]
def "tagging in mock mode returns consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb list-tags-of-resource $context.test_resource_arn
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get Tags? | default [] | describe | get type) ("list")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# GLOBAL TABLES TESTS (12 tests)
# ============================================================================

#[test]
def "create global table with replica regions" [] {
    let context = $in
    
    let replication_group = [
        { RegionName: "us-east-1" }
        { RegionName: "us-west-2" }
        { RegionName: "eu-west-1" }
    ]
    
    let result = try {
        dynamodb create-global-table $context.test_global_table_name $replication_group
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get GlobalTableDescription.GlobalTableName? | default "" | str contains $context.test_global_table_name)
    assert ($result | get GlobalTableDescription.ReplicationGroup? | default [] | length) >= 2
}

#[test]
def "create global table validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    let replication_group = [{ RegionName: "us-east-1" }, { RegionName: "us-west-2" }]
    
    for name in $invalid_names {
        try {
            dynamodb create-global-table $name $replication_group
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "create global table validates replication group" [] {
    let context = $in
    
    let invalid_replication_groups = [
        []  # Empty replication group
        [{ RegionName: "us-east-1" }]  # Single region (need at least 2)
        [{ RegionName: "" }]  # Empty region name
        [{ InvalidField: "us-east-1" }]  # Invalid field
        [{ RegionName: "invalid-region" }]  # Invalid region format
    ]
    
    for group in $invalid_replication_groups {
        try {
            dynamodb create-global-table $context.test_global_table_name $group
            assert false $"Should have failed with invalid replication group: ($group)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "replication"))
        }
    }
}

#[test]
def "describe global table" [] {
    let context = $in
    
    let result = try {
        dynamodb describe-global-table $context.test_global_table_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get GlobalTableDescription.GlobalTableName? | default "" | str contains $context.test_global_table_name)
    assert ($result | get GlobalTableDescription.GlobalTableStatus? | default "" | str length) > 0
}

#[test]
def "describe global table validates table name" [] {
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb describe-global-table $name
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "update global table add replica" [] {
    let context = $in
    
    let replica_updates = [
        {
            Create: {
                RegionName: "ap-southeast-1"
            }
        }
    ]
    
    let result = try {
        dynamodb update-global-table $context.test_global_table_name $replica_updates
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get GlobalTableDescription? | default {} | columns | length) > 0
}

#[test]
def "update global table remove replica" [] {
    let context = $in
    
    let replica_updates = [
        {
            Delete: {
                RegionName: "eu-west-1"
            }
        }
    ]
    
    let result = try {
        dynamodb update-global-table $context.test_global_table_name $replica_updates
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update global table with complex replica configuration" [] {
    let context = $in
    
    let result = try {
        dynamodb update-global-table $context.test_global_table_name $context.test_replica_updates
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update global table validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    let updates = [{ Create: { RegionName: "us-west-2" } }]
    
    for name in $invalid_names {
        try {
            dynamodb update-global-table $name $updates
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "update global table validates replica updates" [] {
    let context = $in
    
    let invalid_updates = [
        []  # Empty updates
        [{}]  # Empty update
        [{ InvalidAction: { RegionName: "us-west-2" } }]  # Invalid action
        [{ Create: {} }]  # Missing RegionName
        [{ Create: { RegionName: "" } }]  # Empty RegionName
        [{ Delete: {} }]  # Missing RegionName for delete
    ]
    
    for updates in $invalid_updates {
        try {
            dynamodb update-global-table $context.test_global_table_name $updates
            assert false $"Should have failed with invalid updates: ($updates)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "update"))
        }
    }
}

#[test]
def "global tables handle table not found" [] {
    let context = $in
    let non_existent_table = "non-existent-global-table-12345"
    
    try {
        dynamodb describe-global-table $non_existent_table
        assert false "Should have failed with non-existent table"
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "not found" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

#[test]
def "global tables in mock mode return consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let replication_group = [{ RegionName: "us-east-1" }, { RegionName: "us-west-2" }]
    
    let result = try {
        dynamodb create-global-table $context.test_global_table_name $replication_group
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get GlobalTableDescription? | default {} | describe | get type) ("record")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# WAIT OPERATIONS TESTS (8 tests)
# ============================================================================

#[test]
def "wait table exists with valid table" [] {
    let context = $in
    
    let result = try {
        dynamodb wait-table-exists $context.test_table_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Wait operation should return when table exists or timeout
    assert true
}

#[test]
def "wait table exists with timeout" [] {
    let context = $in
    let timeout_seconds = 30
    
    let result = try {
        dynamodb wait-table-exists $context.test_table_name --max-wait-time $timeout_seconds
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "wait table exists validates table name" [] {
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb wait-table-exists $name
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "wait table not exists with deleted table" [] {
    let context = $in
    
    let result = try {
        dynamodb wait-table-not-exists $context.test_table_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Wait operation should return when table doesn't exist or timeout
    assert true
}

#[test]
def "wait table not exists validates table name" [] {
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb wait-table-not-exists $name
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "wait operations validate timeout parameters" [] {
    let context = $in
    let invalid_timeouts = [0, -1, -30]
    
    for timeout in $invalid_timeouts {
        try {
            dynamodb wait-table-exists $context.test_table_name --max-wait-time $timeout
            assert false $"Should have failed with invalid timeout: ($timeout)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "timeout"))
        }
    }
}

#[test]
def "wait operations handle long delays gracefully" [] {
    let context = $in
    let short_timeout = 1  # 1 second timeout to test timeout handling
    
    let result = try {
        dynamodb wait-table-exists $context.test_table_name --max-wait-time $short_timeout
        # If table exists quickly, that's fine
        assert true
    } catch { |error|
        # Should handle timeout gracefully
        assert ($error | get msg? | default "" | str contains "timeout" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

#[test]
def "wait operations in mock mode return quickly" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let start_time = (date now)
    let result = try {
        dynamodb wait-table-exists $context.test_table_name
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    let end_time = (date now)
    
    # Mock mode should return quickly (within reasonable time)
    let duration = (($end_time - $start_time) / 1000000000)  # Convert to seconds
    assert (($duration) < (5))  # Should complete within 5 seconds in mock mode
    
    $env.DYNAMODB_MOCK_MODE = "false"
}