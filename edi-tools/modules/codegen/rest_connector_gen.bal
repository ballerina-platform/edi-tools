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

import ballerina/regex;

function generateRESTConnector(string libName) returns string {
    string restConCode = string `
import ballerina/http;

configurable int restConnectorPort = 9090;

service /${regex:replaceAll(libName, "[.]", "_")}Parser on new http:Listener(restConnectorPort) {

    isolated resource function post edis/[string ediType](@http:Payload string ediData) returns json|error {
        EDI_NAME|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        anydata target = check fromEdiString(ediData, ediTypeName);   
        return target.toJson();
    }

    isolated resource function post objects/[string ediType](@http:Payload json jsonData) returns string|error {
        EDI_NAME|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        string ediText = check toEdiString(jsonData, ediTypeName);   
        return ediText;
    }

    isolated resource function get edis() returns string[] {
        return getEDINames();
    }
}
    `;

    return restConCode;
}
