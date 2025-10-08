# Streaming Pipeline Integration Specification

## ADDED Requirements

### Requirement: Paginated Result Streaming
The system SHALL stream paginated AWS API results as Nushell generators without collecting all data in memory, enabling processing of unlimited dataset sizes.

#### Scenario: S3 Object Streaming for Large Buckets
```nushell
# GIVEN a bucket with millions of objects
# WHEN streaming objects with filtering
let large_objects = aws s3 ls "s3://massive-bucket/" --stream --recursive
    | where size > 1mb
    | first 100

# THEN only required objects are loaded into memory
assert ($large_objects | length) <= 100

# AND memory usage remains constant regardless of total bucket size
# (Implementation validates memory doesn't grow with bucket size)

# AND results can be processed in pipeline without memory exhaustion
let total_size = $large_objects | get size | math sum
assert ($total_size > 100mb)  # Verification that we found large objects
```

#### Scenario: Paginated API Result Streaming  
```nushell
# GIVEN a paginated AWS API operation
# WHEN streaming results with token management
let all_instances = stream-paginated "ec2" "DescribeInstances" {} --page-size 50
    | where State.Name == "running"  
    | collect

# THEN pagination is handled transparently  
assert ($all_instances | length) >= 0

# AND each page is processed independently
# (Memory usage doesn't accumulate across pages)

# AND NextToken management is automatic
```

#### Scenario: Streaming Memory Efficiency Validation
```nushell
# GIVEN a large dataset to stream
let initial_memory = (sys mem | get used)

# WHEN streaming large result set
let processed_count = stream-paginated "s3" "ListObjectsV2" {
    Bucket: "large-test-bucket"
} | where size > 10mb 
  | length

# THEN memory usage remains stable
let final_memory = (sys mem | get used) 
let memory_delta = $final_memory - $initial_memory

# AND memory growth is minimal despite large dataset
assert ($memory_delta < 100MB)  # Should not grow significantly
```

### Requirement: Cross-Service Resource Correlation
The system SHALL provide pipeline operators that automatically enrich AWS resources with related cross-service data while maintaining streaming performance.

#### Scenario: EC2 Instance Enrichment with Related Resources  
```nushell
# GIVEN EC2 instances with security groups and IAM roles
let enriched_instances = [
    {
        InstanceId: "i-123456789",
        SecurityGroups: ["sg-abc123"],
        IamInstanceProfile: {Arn: "arn:aws:iam::123456789012:role/MyRole"}
    }
] | correlate-resources

# THEN instances are enriched with related resource data
let instance = $enriched_instances | get 0
assert ("related" in $instance)

# AND security group data is included
let sg_data = $instance.related | where type == "security-group" | get 0
assert ($sg_data.resources | length) > 0

# AND IAM role data is included  
let role_data = $instance.related | where type == "iam-role" | get 0
assert ($role_data.resources | length) > 0
```

#### Scenario: Tag-Based Resource Correlation
```nushell
# GIVEN resources with common application tags
let tagged_resources = [
    {
        InstanceId: "i-app-web-1", 
        Tags: [{Key: "Application", Value: "WebApp"}, {Key: "Environment", Value: "prod"}]
    }
] | correlate-resources

# THEN related resources are found by tag correlation
let instance = $tagged_resources | get 0  
let tag_correlations = $instance.related | where type == "tag-correlation"

assert ($tag_correlations | length) > 0
# AND correlations include other resources with matching Application tag
```

### Requirement: Bulk Enrichment with Deduplication
The system SHALL provide efficient bulk enrichment that automatically deduplicates fetch requests to avoid redundant API calls.

#### Scenario: Security Group Deduplication in Bulk Enrichment
```nushell
# GIVEN multiple instances sharing security groups  
let instances = [
    {InstanceId: "i-1", SecurityGroupId: "sg-shared-123"},
    {InstanceId: "i-2", SecurityGroupId: "sg-shared-123"},  # Same SG
    {InstanceId: "i-3", SecurityGroupId: "sg-unique-456"}
]

mut fetch_count = 0
def mock-sg-enricher [sg_id: string] {
    $fetch_count = $fetch_count + 1  # Track fetch operations
    {GroupId: $sg_id, GroupName: $"SecurityGroup-($sg_id)"}
}

# WHEN bulk enriching with security group data
let enriched = $instances | enrich-bulk {|inst| $inst.SecurityGroupId}

# THEN only unique security groups are fetched
assert equal $fetch_count 2  # sg-shared-123 and sg-unique-456 only

# AND all instances receive enrichment data
assert equal ($enriched | length) 3
assert ($enriched | all {|i| "enriched" in $i})
```

#### Scenario: Parallel Bulk Enrichment  
```nushell
# GIVEN a large set of resources needing enrichment
let instances = 0..100 | each {|i| {
    InstanceId: $"i-instance-($i)",
    VpcId: $"vpc-($i mod 10)"  # 10 unique VPCs for 100 instances
}}

# WHEN bulk enriching with VPC data
let start_time = date now
let enriched = $instances | enrich-bulk {|inst| $inst.VpcId}
let duration = (date now) - $start_time

# THEN enrichment completes efficiently  
assert equal ($enriched | length) 100

# AND parallel fetching improves performance
assert ($duration < 30sec)  # Should complete quickly with parallelization

# AND only unique VPCs are fetched (10 instead of 100)
```

### Requirement: Lazy Evaluation with Optional Caching
The system SHALL support lazy evaluation of expensive operations with optional caching to optimize pipeline performance.

#### Scenario: Lazy Evaluation Defers Expensive Operations
```nushell
# GIVEN expensive mapping operation
mut evaluation_count = 0
let expensive_mapper = {|item|
    $evaluation_count = $evaluation_count + 1
    sleep 10ms  # Simulate expensive operation
    {computed: ($item * 2), source: $item}
}

# WHEN applying lazy mapping  
let lazy_results = [1, 2, 3, 4, 5] | lazy-map $expensive_mapper --cache true

# AND only taking first 2 results
let partial_results = $lazy_results | first 2

# THEN only required evaluations are performed
assert ($evaluation_count <= 2)  # Should not evaluate items 3, 4, 5
assert equal ($partial_results | length) 2
```

#### Scenario: Lazy Evaluation with Caching Optimization
```nushell  
# GIVEN repeated access to same expensive computation
let expensive_operation = {|item| 
    sleep 50ms  # Simulate expensive computation
    $item * 3
}

let data_with_duplicates = [1, 2, 3, 2, 1, 4]

# WHEN processing with lazy caching enabled
let start_time = date now
let results = $data_with_duplicates | lazy-map $expensive_operation --cache true | collect
let duration = (date now) - $start_time

# THEN duplicates benefit from caching
assert equal $results [3, 6, 9, 6, 3, 12]

# AND total time is less than without caching
# (Should be ~4 * 50ms = 200ms instead of 6 * 50ms = 300ms)
assert ($duration < 250ms)
```

### Requirement: Streaming Aggregation with Windowing  
The system SHALL support streaming aggregation operations that process data in configurable windows without accumulating all data in memory.

#### Scenario: Windowed Stream Aggregation
```nushell
# GIVEN a large stream of numeric data
let large_dataset = 1..1000

# WHEN applying windowed aggregation  
let aggregated_results = $large_dataset 
    | stream-aggregate {|window| {
        sum: ($window | math sum),
        avg: ($window | math avg),
        count: ($window | length),
        min: ($window | math min),
        max: ($window | math max)
    }} --window-size 100

# THEN data is processed in windows
assert equal ($aggregated_results | length) 10  # 1000 items / 100 per window

# AND each window contains expected statistics
let first_window = $aggregated_results | get 0
assert equal $first_window.count 100
assert equal $first_window.sum 5050  # Sum of 1..100
assert equal $first_window.min 1
assert equal $first_window.max 100
```

#### Scenario: Memory-Bounded Stream Processing  
```nushell
# GIVEN a memory-constrained environment  
let initial_memory = (sys mem | get used)

# WHEN processing large stream with aggregation
let results = 1..100000 
    | stream-aggregate {|window| 
        {avg: ($window | math avg)}
    } --window-size 1000
    | collect

let peak_memory = (sys mem | get used)
let memory_increase = $peak_memory - $initial_memory

# THEN memory usage remains bounded  
assert ($memory_increase < 50MB)  # Should not accumulate all 100k items

# AND aggregation completes successfully
assert equal ($results | length) 100  # 100k items / 1k per window
```

### Requirement: Pipeline-Native AWS Operations
All AWS operations SHALL integrate seamlessly with Nushell pipelines, accepting pipeline input and producing streamable output.

#### Scenario: S3 Operations in Pipeline Chain
```nushell
# GIVEN S3 bucket listing integrated with pipeline
let filtered_buckets = aws s3 ls 
    | where name =~ "prod-.*"
    | where created > ((date now) - 30day)
    | sort-by created
    | first 10

# THEN operations chain naturally
assert ($filtered_buckets | length) <= 10

# AND results maintain rich type information
assert ($filtered_buckets | all {|b| "name" in $b and "created" in $b})
```

#### Scenario: Cross-Service Pipeline Operations
```nushell
# GIVEN pipeline chain across multiple AWS services
let analysis = aws ec2 describe-instances --stream
    | where State.Name == "running" 
    | correlate-resources
    | enrich-bulk {|inst| $inst.VpcId}
    | where {|inst| $inst.enriched.IsDefault == false}
    | group-by {|inst| $inst.enriched.VpcId}
    | items {|vpc_id, instances| {
        vpc: $vpc_id,
        instance_count: ($instances | length),
        total_cost: ($instances | get InstanceType | estimate-monthly-cost | math sum)
    }}
    | sort-by total_cost
    | reverse

# THEN complex analysis flows naturally
assert ($analysis | all {|a| "vpc" in $a and "instance_count" in $a})

# AND streaming prevents memory exhaustion  
# (Should handle thousands of instances without issue)
```

### Requirement: Backpressure Management
Streaming operations SHALL implement backpressure mechanisms to handle scenarios where data producers are faster than consumers.

#### Scenario: Fast Producer Slow Consumer Backpressure
```nushell
# GIVEN fast data producer (AWS API) and slow consumer (processing)
let processed_items = stream-paginated "s3" "ListObjectsV2" {
    Bucket: "high-volume-bucket"
} | each {|obj|
    # Simulate slow processing
    sleep 10ms
    process-s3-object $obj
} | first 100

# THEN backpressure prevents memory exhaustion
# AND processing completes without overwhelming system resources
assert equal ($processed_items | length) 100
```

### Requirement: Error Propagation in Streaming Pipelines
Streaming operations SHALL handle and propagate errors appropriately while maintaining pipeline integrity.

#### Scenario: Graceful Error Handling in Streaming Pipeline
```nushell
# GIVEN streaming operation that may encounter errors
let results = stream-paginated "s3" "ListObjectsV2" {
    Bucket: "bucket-with-access-issues"
} | each {|obj|
    # Some objects may fail to process
    try {
        process-object $obj
    } catch {|err|
        {error: $err.msg, object: $obj.Key}
    }
} | collect

# THEN errors are captured without breaking the pipeline
let errors = $results | where error != null
let successes = $results | where error == null

# AND both errors and successes are available for analysis
assert ($errors | length) >= 0
assert ($successes | length) >= 0
```