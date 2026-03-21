cask "wine-dxmt" do
  version "11.4.4"
  sha256 "af78f79fafe16b9d681ddc7beb6e869126e99486e319e45576fea65a0cb1e0d0"

  url "https://github.com/zzzz465/homebrew-wine-dxmt/releases/download/v#{version}/wine-dxmt-patches-#{version}.tar.xz"
  name "Wine DXMT"
  desc "Patched Wine Staging + DXMT for macOS gaming (DX11-to-Metal)"
  homepage "https://github.com/zzzz465/homebrew-wine-dxmt"

  depends_on macos: ">= :ventura"

  preflight do
    # --- Ensure Xcode CLI Tools are installed (needed for codesign) ---
    unless system_command("/usr/bin/xcode-select", args: ["-p"], print_stderr: false).exit_status.zero?
      ohai "Installing Xcode Command Line Tools..."
      system_command "/usr/bin/xcode-select", args: ["--install"]
      ohai "Please complete the Xcode CLI Tools installation, then re-run: brew install --cask wine-dxmt"
      raise "Xcode Command Line Tools required. Please install and retry."
    end

    # --- Ensure Rosetta 2 is installed (needed for x86_64 Wine) ---
    unless system_command("/usr/bin/arch", args: ["-x86_64", "/usr/bin/true"], print_stderr: false).exit_status.zero?
      ohai "Installing Rosetta 2..."
      system_command "/usr/sbin/softwareupdate", args: ["--install-rosetta", "--agree-to-license"]
    end

  end

  postflight do
    wine_dir = "#{ENV["HOME"]}/Wine/dxmt"
    config_dir = "#{ENV["HOME"]}/.config/wine-dxmt"

    # --- 1. Wine Staging 11.4 from Gcenx ---
    unless File.exist?("#{wine_dir}/bin/wine")
      ohai "Downloading Wine Staging 11.4..."
      system "/usr/bin/curl", "-sLo", "/tmp/wine-staging-11.4.tar.xz",
        "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.4/wine-staging-11.4-osx64.tar.xz"
      system "/usr/bin/tar", "-xJf", "/tmp/wine-staging-11.4.tar.xz", "-C", "/tmp"
      system "/bin/mkdir", "-p", wine_dir
      system "/bin/cp", "-R", "/tmp/Wine Staging.app/Contents/Resources/wine/", "#{wine_dir}/"
      system "/bin/rm", "-rf", "/tmp/Wine Staging.app", "/tmp/wine-staging-11.4.tar.xz"
    end

    # --- 2. DXMT v0.74 overlay ---
    ohai "Downloading DXMT v0.74..."
    system "/usr/bin/curl", "-sLo", "/tmp/dxmt-v0.74-builtin.tar.gz",
      "https://github.com/3Shain/dxmt/releases/download/v0.74/dxmt-v0.74-builtin.tar.gz"
    system "/usr/bin/tar", "-xzf", "/tmp/dxmt-v0.74-builtin.tar.gz", "-C", "/tmp"
    %w[x86_64-unix x86_64-windows i386-windows].each do |arch|
      Dir.glob("/tmp/v0.74/#{arch}/*").each do |f|
        system "/bin/cp", "-f", f, "#{wine_dir}/lib/wine/#{arch}/"
      end
    end
    system "/bin/rm", "-rf", "/tmp/v0.74", "/tmp/dxmt-v0.74-builtin.tar.gz"

    # --- 3. Our patches overlay (applied AFTER DXMT) ---
    ohai "Applying patches..."
    %w[x86_64-unix x86_64-windows].each do |arch|
      Dir.glob("#{staged_path}/#{arch}/*").each do |f|
        system "/bin/cp", "-f", f, "#{wine_dir}/lib/wine/#{arch}/"
      end
    end

    # --- 4. Symlink GLib/GStreamer libs to system x86_64 versions ---
    # Wine bundles outdated GLib that conflicts with system GStreamer.
    # Deleting alone breaks @rpath resolution; symlink to system libs instead.
    unix_dir = "#{wine_dir}/lib/wine/x86_64-unix"
    %w[
      libglib-2.0.0.dylib libgobject-2.0.0.dylib libgmodule-2.0.0.dylib
      libgio-2.0.0.dylib libintl.8.dylib
      libgstvideo-1.0.0.dylib libgstaudio-1.0.0.dylib libgstbase-1.0.0.dylib
      libgsttag-1.0.0.dylib libgstreamer-1.0.0.dylib libgstpbutils-1.0.0.dylib
    ].each do |lib|
      target = "#{unix_dir}/#{lib}"
      system_lib = "/usr/local/lib/#{lib}"
      File.delete(target) if File.exist?(target) || File.symlink?(target)
      system "/bin/ln", "-sf", system_lib, target if File.exist?(system_lib)
    end

    # --- 5. x86_64 Homebrew + GStreamer ---
    unless File.exist?("/usr/local/bin/brew")
      ohai "Installing x86_64 Homebrew (required for GStreamer)..."
      system "/usr/bin/arch", "-x86_64", "/bin/bash", "-c",
        '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    end
    unless File.exist?("/usr/local/lib/gstreamer-1.0")
      ohai "Installing x86_64 GStreamer..."
      system "arch", "-x86_64", "/usr/local/bin/brew", "install", "gstreamer"
    end

    # --- 6. Quarantine removal + ad-hoc codesign ---
    system "/usr/bin/xattr", "-drs", "com.apple.quarantine", wine_dir
    system "/usr/bin/codesign", "--force", "--deep", "-s", "-", "#{wine_dir}/bin/wine"

    # --- 7. Create wine-dxmt wrapper ---
    system "/bin/mkdir", "-p", config_dir
    wrapper = "#{wine_dir}/bin/wine-dxmt"
    File.write(wrapper, <<~SCRIPT)
      #!/bin/bash
      WINE_DXMT_DIR="#{wine_dir}"
      CONFIG_DIR="#{config_dir}"

      if [[ "$1" == "--set-prefix" ]]; then
        echo "$2" > "$CONFIG_DIR/prefix"
        echo "Prefix set to: $2"
        exit 0
      fi

      # Resolve prefix: arg > env > config > default
      if [[ -n "$WINEPREFIX" ]]; then
        PREFIX="$WINEPREFIX"
      elif [[ -f "$CONFIG_DIR/prefix" ]]; then
        PREFIX="$(cat "$CONFIG_DIR/prefix")"
      else
        PREFIX="$HOME/Bottles/DXMT"
      fi

      export WINEPREFIX="$PREFIX"
      export WINEESYNC=1
      export WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER=1
      export GST_PLUGIN_PATH="$WINE_DXMT_DIR/lib/wine/x86_64-unix/gstreamer-1.0:/usr/local/lib/gstreamer-1.0"
      export WINEDEBUG="${WINEDEBUG:--fixme,-err}"
      export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}winedbg.exe=d"

      exec "$WINE_DXMT_DIR/bin/wine" "$@"
    SCRIPT
    system "/bin/chmod", "+x", wrapper

    # --- 8. Symlink to PATH ---
    system "/bin/mkdir", "-p", "/usr/local/bin"
    system "/bin/ln", "-sf", wrapper, "/usr/local/bin/wine-dxmt"
  end

  uninstall delete: [
    "/usr/local/bin/wine-dxmt",
    "#{ENV["HOME"]}/Wine/dxmt",
    "#{ENV["HOME"]}/.config/wine-dxmt",
  ]

  caveats <<~EOS
    Wine DXMT installed to ~/Wine/dxmt/

    With existing Steam prefix:
      wine-dxmt --set-prefix /path/to/your/prefix
      wine-dxmt steam.exe -applaunch 960170

    New prefix setup:
      brew install --cask wine-dxmt-steam
  EOS
end
