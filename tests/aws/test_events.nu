#!/usr/bin/env nu

# EventBridge module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/events.nu *

@before-each
def setup [] {
    $env.EVENTS_MOCK_MODE = "true"
    { test_context: "events", service: "EventBridge" }
}

@test
def "events list-rules returns mock rules" [] {
    let context = $in
    let result = (aws events list-rules)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result | get items? | default [] | length) > 0 "Should return mock rule items"
}

@test
def "events put-rule returns rule creation data" [] {
    let context = $in
    let result = (aws events put-rule)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return rule creation data"
}

@test
def "events put-events returns event publishing result" [] {
    let context = $in
    let result = (aws events put-events)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return event publishing data"
}

@test
def "events delete-rule returns deletion status" [] {
    let context = $in
    let result = (aws events delete-rule)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "DELETED" "Should return deleted status"
}