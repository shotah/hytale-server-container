#!/bin/bash
#
# World Config Script Test (No Server JAR Required)
#
# Verifies:
#   - World config env vars are applied correctly
#   - PVP, fall damage, NPC spawning work
#   - Day/night duration settings work
#   - Existing values are preserved
#

set -euo pipefail

CONTAINER_NAME="hytale-test-world-config-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== World Config Script Test ==="
echo "Image: $IMAGE_TO_TEST"

# Start container with shell
echo "Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --entrypoint /bin/sh \
    -e SCRIPTS_PATH=/usr/local/bin/scripts \
    -e BASE_DIR=/home/container \
    "$IMAGE_TO_TEST" \
    -c "sleep 300"

sleep 2

# Verify container is running
status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "not found")
if [ "$status" != "running" ]; then
    echo "ERROR: Container failed to start"
    exit 1
fi

echo ""
echo "--- Setup: Create mock world config ---"

# Create server config first (needed for world name detection)
docker exec "$CONTAINER_NAME" sh -c '
    mkdir -p /home/container
    cat > /home/container/config.json << "EOF"
{
    "Version": 3,
    "Defaults": { "World": "default" }
}
EOF
'

# Create mock world config (matches official Hytale world config structure)
docker exec "$CONTAINER_NAME" sh -c '
    mkdir -p /home/container/universe/worlds/default
    cat > /home/container/universe/worlds/default/config.json << "EOF"
{
    "Version": 4,
    "IsPvpEnabled": false,
    "IsFallDamageEnabled": true,
    "IsSpawningNPC": true,
    "IsAllNPCFrozen": false,
    "GameMode": "Adventure",
    "DaytimeDurationSeconds": 1728,
    "NighttimeDurationSeconds": 1151,
    "IsGameTimePaused": false,
    "IsSpawnMarkersEnabled": true,
    "IsCompassUpdating": true,
    "IsObjectiveMarkersEnabled": true,
    "IsSavingPlayers": true,
    "IsSavingChunks": true,
    "IsUnloadingChunks": true
}
EOF
'

echo "  ✓ Mock world config created"

echo ""
echo "--- Test 1: No changes when no env vars set ---"

docker exec "$CONTAINER_NAME" sh -c '
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

pvp=$(docker exec "$CONTAINER_NAME" jq -r '.IsPvpEnabled' /home/container/universe/worlds/default/config.json)
if [ "$pvp" != "false" ]; then
    echo "FAIL: PVP should still be false, got '$pvp'"
    exit 1
fi
echo "  ✓ Config unchanged when no env vars set"

echo ""
echo "--- Test 2: Enable PVP ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_PVP_ENABLED="true"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

pvp=$(docker exec "$CONTAINER_NAME" jq -r '.IsPvpEnabled' /home/container/universe/worlds/default/config.json)
if [ "$pvp" != "true" ]; then
    echo "FAIL: PVP should be true, got '$pvp'"
    exit 1
fi
echo "  ✓ HYTALE_PVP_ENABLED applied"

echo ""
echo "--- Test 3: Disable fall damage ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_FALL_DAMAGE="false"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

fall=$(docker exec "$CONTAINER_NAME" jq -r '.IsFallDamageEnabled' /home/container/universe/worlds/default/config.json)
if [ "$fall" != "false" ]; then
    echo "FAIL: Fall damage should be false, got '$fall'"
    exit 1
fi
echo "  ✓ HYTALE_FALL_DAMAGE applied"

echo ""
echo "--- Test 4: Disable NPC spawning ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_NPC_SPAWNING="false"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

npc=$(docker exec "$CONTAINER_NAME" jq -r '.IsSpawningNPC' /home/container/universe/worlds/default/config.json)
if [ "$npc" != "false" ]; then
    echo "FAIL: NPC spawning should be false, got '$npc'"
    exit 1
fi
echo "  ✓ HYTALE_NPC_SPAWNING applied"

echo ""
echo "--- Test 5: Change game mode ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_WORLD_GAMEMODE="Creative"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

gamemode=$(docker exec "$CONTAINER_NAME" jq -r '.GameMode' /home/container/universe/worlds/default/config.json)
if [ "$gamemode" != "Creative" ]; then
    echo "FAIL: GameMode should be Creative, got '$gamemode'"
    exit 1
fi
echo "  ✓ HYTALE_WORLD_GAMEMODE applied"

echo ""
echo "--- Test 6: Day/night duration ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_DAYTIME_DURATION="3600"
    export HYTALE_NIGHTTIME_DURATION="1800"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

daytime=$(docker exec "$CONTAINER_NAME" jq -r '.DaytimeDurationSeconds' /home/container/universe/worlds/default/config.json)
nighttime=$(docker exec "$CONTAINER_NAME" jq -r '.NighttimeDurationSeconds' /home/container/universe/worlds/default/config.json)

if [ "$daytime" != "3600" ]; then
    echo "FAIL: DaytimeDurationSeconds should be 3600, got '$daytime'"
    exit 1
fi
echo "  ✓ HYTALE_DAYTIME_DURATION applied"

if [ "$nighttime" != "1800" ]; then
    echo "FAIL: NighttimeDurationSeconds should be 1800, got '$nighttime'"
    exit 1
fi
echo "  ✓ HYTALE_NIGHTTIME_DURATION applied"

echo ""
echo "--- Test 7: Pause time ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_TIME_PAUSED="true"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

paused=$(docker exec "$CONTAINER_NAME" jq -r '.IsGameTimePaused' /home/container/universe/worlds/default/config.json)
if [ "$paused" != "true" ]; then
    echo "FAIL: IsGameTimePaused should be true, got '$paused'"
    exit 1
fi
echo "  ✓ HYTALE_TIME_PAUSED applied"

echo ""
echo "--- Test 8: Freeze NPCs ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_NPC_FROZEN="true"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

frozen=$(docker exec "$CONTAINER_NAME" jq -r '.IsAllNPCFrozen' /home/container/universe/worlds/default/config.json)
if [ "$frozen" != "true" ]; then
    echo "FAIL: IsAllNPCFrozen should be true, got '$frozen'"
    exit 1
fi
echo "  ✓ HYTALE_NPC_FROZEN applied"

echo ""
echo "--- Test 9: Spawn markers and compass ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_SPAWN_MARKERS="false"
    export HYTALE_COMPASS_UPDATING="false"
    export HYTALE_OBJECTIVE_MARKERS="false"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

spawn=$(docker exec "$CONTAINER_NAME" jq -r '.IsSpawnMarkersEnabled' /home/container/universe/worlds/default/config.json)
compass=$(docker exec "$CONTAINER_NAME" jq -r '.IsCompassUpdating' /home/container/universe/worlds/default/config.json)
objectives=$(docker exec "$CONTAINER_NAME" jq -r '.IsObjectiveMarkersEnabled' /home/container/universe/worlds/default/config.json)

if [ "$spawn" != "false" ]; then
    echo "FAIL: IsSpawnMarkersEnabled should be false, got '$spawn'"
    exit 1
fi
echo "  ✓ HYTALE_SPAWN_MARKERS applied"

if [ "$compass" != "false" ]; then
    echo "FAIL: IsCompassUpdating should be false, got '$compass'"
    exit 1
fi
echo "  ✓ HYTALE_COMPASS_UPDATING applied"

if [ "$objectives" != "false" ]; then
    echo "FAIL: IsObjectiveMarkersEnabled should be false, got '$objectives'"
    exit 1
fi
echo "  ✓ HYTALE_OBJECTIVE_MARKERS applied"

echo ""
echo "--- Test 10: Persistence settings ---"

docker exec "$CONTAINER_NAME" sh -c '
    export HYTALE_SAVING_PLAYERS="false"
    export HYTALE_SAVING_CHUNKS="false"
    export HYTALE_UNLOADING_CHUNKS="false"
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

save_p=$(docker exec "$CONTAINER_NAME" jq -r '.IsSavingPlayers' /home/container/universe/worlds/default/config.json)
save_c=$(docker exec "$CONTAINER_NAME" jq -r '.IsSavingChunks' /home/container/universe/worlds/default/config.json)
unload=$(docker exec "$CONTAINER_NAME" jq -r '.IsUnloadingChunks' /home/container/universe/worlds/default/config.json)

if [ "$save_p" != "false" ]; then
    echo "FAIL: IsSavingPlayers should be false, got '$save_p'"
    exit 1
fi
echo "  ✓ HYTALE_SAVING_PLAYERS applied"

if [ "$save_c" != "false" ]; then
    echo "FAIL: IsSavingChunks should be false, got '$save_c'"
    exit 1
fi
echo "  ✓ HYTALE_SAVING_CHUNKS applied"

if [ "$unload" != "false" ]; then
    echo "FAIL: IsUnloadingChunks should be false, got '$unload'"
    exit 1
fi
echo "  ✓ HYTALE_UNLOADING_CHUNKS applied"

echo ""
echo "--- Test 11: Verify all changes persisted ---"

# Run script with no env vars - check previous values are still there
docker exec "$CONTAINER_NAME" sh -c '
    . /usr/local/bin/scripts/utils.sh
    sh /usr/local/bin/scripts/hytale/hytale_world_config.sh
'

pvp=$(docker exec "$CONTAINER_NAME" jq -r '.IsPvpEnabled' /home/container/universe/worlds/default/config.json)
gamemode=$(docker exec "$CONTAINER_NAME" jq -r '.GameMode' /home/container/universe/worlds/default/config.json)
paused=$(docker exec "$CONTAINER_NAME" jq -r '.IsGameTimePaused' /home/container/universe/worlds/default/config.json)
frozen=$(docker exec "$CONTAINER_NAME" jq -r '.IsAllNPCFrozen' /home/container/universe/worlds/default/config.json)
save_p=$(docker exec "$CONTAINER_NAME" jq -r '.IsSavingPlayers' /home/container/universe/worlds/default/config.json)

if [ "$pvp" != "true" ]; then
    echo "FAIL: PVP should still be true"
    exit 1
fi
if [ "$gamemode" != "Creative" ]; then
    echo "FAIL: GameMode should still be Creative"
    exit 1
fi
if [ "$paused" != "true" ]; then
    echo "FAIL: Time should still be paused"
    exit 1
fi
if [ "$frozen" != "true" ]; then
    echo "FAIL: NPCs should still be frozen"
    exit 1
fi
if [ "$save_p" != "false" ]; then
    echo "FAIL: Player saving should still be disabled"
    exit 1
fi
echo "  ✓ All previous values preserved"

echo ""
echo "=== All world config tests passed! ==="
exit 0
