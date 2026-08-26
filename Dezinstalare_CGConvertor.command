#!/usr/bin/env bash
#
# Dezinstalare_CGConvertor.command
# Dezinstalare & curatare completa pentru CG Convertor.
#
# Ce face:
#   1. Opreste fortat orice instanta ramasa in fundal.
#   2. Sterge aplicatia + toate fisierele de date/preferinte/cache asociate
#      (INCLUSIV licenta activata — dezinstalarea e completa, intentionat;
#      proba gratuita NU e resetabila prin dezinstalare-reinstalare, vezi
#      nota din LicenseManager.swift/activation.py).
#
# Bundle ID real: com.cristigordas.CGConvertor (Info.plist / project.pbxproj).
#
# Rulare: dublu-click, sau click-dreapta -> Open (Terminal), sau din terminal:
#   chmod +x Dezinstalare_CGConvertor.command && ./Dezinstalare_CGConvertor.command
#
# NOTA 1: daca fisierul a fost descarcat separat (nu din arhiva .zip
# originala), poate avea flag-ul de quarantine si/sau bitul de executie
# lipsa - ruleaza intai:
#   xattr -d com.apple.quarantine Dezinstalare_CGConvertor.command
#   chmod +x Dezinstalare_CGConvertor.command
#
# NOTA 2: stergerea /Applications/CGConvertor.app poate cere parola de
# administrator (sudo), in functie de cum a fost instalata - scriptul
# cere sudo DOAR daca stergerea normala esueaza, nu de la inceput.

set -uo pipefail

BUNDLE_ID="com.cristigordas.CGConvertor"
APP_PATH="/Applications/CGConvertor.app"

echo "=================================================="
echo " CG Convertor — Dezinstalare & Curatare completa"
echo "=================================================="
echo ""

read -p "Sigur vrei sa stergi CG Convertor si toate fisierele lui? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Anulat."
    exit 0
fi
echo ""

echo "[1/2] Opresc orice instanta CG Convertor ramasa in fundal..."
pkill -x "CGConvertor" 2>/dev/null
pkill -f "CGConvertor.app" 2>/dev/null
sleep 1
echo "[+] Procese oprite."
echo ""

echo "[2/2] Sterg aplicatia si toate fisierele asociate..."

remove_if_exists() {
    local path="$1"
    if [ ! -e "$path" ]; then
        return
    fi
    if rm -rf "$path" 2>/dev/null && [ ! -e "$path" ]; then
        echo "      - sters: $path"
        return
    fi
    echo "      - necesita permisiuni de administrator: $path"
    if sudo rm -rf "$path" && [ ! -e "$path" ]; then
        echo "      - sters (cu sudo): $path"
    else
        echo "      - EROARE: nu am putut sterge $path"
    fi
}

remove_if_exists "$APP_PATH"
remove_if_exists "$HOME/Library/Application Support/CGConvertor"
remove_if_exists "$HOME/Library/Caches/$BUNDLE_ID"
defaults delete "$BUNDLE_ID" 2>/dev/null || true
remove_if_exists "$HOME/Library/Preferences/$BUNDLE_ID.plist"
remove_if_exists "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"

echo "[+] Fisiere sterse."
echo ""
echo "=================================================="
echo " [+] Curatare completa finalizata cu succes!"
echo " Poti reinstala CG Convertor de la zero acum."
echo "=================================================="
echo ""
read -p "Apasa Enter pentru a inchide fereastra..."
