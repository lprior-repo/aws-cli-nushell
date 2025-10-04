# AWS DynamoDB testing utilities
#
# Provides type-safe wrappers for AWS DynamoDB operations with comprehensive
# testing capabilities including table operations, item management, and queries.

use ../utils/test_utils.nu

# DynamoDB table configuration record type
export def dynamodb-table-config []: nothing -> record {
    {
        table_name: "",
        attribute_definitions: [],
        key_schema: [],
        billing_mode: "PAY_PER_REQUEST",
        provisioned_throughput: {},
        global_secondary_indexes: [],
        local_secondary_indexes: [],
        stream_specification: {},
        sse_specification: {},
        tags: []
    }
}

# Put item into DynamoDB table
export def put-item [
    table_name: string,
    item: record,
    --condition-expression: string = "",
    --return-values: string = "NONE"
]: nothing -> record {
    let dynamodb_item = convert-to-dynamodb-item $item
    
    let args = [
        "dynamodb", "put-item",
        "--table-name", $table_name,
        "--item", ($dynamodb_item | to json),
        "--return-values", $return_values
    ]
    
    let args = if ($condition_expression != "") {
        $args | append ["--condition-expression", $condition_expression]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to put item in DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Get item from DynamoDB table
export def get-item [
    table_name: string,
    key: record,
    --consistent-read: bool = false,
    --projection-expression: string = ""
]: nothing -> record {
    let dynamodb_key = convert-to-dynamodb-item $key
    
    let args = [
        "dynamodb", "get-item",
        "--table-name", $table_name,
        "--key", ($dynamodb_key | to json)
    ]
    
    let args = if $consistent_read {
        $args | append ["--consistent-read"]
    } else { $args }
    
    let args = if ($projection_expression != "") {
        $args | append ["--projection-expression", $projection_expression]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to get item from DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    if ($result.Item? != null) {
        convert-from-dynamodb-item $result.Item
    } else {
        {}
    }
}

# Delete item from DynamoDB table
export def delete-item [
    table_name: string,
    key: record,
    --condition-expression: string = "",
    --return-values: string = "NONE"
]: nothing -> record {
    let dynamodb_key = convert-to-dynamodb-item $key
    
    let args = [
        "dynamodb", "delete-item",
        "--table-name", $table_name,
        "--key", ($dynamodb_key | to json),
        "--return-values", $return_values
    ]
    
    let args = if ($condition_expression != "") {
        $args | append ["--condition-expression", $condition_expression]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to delete item from DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Update item in DynamoDB table
export def update-item [
    table_name: string,
    key: record,
    update_expression: string,
    --condition-expression: string = "",
    --expression-attribute-values: record = {},
    --expression-attribute-names: record = {},
    --return-values: string = "NONE"
]: nothing -> record {
    let dynamodb_key = convert-to-dynamodb-item $key
    
    let args = [
        "dynamodb", "update-item",
        "--table-name", $table_name,
        "--key", ($dynamodb_key | to json),
        "--update-expression", $update_expression,
        "--return-values", $return_values
    ]
    
    let args = if ($condition_expression != "") {
        $args | append ["--condition-expression", $condition_expression]
    } else { $args }
    
    let args = if ($expression_attribute_values | is-empty | not) {
        let dynamodb_values = convert-to-dynamodb-item $expression_attribute_values
        $args | append ["--expression-attribute-values", ($dynamodb_values | to json)]
    } else { $args }
    
    let args = if ($expression_attribute_names | is-empty | not) {
        $args | append ["--expression-attribute-names", ($expression_attribute_names | to json)]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to update item in DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Scan DynamoDB table
export def scan-table [
    table_name: string,
    --filter-expression: string = "",
    --projection-expression: string = "",
    --limit: int = 100,
    --consistent-read: bool = false
]: nothing -> list<record> {
    let args = [
        "dynamodb", "scan",
        "--table-name", $table_name,
        "--limit", ($limit | into string)
    ]
    
    let args = if ($filter_expression != "") {
        $args | append ["--filter-expression", $filter_expression]
    } else { $args }
    
    let args = if ($projection_expression != "") {
        $args | append ["--projection-expression", $projection_expression]
    } else { $args }
    
    let args = if $consistent_read {
        $args | append ["--consistent-read"]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to scan DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    ($result.Items? | default []) | each { |item| convert-from-dynamodb-item $item }
}

# Query DynamoDB table
export def query-table [
    table_name: string,
    key_condition_expression: string,
    --filter-expression: string = "",
    --projection-expression: string = "",
    --index-name: string = "",
    --limit: int = 100,
    --scan-index-forward: bool = true,
    --consistent-read: bool = false,
    --expression-attribute-values: record = {},
    --expression-attribute-names: record = {}
]: nothing -> list<record> {
    let args = [
        "dynamodb", "query",
        "--table-name", $table_name,
        "--key-condition-expression", $key_condition_expression,
        "--limit", ($limit | into string)
    ]
    
    let args = if ($filter_expression != "") {
        $args | append ["--filter-expression", $filter_expression]
    } else { $args }
    
    let args = if ($projection_expression != "") {
        $args | append ["--projection-expression", $projection_expression]
    } else { $args }
    
    let args = if ($index_name != "") {
        $args | append ["--index-name", $index_name]
    } else { $args }
    
    let args = if (not $scan_index_forward) {
        $args | append ["--no-scan-index-forward"]
    } else { $args }
    
    let args = if $consistent_read {
        $args | append ["--consistent-read"]
    } else { $args }
    
    let args = if ($expression_attribute_values | is-empty | not) {
        let dynamodb_values = convert-to-dynamodb-item $expression_attribute_values
        $args | append ["--expression-attribute-values", ($dynamodb_values | to json)]
    } else { $args }
    
    let args = if ($expression_attribute_names | is-empty | not) {
        $args | append ["--expression-attribute-names", ($expression_attribute_names | to json)]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to query DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    ($result.Items? | default []) | each { |item| convert-from-dynamodb-item $item }
}

# Create DynamoDB table
export def create-table [
    table_name: string,
    attribute_definitions: list<record>,
    key_schema: list<record>,
    --billing-mode: string = "PAY_PER_REQUEST",
    --tags: record = {}
]: nothing -> record {
    let args = [
        "dynamodb", "create-table",
        "--table-name", $table_name,
        "--attribute-definitions", ($attribute_definitions | to json),
        "--key-schema", ($key_schema | to json),
        "--billing-mode", $billing_mode
    ]
    
    let args = if ($tags | is-empty | not) {
        let tag_list = $tags | transpose key value | each { |row| 
            { Key: $row.key, Value: $row.value }
        }
        $args | append ["--tags", ($tag_list | to json)]
    } else { $args }
    
    let result = try {
        run-external "aws" $args | from json
    } catch { |error|
        error make {
            msg: $"Failed to create DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Delete DynamoDB table
export def delete-table [
    table_name: string
]: nothing -> record {
    let result = try {
        run-external "aws" [
            "dynamodb", "delete-table",
            "--table-name", $table_name
        ] | from json
    } catch { |error|
        error make {
            msg: $"Failed to delete DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Describe DynamoDB table
export def describe-table [
    table_name: string
]: nothing -> record {
    let result = try {
        run-external "aws" [
            "dynamodb", "describe-table",
            "--table-name", $table_name
        ] | from json
    } catch { |error|
        error make {
            msg: $"Failed to describe DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result.Table? | default {}
}

# Wait for table to be active
export def wait-for-table-active [
    table_name: string,
    --timeout-seconds: int = 300
]: nothing -> nothing {
    try {
        run-external "aws" [
            "dynamodb", "wait", "table-exists",
            "--table-name", $table_name
        ]
    } catch { |error|
        error make {
            msg: $"Timeout waiting for DynamoDB table to be active: ($table_name)",
            label: { text: $error.msg }
        }
    }
}

# Wait for table to be deleted
export def wait-for-table-deleted [
    table_name: string,
    --timeout-seconds: int = 300
]: nothing -> nothing {
    try {
        run-external "aws" [
            "dynamodb", "wait", "table-not-exists",
            "--table-name", $table_name
        ]
    } catch { |error|
        error make {
            msg: $"Timeout waiting for DynamoDB table to be deleted: ($table_name)",
            label: { text: $error.msg }
        }
    }
}

# Batch write items to DynamoDB table
export def batch-write-items [
    table_name: string,
    items: list<record>,
    --operation: string = "put"
]: nothing -> record {
    let requests = $items | each { |item|
        if ($operation == "put") {
            { PutRequest: { Item: (convert-to-dynamodb-item $item) } }
        } else {
            { DeleteRequest: { Key: (convert-to-dynamodb-item $item) } }
        }
    }
    
    let request_items = { ($table_name): $requests }
    
    let result = try {
        run-external "aws" [
            "dynamodb", "batch-write-item",
            "--request-items", ($request_items | to json)
        ] | from json
    } catch { |error|
        error make {
            msg: $"Failed to batch write items to DynamoDB table: ($table_name)",
            label: { text: $error.msg }
        }
    }
    
    $result
}

# Convert Nushell record to DynamoDB item format
export def convert-to-dynamodb-item [
    item: record
]: nothing -> record {
    $item | transpose key value | reduce -f {} { |row, acc|
        let field_name = $row.key
        let field_value = $row.value
        let dynamodb_value = match ($field_value | describe) {
            "string" => { "S": $field_value },
            "int" => { "N": ($field_value | into string) },
            "float" => { "N": ($field_value | into string) },
            "bool" => { "BOOL": $field_value },
            "list" => { "L": ($field_value | each { |v| convert-value-to-dynamodb $v }) },
            _ => { "S": ($field_value | into string) }
        }
        $acc | insert $field_name $dynamodb_value
    }
}

# Convert DynamoDB item to Nushell record
export def convert-from-dynamodb-item [
    dynamodb_item: record
]: nothing -> record {
    $dynamodb_item | transpose key value | reduce -f {} { |row, acc|
        let field_name = $row.key
        let dynamodb_value = $row.value
        let field_value = convert-value-from-dynamodb $dynamodb_value
        $acc | insert $field_name $field_value
    }
}

# Helper function to convert individual values to DynamoDB format
def convert-value-to-dynamodb [value: any]: nothing -> record {
    match ($value | describe) {
        "string" => { "S": $value },
        "int" => { "N": ($value | into string) },
        "float" => { "N": ($value | into string) },
        "bool" => { "BOOL": $value },
        "list" => { "L": ($value | each { |v| convert-value-to-dynamodb $v }) },
        _ => { "S": ($value | into string) }
    }
}

# Helper function to convert individual values from DynamoDB format
def convert-value-from-dynamodb [dynamodb_value: record]: nothing -> any {
    if ($dynamodb_value.S? != null) {
        $dynamodb_value.S
    } else if ($dynamodb_value.N? != null) {
        try { $dynamodb_value.N | into float } catch { $dynamodb_value.N | into int }
    } else if ($dynamodb_value.BOOL? != null) {
        $dynamodb_value.BOOL
    } else if ($dynamodb_value.L? != null) {
        $dynamodb_value.L | each { |v| convert-value-from-dynamodb $v }
    } else {
        null
    }
}

# Create test table with common schema
export def create-test-table [
    table_name: string,
    --tags: record = {}
]: nothing -> record {
    let attribute_definitions = [
        { AttributeName: "id", AttributeType: "S" },
        { AttributeName: "sort_key", AttributeType: "S" }
    ]
    
    let key_schema = [
        { AttributeName: "id", KeyType: "HASH" },
        { AttributeName: "sort_key", KeyType: "RANGE" }
    ]
    
    create-table $table_name $attribute_definitions $key_schema --tags $tags
}

# Test table operations with assertions
export def test-table-operations [
    table_name: string,
    test_items: list<record>,
    --assertion-closure: closure
]: nothing -> record {
    # Test put operations
    let put_results = $test_items | each { |item|
        put-item $table_name $item
    }
    
    # Test scan operation
    let scan_result = scan-table $table_name
    assert_equal ($scan_result | length) ($test_items | length) "Scan should return all items"
    
    # Test get operations
    let get_results = $test_items | each { |item|
        let key = $item | select id sort_key
        get-item $table_name $key
    }
    
    if ($assertion_closure != null) {
        do $assertion_closure { put_results: $put_results, scan_result: $scan_result, get_results: $get_results }
    }
    
    { put_results: $put_results, scan_result: $scan_result, get_results: $get_results }
}