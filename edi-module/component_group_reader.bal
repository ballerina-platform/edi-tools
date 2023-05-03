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

isolated function readComponentGroup(string compositeText, EDISchema ediSchema, EDIFieldSchema fieldSchema)
            returns EDIComponentGroup|Error? {
    if compositeText.trim().length() == 0 {
        return ();
    }

    string[] components = split(compositeText, ediSchema.delimiters.component);
    if fieldSchema.truncatable {
        int minFields = getMinimumCompositeFields(fieldSchema);
        if components.length() < minFields {
            return error Error(string `Composite mapping's field count does not match minimum field count of the truncatable field: ${fieldSchema.tag}.
                Required minimum field count: ${minFields}. Found ${components.length()} fields. 
                Composite mapping: ${fieldSchema.toJsonString()} | Composite text: ${compositeText}`);
        }
    } else if fieldSchema.components.length() != components.length() {
        return error Error(string `Composite mapping's component count does not match field: ${fieldSchema.tag}. 
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
                return error Error(string `Required component is not provided. Component: ${subMapping.tag}`);
            }
            if ediSchema.preserveEmptyFields {
                composite[subMapping.tag] = subMapping.dataType == STRING ? component : ();
            }
            componentNumber += 1;
            continue;
        }

        if subMapping.subcomponents.length() > 0 {
            EDISubcomponentGroup? scGroup = check readSubcomponentGroup(component, ediSchema, subMapping);
            if scGroup is EDISubcomponentGroup || ediSchema.preserveEmptyFields {
                composite[subMapping.tag] = scGroup;
            }
        } else {
            SimpleType|error value = convertToType(component, subMapping.dataType, ediSchema.delimiters.decimalSeparator);
            if value is error {
                return error Error(string `EDI field cannot be converted to schema type. 
                            EDI field: ${component}, Target type: ${subMapping.dataType}. Composite schema: ${subMapping.toJsonString()}.
                            Composite text: ${compositeText}. Error: ${value.message()}`);
            }
            composite[subMapping.tag] = value;
        }
        componentNumber = componentNumber + 1;
    }
    return composite;
}
