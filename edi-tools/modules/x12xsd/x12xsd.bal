// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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
import ballerina/file;
import ballerina/io;
import ballerina/log;

xmlns "http://www.w3.org/2001/XMLSchema" as xs;
xmlns "http://xml.x12.org/isomorph" as x12;

map<string> conditionalFeildsMap = {};

public function convertFromX12XsdAndWrite(string inPath, string outPath, string segdetPath = "") returns error? {
    loadConditionalFieldsMap(segdetPath);
    xml x12xsd = check io:fileReadXml(inPath);
    edi:EdiSchema ediSchema = check convertFromX12Xsd(x12xsd);
    check io:fileWriteJson(outPath, ediSchema);
}

public function convertFromX12WithHeadersAndWrite(string inPath, string outPath, string segdetPath = "") returns error? {
    loadConditionalFieldsMap(segdetPath);
    edi:EdiSchema ediSchema = check convertFromX12WithHeaders(inPath);
    check io:fileWriteJson(outPath, ediSchema);
}

public function convertFromX12CollectionAndWrite(string inPath, string outPath, boolean withHeaders, string segdetPath = "") returns error? {
    loadConditionalFieldsMap(segdetPath);
    boolean isOutputDir = check file:test(outPath, file:IS_DIR);
    file:MetaData[] inFiles = check file:readDir(inPath);
    if withHeaders {
        foreach file:MetaData inFile in inFiles {
            if (inFile.dir) {
                string dirName = check file:basename(inFile.absPath);
                string outputPathGenerated = isOutputDir ? check file:joinPath(outPath, dirName + ".json") : outPath;
                edi:EdiSchema ediSchema = check convertFromX12WithHeaders(inFile.absPath);
                check io:fileWriteJson(outputPathGenerated, ediSchema);
            }
        }
    } else {
        foreach file:MetaData inFile in inFiles {
            string ediName = check file:basename(inFile.absPath);
            if (ediName.endsWith(".xsd")) {
                ediName = ediName.substring(0, ediName.length() - ".xsd".length());
            }
            xml x12xsd = check io:fileReadXml(inFile.absPath);
            edi:EdiSchema ediSchema = check convertFromX12Xsd(x12xsd);
            check io:fileWriteJson(check file:joinPath(outPath, ediName + ".json"), ediSchema);
        }
    }
}

public function convertFromX12Xsd(xml x12xsd) returns edi:EdiSchema|error {
    xml elements = x12xsd/<xs:element>;
    xml root = elements[0];
    string rootName = "";
    do {
        rootName = check root.name;
    } on fail error e {
        return error("Root element name not found. " + root.toString(), e);
    }
    rootName = getBalCompatibleName(rootName);
    edi:EdiSchema ediSchema = {delimiters: {segment: "~", 'field: "*", component: ":"}, name: rootName, tag: rootName};
    if !rootName.startsWith("X12_") {
        return error("Invalid X12 schema");
    }
    edi:EdiSegGroupSchema rootSegGroupSchema = check convertSegmentGroup(root, x12xsd, ediSchema);
    ediSchema.segments = rootSegGroupSchema.segments;
    check populateX12Envelope(ediSchema);
    return ediSchema;
}

// Builds the structured envelope for an X12 transaction set schema:
//   * interchange — ISA / IEA (inline definitions)
//   * group       — GS / GE (inline definitions)
//   * transaction — ST / SE (lifted out of `segments` where the XSD placed them)
// Returns an error if the XSD does not declare ST / SE — generating a closed
// envelope wrapper without transaction header/trailer segments would produce
// a schema that can never parse a conformant interchange.
function populateX12Envelope(edi:EdiSchema schema) returns error? {
    edi:EdiUnitSchema[] body = [];
    edi:EdiUnitSchema[] txnHeader = [];
    edi:EdiUnitSchema[] txnTrailer = [];

    foreach edi:EdiUnitSchema unit in schema.segments {
        string? code = getRefCode(unit, schema);
        if code == "ST" {
            txnHeader.push(unit);
        } else if code == "SE" {
            txnTrailer.push(unit);
        } else {
            body.push(unit);
        }
    }

    if txnHeader.length() == 0 || txnTrailer.length() == 0 {
        return error(string `Cannot generate envelope for ${schema.name}: ` +
                "the source XSD does not declare " +
                (txnHeader.length() == 0 ? "ST" : "SE") +
                " in the transaction set. An envelope without transaction " +
                "header/trailer segments cannot parse a conformant interchange.");
    }

    schema.segmentDefinitions["ISA"] = ISA_SEG;
    schema.segmentDefinitions["IEA"] = IEA_SEG;
    schema.segmentDefinitions["GS"] = GS_SEG;
    schema.segmentDefinitions["GE"] = GE_SEG;

    schema.segments = body;
    schema.envelope = {
        interchange: {
            header: [<edi:EdiUnitRef>{ref: "ISA", tag: "InterchangeControlHeader", minOccurances: 1, maxOccurances: 1}],
            trailer: [<edi:EdiUnitRef>{ref: "IEA", tag: "InterchangeControlTrailer", minOccurances: 1, maxOccurances: 1}]
        },
        group: {
            header: [<edi:EdiUnitRef>{ref: "GS", tag: "FunctionalGroupHeader", minOccurances: 1, maxOccurances: 1}],
            trailer: [<edi:EdiUnitRef>{ref: "GE", tag: "FunctionalGroupTrailer", minOccurances: 1, maxOccurances: 1}]
        },
        'transaction: {
            header: forceMandatoryX12(txnHeader),
            trailer: forceMandatoryX12(txnTrailer)
        }
    };
}

// ST and SE are lifted out of `segments[]` as-is and inherit whatever
// `minOccurances` the XSD specified (often 0). At the envelope level they
// are mandatory by definition, so promote them.
function forceMandatoryX12(edi:EdiUnitSchema[] units) returns edi:EdiUnitSchema[] {
    edi:EdiUnitSchema[] result = [];
    foreach edi:EdiUnitSchema u in units {
        if u is edi:EdiSegSchema {
            edi:EdiSegSchema promoted = u.clone();
            promoted.minOccurances = 1;
            result.push(promoted);
        } else if u is edi:EdiUnitRef {
            edi:EdiUnitRef promoted = u.clone();
            promoted.minOccurances = 1;
            result.push(promoted);
        } else {
            edi:EdiSegGroupSchema promoted = u.clone();
            promoted.minOccurances = 1;
            result.push(promoted);
        }
    }
    return result;
}

// Returns the segment code of an EdiUnitSchema entry, resolving an EdiUnitRef
// through `schema.segmentDefinitions` when needed.
function getRefCode(edi:EdiUnitSchema unit, edi:EdiSchema schema) returns string? {
    if unit is edi:EdiSegSchema {
        return unit.code;
    }
    if unit is edi:EdiUnitRef {
        edi:EdiSegSchema? def = schema.segmentDefinitions[unit.ref];
        return def?.code;
    }
    return ();
}

function convertFromX12WithHeaders(string inPath) returns edi:EdiSchema|error {
    string interchangePath = inPath + "/Interchange.xsd";
    xml interchangeXsd = check io:fileReadXml(interchangePath);
    xml elements = interchangeXsd/<xs:element>;
    xml root = elements[0];
    string rootName = "";
    do {
        rootName = check root.name;
    } on fail error e {
        return error("Root element name not found. " + root.toString(), e);
    }
    rootName = getBalCompatibleName(rootName);
    edi:EdiSchema ediSchema = {delimiters: {segment: "~", 'field: "*", component: ":"}, name: rootName, tag: rootName};
    if !rootName.startsWith("X12_") {
        return error("Invalid X12 schema");
    }
    edi:EdiSegGroupSchema rootSegGroupSchema = check convertSegmentGroup(root, interchangeXsd, ediSchema, inPath);
    ediSchema.segments = rootSegGroupSchema.segments;
    check populateX12EnvelopeFromHeaders(ediSchema);
    return ediSchema;
}

// Lifts the X12 envelope out of the nested `segments[]` produced by headers-mode
// conversion into the structured `envelope` field required by envelope-aware
// runtime APIs. Headers mode builds a fixed three-level nesting from the
// supplied Interchange/FunctionalGroup XSDs:
//   segments = [ISA, FunctionalGroup[GS, Transaction[ST, ...body..., SE], GE], IEA]
// Unlike the plain path (`populateX12Envelope`), the user supplies their own
// envelope segment definitions, so those are preserved as-is and only relocated.
function populateX12EnvelopeFromHeaders(edi:EdiSchema schema) returns error? {
    edi:EdiUnitSchema? isa = ();
    edi:EdiUnitSchema? iea = ();
    edi:EdiSegGroupSchema? functionalGroup = ();
    foreach edi:EdiUnitSchema unit in schema.segments {
        string? code = getRefCode(unit, schema);
        if code == "ISA" {
            isa = unit;
        } else if code == "IEA" {
            iea = unit;
        } else if unit is edi:EdiSegGroupSchema {
            functionalGroup = unit;
        }
    }
    if isa is () || iea is () {
        return error(string `Cannot generate envelope for ${schema.name}: interchange ` +
                "control header (ISA) or trailer (IEA) not found in the schema.");
    }
    if functionalGroup is () {
        return error(string `Cannot generate envelope for ${schema.name}: functional ` +
                "group not found in the schema.");
    }

    edi:EdiUnitSchema? gs = ();
    edi:EdiUnitSchema? ge = ();
    edi:EdiSegGroupSchema? 'transaction = ();
    foreach edi:EdiUnitSchema unit in functionalGroup.segments {
        string? code = getRefCode(unit, schema);
        if code == "GS" {
            gs = unit;
        } else if code == "GE" {
            ge = unit;
        } else if unit is edi:EdiSegGroupSchema {
            'transaction = unit;
        }
    }
    if gs is () || ge is () {
        return error(string `Cannot generate envelope for ${schema.name}: functional ` +
                "group header (GS) or trailer (GE) not found in the schema.");
    }
    if 'transaction is () {
        return error(string `Cannot generate envelope for ${schema.name}: transaction ` +
                "set not found within the functional group.");
    }

    edi:EdiUnitSchema? st = ();
    edi:EdiUnitSchema? se = ();
    edi:EdiUnitSchema[] body = [];
    foreach edi:EdiUnitSchema unit in 'transaction.segments {
        string? code = getRefCode(unit, schema);
        if code == "ST" {
            st = unit;
        } else if code == "SE" {
            se = unit;
        } else {
            body.push(unit);
        }
    }
    if st is () || se is () {
        return error(string `Cannot generate envelope for ${schema.name}: transaction set ` +
                "header (ST) or trailer (SE) not found in the schema.");
    }

    schema.envelope = {
        interchange: {
            header: forceMandatoryX12([isa]),
            trailer: forceMandatoryX12([iea])
        },
        group: {
            header: forceMandatoryX12([gs]),
            trailer: forceMandatoryX12([ge])
        },
        'transaction: {
            header: forceMandatoryX12([st]),
            trailer: forceMandatoryX12([se])
        }
    };
    schema.segments = body;
}

function convertSegmentGroup(xml segmentGroup, xml x12xsd, edi:EdiSchema schema, string dirPath = "", int parentMinOccur = 0, int parentMaxOccur = 1) returns edi:EdiSegGroupSchema|error {
    xml elements = segmentGroup/<xs:complexType>/<xs:sequence>/<xs:element>;
    string tag = "";
    do {
        tag = check segmentGroup.name;
    } on fail error e {
        return error("Segment group name not found. " + segmentGroup.toString(), e);
    }
    tag = getBalCompatibleName(tag);
    int segMinOccur = segmentGroup.minOccurs is string ? check int:fromString(check segmentGroup.minOccurs) : parentMinOccur;
    int segMaxOccur = segmentGroup.maxOccurs is string ? check segmentGroup.maxOccurs == "unbounded" ? -1 : check int:fromString(check segmentGroup.maxOccurs) : parentMaxOccur;
    edi:EdiSegGroupSchema segGroupSchema = {tag: tag, minOccurances: segMinOccur, maxOccurances: segMaxOccur};
    foreach xml element in elements {
        string ref = check element.ref;
        int eleMinOccur = element.minOccurs is string ? check int:fromString(check element.minOccurs) : 0;
        int eleMaxOccur = element.maxOccurs is string ? check element.maxOccurs == "unbounded" ? -1 : check int:fromString(check element.maxOccurs) : 1;

        if ref.startsWith("X12_") {
            schema.name = ref;
            schema.tag = ref;
            xml innerX12xsd = check readInnerX12xsd(x12xsd, dirPath);
            xml rootElement = check validateAndGetRootEelement(innerX12xsd);
            edi:EdiSegGroupSchema innerSegGroupSchema = check convertSegmentGroup(rootElement, innerX12xsd, schema, dirPath);
            segGroupSchema.segments.push(innerSegGroupSchema);
        }
        else if ref.startsWith("Loop_") {
            xml segGroupElement = check getUnitElement(ref, x12xsd);
            edi:EdiSegGroupSchema childSegGroupSchema = check convertSegmentGroup(segmentGroup = segGroupElement, x12xsd = x12xsd, schema = schema, parentMaxOccur = eleMaxOccur, parentMinOccur = eleMinOccur);
            segGroupSchema.segments.push(childSegGroupSchema);
        } else {
            if !schema.segmentDefinitions.hasKey((ref)) {
                edi:EdiSegSchema segSchema = check convertSegment(ref, eleMinOccur, eleMaxOccur, x12xsd);
                schema.segmentDefinitions[ref] = segSchema;
            }
            edi:EdiUnitRef segRef = {ref: ref, minOccurances: eleMinOccur, maxOccurances: eleMaxOccur};
            segGroupSchema.segments.push(segRef);
        }
    }
    return segGroupSchema;
}

function convertSegment(string segmentName, int minOccurs, int maxOccurs, xml x12xsd) returns edi:EdiSegSchema|error {
    xml segElement = check getUnitElement(segmentName, x12xsd);
    string:RegExp underscorePlaceholder = re `_`;
    string[] nameParts = underscorePlaceholder.split(segmentName);
    edi:EdiSegSchema segSchema =
        {code: getBalCompatibleName(nameParts[0]), tag: getBalCompatibleName(nameParts[1]), minOccurances: minOccurs, maxOccurances: maxOccurs};
    segSchema.fields.push({tag: "code", required: true});
    xml fieldElements = segElement/<xs:complexType>/<xs:sequence>/<xs:element>;
    foreach xml fieldElement in fieldElements {
        string fieldName = "";
        do {
            fieldName = check fieldElement.name;
        } on fail error e {
            return error(string `Field name not found. Segment: ${segmentName}, Field: ${fieldElement.toString()}`, e);
        }
        fieldName = getBalCompatibleName(fieldName);
        edi:EdiFieldSchema fieldSchema = {tag: fieldName, required: true};
        string|error fieldMinOccurs = fieldElement.minOccurs;
        if (fieldMinOccurs is string) {
            fieldSchema.required = fieldMinOccurs != "0";
        }
        if conditionalFeildsMap.length() > 0 {
            string[] nameSplit = underscorePlaceholder.split(fieldName);
            if conditionalFeildsMap.hasKey(nameSplit[0]) {
                fieldSchema.required = false;
            }
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
        string compositeFieldName = "";
        do {
            compositeFieldName = check compositeElement.name;
        } on fail error e {
            return error(string `Composite field name not found. Segment: ${segmentName}, Field: ${fieldName}, Composite field: ${compositeElement.toString()}`, e);
        }
        compositeFieldName = getBalCompatibleName(compositeFieldName);
        edi:EdiComponentSchema compositeFieldSchema = {tag: compositeFieldName, required: true};
        string|error compositeMinOccurs = compositeElement.minOccurs;
        if compositeMinOccurs is string {
            compositeFieldSchema.required = compositeMinOccurs != "0";
        }
        if conditionalFeildsMap.length() > 0 {
            string:RegExp underscorePlaceholder = re `_`;
            string[] nameSplit = underscorePlaceholder.split(compositeFieldName);
            if conditionalFeildsMap.hasKey(nameSplit[0]) {
                compositeFieldSchema.required = false;
            }
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
        "ID"|"AN"|"DT"|"TM"|"R" => {
            return edi:STRING;
        }
        "N"|"N0"|"N2" => {
            return edi:FLOAT;
        }
        "N1" => {
            return edi:INT;
        }
        _ => {
            return error("Unknown data type.");
        }
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

public function getBalCompatibleName(string rawName) returns string {
    string name = rawName.trim();
    string:RegExp nonAlphanumericUnderscore = re `[^a-zA-Z0-9_]`;
    string:RegExp startsWithLetter = re `^[a-zA-Z].*`;
    name = nonAlphanumericUnderscore.replaceAll(name, "_");
    if !startsWithLetter.isFullMatch(name) {
        name = "A_" + name;
    }
    return name;
}

function readInnerX12xsd(xml x12xsd, string dirPath) returns xml|error {
    xml include = x12xsd/<xs:include>;
    string schemaLocation = check include.schemaLocation;
    string schemaFilePath = dirPath + "/" + schemaLocation;
    xml innerX12xsd = check io:fileReadXml(schemaFilePath);
    return innerX12xsd;
}

function validateAndGetRootEelement(xml xsdFileContent) returns xml|error {
    xml elements = xsdFileContent/<xs:element>;
    xml root = elements[0];
    do {
        _ = check root.name;
    } on fail error e {
        return error("Root element name not found. " + root.toString(), e);
    }
    return root;
}

function loadConditionalFieldsMap(string segdetlPath) {
    boolean|file:Error segdetlExisits = file:test(segdetlPath, file:EXISTS);
    if segdetlPath == "" || segdetlExisits is file:Error || !segdetlExisits {
        io:println("Segment details not found. This might affect the accuracy of the requried state of fields.");
        return;
    }
    stream<string[], io:Error?>|io:Error csvStream = io:fileReadCsvAsStream(segdetlPath);
    if (csvStream is io:Error) {
        io:println("Error reading segment details. This might affect the accuracy of the requried state of fields.");
        return;
    }
    map<string> fieldsMap = {};
    io:Error? forEach = csvStream.forEach(function(string[] val) {
        if (val[3] == "C") {
            fieldsMap[val[0] + val[1]] = val[3];
        }
    });
    if forEach is io:Error {
        io:println("Error reading segment details. This might affect the accuracy of the requried state of fields.");
        return;
    }
    io:println("Segment details loaded successfully from " + segdetlPath);
    conditionalFeildsMap = fieldsMap;
};
