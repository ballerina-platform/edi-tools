import ballerina/test;

@test:Config {
    dataProvider: segmentTestDataProvider
}
function testSegments(string testName) returns error? {
    EDISchema schema = check getTestSchema(testName);
    schema.preserveEmptyFields = true;
    string ediIn = check getEDIMessage(testName);
    json message = check read(ediIn, schema);
    check saveJsonMessage(testName, message);

    string ediOut = check write(message, schema);
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
