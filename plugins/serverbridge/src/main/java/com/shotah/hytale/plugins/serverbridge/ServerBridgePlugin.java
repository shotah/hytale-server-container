package com.shotah.hytale.plugins.serverbridge;

import com.hypixel.hytale.server.core.HytaleServer;
import com.hypixel.hytale.server.core.plugin.JavaPlugin;
import com.hypixel.hytale.server.core.plugin.JavaPluginInit;

import javax.annotation.Nonnull;
import java.io.IOException;
import java.nio.file.Path;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

/**
 * ServerBridge: bidirectional file-based IPC between the Hytale JVM
 * and container shell scripts.
 *
 * Plugin writes: server-status.json (player count, uptime, worlds)
 * Plugin reads:  server-commands.json (broadcast, kick_all)
 */
public class ServerBridgePlugin extends JavaPlugin {

    private static final String CONFIG_FILE = "config.properties";

    private ServerBridgeConfig config;
    private StatusReporter statusReporter;
    private CommandWatcher commandWatcher;
    private ScheduledFuture<?> statusTask;
    private ScheduledFuture<?> commandTask;

    public ServerBridgePlugin(@Nonnull JavaPluginInit init) {
        super(init);
    }

    @Override
    protected void setup() {
        try {
            var configPath = getDataDirectory().resolve(CONFIG_FILE);
            this.config = ServerBridgeConfig.load(configPath);
            this.config.save(configPath);
        } catch (IOException e) {
            getLogger().atWarning().log("Failed to load config, using defaults: %s", e.getMessage());
            this.config = new ServerBridgeConfig();
        }
    }

    @Override
    protected void start() {
        Path baseDir = Path.of(System.getProperty("user.dir"));

        if (this.config.isStatusEnabled()) {
            Path statusPath = baseDir.resolve(this.config.getStatusFile());
            this.statusReporter = new StatusReporter(statusPath);

            this.statusTask = HytaleServer.SCHEDULED_EXECUTOR.scheduleAtFixedRate(
                    this::writeStatusSafe,
                    1,
                    this.config.getStatusIntervalSeconds(),
                    TimeUnit.SECONDS
            );

            getLogger().atInfo().log("Status reporter active: writing %s every %ds",
                    statusPath, this.config.getStatusIntervalSeconds());
        }

        if (this.config.isCommandsEnabled()) {
            Path commandsPath = baseDir.resolve(this.config.getCommandsFile());
            this.commandWatcher = new CommandWatcher(commandsPath,
                    java.util.logging.Logger.getLogger("ServerBridge"));

            this.commandTask = HytaleServer.SCHEDULED_EXECUTOR.scheduleAtFixedRate(
                    this.commandWatcher::pollAndExecute,
                    1,
                    this.config.getCommandPollSeconds(),
                    TimeUnit.SECONDS
            );

            getLogger().atInfo().log("Command watcher active: polling %s every %ds",
                    commandsPath, this.config.getCommandPollSeconds());
        }
    }

    private void writeStatusSafe() {
        try {
            this.statusReporter.writeStatus();
        } catch (Exception e) {
            getLogger().atWarning().log("Failed to write status: %s", e.getMessage());
        }
    }

    @Override
    protected void shutdown() {
        if (this.statusTask != null) {
            this.statusTask.cancel(false);
        }
        if (this.commandTask != null) {
            this.commandTask.cancel(false);
        }

        // Clean up status file on shutdown so stale data isn't read
        try {
            Path baseDir = Path.of(System.getProperty("user.dir"));
            java.nio.file.Files.deleteIfExists(baseDir.resolve(this.config.getStatusFile()));
        } catch (IOException e) {
            getLogger().atWarning().log("Failed to clean up status file: %s", e.getMessage());
        }

        getLogger().atInfo().log("ServerBridge shutdown complete");
    }
}
