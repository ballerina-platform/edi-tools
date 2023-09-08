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
import ballerina/regex;
import ballerina/log;
import ballerina/io;

xmlns "http://www.w3.org/2001/XMLSchema" as xs;
xmlns "http://xml.x12.org/isomorph" as x12;

public function convertFromX12XsdAndWrite(string inPath, string outPath) returns error? {
    xml x12xsd = check io:fileReadXml(inPath);
    edi:EdiSchema ediSchema = check convertFromX12Xsd(x12xsd);
    check io:fileWriteJson(outPath, ediSchema);
}

public function convertFromX12Xsd(xml x12xsd) returns edi:EdiSchema|error {
    xml elements = x12xsd/<xs:element>;
    xml root = elements[0];
    string|error rootName = root.name;
    if rootName is error {
        return error("Root element name not found. " + root.toString(), rootName);
    }
    edi:EdiSchema ediSchema = {delimiters: {segment: "~", 'field: "*", component: ":"}, name: rootName, tag: rootName};
    if !rootName.startsWith("X12_") {
        return error("Invalid X12 schema");
    }
    edi:EdiSegGroupSchema rootSegGroupSchema = check convertSegmentGroup(root, x12xsd, ediSchema);
    ediSchema.segments = rootSegGroupSchema.segments;
    return ediSchema;
}

function convertSegmentGroup(xml segmentGroup, xml x12xsd, edi:EdiSchema schema) returns edi:EdiSegGroupSchema|error {
    xml elements = segmentGroup/<xs:complexType>/<xs:sequence>/<xs:element>;
    string|error tag = segmentGroup.name;
    if tag is error {
        return error("Segment group name not found. " + segmentGroup.toString(), tag);
    }
    edi:EdiSegGroupSchema segGroupSchema = {tag};
    foreach xml element in elements {
        string ref = check element.ref;
        if ref.startsWith("Loop_") {
            xml segGroupElement = check getUnitElement(ref, x12xsd);
            edi:EdiSegGroupSchema childSegGroupSchema = check convertSegmentGroup(segGroupElement, x12xsd, schema);
            segGroupSchema.segments.push(childSegGroupSchema);
        } else {
            if !schema.segmentDefinitions.hasKey((ref)) {
                edi:EdiSegSchema segSchema = check convertSegment(ref, x12xsd);
                schema.segmentDefinitions[ref] = segSchema;
            }
            edi:EdiUnitRef segRef = {ref: ref};
            segGroupSchema.segments.push(segRef);
        }
    }
    return segGroupSchema;
}

function convertSegment(string segmentName, xml x12xsd) returns edi:EdiSegSchema|error {
    xml segElement = check getUnitElement(segmentName, x12xsd);
    string[] nameParts = regex:split(segmentName, "_");
    edi:EdiSegSchema segSchema = {code: nameParts[0], tag: nameParts[1]};
    segSchema.fields.push({tag: "code", required: true});
    xml fieldElements = segElement/<xs:complexType>/<xs:sequence>/<xs:element>;
    foreach xml fieldElement in fieldElements {
        string|error fieldName = fieldElement.name;
        if fieldName is error {
            return error(string `Field name not found. Segment: ${segmentName}, Field: ${fieldElement.toString()}`, fieldName);
        }
        edi:EdiFieldSchema fieldSchema = {tag: fieldName, required: true};
        string|error minOccurs = fieldElement.minOccurs;
        if (minOccurs is string) {
            fieldSchema.required = minOccurs == "0" ? false : true;
        }
        string?|error fieldDataType = fieldElement/<xs:'annotation>/<xs:appinfo>/<x12:STD_Info>.DataType;
        if fieldDataType is error || fieldDataType == () {
            // Datatype not defined. This could be a composite field. Process child elements to construct the composite field.
            xml compositeElements = fieldElement/<xs:complexType>/<xs:sequence>/<xs:element>;
            if compositeElements.length() == 0 {
                log:printWarn(string `Data type not defined. Defaulting it to string. Segment name: ${segmentName}, Field name: ${fieldName}`);
                fieldSchema.dataType = edi:STRING;
            } else {
                check convertCompositeField(fieldSchema, compositeElements, segmentName, fieldName);    
            }
        } else {
            edi:EdiDataType|error dataType = getDataType(fieldDataType);
            if dataType is error {
                log:printWarn(string `Unknown data type found. Defaulting it to string. Data type: ${fieldDataType}, Segment name: ${segmentName}, Field name: ${fieldName}`);
                fieldSchema.dataType = edi:STRING;
            } else {
                fieldSchema.dataType = dataType;
            }
        }
        segSchema.fields.push(fieldSchema);
    }
    return segSchema;
}

function convertCompositeField(edi:EdiFieldSchema fieldSchema, xml compositeElements, string segmentName, string fieldName) returns error? {
    fieldSchema.dataType = edi:COMPOSITE;
    foreach xml compositeElement in compositeElements {
        string|error compositeFieldName = compositeElement.name;
        if compositeFieldName is error {
            return error(string `Composite field name not found. Segment: ${segmentName}, Field: ${fieldName}, Composite field: ${compositeElement.toString()}`, compositeFieldName);
        }
        edi:EdiComponentSchema compositeFieldSchema = {tag: compositeFieldName, required: true};
        string|error compositeMinOccurs = compositeElement.minOccurs;
        if compositeMinOccurs is string {
            compositeFieldSchema.required = compositeMinOccurs == "0" ? false : true;
        }
        string?|error compositeDataType = compositeElement/<xs:'annotation>/<xs:appinfo>/<x12:STD_Info>.DataType;
        if compositeDataType is error || compositeDataType == () {
            log:printWarn(string `Data type not defined. Defaulting it to string. Segment name: ${segmentName}, Field name: ${fieldName}, Composite field name: ${compositeFieldName}`);
            compositeFieldSchema.dataType = edi:STRING;
        } else {
            edi:EdiDataType|error dataType = getDataType(compositeDataType);
            if dataType is error {
                log:printWarn(string `Unknown data type. Defaulting it to string. Segment name: ${segmentName}, Field name: ${fieldName}, Composite field name: ${compositeFieldName}`);
                compositeFieldSchema.dataType = edi:STRING;
            } else {
                compositeFieldSchema.dataType = dataType;
            }
        }
        fieldSchema.components.push(compositeFieldSchema);
    }
}

function getDataType(string dataTypeString) returns edi:EdiDataType|error {
    match dataTypeString {
        "ID" => {return edi:STRING;}
        "AN" => {return edi:STRING;}
        "DT" => {return edi:STRING;}
        "TM" => {return edi:STRING;}
        "R" => {return edi:STRING;}
        "N" => {return edi:FLOAT;}
        "N0" => {return edi:FLOAT;}
        "N1" => {return edi:INT;}
        "N2" => {return edi:FLOAT;}
        _ => {return error("Unknown data type.");}
    }
}

function getUnitElement(string name, xml x12xsd) returns xml|error {
    xml? unitElement = ();
    xml x12Elements = x12xsd/<xs:element>;
    foreach xml x12Element in x12Elements {
        string|error elementName = x12Element.name;
        if elementName is error {
            return error("EDI segment/segment group's name attribute  is not available. " + x12Element.toString(), elementName);
        }
        if elementName == name {
            unitElement = x12Element;
        }
    }
    if (unitElement is ()) {
        return error("EDI segment/segment group not found in the input schema. Unit name: " + name);
    }
    return unitElement;
}