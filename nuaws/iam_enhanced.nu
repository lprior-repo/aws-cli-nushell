# Enhanced IAM Tools for NuAWS
# Comprehensive IAM analysis, validation, and security features with functional programming patterns

use ../errors.nu [make-aws-error, map-aws-error-code]
use ../functional.nu [map-aws-resources, filter-aws-resources, compose-aws-operations, pure-aws-function]

# ============================================================================
# Core IAM Enhanced Module Configuration
# ============================================================================

# Mock mode configuration for testing
const IAM_MOCK_MODE = ($env.IAM_MOCK_MODE? | default "false" | into bool)

# IAM policy analysis cache configuration
const POLICY_CACHE_TTL = 300  # 5 minutes
const PRIVILEGE_ESCALATION_PATTERNS = [
    "iam:*",
    "iam:CreateRole",
    "iam:AttachUserPolicy", 
    "iam:AttachRolePolicy",
    "iam:PutUserPolicy",
    "iam:PutRolePolicy",
    "sts:AssumeRole",
    "*"
]

# AWS best practices configuration
const AWS_BEST_PRACTICES = {
    max_access_key_age_days: 90,
    max_unused_key_age_days: 30,
    min_password_length: 14,
    require_mfa: true,
    max_policy_size: 6144,
    max_policies_per_user: 10,
    max_policies_per_role: 10
}

# ============================================================================
# Type Definitions and Validation
# ============================================================================

# Policy analysis result structure
export def policy-analysis-result []: nothing -> record {
    {
        policy_arn: "",
        policy_name: "",
        analysis_type: "",
        findings: [],
        severity: "info",
        compliant: true,
        recommendations: [],
        analyzed_at: (date now),
        mock: $IAM_MOCK_MODE
    }
}

# Privilege escalation finding structure
export def privilege-escalation-finding []: nothing -> record {
    {
        finding_id: "",
        finding_type: "privilege_escalation",
        severity: "high",
        description: "",
        affected_principal: "",
        escalation_path: [],
        mitigation_steps: [],
        detected_at: (date now)
    }
}

# Compliance check result structure  
export def compliance-check-result []: nothing -> record {
    {
        check_name: "",
        check_category: "",
        status: "pass",
        severity: "medium", 
        description: "",
        recommendations: [],
        evidence: {},
        checked_at: (date now)
    }
}

# ============================================================================
# Policy Analysis and Validation Functions
# ============================================================================

# Analyze IAM policy for security issues and best practices
export def "iam analyze-policy" [
    policy_input: any,              # Policy ARN, document, or piped policy data
    --type(-t): string = "auto",    # Analysis type: security, compliance, permissions, auto
    --detailed(-d),                 # Include detailed analysis
    --format(-f): string = "table", # Output format: table, json, detailed
    --cache(-c),                   # Use cached results if available
    --span: any                    # Span information for error handling
]: any -> record {
    
    try {
        let policy_data = get-policy-data $policy_input $span
        let analysis_type = if $type == "auto" { detect-analysis-type $policy_data } else { $type }
        
        # Check cache if enabled
        if $cache {
            let cache_key = generate-cache-key $policy_data $analysis_type
            let cached_result = get-cached-analysis $cache_key
            if ($cached_result | is-not-empty) {
                return $cached_result
            }
        }
        
        let base_analysis = policy-analysis-result | upsert {
            policy_arn: ($policy_data.arn? | default ""),
            policy_name: ($policy_data.policy_name? | default "Unknown"),
            analysis_type: $analysis_type
        }
        
        let analysis_result = match $analysis_type {
            "security" => (analyze-policy-security $policy_data $detailed),
            "compliance" => (analyze-policy-compliance $policy_data $detailed),
            "permissions" => (analyze-policy-permissions $policy_data $detailed),
            "comprehensive" => (analyze-policy-comprehensive $policy_data $detailed),
            _ => (error make { msg: $"Unknown analysis type: ($analysis_type)" })
        }
        
        let final_result = $base_analysis | merge $analysis_result
        
        # Cache result if caching enabled
        if $cache {
            cache-analysis-result $cache_key $final_result
        }
        
        format-analysis-output $final_result $format
        
    } catch { |err|
        make-aws-error "VALIDATION" "PolicyAnalysisError" 
            $"Failed to analyze policy: ($err.msg)" 
            "analyze-policy" "iam" $span
            --context { policy_input: $policy_input, analysis_type: $type }
    }
}

# Get policy data from various input types
def get-policy-data [policy_input: any, span: any]: nothing -> record {
    if $IAM_MOCK_MODE {
        return (generate-mock-policy-data $policy_input)
    }
    
    match ($policy_input | describe) {
        "string" => {
            if ($policy_input | str starts-with "arn:aws:iam") {
                # Policy ARN - fetch from AWS
                fetch-policy-by-arn $policy_input
            } else {
                # Assume policy name
                fetch-policy-by-name $policy_input
            }
        },
        "record" => {
            # Direct policy document
            validate-policy-document $policy_input
        },
        _ => {
            error make { 
                msg: "Invalid policy input type. Expected ARN, name, or policy document",
                label: { text: "Invalid input type", span: $span }
            }
        }
    }
}

# Generate mock policy data for testing
def generate-mock-policy-data [policy_input: any]: nothing -> record {
    {
        arn: "arn:aws:iam::123456789012:policy/mock-policy",
        policy_name: "MockTestPolicy",
        policy_document: {
            Version: "2012-10-17",
            Statement: [
                {
                    Effect: "Allow",
                    Action: ["s3:GetObject", "s3:PutObject"],
                    Resource: "arn:aws:s3:::example-bucket/*"
                },
                {
                    Effect: "Allow", 
                    Action: "iam:ListUsers",
                    Resource: "*"
                }
            ]
        },
        mock: true,
        created_date: (date now),
        update_date: (date now)
    }
}

# Detect optimal analysis type based on policy content
def detect-analysis-type [policy_data: record]: nothing -> string {
    let statements = $policy_data.policy_document.Statement
    let actions = $statements | each { |stmt| $stmt.Action? | default [] } | flatten
    
    if ($actions | any { |action| $action in $PRIVILEGE_ESCALATION_PATTERNS }) {
        "security"
    } else if ($actions | length) > 20 {
        "comprehensive"
    } else {
        "permissions"
    }
}

# Analyze policy for security vulnerabilities
def analyze-policy-security [policy_data: record, detailed: bool]: nothing -> record {
    let statements = $policy_data.policy_document.Statement
    let findings = []
    
    # Check for privilege escalation patterns
    let escalation_findings = check-privilege-escalation $statements
    let findings = ($findings | append $escalation_findings)
    
    # Check for overly permissive policies
    let permissive_findings = check-overly-permissive $statements
    let findings = ($findings | append $permissive_findings)
    
    # Check for resource constraints
    let resource_findings = check-resource-constraints $statements
    let findings = ($findings | append $resource_findings)
    
    # Check for condition constraints
    let condition_findings = check-condition-constraints $statements
    let findings = ($findings | append $condition_findings)
    
    let severity = calculate-overall-severity $findings
    let compliant = ($findings | where severity in ["high", "critical"] | is-empty)
    
    {
        findings: $findings,
        severity: $severity,
        compliant: $compliant,
        recommendations: (generate-security-recommendations $findings),
        security_score: (calculate-security-score $findings),
        risk_level: (calculate-risk-level $findings)
    }
}

# Check for privilege escalation patterns
def check-privilege-escalation [statements: list]: nothing -> list {
    $statements | enumerate | each { |stmt_enum|
        let stmt = $stmt_enum.item
        let stmt_index = $stmt_enum.index
        
        if $stmt.Effect == "Allow" {
            let actions = if ($stmt.Action | describe) == "list" { $stmt.Action } else { [$stmt.Action] }
            
            $actions | each { |action|
                if $action in $PRIVILEGE_ESCALATION_PATTERNS {
                    privilege-escalation-finding | upsert {
                        finding_id: $"escalation-($stmt_index)-((random chars --length 4))",
                        description: $"Potential privilege escalation via action: ($action)",
                        affected_principal: "*",
                        escalation_path: [$action],
                        mitigation_steps: [
                            "Restrict action to specific resources",
                            "Add condition constraints",
                            "Use least privilege principle"
                        ]
                    }
                }
            }
        }
    } | flatten | compact
}

# Check for overly permissive policies
def check-overly-permissive [statements: list]: nothing -> list {
    $statements | enumerate | each { |stmt_enum|
        let stmt = $stmt_enum.item
        let stmt_index = $stmt_enum.index
        
        let findings = []
        
        # Check for wildcard actions
        if ($stmt.Action? | default [] | any { |action| $action == "*" }) {
            let findings = ($findings | append {
                finding_id: $"wildcard-action-($stmt_index)",
                finding_type: "overly_permissive",
                severity: "high",
                description: "Statement uses wildcard (*) action",
                recommendations: ["Replace wildcard with specific actions"]
            })
        }
        
        # Check for wildcard resources
        if ($stmt.Resource? | default [] | any { |resource| $resource == "*" }) {
            let findings = ($findings | append {
                finding_id: $"wildcard-resource-($stmt_index)",
                finding_type: "overly_permissive", 
                severity: "medium",
                description: "Statement uses wildcard (*) resource",
                recommendations: ["Specify exact resource ARNs"]
            })
        }
        
        $findings
    } | flatten | compact
}

# Check for proper resource constraints
def check-resource-constraints [statements: list]: nothing -> list {
    $statements | enumerate | each { |stmt_enum|
        let stmt = $stmt_enum.item
        let stmt_index = $stmt_enum.index
        
        if ($stmt.Resource? | is-empty) and $stmt.Effect == "Allow" {
            {
                finding_id: $"missing-resource-($stmt_index)",
                finding_type: "missing_constraint",
                severity: "medium",
                description: "Statement missing resource constraint",
                recommendations: ["Add specific resource ARNs or patterns"]
            }
        }
    } | compact
}

# Check for condition constraints
def check-condition-constraints [statements: list]: nothing -> list {
    $statements | enumerate | each { |stmt_enum|
        let stmt = $stmt_enum.item
        let stmt_index = $stmt_enum.index
        
        if ($stmt.Condition? | is-empty) and $stmt.Effect == "Allow" {
            let actions = if ($stmt.Action | describe) == "list" { $stmt.Action } else { [$stmt.Action] }
            let sensitive_actions = $actions | where $it in ["iam:*", "sts:AssumeRole", "s3:*"]
            
            if ($sensitive_actions | is-not-empty) {
                {
                    finding_id: $"missing-condition-($stmt_index)",
                    finding_type: "missing_constraint",
                    severity: "medium", 
                    description: $"Sensitive actions without conditions: ($sensitive_actions | str join ', ')",
                    recommendations: [
                        "Add IP address restrictions",
                        "Add MFA requirements",
                        "Add time-based constraints"
                    ]
                }
            }
        }
    } | compact
}

# ============================================================================
# Cross-Account Role Assumption Helpers
# ============================================================================

# Automate cross-account role assumption with validation
export def "iam assume-role-enhanced" [
    role_arn: string,               # Target role ARN
    session_name?: string,          # Session name (auto-generated if not provided)
    --duration(-d): int = 3600,     # Session duration in seconds
    --external-id(-e): string,      # External ID for additional security
    --mfa-serial(-m): string,       # MFA device serial number
    --mfa-token(-t): string,        # MFA token code
    --policy(-p): string,           # Session policy to apply
    --validate(-v),                 # Validate role assumption before proceeding
    --profile(-P): string,          # AWS profile to use
    --span: any                     # Span information
]: nothing -> record {
    
    try {
        # Generate session name if not provided
        let effective_session_name = $session_name | default $"nuaws-session-((date now | format date '%Y%m%d%H%M%S'))"
        
        # Validate role ARN format
        validate-role-arn $role_arn $span
        
        # Pre-validation if requested
        if $validate {
            let validation_result = validate-role-assumption $role_arn $external_id
            if not $validation_result.can_assume {
                error make {
                    msg: $"Cannot assume role: ($validation_result.reason)",
                    label: { text: "Role assumption validation failed", span: $span }
                }
            }
        }
        
        if $IAM_MOCK_MODE {
            return (generate-mock-assume-role-result $role_arn $effective_session_name)
        }
        
        # Build AWS CLI command
        let base_cmd = ["aws", "sts", "assume-role"]
        let role_args = ["--role-arn", $role_arn, "--role-session-name", $effective_session_name]
        let duration_args = ["--duration-seconds", ($duration | into string)]
        
        let external_id_args = if ($external_id | is-not-empty) { ["--external-id", $external_id] } else { [] }
        let mfa_args = if ($mfa_serial | is-not-empty) and ($mfa_token | is-not-empty) { 
            ["--serial-number", $mfa_serial, "--token-code", $mfa_token] 
        } else { [] }
        let policy_args = if ($policy | is-not-empty) { ["--policy", $policy] } else { [] }
        let profile_args = if ($profile | is-not-empty) { ["--profile", $profile] } else { [] }
        
        let full_cmd = $base_cmd | append $role_args | append $duration_args | append $external_id_args | append $mfa_args | append $policy_args | append $profile_args
        
        # Execute role assumption
        let assume_result = run-external $full_cmd | from json
        
        # Parse and enhance result
        let credentials = $assume_result.Credentials
        let assumed_role = $assume_result.AssumedRoleUser
        
        {
            success: true,
            access_key_id: $credentials.AccessKeyId,
            secret_access_key: $credentials.SecretAccessKey,
            session_token: $credentials.SessionToken,
            expiration: $credentials.Expiration,
            assumed_role_arn: $assumed_role.Arn,
            assumed_role_id: $assumed_role.AssumedRoleId,
            session_name: $effective_session_name,
            duration_seconds: $duration,
            external_id_used: ($external_id | is-not-empty),
            mfa_used: ($mfa_serial | is-not-empty),
            policy_applied: ($policy | is-not-empty),
            assumed_at: (date now),
            expires_at: $credentials.Expiration,
            mock: false
        }
        
    } catch { |err|
        make-aws-error "AUTHORIZATION" "AssumeRoleError"
            $"Failed to assume role: ($err.msg)"
            "assume-role-enhanced" "iam" $span
            --context { role_arn: $role_arn, session_name: $effective_session_name }
    }
}

# Generate mock assume role result for testing
def generate-mock-assume-role-result [role_arn: string, session_name: string]: nothing -> record {
    let expiration = (date now | date format "%Y-%m-%dT%H:%M:%S.000Z" | into datetime | $in + 1hr)
    
    {
        success: true,
        access_key_id: "ASIAMOCKKEY123456789",
        secret_access_key: "MockSecretKey+abcdefghijklmnopqrstuvwxyz",
        session_token: "MockSessionToken" + (random chars --length 100),
        expiration: $expiration,
        assumed_role_arn: ($role_arn + "/" + $session_name),
        assumed_role_id: ("AROAMOCKROLEID123:" + $session_name),
        session_name: $session_name,
        duration_seconds: 3600,
        external_id_used: false,
        mfa_used: false,
        policy_applied: false,
        assumed_at: (date now),
        expires_at: $expiration,
        mock: true
    }
}

# Validate role ARN format
def validate-role-arn [role_arn: string, span: any]: nothing -> nothing {
    if not ($role_arn | str starts-with "arn:aws:iam::") {
        error make {
            msg: "Invalid role ARN format",
            label: { text: "Role ARN must start with 'arn:aws:iam::'", span: $span }
        }
    }
    
    if not ($role_arn | str contains ":role/") {
        error make {
            msg: "Invalid role ARN format", 
            label: { text: "Role ARN must contain ':role/'", span: $span }
        }
    }
}

# Validate if role can be assumed
def validate-role-assumption [role_arn: string, external_id?: string]: nothing -> record {
    if $IAM_MOCK_MODE {
        return { can_assume: true, reason: "Mock mode validation" }
    }
    
    try {
        # Check if role exists and trust policy allows assumption
        let role_name = ($role_arn | split row "/" | last)
        let get_role_cmd = ["aws", "iam", "get-role", "--role-name", $role_name]
        let role_info = run-external $get_role_cmd | from json
        
        # Parse trust policy
        let trust_policy = ($role_info.Role.AssumeRolePolicyDocument | url decode | from json)
        
        # Basic validation - check if trust policy exists
        if ($trust_policy.Statement | is-empty) {
            return { can_assume: false, reason: "No trust policy statements found" }
        }
        
        { can_assume: true, reason: "Role validation successful" }
        
    } catch { |err|
        { can_assume: false, reason: $"Role validation failed: ($err.msg)" }
    }
}

# ============================================================================
# Privilege Escalation Detection and Prevention
# ============================================================================

# Detect privilege escalation opportunities in IAM configuration
export def "iam detect-privilege-escalation" [
    --scope(-s): string = "account", # Scope: account, user, role, group
    --target(-t): string,           # Specific target to analyze
    --deep(-d),                     # Enable deep analysis
    --format(-f): string = "table", # Output format
    --span: any                     # Span information
]: nothing -> record {
    
    try {
        let escalation_paths = match $scope {
            "account" => (detect-account-escalation $deep),
            "user" => (detect-user-escalation $target $deep),
            "role" => (detect-role-escalation $target $deep),
            "group" => (detect-group-escalation $target $deep),
            _ => (error make { msg: $"Unknown scope: ($scope)" })
        }
        
        let severity = calculate-escalation-severity $escalation_paths
        let risk_score = calculate-escalation-risk-score $escalation_paths
        
        let result = {
            scope: $scope,
            target: ($target | default "all"),
            escalation_paths: $escalation_paths,
            total_paths: ($escalation_paths | length),
            severity: $severity,
            risk_score: $risk_score,
            high_risk_paths: ($escalation_paths | where severity in ["high", "critical"] | length),
            prevention_steps: (generate-prevention-steps $escalation_paths),
            analyzed_at: (date now),
            mock: $IAM_MOCK_MODE
        }
        
        format-escalation-output $result $format
        
    } catch { |err|
        make-aws-error "VALIDATION" "PrivilegeEscalationError"
            $"Failed to detect privilege escalation: ($err.msg)"
            "detect-privilege-escalation" "iam" $span
            --context { scope: $scope, target: $target }
    }
}

# Detect account-wide escalation opportunities
def detect-account-escalation [deep: bool]: nothing -> list {
    if $IAM_MOCK_MODE {
        return (generate-mock-escalation-paths "account")
    }
    
    let escalation_paths = []
    
    # Check for overprivileged service roles
    let service_role_paths = detect-service-role-escalation $deep
    let escalation_paths = ($escalation_paths | append $service_role_paths)
    
    # Check for cross-account trust relationships
    let cross_account_paths = detect-cross-account-escalation $deep
    let escalation_paths = ($escalation_paths | append $cross_account_paths)
    
    # Check for assume role chains
    let role_chain_paths = detect-role-chain-escalation $deep
    let escalation_paths = ($escalation_paths | append $role_chain_paths)
    
    $escalation_paths | flatten | compact
}

# Generate mock escalation paths for testing
def generate-mock-escalation-paths [scope: string]: nothing -> list {
    [
        {
            path_id: "mock-path-001",
            escalation_type: "service_role",
            source_principal: "arn:aws:iam::123456789012:role/lambda-execution-role",
            target_privilege: "iam:CreateRole",
            severity: "high",
            description: "Lambda execution role can create new IAM roles",
            exploitation_steps: [
                "Invoke Lambda function",
                "Use execution role to create privileged role",
                "Assume newly created role"
            ],
            prevention_steps: [
                "Remove iam:CreateRole from execution role policy",
                "Use least privilege principle",
                "Implement condition constraints"
            ],
            detected_at: (date now)
        },
        {
            path_id: "mock-path-002", 
            escalation_type: "cross_account",
            source_principal: "arn:aws:iam::987654321098:root",
            target_privilege: "sts:AssumeRole",
            severity: "medium",
            description: "External account can assume sensitive roles",
            exploitation_steps: [
                "Authenticate to external account",
                "Assume cross-account role",
                "Access sensitive resources"
            ],
            prevention_steps: [
                "Add external ID requirement",
                "Implement MFA requirement",
                "Restrict assuming principal"
            ],
            detected_at: (date now)
        }
    ]
}

# ============================================================================
# Compliance Checking Against AWS Best Practices
# ============================================================================

# Check IAM configuration compliance against AWS best practices
export def "iam check-compliance" [
    --checks(-c): list<string> = [], # Specific checks to run (empty = all)
    --severity(-s): string = "all",  # Filter by severity: low, medium, high, critical, all
    --format(-f): string = "table",  # Output format
    --export(-e): string,            # Export results to file
    --span: any                      # Span information
]: nothing -> record {
    
    try {
        let available_checks = get-available-compliance-checks
        let checks_to_run = if ($checks | is-empty) { 
            $available_checks | get name 
        } else { 
            $checks 
        }
        
        # Validate requested checks
        let invalid_checks = $checks_to_run | where $it not-in ($available_checks | get name)
        if ($invalid_checks | is-not-empty) {
            error make { 
                msg: $"Invalid compliance checks: ($invalid_checks | str join ', ')",
                label: { text: "Unknown compliance checks", span: $span }
            }
        }
        
        # Run compliance checks
        let check_results = $checks_to_run | each { |check_name|
            run-compliance-check $check_name
        }
        
        # Filter by severity if specified
        let filtered_results = if $severity != "all" {
            $check_results | where severity == $severity
        } else {
            $check_results
        }
        
        # Calculate overall compliance score
        let compliance_score = calculate-compliance-score $check_results
        let compliance_grade = calculate-compliance-grade $compliance_score
        
        let result = {
            total_checks: ($check_results | length),
            passed_checks: ($check_results | where status == "pass" | length),
            failed_checks: ($check_results | where status == "fail" | length),
            warning_checks: ($check_results | where status == "warning" | length),
            compliance_score: $compliance_score,
            compliance_grade: $compliance_grade,
            check_results: $filtered_results,
            recommendations: (generate-compliance-recommendations $check_results),
            checked_at: (date now),
            mock: $IAM_MOCK_MODE
        }
        
        # Export if requested
        if ($export | is-not-empty) {
            $result | to json | save $export
        }
        
        format-compliance-output $result $format
        
    } catch { |err|
        make-aws-error "VALIDATION" "ComplianceCheckError"
            $"Failed to check compliance: ($err.msg)"
            "check-compliance" "iam" $span
            --context { checks: $checks, severity: $severity }
    }
}

# Get available compliance checks
def get-available-compliance-checks []: nothing -> list {
    [
        {
            name: "root_access_key",
            description: "Check if root account has access keys",
            category: "security",
            severity: "critical"
        },
        {
            name: "mfa_enabled",
            description: "Check if MFA is enabled for users",
            category: "security", 
            severity: "high"
        },
        {
            name: "unused_access_keys",
            description: "Check for unused access keys",
            category: "security",
            severity: "medium"
        },
        {
            name: "old_access_keys",
            description: "Check for old access keys",
            category: "security",
            severity: "medium"
        },
        {
            name: "password_policy",
            description: "Check password policy configuration",
            category: "security",
            severity: "high"
        },
        {
            name: "inline_policies",
            description: "Check for inline policies usage",
            category: "best_practice",
            severity: "low"
        },
        {
            name: "policy_versions",
            description: "Check for excessive policy versions",
            category: "maintenance",
            severity: "low"
        },
        {
            name: "service_linked_roles",
            description: "Check service-linked role usage",
            category: "best_practice", 
            severity: "low"
        }
    ]
}

# Run individual compliance check
def run-compliance-check [check_name: string]: nothing -> record {
    if $IAM_MOCK_MODE {
        return (generate-mock-compliance-result $check_name)
    }
    
    match $check_name {
        "root_access_key" => (check-root-access-key),
        "mfa_enabled" => (check-mfa-enabled),
        "unused_access_keys" => (check-unused-access-keys),
        "old_access_keys" => (check-old-access-keys),
        "password_policy" => (check-password-policy),
        "inline_policies" => (check-inline-policies),
        "policy_versions" => (check-policy-versions),
        "service_linked_roles" => (check-service-linked-roles),
        _ => (error make { msg: $"Unknown compliance check: ($check_name)" })
    }
}

# Generate mock compliance result for testing
def generate-mock-compliance-result [check_name: string]: nothing -> record {
    let base_result = compliance-check-result | upsert {
        check_name: $check_name,
        checked_at: (date now),
        mock: true
    }
    
    match $check_name {
        "root_access_key" => ($base_result | upsert {
            check_category: "security",
            status: "pass",
            severity: "critical",
            description: "Root account access keys not detected",
            recommendations: ["Continue monitoring root account usage"]
        }),
        "mfa_enabled" => ($base_result | upsert {
            check_category: "security",
            status: "warning", 
            severity: "high",
            description: "Some users do not have MFA enabled",
            recommendations: ["Enable MFA for all users", "Enforce MFA policy"]
        }),
        _ => ($base_result | upsert {
            check_category: "unknown",
            status: "pass",
            description: $"Mock result for ($check_name)"
        })
    }
}

# ============================================================================
# Interactive Policy Troubleshooting and Repair
# ============================================================================

# Interactive policy troubleshooting with guided repair
export def "iam troubleshoot-policy" [
    policy_input: any,              # Policy ARN, name, or document
    --issue(-i): string,            # Specific issue to troubleshoot
    --interactive,                  # Enable interactive mode
    --auto-fix(-a),                 # Attempt automatic fixes
    --dry-run(-d),                  # Show what would be fixed without applying
    --span: any                     # Span information
]: any -> record {
    
    try {
        let policy_data = get-policy-data $policy_input $span
        let detected_issues = detect-policy-issues $policy_data $issue
        
        if ($detected_issues | is-empty) {
            return {
                policy_name: ($policy_data.policy_name? | default "Unknown"),
                issues_found: 0,
                status: "healthy",
                message: "No issues detected in policy",
                troubleshoot_at: (date now),
                mock: $IAM_MOCK_MODE
            }
        }
        
        if $interactive {
            interactive-policy-troubleshooting $policy_data $detected_issues $auto_fix $dry_run
        } else {
            automatic-policy-troubleshooting $policy_data $detected_issues $auto_fix $dry_run
        }
        
    } catch { |err|
        make-aws-error "VALIDATION" "PolicyTroubleshootError"
            $"Failed to troubleshoot policy: ($err.msg)"
            "troubleshoot-policy" "iam" $span
            --context { policy_input: $policy_input, issue: $issue }
    }
}

# Detect policy issues
def detect-policy-issues [policy_data: record, specific_issue?: string]: nothing -> list {
    let all_issues = []
    
    # Security issues
    let security_issues = detect-security-issues $policy_data
    let all_issues = ($all_issues | append $security_issues)
    
    # Syntax issues
    let syntax_issues = detect-syntax-issues $policy_data
    let all_issues = ($all_issues | append $syntax_issues)
    
    # Best practice issues
    let best_practice_issues = detect-best-practice-issues $policy_data
    let all_issues = ($all_issues | append $best_practice_issues)
    
    # Filter by specific issue if provided
    if ($specific_issue | is-not-empty) {
        $all_issues | where issue_type == $specific_issue
    } else {
        $all_issues | flatten | compact
    }
}

# Interactive troubleshooting workflow
def interactive-policy-troubleshooting [
    policy_data: record,
    issues: list,
    auto_fix: bool,
    dry_run: bool
]: nothing -> record {
    print $"🔧 Policy Troubleshooting Assistant"
    print $"Policy: ($policy_data.policy_name? | default 'Unknown')"
    print $"Issues found: ($issues | length)"
    print ""
    
    let fixed_issues = []
    let skipped_issues = []
    
    for issue in ($issues | enumerate) {
        print $"Issue ($issue.index + 1)/($issues | length): ($issue.item.description)"
        print $"  Severity: ($issue.item.severity)"
        print $"  Category: ($issue.item.category)"
        
        if $auto_fix and ($issue.item.auto_fixable? | default false) {
            let fix_choice = input "Auto-fix available. Apply fix? (y/n/skip): "
            match $fix_choice {
                "y" | "yes" => {
                    let fix_result = apply-policy-fix $policy_data $issue.item $dry_run
                    let fixed_issues = ($fixed_issues | append $fix_result)
                    print $"  ✅ Fix applied: ($fix_result.description)"
                },
                "skip" => {
                    let skipped_issues = ($skipped_issues | append $issue.item)
                    print "  ⏭️  Issue skipped"
                },
                _ => {
                    print "  ❌ Fix declined"
                }
            }
        } else {
            print $"  Recommendations:"
            $issue.item.recommendations | each { |rec| print $"    - ($rec)" }
            
            let manual_choice = input "Mark as resolved? (y/n): "
            if $manual_choice in ["y", "yes"] {
                let fixed_issues = ($fixed_issues | append {
                    issue_id: $issue.item.issue_id,
                    description: $issue.item.description,
                    fix_method: "manual",
                    resolved_at: (date now)
                })
            }
        }
        print ""
    }
    
    {
        policy_name: ($policy_data.policy_name? | default "Unknown"),
        issues_found: ($issues | length),
        issues_fixed: ($fixed_issues | length),
        issues_skipped: ($skipped_issues | length),
        fixed_issues: $fixed_issues,
        skipped_issues: $skipped_issues,
        troubleshoot_method: "interactive",
        dry_run: $dry_run,
        completed_at: (date now),
        mock: $IAM_MOCK_MODE
    }
}

# ============================================================================
# Streaming Operations for Policy Analysis
# ============================================================================

# Stream policy analysis for large policy sets
export def "iam stream-policy-analysis" [
    policy_source: string,          # Source: account, user, role, group, file
    --filter(-f): string,           # Filter pattern for policies
    --batch-size(-b): int = 10,     # Batch size for processing
    --parallel(-p): int = 4,        # Parallel processing threads
    --output(-o): string,           # Output file for results
    --span: any                     # Span information
]: nothing -> any {
    
    try {
        # Create policy stream generator
        let policy_stream = create-policy-stream $policy_source $filter
        
        # Process stream in batches with progress reporting
        $policy_stream 
        | group $batch_size 
        | enumerate 
        | each { |batch|
            print $"Processing batch ($batch.index + 1)..."
            
            $batch.item 
            | par-each --max-threads $parallel { |policy|
                try {
                    iam analyze-policy $policy --type security --cache
                } catch { |err|
                    {
                        policy_arn: ($policy.arn? | default "unknown"),
                        error: true,
                        error_message: $err.msg,
                        analyzed_at: (date now)
                    }
                }
            }
        }
        | flatten
        | if ($output | is-not-empty) { 
            tee { |results| $results | to json | save $output }
        } else { 
            $in 
        }
        
    } catch { |err|
        make-aws-error "RESOURCE" "StreamAnalysisError"
            $"Failed to stream policy analysis: ($err.msg)"
            "stream-policy-analysis" "iam" $span
            --context { policy_source: $policy_source, filter: $filter }
    }
}

# Create policy stream generator
def create-policy-stream [source: string, filter?: string]: nothing -> any {
    if $IAM_MOCK_MODE {
        return (generate-mock-policy-stream $source)
    }
    
    match $source {
        "account" => (stream-account-policies $filter),
        "users" => (stream-user-policies $filter),
        "roles" => (stream-role-policies $filter),
        "groups" => (stream-group-policies $filter),
        _ => {
            if ($source | path exists) {
                stream-file-policies $source $filter
            } else {
                error make { msg: $"Unknown policy source: ($source)" }
            }
        }
    }
}

# Generate mock policy stream for testing
def generate-mock-policy-stream [source: string]: nothing -> list {
    seq 1 25 | each { |i|
        {
            arn: $"arn:aws:iam::123456789012:policy/mock-policy-($i)",
            policy_name: $"MockPolicy($i)",
            policy_document: {
                Version: "2012-10-17",
                Statement: [
                    {
                        Effect: "Allow",
                        Action: $"s3:GetObject($i)",
                        Resource: $"arn:aws:s3:::mock-bucket-($i)/*"
                    }
                ]
            },
            mock: true
        }
    }
}

# ============================================================================
# Helper Functions and Utilities
# ============================================================================

# Format analysis output
def format-analysis-output [result: record, format: string]: nothing -> any {
    match $format {
        "json" => ($result | to json),
        "table" => (format-analysis-table $result),
        "detailed" => (format-analysis-detailed $result),
        _ => $result
    }
}

# Format analysis as table
def format-analysis-table [result: record]: nothing -> table {
    let findings_table = $result.findings | each { |finding|
        {
            finding_id: ($finding.finding_id? | default "N/A"),
            type: ($finding.finding_type? | default "unknown"),
            severity: ($finding.severity? | default "unknown"),
            description: ($finding.description? | default "No description")
        }
    }
    
    if ($findings_table | is-empty) {
        [{ status: "No findings", policy: $result.policy_name, compliant: $result.compliant }]
    } else {
        $findings_table
    }
}

# Calculate overall severity
def calculate-overall-severity [findings: list]: nothing -> string {
    if ($findings | where severity == "critical" | is-not-empty) {
        "critical"
    } else if ($findings | where severity == "high" | is-not-empty) {
        "high"
    } else if ($findings | where severity == "medium" | is-not-empty) {
        "medium"
    } else {
        "low"
    }
}

# Calculate security score (0-100)
def calculate-security-score [findings: list]: nothing -> int {
    let base_score = 100
    let deductions = $findings | each { |finding|
        match $finding.severity {
            "critical" => 30,
            "high" => 20,
            "medium" => 10,
            "low" => 5,
            _ => 0
        }
    } | math sum
    
    ($base_score - $deductions) | if $in < 0 { 0 } else { $in }
}

# Generate cache key for policy analysis
def generate-cache-key [policy_data: record, analysis_type: string]: nothing -> string {
    let policy_content = $policy_data.policy_document | to json
    let content_hash = $policy_content | hash sha256
    $"policy-($analysis_type)-($content_hash | str substring 0..8)"
}

# Export main module functions
export def main [] {
    print "Enhanced IAM Tools for NuAWS loaded successfully"
    print "Available commands:"
    print "  iam analyze-policy        - Analyze IAM policies for security and compliance"
    print "  iam assume-role-enhanced  - Enhanced cross-account role assumption"
    print "  iam detect-privilege-escalation - Detect privilege escalation opportunities"
    print "  iam check-compliance      - Check compliance against AWS best practices"
    print "  iam troubleshoot-policy   - Interactive policy troubleshooting and repair"
    print "  iam stream-policy-analysis - Stream analysis for large policy sets"
}