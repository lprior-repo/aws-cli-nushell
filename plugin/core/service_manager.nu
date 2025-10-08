# Service Manager - High-level service module management
# Provides comprehensive service lifecycle management and operations

use service_registry.nu
use service_interface.nu 
use service_loader.nu
use configuration.nu

# Initialize the service manager
export def init-service-manager []: nothing -> record {
    # Auto-discover existing services
    let discovery = service_registry auto-discover-services --validate=false
    
    {
        initialized: true,
        discovery_result: $discovery,
        timestamp: (date now)
    }
}

# Create a new service module from template
export def create-service [
    service_name: string,
    --type: string = "generated",
    --with-mock = true,
    --with-completions = true,
    --target-dir: string = "plugin/services"
]: nothing -> record {
    
    # Validate service name
    if ($service_name | str contains " ") or ($service_name | str contains "-") {
        return {
            success: false,
            message: "Service name must not contain spaces or hyphens. Use underscores if needed."
        }
    }
    
    # Create target directory if it doesn't exist
    let target_path = $"($target_dir)/($service_name).nu"
    mkdir ($target_dir)
    
    # Check if service already exists
    if ($target_path | path exists) {
        return {
            success: false,
            message: $"Service module already exists at: ($target_path)"
        }
    }
    
    # Generate service template
    let template_content = service_interface generate-service-template $service_name --type=$type --with-mock=$with_mock --with-completions=$with_completions
    
    # Write the template to file
    $template_content | save $target_path
    
    # Register the new service
    let registration = service_registry register-service $service_name $target_path --validate=true
    
    if $registration.success {
        {
            success: true,
            message: $"Service '($service_name)' created successfully",
            module_path: $target_path,
            registration: $registration
        }
    } else {
        # Clean up the file if registration failed
        rm $target_path
        {
            success: false,
            message: $"Service creation failed: ($registration.message)"
        }
    }
}

# Delete a service module
export def delete-service [
    service_name: string,
    --force = false
]: nothing -> record {
    
    # Check if service is registered
    try {
        let registration = service_registry get-service-registration $service_name
        let module_path = $registration.module_path
        
        # Ask for confirmation unless forced
        if not $force {
            print $"Are you sure you want to delete service '($service_name)'?"
            print $"Module path: ($module_path)"
            let confirmation = input "Type 'yes' to confirm: "
            
            if $confirmation != "yes" {
                return {
                    success: false,
                    message: "Operation cancelled by user"
                }
            }
        }
        
        # Unregister from registry
        service_registry unregister-service $service_name | ignore
        
        # Delete the module file
        if ($module_path | path exists) {
            rm $module_path
        }
        
        {
            success: true,
            message: $"Service '($service_name)' deleted successfully"
        }
        
    } catch {
        {
            success: false,
            message: $"Service '($service_name)' not found in registry"
        }
    }
}

# Regenerate a service module
export def regenerate-service [
    service_name: string,
    --force = false,
    --backup = true
]: nothing -> record {
    
    try {
        let registration = service_registry get-service-registration $service_name
        let module_path = $registration.module_path
        
        # Create backup if requested
        if $backup and ($module_path | path exists) {
            let backup_path = $"($module_path).backup.(date now | format date '%Y%m%d_%H%M%S')"
            cp $module_path $backup_path
            print $"Created backup: ($backup_path)"
        }
        
        # Get current metadata for regeneration
        let current_metadata = $registration.metadata
        let service_type = $current_metadata.type? | default "generated"
        let supports_mock = $current_metadata.supports_mock? | default true
        let has_completions = "external_completions" in ($current_metadata.capabilities? | default [])
        
        # Generate new template
        let template_content = service_interface generate-service-template $service_name --type=$service_type --with-mock=$supports_mock --with-completions=$has_completions
        
        # Write the new template
        $template_content | save --force $module_path
        
        # Re-register the service
        service_registry unregister-service $service_name | ignore
        let new_registration = service_registry register-service $service_name $module_path --validate=true
        
        {
            success: $new_registration.success,
            message: $"Service '($service_name)' regenerated successfully",
            registration: $new_registration
        }
        
    } catch { |err|
        {
            success: false,
            message: $"Failed to regenerate service '($service_name)': ($err.msg)"
        }
    }
}

# Validate service module compliance
export def validate-service [service_name: string]: nothing -> record {
    try {
        let registration = service_registry get-service-registration $service_name
        let validation = service_interface validate-service-module $registration.module_path
        
        {
            service: $service_name,
            validation: $validation,
            compliant: $validation.compliant,
            summary: {
                missing_exports: ($validation.missing_exports | length),
                metadata_issues: ($validation.metadata_issues | length),
                errors: ($validation.errors | length),
                warnings: ($validation.warnings | length)
            }
        }
        
    } catch { |err|
        {
            service: $service_name,
            error: $err.msg,
            compliant: false
        }
    }
}

# Get comprehensive service information
export def inspect-service [service_name: string]: nothing -> record {
    try {
        let registration = service_registry get-service-registration $service_name
        
        # Load the module to get detailed information (simulated for testing)
        let module = service_loader load-service $service_name
        
        # Get metadata (simulated)
        let metadata = {
            name: $service_name,
            description: $"Simulated metadata for ($service_name)",
            type: "simulated"
        }
        
        # Get operations (simulated)
        let operations = [
            {name: "help", category: "help"},
            {name: "list-operations", category: "info"}
        ]
        
        # Get validation status
        let validation = service_interface validate-service-module $registration.module_path
        
        {
            name: $service_name,
            registration: $registration,
            metadata: $metadata,
            operations: {
                count: ($operations | length),
                names: ($operations | each {|op| $op.name? | default ""} | where {|n| $n != ""}),
                categories: ($operations | each {|op| $op.category? | default ""} | where {|c| $c != ""} | uniq)
            },
            validation: $validation,
            file_info: {
                path: $registration.module_path,
                size: (ls $registration.module_path | first | get size),
                modified: (ls $registration.module_path | first | get modified)
            }
        }
        
    } catch { |err|
        {
            name: $service_name,
            error: $err.msg
        }
    }
}

# List all services with detailed status
export def list-services [
    --filter: string,
    --status: string,
    --sort-by: string = "name"
]: nothing -> table {
    
    let services = service_registry list-registered-services
    
    # Apply filters
    mut filtered_services = $services
    
    if $filter != null {
        $filtered_services = ($filtered_services | where name =~ $filter)
    }
    
    if $status != null {
        $filtered_services = ($filtered_services | where status == $status)
    }
    
    # Add detailed information
    let detailed_services = $filtered_services | each { |service|
        let inspection = inspect-service $service.name
        
        {
            name: $service.name,
            status: $service.status,
            compliant: $service.compliant,
            operations: ($inspection.operations?.count? | default 0),
            last_used: $service.last_used,
            usage_count: $service.usage_count,
            type: ($inspection.metadata?.type? | default "unknown"),
            supports_mock: ($inspection.metadata?.supports_mock? | default false),
            module_path: $service.module_path
        }
    }
    
    # Sort results
    match $sort_by {
        "name" => ($detailed_services | sort-by name),
        "status" => ($detailed_services | sort-by status),
        "usage" => ($detailed_services | sort-by usage_count | reverse),
        "last_used" => ($detailed_services | sort-by last_used | reverse),
        "operations" => ($detailed_services | sort-by operations | reverse),
        _ => $detailed_services
    }
}

# Generate service statistics report
export def service-report []: nothing -> record {
    let stats = service_registry get-service-statistics
    let all_services = list-services
    
    {
        summary: $stats,
        services_by_type: ($all_services | group-by type | transpose type services | each {|item| {type: $item.type, count: ($item.services | length)}}),
        compliance_rate: (if $stats.total_registered > 0 { ($stats.validation_summary.compliant / $stats.total_registered) * 100 | math round } else { 0 }),
        average_operations: ($all_services | each {|s| $s.operations} | math avg | math round),
        most_used_services: ($all_services | sort-by usage_count | reverse | first 10 | select name usage_count),
        recently_active: ($all_services | sort-by last_used | reverse | first 10 | select name last_used),
        issues_found: ($all_services | where not compliant | select name status),
        total_operations: ($all_services | each {|s| $s.operations} | math sum)
    }
}

# Bulk operations for service management
export def bulk-validate-services [
    --fix-issues = false
]: nothing -> record {
    let validation_results = service_registry validate-all-services
    
    if $fix_issues {
        mut fixed_count = 0
        
        for result in $validation_results.results {
            if not $result.compliant {
                print $"Attempting to fix issues in ($result.service)..."
                
                try {
                    regenerate-service $result.service --force=true --backup=true | ignore
                    $fixed_count = $fixed_count + 1
                    print $"✅ Fixed ($result.service)"
                } catch {
                    print $"❌ Failed to fix ($result.service)"
                }
            }
        }
        
        $validation_results | insert fixed_services $fixed_count
    } else {
        $validation_results
    }
}

# Service manager initialization can be called manually with init-service-manager