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

function generateMainCode(LibData libdata) returns string {
    return string `
${libdata.importsBlock}

type EdiSerialize isolated function (anydata) returns string|error;
type EdiDeserialize isolated function (string) returns anydata|error;

public enum EDI_NAME {
    ${libdata.enumBlock}
}

public isolated function getEDINames() returns string[] {
    return ${libdata.ediNames.toString()};
}

# Convert EDI string to Ballerina record.
# 
# + ediText - EDI string to be converted
# + ediName - EDI type name
# + return - Ballerina record or error
public isolated function fromEdiString(string ediText, EDI_NAME ediName) returns anydata|error {
    EdiDeserialize? ediDeserialize = ediDeserializers[ediName];
    if ediDeserialize is () {
        return error("EDI deserializer is not initialized for EDI type: " + ediName);
    }
    return ediDeserialize(ediText);
}

# Convert Ballerina record to EDI string.
# 
# + data - Ballerina record to be converted
# + ediName - EDI type name
# + return - EDI string or error
public isolated function toEdiString(anydata data, EDI_NAME ediName) returns string|error {
    EdiSerialize? ediSerialize = ediSerializers[ediName];
    if ediSerialize is () {
        return error("EDI serializer is not initialized for EDI type: " + ediName);
    }
    return ediSerialize(data);
}

final readonly & map<EdiDeserialize> ediDeserializers = {
    ${libdata.ediDeserializers}
};

final readonly & map<EdiSerialize> ediSerializers = {
    ${libdata.ediSerializers}
};
    `;

}
