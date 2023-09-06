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
        name = "libgen",
        description = "Generated code for a given EDI schema."
)
public class LibgenCmd implements BLauncherCmd {
    private static final String CMD_NAME = "libgen";
    private PrintStream printStream;

    @CommandLine.Option(names = {"-O", "--org"}, description = "Organization name")
    private String orgName;

    @CommandLine.Option(names = {"-n", "--name"}, description = "Library name")
    private String libName;

    @CommandLine.Option(names = {"-s", "--schema"}, description = "EDI schema path")
    private String schemaPath;

    @CommandLine.Option(names = {"-o", "--output"}, description = "Output path")
    private String outputPath;

    public LibgenCmd() {
        printStream = System.out;
    }

    @Override
    public void execute() {
        if (orgName == null || libName == null || schemaPath == null || outputPath == null) {
            StringBuilder stringBuilder = new StringBuilder();
            printUsage(stringBuilder);
            printStream.println(stringBuilder.toString());
            return;
        }
        try {
            printStream.println("Generating library package for " + orgName + " - " + libName + " : " + schemaPath);
            URL res = LibgenCmd.class.getClassLoader().getResource("editools.jar");
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = res.openStream()) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            ProcessBuilder processBuilder = new ProcessBuilder(
                    "java", "-jar", tempFile.toAbsolutePath().toString(), "libgen", orgName, libName, schemaPath, outputPath);
            Process process = processBuilder.start();
            process.waitFor();
            java.io.InputStream is=process.getInputStream();
            byte b[]=new byte[is.available()];
            is.read(b,0,b.length);
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

    }

    @Override
    public void printUsage(StringBuilder stringBuilder) {
        stringBuilder.append("Ballerina EDI tools - Library generation\n");
        stringBuilder.append("EDI library generation: bal edi libgen -O <org name> -l <library name> -s <EDI schema folder> -o <output folder>\n");
    }

    @Override
    public void setParentCmdParser(CommandLine commandLine) {

    }
}
