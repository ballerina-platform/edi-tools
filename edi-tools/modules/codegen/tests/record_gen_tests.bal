import ballerina/test;
import ballerina/regex;

@test:Config {}
function testFieldGeneration() {
    BalField b1 = new (BSTRING, "firstName", false, true);
    test:assertEquals(b1.toString(false), "string firstName?;");

    BalField b2 = new (BSTRING, "employeeNames", true, true);
    test:assertEquals(b2.toString(false), "string[] employeeNames = [];");

    BalField b3 = new (BINT, "age", false, false);
    test:assertEquals(b3.toString(false), "int age;");
}

@test:Config {}
function testBasicRecordGeneration() {
    BalRecord r1 = new ("Person");
    r1.addField(BSTRING, "name", false, false);
    r1.addField(BINT, "age", false, false);
    r1.addField(BSTRING, "contact", true, true);
}

@test:Config {}
function testComplexRecordGeneration() {
    BalRecord r1 = new ("Person");
    r1.addField(BSTRING, "name", false, false);
    r1.addField(BINT, "age", false, false);
    r1.addField(BSTRING, "contact", true, true);

    BalRecord r2 = new ("Team");
    r2.addField(BSTRING, "teamName", false, false);
    r2.addField(r1, "lead", false, true);
    r2.addField(r1, "members", true, false);
    r2.addField(r2, "subteams", true, true);
    r2.addField(BSTRING, "location", false, true);

    string expected = "public type Team record {| string teamName; Person? lead?; Person[] members = []; Team[] subteams = []; string location?;|};";
    string output = regex:replaceAll(r2.toString(), "\n", "");
    output = regex:replaceAll(output, "   ", " ");
    test:assertEquals(output, expected);
}
