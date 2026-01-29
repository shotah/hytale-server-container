#!/bin/sh
set -eu

# Hytale World Configuration Manager - Manages world-specific config.json settings
# This configures settings in universe/worlds/{world}/config.json

# Load dependencies
. "$SCRIPTS_PATH/utils.sh"

# Get the world name from server config or default
get_world_name() {
    local server_config="${BASE_DIR:-/home/container}/config.json"
    if [ -f "$server_config" ]; then
        jq -r '.Defaults.World // "default"' "$server_config" 2>/dev/null || echo "default"
    else
        echo "default"
    fi
}

# Constants
WORLD_NAME=$(get_world_name)
readonly UNIVERSE_DIR="${BASE_DIR:-/home/container}/universe"
readonly WORLD_DIR="$UNIVERSE_DIR/worlds/$WORLD_NAME"
readonly WORLD_CONFIG="$WORLD_DIR/config.json"
readonly CONFIG_TMP_SUFFIX=".tmp"

# Check if world config exists
check_world_exists() {
    if [ ! -d "$WORLD_DIR" ]; then
        return 1
    fi
    if [ ! -f "$WORLD_CONFIG" ]; then
        return 1
    fi
    return 0
}

# Validate that config file contains valid JSON
validate_config_json() {
    jq empty "$WORLD_CONFIG" >/dev/null 2>&1
}

# Apply environment variable to JSON config
# Args: $1=JSON path, $2=value, $3=type (string|number|boolean)
apply_env() {
    local path="$1"
    local value="$2"
    local value_type="${3:-auto}"
    local tmp_file="${WORLD_CONFIG}${CONFIG_TMP_SUFFIX}"

    # Skip if environment variable is not set
    [ -z "$value" ] && return 0

    # Apply value based on type
    case "$value_type" in
        string)
            if ! jq "$path = \"$value\"" "$WORLD_CONFIG" > "$tmp_file" 2>/dev/null; then
                printf "      ${YELLOW}⚠ Failed to apply %s${NC}\n" "$path"
                rm -f "$tmp_file"
                return 1
            fi
            ;;
        number)
            if ! jq "$path = ($value | tonumber)" "$WORLD_CONFIG" > "$tmp_file" 2>/dev/null; then
                printf "      ${YELLOW}⚠ Failed to apply %s (invalid number)${NC}\n" "$path"
                rm -f "$tmp_file"
                return 1
            fi
            ;;
        boolean)
            case "$value" in
                true|TRUE|1|yes|YES)
                    if ! jq "$path = true" "$WORLD_CONFIG" > "$tmp_file" 2>/dev/null; then
                        printf "      ${YELLOW}⚠ Failed to apply %s${NC}\n" "$path"
                        rm -f "$tmp_file"
                        return 1
                    fi
                    ;;
                false|FALSE|0|no|NO)
                    if ! jq "$path = false" "$WORLD_CONFIG" > "$tmp_file" 2>/dev/null; then
                        printf "      ${YELLOW}⚠ Failed to apply %s${NC}\n" "$path"
                        rm -f "$tmp_file"
                        return 1
                    fi
                    ;;
                *)
                    printf "      ${YELLOW}⚠ Invalid boolean value for %s: %s${NC}\n" "$path" "$value"
                    return 1
                    ;;
            esac
            ;;
    esac

    mv -f "$tmp_file" "$WORLD_CONFIG"
    return 0
}

# Main Logic
log_section "World Configuration Management"

# Check if any world config env vars are set
has_world_config_vars() {
    [ -n "${HYTALE_PVP_ENABLED:-}" ] || \
    [ -n "${HYTALE_FALL_DAMAGE:-}" ] || \
    [ -n "${HYTALE_NPC_SPAWNING:-}" ] || \
    [ -n "${HYTALE_WORLD_GAMEMODE:-}" ] || \
    [ -n "${HYTALE_DAYTIME_DURATION:-}" ] || \
    [ -n "${HYTALE_NIGHTTIME_DURATION:-}" ] || \
    [ -n "${HYTALE_TIME_PAUSED:-}" ]
}

# Skip if no world config vars are set
if ! has_world_config_vars; then
    log_step "World config overrides"
    printf "${DIM}no overrides set${NC}\n"
    exit 0
fi

# Check if world exists
log_step "Checking world"
if ! check_world_exists; then
    printf "${YELLOW}world '$WORLD_NAME' not found${NC}\n"
    printf "      ${DIM}↳ World config will be applied after first server run${NC}\n"
    exit 0
fi

# Validate world config
if ! validate_config_json; then
    printf "${YELLOW}invalid JSON in world config${NC}\n"
    exit 0
fi

printf "${GREEN}$WORLD_NAME${NC}\n"

# Apply environment variable overrides
log_step "Applying world overrides"

apply_env ".IsPvpEnabled"           "${HYTALE_PVP_ENABLED:-}"        "boolean"
apply_env ".IsFallDamageEnabled"    "${HYTALE_FALL_DAMAGE:-}"        "boolean"
apply_env ".IsSpawningNPC"          "${HYTALE_NPC_SPAWNING:-}"       "boolean"
apply_env ".GameMode"               "${HYTALE_WORLD_GAMEMODE:-}"     "string"
apply_env ".DaytimeDurationSeconds" "${HYTALE_DAYTIME_DURATION:-}"   "number"
apply_env ".NighttimeDurationSeconds" "${HYTALE_NIGHTTIME_DURATION:-}" "number"
apply_env ".IsGameTimePaused"       "${HYTALE_TIME_PAUSED:-}"        "boolean"

log_success

# Display current world configuration
printf "\n"

log_step "PVP"
PVP=$(jq -r '.IsPvpEnabled' "$WORLD_CONFIG" 2>/dev/null || echo "false")
if [ "$PVP" = "true" ]; then
    printf "${GREEN}enabled${NC}\n"
else
    printf "${DIM}disabled${NC}\n"
fi

log_step "Fall Damage"
FALL=$(jq -r '.IsFallDamageEnabled' "$WORLD_CONFIG" 2>/dev/null || echo "true")
if [ "$FALL" = "true" ]; then
    printf "${GREEN}enabled${NC}\n"
else
    printf "${DIM}disabled${NC}\n"
fi

log_step "NPC Spawning"
NPC=$(jq -r '.IsSpawningNPC' "$WORLD_CONFIG" 2>/dev/null || echo "true")
if [ "$NPC" = "true" ]; then
    printf "${GREEN}enabled${NC}\n"
else
    printf "${DIM}disabled${NC}\n"
fi

log_step "World Game Mode"
GAMEMODE=$(jq -r '.GameMode' "$WORLD_CONFIG" 2>/dev/null || echo "Adventure")
printf "${GREEN}%s${NC}\n" "$GAMEMODE"

log_step "Day/Night Cycle"
DAY=$(jq -r '.DaytimeDurationSeconds' "$WORLD_CONFIG" 2>/dev/null || echo "1728")
NIGHT=$(jq -r '.NighttimeDurationSeconds' "$WORLD_CONFIG" 2>/dev/null || echo "1151")
printf "${GREEN}%ss${NC} day / ${GREEN}%ss${NC} night\n" "$DAY" "$NIGHT"

log_step "Time Paused"
PAUSED=$(jq -r '.IsGameTimePaused' "$WORLD_CONFIG" 2>/dev/null || echo "false")
if [ "$PAUSED" = "true" ]; then
    printf "${YELLOW}paused${NC}\n"
else
    printf "${DIM}running${NC}\n"
fi
