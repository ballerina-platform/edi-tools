import ballerina/io;
import editools.codegen;

public function main(string[] args) returns error? {

    string usage = string `Ballerina EDI tools -
        Ballerina code generation for edi schema: java -jar edi.jar codegen <schema json path> <output bal file path>
        EDI library generation: java -jar edi.jar libgen <org name> <library name> <EDI schema folder> <output folder>`;

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
        check codegen:generateCodeForSchema(mappingJson, args[2].trim());
    } else if mode == "libgen" {
        if !(args.length() == 5 || args.length() == 6) {
            io:println(usage);
            return;
        }
        codegen:LibData libdata = {
            orgName: args[1],
            libName: args[2],
            schemaPath: args[3],
            outputPath: args[4],
            versioned: args.length() == 6 ? true : false
        };
        check codegen:generateLibrary(libdata);
    } else {
        io:println(usage);
    }
}
