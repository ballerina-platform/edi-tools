/*
 *  Copyright (c) 2026, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
 *
 *  WSO2 LLC. licenses this file to you under the Apache License,
 *  Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

package io.ballerina.edi.cmd;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import picocli.CommandLine;

import java.nio.file.Path;

/**
 * Tests the convertX12Schema command end-to-end against the shared X12 test data in
 * edi-tools/tests/resources (also the golden files of the Ballerina test suite).
 */
class ConvertX12CmdTest {

    @Test
    void testConvertX12SchemaToEdiSchema(@TempDir Path tempDir) throws Exception {
        Path input = TestUtils.testResources().resolve("x12xsd/004010/210.xsd");
        Path expected = TestUtils.testResources().resolve("x12xsd/004010/210.json");
        Path output = tempDir.resolve("210.json");

        ConvertX12Cmd cmd = new ConvertX12Cmd();
        new CommandLine(cmd).parseArgs("-i", input.toString(), "-o", output.toString());
        cmd.execute();

        TestUtils.assertJsonEquals(expected, output);
    }
}
