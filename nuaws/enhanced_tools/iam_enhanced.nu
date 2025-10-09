# Enhanced IAM Tools for NuAWS
# Simple enhanced functionality on top of base IAM commands

# Export enhanced IAM commands
export def "iam enhanced" [] {
    print "Enhanced IAM tools loaded successfully"
}

# Simple enhanced user listing
export def "iam list-users-enhanced" [] {
    ^aws iam list-users --query 'Users[*].[UserName,CreateDate,Arn]' --output table
}

# Simple enhanced policy listing
export def "iam list-policies-enhanced" [] {
    ^aws iam list-policies --query 'Policies[*].[PolicyName,Arn,AttachmentCount]' --output table
}