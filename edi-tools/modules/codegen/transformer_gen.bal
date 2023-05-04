function generateTransformerCode(string ediName, string mainRecordName) returns string {
    string transformer = string `
type InternalType ${mainRecordName};

public function processRead${ediName}(json content) returns anydata|error {
    ${mainRecordName} data = check content.cloneWithType();
    return transformRead(data);
}

function transformRead(${mainRecordName} data) returns InternalType => data;

public function processWrite${ediName}(json content) returns anydata|error {
    InternalType data = check content.cloneWithType();
    return transformWrite(data);
}

function transformWrite(InternalType data) returns ${mainRecordName} => data;
    `;
    return transformer;
}
