# CG Convertor

[🇷🇴 Română](README.md) &middot; [🇬🇧 English](README.en.md) &middot; [🇪🇸 Español](README.es.md)

**Transcode y Rewrap para DaVinci Resolve** — Mac y Windows, totalmente independiente.

**Página de presentación:** https://gordasgdc.github.io/CGConvertor/

Creado por **Cristi Gordas** (GDC) — [YouTube](https://youtube.com/@cristigordas) &middot; [resolvemaster.training](https://resolvemaster.training)

---

## 📦 Descargar e instalar

No necesitas instalar nada por separado — FFmpeg está incluido.

| Plataforma | Archivo | Instalación |
|---|---|---|
| Mac | `CGConvertor-mac.pkg` | Doble clic → sigue el instalador |
| Mac (alt.) | `CGConvertor-mac.zip` | Descomprime y mueve el `.app` a `/Applications` |
| Windows | `CGConvertor-windows.exe` | Doble clic para ejecutar |

Última versión: [Releases](https://github.com/gordasgdc/CGConvertor/releases/latest)

> En Mac, primer inicio: clic derecho en la app → **Open** (la app no está firmada con una cuenta Apple Developer de pago). Alternativa: `xattr -cr /Applications/CGConvertor.app` en Terminal.

## ✨ Características

- Rewrap (rápido, sin re-codificación) y Transcode (re-codificación completa)
- ProRes 422 / 422 HQ / 422 LT / 4444, DNxHD, DNxHR HQ
- Interfaz drag-and-drop, procesamiento por lotes
- Multilingüe: RO / EN / ES
- Totalmente independiente — FFmpeg incluido

## 🛠️ Desarrollo

```bash
pip install -r requirements.txt
python main.py
```

Build local:
```bash
pyinstaller build-mac.spec       # o build-windows.spec en Windows
```

Los releases están automatizados — un `git tag vX.X.X` + `git push origin vX.X.X` dispara los builds para ambas plataformas via GitHub Actions.

## 📄 Licencias

Código de CGConvertor: MIT — ver [LICENSE](LICENSE).
Dependencias incluidas (FFmpeg, etc.): ver [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
