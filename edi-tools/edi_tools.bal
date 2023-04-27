import ballerina/io;
import ballerinax/edi;
import editools.codegen;

public function main(string[] args) returns error? {

    string usage = string `Usage:
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
        json mappingText = check io:fileReadJson(args[1].trim());
        edi:EDISchema mapping = check mappingText.cloneWithType(edi:EDISchema);  
        check codegen:generateCodeToFile(mapping, args[2].trim());    
    } else if mode == "libgen" {
        if args.length() != 5 {
            io:println(usage);
            return;
        }
        string orgName = args[1];
        string libName = args[2];
        string ediMappingFolder = args[3];
        string outputPath = args[4];
        codegen:LibGen g = check new(orgName, libName, outputPath, ediMappingFolder, "");
        check g.generateLibrary();
    } else {
        io:println(usage);
    }
}
