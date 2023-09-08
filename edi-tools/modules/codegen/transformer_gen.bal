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

function generateTransformerCode(string ediName, string mainRecordName) returns string {
    string transformer = string `
type InternalType ${mainRecordName};

public isolated function transformFromEdiString(string ediText) returns anydata|error {
    ${mainRecordName} data = check fromEdiString(ediText);
    return transformRead(data);
}

isolated function transformRead(${mainRecordName} data) returns InternalType => data;

public isolated function transformToEdiString(anydata content) returns string|error {
    ${mainRecordName} data = transformWrite(check content.ensureType());
    return toEdiString(data);
}

isolated function transformWrite(InternalType data) returns ${mainRecordName} => data;
    `;
    return transformer;
}
