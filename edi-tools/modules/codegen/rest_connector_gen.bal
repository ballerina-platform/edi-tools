
function generateRESTConnector(string libName) returns string {
    string restConCode = string `
import ballerina/http;

configurable int restConnectorPort = 9090;

service /${libName}Parser on new http:Listener(restConnectorPort) {

    isolated resource function post edis/[string ediType](@http:Payload string ediData) returns json|error {
        EDI_NAME|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        anydata target = check fromEdiString(ediData, ediTypeName);   
        return target.toJson();
    }

    isolated resource function post objects/[string ediType](@http:Payload json jsonData) returns string|error {
        EDI_NAME|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        string ediText = check toEdiString(jsonData, ediTypeName);   
        return ediText;
    }

    isolated resource function get edis() returns string[] {
        return getEDINames();
    }
}
    `;

    return restConCode;
}
