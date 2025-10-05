# AWS API Documentation Parser
#
# Comprehensive parser for AWS API documentation including JSON schemas,
# OpenAPI specifications, and AWS API reference documentation.
# Follows pure functional programming principles with Effect.ts-inspired patterns.

use utils/test_utils.nu
use aws_advanced_parser.nu

# ============================================================================
# TYPE DEFINITIONS FOR API PARSING
# ============================================================================

# AWS API specification structure
export def aws-api-spec []: nothing -> record {
    {
        version: "",
        service: "",
        protocol: "",
        endpoint_prefix: "",
        service_full_name: "",
        service_abbreviation: "",
        uid: "",
        operations: {},
        shapes: {},
        documentation: "",
        metadata: {}
    }
}

# API operation structure
export def api-operation []: nothing -> record {
    {
        name: "",
        http_method: "",
        http_request_uri: "",
        input_shape: "",
        output_shape: "",
        errors: [],
        documentation: "",
        deprecated: false,
        idempotent: false,
        pagination: {},
        auth_type: ""
    }
}

# API shape (data structure) definition
export def api-shape []: nothing -> record {
    {
        type: "",
        required: [],
        members: {},
        documentation: "",
        sensitive: false,
        deprecated: false,
        enum: [],
        pattern: "",
        min: null,
        max: null,
        location_name: ""
    }
}

# OpenAPI specification structure
export def openapi-spec []: nothing -> record {
    {
        openapi: "3.0.0",
        info: {},
        servers: [],
        paths: {},
        components: {},
        security: [],
        tags: [],
        external_docs: {}
    }
}

# ============================================================================
# AWS SERVICE MODEL PARSER
# ============================================================================

# Parse AWS service model JSON
export def parse-aws-service-model [
    model_json: string
]: nothing -> record {
    try {
        let model = ($model_json | from json)
        
        {
            metadata: (extract-service-metadata $model),
            operations: (parse-operations $model.operations? | default {}),
            shapes: (parse-shapes $model.shapes? | default {}),
            documentation: ($model.documentation? | default ""),
            protocol: ($model.metadata.protocol? | default ""),
            endpoint_prefix: ($model.metadata.endpointPrefix? | default ""),
            signature_version: ($model.metadata.signatureVersion? | default ""),
            service_full_name: ($model.metadata.serviceFullName? | default ""),
            service_abbreviation: ($model.metadata.serviceAbbreviation? | default ""),
            api_version: ($model.metadata.apiVersion? | default ""),
            uid: ($model.metadata.uid? | default ""),
            target_prefix: ($model.metadata.targetPrefix? | default ""),
            json_version: ($model.metadata.jsonVersion? | default ""),
            xml_namespace: ($model.metadata.xmlNamespace? | default {})
        }
    } catch { |error|
        error make {
            msg: "Failed to parse AWS service model",
            label: { text: $error.msg }
        }
    }
}

# Extract service metadata from model
def extract-service-metadata [model: record]: nothing -> record {
    let metadata = ($model.metadata? | default {})
    
    {
        api_version: ($metadata.apiVersion? | default ""),
        endpoint_prefix: ($metadata.endpointPrefix? | default ""),
        global_endpoint: ($metadata.globalEndpoint? | default false),
        json_version: ($metadata.jsonVersion? | default ""),
        protocol: ($metadata.protocol? | default ""),
        service_abbreviation: ($metadata.serviceAbbreviation? | default ""),
        service_full_name: ($metadata.serviceFullName? | default ""),
        service_id: ($metadata.serviceId? | default ""),
        signature_version: ($metadata.signatureVersion? | default ""),
        target_prefix: ($metadata.targetPrefix? | default ""),
        timestamp_format: ($metadata.timestampFormat? | default ""),
        uid: ($metadata.uid? | default ""),
        xml_namespace: ($metadata.xmlNamespace? | default {})
    }
}

# Parse operations from service model
def parse-operations [operations: record]: nothing -> record {
    $operations | transpose key value | each { |op|
        let operation = $op.value
        {
            name: $op.key,
            http: (parse-http-config $operation.http? | default {}),
            input: ($operation.input? | default {}),
            output: ($operation.output? | default {}),
            errors: (parse-operation-errors $operation.errors? | default []),
            documentation: ($operation.documentation? | default ""),
            deprecated: ($operation.deprecated? | default false),
            idempotent: ($operation.idempotent? | default false),
            auth_type: ($operation.authtype? | default ""),
            endpoint_discovery: ($operation.endpointdiscovery? | default {}),
            endpoint_operation: ($operation.endpointoperation? | default false)
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.name $item }
}

# Parse HTTP configuration for operation
def parse-http-config [http: record]: nothing -> record {
    {
        method: ($http.method? | default "POST"),
        request_uri: ($http.requestUri? | default "/"),
        location_name: ($http.locationName? | default ""),
        payload: ($http.payload? | default ""),
        response_code: ($http.responseCode? | default 200)
    }
}

# Parse operation errors
def parse-operation-errors [errors: list]: nothing -> list<record> {
    $errors | each { |error|
        {
            shape: ($error.shape? | default ""),
            documentation: ($error.documentation? | default ""),
            exception: ($error.exception? | default false),
            fault: ($error.fault? | default false),
            retryable: ($error.retryable? | default false),
            throttling: ($error.throttling? | default false)
        }
    }
}

# Parse shapes (data structures) from service model
def parse-shapes [shapes: record]: nothing -> record {
    $shapes | transpose key value | each { |shape|
        let shape_def = $shape.value
        {
            name: $shape.key,
            type: ($shape_def.type? | default ""),
            documentation: ($shape_def.documentation? | default ""),
            members: (parse-shape-members $shape_def.members? | default {}),
            required: ($shape_def.required? | default []),
            enum: ($shape_def.enum? | default []),
            pattern: ($shape_def.pattern? | default ""),
            min: ($shape_def.min? | default null),
            max: ($shape_def.max? | default null),
            sensitive: ($shape_def.sensitive? | default false),
            deprecated: ($shape_def.deprecated? | default false),
            exception: ($shape_def.exception? | default false),
            fault: ($shape_def.fault? | default false),
            flattened: ($shape_def.flattened? | default false),
            streaming: ($shape_def.streaming? | default false),
            timestamp_format: ($shape_def.timestampFormat? | default ""),
            xml_namespace: ($shape_def.xmlNamespace? | default {}),
            xml_attribute: ($shape_def.xmlAttribute? | default false),
            location_name: ($shape_def.locationName? | default ""),
            key: (parse-shape-reference $shape_def.key? | default {}),
            value: (parse-shape-reference $shape_def.value? | default {}),
            member: (parse-shape-reference $shape_def.member? | default {})
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.name $item }
}

# Parse shape members
def parse-shape-members [members: record]: nothing -> record {
    if ($members | is-empty) {
        return {}
    }
    
    $members | transpose key value | each { |member|
        let member_def = $member.value
        {
            name: $member.key,
            shape: ($member_def.shape? | default ""),
            documentation: ($member_def.documentation? | default ""),
            location: ($member_def.location? | default ""),
            location_name: ($member_def.locationName? | default ""),
            deprecated: ($member_def.deprecated? | default false),
            streaming: ($member_def.streaming? | default false),
            payload: ($member_def.payload? | default false),
            host_label: ($member_def.hostLabel? | default false),
            xml_namespace: ($member_def.xmlNamespace? | default {}),
            xml_attribute: ($member_def.xmlAttribute? | default false),
            flattened: ($member_def.flattened? | default false),
            query_name: ($member_def.queryName? | default ""),
            idempotency_token: ($member_def.idempotencyToken? | default false)
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.name $item }
}

# Parse shape reference
def parse-shape-reference [reference: record]: nothing -> record {
    if ($reference | is-empty) {
        return {}
    }
    
    {
        shape: ($reference.shape? | default ""),
        location_name: ($reference.locationName? | default ""),
        documentation: ($reference.documentation? | default "")
    }
}

# ============================================================================
# OPENAPI SPECIFICATION PARSER
# ============================================================================

# Parse OpenAPI specification
export def parse-openapi-spec [
    openapi_json: string
]: nothing -> record {
    try {
        let spec = ($openapi_json | from json)
        
        {
            openapi_version: ($spec.openapi? | default "3.0.0"),
            info: (parse-openapi-info $spec.info? | default {}),
            servers: (parse-openapi-servers $spec.servers? | default []),
            paths: (parse-openapi-paths $spec.paths? | default {}),
            components: (parse-openapi-components $spec.components? | default {}),
            security: ($spec.security? | default []),
            tags: (parse-openapi-tags $spec.tags? | default []),
            external_docs: ($spec.externalDocs? | default {})
        }
    } catch { |error|
        error make {
            msg: "Failed to parse OpenAPI specification",
            label: { text: $error.msg }
        }
    }
}

# Parse OpenAPI info section
def parse-openapi-info [info: record]: nothing -> record {
    {
        title: ($info.title? | default ""),
        description: ($info.description? | default ""),
        version: ($info.version? | default ""),
        terms_of_service: ($info.termsOfService? | default ""),
        contact: ($info.contact? | default {}),
        license: ($info.license? | default {})
    }
}

# Parse OpenAPI servers
def parse-openapi-servers [servers: list]: nothing -> list<record> {
    $servers | each { |server|
        {
            url: ($server.url? | default ""),
            description: ($server.description? | default ""),
            variables: ($server.variables? | default {})
        }
    }
}

# Parse OpenAPI paths
def parse-openapi-paths [paths: record]: nothing -> record {
    $paths | transpose key value | each { |path|
        let path_item = $path.value
        {
            path: $path.key,
            summary: ($path_item.summary? | default ""),
            description: ($path_item.description? | default ""),
            operations: (parse-openapi-operations $path_item),
            parameters: ($path_item.parameters? | default []),
            servers: ($path_item.servers? | default [])
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.path $item }
}

# Parse OpenAPI operations from path item
def parse-openapi-operations [path_item: record]: nothing -> record {
    let methods = ["get", "post", "put", "delete", "options", "head", "patch", "trace"]
    mut operations = {}
    
    for method in $methods {
        if ($method in $path_item) {
            let operation = ($path_item | get $method)
            $operations = ($operations | upsert $method (parse-openapi-operation $operation))
        }
    }
    
    $operations
}

# Parse individual OpenAPI operation
def parse-openapi-operation [operation: record]: nothing -> record {
    {
        tags: ($operation.tags? | default []),
        summary: ($operation.summary? | default ""),
        description: ($operation.description? | default ""),
        external_docs: ($operation.externalDocs? | default {}),
        operation_id: ($operation.operationId? | default ""),
        parameters: ($operation.parameters? | default []),
        request_body: ($operation.requestBody? | default {}),
        responses: ($operation.responses? | default {}),
        callbacks: ($operation.callbacks? | default {}),
        deprecated: ($operation.deprecated? | default false),
        security: ($operation.security? | default []),
        servers: ($operation.servers? | default [])
    }
}

# Parse OpenAPI components
def parse-openapi-components [components: record]: nothing -> record {
    {
        schemas: ($components.schemas? | default {}),
        responses: ($components.responses? | default {}),
        parameters: ($components.parameters? | default {}),
        examples: ($components.examples? | default {}),
        request_bodies: ($components.requestBodies? | default {}),
        headers: ($components.headers? | default {}),
        security_schemes: ($components.securitySchemes? | default {}),
        links: ($components.links? | default {}),
        callbacks: ($components.callbacks? | default {})
    }
}

# Parse OpenAPI tags
def parse-openapi-tags [tags: list]: nothing -> list<record> {
    $tags | each { |tag|
        {
            name: ($tag.name? | default ""),
            description: ($tag.description? | default ""),
            external_docs: ($tag.externalDocs? | default {})
        }
    }
}

# ============================================================================
# JSON SCHEMA PARSER
# ============================================================================

# Parse JSON Schema
export def parse-json-schema [
    schema_json: string
]: nothing -> record {
    try {
        let schema = ($schema_json | from json)
        
        {
            schema_version: ($schema.`$schema`? | default ""),
            id: ($schema.`$id`? | default ""),
            title: ($schema.title? | default ""),
            description: ($schema.description? | default ""),
            type: ($schema.type? | default ""),
            properties: (parse-schema-properties $schema.properties? | default {}),
            required: ($schema.required? | default []),
            additional_properties: ($schema.additionalProperties? | default true),
            pattern_properties: ($schema.patternProperties? | default {}),
            definitions: ($schema.definitions? | default {}),
            all_of: ($schema.allOf? | default []),
            any_of: ($schema.anyOf? | default []),
            one_of: ($schema.oneOf? | default []),
            not: ($schema.not? | default {}),
            if: ($schema.if? | default {}),
            then: ($schema.then? | default {}),
            else: ($schema.else? | default {}),
            format: ($schema.format? | default ""),
            enum: ($schema.enum? | default []),
            const: ($schema.const? | default null),
            default: ($schema.default? | default null),
            examples: ($schema.examples? | default []),
            minimum: ($schema.minimum? | default null),
            maximum: ($schema.maximum? | default null),
            exclusive_minimum: ($schema.exclusiveMinimum? | default null),
            exclusive_maximum: ($schema.exclusiveMaximum? | default null),
            multiple_of: ($schema.multipleOf? | default null),
            min_length: ($schema.minLength? | default null),
            max_length: ($schema.maxLength? | default null),
            pattern: ($schema.pattern? | default ""),
            min_items: ($schema.minItems? | default null),
            max_items: ($schema.maxItems? | default null),
            unique_items: ($schema.uniqueItems? | default false),
            items: ($schema.items? | default {}),
            additional_items: ($schema.additionalItems? | default true),
            contains: ($schema.contains? | default {}),
            min_properties: ($schema.minProperties? | default null),
            max_properties: ($schema.maxProperties? | default null),
            dependencies: ($schema.dependencies? | default {}),
            property_names: ($schema.propertyNames? | default {}),
            read_only: ($schema.readOnly? | default false),
            write_only: ($schema.writeOnly? | default false),
            deprecated: ($schema.deprecated? | default false)
        }
    } catch { |error|
        error make {
            msg: "Failed to parse JSON Schema",
            label: { text: $error.msg }
        }
    }
}

# Parse schema properties
def parse-schema-properties [properties: record]: nothing -> record {
    if ($properties | is-empty) {
        return {}
    }
    
    $properties | transpose key value | each { |prop|
        let property = $prop.value
        {
            name: $prop.key,
            type: ($property.type? | default ""),
            description: ($property.description? | default ""),
            format: ($property.format? | default ""),
            enum: ($property.enum? | default []),
            default: ($property.default? | default null),
            examples: ($property.examples? | default []),
            minimum: ($property.minimum? | default null),
            maximum: ($property.maximum? | default null),
            min_length: ($property.minLength? | default null),
            max_length: ($property.maxLength? | default null),
            pattern: ($property.pattern? | default ""),
            items: ($property.items? | default {}),
            properties: (if ("properties" in $property) { parse-schema-properties $property.properties } else { {} }),
            required: ($property.required? | default []),
            read_only: ($property.readOnly? | default false),
            write_only: ($property.writeOnly? | default false),
            deprecated: ($property.deprecated? | default false)
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.name $item }
}

# ============================================================================
# AWS API REFERENCE PARSER
# ============================================================================

# Parse AWS API Reference documentation
export def parse-aws-api-reference [
    html_content: string,
    service: string
]: nothing -> record {
    # Extract API operations from HTML
    let operations = extract-operations-from-html $html_content
    
    # Extract data types
    let data_types = extract-data-types-from-html $html_content
    
    # Extract error information
    let errors = extract-errors-from-html $html_content
    
    {
        service: $service,
        operations: $operations,
        data_types: $data_types,
        errors: $errors,
        parsed_from: "api-reference-html",
        timestamp: (date now)
    }
}

# Extract operations from HTML content
def extract-operations-from-html [html: string]: nothing -> list<record> {
    # This is a simplified implementation
    # Real implementation would use HTML parsing
    let lines = ($html | lines)
    
    $lines 
    | where ($it | str contains "operation-name" or $it | str contains "<h2")
    | each { |line|
        {
            name: (extract-operation-name $line),
            description: "",
            parameters: [],
            response: {}
        }
    }
    | where ($it.name | str length) > 0
}

# Extract operation name from HTML line
def extract-operation-name [line: string]: nothing -> string {
    # Simplified extraction - real implementation would parse HTML properly
    $line 
    | str replace --all --regex '<[^>]*>' ''
    | str trim
}

# Extract data types from HTML content
def extract-data-types-from-html [html: string]: nothing -> list<record> {
    # Placeholder implementation
    []
}

# Extract errors from HTML content
def extract-errors-from-html [html: string]: nothing -> list<record> {
    # Placeholder implementation  
    []
}

# ============================================================================
# SCHEMA CONVERSION UTILITIES
# ============================================================================

# Convert AWS service model to OpenAPI specification
export def convert-service-model-to-openapi [
    service_model: record
]: nothing -> record {
    let info = {
        title: ($service_model.service_full_name | default "AWS Service"),
        version: ($service_model.api_version | default "1.0.0"),
        description: ($service_model.documentation | default "")
    }
    
    let servers = [{
        url: $"https://($service_model.endpoint_prefix).amazonaws.com",
        description: "AWS service endpoint"
    }]
    
    let paths = convert-operations-to-paths $service_model.operations
    let components = convert-shapes-to-components $service_model.shapes
    
    {
        openapi: "3.0.0",
        info: $info,
        servers: $servers,
        paths: $paths,
        components: $components
    }
}

# Convert operations to OpenAPI paths
def convert-operations-to-paths [operations: record]: nothing -> record {
    $operations | transpose key value | each { |op|
        let operation = $op.value
        let http = $operation.http
        let path = ($http.request_uri | default "/")
        let method = ($http.method | str downcase | default "post")
        
        {
            path: $path,
            method: $method,
            operation: {
                operation_id: $op.key,
                summary: ($operation.documentation | default ""),
                parameters: [],
                responses: {
                    "200": {
                        description: "Successful response"
                    }
                }
            }
        }
    } | group-by path | transpose key value | each { |path_group|
        let path = $path_group.key
        let operations = ($path_group.value | reduce -f {} { |item, acc|
            $acc | upsert $item.method $item.operation
        })
        {
            path: $path,
            operations: $operations
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.path $item.operations }
}

# Convert shapes to OpenAPI components
def convert-shapes-to-components [shapes: record]: nothing -> record {
    let schemas = $shapes | transpose key value | each { |shape|
        let shape_def = $shape.value
        {
            name: $shape.key,
            schema: (convert-shape-to-schema $shape_def)
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.name $item.schema }
    
    { schemas: $schemas }
}

# Convert AWS shape to JSON schema
def convert-shape-to-schema [shape: record]: nothing -> record {
    match $shape.type {
        "structure" => {
            type: "object",
            properties: (convert-members-to-properties $shape.members),
            required: ($shape.required | default [])
        },
        "list" => {
            type: "array",
            items: (if ("member" in $shape) { {"$ref": $"#/components/schemas/($shape.member.shape)"} } else { {} })
        },
        "map" => {
            type: "object",
            additionalProperties: (if ("value" in $shape) { {"$ref": $"#/components/schemas/($shape.value.shape)"} } else { {} })
        },
        "string" => {
            type: "string",
            pattern: ($shape.pattern | default ""),
            enum: ($shape.enum | default [])
        },
        "integer" => {
            type: "integer",
            minimum: ($shape.min | default null),
            maximum: ($shape.max | default null)
        },
        "long" => {
            type: "integer",
            format: "int64",
            minimum: ($shape.min | default null),
            maximum: ($shape.max | default null)
        },
        "double" => {
            type: "number",
            format: "double",
            minimum: ($shape.min | default null),
            maximum: ($shape.max | default null)
        },
        "float" => {
            type: "number",
            format: "float",
            minimum: ($shape.min | default null),
            maximum: ($shape.max | default null)
        },
        "boolean" => {
            type: "boolean"
        },
        "timestamp" => {
            type: "string",
            format: "date-time"
        },
        "blob" => {
            type: "string",
            format: "byte"
        },
        _ => {
            type: "string"
        }
    }
}

# Convert shape members to schema properties
def convert-members-to-properties [members: record]: nothing -> record {
    if ($members | is-empty) {
        return {}
    }
    
    $members | transpose key value | each { |member|
        let member_def = $member.value
        {
            name: $member.key,
            property: {
                "$ref": $"#/components/schemas/($member_def.shape)",
                description: ($member_def.documentation | default "")
            }
        }
    } | reduce -f {} { |item, acc| $acc | upsert $item.name $item.property }
}

# ============================================================================
# VALIDATION AND UTILITIES
# ============================================================================

# Validate API specification
export def validate-api-spec [
    spec: record,
    spec_type: string
]: nothing -> record {
    mut errors = []
    mut warnings = []
    
    match $spec_type {
        "aws-service-model" => {
            if not ("metadata" in $spec) {
                $errors = ($errors | append "Missing metadata section")
            }
            if not ("operations" in $spec) {
                $errors = ($errors | append "Missing operations section")
            }
        },
        "openapi" => {
            if not ("openapi" in $spec) {
                $errors = ($errors | append "Missing OpenAPI version")
            }
            if not ("info" in $spec) {
                $errors = ($errors | append "Missing info section")
            }
            if not ("paths" in $spec) {
                $warnings = ($warnings | append "No paths defined")
            }
        },
        "json-schema" => {
            if not ("type" in $spec) and not ("properties" in $spec) {
                $warnings = ($warnings | append "No type or properties defined")
            }
        }
    }
    
    {
        valid: ($errors | length) == 0,
        errors: $errors,
        warnings: $warnings,
        spec_type: $spec_type
    }
}

# Generate API documentation summary
export def generate-api-summary [
    spec: record,
    spec_type: string
]: nothing -> record {
    match $spec_type {
        "aws-service-model" => {
            service_name: ($spec.service_full_name | default "Unknown Service"),
            api_version: ($spec.api_version | default ""),
            protocol: ($spec.protocol | default ""),
            operations_count: ($spec.operations | columns | length),
            shapes_count: ($spec.shapes | columns | length)
        },
        "openapi" => {
            title: ($spec.info.title | default "Unknown API"),
            version: ($spec.info.version | default ""),
            servers_count: ($spec.servers | length),
            paths_count: ($spec.paths | columns | length),
            schemas_count: (if ("components" in $spec) { $spec.components.schemas | columns | length } else { 0 })
        },
        "json-schema" => {
            title: ($spec.title | default "Unknown Schema"),
            type: ($spec.type | default ""),
            properties_count: (if ("properties" in $spec) { $spec.properties | columns | length } else { 0 }),
            required_count: ($spec.required | length | default 0)
        },
        _ => {
            error: "Unknown specification type"
        }
    }
}