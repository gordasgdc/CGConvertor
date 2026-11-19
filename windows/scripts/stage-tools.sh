#!/bin/bash
# Pregătește dependențele redistribuibile (ffmpeg, ffprobe, gdc-metadata-core) în $R/staging/tools, cu proveniență.
# Rulează după `source scripts/env.sh`. Nu descarcă nimic: cere arhiva ffmpeg deja pusă în $R/cache/ffmpeg.
set -euo pipefail
R=${CGC_WIN_ROOT:?setează CGC_WIN_ROOT}
ZIP=$R/cache/ffmpeg/ffmpeg-9.0.2-essentials_build.zip
CORE=${CGC_METADATA_CORE:-$(cd "$(dirname "$0")/.." && pwd)/vendor/gdc-metadata-core.exe}
OUT=$R/staging/tools
[ -f "$ZIP" ] || { echo "lipsește $ZIP"; exit 1; }
EXP=$(awk '{print $1}' "$ZIP.sha256"); GOT=$(shasum -a 256 "$ZIP" | awk '{print $1}')
[ "$EXP" = "$GOT" ] || { echo "SHA-256 ffmpeg nu se potrivește"; exit 1; }
chmod -R u+w "$OUT" "$R/staging/et" "$R/staging/ff" 2>/dev/null || true; rm -rf "$OUT" "$R/staging/ff"; mkdir -p "$OUT" "$R/staging/ff"
unzip -q "$ZIP" -d "$R/staging/ff"
FF=$(ls -d "$R"/staging/ff/ffmpeg-*)
cp "$FF/bin/ffmpeg.exe" "$FF/bin/ffprobe.exe" "$OUT/"
cp "$FF/LICENSE" "$OUT/FFMPEG-LICENSE.txt"; [ -f "$FF/README.txt" ] && cp "$FF/README.txt" "$OUT/FFMPEG-README.txt"
cp "$CORE" "$OUT/gdc-metadata-core.exe"
cp "$(cd "$(dirname "$0")/../.." && pwd)/THIRD_PARTY_NOTICES.md" "$OUT/THIRD_PARTY_NOTICES.md"
# ExifTool 13.64 (Windows 64-bit, oficial exiftool.org): SHA-256 publicat de autor, verificat; redenumit fără „(-k)” (fără pauză la ieșire)
EZIP=$R/cache/exiftool/exiftool-13.64_64.zip
[ "$(shasum -a 256 "$EZIP" | awk '{print $1}')" = "72c29c44d1e860eebcaefa71692d979af9858fe9a6d7d791a5e7f1dac77804af" ] || { echo "SHA-256 ExifTool nu se potrivește"; exit 1; }
chmod -R u+w "$R/staging/et" 2>/dev/null || true; rm -rf "$R/staging/et"; mkdir -p "$R/staging/et"; unzip -q "$EZIP" -d "$R/staging/et"
ET=$R/staging/et/exiftool-13.64_64
cp "$ET/exiftool(-k).exe" "$OUT/exiftool.exe"; cp -R "$ET/exiftool_files" "$OUT/exiftool_files"; chmod -R u+w "$OUT"
cp "$ET/exiftool_files/LICENSE" "$OUT/EXIFTOOL-LICENSE-GPL3.txt"; cp "$ET/README.txt" "$OUT/EXIFTOOL-README.txt"
{
  echo "ffmpeg: $(basename "$FF") (gyan.dev release essentials), arhivă sha256 $GOT"
  echo "exiftool: 13.64_64 (exiftool.org), arhivă sha256 72c29c44d1e860eebcaefa71692d979af9858fe9a6d7d791a5e7f1dac77804af"
  echo "gdc-metadata-core: $CORE"
  ( cd "$OUT" && shasum -a 256 ffmpeg.exe ffprobe.exe gdc-metadata-core.exe exiftool.exe )
} > "$OUT/PROVENANCE.txt"
cat "$OUT/PROVENANCE.txt"
