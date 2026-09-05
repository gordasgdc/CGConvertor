# Changelog

Toate modificările notabile ale acestui proiect sunt documentate aici.

### v3.7.0 — Offload profesional: MHL, șablon nume, card, profile, istoric + comparație metadate (2026-09-05)

Panoul Offload capătă un flux profesional complet, la nivelul uneltelor de
platou consacrate: fișier **MHL** (Media Hash List) alături de raportul
CSV — citit de Silverstack/YoYotta/ShotPut Pro/Resolve —, **reîncercare
automată** a fișierelor eșuate, **verificare de spațiu liber** înainte de
transfer, **șablon configurabil** pentru numele folderului, **recunoașterea
automată a tipului de card** (RED/ARRI/Sony/Panasonic/Canon/Blackmagic),
câmpuri de **producție** (Proiect/Client/Cameră/Operator/Logo) cu **raport
HTML brandat**, **profile de transfer** salvate și **istoric** persistat.
Discurile detectate se pot acum și trage direct (drag&drop) peste
Sursă/Destinații. Disponibil pe ambele platforme.

Pe Mac, fișierele din coadă pot fi selectate și comparate într-un tabel
de metadate side-by-side, cu evidențierea diferențelor și export CSV.

### v3.6.0 — Discuri detectate în Offload (2026-09-05)

Panoul Offload arată acum discurile/cardurile montate ca listă reală
(nume, spațiu liber), nu doar un câmp de path text — click direct pentru
a folosi un disc ca sursă sau a-l adăuga ca destinație, la fel ca în
DataMover. Disponibil identic pe Mac și Windows.

### v3.5.0 — Preview LUT: fullscreen + rezoluție mare (2026-09-05)

Previzualizarea interactivă cu LUT poate fi acum mărită pe tot ecranul
(sau redimensionată liber pe Windows), și regenerează cadrul la rezoluție
mult mai mare (1920px lățime) când e mărită — nu doar întinde aceeași
imagine mică. Disponibil identic pe Mac și Windows.

### v3.4.0 — Verificare integritate post-conversie (2026-09-05)

Fiecare fișier convertit cu succes e verificat automat: durata fișierului
rezultat e comparată cu durata sursei. Dacă diferă semnificativ (posibilă
trunchiere/corupere silențioasă, nedetectată doar din codul de ieșire al
motorului de conversie), rândul rămâne marcat ca finalizat dar cu un
avertisment vizibil (⚠) și ambele durate afișate, în loc de bifa verde
obișnuită. Disponibil identic pe Mac și Windows.

### v3.3.0 — Faza 2: Preview interactiv cu LUT (2026-09-05)

Fiecare fișier analizat (are thumbnail generat) capătă o previzualizare
interactivă — click-dreapta pe rând → „Previzualizează". O bară de
progres derulează prin clip, regenerând imaginea la momentul respectiv;
un LUT `.cube` opțional se poate aplica live pe previzualizare. Nu e
redare video propriu-zisă (rămâne un proiect separat, mult mai mare) — e
un pas util, disponibil de pe acum, pe ambele platforme.

### v3.2.0 — Faza 2: Watch Folders + Inspecție/Metadata + Rapoarte (2026-09-05)

**Watch Folders**: alege unul sau mai multe foldere de urmărit — orice
fișier video nou apărut acolo (ex. copiat de pe un card) intră automat în
coadă, fără să-l adaugi manual. Fiecare folder poate fi activat/dezactivat
sau șters din listă.

**Inspecție/Metadata + thumbnail**: fiecare fișier adăugat în coadă e
analizat automat (rezoluție, codec, framerate, durată, audio) — apare ca
thumbnail + rezumat direct lângă fiecare rând. Buton nou „Generează
raport" produce un raport HTML (cu toate thumbnail-urile și metadata
lotului curent), deschis automat.

Disponibil identic pe Mac și Windows.

### v3.1.0 — Faza 2: Offload/Checksum (2026-09-05)

**Mod nou, „Offload"** (comutator lângă titlu, alături de „Convertor") —
copiere sursă (card media) → una sau mai multe destinații, cu verificare
integrală a fiecărui fișier după copiere: xxHash64 (implicit, rapid),
MD5, SHA-1, SHA-256, sau doar comparație de mărime. Un raport CSV
(fișier/mărime/verificare sursă/destinație/status) se scrie automat în
fiecare folder destinație. Pauză/Reluare și Anulare, plus aceleași setări
de buffer/plafon de memorie ca restul aplicației. Disponibil identic pe
Mac și Windows.

### v3.0.0 — Faza 1: Motor extins + Presets Manager + conformitate ecosistem (2026-09-05)

Schimbare majoră de arhitectură — modelul fix "Mod (Rewrap/Transcode) +
6 codecuri hardcodate" e înlocuit de un **Presets Manager** complet, iar
motorul de transcodare capătă codecuri de livrare noi cu accelerare
hardware, pe ambele platforme (Mac + Windows).

- **Presets Manager** (nou, ambele platforme) — presetări denumite,
  fiecare cu aplicație țintă (DaVinci/Premiere/FCP/Avid/Web/Personalizat),
  codec, mod audio (Passthrough/PCM 16-24-bit/AAC) și layout de canale.
  Complet editabil: creează/duplică/șterge/redenumește + Import/Export
  JSON (portabil între Mac și Windows). 7 presetări implicite incluse
  (ProRes 422 HQ, DNxHR HQ, H.264 Web, HEVC 10-bit Master, AV1,
  Uncompressed, Rewrap Rapid).
- **Codecuri de livrare noi**: H.264, HEVC 10-bit, AV1, Uncompressed
  10-bit — pe lângă ProRes/DNxHR existente. Mac: accelerare hardware
  VideoToolbox (AV1 rămâne software — niciun Mac nu are encoder AV1
  hardware). Windows: detecție automată a plăcii video (Nvidia NVENC /
  AMD AMF / Intel Quick Sync), cu fallback software și selector manual
  în Setări pentru sisteme cu configurație neobișnuită.
- **Audio extins**: pe lângă Passthrough (implicit, ca până acum),
  presetările de livrare pot re-codifica explicit în PCM sau AAC, cu
  layout de canale ales (Original/Stereo/5.1).
- **Coadă**: Pauză/Reluare (nu doar Stop total — un job deja pornit
  termină natural), procesare paralelă configurabilă (1-4 joburi
  simultane), reordonare din meniul contextual, notificare nativă la
  finalizarea întregii cozi.
- **Profil + Machine ID vizibile în sidebar** (Nume opțional, ID mașină,
  buton Setări) — aliniat cu restul ecosistemului GDC.
- **Revocare de licență online** (fail-open — o licență deja activată
  local nu se blochează niciodată doar pentru că ești offline) și **preț
  de donație dinamic pe Windows** (Mac avea deja acest lucru din
  v2.2.1) — ambele citesc din infrastructura comună a ecosistemului.
- **Temă System/Dark/Light** și **Mărime text** (Mic/Normal/Mare/Foarte
  mare), explicite în Setări, aplicate instant — fără repornire, pe
  ambele platforme.
- Modurile existente (Rewrap, ProRes, DNxHR) rămân neschimbate ca
  rezultat — verificat direct, nu presupus.
- **Fix Windows (ARM64)**: aplicația nu pornea deloc pe unele sisteme
  (biblioteca de drag-and-drop native nu se încărca) — acum cade automat
  pe modul fără drag-and-drop, în loc să crape.
- **Fix Windows**: ferestrele de Presetări/Setări puteau rămâne complet
  goale după acest fallback — reparat.

### v2.2.1 — Preț dinamic din Furnizor (2026-08-31)
- Suma de donație din ecranul de Activare + mesajul WhatsApp se citește
  acum din `pricing.json` (Furnizor), nu mai e fixă în cod — orice ofertă
  programată apare automat, fără recompilare.

### v2.1.0 — Hotfix critic FFmpeg + Manager Modular de Dependințe (2026-08-26)
- **Fix critic Mac**: binarul FFmpeg bundle-uit anterior era legat dinamic
  de un path local Homebrew (`/opt/homebrew/Cellar/ffmpeg/...`), provocând
  crash `dyld: Library not loaded` pe orice alt calculator/versiune Homebrew.
  Înlocuit cu build-uri statice, fără dependințe externe (verificat
  `otool -L` = zero dylib-uri Homebrew), arm64 nativ (osxexperts.net).
- **Manager Modular de Dependințe** (nou standard arhitectural pentru tot
  ecosistemul GDC, opt-in): indicator global 🟢/🔴 în header, panou dedicat
  "Verificare & Dependințe Sistem" cu listă de componente (FFmpeg static,
  Homebrew opțional pe Mac), fiecare cu status individual + buton de
  acțiune ("Descarcă & Instalează Automat" / "Copiază Comanda Homebrew").
  Descărcare 1-click FFmpeg static, autonomă, în `Application Support/bin/`.
  Implementat identic pe Mac (Swift: `DependencyManager.swift`,
  `DependencyPanel.swift`) și Windows (Python: `dependency_manager.py`,
  `dependency_panel.py`, ffmpeg static gyan.dev).
- **Acțiuni post-conversie**: pentru fiecare fișier convertit cu succes,
  butoane "Deschide fișierul" (redare în playerul implicit) și "Arată în
  Finder/Explorer" (evidențiază fișierul în folderul destinație) — Mac+Win.
- **Standard PDF ultra-detaliat** (directivă permanentă nouă, vezi
  CLAUDE.md): `Instructiuni_Utilizare.pdf` regenerat cu 4 secțiuni
  obligatorii — panoul de dependințe roșu/verde explicat pas-cu-pas,
  ghid Homebrew la nivel de acțiune (Spotlight, Terminal, parolă
  invizibilă), fluxul de conversie + explicația butoanelor post-conversie,
  licență/trial 15 zile + donație 23 € — RO/EN/ES.
- Fix real de concurență (Python): apel `.after()` cross-thread înainte
  de pornirea `mainloop()` cauza `RuntimeError: main thread is not in
  main loop` — rezolvat prin `self.after(100, self._refresh_dependencies)`.

### Faza C: packaging semnat, installer Windows, pagină web (2026-08-26)
- Pachet Mac `.pkg` semnat Developer ID Application+Installer, notarizat,
  stapled — instalare 100% automată în `/Applications`, fără drag-and-drop.
  `CGConvertor-Mac.zip`: exact 3 fișiere (pkg + `Dezinstalare_CGConvertor.command`
  + `Instructiuni_Utilizare.pdf` RO/EN/ES).
- Installer Windows (Inno Setup) — instalare automată în Program Files,
  scurtături Desktop + Start Menu.
- Eliminate 2 workflow-uri CI care produceau 4 fișiere Mac nesemnate,
  confuze (`release.yml`, `build-mac.yml`) — un singur pachet Mac oficial.
- Pagină web dedicată (`docs/index.html`, servită la
  `gordas.dev/CGConvertor/`) rescrisă complet — temă Shift, RO/EN/ES,
  linkuri directe la `releases/latest/download/...`.
- **Terminologie financiară**: valoarea (23 €) exprimată exclusiv ca
  donație pentru dezvoltare, niciodată "preț"/"cumpără"/"vânzare" — UI
  Mac+Windows, PDF, site.

### v2.0.0 — Faza B: UI "Shift", licențiere, update checker (2026-08-26)
- **UI rescris complet** pe ambele platforme, temă "Shift" (dark, accent
  cupru/amber, inspirat de paginile de Color din DaVinci Resolve).
- **Licențiere unificată GDC** (Ed25519, aceeași cheie ca tot
  ecosistemul) + probă gratuită 15 zile, pe Mac și Windows.
- **Versiune vizibilă în UI** + **update checker cu pop-up** (verificare
  automată la lansare + buton manual), pe Mac și Windows.
- Fuziune funcțională Python → Swift: setări persistate (ultimul
  mod/codec/folder), Stop/Anulare coadă în curs, gardă la golirea
  listei în timpul rulării.
- Fix regresie reală în Python: transcode-ul forța audio la
  `pcm_s16le` (16-bit), pierzând bit depth-ul original — acum `-c:a copy`,
  aliniat cu varianta Swift.
- Iconiță de fereastră (title bar/taskbar) pe Windows — lipsea complet.
- Installer Windows nou (`installer.iss`, Inno Setup) — înlocuiește
  `.exe`-ul brut publicat anterior, fără scurtături/dezinstalare.
- Curățare: fișierele Python duplicate de la rădăcina repo-ului
  (versiune veche, fără stilizare `ttk` corectă) șterse — `python/`
  e singura sursă de adevăr.
- `MACOSX_DEPLOYMENT_TARGET` corectat de la `26.5` la `14.0` (Xcode).

### Faza A — Relocare & Curățare (2026-08-26)
- Repo mutat din `~/Desktop/CGConvertor` în `~/Developer/CGConvertor`
  (regulă permanentă, vezi `CLAUDE.md`).
- Eliminat token GitHub expus în clar din `.git/config` — remote
  resetat fără credențiale în URL.
- Adăugat `.gitignore` (lipsea complet) — `__pycache__/` scos din
  tracking, `venv/` exclus.
- Verificat `Downloads/CGConvertor-trilingv` și `-update`: subseturi
  vechi, deja depășite — nimic de fuzionat.

## [1.0.0] - 2026-08-04

### Adăugat
- Suport pentru ProRes 422, ProRes 422 HQ, ProRes 422 LT, ProRes 4444
- Suport pentru DNxHD, DNxHR HQ
- Mod Rewrap (fără re-encode) și mod Transcode (re-encode complet)
- Interfață drag-and-drop, procesare batch cu coadă
- Păstrare automată a timecode-ului și metadatelor originale
- Binar universal (Apple Silicon + Intel)
- Release automatizat prin GitHub Actions (`.zip` + `.pkg`)

<!--
Format recomandat pentru intrari viitoare:

## [X.Y.Z] - AAAA-LL-ZZ

### Adăugat
- ...

### Modificat
- ...

### Corectat
- ...
-->
