package com.shotah.hytale.plugins.serverbridge;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

import static org.junit.jupiter.api.Assertions.*;

class ServerBridgeConfigTest {

    @Test
    void defaults_statusEnabled() {
        var config = new ServerBridgeConfig();
        assertTrue(config.isStatusEnabled());
    }

    @Test
    void defaults_commandsEnabled() {
        var config = new ServerBridgeConfig();
        assertTrue(config.isCommandsEnabled());
    }

    @Test
    void defaults_statusIntervalIsFiveSeconds() {
        var config = new ServerBridgeConfig();
        assertEquals(5, config.getStatusIntervalSeconds());
    }

    @Test
    void defaults_commandPollIsOneSecond() {
        var config = new ServerBridgeConfig();
        assertEquals(1, config.getCommandPollSeconds());
    }

    @Test
    void defaults_statusFileName() {
        var config = new ServerBridgeConfig();
        assertEquals("server-status.json", config.getStatusFile());
    }

    @Test
    void defaults_commandsFileName() {
        var config = new ServerBridgeConfig();
        assertEquals("server-commands.json", config.getCommandsFile());
    }

    @Test
    void load_returnsDefaultsWhenMissing(@TempDir Path tempDir) throws IOException {
        var config = ServerBridgeConfig.load(tempDir.resolve("nonexistent.properties"));
        assertTrue(config.isStatusEnabled());
        assertTrue(config.isCommandsEnabled());
        assertEquals(5, config.getStatusIntervalSeconds());
        assertEquals(1, config.getCommandPollSeconds());
    }

    @Test
    void load_readsCustomValues(@TempDir Path tempDir) throws IOException {
        var configFile = tempDir.resolve("config.properties");
        var props = new Properties();
        props.setProperty("statusEnabled", "false");
        props.setProperty("commandsEnabled", "false");
        props.setProperty("statusIntervalSeconds", "10");
        props.setProperty("commandPollSeconds", "3");
        props.setProperty("statusFile", "custom-status.json");
        props.setProperty("commandsFile", "custom-commands.json");
        try (OutputStream out = Files.newOutputStream(configFile)) {
            props.store(out, null);
        }

        var config = ServerBridgeConfig.load(configFile);
        assertFalse(config.isStatusEnabled());
        assertFalse(config.isCommandsEnabled());
        assertEquals(10, config.getStatusIntervalSeconds());
        assertEquals(3, config.getCommandPollSeconds());
        assertEquals("custom-status.json", config.getStatusFile());
        assertEquals("custom-commands.json", config.getCommandsFile());
    }

    @Test
    void roundTrip_preservesValues(@TempDir Path tempDir) throws IOException {
        var configFile = tempDir.resolve("config.properties");
        var config = new ServerBridgeConfig();
        config.save(configFile);
        var reloaded = ServerBridgeConfig.load(configFile);

        assertEquals(config.isStatusEnabled(), reloaded.isStatusEnabled());
        assertEquals(config.isCommandsEnabled(), reloaded.isCommandsEnabled());
        assertEquals(config.getStatusIntervalSeconds(), reloaded.getStatusIntervalSeconds());
        assertEquals(config.getCommandPollSeconds(), reloaded.getCommandPollSeconds());
        assertEquals(config.getStatusFile(), reloaded.getStatusFile());
        assertEquals(config.getCommandsFile(), reloaded.getCommandsFile());
    }
}
