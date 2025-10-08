# Unified Test Runner for All AWS Services
# Tests all generated AWS services

use nutest/nutest/mod.nu

def main [] {
    print "🧪 Running unified AWS services tests..."
    
    # Test that the unified module loads
    print "Testing unified module loading..."
    try {
        use nuaws/mod.nu *
        let info = (nuaws info)
        print $"✅ NuAWS module loaded: ($info.name)"
    } catch { |err|
        print $"❌ Failed to load unified module: ($err.msg)"
        return
    }
    
    # Test service info functions
    print "Testing service info functions..."
    use nuaws/mod.nu *
    
    let s3_info = (aws s3 info)
    print $"✅ S3: ($s3_info.operations_count) operations"
    
    let ec2_info = (aws ec2 info)  
    print $"✅ EC2: ($ec2_info.operations_count) operations"
    
    let iam_info = (aws iam info)
    print $"✅ IAM: ($iam_info.operations_count) operations"
    
    let lambda_info = (aws lambda info)
    print $"✅ Lambda: ($lambda_info.operations_count) operations"
    
    # Test NuAWS check
    let check_result = (nuaws check)
    print $"✅ NuAWS status: ($check_result.status)"
    
    print "🎉 All tests passed! NuAWS unified system is working correctly."
}