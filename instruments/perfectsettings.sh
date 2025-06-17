#!/bin/bash
# @author madebycm (2025-05-22)
# QuickLoad Perfect Settings - Pure bash implementation

KONTAKT_PLIST="$HOME/Library/Preferences/com.native-instruments.Kontakt 8.plist"

echo "🚀 QuickLoad Perfect Settings - Kontakt 8 Optimization"
echo "📁 Target file: $KONTAKT_PLIST"

# Check if plist exists
if [ ! -f "$KONTAKT_PLIST" ]; then
    echo "❌ Kontakt 8 preferences file not found"
    echo "💡 Please run Kontakt 8 at least once to create the preferences file"
    exit 1
fi

echo "🔧 Applying perfect settings..."

# Apply all settings using defaults write
defaults write "com.native-instruments.Kontakt 8" askWhenClosingOrReplacingModifiedInstruments -int 0
defaults write "com.native-instruments.Kontakt 8" "AB2 AudioDevice" -string "CoreAudio Scarlett Solo USB"
defaults write "com.native-instruments.Kontakt 8" uret-allow-transfer -int 0
defaults write "com.native-instruments.Kontakt 8" enableResourceAutoUpdate -int 0
defaults write "com.native-instruments.Kontakt 8" showNewInstrumentsForYou -int 0
defaults write "com.native-instruments.Kontakt 8" cxBrowserBannerInstrument -int 0
defaults write "com.native-instruments.Kontakt 8" quickloadVisible -int 1
defaults write "com.native-instruments.Kontakt 8" defaultView -int 0
defaults write "com.native-instruments.Kontakt 8" overrideInstPreloadSize -int 98304
defaults write "com.native-instruments.Kontakt 8" browserAuto_widthGroup -int 178
defaults write "com.native-instruments.Kontakt 8" widthFBColumn3 -int 117

echo "✅ Perfect settings applied successfully!"
echo "💡 Restart Kontakt 8 for changes to take effect"
echo "🏁 Perfect Settings process completed!"