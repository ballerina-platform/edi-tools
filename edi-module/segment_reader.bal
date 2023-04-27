import ballerina/log;

class SegmentReader {

    RepetitionReader repetitionReader = new();
    ComponentGroupReader componentGroupReader = new();

    function read(EDISegSchema segMapping, string[] fields, EDISchema mapping, string segmentDesc)
        returns EDISegment|error {
        log:printDebug(string `Reading ${printSegMap(segMapping)} | Seg text: ${segmentDesc}`);
        if segMapping.truncatable {
            int minFields = getMinimumFields(segMapping);
            if fields.length() < minFields + 1 {
                return error(string `Segment mapping's field count does not match minimum field count of the truncatable segment ${fields[0]}.
                    Required minimum field count (excluding the segment code): ${minFields}. Found ${fields.length() - 1} fields. 
                    Segment mapping: ${segMapping.toJsonString()} | Segment text: ${segmentDesc}`);
            }
        } else if (segMapping.fields.length() + 1 != fields.length()) {
            string errMsg = string `Segment mapping's field count does not match segment ${fields[0]}. 
                    Segment mapping: ${segMapping.toJsonString()} | Segment text: ${segmentDesc}`;
            return error(errMsg);
        }
        EDISegment ediRecord = {};
        int fieldNumber = 0;
        while (fieldNumber < fields.length() - 1) {
            if fieldNumber >= segMapping.fields.length() {
                return error(string `EDI segment [1] in the message containes more fields than the segment definition [2]
                [1] ${fields.toJsonString()}
                [2] ${segMapping.toJsonString()}`);
            }
            EDIFieldSchema fieldMapping = segMapping.fields[fieldNumber];
            string tag = fieldMapping.tag;

            // EDI segment starts with the segment name. So we have to skip the first field.
            string fieldText = fields[fieldNumber + 1];
            if fieldText.trim().length() == 0 {
                if fieldMapping.required {
                    return error(string `Required field ${fieldMapping.tag} of segment ${segMapping.code} is not provided.`);
                } else {
                    if mapping.preserveEmptyFields {
                        if fieldMapping.repeat {
                            ediRecord[tag] = getArray(fieldMapping.dataType);
                        } else if fieldMapping.dataType == STRING {
                            ediRecord[tag] = fieldText;
                        } else {
                            ediRecord[tag] = ();
                        }
                    }
                    fieldNumber = fieldNumber + 1;
                    continue;
                }
            }
            if (fieldMapping.repeat) {
                // this is a repeating field (i.e. array). can be a repeat of composites as well.
                SimpleArray|EDIComponentGroup[] repeatValues = check self.repetitionReader.read(fieldText, mapping.delimiters.repetition, mapping, fieldMapping);
                if repeatValues.length() > 0 || mapping.preserveEmptyFields {
                    ediRecord[tag] = repeatValues;    
                } 
            } else if (fieldMapping.components.length() > 0) {
                // this is a composite field (but not a repeat)
                EDIComponentGroup? composite = check self.componentGroupReader.read(fieldText, mapping, fieldMapping);
                if (composite is EDIComponentGroup || mapping.preserveEmptyFields) {
                    ediRecord[tag] = composite;
                } 
            } else {
                // this is a simple type field
                SimpleType|error value = convertToType(fieldText, fieldMapping.dataType, mapping.delimiters.decimalSeparator);
                if value is SimpleType {
                    ediRecord[tag] = value;
                } else {
                    string errMsg = string `EDI field: ${fieldText} cannot be converted to type: ${fieldMapping.dataType}.
                            Segment mapping: ${segMapping.toJsonString()} | Segment text: ${segmentDesc}|n${value.message()}`;
                    return error(errMsg);
                }
            }
            fieldNumber = fieldNumber + 1;
        }
        return ediRecord;
    }
}