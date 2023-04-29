
function writeSegment(map<json> seg, EDISegSchema segMap, EDIContext context) returns Error? {
    string fd = context.schema.delimiters.'field;
    // string cd = self.emap.delimiters.component;
    string segLine = segMap.code;
    string[] fTags = seg.keys();
    if fTags.length() < segMap.fields.length() && !segMap.truncatable {
        return error Error(string `Segment "${segMap.code}" is not truncatable. Segment schema has ${segMap.fields.length()} fields. But input segment has only ${fTags.length()} fields.`);
    }
    int fIndex = 0;
    while fIndex < segMap.fields.length() {
        EDIFieldSchema fmap = segMap.fields[fIndex];
        if fIndex >= fTags.length() {
            // Input segment is truncated. So all remaining feilds must be optional
            if fmap.required {
                return error Error(string `Mandatory field "${fmap.tag}" of segment "${segMap.tag}" is not found in input segment ${seg.toString()}`);
            }
            fIndex += 1;
            continue;
        }
        string fTag = fTags[fIndex];
        if fmap.tag == fTag {
            if !fmap.repeat && fmap.components.length() > 0 {
                string|error componentGroupText = writeComponentGroup(seg.get(fTag), segMap, fmap, context);
                if componentGroupText is string {
                    segLine += fd + componentGroupText;
                } else {
                    return error Error(string `Failed to serialize component group ${fmap.toString()} in input segment ${seg.toString()}
                    ${componentGroupText.message()}`);
                }
            } else if fmap.repeat {
                var fdata = seg.get(fTag);
                if !(fdata is json[]) {
                    return error Error(string `Field ${fmap.tag} in segment ${segMap.code} must have an array as the value. Found: ${fdata.toString()}`);
                }
                if fdata.length() == 0 {
                    if fmap.required {
                        return error Error(string `Mandatory field ${fmap.tag} in segment ${segMap.code} not provided.`);
                    } else {
                        segLine += fd + "";
                        fIndex += 1;
                        continue;
                    }
                }
                string rd = context.schema.delimiters.repetition;
                string repeatingText = "";
                if fmap.components.length() == 0 {
                    foreach json fdataElement in fdata {
                        if !(fdataElement is SimpleType) {
                            return error Error(string `Repeatable field "${fmap.tag}" in segment "${segMap.tag}" must be a primitive type array. Found: ${fdata.toString()}`);
                        }
                        repeatingText += (repeatingText == "" ? "" : rd) + fdataElement.toString();
                    }
                } else if fmap.components.length() > 0 {
                    foreach json g in fdata {
                        string cgroupText = check writeComponentGroup(g, segMap, fmap, context);
                        repeatingText += (repeatingText == "" ? "" : rd) + cgroupText;
                    }
                } else {
                    return error Error(string `Repeatable field ${fmap.tag} in segment ${printSegMap(segMap)} must match with array type. Found ${fdata.toString()}`);
                }
                segLine += fd + repeatingText;
            } else {
                var fdata = seg.get(fTag);
                if !(fdata is SimpleType) {
                    return error Error(string `Field "${fmap.tag}" of segment "${segMap.tag}" must be a primitive type value. Found: ${fdata.toString()}`);
                }
                segLine += fd + serializeSimpleType(fdata, context.schema);
            }
            fIndex += 1;
        } else {
            if !fmap.required {
                fIndex += 1;
            } else {
                return error Error(string `Required field ${fmap.tag} is not found in the input segment ${segMap.tag}`);
            }
        }
    }
    segLine += context.schema.delimiters.segment;
    context.ediText.push(segLine);
}
