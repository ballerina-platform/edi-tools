
function generateRESTConnector(string libName) returns string {
    string restConCode = string `
import ballerina/http;

configurable string ediSchemaURL = ?;
configurable string ediSchemaAccessToken = ?;
configurable int restConnectorPort = 9090;

EDIReader ediReader = new(ediSchemaURL, ediSchemaAccessToken);

service /${libName}EDIParser on new http:Listener(restConnectorPort) {

    resource function post [string ediType](@http:Payload string ediData) returns json|error {
        EDI_NAMES|error ediTypeName = ediType.ensureType();
        if ediTypeName is error {
            return error("Unsupported EDI type: " + ediType + ". " + ediTypeName.message());
        }
        anydata target = check ediReader.readEDI(ediData, ediTypeName, "");                  
        return target.toJson();
    }

    resource function get edis() returns string[] {
        return ediReader.getEDINames();
    }
}
    `;

    return restConCode;
}