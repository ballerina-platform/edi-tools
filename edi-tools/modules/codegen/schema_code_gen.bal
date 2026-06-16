// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import ballerina/io;

public function generateCodeForSchema(json schema, string outputPath) returns error? {
    edi:EdiSchema ediSchema = check edi:getSchema(schema);
    BalRecord[] records = check generateCode(ediSchema);
    string recordsString = "";
    foreach BalRecord rec in records {
        recordsString += rec.toString() + "\n";
    }

    string envelopeRecordsCode = "";
    string envelopeFnsCode = "";
    if ediSchema.envelope is edi:EdiEnvelopeSchema {
        edi:EdiEnvelopeSchema env = <edi:EdiEnvelopeSchema>ediSchema.envelope;
        envelopeRecordsCode = renderEnvelopeRecords(ediSchema.name, env);
        envelopeFnsCode = renderEnvelopeFns(ediSchema.name, env);
    }

    string schemaCode = string `
import ballerina/edi;

# Convert EDI string to Ballerina ${ediSchema.name} record.
#
# + ediText - EDI string to be converted
# + return - Ballerina record or error
public isolated function fromEdiString(string ediText) returns ${ediSchema.name}|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json dataJson = check edi:fromEdiString(ediText, ediSchema);
    return dataJson.cloneWithType();
}

# Convert Ballerina ${ediSchema.name} record to EDI string.
#
# + data - Ballerina record to be converted
# + return - EDI string or error
public isolated function toEdiString(${ediSchema.name} data) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    return edi:toEdiString(data, ediSchema);
}

# Get the EDI schema.
#
# + return - EDI schema or error
public isolated function getSchema() returns edi:EdiSchema|error {
    return edi:getSchema(schemaJson);
}

# Convert EDI string to Ballerina ${ediSchema.name} record with schema.
#
# + ediText - EDI string to be converted
# + schema - EDI schema
# + return - Ballerina record or error
public isolated function fromEdiStringWithSchema(string ediText, edi:EdiSchema schema) returns ${ediSchema.name}|error {
    json dataJson = check edi:fromEdiString(ediText, schema);
    return dataJson.cloneWithType();
}

# Convert Ballerina ${ediSchema.name} record to EDI string with schema.
#
# + data - Ballerina record to be converted
# + ediSchema - EDI schema
# + return - EDI string or error
public isolated function toEdiStringWithSchema(${ediSchema.name} data, edi:EdiSchema ediSchema) returns string|error {
    return edi:toEdiString(data, ediSchema);
}
${envelopeFnsCode}

${recordsString}
${envelopeRecordsCode}

final readonly & json schemaJson = ${schema.toJsonString()};
    `;

    check io:fileWriteString(outputPath, schemaCode);

}

// Renders the typed envelope records (Interchange / FunctionalGroup / Transaction)
// for a schema that declares an envelope. The envelope segment wrappers
// (e.g. <Name>InterchangeHeader, <Name>TransactionHeader) are emitted by
// `recordgen.generateCode` via the envelope-level walk added there — so this
// function only needs to reference them by name.
function renderEnvelopeRecords(string name, edi:EdiEnvelopeSchema env) returns string {
    string transactionRecord = string `
# A single transaction within a ${name} interchange.
#
# + transactionHeader - Transaction header segment
# + body - Parsed ${name} body, or the parse error when the body is malformed
# + transactionTrailer - Transaction trailer segment
public type ${name}Transaction record {|
    ${name}TransactionHeader transactionHeader;
    ${name}|error body;
    ${name}TransactionTrailer transactionTrailer;
|};
`;

    // Top-level `<Name>Headers` record returned by `headersFromEdiString`. Field
    // names match the JSON keys emitted by the runtime's `readEnvelopeHeaders`:
    // "interchange", "group" (when present), and "transaction".
    string headersRecord = env?.group is edi:EdiEnvelopeLevel ?
        string `
# Envelope headers of a ${name} interchange.
#
# + interchange - Interchange header
# + group - Functional group header
# + 'transaction - Transaction header
public type ${name}Headers record {|
    ${name}InterchangeHeader interchange;
    ${name}GroupHeader group;
    ${name}TransactionHeader 'transaction;
|};
` :
        string `
# Envelope headers of a ${name} interchange.
#
# + interchange - Interchange header
# + 'transaction - Transaction header
public type ${name}Headers record {|
    ${name}InterchangeHeader interchange;
    ${name}TransactionHeader 'transaction;
|};
`;

    if env?.group is edi:EdiEnvelopeLevel {
        return string `${transactionRecord}
# A functional group within a ${name} interchange.
#
# + groupHeader - Group header segment
# + transactions - Transactions in the group
# + groupTrailer - Group trailer segment
public type ${name}FunctionalGroup record {|
    ${name}GroupHeader groupHeader;
    ${name}Transaction[] transactions;
    ${name}GroupTrailer groupTrailer;
|};

# A parsed ${name} interchange with its full envelope hierarchy.
#
# + interchangeHeader - Interchange header segment
# + groups - Functional groups in the interchange
# + interchangeTrailer - Interchange trailer segment
public type ${name}Interchange record {|
    ${name}InterchangeHeader interchangeHeader;
    ${name}FunctionalGroup[] groups;
    ${name}InterchangeTrailer interchangeTrailer;
|};
${headersRecord}`;
    }

    return string `${transactionRecord}
# A parsed ${name} interchange with its full envelope hierarchy.
#
# + interchangeHeader - Interchange header segment
# + transactions - Transactions in the interchange
# + interchangeTrailer - Interchange trailer segment
public type ${name}Interchange record {|
    ${name}InterchangeHeader interchangeHeader;
    ${name}Transaction[] transactions;
    ${name}InterchangeTrailer interchangeTrailer;
|};
${headersRecord}`;
}

// Renders typed wrappers for `headersFromEdiString` and `interchangeFromEdiString`.
// Each envelope header / trailer JSON is round-tripped through `cloneWithType`
// so the typed wrapper records emitted by `renderEnvelopeRecords` populate
// cleanly. Per-transaction bodies remain fail-safe — a body that came back as
// an error stays as an error in the typed transaction.
function renderEnvelopeFns(string name, edi:EdiEnvelopeSchema env) returns string {
    // Body unwrap helpers — Ballerina does not narrow `json|error` (or
    // `<Name>|error`) across a `?:` ternary, so an inline conversion would
    // be rejected. Two helpers: parse direction (json -> typed) and write
    // direction (typed -> json).
    string bodyHelper = string `

isolated function convert${name}Body(json|error raw) returns ${name}|error {
    if raw is error {
        return raw;
    }
    return raw.cloneWithType();
}

isolated function unwrap${name}Body(${name}|error typed) returns json|error {
    if typed is error {
        return typed;
    }
    return typed.toJson();
}`;

    string convertTxn = env?.group is edi:EdiEnvelopeLevel ?
        string `foreach edi:EdiFunctionalGroup grp in raw.groups ?: [] {
            ${name}Transaction[] txns = [];
            foreach edi:EdiTransaction t in grp.transactions {
                ${name}|error body = convert${name}Body(t.body);
                ${name}TransactionHeader th = check t.transactionHeader.cloneWithType();
                ${name}TransactionTrailer tt = check t.transactionTrailer.cloneWithType();
                txns.push({transactionHeader: th, body, transactionTrailer: tt});
            }
            ${name}GroupHeader gh = check grp.groupHeader.cloneWithType();
            ${name}GroupTrailer gt = check grp.groupTrailer.cloneWithType();
            groups.push({groupHeader: gh, transactions: txns, groupTrailer: gt});
        }` :
        string `foreach edi:EdiTransaction t in raw.transactions ?: [] {
            ${name}|error body = convert${name}Body(t.body);
            ${name}TransactionHeader th = check t.transactionHeader.cloneWithType();
            ${name}TransactionTrailer tt = check t.transactionTrailer.cloneWithType();
            txns.push({transactionHeader: th, body, transactionTrailer: tt});
        }`;

    string assemble = env?.group is edi:EdiEnvelopeLevel ?
        string `${name}FunctionalGroup[] groups = [];
        ${convertTxn}
        ${name}InterchangeHeader ih = check raw.interchangeHeader.cloneWithType();
        ${name}InterchangeTrailer it = check raw.interchangeTrailer.cloneWithType();
        return {interchangeHeader: ih, groups, interchangeTrailer: it};` :
        string `${name}Transaction[] txns = [];
        ${convertTxn}
        ${name}InterchangeHeader ih = check raw.interchangeHeader.cloneWithType();
        ${name}InterchangeTrailer it = check raw.interchangeTrailer.cloneWithType();
        return {interchangeHeader: ih, transactions: txns, interchangeTrailer: it};`;

    // Builds the runtime EdiInterchange (with `json` envelope fields) from a
    // typed `<Name>Interchange`. The transaction body has to detour through
    // `unwrap<Name>Body` because Ballerina does not narrow `<Name>|error`.
    string rawInterchange = env?.group is edi:EdiEnvelopeLevel ?
        string `{
        edi:EdiFunctionalGroup[] rawGroups = [];
        foreach ${name}FunctionalGroup g in msg.groups {
            edi:EdiTransaction[] rawTxns = [];
            foreach ${name}Transaction t in g.transactions {
                json|error body = unwrap${name}Body(t.body);
                rawTxns.push({
                    transactionHeader: t.transactionHeader.toJson(),
                    body: body,
                    transactionTrailer: t.transactionTrailer.toJson()
                });
            }
            rawGroups.push({
                groupHeader: g.groupHeader.toJson(),
                transactions: rawTxns,
                groupTrailer: g.groupTrailer.toJson()
            });
        }
        edi:EdiInterchange built = {
            interchangeHeader: msg.interchangeHeader.toJson(),
            groups: rawGroups,
            interchangeTrailer: msg.interchangeTrailer.toJson()
        };
        raw = built;
    }` :
        string `{
        edi:EdiTransaction[] rawTxns = [];
        foreach ${name}Transaction t in msg.transactions {
            json|error body = unwrap${name}Body(t.body);
            rawTxns.push({
                transactionHeader: t.transactionHeader.toJson(),
                body: body,
                transactionTrailer: t.transactionTrailer.toJson()
            });
        }
        edi:EdiInterchange built = {
            interchangeHeader: msg.interchangeHeader.toJson(),
            transactions: rawTxns,
            interchangeTrailer: msg.interchangeTrailer.toJson()
        };
        raw = built;
    }`;

    return string `

# Parse only the envelope header segments from the given EDI string.
#
# + ediText - EDI string to parse
# + return - Parsed ${name}Headers record, or error if the headers are malformed
public isolated function headersFromEdiString(string ediText) returns ${name}Headers|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json raw = check edi:headersFromEdiString(ediText, ediSchema);
    return raw.cloneWithType();
}

# Parse the full envelope hierarchy from the given EDI string.
# A malformed transaction body becomes an error in that transaction's body field.
#
# + ediText - EDI string to parse
# + return - Parsed ${name}Interchange, or error if the envelope is malformed
public isolated function interchangeFromEdiString(string ediText) returns ${name}Interchange|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw = check edi:interchangeFromEdiString(ediText, ediSchema);
    ${assemble}
}

# Serialise a ${name}Interchange into EDI text; the inverse of interchangeFromEdiString.
# A transaction whose body is an error is refused — filter or replace it before calling.
#
# + msg - The interchange to serialise
# + return - EDI text, or error
public isolated function interchangeToEdiString(${name}Interchange msg) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw;
    ${rawInterchange}
    return edi:interchangeToEdiString(raw, ediSchema);
}
${bodyHelper}`;
}
