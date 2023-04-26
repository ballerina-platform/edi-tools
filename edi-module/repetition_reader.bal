import ballerina/log;

class RepetitionReader {

    ComponentGroupReader componentGroupReader = new();

    function read(string repeatText, string repeatDelimiter, EDIMapping mapping, EDIFieldMapping fieldMapping)
            returns SimpleArray|EDIComponentGroup[]|error {
        string[] fields = split(repeatText, repeatDelimiter);
        SimpleArray|EDIComponentGroup[] repeatValues = getArray(fieldMapping.dataType);
        if (fields.length() == 0) {
            // None of the repeating values are provided. Return an empty array.
            if fieldMapping.required {
                return error(string `Required field ${fieldMapping.tag} is not provided.`);
            }
            return repeatValues;
        }
        foreach string 'field in fields {
            if (fieldMapping.dataType == COMPOSITE) {
                EDIComponentGroup? value = check self.componentGroupReader.read('field, mapping, fieldMapping);
                if (value is EDIComponentGroup) {
                    repeatValues.push(value);
                } else {
                    log:printWarn(string `Repeat value not provided in ${repeatText}.`);
                }
            } else {
                if 'field.trim().length() == 0 {
                    continue;
                }
                SimpleType|error value = convertToType('field, fieldMapping.dataType, mapping.delimiters.decimalSeparator);
                if (value is SimpleType) {
                    repeatValues.push(value);
                } else {
                    string errMsg = string `EDI field: ${'field} cannot be converted to type: ${fieldMapping.dataType}.
                            field mapping: ${fieldMapping.toJsonString()} | Repeat text: ${repeatText}\n${value.message()}`;
                    return error(errMsg);
                }
            }
        }
        return repeatValues;
    }
}