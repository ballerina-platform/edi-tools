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

import ballerina/edi;
import ballerina/test;
import editools.esl;

@test:Config
function testEslElementValuesAreConverted() returns error? {
    json basedef = {
        "elements": [
            {"id": "128", "name": "ReferenceIdentificationQualifier", "type": "ID", "values": ["0F", "1L", "17"]},
            {"id": "127", "name": "ReferenceIdentification", "type": "AN"}
        ],
        "composites": [
            {
                "id": "C040",
                "name": "ReferenceIdentifier",
                "values": [
                    {"idRef": "128", "usage": "M"},
                    {"idRef": "127", "usage": "O"}
                ]
            }
        ],
        "segments": [
            {
                "id": "REF",
                "name": "ReferenceInformation",
                "values": [
                    {"idRef": "128", "usage": "M"},
                    {"idRef": "127", "usage": "O"},
                    {"idRef": "C040", "usage": "O"}
                ]
            }
        ]
    };
    map<edi:EdiSegSchema> segmentDefinitions = check esl:readSegmentSchemas(basedef);
    edi:EdiSegSchema? refSegment = segmentDefinitions["REF"];
    if refSegment is () {
        test:assertFail("REF segment definition was not generated");
    }

    // fields[0] is the segment code placeholder; fields[1] is element 128.
    test:assertEquals(refSegment.fields[1].values, ["0F", "1L", "17"]);
    test:assertEquals(refSegment.fields[1].discriminator, (),
        "ESL code lists must be plain value constraints; discriminators are declared by schema authors");

    // Element 127 declares no code list.
    test:assertEquals(refSegment.fields[2].values, ());

    // The same element referenced as a component of composite C040 must carry its code list too.
    edi:EdiFieldSchema composite = refSegment.fields[3];
    test:assertEquals(composite.components[0].values, ["0F", "1L", "17"]);
    test:assertEquals(composite.components[0].discriminator, ());
}
