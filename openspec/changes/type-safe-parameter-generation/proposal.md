# Type-Safe Parameter Generation Proposal

## Summary

This proposal introduces a Type-Safe Parameter Generation system that converts AWS OpenAPI schemas into native Nushell function signatures. The system will generate type-safe, completion-enabled Nushell command parameters using the latest Nushell syntax (0.85+), supporting the project's goal of creating production-ready AWS CLI wrappers that feel like pure Nushell.

## Problem Statement

Currently, the AWS CLI Nushell project has:
- OpenAPI schema extraction capabilities (existing spec: `openapi-extraction`)
- Rich AWS service schemas with type information in `real-schemas/` directory
- A gap between extracted schemas and usable Nushell function signatures

The missing component is a systematic way to transform AWS operation definitions into idiomatic Nushell function signatures with:
- Type-safe parameter definitions
- Native Nushell completion support 
- Proper handling of optional/required parameters
- Complex nested structure mapping
- Current Nushell syntax compliance (0.85+)

## Proposed Solution

### Core Components

1. **Parameter Type Mapper**: Maps AWS types to Nushell native types (string, int, bool, datetime, filesize, etc.)
2. **Completion Generator**: Creates custom completion functions for AWS resources (@"nu-complete aws s3 buckets")
3. **Signature Builder**: Assembles complete function signatures with current Nushell syntax
4. **Schema Processor**: Handles complex nested structures and constraints

### Key Features

- **Modern Nushell Syntax**: Uses square brackets `[...]` for parameters, proper type annotations
- **AWS Resource Completions**: Dynamic completions for buckets, instances, functions, etc.
- **Type Safety**: Maps AWS constraints to Nushell types (filesize for size values, datetime for timestamps)
- **Documentation Integration**: Preserves AWS documentation as parameter comments
- **Pipeline Optimization**: Prefers `table<>` over `list<record<>>` for better pipeline usage

## Integration with Existing System

This builds directly on the existing `openapi-extraction` specification:
- Consumes normalized schemas from OpenAPI extraction
- Uses existing service schemas in `real-schemas/` directory  
- Follows established TDD and functional programming patterns
- Integrates with the nutest testing framework

## Success Criteria

1. Generate syntactically valid Nushell function signatures from AWS schemas
2. Support all AWS type mappings (primitives, structures, lists, enums)
3. Provide live resource completions for major AWS resource types
4. Maintain 100% test coverage using existing nutest framework
5. Process all existing service schemas (S3, Step Functions, etc.)

## Next Steps

1. Create detailed technical design and implementation specs
2. Define comprehensive requirements with scenarios
3. Implement core helper functions with TDD approach
4. Build integration tests with existing service schemas
5. Validate against current Nushell syntax requirements