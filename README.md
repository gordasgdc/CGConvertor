# CG Convertor

Transcode & rewrap rapid catre ProRes si DNxHD/DNxHR, construit pentru workflow-uri DaVinci Resolve.

**Pagina de prezentare:** https://gordasgdc.github.io/CGConvertor/

Creat de **Cristi Gordas** (GDC) — [YouTube](https://youtube.com/@cristigordas) &middot; [GitHub](https://github.com/gordasgdc)

---

## 📦 Doua versiuni disponibile

CG Convertor exista in doua variante independente. Poti instala oricare, sau ambele — nu se suprapun (nume de aplicatie diferite).

| | **Swift (nativ)** | **Python (standalone)** |
|---|---|---|
| Platforme | macOS | macOS **si** Windows |
| Interfata | SwiftUI, nativa 100% | Tkinter, multilingva (RO/EN/ES) |
| FFmpeg | Necesita `brew install ffmpeg` | Inclus in pachet, nimic de instalat |
| Cod sursa | rădăcina repo-ului (`CGConvertor.xcodeproj`) | `python/` |
| Recomandat pentru | uz zilnic pe Mac, integrare nativa | echipe mixte Mac/Windows, zero setup |

Ambele descarcari sunt pe aceeași pagina de [Releases](https://github.com/gordasgdc/CGConvertor/releases/latest).

### Instalare — versiunea Swift (Mac)

1. Descarcă `CGConvertor-X.X.X.pkg` din Releases
2. Dublu-click → urmează instalatorul
3. La prima rulare: click-dreapta pe aplicație → **Open** (nu e semnată cu cont Apple Developer plătit)
   - Alternativ: `xattr -cr /Applications/CGConvertor.app`
4. Instalezi FFmpeg o singură dată: `brew install ffmpeg`

### Instalare — versiunea Python (Mac sau Windows)

1. Descarcă `CGConvertor-standalone-mac.pkg` (Mac) sau `CGConvertor-standalone-windows.exe` (Windows) din Releases
2. Rulezi installer-ul / executabilul — nimic altceva de instalat, FFmpeg e deja inclus
3. Mac: click-dreapta → Open la prima rulare. Windows: „More info" → „Run anyway" dacă apare SmartScreen

## ✨ Ce fac ambele versiuni

- **Rewrap** — schimbare rapidă de container, fără re-encode
- **Transcode** — re-encode complet
- Codecuri: ProRes 422 / 422 HQ / 422 LT / 4444, DNxHD, DNxHR HQ
- Păstrează timecode-ul și metadata originală
- Drag & drop, procesare batch, progres per fișier

## 🛠️ Dezvoltare

**Swift:** deschizi `CGConvertor.xcodeproj` în Xcode și rulezi.

**Python:**
```bash
cd python
pip install -r requirements.txt
python main.py
```

Detalii complete pentru varianta Python (inclusiv licențierea FFmpeg): [python/README.md](python/README.md).

Release-urile pentru ambele versiuni sunt automatizate prin GitHub Actions (`.github/workflows/`): la fiecare `git tag vX.X.X` + `git push origin vX.X.X` se construiesc automat toate pachetele — `.zip`/`.pkg` Swift, `.zip`/`.pkg` Python-Mac, `.exe` Python-Windows — și se publică pe același Release.

## 📄 Licență

Codul CG Convertor: MIT — vezi [LICENSE](LICENSE).
Dependințele versiunii Python (FFmpeg etc.): vezi [python/THIRD_PARTY_NOTICES.md](python/THIRD_PARTY_NOTICES.md).
