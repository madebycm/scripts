# permsync

A tool to synchronize Claude permissions across projects while maintaining a global allowlist and blacklist.

## Overview

`permsync` helps manage Claude's bash command permissions by:
- Syncing permissions between local `.claude/settings.local.json` files and a global `allowed.json`
- Maintaining a blacklist to prevent certain dangerous commands from being added to the global allowlist
- Ensuring permissions are always synchronized (union of both sets)

## Installation

Run the script for the first time and it will prompt to install itself:

```bash
./permsync.sh
```

Or install manually:

```bash
./permsync.sh install
```

This creates a wrapper script in `~/.local/bin/permsync` that can be run from anywhere.

Protip: alias `claude` to `permsync && claude` 🔥

## Usage

Navigate to any directory containing a `.claude/settings.local.json` file and run:

```bash
permsync
```

The script will:
1. Find the nearest `.claude/settings.local.json` file (searching up the directory tree)
2. Read permissions from both the local settings and global `allowed.json`
3. Merge all permissions (union)
4. Filter out any blacklisted permissions from `allowed.json`
5. Update both files with the synchronized permissions

## File Formats

All files use the same JSON structure:

### allowed.json
```json
{
  "permissions": {
    "allow": [
      "Bash(ls:*)",
      "Bash(npm:*)",
      "Bash(rg:*)"
    ],
    "deny": []
  }
}
```

### blacklist.json
```json
{
  "permissions": {
    "blacklist": [
      "Bash(rm:*)",
      "Bash(npm:*)",
      "*npx*",
      "*dangerous*"
    ]
  }
}
```

The blacklist supports wildcard patterns using `*` to match any characters. For example:
- `Bash(rm:*)` - matches any rm command
- `*npx*` - matches any permission containing "npx" (e.g., `Bash(npx prettier:*)`)
- `*dangerous*` - matches any permission containing "dangerous"

### settings.local.json
```json
{
  "permissions": {
    "allow": [
      "Bash(docker:*)",
      "Bash(npm:*)"
    ],
    "deny": []
  }
}
```

## How It Works

1. **Union Operation**: Permissions from both local and global files are merged
2. **Blacklist Filtering**: Blacklisted commands are removed from `allowed.json` only
3. **Preservation**: Local settings can still contain blacklisted commands
4. **Idempotent**: Running multiple times produces the same result
5. **Sync Reporting**: Shows new commands added from local projects to the global allowed list

## Commands

- `permsync` - Run synchronization
- `permsync install` - Install the tool
- `permsync uninstall` - Remove the tool
- `permsync manage` - Interactive manager for permissions (add, edit, delete, blacklist)

## Interactive Manager

The `permsync manage` command launches an interactive Python CLI for managing permissions:

### Features
- **Arrow key navigation** - Navigate through rules with ↑/↓ keys
- **Mode switching** - Switch between Allowed and Blacklist views with TAB
- **Add rules** - Press 'a' to add new permissions
- **Edit rules** - Press 'e' to modify existing permissions
- **Delete rules** - Press 'd' to remove permissions (with confirmation)
- **Toggle blacklist** - Press 'b' to move items between allowed and blacklist
- **Real-time updates** - Changes are immediately saved to JSON files

### Key Bindings
- `↑/↓` - Navigate through list
- `TAB` - Switch between Allowed/Blacklist modes
- `a` - Add new rule
- `e` - Edit selected rule
- `d` - Delete selected rule
- `b` - Toggle blacklist status (move between lists)
- `q` - Quit
- `Enter` - Save changes (when editing/adding)
- `Escape` - Cancel (when editing/adding)

## Files

The script maintains four files in its installation directory:
- `allowed.json` - Global allowlist of permissions
- `blacklist.json` - Commands that should never be in the global allowlist
- `permsync.sh` - The main script
- `manage.py` - Interactive manager script

## Example

Starting state:
- Local: `Bash(rm:*)`, `Bash(ls:*)`
- Allowed: `Bash(npm:*)`, `Bash(rg:*)`
- Blacklist: `Bash(rm:*)`

After running `permsync`:
- Local: `Bash(rm:*)`, `Bash(ls:*)`, `Bash(npm:*)`, `Bash(rg:*)`
- Allowed: `Bash(ls:*)`, `Bash(npm:*)`, `Bash(rg:*)` (rm is blacklisted)

## Security

The blacklist prevents dangerous commands from being added to the global allowlist, providing an extra layer of safety when synchronizing permissions across multiple projects.
