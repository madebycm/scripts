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

## Commands

- `permsync` - Run synchronization
- `permsync install` - Install the tool
- `permsync uninstall` - Remove the tool
- `permsync blacklist` - Open blacklist.json in your editor
- `permsync allowed` - Open allowed.json in your editor

## Files

The script maintains three files in its installation directory:
- `allowed.json` - Global allowlist of permissions
- `blacklist.json` - Commands that should never be in the global allowlist
- `permsync.sh` - The main script

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