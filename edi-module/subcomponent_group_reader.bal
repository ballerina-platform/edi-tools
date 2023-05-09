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

isolated function readSubcomponentGroup(string scGroupText, EDISchema schema, EDIComponentSchema compSchema) returns EDISubcomponentGroup|Error? {
    if scGroupText.trim().length() == 0 {
        return ();
    }

    string[] subcomponents = split(scGroupText, schema.delimiters.subcomponent);
    if compSchema.truncatable {
        int minFields = getMinimumSubcomponentFields(compSchema);
        if subcomponents.length() < minFields {
            return error Error(string `Subcomponent group schema's field count does not match minimum field count of the truncatable field.
                Field: ${compSchema.tag}, Required minimum field count: ${minFields}. Input fields: ${subcomponents.length()}, 
                Subcomponent group mapping: ${compSchema.toJsonString()}, Subcomponent group text: ${scGroupText}`);
        }
    } else if compSchema.subcomponents.length() != subcomponents.length() {
        return error Error(string `Subcomponent group schema's subcomponent count does not match input field.
                Field: ${compSchema.tag}, Subcomponent group mapping: ${compSchema.toJsonString()}, Subcomponent group text: ${scGroupText}`);
    }

    EDISubcomponentSchema[] subMappings = compSchema.subcomponents;
    EDISubcomponentGroup scGroup = {};
    int subcomponentNumber = 0;
    while subcomponentNumber < subcomponents.length() {
        string subcomponent = subcomponents[subcomponentNumber];
        EDISubcomponentSchema subMapping = subMappings[subcomponentNumber];
        if subcomponent.trim().length() == 0 {
            if subMapping.required {
                return error Error(string `Required subcomponent is not provided. Subcomponent: ${subMapping.tag}`);
            } else {
                if schema.preserveEmptyFields {
                    scGroup[subMapping.tag] = subMapping.dataType == STRING ? subcomponent : ();
                }
                subcomponentNumber += 1;
                continue;
            }
        }

        SimpleType|error value = convertToType(subcomponent, subMapping.dataType, schema.delimiters.decimalSeparator);
        if value is error {
            return error Error(string `Input field cannot be converted to the type given in the schema.
                        Input field: ${subcomponent}, Schema type: ${subMapping.dataType},
                        Subcomponent group mapping: ${subMapping.toJsonString()}, Subcomponent group text: ${scGroupText},
                        Error: ${value.message()}`);
        }
        scGroup[subMapping.tag] = value;
        subcomponentNumber = subcomponentNumber + 1;
    }
    return scGroup;
}
