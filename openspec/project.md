# Project Context

## Purpose
AWS CLI Nushell is a comprehensive, zero-AI automated code generation system that creates production-ready Nushell modules for ANY AWS service. The system introspects AWS CLI and documentation to generate complete wrappers that are indistinguishable from hand-written idiomatic Nushell code, providing type-safe, pipeline-friendly, fully-tested modules with custom completions.

**Core Goal**: Build a universal AWS service wrapper auto-generator that requires zero AI/LLM assistance after initial creation, producing 1:1 AWS CLI mappings that feel like pure Nushell.

## Tech Stack
- **Nushell 0.107.0**: Primary scripting language and target runtime
- **AWS CLI**: Source of truth for service discovery and operation schemas
- **Bash/Shell**: Supporting infrastructure for AWS CLI introspection
- **JSON**: Intermediate schema representation format
- **HTML Parsing**: AWS documentation scraping for error codes and metadata

## Project Conventions

### Code Style
- **Pure Functional Programming**: Immutable data structures, composable functions, no mutations or classes
- **Test-Driven Development (TDD)**: Strict Red-Green-Refactor cycles with 100% test coverage
- **Function Limits**: 10-25 lines per function, single responsibility, maximum clarity
- **Type Safety**: Comprehensive input validation, no `any` types, Nushell native types (duration, filesize, datetime)
- **Descriptive Naming**: Verb+noun functions (e.g., `validate-arn`), descriptive variables, domain-specific terms
- **Pipeline-First Design**: All operations accept pipeline input and chain naturally

### Architecture Patterns
- **Universal Generator Pattern**: Single auto-generator creates complete service implementations
- **Mock-First Testing**: Every service supports environment-variable toggle mock mode
- **Schema-Driven Generation**: Extract complete schemas from AWS CLI, then generate code
- **Layered Architecture**:
  - Schema Extraction (AWS CLI introspection)
  - Code Generation (templates → Nushell modules)
  - Test Generation (comprehensive test suites)
  - Quality Validation (automated checks)

### Testing Strategy
- **Custom nutest Framework**: Annotation-based test discovery (`#[test]`, `#[before-each]`, `#[after-each]`)
- **Four Test Types**:
  - Unit Tests (mocked operations)
  - Validation Tests (invalid input rejection)
  - Pipeline Tests (pipeline compatibility)
  - Integration Tests (real AWS CRUD workflows)
- **Mock Environment**: All services support `<SERVICE>_MOCK_MODE=true` for safe testing
- **Quality Gates**: Syntax validation, type coverage, test coverage, completion coverage

### Git Workflow
- **Main Branch Development**: Direct commits to main branch
- **Commit Conventions**: Descriptive commits with context and scope
- **Clean History**: Logical commit boundaries aligned with feature completion
- **No Forced Dependencies**: Self-contained modules with minimal external dependencies

## Domain Context

### AWS Service Patterns
- **Operation Types**: create-*, list-*, describe-*, update-*, delete-*, get-*
- **Resource Hierarchies**: Services → Resources → Sub-resources with ARN addressing
- **Pagination Patterns**: NextToken/MaxResults for large result sets
- **Error Handling**: AWS error codes with HTTP status mapping and retry semantics
- **ARN Formats**: Service-specific Amazon Resource Name patterns for resource identification

### Nushell Idioms
- **Pipeline Data Flow**: Operations chain naturally with `|` operator
- **Structured Data**: Records and tables as primary data structures
- **Native Types**: duration (1hr), filesize (1MB), datetime, path types
- **Completions**: Custom completion functions for live AWS resource discovery
- **Environment Integration**: Configuration via `$env` variables

### Code Generation Principles
- **Deterministic Output**: Same input always produces identical generated code
- **Self-Documenting**: Generated code includes comprehensive inline documentation
- **Validation-First**: Client-side validation before any AWS API calls
- **Contextual Mocking**: Realistic mock responses based on operation patterns

## Important Constraints

### Technical Constraints
- **Nushell Version Lock**: Code targets Nushell 0.107.0 syntax and features
- **No Recursion**: Use loops for retries/pagination (Nushell doesn't optimize tail recursion)
- **Memory Safety**: Immutable data structures, no shared mutable state
- **Error Propagation**: Structured error handling, no exceptions or panics
- **Type System**: Leverage Nushell's type system for compile-time safety

### Design Constraints
- **Zero AI Dependency**: Generator must be fully automated without LLM assistance
- **AWS CLI Parity**: 100% operation coverage for any AWS service
- **Native Feel**: Generated code indistinguishable from hand-written Nushell
- **Production Ready**: All generated modules must be deployment-ready

### Quality Constraints
- **100% Test Coverage**: Every function, branch, and edge case tested
- **No `any` Types**: Complete type specification throughout codebase
- **Documentation Coverage**: All public functions documented with examples
- **Performance**: Efficient pipeline operations, caching for read operations

## External Dependencies

### Required Systems
- **AWS CLI**: Source of truth for service discovery and operation schemas
- **AWS Documentation**: Error code definitions and API reference materials
- **AWS Credentials**: For integration testing and real operation validation

### Optional Integrations
- **AWS Services**: Any AWS service can be wrapped (355+ services supported)
- **CI/CD Systems**: Automated quality validation and testing pipelines
- **Documentation Generators**: Integration with documentation tooling

### Development Dependencies
- **Nushell Runtime**: Primary execution environment
- **Testing Framework**: Custom nutest framework for comprehensive testing
- **Quality Tools**: Syntax validation, type checking, coverage analysis
