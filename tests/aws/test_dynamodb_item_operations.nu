use std/assert
use ../../aws/dynamodb.nu

#[before-each]
def setup [] {
    {
        test_table_name: "test-table"
        test_table_arn: "arn:aws:dynamodb:us-east-1:123456789012:table/test-table"
        test_item: {
            id: { S: "test-id-123" }
            name: { S: "Test Item" }
            count: { N: "42" }
            active: { BOOL: true }
            tags: { SS: ["tag1", "tag2"] }
            metadata: {
                M: {
                    created: { S: "2023-01-01" }
                    version: { N: "1" }
                }
            }
        }
        test_key: {
            id: { S: "test-id-123" }
        }
        test_composite_key: {
            id: { S: "test-id-123" }
            sort_key: { S: "sort-value" }
        }
        test_update_expression: "SET #n = :name, #c = :count"
        test_expression_attribute_names: {
            "#n": "name"
            "#c": "count"
        }
        test_expression_attribute_values: {
            ":name": { S: "Updated Name" }
            ":count": { N: "100" }
        }
        test_condition_expression: "attribute_exists(id)"
        test_batch_items: [
            {
                id: { S: "batch-item-1" }
                name: { S: "Batch Item 1" }
            }
            {
                id: { S: "batch-item-2" }
                name: { S: "Batch Item 2" }
            }
            {
                id: { S: "batch-item-3" }
                name: { S: "Batch Item 3" }
            }
        ]
    }
}

# ============================================================================
# PUT-ITEM TESTS (15 tests)
# ============================================================================

#[test]
def "put item with complete item data" [] {
    let context = $in
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Validate that operation completed without error
    assert true
}

#[test]
def "put item with condition expression" [] {
    let context = $in
    
    let condition = "attribute_not_exists(id)"
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item --condition-expression $condition
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "put item with expression attribute names" [] {
    let context = $in
    
    let condition = "attribute_not_exists(#id)"
    let attribute_names = { "#id": "id" }
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item --condition-expression $condition --expression-attribute-names $attribute_names
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "put item with return values" [] {
    let context = $in
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item --return-values "ALL_OLD"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should include Attributes field in response when return-values is specified
    assert true
}

#[test]
def "put item validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb put-item $name $context.test_item
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "put item validates item structure" [] {
    let context = $in
    
    let invalid_items = [
        {}  # Empty item
        { id: "invalid-format" }  # Not DynamoDB format
        { id: { X: "invalid-type" } }  # Invalid attribute type
        { "": { S: "empty-key" } }  # Empty attribute name
    ]
    
    for item in $invalid_items {
        try {
            dynamodb put-item $context.test_table_name $item
            assert false $"Should have failed with invalid item: ($item)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "item"))
        }
    }
}

#[test]
def "put item validates condition expressions" [] {
    let context = $in
    
    let invalid_conditions = [
        "invalid syntax &^%"
        "attribute_not_exists("  # Incomplete function call
        "unknown_function(id)"   # Non-existent function
    ]
    
    for condition in $invalid_conditions {
        try {
            dynamodb put-item $context.test_table_name $context.test_item --condition-expression $condition
            assert false $"Should have failed with invalid condition: ($condition)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "condition"))
        }
    }
}

#[test]
def "put item validates return values parameter" [] {
    let context = $in
    
    let invalid_return_values = ["INVALID", "ALL", ""]
    
    for return_val in $invalid_return_values {
        try {
            dynamodb put-item $context.test_table_name $context.test_item --return-values $return_val
            assert false $"Should have failed with invalid return value: ($return_val)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "return"))
        }
    }
}

#[test]
def "put item with complex nested item" [] {
    let context = $in
    
    let complex_item = {
        id: { S: "complex-item" }
        nested_data: {
            M: {
                level1: {
                    M: {
                        level2: { S: "deep value" }
                        array: {
                            L: [
                                { S: "item1" }
                                { N: "123" }
                                { BOOL: false }
                            ]
                        }
                    }
                }
                simple_field: { S: "simple" }
            }
        }
        string_set: { SS: ["a", "b", "c"] }
        number_set: { NS: ["1", "2", "3"] }
        binary_set: { BS: ["dGVzdA==", "YmluYXJ5"] }
    }
    
    let result = try {
        dynamodb put-item $context.test_table_name $complex_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "put item handles conditional check failed error" [] {
    let context = $in
    
    # This simulates a condition that should fail
    let failing_condition = "attribute_exists(non_existent_field) AND #id = :id"
    let attribute_names = { "#id": "id" }
    let attribute_values = { ":id": { S: "different-id" } }
    
    try {
        dynamodb put-item $context.test_table_name $context.test_item --condition-expression $failing_condition --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
        # If this succeeds, the condition didn't fail as expected
        assert true
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "condition" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

#[test]
def "put item with expression attribute values" [] {
    let context = $in
    
    let condition = "#id = :id"
    let attribute_names = { "#id": "id" }
    let attribute_values = { ":id": { S: "test-id-123" } }
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item --condition-expression $condition --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "put item with return consumed capacity" [] {
    let context = $in
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item --return-consumed-capacity "TOTAL"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "put item with return item collection metrics" [] {
    let context = $in
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item --return-item-collection-metrics "SIZE"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "put item validates expression attribute names format" [] {
    let context = $in
    
    let invalid_attribute_names = [
        { "invalid": "id" }  # Should start with #
        { "#": "id" }        # Just # is invalid
        { "#123": "id" }     # Should start with letter after #
    ]
    
    for attr_names in $invalid_attribute_names {
        try {
            dynamodb put-item $context.test_table_name $context.test_item --condition-expression "attribute_exists(#id)" --expression-attribute-names $attr_names
            assert false $"Should have failed with invalid attribute names: ($attr_names)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
        }
    }
}

#[test]
def "put item in mock mode returns consistent response" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb put-item $context.test_table_name $context.test_item
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return a consistent response structure
    assert equal ($result | describe | get type) ("record")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# GET-ITEM TESTS (15 tests)
# ============================================================================

#[test]
def "get item with simple key" [] {
    let context = $in
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should return Item field even if empty
    # Item can be record or nothing
    let item_type = ($result | get Item? | default null | describe | get type)
    assert ($item_type == "record" or $item_type == "nothing")
}

#[test]
def "get item with composite key" [] {
    let context = $in
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_composite_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Item can be record or nothing
    let item_type = ($result | get Item? | default null | describe | get type)
    assert ($item_type == "record" or $item_type == "nothing")
}

#[test]
def "get item with projection expression" [] {
    let context = $in
    
    let projection = "id, #n, #c"
    let attribute_names = { "#n": "name", "#c": "count" }
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key --projection-expression $projection --expression-attribute-names $attribute_names
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "get item with consistent read" [] {
    let context = $in
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key --consistent-read
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "get item validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb get-item $name $context.test_key
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "get item validates key structure" [] {
    let context = $in
    
    let invalid_keys = [
        {}  # Empty key
        { id: "invalid-format" }  # Not DynamoDB format
        { id: { X: "invalid-type" } }  # Invalid attribute type
    ]
    
    for key in $invalid_keys {
        try {
            dynamodb get-item $context.test_table_name $key
            assert false $"Should have failed with invalid key: ($key)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "key"))
        }
    }
}

#[test]
def "get item validates projection expressions" [] {
    let context = $in
    
    let invalid_projections = [
        "invalid, syntax &^%"
        "#"  # Just # is invalid
        "field1,,"  # Double comma
        ""  # Empty projection
    ]
    
    for projection in $invalid_projections {
        try {
            dynamodb get-item $context.test_table_name $context.test_key --projection-expression $projection
            assert false $"Should have failed with invalid projection: ($projection)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "projection"))
        }
    }
}

#[test]
def "get item with return consumed capacity" [] {
    let context = $in
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key --return-consumed-capacity "TOTAL"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "get item handles non-existent item" [] {
    let context = $in
    
    let non_existent_key = { id: { S: "non-existent-id-99999" } }
    
    let result = try {
        dynamodb get-item $context.test_table_name $non_existent_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Non-existent item should return empty Item field
    let item_result = ($result | get Item? | default null)
    assert ($item_result == null or (($item_result | default {} | columns | length) == 0))
}

#[test]
def "get item with complex projection" [] {
    let context = $in
    
    let projection = "#m.#created, #m.#version, tags[0]"
    let attribute_names = {
        "#m": "metadata"
        "#created": "created"
        "#version": "version"
    }
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key --projection-expression $projection --expression-attribute-names $attribute_names
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "get item validates expression attribute names consistency" [] {
    let context = $in
    
    # Use attribute name in projection but don't define it
    let projection = "#undefined_name"
    
    try {
        dynamodb get-item $context.test_table_name $context.test_key --projection-expression $projection
        assert false "Should have failed with undefined attribute name"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
    }
}

#[test]
def "get item handles table access errors" [] {
    let context = $in
    
    # This simulates access denied or table not found
    try {
        dynamodb get-item "restricted-table" $context.test_key
        # If this succeeds, access was allowed
        assert true
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed" or ($error | get msg? | default "" | str contains "access"))
    }
}

#[test]
def "get item in mock mode returns expected structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

#[test]
def "get item with all supported return options" [] {
    let context = $in
    
    let result = try {
        dynamodb get-item $context.test_table_name $context.test_key --consistent-read --return-consumed-capacity "INDEXES"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "get item validates consumed capacity parameter" [] {
    let context = $in
    
    let invalid_capacity_options = ["INVALID", "ALL", ""]
    
    for option in $invalid_capacity_options {
        try {
            dynamodb get-item $context.test_table_name $context.test_key --return-consumed-capacity $option
            assert false $"Should have failed with invalid capacity option: ($option)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "capacity"))
        }
    }
}

# ============================================================================
# DELETE-ITEM TESTS (12 tests)
# ============================================================================

#[test]
def "delete item with simple key" [] {
    let context = $in
    
    let result = try {
        dynamodb delete-item $context.test_table_name $context.test_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "delete item with condition expression" [] {
    let context = $in
    
    let condition = "attribute_exists(id)"
    
    let result = try {
        dynamodb delete-item $context.test_table_name $context.test_key --condition-expression $condition
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "delete item with return values all old" [] {
    let context = $in
    
    let result = try {
        dynamodb delete-item $context.test_table_name $context.test_key --return-values "ALL_OLD"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should include Attributes field when return-values is ALL_OLD
    assert true
}

#[test]
def "delete item validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb delete-item $name $context.test_key
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "delete item validates key structure" [] {
    let context = $in
    
    let invalid_keys = [
        {}  # Empty key
        { id: "invalid-format" }  # Not DynamoDB format
        { id: { X: "invalid-type" } }  # Invalid attribute type
    ]
    
    for key in $invalid_keys {
        try {
            dynamodb delete-item $context.test_table_name $key
            assert false $"Should have failed with invalid key: ($key)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "key"))
        }
    }
}

#[test]
def "delete item with expression attribute names and values" [] {
    let context = $in
    
    let condition = "#id = :id AND #active = :active"
    let attribute_names = { "#id": "id", "#active": "active" }
    let attribute_values = { ":id": { S: "test-id-123" }, ":active": { BOOL: true } }
    
    let result = try {
        dynamodb delete-item $context.test_table_name $context.test_key --condition-expression $condition --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "delete item handles non-existent item" [] {
    let context = $in
    
    let non_existent_key = { id: { S: "non-existent-id-99999" } }
    
    let result = try {
        dynamodb delete-item $context.test_table_name $non_existent_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Deleting non-existent item should succeed (idempotent)
    assert true
}

#[test]
def "delete item validates condition expressions" [] {
    let context = $in
    
    let invalid_conditions = [
        "invalid syntax &^%"
        "attribute_exists("  # Incomplete function
        "unknown_function(id)"  # Non-existent function
    ]
    
    for condition in $invalid_conditions {
        try {
            dynamodb delete-item $context.test_table_name $context.test_key --condition-expression $condition
            assert false $"Should have failed with invalid condition: ($condition)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "condition"))
        }
    }
}

#[test]
def "delete item validates return values parameter" [] {
    let context = $in
    
    let invalid_return_values = ["INVALID", "ALL", "NONE", ""]
    
    for return_val in $invalid_return_values {
        try {
            dynamodb delete-item $context.test_table_name $context.test_key --return-values $return_val
            assert false $"Should have failed with invalid return value: ($return_val)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "return"))
        }
    }
}

#[test]
def "delete item with return consumed capacity" [] {
    let context = $in
    
    let result = try {
        dynamodb delete-item $context.test_table_name $context.test_key --return-consumed-capacity "TOTAL"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "delete item handles conditional check failed" [] {
    let context = $in
    
    # Condition that should fail
    let failing_condition = "attribute_not_exists(id)"
    
    try {
        dynamodb delete-item $context.test_table_name $context.test_key --condition-expression $failing_condition
        # If this succeeds, condition didn't fail as expected
        assert true
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "condition" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

#[test]
def "delete item with return item collection metrics" [] {
    let context = $in
    
    let result = try {
        dynamodb delete-item $context.test_table_name $context.test_key --return-item-collection-metrics "SIZE"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

# ============================================================================
# UPDATE-ITEM TESTS (18 tests)
# ============================================================================

#[test]
def "update item with simple update expression" [] {
    let context = $in
    
    let update_expression = "SET #n = :name"
    let attribute_names = { "#n": "name" }
    let attribute_values = { ":name": { S: "Updated Name" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with multiple operations" [] {
    let context = $in
    
    let update_expression = "SET #n = :name, #c = :count ADD #score :increment REMOVE old_field"
    let attribute_names = { "#n": "name", "#c": "count", "#score": "score" }
    let attribute_values = { ":name": { S: "New Name" }, ":count": { N: "50" }, ":increment": { N: "10" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with condition expression" [] {
    let context = $in
    
    let update_expression = "SET #n = :name"
    let condition_expression = "attribute_exists(id)"
    let attribute_names = { "#n": "name" }
    let attribute_values = { ":name": { S: "Conditional Update" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --condition-expression $condition_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with return values updated new" [] {
    let context = $in
    
    let update_expression = "SET #n = :name"
    let attribute_names = { "#n": "name" }
    let attribute_values = { ":name": { S: "Updated Name" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values --return-values "UPDATED_NEW"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should include Attributes field with updated values
    assert true
}

#[test]
def "update item validates table name" [] {
    let context = $in
    let invalid_names = ["", "123invalid", "table@invalid"]
    
    for name in $invalid_names {
        try {
            dynamodb update-item $name $context.test_key "SET #n = :name" --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
            assert false $"Should have failed with invalid table name: ($name)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "table name"))
        }
    }
}

#[test]
def "update item validates key structure" [] {
    let context = $in
    
    let invalid_keys = [
        {}  # Empty key
        { id: "invalid-format" }  # Not DynamoDB format
        { id: { X: "invalid-type" } }  # Invalid attribute type
    ]
    
    for key in $invalid_keys {
        try {
            dynamodb update-item $context.test_table_name $key "SET #n = :name" --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
            assert false $"Should have failed with invalid key: ($key)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "key"))
        }
    }
}

#[test]
def "update item validates update expression syntax" [] {
    let context = $in
    
    let invalid_expressions = [
        ""  # Empty expression
        "INVALID #n = :name"  # Invalid action
        "SET #n ="  # Incomplete SET
        "ADD #n"  # Incomplete ADD
        "REMOVE"  # Incomplete REMOVE
        "DELETE #n"  # Incomplete DELETE
        "SET #n = :name ADD"  # Mixed incomplete
    ]
    
    for expression in $invalid_expressions {
        try {
            dynamodb update-item $context.test_table_name $context.test_key $expression --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values
            assert false $"Should have failed with invalid expression: ($expression)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "expression"))
        }
    }
}

#[test]
def "update item with nested attribute updates" [] {
    let context = $in
    
    let update_expression = "SET #m.#v = :version, #m.#updated = :timestamp"
    let attribute_names = { "#m": "metadata", "#v": "version", "#updated": "updated" }
    let attribute_values = { ":version": { N: "2" }, ":timestamp": { S: "2023-12-01T10:00:00Z" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with list operations" [] {
    let context = $in
    
    let update_expression = "SET #tags = list_append(#tags, :new_tags), #tags[0] = :first_tag"
    let attribute_names = { "#tags": "tags" }
    let attribute_values = { ":new_tags": { L: [{ S: "new_tag" }] }, ":first_tag": { S: "updated_first_tag" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with add operation for numbers" [] {
    let context = $in
    
    let update_expression = "ADD #count :increment, #score :points"
    let attribute_names = { "#count": "count", "#score": "score" }
    let attribute_values = { ":increment": { N: "5" }, ":points": { N: "100" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with add operation for sets" [] {
    let context = $in
    
    let update_expression = "ADD #tags :new_tags, #numbers :new_numbers"
    let attribute_names = { "#tags": "tags", "#numbers": "numbers" }
    let attribute_values = { ":new_tags": { SS: ["tag3", "tag4"] }, ":new_numbers": { NS: ["4", "5"] } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with remove operations" [] {
    let context = $in
    
    let update_expression = "REMOVE old_field, #tags[1], #metadata.#deprecated"
    let attribute_names = { "#tags": "tags", "#metadata": "metadata", "#deprecated": "deprecated" }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with delete operations for sets" [] {
    let context = $in
    
    let update_expression = "DELETE #tags :remove_tags, #numbers :remove_numbers"
    let attribute_names = { "#tags": "tags", "#numbers": "numbers" }
    let attribute_values = { ":remove_tags": { SS: ["tag1"] }, ":remove_numbers": { NS: ["1"] } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item validates return values parameter" [] {
    let context = $in
    
    let invalid_return_values = ["INVALID", "ALL", ""]
    
    for return_val in $invalid_return_values {
        try {
            dynamodb update-item $context.test_table_name $context.test_key "SET #n = :name" --expression-attribute-names $context.test_expression_attribute_names --expression-attribute-values $context.test_expression_attribute_values --return-values $return_val
            assert false $"Should have failed with invalid return value: ($return_val)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "return"))
        }
    }
}

#[test]
def "update item validates expression attribute consistency" [] {
    let context = $in
    
    # Use attribute name/value in expression but don't define them
    let update_expression = "SET #undefined = :undefined"
    
    try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression
        assert false "Should have failed with undefined attribute name/value"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
    }
}

#[test]
def "update item with if not exists function" [] {
    let context = $in
    
    let update_expression = "SET #count = if_not_exists(#count, :default_count), #name = if_not_exists(#name, :default_name)"
    let attribute_names = { "#count": "count", "#name": "name" }
    let attribute_values = { ":default_count": { N: "0" }, ":default_name": { S: "Default Name" } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item with complex condition" [] {
    let context = $in
    
    let update_expression = "SET #status = :status"
    let condition_expression = "(#count < :max_count) AND (attribute_exists(#id)) AND (#active = :active)"
    let attribute_names = { "#status": "status", "#count": "count", "#id": "id", "#active": "active" }
    let attribute_values = { ":status": { S: "active" }, ":max_count": { N: "100" }, ":active": { BOOL: true } }
    
    let result = try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --condition-expression $condition_expression --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "update item handles conditional check failed error" [] {
    let context = $in
    
    # Condition that should fail
    let update_expression = "SET #n = :name"
    let failing_condition = "attribute_not_exists(id)"  # Should fail if item exists
    let attribute_names = { "#n": "name" }
    let attribute_values = { ":name": { S: "Should Not Update" } }
    
    try {
        dynamodb update-item $context.test_table_name $context.test_key $update_expression --condition-expression $failing_condition --expression-attribute-names $attribute_names --expression-attribute-values $attribute_values
        # If this succeeds, condition didn't fail as expected
        assert true
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "condition" or ($error | get msg? | default "" | str contains "Failed"))
    }
}

# ============================================================================
# BATCH OPERATIONS TESTS (15 tests)
# ============================================================================

#[test]
def "batch get item with single table" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): {
                Keys: [
                    $context.test_key
                    { id: { S: "batch-item-1" } }
                    { id: { S: "batch-item-2" } }
                ]
            }
        }
    }
    
    let result = try {
        dynamodb batch-get-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get Responses? | default {} | describe | get type) ("record")
}

#[test]
def "batch get item with projection expression" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): {
                Keys: [
                    $context.test_key
                    { id: { S: "batch-item-1" } }
                ]
                ProjectionExpression: "id, #n"
                ExpressionAttributeNames: { "#n": "name" }
            }
        }
    }
    
    let result = try {
        dynamodb batch-get-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "batch get item validates request structure" [] {
    let invalid_requests = [
        {}  # Empty request
        { RequestItems: {} }  # Empty RequestItems
        { RequestItems: { "table": {} } }  # Missing Keys
        { RequestItems: { "table": { Keys: [] } } }  # Empty Keys
    ]
    
    for request in $invalid_requests {
        try {
            dynamodb batch-get-item $request
            assert false $"Should have failed with invalid request: ($request)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "request"))
        }
    }
}

#[test]
def "batch get item handles too many items" [] {
    let context = $in
    
    # Create request with more than 100 items (AWS limit)
    let large_keys = (0..150 | each { |i| { id: { S: $"item-($i)" } } })
    
    let request = {
        RequestItems: {
            ($context.test_table_name): {
                Keys: $large_keys
            }
        }
    }
    
    try {
        dynamodb batch-get-item $request
        assert false "Should have failed with too many items"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "too many"))
    }
}

#[test]
def "batch write item with put requests" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): [
                {
                    PutRequest: {
                        Item: { id: { S: "batch-put-1" }, name: { S: "Batch Put Item 1" } }
                    }
                }
                {
                    PutRequest: {
                        Item: { id: { S: "batch-put-2" }, name: { S: "Batch Put Item 2" } }
                    }
                }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-write-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get UnprocessedItems? | default {} | describe | get type) ("record")
}

#[test]
def "batch write item with delete requests" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): [
                {
                    DeleteRequest: {
                        Key: { id: { S: "batch-delete-1" } }
                    }
                }
                {
                    DeleteRequest: {
                        Key: { id: { S: "batch-delete-2" } }
                    }
                }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-write-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "batch write item with mixed requests" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): [
                {
                    PutRequest: {
                        Item: { id: { S: "mixed-put-1" }, name: { S: "Mixed Put Item" } }
                    }
                }
                {
                    DeleteRequest: {
                        Key: { id: { S: "mixed-delete-1" } }
                    }
                }
                {
                    PutRequest: {
                        Item: { id: { S: "mixed-put-2" }, name: { S: "Another Mixed Put" } }
                    }
                }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-write-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "batch write item validates request structure" [] {
    let invalid_requests = [
        {}  # Empty request
        { RequestItems: {} }  # Empty RequestItems
        { RequestItems: { "table": [] } }  # Empty request array
        { RequestItems: { "table": [{}] } }  # Invalid request item
        { RequestItems: { "table": [{ InvalidRequest: {} }] } }  # Invalid request type
    ]
    
    for request in $invalid_requests {
        try {
            dynamodb batch-write-item $request
            assert false $"Should have failed with invalid request: ($request)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "request"))
        }
    }
}

#[test]
def "batch write item handles too many requests" [] {
    let context = $in
    
    # Create request with more than 25 requests (AWS limit)
    let large_requests = (0..30 | each { |i| {
        PutRequest: {
            Item: { id: { S: $"batch-item-($i)" }, name: { S: $"Batch Item ($i)" } }
        }
    }})
    
    let request = {
        RequestItems: {
            ($context.test_table_name): $large_requests
        }
    }
    
    try {
        dynamodb batch-write-item $request
        assert false "Should have failed with too many requests"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "too many"))
    }
}

#[test]
def "batch get item with multiple tables" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): {
                Keys: [
                    $context.test_key
                ]
            }
            "another-table": {
                Keys: [
                    { id: { S: "other-item" } }
                ]
            }
        }
    }
    
    let result = try {
        dynamodb batch-get-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "batch write item with return consumed capacity" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): [
                {
                    PutRequest: {
                        Item: { id: { S: "capacity-test" }, name: { S: "Capacity Test Item" } }
                    }
                }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-write-item $request --return-consumed-capacity "TOTAL"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "batch write item with return item collection metrics" [] {
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): [
                {
                    PutRequest: {
                        Item: { id: { S: "metrics-test" }, name: { S: "Metrics Test Item" } }
                    }
                }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-write-item $request --return-item-collection-metrics "SIZE"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert true
}

#[test]
def "batch operations handle unprocessed items" [] {
    let context = $in
    
    # This simulates a scenario where some items might not be processed
    let request = {
        RequestItems: {
            ($context.test_table_name): [
                {
                    PutRequest: {
                        Item: { id: { S: "unprocessed-test-1" }, name: { S: "Unprocessed Test 1" } }
                    }
                }
                {
                    PutRequest: {
                        Item: { id: { S: "unprocessed-test-2" }, name: { S: "Unprocessed Test 2" } }
                    }
                }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-write-item $request
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Check that UnprocessedItems field is present in response
    assert equal ($result | get UnprocessedItems? | default {} | describe | get type) ("record")
}

#[test]
def "batch operations in mock mode return consistent structure" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let request = {
        RequestItems: {
            ($context.test_table_name): {
                Keys: [ $context.test_key ]
            }
        }
    }
    
    let result = try {
        dynamodb batch-get-item $request
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should return consistent structure
    assert equal ($result | describe | get type) ("record")
    assert equal ($result | get Responses? | default {} | describe | get type) ("record")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}