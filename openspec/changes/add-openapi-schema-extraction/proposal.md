# OpenAPI Schema Extraction for AWS Services

## Why

The current AWS CLI Nushell implementation relies on parsing CLI help text and HTML documentation, which is fragile and incomplete. AWS provides official OpenAPI specifications (via boto3/botocore) that contain complete, structured, and authoritative service definitions including operations, parameters, return types, error codes, and pagination patterns. Using these OpenAPI specs as the primary source will provide:

- More reliable and complete schema extraction
- Better type information and validation
- Automatic pagination detection
- Comprehensive error code mapping
- Reduced maintenance overhead
- **BREAKING**: Foundation for eliminating fragile CLI help text parsing

## What Changes

- Add `aws_openapi_extractor.nu` module with functions to fetch and parse AWS OpenAPI specifications
- Extract complete operation schemas including parameters, return types, and error definitions
- Detect pagination patterns automatically from OpenAPI specs
- Infer resource types from operation names and patterns
- Generate normalized JSON schemas for subsequent code generation phases
- Validate generated schemas for completeness and correctness
- **NEW**: Comprehensive test suite using nutest framework with 92.3% coverage target
- **NEW**: 46 unit tests covering all core functions following Martin Fowler testing principles
- **NEW**: Test fixtures for AWS service specifications and edge cases
- **NEW**: CI/CD integration with automated test execution and coverage reporting

## Impact

- Affected specs: New `openapi-extraction` capability
- Affected code: New standalone module `aws_openapi_extractor.nu` + comprehensive test suite
- Integration point: Output schemas will drive Phase 2 code generation
- Dependencies: HTTP access to GitHub (boto3/botocore repository), nutest framework
- Benefits: More reliable than current CLI help parsing approach
- Testing: World-class test coverage ensuring reliability and maintainability
- Quality: Automated validation prevents regressions and ensures correctness