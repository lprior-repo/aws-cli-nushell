#!/usr/bin/env nu

# RDS module tests using nutest framework

use ../../nutest/nutest/mod.nu
use ../../aws/rds.nu *

@before-each
def setup [] {
    $env.RDS_MOCK_MODE = "true"
    { test_context: "rds", service: "RDS" }
}

@test
def "rds describe-db-instances returns mock instances" [] {
    let context = $in
    let result = (aws rds describe-db-instances)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.id? | default "") != "" "Should return instance details"
}

@test
def "rds create-db-instance returns instance creation data" [] {
    let context = $in
    let result = (aws rds create-db-instance)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "CREATED" "Should return created status"
}

@test
def "rds delete-db-instance returns deletion status" [] {
    let context = $in
    let result = (aws rds delete-db-instance)
    
    assert ($result.mock? | default false) "Result should contain mock flag"
    assert ($result.status? | default "") == "DELETED" "Should return deleted status"
}