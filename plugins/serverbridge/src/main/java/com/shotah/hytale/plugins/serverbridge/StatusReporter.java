package com.shotah.hytale.plugins.serverbridge;

import com.hypixel.hytale.server.core.HytaleServer;
import com.hypixel.hytale.server.core.universe.Universe;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.ArrayList;

/**
 * Writes server-status.json periodically so shell scripts can read server state.
 */
public class StatusReporter {

    private final Path statusFile;
    private final long startTimeMillis;

    public StatusReporter(Path statusFile) {
        this.statusFile = statusFile;
        this.startTimeMillis = System.currentTimeMillis();
    }

    public void writeStatus() throws IOException {
        int playerCount = getPlayerCount();
        int maxPlayers = HytaleServer.get().getConfig().getMaxPlayers();
        int maxViewRadius = HytaleServer.get().getConfig().getMaxViewRadius();
        long uptimeSeconds = (System.currentTimeMillis() - startTimeMillis) / 1000;

        var worldNames = new ArrayList<String>();
        for (var entry : Universe.get().getWorlds().entrySet()) {
            worldNames.add(entry.getKey());
        }

        var json = new StringBuilder();
        json.append("{\n");
        json.append("  \"players_online\": ").append(playerCount).append(",\n");
        json.append("  \"max_players\": ").append(maxPlayers).append(",\n");
        json.append("  \"max_view_radius\": ").append(maxViewRadius).append(",\n");
        json.append("  \"uptime_seconds\": ").append(uptimeSeconds).append(",\n");
        json.append("  \"worlds\": [");
        for (int i = 0; i < worldNames.size(); i++) {
            json.append("\"").append(escapeJson(worldNames.get(i))).append("\"");
            if (i < worldNames.size() - 1) json.append(", ");
        }
        json.append("],\n");
        json.append("  \"last_updated\": \"").append(Instant.now().toString()).append("\"\n");
        json.append("}\n");

        // Atomic write: write to temp file, then rename
        var tmpFile = statusFile.resolveSibling(statusFile.getFileName() + ".tmp");
        Files.writeString(tmpFile, json.toString(),
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        Files.move(tmpFile, statusFile, java.nio.file.StandardCopyOption.REPLACE_EXISTING,
                java.nio.file.StandardCopyOption.ATOMIC_MOVE);
    }

    /**
     * Uses the same workaround as Nitrado PerformanceSaver for accurate player counts.
     * https://github.com/nitrado/hytale-plugin-performance-saver/issues/7
     */
    static int getPlayerCount() {
        int universeCount = Universe.get().getPlayerCount();

        int worldSum = 0;
        for (var entry : Universe.get().getWorlds().entrySet()) {
            worldSum += entry.getValue().getPlayerCount();
        }

        return Math.max(universeCount, worldSum);
    }

    private static String escapeJson(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
