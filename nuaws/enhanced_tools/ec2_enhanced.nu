# Enhanced EC2 Tools for NuAWS
# Simple enhanced functionality on top of base EC2 commands

# Export enhanced EC2 commands
export def "ec2 enhanced" [] {
    print "Enhanced EC2 tools loaded successfully"
}

# Simple enhanced instance listing
export def "ec2 describe-instances-enhanced" [] {
    ^aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' --output table
}

# Simple enhanced security group listing
export def "ec2 describe-security-groups-enhanced" [] {
    ^aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' --output table
}