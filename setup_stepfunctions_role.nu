#!/usr/bin/env nu

# Create IAM role for Step Functions execution
def main [] {
    print "🔧 Setting up Step Functions IAM Role"
    print "===================================="
    
    let role_name = "StepFunctionsExecutionRole"
    let account_id = (aws sts get-caller-identity --query Account --output text)
    
    print $"Account ID: ($account_id)"
    print $"Role Name: ($role_name)"
    
    # Trust policy for Step Functions
    let trust_policy = {
        Version: "2012-10-17"
        Statement: [{
            Effect: "Allow"
            Principal: {
                Service: "states.amazonaws.com"
            }
            Action: "sts:AssumeRole"
        }]
    } | to json
    
    print "\n📝 Creating IAM role..."
    
    try {
        let create_result = aws iam create-role --role-name $role_name --assume-role-policy-document $trust_policy
        print "✅ Role created successfully"
    } catch { |error|
        if ($error.msg | str contains "already exists") {
            print "ℹ️  Role already exists, continuing..."
        } else {
            print $"❌ Error creating role: ($error.msg)"
            return
        }
    }
    
    print "\n🔑 Attaching basic execution policy..."
    
    try {
        aws iam attach-role-policy --role-name $role_name --policy-arn "arn:aws:iam::aws:policy/service-role/AWSStepFunctionsServiceRole"
        print "✅ Policy attached successfully"
    } catch { |error|
        print $"⚠️  Policy attachment: ($error.msg)"
    }
    
    let role_arn = $"arn:aws:iam::($account_id):role/($role_name)"
    
    print $"\n✅ Step Functions role ready!"
    print $"   Role ARN: ($role_arn)"
    print $"\n💡 You can now use this role ARN in your Step Functions deployments."
    
    $role_arn
}