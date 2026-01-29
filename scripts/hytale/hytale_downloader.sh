#!/bin/sh
set -eu

# Load dependencies
. "$SCRIPTS_PATH/utils.sh"

log_section "Hytale Downloader"

# Version tracking file
VERSION_FILE="$BASE_DIR/.hytale_version"

# Get installed version info (returns "version|patchline" or "none|none")
get_installed_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "none|none"
    fi
}

# Save version info after install
save_version() {
    local version="$1"
    local patchline="$2"
    echo "${version}|${patchline}" > "$VERSION_FILE"
}

# Get available version from hytale-downloader
# See: hytale-downloader/QUICKSTART.md for CLI reference
get_available_version() {
    hytale-downloader -patchline "$HYTALE_PATCHLINE" -print-version 2>/dev/null || echo "unknown"
}

# Extract date part from version (YYYY.MM.DD from YYYY.MM.DD-hash)
get_version_date() {
    echo "$1" | grep -o '^[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}'
}

# Compare versions: returns 0 if $1 > $2, 1 otherwise
# Versions can be YYYY.MM.DD or YYYY.MM.DD-hash format
# We compare the date part first, then full string if dates match
is_version_newer() {
    local new_ver="$1"
    local old_ver="$2"
    
    # Handle special cases
    [ "$old_ver" = "none" ] && return 0
    [ "$new_ver" = "unknown" ] && return 1
    [ "$new_ver" = "$old_ver" ] && return 1
    
    # Extract date parts for comparison
    local new_date=$(get_version_date "$new_ver")
    local old_date=$(get_version_date "$old_ver")
    
    # If dates differ, compare dates (lexicographic works for YYYY.MM.DD)
    if [ "$new_date" != "$old_date" ]; then
        [ "$new_date" \> "$old_date" ]
        return $?
    fi
    
    # Same date - compare full version (includes hash)
    # Different hash on same date = different build, treat as newer
    [ "$new_ver" \> "$old_ver" ]
}

# Helper function to extract and finalize
extract_server() {
    local zip_file="$1"
    local version="$2"
    local extract_failed=0
    
    log_step "Extracting Game Content"
    
    if [ "${DEBUG:-FALSE}" = "TRUE" ]; then
        printf "      ${DIM}↳ Source:${NC} %s\n" "$(basename "$zip_file")"
        printf "      ${DIM}↳ Target:${NC} ${GREEN}%s${NC}\n" "$GAME_DIR"
    fi
    
    # SAFE EXTRACTION: Only overwrites files from the archive
    # Files not in the archive (user data, configs, mods) remain untouched
    if unzip -o -q "$zip_file" -d "$GAME_DIR"; then
        log_success
        if [ "${DEBUG:-FALSE}" = "TRUE" ]; then
            printf "      ${DIM}↳ Note:${NC} Server binaries updated. User data preserved.\n"
        fi
    else
        extract_failed=1
        log_error "Extraction failed" "Check disk space or zip file integrity."
    fi
    
    # ALWAYS clean up zip file, even on failure (prevents boot loops)
    log_step "Post-Extraction Cleanup"
    rm -f "$zip_file"
    log_success
    
    # Exit after cleanup if extraction failed
    if [ "$extract_failed" = "1" ]; then
        exit 1
    fi
    
    # Save version info
    save_version "$version" "$HYTALE_PATCHLINE"
    
    chown -R container:container "$BASE_DIR" 2>/dev/null || true
    
    log_step "File Permissions"
    chmod -R 755 "$GAME_DIR" && log_success || log_warning "Chmod failed" "May need manual adjustment."
}

# Download and extract
download_and_install() {
    local reason="$1"
    
    log_warning "$reason"
    
    log_step "Checking Available Version"
    AVAILABLE_VERSION=$(get_available_version)
    if [ "${DEBUG:-FALSE}" = "TRUE" ]; then
        printf "      ${DIM}↳ Available:${NC} ${GREEN}%s${NC}\n" "$AVAILABLE_VERSION"
        printf "      ${DIM}↳ Patchline:${NC} ${GREEN}%s${NC}\n" "$HYTALE_PATCHLINE"
    fi
    
    log_step "Downloading"
    hytale-downloader -patchline "$HYTALE_PATCHLINE"
    
    ZIP_FILE=$(ls "$BASE_DIR"/[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]*.zip 2>/dev/null | head -n 1)
    
    if [ -z "$ZIP_FILE" ]; then
        log_error "Download failed." "Could not find valid YYYY.MM.DD*.zip after download."
        exit 1
    fi
    log_success
    
    # Extract full version from filename (YYYY.MM.DD or YYYY.MM.DD-hash format)
    # Remove .zip extension to get the version
    VERSION=$(basename "$ZIP_FILE" .zip)
    
    extract_server "$ZIP_FILE" "$VERSION"
}

# Clean existing installation for fresh download
# SAFE: Only removes server binaries ($GAME_DIR = /home/container/game/)
# PRESERVED: universe/ (worlds), mods/, config.json, .hytale-auth-tokens.json
clean_for_reinstall() {
    log_step "Cleaning for Reinstall"
    rm -rf "$GAME_DIR" 2>/dev/null || true
    rm -f "$VERSION_FILE" 2>/dev/null || true
    rm -f "$BASE_DIR"/*.zip 2>/dev/null || true
    log_success
}

# Main logic
log_step "Hytale Server Binary Check"

# Get current installed version and patchline
INSTALLED_INFO=$(get_installed_version)
INSTALLED_VERSION=$(echo "$INSTALLED_INFO" | cut -d'|' -f1)
INSTALLED_PATCHLINE=$(echo "$INSTALLED_INFO" | cut -d'|' -f2)

if [ "${DEBUG:-FALSE}" = "TRUE" ]; then
    printf "      ${DIM}↳ Installed:${NC} %s (%s)\n" "$INSTALLED_VERSION" "$INSTALLED_PATCHLINE"
    printf "      ${DIM}↳ Requested:${NC} %s\n" "$HYTALE_PATCHLINE"
fi

# Check for existing zip package (manual drop-in or leftover from failed download)
ZIP_FILE=$(ls "$BASE_DIR"/[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]*.zip 2>/dev/null | head -n 1)

if [ -n "$ZIP_FILE" ]; then
    # Zip file found - check if it's actually newer before extracting
    # Extract full version (YYYY.MM.DD or YYYY.MM.DD-hash)
    ZIP_VERSION=$(basename "$ZIP_FILE" .zip)
    
    if [ "${DEBUG:-FALSE}" = "TRUE" ]; then
        printf "      ${DIM}↳ Found zip:${NC} %s (v%s)\n" "$(basename "$ZIP_FILE")" "$ZIP_VERSION"
    fi
    
    # Only extract if: no server, patchline changed, or zip is newer
    if [ ! -f "$SERVER_JAR_PATH" ]; then
        log_success
        log_warning "Update package detected." "No server installed, applying package..."
        extract_server "$ZIP_FILE" "$ZIP_VERSION"
    elif [ "$INSTALLED_PATCHLINE" != "$HYTALE_PATCHLINE" ]; then
        log_success
        log_warning "Patchline changed." "Applying package for new patchline..."
        extract_server "$ZIP_FILE" "$ZIP_VERSION"
    elif is_version_newer "$ZIP_VERSION" "$INSTALLED_VERSION"; then
        log_success
        log_warning "Update package detected." "Applying v$ZIP_VERSION (installed: v$INSTALLED_VERSION)..."
        extract_server "$ZIP_FILE" "$ZIP_VERSION"
    else
        # Zip is same or older version - clean it up
        log_success
        printf "      ${DIM}↳ Info:${NC} Zip v%s is not newer than installed v%s, removing stale zip.\n" "$ZIP_VERSION" "$INSTALLED_VERSION"
        rm -f "$ZIP_FILE"
    fi

elif [ ! -f "$SERVER_JAR_PATH" ]; then
    # No jar - fresh install required
    log_success
    download_and_install "HytaleServer.jar not found. Downloading fresh installation..."

elif [ "$INSTALLED_VERSION" = "none" ] || [ ! -f "$VERSION_FILE" ]; then
    # FAILSAFE: JAR exists but no version tracking - inconsistent state
    # Clean and re-download to ensure known-good state
    log_success
    log_warning "Version tracking missing." "Server exists but version unknown. Cleaning for fresh download..."
    clean_for_reinstall
    download_and_install "Reinstalling to establish version tracking..."

elif [ "$INSTALLED_PATCHLINE" != "$HYTALE_PATCHLINE" ]; then
    # Patchline changed - need to re-download
    log_success
    clean_for_reinstall
    download_and_install "Patchline changed ($INSTALLED_PATCHLINE → $HYTALE_PATCHLINE). Re-downloading..."

else
    # Check for updates from server
    log_success
    AVAILABLE_VERSION=$(get_available_version)
    
    if is_version_newer "$AVAILABLE_VERSION" "$INSTALLED_VERSION"; then
        download_and_install "Update available ($INSTALLED_VERSION → $AVAILABLE_VERSION). Downloading..."
    else
        printf "      ${DIM}↳ Info:${NC} Server up-to-date (v%s, %s)\n" "$INSTALLED_VERSION" "$INSTALLED_PATCHLINE"
        printf "      ${DIM}↳ Note:${NC} Place newer YYYY.MM.DD*.zip in %s for manual update.\n" "$BASE_DIR"
    fi
fi