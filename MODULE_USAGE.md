# NuAWS Module Usage Guide

The NuAWS plugin system has been restructured as a modular, importable system for easier management and integration with Nushell.

## Quick Start

### Basic Module Import

```nushell
# Import the simplified module interface
use nuaws_simple.nu

# Initialize the plugin system
nuaws_simple nuaws init

# Check system status
nuaws_simple nuaws status

# Get help
nuaws_simple nuaws help
```

### Alternative: Direct Component Access

```nushell
# Access core components directly
use plugin/core/service_registry.nu
service_registry list-registered-services

# Access testing framework
use nutest/plugin/mod.nu as testing
testing run-plugin-tests

# Access specific AWS services
use aws/stepfunctions.nu
stepfunctions list-state-machines
```

## Module Structure

```
aws-cli-nushell/
├── nuaws_simple.nu              # Main module interface (recommended)
├── nuaws/                       # Advanced module structure
│   ├── mod.nu                   # Full-featured module
│   ├── core/mod.nu              # Core components module
│   └── services/mod.nu          # AWS services module
├── plugin/core/                 # Core plugin infrastructure
│   ├── configuration.nu         # Configuration management
│   ├── service_registry.nu      # Service registration
│   ├── module_cache.nu          # Module caching
│   ├── completion_registry.nu   # Shell completions
│   └── ...
├── nutest/plugin/               # Testing framework
│   ├── mod.nu                   # Test runner
│   ├── plugin_test_utilities.nu # Test utilities
│   ├── mock_aws_environment.nu  # Mock environment
│   └── ...
└── aws/                         # AWS service implementations
    ├── stepfunctions.nu         # Step Functions service
    └── ...                      # Other services
```

## Usage Patterns

### 1. Simple Module Interface (Recommended)

The `nuaws_simple.nu` module provides a unified interface that's compatible with Nushell 0.107.0:

```nushell
# Import once
use nuaws_simple.nu

# All functionality available through exported functions
nuaws_simple nuaws version
nuaws_simple nuaws init
nuaws_simple nuaws status

# Core component access
nuaws_simple nuaws core config show
nuaws_simple nuaws core services list
nuaws_simple nuaws core cache status

# Testing framework
nuaws_simple nuaws test health
nuaws_simple nuaws test mock
nuaws_simple nuaws test run

# AWS services
nuaws_simple nuaws aws                          # List services
nuaws_simple nuaws aws stepfunctions help      # Service help
nuaws_simple nuaws aws stepfunctions list-state-machines
```

### 2. Direct Component Access

For advanced usage, access components directly:

```nushell
# Core infrastructure
use plugin/core/service_registry.nu
use plugin/core/module_cache.nu
use plugin/core/completion_registry.nu

# Register a service
service_registry register-service "s3" "aws/s3.nu"

# Check cache status
module_cache get-cache-stats

# Manage completions
completion_registry refresh-completions "s3"
```

### 3. Testing Framework Usage

```nushell
# Import testing framework
use nutest/plugin/mod.nu as testing

# Run comprehensive tests
testing run-plugin-tests

# Individual test components
use nutest/plugin/plugin_test_utilities.nu
use nutest/plugin/mock_aws_environment.nu

plugin_test_utilities validate-plugin-health
mock_aws_environment validate-mock-responses
```

## Configuration

### Environment Variables

The system uses these environment variables:

```nushell
# Set automatically by 'nuaws init'
$env.NUAWS_PLUGIN_DIR = "plugin"
$env.NUAWS_CACHE_DIR = "~/.nuaws/cache"
$env.NUAWS_CONFIG_DIR = "~/.nuaws"
$env.NUAWS_DEBUG = "false"
```

### Manual Configuration

```nushell
use nuaws_simple.nu

# Show current configuration
nuaws_simple nuaws core config show

# Set configuration values
nuaws_simple nuaws core config set "debug" "true"

# Get configuration values
nuaws_simple nuaws core config get "cache_dir"
```

## Adding to Nushell Config

Add to your `config.nu` for automatic loading:

```nushell
# ~/.config/nushell/config.nu

# Method 1: Use simplified interface
use /path/to/aws-cli-nushell/nuaws_simple.nu

# Initialize on startup (optional)
nuaws_simple nuaws init

# Create convenient aliases
alias aws = nuaws_simple nuaws aws
alias nuaws = nuaws_simple nuaws

# Method 2: Import specific components
use /path/to/aws-cli-nushell/plugin/core/service_registry.nu
use /path/to/aws-cli-nushell/aws/stepfunctions.nu
```

## Development Workflow

### Adding New AWS Services

1. Create service module in `aws/` directory:
```nushell
# aws/lambda.nu
export def "nuaws lambda list-functions" [] {
    aws lambda list-functions | from json
}

export def get-service-metadata [] {
    {
        name: "lambda",
        description: "AWS Lambda Functions",
        version: "1.0.0"
    }
}
```

2. Register the service:
```nushell
use nuaws_simple.nu
nuaws_simple nuaws core services register "lambda" "aws/lambda.nu"
```

3. Test the service:
```nushell
nuaws_simple nuaws aws lambda list-functions
```

### Testing Development

1. Create test files with plugin-specific annotations:
```nushell
# tests/test_lambda.nu

#[plugin-test]
def "test lambda service registration" [] {
    use nutest/plugin/plugin_test_utilities.nu
    plugin_test_utilities assert-service-registered "lambda"
}

#[mock-test]
def "test lambda mock responses" [] {
    use nutest/plugin/mock_aws_environment.nu
    let response = mock_aws_environment mock-aws-response "lambda" "list-functions"
    assert ($response != null)
}
```

2. Run tests:
```nushell
use nuaws_simple.nu
nuaws_simple nuaws test run "tests"
```

## Troubleshooting

### Common Issues

1. **Module import errors**: Ensure you're using absolute paths or proper relative paths from your working directory.

2. **Service not found**: Check if the service is registered:
```nushell
nuaws_simple nuaws aws  # List available services
```

3. **Cache issues**: Clear the cache if experiencing stale data:
```nushell
nuaws_simple nuaws core cache clear
```

4. **Permission errors**: Ensure directories are writable:
```nushell
nuaws_simple nuaws status  # Check directory permissions
```

### Debug Mode

Enable debug mode for verbose output:
```nushell
nuaws_simple nuaws core config set "debug" "true"
```

### Health Checks

Run system health checks:
```nushell
nuaws_simple nuaws status
nuaws_simple nuaws test health
```

## Migration from Standalone Scripts

If you were using individual scripts, migrate to the module system:

### Before (Standalone)
```nushell
nu nuaws.nu s3 list-buckets
nu aws_test_framework.nu --service stepfunctions
```

### After (Module)
```nushell
use nuaws_simple.nu
nuaws_simple nuaws aws s3 list-buckets
nuaws_simple nuaws test run --path="tests/aws"
```

## Performance Considerations

- The module system includes intelligent caching for better performance
- Services are loaded on-demand to reduce startup time
- Mock environment is available for testing without AWS API calls

## Security

- All AWS credentials are handled through standard AWS CLI configuration
- Mock mode prevents accidental API calls during testing
- Debug mode can be disabled in production environments

## Contributing

When contributing new modules:

1. Follow the established patterns in existing modules
2. Include comprehensive tests using the plugin testing framework
3. Document your module's exported functions
4. Ensure compatibility with Nushell 0.107.0+

## Support

For issues and questions:
- Check the troubleshooting section above
- Run health checks to identify problems
- Review the comprehensive test suite for examples
- Examine existing AWS service modules for patterns