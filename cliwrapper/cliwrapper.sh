#!/bin/bash
# @author madebycm (2025)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.cliwrapper"
CONFIG_FILE="$CONFIG_DIR/config"
WRAPPER_PATH="$HOME/.local/bin/cliwrapper"
DATA_FILE="$SCRIPT_DIR/hello.txt"

function install() {
    echo "Installing cliwrapper..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Store installation directory in config
    echo "ROOT_INSTALL_DIR=\"$SCRIPT_DIR\"" > "$CONFIG_FILE"
    
    # Create wrapper script
    mkdir -p "$(dirname "$WRAPPER_PATH")"
    cat > "$WRAPPER_PATH" << 'EOF'
#!/bin/bash
# @author madebycm (2025)
# Wrapper script for cliwrapper

CONFIG_FILE="$HOME/.cliwrapper/config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: cliwrapper is not properly installed."
    echo "Please run './cliwrapper.sh install' from the installation directory."
    exit 1
fi

source "$CONFIG_FILE"

if [[ ! -d "$ROOT_INSTALL_DIR" ]]; then
    echo "Error: Installation directory not found: $ROOT_INSTALL_DIR"
    echo "Please reinstall cliwrapper."
    exit 1
fi

exec "$ROOT_INSTALL_DIR/cliwrapper.sh" "$@"
EOF
    
    chmod +x "$WRAPPER_PATH"
    
    echo "cliwrapper installed successfully!"
    echo "You can now run 'cliwrapper' from anywhere."
    
    # Add to PATH reminder
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo ""
        echo "Note: Make sure $HOME/.local/bin is in your PATH."
        echo "Add this to your shell configuration if needed:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

function uninstall() {
    echo "Uninstalling cliwrapper..."
    
    # Remove wrapper script
    if [[ -f "$WRAPPER_PATH" ]]; then
        rm "$WRAPPER_PATH"
        echo "Removed wrapper script."
    fi
    
    # Remove config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        echo "Removed configuration directory."
    fi
    
    echo "cliwrapper uninstalled successfully!"
    echo "Note: The installation directory remains intact at: $SCRIPT_DIR"
}

function main() {
    # Read data from hello.txt
    if [[ -f "$DATA_FILE" ]]; then
        data=$(cat "$DATA_FILE")
        echo "Hello, $data"
    else
        echo "Error: Data file not found: $DATA_FILE"
        echo "Please create hello.txt in the installation directory."
        exit 1
    fi
}

# Main execution
case "${1:-}" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        main "$@"
        ;;
esac