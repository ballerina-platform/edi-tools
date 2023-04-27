import ballerina/regex;

function convertToType(string value, EDIDataType dataType, string? decimalSeparator) returns SimpleType|error {
    match dataType {
        STRING => {
            return value;
        }
        INT => {
            return int:fromString(decimalSeparator != () ? regex:replace(value, decimalSeparator, ".") : value);
        }
        FLOAT => {
            return float:fromString(decimalSeparator != () ? regex:replace(value, decimalSeparator, ".") : value);
        }
    }
    return error("Undefined type for value:" + value);
}

function getArray(EDIDataType dataType) returns SimpleArray|EDIComponentGroup[] {
    match dataType {
        STRING => {
            string[] values = [];
            return values;
        }
        INT => {
            int[] values = [];
            return values;
        }
        FLOAT => {
            float[] values = [];
            return values;
        }
        COMPOSITE => {
            EDIComponentGroup[] values = [];
            return values;
        }
    }
    string[] values = [];
    return values;
}

public function getDataType(string typeString) returns EDIDataType {
    match typeString {
        "string" => {
            return STRING;
        }
        "int" => {
            return INT;
        }
        "float" => {
            return FLOAT;
        }
    }
    return STRING;
}

public function split(string text, string delimiter) returns string[] {
    string preparedText = prepareToSplit(text, delimiter);
    string validatedDelimiter = validateDelimiter(delimiter);
    return regex:split(preparedText, validatedDelimiter);
}

function splitSegments(string text, string delimiter) returns string[] {
    string validatedDelimiter = validateDelimiter(delimiter);
    string[] segmentLines = regex:split(text, validatedDelimiter);
    foreach int i in 0 ... (segmentLines.length() - 1) {
        segmentLines[i] = regex:replaceAll(segmentLines[i], "\n", "");
    }
    return segmentLines;
}

function validateDelimiter(string delimeter) returns string {
    match delimeter {
        "*" => {
            return "\\*";
        }
        "^" => {
            return "\\^";
        }
        "+" => {
            return "\\+";
        }
        "." => {
            return "\\.";
        }
    }
    return delimeter;
}

function prepareToSplit(string content, string delimeter) returns string {
    string preparedContent = content.trim();
    if (content.endsWith(delimeter)) {
        preparedContent = preparedContent + " ";
    }
    if (content.startsWith(delimeter)) {
        preparedContent = " " + preparedContent;
    }
    return preparedContent;
}

function printEDIUnitMapping(EDIUnitSchema smap) returns string {
    if smap is EDISegSchema {
        return string `Segment ${smap.code} | Min: ${smap.minOccurances} | Max: ${smap.maxOccurances} | Trunc: ${smap.truncatable}`;
    } else {
        string sgcode = "";
        foreach EDIUnitSchema umap in smap.segments {
            if umap is EDISegSchema {
                sgcode += umap.code + "-";
            } else {
                sgcode += printSegGroupMap(umap);
            }
        }
        return string `[Segment group: ${sgcode} ]`;
    }
}

function printSegMap(EDISegSchema smap) returns string {
    return string `Segment ${smap.code} | Min: ${smap.minOccurances} | Max: ${smap.maxOccurances} | Trunc: ${smap.truncatable}`;
}

function printSegGroupMap(EDISegGroupSchema sgmap) returns string {
    string sgcode = "";
    foreach EDIUnitSchema umap in sgmap.segments {
        if umap is EDISegSchema {
            sgcode += umap.code + "-";
        } else {
            sgcode += printSegGroupMap(umap);
        }
    }
    return string `[Segment group: ${sgcode} ]`;
}

function getMinimumFields(EDISegSchema segmap) returns int {
    int fieldIndex = segmap.fields.length() - 1;
    while fieldIndex > 0 {
        if segmap.fields[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

function getMinimumCompositeFields(EDIFieldSchema emap) returns int {
    int fieldIndex = emap.components.length() - 1;
    while fieldIndex > 0 {
        if emap.components[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

function getMinimumSubcomponentFields(EDIComponentSchema emap) returns int {
    int fieldIndex = emap.subcomponents.length() - 1;
    while fieldIndex > 0 {
        if emap.subcomponents[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

function serializeSimpleType(SimpleType v, EDISchema schema) returns string {
    string sv = v.toString();
    if v is float {
        if sv.endsWith(".0") {
            sv = sv.substring(0, sv.length() - 2);
        } else if schema.delimiters.decimalSeparator != "." {
            sv = regex:replace(sv, "\\.", schema.delimiters.decimalSeparator ?: ".");
        }
    }
    return sv;
}

