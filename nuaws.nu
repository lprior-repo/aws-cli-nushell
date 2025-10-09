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
    # Check schemas directory for available services (handle both relative and absolute paths)
    let schema_files = try { 
        if ("schemas" | path exists) {
            ls "schemas/" | where name =~ '\.json$' | get name
        } else {
            []
        }
    } catch { [] }
    
    $schema_files | each { |schema_file|
        let service_name = ($schema_file | path basename | str replace ".json" "")
        let schema = try { open $schema_file } catch { 
            {
                service: $service_name,
                operations: 0,
                type: "api",
                available: false
            }
        }
        let operations_count = try { 
            let ops = $schema.operations? | default []
            if ($ops | describe) =~ "^record" {
                # Handle object format (e.g., EC2 format)
                $ops | transpose | length
            } else {
                # Handle array format (e.g., S3 format)  
                $ops | length
            }
        } catch { 0 }
        
        # Determine service type and availability
        let service_type = if $service_name == "s3" { "hybrid" } else { "api" }
        let service_file = $"modules/($service_name).nu"
        let is_available = ($service_file | path exists)
        
        {
            service: $service_name,
            operations: $operations_count,
            type: $service_type,
            available: $is_available
        }
    }
}

# Get operations for a specific service
export def get-service-operations [service: string]: nothing -> list<string> {
    let schema_file = $"schemas/($service).json"
    if not ($schema_file | path exists) {
        return []
    }
    
    let schema = try { open $schema_file } catch { return [] }
    let operations = try { $schema.operations? | default [] } catch { return [] }
    
    if ($operations | describe) =~ "^record" {
        # Handle object format (e.g., EC2 format) - get keys
        $operations | transpose key value | get key
    } else {
        # Handle array format (e.g., S3 format) - get name field
        $operations | get name? | default []
    }
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

# Convert AWS CLI operation name to module function name (reverse conversion)
def convert-to-module-operation [operation: string]: nothing -> string {
    # Convert kebab-case AWS CLI names to lowercase concatenated module function names
    match $operation {
        # Step Functions operations
        "list-state-machines" => "liststatemachines"
        "create-state-machine" => "createstatemachine"
        "delete-state-machine" => "deletestatemachine"
        "describe-state-machine" => "describestatemachine"
        "start-execution" => "startexecution"
        "stop-execution" => "stopexecution"
        "describe-execution" => "describeexecution"
        "list-executions" => "listexecutions"
        "create-activity" => "createactivity"
        "delete-activity" => "deleteactivity"
        "list-activities" => "listactivities"
        "describe-activity" => "describeactivity"
        
        # S3 operations
        "list-objects-v2" => "listobjectsv2"
        "list-buckets" => "listbuckets"
        "create-bucket" => "createbucket"
        "delete-bucket" => "deletebucket"
        "put-object" => "putobject"
        "get-object" => "getobject"
        "delete-object" => "deleteobject"
        "head-object" => "headobject"
        "head-bucket" => "headbucket"
        "copy-object" => "copyobject"
        
        # EC2 operations
        "describe-instances" => "describeinstances"
        "run-instances" => "runinstances"
        "terminate-instances" => "terminateinstances"
        "stop-instances" => "stopinstances"
        "start-instances" => "startinstances"
        
        # For operations not explicitly mapped, remove hyphens and convert to lowercase
        _ => ($operation | str replace --all "-" "" | str downcase)
    }
}

# Convert operation name from schema format to AWS CLI format
def convert-operation-name [operation: string]: nothing -> string {
    # Convert camelCase/PascalCase/compound words to kebab-case for AWS CLI
    # This function handles the conversion from schema operation names to actual AWS CLI command names
    
    # First handle PascalCase (IAM style) -> kebab-case
    let kebab_case = ($operation 
        | str replace --all --regex '([a-z])([A-Z])' '${1}-${2}'  # Insert hyphens before uppercase letters
        | str replace --all --regex '([A-Z])([A-Z][a-z])' '${1}-${2}'  # Handle consecutive uppercase letters
        | str downcase)  # Convert to lowercase
    
    # Then handle common AWS-specific patterns and special cases
    match $kebab_case {
        # S3 operations (handle both concatenated and hyphenated forms)
        "listobjectsv2" => "list-objects-v2"
        "list-objects-v2" => "list-objects-v2"
        "listbuckets" => "list-buckets"
        "list-buckets" => "list-buckets"
        "createbucket" => "create-bucket"
        "create-bucket" => "create-bucket"
        "deletebucket" => "delete-bucket"
        "delete-bucket" => "delete-bucket"
        "putobject" => "put-object"
        "put-object" => "put-object"
        "getobject" => "get-object"
        "get-object" => "get-object"
        "deleteobject" => "delete-object"
        "delete-object" => "delete-object"
        "headobject" => "head-object"
        "head-object" => "head-object"
        "headbucket" => "head-bucket"
        "head-bucket" => "head-bucket"
        "copyobject" => "copy-object"
        "copy-object" => "copy-object"
        
        # EC2 operations  
        "describe-instances" => "describe-instances"
        "run-instances" => "run-instances"
        "terminate-instances" => "terminate-instances"
        "stop-instances" => "stop-instances"
        "start-instances" => "start-instances"
        
        # IAM operations
        "list-users" => "list-users"
        "list-roles" => "list-roles"
        "list-groups" => "list-groups"
        "create-user" => "create-user"
        "delete-user" => "delete-user"
        "get-user" => "get-user"
        "create-role" => "create-role"
        "delete-role" => "delete-role"
        "get-role" => "get-role"
        "attach-user-policy" => "attach-user-policy"
        "detach-user-policy" => "detach-user-policy"
        "put-user-policy" => "put-user-policy"
        "get-user-policy" => "get-user-policy"
        "delete-user-policy" => "delete-user-policy"
        
        # Step Functions operations (handle lowercase concatenated -> hyphenated)
        "liststatemachines" => "list-state-machines"
        "list-state-machines" => "list-state-machines"
        "createstatemachine" => "create-state-machine" 
        "create-state-machine" => "create-state-machine"
        "deletestatemachine" => "delete-state-machine"
        "delete-state-machine" => "delete-state-machine"
        "describestatemachine" => "describe-state-machine"
        "describe-state-machine" => "describe-state-machine"
        "startexecution" => "start-execution"
        "start-execution" => "start-execution"
        "stopexecution" => "stop-execution"
        "stop-execution" => "stop-execution"
        "describeexecution" => "describe-execution"
        "describe-execution" => "describe-execution"
        "listexecutions" => "list-executions"
        "list-executions" => "list-executions"
        "createactivity" => "create-activity"
        "create-activity" => "create-activity"
        "deleteactivity" => "delete-activity"
        "delete-activity" => "delete-activity"
        "listactivities" => "list-activities"
        "list-activities" => "list-activities"
        "describeactivity" => "describe-activity"
        "describe-activity" => "describe-activity"
        
        # Additional Step Functions operations
        "createstatemachinealias" => "create-state-machine-alias"
        "deletestatemachinealias" => "delete-state-machine-alias"
        "deletestatemachineversion" => "delete-state-machine-version"
        "describemaprun" => "describe-map-run"
        "describestatemachinealias" => "describe-state-machine-alias"
        "describestatemachineforexecution" => "describe-state-machine-for-execution"
        "getactivitytask" => "get-activity-task"
        "getexecutionhistory" => "get-execution-history"
        "listmapruns" => "list-map-runs"
        "liststatemachinealiases" => "list-state-machine-aliases"
        "liststatemachineversions" => "list-state-machine-versions"
        "listtagsforresource" => "list-tags-for-resource"
        "publishstatemachineversion" => "publish-state-machine-version"
        "redriveexecution" => "redrive-execution"
        "sendtaskfailure" => "send-task-failure"
        "sendtaskheartbeat" => "send-task-heartbeat"
        "sendtasksuccess" => "send-task-success"
        "startsyncexecution" => "start-sync-execution"
        "tagresource" => "tag-resource"
        "teststate" => "test-state"
        "untagresource" => "untag-resource"
        "updatemaprun" => "update-map-run"
        "updatestatemachine" => "update-state-machine"
        "updatestatemachinealias" => "update-state-machine-alias"
        "validatestatemachinedefinition" => "validate-state-machine-definition"
        
        # Lambda operations
        "list-functions" => "list-functions"
        "create-function" => "create-function"
        "delete-function" => "delete-function"
        "get-function" => "get-function"
        "invoke" => "invoke"
        "update-function-code" => "update-function-code"
        "update-function-configuration" => "update-function-configuration"
        
        # DynamoDB operations
        "list-tables" => "list-tables"
        "create-table" => "create-table"
        "delete-table" => "delete-table"
        "describe-table" => "describe-table"
        "put-item" => "put-item"
        "get-item" => "get-item"
        "delete-item" => "delete-item"
        "scan" => "scan"
        "query" => "query"
        
        # EventBridge operations
        "list-rules" => "list-rules"
        "create-rule" => "create-rule"
        "delete-rule" => "delete-rule"
        "describe-rule" => "describe-rule"
        "put-targets" => "put-targets"
        "remove-targets" => "remove-targets"
        "list-targets-by-rule" => "list-targets-by-rule"
        
        # API Gateway operations
        "get-rest-apis" => "get-rest-apis"
        "create-rest-api" => "create-rest-api"
        "delete-rest-api" => "delete-rest-api"
        "get-resources" => "get-resources"
        "create-resource" => "create-resource"
        "delete-resource" => "delete-resource"
        
        # For any operation not explicitly handled, return the kebab-case conversion
        _ => $kebab_case
    }
}

# ============================================================================
# S3 Command Router Function
# ============================================================================

# Route S3 high-level commands to the generated module
def route-s3-command [operation: string, args: list<string>]: nothing -> any {
    use modules/s3.nu
    
    # Execute the appropriate S3 command based on operation
    match $operation {
        "ls" => {
            if ($args | length) == 0 {
                s3 aws s3 ls
            } else {
                s3 aws s3 ls ($args | get 0)
            }
        }
        "cp" => {
            if ($args | length) >= 2 {
                s3 aws s3 cp ($args | get 0) ($args | get 1)
            } else {
                error make { msg: "cp requires source and destination arguments" }
            }
        }
        "mv" => {
            if ($args | length) >= 2 {
                s3 aws s3 mv ($args | get 0) ($args | get 1)
            } else {
                error make { msg: "mv requires source and destination arguments" }
            }
        }
        "rm" => {
            if ($args | length) >= 1 {
                s3 aws s3 rm ($args | get 0)
            } else {
                error make { msg: "rm requires path argument" }
            }
        }
        "sync" => {
            if ($args | length) >= 2 {
                s3 aws s3 sync ($args | get 0) ($args | get 1)
            } else {
                error make { msg: "sync requires source and destination arguments" }
            }
        }
        "mb" => {
            if ($args | length) >= 1 {
                s3 aws s3 mb ($args | get 0)
            } else {
                error make { msg: "mb requires bucket argument" }
            }
        }
        "rb" => {
            if ($args | length) >= 1 {
                s3 aws s3 rb ($args | get 0)
            } else {
                error make { msg: "rb requires bucket argument" }
            }
        }
        "presign" => {
            if ($args | length) >= 1 {
                s3 aws s3 presign ($args | get 0)
            } else {
                error make { msg: "presign requires S3 URI argument" }
            }
        }
        _ => {
            error make { msg: $"Unknown S3 high-level operation: ($operation)" }
        }
    }
}

# Route S3 API commands to the generated module
def route-s3-api-command [operation: string, args: list<string>]: nothing -> any {
    use modules/s3.nu
    
    # Call the S3 API functions directly using if/else to avoid parsing issues
    if $operation == "list-buckets" {
        s3 aws s3 list-buckets
    } else if $operation == "list-objects-v2" {
        s3 aws s3 list-objects-v2
    } else if $operation == "get-bucket-location" {
        s3 aws s3 get-bucket-location
    } else if $operation == "get-bucket-versioning" {
        s3 aws s3 get-bucket-versioning
    } else if $operation == "get-bucket-encryption" {
        s3 aws s3 get-bucket-encryption
    } else if $operation == "get-bucket-policy" {
        s3 aws s3 get-bucket-policy
    } else if $operation == "get-bucket-acl" {
        s3 aws s3 get-bucket-acl
    } else {
        # For now, use a fallback approach for other operations
        error make { 
            msg: $"S3 API operation '($operation)' not implemented in router" 
            label: { text: "Add this operation to route-s3-api-command function", span: (metadata $operation).span }
        }
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
    # Map back to the actual service file (s3api operations are in modules/s3.nu)
    let service_file = if $service == "s3api" { "modules/s3.nu" } else { $"modules/($service).nu" }
    let original_service = if $service == "s3api" { "s3" } else { $service }
    
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
        if $service == "s3" or $original_service == "s3" {
            # Route ALL S3 commands (both high-level and API) through the unified S3 module
            if (is-s3-high-level $operation) {
                route-s3-command $operation $args
            } else {
                # Route S3 API commands to the S3 module
                route-s3-api-command $operation $args
            }
        } else {
            # Use the generated service module
            match $original_service {
                "stepfunctions" => {
                    let module_operation = (convert-to-module-operation $operation)
                    match $module_operation {
                        "liststatemachines" => {
                            use modules/stepfunctions.nu
                            aws stepfunctions liststatemachines
                        }
                        "createactivity" => {
                            use modules/stepfunctions.nu
                            aws stepfunctions createactivity
                        }
                        "createstatemachine" => {
                            use modules/stepfunctions.nu
                            aws stepfunctions createstatemachine
                        }
                        _ => {
                            # Fallback to direct AWS CLI for operations not explicitly handled
                            let aws_operation = (convert-operation-name $operation)
                            let full_args = ([$service, $aws_operation] | append $args)
                            run-external "aws" ...$full_args | from json
                        }
                    }
                }
                _ => {
                    # Fallback to direct AWS CLI for other services
                    let aws_operation = (convert-operation-name $operation)
                    let full_args = ([$service, $aws_operation] | append $args)
                    run-external "aws" ...$full_args | from json
                }
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
    $services | select service operations available | insert status { |row|
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