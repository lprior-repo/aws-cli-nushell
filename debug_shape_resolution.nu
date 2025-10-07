#!/usr/bin/env nu

# Debug shape resolution step by step
let iam_schema = (open real-schemas/iam.json)

print "=== Step 1: Original Input Reference ==="
let create_user_op = $iam_schema.operations.CreateUser.input
print $create_user_op

print "\n=== Step 2: Resolved Shape ==="
let shape_name = $create_user_op.shape
print $"Shape name: ($shape_name)"
let resolved_shape = $iam_schema.shapes | get $shape_name
print ($resolved_shape | to yaml)

print "\n=== Step 3: Members Details ==="
if "members" in ($resolved_shape | columns) {
    print $"Number of members: ($resolved_shape.members | columns | length)"
    $resolved_shape.members | transpose name details | each { |member|
        print $"Member: ($member.name)"
        print $"  Details: ($member.details | to yaml)"
    }
} else {
    print "No members found"
}

print "\n=== Step 4: Let's look at a specific primitive type ==="
let path_shape = $iam_schema.shapes | get pathType
print "pathType shape:"
print ($path_shape | to yaml)