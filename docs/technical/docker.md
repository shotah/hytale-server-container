---
layout: default
title: "Docker"
parent: "⚙️ Technical Info"
nav_order: 2
---

# 🐳 Docker Configuration Reference

The Hytale server container is highly configurable through environment variables. These allow you to tune performance, security, and automation without modifying the internal container files.

## ⚙️ Core Server Settings

| Variable                      | Description                                                                                             | Default    |
|-------------------------------|---------------------------------------------------------------------------------------------------------|------------|
| `TZ`                          | The [Timezone identifier](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for server logs | `UTC`      |
| `DEBUG`                       | Set to `TRUE` to enable diagnostic scripts and verbose logging                                          | `FALSE`    |
| `SERVER_PORT`                 | The primary UDP port for game traffic                                                                   | `5520`     |
| `SERVER_IP`                   | The IP address the server binds to                                                                      | `0.0.0.0`  |
| `PROD`                        | Set to `TRUE` to run production readiness audits                                                        | `FALSE`    |
| `INIT_MEMORY`                 | Initial Java heap size (e.g., `4G`). Maps to `-Xms`.                                                    | `(Empty)`  |
| `MAX_MEMORY`                  | Maximum Java heap size (e.g., `8G`). Maps to `-Xmx`.                                                    | `(Empty)`  |
| `USE_G1GC`                    | Use G1GC with [Hytale-recommended settings](https://hytale-docs.pages.dev/server/performance/)          | `FALSE`    |
| `USE_AIKAR_FLAGS`             | Use [Aikar's aggressive GC tuning](https://docs.papermc.io/paper/aikars-flags) (experimental)           | `FALSE`    |
| `HYTALE_CACHE`                | Enable AOT (Ahead-of-Time) cache for faster server startup                                              | `FALSE`    |
| `JAVA_ARGS`                   | Additional flags for the JVM (expert use only)                                                          | `(Empty)`  |
| `ENABLE_AUTO_RESTART`         | Auto-restart the server on a schedule to check for updates                                              | `FALSE`    |
| `AUTO_RESTART_INTERVAL`       | Hours between auto-restarts (requires `ENABLE_AUTO_RESTART=TRUE`)                                       | `24`       |
| `ENABLE_PERFORMANCE_SAVER`    | Install bundled [Nitrado PerformanceSaver](https://github.com/nitrado/hytale-plugin-performance-saver) plugin | `FALSE`    |
| `ENABLE_SERVER_BRIDGE`        | Install bundled ServerBridge plugin for bidirectional IPC between scripts and server                   | `FALSE`    |

### Memory & Performance Configuration

**Recommended settings** (Hytale-optimized):

```yaml
environment:
  INIT_MEMORY: "4G"      # Start with 4GB heap
  MAX_MEMORY: "8G"       # Allow up to 8GB heap
  USE_G1GC: "TRUE"       # Hytale-recommended GC settings
  HYTALE_CACHE: "TRUE"   # Faster startup with AOT cache
```

**Experimental settings** (adapted from Minecraft):

```yaml
environment:
  INIT_MEMORY: "4G"
  MAX_MEMORY: "8G"
  USE_AIKAR_FLAGS: "TRUE"  # Aggressive GC tuning
  HYTALE_CACHE: "TRUE"
```

### GC Options Explained

| Option | Description | When to use |
|--------|-------------|-------------|
| `USE_G1GC` | Basic G1GC with conservative settings | **Recommended** - tested with Hytale |
| `USE_AIKAR_FLAGS` | Aggressive G1GC tuning from Minecraft | Experimental - may improve or worsen performance |

**Note:** `USE_AIKAR_FLAGS` was originally tuned for Minecraft's memory allocation patterns. Hytale may behave differently. Start with `USE_G1GC` and only try Aikar flags if you're experiencing GC-related lag.

### AOT Cache

The `HYTALE_CACHE` option enables Hytale's Ahead-of-Time compilation cache, which significantly reduces server startup time by loading pre-compiled code instead of waiting for JIT warmup.

### Auto-Restart

The container checks for server updates on every startup. For pre-release servers where the game client auto-updates frequently, enable auto-restart to keep your server in sync:

```yaml
environment:
  ENABLE_AUTO_RESTART: "TRUE"
  AUTO_RESTART_INTERVAL: "6"  # Check every 6 hours
restart: unless-stopped        # Required! Docker must restart the container
```

**How it works:**
1. A background watchdog starts alongside the server
2. After the configured interval, it sends SIGTERM for a graceful shutdown
3. Docker's restart policy brings the container back up
4. The downloader checks for updates and installs if available
5. Server starts with the latest version

**Important:** You must set `restart: unless-stopped` (or `restart: always`) in your Docker Compose file, otherwise the container will just stop and not come back.

### Performance Saver Plugin

The container bundles the **[Nitrado PerformanceSaver](https://github.com/nitrado/hytale-plugin-performance-saver)** plugin (MIT licensed), which optimizes server resource usage:

```yaml
environment:
  ENABLE_PERFORMANCE_SAVER: "TRUE"
```

**What it does:**
- **TPS limiting** - Caps TPS at 20 when players are online, drops to 5 when empty (after 5 min idle)
- **Dynamic view radius** - Automatically reduces view distance under CPU or memory pressure, recovers when stable
- **GC optimization** - Triggers garbage collection when chunk unloading frees significant memory
- **Crash recovery** - Restores TPS and view radius after unexpected shutdowns

**Plugin configuration** (`mods/Nitrado_PerformanceSaver/config.json`, auto-created on first run):

| Section | Key Settings | Default |
| :--- | :--- | :--- |
| `Tps` | `TpsLimit` / `TpsLimitEmpty` / `EmptyLimitDelaySeconds` | `20` / `5` / `300` |
| `ViewRadius` | `MinViewRadius` / `DecreaseFactor` / `RecoveryWaitTimeSeconds` | `2` / `0.75` / `60` |
| `ChunkGarbageCollection` | `ChunkDropRatioThreshold` / `GarbageCollectionDelaySeconds` | `0.8` / `300` |

See the [full configuration reference](https://github.com/nitrado/hytale-plugin-performance-saver#configuration) for all options.

### ServerBridge Plugin

The container includes a custom **ServerBridge** plugin that provides bidirectional file-based IPC between the Java server and container shell scripts.

```yaml
environment:
  ENABLE_SERVER_BRIDGE: "TRUE"
```

**What it does:**

- **Status reporting** - Writes `server-status.json` every 5 seconds with player count, uptime, max players, view radius, and world list
- **Command execution** - Polls `server-commands.json` every second for commands written by shell scripts (broadcasts, kick_all)
- **Auto-restart integration** - Automatically enabled when `ENABLE_AUTO_RESTART=TRUE` so restart countdowns are broadcast to players

**How it works:**

The plugin creates two files in the server's working directory:

| File | Direction | Purpose |
| :--- | :--- | :--- |
| `server-status.json` | Plugin → Scripts | Server state (player count, uptime, worlds) |
| `server-commands.json` | Scripts → Plugin | Commands to execute (broadcast, kick_all) |

**Sending commands from shell scripts:**

```bash
# Broadcast a message to all online players
echo '{"command": "broadcast", "message": "Server restarting in 5 minutes!"}' > server-commands.json

# Kick all players with a reason
echo '{"command": "kick_all", "message": "Server shutting down for maintenance."}' > server-commands.json
```

**Reading server status from shell scripts:**

```bash
# Check if players are online
PLAYERS=$(grep -o '"players_online": *[0-9]*' server-status.json | grep -o '[0-9]*$')
if [ "$PLAYERS" -gt 0 ]; then
    echo "Server has $PLAYERS players online"
fi
```

**Plugin configuration** (`ServerBridge/config.properties`, auto-created on first run):

| Property | Description | Default |
| :--- | :--- | :--- |
| `statusEnabled` | Write status file | `true` |
| `commandsEnabled` | Poll for commands | `true` |
| `statusIntervalSeconds` | Seconds between status writes | `5` |
| `commandPollSeconds` | Seconds between command polls | `1` |
| `statusFile` | Status file name | `server-status.json` |
| `commandsFile` | Commands file name | `server-commands.json` |

---

## 📥 Hytale Downloader Options

| Variable                      | Description                                                                                             | Default    |
|-------------------------------|---------------------------------------------------------------------------------------------------------|------------|
| `HYTALE_PATCHLINE`            | Patchline to download from: `release` or `pre-release`                                                  | `release`  |

See the [pre-release example](https://github.com/shotah/hytale-server-container/tree/main/examples/pre-release) for running a pre-release server.

---

## 📦 CurseForge Mod Downloader

Automatically download and manage mods from CurseForge.

The downloader maintains a manifest to track installed mods and automatically removes mods that are no longer in your list.

| Variable                      | Description                                                                                             | Default    |
|-------------------------------|---------------------------------------------------------------------------------------------------------|------------|
| `CURSEFORGE_MOD_IDS`          | Comma-separated list of CurseForge mod project IDs (e.g., `12345,67890`)                                | `(Empty)`  |
| `HYTALE_MOD_DIR`              | Directory where mods are downloaded                                                                     | `./mods` |

### Usage Example

```yaml
environment:
  CURSEFORGE_MOD_IDS: "12345,67890,11111"
```

### How It Works

1. On startup, the downloader fetches mod info from cflookup.com
2. Downloads the latest version from forgecdn.net if not already present
3. Removes mods that were previously downloaded but are no longer in `CURSEFORGE_MOD_IDS`
4. Maintains a manifest file (`.curseforge_manifest.json`) in the mods directory

### Finding Mod IDs

The mod ID can be found in the CurseForge URL. For example:
- URL: `https://www.curseforge.com/hytale/mods/example-mod/12345`
- Mod ID: `12345`

See the [curseforge-mods example](https://github.com/shotah/hytale-server-container/tree/main/examples/curseforge-mods) for a complete configuration.

---

## 🎮 Hytale Server Options

Options are listed in the same order as they appear in `java -jar HytaleServer.jar --help`.

| Variable                          | Description                                                                                                                                                             | Default     |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| `HYTALE_CACHE`                    | Enables the Ahead-Of-Time cache                                                                                                                                         | `FALSE`     |
| `HYTALE_CACHE_DIR`                | Sets the location of the Ahead-Of-Time cache file                                                                                                                       | `./Server/HytaleServer.aot` |
| `HYTALE_ACCEPT_EARLY_PLUGINS`     | Allow loading early or experimental plugins (unsupported and may cause stability issues)                                                                                | `FALSE`     |
| `HYTALE_ALLOW_OP`                 | Automatically grant operator permissions                                                                                                                                | `FALSE`     |
| `HYTALE_AUTH_MODE`                | Authentication mode: `authenticated`, `offline`, or `insecure`. `authenticated` is the built-in default.                                                                | `(Empty)`   |
| `HYTALE_BACKUP`                   | Create a backup on server startup (requires `HYTALE_BACKUP_DIR` to be set)                                                                                              | `FALSE`     |
| `HYTALE_BACKUP_DIR`               | Directory where backups are stored. Setting this enables the `/backup` command in-game. The default `./backups` adds a `backups` directory to your mounted data folder. | `./backups` |
| `HYTALE_BACKUP_FREQUENCY`         | Frequency of scheduled backups in minutes                                                                                                                               | `(Empty)`   |
| `HYTALE_BACKUP_MAX_COUNT`         | Maximum number of backups to keep                                                                                                                                       | `(Empty)`   |
| `HYTALE_BARE`                     | Runs server bare (without loading worlds, binding to ports or creating directories)                                                                                     | `FALSE`     |
| `HYTALE_BOOT_COMMAND`             | Command to run on boot (multiple commands execute synchronously in order)                                                                                               | `(Empty)`   |
| `HYTALE_CLIENT_PID`               | Client process ID (for integrated server scenarios)                                                                                                                     | `(Empty)`   |
| `HYTALE_DISABLE_ASSET_COMPARE`    | Disable asset comparison checks                                                                                                                                         | `FALSE`     |
| `HYTALE_DISABLE_CPB_BUILD`        | Disable building of compact prefab buffers                                                                                                                              | `FALSE`     |
| `HYTALE_DISABLE_FILE_WATCHER`     | Disable file watcher                                                                                                                                                    | `FALSE`     |
| `HYTALE_DISABLE_SENTRY`           | Disable Sentry error reporting                                                                                                                                          | `FALSE`     |
| `HYTALE_EARLY_PLUGINS`            | Additional early plugin directories to load from (Path)                                                                                                                 | `(Empty)`   |
| `HYTALE_EVENT_DEBUG`              | Enable event debugging                                                                                                                                                  | `FALSE`     |
| `HYTALE_FORCE_NETWORK_FLUSH`      | Force network flush behavior                                                                                                                                            | `true`      |
| `HYTALE_GENERATE_SCHEMA`          | Generate schema, save to assets directory and exit                                                                                                                      | `FALSE`     |
| `HYTALE_IDENTITY_TOKEN`           | Identity token (JWT)                                                                                                                                                    | `(Empty)`   |
| `HYTALE_LOG`                      | Sets logger level (KeyValueHolder format)                                                                                                                               | `(Empty)`   |
| `HYTALE_MIGRATE_WORLDS`           | Worlds to migrate (comma-separated)                                                                                                                                     | `(Empty)`   |
| `HYTALE_MIGRATIONS`               | The migrations to run (JSON object)                                                                                                                                     | `(Empty)`   |
| `HYTALE_MODS`                     | Additional mods directories (Path)                                                                                                                                      | `(Empty)`   |
| `HYTALE_OWNER_NAME`               | Server owner name                                                                                                                                                       | `(Empty)`   |
| `HYTALE_OWNER_UUID`               | Server owner UUID                                                                                                                                                       | `(Empty)`   |
| `HYTALE_PREFAB_CACHE`             | Prefab cache directory for immutable assets                                                                                                                             | `(Empty)`   |
| `HYTALE_SESSION_TOKEN`            | Session token for Session Service API                                                                                                                                   | `(Empty)`   |
| `HYTALE_SHUTDOWN_AFTER_VALIDATE`  | Automatically shutdown after asset and/or prefab validation                                                                                                             | `FALSE`     |
| `HYTALE_SINGLEPLAYER`             | Run server in singleplayer mode                                                                                                                                         | `FALSE`     |
| `HYTALE_TRANSPORT`                | Transport type: `QUIC` or other supported types. `QUIC` is the built-in default.                                                                                        | `(Empty)`   |
| `HYTALE_UNIVERSE`                 | Universe directory path                                                                                                                                                 | `(Empty)`   |
| `HYTALE_VALIDATE_ASSETS`          | Exit with error if any assets are invalid                                                                                                                               | `FALSE`     |
| `HYTALE_VALIDATE_PREFABS`         | Validation option for prefabs (exits with error if invalid)                                                                                                             | `(Empty)`   |
| `HYTALE_VALIDATE_WORLD_GEN`       | Exit with error if default world gen is invalid                                                                                                                         | `FALSE`     |
| `HYTALE_VERSION`                  | Print version information and exit                                                                                                                                      | `FALSE`     |
| `HYTALE_WORLD_GEN`                | World generation directory path                                                                                                                                         | `(Empty)`   |

---

## ⚙️ Hytale Settings (config.json)

These variables directly inject values into the `home/container/config.json` file on startup.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `HYTALE_SERVER_NAME` | The name displayed in the server browser. | `Hytale Server` |
| `HYTALE_MOTD` | Message of the Day shown to players. | `(Empty)` |
| `HYTALE_PASSWORD` | Set a password to make the server private. | `(Empty)` |
| `HYTALE_MAX_PLAYERS` | Maximum number of concurrent players. | `100` |
| `HYTALE_MAX_VIEW_RADIUS` | Maximum chunk distance sent to clients. | `32` |
| `HYTALE_COMPRESSION` | Enable or disable local network compression. | `false` |
| `HYTALE_WORLD` | The name of the world folder to load. | `default` |
| `HYTALE_GAMEMODE` | The default game mode (e.g., Adventure, Creative). | `Adventure` |

---

## 🌍 World Settings (universe/worlds/{world}/config.json)

These variables modify per-world settings. The world must exist first (run the server once to create it).

| Variable | Description | Default |
| :--- | :--- | :--- |
| `HYTALE_PVP_ENABLED` | Enable player vs player combat. | `false` |
| `HYTALE_FALL_DAMAGE` | Enable fall damage. | `true` |
| `HYTALE_NPC_SPAWNING` | Enable NPC and creature spawning. | `true` |
| `HYTALE_NPC_FROZEN` | Freeze all NPCs in place. | `false` |
| `HYTALE_WORLD_GAMEMODE` | World-specific game mode (overrides server default). | `Adventure` |
| `HYTALE_DAYTIME_DURATION` | Daytime length in seconds. | `1728` |
| `HYTALE_NIGHTTIME_DURATION` | Nighttime length in seconds. | `1151` |
| `HYTALE_TIME_PAUSED` | Pause the day/night cycle. | `false` |
| `HYTALE_SPAWN_MARKERS` | Enable spawn point markers on the map. | `true` |
| `HYTALE_COMPASS_UPDATING` | Enable compass updating. | `true` |
| `HYTALE_OBJECTIVE_MARKERS` | Enable objective markers on the map. | `true` |
| `HYTALE_SAVING_PLAYERS` | Save player data to disk. Disable for temporary/event worlds. | `true` |
| `HYTALE_SAVING_CHUNKS` | Save chunk data to disk. Disable for temporary/event worlds. | `true` |
| `HYTALE_UNLOADING_CHUNKS` | Unload inactive chunks from memory. Disable to keep all chunks loaded. | `true` |

### Example: PVP Arena World

```yaml
environment:
  HYTALE_PVP_ENABLED: "true"
  HYTALE_FALL_DAMAGE: "true"
  HYTALE_NPC_SPAWNING: "false"      # No mobs in arena
  HYTALE_NPC_FROZEN: "true"         # Freeze any remaining NPCs
  HYTALE_TIME_PAUSED: "true"        # Always daytime
  HYTALE_SAVING_PLAYERS: "false"    # Don't persist arena stats
  HYTALE_UNLOADING_CHUNKS: "false"  # Keep arena loaded
```

### Note on World Configuration

World settings are applied to the world specified by `HYTALE_WORLD` (default: "default"). If the world doesn't exist yet, the settings will be applied on the next container restart after the world is created.

---

## 🔐 Access Control (whitelist.json, permissions.json)

These variables manage player access and permissions via JSON configuration files.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `HYTALE_WHITELIST_ENABLED` | Enable whitelist mode (`true` or `false`). | `false` |
| `HYTALE_WHITELIST` | Comma-separated player UUIDs to add to whitelist. | `(Empty)` |
| `HYTALE_OPS` | Comma-separated player UUIDs to grant OP permissions. | `(Empty)` |

### How Access Control Works

- **Whitelist:** When enabled, only players in `whitelist.json` can join
- **Permissions:** Players in `HYTALE_OPS` are added to the "OP" group in `permissions.json`
- **Non-destructive:** Environment variables add to existing configs, never remove entries
- **Validation:** Invalid JSON files are backed up and recreated with defaults

### Finding Player UUIDs

Use [hytaleid.com](https://hytaleid.com/) to look up player UUIDs by username, or check your server's `permissions.json` after they've connected once.

### Example: Private Server

```yaml
environment:
  HYTALE_PASSWORD: "secret123"
  HYTALE_WHITELIST_ENABLED: "true"
  HYTALE_WHITELIST: "uuid-player1,uuid-player2"
  HYTALE_OPS: "uuid-admin"
```

See the [private-server example](https://github.com/shotah/hytale-server-container/tree/main/examples/private-server) for a complete configuration.

---

## 📂 Volume Mapping (Persistence)

To ensure your world, player data, and configurations are saved when the container restarts, you **must** map a volume to the internal working directory.

| Container Path | Purpose |
| :--- | :--- |
| `/home/container` | Main directory containing world files, logs, and configs. |

## Folder structure

The following folder structure is used: