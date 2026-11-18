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

## GDC Metadata (nucleul `gdc-metadata-core`)

Livrat ca binar alături de aplicație (versiunea 0.3.0, commit 65e07a8), apelat ca subproces
pentru a citi fișa de metadate a sursei și a scrie fișierul sidecar. Licență: MIT.
Dependențe Rust compilate în binar: `serde`, `serde_json` și dependențele lor tranzitive
(licențe MIT sau Apache-2.0).

## ExifTool (opțional, NEINCLUS)

Dacă este instalat separat (de exemplu prin Homebrew), nucleul îl poate apela pentru mai
multe câmpuri. CGConvertor nu îl include și nu îl redistribuie. ExifTool © Phil Harvey,
licență Artistic License / GPL. https://exiftool.org

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

## xxHash (algoritmul XXH64)

CGConvertor conține o implementare proprie, în Swift, a algoritmului xxHash64. Autorul
algoritmului este Yann Collet. Codul nu e copiat din implementarea de referință, dar notificarea e păstrată din
precauție:

> xxHash — Extremely Fast Hash algorithm. Copyright (c) Yann Collet. All rights reserved.
>
> BSD 2-Clause License. Redistribution and use in source and binary forms, with or without modification, are permitted
> provided that the following conditions are met:
>
> 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
>    disclaimer.
> 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
>    following disclaimer in the documentation and/or other materials provided with the distribution.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
> INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
> DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
> SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
> SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
> WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
> OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


**Formatul ASC MHL.** CGConvertor scrie fișiere în formatul public ASC Media Hash List; e folosită doar specificația, nu cod al altor autori.
