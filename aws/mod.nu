# AWS Serverless Testing Framework
#
# A comprehensive testing framework for AWS serverless applications that provides
# type-safe wrappers around AWS CLI with Jest-like assertions and Terratest-inspired
# infrastructure testing patterns.
#
# Example Usage:
#   use aws; aws lambda invoke-function --name my-function --payload '{"test": true}'
#   use aws; aws dynamodb scan-table --table-name my-table
#   use aws; aws eventbridge send-event --source app.test --detail-type "Test Event"

export use lambda.nu *
export use dynamodb.nu *
export use eventbridge.nu *
export use apigateway.nu *
export use stepfunctions.nu *
export use cloudformation.nu *
export use iam.nu *
export use s3.nu *
export use assertions.nu *
export use infrastructure.nu *

# Core AWS CLI wrapper with error handling and type safety
export def aws-cli [
    service: string,
    operation: string,
    ...args: string
]: nothing -> any {
    let cmd = ["aws", $service, $operation, ...$args]
    let result = try {
        run-external "aws" [$service, $operation, ...$args] | from json
    } catch { |error|
        error make {
            msg: $"AWS CLI command failed: ($cmd | str join ' ')",
            label: { text: $error.msg }
        }
    }
    $result
}

# Get AWS account information
export def get-account-info []: nothing -> record<account_id: string, region: string, user_arn: string> {
    let sts_result = aws-cli "sts" "get-caller-identity"
    let region = try { $env.AWS_REGION? } catch { "us-east-1" }
    
    {
        account_id: $sts_result.Account,
        region: $region,
        user_arn: $sts_result.Arn
    }
}

# Wait for AWS resource to reach desired state
export def wait-for-state [
    service: string,
    waiter: string,
    ...args: string
]: nothing -> nothing {
    try {
        run-external "aws" [$service, "wait", $waiter, ...$args]
    } catch { |error|
        error make {
            msg: $"Wait operation failed for ($service) ($waiter)",
            label: { text: $error.msg }
        }
    }
}

# Setup test environment variables
export def setup-test-env [
    --profile: string = "default",
    --region: string = "us-east-1"
]: nothing -> nothing {
    $env.AWS_PROFILE = $profile
    $env.AWS_REGION = $region
    $env.AWS_DEFAULT_REGION = $region
}

# Cleanup test resources by tags
export def cleanup-test-resources [
    tag_key: string = "TestFramework",
    tag_value: string = "nutest"
]: nothing -> nothing {
    # This will be implemented to clean up resources based on tags
    print $"Cleaning up resources with tag ($tag_key)=($tag_value)"
}