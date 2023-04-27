import ballerina/io;

type EDIContext record {|
    EDISchema schema;
    int rawIndex = 0;
    string[] rawSegments = [];
|};

# Reads EDI texts into JSON according to the given schema.
# Each EDI document type (e.g. X12 834) can have a separate EDIReader initialized with its schema.
public class EDIReader {

    EDISchema schema;
    SegmentGroupReader segmentGroupReader = new ();

    # Initializes the EDIReader with an EDI schema
    #
    # + schema - Schema of the EDI type to be processed using the reader.
    # + return - Error is returned if the given schema is not valid.
    public function init(string|json|EDISchema schema) returns error? {

        if schema is string {
            io:StringReader sr = new (schema);
            json schemaJson = check sr.readJson();
            self.schema = check schemaJson.cloneWithType(EDISchema);
        } else {
            self.schema = check schema.cloneWithType(EDISchema);
        }
    }

    # Reads the given EDI text according the provided schema
    #
    # + ediText - EDI text to be read
    # + return - JSON variable containing EDI data. Error if the reading fails.
    public function readEDI(string ediText) returns json|error {
        EDIContext context = {schema: self.schema};
        EDIUnitSchema[] currentMapping = context.schema.segments;
        string[] segmentsDesc = splitSegments(ediText, context.schema.delimiters.segment);
        context.rawSegments = segmentsDesc;
        EDISegmentGroup rootGroup = check self.segmentGroupReader.read(currentMapping, context, true);
        return rootGroup.toJson();
    }

}
