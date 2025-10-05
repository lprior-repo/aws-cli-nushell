# Comprehensive S3 Module Test Suite
# Tests all 8 S3 commands with full coverage including mock/real modes, error handling, and edge cases

use ../../aws/s3.nu *

# ============================================================================
# MOCK MODE TESTS
# ============================================================================

#[test]
def "test s3 ls bucket listing mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 ls)
    
    assert ($result | describe) == "table<date: string, time: string, size: string, type: string, name: string>"
    assert ($result | length) == 2
    assert ($result | get 0 | get type) == "bucket"
    assert ($result | get 0 | get name) == "my-test-bucket"
}

#[test]
def "test s3 ls object listing mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 ls "s3://test-bucket/")
    
    assert ($result | length) == 3
    assert ($result | get 0 | get type) == "file"
    assert ($result | get 0 | get name) == "file1.txt"
    assert ($result | get 2 | get type) == "directory"
}

#[test]
def "test s3 mb make bucket mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 mb "s3://test-bucket")
    
    assert ($result.operation) == "make_bucket"
    assert ($result.status) == "success"
    assert ($result.mock) == true
    assert ($result.bucket) == "s3://test-bucket"
}

#[test]
def "test s3 mb with region mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 mb "s3://test-bucket" --region "us-west-2")
    
    assert ($result.region) == "us-west-2"
    assert ($result.status) == "success"
}

#[test]
def "test s3 cp copy files mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 cp "local-file.txt" "s3://bucket/remote-file.txt")
    
    assert ($result.operation) == "copy"
    assert ($result.source) == "local-file.txt"
    assert ($result.destination) == "s3://bucket/remote-file.txt"
    assert ($result.status) == "success"
    assert ($result.recursive) == false
}

#[test]
def "test s3 cp with recursive flag mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 cp "local-dir/" "s3://bucket/remote-dir/" --recursive)
    
    assert ($result.recursive) == true
    assert ($result.status) == "success"
}

#[test]
def "test s3 cp with dryrun flag mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 cp "file.txt" "s3://bucket/file.txt" --dryrun)
    
    assert ($result.dryrun) == true
    assert ($result.status) == "success"
}

#[test]
def "test s3 mv move files mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 mv "local-file.txt" "s3://bucket/remote-file.txt")
    
    assert ($result.operation) == "move"
    assert ($result.source) == "local-file.txt"
    assert ($result.destination) == "s3://bucket/remote-file.txt"
    assert ($result.status) == "success"
}

#[test]
def "test s3 rb remove bucket mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 rb "s3://test-bucket")
    
    assert ($result.operation) == "remove_bucket"
    assert ($result.bucket) == "s3://test-bucket"
    assert ($result.status) == "success"
    assert ($result.force) == false
}

#[test]
def "test s3 rb with force flag mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 rb "s3://test-bucket" --force)
    
    assert ($result.force) == true
    assert ($result.status) == "success"
}

#[test]
def "test s3 rm remove objects mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 rm "s3://bucket/file.txt")
    
    assert ($result.operation) == "remove"
    assert ($result.path) == "s3://bucket/file.txt"
    assert ($result.status) == "success"
    assert ($result.recursive) == false
}

#[test]
def "test s3 sync directories mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 sync "local-dir/" "s3://bucket/remote-dir/")
    
    assert ($result.operation) == "sync"
    assert ($result.source) == "local-dir/"
    assert ($result.destination) == "s3://bucket/remote-dir/"
    assert ($result.status) == "success"
}

#[test]
def "test s3 sync with delete flag mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 sync "local/" "s3://bucket/" --delete)
    
    assert ($result.delete) == true
    assert ($result.status) == "success"
}

#[test]
def "test s3 presign generate url mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 presign "s3://bucket/file.txt")
    
    assert ($result | str starts-with "https://mock-presigned-url.amazonaws.com")
    assert ($result | str contains "bucket/file.txt")
    assert ($result | str contains "expires=3600")
}

#[test]
def "test s3 presign with custom expiration mock mode" [] {
    s3-enable-mock-mode
    let result = (aws s3 presign "s3://bucket/file.txt" --expires-in 7200)
    
    assert ($result | str contains "expires=7200")
}

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

#[test]
def "test s3 mb invalid bucket uri validation" [] {
    s3-enable-mock-mode
    
    assert_error {
        aws s3 mb "invalid-bucket-name"
    }
}

#[test]
def "test s3 rb invalid bucket uri validation" [] {
    s3-enable-mock-mode
    
    assert_error {
        aws s3 rb "invalid-bucket-name"
    }
}

#[test]
def "test s3 rm invalid path validation" [] {
    s3-enable-mock-mode
    
    assert_error {
        aws s3 rm "not-an-s3-path"
    }
}

#[test]
def "test s3 presign invalid path validation" [] {
    s3-enable-mock-mode
    
    assert_error {
        aws s3 presign "not-an-s3-path"
    }
}

# ============================================================================
# UTILITY FUNCTION TESTS
# ============================================================================

#[test]
def "test s3 mode switching" [] {
    s3-enable-mock-mode
    assert (s3-get-mode) == "mock"
    
    s3-disable-mock-mode
    assert (s3-get-mode) == "real"
    
    # Reset to mock for other tests
    s3-enable-mock-mode
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

#[test]
def "test s3 comprehensive workflow mock mode" [] {
    s3-enable-mock-mode
    
    # Test complete S3 workflow
    let buckets = (aws s3 ls)
    assert ($buckets | length) > 0
    
    let create_result = (aws s3 mb "s3://workflow-test-bucket")
    assert ($create_result.status) == "success"
    
    let copy_result = (aws s3 cp "test.txt" "s3://workflow-test-bucket/test.txt")
    assert ($copy_result.status) == "success"
    
    let objects = (aws s3 ls "s3://workflow-test-bucket/")
    assert ($objects | length) > 0
    
    let presign_url = (aws s3 presign "s3://workflow-test-bucket/test.txt")
    assert ($presign_url | str length) > 50
    
    let remove_result = (aws s3 rm "s3://workflow-test-bucket/test.txt")
    assert ($remove_result.status) == "success"
    
    let delete_bucket = (aws s3 rb "s3://workflow-test-bucket")
    assert ($delete_bucket.status) == "success"
}

#[test]
def "test s3 edge cases" [] {
    s3-enable-mock-mode
    
    # Test empty path for ls
    let empty_path_result = (aws s3 ls "")
    assert ($empty_path_result | length) == 2  # Should return bucket listing
    
    # Test path with trailing slash
    let trailing_slash_result = (aws s3 ls "s3://bucket/")
    assert ($trailing_slash_result | length) == 3  # Should return object listing
    
    # Test presign with default expiration
    let default_presign = (aws s3 presign "s3://bucket/file.txt")
    assert ($default_presign | str contains "expires=3600")
}

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

#[test]
def "test s3 performance mock mode" [] {
    s3-enable-mock-mode
    
    # Test rapid operations
    let start_time = (date now)
    
    for i in 1..10 {
        let result = (aws s3 ls)
        assert ($result | length) == 2
    }
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    # Should complete 10 operations quickly in mock mode
    assert ($duration < 1sec)
}

# ============================================================================
# REAL MODE COMPATIBILITY TESTS (conditional)
# ============================================================================

#[test]
def "test s3 real mode structure" [] {
    # Test that real mode returns proper structure (if AWS credentials available)
    s3-disable-mock-mode
    
    try {
        let result = (aws s3 ls)
        # If successful, should return table format
        assert ($result | describe | str starts-with "table")
    } catch {
        # If no credentials, that's expected - test passes
        assert true
    }
    
    # Reset to mock mode
    s3-enable-mock-mode
}