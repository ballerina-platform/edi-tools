class SubcomponentGroupReader {

    function read(string scGroupText, EDISchema mapping, EDIComponentSchema emap) returns EDISubcomponentGroup|error? {
        if scGroupText.trim().length() == 0 {
            return ();
        }

        string[] subcomponents = split(scGroupText, mapping.delimiters.subcomponent);
        if emap.truncatable {
            int minFields = getMinimumSubcomponentFields(emap);
            if subcomponents.length() < minFields {
                return error(string `Subcomponent group's mapping's field count does not match minimum field count of the truncatable field ${emap.tag}.
                    Required minimum field count: ${minFields}. Found ${subcomponents.length()} fields. 
                    Subcomponent group mapping: ${emap.toJsonString()} | Subcomponent group text: ${scGroupText}`);
            }
        } else if (emap.subcomponents.length() != subcomponents.length()) {
            string errMsg = string `Subcomponent group mapping's subcomponent count does not match field ${emap.tag}. 
                    Subcomponent group mapping: ${emap.toJsonString()} | Subcomponent group text: ${scGroupText}`;
            return error(errMsg);
        }

        EDISubcomponentSchema[] subMappings = emap.subcomponents;
        EDISubcomponentGroup scGroup = {};
        int subcomponentNumber = 0;
        while (subcomponentNumber < subcomponents.length()) {
            string subcomponent = subcomponents[subcomponentNumber];
            EDISubcomponentSchema subMapping = subMappings[subcomponentNumber];
            if subcomponent.trim().length() == 0 {
                if subMapping.required {
                    return error(string `Required subcomponent ${subMapping.tag} is not provided.`);
                } else {
                    if mapping.preserveEmptyFields {
                        scGroup[subMapping.tag] = subMapping.dataType == STRING ? subcomponent : ();
                    }
                    subcomponentNumber += 1;
                    continue;
                }
            }

            SimpleType|error value = convertToType(subcomponent, subMapping.dataType, mapping.delimiters.decimalSeparator);
            if value is SimpleType? {
                scGroup[subMapping.tag] = value;
            } else {
                string errMsg = string `EDI field: ${subcomponent} cannot be converted to type: ${subMapping.dataType}.
                            Subcomponent group mapping: ${subMapping.toJsonString()} | Subcomponent group text: ${scGroupText}
                            Error: ${value.message()}`;
                return error(errMsg);
            }
            subcomponentNumber = subcomponentNumber + 1;
        }
        return scGroup;
    }
}
