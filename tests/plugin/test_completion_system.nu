# NuAWS Completion System Tests
# Comprehensive tests for completion discovery, registration, and external completions

use std assert
use ../../plugin/core/completion_registry.nu *
use ../../plugin/core/external_completions.nu *
use ../../plugin/core/completion_manager.nu *

#[before-each]
def setup [] {
    # Initialize environment for each test
    $env.NUAWS_PLUGIN_DIR = $"(pwd)/plugin"
    $env.NUAWS_CACHE_DIR = $"($env.HOME)/.nuaws/cache"
    $env.NUAWS_CONFIG_DIR = $"($env.HOME)/.nuaws"
    $env.AWS_PROFILE = ($env.AWS_PROFILE? | default "default")
    $env.AWS_DEFAULT_REGION = ($env.AWS_DEFAULT_REGION? | default "us-east-1")
    
    # Initialize completion system state
    $env.NUAWS_COMPLETION_REGISTRY = {}
    $env.NUAWS_COMPLETION_CACHE = {}
    $env.NUAWS_COMPLETION_METADATA = {}
    $env.NUAWS_COMPLETION_STATS = {
        total_registrations: 0,
        cache_hits: 0,
        cache_misses: 0,
        discovery_calls: 0,
        last_cleanup: (date now)
    }
    $env.NUAWS_EXTERNAL_COMPLETIONS_ENABLED = "true"
    
    # Initialize plugin state
    $env.NUAWS_SERVICE_REGISTRY = {}
    $env.NUAWS_MODULE_CACHE = {}
    $env.NUAWS_MODULE_CACHE_ENTRIES = {}
    $env.NUAWS_VALIDATION_CACHE = {}
    $env.NUAWS_CACHE_STATS = {
        hits: 0,
        misses: 0,
        evictions: 0,
        created: (date now),
        last_cleanup: (date now)
    }
    
    # Ensure directories exist
    mkdir $env.NUAWS_CONFIG_DIR
    mkdir $env.NUAWS_CACHE_DIR
    mkdir $"($env.NUAWS_CACHE_DIR)/completions"
    
    {test_context: "completion_system"}
}

#[test]
def test_completion_registry_basic_functionality [] {
    # Test basic registration
    let result = register-completion "s3" "ls" "bucket" "discover-s3-buckets"
    assert ($result.success == true) "Should successfully register completion"
    assert ($result.completion_key == "s3:ls:bucket") "Should create correct completion key"
}

#[test] 
def test_completion_registry_statistics [] {
    # Register a few completions
    register-completion "s3" "ls" "bucket" "discover-s3-buckets" | ignore
    register-completion "ec2" "describe-instances" "instance-ids" "discover-ec2-instances" | ignore
    
    let stats = get-completion-stats
    assert ($stats.total_registrations == 2) "Should track registration count"
    assert ($stats.registry_entries == 2) "Should show correct registry entries"
}

#[test]
def test_completion_cache_functionality [] {
    # Test cache key building and retrieval
    let cache_key = "s3:buckets:default"
    let test_data = ["bucket1", "bucket2", "bucket3"]
    
    # Simulate cache entry
    let cache_entry = {
        data: $test_data,
        cached_at: (date now),
        expires_at: ((date now) + 300sec),
        cache_key: $cache_key,
        resource_count: ($test_data | length)
    }
    
    $env.NUAWS_COMPLETION_CACHE = {$cache_key: $cache_entry}
    
    let cached_result = get-cached-completion $cache_key
    assert ($cached_result != null) "Should retrieve cached entry"
    assert ($cached_result.data | length) == 3 "Should contain correct data"
}

#[test]
def test_auto_register_standard_completions [] {
    let result = auto-register-standard-completions
    assert ($result.success == true) "Should successfully auto-register completions"
    assert ($result.registered_completions > 0) "Should register multiple completions"
    
    # Check that some expected completions were registered
    let completions = list-completions
    let s3_completions = $completions | where service == "s3"
    assert (($s3_completions | length) > 0) "Should register S3 completions"
}

#[test]
def test_external_completions_list [] {
    let functions = list-external-completions
    assert (($functions | length) > 0) "Should define external completion functions"
    
    # Check for key completion functions
    let function_names = $functions | get name
    assert ("nu-complete aws s3 buckets" in $function_names) "Should include S3 bucket completions"
    assert ("nu-complete aws ec2 instances" in $function_names) "Should include EC2 instance completions"
}

#[test]
def test_external_completions_status [] {
    let status = get-completions-status
    assert ($status.enabled == true) "Should be enabled by default"
    assert ($status.available_functions > 0) "Should show available functions"
}

#[test]
def test_completion_enable_disable [] {
    # Test enabling
    let enable_result = set-completions-enabled true
    assert ($enable_result.success == true) "Should successfully enable"
    assert ($enable_result.enabled == true) "Should confirm enabled state"
    
    # Test disabling
    let disable_result = set-completions-enabled false
    assert ($disable_result.success == true) "Should successfully disable"
    assert ($disable_result.enabled == false) "Should confirm disabled state"
}

#[test]
def test_completion_manager_init [] {
    let init_result = init-completion-system
    assert ($init_result.success == true) "Should successfully initialize completion system"
    assert ($init_result.registration_result.success == true) "Should auto-register completions"
}

#[test]
def test_completion_manager_validation [] {
    # Initialize system first
    init-completion-system | ignore
    
    let validation = validate-completion-system
    assert ($validation.overall_health != null) "Should provide health status"
    assert (($validation.validation_results | length) > 0) "Should provide validation results"
}

#[test]
def test_completion_script_generation [] {
    let script_result = generate-completion-script --output-file="test_completions.nu"
    assert ($script_result.success == true) "Should successfully generate script"
    assert ($script_result.function_count > 0) "Should include completion functions"
    
    # Check if file was created
    assert ("test_completions.nu" | path exists) "Should create completion script file"
    
    # Clean up
    rm "test_completions.nu"
}

#[test]
def test_completion_optimization [] {
    # Initialize system first
    init-completion-system | ignore
    
    let optimization = optimize-completions --warm-common-resources=false --cleanup-expired-cache=true --tune-cache-settings=false
    assert ($optimization.success == true) "Should successfully optimize completions"
    assert ($optimization.optimization_steps > 0) "Should perform optimization steps"
}

#[test]
def test_service_completion_registration [] {
    let result = register-service-completions "lambda" --auto-discover=true
    assert ($result.success == true) "Should successfully register service completions"
    assert ($result.registered_completions >= 0) "Should register some completions"
}

#[test]
def test_completion_system_report [] {
    # Initialize system first
    init-completion-system | ignore
    
    let report = completion-system-report
    assert ($report.system_health != null) "Should provide system health status"
    assert ($report.registry_statistics != null) "Should include registry statistics"
    assert ($report.external_completions_status != null) "Should include external completion status"
}