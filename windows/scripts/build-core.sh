#!/bin/bash
# Reconstruiește gdc-metadata-core pentru Windows dintr-o revizie EXACTĂ (nu modifică și nu publică gdc-metadata).
# Rezultat: $R/cache/core-build/gdc-metadata-core.exe + SHA-256 reproductibil (căi remapate, --locked).
set -euo pipefail
REV=2c8c0bc7abe7b5ab0559381827c45a76bf8a7fb9      # gdc-metadata, miezul core/ (tree fe10221f6e30346042dd6a811e90b678c23317f5)
REPO=${GDC_METADATA_REPO:?setează GDC_METADATA_REPO la clona gdc-metadata}
R=${CGC_WIN_ROOT:?setează CGC_WIN_ROOT}
TC=$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin
[ "$(git -C "$REPO" rev-parse "$REV:core")" = fe10221f6e30346042dd6a811e90b678c23317f5 ] || { echo "arborele core/ nu corespunde"; exit 1; }
SRC=$R/staging/core-src; rm -rf "$SRC"; mkdir -p "$SRC"; git -C "$REPO" archive "$REV" core | tar -x -C "$SRC"
OUT=$R/cache/core-build; rm -rf "$OUT"; mkdir -p "$OUT"
( cd "$SRC/core" && env RUSTC=$TC/rustc PATH=$TC:/opt/homebrew/bin:/usr/bin:/bin \
  RUSTFLAGS="--remap-path-prefix=$SRC=/src --remap-path-prefix=$HOME/.cargo=/cargo --remap-path-prefix=$HOME/.rustup=/rustup -C link-arg=-Wl,--no-insert-timestamp" \
  CARGO_TARGET_DIR=$OUT/t CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
  $TC/cargo build --release --locked --target x86_64-pc-windows-gnu )
cp "$OUT/t/x86_64-pc-windows-gnu/release/gdc-metadata-core.exe" "$OUT/gdc-metadata-core.exe"; shasum -a 256 "$OUT/gdc-metadata-core.exe"
