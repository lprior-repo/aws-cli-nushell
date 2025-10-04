use std/assert
use ../discover.nu

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

# suite-files discovery tests (5 tests)
#[test]
def "suite files empty directory" [] {
    let temp = $in.temp
    let result = $temp | discover suite-files
    assert equal $result []
}

#[test]
def "suite files default glob" [] {
    let temp = $in.temp
    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "bar_test.nu")
    let result = $temp | discover suite-files | sort
    assert equal $result [
      ($temp | path join "bar_test.nu" | path expand)
      ($temp | path join "test_foo.nu" | path expand)
    ]
}

#[test]
def "suite files with matcher" [] {
    let temp = $in.temp
    touch ($temp | path join "test_alpha.nu")
    touch ($temp | path join "test_beta.nu")
    let result = $temp | discover suite-files --matcher "alpha" | sort
    assert equal $result [
      ($temp | path join "test_alpha.nu" | path expand)
    ]
}

#[test]
def "suite files nested directories" [] {
    let temp = $in.temp
    mkdir ($temp | path join "subdir")
    touch ($temp | path join "test_root.nu")
    touch ($temp | path join "subdir" "test_nested.nu")
    let result = $temp | discover suite-files | sort
    assert equal $result [
      ($temp | path join "subdir" "test_nested.nu" | path expand)
      ($temp | path join "test_root.nu" | path expand)
    ]
}

#[test]
def "suite files single file path" [] {
    let temp = $in.temp
    let file = $temp | path join "specific.nu"
    touch $file
    let result = $file | discover suite-files
    assert equal $result [$file]
}

# test-suites discovery tests (5 tests)
#[test]
def "test suites empty input" [] {
    let result = [] | discover test-suites
    assert equal $result []
}

#[test]
def "test suites basic annotations" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test_basic.nu"
    $"#[test]
    def test_one [] { }
    #[ignore]
    def test_two [] { }
    " | save $test_file
    let result = [$test_file] | discover test-suites
    assert equal $result [
        {
            name: "test_basic"
            path: $test_file
            tests: [
                { name: "test_one", type: "test" }
                { name: "test_two", type: "ignore" }
            ]
        }
    ]
}

#[test]
def "test suites with hooks" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test_hooks.nu"
    $"#[before-each]
    def setup [] { }
    #[test]
    def test_main [] { }
    #[after-each]
    def cleanup [] { }
    " | save $test_file
    let result = [$test_file] | discover test-suites
    assert equal ($result | get 0 | get tests | length) 3
}

#[test]
def "test suites with matcher filter" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test_filter.nu"
    $"#[test]
    def test_alpha [] { }
    #[test]
    def test_beta [] { }
    " | save $test_file
    let result = [$test_file] | discover test-suites --matcher "alpha"
    assert equal ($result | get 0 | get tests | length) 1
}

#[test]
def "test suites parse error handling" [] {
    let temp = $in.temp
    let broken_file = $temp | path join "test_broken.nu"
    "def incomplete" | save $broken_file
    let result = [$broken_file] | discover test-suites
    assert equal $result []
}

# Edge case tests (5 tests)
#[test]
def "discovery unicode support" [] {
    let temp = $in.temp
    let unicode_file = $temp | path join "test_unicode.nu"
    $"#[test]
    def test_unicode_名前 [] { }
    " | save $unicode_file
    let result = [$unicode_file] | discover test-suites
    assert equal ($result | get 0 | get tests | get 0 | get name) "test_unicode_名前"
}

#[test]
def "discovery mixed annotations" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test_mixed.nu"
    $"#[test]
    def test_valid [] { }
    def regular_function [] { }
    #[unknown]
    def test_unknown [] { }
    " | save $test_file
    let result = [$test_file] | discover test-suites
    assert equal ($result | get 0 | get tests | length) 2
}

#[test]
def "discovery no test matches" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test_nomatch.nu"
    $"#[test]
    def test_foo [] { }
    " | save $test_file
    let result = [$test_file] | discover test-suites --matcher "nonexistent"
    assert equal $result []
}

#[test]
def "discovery large file set" [] {
    let temp = $in.temp
    0..20 | each { |i| 
        touch ($temp | path join $"test_($i).nu")
    }
    let result = $temp | discover suite-files
    assert equal ($result | length) 21
}

#[test]
def "discovery file type filtering" [] {
    let temp = $in.temp
    touch ($temp | path join "test_valid.nu")
    touch ($temp | path join "test_invalid.py")
    touch ($temp | path join "not_test.nu")
    let result = $temp | discover suite-files
    assert equal ($result | length) 1
}