# AWS Documentation Extractor
#
# Advanced utilities for extracting detailed information from AWS CLI help documentation,
# including parameter validation rules, error codes, output schemas, and advanced parsing
# for complex documentation structures.

use utils/test_utils.nu

# ============================================================================
# ADVANCED PARAMETER EXTRACTION
# ============================================================================

# Extract parameter constraints and validation rules
export def extract-parameter-constraints [
    param_description: string
]: nothing -> record {
    mut constraints = {}
    
    # Extract min/max values
    let min_match = ($param_description | parse --regex '(?i)minimum.*?(\d+)')
    if ($min_match | length) > 0 {
        $constraints = ($constraints | upsert min_value ($min_match.capture0.0 | into int))
    }
    
    let max_match = ($param_description | parse --regex '(?i)maximum.*?(\d+)')
    if ($max_match | length) > 0 {
        $constraints = ($constraints | upsert max_value ($max_match.capture0.0 | into int))
    }
    
    # Extract length constraints
    let min_length_match = ($param_description | parse --regex '(?i)minimum length.*?(\d+)')
    if ($min_length_match | length) > 0 {
        $constraints = ($constraints | upsert min_length ($min_length_match.capture0.0 | into int))
    }
    
    let max_length_match = ($param_description | parse --regex '(?i)maximum length.*?(\d+)')
    if ($max_length_match | length) > 0 {
        $constraints = ($constraints | upsert max_length ($max_length_match.capture0.0 | into int))
    }
    
    # Extract pattern constraints
    let pattern_match = ($param_description | parse --regex '(?i)pattern.*?([^\s]+)')
    if ($pattern_match | length) > 0 {
        $constraints = ($constraints | upsert pattern $pattern_match.capture0.0)
    }
    
    # Extract choice values
    let choices = extract-choice-values $param_description
    if ($choices | length) > 0 {
        $constraints = ($constraints | upsert choices $choices)
    }
    
    $constraints
}

# Extract choice values from parameter description
def extract-choice-values [description: string]: nothing -> list<string> {
    # Look for patterns like "Valid values: value1 | value2 | value3"
    let choice_patterns = [
        '(?i)valid values?:?\s*([^.]+)',
        '(?i)possible values?:?\s*([^.]+)',
        '(?i)allowed values?:?\s*([^.]+)',
        '\(([^)]*\|[^)]*)\)'
    ]
    
    mut choices = []
    
    for pattern in $choice_patterns {
        let matches = ($description | parse --regex $pattern)
        if ($matches | length) > 0 {
            let choice_text = $matches.capture0.0
            let extracted_choices = (
                $choice_text 
                | split row "|" 
                | each { |choice| $choice | str trim | str replace "^['\"]" "" | str replace "['\"]$" "" }
                | where ($it | str length) > 0
            )
            $choices = ($choices | append $extracted_choices | uniq)
        }
    }
    
    $choices
}

# ============================================================================
# ERROR CODE EXTRACTION
# ============================================================================

# Extract AWS error codes and descriptions from help text
export def extract-error-codes [
    help_text: string
]: nothing -> list<record> {
    let lines = ($help_text | lines)
    let errors_start = ($lines | enumerate | where $it.item =~ "(?i)errors" | get index.0? | default (-1))
    
    if $errors_start == -1 {
        return []
    }
    
    let errors_section = (
        $lines
        | range ($errors_start + 1)..
        | take while { |it| ($it | str trim | str starts-with "=") == false }
    )
    
    parse-error-section $errors_section
}

# Parse error section into structured records
def parse-error-section [lines: list<string>]: nothing -> list<record> {
    mut errors = []
    mut current_error = {}
    
    for line in $lines {
        let trimmed = ($line | str trim)
        
        # Check if this line starts with an error code pattern
        let error_match = ($trimmed | parse --regex '^([A-Z][a-zA-Z0-9]+(?:Exception|Error)?)')
        if ($error_match | length) > 0 {
            # Save previous error if exists
            if not ($current_error | is-empty) {
                $errors = ($errors | append $current_error)
            }
            
            # Start new error
            $current_error = {
                code: $error_match.capture0.0,
                description: ($trimmed | str replace $error_match.capture0.0 "" | str trim),
                http_status: null,
                retryable: false
            }
        } else if not ($current_error | is-empty) and ($trimmed | str length) > 0 {
            # Continue description
            let updated_desc = ($current_error.description + " " + $trimmed | str trim)
            $current_error = ($current_error | upsert description $updated_desc)
        } else if ($trimmed | str length) == 0 and not ($current_error | is-empty) {
            # End current error
            $errors = ($errors | append $current_error)
            $current_error = {}
        }
    }
    
    # Add final error if exists
    if not ($current_error | is-empty) {
        $errors = ($errors | append $current_error)
    }
    
    $errors
}

# ============================================================================
# OUTPUT SCHEMA EXTRACTION
# ============================================================================

# Extract output schema information from help text and examples
export def extract-output-schema [
    help_text: string,
    examples: list<record>
]: nothing -> record {
    # Try to extract schema from examples
    let schema_from_examples = extract-schema-from-examples $examples
    
    # Try to extract schema from output description
    let schema_from_description = extract-schema-from-description $help_text
    
    # Merge schemas
    merge-schemas $schema_from_examples $schema_from_description
}

# Extract schema from example outputs
def extract-schema-from-examples [examples: list<record>]: nothing -> record {
    mut schema = { type: "object", properties: {}, required: [] }
    
    for example in $examples {
        if ($example.expected_output | str starts-with "{") {
            try {
                let json_output = ($example.expected_output | from json)
                let extracted_schema = infer-schema-from-json $json_output
                $schema = (merge-json-schemas $schema $extracted_schema)
            } catch {
                continue
            }
        }
    }
    
    $schema
}

# Infer JSON schema from actual JSON data
def infer-schema-from-json [data: any]: nothing -> record {
    match ($data | describe) {
        "record" => {
            mut properties = {}
            mut required = []
            
            for key in ($data | columns) {
                let value = ($data | get $key)
                $properties = ($properties | upsert $key (infer-schema-from-json $value))
                $required = ($required | append $key)
            }
            
            {
                type: "object",
                properties: $properties,
                required: $required
            }
        },
        "list" => {
            let first_item = ($data | first | default {})
            {
                type: "array",
                items: (infer-schema-from-json $first_item)
            }
        },
        "string" => { type: "string" },
        "int" => { type: "integer" },
        "float" => { type: "number" },
        "bool" => { type: "boolean" },
        _ => { type: "any" }
    }
}

# Extract schema from output description text
def extract-schema-from-description [help_text: string]: nothing -> record {
    let lines = ($help_text | lines)
    let output_start = ($lines | enumerate | where $it.item =~ "(?i)output" | get index.0? | default (-1))
    
    if $output_start == -1 {
        return { type: "object", properties: {}, required: [] }
    }
    
    let output_section = (
        $lines
        | range ($output_start + 1)..
        | take while { |it| ($it | str trim | str starts-with "=") == false }
    )
    
    parse-output-fields $output_section
}

# Parse output field descriptions
def parse-output-fields [lines: list<string>]: nothing -> record {
    mut properties = {}
    mut required = []
    
    for line in $lines {
        let trimmed = ($line | str trim)
        
        # Look for field patterns like "FieldName -> (type)"
        let field_match = ($trimmed | parse --regex '^([A-Za-z][A-Za-z0-9]*)\s*->\s*\(([^)]+)\)')
        if ($field_match | length) > 0 {
            let field_name = $field_match.capture0.0
            let field_type = map-aws-type-to-json-type $field_match.capture1.0
            
            $properties = ($properties | upsert $field_name { type: $field_type })
            
            # Check if field is marked as required
            if ($trimmed | str contains "(required)") {
                $required = ($required | append $field_name)
            }
        }
    }
    
    {
        type: "object",
        properties: $properties,
        required: $required
    }
}

# Map AWS CLI type names to JSON Schema types
def map-aws-type-to-json-type [aws_type: string]: nothing -> string {
    match ($aws_type | str downcase) {
        "string" => "string",
        "integer" => "integer",
        "long" => "integer",
        "double" => "number",
        "float" => "number",
        "boolean" => "boolean",
        "timestamp" => "string",
        "blob" => "string",
        "list" => "array",
        "map" => "object",
        "structure" => "object",
        _ => "string"
    }
}

# Merge two JSON schemas
def merge-json-schemas [schema1: record, schema2: record]: nothing -> record {
    mut merged = $schema1
    
    # Merge properties
    if "properties" in $schema2 {
        let merged_properties = ($merged.properties | merge $schema2.properties)
        $merged = ($merged | upsert properties $merged_properties)
    }
    
    # Merge required fields
    if "required" in $schema2 {
        let merged_required = ($merged.required | append $schema2.required | uniq)
        $merged = ($merged | upsert required $merged_required)
    }
    
    $merged
}

# ============================================================================
# ADVANCED DOCUMENTATION PATTERNS
# ============================================================================

# Extract shorthand parameter syntax
export def extract-shorthand-syntax [
    help_text: string
]: nothing -> list<record> {
    let lines = ($help_text | lines)
    let shorthand_patterns = []
    
    # Look for shorthand syntax examples
    let shorthand_lines = (
        $lines 
        | where ($it | str contains "Shorthand Syntax") 
        | append ($lines | where ($it | str contains "shorthand syntax"))
    )
    
    $shorthand_lines | each { |line|
        # Extract shorthand patterns
        let patterns = ($line | parse --regex '([A-Za-z0-9_]+)=([^,\s]+)')
        $patterns | each { |pattern|
            {
                parameter: $pattern.capture0,
                syntax: $pattern.capture1,
                description: ""
            }
        }
    } | flatten
}

# Extract CLI syntax variations
export def extract-syntax-variations [
    help_text: string
]: nothing -> list<record> {
    let lines = ($help_text | lines)
    let syntax_variations = []
    
    # Look for different ways to specify the same parameter
    let syntax_lines = ($lines | where ($it | str contains "aws "))
    
    $syntax_lines | each { |line|
        let command_match = ($line | parse --regex '(aws\s+[^\n]+)')
        if ($command_match | length) > 0 {
            {
                syntax: $command_match.capture0.0,
                type: "example",
                description: ""
            }
        } else {
            null
        }
    } | where $it != null
}

# ============================================================================
# REGION AND SERVICE AVAILABILITY
# ============================================================================

# Extract service availability information
export def extract-service-availability [
    service_name: string
]: nothing -> record {
    # This would typically require additional API calls or documentation sources
    # For now, return a placeholder structure
    {
        service: $service_name,
        global_availability: true,
        region_restrictions: [],
        partition_availability: {
            aws: true,
            aws_cn: false,
            aws_us_gov: true
        }
    }
}

# ============================================================================
# PAGINATION PATTERN EXTRACTION
# ============================================================================

# Extract pagination patterns from help text
export def extract-pagination-info [
    help_text: string,
    parameters: list<record>
]: nothing -> record {
    # Look for pagination-related parameters
    let pagination_params = (
        $parameters 
        | where ($it.name | str downcase) in ["next-token", "max-items", "page-size", "starting-token"]
    )
    
    let has_pagination = ($pagination_params | length) > 0
    
    {
        supports_pagination: $has_pagination,
        pagination_type: (if $has_pagination { "token-based" } else { "none" }),
        pagination_parameters: $pagination_params,
        default_page_size: null
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Merge multiple schemas into one
def merge-schemas [schema1: record, schema2: record]: nothing -> record {
    if ($schema1 | is-empty) {
        return $schema2
    }
    if ($schema2 | is-empty) {
        return $schema1
    }
    
    merge-json-schemas $schema1 $schema2
}

# Validate extracted documentation data
export def validate-extracted-data [
    data: record
]: nothing -> record {
    mut errors = []
    
    # Validate required fields exist
    let required_fields = ["service", "command", "parameters"]
    for field in $required_fields {
        if not ($field in $data) {
            $errors = ($errors | append $"Missing required field: ($field)")
        }
    }
    
    # Validate parameters structure
    if "parameters" in $data {
        for param in $data.parameters {
            if not ("name" in $param) {
                $errors = ($errors | append "Parameter missing name field")
            }
            if not ("type" in $param) {
                $errors = ($errors | append $"Parameter ($param.name? | default 'unknown') missing type field")
            }
        }
    }
    
    {
        valid: (($errors | length) == 0),
        errors: $errors,
        data_quality_score: (calculate-data-quality-score $data)
    }
}

# Calculate a quality score for extracted data
def calculate-data-quality-score [data: record]: nothing -> float {
    mut score = 0.0
    mut max_score = 0.0
    
    # Check description completeness
    $max_score = $max_score + 20.0
    if "description" in $data and ($data.description | str length) > 10 {
        $score = $score + 20.0
    }
    
    # Check parameter completeness
    $max_score = $max_score + 30.0
    if "parameters" in $data {
        let complete_params = (
            $data.parameters 
            | where ("name" in $it) and ("type" in $it) and ("description" in $it)
            | length
        )
        let total_params = ($data.parameters | length)
        if $total_params > 0 {
            $score = $score + (30.0 * $complete_params / $total_params)
        }
    }
    
    # Check examples availability
    $max_score = $max_score + 25.0
    if "examples" in $data and ($data.examples | length) > 0 {
        $score = $score + 25.0
    }
    
    # Check output schema availability
    $max_score = $max_score + 25.0
    if "output_schema" in $data and not ($data.output_schema | is-empty) {
        $score = $score + 25.0
    }
    
    if $max_score > 0 {
        $score / $max_score * 100.0
    } else {
        0.0
    }
}