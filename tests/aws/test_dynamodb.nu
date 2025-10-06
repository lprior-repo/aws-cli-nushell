#!/usr/bin/env nu

# DynamoDB module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/dynamodb.nu *

@before-each
def setup [] {
    $env.DYNAMODB_MOCK_MODE = "true"
    { test_context: "dynamodb", service: "DynamoDB" }
}

@test
def "dynamodb list-tables returns mock data" [] {
    let context = $in
    let result = (aws dynamodb list-tables)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return mock table items"
}

@test  
def "dynamodb create-table returns creation data" [] {
    let context = $in
    let result = (aws dynamodb create-table)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "CREATED" "Should return created status"
}

@test
def "dynamodb describe-table returns table info" [] {
    let context = $in
    let result = (aws dynamodb describe-table)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return table info"
}

@test
def "dynamodb put-item returns success" [] {
    let context = $in
    let result = (aws dynamodb put-item)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") != "" "Should return operation status"
}

@test
def "dynamodb get-item returns item data" [] {
    let context = $in
    let result = (aws dynamodb get-item)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return item data"
}

@test
def "dynamodb scan returns scan results" [] {
    let context = $in
    let result = (aws dynamodb scan)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return scanned items"
}

@test
def "dynamodb query returns query results" [] {
    let context = $in
    let result = (aws dynamodb query)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return query results"
}

@test
def "dynamodb delete-table returns deletion status" [] {
    let context = $in
    let result = (aws dynamodb delete-table)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "DELETED" "Should return deleted status"
}