cask "wine-dxmt-steam" do
  version "11.4.4"
  sha256 "af78f79fafe16b9d681ddc7beb6e869126e99486e319e45576fea65a0cb1e0d0"

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
