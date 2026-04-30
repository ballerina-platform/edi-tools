// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.org).
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

import ballerina/edi;
import ballerina/file;
import ballerina/io;
import ballerina/test;

// Schema for a tiny EDIFACT-style ORDERS message with a populated `envelope`.
// Used to exercise the envelope-aware code path in generateCode + generateCodeForSchema.
final readonly & json envelopeSchemaJson = {
    "name": "Orders",
    "tag": "Orders",
    "delimiters": {
        "segment": "'",
        "field": "+",
        "component": ":",
        "subcomponent": "NOT_USED",
        "repetition": "NOT_USED"
    },
    "envelope": {
        "interchange": {
            "header": [{"ref": "UNB"}],
            "trailer": [{"ref": "UNZ"}]
        },
        "transaction": {
            "header": [{"ref": "UNH"}],
            "trailer": [{"ref": "UNT"}]
        }
    },
    "segments": [
        {
            "code": "BGM",
            "tag": "BeginningOfMessage",
            "minOccurances": 1,
            "maxOccurances": 1,
            "fields": [
                {"tag": "code"},
                {"tag": "documentNumber"}
            ]
        }
    ],
    "segmentDefinitions": {
        "UNB": {
            "code": "UNB",
            "tag": "interchange_header",
            "fields": [
                {"tag": "code"},
                {"tag": "controlReference"}
            ]
        },
        "UNZ": {
            "code": "UNZ",
            "tag": "interchange_trailer",
            "fields": [
                {"tag": "code"},
                {"tag": "interchangeControlReference"}
            ]
        },
        "UNH": {
            "code": "UNH",
            "tag": "message_header",
            "fields": [
                {"tag": "code"},
                {"tag": "messageReferenceNumber"}
            ]
        },
        "UNT": {
            "code": "UNT",
            "tag": "message_trailer",
            "fields": [
                {"tag": "code"},
                {"tag": "messageReferenceNumber"}
            ]
        }
    }
};

@test:Config {}
function testEnvelopeRecordEmission() returns error? {
    edi:EdiSchema schema = check edi:getSchema(envelopeSchemaJson);
    BalRecord[] records = check generateCode(schema);

    string[] names = [];
    foreach BalRecord r in records {
        names.push(r.name);
    }

    // Body record (existing behaviour).
    test:assertTrue(names.indexOf("BeginningOfMessage_Type") is int,
            "Expected BeginningOfMessage_Type from schema.segments");

    // Envelope-segment records (new — emitted via the recordgen envelope walk).
    test:assertTrue(names.indexOf("Interchange_header_Type") is int,
            "Expected Interchange_header_Type for the UNB segment");
    test:assertTrue(names.indexOf("Interchange_trailer_Type") is int,
            "Expected Interchange_trailer_Type for the UNZ segment");
    test:assertTrue(names.indexOf("Message_header_Type") is int,
            "Expected Message_header_Type for the UNH segment");
    test:assertTrue(names.indexOf("Message_trailer_Type") is int,
            "Expected Message_trailer_Type for the UNT segment");

    // Per-level wrapper records (one per envelope level/section).
    test:assertTrue(names.indexOf("OrdersInterchangeHeader") is int,
            "Expected OrdersInterchangeHeader wrapper");
    test:assertTrue(names.indexOf("OrdersInterchangeTrailer") is int,
            "Expected OrdersInterchangeTrailer wrapper");
    test:assertTrue(names.indexOf("OrdersTransactionHeader") is int,
            "Expected OrdersTransactionHeader wrapper");
    test:assertTrue(names.indexOf("OrdersTransactionTrailer") is int,
            "Expected OrdersTransactionTrailer wrapper");
}

@test:Config {}
function testEnvelopeCodegenOutput() returns error? {
    string outPath = check file:createTempDir() + "/orders.bal";
    check generateCodeForSchema(envelopeSchemaJson, outPath);

    string output = check io:fileReadString(outPath);

    // Typed envelope wrappers reference the level wrapper records (no `json`).
    test:assertTrue(output.includes("OrdersInterchangeHeader interchangeHeader;"),
            "Generated OrdersInterchange should use OrdersInterchangeHeader, not json");
    test:assertTrue(output.includes("OrdersInterchangeTrailer interchangeTrailer;"),
            "Generated OrdersInterchange should use OrdersInterchangeTrailer, not json");
    test:assertTrue(output.includes("OrdersTransactionHeader transactionHeader;"),
            "Generated OrdersTransaction should use OrdersTransactionHeader, not json");
    test:assertTrue(output.includes("OrdersTransactionTrailer transactionTrailer;"),
            "Generated OrdersTransaction should use OrdersTransactionTrailer, not json");

    // Body field stays typed (Orders|error).
    test:assertTrue(output.includes("Orders|error body;"),
            "Generated OrdersTransaction should preserve fail-safe body field");

    // No `json` typed envelope fields leak through to the user-facing wrappers.
    test:assertFalse(output.includes("json interchangeHeader;"),
            "Generated wrapper must not expose `json interchangeHeader`");
    test:assertFalse(output.includes("json transactionHeader;"),
            "Generated wrapper must not expose `json transactionHeader`");

    // The envelope-aware functions are emitted.
    test:assertTrue(output.includes("public isolated function headersFromEdiString"),
            "Generated module should export headersFromEdiString");
    test:assertTrue(output.includes("public isolated function interchangeFromEdiString"),
            "Generated module should export interchangeFromEdiString");
    test:assertTrue(output.includes("public isolated function interchangeToEdiString"),
            "Generated module should export interchangeToEdiString — the write-side companion");

    // headersFromEdiString returns a typed OrdersHeaders record, not json.
    test:assertTrue(output.includes("returns OrdersHeaders|error"),
            "headersFromEdiString should return the typed OrdersHeaders record");
    test:assertTrue(output.includes("public type OrdersHeaders record"),
            "Generated module should declare OrdersHeaders");
    test:assertFalse(output.includes("function headersFromEdiString(string ediText) returns json"),
            "headersFromEdiString must not leak `json` as its return type");

    // interchangeToEdiString takes the typed OrdersInterchange and returns string|error.
    test:assertTrue(output.includes("interchangeToEdiString(OrdersInterchange msg) returns string|error"),
            "interchangeToEdiString must take the typed OrdersInterchange wrapper");
}
