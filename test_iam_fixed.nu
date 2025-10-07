#!/usr/bin/env nu

# Test IAM operation generation with properly working shape resolution
use src/parameter_generation.nu

# Load IAM schema
let iam_schema = (open real-schemas/iam.json)

print "=== IAM Schema Info ==="
print $"Service: ($iam_schema.metadata.serviceFullName)"

# Simple shape resolver that converts AWS schemas to our format
def convert-aws-schema [operation_name: string, op_data: record, shapes: record]: nothing -> record {
    # Resolve input schema
    let input_schema = if "input" in ($op_data | columns) {
        let input_shape = $shapes | get $op_data.input.shape
        convert-structure-shape $input_shape $shapes
    } else {
        { shape_type: "structure", members: {} }
    }
    
    # Resolve output schema  
    let output_schema = if "output" in ($op_data | columns) {
        let output_shape = $shapes | get $op_data.output.shape
        convert-structure-shape $output_shape $shapes
    } else {
        { shape_type: "structure", members: {} }
    }
    
    {
        operation_name: $operation_name,
        service: "iam",
        input_schema: $input_schema,
        output_schema: $output_schema
    }
}

# Convert AWS structure shape to our format
def convert-structure-shape [shape: record, shapes: record]: nothing -> record {
    if $shape.type == "structure" {
        let converted_members = if "members" in ($shape | columns) {
            $shape.members | transpose name details | reduce -f {} { |member, acc|
                let member_type = (get-member-type $member.details $shapes)
                let is_required = ($shape | get -o required | default [] | any { |r| $r == $member.name })
                
                $acc | insert $member.name {
                    type: $member_type,
                    required: $is_required,
                    constraints: {}
                }
            }
        } else {
            {}
        }
        
        {
            shape_type: "structure",
            members: $converted_members
        }
    } else {
        { shape_type: "structure", members: {} }
    }
}

# Get the appropriate type for a member
def get-member-type [member_details: record, shapes: record]: nothing -> string {
    if "shape" in ($member_details | columns) {
        let referenced_shape = $shapes | get $member_details.shape
        match $referenced_shape.type {
            "string" => "string",
            "integer" => "int", 
            "long" => "int",
            "boolean" => "bool",
            "timestamp" => "datetime",
            "list" => "list",
            "structure" => "record",
            _ => "string"
        }
    } else {
        "string"
    }
}

# Test CreateUser operation
print "\n=== Testing CreateUser Operation ==="
let create_user_op = $iam_schema.operations.CreateUser
let create_user_converted = (convert-aws-schema "CreateUser" $create_user_op $iam_schema.shapes)

print "Converted CreateUser Schema:"
print ($create_user_converted.input_schema | to yaml)

let signature = (parameter_generation generate-function-signature $create_user_converted)
print "\n🎉 Generated CreateUser Function:"
print $signature

# Test AttachUserPolicy operation
print "\n=== Testing AttachUserPolicy Operation ==="
let attach_policy_op = $iam_schema.operations.AttachUserPolicy
let attach_converted = (convert-aws-schema "AttachUserPolicy" $attach_policy_op $iam_schema.shapes)

print "Converted AttachUserPolicy Schema:"
print ($attach_converted.input_schema | to yaml)

let attach_signature = (parameter_generation generate-function-signature $attach_converted)
print "\n🎉 Generated AttachUserPolicy Function:"
print $attach_signature

# Test ListUsers operation
print "\n=== Testing ListUsers Operation ==="
let list_users_op = $iam_schema.operations.ListUsers
let list_converted = (convert-aws-schema "ListUsers" $list_users_op $iam_schema.shapes)

let list_signature = (parameter_generation generate-function-signature $list_converted)
print "\n🎉 Generated ListUsers Function:"
print $list_signature