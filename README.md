# Nutest Framework

A comprehensive testing framework for Nushell scripts and applications with extensive AWS Step Functions integration.

## Overview

Nutest is a robust testing framework designed specifically for Nushell scripts. It provides test discovery, execution, reporting, and various display options. The framework includes specialized support for AWS Step Functions testing with 37 Step Functions commands and 555+ comprehensive tests.

## Quick Start

```nushell
# Install and run basic tests
use nutest
nutest run-tests

# Run with specific options
nutest run-tests --display terminal --returns summary --fail
```

## Project Structure

```
nutest-framework/
├── mod.nu                  # Main API: list-tests, run-tests
├── discover.nu             # Test discovery engine
├── runner.nu               # Individual test execution
├── orchestrator.nu         # Test suite orchestration
├── store.nu                # Test result storage and query
├── formatter.nu            # Output formatting (preserved, unformatted, pretty)
├── theme.nu                # Color themes (none, standard)
├── errors.nu               # Error handling and unwrapping
├── completions.nu          # Shell completion support
├── display/                # Display modules for test output
│   ├── display_nothing.nu  # Silent execution
│   ├── display_table.nu    # Tabular results display
│   └── display_terminal.nu # Real-time terminal output
├── returns/                # Return format modules
│   ├── returns_nothing.nu  # No return value
│   ├── returns_summary.nu  # Test run summary
│   └── returns_table.nu    # Full test results table
├── report/                 # Report generation modules
│   ├── report_nothing.nu   # No report generation
│   └── report_junit.nu     # JUnit XML reports
├── aws/                    # AWS Step Functions integration
│   ├── stepfunctions.nu    # 37 Step Functions commands
│   ├── stepfunctions-commands.json # Command specifications
│   ├── dynamodb.nu         # DynamoDB integration
│   └── lambda.nu           # Lambda integration
├── tests/                  # Comprehensive test suite (240+ tests)
│   ├── aws/                # Step Functions tests (555+ tests)
│   ├── display/            # Display module tests
│   └── test_*.nu           # Framework component tests
└── utils/                  # Testing utilities and helpers
    └── test_utils.nu       # Common assertions and test data
```

## Core Commands

### Test Discovery

```nushell
# List all discoverable tests
nutest list-tests

# List tests in specific directory
nutest list-tests --path ./my-project/tests

# Output: Table with suite and test columns
# │ suite          │ test               │
# │ test_auth      │ login_success      │
# │ test_auth      │ login_failure      │
# │ test_database  │ connection_test    │
```

### Test Execution

```nushell
# Basic test run
nutest run-tests

# Advanced test execution with filtering
nutest run-tests \
  --path ./tests \
  --match-suites "integration.*" \
  --match-tests "auth.*" \
  --strategy { threads: 4 } \
  --display terminal \
  --returns summary \
  --report { type: "junit", path: "results.xml" } \
  --fail
```

#### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--path` | string | Test directory location | Current directory |
| `--match-suites` | string | Regex for suite names | `".*"` (all) |
| `--match-tests` | string | Regex for test names | `".*"` (all) |
| `--strategy` | record | Execution strategy | `{ threads: 0 }` |
| `--display` | string | Display mode | `"terminal"` |
| `--returns` | string | Return format | `"nothing"` |
| `--report` | record | Report configuration | None |
| `--fail` | flag | Exit with error on failures | false |

## Writing Tests

### Test Annotations

Nutest uses function annotations to discover and categorize tests:

```nushell
# [test] - Mark as a test case
#[test]
def "user authentication success" [] {
    let user = { username: "admin", password: "secret" }
    let result = authenticate $user
    assert ($result.status == "success")
}

# [ignore] - Skip this test
#[ignore]
def "flaky test to investigate" [] {
    # This test will be discovered but skipped
}

# [before-each] - Setup before each test
#[before-each]
def setup [] {
    mkdir test_temp
    { temp_dir: "test_temp" }
}

# [after-each] - Cleanup after each test
#[after-each]
def cleanup [] {
    let context = $in
    rm -rf $context.temp_dir
}

# [before-all] - Setup before all tests in suite
#[before-all]
def setup_suite [] {
    start_test_server
}

# [after-all] - Cleanup after all tests in suite
#[after-all]
def cleanup_suite [] {
    stop_test_server
}
```

### Test Context and Lifecycle

```nushell
#[before-each]
def setup [] {
    let temp = mktemp --directory
    {
        temp: $temp
        database: (create_test_database $temp)
    }
}

#[after-each] 
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

#[test]
def "database operations" [] {
    let context = $in
    let db = $context.database
    
    # Use test context in your test
    db insert_user { name: "test", email: "test@example.com" }
    let users = db get_users
    
    assert equal ($users | length) 1
}
```

## Display Modes

### Terminal Display (Default)

Shows real-time test results as they complete:

```
Running tests...
✅ test_auth login_success
❌ test_auth login_failure
  Error: Authentication failed
  Expected: success
  Actual: failure
🚧 test_database connection_test
Test run completed: 3 total, 1 passed, 1 failed, 1 skipped
```

### Table Display

Collects all results and displays as a formatted table:

```nushell
nutest run-tests --display table
```

### Silent Display

No output during execution (useful when piping results):

```nushell
nutest run-tests --display nothing
```

## Return Formats

### Summary Return

```nushell
let summary = nutest run-tests --returns summary
# Returns: { total: 10, passed: 8, failed: 1, skipped: 1 }
```

### Table Return

```nushell
let results = nutest run-tests --returns table
# Returns: Table with suite, test, result, output columns
```

### Nothing Return (Default)

```nushell
nutest run-tests  # Returns null, useful for CI/CD
```

## Test Execution Strategies

### Single-threaded (Default)

```nushell
nutest run-tests --strategy { threads: 0 }
```

### Multi-threaded

```nushell
nutest run-tests --strategy { threads: 4 }
```

## Report Generation

### JUnit XML Reports

Generate JUnit-compatible XML reports for CI/CD integration:

```nushell
nutest run-tests --report { 
    type: "junit", 
    path: "test-results.xml" 
}
```

Example JUnit XML output:
```xml
<testsuites name="nutest" tests="3" disabled="1" failures="1">
  <testsuite name="test_auth" tests="2" disabled="0" failures="1">
    <testcase name="login_success" classname="test_auth"/>
    <testcase name="login_failure" classname="test_auth">
      <failure type="Error" message="Authentication failed"/>
    </testcase>
  </testsuite>
</testsuites>
```

## Testing Utilities

The framework includes comprehensive testing utilities in `utils/test_utils.nu`:

### Enhanced Assertions

```nushell
use utils/test_utils.nu

# Basic assertions
assert_equal $actual $expected "Values should match"
assert_not_equal $actual $unexpected "Values should differ"
assert_type $value "string" "Should be string type"
assert_contains $list $item "List should contain item"
assert_not_contains $list $item "List should not contain item"
assert_error { risky_operation } "Should throw error"
assert_no_error { safe_operation } "Should not throw error"

# Advanced assertions
assert_greater_than $actual 10 "Should be greater than 10"
assert_less_than $actual 100 "Should be less than 100"
assert_matches $text "regex.*pattern" "Should match pattern"
assert_file_exists "path/to/file" "File should exist"
assert_empty $collection "Collection should be empty"
assert_not_empty $collection "Collection should have items"
```

### Test Data Generation

```nushell
# Generate realistic test data
let users = generate_test_users 10
let products = generate_test_products 5
let orders = generate_test_orders 20

# Generate mixed datasets
let test_data = generate_mixed_test_data 10 5
```

### Performance Testing

```nushell
# Benchmark operations
let benchmark = benchmark_operation "database_query" {
    database query "SELECT * FROM users WHERE active = true"
}

# Returns: { operation: "database_query", duration_ms: 45.2, memory_mb: 12.8 }
```

## AWS Step Functions Integration

The framework includes comprehensive AWS Step Functions support with 37 commands and 555+ tests:

### Available Commands

- **State Machine Management**: `create-state-machine`, `delete-state-machine`, `describe-state-machine`
- **Execution Control**: `start-execution`, `stop-execution`, `describe-execution`
- **Activity Management**: `create-activity`, `delete-activity`, `get-activity-task`
- **Map Runs**: `list-map-runs`, `describe-map-run`, `update-map-run`
- **Version Control**: `create-state-machine-alias`, `describe-state-machine-alias`

### Testing Step Functions

```nushell
# Run Step Functions tests
nutest run-tests --path ./aws --match-suites ".*stepfunctions.*"

# Test specific Step Functions commands
nutest run-tests --match-tests "create_state_machine.*"
```

## CI/CD Integration

### Exit Code Support

Use the `--fail` flag to make nutest exit with non-zero status on test failures:

```bash
#!/bin/bash
# In your CI pipeline
nu -c "use nutest; nutest run-tests --fail"
if [ $? -ne 0 ]; then
    echo "Tests failed!"
    exit 1
fi
```

### GitHub Actions Example

```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hustcer/setup-nu@v3
      - name: Run tests
        run: |
          nu -c "use nutest; nutest run-tests --fail --report { type: 'junit', path: 'results.xml' }"
      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Test Results
          path: results.xml
          reporter: java-junit
```

## Advanced Configuration

### Custom Test Strategies

```nushell
# Custom parallel execution
let strategy = {
    threads: 8
    timeout_ms: 30000
    retry_count: 3
}
nutest run-tests --strategy $strategy
```

### Environment-Specific Testing

```nushell
# Development environment
$env.TEST_ENV = "dev"
nutest run-tests --match-suites "unit.*"

# Production environment
$env.TEST_ENV = "prod"
nutest run-tests --match-suites "integration.*" --fail
```

## Troubleshooting

### Common Issues

1. **Test Discovery Problems**
   ```nushell
   # Check if tests are discoverable
   nutest list-tests --path ./tests
   ```

2. **Test Execution Failures**
   ```nushell
   # Run with detailed output
   nutest run-tests --display terminal --returns table
   ```

3. **Performance Issues**
   ```nushell
   # Reduce parallelism
   nutest run-tests --strategy { threads: 1 }
   ```

### Debug Mode

```nushell
# Enable verbose error reporting
$env.NU_BACKTRACE = 1
nutest run-tests --display terminal
```

## Framework Architecture

### Core Components

1. **Discovery Engine**: Scans files for test annotations
2. **Test Runner**: Executes individual tests with lifecycle management
3. **Orchestrator**: Manages test execution strategies and coordination
4. **Store**: Centralizes test results and state management
5. **Display System**: Modular output formatting and display
6. **Report Generator**: Creates various report formats

### Extension Points

The framework is designed for extensibility:

- **Custom Display Modules**: Add new display formats
- **Custom Return Formats**: Add new result return types
- **Custom Report Generators**: Add new report formats
- **Custom Test Strategies**: Add new execution strategies

## Migration Guide

### From Project-Specific Implementations

This framework consolidates testing capabilities from:
- `/aws-nushell-login/nutest/`
- `/aws-serverless-test-framework/_nutest/`
- `/dynamodb-nu-loader/tests/helpers/`

#### Migration Steps

1. Replace project-specific test runners with `use nutest`
2. Update test annotations to match framework conventions
3. Migrate custom assertions to `utils/test_utils.nu`
4. Update CI/CD pipelines to use framework commands

### Version Compatibility

- **Nushell**: Requires 0.80.0 or later
- **Platform**: Cross-platform (Linux, macOS, Windows)
- **Dependencies**: Standard library only

## Contributing

### Running Framework Tests

```nushell
# Run all framework tests
nutest run-tests --path ./tests

# Run specific component tests
nutest run-tests --match-suites "formatter.*"

# Run AWS Step Functions tests
nutest run-tests --path ./tests/aws
```

### Test Coverage

The framework maintains comprehensive test coverage:
- **Core Components**: 15 tests per module (180+ tests)
- **AWS Step Functions**: 15 tests per command (555+ tests)
- **Integration Tests**: End-to-end scenarios
- **Utilities**: Assertion and helper function tests

### Adding New Features

1. Write tests first (TDD approach)
2. Implement feature with pure functional code
3. Add documentation and examples
4. Ensure 100% test coverage

## License

[Specify your license here]

## Support

- **Issues**: [Repository issue tracker]
- **Documentation**: This README and inline code comments
- **Examples**: See `tests/` directory for usage examples