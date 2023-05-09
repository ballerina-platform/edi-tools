import ballerina/file;
import ballerina/io;
import ballerina/edi;

public type LibData record {|
    string orgName = "";
    string libName = "";
    string outputPath = "";
    string schemaPath = "";

    string libPath = "";
    string importsBlock = "";
    string exportsBlock = "";
    string enumBlock = "";
    string readProcessors = "";
    string writeProcessors = "";
    string[] ediNames = [];
|};

# Generates a Ballerina library project containing:
# - Ballerina records for all provided schemas
# - Utility functions to work with EDI files of given schemas
# - REST connector to process EDI files of given schemas
#
# + libdata - Data structure containing the following inputs for the library: orgName, libName, outputPath, schemaPath
# + return - Returns error if library generation is not successful
public function generateLibrary(LibData libdata) returns error? {
    check createLibStructure(libdata);
    check generateCodeFromFileBasedSchemas(libdata);
    check createBalLib(libdata);
}

function createLibStructure(LibData libdata) returns error? {
    libdata.libPath = check file:joinPath(libdata.outputPath, libdata.libName);
    if check file:test(libdata.libPath, file:EXISTS) {
        file:MetaData[] files = check file:readDir(libdata.libPath);
        if files.length() > 0 {
            return error(string `Target library path ${libdata.libPath} is not empty. Please provide an empty directory to create the library.`);
        }
    } else {
        check file:createDir(libdata.libPath, file:RECURSIVE);
    }
    libdata.exportsBlock = "\"" + libdata.libName + "\"";
    check copyNonTemplatedFiles(libdata);
}

function generateCodeFromFileBasedSchemas(LibData libdata) returns error? {
    file:MetaData[] schemaFiles = check file:readDir(libdata.schemaPath);
    foreach file:MetaData schemaFile in schemaFiles {
        string ediName = check file:basename(schemaFile.absPath);
        if ediName.endsWith(".json") {
            ediName = ediName.substring(0, ediName.length() - ".json".length());
        }
        json schemaJson = check io:fileReadJson(schemaFile.absPath);
        check generateEDIFileSpecificCode(ediName, schemaJson, libdata);
    }
}

function createBalLib(LibData libdata) returns error? {
    string mainCode = generateMainCode(libdata);
    string mainBalName = check file:joinPath(libdata.libPath, libdata.libName + ".bal");
    check io:fileWriteString(mainBalName, mainCode);

    string restConnectorFilePath = check file:joinPath(libdata.libPath, "rest_connector.bal");
    check io:fileWriteString(restConnectorFilePath, generateRESTConnector(libdata.libName));

    string balTomlPath = check file:joinPath(libdata.libPath, "Ballerina.toml");
    check io:fileWriteString(balTomlPath, generateBallerinaToml(libdata));
}

function copyNonTemplatedFiles(LibData libdata) returns error? {
    check writeLibFile(packageText, "Package.md", libdata);
    check writeLibFile(ModuleMdText, "Module.md", libdata);

    check file:createDir(check file:joinPath(libdata.outputPath, "secrets"), file:RECURSIVE);
    check io:fileWriteString(check file:joinPath(libdata.outputPath, "secrets", "secrets.toml"), generateConfigText(libdata.libName));
}

function generateEDIFileSpecificCode(string ediName, json mappingJson, LibData libdata) returns error? {
    libdata.ediNames.push(ediName);
    edi:EDISchema ediMapping = check mappingJson.cloneWithType(edi:EDISchema);
    ediMapping.name = "EDI_" + ediName + "_" + ediMapping.name;

    string modulePath = check file:joinPath(libdata.libPath, "modules", "m" + ediName);
    check file:createDir(modulePath, file:RECURSIVE);

    string recordsPath = check file:joinPath(modulePath, "G_" + ediName + ".bal");
    check generateCodeToFile(ediMapping, recordsPath);

    string transformer = generateTransformerCode(ediName, ediMapping.name);
    check io:fileWriteString(check file:joinPath(modulePath, "transformer.bal"), transformer);

    libdata.importsBlock += "\n" + string `import ${libdata.libName}.m${ediName};`;
    libdata.exportsBlock += ",\"" + libdata.libName + ".m" + ediName + "\"";
    libdata.enumBlock += string `${libdata.enumBlock.length() > 0 ? ", " : ""}EDI_${ediName} = "${ediName}"`;
    libdata.readProcessors += (libdata.readProcessors.length() > 0 ? ",\n" : "") +
        string `    "${ediName}": m${ediName}:processRead${ediName}`;
    libdata.writeProcessors += (libdata.writeProcessors.length() > 0 ? ",\n" : "") +
        string `    "${ediName}": m${ediName}:processWrite${ediName}`;
}

function writeLibFile(string content, string targetName, LibData libdata) returns error? {
    error? e = io:fileWriteString(check file:joinPath(libdata.libPath, targetName), content, io:OVERWRITE);
    if e is error {
        return error("Failed to write non-templated file: '" + content.substring(0, 20) + "...' to " + targetName + ". " + e.message());
    }
}
