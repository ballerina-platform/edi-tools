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
import editools.x12xsd;
import ballerina/file;
import editools.esl;
import ballerina/log;
import editools.codegen;

public function main(string[] args) {

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
                log:printError("Both input and output should be either directories or files");
            }
        } on fail error e {
            log:printError("Error converting X12 schema: " + e.message());
        }
    } else {
        io:println(usage);
    }
}
