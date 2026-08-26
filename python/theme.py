# theme.py
import sys

# Identitatea vizuala "Shift" — aceeasi paleta ca varianta nativa Swift
# (vezi CGConvertor/Theme.swift, `enum Shift`): dark, pro, accent
# cupru/amber inspirat de paginile de Color din DaVinci Resolve. Tkinter
# nu suporta un mod "light" la fel de bine ca SwiftUI in acest caz — de
# aceea ramane doar varianta dark, mereu (settings["dark_mode"] e pastrat
# pentru compatibilitate cu fisiere de config vechi, dar LIGHT nu se mai
# foloseste activ).
DARK = {
    "bg": "#14161A",
    "bg_panel": "#1A1D22",
    "bg_elevated": "#23262C",
    "fg": "#EDEFF2",
    "fg_dim": "#93989F",
    "fg_faint": "#5C6169",
    "accent": "#E8963C",
    "accent_hover": "#F2A94F",
    "accent_ink": "#1A1108",
    "success": "#4CAF7D",
    "error": "#E2584A",
    "line": "#2B2F36",
}

LIGHT = DARK  # [ISTORIC] varianta light a fost retrasa odata cu tema Shift — pastrata ca alias, ca fisierele de config vechi (dark_mode=false) sa nu crape.

FONT_MONO = "Menlo" if sys.platform == "darwin" else "Consolas"
FONT_FAMILY = "Helvetica" if sys.platform == "darwin" else "Segoe UI"

def get(dark_mode: bool):
    return DARK
