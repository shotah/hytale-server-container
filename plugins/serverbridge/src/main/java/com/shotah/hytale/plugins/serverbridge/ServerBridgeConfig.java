package com.shotah.hytale.plugins.serverbridge;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

public class ServerBridgeConfig {

    private boolean statusEnabled = true;
    private boolean commandsEnabled = true;
    private int statusIntervalSeconds = 5;
    private int commandPollSeconds = 1;
    private String statusFile = "server-status.json";
    private String commandsFile = "server-commands.json";

    public boolean isStatusEnabled() {
        return statusEnabled;
    }

    public boolean isCommandsEnabled() {
        return commandsEnabled;
    }

    public int getStatusIntervalSeconds() {
        return statusIntervalSeconds;
    }

    public int getCommandPollSeconds() {
        return commandPollSeconds;
    }

    public String getStatusFile() {
        return statusFile;
    }

    public String getCommandsFile() {
        return commandsFile;
    }

    public static ServerBridgeConfig load(Path configFile) throws IOException {
        var config = new ServerBridgeConfig();

        if (Files.exists(configFile)) {
            var props = new Properties();
            try (InputStream in = Files.newInputStream(configFile)) {
                props.load(in);
            }
            config.statusEnabled = Boolean.parseBoolean(props.getProperty("statusEnabled", "true"));
            config.commandsEnabled = Boolean.parseBoolean(props.getProperty("commandsEnabled", "true"));
            config.statusIntervalSeconds = Integer.parseInt(props.getProperty("statusIntervalSeconds", "5"));
            config.commandPollSeconds = Integer.parseInt(props.getProperty("commandPollSeconds", "1"));
            config.statusFile = props.getProperty("statusFile", "server-status.json");
            config.commandsFile = props.getProperty("commandsFile", "server-commands.json");
        }

        return config;
    }

    public void save(Path configFile) throws IOException {
        Files.createDirectories(configFile.getParent());
        var props = new Properties();
        props.setProperty("statusEnabled", String.valueOf(statusEnabled));
        props.setProperty("commandsEnabled", String.valueOf(commandsEnabled));
        props.setProperty("statusIntervalSeconds", String.valueOf(statusIntervalSeconds));
        props.setProperty("commandPollSeconds", String.valueOf(commandPollSeconds));
        props.setProperty("statusFile", statusFile);
        props.setProperty("commandsFile", commandsFile);
        try (OutputStream out = Files.newOutputStream(configFile)) {
            props.store(out, "Shotah ServerBridge Plugin Configuration");
        }
    }
}
