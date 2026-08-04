# CG Convertor

Transcode & rewrap rapid catre ProRes si DNxHD/DNxHR, construit pentru workflow-uri DaVinci Resolve.

**Pagina de prezentare:** https://gordasgdc.github.io/CGConvertor/

Creat de **Cristi Gordas** (GDC) — [YouTube](https://youtube.com/@cristigordas) &middot; 

---

## 📦 Descarcă aplicația

Ultima versiune este disponibilă în [Releases](https://github.com/gordasgdc/CGConvertor/releases/latest).

### Instalare

1. Descarcă `CGConvertor-X.X.X.pkg` din secțiunea **Assets** a ultimei versiuni
2. Dublu-click pe fișierul `.pkg` și urmează instalatorul
3. Aplicația se instalează în `/Applications`
4. La prima rulare, macOS va afișa un avertisment ("dezvoltator neidentificat") — click-dreapta pe aplicație → **Open**, apoi confirmi
   - Alternativ, în Terminal: `xattr -cr /Applications/CGConvertor.app`

> Aplicația nu este semnată cu un cont Apple Developer plătit (dezvoltator individual, fără echipă). Avertismentul de mai sus e normal și nu indică o problemă reală.

### Alternativă (arhivă .zip)

Poți descărca și `CGConvertor-X.X.X.zip`, dezarhiva și muta manual `.app`-ul în `/Applications`.

## ⚙️ Cerințe

- macOS, Apple Silicon sau Intel (binar universal)
- [FFmpeg](https://ffmpeg.org) instalat via Homebrew: `brew install ffmpeg`

## ✨ Ce face

- **Rewrap** — schimbare rapidă de container, fără re-encode
- **Transcode** — re-encode complet cu encoder hardware Apple (VideoToolbox)
- Codecuri: ProRes 422 / 422 HQ / 422 LT / 4444, DNxHD, DNxHR HQ
- Păstrează timecode-ul și metadata originală
- Drag & drop, procesare batch, progres per fișier

## 🛠️ Dezvoltare

Proiect Xcode standard (SwiftUI). Deschizi `CGConvertor.xcodeproj` și rulezi.

Release-urile sunt automatizate prin `.github/workflows/release.yml`: la fiecare `git tag vX.X.X` urmat de `git push origin vX.X.X`, se construiește automat un binar universal (arm64 + x86_64), se generează `.zip` și `.pkg`, și se publică pe GitHub Releases cu note generate automat.

## 📄 Licență

MIT — vezi [LICENSE](LICENSE).
