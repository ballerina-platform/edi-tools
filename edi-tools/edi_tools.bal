// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/file;
import ballerina/log;
import editools.codegen;
import editools.edifact;
import editools.esl;
import editools.x12xsd;

public function main(string[] args) {

    string usage = string 
`NAME
    bal edi - Ballerina EDI Tool

SYNOPSIS
       bal edi <command> [OPTIONS] [<arguments>]

DESCRIPTION
       The 'bal edi' command-line tool provides the functionality required to process
       EDI files and implement EDI integrations.

COMMANDS
       codegen
           Generate records and parser functions for a given EDI schema.

       libgen
           Generate EDI libraries.

       convertX12Schema
           Convert X12 schema to Ballerina EDI schema.

       convertEdifactSchema
           Convert EDIFACT schema to Ballerina EDI schema.

       convertESL
           Convert ESL schema to Ballerina EDI schema.

OPTIONS
       The following options are available for each command:

       codegen:
           -i, --input <input schema path>
               Path to the EDI schema file.

           -o, --output <output path>
               Path to the output file.

       libgen:
           -p, --package <package name>
               Package name(organization-name/library-name).

           -i, --input <input schema folder>
               Path to the folder containing EDI schemas.

           -o, --output <output folder>
               Path to the folder where libraries will be generated.

       convertX12Schema:
           -H, --headers
               Enable headers mode for X12 schema conversion.

           -c, --collection
               Enable collection mode for X12 schema conversion.

           -i, --input <input schema path>
               Path to the X12 schema file.

           -o, --output <output path>
               Path to the output file or folder.

           -d, --segdet <segment details path>
               Path to the segment details file for X12 schema conversion.

       convertEdifactSchema:
           -v, --version <EDIFACT version>
               EDIFACT version for EDIFACT schema conversion.

           -t, --type <EDIFACT message type>
               EDIFACT message type for EDIFACT schema conversion.

           -o, --output <output folder>
               Path to the folder where EDIFACT schemas will be generated.

       convertESL:
           -b, --basedef <segment definitions file path>
               Path to the segment definitions file for ESL schema conversion.

           -i, --input <input ESL schema file/folder>
               Path to the ESL schema file or folder.

           -o, --output <output file/folder>
               Path to the output file or folder.

EXAMPLES
       Generate records and parser functions for a given EDI schema.
           $ bal edi codegen -i resources/schema.json -o modules/orders/records.bal

       Generate EDI libraries.
           $ bal edi libgen -p myorg/mylib -i schemas/ -o lib/

       Convert X12 schema to Ballerina EDI schema.
           $ bal edi convertX12Schema -i input/schema.xsd -o output/schema.json

       Convert EDIFACT schema to Ballerina EDI schema.
           $ bal edi convertEdifactSchema -v d03a -t ORDERS -o output/schema.json

       Convert ESL schema to Ballerina EDI schema.
           $ bal edi convertESL -b segment_definitions.yaml -i esl_schema.esl -o output/schema.json
`;

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
        json|error mappingJson = io:fileReadJson(args[1].trim());
        if mappingJson is error {
            log:printError("Error reading schema json file: " + mappingJson.message());
            return;
        }
        error? e = codegen:generateCodeForSchema(mappingJson, args[2].trim());
        if e is error {
            log:printError("Error generating code: " + e.message());
        }

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
        error? e = codegen:generateLibrary(libdata);
        if e is error {
            log:printError("Error generating library: " + e.message());
        }

    } else if mode == "convertESL" {
        string eslPath = args[1].trim();
        string basedefPath = args[2].trim();
        string outputPath = args[3].trim();
        error? e = esl:convertEsl(eslPath, basedefPath, outputPath);
        if e is error {
            log:printError("Error converting ESL: " + e.message());
        }

    } else if mode == "convertX12Schema" {
        do {
            boolean headers = false;
            boolean collection = false;
            string[] x12args = args.slice(1);
            if (x12args[0] == "H") {
                headers = true;
                _ = x12args.shift();
            }
            if (x12args[0] == "c") {
                collection = true;
                _ = x12args.shift();
            }
            string inputPath = x12args[0].trim();
            string outputPath = x12args[1].trim();
            string segDetlPath = x12args.length() > 2 ? x12args[2].trim() : "";

            boolean isInputDir = check file:test(inputPath, file:IS_DIR);
            boolean isOutputDir = check file:test(outputPath, file:IS_DIR);

            if (collection) {
                if (!isInputDir || !isOutputDir) {
                    io:println("In collection mode, both output and input should be a directories");
                    return;
                }
                check x12xsd:convertFromX12CollectionAndWrite(inputPath, outputPath, headers, segDetlPath);
            } else {
                if (headers) {
                    if (!isInputDir) {
                        io:println("In header mode, input should be a directory containing header and message schema files");
                        return;
                    }
                    string outputPathGenerated = outputPath;
                    if (isOutputDir) {
                        string dirName = check file:basename(inputPath);
                        outputPathGenerated = isOutputDir ? check file:joinPath(outputPath, dirName + ".json") : outputPath;
                    }
                    check x12xsd:convertFromX12WithHeadersAndWrite(inputPath, outputPathGenerated, segDetlPath);
                } else {
                    if (isInputDir || isOutputDir) {
                        io:println("Collection mode or header mode not selected, both input and output should be files");
                        return;
                    }
                    check x12xsd:convertFromX12XsdAndWrite(inputPath, outputPath, segDetlPath);
                }
            }
        } on fail error e {
            log:printError("Error converting X12 schema: " + e.message());
        }
    } else if mode == "convertEdifactSchema" {
        do {
            if args.length() < 3 {
                io:println(usage);
                return;
            }
            string version = args[1].trim(); // ex: d10a
            string 'type = args[2].trim(); // ex: INVOIC
            string outputPath = args[3].trim();
            check edifact:convertEdifactToEdi(version, outputPath, 'type == "" ? () : 'type);
        } on fail error e {
            log:printError("Error converting EDIFACT schema: " + e.message());
        }
    } else {
        io:println(usage);
    }
}
