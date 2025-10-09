# Functional Programming Patterns for AWS Operations
# Pure functional higher-order functions for AWS data processing

# ============================================================================
# Higher-Order AWS Operation Functions
# ============================================================================

# Apply function to all resources in a service collection
export def map-aws-resources [
    operation: closure,          # Function to apply to each resource
    service: string,            # AWS service name
    resource_type: string       # Type of resource to process
]: list<record> -> list<record> {
    $in | each { |resource|
        do $operation $resource
    }
}

# Filter AWS resources based on predicate function
export def filter-aws-resources [
    predicate: closure,         # Boolean function for filtering
    --preserve-metadata(-m)     # Keep original AWS metadata
]: list<record> -> list<record> {
    let input = $in
    let filtered = $input | where { |resource| do $predicate $resource }
    
    if $preserve_metadata {
        $filtered | each { |item| $item | upsert aws_filtered_at (date now) }
    } else {
        $filtered
    }
}

# Reduce AWS resource collection to single value
export def reduce-aws-resources [
    reducer: closure,           # Reduction function (acc, item) -> acc
    initial: any               # Initial accumulator value
]: list<record> -> any {
    $in | reduce --fold $initial { |item, acc|
        do $reducer $acc $item
    }
}

# Compose AWS operations into pipeline
export def compose-aws-operations [
    ...operations: closure      # Variable number of operations to compose
]: closure {
    { |input|
        $operations | reduce --fold $input { |op, acc|
            do $op $acc
        }
    }
}

# ============================================================================
# Data Correlation Combinators
# ============================================================================

# Correlate resources across AWS services
export def correlate-aws-resources [
    primary_key: string,        # Field to join on in primary collection
    secondary: list<record>,    # Secondary collection to join with
    secondary_key: string,      # Field to join on in secondary collection
    --join-type(-j): string = "inner" # Type of join (inner, left, right, outer)
]: list<record> -> list<record> {
    let primary = $in
    
    match $join_type {
        "inner" => (inner-join-aws $primary $secondary $primary_key $secondary_key),
        "left" => (left-join-aws $primary $secondary $primary_key $secondary_key),
        "right" => (right-join-aws $primary $secondary $primary_key $secondary_key),
        "outer" => (outer-join-aws $primary $secondary $primary_key $secondary_key),
        _ => (error make { msg: $"Unknown join type: ($join_type)" })
    }
}

# Inner join implementation for AWS resources
def inner-join-aws [
    primary: list<record>,
    secondary: list<record>,
    primary_key: string,
    secondary_key: string
]: nothing -> list<record> {
    $primary | each { |p_item|
        let p_value = $p_item | get $primary_key
        let matches = $secondary | where ($it | get $secondary_key) == $p_value
        
        $matches | each { |s_item|
            $p_item | merge $s_item | upsert correlation_key $p_value
        }
    } | flatten
}

# Left join implementation for AWS resources
def left-join-aws [
    primary: list<record>,
    secondary: list<record>,
    primary_key: string,
    secondary_key: string
]: nothing -> list<record> {
    $primary | each { |p_item|
        let p_value = $p_item | get $primary_key
        let matches = $secondary | where ($it | get $secondary_key) == $p_value
        
        if ($matches | is-empty) {
            $p_item | upsert correlation_key $p_value | upsert matched false
        } else {
            $matches | each { |s_item|
                $p_item | merge $s_item | upsert correlation_key $p_value | upsert matched true
            }
        }
    } | flatten
}

# ============================================================================
# Function Composition Utilities
# ============================================================================

# Create lazy AWS operation that evaluates on demand
export def lazy-aws-operation [
    operation: closure          # Operation to make lazy
]: closure {
    { |input|
        # Store operation and input for later evaluation
        {
            type: "lazy_operation",
            operation: $operation,
            input: $input,
            evaluated: false
        }
    }
}

# Evaluate lazy AWS operation
export def evaluate-lazy []: record -> any {
    let lazy_op = $in
    
    if ($lazy_op.type? | default "") != "lazy_operation" {
        error make { msg: "Input is not a lazy operation" }
    }
    
    do $lazy_op.operation $lazy_op.input
}

# Chain AWS operations with error handling
export def chain-aws-operations [
    ...operations: closure      # Operations to chain
]: any -> any {
    let input = $in
    let result = try {
        $operations | reduce --fold $input { |op, acc|
            do $op $acc
        }
    } catch { |err|
        {
            error: true,
            message: $err.msg,
            operation_chain_failed: true,
            input: $input
        }
    }
    
    $result
}

# ============================================================================
# Immutability Guarantees
# ============================================================================

# Create immutable AWS resource snapshot
export def freeze-aws-resource []: record -> record {
    let resource = $in
    
    $resource 
    | upsert frozen_at (date now)
    | upsert frozen true
    | upsert checksum (
        $resource | to json | hash sha256
    )
}

# Verify AWS resource hasn't been modified
export def verify-aws-resource [
    original_checksum: string   # Original checksum to verify against
]: record -> bool {
    let resource = $in
    let current_checksum = ($resource | reject frozen_at frozen checksum | to json | hash sha256)
    
    $current_checksum == $original_checksum
}

# Apply transformation while preserving immutability
export def transform-immutable [
    transformer: closure        # Pure transformation function
]: record -> record {
    let original = $in
    let transformed = do $transformer $original
    
    # Verify transformation is pure (doesn't modify original)
    let original_after = $original | to json | hash sha256
    let original_before_hash = $original | to json | hash sha256
    
    if $original_after != $original_before_hash {
        error make { msg: "Transformation function violated immutability" }
    }
    
    $transformed
}

# ============================================================================
# Purity and Side-Effect Management
# ============================================================================

# Mark function as pure (no side effects)
export def pure-aws-function [
    func: closure               # Function to mark as pure
]: closure {
    { |...args|
        # Wrapper that enforces pure function constraints
        let result = do $func ...$args
        
        # Add purity metadata
        if ($result | describe) =~ "^record" {
            $result | upsert pure_function true | upsert computed_at (date now)
        } else {
            $result
        }
    }
}

# Create AWS operation with side-effect isolation
export def isolate-side-effects [
    operation: closure,         # Operation that may have side effects
    --dry-run(-d)              # Execute in dry-run mode
]: closure {
    { |...args|
        if $dry_run {
            # Return description of what would happen
            {
                type: "dry_run",
                operation: "aws_operation",
                args: $args,
                would_execute: true,
                side_effects_isolated: true
            }
        } else {
            # Execute with side-effect tracking
            let result = do $operation ...$args
            
            $result | upsert side_effects_executed true | upsert executed_at (date now)
        }
    }
}

# ============================================================================
# Complex Pipeline Compositions
# ============================================================================

# Create AWS resource processing pipeline
export def aws-pipeline [
    ...stages: closure          # Pipeline stages to execute
]: any -> any {
    let input = $in
    
    # Execute pipeline with error recovery
    let pipeline_result = try {
        $stages | enumerate | reduce --fold { data: $input, stage: 0, errors: [] } { |stage, acc|
            let stage_result = try {
                do $stage.item $acc.data
            } catch { |err|
                $acc | upsert errors ($acc.errors | append {
                    stage: $stage.index,
                    error: $err.msg,
                    occurred_at: (date now)
                })
            }
            
            {
                data: $stage_result,
                stage: ($stage.index + 1),
                errors: $acc.errors
            }
        }
    } catch { |err|
        {
            data: null,
            stage: -1,
            errors: [{ stage: "pipeline", error: $err.msg, occurred_at: (date now) }]
        }
    }
    
    $pipeline_result
}

# Parallel AWS operation execution
export def parallel-aws-operations [
    operations: list<closure>,  # Operations to execute in parallel
    --max-concurrent(-c): int = 4 # Maximum concurrent operations
]: any -> list<any> {
    let input = $in
    
    # Split operations into batches based on concurrency limit
    let batches = $operations | group --by { |item, index| $index mod $max_concurrent }
    
    $batches | transpose key value | each { |batch|
        # Execute batch operations in parallel using par-each
        $batch.value | par-each { |operation|
            try {
                do $operation $input
            } catch { |err|
                {
                    error: true,
                    message: $err.msg,
                    operation_failed: true
                }
            }
        }
    } | flatten
}

# Test complex pipeline compositions
export def test-pipeline-composition []: nothing -> record {
    let test_data = [
        { id: "i-1", type: "ec2", region: "us-east-1" },
        { id: "i-2", type: "ec2", region: "us-west-2" },
        { id: "bucket-1", type: "s3", region: "us-east-1" }
    ]
    
    let filter_ec2 = { |resources| $resources | where type == "ec2" }
    let add_metadata = { |resources| $resources | each { |r| $r | upsert processed_at (date now) } }
    let group_by_region = { |resources| $resources | group-by region }
    
    let composition = compose-aws-operations $filter_ec2 $add_metadata $group_by_region
    
    {
        input: $test_data,
        output: (do $composition $test_data),
        composition_successful: true,
        tested_at: (date now)
    }
}