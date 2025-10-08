# NuAWS Usage Guide

## Simple Usage

```nushell
# Import the unified AWS module
use nuaws/mod.nu *

# Get module information
nuaws info

# Generate a new AWS service (if you have the schema)
nuaws generate dynamodb --schema schemas/dynamodb.json

# List all available services
nuaws list

# Check module status
nuaws check

# Use AWS services directly
aws s3 info
aws ec2 info  
aws iam info
```

## Testing

```nushell
# Run unified test suite
nu run_tests.nu

# Run nutest framework tests
nu -c "use nutest/nutest/mod.nu; mod run-tests --display terminal"
```

## Directory Structure

```
aws-cli-nushell/
├── nuaws/                  # The unified NuAWS module
│   ├── mod.nu             # Main module entry point
│   ├── generator.nu       # Universal AWS generator
│   ├── services.nu        # All services consolidated
│   └── completions.nu     # All completions consolidated
├── schemas/               # AWS service schemas
├── nutest/               # Testing framework
├── s3.nu                 # Generated S3 service (108 operations)
├── ec2.nu                # Generated EC2 service (694 operations)
├── iam.nu                # Generated IAM service (164 operations)
├── completions_*.nu      # Generated external completions
└── run_tests.nu          # Unified test runner
```

## Key Features

- **One Module to Rule Them All**: `nuaws/` contains everything
- **Universal Generator**: Single generator creates all services + completions  
- **Type-Safe Operations**: 966+ AWS operations with proper types
- **External Completions**: Automatic completions for AWS resources
- **Clean Architecture**: Domain-based organization with minimal redundancy