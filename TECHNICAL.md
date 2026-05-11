# Technical Notes

Patches and workarounds applied to make Wine + DXMT work on macOS Apple Silicon.

## applied patches

- Wine Staging 11.8 — custom build via MacPorts (Gcenx [macports-wine](https://github.com/Gcenx/macports-wine) fork + additional patches)
  - CrossOver CEF helper injection patch (sourced from [Gcenx/game-porting-toolkit](https://github.com/Gcenx/game-porting-toolkit)): adds `--in-process-gpu`/`--disable-gpu`/`--no-sandbox` to `steamwebhelper.exe` and other Chromium-based helpers so the Steam UI renders under winemac + DXMT (upstream Gcenx tarball does NOT include this).
  - Proton `mfreadwrite/reader.c` fix ([`164af86d`](https://github.com/ValveSoftware/wine/commit/164af86dd770f975cdff3e09884f14ebc14b856b)) — source patch via MacPorts (VGA/BGA video background rendering fix for DJMax/EZ2ON).
  - Gcenx CW-HACK for Rosetta 2 (inherited from the MacPorts Portfile)
- DXMT v0.80 ([3Shain/dxmt](https://github.com/3Shain/dxmt)) — fixes `D3D11_QUERY_DATA_TIMESTAMP_DISJOINT` handling that was breaking UE5.6 Development builds ([PR #138](https://github.com/3Shain/dxmt/pull/138))
  - DXMT MetalViewFrame fix for screen resolution bug [zzzz465/dxmt](https://github.com/zzzz465/dxmt/tree/fix/resizing)
- GLib/GStreamer version conflict change (2.82 -> 2.88) for game stuck at 75% on startup
  - Libraries: `libglib-2.0.0`, `libgobject-2.0.0`, `libgmodule-2.0.0`, `libgio-2.0.0`, `libintl.8`, `libgstvideo-1.0.0`, `libgstaudio-1.0.0`, `libgstbase-1.0.0`, `libgsttag-1.0.0`, `libgstreamer-1.0.0`, `libgstpbutils-1.0.0`

## Environment

| Variable | Value | Purpose |
|----------|-------|---------|
| `WINEESYNC` | `1` | esync for performance |
| `WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER` | `1` | DXMT setting |
| `GST_PLUGIN_PATH` | Wine internal + `/usr/local/lib/gstreamer-1.0` | H.264 decoder |
| `WINEDEBUG` | `-fixme,-err` | suppress noise (overridable) |
| `WINEDLLOVERRIDES` | `winedbg.exe=d` | disable crash dialog |
