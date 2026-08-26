# Changelog

Toate modificările notabile ale acestui proiect sunt documentate aici.

## [Unreleased]

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
