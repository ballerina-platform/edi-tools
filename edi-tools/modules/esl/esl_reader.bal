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
import ballerina/yaml;
import ballerina/log;
import ballerina/edi;

public function main1(string[] args) returns error? {
    if args.length() != 3 {
        io:println("Parameters: <eslPath> <basedefPath> <outputPath>");
    }
    check convertEsl(args[0], args[1], args[2]);
}

public function convertEsl(string eslDataPath, string eslSegmentsPath, string outputPath) returns error? {
    json baseDefs = check yaml:readFile(eslSegmentsPath);
    map<edi:EdiSegSchema> segDefinitions = check readSegmentSchemas(baseDefs);
    if check file:test(eslDataPath, file:IS_DIR) && check file:test(outputPath, file:IS_DIR) {
        file:MetaData[] eslFiles = check file:readDir(eslDataPath);
        foreach file:MetaData eslFile in eslFiles {
            string ediName = check file:basename(eslFile.absPath);
            if ediName.endsWith(".esl") {
                ediName = ediName.substring(0, ediName.length() - ".esl".length());
            }
            if ediName == "basedefs" || ediName == "structures.txt" {
                continue;
            }
            json eslJson = check yaml:readFile(eslFile.absPath);
            edi:EdiSchema|error ediMapping = readEslSchema(eslJson, segDefinitions);
            if ediMapping is error {
                return error(string `Failed to convert schema of EDI: ${ediName}. Error: ${ediMapping.message()}`);
            }
            check fixSchema(ediMapping);
            string mappingPath = check file:joinPath(outputPath, ediName + ".json");
            check io:fileWriteJson(mappingPath, ediMapping.toJson());
        }
    } else {
        json eslJson = check yaml:readFile(eslDataPath);
        edi:EdiSchema ediSchema = check readEslSchema(eslJson, segDefinitions);
        check fixSchema(ediSchema);
        check io:fileWriteJson(outputPath, ediSchema.toJson());
    }
}

public function readEslSchema(json eslSchema, map<edi:EdiSegSchema> segmentDefs) returns edi:EdiSchema|error {
    json[] units = [];
    var heading = eslSchema.heading;
    if heading is json[] {
        units.push(...heading);
    }
    var detail = eslSchema.detail;
    if detail is json[] {
        units.push(...detail);
    }
    var summary = eslSchema.summary;
    if summary is json[] {
        units.push(...summary);
    }
    map<json> rootSegmentGroup = {};
    var rootName = eslSchema.name;
    if rootName !is string {
        rootName = eslSchema.id;      
    }
    if rootName !is string {
        rootName = "Root";      
    }
    rootSegmentGroup["groupId"] = getBalCompatibleName(check rootName.ensureType());
    rootSegmentGroup["items"] = units;
    rootSegmentGroup["usage"] = "M";
    rootSegmentGroup["count"] = 1;
    edi:EdiSegGroupSchema rootSegGroupSchema = check readSegmentGroup(rootSegmentGroup, segmentDefs);
    edi:EdiSchema ediSchema = {
        name: check rootSegmentGroup.groupId,
        delimiters: {segment: "'", 'field: "+", component: ":"},
        segments: rootSegGroupSchema.segments,
        segmentDefinitions: segmentDefs
    };
    return ediSchema;
}

public function readSegmentGroup(json segGroupDef, map<edi:EdiSegSchema> segmentDefs) returns edi:EdiSegGroupSchema|error {
    json|error segGroupId = segGroupDef.groupId;
    if segGroupId is error {
        return error("Invalid segment group schema. groupId is required. " + segGroupDef.toString());
    }
    log:printDebug("Reading segment group: " + segGroupId.toString());
    edi:EdiSegGroupSchema segGroupSchema = {
        tag: getBalCompatibleName(segGroupId.toString())
    };
    if segGroupDef.usage == "M" {
        segGroupSchema.minOccurances = 1;
    }
    var maxOccurs = segGroupDef.count;
    if maxOccurs is int {
        segGroupSchema.maxOccurances = maxOccurs;
    }
    var items = segGroupDef.items;
    if items !is json[] {
        return error("Invalid segment group schema. Items should be an array. " + segGroupDef.toString());
    }
    foreach json segmentRef in items {
        var code = segmentRef.idRef;
        var groupId = segmentRef.groupId;
        if code is string {
            log:printDebug("Reading segment reference: " + code);
            edi:EdiSegSchema? segmentDef = segmentDefs[code];
            if segmentDef is () {
                return error("Invalid EDI schema. Segment definition not found for segment code " + code);
            }
            edi:EdiUnitRef segRef = { ref: code };
            if segmentRef.usage == "M" {
                segRef.minOccurances = 1;
            }
            var segMaxOccurs = segmentRef.count;
            if segMaxOccurs is int {
                segRef.maxOccurances = segMaxOccurs;
            }
            segGroupSchema.segments.push(segRef);
        } else if groupId is string {
            segGroupSchema.segments.push(check readSegmentGroup(segmentRef, segmentDefs));
        } else {
            return error("Invalid segment group schema. idRef or groupId is required. " + segmentRef.toString());
        }
    }
    return segGroupSchema;
}