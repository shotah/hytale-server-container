package com.shotah.hytale.plugins.autosleep;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Properties;

public class AutoSleepConfig {

    private boolean enabled = true;
    private int sleepDelaySeconds = 300;
    private int checkIntervalSeconds = 5;
    private int sleepTps = 1;
    private int minViewRadius = 2;

    public boolean isEnabled() {
        return enabled;
    }

    public Duration getSleepDelay() {
        return Duration.ofSeconds(sleepDelaySeconds);
    }

    public Duration getCheckInterval() {
        return Duration.ofSeconds(checkIntervalSeconds);
    }

    public int getSleepTps() {
        return sleepTps;
    }

    public int getMinViewRadius() {
        return minViewRadius;
    }

    public static AutoSleepConfig load(Path configFile) throws IOException {
        var config = new AutoSleepConfig();

        if (Files.exists(configFile)) {
            var props = new Properties();
            try (InputStream in = Files.newInputStream(configFile)) {
                props.load(in);
            }
            config.enabled = Boolean.parseBoolean(props.getProperty("enabled", "true"));
            config.sleepDelaySeconds = Integer.parseInt(props.getProperty("sleepDelaySeconds", "300"));
            config.checkIntervalSeconds = Integer.parseInt(props.getProperty("checkIntervalSeconds", "5"));
            config.sleepTps = Integer.parseInt(props.getProperty("sleepTps", "1"));
            config.minViewRadius = Integer.parseInt(props.getProperty("minViewRadius", "2"));
        }

        return config;
    }

    public void save(Path configFile) throws IOException {
        Files.createDirectories(configFile.getParent());
        var props = new Properties();
        props.setProperty("enabled", String.valueOf(enabled));
        props.setProperty("sleepDelaySeconds", String.valueOf(sleepDelaySeconds));
        props.setProperty("checkIntervalSeconds", String.valueOf(checkIntervalSeconds));
        props.setProperty("sleepTps", String.valueOf(sleepTps));
        props.setProperty("minViewRadius", String.valueOf(minViewRadius));
        try (OutputStream out = Files.newOutputStream(configFile)) {
            props.store(out, "Shotah AutoSleep Plugin Configuration");
        }
    }
}
