/*
 *  Copyright (c) 2023, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 *  WSO2 Inc. licenses this file to you under the Apache License,
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

import io.ballerina.cli.BLauncherCmd;
import picocli.CommandLine;

import java.io.InputStream;
import java.io.PrintStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

@CommandLine.Command(
        name = "codegen",
        description = "Generated code for a given EDI schema."
)
public class CodegenCmd implements BLauncherCmd {
    private static final String CMD_NAME = "codegen";
    private final PrintStream printStream;

    @CommandLine.Option(names = {"-s", "--schema"}, description = "EDI schema path")
    private String schemaPath;

    @CommandLine.Option(names = {"-o", "--output"}, description = "Output path")
    private String outputPath;

    public CodegenCmd() {
        this.printStream = System.out;
    }

    @Override
    public void execute() {
        if (schemaPath == null || outputPath == null) {
            StringBuilder stringBuilder = new StringBuilder();
            printUsage(stringBuilder);
            printStream.println(stringBuilder.toString());
            return;
        }
        try {
            printStream.println("Generating code for " + schemaPath + "...");
            URL res = CodegenCmd.class.getClassLoader().getResource("editools.jar");
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = res.openStream()) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            ProcessBuilder processBuilder = new ProcessBuilder(
                    "java", "-jar", tempFile.toAbsolutePath().toString(), "codegen", schemaPath, outputPath);
            processBuilder.redirectErrorStream(true);
            Process process = processBuilder.start();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    printStream.println(line);
                }
            }
            process.waitFor();
            java.io.InputStream is = process.getInputStream();
            byte b[] = new byte[is.available()];
            is.read(b,0,b.length);
            printStream.println(new String(b));
        } catch (Exception e) {
            printStream.println("Error in generating code. " + e.getMessage());
            e.printStackTrace();
        }
    }

    @Override
    public String getName() {
        return CMD_NAME;
    }

    @Override
    public void printLongDesc(StringBuilder stringBuilder) {

    }

    @Override
    public void printUsage(StringBuilder stringBuilder) {
        stringBuilder.append("Ballerina EDI tools - Code generation\n");
        stringBuilder.append("Ballerina code generation for edi schema: bal edi codegen -s <schema json path> -o <output bal file path>\n");
    }

    @Override
    public void setParentCmdParser(CommandLine commandLine) {

    }
}
