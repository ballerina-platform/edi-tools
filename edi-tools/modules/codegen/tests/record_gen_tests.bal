// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;

@test:Config {}
function testFieldGeneration() {
    BalField b1 = new (BSTRING, "firstName", false, true);
    test:assertEquals(b1.toString(false), "string firstName?;");

    BalField b12 = new (BSTRING, "firstName", false, false, "Mark");
    test:assertEquals(b12.toString(false), "string firstName = \"Mark\";");

    BalField b2 = new (BSTRING, "employeeNames", true, true);
    test:assertEquals(b2.toString(false), "string[] employeeNames = [];");

    BalField b3 = new (BINT, "age", false, false);
    test:assertEquals(b3.toString(false), "int age;");

    BalField b4 = new (BINT, "age", false, false, 30);
    test:assertEquals(b4.toString(false), "int age = 30;");
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
    string:RegExp re1 = re `\n`;
    string:RegExp re2 = re `   `;

    string output = re1.replaceAll(r2.toString(), "");
    output = re2.replaceAll(output, " ");
    test:assertEquals(output, expected);
}
