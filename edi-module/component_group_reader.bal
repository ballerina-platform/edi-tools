class ComponentGroupReader {

    SubcomponentGroupReader subcomponentGroupReader = new();

    function read(string compositeText, EDISchema ediSchema, EDIFieldSchema fieldSchema)
                returns EDIComponentGroup|error? {
        if compositeText.trim().length() == 0 {
            return ();
        }

        string[] components = split(compositeText, ediSchema.delimiters.component);
        if fieldSchema.truncatable {
            int minFields = getMinimumCompositeFields(fieldSchema);
            if components.length() < minFields {
                return error(string `Composite mapping's field count does not match minimum field count of the truncatable field ${fieldSchema.tag}.
                    Required minimum field count: ${minFields}. Found ${components.length()} fields. 
                    Composite mapping: ${fieldSchema.toJsonString()} | Composite text: ${compositeText}`);
            }
        } else if fieldSchema.components.length() != components.length() {
            return error(string `Composite mapping's component count does not match field ${fieldSchema.tag}. 
                    Composite mapping: ${fieldSchema.toJsonString()} | Composite text: ${compositeText}`);
        }

        EDIComponentSchema[] subMappings = fieldSchema.components;
        EDIComponentGroup composite = {};
        int componentNumber = 0;
        while componentNumber < components.length() {
            string component = components[componentNumber];
            EDIComponentSchema subMapping = subMappings[componentNumber];
            if component.trim().length() == 0 {
                if subMapping.required {
                    return error(string `Required component ${subMapping.tag} is not provided.`);
                } 
                if ediSchema.preserveEmptyFields {
                    composite[subMapping.tag] = subMapping.dataType == STRING? component : ();
                }
                componentNumber += 1;
                continue;
            }

            if subMapping.subcomponents.length() > 0 {
                EDISubcomponentGroup? scGroup = check self.subcomponentGroupReader.read(component, ediSchema, subMapping);
                if scGroup is EDISubcomponentGroup || ediSchema.preserveEmptyFields {
                    composite[subMapping.tag] = scGroup;
                }
            } else {
                SimpleType|error value = convertToType(component, subMapping.dataType, ediSchema.delimiters.decimalSeparator);
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