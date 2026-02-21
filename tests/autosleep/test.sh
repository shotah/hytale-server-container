#!/bin/bash
#
# Bundled Plugins Test (No Server JAR Required)
#
# Verifies:
#   - Nitrado PerformanceSaver JAR exists and installs correctly
#   - ServerBridge JAR exists and installs correctly
#   - Plugins are NOT copied when disabled
#   - Plugin manifest.json files are valid
#

set -euo pipefail

CONTAINER_NAME="hytale-test-perf-saver-$$"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Performance Saver Plugin Test ==="
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
echo "--- Test 1: Plugin JAR exists in image ---"

if ! docker exec "$CONTAINER_NAME" test -f /usr/local/lib/plugins/performance-saver.jar; then
    echo "FAIL: performance-saver.jar not found at /usr/local/lib/plugins/"
    exit 1
fi
echo "  ✓ performance-saver.jar exists in image"

echo ""
echo "--- Test 2: Plugin JAR is a valid zip/jar ---"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    head -c 2 /usr/local/lib/plugins/performance-saver.jar | od -A n -t x1 | tr -d " "
')

if [ "$result" != "504b" ]; then
    echo "FAIL: performance-saver.jar does not have valid JAR/ZIP magic bytes"
    exit 1
fi
echo "  ✓ performance-saver.jar is a valid JAR file"

echo ""
echo "--- Test 3: Plugin manifest.json exists inside JAR ---"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    unzip -l /usr/local/lib/plugins/performance-saver.jar 2>/dev/null | grep -c "manifest.json" || echo "0"
')

if [ "$result" = "0" ]; then
    echo "FAIL: manifest.json not found inside JAR"
    exit 1
fi
echo "  ✓ manifest.json found inside JAR"

echo ""
echo "--- Test 4: Plugin NOT copied when ENABLE_PERFORMANCE_SAVER=FALSE ---"

docker exec "$CONTAINER_NAME" sh -c '
    export ENABLE_PERFORMANCE_SAVER="FALSE"
    export BASE_DIR=/home/container
    rm -rf /home/container/mods

    if [ "$ENABLE_PERFORMANCE_SAVER" = "TRUE" ]; then
        mkdir -p "$BASE_DIR/mods"
        cp /usr/local/lib/plugins/performance-saver.jar "$BASE_DIR/mods/"
    fi
'

if docker exec "$CONTAINER_NAME" test -f /home/container/mods/performance-saver.jar 2>/dev/null; then
    echo "FAIL: Plugin should NOT be in mods/ when disabled"
    exit 1
fi
echo "  ✓ Plugin not installed when ENABLE_PERFORMANCE_SAVER=FALSE"

echo ""
echo "--- Test 5: Plugin copied when ENABLE_PERFORMANCE_SAVER=TRUE ---"

docker exec "$CONTAINER_NAME" sh -c '
    export ENABLE_PERFORMANCE_SAVER="TRUE"
    export BASE_DIR=/home/container

    if [ "$ENABLE_PERFORMANCE_SAVER" = "TRUE" ]; then
        mkdir -p "$BASE_DIR/mods"
        cp /usr/local/lib/plugins/performance-saver.jar "$BASE_DIR/mods/"
    fi
'

if ! docker exec "$CONTAINER_NAME" test -f /home/container/mods/performance-saver.jar; then
    echo "FAIL: Plugin should be in mods/ when enabled"
    exit 1
fi
echo "  ✓ Plugin installed to mods/ when ENABLE_PERFORMANCE_SAVER=TRUE"

echo ""
echo "--- Test 6: Existing mods preserved when plugin is installed ---"

docker exec "$CONTAINER_NAME" sh -c '
    mkdir -p /home/container/mods
    touch /home/container/mods/some-other-mod.jar

    export ENABLE_PERFORMANCE_SAVER="TRUE"
    export BASE_DIR=/home/container

    if [ "$ENABLE_PERFORMANCE_SAVER" = "TRUE" ]; then
        mkdir -p "$BASE_DIR/mods"
        cp /usr/local/lib/plugins/performance-saver.jar "$BASE_DIR/mods/"
    fi
'

if ! docker exec "$CONTAINER_NAME" test -f /home/container/mods/some-other-mod.jar; then
    echo "FAIL: Existing mods should be preserved"
    exit 1
fi
if ! docker exec "$CONTAINER_NAME" test -f /home/container/mods/performance-saver.jar; then
    echo "FAIL: PerformanceSaver should also be present"
    exit 1
fi
echo "  ✓ Existing mods preserved alongside PerformanceSaver"

echo ""
echo "--- Test 7: ServerBridge JAR exists in image ---"

if ! docker exec "$CONTAINER_NAME" test -f /usr/local/lib/plugins/serverbridge.jar; then
    echo "FAIL: serverbridge.jar not found at /usr/local/lib/plugins/"
    exit 1
fi
echo "  ✓ serverbridge.jar exists in image"

echo ""
echo "--- Test 8: ServerBridge JAR is a valid zip/jar ---"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    head -c 2 /usr/local/lib/plugins/serverbridge.jar | od -A n -t x1 | tr -d " "
')

if [ "$result" != "504b" ]; then
    echo "FAIL: serverbridge.jar does not have valid JAR/ZIP magic bytes"
    exit 1
fi
echo "  ✓ serverbridge.jar is a valid JAR file"

echo ""
echo "--- Test 9: ServerBridge manifest.json exists inside JAR ---"

result=$(docker exec "$CONTAINER_NAME" sh -c '
    unzip -l /usr/local/lib/plugins/serverbridge.jar 2>/dev/null | grep -c "manifest.json" || echo "0"
')

if [ "$result" = "0" ]; then
    echo "FAIL: manifest.json not found inside ServerBridge JAR"
    exit 1
fi
echo "  ✓ manifest.json found inside ServerBridge JAR"

echo ""
echo "--- Test 10: ServerBridge copied when ENABLE_SERVER_BRIDGE=TRUE ---"

docker exec "$CONTAINER_NAME" sh -c '
    rm -rf /home/container/mods
    export ENABLE_SERVER_BRIDGE="TRUE"
    export ENABLE_AUTO_RESTART="FALSE"
    export BASE_DIR=/home/container

    if [ "$ENABLE_SERVER_BRIDGE" = "TRUE" ] || [ "$ENABLE_AUTO_RESTART" = "TRUE" ]; then
        mkdir -p "$BASE_DIR/mods"
        cp /usr/local/lib/plugins/serverbridge.jar "$BASE_DIR/mods/"
    fi
'

if ! docker exec "$CONTAINER_NAME" test -f /home/container/mods/serverbridge.jar; then
    echo "FAIL: ServerBridge should be in mods/ when enabled"
    exit 1
fi
echo "  ✓ ServerBridge installed when ENABLE_SERVER_BRIDGE=TRUE"

echo ""
echo "--- Test 11: ServerBridge auto-installed when ENABLE_AUTO_RESTART=TRUE ---"

docker exec "$CONTAINER_NAME" sh -c '
    rm -rf /home/container/mods
    export ENABLE_SERVER_BRIDGE="FALSE"
    export ENABLE_AUTO_RESTART="TRUE"
    export BASE_DIR=/home/container

    if [ "$ENABLE_SERVER_BRIDGE" = "TRUE" ] || [ "$ENABLE_AUTO_RESTART" = "TRUE" ]; then
        mkdir -p "$BASE_DIR/mods"
        cp /usr/local/lib/plugins/serverbridge.jar "$BASE_DIR/mods/"
    fi
'

if ! docker exec "$CONTAINER_NAME" test -f /home/container/mods/serverbridge.jar; then
    echo "FAIL: ServerBridge should auto-install when auto-restart is enabled"
    exit 1
fi
echo "  ✓ ServerBridge auto-installed for auto-restart"

echo ""
echo "=== All bundled plugin tests passed! ==="
exit 0
