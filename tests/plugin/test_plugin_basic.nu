# Basic NuAWS Plugin System Tests
# Simple tests to verify core functionality

use std assert
use ../../plugin/core/configuration.nu *
use ../../plugin/core/service_interface.nu *

#[before-each]
def setup [] {
    # Initialize environment for each test
    $env.NUAWS_PLUGIN_DIR = $"(pwd)/plugin"
    $env.NUAWS_CACHE_DIR = $"($env.HOME)/.nuaws/cache"
    $env.NUAWS_CONFIG_DIR = $"($env.HOME)/.nuaws"
    $env.AWS_PROFILE = ($env.AWS_PROFILE? | default "default")
    $env.AWS_DEFAULT_REGION = ($env.AWS_DEFAULT_REGION? | default "us-east-1")
    
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
    
    {test_context: "plugin_basic"}
}

#[test]
def test_configuration_get_debug [] {
    let debug_value = get "debug"
    assert ($debug_value == false) "Default debug value should be false"
}

#[test]
def test_service_interface_schemas [] {
    let metadata_schema = service-metadata-schema
    assert (($metadata_schema | columns | length) > 0) "Service metadata schema should be defined"
}

#[test]
def test_service_interface_required_exports [] {
    let required = required-exports
    assert (($required | length) > 0) "Required exports should be defined"
    assert ("get-service-metadata" in $required) "get-service-metadata should be required"
}

#[test]
def test_service_interface_capabilities [] {
    let capabilities = standard-capabilities
    assert (($capabilities | length) > 0) "Standard capabilities should be defined"
}

#[test]
def test_template_generation [] {
    let template = generate-service-template "test-service"
    assert ($template | str contains "export def get-service-metadata") "Template should contain required exports"
    assert ($template | str contains "test-service") "Template should contain service name"
}