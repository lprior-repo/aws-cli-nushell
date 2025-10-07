# Type-Safe Parameter Generation Design

## Architecture Overview

The Type-Safe Parameter Generation system transforms AWS OpenAPI schemas into idiomatic Nushell function signatures. This system operates as a bridge between the existing OpenAPI extraction layer and the final code generation phase.

## Component Architecture

```
AWS Schemas (JSON) → Parameter Generator → Nushell Function Signatures
                         ↓
            [Type Mapper] [Completion Gen] [Signature Builder]
```

### Core Components

#### 1. Type Mapper
**Purpose**: Maps AWS shape types to appropriate Nushell types
**Inputs**: AWS shape definitions with constraints
**Outputs**: Nushell type annotations

**Design Patterns**:
- Pure function mapping (no side effects)
- Semantic type inference (size → filesize, timestamp → datetime)
- Constraint preservation (min/max, enum values)
- Recursive structure handling

#### 2. Completion Generator  
**Purpose**: Creates custom completion functions for AWS resources
**Inputs**: Parameter names and shape information
**Outputs**: Completion function references

**Design Patterns**:
- Priority-based completion selection (AWS resources > enums > paths)
- Lazy evaluation (completions generated on demand)
- Error resilience (graceful degradation on AWS call failures)
- Caching for performance

#### 3. Signature Builder
**Purpose**: Assembles complete Nushell function signatures
**Inputs**: Operation definitions with processed parameters
**Outputs**: Complete function signature strings

**Design Patterns**:
- Template-based generation
- Modern Nushell syntax compliance (0.85+)
- Pipeline-optimized return types
- Documentation preservation

## Data Flow Design

### Input Processing
1. **Schema Normalization**: Consume existing normalized schemas from `openapi-extraction`
2. **Operation Parsing**: Extract operation details (name, parameters, return types)
3. **Shape Resolution**: Resolve all shape references to concrete types

### Type Processing  
1. **Primitive Mapping**: Direct AWS → Nushell type mapping
2. **Semantic Enhancement**: Apply semantic type improvements (filesize, datetime)
3. **Structure Flattening**: Convert nested structures to appropriate Nushell types
4. **Constraint Application**: Apply AWS constraints to generated types

### Completion Processing
1. **Resource Detection**: Identify AWS resource parameters (BucketName, InstanceId)
2. **Completion Generation**: Create appropriate completion functions
3. **Enum Handling**: Generate choice-based completions for enums
4. **Fallback Logic**: Default to path completions for file parameters

### Signature Assembly
1. **Parameter Ordering**: Required positional → optional flags → boolean flags
2. **Type Annotation**: Apply complete type information with completions
3. **Documentation Integration**: Preserve AWS documentation as comments
4. **Return Type Optimization**: Choose optimal return types for pipeline usage

## Key Design Decisions

### Modern Nushell Syntax Compliance
- **Square Brackets**: Use `[...]` for parameter lists (not parentheses)
- **Type Annotations**: Full `param: type@"completion"` syntax
- **Optional Parameters**: Use `--param?: type = default` syntax
- **Return Types**: Support `input_type -> return_type` annotations

### Type Mapping Strategy
- **Semantic Priority**: Size values become `filesize`, timestamps become `datetime`
- **Pipeline Optimization**: Prefer `table<>` over `list<record<>>` for list outputs
- **Constraint Preservation**: Maintain AWS validation rules in generated types
- **Recursive Handling**: Support nested structures with proper type composition

### Completion Strategy
- **AWS Resource Priority**: BucketName → `@"nu-complete aws s3 buckets"`
- **Enum Handling**: Direct choice strings `@"choice1 choice2 choice3"`
- **Error Resilience**: Return empty lists on AWS call failures
- **Performance**: Cache completion results for repeated use

### Error Handling Strategy
- **Graceful Degradation**: Missing completions don't break generation
- **Type Safety**: Invalid type mappings fall back to `any` with warnings
- **Validation Gates**: Comprehensive validation before signature generation

## Implementation Patterns

### Pure Functional Design
- All functions are pure (no side effects)
- Immutable data structures throughout
- Composable function pipeline
- Easy testing and debugging

### Kent Beck TDD Philosophy Integration
The implementation follows Kent Beck's core TDD principles and testing philosophy:

#### Test-Driven Development Cycles
- **Red-Green-Refactor**: Every function begins with a failing test, minimal implementation, then improvement
- **Baby Steps**: Each test covers the smallest possible behavior increment
- **Triangulation**: Use multiple test cases to drive out the right abstraction
- **Clean Code That Works**: Tests serve as executable specifications and safety net for refactoring

#### Beck's Testing Strategies
- **Obvious Implementation**: For simple logic, implement directly if the solution is clear
- **Fake It ('Til You Make It)**: Return constants first, then gradually introduce variables
- **Triangulation**: Add test cases to force generalization when unsure of the right design
- **Test Data Builders**: Create fluent builders for complex test scenarios (AWS schema fixtures)

#### Design Patterns from Beck's Philosophy
- **Test as Documentation**: Tests serve as living documentation of system behavior
- **Fail Fast**: Tests catch errors at the earliest possible moment
- **Test Isolation**: Each test is independent and can run in any order
- **Arrange-Act-Assert**: Clear three-phase structure for all tests
- **One Assertion Per Concept**: Tests verify single behavioral aspects

#### TDD Quality Practices
- **Test Names as Specifications**: Test names clearly describe expected behavior
  ```nushell
  #[test]
  def "test map-aws-type-to-nushell converts timestamp to datetime" [] { ... }
  ```
- **Test-First API Design**: Tests drive the shape of function interfaces
- **Refactoring Safety Net**: Comprehensive tests enable confident refactoring
- **Test Coverage as Confidence**: 90%+ coverage ensures thorough behavior verification

#### Beck's Testing Pyramid Applied
- **Unit Tests (80%)**: Pure function testing with comprehensive edge cases
- **Integration Tests (15%)**: Component interaction testing with real schemas
- **System Tests (5%)**: End-to-end signature generation validation

#### Test Data Strategy (Beck-Inspired)
- **Fixture Builders**: Composable test data creation following Beck's builder pattern
- **Boundary Value Testing**: Test edge cases, nulls, empty collections, malformed input
- **Property-Based Testing**: Generate test cases to verify function properties
- **Test Data Independence**: Each test creates its own data to avoid coupling

### Performance Considerations
- Lazy evaluation for expensive operations
- Caching for repeated computations
- Efficient data structure choices
- Memory-conscious processing

## Integration Points

### Upstream Dependencies
- **OpenAPI Extraction**: Consumes normalized schemas
- **Real Schemas**: Processes existing service schemas in `real-schemas/`
- **Nutest Framework**: Uses existing testing infrastructure

### Downstream Integration
- **Code Generation**: Provides signatures for code generators
- **Documentation**: Supplies type information for docs
- **Validation**: Enables type checking in generated code

## Quality Assurance

### Testing Strategy
- **Unit Tests**: Every helper function with edge cases
- **Integration Tests**: Real schema processing
- **Performance Tests**: Large schema handling
- **Syntax Validation**: Generated signatures parse correctly

### Validation Framework
- **Type Completeness**: All AWS types map to Nushell types
- **Syntax Compliance**: Generated code follows Nushell 0.85+ syntax
- **Completion Coverage**: Major AWS resources have completions
- **Documentation Preservation**: AWS docs maintain fidelity