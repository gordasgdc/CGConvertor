# CG Convertor

[🇷🇴 Română](README.md) &middot; [🇬🇧 English](README.en.md) &middot; [🇪🇸 Español](README.es.md)

**Transcode & Rewrap for DaVinci Resolve** — Mac and Windows, fully standalone.

**Landing page:** https://gordasgdc.github.io/CGConvertor/

Made by **Cristi Gordas** (GDC) — [YouTube](https://youtube.com/@cristigordas) &middot; [resolvemaster.training](https://resolvemaster.training)

---

## 📦 Download & install

Nothing to install separately — FFmpeg is bundled.

| Platform | File | Install |
|---|---|---|
| Mac | `CGConvertor-mac.pkg` | Double-click → follow the installer |
| Mac (alt) | `CGConvertor-mac.zip` | Unzip and move the `.app` to `/Applications` |
| Windows | `CGConvertor-windows.exe` | Double-click to run |

Latest release: [Releases](https://github.com/gordasgdc/CGConvertor/releases/latest)

> On Mac, first launch: right-click the app → **Open** (the app isn't signed with a paid Apple Developer account). Alternative: `xattr -cr /Applications/CGConvertor.app` in Terminal.

## ✨ Features

- Rewrap (fast, no re-encode) and Transcode (full re-encode)
- ProRes 422 / 422 HQ / 422 LT / 4444, DNxHD, DNxHR HQ
- Drag-and-drop interface, batch processing
- Multilingual: RO / EN / ES
- Fully standalone — FFmpeg included

## 🛠️ Development

```bash
pip install -r requirements.txt
python main.py
```

Local build:
```bash
pyinstaller build-mac.spec       # or build-windows.spec on Windows
```

Releases are automated — a `git tag vX.X.X` + `git push origin vX.X.X` triggers builds for both platforms via GitHub Actions.

## 📄 Licenses

CGConvertor code: MIT — see [LICENSE](LICENSE).
Bundled dependencies (FFmpeg etc.): see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
