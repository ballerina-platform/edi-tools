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

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

@CommandLine.Command(name = "libgen", description = "Generates Ballerina package for code for the given collection of EDI schemas.")
public class LibgenCmd implements BLauncherCmd {
    private static final String CMD_NAME = "libgen";
    private static final String EDI_TOOL = "editools.jar";

    private PrintStream printStream;

    @CommandLine.Option(names = { "-p", "--package" }, description = "Package name(organization-name/package-name)")
    private String packageName;

    @CommandLine.Option(names = { "-i", "--input" }, description = "EDI schemas path")
    private String schemaPath;

    @CommandLine.Option(names = { "-o", "--output" }, description = "Output path")
    private String outputPath;

    public LibgenCmd() {
        printStream = System.out;
    }

    @Override
    public void execute() {
        if (packageName == null || schemaPath == null || outputPath == null) {
            StringBuilder stringBuilder = new StringBuilder();
            printUsage(stringBuilder);
            printStream.println(stringBuilder.toString());
            return;
        }
        if (!packageName.matches("^[a-z0-9]+/[a-z0-9]+$")) {
            printStream.println("Invalid package name. Package name should be in the format orgname/packagename");
            return;
        }
        try {
            printStream.println("Generating library package for " + packageName + " : " + schemaPath);
            Class<?> clazz = LibgenCmd.class;
            ClassLoader classLoader = clazz.getClassLoader();
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = classLoader.getResourceAsStream(EDI_TOOL)) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            String orgName = packageName.split("/")[0];
            String libName = packageName.split("/")[1];
            ProcessBuilder processBuilder = new ProcessBuilder(
                    "java", "-jar", tempFile.toAbsolutePath().toString(), "libgen", orgName, libName, schemaPath,
                    outputPath);
            processBuilder.inheritIO();
            Process process = processBuilder.start();
            process.waitFor();
            java.io.InputStream is = process.getInputStream();
            byte b[] = new byte[is.available()];
            is.read(b, 0, b.length);
            printStream.println(new String(b));
        } catch (Exception e) {
            printStream.println("Error in generating library. " + e.getMessage());
            e.printStackTrace();
        }
    }

    @Override
    public String getName() {
        return CMD_NAME;
    }

    @Override
    public void printLongDesc(StringBuilder stringBuilder) {
        Class<?> clazz = EdiCmd.class;
        ClassLoader classLoader = clazz.getClassLoader();
        InputStream inputStream = classLoader.getResourceAsStream("cli-docs/libgen.help");
        if (inputStream != null) {
            try (InputStreamReader inputStreamREader = new InputStreamReader(inputStream, StandardCharsets.UTF_8);
                    BufferedReader br = new BufferedReader(inputStreamREader)) {
                String content = br.readLine();
                printStream.append(content);
                while ((content = br.readLine()) != null) {
                    printStream.append('\n').append(content);
                }
            } catch (IOException e) {
                printStream.println("Helper text is not available.");
            }
        }
    }

    @Override
    public void printUsage(StringBuilder stringBuilder) {
    }

    @Override
    public void setParentCmdParser(CommandLine commandLine) {
    }
}
