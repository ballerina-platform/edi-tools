function generateTransformerCode(string ediName, string mainRecordName) returns string {
    string transformer = string `
type InternalType ${mainRecordName};

public isolated function transformFromEdiString(string ediText) returns anydata|error {
    ${mainRecordName} data = check fromEdiString(ediText);
    return transformRead(data);
}

isolated function transformRead(${mainRecordName} data) returns InternalType => data;

public isolated function transformToEdiString(anydata content) returns string|error {
    ${mainRecordName} data = transformWrite(check content.ensureType());
    return toEdiString(data);
}

isolated function transformWrite(InternalType data) returns ${mainRecordName} => data;
    `;
    return transformer;
}
