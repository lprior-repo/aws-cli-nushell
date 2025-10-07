#!/usr/bin/env nu

# Test IAM operation generation with proper shape resolution
use src/parameter_generation.nu

# Load IAM schema
let iam_schema = (open real-schemas/iam.json)

print "=== IAM Schema Info ==="
print $"Service: ($iam_schema.metadata.serviceFullName)"
print $"Operations: ($iam_schema.operations | columns | length)"
print $"Shapes: ($iam_schema.shapes | columns | length)"

# Helper function to resolve shape references
def resolve-shape [shape_ref: any, shapes: record]: nothing -> any {
    match ($shape_ref | describe) {
        "record" => {
            if "shape" in ($shape_ref | columns) {
                # This is a shape reference, resolve it
                let shape_name = $shape_ref.shape
                if $shape_name in ($shapes | columns) {
                    let resolved = $shapes | get $shape_name
                    {
                        shape_type: $resolved.type,
                        members: ($resolved | get -i members | default {}),
                        required: ($resolved | get -i required | default [])
                    }
                } else {
                    { shape_type: "structure", members: {} }
                }
            } else {
                $shape_ref
            }
        },
        _ => { shape_type: "structure", members: {} }
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

print "Resolved Input Schema:"
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

# Test ListUsers operation
print "\n=== Testing ListUsers Operation ==="
let list_users_op = $iam_schema.operations.ListUsers

let list_input = (resolve-shape $list_users_op.input $iam_schema.shapes)
let list_output = if "output" in ($list_users_op | columns) {
    (resolve-shape $list_users_op.output $iam_schema.shapes)
} else {
    { shape_type: "structure", members: {} }
}

let list_operation = {
    operation_name: "ListUsers", 
    service: "iam",
    input_schema: $list_input,
    output_schema: $list_output
}

let list_signature = (parameter_generation generate-function-signature $list_operation)
print "Generated ListUsers Function:"
print $list_signature

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