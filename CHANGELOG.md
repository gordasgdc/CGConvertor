# Changelog

Toate modificările notabile ale acestui proiect sunt documentate aici.

## [Unreleased]

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
