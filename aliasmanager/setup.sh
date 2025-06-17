#!/bin/bash
# @author madebycm (2025-01-23)

echo "Setting up Alias Manager..."

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Add alias to .zprofile
ALIAS_LINE="alias am='$SCRIPT_DIR/am'"

if grep -q "alias am=" ~/.zprofile 2>/dev/null; then
    echo "Alias 'am' already exists in .zprofile"
    echo "You may need to update it manually to: $ALIAS_LINE"
else
    echo "" >> ~/.zprofile
    echo "# Alias Manager" >> ~/.zprofile
    echo "$ALIAS_LINE" >> ~/.zprofile
    echo "Added alias 'am' to ~/.zprofile"
fi

echo ""
echo "Setup complete!"
echo "Run 'source ~/.zprofile' or restart your terminal to use 'am' command"