# homebrew-wine-dxmt

[한국어 가이드](README.kor.md)

prepackaged wine + dxmt + easy steam setup for macOS.

- wine 11 + GCENX
- dxmt 0.74
- fixed to run DJMax
  - update GLib/GStreamer to system version
  - DXMT patch for resizing issue
  - wine 11 with Gcenx CW-HACK patch for running in Rosetta 2

## how to install

```bash
# install everything including steam
brew tap zzzz465/homebrew-wine-dxmt
brew install --cask wine-dxmt-steam

# if steam is already installed
brew tap zzzz465/homebrew-wine-dxmt
WINE_DXMT_PREFIX=/path/to/your/steam/prefix brew install --cask wine-dxmt-steam
```

## usage

```bash
# launch steam
wine-dxmt-steam

# launch game directly (eg: DJMax)
wine-dxmt-steam -applaunch 960170

# shutdown
wine-dxmt-steam shutdown
```
