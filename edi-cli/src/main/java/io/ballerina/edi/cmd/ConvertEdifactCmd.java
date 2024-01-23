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
        name = "convertEdifactSchema",
        description = "Converts EDIFACT schema to EDI schema."
)
public class ConvertEdifactCmd implements BLauncherCmd {
    private static final String CMD_NAME = "convertEdifactSchema";
    private final PrintStream printStream;

    @CommandLine.Option(names = {"-v", "--version"}, description = "EDIFACT version")
    private String version;

    @CommandLine.Option(names = {"-t", "--type"}, description = "EDIFACT message type")
    private String type;

    @CommandLine.Option(names = {"-o", "--output"}, description = "EDIFACT schema directory path")
    private String dir;

    public ConvertEdifactCmd() {
        this.printStream = System.out;
    }

    @Override
    public void execute() {
        if (version == null || dir == null) {
            StringBuilder stringBuilder = new StringBuilder();
            printUsage(stringBuilder);
            printStream.println(stringBuilder.toString());
            return;
        }
        try {
            printStream.println("Generating EDI schema for EDIFACT schema ...");
            URL res = ConvertEdifactCmd.class.getClassLoader().getResource("editools.jar");
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = res.openStream()) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            ProcessBuilder processBuilder = new ProcessBuilder(
                    "java", "-jar", tempFile.toAbsolutePath().toString(), CMD_NAME, version, type == null ? "" : type, dir);
            processBuilder.inheritIO();
            Process process = processBuilder.start();
            process.waitFor();
            java.io.InputStream is = process.getInputStream();
            byte b[] = new byte[is.available()];
            is.read(b, 0, b.length);
            printStream.println(new String(b));
        } catch (Exception e) {
            printStream.println("Error in generating edi schema for edifact schema. " + e.getMessage());
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
        stringBuilder.append("Ballerina EDI tools - EDIFACT to Ballerina EDI schema conversion\n");
        stringBuilder.append("bal edi convertEdifactSchema -v <EDIFACT version> -t <EDIFACT message type> -o <output folder>\n");
    }

    @Override
    public void setParentCmdParser(CommandLine commandLine) {

    }
}
