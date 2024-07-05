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

import ballerina/edi;
import ballerina/io;

public function generateCodeForSchema(json schema, string outputPath) returns error? {
    edi:EdiSchema ediSchema = check edi:getSchema(schema);
    BalRecord[] records = check generateCode(ediSchema);
    string recordsString = "";
    foreach BalRecord rec in records {
        recordsString += rec.toString() + "\n";
    }

    string schemaCode = string `
import ballerina/edi;

# Convert EDI string to Ballerina ${ediSchema.name} record.
# 
# + ediText - EDI string to be converted
# + return - Ballerina record
public isolated function fromEdiString(string ediText) returns ${ediSchema.name}|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json dataJson = check edi:fromEdiString(ediText, ediSchema);
    return dataJson.cloneWithType();
}

# Convert Ballerina ${ediSchema.name} record to EDI string.
# 
# + data - Ballerina record to be converted
# + return - EDI string
public isolated function toEdiString(${ediSchema.name} data) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    return edi:toEdiString(data, ediSchema);    
} 

# Get the EDI schema.
# 
# + return - EDI schema
public isolated function getSchema() returns edi:EdiSchema|error {
    return edi:getSchema(schemaJson);
}

# Convert EDI string to Ballerina ${ediSchema.name} record with schema.
# 
# + ediText - EDI string to be converted
# + schema - EDI schema
# + return - Ballerina record
public isolated function fromEdiStringWithSchema(string ediText, edi:EdiSchema schema) returns ${ediSchema.name}|error {
    json dataJson = check edi:fromEdiString(ediText, schema);
    return dataJson.cloneWithType();
}

# Convert Ballerina ${ediSchema.name} record to EDI string with schema.
# 
# + data - Ballerina record to be converted
# + ediSchema - EDI schema
# + return - EDI string
public isolated function toEdiStringWithSchema(${ediSchema.name} data, edi:EdiSchema ediSchema) returns string|error {
    return edi:toEdiString(data, ediSchema);    
}

${recordsString}

final readonly & json schemaJson = ${schema.toJsonString()};
    `;

    check io:fileWriteString(outputPath, schemaCode);

}

