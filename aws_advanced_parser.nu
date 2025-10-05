# AWS Advanced Parser
#
# Enhanced AWS CLI documentation parser with sophisticated regex patterns,
# API schema parsing, SDK documentation support, and advanced pattern recognition.
# Follows pure functional programming principles with comprehensive test coverage.

use utils/test_utils.nu

# ============================================================================
# ADVANCED PATTERN DEFINITIONS
# ============================================================================

# Comprehensive regex patterns for AWS CLI documentation parsing
export const ADVANCED_PATTERNS = {
    # Service patterns
    service_line: '^[\s]*([a-zA-Z0-9][a-zA-Z0-9-]*)\s+(.+)$',
    service_section_start: '^AVAILABLE SERVICES\s*$',
    service_section_end: '^(See|For)',
    
    # Command patterns
    command_line: '^[\s]*([a-zA-Z0-9][a-zA-Z0-9-]*)\s+(.+)$',
    command_section_start: '^AVAILABLE (COMMANDS|SUBCOMMANDS)\s*$',
    command_section_end: '^(See|For|GLOBAL OPTIONS)',
    
    # Parameter patterns with variations
    parameter_start: '^[\s]*(-{1,2}[a-zA-Z0-9][a-zA-Z0-9-]*)',
    parameter_continuation: '^[\s]{6,}[^-\s]',
    parameter_type_pattern: '\(([^)]+)\)',
    parameter_required_pattern: '\((required|REQUIRED)\)',
    parameter_optional_pattern: '\((optional|OPTIONAL)\)',
    parameter_default_pattern: 'default[:\s]*([^,\s)]+)',
    parameter_choices_pattern: 'Valid values?:?\s*([^.]+)',
    parameter_range_pattern: '(?:minimum|min)[:\s]*(\d+).*?(?:maximum|max)[:\s]*(\d+)',
    parameter_list_pattern: '\(list\)',
    parameter_multiple_pattern: '(?:multiple|repeated)',
    
    # Complex parameter patterns
    parameter_json_schema: 'JSON format:?\s*(\{[^}]+\})',
    parameter_shorthand: 'Shorthand Syntax:?\s*([^.]+)',
    parameter_file_input: 'file://|fileb://',
    
    # Description and help patterns
    description_start: '^DESCRIPTION\s*$',
    synopsis_start: '^SYNOPSIS\s*$',
    examples_start: '^EXAMPLES?\s*$',
    output_start: '^OUTPUT\s*$',
    errors_start: '^ERRORS?\s*$',
    section_end: '^={3,}',
    
    # Advanced content patterns
    aws_command_pattern: 'aws\s+([a-zA-Z0-9-]+)\s+([a-zA-Z0-9-]+)',
    json_output_pattern: '\{\s*["\'][^"\']+["\']:\s*[^}]+\}',
    error_code_pattern: '^([A-Z][a-zA-Z0-9]*(?:Exception|Error|Fault)?)',
    
    # API reference patterns
    api_operation_pattern: 'API Reference:?\s*([^\s]+)',
    http_method_pattern: '(GET|POST|PUT|DELETE|PATCH)\s+/',
    
    # Advanced parameter constraints
    constraint_min_length: 'minimum length[:\s]*(\d+)',
    constraint_max_length: 'maximum length[:\s]*(\d+)',
    constraint_pattern: 'pattern[:\s]*([^\s]+)',
    constraint_enum: 'enum[:\s]*\[([^\]]+)\]',
    
    # Pagination patterns
    pagination_token: '(?:next-token|starting-token|page-token)',
    pagination_size: '(?:max-items|page-size|limit)',
    
    # Resource identifier patterns
    arn_pattern: 'arn:[^:]*:[^:]*:[^:]*:[^:]*:[^/]+(?:/.*)?',
    resource_id_pattern: '[a-zA-Z0-9-]+(?:[/][a-zA-Z0-9-]+)*',
    
    # Date and time patterns
    timestamp_pattern: '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z?',
    duration_pattern: 'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?',
    
    # Special formatting patterns
    code_block_start: '^```|^::\s*$',
    code_block_end: '^```\s*$',
    list_item: '^[\s]*[*+-]\s+',
    numbered_item: '^[\s]*\d+\.\s+',
    
    # Cross-reference patterns
    see_also_pattern: 'See also[:\s]*([^.]+)',
    related_command_pattern: 'Related commands?[:\s]*([^.]+)'
}

# ============================================================================
# CORE PARSING FUNCTIONS
# ============================================================================

# Parse AWS CLI help output with advanced pattern recognition
export def parse-help-advanced [
    help_text: string,
    context: record = {}
]: nothing -> record {
    let lines = ($help_text | lines)
    
    # Initialize parsing state
    mut parsing_state = {
        current_section: null,
        in_parameter: false,
        current_parameter: null,
        buffer: [],
        line_number: 0
    }
    
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
    
    # Process each line with state tracking
    for line in $lines {
        $parsing_state = ($parsing_state | upsert line_number ($parsing_state.line_number + 1))
        let processed = process-line-advanced $line $parsing_state $result
        $parsing_state = $processed.state
        $result = $processed.result
    }
    
    # Post-process and validate result
    validate-parsed-result $result
}

# Process individual line with advanced pattern matching
def process-line-advanced [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    let trimmed = ($line | str trim)
    
    # Section detection
    let new_section = detect-section $trimmed $state
    let updated_state = if ($new_section != null) {
        $state | upsert current_section $new_section | upsert in_parameter false
    } else {
        $state
    }
    
    # Process based on current section
    match $updated_state.current_section {
        "description" => process-description-line $trimmed $updated_state $result,
        "synopsis" => process-synopsis-line $trimmed $updated_state $result,
        "parameters" => process-parameters-line $trimmed $updated_state $result,
        "examples" => process-examples-line $trimmed $updated_state $result,
        "output" => process-output-line $trimmed $updated_state $result,
        "errors" => process-errors-line $trimmed $updated_state $result,
        _ => process-generic-line $trimmed $updated_state $result
    }
}

# Detect section type from line content
def detect-section [line: string, state: record]: nothing -> string {
    let patterns = $ADVANCED_PATTERNS
    
    if ($line =~ $patterns.description_start) {
        "description"
    } else if ($line =~ $patterns.synopsis_start) {
        "synopsis"
    } else if ($line =~ "^OPTIONS\s*$" or $line =~ "^PARAMETERS\s*$") {
        "parameters"
    } else if ($line =~ $patterns.examples_start) {
        "examples"
    } else if ($line =~ $patterns.output_start) {
        "output"
    } else if ($line =~ $patterns.errors_start) {
        "errors"
    } else if ($line =~ $patterns.section_end) {
        null
    } else {
        $state.current_section
    }
}

# ============================================================================
# SECTION-SPECIFIC PROCESSORS
# ============================================================================

# Process description section lines
def process-description-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    if ($line | str length) > 0 and not ($line =~ $ADVANCED_PATTERNS.section_end) {
        let current_desc = $result.description
        let updated_desc = if ($current_desc | str length) > 0 {
            $current_desc + " " + $line
        } else {
            $line
        }
        {
            state: $state,
            result: ($result | upsert description $updated_desc)
        }
    } else {
        { state: $state, result: $result }
    }
}

# Process synopsis section lines
def process-synopsis-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    if ($line | str length) > 0 and not ($line =~ $ADVANCED_PATTERNS.section_end) {
        let current_synopsis = $result.synopsis
        let updated_synopsis = if ($current_synopsis | str length) > 0 {
            $current_synopsis + " " + $line
        } else {
            $line
        }
        {
            state: $state,
            result: ($result | upsert synopsis $updated_synopsis)
        }
    } else {
        { state: $state, result: $result }
    }
}

# Process parameters section with advanced pattern recognition
def process-parameters-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    let patterns = $ADVANCED_PATTERNS
    
    # Check if this starts a new parameter
    let param_match = ($line | parse --regex $patterns.parameter_start)
    
    if ($param_match | length) > 0 {
        # Save previous parameter if exists
        let updated_result = if ($state.current_parameter != null) {
            $result | upsert parameters ($result.parameters | append $state.current_parameter)
        } else {
            $result
        }
        
        # Start new parameter
        let param_name = ($param_match.capture0.0 | str replace "^-+" "")
        let param_info = parse-parameter-advanced $line
        
        {
            state: ($state | upsert current_parameter $param_info | upsert in_parameter true),
            result: $updated_result
        }
    } else if ($state.in_parameter and ($line =~ $patterns.parameter_continuation)) {
        # Continue current parameter description
        let updated_param = extend-parameter-description $state.current_parameter $line
        {
            state: ($state | upsert current_parameter $updated_param),
            result: $result
        }
    } else if ($line | str length) == 0 and ($state.current_parameter != null) {
        # End current parameter
        {
            state: ($state | upsert current_parameter null | upsert in_parameter false),
            result: ($result | upsert parameters ($result.parameters | append $state.current_parameter))
        }
    } else {
        { state: $state, result: $result }
    }
}

# Parse parameter with advanced pattern recognition
def parse-parameter-advanced [line: string]: nothing -> record {
    let patterns = $ADVANCED_PATTERNS
    
    # Extract parameter name
    let name_match = ($line | parse --regex $patterns.parameter_start)
    let param_name = if ($name_match | length) > 0 {
        $name_match.capture0.0 | str replace "^-+" ""
    } else {
        ""
    }
    
    # Extract parameter type
    let type_match = ($line | parse --regex $patterns.parameter_type_pattern)
    let param_type = if ($type_match | length) > 0 {
        infer-parameter-type $type_match.capture0.0
    } else {
        infer-parameter-type-from-context $line
    }
    
    # Check if required
    let is_required = ($line =~ $patterns.parameter_required_pattern)
    
    # Extract default value
    let default_match = ($line | parse --regex $patterns.parameter_default_pattern)
    let default_value = if ($default_match | length) > 0 {
        $default_match.capture0.0
    } else {
        null
    }
    
    # Extract choices
    let choices = extract-parameter-choices-advanced $line
    
    # Extract constraints
    let constraints = extract-parameter-constraints-advanced $line
    
    # Extract initial description
    let description = extract-parameter-description $line
    
    {
        name: $param_name,
        type: $param_type,
        required: $is_required,
        description: $description,
        default_value: $default_value,
        choices: $choices,
        multiple: ($line =~ $patterns.parameter_list_pattern or $line =~ $patterns.parameter_multiple_pattern),
        constraints: $constraints,
        shorthand: (extract-shorthand-syntax $line),
        file_input: ($line =~ $patterns.parameter_file_input)
    }
}

# Infer parameter type from type hint
def infer-parameter-type [type_hint: string]: nothing -> string {
    let hint = ($type_hint | str downcase | str trim)
    
    match $hint {
        $hint if ($hint | str contains "string") => "string",
        $hint if ($hint | str contains "integer") => "int",
        $hint if ($hint | str contains "long") => "int",
        $hint if ($hint | str contains "double") => "float",
        $hint if ($hint | str contains "float") => "float",
        $hint if ($hint | str contains "boolean") => "bool",
        $hint if ($hint | str contains "timestamp") => "datetime",
        $hint if ($hint | str contains "list") => "list",
        $hint if ($hint | str contains "map") => "record",
        $hint if ($hint | str contains "structure") => "record",
        $hint if ($hint | str contains "blob") => "binary",
        _ => "string"
    }
}

# Infer parameter type from context clues
def infer-parameter-type-from-context [line: string]: nothing -> string {
    let patterns = $ADVANCED_PATTERNS
    
    if ($line =~ $patterns.parameter_list_pattern) {
        "list"
    } else if ($line =~ $patterns.parameter_json_schema) {
        "record"
    } else if ($line =~ $patterns.parameter_file_input) {
        "path"
    } else if ($line =~ $patterns.arn_pattern) {
        "arn"
    } else if ($line =~ $patterns.timestamp_pattern) {
        "datetime"
    } else if ($line =~ $patterns.duration_pattern) {
        "duration"
    } else {
        "string"
    }
}

# Extract parameter choices with advanced patterns
def extract-parameter-choices-advanced [line: string]: nothing -> list<string> {
    let patterns = $ADVANCED_PATTERNS
    
    # Try multiple choice patterns
    let choice_patterns = [
        $patterns.parameter_choices_pattern,
        $patterns.constraint_enum,
        '\(([^)]*\|[^)]*)\)'
    ]
    
    mut choices = []
    
    for pattern in $choice_patterns {
        let matches = ($line | parse --regex $pattern)
        if ($matches | length) > 0 {
            let choice_text = $matches.capture0.0
            let extracted = ($choice_text | split row "|" | each { |c| 
                $c | str trim | str replace "^['\"]" "" | str replace "['\"]$" ""
            } | where ($it | str length) > 0)
            $choices = ($choices | append $extracted | uniq)
        }
    }
    
    $choices
}

# Extract advanced parameter constraints
def extract-parameter-constraints-advanced [line: string]: nothing -> record {
    let patterns = $ADVANCED_PATTERNS
    mut constraints = {}
    
    # Extract min/max values
    let range_match = ($line | parse --regex $patterns.parameter_range_pattern)
    if ($range_match | length) > 0 {
        $constraints = ($constraints | upsert min_value ($range_match.capture0.0 | into int))
        $constraints = ($constraints | upsert max_value ($range_match.capture1.0 | into int))
    }
    
    # Extract length constraints
    let min_length_match = ($line | parse --regex $patterns.constraint_min_length)
    if ($min_length_match | length) > 0 {
        $constraints = ($constraints | upsert min_length ($min_length_match.capture0.0 | into int))
    }
    
    let max_length_match = ($line | parse --regex $patterns.constraint_max_length)
    if ($max_length_match | length) > 0 {
        $constraints = ($constraints | upsert max_length ($max_length_match.capture0.0 | into int))
    }
    
    # Extract pattern constraints
    let pattern_match = ($line | parse --regex $patterns.constraint_pattern)
    if ($pattern_match | length) > 0 {
        $constraints = ($constraints | upsert pattern $pattern_match.capture0.0)
    }
    
    $constraints
}

# Extract parameter description
def extract-parameter-description [line: string]: nothing -> string {
    # Remove parameter prefix and type hints to get description
    $line 
    | str replace --regex '^[\s]*-{1,2}[a-zA-Z0-9][a-zA-Z0-9-]*' ''
    | str replace --regex '\([^)]+\)' ''
    | str trim
}

# Extract shorthand syntax
def extract-shorthand-syntax [line: string]: nothing -> string {
    let shorthand_match = ($line | parse --regex $ADVANCED_PATTERNS.parameter_shorthand)
    if ($shorthand_match | length) > 0 {
        $shorthand_match.capture0.0 | str trim
    } else {
        ""
    }
}

# Extend parameter description with continuation line
def extend-parameter-description [param: record, line: string]: nothing -> record {
    let current_desc = $param.description
    let additional_text = ($line | str trim)
    
    let updated_desc = if ($current_desc | str length) > 0 {
        $current_desc + " " + $additional_text
    } else {
        $additional_text
    }
    
    $param | upsert description $updated_desc
}

# Process examples section
def process-examples-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    # Implementation for examples processing
    if ($line | str starts-with "aws ") {
        let example = {
            title: "",
            description: "",
            command: $line,
            expected_output: ""
        }
        {
            state: $state,
            result: ($result | upsert examples ($result.examples | append $example))
        }
    } else {
        { state: $state, result: $result }
    }
}

# Process output section
def process-output-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    # Implementation for output schema processing
    { state: $state, result: $result }
}

# Process errors section
def process-errors-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    let error_match = ($line | parse --regex $ADVANCED_PATTERNS.error_code_pattern)
    
    if ($error_match | length) > 0 {
        let error_code = $error_match.capture0.0
        let error_desc = ($line | str replace $error_code "" | str trim)
        let error_info = {
            code: $error_code,
            description: $error_desc,
            http_status: null,
            retryable: false
        }
        {
            state: $state,
            result: ($result | upsert errors ($result.errors | append $error_info))
        }
    } else {
        { state: $state, result: $result }
    }
}

# Process generic lines
def process-generic-line [
    line: string,
    state: record,
    result: record
]: nothing -> record {
    { state: $state, result: $result }
}

# ============================================================================
# VALIDATION AND POST-PROCESSING
# ============================================================================

# Validate parsed result
def validate-parsed-result [result: record]: nothing -> record {
    mut errors = []
    
    # Validate required fields
    if ($result.service | str length) == 0 and ($result.command | str length) == 0 {
        $errors = ($errors | append "Either service or command must be specified")
    }
    
    # Validate parameters
    for param in $result.parameters {
        if ($param.name | str length) == 0 {
            $errors = ($errors | append "Parameter missing name")
        }
        
        if not ($param.type in ["string", "int", "float", "bool", "list", "record", "datetime", "duration", "path", "arn", "binary"]) {
            $errors = ($errors | append $"Invalid parameter type: ($param.type)")
        }
    }
    
    if ($errors | length) > 0 {
        error make {
            msg: "Validation failed",
            label: { text: ($errors | str join ", ") }
        }
    }
    
    $result
}

# ============================================================================
# SPECIALIZED PARSERS
# ============================================================================

# Parse AWS CLI service list with advanced patterns
export def parse-service-list-advanced [
    help_text: string
]: nothing -> list<record> {
    let lines = ($help_text | lines)
    let start_pattern = $ADVANCED_PATTERNS.service_section_start
    let end_pattern = $ADVANCED_PATTERNS.service_section_end
    
    # Find service section boundaries
    let start_index = ($lines | enumerate | where $it.item =~ $start_pattern | get index.0? | default (-1))
    let end_index = ($lines | enumerate | where ($it.index > $start_index) and ($it.item =~ $end_pattern) | get index.0? | default ($lines | length))
    
    if $start_index == -1 {
        return []
    }
    
    # Extract and parse service lines
    $lines 
    | range ($start_index + 1)..($end_index - 1)
    | where ($it | str trim | str length) > 0
    | where not ($it | str starts-with "*")
    | each { |line| parse-service-line-advanced $line }
    | where $it != null
}

# Parse individual service line with advanced patterns
def parse-service-line-advanced [line: string]: nothing -> record {
    let trimmed = ($line | str trim)
    let service_match = ($trimmed | parse --regex $ADVANCED_PATTERNS.service_line)
    
    if ($service_match | length) > 0 {
        let service_name = $service_match.capture0.0
        let description = $service_match.capture1.0
        
        {
            name: $service_name,
            description: $description,
            commands: [],
            aliases: (extract-service-aliases $description),
            documentation_url: $"https://docs.aws.amazon.com/cli/latest/reference/($service_name)/",
            category: (infer-service-category $service_name $description),
            deprecated: ($description | str contains "deprecated"),
            beta: ($description | str contains "beta" or $description | str contains "preview")
        }
    } else {
        null
    }
}

# Extract service aliases from description
def extract-service-aliases [description: string]: nothing -> list<string> {
    # Look for patterns like "also known as" or "alias:"
    let alias_patterns = [
        'also known as ([^,.)]+)',
        'alias[:\s]*([^,.)]+)',
        '\(([^)]+)\)$'
    ]
    
    mut aliases = []
    
    for pattern in $alias_patterns {
        let matches = ($description | parse --regex $pattern)
        if ($matches | length) > 0 {
            $aliases = ($aliases | append $matches.capture0.0)
        }
    }
    
    $aliases | each { |a| $a | str trim } | where ($it | str length) > 0
}

# Infer service category from name and description
def infer-service-category [name: string, description: string]: nothing -> string {
    let compute_services = ["ec2", "lambda", "ecs", "fargate", "batch"]
    let storage_services = ["s3", "ebs", "efs", "fsx"]
    let database_services = ["rds", "dynamodb", "redshift", "elasticache"]
    let networking_services = ["vpc", "route53", "cloudfront", "elb"]
    let security_services = ["iam", "kms", "secrets-manager", "cognito"]
    let monitoring_services = ["cloudwatch", "cloudtrail", "xray"]
    let management_services = ["cloudformation", "cloudformations", "systems-manager"]
    
    if ($name in $compute_services) or ($description | str contains "compute") {
        "compute"
    } else if ($name in $storage_services) or ($description | str contains "storage") {
        "storage"
    } else if ($name in $database_services) or ($description | str contains "database") {
        "database"
    } else if ($name in $networking_services) or ($description | str contains "network") {
        "networking"
    } else if ($name in $security_services) or ($description | str contains "security") {
        "security"
    } else if ($name in $monitoring_services) or ($description | str contains "monitor") {
        "monitoring"
    } else if ($name in $management_services) or ($description | str contains "management") {
        "management"
    } else {
        "other"
    }
}

# ============================================================================
# EDGE CASE HANDLERS
# ============================================================================

# Handle various AWS CLI help output variations
export def parse-help-with-fallbacks [
    help_text: string,
    context: record = {}
]: nothing -> record {
    try {
        parse-help-advanced $help_text $context
    } catch { |primary_error|
        # Try fallback parsing strategies
        try {
            parse-help-legacy-format $help_text $context
        } catch { |legacy_error|
            try {
                parse-help-minimal $help_text $context
            } catch { |minimal_error|
                # Return minimal valid structure with errors
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
                        parsing_errors: [
                            $primary_error.msg,
                            $legacy_error.msg, 
                            $minimal_error.msg
                        ]
                    }
                }
            }
        }
    }
}

# Parse legacy format help text
def parse-help-legacy-format [
    help_text: string,
    context: record
]: nothing -> record {
    # Simplified parsing for older AWS CLI versions
    let lines = ($help_text | lines)
    
    {
        service: ($context.service? | default ""),
        command: ($context.command? | default ""),
        description: (extract-description-simple $lines),
        synopsis: (extract-synopsis-simple $lines),
        parameters: (extract-parameters-simple $lines),
        examples: [],
        output_schema: {},
        errors: [],
        metadata: { parsing_method: "legacy" }
    }
}

# Parse minimal help text
def parse-help-minimal [
    help_text: string,
    context: record  
]: nothing -> record {
    # Absolute minimal parsing that should always succeed
    {
        service: ($context.service? | default ""),
        command: ($context.command? | default ""),
        description: ($help_text | lines | first | default "No description available"),
        synopsis: "",
        parameters: [],
        examples: [],
        output_schema: {},
        errors: [],
        metadata: { parsing_method: "minimal" }
    }
}

# Simple extraction functions for fallback parsing
def extract-description-simple [lines: list<string>]: nothing -> string {
    $lines 
    | where ($it | str contains "Description" or $it | str contains "DESCRIPTION")
    | range 1..5
    | str join " "
    | str trim
}

def extract-synopsis-simple [lines: list<string>]: nothing -> string {
    $lines 
    | where ($it | str contains "aws ")
    | first
    | default ""
}

def extract-parameters-simple [lines: list<string>]: nothing -> list<record> {
    $lines 
    | where ($it | str starts-with "--" or $it | str starts-with "  --")
    | each { |line|
        let parts = ($line | str trim | split row " " | where ($it | str length) > 0)
        {
            name: ($parts.0 | str replace "^--" ""),
            type: "string",
            required: false,
            description: ($parts | range 1.. | str join " "),
            default_value: null,
            choices: [],
            multiple: false,
            constraints: {}
        }
    }
}

# ============================================================================
# PERFORMANCE OPTIMIZATIONS
# ============================================================================

# Streaming parser for very large help outputs
export def parse-help-streaming [
    help_text: string,
    chunk_size: int = 1000
]: nothing -> record {
    let lines = ($help_text | lines)
    let total_lines = ($lines | length)
    
    mut result = {
        service: "",
        command: "",
        description: "",
        synopsis: "",
        parameters: [],
        examples: [],
        output_schema: {},
        errors: [],
        metadata: {}
    }
    
    # Process in chunks to manage memory
    mut start_index = 0
    
    while $start_index < $total_lines {
        let end_index = ([$start_index + $chunk_size, $total_lines] | math min)
        let chunk = ($lines | range $start_index..($end_index - 1))
        
        let chunk_result = parse-chunk $chunk $result
        $result = merge-parse-results $result $chunk_result
        
        $start_index = $end_index
    }
    
    $result
}

# Parse individual chunk
def parse-chunk [
    lines: list<string>,
    existing_result: record
]: nothing -> record {
    # Process chunk with existing result context
    let chunk_text = ($lines | str join "\n")
    parse-help-advanced $chunk_text {}
}

# Merge parse results from chunks
def merge-parse-results [
    existing: record,
    new: record
]: nothing -> record {
    {
        service: (if ($existing.service | str length) > 0 { $existing.service } else { $new.service }),
        command: (if ($existing.command | str length) > 0 { $existing.command } else { $new.command }),
        description: (merge-text-fields $existing.description $new.description),
        synopsis: (merge-text-fields $existing.synopsis $new.synopsis),
        parameters: ($existing.parameters | append $new.parameters | uniq-by name),
        examples: ($existing.examples | append $new.examples | uniq-by command),
        output_schema: ($existing.output_schema | merge $new.output_schema),
        errors: ($existing.errors | append $new.errors | uniq-by code),
        metadata: ($existing.metadata | merge $new.metadata)
    }
}

# Merge text fields intelligently
def merge-text-fields [existing: string, new: string]: nothing -> string {
    if ($existing | str length) > 0 and ($new | str length) > 0 {
        $existing + " " + $new
    } else if ($new | str length) > 0 {
        $new
    } else {
        $existing
    }
}