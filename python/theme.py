# theme.py
import sys

DARK = {
    "bg": "#1a1a1a",
    "bg_panel": "#222222",
    "bg_elevated": "#2a2a2a",
    "fg": "#e8e8e8",
    "fg_dim": "#9a9a9a",
    "accent": "#c79a3d",
    "accent_hover": "#e0b458",
    "success": "#5c9b79",
    "error": "#d16b5c",
    "line": "#3a3a3a",
}

LIGHT = {
    "bg": "#f4f4f4",
    "bg_panel": "#ffffff",
    "bg_elevated": "#ececec",
    "fg": "#1a1a1a",
    "fg_dim": "#6a6a6a",
    "accent": "#a97b1f",
    "accent_hover": "#c79a3d",
    "success": "#3f7d5c",
    "error": "#b5493a",
    "line": "#d5d5d5",
}

FONT_MONO = "Menlo" if sys.platform == "darwin" else "Consolas"
FONT_FAMILY = "Helvetica" if sys.platform == "darwin" else "Segoe UI"

def get(dark_mode: bool):
    return DARK if dark_mode else LIGHT
