import ballerina/io;
import ballerina/edi;
import editools.codegen;

public function main(string[] args) returns error? {

    string usage = string `Ballerina EDI tools -
        Ballerina code generation for edi mapping: java -jar edi.jar codegen <mapping json path> <output bal file path>
        Smooks to json mapping conversion: java -jar edi.jar smooksToBal <smooks mapping xml path> <mapping json path>
        ESL to json mapping conversion: java -jar edi.jar eslToBal <ESL file path or directory> <ESL segment definitions path> <output json path or directory>
        EDI library generation: java -jar edi.jar libgen <org name> <library name> <EDI mappings folder> <output folder>`;

    if args.length() == 0 {
        io:println(usage);
        return;
    }

    string mode = args[0].trim();
    if mode == "codegen" {
        if args.length() != 3 {
            io:println(usage);
            return;
        }
        json mappingJson = check io:fileReadJson(args[1].trim());
        edi:EDISchema mapping = check edi:getSchema(mappingJson);
        check codegen:generateCodeToFile(mapping, args[2].trim());
    } else if mode == "libgen" {
        if args.length() != 5 {
            io:println(usage);
            return;
        }
        codegen:LibData libdata = {
            orgName: args[1],
            libName: args[2],
            schemaPath: args[3],
            outputPath: args[4]
        };
        check codegen:generateLibrary(libdata);
    } else {
        io:println(usage);
    }
}
