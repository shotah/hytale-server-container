package com.shotah.hytale.plugins.autosleep;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Properties;

import static org.junit.jupiter.api.Assertions.*;

class AutoSleepConfigTest {

    @Test
    void defaultConfig_isEnabled() {
        var config = new AutoSleepConfig();
        assertTrue(config.isEnabled());
    }

    @Test
    void defaultConfig_sleepDelayIsFiveMinutes() {
        var config = new AutoSleepConfig();
        assertEquals(Duration.ofSeconds(300), config.getSleepDelay());
    }

    @Test
    void defaultConfig_checkIntervalIsFiveSeconds() {
        var config = new AutoSleepConfig();
        assertEquals(Duration.ofSeconds(5), config.getCheckInterval());
    }

    @Test
    void defaultConfig_sleepTpsIsOne() {
        var config = new AutoSleepConfig();
        assertEquals(1, config.getSleepTps());
    }

    @Test
    void defaultConfig_minViewRadiusIsTwo() {
        var config = new AutoSleepConfig();
        assertEquals(2, config.getMinViewRadius());
    }

    @Test
    void load_returnsDefaultsWhenFileDoesNotExist(@TempDir Path tempDir) throws IOException {
        var config = AutoSleepConfig.load(tempDir.resolve("nonexistent.properties"));
        assertTrue(config.isEnabled());
        assertEquals(300, config.getSleepDelay().getSeconds());
        assertEquals(5, config.getCheckInterval().getSeconds());
        assertEquals(1, config.getSleepTps());
        assertEquals(2, config.getMinViewRadius());
    }

    @Test
    void load_readsCustomValues(@TempDir Path tempDir) throws IOException {
        var configFile = tempDir.resolve("config.properties");
        var props = new Properties();
        props.setProperty("enabled", "false");
        props.setProperty("sleepDelaySeconds", "600");
        props.setProperty("checkIntervalSeconds", "10");
        props.setProperty("sleepTps", "5");
        props.setProperty("minViewRadius", "4");
        try (OutputStream out = Files.newOutputStream(configFile)) {
            props.store(out, null);
        }

        var config = AutoSleepConfig.load(configFile);
        assertFalse(config.isEnabled());
        assertEquals(Duration.ofSeconds(600), config.getSleepDelay());
        assertEquals(Duration.ofSeconds(10), config.getCheckInterval());
        assertEquals(5, config.getSleepTps());
        assertEquals(4, config.getMinViewRadius());
    }

    @Test
    void save_createsFileWithDefaults(@TempDir Path tempDir) throws IOException {
        var configFile = tempDir.resolve("subdir/config.properties");
        var config = new AutoSleepConfig();
        config.save(configFile);

        assertTrue(Files.exists(configFile));

        var loaded = AutoSleepConfig.load(configFile);
        assertEquals(config.isEnabled(), loaded.isEnabled());
        assertEquals(config.getSleepDelay(), loaded.getSleepDelay());
        assertEquals(config.getSleepTps(), loaded.getSleepTps());
        assertEquals(config.getMinViewRadius(), loaded.getMinViewRadius());
    }

    @Test
    void save_createsParentDirectories(@TempDir Path tempDir) throws IOException {
        var configFile = tempDir.resolve("deep/nested/dir/config.properties");
        new AutoSleepConfig().save(configFile);
        assertTrue(Files.exists(configFile));
    }

    @Test
    void roundTrip_preservesValues(@TempDir Path tempDir) throws IOException {
        var configFile = tempDir.resolve("config.properties");

        var props = new Properties();
        props.setProperty("enabled", "true");
        props.setProperty("sleepDelaySeconds", "120");
        props.setProperty("checkIntervalSeconds", "3");
        props.setProperty("sleepTps", "2");
        props.setProperty("minViewRadius", "1");
        try (OutputStream out = Files.newOutputStream(configFile)) {
            props.store(out, null);
        }

        var config = AutoSleepConfig.load(configFile);
        config.save(configFile);
        var reloaded = AutoSleepConfig.load(configFile);

        assertEquals(config.isEnabled(), reloaded.isEnabled());
        assertEquals(config.getSleepDelay(), reloaded.getSleepDelay());
        assertEquals(config.getCheckInterval(), reloaded.getCheckInterval());
        assertEquals(config.getSleepTps(), reloaded.getSleepTps());
        assertEquals(config.getMinViewRadius(), reloaded.getMinViewRadius());
    }
}
