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

import ballerina/file;
import ballerina/io;
import ballerina/os;
import ballerina/test;

// X12-style schema WITH a functional group envelope level — exercises the
// grouped variants of the typed wrappers (FunctionalGroup record, groups[]
// loops in interchangeFrom/ToEdiString).
final readonly & json x12EnvelopeSchemaJson = {
    "name": "Rate",
    "tag": "Rate",
    "delimiters": {"segment": "~", "field": "*", "component": ":"},
    "envelope": {
        "interchange": {
            "header": [{"ref": "ISA"}],
            "trailer": [{"ref": "IEA"}]
        },
        "group": {
            "header": [{"ref": "GS"}],
            "trailer": [{"ref": "GE"}]
        },
        "transaction": {
            "header": [{"ref": "ST"}],
            "trailer": [{"ref": "SE"}]
        }
    },
    "segments": [
        {
            "code": "B3",
            "tag": "InvoiceDetail",
            "minOccurances": 1,
            "maxOccurances": 1,
            "fields": [
                {"tag": "code"},
                {"tag": "invoiceNumber"}
            ]
        }
    ],
    "segmentDefinitions": {
        "ISA": {
            "code": "ISA",
            "tag": "InterchangeControlHeader",
            "fields": [
                {"tag": "code"},
                {"tag": "controlNumber"}
            ]
        },
        "IEA": {
            "code": "IEA",
            "tag": "InterchangeControlTrailer",
            "fields": [
                {"tag": "code"},
                {"tag": "groupCount", "dataType": "int"},
                {"tag": "controlNumber"}
            ]
        },
        "GS": {
            "code": "GS",
            "tag": "FunctionalGroupHeader",
            "fields": [
                {"tag": "code"},
                {"tag": "controlNumber"}
            ]
        },
        "GE": {
            "code": "GE",
            "tag": "FunctionalGroupTrailer",
            "fields": [
                {"tag": "code"},
                {"tag": "transactionCount", "dataType": "int"},
                {"tag": "controlNumber"}
            ]
        },
        "ST": {
            "code": "ST",
            "tag": "TransactionSetHeader",
            "fields": [
                {"tag": "code"},
                {"tag": "transactionSetIdentifier"},
                {"tag": "controlNumber"}
            ]
        },
        "SE": {
            "code": "SE",
            "tag": "TransactionSetTrailer",
            "fields": [
                {"tag": "code"},
                {"tag": "segmentCount", "dataType": "int"},
                {"tag": "controlNumber"}
            ]
        }
    }
};

// Verifies that the generated typed-wrapper output actually COMPILES, for
// both envelope shapes:
//   * EDIFACT-style (no group level)  — default module
//   * X12-style (with group level)    — submodule mx12
// The generated sources are written into a temporary Ballerina package whose
// Ballerina.toml pins ballerina/edi 1.6.0 from the local repository, and
// `bal build` is run on it. A non-zero exit code fails the test.
@test:Config {}
function testGeneratedEnvelopeCodeCompiles() returns error? {
    string tmpDir = check file:createTempDir();
    string pkgPath = check file:joinPath(tmpDir, "compilecheck");
    string x12ModulePath = check file:joinPath(pkgPath, "modules", "mx12");
    check file:createDir(x12ModulePath, file:RECURSIVE);

    string balToml = string `
[package]
org = "wso2test"
name = "compilecheck"
version = "0.1.0"

[[dependency]]
org = "ballerina"
name = "edi"
version = "${EDI_RUNTIME_VERSION}"
repository = "local"
`;
    check io:fileWriteString(check file:joinPath(pkgPath, "Ballerina.toml"), balToml);

    // Entry point importing the X12 submodule so `bal build` compiles it too.
    string mainBal = string `
import compilecheck.mx12 as _;

public function main() {
}
`;
    check io:fileWriteString(check file:joinPath(pkgPath, "main.bal"), mainBal);

    // EDIFACT shape (no group) in the default module.
    check generateCodeForSchema(envelopeSchemaJson, check file:joinPath(pkgPath, "orders_gen.bal"));
    // X12 shape (with group) in the submodule.
    check generateCodeForSchema(x12EnvelopeSchemaJson, check file:joinPath(x12ModulePath, "rate_gen.bal"));

    os:Process proc = check os:exec({value: "bal", arguments: ["build", pkgPath]});
    int exitCode = check proc.waitForExit();
    if exitCode != 0 {
        byte[] stdoutBytes = check proc.output(io:stdout);
        byte[] stderrBytes = check proc.output(io:stderr);
        string stdoutText = check string:fromBytes(stdoutBytes);
        string stderrText = check string:fromBytes(stderrBytes);
        test:assertFail(string `Generated envelope code failed to compile (bal build exit ${exitCode}).
stdout:
${stdoutText}
stderr:
${stderrText}`);
    }

    check file:remove(tmpDir, file:RECURSIVE);
}
