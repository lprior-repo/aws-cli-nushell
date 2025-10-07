# OpenAPI Schema Extraction Design

## Context

The AWS CLI Nushell project currently generates service wrappers through CLI help text parsing and HTML documentation scraping. This approach is fragile because:

1. CLI help text is designed for humans, not machines
2. HTML documentation structure can change without notice
3. Type information is incomplete or missing
4. Error codes and pagination patterns require manual inference

AWS provides official OpenAPI specifications through the boto3/botocore project that contain complete, machine-readable service definitions.

## Goals / Non-Goals

### Goals
- Replace fragile CLI help parsing with reliable OpenAPI spec consumption
- Extract complete operation schemas including all parameters, return types, and constraints
- Automatically detect pagination patterns from spec metadata
- Generate normalized schemas that drive Phase 2 code generation
- Support all 355+ AWS services through consistent extraction

### Non-Goals
- Modify existing universal_aws_generator.nu (this is Phase 1 only)
- Implement code generation (that's Phase 2)
- Support non-AWS OpenAPI specs
- Real-time spec updates (batch processing is sufficient)

## Decisions

### Data Source Selection
**Decision**: Use boto3/botocore GitHub repository as primary data source
- **URL Pattern**: `https://raw.githubusercontent.com/boto/botocore/develop/botocore/data/{service}/{version}/service-2.json`
- **Alternative**: AWS SDK Go v2 repository
- **Rationale**: boto3/botocore is the canonical Python SDK source and most complete

### Schema Format
**Decision**: Generate normalized JSON schemas with standardized structure
- **Format**: Consistent field names across all services
- **Type Mapping**: AWS shapes → Nushell native types (string, int, bool, datetime, record, list)
- **Metadata**: Include generation timestamp, version, and source information
- **Rationale**: Enables consistent Phase 2 code generation regardless of source service

### Version Handling
**Decision**: Automatically select latest available version per service
- **Discovery**: Parse directory listing to find latest YYYY-MM-DD version
- **Fallback**: Default to known working version if latest fails
- **Rationale**: Ensures we always use most current API definitions

### Error Handling Strategy
**Decision**: Fail fast with descriptive errors for missing or malformed specs
- **HTTP Errors**: Surface network issues clearly
- **Parse Errors**: Identify specific JSON/structure problems
- **Validation Errors**: Report incomplete or invalid schemas
- **Rationale**: Better to fail early than generate incorrect wrappers

## Architecture

### Module Structure
```
aws_openapi_extractor.nu
├─ HTTP Functions (fetch-service-spec)
├─ Parsing Functions (extract-operations, parse-shape)
├─ Analysis Functions (detect-pagination, infer-resources)
├─ Generation Functions (build-service-schema, save-service-schema)
└─ Validation Functions (validate-schema)
```

### Data Flow
1. **Fetch**: Download OpenAPI spec from GitHub
2. **Parse**: Extract operations, shapes, and metadata
3. **Analyze**: Detect patterns (pagination, resources, errors)
4. **Generate**: Create normalized schema
5. **Validate**: Ensure schema completeness
6. **Save**: Write JSON to file system

### Type Mapping Strategy
| AWS Shape Type | Nushell Type | Notes |
|----------------|--------------|-------|
| structure | record | Field mapping with required/optional flags |
| list | list | Element type preserved |
| map | record | Key/value type mapping |
| string | string | Enum values, length constraints |
| integer/long | int | Min/max constraints |
| boolean | bool | Direct mapping |
| timestamp | datetime | ISO format |
| blob | binary | Base64 handling |

## Risks / Trade-offs

### Network Dependency
- **Risk**: HTTP failures during spec fetching
- **Mitigation**: Implement caching and fallback mechanisms

### OpenAPI Spec Changes
- **Risk**: AWS changes spec format or structure
- **Mitigation**: Comprehensive error handling and validation

### Performance
- **Risk**: Large specs may be slow to process
- **Mitigation**: Process services individually, add progress indicators

### Completeness
- **Risk**: Some services may have incomplete or malformed specs
- **Mitigation**: Validation functions to catch issues early

## Migration Plan

### Phase 1: Implementation
1. Create `aws_openapi_extractor.nu` module
2. Test against known services (stepfunctions, s3, dynamodb)
3. Validate output schema format
4. Document usage patterns

### Phase 2: Integration
1. Update universal generator to consume OpenAPI schemas
2. Compare outputs with existing CLI-based approach
3. Switch to OpenAPI as primary source
4. Deprecate CLI help parsing

### Rollback Plan
- OpenAPI extraction is additive and doesn't modify existing generators
- Can fall back to CLI help parsing if OpenAPI approach fails
- Schemas are versioned for debugging and comparison

## Testing Strategy

### Test-Driven Development (TDD)
**Decision**: Use strict Red-Green-Refactor cycles for all implementation
- **Write failing tests first** before any implementation
- **Implement minimal code** to make tests pass
- **Refactor** while keeping tests green
- **Rationale**: Ensures comprehensive coverage and prevents regression

### Testing Framework
**Decision**: Use nutest (Nushell's built-in testing framework)
- **46 total unit tests** covering all core functions
- **92.3% minimum coverage target** exceeding industry standard of 80%
- **Martin Fowler principles**: Arrange-Act-Assert, fast tests, clear naming
- **Rationale**: Native integration, no external dependencies, excellent error reporting

### Test Organization
```
tests/
├── test_aws_openapi_extractor.nu    # Main test file (46 tests)
├── test_helpers.nu                  # Fixtures and custom assertions
└── fixtures/                       # Real AWS specs and edge cases
    ├── minimal_spec.json
    ├── stepfunctions_spec.json
    ├── malformed_spec.json
    └── complex_spec.json
```

### Coverage Requirements
- **Unit Tests**: extract-operations (7), parse-shape (15), detect-pagination (5), extract-errors (6), infer-resources (5), validate-schema (3)
- **Integration Tests**: build-service-schema, save-service-schema (mocked network dependencies)
- **Edge Cases**: circular references, malformed data, missing fields
- **Quality Gates**: All tests pass, 90% coverage minimum, no skipped unit tests

## Open Questions

1. Should we cache downloaded specs locally to reduce GitHub API calls?
   - **Decision needed**: Cache duration and invalidation strategy

2. How do we handle services with multiple API versions?
   - **Decision needed**: Latest version only vs. version selection

3. What validation level is sufficient for generated schemas?
   - **Decision needed**: Basic structure vs. deep semantic validation

4. Should we support alternative OpenAPI sources beyond boto3/botocore?
   - **Decision needed**: Single source vs. source fallback chain

5. Should we mock network calls in unit tests or create integration test suite?
   - **Decision needed**: Pure unit tests vs. mixed approach for HTTP operations