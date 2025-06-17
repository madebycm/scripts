# QuickLoad Instruments

A Python tool for organizing Native Instruments Kontakt patches (.nki files) and snapshots (.nksn files) into a clean, symlinked folder structure.

## Overview

QuickLoad Instruments scans specified directories for Kontakt instrument files and creates an organized folder structure at `/opt/instruments` using symbolic links. It intelligently groups files by brand and library, with special handling for single-instrument libraries.

## Features

- **Intelligent Organization**: Groups instruments by brand/library hierarchy
- **Smart Flattening**: Single-instrument libraries are flattened to brand level for easier access
- **Snapshot Support**: Organizes .nksn snapshot files in dedicated `!!Snapshots` folders
- **Duplicate Handling**: Automatically handles duplicate filenames by appending counters
- **Perfect Settings**: Optionally applies optimized Kontakt 8 settings via `perfectsettings.sh`
- **Non-destructive**: Uses symlinks instead of copying files, preserving disk space

## Files

- `instruments` - Main Python script that creates the organized structure
- `config.py` - Configuration file containing search paths and settings
- `perfectsettings.sh` - Bash script for applying optimal Kontakt 8 settings

## Configuration

Edit `config.py` to customize:
- `SEARCH_PATHS`: Directories to scan for Kontakt files
- File extensions (.nki, .nkm, .nksn, .nicnt)
- Output directories

## Usage

```bash
./instruments
```

The script will:
1. Clear any existing `/opt/instruments` directory
2. Scan configured paths for .nki and .nksn files
3. Create organized symlink structure
4. Apply Kontakt perfect settings (if available)

## Requirements

- Python 3
- macOS (for perfectsettings.sh)
- Native Instruments Kontakt 8 (for settings optimization)

## Author

@author madebycm (2025)