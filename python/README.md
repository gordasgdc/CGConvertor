# CG Convertor

[🇷🇴 Română](README.md) &middot; [🇬🇧 English](README.en.md) &middot; [🇪🇸 Español](README.es.md)

**Transcode & Rewrap pentru DaVinci Resolve** — Mac și Windows, complet standalone.

**Pagina de prezentare:** https://gordasgdc.github.io/CGConvertor/

Creat de **Cristi Gordas** (GDC) — [YouTube](https://youtube.com/@cristigordas) &middot; [resolvemaster.training](https://resolvemaster.training)

---

## 📦 Descarcă și instalează

Nu trebuie să instalezi nimic separat — FFmpeg e inclus în pachet.

| Platformă | Fișier | Instalare |
|---|---|---|
| Mac | `CGConvertor-mac.pkg` | Dublu-click → urmează instalatorul |
| Mac (alternativ) | `CGConvertor-mac.zip` | Dezarhivezi și muți `.app`-ul în `/Applications` |
| Windows | `CGConvertor-windows.exe` | Dublu-click pentru a rula |

Ultima versiune: [Releases](https://github.com/gordasgdc/CGConvertor/releases/latest)

> Pe Mac, la prima rulare: click-dreapta pe aplicație → **Open** (aplicația nu e semnată cu cont Apple Developer plătit). Alternativ: `xattr -cr /Applications/CGConvertor.app` în Terminal.

## ✨ Caracteristici

- Rewrap (rapid, fără re-encode) și Transcode (re-encode complet)
- ProRes 422 / 422 HQ / 422 LT / 4444, DNxHD, DNxHR HQ
- Interfață drag-and-drop, procesare batch
- Multilingv: RO / EN / ES
- Complet standalone — FFmpeg inclus

## 🛠️ Dezvoltare

```bash
pip install -r requirements.txt
python main.py
```

Build local:
```bash
pyinstaller build-mac.spec       # sau build-windows.spec pe Windows
```

Release-urile sunt automatizate — un `git tag vX.X.X` + `git push origin vX.X.X` pornește build-urile pentru ambele platforme prin GitHub Actions.

## 📄 Licențe

Codul CGConvertor: MIT — vezi [LICENSE](LICENSE).
Dependințe incluse (FFmpeg etc.): vezi [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
