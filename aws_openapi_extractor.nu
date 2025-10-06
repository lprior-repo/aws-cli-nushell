# AWS OpenAPI Schema Extractor
# Extracts and normalizes AWS service schemas from boto3/botocore OpenAPI specifications
# Following TDD methodology and pure functional programming principles

use std log

# ============================================================================
# CONFIGURATION
# ============================================================================

const BOTOCORE_BASE_URL = "https://raw.githubusercontent.com/boto/botocore/develop/botocore/data"

# Get cache directory (can't use const with env variable)
def get-cache-dir []: nothing -> string {
    $"($env.HOME)/.aws-openapi-cache"
}

# ============================================================================
# PHASE 2: CORE OPENAPI FETCHING
# ============================================================================

# Fetch AWS service OpenAPI specification from boto3/botocore GitHub repository
# REAL implementation: Fetches from actual GitHub repository
export def fetch-service-spec [
    service_name: string,       # AWS service name (e.g., "stepfunctions", "s3")
    --version: string = "",     # Specific version (defaults to latest)
    --use-cache                 # Use local cache if available
]: nothing -> record {
    # Construct the GitHub URL for the service specification
    let service_version = if $version == "" {
        (discover-latest-version $service_name)
    } else {
        $version
    }
    
    # Check cache first if enabled
    if $use_cache {
        let cache_file = (get-cache-path $service_name $service_version)
        if ($cache_file | path exists) {
            try {
                print $"Using cached spec for ($service_name)..."
                return (open $cache_file)
            } catch {
                print $"Cache file corrupted, fetching fresh..."
            }
        }
    }
    
    # Construct GitHub URL
    let github_url = $"($BOTOCORE_BASE_URL)/($service_name)/($service_version)/service-2.json"
    
    print $"Fetching ($service_name) spec from GitHub..."
    print $"URL: ($github_url)"
    
    try {
        # Fetch from GitHub
        let response = (http get $github_url)
        
        # Validate the response
        if not ("metadata" in ($response | columns)) {
            error make {
                msg: $"Invalid service specification for ($service_name)"
                label: {
                    text: "Missing metadata in specification"
                    span: (metadata $service_name).span
                }
            }
        }
        
        # Cache the response if caching is enabled
        if $use_cache {
            create-cache-dir
            let cache_file = (get-cache-path $service_name $service_version)
            $response | to json | save $cache_file
            print $"Cached spec to ($cache_file)"
        }
        
        return $response
        
    } catch { |err|
        # Handle HTTP errors gracefully
        if ($err.msg | str contains "404") {
            error make {
                msg: $"Service ($service_name) not found or version ($service_version) does not exist"
                label: {
                    text: "Service not available"
                    span: (metadata $service_name).span
                }
            }
        } else {
            error make {
                msg: $"Failed to fetch service specification: ($err.msg)"
                label: {
                    text: "Network or parsing error"
                    span: (metadata $service_name).span
                }
            }
        }
    }
}

# Discover the latest available version for a service
# REAL implementation: Fetches available versions from GitHub
export def discover-latest-version [
    service_name: string
]: nothing -> string {
    try {
        # Try to fetch the directory listing from GitHub API
        let api_url = $"https://api.github.com/repos/boto/botocore/contents/botocore/data/($service_name)"
        
        print $"Discovering versions for ($service_name)..."
        
        let response = (http get $api_url)
        
        # Extract version directories (they should be dates like "2016-11-23")
        let versions = $response 
            | where type == "dir" 
            | get name 
            | where {|name| $name =~ '\d{4}-\d{2}-\d{2}'}
            | sort
            | reverse
        
        if ($versions | is-empty) {
            # Fallback to common version pattern
            return "2016-11-23"
        }
        
        let latest = $versions | first
        print $"Latest version for ($service_name): ($latest)"
        return $latest
        
    } catch { |err|
        print $"Warning: Could not discover versions for ($service_name), using default"
        print $"Error: ($err.msg)"
        # Fallback to a reasonable default
        return "2016-11-23"
    }
}

# ============================================================================
# PHASE 3: SCHEMA PARSING 
# ============================================================================

# Extract operations from OpenAPI specification
# GREEN phase: Minimal implementation to make tests pass
export def extract-operations [
    spec: record                # OpenAPI specification
]: nothing -> list<record> {
    # Handle empty operations
    if ($spec.operations? | default {} | is-empty) {
        return []
    }
    
    # Extract operations with basic normalization
    $spec.operations | items {|name, op|
        {
            name: (to-kebab-case $name),
            original_name: $name,
            http_method: ($op.http?.method? | default "POST"),
            http_uri: ($op.http?.requestUri? | default "/"),
            input_shape: ($op.input?.shape? | default ""),
            output_shape: ($op.output?.shape? | default ""),
            errors: ($op.errors? | default [] | each {|e| $e.shape? | default ""}),
            documentation: ($op.documentation? | default ""),
            deprecated: ($op.deprecated? | default false)
        }
    }
}

# Parse AWS shape definition to Nushell type
# GREEN phase: Minimal implementation to make tests pass
export def parse-shape [
    shape: record,              # AWS shape definition
    all_shapes: record,         # All shapes for reference resolution
    --visited: list = []        # Track visited shapes to prevent infinite recursion
]: nothing -> record {
    let shape_type = $shape.type? | default "any"
    
    match $shape_type {
        "structure" => {
            let members = $shape.members? | default {}
            let required = $shape.required? | default []
            
            # Handle invalid members gracefully
            let parsed_members = if ($members | describe | str contains "record") {
                $members | items {|name, member_def|
                    let member_shape_name = $member_def.shape? | default "String"
                    
                    # Prevent infinite recursion for circular references
                    if $member_shape_name in $visited {
                        { name: $name, type: "any", circular_ref: true }
                    } else {
                        let member_shape = $all_shapes | get $member_shape_name -o | default { type: "string" }
                        let new_visited = $visited | append $member_shape_name
                        let parsed_member = (parse-shape $member_shape $all_shapes --visited $new_visited)
                        { name: $name, type: $parsed_member.type, required: ($name in $required) }
                    }
                }
            } else {
                []
            }
            
            {
                type: "record",
                members: $parsed_members,
                required: $required
            }
        }
        
        "list" => {
            let member = $shape.member? | default { shape: "String" }
            let member_shape_name = $member.shape? | default "String"
            let member_shape = $all_shapes | get $member_shape_name -o | default { type: "string" }
            let member_type = (parse-shape $member_shape $all_shapes --visited $visited)
            
            {
                type: "list",
                member_type: $member_type.type
            }
        }
        
        "map" => {
            let key = $shape.key? | default { shape: "String" }
            let value = $shape.value? | default { shape: "String" }
            let key_shape_name = $key.shape? | default "String"
            let value_shape_name = $value.shape? | default "String"
            let key_shape = $all_shapes | get $key_shape_name -o | default { type: "string" }
            let value_shape = $all_shapes | get $value_shape_name -o | default { type: "string" }
            let key_type = (parse-shape $key_shape $all_shapes --visited $visited)
            let value_type = (parse-shape $value_shape $all_shapes --visited $visited)
            
            {
                type: "record",
                key_type: $key_type.type,
                value_type: $value_type.type
            }
        }
        
        "string" => {
            let constraints = {
                min: ($shape.min? | default null),
                max: ($shape.max? | default null),
                pattern: ($shape.pattern? | default null),
                enum: ($shape.enum? | default null)
            }
            
            {
                type: "string",
                constraints: $constraints
            }
        }
        
        "integer" => {
            let constraints = {
                min: ($shape.min? | default null),
                max: ($shape.max? | default null)
            }
            
            {
                type: "int",
                constraints: $constraints
            }
        }
        
        "boolean" => {
            { type: "bool" }
        }
        
        "timestamp" => {
            { type: "datetime" }
        }
        
        "blob" => {
            { type: "binary" }
        }
        
        _ => {
            # Handle unknown types and missing types
            { type: "any" }
        }
    }
}

# Map AWS shape type to Nushell native type
# RED phase: Placeholder implementation
export def map-shape-type [
    aws_type: string            # AWS shape type
]: nothing -> any {
    error make {
        msg: "map-shape-type not implemented yet - TDD RED phase"
        label: {
            text: "Function intentionally unimplemented for TDD"
            span: (metadata $aws_type).span
        }
    }
}

# ============================================================================
# PHASE 4: ADVANCED FEATURES
# ============================================================================

# Detect pagination patterns in operations
# GREEN phase: Minimal implementation to make tests pass
export def detect-pagination [
    operation: record,          # Operation definition
    spec: record               # Full specification for context
]: nothing -> record {
    # Check if pagination is explicitly configured in spec
    let op_name = $operation.name
    let pagination_configs = $spec.pagination? | default {}
    if $op_name in ($pagination_configs | columns) {
        let pagination_config = $pagination_configs | get $op_name
        return {
            paginated: true,
            input_token: $pagination_config.input_token,
            output_token: $pagination_config.output_token,
            limit_key: $pagination_config.limit_key,
            result_key: $pagination_config.result_key
        }
    }
    
    # Check for standard pagination patterns
    let input_shape = $operation.input?.shape? | default ""
    let output_shape = $operation.output?.shape? | default ""
    
    if $input_shape == "" or $output_shape == "" {
        return { paginated: false }
    }
    
    # Look for NextToken/MaxResults pattern in shapes
    let shapes = $spec.shapes? | default {}
    let input_members = if $input_shape in ($shapes | columns) {
        $shapes | get $input_shape | get members? | default {}
    } else {
        {}
    }
    let output_members = if $output_shape in ($shapes | columns) {
        $shapes | get $output_shape | get members? | default {}
    } else {
        {}
    }
    
    let has_next_token_input = ("NextToken" in ($input_members | columns)) or ("nextToken" in ($input_members | columns))
    let has_max_results = ("MaxResults" in ($input_members | columns)) or ("maxResults" in ($input_members | columns))
    let has_next_token_output = ("NextToken" in ($output_members | columns)) or ("nextToken" in ($output_members | columns))
    
    if $has_next_token_input and $has_max_results and $has_next_token_output {
        return {
            paginated: true,
            input_token: "NextToken",
            output_token: "NextToken", 
            limit_key: "MaxResults",
            result_key: []
        }
    }
    
    return { paginated: false }
}

# Extract error definitions from specification
# GREEN phase: Minimal implementation to make tests pass
export def extract-errors [
    spec: record               # OpenAPI specification
]: nothing -> list<record> {
    let shapes = $spec.shapes? | default {}
    
    # Filter shapes that have exception flag set to true
    $shapes | items {|name, shape|
        if ($shape.exception? | default false) {
            {
                name: $name,
                http_status: ($shape.error?.httpStatusCode? | default 500),
                retryable: ($shape.retryable? | default {} | get throttling? | default false),
                description: ($shape.documentation? | default ""),
                sender_fault: ($shape.error?.senderFault? | default false)
            }
        } else {
            null
        }
    } | compact
}

# Infer resource types from operation patterns
# GREEN phase: Minimal implementation to make tests pass
export def infer-resources [
    operations: list<record>    # List of operations
]: nothing -> list<record> {
    if ($operations | is-empty) {
        return []
    }
    
    # Process list operations
    let list_resources = $operations 
        | where {|op| $op.name | str starts-with "list"}
        | each {|op| 
            let resource = $op.name | str substring 4..
            if $resource != "" {
                { name: $resource, type: "list_inferred", operations: [$op.name] }
            }
        } | compact
    
    # Process create operations  
    let create_resources = $operations 
        | where {|op| $op.name | str starts-with "create"}
        | each {|op|
            let resource = $op.name | str substring 6..
            if $resource != "" {
                { name: $resource, type: "crud_inferred", operations: [$op.name] }
            }
        } | compact
        
    # Process describe operations
    let describe_resources = $operations 
        | where {|op| $op.name | str starts-with "describe"}
        | each {|op|
            let resource = $op.name | str substring 8..
            if $resource != "" {
                { name: $resource, type: "crud_inferred", operations: [$op.name] }
            }
        } | compact
        
    # Process update operations
    let update_resources = $operations 
        | where {|op| $op.name | str starts-with "update"}
        | each {|op|
            let resource = $op.name | str substring 6..
            if $resource != "" {
                { name: $resource, type: "crud_inferred", operations: [$op.name] }
            }
        } | compact
        
    # Process delete operations
    let delete_resources = $operations 
        | where {|op| $op.name | str starts-with "delete"}
        | each {|op|
            let resource = $op.name | str substring 6..
            if $resource != "" {
                { name: $resource, type: "crud_inferred", operations: [$op.name] }
            }
        } | compact
        
    # Process ARN operations
    let arn_resources = $operations 
        | where {|op| $op.name | str contains "arn"}
        | each {|op|
            let resource = $op.name | str replace "arn" "" | str replace "get" "" | str replace "describe" ""
            if $resource != "" {
                { name: $resource, type: "arn_inferred", operations: [$op.name] }
            }
        } | compact
    
    # Combine all results and remove duplicates
    [$list_resources, $create_resources, $describe_resources, $update_resources, $delete_resources, $arn_resources] 
        | flatten | uniq-by name
}

# ============================================================================
# PHASE 5: SCHEMA GENERATION
# ============================================================================

# Build complete normalized service schema
# GREEN phase: Minimal implementation to make tests pass
export def build-service-schema [
    service_name: string,       # Service name
    spec: record               # OpenAPI specification
]: nothing -> record {
    # Extract operations
    let operations = (extract-operations $spec)
    
    # Extract errors
    let errors = (extract-errors $spec)
    
    # Infer resources
    let resources = (infer-resources $operations)
    
    # Build normalized metadata
    let metadata = {
        api_version: ($spec.metadata?.apiVersion? | default "unknown"),
        protocol: ($spec.metadata?.protocol? | default "json"),
        service_full_name: ($spec.metadata?.serviceFullName? | default $service_name),
        endpoint_prefix: ($spec.metadata?.endpointPrefix? | default $service_name),
        signature_version: ($spec.metadata?.signatureVersion? | default "v4")
    }
    
    # Generate schema
    {
        service: $service_name,
        operations: $operations,
        errors: $errors,
        resources: $resources,
        metadata: $metadata,
        generated_at: (date now | format date "%Y-%m-%dT%H:%M:%SZ"),
        schema_version: "1.0.0",
        extractor_version: "1.0.0"
    }
}

# Save service schema to filesystem
# GREEN phase: Minimal implementation to make tests pass
export def save-service-schema [
    schema: record,            # Normalized schema
    output_dir: string,        # Output directory
    service_name: string       # Service name for filename
]: nothing -> nothing {
    # Create output directory if it doesn't exist
    if not ($output_dir | path exists) {
        mkdir $output_dir
    }
    
    # Generate output file path
    let output_file = $"($output_dir)/($service_name).json"
    
    # Save schema as JSON
    $schema | to json | save -f $output_file
}

# ============================================================================
# PHASE 6: VALIDATION AND QUALITY
# ============================================================================

# Validate generated schema for completeness and correctness
# GREEN phase: Minimal implementation to make tests pass
export def validate-schema [
    schema: record             # Schema to validate
]: nothing -> record {
    mut errors = []
    
    # Check required top-level fields
    let required_fields = ["service", "operations", "metadata"]
    for field in $required_fields {
        if not ($field in ($schema | columns)) {
            $errors = ($errors | append $"Missing required field: ($field)")
        }
    }
    
    # Validate operations if present
    if "operations" in ($schema | columns) {
        let operations = $schema.operations
        if ($operations | describe | str contains "list") or ($operations | describe | str contains "table") {
            for operation in $operations {
                let required_op_fields = ["name", "original_name", "http_method", "http_uri"]
                for field in $required_op_fields {
                    if not ($field in ($operation | columns)) {
                        $errors = ($errors | append $"Operation missing required field: ($field)")
                    }
                }
            }
        }
    }
    
    # Validate errors format if present
    if "errors" in ($schema | columns) {
        let schema_errors = $schema.errors
        if ($schema_errors | describe | str contains "list") or ($schema_errors | describe | str contains "table") {
            for error in $schema_errors {
                let required_error_fields = ["name", "http_status"]
                for field in $required_error_fields {
                    if not ($field in ($error | columns)) {
                        $errors = ($errors | append $"Error missing required field: ($field)")
                    }
                }
            }
        }
    }
    
    # Return validation result
    {
        valid: (($errors | length) == 0),
        errors: $errors
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Create cache directory if it doesn't exist
def create-cache-dir []: nothing -> nothing {
    let cache_dir = (get-cache-dir)
    if not ($cache_dir | path exists) {
        mkdir $cache_dir
    }
}

# Generate cache file path for service and version
def get-cache-path [
    service_name: string,
    version: string
]: nothing -> string {
    let cache_dir = (get-cache-dir)
    $"($cache_dir)/($service_name)-($version)-service-2.json"
}

# Convert operation name to kebab-case
def to-kebab-case [
    name: string
]: nothing -> string {
    $name
    | str replace -r "([A-Z])" "-$1" 
    | str downcase 
    | str trim -l -c "-"
}

# ============================================================================
# MAIN ENTRY POINTS
# ============================================================================

# Extract schema for a single AWS service
export def main [
    service_name: string,                    # AWS service name
    --output-dir: string = "./schemas",     # Output directory
    --version: string = "",                 # Specific version (default: latest)
    --no-cache,                            # Disable caching
    --validate                             # Validate generated schema
] {
    print $"Extracting OpenAPI schema for ($service_name)..."
    
    try {
        # Following TDD - these will fail until implementation is complete
        let spec = if $no_cache {
            fetch-service-spec $service_name --version $version
        } else {
            fetch-service-spec $service_name --version $version --use-cache
        }
        let schema = (build-service-schema $service_name $spec)
        
        if $validate {
            let validation = (validate-schema $schema)
            if not $validation.valid {
                error make { msg: $"Schema validation failed: ($validation.errors)" }
            }
        }
        
        save-service-schema $schema $output_dir $service_name
        print $"✓ Schema extracted and saved to ($output_dir)/($service_name).json"
        
    } catch { |err|
        print $"✗ Failed to extract schema for ($service_name): ($err.msg)"
        exit 1
    }
}

# Extract schemas for multiple AWS services
export def batch [
    service_names: list<string>,            # List of AWS service names
    --output-dir: string = "./schemas",     # Output directory  
    --no-cache,                            # Disable caching
    --validate,                            # Validate generated schemas
    --continue-on-error                    # Continue processing if one service fails
] {
    print $"Extracting OpenAPI schemas for ($service_names | length) services..."
    
    let results = $service_names | each { |service|
        try {
            if $no_cache and $validate {
                main $service --output-dir $output_dir --no-cache --validate
            } else if $no_cache {
                main $service --output-dir $output_dir --no-cache
            } else if $validate {
                main $service --output-dir $output_dir --validate
            } else {
                main $service --output-dir $output_dir
            }
            { service: $service, status: "success" }
        } catch { |err|
            print $"✗ Failed to extract schema for ($service): ($err.msg)"
            if not $continue_on_error {
                exit 1
            }
            { service: $service, status: "failed", error: $err.msg }
        }
    }
    
    let successful = ($results | where status == "success" | length)
    let failed = ($results | where status == "failed" | length)
    
    print ""
    print $"Batch extraction complete:"
    print $"  ✓ Successful: ($successful)"
    print $"  ✗ Failed: ($failed)"
    
    if $failed > 0 and not $continue_on_error {
        exit 1
    }
}