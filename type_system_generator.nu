# Type System Generator - AWS to Nushell Type Mapping System
# Pure functional implementation following TDD principles

# =====================================================
# CORE TYPE MAPPING FUNCTIONS (Pure)
# =====================================================

# Map AWS primitive type to Nushell type equivalent
def map_aws_primitive_type [aws_type: record] {
    let type_name = $aws_type.type
    
    match $type_name {
        "string" => {
            nushell_type: "string",
            validator: "validate_string",
            coercer: "coerce_to_string"
        },
        "integer" => {
            nushell_type: "int", 
            validator: "validate_integer",
            coercer: "coerce_to_int"
        },
        "boolean" => {
            nushell_type: "bool",
            validator: "validate_boolean", 
            coercer: "coerce_to_bool"
        },
        "double" | "float" => {
            nushell_type: "float",
            validator: "validate_float",
            coercer: "coerce_to_float"
        },
        "long" => {
            nushell_type: "int",
            validator: "validate_integer",
            coercer: "coerce_to_int"
        },
        "timestamp" => {
            nushell_type: "datetime",
            validator: "validate_datetime",
            coercer: "coerce_to_datetime"
        },
        "blob" => {
            nushell_type: "binary",
            validator: "validate_binary",
            coercer: "coerce_to_binary"
        },
        _ => {
            nushell_type: "any",
            validator: "validate_any",
            coercer: "coerce_to_any"
        }
    }
}

# Map AWS structure type to Nushell record
def map_aws_structure_type [aws_type: record, shapes: record] {
    let field_mappings = (
        $aws_type.members 
        | items { |key, value| { name: $key, spec: $value } }
        | each { |field_info|
            let field_name = $field_info.name
            let field_spec = $field_info.spec
            let shape_name = $field_spec.shape
            let shape_def = ($shapes | get $shape_name)
            let field_mapping = (map_aws_type_to_nushell $shape_def --shapes $shapes)
            
            [$field_name, $field_mapping]
        }
        | into record
    )
    
    {
        nushell_type: "record",
        fields: $field_mappings,
        validator: "validate_record",
        coercer: "coerce_to_record"
    }
}

# Map AWS list type to Nushell list  
def map_aws_list_type [aws_type: record, shapes: record] {
    let member_shape = $aws_type.member.shape
    let member_def = ($shapes | get $member_shape)
    let element_mapping = (map_aws_type_to_nushell $member_def --shapes $shapes)
    
    {
        nushell_type: $"list<($element_mapping.nushell_type)>",
        element_type: $element_mapping,
        validator: "validate_list",
        coercer: "coerce_to_list"
    }
}

# Map AWS map type to Nushell record
def map_aws_map_type [aws_type: record, shapes: record] {
    let key_shape = $aws_type.key.shape
    let value_shape = $aws_type.value.shape
    let key_def = ($shapes | get $key_shape)
    let value_def = ($shapes | get $value_shape)
    
    let key_mapping = (map_aws_type_to_nushell $key_def --shapes $shapes)
    let value_mapping = (map_aws_type_to_nushell $value_def --shapes $shapes)
    
    {
        nushell_type: "record",
        key_type: $key_mapping,
        value_type: $value_mapping,
        validator: "validate_map",
        coercer: "coerce_to_map"
    }
}

# Internal function, will be exported separately

# =====================================================
# VALIDATION FUNCTIONS (Pure)
# =====================================================

# Internal function, will be exported separately

# =====================================================
# TYPE COERCION FUNCTIONS (Pure)
# =====================================================

# Internal function, will be exported separately

# =====================================================
# CONSTRAINT VALIDATION FUNCTIONS (Pure)
# =====================================================

# Internal function, will be exported separately

# =====================================================
# PERFORMANCE OPTIMIZATION (Pure) 
# =====================================================

# Internal function, will be exported separately

# =====================================================
# AWS SCHEMA PROCESSING (Imperative Shell)
# =====================================================

# Internal function, will be exported separately

# =====================================================
# EXPORTS (Public API)
# =====================================================

# Main functions for external use
export def main [] {
    print "AWS Type System Generator"
    print "========================"
    print ""
    print "Available functions:"
    print "- map_aws_type_to_nushell: Convert AWS type to Nushell equivalent"
    print "- validate_type: Validate value against type definition" 
    print "- coerce_type: Convert value to target type"
    print "- validate_constraints: Validate AWS constraints"
    print "- process_aws_schema: Process complete AWS schema file"
    print "- create_validator_cache: Create optimized type cache"
}

# Export key functions
export def map_aws_type_to_nushell [
    aws_type: record,
    --shapes: record = {}
] {
    let type_name = $aws_type.type
    
    match $type_name {
        "structure" => (map_aws_structure_type $aws_type $shapes),
        "list" => (map_aws_list_type $aws_type $shapes),
        "map" => (map_aws_map_type $aws_type $shapes),
        _ => (map_aws_primitive_type $aws_type)
    }
}

export def validate_type [value: any, type_mapping: record] {
    let nushell_type = $type_mapping.nushell_type
    let actual_type = ($value | describe)
    
    match $nushell_type {
        "string" => {
            if ($actual_type == "string") {
                { valid: true, value: $value }
            } else {
                { valid: false, error: $"Expected string, got ($actual_type)" }
            }
        },
        "int" => {
            if ($actual_type == "int") {
                { valid: true, value: $value }
            } else {
                { valid: false, error: $"Expected int, got ($actual_type)" }
            }
        },
        "bool" => {
            if ($actual_type == "bool") {
                { valid: true, value: $value }
            } else {
                { valid: false, error: $"Expected bool, got ($actual_type)" }
            }
        },
        "float" => {
            if ($actual_type in ["float", "int"]) {
                { valid: true, value: $value }
            } else {
                { valid: false, error: $"Expected float, got ($actual_type)" }
            }
        },
        "record" => {
            if ($actual_type == "record") {
                { valid: true, value: $value }
            } else {
                { valid: false, error: $"Expected record, got ($actual_type)" }
            }
        },
        _ => {
            if ($nushell_type | str starts-with "list<") {
                if ($actual_type == "list") {
                    { valid: true, value: $value }
                } else {
                    { valid: false, error: $"Expected list, got ($actual_type)" }
                }
            } else {
                { valid: true, value: $value }
            }
        }
    }
}

export def coerce_type [value: any, type_mapping: record] {
    let target_type = $type_mapping.nushell_type
    let source_type = ($value | describe)
    
    try {
        match $target_type {
            "string" => {
                { success: true, value: ($value | into string) }
            },
            "int" => {
                if ($source_type == "string") {
                    let parsed = ($value | into int)
                    { success: true, value: $parsed }
                } else {
                    { success: true, value: ($value | into int) }
                }
            },
            "bool" => {
                { success: true, value: ($value | into bool) }
            },
            "float" => {
                { success: true, value: ($value | into float) }
            },
            _ => {
                { success: true, value: $value }
            }
        }
    } catch { |err|
        { success: false, error: $"Coercion failed: ($err.msg)" }
    }
}

export def validate_constraints [value: any, type_mapping: record] {
    if ("constraints" not-in $type_mapping) {
        return { valid: true, value: $value }
    }
    
    let constraints = $type_mapping.constraints
    let type_name = $type_mapping.nushell_type
    
    # Validate numeric constraints (min/max)
    if ($type_name in ["int", "float"]) {
        if ("min" in $constraints) {
            if ($value < $constraints.min) {
                return { 
                    valid: false, 
                    error: $"Value ($value) is below minimum ($constraints.min)" 
                }
            }
        }
        
        if ("max" in $constraints) {
            if ($value > $constraints.max) {
                return { 
                    valid: false, 
                    error: $"Value ($value) is above maximum ($constraints.max)" 
                }
            }
        }
    }
    
    # Validate string pattern constraints
    if ($type_name == "string") {
        if ("pattern" in $constraints) {
            let pattern = $constraints.pattern
            if not ($value =~ $pattern) {
                return {
                    valid: false,
                    error: $"Value '($value)' does not match pattern '($pattern)'"
                }
            }
        }
        
        if ("minLength" in $constraints) {
            if (($value | str length) < $constraints.minLength) {
                return {
                    valid: false,
                    error: $"String length is below minimum ($constraints.minLength)"
                }
            }
        }
        
        if ("maxLength" in $constraints) {
            if (($value | str length) > $constraints.maxLength) {
                return {
                    valid: false, 
                    error: $"String length is above maximum ($constraints.maxLength)"
                }
            }
        }
    }
    
    # Validate list constraints
    if ($type_name | str starts-with "list<") {
        if ("minItems" in $constraints) {
            if (($value | length) < $constraints.minItems) {
                return {
                    valid: false,
                    error: $"List has fewer items than minimum ($constraints.minItems)"
                }
            }
        }
        
        if ("maxItems" in $constraints) {
            if (($value | length) > $constraints.maxItems) {
                return {
                    valid: false,
                    error: $"List has more items than maximum ($constraints.maxItems)"
                }
            }
        }
    }
    
    { valid: true, value: $value }
}

export def process_aws_schema [schema_path: string] {
    if not ($schema_path | path exists) {
        error make {
            msg: $"Schema file not found: ($schema_path)"
        }
    }
    
    let schema = (open $schema_path)
    
    # Extract service name - different schemas have different structures
    let service = if ("service" in $schema) {
        $schema.service
    } else if ("metadata" in $schema and "endpointPrefix" in $schema.metadata) {
        $schema.metadata.endpointPrefix
    } else {
        ($schema_path | path basename | path parse | get stem)
    }
    
    # Process shapes if available (EC2 style)
    let processed_types = if ("shapes" in $schema) {
        create_validator_cache $schema.shapes
    } else {
        {}
    }
    
    # Return processed schema information
    {
        service: $service,
        types: $processed_types,
        operations: ($schema.operations? | default []),
        schema_path: $schema_path
    }
}

export def create_validator_cache [types: record] {
    $types 
    | items { |key, value| { name: $key, def: $value } }
    | each { |type_entry|
        let type_name = $type_entry.name
        let type_def = $type_entry.def
        
        # Safe mapping with error handling for circular references
        let mapped = try {
            map_aws_type_to_nushell $type_def --shapes $types
        } catch {
            # Fallback for complex/circular types
            {
                nushell_type: "any",
                validator: "validate_any",
                coercer: "coerce_to_any",
                error: "circular_reference_or_complex_type"
            }
        }
        [$type_name, $mapped]
    }
    | into record
}