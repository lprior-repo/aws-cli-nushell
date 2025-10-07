#!/usr/bin/env nu

# Test IAM operation generation with full recursive shape resolution
use src/parameter_generation.nu

# Load IAM schema
let iam_schema = (open real-schemas/iam.json)

print "=== IAM Schema Info ==="
print $"Service: ($iam_schema.metadata.serviceFullName)"
print $"Operations: ($iam_schema.operations | columns | length)"
print $"Shapes: ($iam_schema.shapes | columns | length)"

# Helper function to recursively resolve shape references
def resolve-shape [shape_ref: any, shapes: record]: nothing -> any {
    match ($shape_ref | describe) {
        "record" => {
            if "shape" in ($shape_ref | columns) {
                # This is a shape reference, resolve it
                let shape_name = $shape_ref.shape
                if $shape_name in ($shapes | columns) {
                    let resolved = $shapes | get $shape_name
                    resolve-shape-definition $resolved $shapes
                } else {
                    { shape_type: "string", required: false }  # Fallback for unknown shapes
                }
            } else {
                $shape_ref
            }
        },
        _ => { shape_type: "structure", members: {} }
    }
}

# Helper to resolve a shape definition with recursive member resolution
def resolve-shape-definition [shape_def: record, shapes: record]: nothing -> any {
    match $shape_def.type {
        "structure" => {
            let members = if "members" in ($shape_def | columns) {
                # Recursively resolve each member
                $shape_def.members | transpose name details | each { |member|
                    let resolved_member = (resolve-shape $member.details $shapes)
                    { 
                        name: $member.name,
                        type: $resolved_member.shape_type,
                        required: ($shape_def | get -o required | default [] | any { |r| $r == $member.name }),
                        constraints: ($resolved_member | get -o constraints | default {})
                    }
                } | transpose name value | into record
            } else {
                {}
            }
            {
                shape_type: "structure",
                members: $members,
                required: ($shape_def | get -o required | default [])
            }
        },
        "list" => {
            let member_type = if "member" in ($shape_def | columns) {
                let resolved_member = (resolve-shape $shape_def.member $shapes) 
                $resolved_member.shape_type
            } else {
                "string"
            }
            {
                shape_type: "list",
                member: $member_type
            }
        },
        _ => {
            # For primitive types, just return the type
            {
                shape_type: $shape_def.type,
                constraints: ($shape_def | select -o min max pattern enum | default {})
            }
        }
    }
}

# Test CreateUser operation
print "\n=== Testing CreateUser Operation ==="
let create_user_op = $iam_schema.operations.CreateUser

# Resolve input and output shapes
let input_schema = (resolve-shape $create_user_op.input $iam_schema.shapes)
let output_schema = if "output" in ($create_user_op | columns) {
    (resolve-shape $create_user_op.output $iam_schema.shapes)
} else {
    { shape_type: "structure", members: {} }
}

print "CreateUser Input Schema:"
print ($input_schema | to yaml)

let operation = {
    operation_name: "CreateUser",
    service: "iam",
    input_schema: $input_schema,
    output_schema: $output_schema
}

let signature = (parameter_generation generate-function-signature $operation)
print "\nGenerated CreateUser Function:"
print $signature

# Test AttachUserPolicy operation  
print "\n=== Testing AttachUserPolicy Operation ==="
let attach_policy_op = $iam_schema.operations.AttachUserPolicy

let attach_input = (resolve-shape $attach_policy_op.input $iam_schema.shapes)
let attach_output = if "output" in ($attach_policy_op | columns) {
    (resolve-shape $attach_policy_op.output $iam_schema.shapes)
} else {
    { shape_type: "structure", members: {} }
}

print "AttachUserPolicy Input Schema:"
print ($attach_input | to yaml)

let attach_operation = {
    operation_name: "AttachUserPolicy",
    service: "iam",
    input_schema: $attach_input,
    output_schema: $attach_output
}

let attach_signature = (parameter_generation generate-function-signature $attach_operation)
print "\nGenerated AttachUserPolicy Function:"
print $attach_signature