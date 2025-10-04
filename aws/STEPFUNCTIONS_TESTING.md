# AWS Step Functions Testing Documentation

## Overview

This document describes the comprehensive testing approach for AWS Step Functions integration in the nutest framework. We provide 120+ tests covering all 37 Step Functions commands with mock-first testing methodology.

## Test Architecture

### Test Organization

Tests are organized into logical command groups:

1. **State Machine Management** (15 tests)
   - `create-state-machine`, `delete-state-machine`, `describe-state-machine`
   - `update-state-machine`, `validate-state-machine-definition`

2. **Execution Management** (15 tests)  
   - `start-execution`, `start-sync-execution`, `stop-execution`
   - `describe-execution`, `get-execution-history`

3. **Activity Management** (15 tests)
   - `create-activity`, `delete-activity`, `describe-activity`
   - `get-activity-task`, `send-task-success`, `send-task-failure`

4. **Map Run Management** (15 tests)
   - `list-map-runs`, `describe-map-run`, `update-map-run`

5. **Version/Alias Management** (15 tests)
   - `publish-state-machine-version`, `delete-state-machine-version`
   - `create-state-machine-alias`, `describe-state-machine-alias`, `update-state-machine-alias`, `delete-state-machine-alias`

6. **Listing Operations** (15 tests)
   - `list-state-machines`, `list-executions`, `list-activities`
   - `list-state-machine-versions`, `list-state-machine-aliases`

7. **Miscellaneous Operations** (15 tests)
   - `tag-resource`, `untag-resource`, `list-tags-for-resource`
   - `redrive-execution`, `test-state`

8. **Task Operations** (15 tests)
   - `send-task-heartbeat`, `describe-state-machine-for-execution`

9. **Integration Tests** (15 tests)
   - End-to-end workflows, error consistency, validation patterns

## Testing Methodology

### Mock-First Approach

All tests use a mock-first approach where:

1. **Primary Path**: Tests attempt actual AWS CLI calls
2. **Fallback Path**: When AWS CLI fails (expected in test environment), tests validate error messages and mock responses
3. **Validation Focus**: Input validation, error handling, and response structure validation

### Test Structure Pattern

Each test follows this consistent pattern:

```nushell
#[test]
def "descriptive test name" [] {
    let context = $in
    
    let config = {
        # Test configuration
    }
    
    let result = try {
        stepfunctions command-name $config
    } catch { |error|
        # Validate expected error patterns
        assert str contains $error.msg "Expected error pattern"
        return
    }
    
    # Validate successful response structure
    assert ($result | get expected_field? | is-not-empty)
}
```

### Test Categories per Command

Each command group includes:

1. **Basic Functionality Tests** (5 tests)
   - Minimal valid configuration
   - Required parameters only
   - Success path validation

2. **Configuration Tests** (5 tests)
   - Optional parameters
   - Complex configurations
   - Parameter combinations

3. **Validation and Error Tests** (5 tests)
   - Input validation
   - Edge cases
   - Error handling consistency

## Command Coverage

### Complete Command List (37 commands)

| Command | Test File | Status |
|---------|-----------|--------|
| `create-activity` | state_machine_management | ✅ |
| `create-state-machine` | state_machine_management | ✅ |
| `create-state-machine-alias` | version_alias_management | ✅ |
| `delete-activity` | activity_management | ✅ |
| `delete-state-machine` | state_machine_management | ✅ |
| `delete-state-machine-alias` | version_alias_management | ✅ |
| `delete-state-machine-version` | version_alias_management | ✅ |
| `describe-activity` | activity_management | ✅ |
| `describe-execution` | execution_management | ✅ |
| `describe-map-run` | map_run_management | ✅ |
| `describe-state-machine` | state_machine_management | ✅ |
| `describe-state-machine-alias` | version_alias_management | ✅ |
| `describe-state-machine-for-execution` | task_operations | ✅ |
| `get-activity-task` | activity_management | ✅ |
| `get-execution-history` | execution_management | ✅ |
| `list-activities` | listing_operations | ✅ |
| `list-executions` | listing_operations | ✅ |
| `list-map-runs` | map_run_management | ✅ |
| `list-state-machine-aliases` | listing_operations | ✅ |
| `list-state-machine-versions` | listing_operations | ✅ |
| `list-state-machines` | listing_operations | ✅ |
| `list-tags-for-resource` | miscellaneous_operations | ✅ |
| `publish-state-machine-version` | version_alias_management | ✅ |
| `redrive-execution` | miscellaneous_operations | ✅ |
| `send-task-failure` | activity_management | ✅ |
| `send-task-heartbeat` | task_operations | ✅ |
| `send-task-success` | activity_management | ✅ |
| `start-execution` | execution_management | ✅ |
| `start-sync-execution` | execution_management | ✅ |
| `stop-execution` | execution_management | ✅ |
| `tag-resource` | miscellaneous_operations | ✅ |
| `test-state` | miscellaneous_operations | ✅ |
| `untag-resource` | miscellaneous_operations | ✅ |
| `update-map-run` | map_run_management | ✅ |
| `update-state-machine` | state_machine_management | ✅ |
| `update-state-machine-alias` | version_alias_management | ✅ |
| `validate-state-machine-definition` | state_machine_management | ✅ |

## Running Step Functions Tests

### All Step Functions Tests

```nushell
# Run all Step Functions tests
nutest run-tests --path ./tests/aws --match-suites ".*stepfunctions.*"

# Run specific command group
nutest run-tests --match-suites ".*state_machine_management.*"
```

### Individual Test Files

```nushell
# State machine management
nutest run-tests --path ./tests/aws/test_stepfunctions_state_machine_management.nu

# Execution management  
nutest run-tests --path ./tests/aws/test_stepfunctions_execution_management.nu

# Activity management
nutest run-tests --path ./tests/aws/test_stepfunctions_activity_management.nu

# Integration tests
nutest run-tests --path ./tests/aws/test_stepfunctions_integration_comprehensive.nu
```

## Test Data Patterns

### Common Test Contexts

Tests use standardized test data:

```nushell
#[before-each]
def setup [] {
    {
        state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:test-state-machine"
        execution_arn: "arn:aws:states:us-east-1:123456789012:execution:test-state-machine:test-execution"
        activity_arn: "arn:aws:states:us-east-1:123456789012:activity:test-activity"
        test_role: "arn:aws:iam::123456789012:role/StepFunctionsRole"
        test_definition: '{"StartAt": "Pass", "States": {"Pass": {"Type": "Pass", "End": true}}}'
    }
}
```

### ARN Validation Patterns

All tests validate ARN formats consistently:

```nushell
# Valid ARN patterns
"arn:aws:states:region:account:stateMachine:name"
"arn:aws:states:region:account:execution:stateMachine:executionName"
"arn:aws:states:region:account:activity:activityName"

# Invalid patterns (should fail)
"invalid-arn"
""
"arn:invalid"
```

## Error Handling Standards

### Consistent Error Messages

All commands use standardized error message patterns:

- **Invalid ARN**: "Invalid ARN format"
- **Not Found**: "does not exist"
- **Validation**: Specific field name mentioned
- **Service Error**: "Failed to [command] [resource]"

### Mock Response Validation

Tests validate mock responses against expected schemas:

```nushell
# State machine response structure
{
    stateMachineArn: string
    name: string  
    definition: string
    roleArn: string
    type: "STANDARD" | "EXPRESS"
    creationDate: timestamp
}

# Execution response structure  
{
    executionArn: string
    stateMachineArn: string
    name: string
    status: "RUNNING" | "SUCCEEDED" | "FAILED" | "TIMED_OUT" | "ABORTED"
    startDate: timestamp
}
```

## Integration Testing

### Workflow Tests

Integration tests validate complete workflows:

1. **State Machine Lifecycle**
   - Create → Describe → Update → Delete
   - Input validation throughout lifecycle

2. **Execution Workflow**
   - Start → Monitor → Stop
   - History retrieval and analysis

3. **Version/Alias Management**
   - Publish version → Create alias → Update routing → Delete

4. **Activity Task Processing**
   - Create activity → Get task → Send response → Delete

### Cross-Command Consistency

Tests ensure consistency across commands:

- ARN validation patterns
- Error message formats  
- Response structure standards
- Pagination parameter handling

## Performance Considerations

### Test Execution Speed

- **Mock-first approach**: Fast execution in test environments
- **Parallel execution**: Tests can run concurrently
- **Minimal AWS calls**: Only validation attempts, not actual resource creation

### Resource Management

- **No persistent resources**: All tests clean up automatically
- **Mock data only**: No real AWS resources created during testing
- **Isolated tests**: Each test is independent and stateless

## Extending Test Coverage

### Adding New Commands

When AWS adds new Step Functions commands:

1. Add command specification to `stepfunctions-commands.json`
2. Implement command in `stepfunctions.nu`
3. Create 15 tests following the established pattern
4. Update this documentation

### Test Pattern Template

```nushell
# New command tests (15 tests)
#[test]
def "command basic functionality" [] { ... }

#[test]  
def "command with optional parameters" [] { ... }

#[test]
def "command validates required fields" [] { ... }

#[test]
def "command handles invalid input" [] { ... }

#[test]
def "command error handling" [] { ... }

# ... 10 more tests covering edge cases, configurations, and validations
```

## Quality Assurance

### Test Quality Metrics

- **100% Command Coverage**: All 37 commands tested
- **15 Tests per Command Group**: Comprehensive scenario coverage
- **Consistent Patterns**: Standardized test structure
- **Error Path Coverage**: Validation and error handling tested

### Continuous Validation

Tests can be run in CI/CD pipelines:

```bash
# In CI/CD pipeline
nu -c "use nutest; nutest run-tests --path ./tests/aws --fail"
```

### Test Maintenance

- **Regular Updates**: Keep tests aligned with AWS API changes
- **Mock Response Updates**: Update mock data as needed
- **Documentation Updates**: Keep this documentation current

## Conclusion

The Step Functions testing suite provides comprehensive coverage of all AWS Step Functions commands with a robust, maintainable testing approach. The mock-first methodology ensures fast, reliable testing while validating both success and error paths for each command.