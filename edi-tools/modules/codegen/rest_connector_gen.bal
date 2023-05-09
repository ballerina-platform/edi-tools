
function generateRESTConnector(string libName) returns string {
    string restConCode = string `
import ballerina/http;
import ballerina/edi;

configurable int restConnectorPort = 9090;

service /${libName}EDI on new http:Listener(restConnectorPort) {

    isolated resource function post reader/[string ediType](@http:Payload string ediData) returns json|error {
        EDI_NAME|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error edi:Error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        anydata target = check read(ediData, ediTypeName);   
        return target.toJson();
    }

    isolated resource function post writer/[string ediType](@http:Payload json jsonData) returns string|error {
        EDI_NAME|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error edi:Error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        string ediText = check write(jsonData, ediTypeName);   
        return ediText;
    }

    isolated resource function get edis() returns string[] {
        return getEDINames();
    }
}
    `;

    return restConCode;
}
