# Technical Notes

Patches and workarounds applied to make Wine + DXMT work on macOS Apple Silicon.

## applied patches

- Wine Staging 11.6_1 ([Gcenx/macOS_Wine_builds](https://github.com/Gcenx/macOS_Wine_builds))
  - Gcenx CW-HACK for rosetta 2 [Gcenx/macports-wine](https://github.com/Gcenx/macports-wine)
  - `mfreadwrite.dll` fix for VGA black [`164af86d`](https://github.com/ValveSoftware/wine/commit/164af86dd770f975cdff3e09884f14ebc14b856b) 
- DXMT v0.74 ([3Shain/dxmt](https://github.com/3Shain/dxmt))
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
