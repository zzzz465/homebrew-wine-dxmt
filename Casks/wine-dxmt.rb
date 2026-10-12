cask "wine-dxmt" do
  version "11.8_mm1"
  sha256 "236e517c12b8adf2092607742c4337632f7b03ffc06e4341bc5fc0a8f0160a9f"

  url "https://github.com/zzzz465/homebrew-wine-dxmt/releases/download/v#{version}/wine-staging-#{version}-osx64.tar.xz"
  name "Wine DXMT"
  desc "Wine Staging (macports custom) + DXMT for macOS gaming (DX11-to-Metal, UE5.6 patched)"
  homepage "https://github.com/zzzz465/homebrew-wine-dxmt"

  depends_on macos: ">= :ventura"

  preflight do
    # --- Ensure Xcode CLI Tools are installed (needed for codesign) ---
    unless system_command("/usr/bin/xcode-select", args: ["-p"], print_stderr: false, must_succeed: false).exit_status.zero?
      ohai "Installing Xcode Command Line Tools..."
      system_command "/usr/bin/xcode-select", args: ["--install"]
      ohai "Please complete the Xcode CLI Tools installation, then re-run: brew install --cask wine-dxmt"
      raise "Xcode Command Line Tools required. Please install and retry."
    end

    # --- Ensure Rosetta 2 is installed (needed for x86_64 Wine) ---
    unless system_command("/usr/bin/arch", args: ["-x86_64", "/usr/bin/true"], print_stderr: false, must_succeed: false).exit_status.zero?
      ohai "Installing Rosetta 2..."
      system_command "/usr/sbin/softwareupdate", args: ["--install-rosetta", "--agree-to-license"]
    end
  end

  postflight do
    wine_dir = "#{ENV["HOME"]}/Wine/dxmt"
    config_dir = "#{ENV["HOME"]}/.config/wine-dxmt"
    tap_dir = File.expand_path("..", __dir__)

    # --- 1. Wine Staging 11.8 custom build (macports + CW-HACK + DXMT adapter +
    #        winemac resize fix). Built from zzzz465/macports-wine fork; tarball
    #        layout matches Gcenx's Wine Staging.app/Contents/Resources/wine/. ---
    unless File.exist?("#{wine_dir}/bin/wine")
      ohai "Installing Wine Staging 11.8_mm1..."
      system "/bin/mkdir", "-p", wine_dir
      system "/bin/cp", "-R",
        "#{staged_path}/Wine Staging.app/Contents/Resources/wine/",
        "#{wine_dir}/"
    end

    # --- 2. DXMT v0.80 prebuilt overlay (NVIDIA stubs + 32-bit DXMT only) ---
    # Our v0.80 build (step 3) overwrites all 64-bit DXMT files. This step
    # contributes i386-windows/* (32-bit DXMT) and x86_64-windows/nv{api64,ngx}.dll
    # (NVIDIA stubs).
    ohai "Downloading DXMT v0.80 prebuilt..."
    system "/usr/bin/curl", "-sLo", "/tmp/dxmt-v0.80-builtin.tar.gz",
      "https://github.com/3Shain/dxmt/releases/download/v0.80/dxmt-v0.80-builtin.tar.gz"
    system "/usr/bin/tar", "-xzf", "/tmp/dxmt-v0.80-builtin.tar.gz", "-C", "/tmp"
    %w[x86_64-unix x86_64-windows i386-windows].each do |arch|
      Dir.glob("/tmp/v0.80/#{arch}/*").each do |f|
        system "/bin/cp", "-f", f, "#{wine_dir}/lib/wine/#{arch}/"
      end
    end
    system "/bin/rm", "-rf", "/tmp/v0.80", "/tmp/dxmt-v0.80-builtin.tar.gz"

    # --- 3. DXMT v0.80 patched binaries (calibration + frame sync fix for UE5.6) ---
    # See patches/dxmt-v0.80-patches/ in tap.
    # Patches applied to DXMT v0.80 source:
    #   - src/d3d11/d3d11_query.cpp: latest_value_=1 (calibration assert fix)
    #   - src/d3d11/d3d11_query.cpp: stale fallback returns S_OK
    #   - src/d3d11/d3d11_context_imm.cpp: TIMESTAMP_DISJOINT hr=S_OK
    #   - src/d3d11/d3d11_query.hpp: Undefined→Signaled
    #   - src/winemetal/unix/winemetal_unix.c: frame sync fix in _MetalLayer_setProps
    ohai "Applying DXMT v0.80 UE5.6-patched binaries..."
    dxmt_patches_dir = "#{tap_dir}/patches/dxmt-v0.80-patches"
    %w[x86_64-unix x86_64-windows].each do |arch|
      Dir.glob("#{dxmt_patches_dir}/#{arch}/*").each do |f|
        system "/bin/cp", "-f", f, "#{wine_dir}/lib/wine/#{arch}/"
      end
    end

    # --- 4. Bundle x86_64 GStreamer from the official universal framework pkg ---
    # Homebrew no longer installs on Intel macOS nor builds Intel bottles, so
    # the x86_64 brew GStreamer is gone. The pkg is expanded (not installed) into
    # wine_dir/gstreamer; its dylibs are @rpath-relocatable, so no sudo and no
    # /Library/Frameworks. Components cover winegstreamer's elements (decodebin,
    # videoconvert, audioconvert, audioresample, deinterlace, videoflip) plus
    # H.264 (vtdec, avdec_h264) and VP9 (vp9dec) decoders.
    gst_version = "1.28.8"
    gst_pkg_sha256 = "d371ab04a7632713626836c2fc234e863cc98484c74c473eba99b0fbd9b3a3fe"
    gst_components = %w[
      base-system-1.0 base-crypto gstreamer-1.0-core gstreamer-1.0-playback
      gstreamer-1.0-effects gstreamer-1.0-codecs gstreamer-1.0-libav gstreamer-1.0-system
    ]
    gst_dir = "#{wine_dir}/gstreamer"
    unless File.exist?("#{gst_dir}/lib/libgstreamer-1.0.0.dylib")
      ohai "Bundling GStreamer #{gst_version} into #{gst_dir}..."
      Dir.mktmpdir do |tmp|
        pkg = "#{tmp}/gstreamer.pkg"
        system "/usr/bin/curl", "-fsSLo", pkg,
               "https://gstreamer.freedesktop.org/data/pkg/osx/#{gst_version}/gstreamer-1.0-#{gst_version}-universal.pkg",
               exception: true
        actual_sha256 = Pathname(pkg).sha256
        raise "GStreamer pkg checksum mismatch: #{actual_sha256}" if actual_sha256 != gst_pkg_sha256

        system "/usr/sbin/pkgutil", "--expand-full", pkg, "#{tmp}/expanded", exception: true
        system "/bin/mkdir", "-p", gst_dir, exception: true
        gst_components.each do |component|
          payload = "#{tmp}/expanded/#{component}-#{gst_version}-universal.pkg/Payload/."
          system "/bin/cp", "-R", payload, gst_dir, exception: true
        end
      end
    end

    # --- 5. Symlink GLib/GStreamer dylibs to the bundled GStreamer ---
    # winegstreamer.so resolves these via @rpath (LC_RPATH = @loader_path/ +
    # @loader_path/../..), so both lib/ and lib/wine/x86_64-unix/ must point
    # to the bundle. Deleting them breaks H.264/VP9 decoding (DJMax BGA video, etc).
    # The tarball's versions are older and conflict with the plugins (decodebin
    # creation fail, GstCocoaApplicationDelegate duplicate), so the whole
    # dependency closure (incl. ffi, orc, pcre2, z) comes from the bundle.
    gst_libs = %w[
      libgstvideo-1.0.0.dylib libgstaudio-1.0.0.dylib libgstbase-1.0.0.dylib
      libgsttag-1.0.0.dylib libgstreamer-1.0.0.dylib libgstpbutils-1.0.0.dylib
      libgobject-2.0.0.dylib libglib-2.0.0.dylib libgmodule-2.0.0.dylib
      libgio-2.0.0.dylib libintl.8.dylib libffi.7.dylib liborc-0.4.0.dylib
      libpcre2-8.0.dylib libz.1.dylib
    ]
    ["#{wine_dir}/lib", "#{wine_dir}/lib/wine/x86_64-unix"].each do |dir|
      gst_libs.each do |lib|
        target = "#{dir}/#{lib}"
        File.delete(target) if File.exist?(target) || File.symlink?(target)
        system "/bin/ln", "-sf", "#{gst_dir}/lib/#{lib}", target
      end
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
      # msync (Mach semaphore sync) — macOS-native, avoids esync audio thread
      # starvation that caused XAudio2 buffer underruns in UE5 games.
      export WINEESYNC=0
      export WINEMSYNC=1
      export WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER=1
      # Use only the bundled GStreamer plugins, with a registry separate from
      # any other GStreamer install on this Mac.
      unset GST_PLUGIN_PATH GST_PLUGIN_PATH_1_0
      export GST_PLUGIN_SYSTEM_PATH_1_0="$WINE_DXMT_DIR/gstreamer/lib/gstreamer-1.0"
      export GST_PLUGIN_SCANNER_1_0="$WINE_DXMT_DIR/gstreamer/libexec/gstreamer-1.0/gst-plugin-scanner"
      export GST_REGISTRY_1_0="$CONFIG_DIR/gstreamer-registry.x86_64.bin"

      exec "$WINE_DXMT_DIR/bin/wine" "$@"
    SCRIPT
    system "/bin/chmod", "+x", wrapper

    # --- 8. Symlink to PATH ---
    # /usr/local/bin is only user-writable when something (formerly x86_64
    # Homebrew) has taken ownership of it, so also link into Homebrew's bin.
    system "/bin/ln", "-sf", wrapper, "#{HOMEBREW_PREFIX}/bin/wine-dxmt"
    system "/bin/mkdir", "-p", "/usr/local/bin"
    system "/bin/ln", "-sf", wrapper, "/usr/local/bin/wine-dxmt"
  end

  uninstall delete: [
    "#{HOMEBREW_PREFIX}/bin/wine-dxmt",
    "/usr/local/bin/wine-dxmt",
    "#{ENV["HOME"]}/Wine/dxmt",
    "#{ENV["HOME"]}/.config/wine-dxmt",
  ]

  caveats <<~EOS
    Wine DXMT installed to ~/Wine/dxmt/

    With existing prefix:
      wine-dxmt --set-prefix /path/to/your/prefix
      wine-dxmt your_game.exe
  EOS
end
