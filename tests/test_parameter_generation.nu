# Type-Safe Parameter Generation Test Suite
# Following Kent Beck TDD methodology with nutest framework integration

use std/assert
use std/testing *

# ============================================================================
# TDD Cycle 1: Test Framework Setup (Beck-Style)
# RED Phase: Test infrastructure that expects parameter generation functionality
# ============================================================================

@before-each
def setup [] {
    # Setup test environment for parameter generation testing
    $env.AWS_ACCOUNT_ID = "123456789012"
    $env.AWS_REGION = "us-east-1" 
    $env.PARAMETER_GENERATION_TEST_MODE = "true"
    
    {
        test_context: "parameter_generation",
        aws_account: $env.AWS_ACCOUNT_ID,
        aws_region: $env.AWS_REGION
    }
}

#[after-each]
def cleanup [] {
    # Clean up test environment
    $env.PARAMETER_GENERATION_TEST_MODE = null
}

# ============================================================================
# TDD Cycle 1 Tests: Framework Integration (RED Phase)
# ============================================================================

#[test]
def "test nutest integration expects parameter generation test discovery" [] {
    let context = $in
    
    # This test should FAIL - no parameter generation module exists yet
    # Testing that we can discover and run parameter generation tests
    assert ($context.test_context == "parameter_generation") "Test context should be parameter_generation"
    
    # GREEN Phase: Module should now exist and be importable
    try {
        use ../src/parameter_generation.nu
        assert true "Module should now exist in GREEN phase"
    } catch {
        assert false "Module should exist now - we're in GREEN phase"
    }
}

#[test]
def "test AWS schema fixture creation expects builders" [] {
    let context = $in
    
    # GREEN Phase: Fixture builders should now exist
    # Testing fixture creation capability for AWS schemas
    use ../src/parameter_generation.nu
    
    try {
        let test_schema = (parameter_generation create-test-aws-schema "string" {})
        assert ($test_schema.shape_type == "string") "Fixture should create proper AWS schema structure"
        assert ($test_schema.mock == true) "Fixture should be marked as mock"
    } catch {
        assert false "Fixture builder should exist now - we're in GREEN phase"
    }
}

#[test]
def "test signature validation helper expects syntax checking" [] {
    let context = $in
    
    # GREEN Phase: Signature validator should now exist
    # Testing that generated signatures can be validated
    use ../src/parameter_generation.nu
    let test_signature = 'def "aws s3 list-buckets" [] { }'
    
    try {
        let validation_result = (parameter_generation validate-nushell-signature $test_signature)
        assert ($validation_result.valid == true) "Signature validation should return valid result"
        assert ($validation_result.signature == $test_signature) "Signature should be preserved"
        assert ($validation_result.mock == true) "Validation should be marked as mock"
    } catch {
        assert false "Signature validator should exist now - we're in GREEN phase"
    }
}

# ============================================================================
# TDD Cycle 2: to-kebab-case Function (RED Phase)
# Beck baby-step micro-tests - each should FAIL initially
# ============================================================================

#[test]
def "test to-kebab-case BucketName converts correctly" [] {
    let context = $in
    
    # GREEN Phase: Test 1 - Basic PascalCase conversion should now work
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation to-kebab-case "BucketName")
    assert ($result == "bucket-name") "BucketName should convert to bucket-name"
}

#[test]
def "test to-kebab-case MaxKeys converts correctly" [] {
    let context = $in
    
    # GREEN Phase: Test 2 - Another PascalCase example should work
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation to-kebab-case "MaxKeys")
    assert ($result == "max-keys") "MaxKeys should convert to max-keys"
}

#[test]
def "test to-kebab-case preserves already-kebab-case" [] {
    let context = $in
    
    # GREEN Phase: Test 3 - Already kebab-case preservation should work
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation to-kebab-case "already-kebab")
    assert ($result == "already-kebab") "Should preserve already-kebab-case strings"
}

#[test]
def "test to-kebab-case handles acronyms correctly" [] {
    let context = $in
    
    # GREEN Phase: Test 4 - Acronym handling should work
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation to-kebab-case "DBInstanceID")
    assert ($result == "db-instance-id") "Should handle acronyms properly (DBInstanceID → db-instance-id)"
}

#[test]
def "test to-kebab-case handles special characters" [] {
    let context = $in
    
    # GREEN Phase: Test 5 - Special character handling should work
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation to-kebab-case "Special@#Characters")
    assert ($result == "special-characters") "Should replace special characters with hyphens"
}

#[test]
def "test to-kebab-case handles empty string edge case" [] {
    let context = $in
    
    # GREEN Phase: Test 6 - Empty string edge case should work
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation to-kebab-case "")
    assert ($result == "") "Should handle empty string correctly"
}

# ============================================================================
# TDD Cycle 2 Tests: generate-default-value Function (RED Phase)
# Beck baby-step micro-tests - each should FAIL initially
# ============================================================================

#[test]
def "test generate-default-value string type defaults to empty" [] {
    let context = $in
    
    # RED Phase: Test 1 - Basic string default should FAIL (no function exists)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "string" {})
    assert ($result == "") "String type should default to empty string"
}

#[test]
def "test generate-default-value integer type defaults to zero" [] {
    let context = $in
    
    # RED Phase: Test 2 - Basic integer default should FAIL (basic types)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "integer" {})
    assert ($result == 0) "Integer type should default to 0"
}

#[test]
def "test generate-default-value boolean type defaults to false" [] {
    let context = $in
    
    # RED Phase: Test 3 - Boolean default should FAIL (bool handling)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "boolean" {})
    assert ($result == false) "Boolean type should default to false"
}

#[test]
def "test generate-default-value list type defaults to empty list" [] {
    let context = $in
    
    # RED Phase: Test 4 - List default should FAIL (collections)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "list" {})
    assert ($result == []) "List type should default to empty list"
}

#[test]
def "test generate-default-value binary type defaults to empty binary" [] {
    let context = $in
    
    # RED Phase: Test 5 - Binary default should FAIL (special types)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "blob" {})
    assert ($result == (0x[])) "Binary type should default to empty binary"
}

#[test]
def "test generate-default-value datetime type defaults appropriately" [] {
    let context = $in
    
    # RED Phase: Test 6 - Datetime default should FAIL (semantic types)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "timestamp" {})
    # Check that result is a valid datetime (not exact match due to timing)
    assert (($result | describe) == "datetime") "Timestamp type should default to valid datetime"
}

#[test]
def "test generate-default-value constrained int uses minimum" [] {
    let context = $in
    
    # RED Phase: Test 7 - Constrained int should FAIL (constraints)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "integer" { min: 5 })
    assert ($result == 5) "Constrained integer should use minimum value as default"
}

#[test]
def "test generate-default-value enum uses first value" [] {
    let context = $in
    
    # RED Phase: Test 8 - Enum default should FAIL (enum handling)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "string" { enum: ["first", "second", "third"] })
    assert ($result == "first") "Enum should default to first value"
}

#[test]
def "test generate-default-value filesize uses appropriate units" [] {
    let context = $in
    
    # RED Phase: Test 9 - Filesize default should FAIL (semantic defaults)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-default-value "long" { field_name: "max_file_size" })
    assert (($result | describe) == "filesize") "Size-related fields should default to filesize type"
}

# ============================================================================
# TDD Cycle 3 Tests: map-aws-type-to-nushell Function (RED Phase)
# Beck baby-step micro-tests - 12 progressive tests should FAIL initially
# ============================================================================

#[test]
def "test map-aws-type-to-nushell string maps to nushell string" [] {
    let context = $in
    
    # RED Phase: Test 1 - Basic string mapping should FAIL (no function exists)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "string" {})
    assert ($result == "string") "AWS string should map to Nushell string"
}

#[test]
def "test map-aws-type-to-nushell integer maps to nushell int" [] {
    let context = $in
    
    # RED Phase: Test 2 - Basic integer mapping should FAIL (basic primitives)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "integer" {})
    assert ($result == "int") "AWS integer should map to Nushell int"
}

#[test]
def "test map-aws-type-to-nushell boolean maps to nushell bool" [] {
    let context = $in
    
    # RED Phase: Test 3 - Boolean mapping should FAIL (bool mapping)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "boolean" {})
    assert ($result == "bool") "AWS boolean should map to Nushell bool"
}

#[test]
def "test map-aws-type-to-nushell timestamp maps to nushell datetime" [] {
    let context = $in
    
    # RED Phase: Test 4 - Timestamp semantic mapping should FAIL (semantic enhancement)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "timestamp" {})
    assert ($result == "datetime") "AWS timestamp should map to Nushell datetime"
}

#[test]
def "test map-aws-type-to-nushell size field maps to filesize" [] {
    let context = $in
    
    # RED Phase: Test 5 - Size semantic detection should FAIL (semantic detection)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "long" { field_name: "MaxFileSize" })
    assert ($result == "filesize") "Size fields should map to Nushell filesize"
}

#[test]
def "test map-aws-type-to-nushell blob maps to binary" [] {
    let context = $in
    
    # RED Phase: Test 6 - Binary type mapping should FAIL (binary types)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "blob" {})
    assert ($result == "binary") "AWS blob should map to Nushell binary"
}

#[test]
def "test map-aws-type-to-nushell structure maps to record" [] {
    let context = $in
    
    # RED Phase: Test 7 - Structure mapping should FAIL (complex types)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "structure" { members: { field1: "string", field2: "int" } })
    assert ($result == "record") "AWS structure should map to Nushell record"
}

#[test]
def "test map-aws-type-to-nushell list maps to list" [] {
    let context = $in
    
    # RED Phase: Test 8 - List mapping should FAIL (collection types)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "list" { member: "string" })
    assert ($result == "list") "AWS list should map to Nushell list"
}

#[test]
def "test map-aws-type-to-nushell list of objects maps to table" [] {
    let context = $in
    
    # RED Phase: Test 9 - List optimization should FAIL (optimization)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "list" { member: "structure", members: { id: "string", name: "string" } })
    assert ($result == "table") "List of objects should map to Nushell table for pipeline optimization"
}

#[test]
def "test map-aws-type-to-nushell enum maps to string with completion" [] {
    let context = $in
    
    # RED Phase: Test 10 - Enum completion should FAIL (enum completion)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation map-aws-type-to-nushell "string" { enum: ["choice1", "choice2", "choice3"] })
    assert ($result == "string@choices") "Enum should map to string with completion marker"
}

#[test]
def "test map-aws-type-to-nushell nested structure maps to record" [] {
    let context = $in
    
    # RED Phase: Test 11 - Nested structure should FAIL (recursion)
    use ../src/parameter_generation.nu
    
    let nested_members = { outer: "structure", inner: { field: "string" } }
    let result = (parameter_generation map-aws-type-to-nushell "structure" { members: $nested_members })
    assert ($result == "record") "Nested structures should map to Nushell record"
}

#[test]
def "test map-aws-type-to-nushell self-reference maps to any" [] {
    let context = $in
    
    # RED Phase: Test 12 - Self-reference fallback should FAIL (infinite recursion)
    use ../src/parameter_generation.nu
    
    let self_ref_members = { parent: "structure", child: "structure" }
    let result = (parameter_generation map-aws-type-to-nushell "structure" { members: $self_ref_members, self_reference: true })
    assert ($result == "any") "Self-referencing structures should map to any to prevent infinite recursion"
}

# ============================================================================
# TDD Cycle 4 Tests: Dynamic Resource Completion System (RED Phase)
# Beck baby-step micro-tests - 12 progressive tests for intelligent completion system
# ============================================================================

#[test]
def "test completion registry registration fails without registry" [] {
    let context = $in
    
    # RED Phase: Test 1 - Registry registration should FAIL (no registry exists)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation register-completion-handler "BucketName" "s3-buckets")
    assert ($result.registered == true) "Completion handler should be registered successfully"
    assert ($result.handler_id == "s3-buckets") "Handler ID should be preserved"
}

#[test]
def "test cache-aware resource fetching fails without caching" [] {
    let context = $in
    
    # RED Phase: Test 2 - Cache-aware fetching should FAIL (no caching system)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation get-cached-resources "s3-buckets" $context.aws_region $context.aws_account)
    assert ($result.cached == true) "Result should indicate cache usage"
    assert (($result.resources | length) > 0) "Should return cached resource list"
}

#[test]
def "test bucket-name generates live s3 completion fails without dynamic system" [] {
    let context = $in
    
    # RED Phase: Test 3 - Live S3 bucket completion should FAIL (no dynamic system)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-parameter-completion "BucketName" "string" {})
    assert ($result == "@nu-complete-aws-s3-buckets") "BucketName should generate S3 bucket completion function"
}

#[test]
def "test context-aware ec2-instances fails without context awareness" [] {
    let context = $in
    
    # RED Phase: Test 4 - Context-aware EC2 filtering should FAIL (no context awareness)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-parameter-completion "InstanceId" "string" { command_context: "stop-instances" })
    assert ($result == "@nu-complete-aws-ec2-instances-running") "Stop command should filter for running instances only"
}

#[test]
def "test rich descriptions with metadata fails without description system" [] {
    let context = $in
    
    # RED Phase: Test 5 - Rich completion descriptions should FAIL (no description system)
    use ../src/parameter_generation.nu
    
    let completion_func = (parameter_generation create-completion-function "s3-buckets" ["bucket1", "bucket2"])
    let result = ($completion_func | get 0)
    assert ("description" in ($result | columns)) "Completion items should include description field"
    assert (($result.description | str length) > 0) "Description should contain metadata"
}

#[test]
def "test ttl-based cache expiration fails without ttl management" [] {
    let context = $in
    
    # RED Phase: Test 6 - TTL cache expiration should FAIL (no TTL management)
    use ../src/parameter_generation.nu
    
    let cache_result = (parameter_generation check-cache-ttl "s3-buckets" $context.aws_region)
    assert ($cache_result.expired == false) "Cache should not be expired for recent data"
    assert (($cache_result.ttl_remaining | describe) == "duration") "Should return remaining TTL duration"
}

#[test]
def "test profile-region cache scoping fails without scope isolation" [] {
    let context = $in
    
    # RED Phase: Test 7 - Profile/region scoped cache should FAIL (no scope isolation)
    use ../src/parameter_generation.nu
    
    let cache_key = (parameter_generation generate-cache-key "s3-buckets" "us-west-2" "dev-profile")
    assert ($cache_key | str contains "us-west-2") "Cache key should include region"
    assert ($cache_key | str contains "dev-profile") "Cache key should include profile"
    assert ($cache_key | str contains "s3-buckets") "Cache key should include resource type"
}

#[test]
def "test background cache refresh fails without background processing" [] {
    let context = $in
    
    # RED Phase: Test 8 - Background refresh should FAIL (no background processing)
    use ../src/parameter_generation.nu
    
    let refresh_result = (parameter_generation schedule-background-refresh "s3-buckets" $context.aws_region)
    assert ($refresh_result.scheduled == true) "Background refresh should be scheduled"
    assert (($refresh_result.refresh_interval | describe) == "duration") "Should return refresh interval"
}

#[test]
def "test offline mode with cached data fails without offline support" [] {
    let context = $in
    
    # RED Phase: Test 9 - Offline mode should FAIL (no offline support)
    use ../src/parameter_generation.nu
    
    $env.AWS_OFFLINE_MODE = "true"
    let result = (parameter_generation get-completion-data "s3-buckets" $context.aws_region)
    assert ($result.offline_mode == true) "Should operate in offline mode"
    assert ($result.data_source == "cache") "Should use cached data when offline"
    $env.AWS_OFFLINE_MODE = null
}

#[test]
def "test performance sub-200ms fails without performance optimization" [] {
    let context = $in
    
    # RED Phase: Test 10 - Performance optimization should FAIL (no performance optimization)
    use ../src/parameter_generation.nu
    
    let start_time = (date now)
    let result = (parameter_generation get-completion-data "s3-buckets" $context.aws_region)
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    assert (($duration | into int) < 200_000_000) "Cached completion data should return in under 200ms (nanoseconds)"
}

#[test]
def "test error resilience on api failure fails without error handling" [] {
    let context = $in
    
    # RED Phase: Test 11 - Error resilience should FAIL (no error handling)
    use ../src/parameter_generation.nu
    
    $env.AWS_API_SIMULATE_FAILURE = "true"
    let result = (parameter_generation get-completion-data "s3-buckets" $context.aws_region)
    assert ($result.success == false) "Should handle API failure gracefully"
    assert ($result.fallback_used == true) "Should use cached fallback data"
    $env.AWS_API_SIMULATE_FAILURE = null
}

#[test]
def "test enum static completion functions fails without enum system" [] {
    let context = $in
    
    # RED Phase: Test 12 - Static enum completions should FAIL (no enum system)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-parameter-completion "StorageClass" "string" { enum: ["STANDARD", "REDUCED_REDUNDANCY", "GLACIER"] })
    assert ($result == "@nu-complete-storage-class") "Enum should generate static completion function"
}

# ============================================================================
# TDD Cycle 4.5 Tests: Intelligent Type System Foundation (RED Phase)
# Beck baby-step micro-tests - 10 progressive tests for type system integration
# ============================================================================

#[test]
def "test parameter constraint validation fails without validation framework" [] {
    let context = $in
    
    # RED Phase: Test 1 - Constraint validation should FAIL (no validation framework)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation validate-parameter-constraints "MaxKeys" 5 { min: 1, max: 1000 })
    assert ($result.valid == true) "Valid parameter should pass constraint validation"
    assert (($result.constraints_applied | length) > 0) "Should return applied constraints"
}

#[test]
def "test aws type constructor generation fails without constructor system" [] {
    let context = $in
    
    # RED Phase: Test 2 - Type constructor generation should FAIL (no constructor system)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-aws-type-constructor "BucketName" "string" { pattern: "^[a-z0-9.-]+$" })
    assert ($result.constructor_name == "aws-bucket-name") "Should generate constructor function name"
    assert (($result.validation_code | str length) > 0) "Should generate validation code"
}

#[test]
def "test client-side validation integration fails without validation calls" [] {
    let context = $in
    
    # RED Phase: Test 3 - Client-side validation should FAIL (no validation calls)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-validation-call "BucketName" "my-bucket" { pattern: "^[a-z0-9.-]+$" })
    assert ($result.validation_passed == true) "Valid bucket name should pass validation"
    assert ($result.validation_function == "validate-aws-bucket-name") "Should use correct validation function"
}

#[test]
def "test type coercion for timestamps fails without coercion system" [] {
    let context = $in
    
    # RED Phase: Test 4 - Type coercion should FAIL (no coercion system)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation coerce-type "2024-01-01T10:00:00Z" "timestamp")
    assert (($result | describe) == "datetime") "Timestamp string should coerce to datetime"
}

#[test]
def "test semantic type enhancement fails without semantic detection" [] {
    let context = $in
    
    # RED Phase: Test 5 - Semantic enhancement should FAIL (no semantic detection)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation enhance-type-semantically "max_file_size" "long" 1024)
    assert (($result | describe) == "filesize") "Size fields should be enhanced to filesize type"
}

#[test]
def "test constraint metadata preservation fails without metadata system" [] {
    let context = $in
    
    # RED Phase: Test 6 - Metadata preservation should FAIL (no metadata system)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation preserve-constraint-metadata { min: 1, max: 100, pattern: "^[a-z]+$" })
    assert ($result.min == 1) "Should preserve minimum constraint"
    assert ($result.max == 100) "Should preserve maximum constraint"
    assert ($result.pattern == "^[a-z]+$") "Should preserve pattern constraint"
}

#[test]
def "test error reporting for validation failures fails without error framework" [] {
    let context = $in
    
    # RED Phase: Test 7 - Error reporting should FAIL (no error framework)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation generate-validation-error "BucketName" "Invalid-Bucket-Name!" { pattern: "^[a-z0-9.-]+$" })
    assert ($result.error == true) "Should indicate validation error"
    assert ($result.message | str contains "pattern") "Error message should mention pattern constraint"
}

#[test]
def "test arn pattern validation fails without pattern validation" [] {
    let context = $in
    
    # RED Phase: Test 8 - ARN validation should FAIL (no pattern validation)
    use ../src/parameter_generation.nu
    
    let valid_arn = "arn:aws:s3:::my-bucket"
    let result = (parameter_generation validate-arn-pattern $valid_arn)
    assert ($result.valid == true) "Valid ARN should pass pattern validation"
    assert ($result.arn_components.service == "s3") "Should parse ARN service component"
}

#[test]
def "test enum constraint enforcement fails without enum validation" [] {
    let context = $in
    
    # RED Phase: Test 9 - Enum validation should FAIL (no enum validation)
    use ../src/parameter_generation.nu
    
    let result = (parameter_generation validate-enum-constraint "STANDARD" ["STANDARD", "REDUCED_REDUNDANCY", "GLACIER"])
    assert ($result.valid == true) "Valid enum value should pass validation"
    assert ($result.matched_value == "STANDARD") "Should return matched enum value"
}

#[test]
def "test type safety throughout pipeline fails without type safety" [] {
    let context = $in
    
    # RED Phase: Test 10 - Type safety pipeline should FAIL (no type safety)
    use ../src/parameter_generation.nu
    
    let input_value = "my-bucket"
    let result = (parameter_generation process-with-type-safety $input_value "BucketName" "string" { pattern: "^[a-z0-9.-]+$" })
    assert ($result.type_safe == true) "Processing should maintain type safety"
    assert ($result.validated == true) "Value should be validated"
    assert ($result.coerced_value == $input_value) "Value should be properly coerced"
}

# ============================================================================
# TDD Cycle 5 Tests: map-output-type Function (RED Phase)
# Beck baby-step micro-tests - 9 progressive tests for pipeline optimization with type constructors
# ============================================================================

#[test]
def "test map-output-type single object maps to record type fails without function" [] {
    let context = $in
    
    # RED Phase: Test 1 - Single object mapping should FAIL (no function exists)
    use ../src/parameter_generation.nu
    
    let single_object_schema = { 
        shape_type: "structure", 
        members: { name: "string", id: "integer", status: "boolean" }
    }
    let result = (parameter_generation map-output-type $single_object_schema)
    assert ($result == "record") "Single object should map to record type"
}

#[test]
def "test map-output-type list of objects maps to table type fails without optimization" [] {
    let context = $in
    
    # RED Phase: Test 2 - List optimization should FAIL (no pipeline optimization)
    use ../src/parameter_generation.nu
    
    let list_schema = {
        shape_type: "list",
        member: "structure",
        members: { bucket_name: "string", creation_date: "timestamp", region: "string" }
    }
    let result = (parameter_generation map-output-type $list_schema)
    assert ($result == "table") "List of objects should map to table for pipeline optimization"
}

#[test]
def "test map-output-type empty output maps to nothing type fails without empty handling" [] {
    let context = $in
    
    # RED Phase: Test 3 - Empty handling should FAIL (no empty output handling)
    use ../src/parameter_generation.nu
    
    let empty_schema = { shape_type: "structure", members: {} }
    let result = (parameter_generation map-output-type $empty_schema)
    assert ($result == "nothing") "Empty output should map to nothing type"
}

#[test]
def "test map-output-type complex nested maps to list type fails without complex handling" [] {
    let context = $in
    
    # RED Phase: Test 4 - Complex structure should FAIL (no complex structure handling)
    use ../src/parameter_generation.nu
    
    let complex_schema = {
        shape_type: "structure",
        members: {
            items: {
                shape_type: "list",
                member: "structure",
                members: { nested: { shape_type: "structure", members: { deep: "string" } } }
            }
        }
    }
    let result = (parameter_generation map-output-type $complex_schema)
    assert ($result == "list") "Complex nested structures should map to list type"
}

#[test]
def "test map-output-type mixed types maps to appropriate fallback fails without mixed handling" [] {
    let context = $in
    
    # RED Phase: Test 5 - Mixed type fallback should FAIL (no mixed type handling)
    use ../src/parameter_generation.nu
    
    let mixed_schema = {
        shape_type: "union",
        types: ["string", "integer", "structure"]
    }
    let result = (parameter_generation map-output-type $mixed_schema)
    assert ($result == "any") "Mixed types should map to any with validation"
}

#[test]
def "test map-output-type large object lists prefers table fails without performance optimization" [] {
    let context = $in
    
    # RED Phase: Test 6 - Performance optimization should FAIL (no performance consideration)
    use ../src/parameter_generation.nu
    
    let large_list_schema = {
        shape_type: "list",
        member: "structure",
        members: { id: "string", name: "string", tags: "list" },
        size_hint: "large"
    }
    let result = (parameter_generation map-output-type $large_list_schema)
    assert ($result == "table") "Large object lists should prefer table for performance"
}

#[test]
def "test map-output-type recursive output maps safely fails without cycle detection" [] {
    let context = $in
    
    # RED Phase: Test 7 - Recursive safety should FAIL (no cycle detection)
    use ../src/parameter_generation.nu
    
    let recursive_schema = {
        shape_type: "structure",
        members: {
            parent: { shape_type: "structure", self_reference: true },
            children: { shape_type: "list", member: "structure", self_reference: true }
        }
    }
    let result = (parameter_generation map-output-type $recursive_schema)
    assert ($result == "any") "Recursive structures should map to any for cycle safety"
}

#[test]
def "test map-output-type aws resource types generates custom constructors fails without resource typing" [] {
    let context = $in
    
    # RED Phase: Test 8 - AWS resource types should FAIL (no resource-specific handling)
    use ../src/parameter_generation.nu
    
    let resource_schema = {
        shape_type: "structure",
        members: { arn: "string", name: "string", status: "string" },
        aws_resource_type: "s3_bucket"
    }
    let result = (parameter_generation map-output-type $resource_schema)
    assert ($result == "record") "AWS resource types should generate custom type constructors"
}

#[test]
def "test map-output-type response validation enables constraint checking fails without validation" [] {
    let context = $in
    
    # RED Phase: Test 9 - Response validation should FAIL (no output validation)
    use ../src/parameter_generation.nu
    
    let validated_schema = {
        shape_type: "structure",
        members: { count: "integer", items: "list" },
        constraints: { count: { min: 0, max: 1000 } }
    }
    let result = (parameter_generation map-output-type $validated_schema)
    assert ($result == "record") "Output with constraints should enable validation"
}

# ============================================================================
# TDD Cycle 6 Tests: extract-table-columns Function (RED Phase)
# Beck baby-step micro-tests - 5 progressive tests for table generation
# ============================================================================

#[test]
def "test extract-table-columns simple structure generates basic columns fails without function" [] {
    let context = $in
    
    # RED Phase: Test 1 - Simple column extraction should FAIL (no function exists)
    use ../src/parameter_generation.nu
    
    let simple_structure = {
        shape_type: "structure",
        members: { 
            id: "string", 
            name: "string", 
            count: "integer" 
        }
    }
    let result = (parameter_generation extract-table-columns $simple_structure)
    assert ($result == "table<id: string, name: string, count: int>") "Simple structure should generate basic table columns"
}

#[test]
def "test extract-table-columns nested structure flattens appropriately fails without nesting" [] {
    let context = $in
    
    # RED Phase: Test 2 - Nested flattening should FAIL (no nesting logic)
    use ../src/parameter_generation.nu
    
    let nested_structure = {
        shape_type: "structure",
        members: {
            id: "string",
            metadata: {
                shape_type: "structure",
                members: { created: "timestamp", author: "string" }
            },
            status: "string"
        }
    }
    let result = (parameter_generation extract-table-columns $nested_structure)
    assert ($result == "table<id: string, metadata-created: datetime, metadata-author: string, status: string>") "Nested structures should flatten to table columns"
}

#[test]
def "test extract-table-columns list member extracts element structure fails without member handling" [] {
    let context = $in
    
    # RED Phase: Test 3 - List member extraction should FAIL (no member processing)
    use ../src/parameter_generation.nu
    
    let list_structure = {
        shape_type: "list",
        member: "structure",
        members: {
            bucket_name: "string",
            creation_date: "timestamp", 
            region: "string"
        }
    }
    let result = (parameter_generation extract-table-columns $list_structure)
    assert ($result == "table<bucket-name: string, creation-date: datetime, region: string>") "List member structure should extract to table columns"
}

#[test]
def "test extract-table-columns name conflicts resolve uniquely fails without conflict resolution" [] {
    let context = $in
    
    # RED Phase: Test 4 - Name conflict resolution should FAIL (no naming strategy)
    use ../src/parameter_generation.nu
    
    let conflict_structure = {
        shape_type: "structure",
        members: {
            name: "string",
            user: {
                shape_type: "structure",
                members: { name: "string", id: "integer" }
            },
            group: {
                shape_type: "structure", 
                members: { name: "string", permissions: "list" }
            }
        }
    }
    let result = (parameter_generation extract-table-columns $conflict_structure)
    assert ($result == "table<name: string, user-name: string, user-id: int, group-name: string, group-permissions: list>") "Name conflicts should resolve with prefixes"
}

#[test]
def "test extract-table-columns complex types map appropriately fails without complexity handling" [] {
    let context = $in
    
    # RED Phase: Test 5 - Complex type mapping should FAIL (no complex handling)
    use ../src/parameter_generation.nu
    
    let complex_structure = {
        shape_type: "structure",
        members: {
            simple_field: "string",
            complex_nested: {
                shape_type: "structure",
                members: {
                    deep_field: "string",
                    very_deep: {
                        shape_type: "structure",
                        members: { deepest: "string" }
                    }
                }
            },
            list_field: {
                shape_type: "list",
                member: "string"
            }
        }
    }
    let result = (parameter_generation extract-table-columns $complex_structure)
    assert ($result == "table<simple-field: string, complex-nested: record, list-field: list>") "Complex nested types should use appropriate column types"
}

# ============================================================================
# TDD Cycle 7 Tests: Complete Signature Assembly Function (RED Phase)
# Beck baby-step integration tests - 8 progressive tests building complete signatures
# ============================================================================

#[test]
def "test generate-function-signature simple operation creates basic signature fails without integration" [] {
    let context = $in
    
    # RED Phase: Test 1 - Basic signature generation should FAIL (no integration function)
    use ../src/parameter_generation.nu
    
    let simple_operation = {
        operation_name: "list-buckets",
        service: "s3",
        input_schema: {
            shape_type: "structure",
            members: {}
        },
        output_schema: {
            shape_type: "structure", 
            members: {
                buckets: {
                    shape_type: "list",
                    member: "structure",
                    members: { name: "string", creation_date: "timestamp" }
                }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $simple_operation)
    assert ($result | str contains "def \"aws s3 list-buckets\" []") "Should generate basic function signature"
    assert ($result | str contains "-> table<name: string, creation-date: datetime>") "Should include return type"
}

#[test]
def "test generate-function-signature with parameters handles ordering fails without parameter logic" [] {
    let context = $in
    
    # RED Phase: Test 2 - Parameter ordering should FAIL (no parameter ordering logic)
    use ../src/parameter_generation.nu
    
    let operation_with_params = {
        operation_name: "get-object",
        service: "s3", 
        input_schema: {
            shape_type: "structure",
            members: {
                bucket: { type: "string", required: true },
                key: { type: "string", required: true },
                version_id: { type: "string", required: false },
                download: { type: "boolean", required: false }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: { body: "blob", content_type: "string" }
        }
    }
    let result = (parameter_generation generate-function-signature $operation_with_params)
    assert ($result | str contains "bucket: string") "Should include required positional parameters first"
    assert ($result | str contains "key: string") "Should include required parameters"
    assert ($result | str contains "--version-id: string") "Should include optional named parameters"
    assert ($result | str contains "--download") "Should include boolean flags without type"
}

#[test]
def "test generate-function-signature with completions integrates completion syntax fails without completion integration" [] {
    let context = $in
    
    # RED Phase: Test 3 - Completion integration should FAIL (no completion integration)
    use ../src/parameter_generation.nu
    
    let operation_with_completions = {
        operation_name: "put-object",
        service: "s3",
        input_schema: {
            shape_type: "structure", 
            members: {
                bucket: { type: "string", required: true, completion: "s3-buckets" },
                key: { type: "string", required: true },
                storage_class: { 
                    type: "string", 
                    required: false,
                    constraints: { enum: ["STANDARD", "REDUCED_REDUNDANCY", "GLACIER"] }
                }
            }
        },
        output_schema: { shape_type: "structure", members: {} }
    }
    let result = (parameter_generation generate-function-signature $operation_with_completions)
    assert ($result | str contains "bucket: string@nu-complete-aws-s3-buckets") "Should integrate bucket completion"
    assert ($result | str contains "storage-class: string@nu-complete-storage-class") "Should generate enum completion"
}

#[test]
def "test generate-function-signature with documentation includes comments fails without doc integration" [] {
    let context = $in
    
    # RED Phase: Test 4 - Documentation integration should FAIL (no doc integration)
    use ../src/parameter_generation.nu
    
    let documented_operation = {
        operation_name: "create-bucket",
        service: "s3",
        documentation: "Creates a new S3 bucket in the specified region with optional configuration.",
        input_schema: {
            shape_type: "structure",
            members: {
                bucket: { 
                    type: "string", 
                    required: true,
                    documentation: "The name of the bucket to create"
                },
                region: { 
                    type: "string", 
                    required: false,
                    documentation: "AWS region for bucket creation"
                }
            }
        },
        output_schema: { shape_type: "structure", members: { location: "string" } }
    }
    let result = (parameter_generation generate-function-signature $documented_operation)
    assert ($result | str contains "# Creates a new S3 bucket") "Should include operation documentation"
    assert ($result | str contains "# The name of the bucket") "Should include parameter documentation"
}

#[test]
def "test generate-function-signature with return types applies output mapping fails without return type integration" [] {
    let context = $in
    
    # RED Phase: Test 5 - Return type integration should FAIL (no return type integration)
    use ../src/parameter_generation.nu
    
    let operation_with_output = {
        operation_name: "list-objects",
        service: "s3",
        input_schema: {
            shape_type: "structure",
            members: { bucket: { type: "string", required: true } }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                contents: {
                    shape_type: "list",
                    member: "structure", 
                    members: {
                        key: "string",
                        size: "long",
                        last_modified: "timestamp"
                    }
                }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $operation_with_output)
    assert ($result | str contains "-> table<key: string, size: filesize, last-modified: datetime>") "Should apply table return type for list of objects"
}

#[test]
def "test generate-function-signature complex operation combines all features fails without complete integration" [] {
    let context = $in
    
    # RED Phase: Test 6 - Complete integration should FAIL (no complete feature integration)
    use ../src/parameter_generation.nu
    
    let complex_operation = {
        operation_name: "copy-object",
        service: "s3",
        documentation: "Copies an object from one S3 location to another with optional metadata updates.",
        input_schema: {
            shape_type: "structure",
            members: {
                source_bucket: { type: "string", required: true, completion: "s3-buckets" },
                source_key: { type: "string", required: true },
                dest_bucket: { type: "string", required: true, completion: "s3-buckets" },
                dest_key: { type: "string", required: true },
                storage_class: { 
                    type: "string", 
                    required: false,
                    constraints: { enum: ["STANDARD", "GLACIER"] }
                },
                metadata_directive: {
                    type: "string",
                    required: false,
                    constraints: { enum: ["COPY", "REPLACE"] }
                },
                server_side_encryption: { type: "boolean", required: false }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                copy_object_result: {
                    shape_type: "structure",
                    members: { etag: "string", last_modified: "timestamp" }
                }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $complex_operation)
    assert ($result | str contains "def \"aws s3 copy-object\"") "Should generate proper function name"
    assert ($result | str contains "source-bucket: string@nu-complete-aws-s3-buckets") "Should include completions"
    assert ($result | str contains "--storage-class: string@nu-complete-storage-class") "Should include enum completions"
    assert ($result | str contains "--server-side-encryption") "Should include boolean flags"
    assert ($result | str contains "-> record") "Should include return type"
}

#[test]
def "test generate-function-signature nushell syntax validation ensures parser acceptance fails without syntax validation" [] {
    let context = $in
    
    # RED Phase: Test 7 - Syntax validation should FAIL (no syntax validation)
    use ../src/parameter_generation.nu
    
    let syntax_test_operation = {
        operation_name: "describe-instances",
        service: "ec2",
        input_schema: {
            shape_type: "structure", 
            members: {
                instance_ids: {
                    shape_type: "list",
                    member: "string",
                    required: false
                }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                reservations: {
                    shape_type: "list", 
                    member: "structure",
                    members: { instance_id: "string", state: "string" }
                }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $syntax_test_operation)
    # Test that generated signature has valid Nushell syntax
    assert ($result | str starts-with "# ") "Should start with documentation comment"
    assert ($result | str contains "def \"aws ec2 describe-instances\"") "Should have valid function definition"
    assert ($result | str contains ": nothing ->") "Should have valid input/output type syntax"
}

#[test]
def "test generate-function-signature edge cases handles empty and complex parameters fails without edge case handling" [] {
    let context = $in
    
    # RED Phase: Test 8 - Edge case handling should FAIL (no edge case handling)
    use ../src/parameter_generation.nu
    
    let edge_case_operation = {
        operation_name: "get-service-status",
        service: "health",
        input_schema: {
            shape_type: "structure",
            members: {}
        },
        output_schema: {
            shape_type: "structure",
            members: {
                status: "string",
                nested_complex: {
                    shape_type: "structure",
                    members: {
                        very_deep: {
                            shape_type: "structure", 
                            members: { deepest: "string" }
                        }
                    }
                }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $edge_case_operation)
    assert ($result | str contains "def \"aws health get-service-status\" []") "Should handle empty parameters correctly"
    assert ($result | str contains "-> record") "Should handle complex nested output appropriately"
}

# ============================================================================
# TDD Cycle 8: Edge Case Robustness (RED Phase - Beck Implementation)
# ============================================================================

#[test]
def "test edge-case no parameters generates valid empty signature fails without empty handling" [] {
    let context = $in
    
    # RED Phase: Test 1 - Empty parameters should FAIL (no empty handling)
    use ../src/parameter_generation.nu
    
    let empty_params_operation = {
        operation_name: "get-caller-identity",
        service: "sts",
        input_schema: {
            shape_type: "structure",
            members: {}
        },
        output_schema: {
            shape_type: "structure",
            members: { account: "string", arn: "string", user_id: "string" }
        }
    }
    let result = (parameter_generation generate-function-signature $empty_params_operation)
    assert ($result | str contains "def \"aws sts get-caller-identity\" []") "Should generate empty parameter list"
    assert ($result | str contains ": nothing -> record") "Should have proper type annotations"
}

#[test]
def "test edge-case recursive types use any with comments fails without recursion handling" [] {
    let context = $in
    
    # RED Phase: Test 2 - Recursive types should FAIL (no recursion safety)
    use ../src/parameter_generation.nu
    
    let recursive_operation = {
        operation_name: "describe-policy",
        service: "iam",
        input_schema: {
            shape_type: "structure",
            members: {
                policy_document: {
                    type: "structure",
                    self_reference: true
                }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: { policy: "string" }
        }
    }
    let result = (parameter_generation generate-function-signature $recursive_operation)
    assert ($result | str contains "policy-document: any") "Should use any type for recursive structures"
    assert ($result | str contains "# self-referencing") "Should include explanatory comment"
}

#[test]
def "test edge-case union types fallback to any with validation comments fails without union handling" [] {
    let context = $in
    
    # RED Phase: Test 3 - Union types should FAIL (no union handling)
    use ../src/parameter_generation.nu
    
    let union_operation = {
        operation_name: "update-resource",
        service: "cloudformation",
        input_schema: {
            shape_type: "structure",
            members: {
                value: {
                    shape_type: "union",
                    members: ["string", "integer", "boolean"]
                }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: { status: "string" }
        }
    }
    let result = (parameter_generation generate-function-signature $union_operation)
    assert ($result | str contains "value: any") "Should use any type for union types"
    assert ($result | str contains "# multiple types") "Should include explanatory comment"
}

#[test]
def "test edge-case long parameter lists use multiline formatting fails without formatting" [] {
    let context = $in
    
    # RED Phase: Test 4 - Long parameter lists should FAIL (no multiline formatting)
    use ../src/parameter_generation.nu
    
    let long_params_operation = {
        operation_name: "run-instances",
        service: "ec2",
        input_schema: {
            shape_type: "structure",
            members: {
                image_id: { type: "string", required: true },
                instance_type: { type: "string", required: true },
                min_count: { type: "integer", required: true },
                max_count: { type: "integer", required: true },
                key_name: { type: "string", required: false },
                security_groups: { type: "list", required: false },
                subnet_id: { type: "string", required: false },
                user_data: { type: "string", required: false },
                monitoring: { type: "boolean", required: false },
                disable_api_termination: { type: "boolean", required: false }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: { instances: "list" }
        }
    }
    let result = (parameter_generation generate-function-signature $long_params_operation)
    # Should format readably when parameter count is high
    assert (($result | str length) > 200) "Should generate comprehensive parameter list"
    assert ($result | str contains "image-id: string") "Should include all required parameters"
    assert ($result | str contains "--key-name: string") "Should include optional parameters"
}

#[test]
def "test edge-case deprecated parameters include warning comments fails without deprecation" [] {
    let context = $in
    
    # RED Phase: Test 5 - Deprecated parameters should FAIL (no deprecation support)
    use ../src/parameter_generation.nu
    
    let deprecated_operation = {
        operation_name: "create-cluster",
        service: "ecs",
        input_schema: {
            shape_type: "structure",
            members: {
                cluster_name: { type: "string", required: true },
                capacity_providers: { 
                    type: "list", 
                    required: false,
                    deprecated: true,
                    deprecation_message: "Use defaultCapacityProviderStrategy instead"
                }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: { cluster: "record" }
        }
    }
    let result = (parameter_generation generate-function-signature $deprecated_operation)
    assert ($result | str contains "--capacity-providers: list") "Should include deprecated parameter"
    assert ($result | str contains "# DEPRECATED") "Should include deprecation warning"
    assert ($result | str contains "Use defaultCapacityProviderStrategy") "Should include deprecation message"
}

#[test]
def "test edge-case malformed input graceful degradation fails without error resilience" [] {
    let context = $in
    
    # RED Phase: Test 6 - Malformed input should FAIL (no error resilience)
    use ../src/parameter_generation.nu
    
    let malformed_operation = {
        operation_name: "malformed-test",
        service: "test",
        input_schema: {
            # Missing required shape_type field
            members: {
                param1: { type: "invalid_type" }
            }
        },
        output_schema: {
            # Missing members field
            shape_type: "structure"
        }
    }
    let result = (parameter_generation generate-function-signature $malformed_operation)
    assert ($result | str contains "def \"aws test malformed-test\"") "Should generate basic function signature"
    assert ($result | str contains "param1: any") "Should fallback to any type for invalid types"
    # Should not crash and provide meaningful fallback
    assert (($result | str length) > 50) "Should generate reasonable fallback signature"
}

#### TDD Cycle 9: S3 Schema Integration Tests
#[test]
def "test s3 list-objects-v2 generates complete valid signature fails without real integration" [] {
    let context = $in
    
    # RED Phase: Test 1 - S3 list-objects-v2 → complete valid signature (fail - no real integration)
    use ../src/parameter_generation.nu
    
    let s3_list_objects_operation = {
        operation_name: "list-objects-v2",
        service: "s3", 
        input_schema: {
            shape_type: "structure",
            members: {
                Bucket: { type: "string", required: true },
                MaxKeys: { type: "integer", min: 1, max: 1000 },
                Prefix: { type: "string" },
                Delimiter: { type: "string" },
                ContinuationToken: { type: "string" }
            }
        },
        output_schema: {
            shape_type: "structure", 
            members: {
                Name: { type: "string" },
                Contents: {
                    type: "list",
                    member: {
                        type: "structure",
                        members: {
                            Key: { type: "string" },
                            Size: { type: "long" }, 
                            LastModified: { type: "timestamp" }
                        }
                    }
                }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $s3_list_objects_operation)
    assert ($result | str contains "def \"aws s3 list-objects-v2\"") "Should generate valid S3 function signature"
    assert ($result | str contains "bucket: string") "Should include required bucket parameter"
    assert ($result | str contains "--max-keys: int") "Should include optional max-keys with integer type"
    assert ($result | str contains "@nu-complete-aws-s3-buckets") "Should include bucket completion"
    assert ($result | str contains "-> table<key: string, size: filesize, last-modified: datetime>") "Should generate pipeline-optimized return type"
}

#[test]
def "test s3 create-bucket handles proper parameter ordering fails without complex params" [] {
    let context = $in
    
    # RED Phase: Test 2 - S3 create-bucket → proper parameter ordering (fail - complex params)
    use ../src/parameter_generation.nu
    
    let s3_create_bucket_operation = {
        operation_name: "create-bucket",
        service: "s3",
        input_schema: {
            shape_type: "structure",
            members: {
                Bucket: { type: "string", required: true },
                ACL: { 
                    type: "string", 
                    enum: ["private", "public-read", "public-read-write", "authenticated-read"] 
                },
                CreateBucketConfiguration: {
                    type: "structure",
                    members: {
                        LocationConstraint: { type: "string" }
                    }
                },
                GrantFullControl: { type: "string" },
                GrantRead: { type: "string" }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                Location: { type: "string" }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $s3_create_bucket_operation)
    assert ($result | str contains "bucket: string") "Should have required bucket parameter first"
    assert ($result | str contains "--acl: string@nu-complete-acl") "Should include enum completion for ACL"
    assert ($result | str contains "--create-bucket-configuration: record") "Should handle nested structure parameter"
    # Parameter ordering: required → optional → boolean flags
    let bucket_pos = ($result | str index-of "bucket:")
    let acl_pos = ($result | str index-of "--acl:")
    assert ($bucket_pos < $acl_pos) "Required parameters should come before optional"
}

#[test]
def "test s3 put-object handles binary parameter fails without binary types" [] {
    let context = $in
    
    # RED Phase: Test 3 - S3 put-object → binary parameter handling (fail - binary types)
    use ../src/parameter_generation.nu
    
    let s3_put_object_operation = {
        operation_name: "put-object",
        service: "s3",
        input_schema: {
            shape_type: "structure",
            members: {
                Bucket: { type: "string", required: true },
                Key: { type: "string", required: true },
                Body: { type: "blob" },
                ContentLength: { type: "long" },
                ContentType: { type: "string" },
                Metadata: {
                    type: "map",
                    key: { type: "string" },
                    value: { type: "string" }
                }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                ETag: { type: "string" }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $s3_put_object_operation)
    assert ($result | str contains "bucket: string") "Should include bucket parameter"
    assert ($result | str contains "key: string") "Should include key parameter"
    assert ($result | str contains "--body: binary") "Should map blob to binary type"
    assert ($result | str contains "--content-length: filesize") "Should use semantic filesize type"
    assert ($result | str contains "--metadata: record") "Should handle map as record type"
}

#[test]
def "test s3 batch operations meet performance acceptance fails without performance" [] {
    let context = $in
    
    # RED Phase: Test 4 - S3 batch operations → performance acceptance (fail - performance)
    use ../src/parameter_generation.nu
    
    # Simulate processing 50 S3 operations
    let start_time = (date now)
    let operations = (1..50 | each { |i|
        {
            operation_name: $"operation-($i)",
            service: "s3",
            input_schema: {
                shape_type: "structure",
                members: {
                    Bucket: { type: "string", required: true },
                    Key: { type: "string" }
                }
            },
            output_schema: { shape_type: "structure" }
        }
    })
    
    let results = ($operations | each { |op| 
        parameter_generation generate-function-signature $op
    })
    let end_time = (date now)
    let duration = (($end_time - $start_time) | into int) / 1000000
    
    assert (($results | length) == 50) "Should process all 50 operations"
    assert ($duration < 5000) "Should complete 50 operations in under 5 seconds (100ms average)"
    # Each result should be valid
    assert ($results | all { |r| ($r | str contains "def \"aws s3") }) "All signatures should be valid"
}

#[test]
def "test all s3 operations generate without failures fails without coverage" [] {
    let context = $in
    
    # RED Phase: Test 5 - All S3 operations → no generation failures (fail - coverage)
    use ../src/parameter_generation.nu
    
    let s3_operations = [
        "list-buckets",
        "create-bucket", 
        "delete-bucket",
        "put-object",
        "get-object",
        "delete-object",
        "list-objects-v2",
        "copy-object",
        "create-multipart-upload",
        "upload-part",
        "complete-multipart-upload",
        "abort-multipart-upload"
    ]
    
    let results = ($s3_operations | each { |op_name|
        try {
            let operation = {
                operation_name: $op_name,
                service: "s3",
                input_schema: {
                    shape_type: "structure",
                    members: {
                        Bucket: { type: "string", required: true }
                    }
                },
                output_schema: { shape_type: "structure" }
            }
            parameter_generation generate-function-signature $operation
        } catch {
            $"FAILED: ($op_name)"
        }
    })
    
    let failed_operations = ($results | where { $in | str starts-with "FAILED:" })
    assert (($failed_operations | length) == 0) $"Should generate all S3 operations without failures, but failed: ($failed_operations)"
    assert (($results | length) == ($s3_operations | length)) "Should process all S3 operations"
}

#### TDD Cycle 10: Step Functions Schema Integration Tests
#[test]
def "test stepfunctions create-state-machine handles json parameter fails without json handling" [] {
    let context = $in
    
    # RED Phase: Test 1 - Step Functions create-state-machine → JSON parameter handling (fail)
    use ../src/parameter_generation.nu
    
    let sf_create_state_machine_operation = {
        operation_name: "create-state-machine",
        service: "stepfunctions",
        input_schema: {
            shape_type: "structure",
            members: {
                stateMachineName: { type: "string", required: true },
                definition: { type: "string", required: true },  # JSON string
                roleArn: { type: "string", required: true },
                type: { 
                    type: "string", 
                    enum: ["STANDARD", "EXPRESS"] 
                },
                loggingConfiguration: {
                    type: "structure",
                    members: {
                        level: { type: "string", enum: ["ALL", "ERROR", "FATAL", "OFF"] },
                        includeExecutionData: { type: "boolean" },
                        destinations: {
                            type: "list",
                            member: {
                                type: "structure",
                                members: {
                                    cloudWatchLogsLogGroup: {
                                        type: "structure",
                                        members: {
                                            logGroupArn: { type: "string" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                stateMachineArn: { type: "string" },
                creationDate: { type: "timestamp" }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $sf_create_state_machine_operation)
    assert ($result | str contains "def \"aws stepfunctions create-state-machine\"") "Should generate valid Step Functions function signature"
    assert ($result | str contains "state-machine-name: string") "Should include required state machine name parameter"
    assert ($result | str contains "definition: string") "Should handle JSON string parameter"
    assert ($result | str contains "role-arn: string") "Should include role ARN parameter"
    assert ($result | str contains "--type: string@nu-complete-type") "Should include enum completion for type"
    assert ($result | str contains "--logging-configuration: record") "Should handle complex nested structure"
}

#[test]
def "test stepfunctions list-executions handles pagination detection fails without pagination" [] {
    let context = $in
    
    # RED Phase: Test 2 - Step Functions list-executions → pagination detection (fail)
    use ../src/parameter_generation.nu
    
    let sf_list_executions_operation = {
        operation_name: "list-executions",
        service: "stepfunctions",
        input_schema: {
            shape_type: "structure",
            members: {
                stateMachineArn: { type: "string", required: true },
                statusFilter: { 
                    type: "string", 
                    enum: ["RUNNING", "SUCCEEDED", "FAILED", "TIMED_OUT", "ABORTED"] 
                },
                maxResults: { type: "integer", min: 1, max: 1000 },
                nextToken: { type: "string" },
                mapRunArn: { type: "string" },
                redriveFilter: {
                    type: "string",
                    enum: ["REDRIVEN", "NOT_REDRIVEN"]
                }
            }
        },
        output_schema: {
            shape_type: "structure", 
            members: {
                executions: {
                    type: "list",
                    member: {
                        type: "structure",
                        members: {
                            executionArn: { type: "string" },
                            stateMachineArn: { type: "string" },
                            name: { type: "string" },
                            status: { type: "string" },
                            startDate: { type: "timestamp" },
                            stopDate: { type: "timestamp" },
                            mapRunArn: { type: "string" },
                            itemCount: { type: "integer" },
                            toleratedFailureCount: { type: "long" },
                            toleratedFailurePercentage: { type: "float" }
                        }
                    }
                },
                nextToken: { type: "string" }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $sf_list_executions_operation)
    assert ($result | str contains "state-machine-arn: string") "Should include required state machine ARN"
    assert ($result | str contains "--status-filter: string@nu-complete-status-filter") "Should include status filter enum"
    assert ($result | str contains "--max-results: int") "Should include max results parameter"
    assert ($result | str contains "--next-token: string") "Should include pagination token"
    assert ($result | str contains "-> table<") "Should generate table return type for list operations"
    assert ($result | str contains "execution-arn: string") "Should include execution ARN column"
    assert ($result | str contains "start-date: datetime") "Should use datetime for timestamp columns"
}

#[test]
def "test stepfunctions describe-execution handles complex return types fails without complex handling" [] {
    let context = $in
    
    # RED Phase: Test 3 - Step Functions describe-execution → complex return types (fail)
    use ../src/parameter_generation.nu
    
    let sf_describe_execution_operation = {
        operation_name: "describe-execution",
        service: "stepfunctions",
        input_schema: {
            shape_type: "structure",
            members: {
                executionArn: { type: "string", required: true }
            }
        },
        output_schema: {
            shape_type: "structure",
            members: {
                executionArn: { type: "string" },
                stateMachineArn: { type: "string" },
                name: { type: "string" },
                status: { type: "string" },
                startDate: { type: "timestamp" },
                stopDate: { type: "timestamp" },
                input: { type: "string" },  # JSON string
                inputDetails: {
                    type: "structure",
                    members: {
                        included: { type: "boolean" }
                    }
                },
                output: { type: "string" },  # JSON string
                outputDetails: {
                    type: "structure", 
                    members: {
                        included: { type: "boolean" }
                    }
                },
                traceHeader: { type: "string" },
                mapRunArn: { type: "string" },
                error: { type: "string" },
                cause: { type: "string" },
                redriveCount: { type: "integer" },
                redriveDate: { type: "timestamp" },
                redriveStatus: { type: "string" },
                redriveStatusReason: { type: "string" }
            }
        }
    }
    let result = (parameter_generation generate-function-signature $sf_describe_execution_operation)
    assert ($result | str contains "execution-arn: string") "Should include required execution ARN parameter"
    assert ($result | str contains "-> record") "Should use record return type for single object"
    # Complex nested structure should be handled gracefully without breaking
    assert (($result | str length) > 100) "Should generate complete function signature"
}

#[test]  
def "test all stepfunctions operations generate without failures fails without coverage" [] {
    let context = $in
    
    # RED Phase: Test 4 - All Step Functions operations → complete coverage (fail)
    use ../src/parameter_generation.nu
    
    let stepfunctions_operations = [
        "create-state-machine",
        "delete-state-machine", 
        "describe-state-machine",
        "list-state-machines",
        "start-execution",
        "stop-execution",
        "describe-execution",
        "list-executions",
        "get-execution-history",
        "create-activity",
        "delete-activity",
        "describe-activity",
        "list-activities"
    ]
    
    let results = ($stepfunctions_operations | each { |op_name|
        try {
            let operation = {
                operation_name: $op_name,
                service: "stepfunctions",
                input_schema: {
                    shape_type: "structure",
                    members: {
                        # Basic parameter for all operations
                        name: { type: "string", required: true }
                    }
                },
                output_schema: { shape_type: "structure" }
            }
            parameter_generation generate-function-signature $operation
        } catch {
            $"FAILED: ($op_name)"
        }
    })
    
    let failed_operations = ($results | where { $in | str starts-with "FAILED:" })
    assert (($failed_operations | length) == 0) $"Should generate all Step Functions operations without failures, but failed: ($failed_operations)"
    assert (($results | length) == ($stepfunctions_operations | length)) "Should process all Step Functions operations"
    # Each result should be valid Step Functions signature
    assert ($results | all { |r| ($r | str contains "def \"aws stepfunctions") }) "All signatures should be valid Step Functions commands"
}

#### TDD Cycle 11: OpenAPI Extraction Compatibility Tests
#[test]
def "test openapi-input-shape-resolution fails without pipeline integration" [] {
    let context = $in
    
    # RED Phase: Test 1 - Input shape resolution → correct parameter extraction (fail)
    use ../src/parameter_generation.nu
    
    # Simulate how the OpenAPI extractor provides operation data
    let openapi_operation = {
        operation_name: "list-objects-v2",
        service: "s3",
        # OpenAPI extraction provides input_shape reference instead of direct schema
        input_shape: "ListObjectsV2Request",  # Reference to shape
        input_schema: {
            # This is how the resolved schema would look after shape resolution
            shape_type: "structure",
            members: {
                Bucket: { type: "string", required: true },
                MaxKeys: { type: "integer", min: 1, max: 1000 },
                Prefix: { type: "string" }
            }
        },
        output_shape: "ListObjectsV2Output",  # Reference to shape  
        output_schema: {
            # Resolved output schema
            shape_type: "structure",
            members: {
                Contents: {
                    type: "list",
                    member: {
                        type: "structure", 
                        members: {
                            Key: { type: "string" },
                            Size: { type: "long" }
                        }
                    }
                }
            }
        }
    }
    
    let result = (parameter_generation generate-function-signature $openapi_operation)
    assert ($result | str contains "def \"aws s3 list-objects-v2\"") "Should handle OpenAPI extractor operation format"
    assert ($result | str contains "bucket: string") "Should resolve input shape parameters correctly"
    assert ($result | str contains "--max-keys: int") "Should handle optional parameters from resolved shapes"
    assert ($result | str contains "-> table<") "Should resolve output shape to appropriate return type"
}

#[test]
def "test required-optional-flag-handling fails without flag classification" [] {
    let context = $in
    
    # RED Phase: Test 2 - Required/optional flags → proper parameter classification (fail)
    use ../src/parameter_generation.nu
    
    let operation_with_flags = {
        operation_name: "create-bucket",
        service: "s3",
        input_schema: {
            shape_type: "structure",
            members: {
                Bucket: { type: "string", required: true },  # Required
                ACL: { type: "string", required: false },     # Optional
                CreateBucketConfiguration: { type: "structure", required: false },  # Optional complex
                GrantFullControl: { type: "string" },         # Defaults to optional (no required field)
                PublicAccessBlock: { type: "boolean", required: false }  # Optional boolean
            }
        },
        output_schema: { shape_type: "structure" }
    }
    
    let result = (parameter_generation generate-function-signature $operation_with_flags)
    
    # Required parameters should be positional (no --)
    assert ($result | str contains "bucket: string") "Required parameter should be positional"
    
    # Optional parameters should have -- prefix
    assert ($result | str contains "--acl: string") "Optional string should use -- prefix"
    assert ($result | str contains "--create-bucket-configuration: record") "Optional complex type should use -- prefix"
    assert ($result | str contains "--grant-full-control: string") "Parameters without required field should default to optional"
    
    # Boolean parameters should be flags (no type annotation)
    assert ($result | str contains "--public-access-block") "Boolean parameter should be a flag"
}

#[test]
def "test error-propagation-meaningful-messages fails without error framework" [] {
    let context = $in
    
    # RED Phase: Test 3 - Error propagation → meaningful error messages (fail)
    use ../src/parameter_generation.nu
    
    # Test with completely malformed operation (missing required fields)
    let malformed_operation = {
        # Missing operation_name and service
        input_schema: {
            # Missing shape_type
            members: {}  # Empty members
        }
        # Missing output_schema entirely
    }
    
    let result = try {
        parameter_generation generate-function-signature $malformed_operation
    } catch { |e|
        $"ERROR: ($e.msg)"
    }
    
    # Should handle errors gracefully rather than crashing
    assert ($result != null) "Should handle malformed input without crashing"
    assert (($result | describe) == "string") "Should return string result even on error"
    
    # If it's an error, should be meaningful
    if ($result | str starts-with "ERROR:") {
        assert (($result | str length) > 20) "Error messages should be descriptive"
    } else {
        # If it succeeded, should generate a meaningful fallback
        assert ($result | str contains "def") "Should generate valid fallback signature"
    }
}

#[test]
def "test progress-reporting-batch-operations fails without progress feedback" [] {
    let context = $in
    
    # RED Phase: Test 4 - Progress reporting → batch operation feedback (fail)
    use ../src/parameter_generation.nu
    
    # Test batch processing of multiple operations
    let batch_operations = (1..10 | each { |i|
        {
            operation_name: $"operation-($i)",
            service: "test",
            input_schema: {
                shape_type: "structure",
                members: {
                    param1: { type: "string", required: true }
                }
            },
            output_schema: { shape_type: "structure" }
        }
    })
    
    # Process batch operations  
    let start_time = (date now)
    let results = ($batch_operations | each { |op|
        parameter_generation generate-function-signature $op
    })
    let end_time = (date now)
    let processing_time = (($end_time - $start_time) | into int) / 1000000
    
    # Verify batch processing works correctly
    assert (($results | length) == 10) "Should process all batch operations"
    assert ($results | all { |r| ($r | str contains "def \"aws test operation-") }) "All operations should generate valid signatures"
    assert ($processing_time < 1000) "Batch processing should complete quickly (under 1 second)"
    
    # Progress reporting would be tested here if implemented
    # For now, ensure operations complete without error
    let failed_operations = ($results | where { $in | str starts-with "ERROR:" })
    assert (($failed_operations | length) == 0) "No operations should fail during batch processing"
}

#[test]
def "test shape-resolution-compatibility fails without shape support" [] {
    let context = $in
    
    # RED Phase: Test 5 - Shape resolution compatibility → handle both direct and reference schemas (fail)  
    use ../src/parameter_generation.nu
    
    # Test operation that uses both direct schema and shape references
    let mixed_operation = {
        operation_name: "mixed-schema-test",
        service: "test",
        input_shape: "TestInputShape",  # Reference (would be resolved by OpenAPI extractor)
        input_schema: {
            # Direct schema (already resolved)
            shape_type: "structure",
            members: {
                DirectParam: { type: "string", required: true },
                OptionalParam: { type: "integer" }
            }
        },
        output_shape: "TestOutputShape",  # Reference
        output_schema: {
            # Direct resolved schema
            shape_type: "structure",
            members: {
                Result: { type: "string" },
                Count: { type: "integer" }
            }
        }
    }
    
    let result = (parameter_generation generate-function-signature $mixed_operation)
    
    # Should handle the resolved schema properly regardless of shape references
    assert ($result | str contains "def \"aws test mixed-schema-test\"") "Should generate function with proper naming"
    assert ($result | str contains "direct-param: string") "Should process direct schema parameters"  
    assert ($result | str contains "--optional-param: int") "Should handle optional parameters correctly"
    assert ($result | str contains "-> record") "Should handle output schema for return type"
    
    # The presence of input_shape and output_shape fields shouldn't break processing
    assert (($result | str length) > 80) "Should generate complete signature despite shape references"
}

# ============================================================================
# Test Execution Helper (for manual testing during development)
# ============================================================================

#[test]
def "test framework meta-test can run individual tests" [] {
    let context = $in
    
    # Verify that the test framework itself is working
    assert ($context.test_context == "parameter_generation") "Test framework should provide context"
    assert ($context.aws_account == "123456789012") "Test context should include AWS account"
    assert ($context.aws_region == "us-east-1") "Test context should include AWS region"
}

# ============================================================================
# Beck TDD Notes for Implementation
# ============================================================================

# RED Phase Status: ✅ COMPLETE
# All tests above should FAIL when run - this confirms we're in proper RED phase
# 
# Next: GREEN Phase Implementation
# 1. Create minimal parameter_generation.nu module
# 2. Implement basic fixture builders  
# 3. Create minimal signature validator
# 4. Implement to-kebab-case function using Beck strategies:
#    - Fake It: Return hardcoded "bucket-name" for first test
#    - Triangulation: Add logic for "MaxKeys" → "max-keys"
#    - Obvious Implementation: Add preservation logic for already-kebab
#    - Extend: Handle acronyms and special characters
#
# REFACTOR Phase:
# - Extract string manipulation patterns
# - Optimize algorithm for clarity and performance
# - Ensure edge cases are handled elegantly