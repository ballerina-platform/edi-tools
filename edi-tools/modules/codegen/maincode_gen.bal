function generateMainCode(LibData libdata) returns string {
    return string `
import ballerina/http;
import ballerina/edi;
${libdata.importsBlock}

configurable string ediSchemaURL = ?;
configurable string ediSchemaAccessToken = ?;

type EDIProcess function (json) returns anydata|error;

public enum EDI_NAME {
    ${libdata.enumBlock}
}

public isolated function getEDINames() returns string[] {
    return ${libdata.ediNames.toString()};
}

public isolated function read(string ediText, EDI_NAME ediName) returns anydata|error {
    string|error schemaText = getEDISchemaText(ediName);
    if schemaText is error {
        return error edi:Error("Schema is not available for the EDI type. EDI: " +
                 ediName + ", Schema URL: " + ediSchemaURL);
    }
    edi:EDISchema schema = check edi:getSchema(schemaText);
    json jsonData = check edi:read(ediText, schema);
    EDIProcess? ediProcess = readProcessors[ediName];
    if ediProcess is () {
        return error edi:Error("EDI processor is not initialized for EDI type: " + ediName);
    }
    return ediProcess(jsonData);
}

public isolated function write(json data, EDI_NAME ediName) returns string|error {
    string|error schemaText = getEDISchemaText(ediName);
    if schemaText is error {
        return error edi:Error("Schema is not available for the EDI type. EDI: " +
                 ediName + ", Schema URL: " + ediSchemaURL);
    }
    edi:EDISchema schema = check edi:getSchema(schemaText);
    EDIProcess? ediProcess = writeProcessors[ediName];
    if ediProcess is () {
        return error edi:Error("EDI processor is not initialized for EDI type: " + ediName);
    }
    json processedData = (check ediProcess(data)).toJson();
    string ediText = check edi:write(processedData, schema);
    return ediText;
}

isolated function getEDISchemaText(string ediName) returns string|error {
    http:Client sclient = check new(ediSchemaURL);
    string fileName = ediName + ".json";
    string authHeader = "Bearer" + ediSchemaAccessToken;
    string schemaContent = check sclient->/[fileName]({
        Authorization: authHeader, 
        Accept: "application/vnd.github.raw"});
    return schemaContent;
}

final readonly & map<EDIProcess> readProcessors = {
    ${libdata.readProcessors}
};

final readonly & map<EDIProcess> writeProcessors = {
    ${libdata.writeProcessors}
};
    `;

}
