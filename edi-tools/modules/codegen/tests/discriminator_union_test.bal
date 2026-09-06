// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
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

import ballerina/file;
import ballerina/io;
import ballerina/test;

// A schema exercising discriminators at field level (REF qualifier) and at
// component level (RFF C506 qualifier), plus a plain `values` field that must
// NOT be narrowed (validation-only code lists can be huge, and narrowing them
// would reject dirty-but-parseable inbound data during record conversion).
final readonly & json discriminatorUnionSchemaJson = {
    "name": "DiscUnion",
    "delimiters": {"segment": "~", "field": "*", "component": ":"},
    "segments": [
        {
            "code": "REF",
            "tag": "SubscriberIdentifier",
            "minOccurances": 1,
            "fields": [
                {"tag": "code"},
                {"tag": "qualifier", "required": true, "discriminator": ["0F"]},
                {"tag": "identifier", "required": true}
            ]
        },
        {
            "code": "REF",
            "tag": "MemberSupplementalIdentifier",
            "minOccurances": 0,
            "maxOccurances": 13,
            "fields": [
                {"tag": "code"},
                {"tag": "qualifier", "required": true, "discriminator": ["17", "23", "DX"]},
                {"tag": "identifier", "required": true}
            ]
        },
        {
            "code": "RFF",
            "tag": "VatNumber",
            "minOccurances": 0,
            "fields": [
                {"tag": "code"},
                {"tag": "REFERENCE", "required": true, "dataType": "composite", "components": [
                    {"tag": "rffQualifier", "required": true, "discriminator": ["VA"]},
                    {"tag": "number", "required": true}
                ]}
            ]
        },
        {
            "code": "DTM",
            "tag": "DateReference",
            "minOccurances": 0,
            "fields": [
                {"tag": "code"},
                {"tag": "dateQualifier", "values": ["137", "17", "64"]},
                {"tag": "dateValue"}
            ]
        }
    ]
};

// Codes containing characters that must be escaped in generated Ballerina literals.
final readonly & json escapedValuesSchemaJson = {
    "name": "EscapeTest",
    "delimiters": {"segment": "~", "field": "*", "component": ":"},
    "segments": [
        {"code": "REF", "tag": "Odd", "fields": [
            {"tag": "code"},
            {"tag": "q", "required": true, "discriminator": ["A\"B", "C\\D", "E\nF"]},
            {"tag": "v", "required": true}
        ]}
    ]
};

@test:Config {}
function testDiscriminatorFieldsGenerateLiteralUnions() returns error? {
    string tmpDir = check file:createTempDir();
    string outputPath = check file:joinPath(tmpDir, "disc_gen.bal");
    check generateCodeForSchema(discriminatorUnionSchemaJson, outputPath);
    string generated = check io:fileReadString(outputPath);
    check file:remove(tmpDir, file:RECURSIVE);

    // Field-level discriminators become string-literal unions.
    test:assertTrue(generated.includes("(\"0F\")"),
        "Single-value discriminator field must be narrowed to its literal");
    test:assertTrue(generated.includes("(\"17\"|\"23\"|\"DX\")"),
        "Multi-value discriminator field must be narrowed to a literal union");

    // Component-level discriminators too.
    test:assertTrue(generated.includes("(\"VA\")"),
        "Component-level discriminator must be narrowed to its literal");

    // Plain `values` (no discriminator) must stay `string`.
    test:assertFalse(generated.includes("(\"137\"|\"17\"|\"64\")"),
        "Validation-only values lists must not be narrowed");
}

@test:Config {}
function testDiscriminatorValuesAreEscapedInGeneratedLiterals() returns error? {
    // Code lists come from third-party schema files: a value may legitimately contain a quote,
    // a backslash or a line break, and inserting it verbatim would produce source that does not
    // compile. Assert the complete union so a dropped or over-escaped value cannot pass.
    string tmpDir = check file:createTempDir();
    string outputPath = check file:joinPath(tmpDir, "escape_gen.bal");
    check generateCodeForSchema(escapedValuesSchemaJson, outputPath);
    string generated = check io:fileReadString(outputPath);
    check file:remove(tmpDir, file:RECURSIVE);

    // The three codes are A"B, C\D and E<LF>F; the generated field must read exactly:
    //     ("A\"B"|"C\\D"|"E\nF") q;
    test:assertTrue(generated.includes("(\"A\\\"B\"|\"C\\\\D\"|\"E\\nF\") q;"),
            "the generated union must escape every value exactly: " + generated);
}

