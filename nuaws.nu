# NuAWS - Unified AWS Module for Nushell
# Single entry point router for all AWS operations
# Supports: nuaws service operation [args...]
#
# Examples:
#   nuaws s3 ls                     # Routes to s3 high-level commands  
#   nuaws s3 list-buckets          # Routes to s3api low-level API
#   nuaws ec2 describe-instances   # Routes to ec2 service
#   nuaws help                     # Shows all available services
#   nuaws s3 help                  # Shows s3-specific operations

# ============================================================================
# Service Discovery and Metadata
# ============================================================================

# Get all available AWS services from schemas and generated modules
export def get-available-services []: nothing -> table<service: string, operations: int, type: string, available: bool> {
    mut services = []
    
    # Check schemas directory for available services (handle both relative and absolute paths)
    let schema_files = try { 
        if ("schemas" | path exists) {
            ls "schemas/*.json" | get name 
        } else {
            []
        }
    } catch { [] }
    for schema_file in $schema_files {
        let service_name = ($schema_file | path basename | str replace ".json" "")
        let schema = try { open $schema_file } catch { continue }
        let operations_count = try { $schema.operations? | default [] | length } catch { 0 }
        
        # Determine service type and availability
        let service_type = if $service_name == "s3" { "hybrid" } else { "api" }
        let service_file = $"($service_name).nu"
        let is_available = ($service_file | path exists)
        
        $services = ($services | append {
            service: $service_name,
            operations: $operations_count,
            type: $service_type,
            available: $is_available
        })
    }
    
    $services
}

# Get operations for a specific service
export def get-service-operations [service: string]: nothing -> list<string> {
    let schema_file = $"schemas/($service).json"
    if not ($schema_file | path exists) {
        return []
    }
    
    let schema = try { open $schema_file } catch { return [] }
    let operations = try { $schema.operations? | default [] } catch { return [] }
    
    $operations | get name? | default []
}

# Check if an operation is a high-level S3 command
def is-s3-high-level [operation: string]: nothing -> bool {
    let high_level_ops = ["ls", "cp", "mv", "rm", "sync", "mb", "rb", "presign"]
    $operation in $high_level_ops
}

# Determine the actual AWS service to use for routing
def resolve-service [service: string, operation: string]: nothing -> string {
    if $service == "s3" {
        if (is-s3-high-level $operation) {
            "s3"
        } else {
            "s3api"
        }
    } else {
        $service
    }
}

# ============================================================================
# Core Router Functions
# ============================================================================

# Main router entry point
export def main [
    service?: string,      # AWS service name (s3, ec2, iam, etc.)
    operation?: string,    # Operation name (ls, describe-instances, etc.)
    ...args: string        # Additional arguments to pass to operation
]: nothing -> any {
    
    # Handle help and service discovery
    if ($service | is-empty) or $service == "help" {
        return (show-help)
    }
    
    # Handle service-specific help
    if ($operation | is-empty) or $operation == "help" {
        return (show-service-help $service)
    }
    
    # Validate service exists
    let available_services = (get-available-services)
    let service_info = ($available_services | where service == $service | first)
    
    if ($service_info | is-empty) {
        return (error make {
            msg: $"Unknown AWS service: ($service)",
            label: {
                text: $"Available services: ($available_services | get service | str join ', ')",
                span: (metadata $service).span
            }
        })
    }
    
    # Check if service module is available
    if not $service_info.available {
        return (error make {
            msg: $"Service ($service) not generated yet",
            label: {
                text: $"Run 'nu nuaws/mod.nu generate ($service)' to generate this service",
                span: (metadata $service).span
            }
        })
    }
    
    # Resolve the actual service for routing
    let target_service = (resolve-service $service $operation)
    
    # Validate operation exists
    let operations = (get-service-operations $service)
    if not ($operation in $operations) and not (is-s3-high-level $operation) {
        return (error make {
            msg: $"Unknown operation '($operation)' for service ($service)",
            label: {
                text: $"Available operations: ($operations | str join ', ')",
                span: (metadata $operation).span
            }
        })
    }
    
    # Route to the appropriate service
    route-to-service $target_service $operation $args
}

# Route command to the appropriate service module
def route-to-service [service: string, operation: string, args: list<string>]: nothing -> any {
    let service_file = $"($service).nu"
    
    if not ($service_file | path exists) {
        return (error make {
            msg: $"Service module not found: ($service_file)",
            label: {
                text: "Service may not be generated yet",
                span: (metadata $service).span
            }
        })
    }
    
    # Import the service module and invoke the operation
    # Note: This uses dynamic module loading
    try {
        # Construct the command to execute
        let cmd_args = if ($args | length) > 0 {
            $args | str join " "
        } else {
            ""
        }
        
        # Execute the service operation
        if $service == "s3" and (is-s3-high-level $operation) {
            # High-level S3 commands
            run-external "aws" (["s3", $operation] | append $args)
        } else {
            # Use the generated service module
            let full_command = $"aws ($service) ($operation)"
            
            # Check if we're in mock mode
            let mock_env_var = $"($service | str upcase)_MOCK_MODE"
            let mock_mode = try { $env | get $mock_env_var | into bool } catch { false }
            
            if $mock_mode {
                # Return mock response
                {
                    mock: true,
                    service: $service,
                    operation: $operation,
                    args: $args,
                    message: $"Mock response for ($service) ($operation)"
                }
            } else {
                # Execute actual AWS CLI command
                run-external "aws" ([$service, $operation] | append $args) | from json
            }
        }
    } catch { |err|
        error make {
            msg: $"Failed to execute ($service) ($operation): ($err.msg)",
            label: {
                text: "AWS operation failed",
                span: (metadata $operation).span
            }
        }
    }
}

# ============================================================================
# Help and Documentation Functions
# ============================================================================

# Show general help with all available services
def show-help []: nothing -> table<service: string, operations: int, status: string, description: string> {
    print "🚀 NuAWS - Unified AWS Module for Nushell"
    print ""
    print "Usage:"
    print "  nuaws <service> <operation> [args...]"
    print "  nuaws help                              # Show this help"
    print "  nuaws <service> help                    # Show service operations"
    print ""
    print "Examples:"
    print "  nuaws s3 ls                            # List S3 objects (high-level)"
    print "  nuaws s3 list-buckets                  # List S3 buckets (API)"  
    print "  nuaws ec2 describe-instances           # Describe EC2 instances"
    print "  nuaws iam list-users                   # List IAM users"
    print ""
    print "Available Services:"
    
    let services = (get-available-services)
    $services | select service operations status | insert status { |row|
        if $row.available { "✅ available" } else { "⏳ not generated" }
    } | insert description { |row|
        match $row.service {
            "s3" => "Simple Storage Service (hybrid: high-level + API)"
            "ec2" => "Elastic Compute Cloud"
            "iam" => "Identity and Access Management"
            "lambda" => "AWS Lambda Functions"
            "dynamodb" => "DynamoDB NoSQL Database"
            "stepfunctions" => "Step Functions State Machines"
            _ => "AWS Service"
        }
    }
}

# Show help for a specific service
def show-service-help [service: string]: nothing -> any {
    let available_services = (get-available-services)
    let service_info = ($available_services | where service == $service | first)
    
    if ($service_info | is-empty) {
        return (error make {
            msg: $"Unknown service: ($service)",
            label: {
                text: $"Available services: ($available_services | get service | str join ', ')",
                span: (metadata $service).span
            }
        })
    }
    
    print $"📖 AWS ($service | str upcase) Service Help"
    print ""
    
    if not $service_info.available {
        print $"⚠️  Service ($service) is not generated yet"
        print $"Run: nu nuaws/mod.nu generate ($service)"
        print ""
        return
    }
    
    let operations = (get-service-operations $service)
    
    if $service == "s3" {
        print "High-level S3 operations (aws s3):"
        print "  ls [path]                             # List objects"
        print "  cp <source> <dest>                    # Copy files"
        print "  mv <source> <dest>                    # Move files"
        print "  rm <path>                             # Remove files"
        print "  sync <source> <dest>                  # Sync directories"
        print "  mb <bucket>                           # Make bucket"
        print "  rb <bucket>                           # Remove bucket"
        print ""
        print "Low-level S3 API operations (aws s3api):"
    }
    
    print $"Operations: ($operations | length)"
    print ""
    
    # Group operations for better display
    let grouped_operations = ($operations | group-by { |op| 
        ($op | str substring 0..10)
    })
    
    for group in ($grouped_operations | transpose key value) {
        let ops = ($group.value | str join ", ")
        print $"  ($ops)"
    }
    
    print ""
    print $"Usage: nuaws ($service) <operation> [args...]"
    print $"Example: nuaws ($service) ($operations | first) --help"
}

# ============================================================================
# External Completion Support
# ============================================================================

# External completion for AWS services
export def "nuaws-complete-service" []: nothing -> list<string> {
    get-available-services | where available == true | get service
}

# External completion for operations within a service
export def "nuaws-complete-operation" [service: string]: nothing -> list<string> {
    let operations = (get-service-operations $service)
    
    if $service == "s3" {
        # Add high-level operations for S3
        let high_level = ["ls", "cp", "mv", "rm", "sync", "mb", "rb", "presign"]
        $high_level | append $operations
    } else {
        $operations
    }
}

# ============================================================================
# Integration with Existing Generator System
# ============================================================================

# Quick access to generator functions
export def "nuaws-init" []: nothing -> any {
    nu nuaws/mod.nu init
}

export def "nuaws-generate" [service: string]: nothing -> any {
    nu nuaws/mod.nu generate $service
}

export def "nuaws-list" []: nothing -> any {
    nu nuaws/mod.nu list
}

export def "nuaws-info" []: nothing -> any {
    nu nuaws/mod.nu info
}

# ============================================================================
# Module Exports for Single-File Distribution
# ============================================================================

# Standalone nuaws command for when used outside module context
def nuaws [
    service?: string,
    operation?: string, 
    ...args: string
]: nothing -> any {
    main $service $operation ...$args
}

# ============================================================================
# Startup and Status Functions
# ============================================================================

# Show startup status and initialization info
export def "nuaws-status" []: nothing -> record {
    print "🚀 NuAWS Unified Module Status"
    let services = (get-available-services)
    let available_count = ($services | where available == true | length)
    let total_count = ($services | length)
    print $"📊 Services: ($available_count)/($total_count) available"

    if $available_count == 0 {
        print "⚠️  No services generated yet. Run 'nuaws-init' to get started."
    } else {
        print $"✅ Ready! Try: nuaws help"
    }
    
    {
        available_services: $available_count,
        total_services: $total_count,
        status: (if $available_count > 0 { "ready" } else { "needs_init" }),
        services: $services
    }
}