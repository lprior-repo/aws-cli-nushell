# Nutest Framework Test Plan

## Goal: 15 unique test cases per core component covering all execution paths

### 1. mod.nu (Main Commands: list-tests, run-tests)

**list-tests command (7 tests):**
1. List tests with default path (current directory)
2. List tests with specified path
3. List tests with non-existent path (error case)
4. List tests with empty directory
5. List tests filtering by test type (test vs ignore)
6. List tests with nested directory structure
7. List tests with malformed test files

**run-tests command (8 tests):**
8. Run tests with all default options
9. Run tests with match-suites filter
10. Run tests with match-tests filter
11. Run tests with custom strategy (thread count)
12. Run tests with different display options (none, terminal, table)
13. Run tests with different return options (nothing, summary, table)
14. Run tests with report generation (junit)
15. Run tests with --fail flag behavior

### 2. discover.nu (15 tests focusing on unique scenarios)

**suite-files discovery (5 tests):**
1. Default glob pattern matching
2. Custom glob pattern
3. Suite file matcher regex
4. Single file path discovery
5. Non-existent path handling

**test-suites discovery (5 tests):**
6. Parse test annotations (test, ignore, before-each, after-each, before-all, after-all)
7. Test matcher regex filtering
8. Suite filtering with no matches
9. Malformed annotation handling
10. Mixed test types in single file

**Edge cases (5 tests):**
11. Empty test files
12. Parse errors in test files
13. Unicode test names
14. Special characters in test names
15. Very large test files

### 3. runner.nu (15 comprehensive execution tests)

**Basic execution (5 tests):**
1. Execute single passing test
2. Execute single failing test
3. Execute test with output
4. Execute test with error output
5. Execute test with mixed output types

**Lifecycle hooks (5 tests):**
6. Before-all execution and context passing
7. After-all execution and cleanup
8. Before-each execution per test
9. After-each execution per test
10. Hook failure propagation

**Advanced scenarios (5 tests):**
11. Parallel test execution
12. Context preservation across hooks
13. Output capture and formatting
14. Error handling and recovery
15. Performance with large test suites

### 4. orchestrator.nu (15 test orchestration scenarios)

**Suite orchestration (5 tests):**
1. Single suite execution
2. Multiple suite execution
3. Suite dependency handling
4. Suite failure isolation
5. Empty suite handling

**Event processing (5 tests):**
6. Test start events
7. Test complete events
8. Run start events
9. Run complete events
10. Event processor integration

**Strategy execution (5 tests):**
11. Sequential execution strategy
12. Parallel execution strategy
13. Custom thread count strategy
14. Strategy failure handling
15. Resource management during execution

### 5. store.nu (15 data persistence tests)

**Basic operations (5 tests):**
1. Store creation and initialization
2. Store deletion and cleanup
3. Result insertion
4. Result querying
5. Success status determination

**Concurrency (5 tests):**
6. Concurrent read operations
7. Concurrent write operations
8. Lock retry mechanism
9. Database locked error handling
10. Transaction isolation

**Data integrity (5 tests):**
11. Result data validation
12. Large dataset handling
13. Corruption recovery
14. State consistency
15. Memory management

## Implementation Strategy

1. **Audit existing tests** - Remove redundant tests, keep unique ones
2. **Gap analysis** - Identify missing test scenarios
3. **Implement missing tests** - Add tests to reach exactly 15 per component
4. **Validate coverage** - Ensure all execution paths are tested
5. **Performance validation** - Test suite should run efficiently

## Success Criteria

- Exactly 15 unique test cases per core component
- 100% branch coverage for all execution paths
- All tests follow TDD principles
- No redundant or overlapping test cases
- Test suite runs in under 30 seconds