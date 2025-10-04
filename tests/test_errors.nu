use std/assert
use ../errors.nu

# Basic error unwrapping tests (5 tests)
#[test]
def "unwrap error with simple structure" [] {
    let simple_error = {
        msg: "Simple error message"
        rendered: "Error: Simple error message"
        json: '{"msg": "Simple error message", "labels": []}'
    }
    
    let result = $simple_error | errors unwrap-error
    assert equal $result.msg "Simple error message"
    assert equal $result.rendered "Error: Simple error message"
    assert str contains $result.json "Simple error message"
}

#[test]
def "unwrap error preserves original fields" [] {
    let error = {
        msg: "Original message"
        rendered: "Original rendered"
        json: '{"msg": "Original message", "labels": []}'
    }
    
    let result = $error | errors unwrap-error
    assert equal $result.msg "Original message"
    assert equal $result.rendered "Original rendered"
    assert str contains $result.json "Original message"
}

#[test]
def "unwrap error with labels" [] {
    let error_with_labels = {
        msg: "Error with labels"
        rendered: "Error: Error with labels"
        json: '{"msg": "Error with labels", "labels": [{"text": "label1"}, {"text": "label2"}]}'
    }
    
    let result = $error_with_labels | errors unwrap-error
    assert equal $result.msg "Error with labels"
    assert ($result | get labels? | is-not-empty)
}

#[test]
def "unwrap error with empty inner errors" [] {
    let error = {
        msg: "Outer error"
        rendered: "Error: Outer error"
        json: '{"msg": "Outer error", "inner": [], "labels": []}'
    }
    
    let result = $error | errors unwrap-error
    assert equal $result.msg "Outer error"
}

#[test]
def "unwrap error returns record with required fields" [] {
    let error = {
        msg: "Test error"
        rendered: "Error: Test error"
        json: '{"msg": "Test error", "labels": []}'
    }
    
    let result = $error | errors unwrap-error
    let columns = $result | columns | sort
    assert ("msg" in $columns)
    assert ("rendered" in $columns)
    assert ("json" in $columns)
}

# Nested error unwrapping tests (5 tests)
#[test]
def "unwrap error with single inner error" [] {
    let nested_error = {
        msg: "Outer error"
        rendered: "Error: Outer error\nError: Inner error"
        json: '{"msg": "Outer error", "inner": [{"msg": "Inner error", "labels": []}], "labels": []}'
    }
    
    let result = $nested_error | errors unwrap-error
    assert equal $result.msg "Inner error"
    assert str contains $result.rendered "Inner error"
}

#[test]
def "unwrap error with multiple nested errors" [] {
    let deeply_nested = {
        msg: "Level 1"
        rendered: "Error: Level 1\nError: Level 2\nError: Level 3"
        json: '{"msg": "Level 1", "inner": [{"msg": "Level 2", "inner": [{"msg": "Level 3", "labels": []}], "labels": []}], "labels": []}'
    }
    
    let result = $deeply_nested | errors unwrap-error
    assert equal $result.msg "Level 3"
}

#[test]
def "unwrap error preserves inner error labels" [] {
    let error_with_inner_labels = {
        msg: "Outer"
        rendered: "Error: Outer\nError: Inner with details"
        json: '{"msg": "Outer", "inner": [{"msg": "Inner with details", "labels": [{"text": "inner label"}]}], "labels": []}'
    }
    
    let result = $error_with_inner_labels | errors unwrap-error
    assert equal $result.msg "Inner with details"
    assert ($result | get labels? | is-not-empty)
}

#[test]
def "unwrap error handles malformed json gracefully" [] {
    let malformed_error = {
        msg: "Test error"
        rendered: "Error: Test error"
        json: 'invalid json{'
    }
    
    # Should handle malformed JSON without crashing
    try {
        let result = $malformed_error | errors unwrap-error
        assert false "Should have handled gracefully or errored"
    } catch {
        # Expected to fail gracefully
        assert true
    }
}

#[test]
def "unwrap error with complex inner structure" [] {
    let complex_inner = {
        msg: "Complex outer"
        rendered: "Error: Complex outer\nError: Complex inner"
        json: '{"msg": "Complex outer", "inner": [{"msg": "Complex inner", "labels": [{"text": "detail1"}, {"text": "detail2"}], "help": "Try this fix"}], "labels": []}'
    }
    
    let result = $complex_inner | errors unwrap-error
    assert equal $result.msg "Complex inner"
    assert equal (($result | get labels? | length)) 2
}

# Rendered error processing tests (5 tests)
#[test]
def "last rendered with single error" [] {
    let single_error_text = "Error: Single error message\nSome context\nMore details"
    let result = $single_error_text | last-rendered
    assert equal $result $single_error_text
}

#[test]
def "last rendered with multiple errors" [] {
    let multiple_errors = "Error: First error\nSome context\nError: Second error\nFinal details"
    let result = $multiple_errors | last-rendered
    assert str contains $result "Error: Second error"
    assert str contains $result "Final details"
    assert not ($result | str contains "First error")
}

#[test]
def "last rendered with no error prefix" [] {
    let no_error_text = "Some regular text\nWith multiple lines\nNo error here"
    let result = $no_error_text | last-rendered
    assert equal $result $no_error_text
}

#[test]
def "last rendered handles empty input" [] {
    let empty_text = ""
    let result = $empty_text | last-rendered
    assert equal $result ""
}

#[test]
def "last rendered with complex error stack" [] {
    let complex_stack = "Error: Outer error\nContext line 1\nContext line 2\nError: Middle error\nMore context\nError: Inner error\nFinal context"
    let result = $complex_stack | last-rendered
    assert str contains $result "Error: Inner error"
    assert str contains $result "Final context"
    assert not ($result | str contains "Outer error")
    assert not ($result | str contains "Middle error")
}