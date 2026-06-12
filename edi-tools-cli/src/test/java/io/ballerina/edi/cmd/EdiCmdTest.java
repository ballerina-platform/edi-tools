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
import picocli.CommandLine;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests the top-level edi command: subcommand registration and the no-argument invocation,
 * which runs the bundled editools.jar (printing its usage) via the `bal` from PATH.
 */
class EdiCmdTest {

    @Test
    void testAllSubcommandsAreRegistered() {
        CommandLine commandLine = new CommandLine(new EdiCmd());
        Set<String> subcommands = commandLine.getSubcommands().keySet();
        assertTrue(subcommands.containsAll(Set.of(
                        "codegen", "libgen", "convertESL", "convertX12Schema", "convertEdifactSchema")),
                "Missing subcommands, found: " + subcommands);
    }

    @Test
    void testNoArgumentInvocationRunsEdiTool() {
        PrintStream originalOut = System.out;
        ByteArrayOutputStream captured = new ByteArrayOutputStream();
        System.setOut(new PrintStream(captured));
        try {
            // EdiCmd picks up System.out in its constructor; the command swallows failures,
            // so the error message on the captured stream is the only failure signal
            new EdiCmd().execute();
        } finally {
            System.setOut(originalOut);
        }
        assertFalse(captured.toString().contains("Error in executing EDI CLI commands"),
                "EDI tool invocation failed: " + captured);
    }
}
