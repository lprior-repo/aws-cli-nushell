# Mock AWS Environment - Simulates AWS CLI responses for testing
# Provides realistic mock data for AWS services without making actual API calls

# Mock AWS service responses
export def mock-aws-response [
    service: string,
    operation: string,
    --region: string = "us-east-1",
    --format: string = "json"
]: nothing -> any {
    
    match [$service, $operation] {
        # S3 mock responses
        ["s3api", "list-buckets"] => {
            {
                Buckets: [
                    {Name: "test-bucket-1", CreationDate: "2023-01-01T00:00:00.000Z"},
                    {Name: "test-bucket-2", CreationDate: "2023-01-02T00:00:00.000Z"},
                    {Name: "test-bucket-3", CreationDate: "2023-01-03T00:00:00.000Z"},
                    {Name: "nuaws-test-bucket", CreationDate: "2023-01-04T00:00:00.000Z"},
                    {Name: "demo-bucket", CreationDate: "2023-01-05T00:00:00.000Z"}
                ],
                Owner: {
                    DisplayName: "test-user",
                    ID: "test-canonical-user-id"
                }
            }
        },
        
        ["s3api", "list-objects-v2"] => {
            {
                Contents: [
                    {Key: "file1.txt", Size: 1024, LastModified: "2023-01-01T00:00:00.000Z"},
                    {Key: "file2.json", Size: 2048, LastModified: "2023-01-02T00:00:00.000Z"},
                    {Key: "folder/file3.csv", Size: 4096, LastModified: "2023-01-03T00:00:00.000Z"}
                ],
                IsTruncated: false,
                MaxKeys: 1000,
                Name: "test-bucket",
                Prefix: ""
            }
        },
        
        # EC2 mock responses
        ["ec2", "describe-instances"] => {
            {
                Reservations: [
                    {
                        Instances: [
                            {
                                InstanceId: "i-1234567890abcdef0",
                                InstanceType: "t3.micro",
                                State: {Name: "running", Code: 16},
                                VpcId: "vpc-12345678",
                                SubnetId: "subnet-12345678",
                                PublicIpAddress: "54.123.45.67"
                            },
                            {
                                InstanceId: "i-0fedcba0987654321",
                                InstanceType: "t3.small",
                                State: {Name: "stopped", Code: 80},
                                VpcId: "vpc-87654321",
                                SubnetId: "subnet-87654321",
                                PublicIpAddress: null
                            }
                        ]
                    }
                ]
            }
        },
        
        ["ec2", "describe-vpcs"] => {
            {
                Vpcs: [
                    {
                        VpcId: "vpc-12345678",
                        State: "available",
                        CidrBlock: "10.0.0.0/16",
                        IsDefault: true
                    },
                    {
                        VpcId: "vpc-87654321", 
                        State: "available",
                        CidrBlock: "172.16.0.0/16",
                        IsDefault: false
                    }
                ]
            }
        },
        
        ["ec2", "describe-subnets"] => {
            {
                Subnets: [
                    {
                        SubnetId: "subnet-12345678",
                        VpcId: "vpc-12345678",
                        CidrBlock: "10.0.1.0/24",
                        AvailabilityZone: $"($region)a"
                    },
                    {
                        SubnetId: "subnet-87654321",
                        VpcId: "vpc-87654321", 
                        CidrBlock: "172.16.1.0/24",
                        AvailabilityZone: $"($region)b"
                    }
                ]
            }
        },
        
        ["ec2", "describe-security-groups"] => {
            {
                SecurityGroups: [
                    {
                        GroupId: "sg-12345678",
                        GroupName: "default",
                        Description: "Default security group",
                        VpcId: "vpc-12345678"
                    },
                    {
                        GroupId: "sg-87654321",
                        GroupName: "web-servers",
                        Description: "Security group for web servers",
                        VpcId: "vpc-12345678"
                    }
                ]
            }
        },
        
        ["ec2", "describe-key-pairs"] => {
            {
                KeyPairs: [
                    {KeyName: "my-key-pair", KeyFingerprint: "aa:bb:cc:dd:ee:ff"},
                    {KeyName: "test-key", KeyFingerprint: "11:22:33:44:55:66"},
                    {KeyName: "production-key", KeyFingerprint: "aa:11:bb:22:cc:33"}
                ]
            }
        },
        
        # IAM mock responses
        ["iam", "list-users"] => {
            {
                Users: [
                    {
                        UserName: "admin-user",
                        UserId: "AIDACKCEVSQ6C2EXAMPLE",
                        CreateDate: "2023-01-01T00:00:00.000Z",
                        Path: "/"
                    },
                    {
                        UserName: "test-user",
                        UserId: "AIDACKCEVSQ6C2EXAMPLE2",
                        CreateDate: "2023-01-02T00:00:00.000Z", 
                        Path: "/"
                    },
                    {
                        UserName: "demo-user",
                        UserId: "AIDACKCEVSQ6C2EXAMPLE3",
                        CreateDate: "2023-01-03T00:00:00.000Z",
                        Path: "/demo/"
                    }
                ]
            }
        },
        
        ["iam", "list-roles"] => {
            {
                Roles: [
                    {
                        RoleName: "EC2InstanceRole",
                        RoleId: "AROA12EXAMPLE34567890",
                        CreateDate: "2023-01-01T00:00:00.000Z",
                        Path: "/"
                    },
                    {
                        RoleName: "LambdaExecutionRole",
                        RoleId: "AROA12EXAMPLE34567891",
                        CreateDate: "2023-01-02T00:00:00.000Z",
                        Path: "/service-role/"
                    }
                ]
            }
        },
        
        ["iam", "list-policies"] => {
            {
                Policies: [
                    {
                        PolicyName: "S3ReadOnlyPolicy",
                        PolicyId: "ANPA12EXAMPLE34567890",
                        CreateDate: "2023-01-01T00:00:00.000Z",
                        Path: "/"
                    },
                    {
                        PolicyName: "EC2FullAccessPolicy",
                        PolicyId: "ANPA12EXAMPLE34567891", 
                        CreateDate: "2023-01-02T00:00:00.000Z",
                        Path: "/"
                    }
                ]
            }
        },
        
        # Lambda mock responses
        ["lambda", "list-functions"] => {
            {
                Functions: [
                    {
                        FunctionName: "hello-world",
                        FunctionArn: $"arn:aws:lambda:($region):123456789012:function:hello-world",
                        Runtime: "nodejs18.x",
                        Handler: "index.handler",
                        LastModified: "2023-01-01T00:00:00.000Z"
                    },
                    {
                        FunctionName: "data-processor",
                        FunctionArn: $"arn:aws:lambda:($region):123456789012:function:data-processor",
                        Runtime: "python3.9",
                        Handler: "lambda_function.lambda_handler",
                        LastModified: "2023-01-02T00:00:00.000Z"
                    },
                    {
                        FunctionName: "api-handler",
                        FunctionArn: $"arn:aws:lambda:($region):123456789012:function:api-handler",
                        Runtime: "nodejs18.x",
                        Handler: "app.handler",
                        LastModified: "2023-01-03T00:00:00.000Z"
                    }
                ]
            }
        },
        
        # DynamoDB mock responses
        ["dynamodb", "list-tables"] => {
            {
                TableNames: [
                    "Users",
                    "Products", 
                    "Orders",
                    "Sessions",
                    "Analytics"
                ]
            }
        },
        
        # RDS mock responses
        ["rds", "describe-db-instances"] => {
            {
                DBInstances: [
                    {
                        DBInstanceIdentifier: "production-db",
                        DBInstanceClass: "db.t3.medium",
                        Engine: "mysql",
                        DBInstanceStatus: "available",
                        AllocatedStorage: 100
                    },
                    {
                        DBInstanceIdentifier: "test-db",
                        DBInstanceClass: "db.t3.micro",
                        Engine: "postgres",
                        DBInstanceStatus: "available",
                        AllocatedStorage: 20
                    }
                ]
            }
        },
        
        ["rds", "describe-db-clusters"] => {
            {
                DBClusters: [
                    {
                        DBClusterIdentifier: "aurora-cluster-1",
                        Engine: "aurora-mysql",
                        Status: "available",
                        DatabaseName: "production"
                    },
                    {
                        DBClusterIdentifier: "aurora-cluster-2",
                        Engine: "aurora-postgresql",
                        Status: "available", 
                        DatabaseName: "analytics"
                    }
                ]
            }
        },
        
        # STS mock responses (for identity verification)
        ["sts", "get-caller-identity"] => {
            {
                UserId: "AIDACKCEVSQ6C2EXAMPLE",
                Account: "123456789012",
                Arn: "arn:aws:iam::123456789012:user/test-user"
            }
        },
        
        # Default fallback
        _ => {
            {
                mock: true,
                service: $service,
                operation: $operation,
                region: $region,
                message: "Mock response - no specific data available for this operation",
                timestamp: (date now)
            }
        }
    }
}

# Create a mock AWS CLI wrapper
export def create-mock-aws-cli []: nothing -> string {
    let mock_script = $"#!/usr/bin/env nu
# Mock AWS CLI for testing

let service = $env.AWS_SERVICE_ARG
let operation = $env.AWS_OPERATION_ARG 
let region = $env.AWS_DEFAULT_REGION? | default \"us-east-1\"

use ($env.PWD)/nutest/plugin/mock_aws_environment.nu
mock_aws_environment mock-aws-response $service $operation --region=$region | to json
"
    
    let mock_path = $"($env.NUAWS_CACHE_DIR)/mock-aws"
    $mock_script | save $mock_path
    chmod +x $mock_path
    $mock_path
}

# Setup comprehensive mock environment
export def setup-mock-environment []: nothing -> record {
    # Create mock AWS CLI
    let mock_aws_path = create-mock-aws-cli
    
    # Enable mock modes for all services
    let services = ["s3", "s3api", "ec2", "iam", "lambda", "dynamodb", "rds", "sts"]
    
    for service in $services {
        let mock_env_var = $"($service | str upcase)_MOCK_MODE"
        load-env {$mock_env_var: "true"}
    }
    
    # Set mock AWS credentials
    load-env {
        AWS_ACCESS_KEY_ID: "AKIAIOSFODNN7EXAMPLE",
        AWS_SECRET_ACCESS_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        AWS_DEFAULT_REGION: "us-east-1",
        AWS_ACCOUNT_ID: "123456789012"
    }
    
    {
        mock_aws_path: $mock_aws_path,
        mock_services: $services,
        mock_credentials_set: true,
        setup_at: (date now)
    }
}

# Teardown mock environment
export def teardown-mock-environment []: nothing -> nothing {
    # Remove mock AWS CLI
    let mock_aws_path = $"($env.NUAWS_CACHE_DIR)/mock-aws"
    if ($mock_aws_path | path exists) {
        rm $mock_aws_path
    }
    
    # Disable mock modes
    let services = ["s3", "s3api", "ec2", "iam", "lambda", "dynamodb", "rds", "sts"]
    
    for service in $services {
        let mock_env_var = $"($service | str upcase)_MOCK_MODE"
        try {
            hide-env $mock_env_var
        } catch {
            # Ignore if variable doesn't exist
        }
    }
}

# Validate mock responses
export def validate-mock-responses []: nothing -> record {
    let services_to_test = [
        ["s3api", "list-buckets"],
        ["ec2", "describe-instances"],
        ["iam", "list-users"],
        ["lambda", "list-functions"],
        ["dynamodb", "list-tables"],
        ["rds", "describe-db-instances"]
    ]
    
    let validation_results = $services_to_test | each { |service_op|
        let service = $service_op.0
        let operation = $service_op.1
        
        try {
            let response = mock-aws-response $service $operation
            let has_expected_structure = match [$service, $operation] {
                ["s3api", "list-buckets"] => ("Buckets" in ($response | columns)),
                ["ec2", "describe-instances"] => ("Reservations" in ($response | columns)),
                ["iam", "list-users"] => ("Users" in ($response | columns)),
                ["lambda", "list-functions"] => ("Functions" in ($response | columns)),
                ["dynamodb", "list-tables"] => ("TableNames" in ($response | columns)),
                ["rds", "describe-db-instances"] => ("DBInstances" in ($response | columns)),
                _ => true
            }
            
            {
                service: $service,
                operation: $operation,
                status: "success",
                has_expected_structure: $has_expected_structure
            }
        } catch { |err|
            {
                service: $service,
                operation: $operation,
                status: "error",
                error: $err.msg
            }
        }
    }
    
    let successful_tests = $validation_results | where status == "success" | length
    let total_tests = $validation_results | length
    
    {
        success_rate: (($successful_tests / $total_tests) * 100 | math round),
        successful_tests: $successful_tests,
        total_tests: $total_tests,
        validation_results: $validation_results,
        validated_at: (date now)
    }
}

# Generate realistic test data for specific scenarios
export def generate-scenario-data [
    scenario: string
]: nothing -> record {
    match $scenario {
        "web_application" => {
            {
                ec2_instances: ["i-web01", "i-web02", "i-db01"],
                s3_buckets: ["webapp-assets", "webapp-logs", "webapp-backups"],
                iam_roles: ["WebServerRole", "DatabaseRole"],
                lambda_functions: ["api-handler", "image-processor"],
                rds_instances: ["webapp-db"]
            }
        },
        "data_pipeline" => {
            {
                lambda_functions: ["data-ingestion", "data-transform", "data-validation"],
                s3_buckets: ["raw-data", "processed-data", "archive-data"],
                dynamodb_tables: ["DataCatalog", "ProcessingStatus"],
                iam_roles: ["DataPipelineRole", "LambdaExecutionRole"]
            }
        },
        "microservices" => {
            {
                lambda_functions: ["user-service", "product-service", "order-service"],
                dynamodb_tables: ["Users", "Products", "Orders"],
                s3_buckets: ["service-configs", "service-logs"],
                iam_roles: ["MicroserviceRole"]
            }
        },
        _ => {
            {
                message: $"Unknown scenario: ($scenario)",
                available_scenarios: ["web_application", "data_pipeline", "microservices"]
            }
        }
    }
}