use std/assert
use ../formatter.nu
use ../theme.nu

const success_message = "Test passed successfully"
const warning_message = "Warning occurred"
const failure_message = "Test failed"

# Basic execution tests (5 tests)
#[test]
def "execute empty plan" [] {
    let plan = []
    let results = test-run "empty-suite" $plan
    assert equal $results []
}

#[test]
def "execute single passing test" [] {
    let plan = [
        { name: "pass_test", type: "test", execute: "{ success }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "PASS"
}

#[test]
def "execute single failing test" [] {
    let plan = [
        { name: "fail_test", type: "test", execute: "{ failure }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "FAIL"
}

#[test]
def "execute test with output capture" [] {
    let plan = [
        { name: "output_test", type: "test", execute: "{ print 'hello'; print -e 'error' }" }
    ]
    let results = test-run "suite" $plan
    let output_events = $results | where type == "output"
    assert ($output_events | length) >= 2
}

#[test]
def "execute multiple tests with mixed results" [] {
    let plan = [
        { name: "test_pass", type: "test", execute: "{ success }" }
        { name: "test_fail", type: "test", execute: "{ failure }" }
    ]
    let results = test-run "suite" $plan
    let result_events = $results | where type == "result"
    assert equal ($result_events | get payload) ["PASS", "FAIL"]
}

# Lifecycle hook tests (5 tests)
#[test]
def "execute before-all hook" [] {
    let plan = [
        { name: "setup", type: "before-all", execute: "{ get-context }" }
        { name: "test", type: "test", execute: "{ assert-context-received }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "PASS"
}

#[test]
def "execute after-all hook" [] {
    let plan = [
        { name: "test", type: "test", execute: "{ success }" }
        { name: "cleanup", type: "after-all", execute: "{ success }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "PASS"
}

#[test]
def "execute before-each hook" [] {
    let plan = [
        { name: "setup", type: "before-each", execute: "{ get-context }" }
        { name: "test", type: "test", execute: "{ assert-context-received }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "PASS"
}

#[test]
def "execute after-each hook" [] {
    let plan = [
        { name: "test", type: "test", execute: "{ success }" }
        { name: "cleanup", type: "after-each", execute: "{ success }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "PASS"
}

#[test]
def "hook failure propagation" [] {
    let plan = [
        { name: "setup", type: "before-each", execute: "{ failure }" }
        { name: "test", type: "test", execute: "{ success }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "FAIL"
}

# Advanced scenario tests (5 tests)
#[test]
def "context preservation across hooks" [] {
    let plan = [
        { name: "before-all", type: "before-all", execute: "{ get-context }" }
        { name: "before-each", type: "before-each", execute: "{ merge-context }" }
        { name: "test", type: "test", execute: "{ assert-merged-context }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "PASS"
}

#[test]
def "output formatting and capture" [] {
    let plan = [
        { name: "multi_output", type: "test", execute: "{ print 'line1'; print 'line2' }" }
    ]
    let results = test-run "suite" $plan
    let output_events = $results | where type == "output"
    assert ($output_events | length) >= 2
}

#[test]
def "error handling and recovery" [] {
    let plan = [
        { name: "error_test", type: "test", execute: "{ error make { msg: 'custom error' } }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "FAIL"
}

#[test]
def "data type preservation" [] {
    let plan = [
        { name: "types_test", type: "test", execute: "{ print 42; print true; print 3.14 }" }
    ]
    let results = test-run "suite" $plan
    let output_events = $results | where type == "output"
    assert ($output_events | length) >= 3
}

#[test]
def "hook signature validation" [] {
    let plan = [
        { name: "invalid_hook", type: "before-all", execute: "{ 'invalid_return_type' }" }
        { name: "test", type: "test", execute: "{ success }" }
    ]
    let results = test-run "suite" $plan
    assert equal ($results | where type == "result" | get payload | first) "FAIL"
}

# Helper functions
def success [] {
    print $success_message
}

def failure [] {
    error make { msg: $failure_message }
}

def get-context [] {
    {
        question: "Ultimate Answer"
        answer: 42
    }
}

def merge-context [] {
    let context = $in
    $context | merge { merged: true }
}

def assert-context-received [] {
    let context = $in
    print ($context | get question) ($context | get answer)
    assert equal $context (get-context)
}

def assert-merged-context [] {
    let context = $in
    assert equal $context.answer 42
    assert equal $context.merged true
}

def test-run [suite: string, plan: list<record>]: nothing -> table<suite, test, type, payload> {
    const this_file = path self
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest/runner.nu *
                source ($this_file)
                nutest-299792458-execute-suite { threads: 0 } ($suite) ($plan)
            "
    ) | complete

    if $result.exit_code != 0 {
        error make { msg: $result.stderr }
    }

    (
        $result.stdout
            | lines
            | each { $in | from nuon }
            | sort-by suite test
            | reject timestamp
            | update payload { |row|
                if ($row.type in ["output", "error"]) {
                    ($row.payload | decode-output )
                } else {
                    $row.payload
                }
            }
    )
}

def decode-output []: string -> record<stream: string, items: list<any>> {
    $in | decode base64 | decode | from nuon | reformat-errors
}

def reformat-errors []: record<stream: string, items: list<any>> -> record<stream: string, items: list<any>> {
    $in | update items { |event|
        $event.items | each { |item|
            if ($item | looks-like-error) {
                $item | get msg
            } else {
                $item
            }
        }
    }
}

def looks-like-error []: any -> bool {
    let value = $in
    if ($value | describe | str starts-with "record") {
        let columns = $value | columns
        ("msg" in $columns) and ("rendered" in $columns) and ("json" in $columns)
    } else {
        false
    }
}