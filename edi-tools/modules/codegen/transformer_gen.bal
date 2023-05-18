function generateTransformerCode(string ediName, string mainRecordName) returns string {
    string transformer = string `
type InternalType ${mainRecordName};

public function transformFromEdiString(string ediText) returns anydata|error {
    ${mainRecordName} data = check fromEdiString(ediText);
    return transformRead(data);
}

function transformRead(${mainRecordName} data) returns InternalType => data;

public function transformToEdiString(anydata content) returns string|error {
    ${mainRecordName} data = transformWrite(check content.ensureType());
    return toEdiString(data);
}

function transformWrite(InternalType data) returns ${mainRecordName} => data;
    `;
    return transformer;
}
