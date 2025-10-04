use std/assert
source ../mod.nu

#[before-each]
def setup [] {
    let temp = mktemp --directory
    {
        temp: $temp
    }
}

#[after-each] 
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

# Core strategy selection tests (2 tests)
#[test]
def "strategy default configuration" [] {
    assert equal (null | select-strategy) { threads: 0 }
}

#[test]
def "strategy custom configuration" [] {
    assert equal ({ threads: 4 } | select-strategy) { threads: 4 }
}

# Display selection tests (3 tests)
#[test]
def "display default terminal" [] {
    assert equal (null | select-display null | get name) "display terminal"
}

#[test]
def "display nothing with results" [] {
    assert equal (null | select-display "table" | get name) "display nothing"
}

#[test]
def "display table mode" [] {
    assert equal ("table" | select-display null | get name) "display table"
}

# Returns selection tests (2 tests)
#[test]
def "returns nothing default" [] {
    assert equal ("nothing" | select-returns | get name) "returns nothing"
}

#[test]
def "returns summary mode" [] {
    assert equal ("summary" | select-returns | get name) "returns summary"
}

# Report selection tests (2 tests)
#[test]
def "report nothing default" [] {
    assert equal (null | select-report | get name) "report nothing"
}

#[test]
def "report junit configuration" [] {
    assert equal ({ type: "junit", path: "report.xml" } | select-report | get name) "report junit"
}

# list-tests command tests (3 tests)
#[test]
def "list tests with valid directory" [] {
    let context = $in
    let temp = $context.temp
    
    $"#[test]
    def sample_test [] { assert equal 1 1 }
    " | save ($temp | path join "test_sample.nu")
    
    let result = list-tests --path $temp
    
    assert equal $result [
        { suite: "test_sample", test: "sample_test" }
    ]
}

#[test]
def "list tests with empty directory" [] {
    let context = $in
    let temp = $context.temp
    
    let result = list-tests --path $temp
    
    assert equal $result []
}

#[test] 
def "list tests with invalid path" [] {
    try {
        list-tests --path "/invalid/path"
        assert false "Should have errored"
    } catch { |error|
        assert str contains $error.msg "Path doesn't exist"
    }
}

# Main execution path validation tests (3 tests)
#[test]
def "path validation with valid path" [] {
    let context = $in
    let temp = $context.temp
    
    let result = $temp | check-path
    assert equal $result $temp
}

#[test]
def "path validation with invalid path" [] {
    try {
        "/invalid/path" | check-path
        assert false "Should have errored"
    } catch { |error|
        assert str contains $error.msg "Path doesn't exist"
    }
}

#[test]
def "run tests error handling" [] {
    let context = $in
    let temp = $context.temp
    
    # Test run-tests with invalid configuration
    try {
        run-tests --path "/invalid/path"
        assert false "Should have errored"
    } catch { |error|
        assert str contains $error.msg "Path doesn't exist"
    }
}

