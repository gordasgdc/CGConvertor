#!/usr/bin/env bash
# Builds "CGConvertor.app" fresh (xcodebuild, fara instalare directa in
# /Applications — vezi build_app.sh pentru asta), apoi il impacheteaza
# intr-un .pkg semnat + notarizat, cu panou de licenta (Terms &
# Conditions) si TINTA DE INSTALARE DIRECTA in /Applications (cerinta
# critica: userul NU trebuie sa traga nimic manual — pkgbuild scrie
# direct in /Applications/, la fel ca orice .pkg standard macOS).
#
# NOTE: produce un .pkg SEMNAT + NOTARIZAT automat daca certificatele
# Developer ID Application/Installer sunt configurate (vezi
# codesigning/README.md). Altfel cade pe un pachet NESEMNAT.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(grep -m1 "MARKETING_VERSION" CGConvertor.xcodeproj/project.pbxproj | sed -E 's/.*MARKETING_VERSION = ([0-9.]+);.*/\1/')
PKG_ID="com.cristigordas.CGConvertor.installer"
APP_NAME="CGConvertor.app"
DIST_DIR="dist"
PAYLOAD_ROOT="$DIST_DIR/payload"
COMPONENT_PKG="$DIST_DIR/CGConvertor-component.pkg"
FINAL_PKG="$DIST_DIR/CGConvertor-$VERSION.pkg"

echo "==> Building app (version $VERSION)…"
DERIVED_DATA="/tmp/CGConvertor-installer-build-$$"
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

if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILT_APP"
else
    echo "AVERTISMENT: APPLE_SIGN_IDENTITY_APP nesetat - semnez ad-hoc (pachetul final va ramane nesemnat)."
    codesign --force --deep --sign - "$BUILT_APP"
fi

rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_ROOT/Applications"
cp -R "$BUILT_APP" "$PAYLOAD_ROOT/Applications/$APP_NAME"
rm -rf "$DERIVED_DATA"

echo "==> Building component package (instalare directa in /Applications)…"
# --install-location "/" + root-ul are Applications/CGConvertor.app —
# pkgbuild scrie ASTFEL direct in /Applications la instalare, fara
# niciun pas manual din partea userului (drag-and-drop dintr-un .dmg NU
# se foloseste aici, intentionat). --scripts: preinstall CURATA doar o
# instalare veche ramasa (pkill + rm -rf), NIMIC legat de Gatekeeper.
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "installer/scripts" \
    "$COMPONENT_PKG"

echo "==> Writing distribution definition…"
cat > "$DIST_DIR/Distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>CG Convertor $VERSION</title>
    <license file="License.txt" mime-type="text/plain"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$PKG_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$PKG_ID" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">CGConvertor-component.pkg</pkg-ref>
</installer-gui-script>
EOF

cp installer/License.txt "$DIST_DIR/License.txt"

echo "==> Building final installer package…"
productbuild \
    --distribution "$DIST_DIR/Distribution.xml" \
    --package-path "$DIST_DIR" \
    --resources "$DIST_DIR" \
    "$FINAL_PKG"

rm -rf "$PAYLOAD_ROOT" "$COMPONENT_PKG"

# Semnare + notarizare a .pkg-ului final, daca certificatul Installer e
# configurat - altfel ramane nesemnat.
./codesigning/sign-and-notarize.sh pkg "$FINAL_PKG"

cp "$FINAL_PKG" "$DIST_DIR/CGConvertor.pkg"

echo "==> Copying uninstaller (Dezinstalare_CGConvertor.command)…"
cp "Dezinstalare_CGConvertor.command" "$DIST_DIR/Dezinstalare_CGConvertor.command"
chmod +x "$DIST_DIR/Dezinstalare_CGConvertor.command"

# Bundle .pkg + uninstaller + instructiuni intr-un zip curat. Pachetul e
# semnat + notarizat + stapled, deci Gatekeeper il accepta nativ la
# dublu-click - NU exista niciun launcher/script de bypass. Totul la
# radacina arhivei, fara subfoldere - doar 3 fisiere, fara ambiguitate.
echo "==> Building CGConvertor-Mac.zip (pkg + uninstaller + instructiuni)…"
ZIP_STAGE="$DIST_DIR/zip_stage"
rm -rf "$ZIP_STAGE"
mkdir -p "$ZIP_STAGE"
cp "$DIST_DIR/CGConvertor.pkg" "$ZIP_STAGE/"
cp "installer/Instructiuni_Utilizare.pdf" "$ZIP_STAGE/" 2>/dev/null || true
cp "$DIST_DIR/Dezinstalare_CGConvertor.command" "$ZIP_STAGE/"
chmod +x "$ZIP_STAGE/Dezinstalare_CGConvertor.command"
( cd "$ZIP_STAGE" && zip -q -r -y "../CGConvertor-Mac.zip" . )
rm -rf "$ZIP_STAGE"

echo "==> Done: $FINAL_PKG"
echo "==> Also: $DIST_DIR/CGConvertor.pkg, $DIST_DIR/Dezinstalare_CGConvertor.command, $DIST_DIR/CGConvertor-Mac.zip"
echo "    Upload CGConvertor-Mac.zip to the GitHub release (that's what the website links to)."
