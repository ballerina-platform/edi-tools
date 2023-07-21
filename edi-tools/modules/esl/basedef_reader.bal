import ballerina/io;
import ballerina/log;
import ballerina/edi;

type CompositeSchema record {|
    string tag;
    edi:EdiComponentSchema[] components = [];
|};

type ElementDef record {|
    string tag;
    edi:EdiDataType dataType;
|};

public function readSegmentSchemas(json basedef) returns map<edi:EdiSegSchema>|error {
    map<ElementDef> elements = check readFieldDefinitions(basedef);
    map<CompositeSchema> composites = check readCompositeDefinitions(basedef, elements);
    json|error segDefs = basedef.segments;
    if segDefs !is json[] {
        return error("Invalid segment definitions. " + (segDefs is error? segDefs.message() : segDefs.toString()));
    }
    map<edi:EdiSegSchema> segmentSchemas = {};
    foreach json segDef in segDefs {
        var segName = segDef.name;
        if segName !is string {
            return error("Segment name is required. " + segDef.toString());
        }
        var segCode = segDef.id;
        if segCode !is string {
            return error("Segment code is required. " + segDef.toString());
        }
        log:printDebug("Reading segment: " + segCode);
        edi:EdiSegSchema segSchema = {code: segCode, tag: getBalCompatibleName(segName)};
        json|error segFields = segDef.values;
        if segFields !is json[] {
            return error("Invalid segment field definitions. " + (segFields is error? segFields.message() : segFields.toString()));
        }
        edi:EdiFieldSchema codeField = {
            tag: "code",
            dataType: edi:STRING,
            required: true
        };
        segSchema.fields.push(codeField);
        foreach json segField in segFields {
            log:printDebug("Reading field ref: " + segField.toString());
            string id = check segField.idRef;
            if id.startsWith("C") {
                CompositeSchema? compositeDef = composites[id];
                if compositeDef is () {
                    return error(string `Composite definition not found. composite id: ${id}, segment: ${segCode}`);
                }
                edi:EdiFieldSchema fieldSchema = {
                    tag: compositeDef.tag,
                    dataType: edi:COMPOSITE,
                    required: check segField.usage == "M",
                    components: compositeDef.components
                };
                segSchema.fields.push(fieldSchema);
            } else {
                ElementDef? elementDef = elements[id];
                if elementDef is () {
                    return error(string `Field definition not found. field id: ${id}, segment: ${segCode}`);
                }
                edi:EdiFieldSchema fieldSchema = {
                    tag: elementDef.tag,
                    dataType: elementDef.dataType,
                    required: check segField.usage == "M"
                };
                segSchema.fields.push(fieldSchema);
            }
            io:println(segField);
        }
        segmentSchemas[segCode] = segSchema;
    }
    return segmentSchemas;
}

function readFieldDefinitions(json basedef) returns map<ElementDef>|error {
    map<ElementDef> elementDefs = {};
    json fieldDefinitions = check basedef.elements;
    if fieldDefinitions !is json[] {
        return error("Invalid field definitions. " + fieldDefinitions.toString());
    }
    foreach json fieldDef in fieldDefinitions {
        log:printDebug("Reading field definition: " + fieldDef.toString());
        ElementDef fieldSchema = {
            tag: getBalCompatibleName(check fieldDef.name),
            dataType: getDataType(check fieldDef.'type)
        };
        elementDefs[check fieldDef.id] = fieldSchema;
    }
    return elementDefs;
}

function readCompositeDefinitions(json basedef, map<ElementDef> elements) returns map<CompositeSchema>|error {
    map<CompositeSchema> compositeSchemas = {};
    json compositeDefinitions = check basedef.composites;
    if compositeDefinitions !is json[] {
        return error("Invalid composite definitions. " + compositeDefinitions.toString());
    }
    foreach json compositeDef in compositeDefinitions {
        log:printDebug("Reading composite definition: " + compositeDef.toString());
        CompositeSchema compositeSchema = {
            tag: getBalCompatibleName(check compositeDef.name)
        };
        json componentDefs = check compositeDef.values;
        if componentDefs !is json[] {
            return error("Invalid component definitions. " + componentDefs.toString());
        }
        foreach json componentDef in componentDefs {
            ElementDef? elementDef = elements[check componentDef.idRef];
            if elementDef is () {
                return error("Component definition of composite not found. " + componentDef.toString());
            }
            edi:EdiComponentSchema componentSchema = {
                tag: elementDef.tag,
                dataType: elementDef.dataType,
                required: check componentDef.usage == "M"
            };
            compositeSchema.components.push(componentSchema);
        }
        compositeSchemas[check compositeDef.id] = compositeSchema;
    }
    return compositeSchemas;
}

function getDataType(string dataTypeValue) returns edi:EdiDataType {
    return edi:STRING;
}

