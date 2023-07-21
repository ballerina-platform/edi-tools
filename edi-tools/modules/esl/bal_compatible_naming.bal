import ballerina/regex;
import ballerina/log;
import ballerina/edi;

map<int> recordNames = {};

public function fixSchema(edi:EdiSchema schema) returns error? {
    foreach edi:EdiSegSchema segSchema in schema.segmentDefinitions {
        check fixSegment(segSchema);
    }
    edi:EdiSegGroupSchema rootSchema = {tag: schema.tag, segments: schema.segments};
    check fixSegmentGroup(rootSchema, schema);
}

public function fixSegmentGroup(edi:EdiSegGroupSchema groupSchema, edi:EdiSchema schema) returns error? {
    map<int> fieldNames = {};
    foreach edi:EdiUnitSchema unit in groupSchema.segments {
        if unit is edi:EdiSegSchema {
            string tag = unit.tag;
            int? count = fieldNames[tag];
            if count == () {
                fieldNames[tag] = 1;
            } else {
                fieldNames[tag] = count + 1;
                unit.tag = tag + "_" + count.toString();
                log:printInfo(string `Renamed segment to avoid name conflict in segment group. 
                    Segment group: ${groupSchema.tag}, Segment: ${tag}, Count: ${count}`);
            }
            check fixSegment(unit);
        } else if unit is edi:EdiUnitRef {
            edi:EdiSegSchema? segSchema = schema.segmentDefinitions[unit.ref];
            if segSchema is () {
                return error("Segment definition not found for " + unit.ref);
            }
            string tag = segSchema.tag;
            int? count = fieldNames[tag];
            if count == () {
                fieldNames[tag] = 1;
            } else {
                fieldNames[tag] = count + 1;
                unit.tag = tag + "_" + count.toString();
                log:printInfo(string `Renamed segment (reference) to avoid name conflict in segment group. 
                    Segment group: ${groupSchema.tag}, Segment: ${tag}, Count: ${count}`);
            }
        } else {
            check fixSegmentGroup(unit, schema);
        }
    }
}

function fixSegment(edi:EdiSegSchema segSchema) returns error? {
    map<int> fieldNames = {};
    foreach edi:EdiFieldSchema 'field in segSchema.fields {
        string tag = 'field.tag;
        int? count = fieldNames[tag];
        if count == () {
            fieldNames[tag] = 1;
        } else {
            fieldNames[tag] = count + 1;
            'field.tag = tag + "_" + count.toString();
            log:printInfo(string `Renamed field to avoid name conflict in segment. 
                    Segment: ${segSchema.tag}, field: ${tag}, Count: ${count}`);
        }
        check fixComposite('field);
    }
}

function fixComposite(edi:EdiFieldSchema fieldSchema) returns error? {
    map<int> fieldNames = {};
    foreach edi:EdiComponentSchema component in fieldSchema.components {
        string tag = component.tag;
        int? count = fieldNames[tag];
        if count == () {
            fieldNames[tag] = 1;
        } else {
            fieldNames[tag] = count + 1;
            component.tag = tag + "_" + count.toString();
            log:printInfo(string `Renamed component to avoid name conflict in composite field. 
                    Field: ${fieldSchema.tag}, component: ${tag}, Count: ${count}`);
        }
    }
}

public function getBalCompatibleName(string rawName) returns string {
    string name = rawName.trim();
    name = regex:replaceAll(name, "[^a-zA-Z1-9_]", "_");
    if !regex:matches(name, "^[a-zA-Z].*") {
        name = "A_" + name;
    }
    return name;
}