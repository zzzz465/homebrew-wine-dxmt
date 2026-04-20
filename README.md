# homebrew-wine-dxmt

[한국어 가이드](README.kor.md)

Prepackaged Wine + DXMT + Steam setup for macOS (Apple Silicon).

Bundles patched binaries and automated installation so games like DJMax and EZ2ON work out of the box.

For technical details on patches applied, see [TECHNICAL.md](./TECHNICAL.md).

## What's included

- Wine Staging 11.6_1 + Gcenx CW-HACK patches (Rosetta 2 compatibility)
- DXMT v0.74 (DirectX 11-to-Metal translation)
- DXMT Metal view frame sync patch (in-game resolution change fix)
- Proton mfreadwrite patch (video background rendering fix)
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
