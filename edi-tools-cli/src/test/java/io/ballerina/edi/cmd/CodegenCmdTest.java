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

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests the codegen command end-to-end: the command extracts the bundled editools.jar and runs it
 * with the `bal` resolved from PATH (pointed at the local distribution by the Gradle test task).
 */
class CodegenCmdTest {

    @Test
    void testCodegenGeneratesParserSource(@TempDir Path tempDir) throws Exception {
        Path schema = TestUtils.copyResource("codegen/schema.json", tempDir);
        Path output = tempDir.resolve("gen_code.bal");

        CodegenCmd cmd = new CodegenCmd();
        new CommandLine(cmd).parseArgs("-i", schema.toString(), "-o", output.toString());
        cmd.execute();

        assertTrue(Files.exists(output), "Generated source was not created: " + output);
        String generated = Files.readString(output);
        assertTrue(!generated.isBlank(), "Generated source is empty");
        assertTrue(generated.contains("function fromEdiString("), "Missing fromEdiString function");
        assertTrue(generated.contains("function toEdiString("), "Missing toEdiString function");
        assertTrue(generated.contains("SimpleOrder"), "Missing schema record type SimpleOrder");
    }
}
