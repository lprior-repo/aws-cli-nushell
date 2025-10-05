# AWS Edge Case Handler
#
# Comprehensive handler for edge cases and variations in AWS CLI help output.
# Implements fallback strategies, format detection, and robust parsing techniques
# following pure functional programming principles.

use utils/test_utils.nu
use aws_advanced_parser.nu

# ============================================================================
# EDGE CASE DETECTION PATTERNS
# ============================================================================

export const EDGE_CASE_PATTERNS = {
    # Format variation patterns
    old_format_marker: 'aws-cli/1\.',
    new_format_marker: 'aws-cli/2\.',
    json_output_marker: '\{\s*"[^"]+"\s*:',
    xml_output_marker: '<[^>]+>',
    table_output_marker: '\+[-+]+\+',
    
    # Service-specific variations
    s3_transfer_commands: '(cp|sync|mv|rm)',
    ec2_describe_variations: 'describe-[a-z-]+',
    lambda_invoke_variations: 'invoke(-async)?',
    
    # Documentation inconsistencies
    missing_description: '^$|^\\s*$',
    truncated_help: '\\.\\.\\.$',
    encoding_issues: '[^\x00-\x7F]',
    malformed_options: '--[a-zA-Z0-9-]*[^a-zA-Z0-9-]',
    
    # Parameter variations
    flag_without_description: '^\\s*--[a-zA-Z0-9-]+\\s*$',
    parameter_with_equals: '--[a-zA-Z0-9-]+=',
    shorthand_flags: '\\s+-[a-zA-Z]\\s+',
    deprecated_flags: '\\(deprecated\\)',
    
    # Output format inconsistencies
    mixed_case_sections: '[A-Z][a-z]+\\s+[A-Z][a-z]+',
    inconsistent_indentation: '^\\s{1,3}[^\\s]',
    tab_vs_spaces: '\\t',
    windows_line_endings: '\\r\\n',
    
    # Error patterns
    permission_denied: 'permission denied|access denied',
    network_error: 'network error|connection failed',
    invalid_region: 'invalid region|region not found',
    malformed_json: 'malformed json|invalid json',
    
    # Version-specific patterns
    beta_commands: '\\(beta\\)|\\[beta\\]',
    preview_commands: '\\(preview\\)|\\[preview\\]',
    experimental_flags: '--experimental',
    
    # Locale-specific variations
    non_english_text: '[^\x00-\x7F]+',
    date_formats: '\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}',
    number_formats: '\\d{1,3}(,\\d{3})*(\\.\\d+)?',
    
    # Platform-specific issues
    path_separators: '[\\\\|/]',
    case_sensitivity: '[A-Z]{2,}',
    shell_escaping: '[\\\\`$"]'
}

# ============================================================================
# FORMAT DETECTION AND CLASSIFICATION
# ============================================================================

# Detect AWS CLI version and format variations
export def detect-cli-format [
    help_text: string
]: nothing -> record {
    let patterns = $EDGE_CASE_PATTERNS
    
    let version_info = detect-cli-version $help_text
    let format_type = detect-output-format $help_text
    let encoding_issues = detect-encoding-issues $help_text
    let structure_issues = detect-structure-issues $help_text
    
    {
        version: $version_info,
        format_type: $format_type,
        encoding_issues: $encoding_issues,
        structure_issues: $structure_issues,
        complexity_score: (calculate-complexity-score $help_text),
        parsing_strategy: (recommend-parsing-strategy $version_info $format_type $structure_issues)
    }
}

# Detect AWS CLI version
def detect-cli-version [help_text: string]: nothing -> record {
    let patterns = $EDGE_CASE_PATTERNS
    
    let is_v1 = ($help_text =~ $patterns.old_format_marker)
    let is_v2 = ($help_text =~ $patterns.new_format_marker)
    
    # Extract version number
    let version_matches = ($help_text | parse --regex 'aws-cli/([0-9]+)\\.([0-9]+)\\.([0-9]+)')
    let version = if ($version_matches | length) > 0 {
        let match = ($version_matches | first)
        $"($match.capture0).($match.capture1).($match.capture2)"
    } else {
        "unknown"
    }
    
    {
        version: $version,
        major_version: (if $is_v2 { 2 } else if $is_v1 { 1 } else { 0 }),
        is_legacy: $is_v1,
        is_modern: $is_v2,
        beta_features: ($help_text =~ $patterns.beta_commands),
        preview_features: ($help_text =~ $patterns.preview_commands)
    }
}

# Detect output format type
def detect-output-format [help_text: string]: nothing -> string {
    let patterns = $EDGE_CASE_PATTERNS
    
    if ($help_text =~ $patterns.json_output_marker) {
        "json"
    } else if ($help_text =~ $patterns.xml_output_marker) {
        "xml"
    } else if ($help_text =~ $patterns.table_output_marker) {
        "table"
    } else {
        "text"
    }
}

# Detect encoding issues
def detect-encoding-issues [help_text: string]: nothing -> list<string> {
    let patterns = $EDGE_CASE_PATTERNS
    mut issues = []
    
    if ($help_text =~ $patterns.encoding_issues) {
        $issues = ($issues | append "non-ascii-characters")
    }
    
    if ($help_text =~ $patterns.windows_line_endings) {
        $issues = ($issues | append "windows-line-endings")
    }
    
    if ($help_text =~ $patterns.tab_vs_spaces) {
        $issues = ($issues | append "mixed-whitespace")
    }
    
    $issues
}

# Detect structure issues
def detect-structure-issues [help_text: string]: nothing -> list<string> {
    let patterns = $EDGE_CASE_PATTERNS
    mut issues = []
    
    if ($help_text =~ $patterns.inconsistent_indentation) {
        $issues = ($issues | append "inconsistent-indentation")
    }
    
    if ($help_text =~ $patterns.truncated_help) {
        $issues = ($issues | append "truncated-content")
    }
    
    if ($help_text =~ $patterns.malformed_options) {
        $issues = ($issues | append "malformed-options")
    }
    
    if ($help_text =~ $patterns.mixed_case_sections) {
        $issues = ($issues | append "inconsistent-casing")
    }
    
    $issues
}

# Calculate complexity score for parsing difficulty
def calculate-complexity-score [help_text: string]: nothing -> float {
    let base_score = 0.0
    let line_count = ($help_text | lines | length)
    let char_count = ($help_text | str length)
    
    mut complexity = $base_score
    
    # Size complexity
    $complexity = $complexity + ($line_count / 100.0)
    $complexity = $complexity + ($char_count / 10000.0)
    
    # Structure complexity
    let sections = ($help_text | str replace --all --regex '\n\n+' '\n' | lines | where ($it | str trim | str starts-with "AVAILABLE") | length)
    $complexity = $complexity + ($sections * 0.5)
    
    # Format inconsistencies
    let inconsistencies = (detect-structure-issues $help_text | length)
    $complexity = $complexity + ($inconsistencies * 1.0)
    
    # Encoding issues
    let encoding_problems = (detect-encoding-issues $help_text | length)
    $complexity = $complexity + ($encoding_problems * 2.0)
    
    ($complexity | math min 10.0)
}

# Recommend parsing strategy based on detected issues
def recommend-parsing-strategy [
    version_info: record,
    format_type: string,
    structure_issues: list<string>
]: nothing -> string {
    if ($structure_issues | length) > 3 {
        "minimal"
    } else if ($version_info.major_version == 1) {
        "legacy"
    } else if ($structure_issues | length) > 0 {
        "robust"
    } else {
        "standard"
    }
}

# ============================================================================
# ADAPTIVE PARSING STRATEGIES
# ============================================================================

# Parse with automatic strategy selection
export def parse-with-adaptive-strategy [
    help_text: string,
    context: record = {}
]: nothing -> record {
    let format_info = detect-cli-format $help_text
    let strategy = $format_info.parsing_strategy
    
    match $strategy {
        "minimal" => parse-minimal-safe $help_text $context,
        "legacy" => parse-legacy-format $help_text $context,
        "robust" => parse-with-error-recovery $help_text $context,
        "standard" => aws_advanced_parser parse-help-advanced $help_text $context,
        _ => parse-with-fallback-chain $help_text $context
    }
}

# Parse with minimal safe approach
def parse-minimal-safe [
    help_text: string,
    context: record
]: nothing -> record {
    let lines = ($help_text | lines)
    let description = extract-description-minimal $lines
    let basic_params = extract-parameters-minimal $lines
    
    {
        service: ($context.service? | default ""),
        command: ($context.command? | default ""),
        description: $description,
        synopsis: "",
        parameters: $basic_params,
        examples: [],
        output_schema: {},
        errors: [],
        metadata: {
            parsing_method: "minimal-safe",
            quality_score: 30.0,
            issues: ["complex-format-detected"]
        }
    }
}

# Parse legacy format (AWS CLI v1)
def parse-legacy-format [
    help_text: string,
    context: record
]: nothing -> record {
    let normalized_text = normalize-legacy-format $help_text
    
    # Use legacy-specific patterns
    let legacy_result = parse-with-legacy-patterns $normalized_text $context
    
    $legacy_result | upsert metadata {
        parsing_method: "legacy-v1",
        quality_score: 70.0,
        aws_cli_version: 1
    }
}

# Parse with error recovery mechanisms
def parse-with-error-recovery [
    help_text: string,
    context: record
]: nothing -> record {
    mut recovery_attempts = []
    
    # Attempt 1: Clean and retry
    try {
        let cleaned_text = clean-problematic-content $help_text
        let result = aws_advanced_parser parse-help-advanced $cleaned_text $context
        return ($result | upsert metadata {
            parsing_method: "error-recovery-cleaned",
            recovery_attempts: ["content-cleaning"]
        })
    } catch { |error|
        $recovery_attempts = ($recovery_attempts | append "content-cleaning-failed")
    }
    
    # Attempt 2: Section-by-section parsing
    try {
        let result = parse-section-by-section $help_text $context
        return ($result | upsert metadata {
            parsing_method: "error-recovery-sectional",
            recovery_attempts: $recovery_attempts
        })
    } catch { |error|
        $recovery_attempts = ($recovery_attempts | append "sectional-parsing-failed")
    }
    
    # Attempt 3: Line-by-line parsing
    try {
        let result = parse-line-by-line $help_text $context
        return ($result | upsert metadata {
            parsing_method: "error-recovery-line-by-line",
            recovery_attempts: $recovery_attempts
        })
    } catch { |error|
        $recovery_attempts = ($recovery_attempts | append "line-by-line-failed")
    }
    
    # Final fallback
    parse-minimal-safe $help_text $context | upsert metadata {
        parsing_method: "error-recovery-final-fallback",
        recovery_attempts: $recovery_attempts
    }
}

# Parse with complete fallback chain
def parse-with-fallback-chain [
    help_text: string,
    context: record
]: nothing -> record {
    let strategies = [
        "advanced",
        "legacy", 
        "cleaned",
        "sectional",
        "line-by-line",
        "minimal"
    ]
    
    mut last_error = ""
    
    for strategy in $strategies {
        try {
            let result = match $strategy {
                "advanced" => aws_advanced_parser parse-help-advanced $help_text $context,
                "legacy" => parse-legacy-format $help_text $context,
                "cleaned" => (aws_advanced_parser parse-help-advanced (clean-problematic-content $help_text) $context),
                "sectional" => parse-section-by-section $help_text $context,
                "line-by-line" => parse-line-by-line $help_text $context,
                "minimal" => parse-minimal-safe $help_text $context
            }
            
            return ($result | upsert metadata {
                parsing_method: $"fallback-($strategy)",
                fallback_level: ($strategies | enumerate | where $it.item == $strategy | get index.0)
            })
        } catch { |error|
            $last_error = $error.msg
            continue
        }
    }
    
    # If all strategies fail, return minimal result with errors
    {
        service: ($context.service? | default ""),
        command: ($context.command? | default ""),
        description: "Failed to parse help text",
        synopsis: "",
        parameters: [],
        examples: [],
        output_schema: {},
        errors: [],
        metadata: {
            parsing_method: "all-fallbacks-failed",
            last_error: $last_error,
            quality_score: 0.0
        }
    }
}

# ============================================================================
# CONTENT CLEANING AND NORMALIZATION
# ============================================================================

# Clean problematic content
def clean-problematic-content [help_text: string]: nothing -> string {
    $help_text
    | normalize-line-endings
    | fix-encoding-issues
    | normalize-whitespace
    | remove-malformed-sections
    | standardize-section-headers
}

# Normalize line endings
def normalize-line-endings [text: string]: nothing -> string {
    $text | str replace --all '\r\n' '\n' | str replace --all '\r' '\n'
}

# Fix encoding issues
def fix-encoding-issues [text: string]: nothing -> string {
    # Remove or replace non-ASCII characters
    $text | str replace --all --regex '[^\x00-\x7F]' ' '
}

# Normalize whitespace
def normalize-whitespace [text: string]: nothing -> string {
    $text 
    | str replace --all --regex '\t' '    '  # Convert tabs to spaces
    | str replace --all --regex '[ ]{2,}' '  '  # Normalize multiple spaces
    | str replace --all --regex '\n\n\n+' '\n\n'  # Normalize multiple newlines
}

# Remove malformed sections
def remove-malformed-sections [text: string]: nothing -> string {
    let lines = ($text | lines)
    let cleaned_lines = ($lines | each { |line|
        if ($line =~ $EDGE_CASE_PATTERNS.malformed_options) {
            ""  # Remove malformed option lines
        } else {
            $line
        }
    })
    
    $cleaned_lines | str join "\n"
}

# Standardize section headers
def standardize-section-headers [text: string]: nothing -> string {
    $text
    | str replace --all --regex '(?i)available services' 'AVAILABLE SERVICES'
    | str replace --all --regex '(?i)available commands' 'AVAILABLE COMMANDS'
    | str replace --all --regex '(?i)options' 'OPTIONS'
    | str replace --all --regex '(?i)examples?' 'EXAMPLES'
    | str replace --all --regex '(?i)description' 'DESCRIPTION'
    | str replace --all --regex '(?i)synopsis' 'SYNOPSIS'
}

# Normalize legacy format
def normalize-legacy-format [text: string]: nothing -> string {
    $text
    | str replace --all --regex 'Available Commands:' 'AVAILABLE COMMANDS'
    | str replace --all --regex 'Global Options:' 'GLOBAL OPTIONS'
    | str replace --all --regex 'Service-specific Options:' 'OPTIONS'
    | clean-problematic-content
}

# ============================================================================
# SPECIALIZED PARSING METHODS
# ============================================================================

# Parse section by section with error isolation
def parse-section-by-section [
    help_text: string,
    context: record
]: nothing -> record {
    let sections = split-into-sections $help_text
    
    mut result = {
        service: ($context.service? | default ""),
        command: ($context.command? | default ""),
        description: "",
        synopsis: "",
        parameters: [],
        examples: [],
        output_schema: {},
        errors: [],
        metadata: {}
    }
    
    for section in $sections {
        try {
            let section_result = parse-individual-section $section
            $result = merge-section-result $result $section_result
        } catch {
            # Continue with next section if one fails
            continue
        }
    }
    
    $result
}

# Split help text into logical sections
def split-into-sections [help_text: string]: nothing -> list<record> {
    let lines = ($help_text | lines)
    let section_headers = [
        "DESCRIPTION",
        "SYNOPSIS", 
        "AVAILABLE SERVICES",
        "AVAILABLE COMMANDS",
        "OPTIONS",
        "GLOBAL OPTIONS",
        "EXAMPLES",
        "OUTPUT",
        "ERRORS"
    ]
    
    mut sections = []
    mut current_section = null
    mut current_lines = []
    
    for line in $lines {
        let trimmed = ($line | str trim)
        let is_header = ($section_headers | any { |h| $trimmed == $h })
        
        if $is_header {
            # Save previous section
            if ($current_section != null) {
                $sections = ($sections | append {
                    type: $current_section,
                    content: ($current_lines | str join "\n")
                })
            }
            
            # Start new section
            $current_section = $trimmed
            $current_lines = [$line]
        } else {
            $current_lines = ($current_lines | append $line)
        }
    }
    
    # Add final section
    if ($current_section != null) {
        $sections = ($sections | append {
            type: $current_section,
            content: ($current_lines | str join "\n")
        })
    }
    
    $sections
}

# Parse individual section
def parse-individual-section [section: record]: nothing -> record {
    match $section.type {
        "DESCRIPTION" => { description: (extract-description-from-section $section.content) },
        "SYNOPSIS" => { synopsis: (extract-synopsis-from-section $section.content) },
        "OPTIONS" => { parameters: (extract-parameters-from-section $section.content) },
        "EXAMPLES" => { examples: (extract-examples-from-section $section.content) },
        _ => {}
    }
}

# Merge section results
def merge-section-result [
    main_result: record,
    section_result: record
]: nothing -> record {
    mut result = $main_result
    
    for key in ($section_result | columns) {
        $result = ($result | upsert $key ($section_result | get $key))
    }
    
    $result
}

# Parse line by line with maximum error tolerance
def parse-line-by-line [
    help_text: string,
    context: record
]: nothing -> record {
    let lines = ($help_text | lines)
    
    mut result = {
        service: ($context.service? | default ""),
        command: ($context.command? | default ""),
        description: "",
        synopsis: "",
        parameters: [],
        examples: [],
        output_schema: {},
        errors: [],
        metadata: { parsed_lines: 0, failed_lines: 0 }
    }
    
    mut parsed_lines = 0
    mut failed_lines = 0
    
    for line in $lines {
        try {
            let line_info = parse-single-line $line
            $result = merge-line-info $result $line_info
            $parsed_lines = $parsed_lines + 1
        } catch {
            $failed_lines = $failed_lines + 1
            continue
        }
    }
    
    $result | upsert metadata {
        parsing_method: "line-by-line",
        parsed_lines: $parsed_lines,
        failed_lines: $failed_lines,
        success_rate: ($parsed_lines / ($parsed_lines + $failed_lines) * 100.0)
    }
}

# Parse single line
def parse-single-line [line: string]: nothing -> record {
    let trimmed = ($line | str trim)
    
    if ($trimmed | str starts-with "--") {
        # This is likely a parameter
        { type: "parameter", content: $trimmed }
    } else if ($trimmed | str starts-with "aws ") {
        # This is likely an example
        { type: "example", content: $trimmed }
    } else if ($trimmed | str length) > 0 {
        # This is descriptive text
        { type: "description", content: $trimmed }
    } else {
        { type: "empty", content: "" }
    }
}

# Merge line information
def merge-line-info [
    result: record,
    line_info: record
]: nothing -> record {
    match $line_info.type {
        "parameter" => {
            let param = parse-basic-parameter $line_info.content
            $result | upsert parameters ($result.parameters | append $param)
        },
        "example" => {
            let example = { command: $line_info.content, description: "" }
            $result | upsert examples ($result.examples | append $example)
        },
        "description" => {
            let current_desc = $result.description
            let updated_desc = if ($current_desc | str length) > 0 {
                $current_desc + " " + $line_info.content
            } else {
                $line_info.content
            }
            $result | upsert description $updated_desc
        },
        _ => $result
    }
}

# ============================================================================
# MINIMAL EXTRACTION FUNCTIONS
# ============================================================================

# Extract description with minimal assumptions
def extract-description-minimal [lines: list<string>]: nothing -> string {
    $lines 
    | where ($it | str trim | str length) > 0
    | where not ($it | str starts-with "--")
    | where not ($it | str starts-with "aws ")
    | range 0..5  # Take first few lines
    | str join " "
    | str trim
}

# Extract parameters with minimal parsing
def extract-parameters-minimal [lines: list<string>]: nothing -> list<record> {
    $lines 
    | where ($it | str starts-with "--" or $it | str starts-with "  --")
    | each { |line| parse-basic-parameter $line }
    | where ($it.name | str length) > 0
}

# Parse basic parameter from line
def parse-basic-parameter [line: string]: nothing -> record {
    let trimmed = ($line | str trim)
    let parts = ($trimmed | split row " " | where ($it | str length) > 0)
    
    if ($parts | length) > 0 {
        let param_name = ($parts.0 | str replace "^--?" "")
        let description = ($parts | range 1.. | str join " ")
        
        {
            name: $param_name,
            type: "string",
            required: false,
            description: $description,
            default_value: null,
            choices: [],
            multiple: false,
            constraints: {}
        }
    } else {
        {
            name: "",
            type: "string", 
            required: false,
            description: "",
            default_value: null,
            choices: [],
            multiple: false,
            constraints: {}
        }
    }
}

# ============================================================================
# UTILITY FUNCTIONS FOR SECTION EXTRACTION
# ============================================================================

# Extract description from section content
def extract-description-from-section [content: string]: nothing -> string {
    let lines = ($content | lines)
    $lines 
    | range 1..  # Skip header
    | where ($it | str trim | str length) > 0
    | str join " "
    | str trim
}

# Extract synopsis from section content  
def extract-synopsis-from-section [content: string]: nothing -> string {
    let lines = ($content | lines)
    $lines 
    | range 1..  # Skip header
    | where ($it | str trim | str length) > 0
    | str join " "
    | str trim
}

# Extract parameters from section content
def extract-parameters-from-section [content: string]: nothing -> list<record> {
    let lines = ($content | lines)
    $lines 
    | range 1..  # Skip header
    | where ($it | str starts-with "--" or $it | str starts-with "  --")
    | each { |line| parse-basic-parameter $line }
}

# Extract examples from section content
def extract-examples-from-section [content: string]: nothing -> list<record> {
    let lines = ($content | lines)
    $lines 
    | range 1..  # Skip header
    | where ($it | str starts-with "aws ")
    | each { |line|
        {
            title: "",
            description: "",
            command: ($line | str trim),
            expected_output: ""
        }
    }
}

# ============================================================================
# VALIDATION AND RECOVERY
# ============================================================================

# Validate parsing result and suggest improvements
export def validate-parsing-result [
    result: record
]: nothing -> record {
    mut issues = []
    mut suggestions = []
    mut quality_score = 100.0
    
    # Check completeness
    if ($result.description | str length) == 0 {
        $issues = ($issues | append "missing-description")
        $quality_score = $quality_score - 20.0
    }
    
    if ($result.parameters | length) == 0 {
        $issues = ($issues | append "no-parameters-found")
        $quality_score = $quality_score - 10.0
    }
    
    if ($result.synopsis | str length) == 0 {
        $issues = ($issues | append "missing-synopsis")
        $quality_score = $quality_score - 15.0
    }
    
    # Check parameter quality
    let incomplete_params = ($result.parameters | where ($it.description | str length) == 0 | length)
    if $incomplete_params > 0 {
        $quality_score = $quality_score - ($incomplete_params * 5.0)
        $suggestions = ($suggestions | append "improve-parameter-descriptions")
    }
    
    # Check for edge case indicators
    if ("metadata" in $result) and ("parsing_method" in $result.metadata) {
        let method = $result.metadata.parsing_method
        if ($method | str contains "fallback" or $method | str contains "recovery") {
            $quality_score = $quality_score - 30.0
            $suggestions = ($suggestions | append "input-quality-improvement-needed")
        }
    }
    
    {
        issues: $issues,
        suggestions: $suggestions,
        quality_score: ($quality_score | math max 0.0),
        completeness_score: (calculate-completeness-score $result),
        reliability_score: (calculate-reliability-score $result)
    }
}

# Calculate completeness score
def calculate-completeness-score [result: record]: nothing -> float {
    mut score = 0.0
    let max_score = 100.0
    
    # Description (25 points)
    if ($result.description | str length) > 0 {
        $score = $score + 25.0
    }
    
    # Parameters (30 points)
    if ($result.parameters | length) > 0 {
        $score = $score + 30.0
    }
    
    # Synopsis (20 points)
    if ($result.synopsis | str length) > 0 {
        $score = $score + 20.0
    }
    
    # Examples (15 points)
    if ($result.examples | length) > 0 {
        $score = $score + 15.0
    }
    
    # Output schema (10 points)
    if not ($result.output_schema | is-empty) {
        $score = $score + 10.0
    }
    
    $score
}

# Calculate reliability score based on parsing method
def calculate-reliability-score [result: record]: nothing -> float {
    if not ("metadata" in $result) {
        return 50.0
    }
    
    let metadata = $result.metadata
    
    if not ("parsing_method" in $metadata) {
        return 60.0
    }
    
    match $metadata.parsing_method {
        $method if ($method | str contains "advanced") => 95.0,
        $method if ($method | str contains "standard") => 90.0,
        $method if ($method | str contains "legacy") => 80.0,
        $method if ($method | str contains "cleaned") => 75.0,
        $method if ($method | str contains "sectional") => 70.0,
        $method if ($method | str contains "line-by-line") => 60.0,
        $method if ($method | str contains "minimal") => 40.0,
        $method if ($method | str contains "fallback") => 30.0,
        _ => 50.0
    }
}

# ============================================================================
# EDGE CASE REPORTING
# ============================================================================

# Generate comprehensive edge case report
export def generate-edge-case-report [
    help_text: string,
    parsing_result: record
]: nothing -> record {
    let format_info = detect-cli-format $help_text
    let validation_result = validate-parsing-result $parsing_result
    
    {
        input_analysis: $format_info,
        parsing_result: $parsing_result,
        validation_result: $validation_result,
        recommendations: (generate-improvement-recommendations $format_info $validation_result),
        timestamp: (date now)
    }
}

# Generate improvement recommendations
def generate-improvement-recommendations [
    format_info: record,
    validation_result: record
]: nothing -> list<string> {
    mut recommendations = []
    
    if ($format_info.complexity_score > 7.0) {
        $recommendations = ($recommendations | append "Consider input preprocessing to reduce complexity")
    }
    
    if ($format_info.encoding_issues | length) > 0 {
        $recommendations = ($recommendations | append "Fix encoding issues in input text")
    }
    
    if ($format_info.structure_issues | length) > 0 {
        $recommendations = ($recommendations | append "Standardize input format structure")
    }
    
    if ($validation_result.quality_score < 70.0) {
        $recommendations = ($recommendations | append "Improve input quality or use more robust parsing")
    }
    
    if ($validation_result.completeness_score < 80.0) {
        $recommendations = ($recommendations | append "Enhance parsing to extract more complete information")
    }
    
    $recommendations
}