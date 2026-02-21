package com.shotah.hytale.plugins.autosleep;

import com.hypixel.hytale.server.core.HytaleServer;
import com.hypixel.hytale.server.core.Message;
import com.hypixel.hytale.server.core.plugin.JavaPlugin;
import com.hypixel.hytale.server.core.plugin.JavaPluginInit;
import com.hypixel.hytale.server.core.universe.Universe;
import com.hypixel.hytale.server.core.universe.world.World;

import javax.annotation.Nonnull;
import java.io.IOException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

/**
 * Auto-sleep plugin for Hytale servers.
 *
 * When no players are online for a configurable period, the server enters
 * a low-resource "sleep" mode (TPS=1, minimal view radius). When a player
 * connects, everything is instantly restored.
 */
public class AutoSleepPlugin extends JavaPlugin {

    private static final String CONFIG_FILE = "config.properties";

    private AutoSleepConfig config;
    private ScheduledFuture<?> pollTask;
    private long lastPlayerSeenAt;
    private boolean sleeping = false;
    private int savedViewRadius;

    public AutoSleepPlugin(@Nonnull JavaPluginInit init) {
        super(init);
    }

    @Override
    protected void setup() {
        try {
            var configPath = getDataDirectory().resolve(CONFIG_FILE);
            this.config = AutoSleepConfig.load(configPath);
            this.config.save(configPath);
        } catch (IOException e) {
            getLogger().atWarning().log("Failed to load config, using defaults: %s", e.getMessage());
            this.config = new AutoSleepConfig();
        }
    }

    @Override
    protected void start() {
        if (!this.config.isEnabled()) {
            getLogger().atInfo().log("AutoSleep is disabled via config");
            return;
        }

        this.lastPlayerSeenAt = System.nanoTime();
        this.savedViewRadius = HytaleServer.get().getConfig().getMaxViewRadius();

        getLogger().atInfo().log(
                "AutoSleep active: sleep after %ds idle, TPS=%d, min view radius=%d",
                this.config.getSleepDelay().getSeconds(),
                this.config.getSleepTps(),
                this.config.getMinViewRadius()
        );

        this.pollTask = HytaleServer.SCHEDULED_EXECUTOR.scheduleAtFixedRate(
                this::checkPlayers,
                this.config.getCheckInterval().getSeconds(),
                this.config.getCheckInterval().getSeconds(),
                TimeUnit.SECONDS
        );
    }

    private void checkPlayers() {
        try {
            int playerCount = getPlayerCount();

            if (playerCount > 0) {
                this.lastPlayerSeenAt = System.nanoTime();

                if (this.sleeping) {
                    wake();
                }
                return;
            }

            if (this.sleeping) {
                return;
            }

            long idleNanos = System.nanoTime() - this.lastPlayerSeenAt;
            if (idleNanos > this.config.getSleepDelay().toNanos()) {
                sleep();
            }
        } catch (Exception e) {
            getLogger().atWarning().log("AutoSleep check failed: %s", e.getMessage());
        }
    }

    private void sleep() {
        this.sleeping = true;
        this.savedViewRadius = HytaleServer.get().getConfig().getMaxViewRadius();

        HytaleServer.get().getConfig().setMaxViewRadius(this.config.getMinViewRadius());

        for (var entry : Universe.get().getWorlds().entrySet()) {
            var world = entry.getValue();
            CompletableFuture.runAsync(() -> {
                world.setTps(this.config.getSleepTps());
            }, world);
        }

        getLogger().atInfo().log(
                "Server entering sleep mode (TPS=%d, view radius=%d)",
                this.config.getSleepTps(),
                this.config.getMinViewRadius()
        );
    }

    private void wake() {
        this.sleeping = false;

        HytaleServer.get().getConfig().setMaxViewRadius(this.savedViewRadius);

        for (var entry : Universe.get().getWorlds().entrySet()) {
            var world = entry.getValue();
            CompletableFuture.runAsync(() -> {
                world.setTps(World.TPS);
            }, world);
        }

        getLogger().atInfo().log(
                "Server waking up (TPS=%d, view radius=%d)",
                World.TPS,
                this.savedViewRadius
        );

        Universe.get().getPlayers().forEach(playerRef ->
                playerRef.sendMessage(Message.raw("Server is waking up! Welcome back."))
        );
    }

    /**
     * Uses the same workaround as Nitrado PerformanceSaver for accurate player counts.
     * See: https://github.com/nitrado/hytale-plugin-performance-saver/issues/7
     */
    private int getPlayerCount() {
        int universeCount = Universe.get().getPlayerCount();

        int worldSum = 0;
        for (var entry : Universe.get().getWorlds().entrySet()) {
            worldSum += entry.getValue().getPlayerCount();
        }

        return Math.max(universeCount, worldSum);
    }

    @Override
    protected void shutdown() {
        if (this.pollTask != null) {
            this.pollTask.cancel(false);
        }

        if (this.sleeping) {
            HytaleServer.get().getConfig().setMaxViewRadius(this.savedViewRadius);

            for (var entry : Universe.get().getWorlds().entrySet()) {
                var world = entry.getValue();
                CompletableFuture.runAsync(() -> {
                    world.setTps(World.TPS);
                }, world);
            }

            getLogger().atInfo().log("AutoSleep shutdown: restored TPS and view radius");
        }
    }
}
