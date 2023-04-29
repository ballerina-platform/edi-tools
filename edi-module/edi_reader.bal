import ballerina/io;

# Reads EDI texts into JSON according to the given schema.
# Each EDI document type (e.g. X12 834) can have a separate EDIReader initialized with its schema.
public class EDIReader {

    EDISchema schema;

    # Initializes the EDIReader with an EDI schema
    #
    # + schema - Schema of the EDI type to be processed using the reader.
    # + return - Error is returned if the given schema is not valid.
    public isolated function init(string|json|EDISchema schema) returns error? {

        if schema is string {
            io:StringReader sr = new (schema);
            json schemaJson = check sr.readJson();
            self.schema = check schemaJson.cloneWithType(EDISchema);
        } else {
            self.schema = check schema.cloneWithType(EDISchema);
        }
    }

    

}
