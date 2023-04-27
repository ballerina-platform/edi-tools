import ballerina/io;

# Writes JSON variables into EDI texts according to the given schema.
# Each EDI document type (e.g. X12 834) can have a separate EDIWriter initialized with its schema.
public class EDIWriter {

    EDISchema schema;
    SegmentGroupWriter segmentGroupSerializer;

    # Initializes the EDIWriter with an EDI schema
    #
    # + schema - Schema of the EDI type to be processed using the writer.
    # + return - Error is returned if the given schema is not valid.
    public function init(string|json|EDISchema schema) returns error? {
        if schema is string {
            io:StringReader sr = new (schema);
            json schemaJson = check sr.readJson();
            self.schema = check schemaJson.cloneWithType(EDISchema);
        } else {
            self.schema = check schema.cloneWithType(EDISchema);
        }
        self.segmentGroupSerializer = new (self.schema);
    }

    # Writes the given JSON varibale into a EDI text according the provided schema
    #
    # + msg - JSON value to be written into EDI
    # + return - EDI text containing the data provided in the JSON variable. Error if the reading fails.
    public function writeEDI(json msg) returns string|error {
        string[] ediText = [];
        if !(msg is map<json>) {
            return error(string `Input is not compatible with the schema.`);
        }
        check self.segmentGroupSerializer.serialize(msg, self.schema, ediText);
        string ediOutput = "";
        foreach string s in ediText {
            ediOutput += s + (self.schema.delimiters.segment == "\n" ? "" : "\n");
        }
        return ediOutput;
    }
}
