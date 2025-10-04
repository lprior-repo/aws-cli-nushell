use std/assert
source ../completions.nu

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

#[test]
def "parse with empty option" [] {
    let result = "nutest run-tests --returns table --match-suites " | parse-command-context

    assert equal $result {
        suite: ".*"
        test: ".*"
        path: "."
    }
}

#[test]
def "parse with specified option" [] {
    let result = "nutest run-tests --returns table --match-suites orc" | parse-command-context

    assert equal $result {
        suite: "orc"
        test: ".*"
        path: "."
    }
}

#[test]
def "parse with extra space" [] {
    let result = "nutest run-tests  --match-suites  orc" | parse-command-context

    assert equal $result {
        suite: "orc"
        test: ".*"
        path: "."
    }
}

#[test]
def "parse when fully specified" [] {
    let result = "nutest run-tests --match-suites sui --match-tests te --path ../something" | parse-command-context

    assert equal $result {
        suite: "sui"
        test: "te"
        path: "../something"
    }
}

#[test]
def "parse with space in value" [] {
    let result = 'nutest run-tests --match-tests "parse some" --path ../something'  | parse-command-context

    assert equal $result {
        suite: ".*"
        test: "\"parse some\""
        path: "../something"
    }
}

#[test]
def "parse with prior commands" [] {
    let result = "use nutest; nutest run-tests --match-suites sui --match-tests te --path ../something" | parse-command-context

    assert equal $result {
        suite: "sui"
        test: "te"
        path: "../something"
    }
}

#[test]
def "complete suites" [] {
    let temp = $in.temp
    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test_bar.nu")
    touch ($temp | path join "test_baz.nu")

    let result = nu-complete suites $"--path ($temp) --match-suites ba"

    assert equal $result.completions [
        "test_bar"
        "test_baz"
    ]
}

#[test]
def "complete tests" [] {
    let temp = $in.temp

    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"

    "
    #[test]
    def some_foo1 [] { }
    " | save $test_file_1
    '
    #[test]
    def "some foo2" [] { }
    #[ignore]
    def some_foo3 [] { }
    #[before-each]
    def some_foo4 [] { }
    #[test]
    def some_foo5 [] { }
    ' | save $test_file_2


    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test_bar.nu")
    touch ($temp | path join "test_baz.nu")

    let result = nu-complete tests $"--path ($temp) --match-suites _2 --match-tests foo[1234]"

    assert equal $result.completions [
        # foo1 is excluded via suite pattern
        '"some foo2"' # Commands with spaces are quoted
        "some_foo3"
        # foo4 is excluded as it's not a test
        # foo5 is excluded test pattern
    ]
}

# Additional completion function tests (4 tests)
#[test]
def "nu-complete display options" [] {
    let result = nu-complete display
    
    assert equal ($result.options.sort) false
    assert equal ($result.completions | length) 3
    assert equal ($result.completions.0.value) "none"
    assert equal ($result.completions.1.value) "terminal"
    assert equal ($result.completions.2.value) "table"
}

#[test]
def "nu-complete returns options" [] {
    let result = nu-complete returns
    
    assert equal ($result.options.sort) false
    assert equal ($result.completions | length) 3
    assert equal ($result.completions.0.value) "nothing"
    assert equal ($result.completions.1.value) "table"
    assert equal ($result.completions.2.value) "summary"
}

#[test]
def "parse command context edge cases" [] {
    # Test various edge cases in command parsing
    
    # Empty command
    let empty_result = "" | parse-command-context
    assert equal $empty_result { suite: ".*", test: ".*", path: "." }
    
    # Command without parameters
    let no_params = "nutest run-tests" | parse-command-context
    assert equal $no_params { suite: ".*", test: ".*", path: "." }
    
    # Command with only one parameter
    let one_param = "nutest run-tests --path /tmp" | parse-command-context
    assert equal $one_param { suite: ".*", test: ".*", path: "/tmp" }
}

#[test]
def "completion algorithm configuration" [] {
    let temp = $in.temp
    touch ($temp | path join "test_sample.nu")
    
    # Test suites completion configuration
    let suites_result = nu-complete suites $"--path ($temp)"
    assert equal $suites_result.options.completion_algorithm "prefix"
    assert equal $suites_result.options.positional false
    
    # Test tests completion configuration
    let tests_result = nu-complete tests $"--path ($temp)"
    assert equal $tests_result.options.completion_algorithm "prefix"
    assert equal $tests_result.options.positional false
}
