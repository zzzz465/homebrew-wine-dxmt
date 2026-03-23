cask "wine-dxmt-steam" do
  version "11.5.1"
  sha256 "12e351336db4ab6eae560c1ba5d37f76b91be9ae32799d221345620c66124557"

  url "https://github.com/zzzz465/homebrew-wine-dxmt/releases/download/v#{version}/wine-dxmt-patches-#{version}.tar.xz"
  name "Wine DXMT with Steam"
  desc "Patched Wine Staging + DXMT + Steam prefix setup for macOS gaming"
  homepage "https://github.com/zzzz465/homebrew-wine-dxmt"

  depends_on cask: "wine-dxmt"
  depends_on macos: ">= :ventura"

  postflight do
    wine_dir = "#{ENV["HOME"]}/Wine/dxmt"
    config_dir = "#{ENV["HOME"]}/.config/wine-dxmt"
    wine_dxmt = "#{wine_dir}/bin/wine-dxmt"

    # Use existing prefix from env, or default
    prefix = ENV["WINE_DXMT_PREFIX"] || "#{ENV["HOME"]}/Bottles/DXMT"
    existing = ENV["WINE_DXMT_PREFIX"] && File.exist?("#{prefix}/system.reg")

    if existing
      ohai "Using existing prefix: #{prefix}"
    else
      # --- 1. Create Wine prefix ---
      unless File.exist?("#{prefix}/system.reg")
        ohai "Creating Wine prefix at #{prefix}..."
        system "/bin/mkdir", "-p", prefix
        system "WINEPREFIX=#{prefix} #{wine_dxmt} wineboot --init 2>/dev/null"
      end
    end

    # --- 2. Set default prefix in config ---
    system "/bin/mkdir", "-p", config_dir
    File.write("#{config_dir}/prefix", prefix)

    # --- 3. Install Steam in background (skip if existing prefix with Steam) ---
    steam_exe = "#{prefix}/drive_c/Program Files (x86)/Steam/steam.exe"
    unless File.exist?(steam_exe)
      ohai "Starting Steam installation in background..."
      ohai "Progress: tail -f #{config_dir}/steam-install.log"
      system "/bin/bash", "-c", <<~BG
        (
          LOCK="#{config_dir}/steam-installing.lock"
          LOG="#{config_dir}/steam-install.log"
          touch "$LOCK"
          echo "[$(date)] Starting Steam installation..." > "$LOG"
          echo "[$(date)] Downloading SteamSetup.exe..." >> "$LOG"
          /usr/bin/curl -sLo /tmp/SteamSetup.exe https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe 2>> "$LOG"
          echo "[$(date)] Running SteamSetup.exe..." >> "$LOG"
          WINEPREFIX="#{prefix}" "#{wine_dxmt}" /tmp/SteamSetup.exe /S >> "$LOG" 2>&1
          /bin/rm -f /tmp/SteamSetup.exe
          WINEPREFIX="#{prefix}" "#{wine_dir}/bin/wineserver" -k 2>/dev/null
          echo "[$(date)] Steam installation complete." >> "$LOG"
          rm -f "$LOCK"
        ) &
      BG
    else
      ohai "Steam already installed in prefix, skipping."
    end

    # --- 4. Create wine-dxmt-steam launcher ---
    launcher = "#{wine_dir}/bin/wine-dxmt-steam"
    File.write(launcher, <<~'SCRIPT')
#!/bin/bash
CONFIG_DIR="$HOME/.config/wine-dxmt"

if [[ "$1" == "--set-prefix" ]]; then
  echo "$2" > "$CONFIG_DIR/prefix"
  echo "Prefix set to: $2"
  exit 0
fi

if [[ "$1" == "add-game" ]]; then
  APPID="$2"
  if [[ -z "$APPID" ]]; then
    echo "Usage: wine-dxmt-steam add-game <appid> [display-name]"
    echo "Example: wine-dxmt-steam add-game 960170 DJMax"
    exit 1
  fi
  DISPLAY_NAME="${3:-Game $APPID}"
  SAFE_NAME=$(echo "$DISPLAY_NAME" | sed 's/[^a-zA-Z0-9]//g')
  APP_DIR="$HOME/Applications/${DISPLAY_NAME}.app"

  # Fetch game name from Steam API if no display name given
  if [[ -z "$3" ]]; then
    API_NAME=$(curl -s "https://store.steampowered.com/api/appdetails?appids=${APPID}" \
      | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ -n "$API_NAME" ]]; then
      DISPLAY_NAME="$API_NAME"
      SAFE_NAME=$(echo "$DISPLAY_NAME" | sed 's/[^a-zA-Z0-9]//g')
      APP_DIR="$HOME/Applications/${DISPLAY_NAME}.app"
    fi
  fi

  echo "Creating app for: $DISPLAY_NAME (AppID: $APPID)"

  # Download icon
  ICON_URL="https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/${APPID}/header.jpg"
  ICON_TMP="/tmp/wine-dxmt-icon-${APPID}"
  mkdir -p "${ICON_TMP}.iconset"
  curl -sL "$ICON_URL" -o "${ICON_TMP}.jpg"

  if [[ ! -s "${ICON_TMP}.jpg" ]]; then
    echo "Warning: Could not download icon."
  else
    for size in 512 256 128 64 32 16; do
      sips -s format png -z $size $size "${ICON_TMP}.jpg" \
        --out "${ICON_TMP}.iconset/icon_${size}x${size}.png" >/dev/null 2>&1
    done
    iconutil -c icns "${ICON_TMP}.iconset" -o "${ICON_TMP}.icns" 2>/dev/null
  fi

  # Create .app bundle
  mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
  cat > "$APP_DIR/Contents/MacOS/launch" << LAUNCH
#!/bin/bash
exec /usr/local/bin/wine-dxmt-steam -applaunch $APPID
LAUNCH
  chmod +x "$APP_DIR/Contents/MacOS/launch"

  cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>launch</string>
    <key>CFBundleIdentifier</key>
    <string>com.wine-dxmt.game.${APPID}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
</dict>
</plist>
PLIST

  if [[ -f "${ICON_TMP}.icns" ]]; then
    cp "${ICON_TMP}.icns" "$APP_DIR/Contents/Resources/icon.icns"
  fi
  rm -rf "${ICON_TMP}.jpg" "${ICON_TMP}.iconset" "${ICON_TMP}.icns"

  echo "Created: $APP_DIR"
  echo "You can find it in ~/Applications or search Spotlight."
  exit 0
fi

# Resolve prefix: env > config > default
if [[ -n "$WINEPREFIX" ]]; then
  PREFIX="$WINEPREFIX"
elif [[ -f "$CONFIG_DIR/prefix" ]]; then
  PREFIX="$(cat "$CONFIG_DIR/prefix")"
else
  PREFIX="$HOME/Bottles/DXMT"
fi

WINE_DXMT_DIR="$HOME/Wine/dxmt"
LOCK="$CONFIG_DIR/steam-installing.lock"
STEAM="$PREFIX/drive_c/Program Files (x86)/Steam/steam.exe"

# Kill stale wineserver if running
if WINEPREFIX="$PREFIX" "$WINE_DXMT_DIR/bin/wineserver" -k 0 2>/dev/null; then
  echo "Stopped stale wineserver."
fi

# Wait if background installation is in progress
if [[ -f "$LOCK" ]]; then
  echo "Steam is being installed in the background. Waiting..."
  echo "  (see: tail -f $CONFIG_DIR/steam-install.log)"
  while [[ -f "$LOCK" ]]; do sleep 2; done
  echo "Background installation finished."
fi

if [[ ! -f "$STEAM" ]]; then
  echo "Steam not found. Installing..."
  curl -sLo /tmp/SteamSetup.exe https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
  WINEPREFIX="$PREFIX" wine-dxmt /tmp/SteamSetup.exe /S
  rm -f /tmp/SteamSetup.exe
  # Kill wineserver left by installer
  WINEPREFIX="$PREFIX" "$WINE_DXMT_DIR/bin/wineserver" -k 2>/dev/null
fi

echo "Launching Steam..."
wine-dxmt "$STEAM" "$@" >/dev/null 2>&1 &
disown
echo "Steam launched in background (PID $!)."
SCRIPT
    system "/bin/chmod", "+x", launcher
    system "/bin/mkdir", "-p", "/usr/local/bin"
    system "/bin/ln", "-sf", launcher, "/usr/local/bin/wine-dxmt-steam"
  end

  uninstall delete: [
    "/usr/local/bin/wine-dxmt-steam",
    "#{ENV["HOME"]}/Wine/dxmt/bin/wine-dxmt-steam",
  ]

  caveats <<~EOS
    Steam prefix: #{ENV["WINE_DXMT_PREFIX"] || "~/Bottles/DXMT/"}

    Launch Steam:
      wine-dxmt-steam

    Launch DJMax directly:
      wine-dxmt-steam -applaunch 960170

    Use existing prefix:
      WINE_DXMT_PREFIX=/path/to/prefix brew install --cask wine-dxmt-steam
      wine-dxmt-steam --set-prefix /path/to/prefix
  EOS
end
