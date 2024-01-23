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
import editools.edifact;

public function main(string[] args) {

    string usage = string `Ballerina EDI tools -
        Ballerina code generation for edi schema: bal edi codegen -s <schema json path> -o <output bal file path>
        EDI library generation: bal edi libgen -O <org name> -n <library name> -s <EDI schema folder> -o <output folder>
        Convert EDIFACT schema to EDI: bal edi convertEdifactSchema -v <EDIFACT version> -t <EDIFACT message type> -o <output folder>`;

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
