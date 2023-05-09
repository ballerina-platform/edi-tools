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

isolated function convertToType(string value, EDIDataType dataType, string? decimalSeparator) returns SimpleType|error {
    string v = value.trim();
    match dataType {
        STRING => {
            return v;
        }
        INT => {
            return int:fromString(decimalSeparator != () ? regex:replace(v, decimalSeparator, ".") : v);
        }
        FLOAT => {
            return float:fromString(decimalSeparator != () ? regex:replace(v, decimalSeparator, ".") : v);
        }
    }
    return error("Undefined type for value:" + value);
}

isolated function getArray(EDIDataType dataType) returns SimpleArray|EDIComponentGroup[] {
    match dataType {
        STRING => {
            string[] values = [];
            return values;
        }
        INT => {
            int[] values = [];
            return values;
        }
        FLOAT => {
            float[] values = [];
            return values;
        }
        COMPOSITE => {
            EDIComponentGroup[] values = [];
            return values;
        }
    }
    string[] values = [];
    return values;
}

public function getDataType(string typeString) returns EDIDataType {
    match typeString {
        "string" => {
            return STRING;
        }
        "int" => {
            return INT;
        }
        "float" => {
            return FLOAT;
        }
    }
    return STRING;
}

isolated function splitFields(string segmentText, string fieldDelimiter, EDIUnitSchema unitSchema) returns string[]|Error {
    if fieldDelimiter == "FL" {
        EDISegSchema segSchema;
        if unitSchema is EDISegSchema {
            segSchema = unitSchema;
        } else {
            EDIUnitSchema firstSegSchema = unitSchema.segments[0];
            if firstSegSchema is EDISegGroupSchema {
                return error Error("First item of segment group must be a segment. Found a segment group.\nSegment group: " + printSegGroupMap(unitSchema));
            }
            segSchema = firstSegSchema;
        }
        string[] fields = [];
        foreach EDIFieldSchema fieldSchema in segSchema.fields {
            if fieldSchema.startIndex < 0 || fieldSchema.length < 0 {
                return error Error(string `Start index and field length is not provided for fixed length schema field. Segment: ${segSchema.code}, Field: ${fieldSchema.tag}`);
            }
            int startIndex = fieldSchema.startIndex - 1;
            int endIndex = startIndex + fieldSchema.length;
            if startIndex >= segmentText.length() {
                break;
            }
            endIndex = segmentText.length() < endIndex? segmentText.length() : endIndex;
            string fieldText = segmentText.substring(startIndex, endIndex);
            fields.push(fieldText);    
        }
        return fields;
    } else {
        return split(segmentText, fieldDelimiter);
    }
}

isolated function split(string text, string delimiter) returns string[] {
    string preparedText = prepareToSplit(text, delimiter);
    string validatedDelimiter = validateDelimiter(delimiter);
    return regex:split(preparedText, validatedDelimiter);
}

isolated function splitSegments(string text, string delimiter) returns string[] {
    string validatedDelimiter = validateDelimiter(delimiter);
    string[] segmentLines = regex:split(text, validatedDelimiter);
    foreach int i in 0 ... (segmentLines.length() - 1) {
        segmentLines[i] = regex:replaceAll(segmentLines[i], "\n", "");
    }
    return segmentLines;
}

isolated function validateDelimiter(string delimeter) returns string {
    match delimeter {
        "*" => {
            return "\\*";
        }
        "^" => {
            return "\\^";
        }
        "+" => {
            return "\\+";
        }
        "." => {
            return "\\.";
        }
    }
    return delimeter;
}

isolated function prepareToSplit(string content, string delimeter) returns string {
    string preparedContent = content.trim();
    if content.endsWith(delimeter) {
        preparedContent = preparedContent + " ";
    }
    if content.startsWith(delimeter) {
        preparedContent = " " + preparedContent;
    }
    return preparedContent;
}

isolated function printEDIUnitMapping(EDIUnitSchema smap) returns string {
    if smap is EDISegSchema {
        return string `Segment ${smap.code} | Min: ${smap.minOccurances} | Max: ${smap.maxOccurances} | Trunc: ${smap.truncatable}`;
    } else {
        string sgcode = "";
        foreach EDIUnitSchema umap in smap.segments {
            if umap is EDISegSchema {
                sgcode += umap.code + "-";
            } else {
                sgcode += printSegGroupMap(umap);
            }
        }
        return string `[Segment group: ${sgcode} ]`;
    }
}

isolated function printSegMap(EDISegSchema smap) returns string {
    return string `Segment ${smap.code} | Min: ${smap.minOccurances} | Max: ${smap.maxOccurances} | Trunc: ${smap.truncatable}`;
}

isolated function printSegGroupMap(EDISegGroupSchema sgmap) returns string {
    string sgcode = "";
    foreach EDIUnitSchema umap in sgmap.segments {
        if umap is EDISegSchema {
            sgcode += umap.code + "-";
        } else {
            sgcode += printSegGroupMap(umap);
        }
    }
    return string `[Segment group: ${sgcode} ]`;
}

isolated function getMinimumFields(EDISegSchema segmap) returns int {
    int fieldIndex = segmap.fields.length() - 1;
    while fieldIndex > 0 {
        if segmap.fields[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

isolated function getMinimumCompositeFields(EDIFieldSchema fieldSchema) returns int {
    int fieldIndex = fieldSchema.components.length() - 1;
    while fieldIndex > 0 {
        if fieldSchema.components[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

isolated function getMinimumSubcomponentFields(EDIComponentSchema componentSchema) returns int {
    int fieldIndex = componentSchema.subcomponents.length() - 1;
    while fieldIndex > 0 {
        if componentSchema.subcomponents[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

isolated function serializeSimpleType(SimpleType v, EDISchema schema, int fixedLength) returns string {
    string sv = v.toString();
    if v is float {
        if sv.endsWith(".0") {
            sv = sv.substring(0, sv.length() - 2);
        } else if schema.delimiters.decimalSeparator != "." {
            sv = regex:replace(sv, "\\.", schema.delimiters.decimalSeparator ?: ".");
        }
    }
    return fixedLength > 0 ? addPadding(sv, fixedLength) : sv;
}

isolated function addPadding(string value, int requiredLength) returns string {
    string paddedValue = value;
    int lengthDiff = requiredLength - value.length();
    foreach int i in 1...lengthDiff {
        paddedValue += " ";
    }
    return paddedValue;
}

