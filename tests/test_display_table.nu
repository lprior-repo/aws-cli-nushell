use std/assert
use ../display/display_table.nu

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
def "display table creation" [] {
    let display = display_table create
    
    assert equal $display.name "display table"
    assert equal ($display.run-start | describe) "closure"
    assert equal ($display.run-complete | describe) "closure"
    assert equal ($display.test-start | describe) "closure"
    assert equal ($display.test-complete | describe) "closure"
}

#[test]
def "display table name field" [] {
    let display = display_table create
    assert equal $display.name "display table"
}

#[test]
def "display table has all required fields" [] {
    let display = display_table create
    let fields = $display | columns | sort
    
    assert ("name" in $fields)
    assert ("run-start" in $fields)
    assert ("run-complete" in $fields)
    assert ("test-start" in $fields)
    assert ("test-complete" in $fields)
}

#[test]
def "display table has results field for testing" [] {
    let display = display_table create
    
    # Should have results field for easier testing
    assert ("results" in ($display | columns))
    assert equal ($display.results | describe) "closure"
}

#[test]
def "display table consistent interface" [] {
    let display = display_table create
    
    # Verify interface consistency
    assert equal ($display | get name | describe) "string"
    assert equal ($display | get run-start | describe) "closure"
    assert equal ($display | get run-complete | describe) "closure"
    assert equal ($display | get test-start | describe) "closure"
    assert equal ($display | get test-complete | describe) "closure"
}

# Run lifecycle tests (5 tests)
#[test]
def "run start does nothing" [] {
    let display = display_table create
    
    # Table display waits until complete to show results
    do $display.run-start
    assert true
}

#[test]
def "run complete with empty results" [] {
    let display = display_table create
    
    # Should handle empty store gracefully
    do $display.run-complete
    assert true
}

#[test]
def "run complete prints results table" [] {
    let context = $in
    let display = display_table create
    
    # Add some test results to store
    store put $context.test_suite $context.test_name "PASS" []
    
    # Should complete without error (prints table)
    do $display.run-complete
    assert true
}

#[test]
def "test start does nothing" [] {
    let display = display_table create
    let test_row = { suite: "test_suite", test: "test_name" }
    
    # Table display waits until run complete
    do $display.test-start $test_row
    assert true
}

#[test]
def "test complete does nothing" [] {
    let display = display_table create
    let test_row = { suite: "test_suite", test: "test_name" }
    
    # Table display waits until run complete
    do $display.test-complete $test_row
    assert true
}

# Results query tests (5 tests)
#[test]
def "results query with empty store" [] {
    let display = display_table create
    
    let results = do $display.results
    assert equal $results []
}

#[test]
def "results query with single test result" [] {
    let context = $in
    let display = display_table create
    
    # Add a single test result
    store put $context.test_suite $context.test_name "PASS" []
    
    let results = do $display.results
    assert equal ($results | length) 1
    
    let row = $results | first
    assert ("suite" in ($row | columns))
    assert ("test" in ($row | columns))
    assert ("result" in ($row | columns))
    assert ("output" in ($row | columns))
}

#[test]
def "results query with multiple test results" [] {
    let display = display_table create
    
    # Add multiple test results
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "FAIL" []
    store put "suite2" "test3" "SKIP" []
    
    let results = do $display.results
    assert equal ($results | length) 3
    
    # Verify each result has required columns
    $results | each { |row|
        assert ("suite" in ($row | columns))
        assert ("test" in ($row | columns))
        assert ("result" in ($row | columns))
        assert ("output" in ($row | columns))
    }
}

#[test]
def "results query formats test results" [] {
    let context = $in
    let display = display_table create
    
    # Add test results with different statuses
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "FAIL" []
    store put "suite1" "test3" "SKIP" []
    
    let results = do $display.results
    
    # Results should be formatted with theme
    let pass_result = $results | where { |r| $r.test | str contains "test1" } | first
    let fail_result = $results | where { |r| $r.test | str contains "test2" } | first
    let skip_result = $results | where { |r| $r.test | str contains "test3" } | first
    
    assert str contains $pass_result.result "PASS"
    assert str contains $fail_result.result "FAIL"
    assert str contains $skip_result.result "SKIP"
}

#[test]
def "results query with test output" [] {
    let context = $in
    let display = display_table create
    
    # Add test result with output
    let output = [{ stream: "output", items: ["test output", "more output"] }]
    store put $context.test_suite $context.test_name "PASS" $output
    
    let results = do $display.results
    assert equal ($results | length) 1
    
    let row = $results | first
    assert str contains $row.output "test output"
    assert str contains $row.output "more output"
}