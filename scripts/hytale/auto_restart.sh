#!/bin/sh
# Auto-Restart Watchdog
#
# Runs as a background process. Sleeps for the configured interval,
# then warns players via ServerBridge (if available) and sends SIGTERM
# to PID 1 (the Java server process after exec).
# Docker's restart policy brings the container back up, which triggers
# the downloader to check for updates.
#
# Requires: restart: unless-stopped (or always) in docker-compose

. "$SCRIPTS_PATH/utils.sh"

INTERVAL_HOURS="${AUTO_RESTART_INTERVAL:-24}"
STATUS_FILE="$BASE_DIR/server-status.json"
COMMANDS_FILE="$BASE_DIR/server-commands.json"

# Validate interval
case "$INTERVAL_HOURS" in
    ''|*[!0-9]*) 
        printf "      ${YELLOW}⚠ Invalid AUTO_RESTART_INTERVAL: %s (must be a number)${NC}\n" "$INTERVAL_HOURS"
        exit 1
        ;;
esac

if [ "$INTERVAL_HOURS" -lt 1 ]; then
    printf "      ${YELLOW}⚠ AUTO_RESTART_INTERVAL must be >= 1 hour${NC}\n"
    exit 1
fi

INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))
WARNING_SECONDS=600  # Start warnings 10 minutes before restart
SLEEP_UNTIL=$((INTERVAL_SECONDS - WARNING_SECONDS))

# Calculate approximate restart time for display
if command -v date >/dev/null 2>&1; then
    RESTART_AT=$(date -d "+${INTERVAL_HOURS} hours" '+%Y-%m-%d %H:%M %Z' 2>/dev/null || \
                 date -v+${INTERVAL_HOURS}H '+%Y-%m-%d %H:%M %Z' 2>/dev/null || \
                 echo "in ${INTERVAL_HOURS}h")
else
    RESTART_AT="in ${INTERVAL_HOURS}h"
fi

printf "      ${DIM}↳ Next restart:${NC} ${GREEN}%s${NC}\n" "$RESTART_AT"

# Send a broadcast command via ServerBridge (if plugin is active)
send_broadcast() {
    MSG="$1"
    printf '{"command": "broadcast", "message": "%s"}\n' "$MSG" > "$COMMANDS_FILE" 2>/dev/null || true
}

# Check if players are online via ServerBridge status file
get_player_count() {
    if [ -f "$STATUS_FILE" ]; then
        # Extract players_online from JSON using basic tools
        PLAYERS=$(grep -o '"players_online":[[:space:]]*[0-9]*' "$STATUS_FILE" 2>/dev/null \
                  | grep -o '[0-9]*$' 2>/dev/null || echo "-1")
        echo "$PLAYERS"
    else
        echo "-1"
    fi
}

# Sleep until warning period
if [ "$SLEEP_UNTIL" -gt 0 ]; then
    sleep "$SLEEP_UNTIL"
fi

# Countdown warnings
send_broadcast "Server restarting in 10 minutes for updates."
sleep 300  # 5 min

send_broadcast "Server restarting in 5 minutes."
sleep 180  # 3 min

send_broadcast "Server restarting in 2 minutes!"
sleep 60   # 1 min

send_broadcast "Server restarting in 1 minute!"
sleep 50   # 50 sec

send_broadcast "Server restarting in 10 seconds!"
sleep 10

printf "\n${BOLD}${YELLOW}⏰ Auto-restart: Scheduled restart after %sh. Shutting down for update check...${NC}\n\n" "$INTERVAL_HOURS"

# SIGTERM to PID 1 (Java process after exec) triggers graceful shutdown
# Docker restart policy will bring the container back up
kill -TERM 1
