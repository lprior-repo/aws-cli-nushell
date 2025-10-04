use std/assert
use ../theme.nu

# Basic theme none tests (5 tests)
#[test]
def "theme none with pass type" [] {
    let theme = theme none
    let result = { type: "pass", text: "success" } | do $theme
    assert equal $result "success"
}

#[test]
def "theme none with fail type" [] {
    let theme = theme none
    let result = { type: "fail", text: "failure" } | do $theme
    assert equal $result "failure"
}

#[test]
def "theme none with skip type" [] {
    let theme = theme none
    let result = { type: "skip", text: "skipped" } | do $theme
    assert equal $result "skipped"
}

#[test]
def "theme none with warning type" [] {
    let theme = theme none
    let result = { type: "warning", text: "warning message" } | do $theme
    assert equal $result "warning message"
}

#[test]
def "theme none with unknown type" [] {
    let theme = theme none
    let result = { type: "unknown", text: "custom text" } | do $theme
    assert equal $result "custom text"
}

# Theme standard tests (5 tests)
#[test]
def "theme standard with pass type" [] {
    let theme = theme standard
    let result = { type: "pass", text: "success" } | do $theme
    assert str contains $result "✅"
    assert str contains $result "success"
    # Test contains ANSI color codes (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

#[test]
def "theme standard with fail type" [] {
    let theme = theme standard
    let result = { type: "fail", text: "failure" } | do $theme
    assert str contains $result "❌"
    assert str contains $result "failure"
    # Test contains ANSI color codes (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

#[test]
def "theme standard with skip type" [] {
    let theme = theme standard
    let result = { type: "skip", text: "skipped" } | do $theme
    assert str contains $result "🚧"
    assert str contains $result "skipped"
    # Test contains ANSI color codes (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

#[test]
def "theme standard with warning type" [] {
    let theme = theme standard
    let result = { type: "warning", text: "warning message" } | do $theme
    assert str contains $result "warning message"
    # Test contains ANSI color codes (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

#[test]
def "theme standard with error type" [] {
    let theme = theme standard
    let result = { type: "error", text: "error message" } | do $theme
    assert str contains $result "error message"
    # Test contains ANSI color codes (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

# Theme consistency and edge case tests (5 tests)
#[test]
def "theme standard with suite type" [] {
    let theme = theme standard
    let result = { type: "suite", text: "test suite" } | do $theme
    assert str contains $result "test suite"
    # Test contains ANSI color codes (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

#[test]
def "theme standard with test type" [] {
    let theme = theme standard
    let result = { type: "test", text: "test name" } | do $theme
    assert equal $result "test name"
}

#[test]
def "theme functions return closures" [] {
    let theme_none = theme none
    let theme_standard = theme standard
    
    assert equal ($theme_none | describe) "closure"
    assert equal ($theme_standard | describe) "closure"
}

#[test]
def "theme handles empty text" [] {
    let theme_none = theme none
    let theme_standard = theme standard
    
    let empty_none = { type: "pass", text: "" } | do $theme_none
    let empty_standard = { type: "pass", text: "" } | do $theme_standard
    
    assert equal $empty_none ""
    assert str contains $empty_standard "✅"
}

#[test]
def "theme handles multiline text" [] {
    let theme_none = theme none
    let theme_standard = theme standard
    
    let multiline_text = "line1\nline2\nline3"
    let none_result = { type: "fail", text: $multiline_text } | do $theme_none
    let standard_result = { type: "fail", text: $multiline_text } | do $theme_standard
    
    assert equal $none_result $multiline_text
    assert str contains $standard_result $multiline_text
    assert str contains $standard_result "❌"
}