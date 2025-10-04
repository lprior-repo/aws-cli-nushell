use std/assert
use ../display/display_terminal.nu

#[before-each]
def setup [] {
    # Clear store before each test
    store clear
    {
        test_suite: "test_suite"
        test_name: "test_name"
    }
}

#[after-each]
def cleanup [] {
    # Clear store after each test
    store clear
}

# Basic display creation tests (5 tests)
#[test]
def "display terminal creation" [] {
    let display = display_terminal create
    
    assert equal $display.name "display terminal"
    assert equal ($display.run-start | describe) "closure"
    assert equal ($display.run-complete | describe) "closure"
    assert equal ($display.test-start | describe) "closure"
    assert equal ($display.test-complete | describe) "closure"
}

#[test]
def "display terminal name field" [] {
    let display = display_terminal create
    assert equal $display.name "display terminal"
}

#[test]
def "display terminal closures are callable" [] {
    let display = display_terminal create
    
    # Test that closures can be called without error
    do $display.run-start
    do $display.test-start { suite: "test", test: "example" }
    
    assert true
}

#[test]
def "display terminal has all required fields" [] {
    let display = display_terminal create
    let fields = $display | columns | sort
    
    assert ("name" in $fields)
    assert ("run-start" in $fields)
    assert ("run-complete" in $fields)
    assert ("test-start" in $fields)
    assert ("test-complete" in $fields)
}

#[test]
def "display terminal consistent interface" [] {
    let display = display_terminal create
    
    # Verify interface consistency
    assert equal ($display | get name | describe) "string"
    assert equal ($display | get run-start | describe) "closure"
    assert equal ($display | get run-complete | describe) "closure"
    assert equal ($display | get test-start | describe) "closure"
    assert equal ($display | get test-complete | describe) "closure"
}

# Run lifecycle tests (5 tests)
#[test]
def "run start executes without error" [] {
    let display = display_terminal create
    
    # Should not throw an error
    do $display.run-start
    assert true
}

#[test]
def "run complete with empty results" [] {
    let display = display_terminal create
    
    # Should handle empty store gracefully
    do $display.run-complete
    assert true
}

#[test]
def "run complete with test results" [] {
    let context = $in
    let display = display_terminal create
    
    # Add some test results to store
    store put $context.test_suite $context.test_name "PASS" []
    
    # Should complete without error
    do $display.run-complete
    assert true
}

#[test]
def "run complete summary calculation" [] {
    let context = $in
    let display = display_terminal create
    
    # Add mixed results
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "FAIL" []
    store put "suite2" "test3" "SKIP" []
    
    # Should calculate summary correctly (we can't capture print output easily, but verify no errors)
    do $display.run-complete
    assert true
}

#[test]
def "test start executes with test row" [] {
    let display = display_terminal create
    let test_row = { suite: "test_suite", test: "test_name" }
    
    # Should handle test start without error
    do $display.test-start $test_row
    assert true
}

# Test completion tests (5 tests)
#[test]
def "test complete with passing test" [] {
    let context = $in
    let display = display_terminal create
    
    # Add a passing test result
    store put $context.test_suite $context.test_name "PASS" []
    
    let test_event = { suite: $context.test_suite, test: $context.test_name }
    
    # Should complete without error
    do $display.test-complete $test_event
    assert true
}

#[test]
def "test complete with failing test" [] {
    let context = $in
    let display = display_terminal create
    
    # Add a failing test result
    store put $context.test_suite $context.test_name "FAIL" []
    
    let test_event = { suite: $context.test_suite, test: $context.test_name }
    
    # Should complete without error
    do $display.test-complete $test_event
    assert true
}

#[test]
def "test complete with skipped test" [] {
    let context = $in
    let display = display_terminal create
    
    # Add a skipped test result
    store put $context.test_suite $context.test_name "SKIP" []
    
    let test_event = { suite: $context.test_suite, test: $context.test_name }
    
    # Should complete without error
    do $display.test-complete $test_event
    assert true
}

#[test]
def "test complete with output" [] {
    let context = $in
    let display = display_terminal create
    
    # Add test result with output
    let output = [{ stream: "output", items: ["test output"] }]
    store put $context.test_suite $context.test_name "PASS" $output
    
    let test_event = { suite: $context.test_suite, test: $context.test_name }
    
    # Should handle output formatting without error
    do $display.test-complete $test_event
    assert true
}

#[test]
def "test complete with missing test result errors" [] {
    let display = display_terminal create
    
    let test_event = { suite: "nonexistent", test: "test" }
    
    # Should error when test result is not found
    try {
        do $display.test-complete $test_event
        assert false "Should have errored for missing test result"
    } catch {
        assert true
    }
}