function generateMainCode(LibData libdata) returns string {
    return string `
${libdata.importsBlock}

type EdiSerialize function (anydata) returns string|error;
type EdiDeserialize function (string) returns anydata|error;

public enum EDI_NAME {
    ${libdata.enumBlock}
}

public isolated function getEDINames() returns string[] {
    return ${libdata.ediNames.toString()};
}

public isolated function fromEdiString(string ediText, EDI_NAME ediName) returns anydata|error {
    EdiDeserialize? ediDeserialize = ediDeserializers[ediName];
    if ediDeserialize is () {
        return error("EDI deserializer is not initialized for EDI type: " + ediName);
    }
    return ediDeserialize(ediText);
}

public isolated function toEdiString(anydata data, EDI_NAME ediName) returns string|error {
    EdiSerialize? ediSerialize = ediSerializers[ediName];
    if ediSerialize is () {
        return error("EDI serializer is not initialized for EDI type: " + ediName);
    }
    return ediSerialize(data);
}

final readonly & map<EdiDeserialize> ediDeserializers = {
    ${libdata.ediDeserializers}
};

final readonly & map<EdiSerialize> ediSerializers = {
    ${libdata.ediSerializers}
};
    `;

}
