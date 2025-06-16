#!/bin/bash
# @author madebycm (2025)

set -e

# Cleanup function
cleanup() {
    rm -f /tmp/permsync.*.tmp 2>/dev/null
    # Clean up any tmp files in current directory
    find . -name "*.json.tmp*" -type f -delete 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Handle install command first
if [ "$1" = "install" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    
    # Create config directory and file
    CONFIG_DIR="$HOME/.permsync"
    CONFIG_FILE="$CONFIG_DIR/config"
    mkdir -p "$CONFIG_DIR"
    
    # Store the installation root directory in config
    cat > "$CONFIG_FILE" << EOF
# @author madebycm (2025)
# permsync configuration
ROOT_INSTALL_DIR="$SCRIPT_DIR"
EOF
    
    # Create a wrapper script
    cat > "$INSTALL_DIR/permsync" << EOF
#!/bin/bash
# @author madebycm (2025)
# permsync wrapper - installed version

# The actual permsync script location
PERMSYNC_EXEC="$SCRIPT_DIR/permsync.sh"

# Check if permsync executable exists
if [ ! -x "\$PERMSYNC_EXEC" ]; then
    echo "Error: permsync executable not found at \$PERMSYNC_EXEC"
    echo "The permsync installation may have been moved or deleted."
    exit 1
fi

# Execute the real permsync script
exec "\$PERMSYNC_EXEC" "\$@"
EOF
    
    chmod +x "$INSTALL_DIR/permsync"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "permsync installed to $INSTALL_DIR/permsync"
        echo ""
        echo "To use permsync from anywhere, add this to your shell profile:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    else
        echo "permsync installed successfully to $INSTALL_DIR/permsync"
        echo "You can now use 'permsync' from anywhere!"
    fi
    exit 0
fi

# Check if running from wrapper or source
if [ -f "$0" ] && [ "$(basename "$0")" = "permsync.sh" ]; then
    # Running from source directory
    ROOT_INSTALL_DIR="$SCRIPT_DIR"
else
    # Running from wrapper - load config
    CONFIG_FILE="$HOME/.permsync/config"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "Error: Configuration file not found. Please reinstall permsync."
        exit 1
    fi
fi

# Check if installed, if not prompt to install
if [ ! -f "$HOME/.local/bin/permsync" ] && [ ! -f "/usr/local/bin/permsync" ]; then
    echo "permsync is not installed."
    echo "Would you like to install it? (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        "$0" install
        exit 0
    else
        echo "Installation cancelled. Running without installation..."
    fi
fi

# allowed.json and blacklist.json are always in the installation directory
ALLOWED_FILE="$ROOT_INSTALL_DIR/allowed.json"
BLACKLIST_FILE="$ROOT_INSTALL_DIR/blacklist.json"

# Handle uninstall command
if [ "$1" = "uninstall" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME/.permsync"
    
    # Remove the wrapper script
    if [ -f "$INSTALL_DIR/permsync" ]; then
        rm "$INSTALL_DIR/permsync"
        echo "permsync uninstalled from $INSTALL_DIR/permsync"
    else
        echo "permsync not found in $INSTALL_DIR"
    fi
    
    # Remove the config directory
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo "Removed permsync configuration from $CONFIG_DIR"
    fi
    
    exit 0
fi

# Find .claude/settings.local.json file
find_settings_file() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/.claude/settings.local.json" ]]; then
            echo "$current_dir/.claude/settings.local.json"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # Also check current directory
    if [[ -f "$PWD/.claude/settings.local.json" ]]; then
        echo "$PWD/.claude/settings.local.json"
        return 0
    fi
    
    return 1
}

# Read permissions from allowed.json
read_allowed_permissions() {
    if [[ ! -f "$ALLOWED_FILE" ]]; then
        # Create default allowed.json with empty permissions
        echo '{"permissions":{"allow":[],"deny":[]}}' | jq '.' > "$ALLOWED_FILE"
    fi
    
    # Read permissions from allowed.json
    jq -r '.permissions.allow[]' "$ALLOWED_FILE" 2>/dev/null | grep -E '^Bash\(' | sort -u
}

# Read blacklisted permissions
read_blacklisted_permissions() {
    if [[ ! -f "$BLACKLIST_FILE" ]]; then
        # Create default blacklist.json with empty permissions
        echo '{"permissions":{"blacklist":[]}}' | jq '.' > "$BLACKLIST_FILE"
    fi
    
    # Read all blacklist patterns (including wildcards)
    jq -r '.permissions.blacklist[]' "$BLACKLIST_FILE" 2>/dev/null | sort -u
}

# Write permissions to allowed.json
write_allowed_permissions() {
    local perms="$1"
    
    # Convert newline-separated permissions to JSON array
    local json_array="[]"
    while IFS= read -r perm; do
        if [[ -n "$perm" ]]; then
            json_array=$(echo "$json_array" | jq --arg perm "$perm" '. += [$perm]')
        fi
    done <<< "$perms"
    
    # Update allowed.json
    jq --argjson perms "$json_array" '.permissions.allow = $perms' "$ALLOWED_FILE" > "$ALLOWED_FILE.tmp" && mv "$ALLOWED_FILE.tmp" "$ALLOWED_FILE"
}

# Main sync function
sync_permissions() {
    local settings_file="$1"
    
    # Clean up any leftover tmp files first
    rm -f "$settings_file.tmp" "$settings_file.tmp2" "$ALLOWED_FILE.tmp" 2>/dev/null
    
    # Read permissions from all files
    local allowed_perms=$(read_allowed_permissions)
    local json_perms=$(jq -r '.permissions.allow[]' "$settings_file" 2>/dev/null | grep -E '^Bash\(' | sort -u)
    local blacklisted_perms=$(read_blacklisted_permissions)
    
    # Merge permissions (union of both sets)
    local all_perms=$(echo -e "$allowed_perms\n$json_perms" | grep -v '^$' | sort -u)
    
    # Filter out blacklisted permissions from allowed.json only
    local filtered_allowed_perms=""
    while IFS= read -r perm; do
        if [[ -n "$perm" ]]; then
            # Check if this permission matches any blacklist pattern
            local is_blacklisted=false
            while IFS= read -r blacklist_pattern; do
                if [[ -n "$blacklist_pattern" ]]; then
                    # Convert * wildcards to regex pattern matching
                    # First escape special regex characters, but not *
                    local pattern=$(echo "$blacklist_pattern" | sed 's/\([[\\.^$()|?+{}]\)/\\\1/g')
                    # Then convert * to .*
                    pattern="${pattern//\*/.*}"
                    
                    # Check if permission matches the pattern
                    if echo "$perm" | grep -Eq "^${pattern}$"; then
                        is_blacklisted=true
                        break
                    fi
                fi
            done <<< "$blacklisted_perms"
            
            # Only add if not blacklisted
            if [[ "$is_blacklisted" == false ]]; then
                if [[ -n "$filtered_allowed_perms" ]]; then
                    filtered_allowed_perms="$filtered_allowed_perms"$'\n'"$perm"
                else
                    filtered_allowed_perms="$perm"
                fi
            fi
        fi
    done <<< "$all_perms"
    
    # Update allowed.json with filtered permissions
    write_allowed_permissions "$filtered_allowed_perms"
    
    # Update settings.local.json - preserve existing structure
    # First validate the JSON
    if ! jq empty "$settings_file" 2>/dev/null; then
        echo "Error: Invalid JSON in $settings_file"
        echo "Please fix the JSON syntax and try again."
        exit 1
    fi
    
    local current_json=$(cat "$settings_file")
    local deny_list=$(echo "$current_json" | jq '.permissions.deny // []')
    
    # Build clean array of permissions
    local perms_array="["
    local first=true
    while IFS= read -r perm; do
        if [[ -n "$perm" ]]; then
            if [[ "$first" == true ]]; then
                perms_array="${perms_array}\"${perm}\""
                first=false
            else
                perms_array="${perms_array},\"${perm}\""
            fi
        fi
    done <<< "$all_perms"
    perms_array="${perms_array}]"
    
    # Update settings file preserving deny list and other fields
    echo "$current_json" | jq --argjson allow "$perms_array" --argjson deny "$deny_list" \
        '.permissions.allow = $allow | .permissions.deny = $deny' > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    
    echo "✓ Synchronized permissions:"
    echo "  - Total permissions: $(echo "$all_perms" | grep -v '^$' | wc -l | tr -d ' ')"
    echo "  - Allowed (after blacklist): $(echo "$filtered_allowed_perms" | grep -v '^$' | wc -l | tr -d ' ')"
    echo "  - Blacklisted: $(echo "$blacklisted_perms" | grep -v '^$' | wc -l | tr -d ' ')"
    echo "  - Local settings: $settings_file"
    echo "  - Global allowed: $ALLOWED_FILE"
    echo "  - Blacklist: $BLACKLIST_FILE"
}

# Main execution
main() {
    echo "Scanning for .claude/settings.local.json..."
    
    if settings_file=$(find_settings_file); then
        echo "Found: $settings_file"
        sync_permissions "$settings_file"
    else
        echo "Error: No .claude/settings.local.json file found in current directory or parent directories"
        exit 1
    fi
}

main "$@"