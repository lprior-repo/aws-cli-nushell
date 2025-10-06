#!/usr/bin/env nu

# IAM module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/iam.nu *

@before-each
def setup [] {
    $env.IAM_MOCK_MODE = "true"
    { test_context: "iam", service: "IAM" }
}

@test
def "iam list-users returns mock users" [] {
    let context = $in
    let result = (aws iam list-users)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.Users? | default [] | length) > 0 "Should return mock user list"
}

@test
def "iam create-user returns user creation data" [] {
    let context = $in
    let result = (aws iam create-user)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.User? | default {} | get UserName? | default "") != "" "Should return created user data"
}

@test
def "iam attach-group-policy returns policy attachment" [] {
    let context = $in
    let result = (aws iam attach-group-policy)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "REGISTERED" "Should return registered status"
}