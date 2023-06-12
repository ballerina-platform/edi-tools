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
            LibgenCmd.class
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
    }

    @Override
    public void setParentCmdParser(CommandLine parentCmdParser) {
    }
}
