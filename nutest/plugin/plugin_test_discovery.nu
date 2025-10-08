# Plugin Test Discovery - Enhanced test discovery for plugin modules
# Extends nutest discovery to handle plugin-specific test patterns and scenarios

use std assert

# Discovery patterns for plugin tests
const plugin_test_patterns = [
    '**/*{plugin,aws,completion,service}*test*.nu',  # Plugin-specific test files
    '**/test_{plugin,aws,completion,service}*.nu',    # Test prefix files
    '**/tests/{plugin,aws,service,completion}/**/*.nu' # Test directory structure
]

# Plugin-specific test annotations
const plugin_test_types = [
    "plugin-test",      # General plugin test
    "service-test",     # Service module test
    "completion-test",  # Completion system test
    "integration-test", # Integration test
    "mock-test",        # Test using mocks
    "performance-test", # Performance benchmark test
    "workflow-test"     # End-to-end workflow test
]

# Discover plugin test files
export def discover-plugin-tests [
    --path: string,
    --pattern: string,
    --include-integration = true,
    --include-performance = false
]: nothing -> table {
    
    let test_path = $path | default $env.PWD
    let search_pattern = $pattern | default $plugin_test_patterns.0
    
    # Discover test files using plugin patterns
    let plugin_test_files = discover-plugin-test-files $test_path $search_pattern
    
    # Parse each test file for plugin-specific annotations
    let plugin_test_suites = $plugin_test_files | each { |file|
        discover-plugin-test-suite $file
    }
    
    # Filter based on test types
    let filtered_suites = $plugin_test_suites | each { |suite|
        let filtered_tests = $suite.tests | where {|test|
            let include_test = match $test.type {
                "integration-test" => $include_integration,
                "performance-test" => $include_performance,
                _ => true
            }
            $include_test and ($test.type in (["test", "ignore"] | append $plugin_test_types))
        }
        
        $suite | update tests $filtered_tests
    } | where { |suite| ($suite.tests | length) > 0 }
    
    $filtered_suites
}

# Discover plugin test files using multiple patterns
def discover-plugin-test-files [
    test_path: string,
    pattern: string
]: nothing -> list<string> {
    
    let patterns_to_search = if $pattern in $plugin_test_patterns {
        $plugin_test_patterns
    } else {
        [$pattern]
    }
    
    mut all_files = []
    
    for search_pattern in $patterns_to_search {
        try {
            cd $test_path
            let files = glob $search_pattern
            $all_files = ($all_files | append $files)
        } catch {
            # Continue if pattern doesn't match anything
        }
    }
    
    # Remove duplicates and sort
    $all_files | uniq | sort
}

# Discover tests in a plugin test suite
def discover-plugin-test-suite [test_file: string]: nothing -> record {
    
    let query = plugin-test-query $test_file
    let result = (^$nu.current-exe --no-config-file --commands $query) | complete
    
    if $result.exit_code == 0 {
        try {
            let commands_data = $result.stdout | from nuon
            parse-plugin-test-suite $test_file $commands_data
        } catch {
            # Fallback to basic parsing if nuon parsing fails
            {
                name: ($test_file | path parse | get stem),
                path: $test_file,
                tests: [],
                plugin_metadata: {
                    parsing_error: true,
                    error_message: "Failed to parse test file"
                }
            }
        }
    } else {
        {
            name: ($test_file | path parse | get stem),
            path: $test_file,
            tests: [],
            plugin_metadata: {
                discovery_error: true,
                error_message: $result.stderr
            }
        }
    }
}

# Enhanced query for plugin tests
def plugin-test-query [file: string]: nothing -> string {
    let query = "
        scope commands
            | where ( $it.type == 'custom' and (
                ($it.attributes | is-not-empty) or 
                ($it.description =~ '\\[[a-z-]+\\]') or
                ($it.name =~ 'test') or
                ($it.name =~ 'plugin') or
                ($it.name =~ 'aws') or
                ($it.name =~ 'completion')
            ))
            | each { |item| {
                name: $item.name
                attributes: ($item.attributes | get name)
                description: $item.description
                signature: ($item.signatures | first | default {})
            } }
            | to nuon
    "
    $"source ($file); ($query)"
}

# Parse plugin test suite with enhanced metadata
def parse-plugin-test-suite [
    test_file: string,
    commands_data: list
]: nothing -> record {
    
    let tests = $commands_data | each { |cmd| parse-plugin-test $cmd }
    
    # Extract plugin metadata from the file
    let plugin_metadata = extract-plugin-metadata $test_file
    
    {
        name: ($test_file | path parse | get stem),
        path: $test_file,
        tests: $tests,
        plugin_metadata: $plugin_metadata
    }
}

# Parse individual plugin test with enhanced type detection
def parse-plugin-test [
    command_data: record
]: nothing -> record {
    
    let test_type = detect-plugin-test-type $command_data
    let test_tags = extract-test-tags $command_data
    let test_requirements = extract-test-requirements $command_data
    
    {
        name: $command_data.name,
        type: $test_type,
        tags: $test_tags,
        requirements: $test_requirements,
        signature: ($command_data.signature? | default {}),
        description: ($command_data.description? | default "")
    }
}

# Detect plugin-specific test types
def detect-plugin-test-type [command_data: record]: nothing -> string {
    
    # Check attributes first
    let attributes = $command_data.attributes? | default []
    for attr in $attributes {
        if $attr in (["test", "ignore"] | append $plugin_test_types) {
            return $attr
        }
    }
    
    # Check description for plugin test markers
    let description = $command_data.description? | default ""
    let description_matches = $description | parse --regex '.*\[([a-z-]+)\].*'
    
    if ($description_matches | length) > 0 {
        let extracted_type = $description_matches.0.capture0
        if $extracted_type in (["test", "ignore"] | append $plugin_test_types) {
            return $extracted_type
        }
    }
    
    # Check function name patterns
    let name = $command_data.name
    let name_patterns = [
        {pattern: "test.*plugin", type: "plugin-test"},
        {pattern: "test.*service", type: "service-test"},
        {pattern: "test.*completion", type: "completion-test"},
        {pattern: "test.*integration", type: "integration-test"},
        {pattern: "test.*mock", type: "mock-test"},
        {pattern: "test.*performance", type: "performance-test"},
        {pattern: "test.*workflow", type: "workflow-test"}
    ]
    
    for pattern_info in $name_patterns {
        if ($name | str contains $pattern_info.pattern) {
            return $pattern_info.type
        }
    }
    
    # Default classification
    if ($name | str contains "test") {
        "test"
    } else {
        "unsupported"
    }
}

# Extract test tags from comments or descriptions
def extract-test-tags [command_data: record]: nothing -> list<string> {
    let description = $command_data.description? | default ""
    
    # Look for tags in format @tag1 @tag2
    let tag_matches = $description | parse --regex '@([a-zA-Z0-9_-]+)'
    
    if ($tag_matches | length) > 0 {
        $tag_matches | get capture0
    } else {
        []
    }
}

# Extract test requirements (AWS services, mock mode, etc.)
def extract-test-requirements [command_data: record]: nothing -> record {
    let description = $command_data.description? | default ""
    let name = $command_data.name
    
    # Detect AWS service requirements
    let aws_services = [
        "s3", "ec2", "iam", "lambda", "dynamodb", "rds", 
        "sns", "sqs", "stepfunctions", "cloudformation"
    ]
    
    let required_services = $aws_services | where { |service|
        ($name | str contains $service) or ($description | str contains $service)
    }
    
    # Detect mock requirements
    let requires_mock = ($name | str contains "mock") or ($description | str contains "mock")
    
    # Detect AWS CLI requirements
    let requires_aws_cli = ($description | str contains "aws-cli") or ($description | str contains "aws cli")
    
    {
        aws_services: $required_services,
        requires_mock: $requires_mock,
        requires_aws_cli: $requires_aws_cli,
        estimated_duration: (estimate-test-duration $command_data)
    }
}

# Extract plugin metadata from test file
def extract-plugin-metadata [test_file: string]: nothing -> record {
    
    try {
        let file_content = open $test_file
        
        # Look for plugin metadata comments
        let metadata_lines = $file_content | lines | where { |line|
            let trimmed = $line | str trim
            (
                ($trimmed | str starts-with "# @") or
                ($trimmed | str starts-with "# Plugin:") or  
                ($trimmed | str starts-with "# Service:") or
                ($trimmed | str starts-with "# Requires:")
            )
        }
        
        let metadata = $metadata_lines | reduce -f {} { |line, acc|
            let clean_line = $line | str trim | str replace "# " ""
            
            if ($clean_line | str starts-with "@") {
                # Handle @key=value format
                let parts = $clean_line | str replace "@" "" | split row "="
                if ($parts | length) == 2 {
                    $acc | insert $parts.0 $parts.1
                } else {
                    $acc
                }
            } else if ($clean_line | str contains ":") {
                # Handle Key: value format
                let parts = $clean_line | split row ":"
                if ($parts | length) >= 2 {
                    let key = $parts.0 | str trim | str downcase | str replace " " "_"
                    let value = $parts | skip 1 | str join ":" | str trim
                    $acc | insert $key $value
                } else {
                    $acc
                }
            } else {
                $acc
            }
        }
        
        $metadata | insert file_size (ls $test_file | get size | first)
            | insert last_modified (ls $test_file | get modified | first)
    } catch {
        {
            error: "Failed to extract metadata",
            file_size: 0,
            last_modified: null
        }
    }
}

# Estimate test duration based on test type and content
def estimate-test-duration [command_data: record]: nothing -> string {
    let test_type = detect-plugin-test-type $command_data
    let name = $command_data.name
    
    match $test_type {
        "performance-test" => "long",      # 30+ seconds
        "integration-test" => "medium",    # 5-30 seconds
        "workflow-test" => "medium",       # 5-30 seconds
        "mock-test" => "short",           # < 5 seconds
        "plugin-test" => "short",         # < 5 seconds
        "service-test" => "short",        # < 5 seconds
        "completion-test" => "short",     # < 5 seconds
        _ => {
            if ($name | str contains "performance") or ($name | str contains "benchmark") {
                "long"
            } else if ($name | str contains "integration") or ($name | str contains "end-to-end") {
                "medium"
            } else {
                "short"
            }
        }
    }
}

# Create test execution plan based on dependencies and requirements
export def create-plugin-test-plan [
    test_suites: table,
    --strategy: string = "parallel",
    --respect-dependencies = true
]: nothing -> record {
    
    # Group tests by type and duration
    let test_groups = $test_suites | each { |suite|
        $suite.tests | each { |test|
            $test | insert suite_name $suite.name
                  | insert suite_path $suite.path
        }
    } | flatten | group-by type
    
    # Create execution phases
    let execution_phases = if $respect_dependencies {
        [
            {
                phase: 1,
                name: "setup_and_unit_tests",
                types: ["plugin-test", "service-test", "completion-test", "mock-test"],
                parallel: true
            },
            {
                phase: 2, 
                name: "integration_tests",
                types: ["integration-test", "workflow-test"],
                parallel: ($strategy == "parallel")
            },
            {
                phase: 3,
                name: "performance_tests", 
                types: ["performance-test"],
                parallel: false
            }
        ]
    } else {
        [
            {
                phase: 1,
                name: "all_tests",
                types: $plugin_test_types,
                parallel: ($strategy == "parallel")
            }
        ]
    }
    
    # Estimate total execution time
    let total_tests = $test_suites | each { |suite| $suite.tests | length } | math sum
    let estimated_duration = estimate-total-duration $test_groups $execution_phases $strategy
    
    {
        execution_phases: $execution_phases,
        test_groups: $test_groups,
        total_tests: $total_tests,
        estimated_duration: $estimated_duration,
        strategy: $strategy,
        respect_dependencies: $respect_dependencies,
        created_at: (date now)
    }
}

# Estimate total execution duration
def estimate-total-duration [
    test_groups: record,
    execution_phases: list,
    strategy: string
]: nothing -> string {
    
    let duration_estimates = {
        short: 2,   # seconds
        medium: 15, # seconds  
        long: 60    # seconds
    }
    
    mut total_seconds = 0
    
    for phase in $execution_phases {
        let phase_tests = $phase.types | each { |type|
            $test_groups | get $type --optional | default []
        } | flatten
        
        if ($phase_tests | length) > 0 {
            let phase_duration = if $phase.parallel {
                # Parallel execution - take the longest test
                $phase_tests | each { |test|
                    $duration_estimates | get ($test.requirements.estimated_duration)
                } | math max
            } else {
                # Sequential execution - sum all tests
                $phase_tests | each { |test| 
                    $duration_estimates | get ($test.requirements.estimated_duration)
                } | math sum
            }
            
            $total_seconds = $total_seconds + $phase_duration
        }
    }
    
    if $total_seconds < 60 {
        $"($total_seconds) seconds"
    } else if $total_seconds < 3600 {
        $"($total_seconds / 60 | math round) minutes"
    } else {
        $"($total_seconds / 3600 | math round) hours"
    }
}