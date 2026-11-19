#!/bin/bash
# Mediu de build Windows (CGConvertor): totul pe volumul extern (STORAGE_POLICY). Se rulează cu `source scripts/env.sh`.
R=${CGC_WIN_ROOT:?setează CGC_WIN_ROOT la un director de lucru extern (ieșiri de build, cache)}
if ! [ -d "$(dirname "$R")" ] || ! [ -w "$(dirname "$R")" ]; then echo "EXTERNAL TEST STORAGE NOT AVAILABLE"; return 1 2>/dev/null || exit 1; fi
mkdir -p "$R"/{builds,cache/nuget,cache/cargo,artifacts,temp,evidence}
export CGC_WIN_BUILD="$R/builds"
export NUGET_PACKAGES="$R/cache/nuget"
export CARGO_TARGET_DIR="$R/cache/cargo"
export DOTNET_CLI_HOME="$R/cache/dotnet-home"
export DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
