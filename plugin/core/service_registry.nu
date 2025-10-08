# Service Registry - Central management for AWS service modules
# Handles registration, discovery, validation, and lifecycle management

use service_interface.nu
use error_handler.nu
use module_cache.nu

# Global service registry state
export-env {
    $env.NUAWS_SERVICE_REGISTRY = {}
    $env.NUAWS_MODULE_CACHE = {}
    $env.NUAWS_VALIDATION_CACHE = {}
}

# Service registration record structure
def service-registration-schema []: nothing -> record {
    {
        name: "string",
        module_path: "string",
        metadata: "record",
        validation_status: "record",
        load_time: "datetime",
        last_used: "datetime",
        usage_count: "int",
        status: "string"  # "registered", "loaded", "validated", "error"
    }
}

# Register a service module in the registry
export def register-service [
    service_name: string,
    module_path: string,
    --validate = true,
    --force = false
]: nothing -> record {
    
    # Check if service already registered
    if $service_name in $env.NUAWS_SERVICE_REGISTRY and not $force {
        return {
            success: false,
            message: $"Service '($service_name)' already registered. Use --force to override.",
            service_name: $service_name
        }
    }
    
    # Validate module path exists
    if not ($module_path | path exists) {
        return {
            success: false,
            message: $"Module path does not exist: ($module_path)",
            service_name: $service_name
        }
    }
    
    # Base registration structure
    let base_registration = {
        name: $service_name,
        module_path: $module_path,
        metadata: {},
        validation_status: {},
        load_time: (date now),
        last_used: (date now),
        usage_count: 0,
        status: "registered"
    }
    
    # Validate interface compliance if requested
    let validation_result = if $validate {
        try {
            let validation = service_interface validate-service-module $module_path
            
            if $validation.compliant {
                {
                    success: true,
                    validation_status: $validation,
                    status: "validated",
                    error: null
                }
            } else {
                return {
                    success: false,
                    message: $"Service module validation failed: ($validation.errors | str join ', ')",
                    service_name: $service_name,
                    validation: $validation
                }
            }
        } catch { |err|
            return {
                success: false,
                message: $"Validation error: ($err.msg)",
                service_name: $service_name
            }
        }
    } else {
        {
            success: true,
            validation_status: {},
            status: "registered",
            error: null
        }
    }
    
    # Try to load metadata (simulated for testing since Nushell requires literal paths for 'use')
    let metadata_result = try {
        # Simulate loading module metadata by creating a minimal version
        # In a real implementation, this would require a different approach to dynamic loading
        let metadata = {
            name: $service_name,
            description: $"Simulated metadata for ($service_name)",
            version: "1.0.0",
            type: "simulated",
            capabilities: ["basic_validation"],
            requires_auth: true,
            supports_mock: true,
            operations_count: 0,
            last_updated: (date now),
            dependencies: []
        }
        {
            success: true,
            metadata: $metadata,
            status: "loaded"
        }
    } catch { |err|
        return {
            success: false,
            message: $"Failed to load module metadata: ($err.msg)",
            service_name: $service_name
        }
    }
    
    # Build final registration
    let final_registration = $base_registration 
        | update validation_status $validation_result.validation_status
        | update metadata $metadata_result.metadata
        | update status $metadata_result.status
    
    # Add to registry
    $env.NUAWS_SERVICE_REGISTRY = ($env.NUAWS_SERVICE_REGISTRY | insert $service_name $final_registration)
    
    return {
        success: true,
        message: $"Service '($service_name)' registered successfully",
        service_name: $service_name,
        status: $final_registration.status
    }
}

# Unregister a service module
export def unregister-service [service_name: string]: nothing -> record {
    if $service_name not-in $env.NUAWS_SERVICE_REGISTRY {
        return {
            success: false,
            message: $"Service '($service_name)' not found in registry"
        }
    }
    
    # Remove from registry
    $env.NUAWS_SERVICE_REGISTRY = ($env.NUAWS_SERVICE_REGISTRY | reject $service_name)
    
    # Clear caches
    if $service_name in $env.NUAWS_MODULE_CACHE {
        $env.NUAWS_MODULE_CACHE = ($env.NUAWS_MODULE_CACHE | reject $service_name)
    }
    
    if $service_name in $env.NUAWS_VALIDATION_CACHE {
        $env.NUAWS_VALIDATION_CACHE = ($env.NUAWS_VALIDATION_CACHE | reject $service_name)
    }
    
    return {
        success: true,
        message: $"Service '($service_name)' unregistered successfully"
    }
}

# Get service registration information
export def get-service-registration [service_name: string]: nothing -> record {
    if $service_name in $env.NUAWS_SERVICE_REGISTRY {
        $env.NUAWS_SERVICE_REGISTRY | get $service_name
    } else {
        error make {
            msg: $"Service '($service_name)' not found in registry"
        }
    }
}

# List all registered services
export def list-registered-services []: nothing -> list<record> {
    $env.NUAWS_SERVICE_REGISTRY | transpose name registration | each { |item|
        {
            name: $item.name,
            status: $item.registration.status,
            module_path: $item.registration.module_path,
            last_used: $item.registration.last_used,
            usage_count: $item.registration.usage_count,
            compliant: ($item.registration.validation_status.compliant? | default false)
        }
    }
}

# Auto-discover and register service modules
export def auto-discover-services [
    --scan-paths: list<string> = ["plugin/services", "aws"],
    --validate = true,
    --force = false
]: nothing -> record {
    
    # Collect all discovery results from all scan paths
    let all_results = $scan_paths | each { |scan_path|
        if ($scan_path | path exists) {
            let service_files = ls $scan_path | where type == file and name =~ "\\.nu$"
            
            $service_files | each { |file|
                let service_name = $file.name | path basename | str replace ".nu" ""
                let module_path = $file.name
                
                try {
                    let result = register-service $service_name $module_path --validate=$validate --force=$force
                    
                    if $result.success {
                        {
                            service: $service_name,
                            path: $module_path,
                            status: "registered",
                            outcome: "success"
                        }
                    } else {
                        {
                            service: $service_name,
                            path: $module_path,
                            status: "failed",
                            outcome: "failed",
                            error: $result.message
                        }
                    }
                } catch { |err|
                    {
                        service: $service_name,
                        path: $module_path,
                        status: "error",
                        outcome: "failed",
                        error: $err.msg
                    }
                }
            }
        } else {
            []
        }
    } | flatten
    
    # Aggregate results
    let successful = $all_results | where outcome == "success"
    let failed = $all_results | where outcome == "failed"
    
    {
        discovered: ($all_results | length),
        registered: ($successful | length),
        failed: ($failed | length),
        services: ($successful | select service path status),
        errors: ($failed | select service error)
    }
}

# Load service module with advanced caching
export def load-service-module [service_name: string]: nothing -> any {
    # Check if service is registered
    if $service_name not-in $env.NUAWS_SERVICE_REGISTRY {
        error make {
            msg: $"Service '($service_name)' not registered in service registry"
        }
    }
    
    let registration = $env.NUAWS_SERVICE_REGISTRY | get $service_name
    
    try {
        # Use advanced module cache for loading
        let module = module_cache load-module-cached $service_name $registration.module_path
        
        # Update registration statistics
        mut updated_registration = $registration
        $updated_registration.last_used = (date now)
        $updated_registration.usage_count = $updated_registration.usage_count + 1
        $updated_registration.status = "loaded"
        $env.NUAWS_SERVICE_REGISTRY = ($env.NUAWS_SERVICE_REGISTRY | upsert $service_name $updated_registration)
        
        return $module
        
    } catch { |err|
        # Update registration with error status
        mut updated_registration = $registration
        $updated_registration.status = "load_error"
        $env.NUAWS_SERVICE_REGISTRY = ($env.NUAWS_SERVICE_REGISTRY | upsert $service_name $updated_registration)
        
        error make {
            msg: $"Failed to load service module '($service_name)': ($err.msg)"
        }
    }
}

# Get service statistics
export def get-service-statistics []: nothing -> record {
    let registered = $env.NUAWS_SERVICE_REGISTRY | transpose name registration
    
    {
        total_registered: ($registered | length),
        loaded_in_cache: ($env.NUAWS_MODULE_CACHE | columns | length),
        by_status: ($registered | group-by {|item| $item.registration.status} | transpose status count | each {|item| {status: $item.status, count: ($item.count | length)}}),
        most_used: ($registered | sort-by {|item| $item.registration.usage_count} | reverse | first 5 | get name),
        recently_used: ($registered | sort-by {|item| $item.registration.last_used} | reverse | first 5 | get name),
        validation_summary: {
            compliant: ($registered | where {|item| $item.registration.validation_status.compliant? | default false} | length),
            non_compliant: ($registered | where {|item| not ($item.registration.validation_status.compliant? | default true)} | length),
            not_validated: ($registered | where {|item| $item.registration.validation_status == {}} | length)
        }
    }
}

# Clear service caches
export def clear-service-caches [
    --module-cache = true,
    --validation-cache = true,
    --service: string
]: nothing -> record {
    mut cleared = {
        module_cache: 0,
        validation_cache: 0,
        advanced_cache: 0
    }
    
    if $service != null {
        # Clear specific service
        if $module_cache {
            # Clear from advanced module cache
            if (module_cache is-module-cached $service) {
                module_cache evict-module $service | ignore
                $cleared.advanced_cache = 1
            }
            
            # Clear from legacy cache
            if $service in $env.NUAWS_MODULE_CACHE {
                $env.NUAWS_MODULE_CACHE = ($env.NUAWS_MODULE_CACHE | reject $service)
                $cleared.module_cache = 1
            }
        }
        
        if $validation_cache and $service in $env.NUAWS_VALIDATION_CACHE {
            $env.NUAWS_VALIDATION_CACHE = ($env.NUAWS_VALIDATION_CACHE | reject $service)
            $cleared.validation_cache = 1
        }
    } else {
        # Clear all caches
        if $module_cache {
            # Clear advanced module cache
            let advanced_cache_result = module_cache clear-cache
            $cleared.advanced_cache = $advanced_cache_result.cleared_entries
            
            # Clear legacy cache
            $cleared.module_cache = ($env.NUAWS_MODULE_CACHE | columns | length)
            $env.NUAWS_MODULE_CACHE = {}
        }
        
        if $validation_cache {
            $cleared.validation_cache = ($env.NUAWS_VALIDATION_CACHE | columns | length)
            $env.NUAWS_VALIDATION_CACHE = {}
        }
    }
    
    $cleared
}

# Validate all registered services
export def validate-all-services []: nothing -> record {
    let services = list-registered-services
    
    # Process each service validation
    let all_results = $services | each { |service|
        try {
            let validation = service_interface validate-service-module $service.module_path
            
            {
                service: $service.name,
                compliant: $validation.compliant,
                issues: ($validation.missing_exports ++ $validation.metadata_issues ++ $validation.errors),
                outcome: (if $validation.compliant { "compliant" } else { "non_compliant" })
            }
        } catch {
            {
                service: $service.name,
                compliant: false,
                issues: ["Validation failed"],
                outcome: "error"
            }
        }
    }
    
    # Aggregate results
    let compliant_count = $all_results | where outcome == "compliant" | length
    let non_compliant_count = $all_results | where outcome == "non_compliant" | length
    let error_count = $all_results | where outcome == "error" | length
    
    {
        total: ($services | length),
        compliant: $compliant_count,
        non_compliant: $non_compliant_count,
        errors: $error_count,
        results: ($all_results | select service compliant issues)
    }
}

# Export registry state for debugging
export def export-registry-state []: nothing -> record {
    {
        registry: $env.NUAWS_SERVICE_REGISTRY,
        module_cache: ($env.NUAWS_MODULE_CACHE | columns),
        validation_cache: ($env.NUAWS_VALIDATION_CACHE | columns),
        statistics: (get-service-statistics)
    }
}