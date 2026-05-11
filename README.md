# homebrew-wine-dxmt

[한국어 가이드](README.kor.md)

Prepackaged Wine + DXMT + Steam setup for macOS (Apple Silicon).

Bundles patched binaries and automated installation so games like DJMax and EZ2ON work out of the box.

For technical details on patches applied, see [TECHNICAL.md](./TECHNICAL.md).

## What's included

- Wine Staging 11.8 (custom MacPorts build) + CrossOver CEF injection patch (Steam UI fix)
- Gcenx CW-HACK for Rosetta 2 compatibility
- Proton mfreadwrite patch (VGA/BGA video background rendering fix)
- DXMT v0.74 (DirectX 11-to-Metal translation)
- DXMT Metal view frame sync patch (in-game resolution change fix)
- GLib/GStreamer system library symlinks (75% loading freeze fix)

## Install

```bash
# install everything including Steam (recommended)
brew tap zzzz465/homebrew-wine-dxmt
brew install --cask wine-dxmt-steam

# if Steam is already installed in an existing prefix
brew tap zzzz465/homebrew-wine-dxmt
WINE_DXMT_PREFIX=/path/to/your/steam/prefix brew install --cask wine-dxmt-steam
```

## Usage

```bash
# launch Steam
wine-dxmt-steam

# launch game directly (eg: DJMax)
wine-dxmt-steam -applaunch 960170

# shutdown — use Steam's Exit button. If that doesn't work:
wine-dxmt-steam shutdown
```
