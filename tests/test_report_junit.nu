use std/assert
use ../report/report_junit.nu

#[before-each]
def setup [] {
    # Clear store before each test
    store clear
    let temp = mktemp --directory
    {
        temp: $temp
        report_path: ($temp | path join "test-report.xml")
    }
}

#[after-each]
def cleanup [] {
    let context = $in
    # Clear store after each test
    store clear
    # Clean up temp directory
    rm --recursive $context.temp
}

# Basic report creation tests (5 tests)
#[test]
def "report junit creation with path" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    assert equal $report.name "report junit"
    assert equal ($report.save | describe) "closure"
    assert equal ($report.results | describe) "closure"
}

#[test]
def "report junit name field" [] {
    let context = $in
    let report = report_junit create $context.report_path
    assert equal $report.name "report junit"
}

#[test]
def "report junit has required fields" [] {
    let context = $in
    let report = report_junit create $context.report_path
    let fields = $report | columns | sort
    
    assert ("name" in $fields)
    assert ("save" in $fields)
    assert ("results" in $fields)
}

#[test]
def "report junit consistent interface" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Verify interface consistency
    assert equal ($report | get name | describe) "string"
    assert equal ($report | get save | describe) "closure"
    assert equal ($report | get results | describe) "closure"
}

#[test]
def "report junit closures callable" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Should be able to call both closures
    let results = do $report.results
    do $report.save
    assert true
}

# Empty store report tests (5 tests)
#[test]
def "report junit with empty store results" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    let results = do $report.results
    assert equal ($results | describe) "string"
    assert str contains $results "testsuites"
}

#[test]
def "report junit with empty store save" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Should save without error
    do $report.save
    
    # File should exist
    assert ($context.report_path | path exists)
    
    # File should contain XML
    let content = open $context.report_path
    assert str contains $content "testsuites"
}

#[test]
def "report junit empty store xml structure" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    let xml = do $report.results
    
    # Should have basic XML structure
    assert str contains $xml "<testsuites"
    assert str contains $xml "</testsuites>"
    assert str contains $xml 'name="nutest"'
}

#[test]
def "report junit empty store counts" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    let xml = do $report.results
    
    # Should have zero counts
    assert str contains $xml 'tests="0"'
    assert str contains $xml 'disabled="0"'
    assert str contains $xml 'failures="0"'
}

#[test]
def "report junit results vs save consistency" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Results and save should produce same content
    let results_xml = do $report.results
    do $report.save
    let saved_xml = open $context.report_path
    
    assert equal $results_xml $saved_xml
}

# Single test report tests (5 tests)
#[test]
def "report junit with single passing test" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Add a passing test
    store put "suite1" "test1" "PASS" []
    
    let xml = do $report.results
    
    assert str contains $xml "<testcase"
    assert str contains $xml 'name="test1"'
    assert str contains $xml 'classname="suite1"'
    assert str contains $xml 'tests="1"'
    assert str contains $xml 'failures="0"'
}

#[test]
def "report junit with single failing test" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Add a failing test
    store put "suite1" "test1" "FAIL" []
    
    let xml = do $report.results
    
    assert str contains $xml "<failure"
    assert str contains $xml 'tests="1"'
    assert str contains $xml 'failures="1"'
}

#[test]
def "report junit with single skipped test" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Add a skipped test
    store put "suite1" "test1" "SKIP" []
    
    let xml = do $report.results
    
    assert str contains $xml "<skipped"
    assert str contains $xml 'tests="1"'
    assert str contains $xml 'disabled="1"'
    assert str contains $xml 'failures="0"'
}

#[test]
def "report junit testcase structure" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Add a test
    store put "my_suite" "my_test" "PASS" []
    
    let xml = do $report.results
    
    # Verify testcase structure
    assert str contains $xml 'name="my_test"'
    assert str contains $xml 'classname="my_suite"'
    assert str contains $xml "<testcase"
    assert str contains $xml "</testcase>"
}

#[test]
def "report junit testsuite grouping" [] {
    let context = $in
    let report = report_junit create $context.report_path
    
    # Add tests to same suite
    store put "suite1" "test1" "PASS" []
    store put "suite1" "test2" "FAIL" []
    
    let xml = do $report.results
    
    # Should have one testsuite with multiple testcases
    assert str contains $xml "<testsuite"
    assert str contains $xml 'name="suite1"'
    assert str contains $xml 'tests="2"'
    assert str contains $xml 'failures="1"'
}