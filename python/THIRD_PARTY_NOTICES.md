# Third-Party Notices

CGConvertor include binare terțe care au propriile licențe, separate de licența MIT a
codului CGConvertor.

## FFmpeg / FFprobe

CGConvertor include binarele FFmpeg și FFprobe pentru a converti fișiere video fără
ca utilizatorul să instaleze nimic separat.

**Sursa:** https://ffmpeg.org

### Build-ul pentru Windows

Folosim build-ul **"essentials" (LGPL)** publicat de gyan.dev
(https://www.gyan.dev/ffmpeg/builds/). Acest build **nu** include componente GPL
(precum libx264/libx265), deci poate fi redistribuit sub termenii LGPL 2.1+ fără
obligația de a oferi codul sursă al aplicației care îl include.

### Build-ul pentru macOS

Folosim build-ul FFmpeg instalat prin **Homebrew**, care în configurația implicită
include componente **GPL** (libx264, libx265 etc.). Redistribuirea acestui binar
înseamnă că trebuie respectate condițiile GPL v2/v3 pentru binarul FFmpeg în sine —
în principal, oferirea codului sursă corespunzător sau a unei oferte scrise de a-l
furniza, la cerere.

> **De facut inainte de o distribuire publica la scara mare:** inlocuit build-ul Mac
> cu unul LGPL-only (fara libx264/libx265), pentru consistenta cu varianta Windows
> si pentru a elimina complet obligatiile GPL. Codecurile folosite de CGConvertor
> (ProRes, DNxHD/DNxHR) nu depind de componente GPL.

Codul sursă complet al FFmpeg este disponibil public la:
https://github.com/FFmpeg/FFmpeg

## tkinterdnd2

Folosit pentru suport drag-and-drop în interfața Tkinter.
Licență: MIT. https://github.com/pmgagne/tkinterdnd2

## PyInstaller

Folosit doar la build (nu e distribuit cu aplicația finală).
Licență: GPL v2 cu excepție de bootloader — nu afectează licența codului ambalat.
https://pyinstaller.org

---

Codul sursă al CGConvertor (excluzând binarele de mai sus) este licențiat MIT —
vezi [LICENSE](LICENSE).
