import ballerina/io;
import editools.x12xsd;
import ballerina/file;
import editools.esl;
import editools.codegen;

public function main(string[] args) returns error? {

    string usage = string `Ballerina EDI tools -
        Ballerina code generation for edi schema: bal edi codegen -s <schema json path> -o <output bal file path>
        EDI library generation: bal edi libgen -O <org name> -n <library name> -s <EDI schema folder> -o <output folder>`;

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

    } else if mode == "convertESL" {
        string eslPath = args[1].trim();
        string basedefPath = args[2].trim();
        string outputPath = args[3].trim();
        check esl:convertEsl(eslPath, basedefPath, outputPath);

    } else if mode == "convertX12Schema" {
        string inputPath = args[1].trim();
        string outputPath = args[2].trim();
        boolean inputDir = check file:test(inputPath, file:IS_DIR);
        boolean outputDir = check file:test(outputPath, file:IS_DIR);

        if inputDir && outputDir {
            file:MetaData[] inFiles = check file:readDir(inputPath);
            foreach file:MetaData inFile in inFiles {
                string ediName = check file:basename(inFile.absPath);
                if ediName.endsWith(".xsd") {
                    ediName = ediName.substring(0, ediName.length() - ".xsd".length());
                }
                check x12xsd:convertFromX12XsdAndWrite(inFile.absPath, check file:joinPath(outputPath, ediName + ".json"));
            }
        } else if !inputDir && !outputDir {
            check x12xsd:convertFromX12XsdAndWrite(inputPath, outputPath);
        } else {
            io:println("Both input and output should be either directories or files");
        }
    } else {
        io:println(usage);
    }
}
