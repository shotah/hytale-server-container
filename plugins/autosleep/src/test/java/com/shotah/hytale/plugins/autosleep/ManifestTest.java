package com.shotah.hytale.plugins.autosleep;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

class ManifestTest {

    @Test
    void manifestExists() {
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("manifest.json")) {
            assertNotNull(is, "manifest.json must exist in resources");
        } catch (IOException e) {
            fail("Failed to read manifest.json: " + e.getMessage());
        }
    }

    @Test
    void manifestContainsRequiredFields() throws IOException {
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("manifest.json")) {
            assertNotNull(is);
            String content = new String(is.readAllBytes(), StandardCharsets.UTF_8);

            assertTrue(content.contains("\"Group\""), "manifest must contain Group");
            assertTrue(content.contains("\"Name\""), "manifest must contain Name");
            assertTrue(content.contains("\"Main\""), "manifest must contain Main");
            assertTrue(content.contains("\"Version\""), "manifest must contain Version");
        }
    }

    @Test
    void manifestMainClassMatchesActualClass() throws IOException {
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("manifest.json")) {
            assertNotNull(is);
            String content = new String(is.readAllBytes(), StandardCharsets.UTF_8);

            String expectedClass = AutoSleepPlugin.class.getName();
            assertTrue(content.contains(expectedClass),
                    "manifest Main must reference " + expectedClass);
        }
    }

    @Test
    void manifestGroupIsShotah() throws IOException {
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("manifest.json")) {
            assertNotNull(is);
            String content = new String(is.readAllBytes(), StandardCharsets.UTF_8);

            assertTrue(content.contains("\"Shotah\""), "manifest Group must be Shotah");
        }
    }

    @Test
    void manifestNameIsAutoSleep() throws IOException {
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("manifest.json")) {
            assertNotNull(is);
            String content = new String(is.readAllBytes(), StandardCharsets.UTF_8);

            assertTrue(content.contains("\"AutoSleep\""), "manifest Name must be AutoSleep");
        }
    }
}
