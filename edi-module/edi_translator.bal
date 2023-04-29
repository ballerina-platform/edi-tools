import ballerina/io;

type EDIContext record {|
    EDISchema schema;
    string[] ediText = [];
    int rawIndex = 0;
|};

# Reads the given EDI text according to the provided schema
#
# + ediText - EDI text to be read
# + schema - Schema of the EDI text
# + return - JSON variable containing EDI data. Error if the reading fails.
public function read(string ediText, EDISchema schema) returns json|Error {
    EDIContext context = {schema: schema};
    EDIUnitSchema[] currentMapping = context.schema.segments;
    context.ediText = splitSegments(ediText, context.schema.delimiters.segment);
    EDISegmentGroup rootGroup = check readSegmentGroup(currentMapping, context, true);
    return rootGroup.toJson();
}

# Writes the given JSON varibale into a EDI text according to the provided schema
#
# + msg - JSON value to be written into EDI
# + schema - Schema of the EDI text
# + return - EDI text containing the data provided in the JSON variable. Error if the reading fails.
public function write(json msg, EDISchema schema) returns string|Error {
    EDIContext context = {schema: schema};
    if !(msg is map<json>) {
        return error(string `Input is not compatible with the schema.`);
    }
    check writeSegmentGroup(msg, schema, context);
    string ediOutput = "";
    foreach string s in context.ediText {
        ediOutput += s + (schema.delimiters.segment == "\n" ? "" : "\n");
    }
    return ediOutput;
}

# Creates an EDI schema from a string or a JSON.
#
# + schema - Schema of the EDI type 
# + return - Error is returned if the given schema is not valid.
public isolated function getSchema(string|json schema) returns EDISchema|error {
    if schema is string {
        io:StringReader sr = new (schema);
        json schemaJson = check sr.readJson();
        return schemaJson.cloneWithType(EDISchema);
    } else {
        return schema.cloneWithType(EDISchema);
    }
}