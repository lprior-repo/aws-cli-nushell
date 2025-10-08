# AWS OpenAPI Extractor - Usage Examples

This document demonstrates how to use the AWS OpenAPI Extractor with Nushell pipeline integration.

## Basic Usage

### Single Service Extraction

```nushell
# Extract stepfunctions service schema
use aws_openapi_extractor.nu *
main stepfunctions --output-dir ./schemas --validate

# Extract with specific version and no caching
main lambda --output-dir ./schemas --version "2015-03-31" --no-cache
```

### Batch Processing

```nushell
# Extract multiple services
use aws_openapi_extractor.nu *
batch ["stepfunctions", "s3", "dynamodb"] --output-dir ./schemas --validate

# Extract with error handling
batch ["stepfunctions", "nonexistent-service", "lambda"] --continue-on-error
```

## Nushell Pipeline Integration

### Schema Analysis Pipeline

```nushell
# Extract and analyze service operations
use aws_openapi_extractor.nu *

# Get stepfunctions schema and analyze operations
let spec = (fetch-service-spec "stepfunctions")
let operations = (extract-operations $spec)

# Show operation summary
$operations 
| select name http_method input_shape output_shape
| sort-by name
| table
```

### Error Analysis Pipeline

```nushell
# Extract and categorize errors
use aws_openapi_extractor.nu *

let spec = (fetch-service-spec "stepfunctions") 
let errors = (extract-errors $spec)

# Group errors by HTTP status
$errors 
| group-by http_status 
| transpose status errors
| each {|group| 
    {
        status: $group.status, 
        count: ($group.errors | length),
        retryable: ($group.errors | where retryable == true | length)
    }
}
| table
```

### Resource Discovery Pipeline

```nushell
# Discover and analyze resources from operations
use aws_openapi_extractor.nu *

let spec = (fetch-service-spec "s3")
let operations = (extract-operations $spec)
let resources = (infer-resources $operations)

# Show resource types and operations
$resources 
| each {|resource| 
    {
        name: $resource.name,
        type: $resource.type,
        operation_count: ($resource.operations | length),
        operations: ($resource.operations | str join ", ")
    }
}
| sort-by operation_count
| reverse
| table
```

### Pagination Analysis Pipeline

```nushell
# Analyze pagination patterns across services
use aws_openapi_extractor.nu *

["stepfunctions", "s3", "dynamodb"] 
| each {|service|
    let spec = (fetch-service-spec $service)
    let operations = (extract-operations $spec)
    
    $operations | each {|op|
        let pagination = (detect-pagination $op $spec)
        if $pagination.paginated {
            {
                service: $service,
                operation: $op.name,
                input_token: $pagination.input_token,
                output_token: $pagination.output_token,
                limit_key: $pagination.limit_key
            }
        }
    } | compact
} 
| flatten
| table
```

### Schema Validation Pipeline

```nushell
# Validate schemas across multiple services
use aws_openapi_extractor.nu *

["stepfunctions", "lambda", "s3"] 
| each {|service_name|
    try {
        let spec = (fetch-service-spec $service_name)
        let schema = (build-service-schema $service_name $spec)
        let validation = (validate-schema $schema)
        
        {
            service: $service_name,
            valid: $validation.valid,
            error_count: ($validation.errors | length),
            operations: ($schema.operations | length),
            errors: ($schema.errors | length),
            resources: ($schema.resources | length)
        }
    } catch { |err|
        {
            service: $service_name,
            valid: false,
            error: $err.msg,
            error_count: 1,
            operations: 0,
            errors: 0,
            resources: 0
        }
    }
}
| table
```

### Shape Type Analysis Pipeline

```nushell
# Analyze AWS shape types across services
use aws_openapi_extractor.nu *

let spec = (fetch-service-spec "stepfunctions")
let shapes = $spec.shapes

$shapes 
| items {|name, shape|
    let parsed = (parse-shape $shape $shapes)
    {
        name: $name,
        aws_type: ($shape.type? | default "unknown"),
        nushell_type: $parsed.type,
        constraints: ($parsed.constraints? | default {}),
        complex: ($parsed.type in ["record", "list"])
    }
}
| where complex == true
| sort-by aws_type
| table
```

### Cross-Service Comparison Pipeline

```nushell
# Compare service metadata across AWS services
use aws_openapi_extractor.nu *

["stepfunctions", "lambda", "s3", "dynamodb"]
| each {|service_name|
    try {
        let spec = (fetch-service-spec $service_name)
        let schema = (build-service-schema $service_name $spec)
        
        {
            service: $service_name,
            api_version: $schema.metadata.api_version,
            protocol: $schema.metadata.protocol,
            operations: ($schema.operations | length),
            error_types: ($schema.errors | length),
            has_pagination: ($schema.operations | any {|op| (detect-pagination $op $spec).paginated})
        }
    } catch { |err|
        {service: $service_name, error: $err.msg}
    }
}
| table
```

## Advanced Patterns

### Schema Generation with Custom Filtering

```nushell
# Generate schemas only for CRUD operations
use aws_openapi_extractor.nu *

def extract-crud-only [service_name: string] {
    let spec = (fetch-service-spec $service_name)
    let all_operations = (extract-operations $spec)
    
    # Filter for CRUD operations only
    let crud_operations = $all_operations | where {|op|
        $op.name | str starts-with any of ["create", "delete", "update", "describe", "get", "put"]
    }
    
    # Build schema with filtered operations
    {
        service: $service_name,
        operations: $crud_operations,
        metadata: $spec.metadata,
        operation_count: ($crud_operations | length)
    }
}

# Use the custom function
extract-crud-only "s3" | get operations | select name http_method | table
```

### Testing Framework Integration

```nushell
# Use with nutest framework for testing
use nutest/nutest/mod.nu

# Run extractor tests
mod run-tests --path tests/ --match-suites 'test_aws_openapi_extractor' --display terminal --returns summary

# Run specific test categories
mod run-tests --path tests/ --match-tests 'test.*parse.*shape' --display terminal
```

## Error Handling Patterns

```nushell
# Robust error handling in pipelines
use aws_openapi_extractor.nu *

def safe-extract [service_name: string] {
    try {
        let spec = (fetch-service-spec $service_name --use-cache)
        let schema = (build-service-schema $service_name $spec)
        {status: "success", service: $service_name, schema: $schema}
    } catch { |err|
        {status: "error", service: $service_name, error: $err.msg}
    }
}

# Process multiple services safely
["stepfunctions", "invalid-service", "lambda"]
| each {|service| safe-extract $service}
| where status == "success" 
| get schema
| each {|schema| $schema.service}
```

## Performance Optimization

```nushell
# Cache-aware batch processing
use aws_openapi_extractor.nu *

# First run - downloads and caches
batch ["stepfunctions", "lambda"] --output-dir ./schemas

# Subsequent runs - uses cache
batch ["stepfunctions", "lambda", "s3"] --output-dir ./schemas  # Faster!

# Force refresh when needed
batch ["stepfunctions"] --no-cache --output-dir ./schemas
```

These examples demonstrate the power of combining the AWS OpenAPI Extractor with Nushell's pipeline system for advanced data processing and analysis workflows.