import ballerina/io;
import ballerina/regex;
import ballerina/file;

function getTestSchema(string testName) returns EDISchema|error {
    string schemaPath = check file:joinPath("tests", "resources", testName, "schema.json");
    json schemaJson = check io:fileReadJson(schemaPath);
    EDISchema schema = check getSchema(schemaJson);
    return schema;
}

function getEDIMessage(string testName) returns string|error {
    string inputPath = check file:joinPath("tests", "resources", testName, "message.edi");
    return check io:fileReadString(inputPath);
}

function saveEDIMessage(string testName, string message) returns error? {
    string path = check file:joinPath("tests", "resources", testName, "output.edi");
    check io:fileWriteString(path, message);
}

function getJSONPath(string testName) returns string|error {
    return file:joinPath("tests", "resources", testName, "message.json");
}

function getJSONMessage(string testName) returns json|error {
    return io:fileReadJson(check getJSONPath(testName));
}

function saveJsonMessage(string testName, json message) returns error? {
    string path = check file:joinPath("tests", "resources", testName, "output.json");
    check io:fileWriteJson(path, message);
}

function prepareEDI(string edi, EDISchema schema) returns string {
    string e1 = regex:replaceAll(edi, " ", "");
    e1 = regex:replaceAll(e1, "\n", "");
    e1 = regex:replaceAll(e1, validateDelimiter((schema.delimiters.decimalSeparator ?: ".")) + "0", "");
    e1 = regex:replaceAll(e1, "0", "");
    return e1;
}

