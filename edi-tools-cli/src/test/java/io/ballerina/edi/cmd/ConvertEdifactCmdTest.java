/*
 *  Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
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
 * Tests the convertEdifactSchema command end-to-end. The underlying converter fetches the EDIFACT
 * specification from https://service.unece.org/ — the same network dependency as the Ballerina
 * test edi-tools/tests/edifact_conversion_test.bal.
 */
class ConvertEdifactCmdTest {

    @Test
    void testConvertEdifactSchema(@TempDir Path tempDir) throws Exception {
        Path expected = TestUtils.testResources().resolve("edifact/d03a/ORDERS_expected.json");
        Path output = tempDir.resolve("ORDERS.json");

        ConvertEdifactCmd cmd = new ConvertEdifactCmd();
        new CommandLine(cmd).parseArgs("-v", "d03a", "-t", "ORDERS", "-o", tempDir.toString());
        cmd.execute();

        TestUtils.assertJsonEquals(expected, output);
    }
}
