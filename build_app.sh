#!/usr/bin/env bash
# Builds "CG Convertor.app" din proiectul Xcode si il instaleaza in
# /Applications — echivalentul build_app.sh din GDCVault/CursorPro, dar
# folosind xcodebuild (proiect .xcodeproj), nu Swift Package Manager.
set -euo pipefail
cd "$(dirname "$0")"

DERIVED_DATA="/tmp/CGConvertor-build-$$"
rm -rf "$DERIVED_DATA"

xcodebuild -project CGConvertor.xcodeproj \
    -scheme CGConvertor \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build

BUILT_APP=$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 1 -name "*.app")
if [ -z "$BUILT_APP" ]; then
    echo "EROARE: xcodebuild nu a produs niciun .app" >&2
    exit 1
fi

# Semnare cu Developer ID Application (certificat Apple real) daca e
# configurat - vezi codesigning/README.md - altfel fallback ad-hoc, ca
# rebuild-urile locale de dezvoltare sa functioneze si fara certificat.
if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILT_APP"
else
    echo "AVERTISMENT: APPLE_SIGN_IDENTITY_APP nesetat - semnez ad-hoc (doar pentru test local)."
    codesign --force --deep --sign - "$BUILT_APP"
fi

INSTALLED="/Applications/CGConvertor.app"
if [ -d "$INSTALLED" ]; then
    pkill -x CGConvertor 2>/dev/null || true
    sleep 0.5
fi
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$INSTALLED" 2>/dev/null || true
if [ -e "$INSTALLED" ] && [ ! -O "$INSTALLED" ]; then
    sudo rm -rf "$INSTALLED"
    sudo cp -R "$BUILT_APP" "$INSTALLED"
    sudo chown -R "$(id -u):$(id -g)" "$INSTALLED"
else
    rm -rf "$INSTALLED"
    cp -R "$BUILT_APP" "$INSTALLED"
fi
"$LSREGISTER" -f "$INSTALLED" 2>/dev/null || true
rm -rf "$DERIVED_DATA"
echo "Installed to $INSTALLED"
