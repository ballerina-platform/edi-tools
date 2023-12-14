import ballerina/test;
import editools.edifact;
import ballerina/io;
import ballerina/file;

@test:Config {
    dataProvider: filesProvider,
    after: afterFunc
}
function testEdifactConversion(string msgType, string expected, string actual) returns error? {
    check edifact:convertEdifactToEdi("d03a", "tests/resources/edifact/d03a", msgType);

    json expectedJson = check io:fileReadJson(expected);
    json actualJson = check io:fileReadJson(actual);
    test:assertEquals(expectedJson, actualJson, "Edifact conversion failed");
}

function afterFunc() returns error? {
    check file:remove("tests/resources/edifact/d03a/INVOIC.json");
}

function filesProvider() returns string[][] {
    return [
        ["INVOIC", "tests/resources/edifact/d03a/INVOIC_expected.json", "tests/resources/edifact/d03a/INVOIC.json"],
        ["ORDERS", "tests/resources/edifact/d03a/ORDERS_expected.json", "tests/resources/edifact/d03a/ORDERS.json"]
    ];
}
