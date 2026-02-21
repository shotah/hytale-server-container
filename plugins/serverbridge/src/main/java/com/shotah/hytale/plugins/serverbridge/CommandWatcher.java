package com.shotah.hytale.plugins.serverbridge;

import com.hypixel.hytale.server.core.Message;
import com.hypixel.hytale.server.core.universe.Universe;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.logging.Logger;

/**
 * Polls for server-commands.json and executes commands written by shell scripts.
 *
 * Supported commands:
 *   {"command": "broadcast", "message": "Server restarting in 5 minutes!"}
 */
public class CommandWatcher {

    public enum Command {
        BROADCAST("broadcast"),
        KICK_ALL("kick_all");

        private final String jsonValue;

        Command(String jsonValue) {
            this.jsonValue = jsonValue;
        }

        static Command fromJson(String value) {
            for (var cmd : values()) {
                if (cmd.jsonValue.equals(value)) {
                    return cmd;
                }
            }
            return null;
        }
    }

    private final Path commandsFile;
    private final Logger logger;

    public CommandWatcher(Path commandsFile, Logger logger) {
        this.commandsFile = commandsFile;
        this.logger = logger;
    }

    public void pollAndExecute() {
        if (!Files.exists(commandsFile)) {
            return;
        }

        try {
            String content = Files.readString(commandsFile);
            Files.deleteIfExists(commandsFile);

            if (content.isBlank()) {
                return;
            }

            String rawCommand = extractJsonValue(content, "command");
            if (rawCommand == null) {
                logger.warning("ServerBridge: command file missing 'command' field");
                return;
            }

            Command command = Command.fromJson(rawCommand);
            if (command == null) {
                logger.warning("ServerBridge: unknown command: " + rawCommand);
                return;
            }

            switch (command) {
                case BROADCAST -> handleBroadcast(content);
                case KICK_ALL -> handleKickAll(content);
            }
        } catch (IOException e) {
            logger.warning("ServerBridge: failed to read command file: " + e.getMessage());
        }
    }

    private void handleBroadcast(String content) {
        String message = extractJsonValue(content, "message");
        if (message == null) {
            logger.warning("ServerBridge: broadcast command missing 'message' field");
            return;
        }

        Universe.get().getPlayers().forEach(player ->
                player.sendMessage(Message.raw(message))
        );
        logger.info("ServerBridge: broadcast sent: " + message);
    }

    private void handleKickAll(String content) {
        String reason = extractJsonValue(content, "message");
        if (reason == null) {
            reason = "Server is shutting down for maintenance.";
        }

        final String kickReason = reason;
        Universe.get().getPlayers().forEach(player ->
                player.sendMessage(Message.raw(kickReason))
        );
        logger.info("ServerBridge: warned all players: " + kickReason);
    }

    /**
     * Minimal JSON value extractor. Avoids pulling in a JSON library dependency.
     * Handles: {"key": "value"} patterns with string values only.
     */
    static String extractJsonValue(String json, String key) {
        String search = "\"" + key + "\"";
        int keyIdx = json.indexOf(search);
        if (keyIdx == -1) return null;

        int colonIdx = json.indexOf(':', keyIdx + search.length());
        if (colonIdx == -1) return null;

        int startQuote = json.indexOf('"', colonIdx + 1);
        if (startQuote == -1) return null;

        int endQuote = json.indexOf('"', startQuote + 1);
        if (endQuote == -1) return null;

        return json.substring(startQuote + 1, endQuote);
    }
}
