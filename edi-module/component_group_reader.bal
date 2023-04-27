class ComponentGroupReader {

    SubcomponentGroupReader subcomponentGroupReader = new ();

    function read(string compositeText, EDISchema mapping, EDIFieldSchema emap)
                returns EDIComponentGroup|error? {
        if compositeText.trim().length() == 0 {
            // Composite value is not provided. Return null, which will cause this field to be not included.
            return null;
        }

        string[] components = split(compositeText, mapping.delimiters.component);
        if emap.truncatable {
            int minFields = getMinimumCompositeFields(emap);
            if components.length() < minFields {
                return error(string `Composite mapping's field count does not match minimum field count of the truncatable field ${emap.tag}.
                    Required minimum field count: ${minFields}. Found ${components.length()} fields. 
                    Composite mapping: ${emap.toJsonString()} | Composite text: ${compositeText}`);
            }
        } else if (emap.components.length() != components.length()) {
            string errMsg = string `Composite mapping's component count does not match field ${emap.tag}. 
                    Composite mapping: ${emap.toJsonString()} | Composite text: ${compositeText}`;
            return error(errMsg);
        }

        EDIComponentSchema[] subMappings = emap.components;
        EDIComponentGroup composite = {};
        int componentNumber = 0;
        while (componentNumber < components.length()) {
            string component = components[componentNumber];
            EDIComponentSchema subMapping = subMappings[componentNumber];
            if component.trim().length() == 0 {
                if subMapping.required {
                    return error(string `Required component ${subMapping.tag} is not provided.`);
                } else {
                    if mapping.preserveEmptyFields {
                        composite[subMapping.tag] = subMapping.dataType == STRING? component : null;
                    }
                    componentNumber += 1;
                    continue;
                }
            }

            if subMapping.subcomponents.length() > 0 {
                EDISubcomponentGroup? scGroup = check self.subcomponentGroupReader.read(component, mapping, subMapping);
                if scGroup is EDISubcomponentGroup || mapping.preserveEmptyFields {
                    composite[subMapping.tag] = scGroup;
                }
            } else {
                SimpleType|error value = convertToType(component, subMapping.dataType, mapping.delimiters.decimalSeparator);
                if value is SimpleType? {
                    composite[subMapping.tag] = value;
                } else {
                    string errMsg = string `EDI field: ${component} cannot be converted to type: ${subMapping.dataType}.
                                Composite mapping: ${subMapping.toJsonString()} | Composite text: ${compositeText}
                                Error: ${value.message()}`;
                    return error(errMsg);
                }
            }
            componentNumber = componentNumber + 1;
        }
        return composite;
    }
}