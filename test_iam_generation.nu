#!/usr/bin/env nu

# Test IAM operation generation using our type-safe parameter generation system
use src/parameter_generation.nu

# Load IAM schema
let iam_schema = (open real-schemas/iam.json)

# Test CreateUser operation
let create_user_op = $iam_schema.operations.CreateUser
print "=== CreateUser Operation Schema ==="
print $create_user_op | to yaml

print "\n=== Generating Type-Safe Nushell Function Signature ==="

# Convert to our parameter generation format
let operation = {
    operation_name: "CreateUser",
    service: "iam",
    input_schema: $create_user_op.input,
    output_schema: $create_user_op.output
}

let signature = (parameter_generation generate-function-signature $operation)
print "Generated Function Signature:"
print $signature

print "\n=== Testing a few more operations ==="

# Test ListUsers
let list_users_op = $iam_schema.operations.ListUsers
let list_operation = {
    operation_name: "ListUsers", 
    service: "iam",
    input_schema: $list_users_op.input,
    output_schema: $list_users_op.output
}

let list_signature = (parameter_generation generate-function-signature $list_operation)
print "\nListUsers Function:"
print $list_signature

# Test AttachUserPolicy
let attach_policy_op = $iam_schema.operations.AttachUserPolicy
let attach_operation = {
    operation_name: "AttachUserPolicy",
    service: "iam", 
    input_schema: $attach_policy_op.input,
    output_schema: (if "output" in ($attach_policy_op | columns) { $attach_policy_op.output } else { { shape_type: "structure", members: {} } })
}

let attach_signature = (parameter_generation generate-function-signature $attach_operation)
print "\nAttachUserPolicy Function:"
print $attach_signature