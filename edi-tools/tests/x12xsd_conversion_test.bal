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
import ballerina/test;
import editools.x12xsd;

@test:Config
function testX12XsdConversion() returns error? {
    string inpath = "tests/resources/x12xsd/004010/210.xsd";
    string outpath = "tests/resources/x12xsd/004010/210.json";
    check x12xsd:convertFromX12XsdAndWrite(inpath, outpath);
}

@test:Config
function testX12XsdConversionWithHeaders() returns error? {
    string inpath = "tests/resources/x12xsd/headers";
    string outpath = "tests/resources/x12xsd/headers/schema.json";
    check x12xsd:convertFromX12WithHeadersAndWrite(inpath, outpath);

    edi:EdiSchema schema = check (check io:fileReadJson(outpath)).cloneWithType();
    edi:EdiEnvelopeSchema? envelope = schema.envelope;
    if envelope is () {
        test:assertFail("Headers-mode conversion did not populate the envelope.");
    }
    test:assertEquals(refCode(schema, envelope.interchange.header[0]), "ISA");
    test:assertEquals(refCode(schema, envelope.interchange.trailer[0]), "IEA");
    edi:EdiEnvelopeLevel? group = envelope.group;
    if group is () {
        test:assertFail("Headers-mode envelope is missing the functional group level.");
    }
    test:assertEquals(refCode(schema, group.header[0]), "GS");
    test:assertEquals(refCode(schema, group.trailer[0]), "GE");
    test:assertEquals(refCode(schema, envelope.'transaction.header[0]), "ST");
    test:assertEquals(refCode(schema, envelope.'transaction.trailer[0]), "SE");

    // The envelope segments must be lifted out of the top-level body.
    foreach edi:EdiUnitSchema unit in schema.segments {
        string? code = refCode(schema, unit);
        test:assertNotEquals(code, "ISA", "ISA should be lifted into the envelope.");
        test:assertNotEquals(code, "ST", "ST should be lifted into the envelope.");
    }
}

function refCode(edi:EdiSchema schema, edi:EdiUnitSchema unit) returns string? {
    if unit is edi:EdiSegSchema {
        return unit.code;
    }
    if unit is edi:EdiUnitRef {
        edi:EdiSegSchema? def = schema.segmentDefinitions[unit.ref];
        return def?.code;
    }
    return ();
}

@test:Config
function testInlineEnumerationsBecomeValueDiscriminators() returns error? {
    string inpath = "tests/resources/x12xsd/qualifier-constraints/834-ref.xsd";
    string outpath = "tests/resources/x12xsd/qualifier-constraints/834-ref.json";
    check x12xsd:convertFromX12XsdAndWrite(inpath, outpath);
    edi:EdiSchema schema = check (check io:fileReadJson(outpath)).cloneWithType();

    // The three REF definitions are same-code siblings, so their inline qualifier
    // enumerations must be attached as values and marked as discriminators.
    edi:EdiFieldSchema policyQualifier = check getField(schema, "REF_MemberPolicyNumber_2000",
        "REF01__ReferenceIdentificationQualifier");
    test:assertEquals(policyQualifier.discriminator, ["1L"],
        "Qualifier of a same-code sibling definition must become a discriminator");
    test:assertEquals(policyQualifier.values, (), "A discriminating enumeration is not duplicated into values");

    edi:EdiFieldSchema supplementalQualifier = check getField(schema, "REF_MemberSupplementalIdentifier_2000",
        "REF01__ReferenceIdentificationQualifier");
    test:assertEquals(supplementalQualifier.discriminator, ["17", "23", "DX"]);

    // ST has no same-code sibling: its inline enumeration is demoted to a plain value
    // constraint and must not participate in segment matching.
    edi:EdiFieldSchema stIdentifier = check getField(schema, "ST_TransactionSetHeader",
        "ST01__TransactionSetIdentifierCode");
    test:assertEquals(stIdentifier.values, ["834"]);
    test:assertEquals(stIdentifier.discriminator, (), "Unique-code definitions must not get discriminators");

    // Non-enumerated fields must carry no value constraints.
    edi:EdiFieldSchema policyIdentifier = check getField(schema, "REF_MemberPolicyNumber_2000",
        "REF02__MemberGroupOrPolicyNumber");
    test:assertEquals(policyIdentifier.values, ());
    test:assertEquals(policyIdentifier.discriminator, ());
}

@test:Config
function testNamedTypeEnumerationsResolvedFromIncludedSchema() returns error? {
    string inpath = "tests/resources/x12xsd/named-type-constraints/834-named.xsd";
    string outpath = "tests/resources/x12xsd/named-type-constraints/834-named.json";
    check x12xsd:convertFromX12XsdAndWrite(inpath, outpath);
    edi:EdiSchema schema = check (check io:fileReadJson(outpath)).cloneWithType();

    // DE_128 is defined in the included codes.xsd. Its full code list must be attached
    // as a value constraint, but named-type code lists never become discriminators —
    // only inline (position-narrowed) enumerations do.
    edi:EdiFieldSchema subscriberQualifier = check getField(schema, "REF_SubscriberIdentifier_2000",
        "REF01__ReferenceIdentificationQualifier");
    test:assertEquals(subscriberQualifier.values, ["0F", "1L", "17", "23", "DX"]);
    test:assertEquals(subscriberQualifier.discriminator, (),
        "Named-type code lists must stay plain value constraints even for same-code siblings");

    edi:EdiFieldSchema stIdentifier = check getField(schema, "ST_TransactionSetHeader",
        "ST01__TransactionSetIdentifierCode");
    test:assertEquals(stIdentifier.values, ["834"]);
    test:assertEquals(stIdentifier.discriminator, ());
}

function getField(edi:EdiSchema schema, string segDefName, string fieldTag) returns edi:EdiFieldSchema|error {
    edi:EdiSegSchema? segDef = schema.segmentDefinitions[segDefName];
    if segDef is () {
        return error(string `Segment definition not found: ${segDefName}`);
    }
    foreach edi:EdiFieldSchema fieldSchema in segDef.fields {
        if fieldSchema.tag == fieldTag {
            return fieldSchema;
        }
    }
    return error(string `Field not found. Segment definition: ${segDefName}, Field: ${fieldTag}`);
}
