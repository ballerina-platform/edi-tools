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