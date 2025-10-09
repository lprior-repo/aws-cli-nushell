# Enhanced Lambda Tools for NuAWS
# Simple enhanced functionality on top of base Lambda commands

# Export enhanced Lambda commands
export def "lambda enhanced" [] {
    print "Enhanced Lambda tools loaded successfully"
}

# Simple enhanced function listing
export def "lambda list-functions-enhanced" [] {
    ^aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,Timeout,MemorySize]' --output table
}

# Simple enhanced invoke
export def "lambda invoke-enhanced" [function_name: string] {
    let temp_file = "/tmp/lambda_response.json"
    ^aws lambda invoke --function-name $function_name $temp_file
    
    if ($temp_file | path exists) {
        open $temp_file | from json
    }
}