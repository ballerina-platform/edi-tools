// import ballerina/io;
// import ballerina/file;
// import ballerina/edi;

// type LibData record {|
//     string orgName = "";
//     string libName = "";
//     string outputPath = "";
//     string schemaPath = "";
//     string libPath = "";
//     string importsBlock = "";
//     string exportsBlock = "";
//     string enumBlock = "";
//     string ediFunctions = "";
//     string selectionBlocks = "";
//     string token = "";
//     string[] ediNames = [];
// |};

// # Generates a Ballerina library project containing:
// # - Record files for all provided schemas
// # - Utility functions to work with EDI files of given schemas
// # - REST connector to process EDI files of given schemas
// public class LibGen {

//     string orgName = "";
//     string libName = "";
//     string outputPath = "";
//     string schemaPath = "";
//     string libPath = "";
//     string importsBlock = "";
//     string exportsBlock = "";
//     string enumBlock = "";
//     string ediFunctions = "";
//     string selectionBlocks = "";
//     string token = "";
//     string[] ediNames = [];

//     public function init(string orgName, string libName, string outputPath, string schemaPath, string token) returns error? {
//         self.orgName = orgName;
//         self.libName = libName;
//         self.schemaPath = schemaPath;
//         self.outputPath = outputPath;
//         self.libPath =  check file:joinPath(outputPath, libName);
//         self.exportsBlock = "export=[\"" + libName + "\"";
//         self.token = token;
//     }

//     public function generateLibrary() returns error? {
//         check self.createLibStructure();
//         check self.generateCodeFromFileBasedSchemas();
//         check self.copyNonTemplatedFiles();
//         check self.createBalLib();
//     }

//     function generateCodeFromFileBasedSchemas() returns error? {
//         file:MetaData[] mappingFiles = check file:readDir(self.schemaPath);
//         foreach file:MetaData mappingFile in mappingFiles {
//             string ediName = check file:basename(mappingFile.absPath);
//             if ediName.endsWith(".json") {
//                 ediName = ediName.substring(0, ediName.length() - ".json".length());
//             }
//             json mappingJson = check io:fileReadJson(mappingFile.absPath);
//             check self.generateEDIFileSpecificCode(ediName, mappingJson);
//         }
//     }

//     function createBalLib() returns error? {
//         string selectorCode = self.generateLibraryMainCode();
//         string mainBalName = check file:joinPath(self.libPath, self.libName + ".bal");
//         check io:fileWriteString(mainBalName, selectorCode, io:OVERWRITE);    

//         string restConnectorFilePath = check file:joinPath(self.libPath, "restConnector.bal");
//         check io:fileWriteString(restConnectorFilePath, generateRESTConnector(self.libName));    

//         // add export package names to the Ballerina.toml file
//         string ballerinaTomlPath = check file:joinPath(self.libPath, "Ballerina.toml");
//         self.exportsBlock += "]";
//         check io:fileWriteString(ballerinaTomlPath, self.exportsBlock, io:APPEND);
//     }

//     function copyNonTemplatedFiles() returns error? {
//         check self.writeLibFile(packageText, "Package.md");
//         check self.writeLibFile(ModuleMdText, "Module.md");

//         check file:createDir(check file:joinPath(self.outputPath, "secrets"), file:RECURSIVE);
//         check io:fileWriteString(check file:joinPath(self.outputPath, "secrets", "secrets.toml"), generateConfigText(self.libName));
//     }

//     function writeLibFile(string content, string targetName) returns error? {
//         error? e = io:fileWriteString(check file:joinPath(self.libPath, targetName), content, io:OVERWRITE);
//         if e is error {
//             return error("Failed to write non-templated file: '" + content.substring(0, 20) + "...' to " + targetName + ". " + e.message());
//         }
//     }

//     function generateEDIFileSpecificCode(string ediName, json mappingJson) returns error? {
//         self.ediNames.push(ediName);
//         edi:EDISchema ediMapping = check mappingJson.cloneWithType(edi:EDISchema);

//         string modulePath = check file:joinPath(self.libPath, "modules", "m" + ediName);
//         check file:createDir(modulePath, file:RECURSIVE);

//         string recordsPath = check file:joinPath(modulePath, "G_" + ediName + ".bal");
//         check generateCodeToFile(ediMapping, recordsPath);

//         string transformer = self.generateTransformerCode(ediName, ediMapping.name);
//         check io:fileWriteString(check file:joinPath(modulePath, "transformer.bal"), transformer);

//         self.ediFunctions += self.generateEDITypeFunctions(ediName, ediMapping.name);
//         self.selectionBlocks += self.generateEDISelectionBlock(ediName, ediMapping.name);
//         self.importsBlock += string `
// import ${self.libName}.m${ediName};`;
//         self.exportsBlock += ",\"" + self.libName + ".m" + ediName + "\"";
//         self.enumBlock += string `${self.enumBlock.length() > 0? ", ":""}EDI_${ediName} = "${ediName}"`;    
//     }

//     function generateLibraryMainCode() returns string {
//         string codeBlock = string `
// import ballerina/edi;
// import ballerina/http;
// ${self.importsBlock}

// configurable string partnerId = "${self.libName}";

// public enum EDI_NAMES {
//     ${self.enumBlock}
// }

// public class EDIReader {
//     string schemaURL = "";
//     string schemaAccessToken = "";

//     public function init(string schemaURL, string schemaAccessToken) {
//         self.schemaURL = schemaURL;
//         self.schemaAccessToken = schemaAccessToken;
//     }

//     function parse(string ediText, string ediName) returns json|error {
//         string|error mappingText = self.getEDISchemaText(ediName);
//         if mappingText is error {
//             return error("Schema for the EDI " + ediName + " not found in URL " + self.schemaURL);
//         }
//         edi:EDIMapping mapping = check edi:readMappingFromString(mappingText);
//         json jb = check edi:readEDIAsJson(ediText, mapping);
//         return jb;
//     }

//     ${self.ediFunctions}

//     public function readEDI(string ediText, EDI_NAMES ediName, string? ediFileName) returns anydata|error {
//         match ediName {
//             ${self.selectionBlocks}
//         }
//     }

//     public function getEDINames() returns string[] {
//         return ${self.ediNames.toString()};
//     }

//     function getEDISchemaText(string ediName) returns string|error {
//         http:Client sclient = check new(self.schemaURL);
//         string fileName = ediName + ".json";
//         string authHeader = "Bearer" + self.schemaAccessToken;
//         string schemaContent = check sclient->/[fileName]({
//             Authorization: authHeader, 
//             Accept: "application/vnd.github.raw"});
//         return schemaContent;
//     }
// }
//         `;
//         return codeBlock;        
//     }

//     function generateEDITypeFunctions(string ediName, string mainRecordName) returns string {
//         string ediFunctions = string `
//     public function read_${ediName}(string ediText) returns m${ediName}:${mainRecordName}|error {
//         m${ediName}:${mainRecordName} b = check (check self.parse(ediText, "${ediName}")).cloneWithType(m${ediName}:${mainRecordName});
//         return m${ediName}:process(b);
//     }

//     public function readAndTransform_${ediName}(string ediText) returns anydata|error {
//         m${ediName}:${mainRecordName} b = check self.read_${ediName}(ediText);
//         return m${ediName}:transform(b);
//     }
//         `;
//         return ediFunctions;
//     }

//     function generateEDISelectionBlock(string ediName, string mainRecordName) returns string {
//         string block = string `EDI_${ediName} => { return self.readAndTransform_${ediName}(ediText); }
//             `;
//         return block;
//     }

//     function createLibStructure() returns error? {
//         self.libPath = check file:joinPath(self.outputPath, self.libName);
//         if check file:test(self.libPath, file:EXISTS) {
//             file:MetaData[] files = check file:readDir(self.libPath);
//             if files.length() > 0 {
//                 return error(string `Target library path ${self.libPath} is not empty. Please provide an empty directory to create the library.`);
//             } 
//         } else {
//             check file:createDir(self.libPath, file:RECURSIVE);
//         }

//         string balTomlContent = string `
// [package]
// org = "${self.orgName}"
// name = "${self.libName}"
// version = "0.1.0"
// distribution = "2201.4.1"
// `;
//         string balTomlPath = check file:joinPath(self.libPath, "Ballerina.toml");
//         check io:fileWriteString(balTomlPath, balTomlContent);
//     }

//     function generateTransformerCode(string ediName, string mainRecordName) returns string {
//         string transformer = string `

// type TargetType ${mainRecordName};

// public function transform(${mainRecordName} data) returns TargetType => data;

// public function process(${mainRecordName} data) returns ${mainRecordName} {
//     // Implement EDI type specific processing code here

//     return data;
// }
//     `;
//         return transformer;
//     }
// }