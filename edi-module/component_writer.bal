class ComponentWriter {

    EDISchema schema;

    function init(EDISchema schema) {
        self.schema = schema;
    }    

    function serializeComponentGroup(json componentGroup, EDISegSchema segMap, EDIFieldSchema fmap) returns string|error {
        if componentGroup is null {
            if fmap.required {
                return error(string `Mandatory composite field "${fmap.tag}" of segment "${segMap.tag}" is not provided.`);
            } else {
                return "";
            }            
        }

        string cd = self.schema.delimiters.component;
        if componentGroup is map<json> {
            string[] ckeys = componentGroup.keys();
            if ckeys.length() < fmap.components.length() && !fmap.truncatable {
                return error(string `Field ${fmap.tag} in segment ${segMap.code} must have ${fmap.components.length()} components. 
                Found only ${ckeys.length()} components in ${componentGroup.toString()}.`);
            }
            int cindex = 0;
            string cGroupText = "";
            while cindex < fmap.components.length() {
                EDIComponentSchema cmap = fmap.components[cindex];
                if cindex >= ckeys.length() {
                    if cmap.required {
                        return error(string `Mandatory component ${cmap.tag} not found in ${componentGroup.toString()} in segment ${segMap.code}`);
                    }
                    cindex += 1;
                    continue;
                }
                string ckey = ckeys[cindex];
                if ckey != cmap.tag {
                    return error(string `Component ${cmap.tag} - cindex: ${cindex} [segment: ${segMap.tag}, field: ${fmap.tag}] in the schema does not match with ${ckey} found in the input EDI.`);
                }
                var componentValue = componentGroup.get(ckey);
                if componentValue is string && componentValue.trim().length() == 0 {
                    if cmap.required {
                        return error(string `Mandatory component ${cmap.tag} in [Segment: ${segMap.code}, Field: ${fmap.tag}] not provided`);
                    } else {
                        cGroupText += (cindex == 0? "" : cd) + "";
                        cindex += 1;
                        continue;
                    }
                }
                if cmap.subcomponents.length() == 0 {
                    if componentValue is SimpleType {
                        cGroupText += (cindex == 0? "" : cd) + serializeSimpleType(componentValue, self.schema);
                        cindex += 1;
                    } else {
                        return error(string `Component ${cmap.tag} in [Segment: ${segMap.code}, Field: ${fmap.tag}] must contain a primitive value. Found: ${componentValue.toString()}`);
                    }
                } else if cmap.subcomponents.length() > 0 {
                    string|error scGroupText = self.serializeSubcomponentGroup(componentValue, segMap, cmap);
                    if scGroupText is string {
                        cGroupText += (cindex == 0? "" : cd) + scGroupText;
                        cindex += 1;
                    } else {
                        return error(string `Component ${cmap.tag} in [Segment: ${segMap.code}, Field: ${fmap.tag}] must contain a composite value. Found: ${componentValue.toString()}`);   
                    }
                } else {
                    return error(string `Unsupported component value. Found ${componentValue.toString()}`);
                }
            }
            return cGroupText;
        } else if componentGroup is string && componentGroup.trim() == "" {
            if fmap.required {
                return error(string `Mandatory compite field ${fmap.tag} of segment ${segMap.tag} is not available in the input.`);
            } else {
                return "";
            }
        } else {
            return error(string `Input segment is not compatible with the schema ${printSegMap(segMap)}.
                Composite field ${fmap.toString()} is expected. Found ${componentGroup.toString()}`);
        }
    }

    function serializeSubcomponentGroup(json subcomponentGroup, EDISegSchema segMap, EDIComponentSchema compMap) returns string|error {
        string scd = self.schema.delimiters.subcomponent;
        if subcomponentGroup is map<json> {
            string[] sckeys = subcomponentGroup.keys();
            if sckeys.length() < compMap.subcomponents.length() && !compMap.truncatable {
                return error(string `Component ${compMap.tag} in segment ${segMap.code} must have ${compMap.subcomponents.length()} subcomponents. 
                Found only ${sckeys.length()} subcomponents in ${subcomponentGroup.toString()}.`);
            }
            int scindex = 0;
            string scGroupText = "";
            while scindex < compMap.subcomponents.length() {
                EDISubcomponentSchema scmap = compMap.subcomponents[scindex];
                if scindex >= sckeys.length() {
                    if scmap.required {
                        return error(string `Mandatory subcomponent ${scmap.tag} not found in ${subcomponentGroup.toString()} in segment ${segMap.code}`);
                    }
                    scindex += 1;
                    continue;
                }
                string sckey = sckeys[scindex];
                if sckey != scmap.tag {
                    return error(string `Subcomponent ${scmap.tag} - scindex: ${scindex} [segment: ${segMap.tag}, component: ${compMap.tag}] in the schema does not match with ${sckey} found in the input EDI.`);
                }
                var subcomponentValue = subcomponentGroup.get(sckey);
                if subcomponentValue is SimpleType {
                    scGroupText += (scGroupText == ""? "" : scd) + serializeSimpleType(subcomponentValue, self.schema);
                    scindex += 1;
                } else {
                    return error(string `Only primitive types are supported as subcomponent values. Found ${subcomponentValue.toString()}`);
                }
            }
            return scGroupText;
        } else if subcomponentGroup is string && subcomponentGroup.trim() == "" {
            if compMap.required {
                return error(string `Mandatory sub-compite field ${compMap.tag} of segment ${segMap.tag} is not available in the input.`);
            } else {
                return "";
            }
        } else {
            return error(string `Input segment is not compatible with the schema ${printSegMap(segMap)}.
                Sub-composite field ${compMap.toString()} is expected. Found ${subcomponentGroup.toString()}`);
        }
    }

    
}