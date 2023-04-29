
function writeComponentGroup(json componentGroup, EDISegSchema segSchema, EDIFieldSchema fieldSchema, EDIContext context) returns string|error {
    if componentGroup is () {
        if fieldSchema.required {
            return error(string `Mandatory composite field "${fieldSchema.tag}" of segment "${segSchema.tag}" is not provided.`);
        } else {
            return "";
        }
    }

    string cd = context.schema.delimiters.component;
    if componentGroup is map<json> {
        string[] ckeys = componentGroup.keys();
        if ckeys.length() < fieldSchema.components.length() && !fieldSchema.truncatable {
            return error(string `Field ${fieldSchema.tag} in segment ${segSchema.code} must have ${fieldSchema.components.length()} components. 
            Found only ${ckeys.length()} components in ${componentGroup.toString()}.`);
        }
        int cindex = 0;
        string cGroupText = "";
        while cindex < fieldSchema.components.length() {
            EDIComponentSchema cmap = fieldSchema.components[cindex];
            if cindex >= ckeys.length() {
                if cmap.required {
                    return error(string `Mandatory component ${cmap.tag} not found in ${componentGroup.toString()} in segment ${segSchema.code}`);
                }
                cindex += 1;
                continue;
            }
            string ckey = ckeys[cindex];
            if ckey != cmap.tag {
                return error(string `Component ${cmap.tag} - cindex: ${cindex} [segment: ${segSchema.tag}, field: ${fieldSchema.tag}] in the schema does not match with ${ckey} found in the input EDI.`);
            }
            var componentValue = componentGroup.get(ckey);
            if componentValue is string && componentValue.trim().length() == 0 {
                if cmap.required {
                    return error(string `Mandatory component ${cmap.tag} in [Segment: ${segSchema.code}, Field: ${fieldSchema.tag}] not provided`);
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
                    return error(string `Component ${cmap.tag} in [Segment: ${segSchema.code}, Field: ${fieldSchema.tag}] must contain a primitive value. Found: ${componentValue.toString()}`);
                }
            } else if cmap.subcomponents.length() > 0 {
                string|error scGroupText = writeSubcomponentGroup(componentValue, segSchema, cmap, context);
                if scGroupText is string {
                    cGroupText += (cindex == 0 ? "" : cd) + scGroupText;
                    cindex += 1;
                } else {
                    return error(string `Component ${cmap.tag} in [Segment: ${segSchema.code}, Field: ${fieldSchema.tag}] must contain a composite value. Found: ${componentValue.toString()}`);
                }
            } else {
                return error(string `Unsupported component value. Found ${componentValue.toString()}`);
            }
        }
        return cGroupText;
    } else if componentGroup is string && componentGroup.trim() == "" {
        if fieldSchema.required {
            return error(string `Mandatory compite field ${fieldSchema.tag} of segment ${segSchema.tag} is not available in the input.`);
        } else {
            return "";
        }
    } else {
        return error(string `Input segment is not compatible with the schema ${printSegMap(segSchema)}.
            Composite field ${fieldSchema.toString()} is expected. Found ${componentGroup.toString()}`);
    }
}

function writeSubcomponentGroup(json subcomponentGroup, EDISegSchema segSchema, EDIComponentSchema compSchema, EDIContext context) returns string|error {
    string scd = context.schema.delimiters.subcomponent;
    if subcomponentGroup is map<json> {
        string[] sckeys = subcomponentGroup.keys();
        if sckeys.length() < compSchema.subcomponents.length() && !compSchema.truncatable {
            return error(string `Component ${compSchema.tag} in segment ${segSchema.code} must have ${compSchema.subcomponents.length()} subcomponents. 
            Found only ${sckeys.length()} subcomponents in ${subcomponentGroup.toString()}.`);
        }
        int scindex = 0;
        string scGroupText = "";
        while scindex < compSchema.subcomponents.length() {
            EDISubcomponentSchema scmap = compSchema.subcomponents[scindex];
            if scindex >= sckeys.length() {
                if scmap.required {
                    return error(string `Mandatory subcomponent ${scmap.tag} not found in ${subcomponentGroup.toString()} in segment ${segSchema.code}`);
                }
                scindex += 1;
                continue;
            }
            string sckey = sckeys[scindex];
            if sckey != scmap.tag {
                return error(string `Subcomponent ${scmap.tag} - scindex: ${scindex} [segment: ${segSchema.tag}, component: ${compSchema.tag}] in the schema does not match with ${sckey} found in the input EDI.`);
            }
            var subcomponentValue = subcomponentGroup.get(sckey);
            if subcomponentValue is SimpleType {
                scGroupText += (scGroupText == "" ? "" : scd) + serializeSimpleType(subcomponentValue, context.schema);
                scindex += 1;
            } else {
                return error(string `Only primitive types are supported as subcomponent values. Found ${subcomponentValue.toString()}`);
            }
        }
        return scGroupText;
    } else if subcomponentGroup is string && subcomponentGroup.trim() == "" {
        if compSchema.required {
            return error(string `Mandatory sub-compite field ${compSchema.tag} of segment ${segSchema.tag} is not available in the input.`);
        } else {
            return "";
        }
    } else {
        return error(string `Input segment is not compatible with the schema ${printSegMap(segSchema)}.
            Sub-composite field ${compSchema.toString()} is expected. Found ${subcomponentGroup.toString()}`);
    }
}
