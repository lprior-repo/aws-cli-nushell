# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS CLI Nushell is a comprehensive AWS CLI implementation specifically designed for Nushell scripts. It provides type-safe wrappers for AWS services with extensive testing capabilities, mocking support, and pure functional programming patterns.

## Architecture

### Core Components

1. **Universal AWS Generator** (`universal_aws_generator.nu`): Single-file solution that can auto-generate complete AWS CLI wrappers for ANY AWS service by parsing AWS CLI help output
2. **Service Modules** (`aws/*.nu`): Individual AWS service implementations (currently Step Functions with 37 commands)
3. **Testing Framework** (`nutest/`): Comprehensive testing framework with discovery, execution, and reporting capabilities
4. **Test Suites** (`tests/aws/`): Service-specific test implementations

### Key Design Patterns

- **Pure Functional Programming**: All modules follow immutable data patterns with composable functions
- **Mock-First Testing**: Every service supports mock mode via environment variables (e.g., `STEPFUNCTIONS_MOCK_MODE=true`)
- **Type Safety**: Comprehensive input validation and error handling throughout
- **Test-Driven Development**: 555+ tests covering all functionality

## Development Commands

### Running Tests

```nushell
# Run all tests with the nutest framework
nu -c "use nutest/nutest/mod.nu; mod run-tests --display terminal --returns summary"

# Run AWS service tests specifically
nu aws_test_framework.nu --service all --mock

# Run tests for a specific service
nu aws_test_framework.nu --service stepfunctions --mock

# Simple test runner for quick validation
nu simple_test_runner.nu
```

### Code Generation

```nushell
# Generate a complete AWS service wrapper (example: S3)
nu universal_aws_generator.nu s3

# Generate multiple services at once
nu -c "['dynamodb', 'lambda', 'ecs'] | each { |svc| nu universal_aws_generator.nu $svc }"
```

### Service Testing

```nushell
# Test all AWS services with comprehensive output
nu test_all_services.nu

# Run specific AWS service tests
nu run_aws_tests.nu
```

## Testing Framework (nutest)

The project includes a custom testing framework located in `nutest/nutest/` with these key features:

### Test Discovery and Execution

- Tests are discovered via annotations: `#[test]`, `#[ignore]`, `#[before-each]`, `#[after-each]`
- Supports parallel execution and various display modes
- Comprehensive assertion library in test utilities

### Test Structure

```nushell
#[before-each]
def setup [] {
    $env.SERVICE_MOCK_MODE = "true"
    { test_context: "service_name" }
}

#[test]
def "test description" [] {
    let context = $in
    let result = (some_function)
    assert ($result.status == "expected") "Assertion message"
}
```

### Mock Environment Setup

All AWS services support mock mode through environment variables:
- `STEPFUNCTIONS_MOCK_MODE=true`
- `DYNAMODB_MOCK_MODE=true`
- `LAMBDA_MOCK_MODE=true`
- `ECS_MOCK_MODE=true`
- `IAM_MOCK_MODE=true`
- `S3API_MOCK_MODE=true`
- `EVENTS_MOCK_MODE=true`
- `RDS_MOCK_MODE=true`

## Code Organization

### File Structure

```
aws-cli-nushell/
├── aws/                          # AWS service implementations
│   └── stepfunctions.nu         # Complete Step Functions implementation (37 commands)
├── nutest/                      # Testing framework
│   └── nutest/                  # Core framework modules
├── tests/aws/                   # AWS service tests
├── universal_aws_generator.nu   # Auto-generator for any AWS service
├── aws_test_framework.nu        # Direct test runner
└── test_all_services.nu         # Comprehensive test suite
```

### AWS Service Implementation Pattern

Each AWS service module follows this structure:
1. **Type Definitions**: Error types, validation schemas, mock configuration
2. **Error Handling**: Standardized error creation and validation
3. **Core Functions**: AWS CLI command wrappers with input validation
4. **Mock Support**: Contextual mock responses based on command patterns
5. **Export Interface**: Clean public API for the service

### Universal Generator Capabilities

The `universal_aws_generator.nu` can create complete implementations for any AWS service by:
1. Discovering all commands via `aws <service> help`
2. Generating contextual mock responses based on command patterns
3. Creating type-safe wrappers with validation
4. Providing comprehensive test scaffolding

## Development Guidelines

### Adding New AWS Services

1. Use the universal generator: `nu universal_aws_generator.nu <service_name>`
2. Review generated code for service-specific customizations
3. Add comprehensive tests following existing patterns
4. Ensure mock mode support is properly implemented

### Working with Tests

1. All tests must use the `#[test]` annotation for discovery
2. Use `#[before-each]` for setup that provides test context
3. Leverage the assertion utilities for consistent error messages
4. Always enable mock mode in test setup to avoid real AWS calls

### Code Style

- Functions should be pure and composable
- Use descriptive names that explain intent
- Limit functions to 25 lines for clarity
- Prefer explicit error handling over exceptions
- Follow the established pattern of mock-first development

### Mock Development

- Mock responses should be contextually appropriate to command type
- Use the established patterns in `get_mock_response` function
- Include `mock: true` flag in all mock responses
- Provide realistic but safe data structures

## Environment Configuration

Key environment variables:
- `AWS_REGION`: Target AWS region (default: us-east-1)
- `AWS_ACCOUNT_ID`: Account ID for mocking (default: 123456789012)
- `<SERVICE>_MOCK_MODE`: Enable mock mode for specific services
- `NU_BACKTRACE`: Enable verbose error reporting for debugging

## Nushell Version

This codebase is developed for Nushell 0.107.0 and follows current syntax and patterns. The testing framework may require syntax updates for different Nushell versions.