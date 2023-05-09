// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;

type EDIContext record {|
    EDISchema schema;
    string[] ediText = [];
    int rawIndex = 0;
|};

# Reads the given EDI text according to the provided schema.
#
# + ediText - EDI text to be read
# + schema - Schema of the EDI text
# + return - JSON variable containing EDI data. Error if the reading fails.
public isolated function read(string ediText, EDISchema schema) returns json|Error {
    EDIContext context = {schema};
    EDIUnitSchema[] currentMapping = context.schema.segments;
    context.ediText = splitSegments(ediText, context.schema.delimiters.segment);
    EDISegmentGroup rootGroup = check readSegmentGroup(currentMapping, context, true);
    return rootGroup;
}

# Writes the given JSON varibale into a EDI text according to the provided schema.
#
# + msg - JSON value to be written into EDI
# + schema - Schema of the EDI text
# + return - EDI text containing the data provided in the JSON variable. Error if the reading fails.
public isolated function write(json msg, EDISchema schema) returns string|Error {
    if !(msg is map<json>) {
        return error(string `Input is not compatible with the schema.`);
    }
    EDIContext context = {schema};
    check writeSegmentGroup(msg, schema, context);
    string ediOutput = "";
    foreach string s in context.ediText {
        ediOutput += s + (schema.delimiters.segment == "\n" ? "" : "\n");
    }
    return ediOutput;
}

# Creates an EDI schema from a string or a JSON.
#
# + schema - Schema of the EDI type 
# + return - Error is returned if the given schema is not valid
public isolated function getSchema(string|json schema) returns EDISchema|error {
    if !(schema is map<json> || schema is string) {
        return error("Schema is not valid.");
    }
    json schemaJson;
    if schema is string {
        io:StringReader sr = new (schema);
        schemaJson = check sr.readJson();
    } else {
        schemaJson = schema;
    }
    check denormalizeSchema(schemaJson);
    return schemaJson.cloneWithType(EDISchema);
}

# Represents EDI module related errors
public type Error distinct error;
