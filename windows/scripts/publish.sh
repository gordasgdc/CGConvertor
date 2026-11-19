#!/bin/bash
# Publică clientul WPF self-contained (win-x64) pe volumul extern, cu tools/ și ghidurile.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
source "$HERE/scripts/env.sh" >/dev/null
R=${CGC_WIN_ROOT:?setează CGC_WIN_ROOT}
OUT=$R/artifacts/publish
rm -rf "$OUT"
dotnet publish "$HERE/CGConvertor.Client/CGConvertor.Client.csproj" -c Release -r win-x64 --self-contained true \
  -p:CGC_TOOLS_DIR=$R/staging/tools -p:DebugType=none -o "$OUT" 2>&1 | grep -E "error|warn|->|Elapsed" | sort -u
[ -d "$HERE/guides" ] && mkdir -p "$OUT/guides" && cp "$HERE"/guides/*.pdf "$OUT/guides/" 2>/dev/null || true
du -sh "$OUT"; ls "$OUT" | head -20
