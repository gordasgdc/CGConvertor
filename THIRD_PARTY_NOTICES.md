# Third-Party Notices

CGConvertor include binare terțe care au propriile licențe, separate de licența MIT a
codului CGConvertor.

## FFmpeg / FFprobe

CGConvertor include binarele FFmpeg și FFprobe pentru a converti fișiere video fără
ca utilizatorul să instaleze nimic separat.

**Sursa:** https://ffmpeg.org

### Build-ul pentru Windows

Folosim build-ul **"essentials"** (versiunea 9.0.2) publicat de gyan.dev
(https://www.gyan.dev/ffmpeg/builds/). Verificat cu `ffmpeg -buildconf`: acest build este
compilat cu `--enable-gpl` și include libx264 și libx265, deci binarul FFmpeg este licențiat
**GPL v3**; se respectă condițiile GPL pentru acest binar (cod sursă corespunzător: https://github.com/FFmpeg/FFmpeg, comitul `946fcce07b` indicat în
`tools\\FFMPEG-README.txt`; configurația completă de build, inclusiv bibliotecile terțe cu
licențele lor, este în același fișier și pe https://www.gyan.dev/ffmpeg/builds/; la cerere,
putem furniza și o ofertă scrisă pentru sursa corespunzătoare). Textul GPL v3 este în
`tools\\FFMPEG-LICENSE.txt`. Aplicația rulează FFmpeg ca proces separat.
Nu include libsvtav1: presetul AV1 nu este disponibil în versiunea Windows. mpv nu este inclus.

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

Livrat ca binar alături de aplicație, apelat ca subproces pentru a citi fișa de metadate a
sursei și a scrie fișierul sidecar. Licență: MIT. Pachetul Windows folosește binarul
compilat reproductibil din revizia exactă `2c8c0bc7abe7b5ab0559381827c45a76bf8a7fb9`
(`windows/scripts/build-core.sh`, `--locked`, fără amprentă de timp; SHA-256 în
`windows/vendor/PROVENANCE.txt`). Dependențe Rust compilate în binar: `serde`, `serde_json`
și dependențele lor tranzitive (licențe MIT sau Apache-2.0).

## ExifTool (inclus în pachetul Windows; neinclus pe macOS)

**Pachetul Windows include ExifTool 13.64** (`tools\exiftool.exe` și folderul
`tools\exiftool_files`), neschimbat, descărcat de pe https://exiftool.org (arhivă verificată
cu SHA-256 la asamblare). ExifTool © Phil Harvey, licență dublă Artistic License / GPL;
CGConvertor îl rulează ca proces separat și nu îl modifică. Textul GPL v3 este în
`tools\EXIFTOOL-LICENSE-GPL3.txt`, iar notele pachetului în `tools\EXIFTOOL-README.txt`.
Folderul `exiftool_files` conține și interpretorul Perl (Strawberry Perl, licențele lui în
`exiftool_files\perl`), distribuit sub licențele proprii Artistic/GPL.
Sursa ExifTool: https://exiftool.org și https://github.com/exiftool/exiftool.
Pe macOS ExifTool nu este inclus: dacă este instalat separat (de exemplu prin Homebrew),
nucleul îl poate apela.

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
