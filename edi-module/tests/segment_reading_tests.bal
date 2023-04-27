import ballerina/test;

@test:Config {
    dataProvider: segmentTestDataProvider
}
function testSegments(string testName) returns error? {
    EDISchema schema = check getSchema(testName);
    schema.preserveEmptyFields = true;
    EDIReader reader = check new (schema);
    string ediIn = check getEDIMessage(testName);
    json message = check reader.readEDI(ediIn);
    check saveJsonMessage(testName, message);

    EDIWriter writer = check new (schema);
    string ediOut = check writer.writeEDI(message);
    check saveEDIMessage(testName, ediOut);

    ediOut = prepareEDI(ediOut, schema);
    ediIn = prepareEDI(ediIn, schema);

    test:assertEquals(ediOut, ediIn);
}

function segmentTestDataProvider() returns string[][] {
    return [
        ["sample1"],
        ["sample2"],
        ["sample3"],
        ["sample4"],
        ["sample5"],
        ["sample6"],
        ["edi-837"],
        ["d3a-invoic-1"]
    ];
}
