# Changelog

Toate modificările notabile ale acestui proiect sunt documentate aici.

## [Unreleased]

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
