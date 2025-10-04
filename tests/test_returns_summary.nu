use std/assert
use ../returns/returns_summary.nu

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
def "returns summary creation" [] {
    let returns = returns_summary create
    
    assert equal $returns.name "returns summary"
    assert equal ($returns.results | describe) "closure"
}

#[test]
def "returns summary name field" [] {
    let returns = returns_summary create
    assert equal $returns.name "returns summary"
}

#[test]
def "returns summary has required fields" [] {
    let returns = returns_summary create
    let fields = $returns | columns | sort
    
    assert ("name" in $fields)
    assert ("results" in $fields)
}

#[test]
def "returns summary consistent interface" [] {
    let returns = returns_summary create
    
    # Verify interface consistency
    assert equal ($returns | get name | describe) "string"
    assert equal ($returns | get results | describe) "closure"
}

#[test]
def "returns summary results closure callable" [] {
    let returns = returns_summary create
    
    # Should be able to call the results closure
    let result = do $returns.results
    assert true
}

# Empty store summary tests (5 tests)
#[test]
def "returns summary with empty store" [] {
    let returns = returns_summary create
    
    let result = do $returns.results
    
    assert equal $result.total 0
    assert equal $result.passed 0
    assert equal $result.failed 0
    assert equal $result.skipped 0
}

#[test]
def "returns summary structure with empty store" [] {
    let returns = returns_summary create
    
    let result = do $returns.results
    let fields = $result | columns | sort
    
    assert equal $fields ["failed", "passed", "skipped", "total"]
}

#[test]
def "returns summary types with empty store" [] {
    let returns = returns_summary create
    
    let result = do $returns.results
    
    assert equal ($result.total | describe) "int"
    assert equal ($result.passed | describe) "int"
    assert equal ($result.failed | describe) "int"
    assert equal ($result.skipped | describe) "int"
}

#[test]
def "returns summary consistency with empty store" [] {
    let returns = returns_summary create
    
    let result1 = do $returns.results
    let result2 = do $returns.results
    
    assert equal $result1 $result2
}

#[test]
def "returns summary zero values with empty store" [] {
    let returns = returns_summary create
    
    let result = do $returns.results
    
    # All counts should be zero
    assert equal ($result.total + $result.passed + $result.failed + $result.skipped) 0
}

# Populated store summary tests (5 tests)
#[test]
def "returns summary with single passing test" [] {
    let returns = returns_summary create
    
    # Add a passing test
    store put "suite1" "test1" "PASS" []
    
    let result = do $returns.results
    
    assert equal $result.total 1
    assert equal $result.passed 1
    assert equal $result.failed 0
    assert equal $result.skipped 0
}

#[test]
def "returns summary with single failing test" [] {
    let returns = returns_summary create
    
    # Add a failing test
    store put "suite1" "test1" "FAIL" []
    
    let result = do $returns.results
    
    assert equal $result.total 1
    assert equal $result.passed 0
    assert equal $result.failed 1
    assert equal $result.skipped 0
}

#[test]
def "returns summary with single skipped test" [] {
    let returns = returns_summary create
    
    # Add a skipped test
    store put "suite1" "test1" "SKIP" []
    
    let result = do $returns.results
    
    assert equal $result.total 1
    assert equal $result.passed 0
    assert equal $result.failed 0
    assert equal $result.skipped 1
}

#[test]
def "returns summary with mixed test results" [] {
    let returns = returns_summary create
    
    # Add mixed test results
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "FAIL" []
    store put "suite2" "test3" "SKIP" []
    store put "suite2" "test4" "PASS" []
    store put "suite3" "test5" "FAIL" []
    
    let result = do $returns.results
    
    assert equal $result.total 5
    assert equal $result.passed 2
    assert equal $result.failed 2
    assert equal $result.skipped 1
    
    # Verify total equals sum of parts
    assert equal $result.total ($result.passed + $result.failed + $result.skipped)
}

#[test]
def "returns summary counts accuracy" [] {
    let returns = returns_summary create
    
    # Add many tests of each type
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "PASS" []
    store put "suite1" "test3" "PASS" []
    store put "suite2" "test4" "FAIL" []
    store put "suite2" "test5" "FAIL" []
    store put "suite3" "test6" "SKIP" []
    
    let result = do $returns.results
    
    assert equal $result.total 6
    assert equal $result.passed 3
    assert equal $result.failed 2
    assert equal $result.skipped 1
}