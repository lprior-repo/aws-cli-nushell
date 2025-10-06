#!/usr/bin/env nu

# Lambda module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/lambda.nu *

@before-each
def setup [] {
    $env.LAMBDA_MOCK_MODE = "true"
    { test_context: "lambda", service: "Lambda" }
}

@test
def "lambda list-functions returns mock functions" [] {
    let context = $in
    let result = (aws lambda list-functions)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return mock function items"
}

@test
def "lambda create-function returns function data" [] {
    let context = $in
    let result = (aws lambda create-function)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "CREATED" "Should return created status"
}

@test
def "lambda invoke returns invocation result" [] {
    let context = $in
    let result = (aws lambda invoke)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return invocation data"
}

@test
def "lambda update-function-code returns update status" [] {
    let context = $in
    let result = (aws lambda update-function-code)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "UPDATED" "Should return updated status"
}

@test
def "lambda delete-function returns deletion status" [] {
    let context = $in
    let result = (aws lambda delete-function)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "DELETED" "Should return deleted status"
}

@test
def "lambda get-function returns function details" [] {
    let context = $in
    let result = (aws lambda get-function)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return function details"
}

@test
def "lambda list-layers returns layer list" [] {
    let context = $in
    let result = (aws lambda list-layers)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return layer items"
}