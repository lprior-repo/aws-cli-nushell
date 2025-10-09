# Build Script for NuAWS - Pre-Generation System
# Transforms from generation-based to distribution-based model
# Generates all AWS services and completions at build time

use nuaws/generator.nu *
use std log

# Build configuration
const BUILD_CONFIG = {
    parallel_builds: true,
    validation_enabled: true,
    cache_enabled: true,
    performance_monitoring: true,
    incremental_builds: true
}

# Enhanced build function with parallel processing and incremental builds
def main [
    --clean               # Clean existing generated files first
    --services: list<string> = []  # Specific services to generate (empty = all)
    --parallel: int = 4   # Number of parallel generation tasks
    --incremental         # Enable incremental build optimization
    --force              # Force rebuild even if files are up to date
    --analytics          # Enable build analytics and reporting
]: nothing -> nothing {
    log info "🚀 Building NuAWS Unified Module for Distribution..."
    let build_start_time = (date now)
    
    # Load build configuration
    let config = get_build_config $analytics
    log info $"Configuration: parallel=($parallel), incremental=($incremental), analytics=($analytics)"
    print ""
    
    if $clean {
        print "🧹 Cleaning existing generated files..."
        clean-generated-files
    }
    
    # Ensure required directories exist
    create-build-directories
    
    # Discover all available services from schemas
    let available_services = discover-services
    let services_to_generate = if ($services | is-empty) { $available_services } else { $services }
    
    print $"📋 Found ($available_services | length) services in schemas"
    print $"🎯 Generating ($services_to_generate | length) services..."
    print ""
    
    # Apply incremental build optimization
    let services_to_build = if $incremental {
        filter_services_for_incremental_build $services_to_generate $force
    } else {
        $services_to_generate
    }
    
    log info $"Services requiring build: ($services_to_build | length) of ($services_to_generate | length)"
    
    # Generate all services with enhanced parallel processing
    let generation_results = generate-all-services-enhanced $services_to_build $parallel $config
    
    # Create unified exports
    create-unified-exports $generation_results
    
    # Generate external completions
    generate-all-completions $services_to_generate
    
    # Validate generated modules
    validate-generated-modules $generation_results
    
    # Create comprehensive build summary with analytics
    let build_duration = ((date now) - $build_start_time)
    create-enhanced-distribution-summary $generation_results $build_duration $config
    
    # Performance reporting
    if $analytics {
        generate_build_analytics $generation_results $build_duration $config
    }
    
    log info $"✅ Build complete in ($build_duration)! NuAWS is ready for distribution."
    log info "📦 To use: git clone && use nuaws.nu"
}

# Clean all generated files
def clean-generated-files []: nothing -> nothing {
    # Clean directories
    let directories_to_clean = ["modules", "completions"]
    for dir in $directories_to_clean {
        if ($dir | path exists) {
            rm -rf $dir
            print $"  🗑️  Removed ($dir)/"
        }
    }
    
    # Clean generated service files in root
    let service_files = ["s3.nu", "ec2.nu", "iam.nu", "lambda.nu", "stepfunctions.nu", "dynamodb.nu"]
    for file in $service_files {
        if ($file | path exists) {
            rm $file
            print $"  🗑️  Removed ($file)"
        }
    }
    
    # Clean completion files in root
    let completion_files = glob "completions_*.nu"
    for file in $completion_files {
        if ($file | path exists) {
            rm $file
            print $"  🗑️  Removed ($file)"
        }
    }
}

# Create required build directories
def create-build-directories []: nothing -> nothing {
    let directories = ["modules", "completions"]
    
    for dir in $directories {
        if not ($dir | path exists) {
            mkdir $dir
            print $"  📁 Created ($dir)/ directory"
        }
    }
}

# Discover all available services from schemas directory
def discover-services []: nothing -> list<string> {
    if not ("schemas" | path exists) {
        print "⚠️  Warning: schemas/ directory not found"
        return []
    }
    
    ls "schemas/" 
    | where name =~ '\.json$' 
    | get name 
    | each { |file| $file | path basename | str replace ".json" "" }
    | sort
}

# Generate all services with parallel processing
def generate-all-services [services: list<string>, parallel_count: int]: nothing -> table {
    let total_services = ($services | length)
    
    # Generate results for each service
    let results = ($services | each { |service|
        let start_time = (date now)
        
        try {
            # Generate the service module
            let schema_file = $"schemas/($service).json"
            if not ($schema_file | path exists) {
                print $"  ⚠️  Schema not found for ($service), skipping..."
                {
                    service: $service,
                    status: "skipped",
                    error: "Schema file not found",
                    output_file: null
                }
            } else {
                print $"🔧 Generating ($service)..."
                
                # Use the generator to create the service module  
                generate-aws-service $service --use-schema $schema_file --output "modules" --with-completions
                
                # Calculate generation time
                let end_time = (date now)
                let duration = ($end_time - $start_time)
                
                print $"  ✅ Generated ($service).nu"
                
                {
                    service: $service,
                    status: "success",
                    duration: $duration,
                    output_file: $"modules/($service).nu"
                }
            }
        } catch { |err|
            print $"  ❌ Failed to generate ($service): ($err.msg)"
            
            {
                service: $service,
                status: "failed",
                error: $err.msg,
                output_file: null
            }
        }
    })
    
    print ""
    print $"📊 Generation Summary:"
    let successful = ($results | where status == "success" | length)
    let failed = ($results | where status == "failed" | length)
    print $"  ✅ Successful: ($successful)"
    if $failed > 0 {
        print $"  ❌ Failed: ($failed)"
    }
    
    $results
}

# Create unified module exports
def create-unified-exports [results: table]: nothing -> nothing {
    let successful_services = ($results | where status == "success" | get service)
    
    # Create modules/mod.nu that exports all services
    let module_exports = ($successful_services | each { |service|
        $"export use ($service).nu *"
    } | str join "\n")
    
    let modules_mod_content = $"# NuAWS Unified Module Exports
# Generated by build.nu at (date now | format date '%Y-%m-%d %H:%M:%S')
# All AWS services pre-generated and ready for use

($module_exports)

# Service discovery function
export def \"nuaws services\" []: nothing -> list<string> {
    ($successful_services)
}
"

    $modules_mod_content | save --force "modules/mod.nu"
    print $"  📦 Created modules/mod.nu with ($successful_services | length) services"
}

# Generate external completions for all services
def generate-all-completions [services: list<string>]: nothing -> nothing {
    print "🔧 Generating external completions..."
    
    for service in $services {
        let schema_file = $"schemas/($service).json"
        if not ($schema_file | path exists) {
            continue
        }
        
        try {
            # Generate completion file for the service
            let completion_content = generate-service-completion $service $schema_file
            let completion_file = $"completions/($service).nu"
            
            $completion_content | save $completion_file
            print $"  ✅ Generated ($completion_file)"
            
        } catch { |err|
            print $"  ⚠️  Failed to generate completion for ($service): ($err.msg)"
        }
    }
    
    # Create unified completions module
    let completion_exports = ($services | each { |service|
        let file = $"completions/($service).nu"
        if ($file | path exists) {
            $"export use ($service).nu *"
        } else {
            null
        }
    } | compact | str join "\n")
    
    let completions_mod_content = $"# NuAWS External Completions
# Generated by build.nu at (date now | format date '%Y-%m-%d %H:%M:%S')

($completion_exports)
"

    $completions_mod_content | save --force "completions/mod.nu"
    print $"  📦 Created completions/mod.nu"
}

# Generate completion content for a service
def generate-service-completion [service: string, schema_file: string]: nothing -> string {
    let schema = try { open $schema_file } catch { return "" }
    let operations = try { $schema.operations? | default [] } catch { return "" }
    
    # Extract operation names based on schema format
    let operation_names = if ($operations | describe) =~ "^record" {
        # Handle object format (e.g., EC2)
        $operations | transpose key value | get key
    } else {
        # Handle array format (e.g., S3)
        $operations | get name? | default []
    }
    
    let completion_functions = ($operation_names | each { |op|
        $"export def \"nuaws-complete-($service)-($op)\" []: nothing -> list<string> {
    # Auto-generated completion for ($service) ($op)
    # Add custom completion logic here
    []
}"
    } | str join "\n\n")
    
    $"# External Completions for AWS ($service | str upcase) Service
# Generated by build.nu at (date now | format date '%Y-%m-%d %H:%M:%S')

($completion_functions)

# Main service completion
export def \"nuaws-complete-($service)\" []: nothing -> list<string> {
    ($operation_names)
}
"
}

# Validate all generated modules
def validate-generated-modules [results: table]: nothing -> nothing {
    print "🔍 Validating generated modules..."
    
    let successful_results = ($results | where status == "success")
    
    let validation_results = ($successful_results | each { |result|
        let module_file = ($result.output_files | get 0)
        
        # Check if file exists and has content
        if not ($module_file | path exists) {
            {
                service: $result.service,
                status: "error",
                message: "Module file not found"
            }
        } else {
            let file_size = (ls $module_file | first | get size)
            if ($file_size | into int) < 100 {
                {
                    service: $result.service,
                    status: "error", 
                    message: ($"Module file too small " + ($file_size | into string) + " bytes")
                }
            } else {
                # Basic syntax validation (check if it's valid Nushell)
                try {
                    nu --ide-check $module_file
                    print $"  ✅ Validated ($result.service).nu"
                    {
                        service: $result.service,
                        status: "success",
                        message: "Valid"
                    }
                } catch { |err|
                    {
                        service: $result.service,
                        status: "error",
                        message: $"Syntax error - ($err.msg)"
                    }
                }
            }
        }
    })
    
    let validation_errors = ($validation_results | where status == "error")
    if ($validation_errors | length) > 0 {
        print ""
        print "❌ Validation Errors:"
        for error in $validation_errors {
            print $"  • ($error.service): ($error.message)"
        }
    } else {
        print "✅ All modules validated successfully"
    }
}

# Create distribution summary
def create-distribution-summary [results: table]: nothing -> nothing {
    let successful = ($results | where status == "success")
    let total_operations = ($successful | each { |result|
        let module_file = ($result.output_files | get 0)
        if ($module_file | path exists) {
            try {
                let content = (open $module_file)
                # Count export def statements 
                ($content | str replace --all --regex 'export def "[^"]*"' "" | str replace --all 'export def' "" | lines | length) - 1
            } catch { 0 }
        } else { 0 }
    } | math sum)
    
    let summary = {
        build_date: (date now | format date '%Y-%m-%d %H:%M:%S'),
        total_services: ($results | length),
        successful_services: ($successful | length),
        failed_services: (($results | where status == "failed") | length),
        total_operations: $total_operations,
        services: ($successful | get service | sort),
        distribution_ready: true
    }
    
    $summary | to json | save --force "build-summary.json"
    
    print $"📈 Distribution Summary:"
    print $"  🎯 Services: ($summary.successful_services)/($summary.total_services)"
    print $"  ⚡ Operations: ($summary.total_operations)"
    print $"  📦 Ready for distribution: ($summary.distribution_ready)"
    print $"  📄 Details saved to build-summary.json"
}

# ============================================================================
# Enhanced Build System Functions - ARCH-002 Implementation  
# ============================================================================

# Get build configuration with performance monitoring
def get_build_config [analytics: bool]: nothing -> record {
    {
        parallel_builds: $BUILD_CONFIG.parallel_builds,
        validation_enabled: $BUILD_CONFIG.validation_enabled,
        cache_enabled: $BUILD_CONFIG.cache_enabled,
        performance_monitoring: ($BUILD_CONFIG.performance_monitoring and $analytics),
        incremental_builds: $BUILD_CONFIG.incremental_builds,
        start_time: (date now)
    }
}

# Filter services for incremental build optimization
def filter_services_for_incremental_build [
    services: list<string>,
    force: bool
]: nothing -> list<string> {
    if $force {
        log info "Force rebuild enabled - all services will be rebuilt"
        return $services
    }
    
    let services_needing_build = ($services | where { |service|
        let schema_path = $"schemas/($service).json"
        let module_path = $"modules/($service).nu"
        let completion_path = $"completions/($service).nu"
        
        # Check if output files exist and are newer than schema
        if not ($module_path | path exists) or not ($completion_path | path exists) {
            true  # Build needed - missing output files
        } else {
            # Compare modification times 
            let schema_time = (ls -l $schema_path | get 0.modified)
            let module_time = (ls -l $module_path | get 0.modified)
            let completion_time = (ls -l $completion_path | get 0.modified)
            
            # Build if schema is newer than generated files
            ($schema_time > $module_time) or ($schema_time > $completion_time)
        }
    })
    
    if ($services_needing_build | length) != ($services | length) {
        log info $"Incremental build: ($services_needing_build | length) of ($services | length) services need rebuilding"
    }
    
    $services_needing_build
}

# Enhanced parallel service generation with progress reporting
def generate-all-services-enhanced [
    services: list<string>,
    parallel_workers: int,
    config: record
]: nothing -> list<record> {
    log info $"Starting enhanced parallel generation with ($parallel_workers) workers"
    
    let total_services = ($services | length)
    
    # Progress will be tracked within the parallel processing
    
    # Enhanced parallel processing with error recovery
    let results = ($services | par-each --threads $parallel_workers { |service|
        let start_time = (date now)
        
        try {
            let schema_file = $"schemas/($service).json"
            if not ($schema_file | path exists) {
                log info $"Skipping ($service) - no schema found"
                {
                    service: $service,
                    status: "skipped",
                    error: "Schema file not found",
                    duration: ((date now) - $start_time),
                    output_files: []
                }
            } else {
                # Generate service with comprehensive output tracking
                let generation_result = generate-aws-service $service --use-schema $schema_file --output "modules" --with-completions
                
                log info $"Completed ($service) generation"
                
                {
                    service: $service,
                    status: "success", 
                    duration: ((date now) - $start_time),
                    operations_count: ($generation_result.operations_count? | default 0),
                    output_files: [
                        $generation_result.module_path,
                        $"completions/($service).nu"
                    ]
                }
            }
        } catch { |err|
            log error $"Failed ($service) generation - ($err.msg)"
            
            # Error recovery: log detailed error information
            log error $"Service ($service) generation failed: ($err)"
            
            {
                service: $service,
                status: "failed",
                error: $err.msg,
                duration: ((date now) - $start_time),
                output_files: []
            }
        }
    })
    
    $results
}

# Create enhanced distribution summary with analytics
def create-enhanced-distribution-summary [
    results: list<record>,
    build_duration: duration,
    config: record
]: nothing -> nothing {
    let successful = ($results | where status == "success")
    let failed = ($results | where status == "failed")
    let skipped = ($results | where status == "skipped")
    
    let total_operations = ($successful | get operations_count | where $it != null | math sum)
    
    let summary = {
        timestamp: (date now),
        build_duration: $build_duration,
        total_services: ($results | length),
        successful_services: ($successful | length),
        failed_services: ($failed | length),
        skipped_services: ($skipped | length),
        total_operations: $total_operations,
        services: ($successful | get service | sort),
        failed_services_details: ($failed | select service error),
        skipped_services_details: ($skipped | select service error),
        distribution_ready: (($failed | length) == 0),
        config: $config,
        performance_metrics: {
            avg_service_build_time: ($successful | get duration | math avg),
            fastest_service: ($successful | sort-by duration | first | get service),
            slowest_service: ($successful | sort-by duration | last | get service),
            parallel_efficiency: (calculate_parallel_efficiency $successful $build_duration)
        }
    }
    
    $summary | to json | save --force "build-summary.json"
    
    # Enhanced reporting
    log info "📈 Enhanced Distribution Summary:"
    log info $"  🎯 Services: ($summary.successful_services)/($summary.total_services)"
    log info $"  ⚡ Operations: ($summary.total_operations)"
    log info $"  ⏱️  Build time: ($summary.build_duration)"
    log info $"  📦 Ready for distribution: ($summary.distribution_ready)"
    
    if ($summary.failed_services) > 0 {
        log warning $"  ❌ Failed services: ($summary.failed_services)"
        log warning "    See build-summary.json for details"
    }
    
    if ($summary.skipped_services) > 0 {
        log info $"  ⏭️  Skipped services: ($summary.skipped_services)"
    }
}

# Generate build analytics report
def generate_build_analytics [
    results: list<record>,
    build_duration: duration, 
    config: record
]: nothing -> nothing {
    let analytics = {
        build_session: {
            timestamp: (date now),
            duration: $build_duration,
            config: $config
        },
        performance_analysis: {
            service_build_times: ($results | select service duration status),
            build_efficiency: (calculate_build_efficiency $results $build_duration),
            bottlenecks: (identify_build_bottlenecks $results),
            recommendations: (generate_build_recommendations $results $config)
        },
        resource_usage: {
            peak_parallel_workers: $config.parallel_builds,
            cache_utilization: "Not yet implemented",
            memory_efficiency: "Not yet implemented"
        }
    }
    
    $analytics | to json | save "logs/build_analytics.json"
    log info "📊 Build analytics saved to logs/build_analytics.json"
}

# Helper function to calculate parallel efficiency
def calculate_parallel_efficiency [
    successful_results: list<record>,
    total_duration: duration
]: nothing -> float {
    let total_sequential_time = ($successful_results | get duration | math sum)
    let efficiency = ($total_sequential_time / $total_duration)
    $efficiency
}

# Helper function to calculate build efficiency
def calculate_build_efficiency [
    results: list<record>,
    total_duration: duration
]: nothing -> record {
    let successful = ($results | where status == "success")
    let total_work_time = ($successful | get duration | math sum)
    
    {
        parallel_speedup: ($total_work_time / $total_duration),
        success_rate: (($successful | length) / ($results | length)),
        avg_service_time: ($successful | get duration | math avg)
    }
}

# Helper function to identify build bottlenecks  
def identify_build_bottlenecks [
    results: list<record>
]: nothing -> list<record> {
    let successful = ($results | where status == "success")
    let avg_time = ($successful | get duration | math avg)
    
    $successful 
    | where duration > ($avg_time * 1.5)
    | select service duration
    | sort-by duration --reverse
}

# Helper function to generate build recommendations
def generate_build_recommendations [
    results: list<record>,
    config: record
]: nothing -> list<string> {
    let recommendations = []
    
    let failed_count = ($results | where status == "failed" | length)
    let slow_services = (identify_build_bottlenecks $results)
    
    if $failed_count > 0 {
        $recommendations | append "Review failed service generation logs and fix schema issues"
    }
    
    if ($slow_services | length) > 0 {
        $recommendations | append $"Optimize slow services: (($slow_services | get service | str join ', '))"
    }
    
    if not $config.cache_enabled {
        $recommendations | append "Enable caching to improve incremental build performance"
    }
    
    $recommendations
}

# Help function
export def "build help" []: nothing -> nothing {
    print "NuAWS Build System - Pre-Generation for Distribution"
    print ""
    print "Usage:"
    print "  nu build.nu                    # Generate all services"
    print "  nu build.nu --clean            # Clean and generate all"
    print "  nu build.nu --services [s3 ec2] # Generate specific services"
    print "  nu build.nu --parallel 8       # Use 8 parallel workers"
    print ""
    print "This script transforms NuAWS from generation-based to distribution-based:"
    print "• Pre-generates all AWS service modules"
    print "• Creates external completions"
    print "• Validates all generated code"
    print "• Prepares for easy distribution"
}