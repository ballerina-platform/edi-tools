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

import ballerina/log;

isolated function readRepetition(string repeatText, string repeatDelimiter, EDISchema mapping, EDIFieldSchema fieldMapping)
        returns SimpleArray|EDIComponentGroup[]|Error {
    string[] fields = split(repeatText, repeatDelimiter);
    SimpleArray|EDIComponentGroup[] repeatValues = getArray(fieldMapping.dataType);
    if fields.length() == 0 {
        // None of the repeating values are provided. Return an empty array.
        if fieldMapping.required {
            return error Error(string `Required (multi-value) field is not provided. Field: ${fieldMapping.tag}`);
        }
        return repeatValues;
    }
    foreach string 'field in fields {
        if fieldMapping.dataType == COMPOSITE {
            EDIComponentGroup? value = check readComponentGroup('field, mapping, fieldMapping);
            if value is EDIComponentGroup {
                repeatValues.push(value);
            } else {
                log:printWarn(string `Repeat value not provided in ${repeatText}.`);
            }
        } else {
            if 'field.trim().length() == 0 {
                continue;
            }
            SimpleType|error value = convertToType('field, fieldMapping.dataType, mapping.delimiters.decimalSeparator);
            if value is error {
                return error Error(string `Input value does not match with the shema type.
                    Input value: ${'field}, Schema type: ${fieldMapping.dataType}, Field schema: ${fieldMapping.toJsonString()}, Repeat text: ${repeatText}, Error: ${value.message()}`);
            }
            repeatValues.push(value);
        }
    }
    return repeatValues;
}
