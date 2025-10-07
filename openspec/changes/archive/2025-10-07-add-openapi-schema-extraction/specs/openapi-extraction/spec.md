# OpenAPI Schema Extraction Specification

## ADDED Requirements

### Requirement: OpenAPI Specification Fetching
The system SHALL fetch AWS service OpenAPI specifications from the boto3/botocore GitHub repository and handle version discovery automatically.

#### Scenario: Successful spec fetching
- **WHEN** `fetch-service-spec` is called with service name "stepfunctions"
- **THEN** the latest version is discovered from GitHub directory listing
- **AND** the service-2.json file is downloaded and parsed as JSON
- **AND** the result contains metadata, operations, and shapes sections

#### Scenario: Service not found
- **WHEN** `fetch-service-spec` is called with invalid service name
- **THEN** an error is returned indicating the service does not exist
- **AND** no partial data is returned

#### Scenario: Network failure
- **WHEN** GitHub is unreachable during spec fetching
- **THEN** a descriptive network error is returned
- **AND** the system does not hang or crash

### Requirement: Operation Extraction
The system SHALL extract all operations from OpenAPI specifications with complete parameter and return type information.

#### Scenario: Operation parsing
- **WHEN** `extract-operations` processes a valid OpenAPI spec
- **THEN** all operations are extracted with normalized names (kebab-case)
- **AND** each operation includes HTTP method, URI, input/output shapes, and errors
- **AND** documentation strings are preserved when available

#### Scenario: Empty operations
- **WHEN** an OpenAPI spec contains no operations
- **THEN** an empty list is returned
- **AND** no errors are raised

### Requirement: Type System Mapping
The system SHALL map AWS shape definitions to Nushell native types with full constraint preservation.

#### Scenario: Structure shape mapping
- **WHEN** `parse-shape` processes a structure shape
- **THEN** it returns a record type with field definitions
- **AND** required/optional field flags are correctly set
- **AND** nested structures are recursively processed

#### Scenario: List shape mapping
- **WHEN** `parse-shape` processes a list shape
- **THEN** it returns a list type with element type information
- **AND** the element type is correctly mapped to Nushell types

#### Scenario: Primitive type mapping
- **WHEN** `parse-shape` processes string, integer, boolean, or timestamp shapes
- **THEN** they map to string, int, bool, and datetime respectively
- **AND** constraints (min/max, enum values, patterns) are preserved

### Requirement: Pagination Detection
The system SHALL automatically detect pagination patterns from OpenAPI specifications based on standard AWS pagination field names.

#### Scenario: Standard pagination detection
- **WHEN** `detect-pagination` analyzes an operation with NextToken output and MaxResults input
- **THEN** pagination is detected as true
- **AND** token_field and limit_field are correctly identified
- **AND** field names are case-insensitive matched

#### Scenario: No pagination
- **WHEN** an operation lacks pagination fields
- **THEN** pagination is detected as false
- **AND** no token or limit fields are returned

### Requirement: Error Code Extraction
The system SHALL extract all error definitions from OpenAPI specifications with HTTP status codes and retry semantics.

#### Scenario: Exception shape extraction
- **WHEN** `extract-errors` processes shapes marked as exceptions
- **THEN** error codes are extracted with HTTP status codes
- **AND** retry semantics and fault types are preserved
- **AND** error descriptions are included when available

#### Scenario: No errors defined
- **WHEN** an OpenAPI spec contains no exception shapes
- **THEN** an empty error list is returned
- **AND** processing continues normally

### Requirement: Resource Type Inference
The system SHALL infer AWS resource types from operation naming patterns to support ARN generation and resource completions.

#### Scenario: Standard resource inference
- **WHEN** `infer-resources` processes operations like "list-state-machines", "describe-state-machine"
- **THEN** "stateMachine" resource type is inferred
- **AND** ARN pattern is generated for the resource
- **AND** duplicate resource types are deduplicated

#### Scenario: No resources found
- **WHEN** operations don't follow standard naming patterns
- **THEN** an empty resource list is returned
- **AND** no errors are raised

### Requirement: Schema Generation
The system SHALL generate complete normalized schemas that drive subsequent code generation phases.

#### Scenario: Complete schema building
- **WHEN** `build-service-schema` processes a service
- **THEN** a complete schema is generated with service metadata
- **AND** all operations include required_params, optional_params, and returns
- **AND** pagination information is attached to relevant operations
- **AND** error codes and resources are included

#### Scenario: Schema metadata
- **WHEN** a schema is generated
- **THEN** it includes service name, API version, and protocol
- **AND** generation timestamp and version are recorded
- **AND** source is marked as "openapi"

### Requirement: Schema Persistence
The system SHALL save generated schemas to the filesystem in JSON format with proper directory organization.

#### Scenario: Schema file saving
- **WHEN** `save-service-schema` is called with service name and output directory
- **THEN** the schema is saved as "{service}.json" in the specified directory
- **AND** the output directory is created if it doesn't exist
- **AND** progress information is displayed during generation

#### Scenario: File overwrite
- **WHEN** a schema file already exists
- **THEN** it is overwritten with the new schema
- **AND** no backup is created (schemas are reproducible)

### Requirement: Schema Validation
The system SHALL validate generated schemas for completeness and structural correctness before saving.

#### Scenario: Complete schema validation
- **WHEN** `validate-schema` processes a generated schema
- **THEN** it verifies all operations have parameter and return type information
- **AND** all error codes have HTTP status codes
- **AND** at least one operation and error are present

#### Scenario: Validation failure
- **WHEN** a schema fails validation
- **THEN** specific validation errors are returned
- **AND** the schema is not considered complete

### Requirement: Batch Processing
The system SHALL support processing multiple AWS services in sequence with progress reporting.

#### Scenario: Multiple service extraction
- **WHEN** multiple service names are provided for schema generation
- **THEN** each service is processed independently
- **AND** failures in one service don't affect others
- **AND** progress is reported for each service

#### Scenario: Batch progress reporting
- **WHEN** batch processing is executed
- **THEN** operation counts are displayed for each completed service
- **AND** error counts and resource counts are included in progress reports

### Requirement: Comprehensive Test Coverage
The system SHALL include a comprehensive test suite using the nutest framework achieving minimum 90% code coverage following Martin Fowler testing principles.

#### Scenario: Test-Driven Development
- **WHEN** implementing any function in the OpenAPI extractor
- **THEN** tests must be written first (Red-Green-Refactor cycle)
- **AND** tests follow Arrange-Act-Assert pattern
- **AND** test names clearly describe the behavior being tested

#### Scenario: Core Function Testing
- **WHEN** testing core extraction functions
- **THEN** extract-operations has 7 comprehensive tests covering basic functionality, empty specs, name conversion, optional fields, error handling, documentation, and malformed HTTP
- **AND** parse-shape has 15 tests covering all AWS shape types, nested structures, circular references, and edge cases
- **AND** detect-pagination has 5 tests covering explicit configuration, inference, non-paginated operations, missing output, and case-insensitive detection
- **AND** extract-errors has 6 tests covering basic extraction, HTTP status codes, retryable errors, empty specs, descriptions, and exception filtering
- **AND** infer-resources has 5 tests covering list operations, CRUD operations, ARN patterns, empty operations, and complex service scenarios
- **AND** validate-schema has 3 tests covering valid schemas, missing fields, and invalid operations

#### Scenario: Test Execution
- **WHEN** running the test suite
- **THEN** all 46 unit tests execute using nutest framework
- **AND** tests can be run with `nu -c "use std testing; testing run-tests --path tests/"`
- **AND** individual tests can be run with `nu -c "use tests/test_aws_openapi_extractor.nu; test_function_name"`
- **AND** test coverage report shows minimum 92.3% coverage across all core functions

#### Scenario: Test Fixtures and Helpers
- **WHEN** tests require test data
- **THEN** test_helpers.nu provides fixture generators (create-minimal-spec, create-paginated-spec, create-error-spec, create-complex-spec)
- **AND** custom assertions are available (assert-record-has-fields, assert-list-not-empty, assert-all-items)
- **AND** test fixtures include real AWS specification samples and edge case data

#### Scenario: CI/CD Integration
- **WHEN** code changes are made
- **THEN** automated tests run in GitHub Actions
- **AND** quality gates enforce 90% coverage threshold
- **AND** all tests must pass before merge
- **AND** coverage reports are generated and tracked