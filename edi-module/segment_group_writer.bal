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

isolated function writeSegmentGroup(map<json> segGroup, EDISegGroupSchema|EDISchema sgmap, EDIContext context) returns Error? {

    string[] keys = segGroup.keys();
    int msgIndex = 0;
    int mapIndex = 0;
    while mapIndex < sgmap.segments.length() {
        EDIUnitSchema umap = sgmap.segments[mapIndex];
        if msgIndex >= keys.length() {
            if umap.minOccurances > 0 {
                return error Error(string `Mandatory segment not found in input message. Segment: ${umap.tag}`);
            }
            mapIndex += 1;
            continue;
        }
        string unitKey = keys[msgIndex];
        json unit = segGroup.get(unitKey);
        if umap.tag != unitKey {
            if umap.minOccurances > 0 {
                return error Error(string `Mandatory segment not found in input message. Required segment: ${umap.tag}, Found ${unitKey}`);
            }
            mapIndex += 1;
            continue;
        }
        if umap.maxOccurances == 0 {
            return error Error(string `Maximum occurances must not be equal to zero. Segment/segment group: ${umap.tag}`);
        }

        if umap.maxOccurances == 1 {
            if !(unit is map<json>) {
                return error Error(string `Segment group must contain segments or segment groups. Segment group: ${sgmap.tag}, Found: ${unit.toString()}"`);
            }
            if umap is EDISegSchema {
                check writeSegment(unit, umap, context);
            } else {
                check writeSegmentGroup(unit, umap, context);
            }
        } else {
            if !(unit is json[]) {
                return error Error(string `Value of multi-occurance segment/segment group must be an array. Segment group: ${umap.tag}, Found: ${unit.toString()}`);
            }
            if unit.length() < umap.minOccurances || ((unit.length() > umap.maxOccurances) && umap.maxOccurances > 0) {
                return error Error(string `Cardinality of input segment/segment group does not match with the schema.
                    Segment/segment group: ${unitKey}, Allowed min: ${umap.minOccurances}, Allowed max: ${umap.maxOccurances}, Found ${unit is EDIUnit[] ? unit.length() : 1}
                    Schema: Schema: ${printEDIUnitMapping(umap)}`);
            }
            foreach json u in unit {
                if !(u is map<json>) {
                    return error Error(string `Each item in segment group must be a segment/segment group. Segment group: ${umap.tag}, Found: ${u.toString()}`);
                }
                if umap is EDISegSchema {
                    check writeSegment(u, umap, context);
                } else {
                    check writeSegmentGroup(u, umap, context);
                }
            }
        }
        mapIndex += 1;
        msgIndex += 1;
    }
}
