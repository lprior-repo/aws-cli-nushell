#!/usr/bin/env nu

# S3 API module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/s3api.nu *

@before-each
def setup [] {
    $env.S3API_MOCK_MODE = "true"
    { test_context: "s3api", service: "S3API" }
}

@test
def "s3api list-buckets returns mock buckets" [] {
    let context = $in
    let result = (aws s3api list-buckets)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return mock bucket items"
}

@test
def "s3api create-bucket returns bucket creation data" [] {
    let context = $in
    let result = (aws s3api create-bucket)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "CREATED" "Should return created status"
}

@test
def "s3api put-object returns object upload result" [] {
    let context = $in
    let result = (aws s3api put-object)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return object upload data"
}

@test
def "s3api get-object returns object data" [] {
    let context = $in
    let result = (aws s3api get-object)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return object data"
}

@test
def "s3api delete-bucket returns deletion status" [] {
    let context = $in
    let result = (aws s3api delete-bucket)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "DELETED" "Should return deleted status"
}