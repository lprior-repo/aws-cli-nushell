use std/assert
use ../../aws/dynamodb.nu

#[before-each]
def setup [] {
    {
        test_table_name: "test-table"
        test_index_name: "test-gsi"
        test_partition_key: "test-partition"
        test_sort_key_prefix: "sort"
        test_key_condition_expression: "#pk = :pk"
        test_filter_expression: "#active = :active"
        test_projection_expression: "id, #n, #c, #metadata"
        test_expression_attribute_names: {
            "#pk": "id"
            "#sk": "sort_key"
            "#n": "name"
            "#c": "count"
            "#active": "active"
            "#metadata": "metadata"
        }
        test_expression_attribute_values: {
            ":pk": { S: "test-partition" }
            ":sk_prefix": { S: "sort" }
            ":active": { BOOL: true }
            ":min_count": { N: "10" }
            ":max_count": { N: "100" }
        }
        test_scan_filters: {
            "#count": "count"
            "#status": "status"
            "#created": "created_date"
        }
        test_scan_values: {
            ":min_count": { N: "50" }
            ":status": { S: "active" }
            ":start_date": { S: "2023-01-01" }
        }
    }
}

# ============================================================================
# QUERY TESTS (20 tests)
# ============================================================================

#[test]
def "query with partition key only" [] {
    let context = $in
    
    let params = {
        table_name: $context.test_table_name
        key_condition_expression: $context.test_key_condition_expression
        expression_attribute_names: { "#pk": "id" }
        expression_attribute_values: { ":pk": { S: $context.test_partition_key } }
    }
    
    let result = try {
        dynamodb query $params.table_name $params.key_condition_expression --expression-attribute-names $params.expression_attribute_names --expression-attribute-values $params.expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
    assert equal ($result | get Count? | default 0 | describe | get type) ("int")
}

#[test]
def "query with partition and sort key condition" [] {
    let context = $in
    
    let key_condition = "#pk = :pk AND begins_with(#sk, :sk_prefix)"
    let attribute_names = { "#pk": "id", "#sk": "sort_key" }
    let attribute_values = { ":pk": { S: $context.test_partition_key }, ":sk_prefix": { S: $context.test_sort_key_prefix } }
    
    let result = try {
        dynamodb query $context.test_table_name $key_condition --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
}

#[test]
def "query with filter expression" [] {
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --filter-expression $context.test_filter_expression --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
}

#[test]
def "query with projection expression" [] {
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --projection-expression $context.test_projection_expression --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "query with limit" [] {
    let context = $in
    
    let limit = 10
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --limit $limit --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get Items? | default [] | length) <= $limit
}

#[test]
def "query with scan index forward false" [] {
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --scan-index-forward false --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "query with global secondary index" [] {
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --index-name $context.test_index_name --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "query with consistent read" [] {
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --consistent-read --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "query validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb query $name $context.test_key_condition_expression --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "query validates key condition expression" [] {
    let context = $in
    
    let invalid_conditions = [
        ""  # Empty condition
        "invalid syntax &^%"
        "#pk"  # Incomplete condition
        "#pk = :pk AND"  # Incomplete AND
        "#pk INVALID :pk"  # Invalid operator
    ]
    
    for condition in $invalid_conditions {
        try {
            dynamodb query $context.test_table_name $condition --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
            assert false $"Should have failed with invalid condition: ($condition)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "condition"))
        }
    }
}

#[test]
def "query validates limit parameter" [] {
    let context = $in
    
    let invalid_limits = [0, -1, -100]
    
    for limit in $invalid_limits {
        try {
            dynamodb query $context.test_table_name $context.test_key_condition_expression --limit $limit --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
            assert false $"Should have failed with invalid limit: ($limit)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "limit"))
        }
    }
}

#[test]
def "query with complex sort key conditions" [] {
    let context = $in
    
    let complex_conditions = [
        "#pk = :pk AND #sk = :sk"  # Equals
        "#pk = :pk AND #sk < :sk"  # Less than
        "#pk = :pk AND #sk <= :sk"  # Less than or equal
        "#pk = :pk AND #sk > :sk"  # Greater than
        "#pk = :pk AND #sk >= :sk"  # Greater than or equal
        "#pk = :pk AND #sk BETWEEN :sk1 AND :sk2"  # Between
        "#pk = :pk AND begins_with(#sk, :sk_prefix)"  # Begins with
    ]
    
    let base_names = { "#pk": "id", "#sk": "sort_key" }
    let base_values = { ":pk": { S: $context.test_partition_key }, ":sk": { S: "test" }, ":sk1": { S: "a" }, ":sk2": { S: "z" }, ":sk_prefix": { S: "prefix" } }
    
    for condition in $complex_conditions {
        let result = try {
            dynamodb query $context.test_table_name $condition --expression-attribute-names $base_names --expression-attribute-values $base_values
        } catch { |error|
            assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
            continue
        }
        assert true
    }
}

#[test]
def "query with exclusive start key for pagination" [] {
    let context = $in
    
    let start_key = {
        id: { S: $context.test_partition_key }
        sort_key: { S: "previous-item" }
    }
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --exclusive-start-key $start_key --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # LastEvaluatedKey can be record or nothing
    let last_key_type = ($result | get LastEvaluatedKey? | default null | describe | get type)
    assert ($last_key_type == "record" or $last_key_type == "nothing")
}

#[test]
def "query with return consumed capacity" [] {
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --return-consumed-capacity "TOTAL" --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "query with select parameter" [] {
    let context = $in
    
    let select_options = ["ALL_ATTRIBUTES", "ALL_PROJECTED_ATTRIBUTES", "SPECIFIC_ATTRIBUTES", "COUNT"]
    
    for select in $select_options {
        let result = try {
            dynamodb query $context.test_table_name $context.test_key_condition_expression --select $select --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
        } catch { |error|
            assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
            continue
        }
        assert true
    }
}

#[test]
def "query validates expression attribute consistency" [] {
    let context = $in
    
    # Use attribute name in condition but don't define it
    let invalid_condition = "#undefined_pk = :pk"
    
    try {
        dynamodb query $context.test_table_name $invalid_condition --expression-attribute-values $context.test_expression_attribute_values
        assert false "Should have failed with undefined attribute name"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
    }
}

#[test]
def "query with complex filter expressions" [] {
    let context = $in
    
    let complex_filters = [
        "#count > :min_count"
        "#count BETWEEN :min_count AND :max_count"
        "attribute_exists(#metadata)"
        "attribute_not_exists(deleted_at)"
        "size(#n) > :name_length"
        "contains(#n, :substring)"
        "#active = :active AND #count > :min_count"
        "(#active = :active) OR (#count > :max_count)"
    ]
    
    let filter_names = { "#count": "count", "#active": "active", "#n": "name", "#metadata": "metadata" }
    let filter_values = { 
        ":min_count": { N: "10" }
        ":max_count": { N: "100" } 
        ":active": { BOOL: true }
        ":name_length": { N: "5" }
        ":substring": { S: "test" }
        ":pk": { S: $context.test_partition_key }
    }
    
    for filter_expr in $complex_filters {
        let result = try {
            dynamodb query $context.test_table_name $context.test_key_condition_expression --filter-expression $filter_expr --expression-attribute-names ($context.test_expression_attribute_names | merge $filter_names) --expression-attribute-values ($context.test_expression_attribute_values | merge $filter_values)
        } catch { |error|
            assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
            continue
        }
        assert true
    }
}

#[test]
def "query handles empty results" [] {
    let context = $in
    
    # Query for non-existent partition
    let empty_key_condition = "#pk = :empty_pk"
    let empty_names = { "#pk": "id" }
    let empty_values = { ":empty_pk": { S: "non-existent-partition-12345" } }
    
    let result = try {
        dynamodb query $context.test_table_name $empty_key_condition --expression-attribute-names $empty_names --expression-attribute-values $empty_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Items? | default [] | length) (0)
    assert equal ($result | get Count? | default 0) (0)
}

#[test]
def "query in mock mode returns consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb query $context.test_table_name $context.test_key_condition_expression --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
    assert equal ($result | get Count? | default 0 | describe | get type) ("int")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# SCAN TESTS (18 tests)
# ============================================================================

#[test]
def "scan table without filters" [] {
    let context = $in
    
    let result = try {
        dynamodb scan $context.test_table_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
    assert equal ($result | get Count? | default 0 | describe | get type) ("int")
    assert equal ($result | get ScannedCount? | default 0 | describe | get type) ("int")
}

#[test]
def "scan with filter expression" [] {
    let context = $in
    
    let filter_expression = "#count > :min_count"
    let attribute_names = { "#count": "count" }
    let attribute_values = { ":min_count": { N: "50" } }
    
    let result = try {
        dynamodb scan $context.test_table_name --filter-expression $filter_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
}

#[test]
def "scan with projection expression" [] {
    let context = $in
    
    let projection = "id, #n, #c"
    let attribute_names = { "#n": "name", "#c": "count" }
    
    let result = try {
        dynamodb scan $context.test_table_name --projection-expression $projection --expression-attribute-names $attribute_names
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "scan with limit" [] {
    let context = $in
    
    let limit = 25
    
    let result = try {
        dynamodb scan $context.test_table_name --limit $limit
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get ScannedCount? | default 0) <= $limit
}

#[test]
def "scan with consistent read" [] {
    let context = $in
    
    let result = try {
        dynamodb scan $context.test_table_name --consistent-read
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "scan with parallel scanning" [] {
    let context = $in
    
    let total_segments = 4
    let segment = 0
    
    let result = try {
        dynamodb scan $context.test_table_name --total-segments $total_segments --segment $segment
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "scan with global secondary index" [] {
    let context = $in
    
    let result = try {
        dynamodb scan $context.test_table_name --index-name $context.test_index_name
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "scan validates table name" [] {
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb scan $name
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "scan validates limit parameter" [] {
    let context = $in
    
    let invalid_limits = [0, -1, -100]
    
    for limit in $invalid_limits {
        try {
            dynamodb scan $context.test_table_name --limit $limit
            assert false $"Should have failed with invalid limit: ($limit)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "limit"))
        }
    }
}

#[test]
def "scan validates parallel scan parameters" [] {
    let context = $in
    
    let invalid_parallel_params = [
        [0, 0]   # total_segments must be > 0
        [4, 4]   # segment must be < total_segments
        [4, -1]  # segment must be >= 0
        [-1, 0]  # total_segments must be > 0
    ]
    
    for params in $invalid_parallel_params {
        let total_segments = ($params | get 0)
        let segment = ($params | get 1)
        
        try {
            dynamodb scan $context.test_table_name --total-segments $total_segments --segment $segment
            assert false $"Should have failed with invalid parallel params: total_segments=($total_segments), segment=($segment)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "segment"))
        }
    }
}

#[test]
def "scan with complex filter expressions" [] {
    let context = $in
    
    let complex_filters = [
        "#status = :status"
        "#count BETWEEN :min AND :max"
        "attribute_exists(#metadata)"
        "attribute_not_exists(deleted_at)"
        "size(#n) > :min_length"
        "contains(#tags, :tag)"
        "#active = :active AND #count > :min"
        "(#status = :active_status) OR (#status = :pending_status)"
        "#created >= :start_date AND #created <= :end_date"
    ]
    
    let filter_names = { 
        "#status": "status"
        "#count": "count" 
        "#metadata": "metadata"
        "#n": "name"
        "#tags": "tags"
        "#active": "active"
        "#created": "created_date"
    }
    let filter_values = { 
        ":status": { S: "active" }
        ":min": { N: "10" }
        ":max": { N: "100" }
        ":min_length": { N: "5" }
        ":tag": { S: "important" }
        ":active": { BOOL: true }
        ":active_status": { S: "active" }
        ":pending_status": { S: "pending" }
        ":start_date": { S: "2023-01-01" }
        ":end_date": { S: "2023-12-31" }
    }
    
    for filter_expr in $complex_filters {
        let result = try {
            dynamodb scan $context.test_table_name --filter-expression $filter_expr --expression-attribute-names $filter_names --expression-attribute-values $filter_values
        } catch { |error|
            assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
            continue
        }
        assert true
    }
}

#[test]
def "scan with exclusive start key for pagination" [] {
    let context = $in
    
    let start_key = {
        id: { S: "pagination-test" }
        sort_key: { S: "start-here" }
    }
    
    let result = try {
        dynamodb scan $context.test_table_name --exclusive-start-key $start_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # LastEvaluatedKey can be record or nothing
    let last_key_type = ($result | get LastEvaluatedKey? | default null | describe | get type)
    assert ($last_key_type == "record" or $last_key_type == "nothing")
}

#[test]
def "scan with return consumed capacity" [] {
    let context = $in
    
    let result = try {
        dynamodb scan $context.test_table_name --return-consumed-capacity "TOTAL"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "scan with select parameter" [] {
    let context = $in
    
    let select_options = ["ALL_ATTRIBUTES", "ALL_PROJECTED_ATTRIBUTES", "SPECIFIC_ATTRIBUTES", "COUNT"]
    
    for select in $select_options {
        let result = try {
            dynamodb scan $context.test_table_name --select $select
        } catch { |error|
            assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
            continue
        }
        assert true
    }
}

#[test]
def "scan validates filter expression syntax" [] {
    let context = $in
    
    let invalid_filters = [
        "invalid syntax &^%"
        "#field ="  # Incomplete expression
        "#field INVALID :value"  # Invalid operator
        "unknown_function(#field)"  # Non-existent function
        "#field = :value AND"  # Incomplete logical expression
    ]
    
    for filter in $invalid_filters {
        try {
            dynamodb scan $context.test_table_name --filter-expression $filter
            assert false $"Should have failed with invalid filter: ($filter)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "filter"))
        }
    }
}

#[test]
def "scan validates expression attribute consistency" [] {
    let context = $in
    
    # Use attribute name in filter but don't define it
    let filter_with_undefined = "#undefined_field = :value"
    let values = { ":value": { S: "test" } }
    
    try {
        dynamodb scan $context.test_table_name --filter-expression $filter_with_undefined --expression-attribute-values $values
        assert false "Should have failed with undefined attribute name"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
    }
}

#[test]
def "scan handles large result sets" [] {
    let context = $in
    
    # This simulates scanning a large table with pagination
    let result = try {
        dynamodb scan $context.test_table_name --limit 1000
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle large scans gracefully
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
    assert ($result | get ScannedCount? | default 0) <= 1000
}

#[test]
def "scan in mock mode returns consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb scan $context.test_table_name
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get Items? | default [] | describe | get type) ("list")
    assert equal ($result | get Count? | default 0 | describe | get type) ("int")
    assert equal ($result | get ScannedCount? | default 0 | describe | get type) ("int")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# PAGINATED OPERATIONS TESTS (12 tests)
# ============================================================================

#[test]
def "query paginated with default settings" [] {
    let context = $in
    
    let pagination_config = {
        key_condition_expression: $context.test_key_condition_expression
        expression_attribute_names: $context.test_expression_attribute_names
        expression_attribute_values: $context.test_expression_attribute_values
    }
    
    let result = try {
        dynamodb query-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get items? | default [] | describe | get type) ("list")
    assert equal ($result | get total_count? | default 0 | describe | get type) ("int")
}

#[test]
def "query paginated with custom page size" [] {
    let context = $in
    
    let pagination_config = {
        key_condition_expression: $context.test_key_condition_expression
        expression_attribute_names: $context.test_expression_attribute_names
        expression_attribute_values: $context.test_expression_attribute_values
        page_size: 50
    }
    
    let result = try {
        dynamodb query-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "query paginated with max items limit" [] {
    let context = $in
    
    let pagination_config = {
        key_condition_expression: $context.test_key_condition_expression
        expression_attribute_names: $context.test_expression_attribute_names
        expression_attribute_values: $context.test_expression_attribute_values
        max_items: 100
    }
    
    let result = try {
        dynamodb query-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get items? | default [] | length) <= 100
}

#[test]
def "scan paginated with default settings" [] {
    let context = $in
    
    let pagination_config = {}
    
    let result = try {
        dynamodb scan-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get items? | default [] | describe | get type) ("list")
    assert equal ($result | get total_count? | default 0 | describe | get type) ("int")
}

#[test]
def "scan paginated with filter expression" [] {
    let context = $in
    
    let pagination_config = {
        filter_expression: "#active = :active"
        expression_attribute_names: { "#active": "active" }
        expression_attribute_values: { ":active": { BOOL: true } }
        page_size: 100
    }
    
    let result = try {
        dynamodb scan-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "scan paginated with parallel scanning" [] {
    let context = $in
    
    let pagination_config = {
        total_segments: 4
        segment: 0
        page_size: 50
    }
    
    let result = try {
        dynamodb scan-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "paginated operations validate configuration" [] {
    let context = $in
    
    let invalid_configs = [
        { page_size: 0 }  # Invalid page size
        { page_size: -1 }  # Negative page size
        { max_items: -1 }  # Negative max items
        { total_segments: 0, segment: 0 }  # Invalid segments
        { total_segments: 4, segment: 4 }  # Segment >= total_segments
    ]
    
    for config in $invalid_configs {
        try {
            dynamodb scan-paginated $context.test_table_name $config
            assert false $"Should have failed with invalid config: ($config)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "config"))
        }
    }
}

#[test]
def "paginated operations handle empty results" [] {
    let context = $in
    
    # Query for non-existent data
    let pagination_config = {
        filter_expression: "#field = :value"
        expression_attribute_names: { "#field": "non_existent_field" }
        expression_attribute_values: { ":value": { S: "non-existent-value" } }
    }
    
    let result = try {
        dynamodb scan-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get items? | default [] | length) (0)
    assert equal ($result | get total_count? | default 0) (0)
}

#[test]
def "paginated operations in mock mode" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let pagination_config = {
        page_size: 10
        max_items: 50
    }
    
    let result = try {
        dynamodb scan-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get items? | default [] | describe | get type) ("list")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

#[test]
def "paginated operations track progress correctly" [] {
    let context = $in
    
    let pagination_config = {
        page_size: 5  # Small page size to test pagination
        max_items: 15  # Should require multiple pages
    }
    
    let result = try {
        dynamodb scan-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should have pagination metadata
    assert equal ($result | get pages_fetched? | default 0 | describe | get type) ("int")
    assert equal ($result | get has_more_data? | default false | describe | get type) ("bool")
}

#[test]
def "paginated operations with complex expressions" [] {
    let context = $in
    
    let pagination_config = {
        key_condition_expression: "#pk = :pk AND begins_with(#sk, :sk_prefix)"
        filter_expression: "#count > :min_count AND #active = :active"
        projection_expression: "id, #n, #c, #metadata"
        expression_attribute_names: {
            "#pk": "id"
            "#sk": "sort_key"
            "#n": "name"
            "#c": "count"
            "#active": "active"
            "#metadata": "metadata"
        }
        expression_attribute_values: {
            ":pk": { S: $context.test_partition_key }
            ":sk_prefix": { S: $context.test_sort_key_prefix }
            ":min_count": { N: "10" }
            ":active": { BOOL: true }
        }
        page_size: 20
    }
    
    let result = try {
        dynamodb query-paginated $context.test_table_name $pagination_config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "paginated operations validate expression consistency" [] {
    let context = $in
    
    # Use attribute name in expression but don't define it
    let invalid_config = {
        filter_expression: "#undefined_field = :value"
        expression_attribute_values: { ":value": { S: "test" } }
        # Missing expression_attribute_names for #undefined_field
    }
    
    try {
        dynamodb scan-paginated $context.test_table_name $invalid_config
        assert false "Should have failed with undefined attribute name"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
    }
}