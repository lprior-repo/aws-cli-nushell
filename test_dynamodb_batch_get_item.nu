# DynamoDB Batch Get Item - Comprehensive Test
#
# This test validates 100% coverage of AWS CLI DynamoDB batch-get-item command
# including all parameters, error codes, responses, and type safety as requested.
# Follows pure functional programming principles with complete test coverage.

use utils/test_utils.nu
use aws_cli_parser.nu
use aws_wrapper_generator.nu
use aws_advanced_parser.nu
use aws_edge_case_handler.nu

# ============================================================================
# TEST DATA: AWS CLI BATCH-GET-ITEM DOCUMENTATION
# ============================================================================

# Complete AWS CLI help output for batch-get-item command
const BATCH_GET_ITEM_HELP = `
BATCH-GET-ITEM()                                              BATCH-GET-ITEM()

NAME
       batch-get-item -

DESCRIPTION
       The  BatchGetItem operation returns the attributes of one or more items
       from one or more tables. You identify requested items by primary key.

       A single operation can retrieve up to 16 MB of data, which can contain
       as many as 100 items. BatchGetItem returns a partial result if the re‐
       sponse  size  limit  is  exceeded, the table's provisioned throughput is
       exceeded, or an internal processing failure occurs. If a partial  result
       is  given,  the  operation returns a value for UnprocessedKeys . You can
       use this value to retry the operation starting with  the  next  item  to
       get.

       If  you request more than 100 items, BatchGetItem returns a ValidationE‐
       xception with the message "Too many items requested for  the  BatchGetI‐
       tem call."

       For  example,  if  you ask to retrieve 100 items, but each individual i‐
       tem is 300 KB in size, the operation returns 52 items (so as not to  ex‐
       ceed  the  16  MB  limit).  It  also returns an appropriate Unprocessed‐
       Keys  value  so  you  can  get  the  next  page  of  results.  If   de‐
       sired,  your  application  can  include  its own logic to assemble the
       pages of results into one dataset.

       If none of the items can be processed due to insufficient provisioned
       throughput on all of the tables in the request, then BatchGetItem re‐
       turns a ProvisionedThroughputExceededException. If at least one of the
       items is successfully processed, then BatchGetItem completes success‐
       fully, while returning the keys of the unprocessed items in Unprocessed‐
       Keys.

       See also: AWS API Documentation

SYNOPSIS
            batch-get-item
          --request-items <value>
          [--return-consumed-capacity <value>]
          [--cli-input-json <value>]
          [--generate-cli-skeleton <value>]

OPTIONS
       --request-items (map)
          A map of one or more table names and, for each table, a map that de‐
          scribes  one  or  more  items  to retrieve from that table. Each ta‐
          ble name can appear only once in the request.

          Each element in the map of items to retrieve has the following  for‐
          mat:

          o Keys  -  An array of primary key attribute values that define spe‐
            cific items in the table. For each primary key, you must  provide
            all  of  the key attributes. For example, with a simple primary
            key, you only need to provide a value for the partition key.  For
            a composite primary key, you must provide values for both the par‐
            tition key and the sort key.

          o AttributesToGet - This legacy parameter does not provide any func‐
            tional  advantage  over using ProjectionExpression . New and exist‐
            ing code should use ProjectionExpression instead.

          o ProjectionExpression - A string that identifies one or more  attri‐
            butes  to  retrieve  from  the table. These attributes can include
            scalars, sets, or elements of a JSON document. The  attributes  in
            the  expression  must  be  separated by commas. If no attribute
            names are specified, then all attributes  are  returned.  If  any
            of  the requested attributes are not found, they do not appear in
            the result.

          o ExpressionAttributeNames - One or more substitution tokens for at‐
            tribute  names  in  an  expression.  The following are some use
            cases for using ExpressionAttributeNames :

            o To access an attribute whose name conflicts with a DynamoDB  re‐
              served word.

            o To  create  a  placeholder for repeating occurrences of an at‐
              tribute name in an expression.

            o To prevent special characters in an attribute  name  from  being
              misinterpreted in an expression.

          key -> (string)

          value -> (structure)
             Keys -> (list)
                (map)

                   key -> (string)

                   value -> (structure)
                      S -> (string)
                         An attribute of type String. For example:

                            "S": "Hello"

                      N -> (string)
                         An attribute of type Number. For example:

                            "N": "123.45"

                         Numbers are sent across the network to DynamoDB as
                         strings, to maximize compatibility across different
                         languages and libraries. However, DynamoDB treats
                         them as number type attributes for mathematical op‐
                         erations.

                      B -> (blob)
                         An attribute of type Binary. For example:

                            "B": blob

                         Type: Base64 encoded binary data object

                      SS -> (list)
                         An attribute of type String Set. For example:

                            "SS": ["Giraffe", "Hippo" ,"Zebra"]

                         (string)

                      NS -> (list)
                         An attribute of type Number Set. For example:

                            "NS": ["42.2", "-19", "7.5", "3.14"]

                         Numbers are sent across the network to DynamoDB as
                         strings, to maximize compatibility across different
                         languages and libraries. However, DynamoDB treats
                         them as number type attributes for mathematical op‐
                         erations.

                         (string)

                      BS -> (list)
                         An attribute of type Binary Set. For example:

                            "BS": ["U3Vubnk=", "UmFpbnk=", "U25vd3k="]

                         (blob)

                      M -> (map)
                         An attribute of type Map. For example:

                            "M": {"Name": {"S": "Joe"}, "Age": {"N": "35"}}

                         key -> (string)

                         value -> (structure)
                            Recursive attribute value structure.

                      L -> (list)
                         An attribute of type List. For example:

                            "L": [ {"S": "Cookies"} , {"S": "Coffee"}, {"N":
                            "3.14159"}]

                         (structure)
                            Recursive attribute value structure.

                      NULL -> (boolean)
                         An attribute of type Null. For example:

                            "NULL": true

                      BOOL -> (boolean)
                         An attribute of type Boolean. For example:

                            "BOOL": true

             AttributesToGet -> (list)
                This is a legacy parameter. Use ProjectionExpression instead.
                For more information, see AttributesToGet in the Amazon Dyna‐
                moDB Developer Guide .

                (string)

             ProjectionExpression -> (string)
                A string that identifies one or more attributes to retrieve
                from the table. These attributes can include scalars, sets, or
                elements of a JSON document. The attributes in the expression
                must be separated by commas.

                If no attribute names are specified, then all attributes are
                returned. If any of the requested attributes are not found,
                they do not appear in the result.

                For more information, see Specifying Item Attributes in the
                Amazon DynamoDB Developer Guide .

             ExpressionAttributeNames -> (map)
                One or more substitution tokens for attribute names in an ex‐
                pression. The following are some use cases for using Expres‐
                sionAttributeNames :

                o To access an attribute whose name conflicts with a DynamoDB
                  reserved word.

                o To create a placeholder for repeating occurrences of an at‐
                  tribute name in an expression.

                o To prevent special characters in an attribute name from be‐
                  ing misinterpreted in an expression.

                Use the # character in an expression to dereference an at‐
                tribute name. For example, consider the following attribute
                name:

                o Percentile

                The name of this attribute conflicts with a reserved word, so
                it cannot be used directly in an expression. To work around
                this, you could specify the following for ExpressionAt‐
                tributeNames :

                o {"#P":"Percentile"}

                You could then use this substitution in an expression, as in
                this example:

                o #P = :val

                NOTE:
                   Tokens that begin with the : character are expression at‐
                   tribute values , which are placeholders for the actual val‐
                   ue at runtime.

                For more information on expression attribute names, see Speci‐
                fying Item Attributes in the Amazon DynamoDB Developer Guide .

                key -> (string)

                value -> (string)

          JSON Syntax:

             {
                "string": {
                   "Keys": [
                      {
                         "string": {
                            "S": "string",
                            "N": "string", 
                            "B": blob,
                            "SS": ["string", ...],
                            "NS": ["string", ...],
                            "BS": [blob, ...],
                            "M": {
                               "string": AttributeValue
                            },
                            "L": [
                               AttributeValue
                               ...
                            ],
                            "NULL": true|false,
                            "BOOL": true|false
                         }
                      }
                      ...
                   ],
                   "AttributesToGet": ["string", ...],
                   "ProjectionExpression": "string",
                   "ExpressionAttributeNames": {"string": "string"
                      ...}
                }
                ...
             }

       --return-consumed-capacity (string)
          Determines  the  level  of  detail about either provisioned or on-
          demand throughput consumption that is returned in the response:

          o INDEXES - The response includes the aggregate ConsumedCapacity for
            the operation, together with ConsumedCapacity for each table  and
            secondary index that was accessed. Note that some operations, such
            as GetItem and BatchGetItem , do not access any indexes  at  all.
            In  these cases, specifying INDEXES will only return ConsumedCa‐
            pacity information for table(s).

          o TOTAL - The response includes only the aggregate  ConsumedCapacity
            for the operation.

          o NONE - No ConsumedCapacity details are included in the response.

          Possible values:

          o INDEXES

          o TOTAL

          o NONE

       --cli-input-json (string)
          Performs  service  operation  based on the JSON string provided. The
          JSON string follows the format provided by --generate-cli-skeleton .
          If other arguments are provided on the command line, the CLI  values
          will override the JSON-provided values. It is not possible to pass
          arbitrary binary values using a JSON-provided value as the string
          will be taken literally.

       --generate-cli-skeleton (string)
          Prints a JSON skeleton to standard output without sending an API re‐
          quest. If provided with no value or the value input , a JSON object
          is printed. If provided with the  value  output  ,  a  JSON  schema
          service  model  is  printed  for  the  output.  The same format is
          printed to stdout for the service model.

OUTPUT
       Responses -> (map)
          A map of table name to a list of items. Each object in Responses
          consists of a table name as the key and a KeysAndAttributes object
          as the value.

          key -> (string)

          value -> (list)
             (map)

                key -> (string)

                value -> (structure)
                   S -> (string)
                      An attribute of type String. For example:

                         "S": "Hello"

                   N -> (string)
                      An attribute of type Number. For example:

                         "N": "123.45"

                      Numbers are sent across the network to DynamoDB as
                      strings, to maximize compatibility across different lan‐
                      guages and libraries. However, DynamoDB treats them as
                      number type attributes for mathematical operations.

                   B -> (blob)
                      An attribute of type Binary. For example:

                         "B": blob

                      Type: Base64 encoded binary data object

                   SS -> (list)
                      An attribute of type String Set. For example:

                         "SS": ["Giraffe", "Hippo" ,"Zebra"]

                      (string)

                   NS -> (list)
                      An attribute of type Number Set. For example:

                         "NS": ["42.2", "-19", "7.5", "3.14"]

                      Numbers are sent across the network to DynamoDB as
                      strings, to maximize compatibility across different lan‐
                      guages and libraries. However, DynamoDB treats them as
                      number type attributes for mathematical operations.

                      (string)

                   BS -> (list)
                      An attribute of type Binary Set. For example:

                         "BS": ["U3Vubnk=", "UmFpbnk=", "U25vd3k="]

                      (blob)

                   M -> (map)
                      An attribute of type Map. For example:

                         "M": {"Name": {"S": "Joe"}, "Age": {"N": "35"}}

                      key -> (string)

                      value -> (structure)
                         Recursive attribute value structure.

                   L -> (list)
                      An attribute of type List. For example:

                         "L": [ {"S": "Cookies"} , {"S": "Coffee"}, {"N":
                         "3.14159"}]

                      (structure)
                         Recursive attribute value structure.

                   NULL -> (boolean)
                      An attribute of type Null. For example:

                         "NULL": true

                   BOOL -> (boolean)
                      An attribute of type Boolean. For example:

                         "BOOL": true

       UnprocessedKeys -> (map)
          A map of tables and their respective keys that were not processed
          with the current response. The UnprocessedKeys value is in the same
          form as RequestItems , so you can provide this value directly to a
          subsequent BatchGetItem operation. For more information, see Re‐
          questItems in the Request Parameters section.

          Each UnprocessedKeys element consists of:

          o Keys - An array of primary key attribute values that define spe‐
            cific items in the table.

          o ProjectionExpression - One or more attributes to be retrieved from
            the table or index. By default, all attributes are returned. When
            you query a local secondary index, you can only request attributes
            that are projected into the index. To force DynamoDB to use a
            particular index, use the IndexName parameter.

          key -> (string)

          value -> (structure)
             Keys -> (list)
                (map)

                   key -> (string)

                   value -> (structure)
                      S -> (string)
                         An attribute of type String. For example:

                            "S": "Hello"

                      N -> (string)
                         An attribute of type Number. For example:

                            "N": "123.45"

                         Numbers are sent across the network to DynamoDB as
                         strings, to maximize compatibility across different
                         languages and libraries. However, DynamoDB treats
                         them as number type attributes for mathematical op‐
                         erations.

                      B -> (blob)
                         An attribute of type Binary. For example:

                            "B": blob

                         Type: Base64 encoded binary data object

                      SS -> (list)
                         An attribute of type String Set. For example:

                            "SS": ["Giraffe", "Hippo" ,"Zebra"]

                         (string)

                      NS -> (list)
                         An attribute of type Number Set. For example:

                            "NS": ["42.2", "-19", "7.5", "3.14"]

                         Numbers are sent across the network to DynamoDB as
                         strings, to maximize compatibility across different
                         languages and libraries. However, DynamoDB treats
                         them as number type attributes for mathematical op‐
                         erations.

                         (string)

                      BS -> (list)
                         An attribute of type Binary Set. For example:

                            "BS": ["U3Vubnk=", "UmFpbnk=", "U25vd3k="]

                         (blob)

                      M -> (map)
                         An attribute of type Map. For example:

                            "M": {"Name": {"S": "Joe"}, "Age": {"N": "35"}}

                         key -> (string)

                         value -> (structure)
                            Recursive attribute value structure.

                      L -> (list)
                         An attribute of type List. For example:

                            "L": [ {"S": "Cookies"} , {"S": "Coffee"}, {"N":
                            "3.14159"}]

                         (structure)
                            Recursive attribute value structure.

                      NULL -> (boolean)
                         An attribute of type Null. For example:

                            "NULL": true

                      BOOL -> (boolean)
                         An attribute of type Boolean. For example:

                            "BOOL": true

             AttributesToGet -> (list)
                This is a legacy parameter. Use ProjectionExpression instead.
                For more information, see AttributesToGet in the Amazon Dyna‐
                moDB Developer Guide .

                (string)

             ProjectionExpression -> (string)
                A string that identifies one or more attributes to retrieve
                from the table. These attributes can include scalars, sets, or
                elements of a JSON document. The attributes in the expression
                must be separated by commas.

                If no attribute names are specified, then all attributes are
                returned. If any of the requested attributes are not found,
                they do not appear in the result.

                For more information, see Specifying Item Attributes in the
                Amazon DynamoDB Developer Guide .

             ExpressionAttributeNames -> (map)
                One or more substitution tokens for attribute names in an ex‐
                pression. The following are some use cases for using Expres‐
                sionAttributeNames :

                o To access an attribute whose name conflicts with a DynamoDB
                  reserved word.

                o To create a placeholder for repeating occurrences of an at‐
                  tribute name in an expression.

                o To prevent special characters in an attribute name from be‐
                  ing misinterpreted in an expression.

                Use the # character in an expression to dereference an at‐
                tribute name. For example, consider the following attribute
                name:

                o Percentile

                The name of this attribute conflicts with a reserved word, so
                it cannot be used directly in an expression. To work around
                this, you could specify the following for ExpressionAt‐
                tributeNames :

                o {"#P":"Percentile"}

                You could then use this substitution in an expression, as in
                this example:

                o #P = :val

                NOTE:
                   Tokens that begin with the : character are expression at‐
                   tribute values , which are placeholders for the actual val‐
                   ue at runtime.

                For more information on expression attribute names, see Speci‐
                fying Item Attributes in the Amazon DynamoDB Developer Guide .

                key -> (string)

                value -> (string)

       ConsumedCapacity -> (list)
          The read capacity units consumed by the entire BatchGetItem opera‐
          tion.

          Each element consists of:

          o TableName - The name of the table that consumed the provisioned
            throughput.

          o CapacityUnits - The total number of capacity units consumed.

          (structure)
             The capacity units consumed by an operation. The data returned
             includes the total provisioned throughput consumed, along with
             statistics for the table and any indexes involved in the opera‐
             tion. ConsumedCapacity is only returned if the ReturnConsumedCa‐
             pacity parameter was specified. For more information, see Provi‐
             sioned Throughput in the Amazon DynamoDB Developer Guide .

             TableName -> (string)
                The name of the table that was affected by the operation.

             CapacityUnits -> (double)
                The total number of capacity units consumed by the operation.

             ReadCapacityUnits -> (double)
                The total number of read capacity units consumed by the opera‐
                tion.

             WriteCapacityUnits -> (double)
                The total number of write capacity units consumed by the oper‐
                ation.

             Table -> (structure)
                The amount of throughput consumed on the table affected by the
                operation.

                ReadCapacityUnits -> (double)
                   The total number of read capacity units consumed on a ta‐
                   ble or an index.

                WriteCapacityUnits -> (double)
                   The total number of write capacity units consumed on a ta‐
                   ble or an index.

                CapacityUnits -> (double)
                   The total number of capacity units consumed on a table or
                   an index.

             LocalSecondaryIndexes -> (map)
                The amount of throughput consumed on each local secondary in‐
                dex affected by the operation.

                key -> (string)

                value -> (structure)
                   Represents the amount of provisioned throughput capacity
                   consumed on a table or an index.

                   ReadCapacityUnits -> (double)
                      The total number of read capacity units consumed on a
                      table or an index.

                   WriteCapacityUnits -> (double)
                      The total number of write capacity units consumed on a
                      table or an index.

                   CapacityUnits -> (double)
                      The total number of capacity units consumed on a table
                      or an index.

             GlobalSecondaryIndexes -> (map)
                The amount of throughput consumed on each global secondary in‐
                dex affected by the operation.

                key -> (string)

                value -> (structure)
                   Represents the amount of provisioned throughput capacity
                   consumed on a table or an index.

                   ReadCapacityUnits -> (double)
                      The total number of read capacity units consumed on a
                      table or an index.

                   WriteCapacityUnits -> (double)
                      The total number of write capacity units consumed on a
                      table or an index.

                   CapacityUnits -> (double)
                      The total number of capacity units consumed on a table
                      or an index.
`

# Error codes that can be returned by batch-get-item
const BATCH_GET_ITEM_ERROR_CODES = [
    "InternalServerError",
    "ProvisionedThroughputExceededException", 
    "RequestLimitExceeded",
    "ResourceNotFoundException",
    "ThrottlingException",
    "ValidationException"
]

# ============================================================================
# COMPREHENSIVE TEST FUNCTIONS
# ============================================================================

# Main test function for DynamoDB batch-get-item
export def test-dynamodb-batch-get-item-complete []: nothing -> record {
    let start_time = (date now)
    
    print "🧪 Starting comprehensive DynamoDB batch-get-item test..."
    
    # Test 1: Parse command help with advanced parser
    let parsing_result = test-parse-batch-get-item-help
    
    # Test 2: Validate parameter extraction completeness
    let parameter_validation = test-parameter-completeness $parsing_result
    
    # Test 3: Test error code coverage
    let error_coverage = test-error-code-coverage $parsing_result
    
    # Test 4: Test output schema parsing
    let output_schema_test = test-output-schema-parsing $parsing_result
    
    # Test 5: Generate type-safe wrapper
    let wrapper_generation = test-wrapper-generation $parsing_result
    
    # Test 6: Validate generated wrapper
    let wrapper_validation = test-wrapper-validation $wrapper_generation.wrapper
    
    # Test 7: Test edge cases and fallbacks
    let edge_case_testing = test-edge-cases
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    let overall_result = {
        test_name: "DynamoDB batch-get-item comprehensive test",
        start_time: $start_time,
        end_time: $end_time,
        duration_ms: $duration,
        results: {
            parsing: $parsing_result,
            parameters: $parameter_validation,
            errors: $error_coverage,
            output_schema: $output_schema_test,
            wrapper_generation: $wrapper_generation,
            wrapper_validation: $wrapper_validation,
            edge_cases: $edge_case_testing
        },
        coverage_summary: (calculate-coverage-summary {
            parsing: $parsing_result,
            parameters: $parameter_validation,
            errors: $error_coverage,
            output_schema: $output_schema_test,
            wrapper_generation: $wrapper_generation,
            wrapper_validation: $wrapper_validation,
            edge_cases: $edge_case_testing
        }),
        overall_success: (all-tests-passed {
            parsing: $parsing_result,
            parameters: $parameter_validation,
            errors: $error_coverage,
            output_schema: $output_schema_test,
            wrapper_generation: $wrapper_generation,
            wrapper_validation: $wrapper_validation,
            edge_cases: $edge_case_testing
        })
    }
    
    print-test-summary $overall_result
    $overall_result
}

# Test parsing of batch-get-item help text
def test-parse-batch-get-item-help []: nothing -> record {
    print "  📋 Testing help text parsing..."
    
    let context = {
        service: "dynamodb",
        command: "batch-get-item"
    }
    
    # Test with advanced parser
    let parsed_result = aws_advanced_parser parse-help-advanced $BATCH_GET_ITEM_HELP $context
    
    # Test with edge case handler for comparison
    let edge_case_result = aws_edge_case_handler parse-with-adaptive-strategy $BATCH_GET_ITEM_HELP $context
    
    # Validate parsing results
    let validation_result = validate-batch-get-item-parsing $parsed_result
    
    {
        success: $validation_result.success,
        parsed_result: $parsed_result,
        edge_case_result: $edge_case_result,
        validation: $validation_result,
        errors: $validation_result.errors
    }
}

# Validate that parsing captured all essential elements
def validate-batch-get-item-parsing [result: record]: nothing -> record {
    mut errors = []
    mut success = true
    
    # Check service and command
    if $result.service != "dynamodb" {
        $errors = ($errors | append "Service not correctly identified")
        $success = false
    }
    
    if $result.command != "batch-get-item" {
        $errors = ($errors | append "Command not correctly identified")
        $success = false
    }
    
    # Check description
    if ($result.description | str length) == 0 {
        $errors = ($errors | append "Description not extracted")
        $success = false
    }
    
    # Check synopsis
    if ($result.synopsis | str length) == 0 {
        $errors = ($errors | append "Synopsis not extracted")
        $success = false
    }
    
    # Check parameters - must have required ones
    let required_params = ["request-items", "return-consumed-capacity"]
    for param_name in $required_params {
        let param_found = ($result.parameters | any { |p| $p.name == $param_name })
        if not $param_found {
            $errors = ($errors | append $"Required parameter not found: ($param_name)")
            $success = false
        }
    }
    
    {
        success: $success,
        errors: $errors,
        parameter_count: ($result.parameters | length),
        description_length: ($result.description | str length),
        synopsis_length: ($result.synopsis | str length)
    }
}

# Test parameter completeness and type safety
def test-parameter-completeness [parsing_result: record]: nothing -> record {
    print "  🔍 Testing parameter completeness..."
    
    let parameters = $parsing_result.parsed_result.parameters
    let expected_parameters = [
        {
            name: "request-items",
            type: "record",
            required: true,
            description_contains: ["map", "table", "items"]
        },
        {
            name: "return-consumed-capacity",
            type: "string",
            required: false,
            choices: ["INDEXES", "TOTAL", "NONE"]
        },
        {
            name: "cli-input-json",
            type: "string",
            required: false,
            description_contains: ["JSON", "string"]
        },
        {
            name: "generate-cli-skeleton",
            type: "string",
            required: false,
            description_contains: ["JSON", "skeleton"]
        }
    ]
    
    mut test_results = []
    mut all_passed = true
    
    for expected in $expected_parameters {
        let found_param = ($parameters | where name == $expected.name | first | default null)
        
        if $found_param == null {
            $test_results = ($test_results | append {
                parameter: $expected.name,
                test: "existence",
                passed: false,
                message: "Parameter not found"
            })
            $all_passed = false
        } else {
            # Test parameter type
            let type_correct = ($found_param.type == $expected.type)
            $test_results = ($test_results | append {
                parameter: $expected.name,
                test: "type",
                passed: $type_correct,
                message: (if $type_correct { "Type correct" } else { $"Expected ($expected.type), got ($found_param.type)" })
            })
            
            if not $type_correct {
                $all_passed = false
            }
            
            # Test required flag
            let required_correct = ($found_param.required == $expected.required)
            $test_results = ($test_results | append {
                parameter: $expected.name,
                test: "required",
                passed: $required_correct,
                message: (if $required_correct { "Required flag correct" } else { $"Expected ($expected.required), got ($found_param.required)" })
            })
            
            if not $required_correct {
                $all_passed = false
            }
            
            # Test choices if specified
            if "choices" in $expected {
                let choices_match = ($found_param.choices | sort) == ($expected.choices | sort)
                $test_results = ($test_results | append {
                    parameter: $expected.name,
                    test: "choices",
                    passed: $choices_match,
                    message: (if $choices_match { "Choices correct" } else { "Choices don't match expected values" })
                })
                
                if not $choices_match {
                    $all_passed = false
                }
            }
            
            # Test description contains expected keywords
            if "description_contains" in $expected {
                mut description_tests = []
                for keyword in $expected.description_contains {
                    let contains_keyword = ($found_param.description | str downcase | str contains ($keyword | str downcase))
                    $description_tests = ($description_tests | append $contains_keyword)
                }
                
                let description_complete = ($description_tests | all { |x| $x })
                $test_results = ($test_results | append {
                    parameter: $expected.name,
                    test: "description",
                    passed: $description_complete,
                    message: (if $description_complete { "Description contains expected keywords" } else { "Description missing expected keywords" })
                })
                
                if not $description_complete {
                    $all_passed = false
                }
            }
        }
    }
    
    {
        success: $all_passed,
        test_results: $test_results,
        total_parameters_found: ($parameters | length),
        expected_parameters_count: ($expected_parameters | length),
        coverage_percentage: (($test_results | where passed | length) / ($test_results | length) * 100.0)
    }
}

# Test error code coverage
def test-error-code-coverage [parsing_result: record]: nothing -> record {
    print "  ⚠️  Testing error code coverage..."
    
    let extracted_errors = $parsing_result.parsed_result.errors
    mut coverage_results = []
    mut all_covered = true
    
    for expected_error in $BATCH_GET_ITEM_ERROR_CODES {
        let error_found = ($extracted_errors | any { |e| $e.code == $expected_error })
        
        $coverage_results = ($coverage_results | append {
            error_code: $expected_error,
            found: $error_found,
            description: (if $error_found { 
                ($extracted_errors | where code == $expected_error | get description.0 | default "")
            } else { 
                "" 
            })
        })
        
        if not $error_found {
            $all_covered = false
        }
    }
    
    # Also check for any additional errors found that weren't expected
    let additional_errors = ($extracted_errors | where code not-in $BATCH_GET_ITEM_ERROR_CODES)
    
    {
        success: $all_covered,
        coverage_results: $coverage_results,
        additional_errors: $additional_errors,
        expected_error_count: ($BATCH_GET_ITEM_ERROR_CODES | length),
        found_error_count: ($extracted_errors | length),
        coverage_percentage: (($coverage_results | where found | length) / ($BATCH_GET_ITEM_ERROR_CODES | length) * 100.0)
    }
}

# Test output schema parsing
def test-output-schema-parsing [parsing_result: record]: nothing -> record {
    print "  📤 Testing output schema parsing..."
    
    let output_schema = $parsing_result.parsed_result.output_schema
    
    # Expected output structure for batch-get-item
    let expected_output_fields = [
        "Responses",
        "UnprocessedKeys", 
        "ConsumedCapacity"
    ]
    
    mut schema_tests = []
    mut all_passed = true
    
    for field in $expected_output_fields {
        let field_present = ($field in $output_schema)
        
        $schema_tests = ($schema_tests | append {
            field: $field,
            present: $field_present,
            test_passed: $field_present
        })
        
        if not $field_present {
            $all_passed = false
        }
    }
    
    {
        success: $all_passed,
        schema_tests: $schema_tests,
        output_schema: $output_schema,
        expected_fields_count: ($expected_output_fields | length),
        coverage_percentage: (($schema_tests | where test_passed | length) / ($expected_output_fields | length) * 100.0)
    }
}

# Test wrapper generation
def test-wrapper-generation [parsing_result: record]: nothing -> record {
    print "  🔧 Testing wrapper generation..."
    
    let parsed_data = $parsing_result.parsed_result
    
    # Generate wrapper using the wrapper generator
    let wrapper_result = aws_wrapper_generator generate-command-wrapper $parsed_data
    
    # Validate wrapper structure
    let validation = validate-wrapper-structure $wrapper_result
    
    {
        success: $validation.success,
        wrapper: $wrapper_result,
        validation: $validation
    }
}

# Validate generated wrapper structure
def validate-wrapper-structure [wrapper: string]: nothing -> record {
    mut errors = []
    mut success = true
    
    # Check that wrapper is not empty
    if ($wrapper | str length) == 0 {
        $errors = ($errors | append "Generated wrapper is empty")
        $success = false
    }
    
    # Check for function definition
    if not ($wrapper | str contains "def ") {
        $errors = ($errors | append "Wrapper missing function definition")
        $success = false
    }
    
    # Check for parameter handling
    if not ($wrapper | str contains "request-items") {
        $errors = ($errors | append "Wrapper missing request-items parameter")
        $success = false
    }
    
    # Check for error handling
    if not ($wrapper | str contains "try" or $wrapper | str contains "catch") {
        $errors = ($errors | append "Wrapper missing error handling")
        $success = false
    }
    
    # Check for type validation
    if not ($wrapper | str contains "validate" or $wrapper | str contains "type") {
        $errors = ($errors | append "Wrapper missing type validation")
        $success = false
    }
    
    {
        success: $success,
        errors: $errors,
        wrapper_length: ($wrapper | str length),
        has_function_def: ($wrapper | str contains "def "),
        has_parameters: ($wrapper | str contains "request-items"),
        has_error_handling: ($wrapper | str contains "try" or $wrapper | str contains "catch"),
        has_type_validation: ($wrapper | str contains "validate" or $wrapper | str contains "type")
    }
}

# Test wrapper validation
def test-wrapper-validation [wrapper: string]: nothing -> record {
    print "  ✅ Testing wrapper validation..."
    
    # Test wrapper syntax (basic validation)
    let syntax_check = validate-wrapper-syntax $wrapper
    
    # Test wrapper completeness
    let completeness_check = validate-wrapper-completeness $wrapper
    
    # Test type safety features
    let type_safety_check = validate-wrapper-type-safety $wrapper
    
    {
        success: ($syntax_check.success and $completeness_check.success and $type_safety_check.success),
        syntax_check: $syntax_check,
        completeness_check: $completeness_check,
        type_safety_check: $type_safety_check
    }
}

# Validate wrapper syntax
def validate-wrapper-syntax [wrapper: string]: nothing -> record {
    mut errors = []
    mut success = true
    
    # Check for balanced braces/brackets
    let open_braces = ($wrapper | str replace --all --regex '[^{]' '' | str length)
    let close_braces = ($wrapper | str replace --all --regex '[^}]' '' | str length)
    
    if $open_braces != $close_braces {
        $errors = ($errors | append "Unbalanced braces in wrapper")
        $success = false
    }
    
    # Check for valid Nushell syntax patterns
    if not ($wrapper | str contains "export def" or $wrapper | str contains "def ") {
        $errors = ($errors | append "Invalid function definition")
        $success = false
    }
    
    {
        success: $success,
        errors: $errors,
        brace_balance: ($open_braces == $close_braces)
    }
}

# Validate wrapper completeness
def validate-wrapper-completeness [wrapper: string]: nothing -> record {
    let required_elements = [
        "request-items",
        "return-consumed-capacity", 
        "aws dynamodb batch-get-item",
        "validate",
        "error"
    ]
    
    mut completeness_tests = []
    mut all_present = true
    
    for element in $required_elements {
        let element_present = ($wrapper | str contains $element)
        
        $completeness_tests = ($completeness_tests | append {
            element: $element,
            present: $element_present
        })
        
        if not $element_present {
            $all_present = false
        }
    }
    
    {
        success: $all_present,
        completeness_tests: $completeness_tests,
        coverage_percentage: (($completeness_tests | where present | length) / ($required_elements | length) * 100.0)
    }
}

# Validate wrapper type safety
def validate-wrapper-type-safety [wrapper: string]: nothing -> record {
    let type_safety_features = [
        "record",
        "string", 
        "validate",
        "type",
        "required"
    ]
    
    mut type_safety_tests = []
    mut all_present = true
    
    for feature in $type_safety_features {
        let feature_present = ($wrapper | str contains $feature)
        
        $type_safety_tests = ($type_safety_tests | append {
            feature: $feature,
            present: $feature_present
        })
        
        if not $feature_present {
            $all_present = false
        }
    }
    
    {
        success: $all_present,
        type_safety_tests: $type_safety_tests,
        coverage_percentage: (($type_safety_tests | where present | length) / ($type_safety_features | length) * 100.0)
    }
}

# Test edge cases and fallback mechanisms
def test-edge-cases []: nothing -> record {
    print "  🧩 Testing edge cases and fallbacks..."
    
    # Test with malformed help text
    let malformed_test = test-malformed-help-text
    
    # Test with empty help text
    let empty_test = test-empty-help-text
    
    # Test with partial help text
    let partial_test = test-partial-help-text
    
    {
        success: ($malformed_test.success and $empty_test.success and $partial_test.success),
        malformed_test: $malformed_test,
        empty_test: $empty_test,
        partial_test: $partial_test
    }
}

# Test with malformed help text
def test-malformed-help-text []: nothing -> record {
    let malformed_help = "This is not valid AWS CLI help output"
    
    let context = {
        service: "dynamodb",
        command: "batch-get-item"
    }
    
    # Should not crash and should return a valid structure
    try {
        let result = aws_edge_case_handler parse-with-adaptive-strategy $malformed_help $context
        {
            success: true,
            result: $result,
            error: null
        }
    } catch { |error|
        {
            success: false,
            result: null,
            error: $error.msg
        }
    }
}

# Test with empty help text
def test-empty-help-text []: nothing -> record {
    let empty_help = ""
    
    let context = {
        service: "dynamodb",
        command: "batch-get-item"
    }
    
    try {
        let result = aws_edge_case_handler parse-with-adaptive-strategy $empty_help $context
        {
            success: true,
            result: $result,
            error: null
        }
    } catch { |error|
        {
            success: false,
            result: null,
            error: $error.msg
        }
    }
}

# Test with partial help text
def test-partial-help-text []: nothing -> record {
    let partial_help = "BATCH-GET-ITEM\n\nDESCRIPTION\nSome description\n\nOPTIONS\n--request-items (map)"
    
    let context = {
        service: "dynamodb",
        command: "batch-get-item"
    }
    
    try {
        let result = aws_advanced_parser parse-help-advanced $partial_help $context
        
        # Validate that it extracted what it could
        let has_description = ($result.description | str length) > 0
        let has_parameters = ($result.parameters | length) > 0
        
        {
            success: ($has_description and $has_parameters),
            result: $result,
            error: null,
            has_description: $has_description,
            has_parameters: $has_parameters
        }
    } catch { |error|
        {
            success: false,
            result: null,
            error: $error.msg
        }
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Calculate overall coverage summary
def calculate-coverage-summary [results: record]: nothing -> record {
    mut total_tests = 0
    mut passed_tests = 0
    
    # Count tests from each category
    if ($results.parsing.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    if ($results.parameters.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    if ($results.errors.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    if ($results.output_schema.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    if ($results.wrapper_generation.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    if ($results.wrapper_validation.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    if ($results.edge_cases.success) { $passed_tests = $passed_tests + 1 }
    $total_tests = $total_tests + 1
    
    {
        total_tests: $total_tests,
        passed_tests: $passed_tests,
        failed_tests: ($total_tests - $passed_tests),
        coverage_percentage: ($passed_tests / $total_tests * 100.0),
        parameter_coverage: ($results.parameters.coverage_percentage? | default 0.0),
        error_coverage: ($results.errors.coverage_percentage? | default 0.0),
        output_schema_coverage: ($results.output_schema.coverage_percentage? | default 0.0)
    }
}

# Check if all tests passed
def all-tests-passed [results: record]: nothing -> bool {
    ($results.parsing.success and 
     $results.parameters.success and
     $results.errors.success and
     $results.output_schema.success and
     $results.wrapper_generation.success and
     $results.wrapper_validation.success and
     $results.edge_cases.success)
}

# Print comprehensive test summary
def print-test-summary [result: record]: nothing -> nothing {
    print "\n" 
    print "=".repeat(80)
    print $" 📊 TEST SUMMARY: ($result.test_name)"
    print "=".repeat(80)
    
    let summary = $result.coverage_summary
    
    print $"⏱️  Duration: ($result.duration_ms)ms"
    print $"✅ Tests Passed: ($summary.passed_tests)/($summary.total_tests)"
    print $"📈 Overall Coverage: ($summary.coverage_percentage | math round)%"
    print $"🔧 Parameter Coverage: ($summary.parameter_coverage | math round)%"
    print $"⚠️  Error Coverage: ($summary.error_coverage | math round)%"
    print $"📤 Output Schema Coverage: ($summary.output_schema_coverage | math round)%"
    
    if $result.overall_success {
        print "🎉 ALL TESTS PASSED - 100% COVERAGE ACHIEVED!"
    } else {
        print "❌ SOME TESTS FAILED - COVERAGE INCOMPLETE"
        
        # Print failed test details
        if not $result.results.parsing.success {
            print "  - Parsing tests failed"
        }
        if not $result.results.parameters.success {
            print "  - Parameter tests failed"
        }
        if not $result.results.errors.success {
            print "  - Error coverage tests failed"
        }
        if not $result.results.output_schema.success {
            print "  - Output schema tests failed"
        }
        if not $result.results.wrapper_generation.success {
            print "  - Wrapper generation tests failed"
        }
        if not $result.results.wrapper_validation.success {
            print "  - Wrapper validation tests failed"
        }
        if not $result.results.edge_cases.success {
            print "  - Edge case tests failed"
        }
    }
    
    print "=".repeat(80)
    print ""
}

# ============================================================================
# SPECIFIC VALIDATION FUNCTIONS FOR DYNAMODB BATCH-GET-ITEM
# ============================================================================

# Validate specific DynamoDB batch-get-item requirements
export def validate-batch-get-item-requirements [
    parsing_result: record
]: nothing -> record {
    mut requirements_check = []
    mut all_met = true
    
    # Requirement 1: Must parse request-items parameter with complex structure
    let request_items_param = ($parsing_result.parameters | where name == "request-items" | first | default null)
    let request_items_valid = ($request_items_param != null and $request_items_param.type == "record")
    
    $requirements_check = ($requirements_check | append {
        requirement: "Complex request-items parameter parsing",
        met: $request_items_valid,
        details: (if $request_items_valid { "Successfully parsed as record type" } else { "Failed to parse or incorrect type" })
    })
    
    if not $request_items_valid {
        $all_met = false
    }
    
    # Requirement 2: Must identify all DynamoDB-specific error codes
    let required_errors = $BATCH_GET_ITEM_ERROR_CODES
    let found_errors = ($parsing_result.errors | get code)
    let error_coverage = ($required_errors | all { |e| $e in $found_errors })
    
    $requirements_check = ($requirements_check | append {
        requirement: "All DynamoDB error codes identified",
        met: $error_coverage,
        details: $"Found ($found_errors | length)/($required_errors | length) required error codes"
    })
    
    if not $error_coverage {
        $all_met = false
    }
    
    # Requirement 3: Must parse complex AttributeValue structures
    let description = $parsing_result.description
    let has_attribute_value_info = ($description | str contains "AttributeValue" or $description | str contains "attribute")
    
    $requirements_check = ($requirements_check | append {
        requirement: "AttributeValue structure documentation",
        met: $has_attribute_value_info,
        details: (if $has_attribute_value_info { "Documentation includes AttributeValue information" } else { "Missing AttributeValue documentation" })
    })
    
    if not $has_attribute_value_info {
        $all_met = false
    }
    
    # Requirement 4: Must handle pagination and unprocessed keys
    let has_unprocessed_keys = ($parsing_result.description | str contains "UnprocessedKeys" or 
                               ($parsing_result.output_schema | columns | any { |c| $c | str contains "Unprocessed" }))
    
    $requirements_check = ($requirements_check | append {
        requirement: "Unprocessed keys and pagination handling",
        met: $has_unprocessed_keys,
        details: (if $has_unprocessed_keys { "Documentation includes UnprocessedKeys information" } else { "Missing UnprocessedKeys documentation" })
    })
    
    if not $has_unprocessed_keys {
        $all_met = false
    }
    
    {
        all_requirements_met: $all_met,
        requirements_check: $requirements_check,
        total_requirements: ($requirements_check | length),
        met_requirements: ($requirements_check | where met | length),
        compliance_percentage: (($requirements_check | where met | length) / ($requirements_check | length) * 100.0)
    }
}

# Run the comprehensive test if this file is executed directly
if $env.NU_CURRENT_FILE? == ($env.FILE_PWD + "/test_dynamodb_batch_get_item.nu") {
    test-dynamodb-batch-get-item-complete
}