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

isolated function writeSegment(map<json> seg, EDISegSchema segMap, EDIContext context) returns Error? {
    string fd = context.schema.delimiters.'field;
    // string segLine = context.schema.includeSegmentCode? "" : segMap.code;
    string segLine = segMap.code;
    string[] fTags = seg.keys();
    if fTags.length() < segMap.fields.length() && !segMap.truncatable {
        return error Error(string `Input field count does not match with the field count of the (non-truncatable) segment schema.
        Segment: ${segMap.code}, Segment schema field count: ${segMap.fields.length()}, Input segment's field count: ${fTags.length()}`);
    }
    int fIndex = context.schema.includeSegmentCode? 1 : 0;
    while fIndex < segMap.fields.length() {
        EDIFieldSchema fieldSchema = segMap.fields[fIndex];
        if fIndex >= fTags.length() {
            // Input segment is truncated. So all remaining feilds must be optional
            if fieldSchema.required {
                return error Error(string `Mandatory field not found in the input segment.
                Field: ${fieldSchema.tag}, Segment: ${segMap.tag}, Input segment: ${seg.toString()}`);
            }
            fIndex += 1;
            continue;
        }
        string fTag = fTags[fIndex];
        if fieldSchema.tag != fTag {
            if fieldSchema.required {
                return error Error(string `Required field is not found in the input. Segment: ${segMap.tag}, Field: ${fieldSchema.tag}`);
            }
            fIndex += 1;
            continue;
        }
        if !fieldSchema.repeat && fieldSchema.components.length() > 0 {
            string|error componentGroupText = writeComponentGroup(seg.get(fTag), segMap, fieldSchema, context);
            if componentGroupText is error {
                return error Error(string `Failed to serialize component group. Segment: ${segMap.tag}, Field: ${fieldSchema.toString()}, Input segment ${seg.toString()}
                ${componentGroupText.message()}`);
            }
            segLine += fd + componentGroupText;
        } else if fieldSchema.repeat {
            json fdata = seg.get(fTag);
            if !(fdata is json[]) {
                return error Error(string `Repeatable field must contain an array as the value.
                Segment: ${segMap.code}, Field: ${fieldSchema.tag}, Input value: ${fdata.toString()}`);
            }
            if fdata.length() == 0 {
                if fieldSchema.required {
                    return error Error(string `Mandatory field is not provided. Field: ${fieldSchema.tag}, Segment: ${segMap.code}`);
                }
                segLine += fd + "";
                fIndex += 1;
                continue;
            }
            string rd = context.schema.delimiters.repetition;
            string repeatingText = "";
            if fieldSchema.components.length() == 0 {
                foreach json fdataElement in fdata {
                    if !(fdataElement is SimpleType) {
                        return error Error(string `Repeatable field value must be a primitive type array. 
                                                    Field: ${fieldSchema.tag}, Segment: ${segMap.tag}, Input value: ${fdata.toString()}`);
                    }
                    repeatingText += (repeatingText == "" ? "" : rd) + fdataElement.toString();
                }
            } else {
                foreach json g in fdata {
                    string cgroupText = check writeComponentGroup(g, segMap, fieldSchema, context);
                    repeatingText += (repeatingText == "" ? "" : rd) + cgroupText;
                }
            }
            segLine += fd + repeatingText;
        } else {
            var fdata = seg.get(fTag);
            if !(fdata is SimpleType) {
                return error Error(string `Field must contain a primitive value.
                Field: ${fieldSchema.tag}, Segment: ${segMap.tag}, Input value: ${fdata.toString()}`);
            }
            segLine += (segLine.length() > 0 && fd != "FL"? fd : "") + serializeSimpleType(fdata, context.schema, fd == "FL" ? fieldSchema.length : -1);
        }
        fIndex += 1;
    }
    segLine += context.schema.delimiters.segment;
    context.ediText.push(segLine);
}
