/*
 *  Copyright (c) 2023, WSO2 LLC (http://www.wso2.org) All Rights Reserved.
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

import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

@CommandLine.Command(
        name = "convertX12Schema",
        description = "Converts X12 schema to JSON schema."
)
public class ConvertX12Cmd implements BLauncherCmd {

    private static final String CMD_NAME = "convertX12Schema";
    private static final String EDI_TOOL = "editools.jar";

    private final PrintStream printStream;

    @CommandLine.Option(names = {"-H", "--headers"}, description = {"Include headers in the input"})
    private boolean headersIncluded;

    @CommandLine.Option(names = {"-c", "--collection"}, description = {"Switch to collection mode"})
    private boolean collectionMode;

    @CommandLine.Option(names = {"-i", "--input"}, description = {"X12 schema path"})
    private String inputPath;

    @CommandLine.Option(names = {"-o", "--output"}, description = {"Output path"})
    private String outputPath;

    @CommandLine.Option(names = {"-d", "--segdet"}, description = {"Segment details path"})
    private String segdetPath;

    public ConvertX12Cmd() {
        this.printStream = System.out;
    }

    @Override
    public void execute() {
        if (inputPath == null || outputPath == null) {
            StringBuilder stringBuilder = new StringBuilder();
            printUsage(stringBuilder);
            printStream.println(stringBuilder.toString());
            return;
        }
        StringBuilder stringBuilder = new StringBuilder("Converting schema ");
        if(collectionMode){
            stringBuilder.append("in collection ");
        }
        if(headersIncluded){
            stringBuilder.append("with headers ");
        }
        stringBuilder.append(inputPath).append("...");
        printStream.println(stringBuilder);
        Class<?> clazz = ConvertX12Cmd.class;
        ClassLoader classLoader = clazz.getClassLoader();
        try {
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = classLoader.getResourceAsStream(EDI_TOOL)) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            List<String> argsList = new ArrayList<>();
            argsList.add("java");
            argsList.add("-jar");
            argsList.add(tempFile.toAbsolutePath().toString());
            argsList.add(CMD_NAME);
            if(headersIncluded){
                argsList.add("H");
            }
            if(collectionMode){
                argsList.add("c");
            }
            argsList.add(inputPath);
            argsList.add(outputPath);
            if(segdetPath != null){
                argsList.add(segdetPath);
            }
            ProcessBuilder processBuilder = new ProcessBuilder(argsList);
            Process process = processBuilder.start();
            process.waitFor();
            java.io.InputStream is = process.getInputStream();
            byte[] b = new byte[is.available()];
            is.read(b,0,b.length);
            printStream.println(new String(b));

        } catch (IOException | InterruptedException e) {
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
        // Not implemented
    }

    @Override
    public void printUsage(StringBuilder stringBuilder) {
        stringBuilder.append("Ballerina EDI tools - X12 Schema Conversion\n");
        stringBuilder.append("Ballerina X12 schema conversion: bal edi ").append(CMD_NAME).append(" [-H] [-c] -i <schema input path> -o <output json file/folder path> [-d] <segment details path>\n");
        stringBuilder.append("Options:\n");
        stringBuilder.append("  -H, --headers       Enable headers mode (Input should be a directory and should contain header schemas)\n");
        stringBuilder.append("  -c, --collection    Enable collection mode (Input should be a directory)\n");
        stringBuilder.append("  -i, --input string  Input path\n");
        stringBuilder.append("  -o, --output string Output path\n");
        stringBuilder.append("  -d, --segdet string Segment details path\n");
    }

    @Override
    public void setParentCmdParser(CommandLine commandLine) {
        // Not implemented
    }
}
