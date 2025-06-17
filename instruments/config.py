#!/usr/bin/env python3
# @author madebycm (2025-05-21)

"""
Configuration file for QuickLoad
Contains paths to search for Native Instruments patches
"""

import os

# Paths to search for Native Instruments patches
SEARCH_PATHS = [
#    "/Volumes/FIRESPITTER/_ARCHIVE_FS/",
#    "/Volumes/ZIMMER/_ARCHIVE_Z/",
    "/Volumes/ZIMMER/_INST_Z/",
"/Volumes/FIRESPITTER/_INST_FS/"
]

# File extensions to look for
NKI_EXTENSION = ".nki"  # Instrument files
NKM_EXTENSION = ".nkm"  # Multi files
NKSN_EXTENSION = ".nksn"  # Snapshot files
NICNT_EXTENSION = ".nicnt"  # Native Instruments content files

# Output directories
QUICKLOAD_DIR = "./QuickLoad"
INSTR_DIR = f"{QUICKLOAD_DIR}/Instr"
MULTI_DIR = f"{QUICKLOAD_DIR}/Multi"

# Kontakt 8 QuickLoad installation directory
KONTAKT_QUICKLOAD_DIR = os.path.expanduser("~/Library/Application Support/Native Instruments/Kontakt 8/QuickLoad")
KONTAKT_INSTR_DIR = f"{KONTAKT_QUICKLOAD_DIR}/Instr"
KONTAKT_MULTI_DIR = f"{KONTAKT_QUICKLOAD_DIR}/Multi"

# MasterBank directory for consolidated libraries
KONTAKT_MASTERBANK_DIR = f"{KONTAKT_QUICKLOAD_DIR}/MasterBank"

# Kontakt User Content directory for snapshots
KONTAKT_USER_CONTENT_DIR = os.path.expanduser("~/Documents/Native Instruments/User Content/Kontakt")
USER_CONTENT_DIR = os.path.expanduser("~/Documents/Native Instruments/User Content")
QTOOL_MARKER_FILE = "installed_by_qtool.txt"
