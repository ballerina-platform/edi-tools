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
// for a schema that declares an envelope. Header / trailer fields stay as `json`
// — the structured envelope shape is exposed but the per-field decomposition of
// envelope segments is left as JSON for callers who need it.
function renderEnvelopeRecords(string name, edi:EdiEnvelopeSchema env) returns string {
    string transactionRecord = string `
public type ${name}Transaction record {|
    json transactionHeader;
    ${name}|error body;
    json transactionTrailer;
|};
`;

    if env?.group is edi:EdiEnvelopeLevel {
        return string `${transactionRecord}
public type ${name}FunctionalGroup record {|
    json groupHeader;
    ${name}Transaction[] transactions;
    json groupTrailer;
|};

public type ${name}Interchange record {|
    json interchangeHeader;
    ${name}FunctionalGroup[] groups;
    json interchangeTrailer;
|};
`;
    }

    return string `${transactionRecord}
public type ${name}Interchange record {|
    json interchangeHeader;
    ${name}Transaction[] transactions;
    json interchangeTrailer;
|};
`;
}

// Renders typed wrappers for `headersFromEdiString` and `interchangeFromEdiString`.
function renderEnvelopeFns(string name, edi:EdiEnvelopeSchema env) returns string {
    string convertTxn = env?.group is edi:EdiEnvelopeLevel ?
        string `foreach var grp in raw.groups ?: [] {
            ${name}Transaction[] txns = [];
            foreach var t in grp.transactions {
                ${name}|error body = t.body is error ? <error>t.body : (<json>t.body).cloneWithType();
                txns.push({transactionHeader: t.transactionHeader, body, transactionTrailer: t.transactionTrailer});
            }
            groups.push({groupHeader: grp.groupHeader, transactions: txns, groupTrailer: grp.groupTrailer});
        }` :
        string `foreach var t in raw.transactions ?: [] {
            ${name}|error body = t.body is error ? <error>t.body : (<json>t.body).cloneWithType();
            txns.push({transactionHeader: t.transactionHeader, body, transactionTrailer: t.transactionTrailer});
        }`;

    string assemble = env?.group is edi:EdiEnvelopeLevel ?
        string `${name}FunctionalGroup[] groups = [];
        ${convertTxn}
        return {interchangeHeader: raw.interchangeHeader, groups, interchangeTrailer: raw.interchangeTrailer};` :
        string `${name}Transaction[] txns = [];
        ${convertTxn}
        return {interchangeHeader: raw.interchangeHeader, transactions: txns, interchangeTrailer: raw.interchangeTrailer};`;

    return string `

# Parse only the envelope header segments from the given EDI string.
#
# + ediText - EDI string to parse
# + return - Parsed header sections as JSON, or error
public isolated function headersFromEdiString(string ediText) returns json|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    return edi:headersFromEdiString(ediText, ediSchema);
}

# Parse the full envelope hierarchy from the given EDI string.
# Envelope headers and trailers are fail-fast; transaction body is fail-safe —
# a malformed body becomes an error in that transaction's body field
# without aborting the rest of the interchange.
#
# + ediText - EDI string to parse
# + return - Parsed ${name}Interchange, or error if the envelope is malformed
public isolated function interchangeFromEdiString(string ediText) returns ${name}Interchange|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw = check edi:interchangeFromEdiString(ediText, ediSchema);
    ${assemble}
}`;
}
