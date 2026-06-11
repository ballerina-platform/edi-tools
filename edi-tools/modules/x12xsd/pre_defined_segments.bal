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

// X12 envelope segments (ISA/IEA, GS/GE) are not present in transaction-set
// XSDs, so they are inlined here. ST/SE come from the XSD itself and are
// extracted from `segments` by `populateX12Envelope`.

final edi:EdiSegSchema ISA_SEG = {
    code: "ISA",
    tag: "InterchangeControlHeader",
    fields: [
        {tag: "code", required: true},
        {tag: "authInfoQualifier", required: true},
        // ISA02 / ISA04 are fixed-width (10 chars) and carry all spaces when
        // ISA01 / ISA03 is "00" (no authorization / security information) —
        // which is the common case in production. The runtime treats
        // whitespace-only required fields as missing, so these must be
        // optional to accept standard interchanges.
        {tag: "authInfo", required: false},
        {tag: "securityQualifier", required: true},
        {tag: "securityInfo", required: false},
        {tag: "senderQualifier", required: true},
        {tag: "senderId", required: true},
        {tag: "receiverQualifier", required: true},
        {tag: "receiverId", required: true},
        {tag: "date", required: true},
        {tag: "time", required: true},
        // ISA11 in 004010 is the Interchange Control Standards Identifier
        // (constant "U"). Later versions repurpose it as the repetition
        // separator, but this converter targets the 004010 family.
        {tag: "standardsId", required: true},
        {tag: "version", required: true},
        {tag: "controlNumber", required: true, dataType: edi:STRING},
        {tag: "ackRequested", required: true},
        {tag: "usageIndicator", required: true},
        {tag: "componentSeparator", required: true}
    ]
};

final edi:EdiSegSchema IEA_SEG = {
    code: "IEA",
    tag: "InterchangeControlTrailer",
    fields: [
        {tag: "code", required: true},
        {tag: "groupCount", required: true, dataType: edi:INT},
        {tag: "controlNumber", required: true, dataType: edi:STRING}
    ]
};

final edi:EdiSegSchema GS_SEG = {
    code: "GS",
    tag: "FunctionalGroupHeader",
    fields: [
        {tag: "code", required: true},
        {tag: "functionalIdentifier", required: true},
        {tag: "senderId", required: true},
        {tag: "receiverId", required: true},
        {tag: "date", required: true},
        {tag: "time", required: true},
        {tag: "controlNumber", required: true, dataType: edi:STRING},
        {tag: "agencyCode", required: true},
        {tag: "version", required: true}
    ]
};

final edi:EdiSegSchema GE_SEG = {
    code: "GE",
    tag: "FunctionalGroupTrailer",
    fields: [
        {tag: "code", required: true},
        {tag: "transactionCount", required: true, dataType: edi:INT},
        {tag: "controlNumber", required: true, dataType: edi:STRING}
    ]
};
