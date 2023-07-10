import ballerina/test;
import editools.x12xsd;

@test:Config
function testX12XsdConversion() returns error? {
    string inpath = "tests/resources/x12xsd/004010/210.xsd";
    string outpath = "tests/resources/x12xsd/004010/210.json";
    check x12xsd:convertFromX12XsdAndWrite(inpath, outpath);
}