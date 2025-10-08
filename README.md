# NuAWS - Native Nushell AWS CLI Plugin

A comprehensive AWS CLI implementation designed specifically for Nushell, providing type-safe AWS operations with native shell integration, intelligent caching, and comprehensive testing capabilities.

## 🚀 Quick Start

### Installation

```nushell
# Clone the repository
git clone https://github.com/lprior-repo/aws-cli-nushell.git
cd aws-cli-nushell

# Import the plugin
use nuaws_simple.nu

# Initialize the system
nuaws_simple nuaws init

# Check status
nuaws_simple nuaws status
```

### Basic Usage

```nushell
# Use AWS services with native Nushell syntax
nuaws_simple nuaws aws stepfunctions list-state-machines
nuaws_simple nuaws aws s3 list-buckets
nuaws_simple nuaws aws ec2 describe-instances

# Manage the plugin system
nuaws_simple nuaws core config show
nuaws_simple nuaws core services list
nuaws_simple nuaws test health
```

## ✨ Key Features

### 🎯 **Native Module System**
- **Single Import**: `use nuaws_simple.nu` provides access to entire system
- **Modular Architecture**: Core components can be imported individually
- **Nushell Integration**: Designed specifically for Nushell 0.107.0+

### 🔧 **Core Infrastructure**
- **Service Registry**: Dynamic AWS service discovery and registration
- **Intelligent Caching**: Performance optimization with LRU eviction
- **Configuration Management**: Centralized settings and preferences
- **Shell Completions**: AWS resource discovery for tab completion

### 🧪 **Comprehensive Testing**
- **Extended nutest Framework**: Plugin-specific testing capabilities
- **Mock Environment**: Safe testing without AWS API calls
- **Integration Tests**: End-to-end workflow validation
- **Health Monitoring**: System status and component validation

### ⚡ **AWS Service Generation**
- **Universal Generator**: Auto-generate wrappers for any AWS service
- **Type-Safe Functions**: Nushell-native parameter validation
- **Real Schema Processing**: Uses actual AWS CLI help output

## 📁 Project Structure

```
aws-cli-nushell/
├── nuaws_simple.nu              # 🎯 Main module interface
├── MODULE_USAGE.md              # 📖 Comprehensive usage guide
├── plugin/core/                 # Core infrastructure
│   ├── configuration.nu         # Configuration management
│   ├── service_registry.nu      # Service registration system
│   ├── module_cache.nu          # Intelligent caching
│   ├── completion_registry.nu   # Shell completion system
│   └── [5 more components]      # Additional core modules
├── nutest/plugin/               # Extended testing framework
│   ├── mod.nu                   # Main test runner
│   ├── plugin_test_utilities.nu # Plugin-specific test utilities
│   ├── mock_aws_environment.nu  # Mock AWS responses
│   └── [2 more modules]         # Additional test components
├── aws/                         # AWS service implementations
│   ├── stepfunctions.nu         # Complete Step Functions wrapper
│   └── [additional services]    # Generated service modules
└── tests/                       # Organized test suites
```

## 🎮 Usage Patterns

### 1. Simple Module Interface (Recommended)

```nushell
# Import once, access everything
use nuaws_simple.nu

# Plugin management
nuaws_simple nuaws init                    # Initialize system
nuaws_simple nuaws version                 # Show version info
nuaws_simple nuaws status                  # System health check

# Core system access
nuaws_simple nuaws core config show       # View configuration
nuaws_simple nuaws core services list     # List registered services
nuaws_simple nuaws core cache status      # Cache statistics

# AWS services
nuaws_simple nuaws aws                     # List available services
nuaws_simple nuaws aws stepfunctions help # Service help
nuaws_simple nuaws aws stepfunctions list-state-machines

# Testing framework
nuaws_simple nuaws test health             # Plugin health check
nuaws_simple nuaws test mock               # Validate mock environment
nuaws_simple nuaws test run                # Run test suite
```

### 2. Direct Component Access (Advanced)

```nushell
# Import specific components for advanced usage
use plugin/core/service_registry.nu
use plugin/core/module_cache.nu
use nutest/plugin/mod.nu as testing

# Direct component operations
service_registry register-service "lambda" "aws/lambda.nu"
module_cache get-cache-stats
testing run-plugin-tests --path="tests"
```

### 3. Service Development

```nushell
# Generate new AWS service wrapper
nu universal_aws_generator.nu lambda

# Register the new service
nuaws_simple nuaws core services register "lambda" "aws/lambda.nu"

# Test the service
nuaws_simple nuaws aws lambda list-functions
```

## 🛠️ Development Workflow

### Adding New AWS Services

1. **Generate the service**:
```nushell
nu universal_aws_generator.nu s3
```

2. **Register with the system**:
```nushell
use nuaws_simple.nu
nuaws_simple nuaws core services register "s3" "aws/s3.nu"
```

3. **Test the service**:
```nushell
nuaws_simple nuaws aws s3 list-buckets
```

### Running Tests

```nushell
# Health check
nuaws_simple nuaws test health

# Mock environment validation
nuaws_simple nuaws test mock

# Full test suite
nuaws_simple nuaws test run

# Specific test paths
nuaws_simple nuaws test run "tests/aws"
```

### Configuration Management

```nushell
# View current configuration
nuaws_simple nuaws core config show

# Update settings
nuaws_simple nuaws core config set "debug" "true"
nuaws_simple nuaws core config set "cache_size" "50"

# Reset to defaults
nuaws_simple nuaws core config reset
```

## 🧪 Testing & Mock Environment

### Mock Mode Setup

The system includes comprehensive mock capabilities for safe testing:

```nushell
# Automatic mock environment
nuaws_simple nuaws test mock

# Service-specific mocking (via environment variables)
$env.STEPFUNCTIONS_MOCK_MODE = "true"
$env.S3_MOCK_MODE = "true"
$env.IAM_MOCK_MODE = "true"
```

### Test Framework Features

- **Plugin-Specific Utilities**: Specialized assertions and helpers
- **Mock AWS Environment**: 12+ service mock responses
- **Integration Testing**: End-to-end workflow validation
- **Performance Testing**: Benchmarking and optimization
- **Health Monitoring**: Component status validation

## 🔧 Configuration

### Environment Variables

```nushell
# Set automatically by 'nuaws init'
$env.NUAWS_PLUGIN_DIR = "plugin"
$env.NUAWS_CACHE_DIR = "~/.nuaws/cache"
$env.NUAWS_CONFIG_DIR = "~/.nuaws"
$env.NUAWS_DEBUG = "false"
```

### Adding to Nushell Config

Add to your `~/.config/nushell/config.nu`:

```nushell
# Import NuAWS plugin
use /path/to/aws-cli-nushell/nuaws_simple.nu

# Initialize on startup (optional)
nuaws_simple nuaws init

# Create convenient aliases
alias aws = nuaws_simple nuaws aws
alias nuaws = nuaws_simple nuaws
```

## 📊 System Status

### Current Capabilities

- ✅ **Core Plugin Infrastructure**: Complete with 9 components
- ✅ **Testing Framework**: Extended nutest with 5 plugin modules
- ✅ **Service Registry**: Dynamic registration and management
- ✅ **Caching System**: Intelligent performance optimization
- ✅ **Completion Engine**: Shell completion with AWS resource discovery
- ✅ **Mock Environment**: Safe testing for 12+ AWS services
- ✅ **Step Functions**: Complete implementation (37 commands)

### Performance

- **Startup Time**: < 100ms with caching
- **Service Loading**: On-demand with intelligent caching
- **Test Execution**: Parallel execution with mock environment
- **Memory Usage**: Optimized with LRU cache management

## 🚀 Universal Service Generator

Generate complete AWS service wrappers for any service:

```nushell
# Generate popular services
nu universal_aws_generator.nu s3         # S3 storage operations
nu universal_aws_generator.nu lambda     # Lambda function management
nu universal_aws_generator.nu dynamodb   # DynamoDB table operations
nu universal_aws_generator.nu ec2        # EC2 instance management
nu universal_aws_generator.nu iam        # Identity and access management

# Generated services include:
# - Type-safe parameter validation
# - Comprehensive error handling
# - Mock response capabilities
# - Native Nushell return types
```

## 📖 Documentation

- **[MODULE_USAGE.md](MODULE_USAGE.md)**: Comprehensive usage guide
- **[OPENAPI_EXTRACTOR_EXAMPLES.md](OPENAPI_EXTRACTOR_EXAMPLES.md)**: OpenAPI extraction examples
- **Plugin Documentation**: In-code documentation for all components

## 🔄 Migration from Previous Versions

### From Standalone Scripts

**Before**:
```nushell
nu nuaws.nu stepfunctions list-state-machines
nu aws_test_framework.nu --service stepfunctions
```

**After**:
```nushell
use nuaws_simple.nu
nuaws_simple nuaws aws stepfunctions list-state-machines
nuaws_simple nuaws test run
```

### Benefits of Modular System

1. **Single Import**: No need to manage multiple script files
2. **Consistent Interface**: Unified command structure
3. **Better Organization**: Clear separation of concerns
4. **Enhanced Testing**: Comprehensive testing framework
5. **Performance**: Intelligent caching and optimization

## 🤝 Contributing

### Development Setup

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-service`
3. Follow TDD practices with the testing framework
4. Ensure all tests pass: `nuaws_simple nuaws test run`
5. Submit pull request

### Code Standards

- **Pure Functional Programming**: Use immutable patterns
- **Test-Driven Development**: Write tests first
- **Documentation**: Include comprehensive examples
- **Compatibility**: Ensure Nushell 0.107.0+ compatibility

## 📋 Troubleshooting

### Common Issues

1. **Import Errors**: Ensure using absolute paths
2. **Service Not Found**: Check registration with `nuaws_simple nuaws aws`
3. **Cache Issues**: Clear with `nuaws_simple nuaws core cache clear`
4. **Test Failures**: Run health check `nuaws_simple nuaws test health`

### Debug Mode

```nushell
nuaws_simple nuaws core config set "debug" "true"
$env.NU_BACKTRACE = 1
```

## 📈 Roadmap

- [ ] **Phase 2**: Enhanced completion engine with live AWS resource discovery
- [ ] **Phase 3**: Configuration profiles and multi-account support
- [ ] **Phase 4**: Advanced pipeline integration and streaming
- [ ] **Phase 5**: Visual workflow builder and monitoring dashboard

## 📄 License

MIT License - see LICENSE file for details

## 🎯 Support

- **Issues**: [GitHub Issues](https://github.com/lprior-repo/aws-cli-nushell/issues)
- **Documentation**: [MODULE_USAGE.md](MODULE_USAGE.md)
- **Examples**: Check `test_final_module_demo.nu` for comprehensive examples

---

**🎉 Ready to revolutionize your AWS workflow with native Nushell integration!**

```nushell
use nuaws_simple.nu
nuaws_simple nuaws init
nuaws_simple nuaws help
```