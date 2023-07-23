import ballerina/io;
import ballerina/test;

@test:Config
function testSimpleOrder() returns error? {
    string ediText = check io:fileReadString("modules/codegen/resources/sample1/message.edi");
    SimpleOrder orderJson = check fromEdiStringSimpleOrder(ediText);
    io:println(orderJson);
}