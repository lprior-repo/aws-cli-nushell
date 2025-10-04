use std/assert
use ../returns/returns_table.nu

#[before-each]
def setup [] {
    # Clear store before each test
    store clear
    {}
}

#[after-each]
def cleanup [] {
    # Clear store after each test
    store clear
}

# Basic returns creation tests (5 tests)
#[test]
def "returns table creation" [] {
    let returns = returns_table create
    
    assert equal $returns.name "returns table"
    assert equal ($returns.results | describe) "closure"
}

#[test]
def "returns table name field" [] {
    let returns = returns_table create
    assert equal $returns.name "returns table"
}

#[test]
def "returns table has required fields" [] {
    let returns = returns_table create
    let fields = $returns | columns | sort
    
    assert ("name" in $fields)
    assert ("results" in $fields)
}

#[test]
def "returns table consistent interface" [] {
    let returns = returns_table create
    
    # Verify interface consistency
    assert equal ($returns | get name | describe) "string"
    assert equal ($returns | get results | describe) "closure"
}

#[test]
def "returns table results closure callable" [] {
    let returns = returns_table create
    
    # Should be able to call the results closure
    let result = do $returns.results
    assert true
}

# Empty store table tests (5 tests)
#[test]
def "returns table with empty store" [] {
    let returns = returns_table create
    
    let result = do $returns.results
    
    assert equal $result []
    assert equal ($result | describe) "table"
}

#[test]
def "returns table empty is list" [] {
    let returns = returns_table create
    
    let result = do $returns.results
    
    assert equal ($result | length) 0
    assert equal ($result | describe | str starts-with "table") true
}

#[test]
def "returns table consistent with empty store" [] {
    let returns = returns_table create
    
    let result1 = do $returns.results
    let result2 = do $returns.results
    
    assert equal $result1 $result2
    assert equal $result1 []
}

#[test]
def "returns table idempotent with empty store" [] {
    let returns = returns_table create
    
    # Multiple calls should return the same thing
    let result1 = do $returns.results
    let result2 = do $returns.results
    let result3 = do $returns.results
    
    assert equal $result1 []
    assert equal $result2 []
    assert equal $result3 []
}

#[test]
def "returns table no side effects" [] {
    let returns = returns_table create
    
    # Calling results should not change store
    let result1 = do $returns.results
    let result2 = do $returns.results
    
    assert equal $result1 $result2
}

# Single test result tests (5 tests)
#[test]
def "returns table with single test result" [] {
    let returns = returns_table create
    
    # Add a single test result
    store put "suite1" "test1" "PASS" []
    
    let result = do $returns.results
    
    assert equal ($result | length) 1
    
    let row = $result | first
    assert equal $row.suite "suite1"
    assert equal $row.test "test1"
    assert equal $row.result "PASS"
}

#[test]
def "returns table row structure" [] {
    let returns = returns_table create
    
    # Add a test result
    store put "suite1" "test1" "PASS" []
    
    let result = do $returns.results
    let row = $result | first
    let fields = $row | columns | sort
    
    assert equal $fields ["output", "result", "suite", "test"]
}

#[test]
def "returns table with test output" [] {
    let returns = returns_table create
    
    # Add test result with output
    let output = [{ stream: "output", items: ["test output", "more output"] }]
    store put "suite1" "test1" "PASS" $output
    
    let result = do $returns.results
    let row = $result | first
    
    # Output should be formatted by unformatted formatter
    assert equal ($row.output | describe | str starts-with "list") true
    assert equal ($row.output | length) 2
    assert equal ($row.output.0) "test output"
    assert equal ($row.output.1) "more output"
}

#[test]
def "returns table preserves test details" [] {
    let returns = returns_table create
    
    # Add test result
    store put "my_suite" "my_test" "FAIL" []
    
    let result = do $returns.results
    let row = $result | first
    
    assert equal $row.suite "my_suite"
    assert equal $row.test "my_test"
    assert equal $row.result "FAIL"
}

#[test]
def "returns table different result types" [] {
    let returns = returns_table create
    
    # Add different result types
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "FAIL" []
    store put "suite1" "test3" "SKIP" []
    
    let result = do $returns.results
    
    assert equal ($result | length) 3
    
    let results_column = $result | get result
    assert ("PASS" in $results_column)
    assert ("FAIL" in $results_column)
    assert ("SKIP" in $results_column)
}