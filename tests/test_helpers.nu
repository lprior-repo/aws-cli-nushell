# Test helpers for AWS OpenAPI Extractor tests
# Uses nutest framework conventions

use std assert

# ============================================================================
# FIXTURE GENERATORS
# ============================================================================

export def create-minimal-spec []: nothing -> record {
    {
        metadata: {
            apiVersion: "2016-11-23",
            endpointPrefix: "test",
            protocol: "json",
            serviceFullName: "Test Service",
            signatureVersion: "v4"
        },
        operations: {
            TestOperation: {
                name: "TestOperation",
                http: {
                    method: "POST",
                    requestUri: "/"
                },
                input: { shape: "TestInput" },
                output: { shape: "TestOutput" }
            }
        },
        shapes: {
            TestInput: {
                type: "structure",
                required: ["requiredField"],
                members: {
                    requiredField: { shape: "String" },
                    optionalField: { shape: "Integer" }
                }
            },
            TestOutput: {
                type: "structure",
                members: {
                    result: { shape: "String" }
                }
            },
            String: { type: "string" },
            Integer: { type: "integer" }
        }
    }
}

export def create-paginated-spec []: nothing -> record {
    {
        metadata: {
            apiVersion: "2016-11-23",
            protocol: "json",
            serviceFullName: "Paginated Service"
        },
        operations: {
            ListItems: {
                name: "ListItems",
                http: { method: "POST", requestUri: "/" },
                input: { shape: "ListItemsInput" },
                output: { shape: "ListItemsOutput" }
            }
        },
        shapes: {
            ListItemsInput: {
                type: "structure",
                members: {
                    MaxResults: { shape: "Integer" },
                    NextToken: { shape: "String" }
                }
            },
            ListItemsOutput: {
                type: "structure",
                members: {
                    Items: { shape: "ItemList" },
                    NextToken: { shape: "String" }
                }
            },
            ItemList: {
                type: "list",
                member: { shape: "String" }
            },
            String: { type: "string" },
            Integer: { type: "integer" }
        },
        pagination: {
            ListItems: {
                input_token: "NextToken",
                output_token: "NextToken",
                limit_key: "MaxResults",
                result_key: ["Items"]
            }
        }
    }
}

export def create-error-spec []: nothing -> record {
    {
        metadata: {
            apiVersion: "2016-11-23",
            protocol: "json",
            serviceFullName: "Error Service"
        },
        operations: {},
        shapes: {
            ResourceNotFoundException: {
                type: "structure",
                exception: true,
                error: {
                    httpStatusCode: 404,
                    senderFault: true
                },
                documentation: "Resource not found"
            },
            ThrottlingException: {
                type: "structure",
                exception: true,
                error: {
                    httpStatusCode: 429
                },
                retryable: {
                    throttling: true
                },
                documentation: "Request throttled"
            }
        }
    }
}

export def create-complex-spec []: nothing -> record {
    {
        metadata: {
            apiVersion: "2016-11-23",
            protocol: "json",
            serviceFullName: "Complex Service"
        },
        operations: {
            CreateThing: {
                name: "CreateThing",
                http: { method: "POST", requestUri: "/" },
                input: { shape: "CreateThingInput" },
                output: { shape: "CreateThingOutput" }
            },
            ListThings: {
                name: "ListThings",
                http: { method: "POST", requestUri: "/" },
                input: { shape: "ListThingsInput" },
                output: { shape: "ListThingsOutput" }
            },
            DescribeThing: {
                name: "DescribeThing",
                http: { method: "POST", requestUri: "/" },
                input: { shape: "DescribeThingInput" },
                output: { shape: "DescribeThingOutput" }
            },
            DeleteThing: {
                name: "DeleteThing",
                http: { method: "POST", requestUri: "/" },
                input: { shape: "DeleteThingInput" }
            }
        },
        shapes: {
            CreateThingInput: {
                type: "structure",
                required: ["name"],
                members: {
                    name: { shape: "ThingName" },
                    description: { shape: "String" }
                }
            },
            CreateThingOutput: {
                type: "structure",
                members: {
                    thingArn: { shape: "ThingArn" },
                    createdAt: { shape: "Timestamp" }
                }
            },
            ListThingsInput: {
                type: "structure",
                members: {
                    maxResults: { shape: "MaxResults" },
                    nextToken: { shape: "NextToken" }
                }
            },
            ListThingsOutput: {
                type: "structure",
                members: {
                    things: { shape: "ThingList" },
                    nextToken: { shape: "NextToken" }
                }
            },
            DescribeThingInput: {
                type: "structure",
                required: ["thingArn"],
                members: {
                    thingArn: { shape: "ThingArn" }
                }
            },
            DescribeThingOutput: {
                type: "structure",
                members: {
                    name: { shape: "ThingName" },
                    thingArn: { shape: "ThingArn" },
                    description: { shape: "String" },
                    createdAt: { shape: "Timestamp" }
                }
            },
            DeleteThingInput: {
                type: "structure",
                required: ["thingArn"],
                members: {
                    thingArn: { shape: "ThingArn" }
                }
            },
            ThingList: {
                type: "list",
                member: { shape: "ThingSummary" }
            },
            ThingSummary: {
                type: "structure",
                members: {
                    name: { shape: "ThingName" },
                    thingArn: { shape: "ThingArn" }
                }
            },
            ThingName: { type: "string", min: 1, max: 128 },
            ThingArn: { type: "string", pattern: "^arn:aws:test:.*" },
            String: { type: "string" },
            Timestamp: { type: "timestamp" },
            MaxResults: { type: "integer", min: 1, max: 100 },
            NextToken: { type: "string" }
        },
        pagination: {
            ListThings: {
                input_token: "nextToken",
                output_token: "nextToken",
                limit_key: "maxResults",
                result_key: ["things"]
            }
        }
    }
}

# ============================================================================
# CUSTOM ASSERTIONS
# ============================================================================

export def assert-record-has-fields [
    record: record,
    fields: list<string>
] {
    let missing = $fields | where {|field| not ($field in ($record | columns))}
    
    if ($missing | length) > 0 {
        let msg = $"Missing required fields: ($missing | str join ', ')"
        assert equal ($missing | length) 0 $msg
    }
}

export def assert-list-not-empty [list: list, message: string = "List should not be empty"] {
    assert greater ($list | length) 0 $message
}

export def assert-all-items [list: list, condition: closure, message: string = "Condition failed"] {
    let failing = $list | where {|item| not (do $condition $item)}
    assert equal ($failing | length) 0 $message
}

export def create-temp-file [content: any]: nothing -> string {
    let temp_file = $"/tmp/test-openapi-(random uuid).json"
    $content | to json | save $temp_file
    $temp_file
}

export def cleanup-temp-file [file_path: string]: nothing -> nothing {
    if ($file_path | path exists) {
        rm $file_path
    }
}