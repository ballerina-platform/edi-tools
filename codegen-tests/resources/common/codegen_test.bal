import ballerina/test;
import ballerina/io;

@test:Config
function testGenerateCode() returns error? {
    string ediText = check io:fileReadString("resources/<sample-name>/message.edi");
    anydata|error generatedRecord = fromEdiString(ediText);
    if generatedRecord is error {
        test:assertFail("Generated code is not compatible with the schema. " + generatedRecord.message());
    }
}