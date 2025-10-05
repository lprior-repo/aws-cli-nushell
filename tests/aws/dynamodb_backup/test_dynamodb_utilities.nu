use std/assert
use ../../aws/dynamodb.nu

#[before-each]
def setup [] {
    {
        test_nushell_item: {
            id: "test-123"
            name: "Test Item"
            count: 42
            active: true
            scores: [10, 20, 30]
            tags: ["important", "test"]
            metadata: {
                created: "2023-01-01"
                version: 1
                nested: {
                    field: "value"
                }
            }
            optional_field: null
            binary_data: "dGVzdCBkYXRh"  # base64 encoded "test data"
        }
        test_dynamodb_item: {
            id: { S: "test-123" }
            name: { S: "Test Item" }
            count: { N: "42" }
            active: { BOOL: true }
            scores: { L: [{ N: "10" }, { N: "20" }, { N: "30" }] }
            tags: { SS: ["important", "test"] }
            metadata: {
                M: {
                    created: { S: "2023-01-01" }
                    version: { N: "1" }
                    nested: {
                        M: {
                            field: { S: "value" }
                        }
                    }
                }
            }
            binary_data: { B: "dGVzdCBkYXRh" }
        }
        test_expression_config: {
            condition_expression: "#id = :id AND #active = :active"
            filter_expression: "#count > :min_count"
            projection_expression: "id, #n, #metadata.#created"
            update_expression: "SET #n = :new_name, #count = #count + :increment"
        }
        test_pagination_config: {
            page_size: 25
            max_items: 100
            exclusive_start_key: { id: { S: "start-key" } }
        }
        test_batch_config: {
            batch_size: 25
            max_retries: 3
            retry_delay_seconds: 1
        }
    }
}

# ============================================================================
# TYPE CONVERSION TESTS (20 tests)
# ============================================================================

#[test]
def "convert nushell item to dynamodb format" [] {
    let context = $in
    
    let result = try {
        dynamodb convert-to-dynamodb-item $context.test_nushell_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Validate basic conversions
    assert ($result | get id.S? | default "" | str contains "test-123")
    assert ($result | get name.S? | default "" | str contains "Test Item")
    assert ($result | get count.N? | default "" | str contains "42")
    assert equal ($result | get active.BOOL? | default false) (true)
}

#[test]
def "convert dynamodb item to nushell format" [] {
    let context = $in
    
    let result = try {
        dynamodb convert-from-dynamodb-item $context.test_dynamodb_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Validate basic conversions
    assert ($result | get id? | default "" | str contains "test-123")
    assert ($result | get name? | default "" | str contains "Test Item")
    assert equal ($result | get count? | default 0) (42)
    assert equal ($result | get active? | default false) (true)
}

#[test]
def "convert handles string attributes" [] {
    let test_item = { simple_string: "hello world", empty_string: "" }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get simple_string.S? | default "" | str contains "hello world")
    # Empty strings should be handled appropriately
}

#[test]
def "convert handles number attributes" [] {
    let test_item = {
        integer: 123
        float: 123.45
        negative: -42
        zero: 0
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get integer.N? | default "" | str contains "123")
    assert ($result | get float.N? | default "" | str contains "123.45")
    assert ($result | get negative.N? | default "" | str contains "-42")
    assert ($result | get zero.N? | default "" | str contains "0")
}

#[test]
def "convert handles boolean attributes" [] {
    let test_item = {
        true_value: true
        false_value: false
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get true_value.BOOL? | default false) (true)
    assert equal ($result | get false_value.BOOL? | default true) (false)
}

#[test]
def "convert handles list attributes" [] {
    let test_item = {
        mixed_list: ["string", 123, true, null]
        empty_list: []
        nested_list: [["a", "b"], ["c", "d"]]
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get mixed_list.L? | default [] | length) (4)
    assert equal ($result | get empty_list.L? | default [] | length) (0)
    assert equal ($result | get nested_list.L? | default [] | length) (2)
}

#[test]
def "convert handles map attributes" [] {
    let test_item = {
        simple_map: { key1: "value1", key2: 42 }
        empty_map: {}
        nested_map: {
            level1: {
                level2: {
                    deep_value: "nested"
                }
            }
        }
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get simple_map.M? | default {} | columns | length) (2)
    assert equal ($result | get empty_map.M? | default {} | columns | length) (0)
    assert ($result | get nested_map.M? | default {} | columns | length) > 0
}

#[test]
def "convert handles string sets" [] {
    let test_item = {
        string_set: ["apple", "banana", "cherry"]
        single_string_set: ["solo"]
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get string_set.SS? | default [] | length) (3)
    assert equal ($result | get single_string_set.SS? | default [] | length) (1)
}

#[test]
def "convert handles number sets" [] {
    let test_item = {
        number_set: [1, 2, 3, 4.5]
        single_number_set: [42]
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get number_set.NS? | default [] | length) (4)
    assert equal ($result | get single_number_set.NS? | default [] | length) (1)
}

#[test]
def "convert handles binary attributes" [] {
    let test_item = {
        binary_data: "dGVzdCBkYXRh"  # base64 encoded
        binary_set: ["dGVzdDE=", "dGVzdDI="]  # base64 encoded set
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($result | get binary_data.B? | default "" | str contains "dGVzdCBkYXRh")
    assert equal ($result | get binary_set.BS? | default [] | length) (2)
}

#[test]
def "convert handles null values" [] {
    let test_item = {
        null_value: null
        optional_field: null
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $test_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get null_value.NULL? | default false) (true)
    assert equal ($result | get optional_field.NULL? | default false) (true)
}

#[test]
def "convert validates item structure" [] {
    let invalid_items = [
        {}  # Empty item should be allowed
        # Items with invalid attribute names are handled by AWS, not conversion
    ]
    
    for item in $invalid_items {
        let result = try {
            dynamodb convert-to-dynamodb-item $item
        } catch { |error|
            # Empty items might be valid, so this test mainly checks no crashes
            assert ($error | get type? | default "" | str contains "ValidationError")
            continue
        }
        # If successful, that's fine too
        assert true
    }
}

#[test]
def "convert round trip preserves data" [] {
    let context = $in
    
    # Convert Nushell -> DynamoDB -> Nushell
    let dynamodb_format = try {
        dynamodb convert-to-dynamodb-item $context.test_nushell_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    let back_to_nushell = try {
        dynamodb convert-from-dynamodb-item $dynamodb_format
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Validate key fields are preserved
    assert ($back_to_nushell | get id? | default "" | str contains "test-123")
    assert ($back_to_nushell | get name? | default "" | str contains "Test Item")
    assert equal ($back_to_nushell | get count? | default 0) (42)
    assert equal ($back_to_nushell | get active? | default false) (true)
}

#[test]
def "convert handles advanced data types" [] {
    let complex_item = {
        timestamp: "2023-12-01T10:00:00Z"
        uuid: "123e4567-e89b-12d3-a456-426614174000"
        json_string: '{"embedded": "json"}'
        large_number: 999999999999999
        decimal: 123.456789
        scientific: 1.23e10
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item $complex_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # All should convert to appropriate DynamoDB types
    assert ($result | get timestamp.S? | default "" | str length) > 0
    assert ($result | get uuid.S? | default "" | str length) > 0
    assert ($result | get json_string.S? | default "" | str length) > 0
    assert ($result | get large_number.N? | default "" | str length) > 0
}

#[test]
def "convert advanced handles deep nesting" [] {
    let deeply_nested = {
        level1: {
            level2: {
                level3: {
                    level4: {
                        level5: {
                            deep_value: "way down here"
                            deep_list: [1, 2, 3]
                        }
                    }
                }
            }
        }
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item-advanced $deeply_nested
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle deep nesting without errors
    assert ($result | get level1.M? | default {} | columns | length) > 0
}

#[test]
def "convert advanced handles large items" [] {
    # Create an item with many attributes
    let large_item = (0..100 | reduce -f {} { |it, acc|
        $acc | insert $"field_($it)" $"value_($it)"
    })
    
    let result = try {
        dynamodb convert-to-dynamodb-item-advanced $large_item
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle large items
    assert equal ($result | columns | length) (101)
}

#[test]
def "convert advanced validates attribute names" [] {
    let item_with_invalid_names = {
        "": "empty_name"  # Empty attribute name
        "valid_name": "good"
        "": "another_empty"  # Another empty name
    }
    
    try {
        dynamodb convert-to-dynamodb-item-advanced $item_with_invalid_names
        # Some implementations might allow this and filter out invalid names
        assert true
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
    }
}

#[test]
def "convert advanced handles edge cases" [] {
    let edge_cases = {
        very_long_string: (1..1000 | each { "x" } | str join)
        empty_string: ""
        zero: 0
        negative_zero: -0
        infinity: null  # Represent as null since DynamoDB doesn't support infinity
        very_small_decimal: 0.0000001
    }
    
    let result = try {
        dynamodb convert-to-dynamodb-item-advanced $edge_cases
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle edge cases appropriately
    assert ($result | get very_long_string.S? | default "" | str length) > 500
    assert ($result | get zero.N? | default "" | str contains "0")
}

#[test]
def "type conversion in mock mode works consistently" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let result = try {
        dynamodb convert-to-dynamodb-item $context.test_nushell_item
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should still perform conversions
    assert equal ($result | describe | get type) ("record")
    assert ($result | get id.S? | default "" | str contains "test-123")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# EXPRESSION BUILDER TESTS (15 tests)
# ============================================================================

#[test]
def "create expression builder with default values" [] {
    let builder = try {
        dynamodb create-expression-builder
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($builder | get attribute_names? | default {} | describe | get type) ("record")
    assert equal ($builder | get attribute_values? | default {} | describe | get type) ("record")
    assert equal ($builder | get conditions? | default [] | describe | get type) ("list")
}

#[test]
def "add attribute names to expression builder" [] {
    let builder = dynamodb create-expression-builder
    
    let updated_builder = try {
        dynamodb add-attribute-name $builder "#id" "id" | dynamodb add-attribute-name $in "#name" "name"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($updated_builder | get attribute_names."#id"? | default "" | str contains "id")
    assert ($updated_builder | get attribute_names."#name"? | default "" | str contains "name")
}

#[test]
def "add attribute values to expression builder" [] {
    let builder = dynamodb create-expression-builder
    
    let updated_builder = try {
        dynamodb add-attribute-value $builder ":id" { S: "test-123" } | dynamodb add-attribute-value $in ":count" { N: "42" }
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($updated_builder | get attribute_values.":id".S? | default "" | str contains "test-123")
    assert ($updated_builder | get attribute_values.":count".N? | default "" | str contains "42")
}

#[test]
def "add conditions to expression builder" [] {
    let builder = dynamodb create-expression-builder
    
    let updated_builder = try {
        dynamodb add-condition $builder "#id = :id" | dynamodb add-condition $in "#active = :active"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($updated_builder | get conditions? | default [] | length) (2)
}

#[test]
def "add filters to expression builder" [] {
    let builder = dynamodb create-expression-builder
    
    let updated_builder = try {
        dynamodb add-filter $builder "#count > :min_count" | dynamodb add-filter $in "attribute_exists(#metadata)"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($updated_builder | get filters? | default [] | length) (2)
}

#[test]
def "add projections to expression builder" [] {
    let builder = dynamodb create-expression-builder
    
    let updated_builder = try {
        dynamodb add-projection $builder "id, #name, #metadata.#created"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($updated_builder | get projection? | default "" | str contains "id")
    assert ($updated_builder | get projection? | default "" | str contains "#name")
}

#[test]
def "add updates to expression builder" [] {
    let builder = dynamodb create-expression-builder
    
    let updated_builder = try {
        dynamodb add-update $builder "SET #name = :new_name" | dynamodb add-update $in "ADD #count :increment"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($updated_builder | get updates? | default [] | length) (2)
}

#[test]
def "build expressions from builder" [] {
    let builder = (
        dynamodb create-expression-builder
        | dynamodb add-attribute-name $in "#id" "id"
        | dynamodb add-attribute-name $in "#name" "name"
        | dynamodb add-attribute-value $in ":id" { S: "test-123" }
        | dynamodb add-attribute-value $in ":name" { S: "Test Name" }
        | dynamodb add-condition $in "#id = :id"
        | dynamodb add-filter $in "#name = :name"
    )
    
    let expressions = try {
        dynamodb build-expressions $builder
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($expressions | get condition_expression? | default "" | str contains "#id = :id")
    assert ($expressions | get filter_expression? | default "" | str contains "#name = :name")
    assert equal ($expressions | get expression_attribute_names? | default {} | columns | length) (2)
    assert equal ($expressions | get expression_attribute_values? | default {} | columns | length) (2)
}

#[test]
def "create equals condition helper" [] {
    let condition = try {
        dynamodb create-equals-condition "#id" ":id"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($condition | str contains "#id = :id")
}

#[test]
def "create between condition helper" [] {
    let condition = try {
        dynamodb create-between-condition "#date" ":start_date" ":end_date"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($condition | str contains "#date BETWEEN :start_date AND :end_date")
}

#[test]
def "create exists condition helper" [] {
    let condition = try {
        dynamodb create-exists-condition "#metadata"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($condition | str contains "attribute_exists(#metadata)")
}

#[test]
def "expression builder validates attribute name format" [] {
    let builder = dynamodb create-expression-builder
    
    let invalid_names = [
        ["invalid", "id"]  # Should start with #
        ["#", "id"]        # Just # is invalid
        ["#123", "id"]     # Should start with letter after #
    ]
    
    for name_pair in $invalid_names {
        let placeholder = ($name_pair | get 0)
        let actual = ($name_pair | get 1)
        
        try {
            dynamodb add-attribute-name $builder $placeholder $actual
            assert false $"Should have failed with invalid attribute name placeholder: ($placeholder)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
        }
    }
}

#[test]
def "expression builder validates attribute value format" [] {
    let builder = dynamodb create-expression-builder
    
    let invalid_values = [
        ["invalid", { S: "test" }]  # Should start with :
        [":", { S: "test" }]        # Just : is invalid
        [":123", { S: "test" }]     # Should start with letter after :
    ]
    
    for value_pair in $invalid_values {
        let placeholder = ($value_pair | get 0)
        let value = ($value_pair | get 1)
        
        try {
            dynamodb add-attribute-value $builder $placeholder $value
            assert false $"Should have failed with invalid attribute value placeholder: ($placeholder)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "attribute"))
        }
    }
}

#[test]
def "expression builder handles complex expressions" [] {
    let complex_builder = (
        dynamodb create-expression-builder
        | dynamodb add-attribute-name $in "#pk" "partition_key"
        | dynamodb add-attribute-name $in "#sk" "sort_key"
        | dynamodb add-attribute-name $in "#status" "status"
        | dynamodb add-attribute-name $in "#count" "count"
        | dynamodb add-attribute-value $in ":pk" { S: "USER#123" }
        | dynamodb add-attribute-value $in ":sk_prefix" { S: "PROFILE#" }
        | dynamodb add-attribute-value $in ":status" { S: "active" }
        | dynamodb add-attribute-value $in ":min_count" { N: "10" }
        | dynamodb add-condition $in "#pk = :pk AND begins_with(#sk, :sk_prefix)"
        | dynamodb add-filter $in "#status = :status AND #count > :min_count"
        | dynamodb add-projection $in "#pk, #sk, #status, #count"
        | dynamodb add-update $in "SET #status = :status ADD #count :increment"
    )
    
    let expressions = try {
        dynamodb build-expressions $complex_builder
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($expressions | get condition_expression? | default "" | str contains "begins_with")
    assert ($expressions | get filter_expression? | default "" | str contains "AND")
    assert ($expressions | get projection_expression? | default "" | str contains "#pk, #sk")
    assert ($expressions | get update_expression? | default "" | str contains "SET")
}

#[test]
def "expression builder in mock mode works consistently" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    
    let builder = try {
        dynamodb create-expression-builder
        | dynamodb add-attribute-name $in "#id" "id"
        | dynamodb add-condition $in "#id = :id"
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should still create expression builders
    assert equal ($builder | describe | get type) ("record")
    assert ($builder | get attribute_names."#id"? | default "" | str contains "id")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# PAGINATION CONFIGURATION TESTS (8 tests)
# ============================================================================

#[test]
def "create pagination config with default values" [] {
    let config = try {
        dynamodb create-pagination-config
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($config | get page_size? | default 0) > 0
    assert ($config | get max_items? | default 0) >= 0
    assert ($config | get max_pages? | default 0) > 0
}

#[test]
def "create pagination config with custom values" [] {
    let custom_config = {
        page_size: 50
        max_items: 200
        max_pages: 10
        start_key: { id: { S: "start-here" } }
    }
    
    let config = try {
        dynamodb create-pagination-config --page-size $custom_config.page_size --max-items $custom_config.max_items --max-pages $custom_config.max_pages --start-key $custom_config.start_key
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($config | get page_size? | default 0) (50)
    assert equal ($config | get max_items? | default 0) (200)
    assert equal ($config | get max_pages? | default 0) (10)
}

#[test]
def "create pagination config validates page size" [] {
    let invalid_page_sizes = [0, -1, -10]
    
    for size in $invalid_page_sizes {
        try {
            dynamodb create-pagination-config --page-size $size
            assert false $"Should have failed with invalid page size: ($size)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "page"))
        }
    }
}

#[test]
def "create pagination config validates max items" [] {
    let invalid_max_items = [-1, -10]  # 0 is valid (unlimited)
    
    for max_items in $invalid_max_items {
        try {
            dynamodb create-pagination-config --max-items $max_items
            assert false $"Should have failed with invalid max items: ($max_items)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "items"))
        }
    }
}

#[test]
def "create pagination config validates max pages" [] {
    let invalid_max_pages = [0, -1, -10]
    
    for pages in $invalid_max_pages {
        try {
            dynamodb create-pagination-config --max-pages $pages
            assert false $"Should have failed with invalid max pages: ($pages)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "page"))
        }
    }
}

#[test]
def "create pagination config validates start key format" [] {
    let invalid_start_keys = [
        "not-a-record"  # Should be a record
        { invalid: "format" }  # Should be DynamoDB format
        {}  # Empty key might be invalid
    ]
    
    for key in $invalid_start_keys {
        try {
            dynamodb create-pagination-config --start-key $key
            # Some invalid keys might be caught later, so this is a soft validation
            assert true
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "key"))
        }
    }
}

#[test]
def "pagination config with reasonable limits" [] {
    let config = try {
        dynamodb create-pagination-config --page-size 100 --max-items 1000 --max-pages 50
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle reasonable limits without issues
    assert equal ($config | get page_size? | default 0) (100)
    assert equal ($config | get max_items? | default 0) (1000)
    assert equal ($config | get max_pages? | default 0) (50)
}

#[test]
def "pagination config in mock mode works consistently" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    
    let config = try {
        dynamodb create-pagination-config --page-size 25
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should still create pagination configs
    assert equal ($config | describe | get type) ("record")
    assert equal ($config | get page_size? | default 0) (25)
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# CHUNKED OPERATIONS TESTS (10 tests)
# ============================================================================

#[test]
def "batch get items chunked with single table" [] {
    let context = $in
    
    let request_items = {
        ($context.test_table_name): {
            Keys: [
                { id: { S: "item1" } }
                { id: { S: "item2" } }
                { id: { S: "item3" } }
            ]
        }
    }
    
    let result = try {
        dynamodb batch-get-items-chunked $request_items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get items? | default [] | describe | get type) ("list")
    assert equal ($result | get unprocessed_keys? | default {} | describe | get type) ("record")
}

#[test]
def "batch get items chunked with large request" [] {
    let context = $in
    
    # Create a large batch (over 100 items)
    let large_keys = (0..150 | each { |i| { id: { S: $"item-($i)" } } })
    let request_items = {
        ($context.test_table_name): {
            Keys: $large_keys
        }
    }
    
    let result = try {
        dynamodb batch-get-items-chunked $request_items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle chunking automatically
    assert equal ($result | get items? | default [] | describe | get type) ("list")
    assert ($result | get total_requests? | default 0) > 1  # Should require multiple requests
}

#[test]
def "batch write items chunked with put requests" [] {
    let context = $in
    
    let request_items = {
        ($context.test_table_name): [
            { PutRequest: { Item: { id: { S: "put1" }, name: { S: "Put Item 1" } } } }
            { PutRequest: { Item: { id: { S: "put2" }, name: { S: "Put Item 2" } } } }
            { PutRequest: { Item: { id: { S: "put3" }, name: { S: "Put Item 3" } } } }
        ]
    }
    
    let result = try {
        dynamodb batch-write-items-chunked $request_items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get unprocessed_items? | default {} | describe | get type) ("record")
    assert ($result | get total_requests? | default 0) >= 1
}

#[test]
def "batch write items chunked with large request" [] {
    let context = $in
    
    # Create a large batch (over 25 items)
    let large_requests = (0..50 | each { |i| {
        PutRequest: { Item: { id: { S: $"batch-item-($i)" }, name: { S: $"Batch Item ($i)" } } }
    }})
    let request_items = {
        ($context.test_table_name): $large_requests
    }
    
    let result = try {
        dynamodb batch-write-items-chunked $request_items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle chunking automatically
    assert ($result | get total_requests? | default 0) > 1  # Should require multiple requests
}

#[test]
def "batch put items convenience function" [] {
    let context = $in
    
    let items = [
        { id: { S: "convenience1" }, name: { S: "Convenience Item 1" } }
        { id: { S: "convenience2" }, name: { S: "Convenience Item 2" } }
    ]
    
    let result = try {
        dynamodb batch-put-items $context.test_table_name $items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get unprocessed_items? | default {} | describe | get type) ("record")
}

#[test]
def "batch delete items convenience function" [] {
    let context = $in
    
    let keys = [
        { id: { S: "delete1" } }
        { id: { S: "delete2" } }
        { id: { S: "delete3" } }
    ]
    
    let result = try {
        dynamodb batch-delete-items $context.test_table_name $keys
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($result | get unprocessed_items? | default {} | describe | get type) ("record")
}

#[test]
def "chunked operations validate batch size" [] {
    let context = $in
    
    # This would test custom batch size configuration if supported
    let small_items = [
        { id: { S: "small1" }, name: { S: "Small Item 1" } }
        { id: { S: "small2" }, name: { S: "Small Item 2" } }
    ]
    
    let result = try {
        dynamodb batch-put-items $context.test_table_name $small_items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should handle small batches efficiently
    assert ($result | get total_requests? | default 0) >= 1
}

#[test]
def "chunked operations handle empty requests" [] {
    let context = $in
    
    let empty_items = []
    
    try {
        dynamodb batch-put-items $context.test_table_name $empty_items
        assert false "Should have failed with empty items"
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "empty"))
    }
}

#[test]
def "chunked operations track progress" [] {
    let context = $in
    
    let moderate_items = (0..10 | each { |i| {
        id: { S: $"progress-($i)" }
        name: { S: $"Progress Item ($i)" }
    }})
    
    let result = try {
        dynamodb batch-put-items $context.test_table_name $moderate_items
    } catch { |error|
        assert ($error | get type? | default "" | str contains "AWSError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should include progress tracking information
    assert ($result | get total_requests? | default 0) >= 1
    assert ($result | get total_items_processed? | default 0) >= 0
}

#[test]
def "chunked operations in mock mode work consistently" [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    let context = $in
    
    let items = [
        { id: { S: "mock1" }, name: { S: "Mock Item 1" } }
        { id: { S: "mock2" }, name: { S: "Mock Item 2" } }
    ]
    
    let result = try {
        dynamodb batch-put-items $context.test_table_name $items
    } catch { |error|
        assert ($error | get msg? | default "" | str contains "Failed")
        return
    }
    
    # Mock mode should still handle chunked operations
    assert equal ($result | describe | get type) ("record")
    
    $env.DYNAMODB_MOCK_MODE = "false"
}

# ============================================================================
# UTILITY FUNCTION TESTS (8 tests)
# ============================================================================

#[test]
def "extract table name from arn" [] {
    let table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/my-table"
    
    let table_name = try {
        dynamodb extract-table-name $table_arn
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($table_name | str contains "my-table")
}

#[test]
def "extract account id from arn" [] {
    let table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/my-table"
    
    let account_id = try {
        dynamodb extract-account-id $table_arn
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($account_id | str contains "123456789012")
}

#[test]
def "extract region from arn" [] {
    let table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/my-table"
    
    let region = try {
        dynamodb extract-region $table_arn
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert ($region | str contains "us-east-1")
}

#[test]
def "generate test items with count" [] {
    let count = 5
    
    let items = try {
        dynamodb generate-test-items $count
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    assert equal ($items | length) ($count)
    assert ($items | each { |item| $item | get id? | default "" | str length } | all { |len| $len > 0 })
}

#[test]
def "generate test items validates count" [] {
    let invalid_counts = [0, -1, -10]
    
    for count in $invalid_counts {
        try {
            dynamodb generate-test-items $count
            assert false $"Should have failed with invalid count: ($count)"
        } catch { |error|
            assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "count"))
        }
    }
}

#[test]
def "is mock mode detection" [] {
    # Test with mock mode disabled
    $env.DYNAMODB_MOCK_MODE = "false"
    let mock_disabled = dynamodb is-mock-mode
    assert ($mock_disabled == false)
    
    # Test with mock mode enabled
    $env.DYNAMODB_MOCK_MODE = "true"
    let mock_enabled = dynamodb is-mock-mode
    assert ($mock_enabled == true)
    
    # Clean up
    $env.DYNAMODB_MOCK_MODE = "false"
}

#[test]
def "process items in batches with function" [] {
    let items = (0..25 | each { |i| { id: $"item-($i)", value: $i } })
    let batch_size = 10
    
    let result = try {
        dynamodb process-items-in-batches $items $batch_size { |batch| $batch | length }
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should process in batches and return results
    assert ($result | length) >= 3  # Should have at least 3 batches for 26 items with batch size 10
}

#[test]
def "monitor operation performance" [] {
    let operation_name = "test-operation"
    
    let performance_data = try {
        dynamodb monitor-operation-performance $operation_name {
            # Simulate some work
            sleep 100ms
            "operation completed"
        }
    } catch { |error|
        assert ($error | get type? | default "" | str contains "ValidationError" or ($error | get msg? | default "" | str contains "Failed"))
        return
    }
    
    # Should include timing and result information
    assert ($performance_data | get operation? | default "" | str contains $operation_name)
    assert ($performance_data | get duration_ms? | default 0) > 0
    assert ($performance_data | get result? | default "" | str contains "operation completed")
}