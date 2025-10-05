# AWS SDK Documentation Parser
#
# Comprehensive parser for AWS SDK documentation across multiple languages
# including JavaScript, Python, Java, Go, .NET, Ruby, and PHP.
# Extracts method signatures, parameters, examples, and type information.

use utils/test_utils.nu
use aws_advanced_parser.nu
use aws_api_parser.nu

# ============================================================================
# SDK LANGUAGE PATTERNS
# ============================================================================

export const SDK_PATTERNS = {
    # JavaScript/TypeScript patterns
    js_method: 'async\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)',
    js_param: '([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*([a-zA-Z_][a-zA-Z0-9_<>|\[\]]*)',
    js_promise: 'Promise<([^>]+)>',
    js_interface: 'interface\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    js_type: 'type\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=',
    
    # Python patterns
    py_method: 'def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)',
    py_param: '([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*([a-zA-Z_][a-zA-Z0-9_\[\]\.]*)',
    py_return: '->\s*([a-zA-Z_][a-zA-Z0-9_\[\]\.]*)',
    py_class: 'class\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    py_docstring: '"""([^"]+)"""',
    
    # Java patterns
    java_method: '(public|private|protected)?\s*(static)?\s*([a-zA-Z_][a-zA-Z0-9_<>]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)',
    java_param: '([a-zA-Z_][a-zA-Z0-9_<>]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    java_class: '(public|private)?\s*class\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    java_interface: '(public|private)?\s*interface\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    java_generic: '<([^>]+)>',
    
    # Go patterns
    go_func: 'func\s+(?:\([^)]*\)\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)',
    go_param: '([a-zA-Z_][a-zA-Z0-9_]*)\s+([a-zA-Z_][a-zA-Z0-9_\[\]*\.]*)',
    go_return: '\)\s*\(([^)]+)\)',
    go_struct: 'type\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+struct',
    go_interface: 'type\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+interface',
    
    # .NET/C# patterns
    csharp_method: '(public|private|protected|internal)?\s*(static|async)?\s*([a-zA-Z_][a-zA-Z0-9_<>]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)',
    csharp_param: '([a-zA-Z_][a-zA-Z0-9_<>]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    csharp_class: '(public|private|internal)?\s*class\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    csharp_interface: '(public|private|internal)?\s*interface\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    csharp_property: '(public|private|protected)?\s*([a-zA-Z_][a-zA-Z0-9_<>]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*{',
    
    # Ruby patterns
    ruby_method: 'def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:\([^)]*\))?',
    ruby_param: '([a-zA-Z_][a-zA-Z0-9_]*)\s*:',
    ruby_class: 'class\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    ruby_module: 'module\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    
    # PHP patterns
    php_method: '(public|private|protected)?\s*function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)',
    php_param: '\$([a-zA-Z_][a-zA-Z0-9_]*)',
    php_class: 'class\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    php_interface: 'interface\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    
    # Common documentation patterns
    code_block: '```([a-zA-Z]*)\n([^`]+)\n```',
    inline_code: '`([^`]+)`',
    example_section: '## Examples?',
    parameter_section: '## Parameters?',
    return_section: '## Returns?',
    see_also: '## See [Aa]lso',
    
    # AWS SDK specific patterns
    aws_service_pattern: 'AWS\.([A-Za-z0-9]+)',
    boto3_client: 'boto3\.client\([\'"]([^\'"]+)[\'"]\)',
    aws_sdk_js: 'new AWS\.([A-Za-z0-9]+)',
    aws_sdk_java: 'Amazon([A-Za-z0-9]+)Client',
    aws_sdk_go: 'aws-sdk-go/service/([a-zA-Z0-9]+)',
    aws_sdk_dotnet: 'Amazon\.([A-Za-z0-9]+)\.([A-Za-z0-9]+)',
    
    # Error patterns
    exception_pattern: '([A-Za-z0-9]+Exception)',
    error_code_pattern: 'Error[Cc]ode:\s*([A-Za-z0-9]+)',
    
    # Version patterns
    version_pattern: 'v?(\d+)\.(\d+)\.(\d+)',
    api_version_pattern: 'API [Vv]ersion:?\s*([\d-]+)'
}

# ============================================================================
# SDK DOCUMENTATION STRUCTURES
# ============================================================================

# SDK method documentation structure
export def sdk-method-doc []: nothing -> record {
    {
        name: "",
        language: "",
        service: "",
        description: "",
        signature: "",
        parameters: [],
        return_type: "",
        return_description: "",
        examples: [],
        exceptions: [],
        see_also: [],
        since_version: "",
        deprecated: false,
        async: false
    }
}

# SDK parameter structure
export def sdk-parameter []: nothing -> record {
    {
        name: "",
        type: "",
        required: false,
        description: "",
        default_value: null,
        constraints: {},
        examples: []
    }
}

# SDK example structure
export def sdk-example []: nothing -> record {
    {
        title: "",
        description: "",
        code: "",
        language: "",
        full_example: false
    }
}

# ============================================================================
# MULTI-LANGUAGE SDK PARSER
# ============================================================================

# Parse SDK documentation for multiple languages
export def parse-sdk-documentation [
    content: string,
    language: string,
    service: string = ""
]: nothing -> record {
    match $language {
        "javascript" | "typescript" | "js" | "ts" => parse-javascript-sdk $content $service,
        "python" | "py" => parse-python-sdk $content $service,
        "java" => parse-java-sdk $content $service,
        "go" => parse-go-sdk $content $service,
        "csharp" | "c#" | "dotnet" => parse-csharp-sdk $content $service,
        "ruby" | "rb" => parse-ruby-sdk $content $service,
        "php" => parse-php-sdk $content $service,
        _ => parse-generic-sdk $content $language $service
    }
}

# ============================================================================
# JAVASCRIPT/TYPESCRIPT PARSER
# ============================================================================

# Parse JavaScript/TypeScript SDK documentation
def parse-javascript-sdk [
    content: string,
    service: string
]: nothing -> record {
    let lines = ($content | lines)
    let patterns = $SDK_PATTERNS
    
    # Extract methods
    let methods = extract-js-methods $content $service
    
    # Extract interfaces and types
    let types = extract-js-types $content
    
    # Extract examples
    let examples = extract-code-examples $content "javascript"
    
    {
        language: "javascript",
        service: $service,
        methods: $methods,
        types: $types,
        examples: $examples,
        sdk_version: (extract-version $content),
        api_version: (extract-api-version $content)
    }
}

# Extract JavaScript methods
def extract-js-methods [
    content: string,
    service: string
]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let method_matches = ($content | parse --regex $patterns.js_method)
    
    $method_matches | each { |match|
        let method_name = $match.capture0
        let method_section = extract-method-section $content $method_name
        
        {
            name: $method_name,
            language: "javascript",
            service: $service,
            description: (extract-method-description $method_section),
            signature: (extract-method-signature $method_section $patterns.js_method),
            parameters: (extract-js-parameters $method_section),
            return_type: (extract-js-return-type $method_section),
            return_description: (extract-return-description $method_section),
            examples: (extract-method-examples $method_section "javascript"),
            exceptions: (extract-method-exceptions $method_section),
            see_also: (extract-see-also $method_section),
            since_version: (extract-since-version $method_section),
            deprecated: (is-deprecated $method_section),
            async: ($method_section | str contains "async")
        }
    }
}

# Extract JavaScript parameters
def extract-js-parameters [method_section: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let param_matches = ($method_section | parse --regex $patterns.js_param)
    
    $param_matches | each { |match|
        let param_name = $match.capture0
        let param_type = $match.capture1
        
        {
            name: $param_name,
            type: $param_type,
            required: (not ($param_type | str contains "?")),
            description: (extract-parameter-description $method_section $param_name),
            default_value: (extract-parameter-default $method_section $param_name),
            constraints: {},
            examples: []
        }
    }
}

# Extract JavaScript return type
def extract-js-return-type [method_section: string]: nothing -> string {
    let patterns = $SDK_PATTERNS
    let promise_matches = ($method_section | parse --regex $patterns.js_promise)
    
    if ($promise_matches | length) > 0 {
        $promise_matches.capture0.0
    } else {
        "void"
    }
}

# Extract JavaScript types and interfaces
def extract-js-types [content: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let interface_matches = ($content | parse --regex $patterns.js_interface)
    let type_matches = ($content | parse --regex $patterns.js_type)
    
    let interfaces = ($interface_matches | each { |match|
        {
            name: $match.capture0,
            kind: "interface",
            definition: (extract-type-definition $content $match.capture0)
        }
    })
    
    let types = ($type_matches | each { |match|
        {
            name: $match.capture0,
            kind: "type",
            definition: (extract-type-definition $content $match.capture0)
        }
    })
    
    $interfaces | append $types
}

# ============================================================================
# PYTHON PARSER
# ============================================================================

# Parse Python SDK documentation
def parse-python-sdk [
    content: string,
    service: string
]: nothing -> record {
    let methods = extract-python-methods $content $service
    let classes = extract-python-classes $content
    let examples = extract-code-examples $content "python"
    
    {
        language: "python",
        service: $service,
        methods: $methods,
        classes: $classes,
        examples: $examples,
        sdk_version: (extract-version $content),
        api_version: (extract-api-version $content)
    }
}

# Extract Python methods
def extract-python-methods [
    content: string,
    service: string
]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let method_matches = ($content | parse --regex $patterns.py_method)
    
    $method_matches | each { |match|
        let method_name = $match.capture0
        let method_section = extract-method-section $content $method_name
        
        {
            name: $method_name,
            language: "python",
            service: $service,
            description: (extract-python-docstring $method_section),
            signature: (extract-method-signature $method_section $patterns.py_method),
            parameters: (extract-python-parameters $method_section),
            return_type: (extract-python-return-type $method_section),
            return_description: (extract-return-description $method_section),
            examples: (extract-method-examples $method_section "python"),
            exceptions: (extract-method-exceptions $method_section),
            see_also: (extract-see-also $method_section),
            since_version: (extract-since-version $method_section),
            deprecated: (is-deprecated $method_section),
            async: false
        }
    }
}

# Extract Python docstring
def extract-python-docstring [method_section: string]: nothing -> string {
    let patterns = $SDK_PATTERNS
    let docstring_matches = ($method_section | parse --regex $patterns.py_docstring)
    
    if ($docstring_matches | length) > 0 {
        $docstring_matches.capture0.0 | str trim
    } else {
        ""
    }
}

# Extract Python parameters
def extract-python-parameters [method_section: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let param_matches = ($method_section | parse --regex $patterns.py_param)
    
    $param_matches | each { |match|
        let param_name = $match.capture0
        let param_type = $match.capture1
        
        {
            name: $param_name,
            type: $param_type,
            required: (not ($param_type | str contains "Optional")),
            description: (extract-parameter-description $method_section $param_name),
            default_value: (extract-parameter-default $method_section $param_name),
            constraints: {},
            examples: []
        }
    }
}

# Extract Python return type
def extract-python-return-type [method_section: string]: nothing -> string {
    let patterns = $SDK_PATTERNS
    let return_matches = ($method_section | parse --regex $patterns.py_return)
    
    if ($return_matches | length) > 0 {
        $return_matches.capture0.0
    } else {
        "None"
    }
}

# Extract Python classes
def extract-python-classes [content: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let class_matches = ($content | parse --regex $patterns.py_class)
    
    $class_matches | each { |match|
        {
            name: $match.capture0,
            kind: "class",
            definition: (extract-class-definition $content $match.capture0)
        }
    }
}

# ============================================================================
# JAVA PARSER
# ============================================================================

# Parse Java SDK documentation
def parse-java-sdk [
    content: string,
    service: string
]: nothing -> record {
    let methods = extract-java-methods $content $service
    let classes = extract-java-classes $content
    let interfaces = extract-java-interfaces $content
    let examples = extract-code-examples $content "java"
    
    {
        language: "java",
        service: $service,
        methods: $methods,
        classes: $classes,
        interfaces: $interfaces,
        examples: $examples,
        sdk_version: (extract-version $content),
        api_version: (extract-api-version $content)
    }
}

# Extract Java methods
def extract-java-methods [
    content: string,
    service: string
]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let method_matches = ($content | parse --regex $patterns.java_method)
    
    $method_matches | each { |match|
        let method_name = $match.capture3
        let return_type = $match.capture2
        let method_section = extract-method-section $content $method_name
        
        {
            name: $method_name,
            language: "java",
            service: $service,
            description: (extract-java-javadoc $method_section),
            signature: (extract-method-signature $method_section $patterns.java_method),
            parameters: (extract-java-parameters $method_section),
            return_type: $return_type,
            return_description: (extract-return-description $method_section),
            examples: (extract-method-examples $method_section "java"),
            exceptions: (extract-method-exceptions $method_section),
            see_also: (extract-see-also $method_section),
            since_version: (extract-since-version $method_section),
            deprecated: (is-deprecated $method_section),
            async: false
        }
    }
}

# Extract Java parameters
def extract-java-parameters [method_section: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let param_matches = ($method_section | parse --regex $patterns.java_param)
    
    $param_matches | each { |match|
        let param_type = $match.capture0
        let param_name = $match.capture1
        
        {
            name: $param_name,
            type: $param_type,
            required: true,  # Java typically doesn't have optional parameters
            description: (extract-parameter-description $method_section $param_name),
            default_value: null,
            constraints: {},
            examples: []
        }
    }
}

# Extract Java classes
def extract-java-classes [content: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let class_matches = ($content | parse --regex $patterns.java_class)
    
    $class_matches | each { |match|
        {
            name: $match.capture1,
            kind: "class",
            definition: (extract-class-definition $content $match.capture1)
        }
    }
}

# Extract Java interfaces
def extract-java-interfaces [content: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let interface_matches = ($content | parse --regex $patterns.java_interface)
    
    $interface_matches | each { |match|
        {
            name: $match.capture1,
            kind: "interface",
            definition: (extract-interface-definition $content $match.capture1)
        }
    }
}

# Extract Java Javadoc
def extract-java-javadoc [method_section: string]: nothing -> string {
    # Look for /** ... */ pattern
    let javadoc_pattern = '/\*\*(.*?)\*/'
    let javadoc_matches = ($method_section | parse --regex $javadoc_pattern)
    
    if ($javadoc_matches | length) > 0 {
        $javadoc_matches.capture0.0 
        | str replace --all '\*' ''
        | str replace --all '\n' ' '
        | str trim
    } else {
        ""
    }
}

# ============================================================================
# GO PARSER
# ============================================================================

# Parse Go SDK documentation
def parse-go-sdk [
    content: string,
    service: string
]: nothing -> record {
    let functions = extract-go-functions $content $service
    let structs = extract-go-structs $content
    let interfaces = extract-go-interfaces $content
    let examples = extract-code-examples $content "go"
    
    {
        language: "go",
        service: $service,
        functions: $functions,
        structs: $structs,
        interfaces: $interfaces,
        examples: $examples,
        sdk_version: (extract-version $content),
        api_version: (extract-api-version $content)
    }
}

# Extract Go functions
def extract-go-functions [
    content: string,
    service: string
]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let func_matches = ($content | parse --regex $patterns.go_func)
    
    $func_matches | each { |match|
        let func_name = $match.capture0
        let func_section = extract-method-section $content $func_name
        
        {
            name: $func_name,
            language: "go",
            service: $service,
            description: (extract-go-comment $func_section),
            signature: (extract-method-signature $func_section $patterns.go_func),
            parameters: (extract-go-parameters $func_section),
            return_type: (extract-go-return-type $func_section),
            return_description: (extract-return-description $func_section),
            examples: (extract-method-examples $func_section "go"),
            exceptions: (extract-method-exceptions $func_section),
            see_also: (extract-see-also $func_section),
            since_version: (extract-since-version $func_section),
            deprecated: (is-deprecated $func_section),
            async: false
        }
    }
}

# Extract Go comment
def extract-go-comment [func_section: string]: nothing -> string {
    # Go comments are typically // or /* */
    let lines = ($func_section | lines)
    let comment_lines = ($lines | where ($it | str starts-with "//"))
    
    $comment_lines 
    | each { |line| $line | str replace "//" "" | str trim }
    | str join " "
}

# Extract Go parameters
def extract-go-parameters [func_section: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let param_matches = ($func_section | parse --regex $patterns.go_param)
    
    $param_matches | each { |match|
        let param_name = $match.capture0
        let param_type = $match.capture1
        
        {
            name: $param_name,
            type: $param_type,
            required: (not ($param_type | str starts-with "*")),
            description: (extract-parameter-description $func_section $param_name),
            default_value: null,
            constraints: {},
            examples: []
        }
    }
}

# Extract Go return type
def extract-go-return-type [func_section: string]: nothing -> string {
    let patterns = $SDK_PATTERNS
    let return_matches = ($func_section | parse --regex $patterns.go_return)
    
    if ($return_matches | length) > 0 {
        $return_matches.capture0.0
    } else {
        ""
    }
}

# Extract Go structs
def extract-go-structs [content: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let struct_matches = ($content | parse --regex $patterns.go_struct)
    
    $struct_matches | each { |match|
        {
            name: $match.capture0,
            kind: "struct",
            definition: (extract-struct-definition $content $match.capture0)
        }
    }
}

# Extract Go interfaces
def extract-go-interfaces [content: string]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let interface_matches = ($content | parse --regex $patterns.go_interface)
    
    $interface_matches | each { |match|
        {
            name: $match.capture0,
            kind: "interface",
            definition: (extract-interface-definition $content $match.capture0)
        }
    }
}

# ============================================================================
# GENERIC PARSING UTILITIES
# ============================================================================

# Extract method section from content
def extract-method-section [
    content: string,
    method_name: string
]: nothing -> string {
    let lines = ($content | lines)
    let method_start = ($lines | enumerate | where ($it.item | str contains $method_name) | get index.0? | default (-1))
    
    if $method_start == -1 {
        return ""
    }
    
    # Find next method or end of section
    let next_method_start = (
        $lines 
        | range ($method_start + 1)..
        | enumerate 
        | where ($it.item | str contains "def " or $it.item | str contains "function " or $it.item | str contains "func ")
        | get index.0?
        | default ($lines | length)
    )
    
    $lines | range $method_start..($method_start + $next_method_start) | str join "\n"
}

# Extract method description
def extract-method-description [method_section: string]: nothing -> string {
    let lines = ($method_section | lines)
    # Look for description after method signature
    $lines 
    | range 1..10  # First few lines after signature
    | where ($it | str trim | str length) > 0
    | where not ($it | str starts-with "//")
    | where not ($it | str starts-with "#")
    | where not ($it | str starts-with "/*")
    | first
    | default ""
    | str trim
}

# Extract method signature
def extract-method-signature [
    method_section: string,
    pattern: string
]: nothing -> string {
    let signature_matches = ($method_section | parse --regex $pattern)
    if ($signature_matches | length) > 0 {
        let lines = ($method_section | lines)
        $lines | first | str trim
    } else {
        ""
    }
}

# Extract parameter description
def extract-parameter-description [
    method_section: string,
    param_name: string
]: nothing -> string {
    let lines = ($method_section | lines)
    let param_lines = ($lines | where ($it | str contains $param_name))
    
    if ($param_lines | length) > 0 {
        $param_lines | first | str trim
    } else {
        ""
    }
}

# Extract parameter default value
def extract-parameter-default [
    method_section: string,
    param_name: string
]: nothing -> any {
    # Look for default value patterns
    let default_patterns = [
        $"($param_name)\\s*=\\s*([^,\\)]+)",
        $"($param_name)\\s*:\\s*[^=]*=\\s*([^,\\)]+)"
    ]
    
    for pattern in $default_patterns {
        let matches = ($method_section | parse --regex $pattern)
        if ($matches | length) > 0 {
            return ($matches.capture1.0 | str trim)
        }
    }
    
    null
}

# Extract code examples
def extract-code-examples [
    content: string,
    language: string
]: nothing -> list<record> {
    let patterns = $SDK_PATTERNS
    let code_matches = ($content | parse --regex $patterns.code_block)
    
    $code_matches | each { |match|
        let code_language = $match.capture0
        let code_content = $match.capture1
        
        {
            title: "",
            description: "",
            code: $code_content,
            language: (if ($code_language | str length) > 0 { $code_language } else { $language }),
            full_example: true
        }
    }
}

# Extract method examples
def extract-method-examples [
    method_section: string,
    language: string
]: nothing -> list<record> {
    extract-code-examples $method_section $language
}

# Extract method exceptions
def extract-method-exceptions [method_section: string]: nothing -> list<string> {
    let patterns = $SDK_PATTERNS
    let exception_matches = ($method_section | parse --regex $patterns.exception_pattern)
    
    $exception_matches | get capture0 | uniq
}

# Extract see also references
def extract-see-also [method_section: string]: nothing -> list<string> {
    let lines = ($method_section | lines)
    let see_also_lines = ($lines | where ($it | str contains "See also" or $it | str contains "See Also"))
    
    $see_also_lines | each { |line|
        # Extract references from the line
        $line | str replace "See also:" "" | str replace "See Also:" "" | str trim
    }
}

# Extract since version
def extract-since-version [method_section: string]: nothing -> string {
    let since_patterns = [
        'Since:?\s*(v?[\d.]+)',
        'Added in:?\s*(v?[\d.]+)',
        '@since\s*(v?[\d.]+)'
    ]
    
    for pattern in $since_patterns {
        let matches = ($method_section | parse --regex $pattern)
        if ($matches | length) > 0 {
            return $matches.capture0.0
        }
    }
    
    ""
}

# Check if method is deprecated
def is-deprecated [method_section: string]: nothing -> bool {
    ($method_section | str contains "deprecated" or 
     $method_section | str contains "Deprecated" or
     $method_section | str contains "@deprecated")
}

# Extract version information
def extract-version [content: string]: nothing -> string {
    let patterns = $SDK_PATTERNS
    let version_matches = ($content | parse --regex $patterns.version_pattern)
    
    if ($version_matches | length) > 0 {
        let match = ($version_matches | first)
        $"($match.capture0).($match.capture1).($match.capture2)"
    } else {
        ""
    }
}

# Extract API version
def extract-api-version [content: string]: nothing -> string {
    let patterns = $SDK_PATTERNS
    let api_matches = ($content | parse --regex $patterns.api_version_pattern)
    
    if ($api_matches | length) > 0 {
        $api_matches.capture0.0
    } else {
        ""
    }
}

# Extract return description
def extract-return-description [method_section: string]: nothing -> string {
    let lines = ($method_section | lines)
    let return_lines = ($lines | where ($it | str contains "Returns" or $it | str contains "return"))
    
    if ($return_lines | length) > 0 {
        $return_lines | first | str trim
    } else {
        ""
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Extract type definition
def extract-type-definition [
    content: string,
    type_name: string
]: nothing -> string {
    let lines = ($content | lines)
    let type_start = ($lines | enumerate | where ($it.item | str contains $type_name) | get index.0? | default (-1))
    
    if $type_start == -1 {
        return ""
    }
    
    # Extract a reasonable number of lines for the definition
    $lines | range $type_start..($type_start + 20) | str join "\n"
}

# Extract class definition
def extract-class-definition [
    content: string,
    class_name: string
]: nothing -> string {
    extract-type-definition $content $class_name
}

# Extract interface definition
def extract-interface-definition [
    content: string,
    interface_name: string
]: nothing -> string {
    extract-type-definition $content $interface_name
}

# Extract struct definition
def extract-struct-definition [
    content: string,
    struct_name: string
]: nothing -> string {
    extract-type-definition $content $struct_name
}

# Parse generic SDK documentation
def parse-generic-sdk [
    content: string,
    language: string,
    service: string
]: nothing -> record {
    let examples = extract-code-examples $content $language
    
    {
        language: $language,
        service: $service,
        methods: [],
        types: [],
        examples: $examples,
        sdk_version: (extract-version $content),
        api_version: (extract-api-version $content),
        raw_content: $content
    }
}

# ============================================================================
# CROSS-LANGUAGE COMPARISON
# ============================================================================

# Compare method implementations across languages
export def compare-sdk-methods [
    method_docs: list<record>
]: nothing -> record {
    let grouped = ($method_docs | group-by name)
    
    $grouped | transpose key value | each { |group|
        let method_name = $group.key
        let implementations = $group.value
        
        {
            method_name: $method_name,
            languages: ($implementations | get language),
            parameter_consistency: (check-parameter-consistency $implementations),
            return_type_consistency: (check-return-type-consistency $implementations),
            description_similarity: (check-description-similarity $implementations)
        }
    }
}

# Check parameter consistency across languages
def check-parameter-consistency [implementations: list<record>]: nothing -> record {
    let all_params = ($implementations | get parameters | flatten | get name | uniq)
    
    {
        total_unique_parameters: ($all_params | length),
        consistent_across_all: ($implementations | all { |impl| 
            ($impl.parameters | get name | sort) == ($all_params | sort)
        })
    }
}

# Check return type consistency
def check-return-type-consistency [implementations: list<record>]: nothing -> bool {
    let return_types = ($implementations | get return_type | uniq)
    ($return_types | length) <= 2  # Allow for slight variations
}

# Check description similarity
def check-description-similarity [implementations: list<record>]: nothing -> float {
    let descriptions = ($implementations | get description)
    # Simple similarity check - could be more sophisticated
    let unique_descriptions = ($descriptions | uniq)
    if ($descriptions | length) > 0 {
        ($unique_descriptions | length) / ($descriptions | length) * 100.0
    } else {
        0.0
    }
}