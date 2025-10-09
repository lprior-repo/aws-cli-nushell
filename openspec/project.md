# NuAWS - Native Nushell AWS CLI

## Project Overview

NuAWS is a comprehensive, pre-generated, immediately usable Nushell module that provides seamless access to the entire AWS CLI with native Nushell ergonomics, type safety, and pipeline integration.

## Current Status

- **Phase**: Distribution-ready foundation
- **Services**: 4 major AWS services (S3, EC2, IAM, Step Functions)
- **Operations**: 30,000+ operations pre-generated
- **Architecture**: Unified router with pre-built modules
- **Testing**: Comprehensive mock mode support

## Core Principles

1. **Structured Data Everything**: All outputs are Nushell-native structured data
2. **Pipeline Native Design**: Seamless integration with Nushell pipelines
3. **Functional Programming**: Pure functions and immutable data patterns
4. **Rich Error Context**: Span-aware errors with actionable suggestions
5. **Type Driven Development**: Comprehensive type safety throughout
6. **TDD Methodology**: Test-first development with 95%+ coverage

## Architecture

- **Unified Router** (`nuaws.nu`): Single entry point for all AWS commands
- **Pre-Generated Modules** (`modules/`): Service-specific implementations
- **External Completions** (`completions/`): Dynamic resource completion
- **Build System** (`build.nu`): Distribution-ready generation pipeline
- **Testing Framework** (`nutest/`): Comprehensive testing infrastructure

## Success Metrics

### Performance
- Cached operations: <100ms
- Completion response: <200ms
- Bulk operations: 10x improvement
- Cache hit rate: >90%
- Memory usage: <100MB typical

### Quality
- Test pass rate: 99%
- API coverage: 100% OpenAPI schemas
- Completion coverage: 95% tab completion
- Error coverage: 100% AWS error codes

### Usability
- Native feel: Commands feel like built-in Nushell
- Zero config: Works immediately after installation
- Pipeline integration: Seamless data flow