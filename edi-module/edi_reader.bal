import ballerina/io;

type EDIContext record {|
    EDIMapping schema;
    int rawIndex = 0;
    string[] rawSegments = [];
|}; 

class EDIReader {

    EDIMapping schema;
    SegmentGroupReader segmentGroupReader = new();

    function init(string|json|EDIMapping schema) returns error? {

        if schema is string {
            io:StringReader sr = new(schema);
            json schemaJson = check sr.readJson();
            self.schema = check schemaJson.cloneWithType(EDIMapping);
        } else {
            self.schema = check schema.cloneWithType(EDIMapping);
        } 
    }

    public function readEDI(string ediText) returns json|error {
        EDIContext context = {schema: self.schema};
        EDIUnitMapping[] currentMapping = context.schema.segments;
        string[] segmentsDesc = splitSegments(ediText, context.schema.delimiters.segment);
        context.rawSegments = segmentsDesc;
        EDISegmentGroup rootGroup = check self.segmentGroupReader.read(currentMapping, context, true);
        return rootGroup.toJson();
    }
    
}