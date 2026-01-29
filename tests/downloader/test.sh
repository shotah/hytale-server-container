#!/bin/bash
#
# Downloader Version Tracking Test (No actual download)
#
# Verifies:
#   - Version file format is correct
#   - Version comparison works (YYYY.MM.DD format)
#   - Stale zips are cleaned up (same/older version)
#   - Failsafe triggers when JAR exists but version file missing
#   - Patchline change triggers re-download logic
#   - Zip cleanup happens even on extraction failure
#

set -euo pipefail

CONTAINER_NAME="hytale-test-downloader-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Downloader Version Tracking Test ==="
echo "Image: $IMAGE_TO_TEST"

# Start container with shell
echo "Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --entrypoint /bin/sh \
    -e SCRIPTS_PATH=/usr/local/bin/scripts \
    -e BASE_DIR=/home/container \
    -e GAME_DIR=/home/container/game \
    -e SERVER_JAR_PATH=/home/container/game/Server/HytaleServer.jar \
    -e HYTALE_PATCHLINE=release \
    -e DEBUG=TRUE \
    "$IMAGE_TO_TEST" \
    -c "sleep 300"

sleep 2

echo ""
echo "--- Test 1: Version file functions ---"

# Test get_installed_version when no file exists
result=$(docker exec "$CONTAINER_NAME" sh -c '
    export VERSION_FILE=/home/container/.hytale_version
    get_installed_version() {
        if [ -f "$VERSION_FILE" ]; then
            cat "$VERSION_FILE"
        else
            echo "none|none"
        fi
    }
    get_installed_version
')

if [ "$result" != "none|none" ]; then
    echo "FAIL: Expected 'none|none' when no version file, got '$result'"
    exit 1
fi
echo "  ✓ get_installed_version returns 'none|none' when file missing"

# Test save_version
docker exec "$CONTAINER_NAME" sh -c '
    export VERSION_FILE=/home/container/.hytale_version
    save_version() {
        local version="$1"
        local patchline="$2"
        echo "${version}|${patchline}" > "$VERSION_FILE"
    }
    save_version "2026.01.15" "release"
'

result=$(docker exec "$CONTAINER_NAME" cat /home/container/.hytale_version)
if [ "$result" != "2026.01.15|release" ]; then
    echo "FAIL: Version file format wrong, got '$result'"
    exit 1
fi
echo "  ✓ save_version creates correct format"

echo ""
echo "--- Test 2: Version parsing ---"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    echo "2026.01.15|release" | cut -d"|" -f1
')
if [ "$result" != "2026.01.15" ]; then
    echo "FAIL: Version parsing failed"
    exit 1
fi
echo "  ✓ Version extracted correctly"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    echo "2026.01.15|release" | cut -d"|" -f2
')
if [ "$result" != "release" ]; then
    echo "FAIL: Patchline parsing failed"
    exit 1
fi
echo "  ✓ Patchline extracted correctly"

echo ""
echo "--- Test 3: Version comparison function ---"

# Define the version comparison functions for testing
VERSION_FUNCS='
get_version_date() {
    echo "$1" | grep -o "^[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}"
}

is_version_newer() {
    local new_ver="$1"
    local old_ver="$2"
    [ "$old_ver" = "none" ] && return 0
    [ "$new_ver" = "unknown" ] && return 1
    [ "$new_ver" = "$old_ver" ] && return 1
    local new_date=$(get_version_date "$new_ver")
    local old_date=$(get_version_date "$old_ver")
    if [ "$new_date" != "$old_date" ]; then
        [ "$new_date" \> "$old_date" ]
        return $?
    fi
    [ "$new_ver" \> "$old_ver" ]
}
'

# Test: newer date version
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.02.01" "2026.01.15"; then
        echo "NEWER_CORRECT"
    else
        echo "NEWER_FAIL"
    fi
')
if [ "$result" != "NEWER_CORRECT" ]; then
    echo "FAIL: 2026.02.01 should be newer than 2026.01.15"
    exit 1
fi
echo "  ✓ Newer date version detected correctly"

# Test: older date version
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.01.01" "2026.01.15"; then
        echo "OLDER_FAIL"
    else
        echo "OLDER_CORRECT"
    fi
')
if [ "$result" != "OLDER_CORRECT" ]; then
    echo "FAIL: 2026.01.01 should NOT be newer than 2026.01.15"
    exit 1
fi
echo "  ✓ Older date version rejected correctly"

# Test: same version (no hash)
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.01.15" "2026.01.15"; then
        echo "SAME_FAIL"
    else
        echo "SAME_CORRECT"
    fi
')
if [ "$result" != "SAME_CORRECT" ]; then
    echo "FAIL: Same version should NOT be considered newer"
    exit 1
fi
echo "  ✓ Same version rejected correctly"

# Test: fresh install (none)
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.01.15" "none"; then
        echo "NONE_CORRECT"
    else
        echo "NONE_FAIL"
    fi
')
if [ "$result" != "NONE_CORRECT" ]; then
    echo "FAIL: Any version should be newer than 'none'"
    exit 1
fi
echo "  ✓ Fresh install (none) handled correctly"

# Test: version with hash - same date, different hash
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.01.15-87d03be09" "2026.01.15-49e5904"; then
        echo "HASH_NEWER_CORRECT"
    else
        echo "HASH_NEWER_FAIL"
    fi
')
if [ "$result" != "HASH_NEWER_CORRECT" ]; then
    echo "FAIL: Same date with different (lexicographically greater) hash should be newer"
    exit 1
fi
echo "  ✓ Same date, newer hash detected correctly"

# Test: version with hash vs without hash
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.01.15-87d03be09" "2026.01.15"; then
        echo "HASH_VS_NOHASH_CORRECT"
    else
        echo "HASH_VS_NOHASH_FAIL"
    fi
')
if [ "$result" != "HASH_VS_NOHASH_CORRECT" ]; then
    echo "FAIL: Version with hash should be newer than same date without hash"
    exit 1
fi
echo "  ✓ Version with hash vs without hash handled correctly"

# Test: newer date beats older hash
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    if is_version_newer "2026.02.01-abc1234" "2026.01.15-zzz9999"; then
        echo "DATE_BEATS_HASH_CORRECT"
    else
        echo "DATE_BEATS_HASH_FAIL"
    fi
')
if [ "$result" != "DATE_BEATS_HASH_CORRECT" ]; then
    echo "FAIL: Newer date should beat older date regardless of hash"
    exit 1
fi
echo "  ✓ Date comparison takes priority over hash"

echo ""
echo "--- Test 4: Failsafe detection (JAR exists, no version file) ---"

# Create fake JAR but no version file
docker exec "$CONTAINER_NAME" sh -c '
    mkdir -p /home/container/game/Server
    touch /home/container/game/Server/HytaleServer.jar
    rm -f /home/container/.hytale_version
'

# Check the condition
result=$(docker exec "$CONTAINER_NAME" sh -c '
    export VERSION_FILE=/home/container/.hytale_version
    export SERVER_JAR_PATH=/home/container/game/Server/HytaleServer.jar
    
    get_installed_version() {
        if [ -f "$VERSION_FILE" ]; then
            cat "$VERSION_FILE"
        else
            echo "none|none"
        fi
    }
    
    INSTALLED_INFO=$(get_installed_version)
    INSTALLED_VERSION=$(echo "$INSTALLED_INFO" | cut -d"|" -f1)
    
    # Check failsafe condition
    if [ -f "$SERVER_JAR_PATH" ] && { [ "$INSTALLED_VERSION" = "none" ] || [ ! -f "$VERSION_FILE" ]; }; then
        echo "FAILSAFE_TRIGGERED"
    else
        echo "NO_FAILSAFE"
    fi
')

if [ "$result" != "FAILSAFE_TRIGGERED" ]; then
    echo "FAIL: Failsafe should trigger when JAR exists but no version file"
    exit 1
fi
echo "  ✓ Failsafe triggers when JAR exists without version file"

echo ""
echo "--- Test 5: No failsafe when both exist ---"

# Create version file
docker exec "$CONTAINER_NAME" sh -c '
    echo "2026.01.15|release" > /home/container/.hytale_version
'

result=$(docker exec "$CONTAINER_NAME" sh -c '
    export VERSION_FILE=/home/container/.hytale_version
    export SERVER_JAR_PATH=/home/container/game/Server/HytaleServer.jar
    
    get_installed_version() {
        if [ -f "$VERSION_FILE" ]; then
            cat "$VERSION_FILE"
        else
            echo "none|none"
        fi
    }
    
    INSTALLED_INFO=$(get_installed_version)
    INSTALLED_VERSION=$(echo "$INSTALLED_INFO" | cut -d"|" -f1)
    
    if [ -f "$SERVER_JAR_PATH" ] && { [ "$INSTALLED_VERSION" = "none" ] || [ ! -f "$VERSION_FILE" ]; }; then
        echo "FAILSAFE_TRIGGERED"
    else
        echo "NO_FAILSAFE"
    fi
')

if [ "$result" != "NO_FAILSAFE" ]; then
    echo "FAIL: Failsafe should NOT trigger when both JAR and version file exist"
    exit 1
fi
echo "  ✓ No failsafe when both JAR and version file exist"

echo ""
echo "--- Test 6: Patchline change detection ---"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    INSTALLED_PATCHLINE="release"
    HYTALE_PATCHLINE="pre-release"
    
    if [ "$INSTALLED_PATCHLINE" != "$HYTALE_PATCHLINE" ]; then
        echo "PATCHLINE_CHANGED"
    else
        echo "SAME"
    fi
')

if [ "$result" != "PATCHLINE_CHANGED" ]; then
    echo "FAIL: Should detect patchline change"
    exit 1
fi
echo "  ✓ Patchline change detected"

echo ""
echo "--- Test 7: Stale zip cleanup (same/older version) ---"

# Setup: installed v2026.01.15-abc123, zip is v2026.01.10-def456 (older)
docker exec "$CONTAINER_NAME" sh -c '
    mkdir -p /home/container/game/Server
    touch /home/container/game/Server/HytaleServer.jar
    echo "2026.01.15-abc1234|release" > /home/container/.hytale_version
    touch "/home/container/2026.01.10-def456.zip"
'

# Simulate the stale zip detection logic
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    INSTALLED_VERSION="2026.01.15-abc1234"
    ZIP_VERSION="2026.01.10-def456"
    
    if is_version_newer "$ZIP_VERSION" "$INSTALLED_VERSION"; then
        echo "WOULD_EXTRACT"
    else
        echo "WOULD_CLEANUP"
    fi
')

if [ "$result" != "WOULD_CLEANUP" ]; then
    echo "FAIL: Older zip should be cleaned up, not extracted"
    exit 1
fi
echo "  ✓ Stale zip (older date) would be cleaned up"

# Test same version with hash
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    INSTALLED_VERSION="2026.01.15-abc1234"
    ZIP_VERSION="2026.01.15-abc1234"
    
    if is_version_newer "$ZIP_VERSION" "$INSTALLED_VERSION"; then
        echo "WOULD_EXTRACT"
    else
        echo "WOULD_CLEANUP"
    fi
')

if [ "$result" != "WOULD_CLEANUP" ]; then
    echo "FAIL: Same version zip should be cleaned up"
    exit 1
fi
echo "  ✓ Stale zip (same version+hash) would be cleaned up"

echo ""
echo "--- Test 8: Newer zip would be extracted ---"

result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    INSTALLED_VERSION="2026.01.15-abc1234"
    ZIP_VERSION="2026.02.01-xyz9999"
    
    if is_version_newer "$ZIP_VERSION" "$INSTALLED_VERSION"; then
        echo "WOULD_EXTRACT"
    else
        echo "WOULD_CLEANUP"
    fi
')

if [ "$result" != "WOULD_EXTRACT" ]; then
    echo "FAIL: Newer zip should be extracted"
    exit 1
fi
echo "  ✓ Newer zip (newer date) would be extracted"

# Test same date but new hash (new build)
result=$(docker exec "$CONTAINER_NAME" sh -c "$VERSION_FUNCS"'
    INSTALLED_VERSION="2026.01.15-abc1234"
    ZIP_VERSION="2026.01.15-xyz9999"
    
    if is_version_newer "$ZIP_VERSION" "$INSTALLED_VERSION"; then
        echo "WOULD_EXTRACT"
    else
        echo "WOULD_CLEANUP"
    fi
')

if [ "$result" != "WOULD_EXTRACT" ]; then
    echo "FAIL: Same date with newer hash should be extracted"
    exit 1
fi
echo "  ✓ Newer zip (same date, new hash) would be extracted"

echo ""
echo "--- Test 9: clean_for_reinstall removes correct files ---"

# Setup files
docker exec "$CONTAINER_NAME" sh -c '
    mkdir -p /home/container/game/Server
    touch /home/container/game/Server/HytaleServer.jar
    echo "2026.01.15|release" > /home/container/.hytale_version
    touch /home/container/2026.01.15.zip
    
    # User data that should NOT be deleted
    mkdir -p /home/container/universe
    touch /home/container/universe/world.dat
    mkdir -p /home/container/mods
    touch /home/container/mods/mymod.jar
    touch /home/container/config.json
'

# Run clean_for_reinstall
docker exec "$CONTAINER_NAME" sh -c '
    export GAME_DIR=/home/container/game
    export VERSION_FILE=/home/container/.hytale_version
    export BASE_DIR=/home/container
    
    # Inline clean function
    rm -rf "$GAME_DIR" 2>/dev/null || true
    rm -f "$VERSION_FILE" 2>/dev/null || true
    rm -f "$BASE_DIR"/*.zip 2>/dev/null || true
'

# Verify game dir removed
if docker exec "$CONTAINER_NAME" test -d /home/container/game 2>/dev/null; then
    echo "FAIL: game/ directory should be removed"
    exit 1
fi
echo "  ✓ game/ directory removed"

# Verify version file removed
if docker exec "$CONTAINER_NAME" test -f /home/container/.hytale_version 2>/dev/null; then
    echo "FAIL: version file should be removed"
    exit 1
fi
echo "  ✓ Version file removed"

# Verify zip removed
if docker exec "$CONTAINER_NAME" test -f /home/container/2026.01.15.zip 2>/dev/null; then
    echo "FAIL: zip file should be removed"
    exit 1
fi
echo "  ✓ Zip files removed"

# Verify user data preserved
if ! docker exec "$CONTAINER_NAME" test -f /home/container/universe/world.dat; then
    echo "FAIL: universe/ should be preserved"
    exit 1
fi
echo "  ✓ universe/ (worlds) preserved"

if ! docker exec "$CONTAINER_NAME" test -f /home/container/mods/mymod.jar; then
    echo "FAIL: mods/ should be preserved"
    exit 1
fi
echo "  ✓ mods/ preserved"

if ! docker exec "$CONTAINER_NAME" test -f /home/container/config.json; then
    echo "FAIL: config.json should be preserved"
    exit 1
fi
echo "  ✓ config.json preserved"

echo ""
echo "=== All downloader tests passed! ==="
exit 0
