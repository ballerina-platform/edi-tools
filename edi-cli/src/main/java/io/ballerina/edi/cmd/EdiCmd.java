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

import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Main class to implement "edi" command for ballerina.
 */
@CommandLine.Command(
        name = "edi",
        description = "Generates Ballerina service/client for OpenAPI contract and OpenAPI contract for Ballerina" +
                "Service.",
        subcommands = {
            CodegenCmd.class,
            LibgenCmd.class,
            EslCmd.class,
            ConvertX12Cmd.class,
            ConvertEdifactCmd.class
        }
)
public class EdiCmd implements BLauncherCmd {
    private static final String CMD_NAME = "edi";
    private static final String EDI_TOOL = "editools.jar";
    private PrintStream printStream;

    @CommandLine.Option(names = {"-h", "--help"}, hidden = true)
    private boolean helpFlag;

    public EdiCmd() {
        printStream = System.out;
    }

    @Override
    public void execute() {
        try {
            URL res = EdiCmd.class.getClassLoader().getResource(EDI_TOOL);
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = res.openStream()) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            ProcessBuilder processBuilder = new ProcessBuilder("java", "-jar", tempFile.toAbsolutePath().toString());
            processBuilder.inheritIO();
            Process process = processBuilder.start();
            process.waitFor();
            java.io.InputStream is=process.getInputStream();
            byte b[]=new byte[is.available()];
            is.read(b,0,b.length);
            printStream.println(new String(b));
        } catch (Exception e) {
            printStream.println("Error in executing EDI CLI commands. " + e.getMessage());
            e.printStackTrace();
        }
    }

    @Override
    public String getName() {
        return CMD_NAME;
    }

    @Override
    public void printLongDesc(StringBuilder out) {
    }

    @Override
    public void printUsage(StringBuilder stringBuilder) {
        stringBuilder.append("Ballerina EDI tools -\n");
        stringBuilder.append("Ballerina code generation for edi schema: bal edi codegen -s <schema json path> -o <output bal file path>\n");
        stringBuilder.append("EDI library generation: bal edi libgen -O <org name> -l <library name> -s <EDI schema folder> -o <output folder>\n");
        stringBuilder.append("ESL to Ballerina EDI schema conversion: bal edi convertESL -b <Segment definitions file path> -s <ESL schema file/folder> -o <output file/folder>\n");
        stringBuilder.append("Ballerina X12 schema conversion: bal edi codegen [-H] [-c] -i <schema input path> -o <output json file/folder path> [-d] <segment details path>\n");
        stringBuilder.append("Ballerina X12 schema conversion: bal edi codegen [-H] [-c] -i <schema input path> -o <output json file/folder path> [-d] <segment details path>\n");
        stringBuilder.append("EDIFACT to Ballerina EDI schema conversion: bal edi convertEdifactSchema -v <EDIFACT version> -t <EDIFACT message type> -o <output folder>\n");
    }

    @Override
    public void setParentCmdParser(CommandLine parentCmdParser) {
    }
}
