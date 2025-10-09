# NuAWS - Unified AWS Module for Nushell
# One module to rule them all - complete AWS CLI integration

# Re-export the generator
export use generator.nu *

# Re-export all services (will be generated)
export use services.nu *

# Re-export all completions (will be generated)
export use completions.nu *

# Re-export enhanced tools
export use lambda_enhanced.nu *

# ============================================================================
# Main NuAWS Entry Points  
# ============================================================================

# Initialize NuAWS with all AWS services
export def "nuaws init" [
    --schemas-dir(-s): string = "schemas",   # Directory containing AWS schemas
    --force(-f)                             # Force regeneration of existing services
]: nothing -> record {
    print "🚀 Initializing NuAWS - Universal AWS Module System"
    
    # Generate all services from schemas
    let generation_results = (generate-all-services $schemas_dir --with-completions --with-tests)
    
    # Consolidate into unified files
    consolidate-services $generation_results
    consolidate-completions $generation_results  
    
    print $"✅ NuAWS initialization complete with ($generation_results | length) services"
    
    {
        status: "success",
        services_generated: ($generation_results | length),
        services: ($generation_results | get service),
        timestamp: (date now)
    }
}

# Generate a specific AWS service
export def "nuaws generate" [
    service: string,                        # AWS service name
    --schema(-s): string,                   # Optional schema file path
    --force(-f)                            # Force regeneration
]: nothing -> record {
    print $"🎯 Generating AWS ($service) service..."
    
    let result = if ($schema | is-empty) {
        generate-aws-service $service --with-completions --with-tests
    } else {
        generate-aws-service $service --use-schema $schema --with-completions --with-tests
    }
    
    # Update unified files
    update-unified-services $service
    update-unified-completions $service
    
    print $"✅ ($service) service generated with ($result.operations_count) operations"
    $result
}

# List all available AWS services
export def "nuaws list" []: nothing -> table<service: string, operations: int, status: string> {
    let schema_files = try { ls "schemas/*.json" | get name } catch { [] }
    let service_files = try { ls "*.nu" | where name =~ "^aws_" | get name } catch { [] }
    
    $schema_files | each { |schema_file|
        let service_name = ($schema_file | path basename | str replace ".json" "")
        let service_file = $"($service_name).nu"
        let operations_count = try {
            let schema = (open $schema_file)
            $schema.operations? | default [] | length
        } catch { 0 }
        
        {
            service: $service_name,
            operations: $operations_count,
            status: (if ($service_file in $service_files) { "generated" } else { "available" })
        }
    }
}

# Get information about NuAWS
export def "nuaws info" []: nothing -> record {
    let schemas_available = try { ls "schemas/*.json" | length } catch { 0 }
    let services_generated = try { ls "*.nu" | where name =~ "^aws_" | length } catch { 0 }
    
    {
        name: "NuAWS - Universal AWS Module",
        version: "1.0.0",
        description: "Unified AWS CLI integration for Nushell",
        schemas_available: $schemas_available,
        services_generated: $services_generated,
        generator: "Universal AWS Generator",
        features: [
            "Type-safe parameter generation",
            "External completions",
            "Mock mode support", 
            "Comprehensive testing",
            "Pipeline integration",
            "Lambda enhanced features",
            "SAM/Serverless integration",
            "Real-time log streaming",
            "Performance analysis",
            "Cost optimization"
        ]
    }
}

# ============================================================================
# Consolidation Functions
# ============================================================================

# Consolidate all generated services into unified services.nu
def consolidate-services [generation_results: list<record>]: nothing -> nothing {
    print "📦 Consolidating services into unified module..."
    
    let header = build-services-header
    let service_imports = ($generation_results | each { |result|
        $"export use ../($result.service).nu *"
    })
    let footer = build-services-footer
    
    let unified_content = $header + "\n\n" + ($service_imports | str join "\n") + "\n\n" + $footer
    $unified_content | save --force "nuaws/services.nu"
}

# Consolidate all completions into unified completions.nu  
def consolidate-completions [generation_results: list<record>]: nothing -> nothing {
    print "🎯 Consolidating completions into unified module..."
    
    let header = build-completions-header
    let completion_imports = ($generation_results | each { |result|
        $"export use ../completions_($result.service).nu *"
    })
    let footer = build-completions-footer
    
    let unified_content = $header + "\n\n" + ($completion_imports | str join "\n") + "\n\n" + $footer
    $unified_content | save --force "nuaws/completions.nu"
}

# Update unified services when single service is generated
def update-unified-services [service: string]: nothing -> nothing {
    # Check if services.nu exists, if not create it
    if not ("nuaws/services.nu" | path exists) {
        consolidate-services [{ service: $service }]
    } else {
        # Add new service to existing file
        let current_content = (open "nuaws/services.nu")
        let new_import = $"export use ../($service).nu *"
        
        if not ($current_content | str contains $new_import) {
            let updated_content = $current_content + "\n" + $new_import
            $updated_content | save --force "nuaws/services.nu"
        }
    }
}

# Update unified completions when single service is generated
def update-unified-completions [service: string]: nothing -> nothing {
    # Check if completions.nu exists, if not create it
    if not ("nuaws/completions.nu" | path exists) {
        consolidate-completions [{ service: $service }]
    } else {
        # Add new completion to existing file
        let current_content = (open "nuaws/completions.nu")
        let new_import = $"export use ../completions_($service).nu *"
        
        if not ($current_content | str contains $new_import) {
            let updated_content = $current_content + "\n" + $new_import
            $updated_content | save --force "nuaws/completions.nu"
        }
    }
}

# Build services.nu header
def build-services-header []: nothing -> string {
    $"# NuAWS Unified Services Module
# All AWS services consolidated into one module
# Generated by Universal AWS Generator

"
}

# Build services.nu footer
def build-services-footer []: nothing -> string {
    $"
# End of unified services module
# Use 'nuaws list' to see all available services
# Use 'help aws <service>' to see service operations"
}

# Build completions.nu header
def build-completions-header []: nothing -> string {
    $"# NuAWS Unified Completions Module  
# All AWS external completions consolidated
# Generated by Universal AWS Generator

"
}

# Build completions.nu footer
def build-completions-footer []: nothing -> string {
    $"
# End of unified completions module
# External completions are automatically available when using AWS commands"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Check if NuAWS is properly initialized
export def "nuaws check" []: nothing -> record {
    let required_files = [
        "nuaws/generator.nu",
        "nuaws/services.nu", 
        "nuaws/completions.nu"
    ]
    
    let file_status = ($required_files | each { |file|
        {
            file: $file,
            exists: ($file | path exists),
            size: (if ($file | path exists) { ls $file | get size | first } else { 0 })
        }
    })
    
    let all_exist = ($file_status | all { |status| $status.exists })
    
    {
        status: (if $all_exist { "ready" } else { "incomplete" }),
        files: $file_status,
        recommendation: (if $all_exist { "NuAWS is ready to use" } else { "Run 'nuaws init' to initialize" })
    }
}

# Clean up generated files
export def "nuaws clean" [
    --force(-f)    # Skip confirmation
]: nothing -> nothing {
    if not $force {
        print "⚠️  This will remove all generated AWS service files"
        let confirm = (input "Continue? (y/N): ")
        if ($confirm | str downcase) != "y" {
            print "Cancelled"
            return
        }
    }
    
    print "🧹 Cleaning up generated files..."
    
    # Remove generated service files
    try { rm -f aws_*.nu } catch { }
    try { rm -f completions_*.nu } catch { }
    try { rm -f test_*.nu } catch { }
    try { rm -f nuaws/services.nu } catch { }
    try { rm -f nuaws/completions.nu } catch { }
    
    print "✅ Cleanup complete"
}