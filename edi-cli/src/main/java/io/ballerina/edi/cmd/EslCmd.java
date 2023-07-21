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
        name = "convertESL",
        description = "Converts ESL schemas to Ballerina compatible JSON schemas."
)
public class EslCmd implements BLauncherCmd {
    private static final String CMD_NAME = "convertESL";
    private PrintStream printStream;

    @CommandLine.Option(names = {"-b", "--basedef"}, description = "Segment definitions path")
    private String basedefPath;

    @CommandLine.Option(names = {"-s", "--schema"}, description = "ESL schema path")
    private String schemaPath;

    @CommandLine.Option(names = {"-o", "--output"}, description = "Output path")
    private String outputPath;

    public EslCmd() {
        printStream = System.out;
    }

    @Override
    public void execute() {
        if (basedefPath == null || schemaPath == null || outputPath == null) {
            StringBuilder stringBuilder = new StringBuilder();
            printUsage(stringBuilder);
            printStream.println(stringBuilder.toString());
            return;
        }
        try {
            printStream.println("Converting ESL schemas in " + schemaPath);
            URL res = LibgenCmd.class.getClassLoader().getResource("editools.jar");
            Path tempFile = Files.createTempFile(null, null);
            try (InputStream in = res.openStream()) {
                Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }
            ProcessBuilder processBuilder = new ProcessBuilder(
                    "java", "-jar", tempFile.toAbsolutePath().toString(), "convertESL", schemaPath, basedefPath, outputPath);
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
        stringBuilder.append("Ballerina EDI tools - ESL to Ballerina EDI schema conversion\n");
        stringBuilder.append("bal edi convertESL -b <Segment definitions file path> -s <ESL schema file/folder> -o <output file/folder>\n");
    }

    @Override
    public void setParentCmdParser(CommandLine commandLine) {

    }
}
