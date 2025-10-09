# AWS CLI Nushell Core Generator System

export use generator.nu *
export use type_system_generator.nu *
export use completion_system_generator.nu *
export use aws_cli_command_extractor.nu *
export use extract_aws_commands.nu *

# Module exports
export def main [] {
    print "AWS CLI Nushell Core Generator System"
    print "====================================="
    print ""
    print "🚀 Core Generators:"
    print "  generator.nu                    - Universal AWS service generator"
    print "  type_system_generator.nu        - AWS to Nushell type mapping"
    print "  completion_system_generator.nu  - External completions generator"
    print ""
    print "📡 Schema Extraction:"
    print "  aws_cli_command_extractor.nu    - Extract commands from AWS CLI help"
    print "  extract_aws_commands.nu         - Alternative command extraction"
    print ""
    print "🔧 Build System:"
    print "  nu build.nu --service s3        - Generate specific service"
    print "  nu build.nu --all               - Generate all services"
    print "  nu build.nu pull-aws-schemas    - Extract schemas from AWS CLI"
    print ""
    print "🎯 Usage:"
    print "  use generator.nu generate-aws-service"
    print "  generate-aws-service s3 --with-completions --with-tests"
    print ""
    print "📚 For complete auto-generation capabilities, all files in this system"
    print "   work together to create comprehensive AWS CLI wrappers for Nushell."
}