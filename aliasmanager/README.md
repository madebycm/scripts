# Alias Manager
# @author madebycm (2025-01-23)

A simple macOS GUI application for managing shell aliases in ~/.zprofile.

## Features

- View all aliases from ~/.zprofile
- Add, edit, and delete aliases
- Search/filter aliases
- Backup and restore ~/.zprofile
- Simple GUI interface

## Installation

1. Run the setup script:
   ```bash
   ./setup.sh
   ```

2. Reload your shell configuration:
   ```bash
   source ~/.zprofile
   ```

## Usage

Simply type `am` in your terminal to launch the Alias Manager GUI.

### Main Features:

- **Search**: Filter aliases by name or command
- **Add/Update**: Enter alias name and command, then click "Add/Update"
- **Delete**: Select an alias and click "Delete"
- **Backup**: File → Backup .zprofile (creates timestamped backup)
- **Restore**: File → Restore from backup
- **Save**: File → Save (or Cmd+S) to save changes to ~/.zprofile

### Notes

- Changes are not automatically saved - use File → Save to persist changes
- Backups are created with timestamp: ~/.zprofile.backup_YYYYMMDD_HHMMSS
- The app preserves non-alias content in your .zprofile file