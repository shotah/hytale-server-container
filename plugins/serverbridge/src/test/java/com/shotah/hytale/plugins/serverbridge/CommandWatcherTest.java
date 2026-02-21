package com.shotah.hytale.plugins.serverbridge;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CommandWatcherTest {

    @Test
    void extractJsonValue_findsSimpleValue() {
        String json = "{\"command\": \"broadcast\", \"message\": \"Hello world\"}";
        assertEquals("broadcast", CommandWatcher.extractJsonValue(json, "command"));
        assertEquals("Hello world", CommandWatcher.extractJsonValue(json, "message"));
    }

    @Test
    void extractJsonValue_returnsNullForMissingKey() {
        String json = "{\"command\": \"broadcast\"}";
        assertNull(CommandWatcher.extractJsonValue(json, "message"));
    }

    @Test
    void extractJsonValue_returnsNullForEmptyJson() {
        assertNull(CommandWatcher.extractJsonValue("{}", "command"));
    }

    @Test
    void extractJsonValue_handlesMultilineJson() {
        String json = """
                {
                  "command": "kick_all",
                  "message": "Server shutting down"
                }
                """;
        assertEquals("kick_all", CommandWatcher.extractJsonValue(json, "command"));
        assertEquals("Server shutting down", CommandWatcher.extractJsonValue(json, "message"));
    }

    @Test
    void extractJsonValue_handlesNoSpaceAfterColon() {
        String json = "{\"command\":\"broadcast\",\"message\":\"test\"}";
        assertEquals("broadcast", CommandWatcher.extractJsonValue(json, "command"));
        assertEquals("test", CommandWatcher.extractJsonValue(json, "message"));
    }

    @Test
    void extractJsonValue_returnsNullForNullInput() {
        assertNull(CommandWatcher.extractJsonValue("", "command"));
    }

    @Test
    void command_fromJson_resolvesKnownCommands() {
        assertEquals(CommandWatcher.Command.BROADCAST, CommandWatcher.Command.fromJson("broadcast"));
        assertEquals(CommandWatcher.Command.KICK_ALL, CommandWatcher.Command.fromJson("kick_all"));
    }

    @Test
    void command_fromJson_returnsNullForUnknown() {
        assertNull(CommandWatcher.Command.fromJson("invalid"));
        assertNull(CommandWatcher.Command.fromJson(""));
    }
}
