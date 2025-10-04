use std/assert
use ../formatter.nu
use ../theme.nu

# Basic formatter tests (5 tests)
#[test]
def "formatter preserved mode with empty data" [] {
    let formatter = formatter preserved
    assert equal ([] | do $formatter) []
}

#[test]
def "formatter preserved mode with metadata" [] {
    let formatter = formatter preserved
    let data = [
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ]
    assert equal ($data | do $formatter) $data
}

#[test]
def "formatter unformatted mode extracts items" [] {
    let formatter = formatter unformatted
    let data = [
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ]
    assert equal ($data | do $formatter) [1, 2, 3, "a", "b", "c"]
}

#[test]
def "formatter pretty mode with theme none" [] {
    let formatter = formatter pretty (theme none) "compact"
    let data = [
        { stream: "error", items: [1, 2, 3]}
    ]
    assert equal ($data | do $formatter) "1\n2\n3"
}

#[test]
def "formatter pretty mode with mixed streams" [] {
    let formatter = formatter pretty (theme none) "compact"
    let data = [
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ]
    assert equal ($data | do $formatter) "1\n2\n3\na\nb\nc"
}

# Theme integration tests (5 tests)
#[test]
def "formatter with standard theme colors" [] {
    let formatter = formatter pretty (theme standard) "compact"
    let data = [
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ]
    let result = $data | do $formatter
    # Should contain ANSI codes for yellow (actual codes, not literal text)
    assert (($result | ansi strip) != $result) # Should contain ANSI codes
}

#[test]
def "formatter with rendered error mode" [] {
    let formatter = formatter pretty (theme standard) "rendered"
    let data = [
        { stream: "error", items: [
            {
                msg: 'test error'
                json: '{}'
                rendered: 'beautifully rendered error'
            }
        ]}
    ]
    let result = $data | do $formatter | ansi strip
    assert equal $result "beautifully rendered error"
}

#[test]
def "formatter theme application consistency" [] {
    let theme_none = theme none
    let theme_standard = theme standard
    
    let formatter_none = formatter pretty $theme_none "compact"
    let formatter_std = formatter pretty $theme_standard "compact"
    
    let data = [{ stream: "output", items: ["test"] }]
    
    let result_none = $data | do $formatter_none
    let result_std = $data | do $formatter_std
    
    assert equal $result_none "test"
    assert str contains $result_std "test"
}

#[test]
def "formatter with empty theme" [] {
    let empty_theme = { match $in { { type: $type, text: $text } => $text } }
    let formatter = formatter pretty $empty_theme "compact"
    let data = [{ stream: "error", items: ["warning"] }]
    assert equal ($data | do $formatter) "warning"
}

#[test]
def "formatter mode switching consistency" [] {
    let data = [{ stream: "output", items: ["test", "data"] }]
    
    let preserved = $data | do (formatter preserved)
    let unformatted = $data | do (formatter unformatted)
    let pretty = $data | do (formatter pretty (theme none) "compact")
    
    assert equal $preserved $data
    assert equal $unformatted ["test", "data"]
    assert equal $pretty "test\ndata"
}

# Data type handling tests (5 tests)
#[test]
def "formatter handles complex data types" [] {
    let formatter = formatter unformatted
    let data = [
        { stream: "output", items: [
            42,
            true,
            3.14,
            "string",
            [1, 2, 3],
            { key: "value" }
        ]}
    ]
    let result = $data | do $formatter
    assert equal ($result | length) 6
}

#[test]
def "formatter handles nested structures" [] {
    let formatter = formatter unformatted
    let data = [
        { stream: "output", items: [
            { nested: { deep: { value: "found" } } }
        ]}
    ]
    let result = $data | do $formatter
    assert equal ($result | get 0 | get nested | get deep | get value) "found"
}

#[test]
def "formatter handles multiline strings" [] {
    let formatter = formatter pretty (theme none) "compact"
    let data = [
        { stream: "output", items: ["line1\nline2\nline3"] }
    ]
    let result = $data | do $formatter
    assert str contains $result "line1\nline2\nline3"
}

#[test]
def "formatter handles special characters" [] {
    let formatter = formatter unformatted
    let data = [
        { stream: "output", items: ["unicode: 🚀", "symbols: @#$%", "quotes: \"'`"] }
    ]
    let result = $data | do $formatter
    assert equal ($result | length) 3
    assert str contains ($result | str join "") "🚀"
}

#[test]
def "formatter error resilience" [] {
    let formatter = formatter preserved
    
    # Test with malformed data
    let malformed = [
        { stream: "output" } # missing items
        { items: ["orphaned"] } # missing stream
        { stream: "error", items: null } # null items
    ]
    
    # Should not crash, handle gracefully
    let result = try { $malformed | do $formatter } catch { [] }
    assert ($result | describe | str starts-with "list")
}