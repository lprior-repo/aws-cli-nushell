#!/usr/bin/env nu

# ECS module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/ecs.nu *

@before-each
def setup [] {
    $env.ECS_MOCK_MODE = "true"
    { test_context: "ecs", service: "ECS" }
}

@test
def "ecs list-clusters returns mock clusters" [] {
    let context = $in
    let result = (aws ecs list-clusters)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return mock cluster items"
}

@test
def "ecs create-cluster returns cluster data" [] {
    let context = $in
    let result = (aws ecs create-cluster)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "CREATED" "Should return created status"
}

@test
def "ecs create-service returns service data" [] {
    let context = $in
    let result = (aws ecs create-service)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "CREATED" "Should return created status"
}

@test
def "ecs list-services returns service list" [] {
    let context = $in
    let result = (aws ecs list-services)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return service items"
}

@test
def "ecs describe-clusters returns cluster details" [] {
    let context = $in
    let result = (aws ecs describe-clusters)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return cluster details"
}

@test
def "ecs run-task returns task execution result" [] {
    let context = $in
    let result = (aws ecs run-task)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return task execution data"
}

@test
def "ecs delete-cluster returns deletion status" [] {
    let context = $in
    let result = (aws ecs delete-cluster)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "DELETED" "Should return deleted status"
}