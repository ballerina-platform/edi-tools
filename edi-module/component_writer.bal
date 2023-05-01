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

isolated function writeComponentGroup(json componentGroup, EDISegSchema segSchema, EDIFieldSchema fieldSchema, EDIContext context) returns string|Error {
    if componentGroup is () {
        if fieldSchema.required {
            return error Error(string `Mandatory composite field of a segment is not provided. Segment: ${segSchema.tag}, Field: ${fieldSchema.tag}`);
        } else {
            return "";
        }
    }

    string cd = context.schema.delimiters.component;
    if componentGroup is map<json> {
        string[] ckeys = componentGroup.keys();
        if ckeys.length() < fieldSchema.components.length() && !fieldSchema.truncatable {
            return error Error(string `Number of components in the composite field does not match with the field schema.
            Segment ${segSchema.code}, Field ${fieldSchema.tag}, Required components: ${fieldSchema.components.length()}, 
            Available components: ${ckeys.length()}, Component group value: ${componentGroup.toString()}.`);
        }
        int cindex = 0;
        string cGroupText = "";
        while cindex < fieldSchema.components.length() {
            EDIComponentSchema cmap = fieldSchema.components[cindex];
            if cindex >= ckeys.length() {
                if cmap.required {
                    return error Error(string `Mandatory component not found. Segment ${segSchema.code}, Field: ${fieldSchema.tag}, Component: ${cmap.tag}, Component group: ${componentGroup.toString()}`);
                }
                cindex += 1;
                continue;
            }
            string ckey = ckeys[cindex];
            if ckey != cmap.tag {
                return error Error(string `Component does not match with the schema.
                Segment: ${segSchema.tag}, Field: ${fieldSchema.tag}, Component schema tag: ${cmap.tag}, Component index: ${cindex}, Component tag: ${ckey}`);
            }
            var componentValue = componentGroup.get(ckey);
            if componentValue is string && componentValue.trim().length() == 0 {
                if cmap.required {
                    return error Error(string `Mandatory component not found. Segment: ${segSchema.code}, Field: ${fieldSchema.tag}, Component: ${cmap.tag}, Component group: ${componentGroup.toString()}`);
                } else {
                    cGroupText += (cindex == 0 ? "" : cd) + "";
                    cindex += 1;
                    continue;
                }
            }
            if cmap.subcomponents.length() == 0 {
                if componentValue is SimpleType {
                    cGroupText += (cindex == 0 ? "" : cd) + serializeSimpleType(componentValue, context.schema);
                    cindex += 1;
                } else {
                    return error Error(string `Component must contain a primitive value. Segment: ${segSchema.code}, Field: ${fieldSchema.tag}, Component: ${cmap.tag}, Component value: ${componentValue.toString()}`);
                }
            } else if cmap.subcomponents.length() > 0 {
                string|error scGroupText = writeSubcomponentGroup(componentValue, segSchema, cmap, context);
                if scGroupText is string {
                    cGroupText += (cindex == 0 ? "" : cd) + scGroupText;
                    cindex += 1;
                } else {
                    return error Error(string `Component must contain a composite value. Segment: ${segSchema.code}, Field: ${fieldSchema.tag}, Component: ${cmap.tag}, Component value: ${componentValue.toString()}`);
                }
            } else {
                return error Error(string `Unsupported component value. Segment: ${segSchema.code}, Field: ${fieldSchema.tag}, Component: ${cmap.tag}, Found: ${componentValue.toString()}`);
            }
        }
        return cGroupText;
    } else if componentGroup is string && componentGroup.trim() == "" {
        if fieldSchema.required {
            return error Error(string `Mandatory compite field not provided. Segment ${segSchema.tag}, Field: ${fieldSchema.tag}`);
        } else {
            return "";
        }
    } else {
        return error Error(string `Input field is not compatible with the schema. 
            Segment schema: ${printSegMap(segSchema)}, Composite field schema: ${fieldSchema.toString()}, Input ${componentGroup.toString()}`);
    }
}

isolated function writeSubcomponentGroup(json subcomponentGroup, EDISegSchema segSchema, EDIComponentSchema compSchema, EDIContext context) returns string|Error {
    string scd = context.schema.delimiters.subcomponent;
    if subcomponentGroup is map<json> {
        string[] sckeys = subcomponentGroup.keys();
        if sckeys.length() < compSchema.subcomponents.length() && !compSchema.truncatable {
            return error Error(string `Required number of subcomponents are not found in the component.
            Segment ${segSchema.code}, Component: ${compSchema.tag}, Required subcomponents: ${compSchema.subcomponents.length()}, 
            Found subcomponents: ${sckeys.length()}, Input component: ${subcomponentGroup.toString()}.`);
        }
        int scindex = 0;
        string scGroupText = "";
        while scindex < compSchema.subcomponents.length() {
            EDISubcomponentSchema scmap = compSchema.subcomponents[scindex];
            if scindex >= sckeys.length() {
                if scmap.required {
                    return error Error(string `Mandatory subcomponent not found. Segment ${segSchema.code}, Subcomponent: ${scmap.tag}, Input subcomponent group: ${subcomponentGroup.toString()}`);
                }
                scindex += 1;
                continue;
            }
            string sckey = sckeys[scindex];
            if sckey != scmap.tag {
                return error Error(string `Subcomponent does not match with the schema.
                Segment: ${segSchema.tag}, Component: ${compSchema.tag}, Subcomponent: ${scmap.tag}, Subcomponent index: ${scindex}, Input subcomponent tag: ${sckey}`);
            }
            var subcomponentValue = subcomponentGroup.get(sckey);
            if subcomponentValue is SimpleType {
                scGroupText += (scGroupText == "" ? "" : scd) + serializeSimpleType(subcomponentValue, context.schema);
                scindex += 1;
            } else {
                return error Error(string `Only primitive types are supported as subcomponent values. Found ${subcomponentValue.toString()}`);
            }
        }
        return scGroupText;
    } else if subcomponentGroup is string && subcomponentGroup.trim() == "" {
        if compSchema.required {
            return error Error(string `Mandatory subcomponent group field is not found in the input.
             Segment ${segSchema.tag}, Subcomponent group field: ${compSchema.tag}`);
        } else {
            return "";
        }
    } else {
        return error Error(string `Input segment is not compatible with the schema.
            Subcomponent group field: ${compSchema.toString()}, Input: ${subcomponentGroup.toString()}, Schema: ${printSegMap(segSchema)}`);
    }
}
