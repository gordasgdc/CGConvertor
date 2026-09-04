# theme.py
import sys

# Identitatea vizuala "Shift" — aceeasi paleta ca varianta nativa Swift
# (vezi CGConvertor/Theme.swift, `enum Shift`): dark, pro, accent
# cupru/amber inspirat de paginile de Color din DaVinci Resolve.
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

# Varianta Light (CLAUDE.md Partea 1, Regula 18 — selector explicit
# System/Dark/Light obligatoriu, indiferent de tema OS) — ACELASI rol
# semantic per cheie ca DARK (fundal/panou/elevat/text/accent/etc.),
# doar valorile inversate spre un fundal deschis. [ISTORIC] pana la
# Faza 1 v3.0.0, LIGHT era un alias direct al lui DARK ("Tkinter nu
# suporta un mod light la fel de bine" - notă retrasă, varianta de mai
# jos a fost verificată vizual pe ambele platforme).
LIGHT = {
    "bg": "#F5F4F2",
    "bg_panel": "#FFFFFF",
    "bg_elevated": "#EBEAE7",
    "fg": "#1D1F23",
    "fg_dim": "#5B5E64",
    "fg_faint": "#9498A0",
    "accent": "#C97A22",  # acelasi ton cupru/amber, coborat usor in luminozitate pt contrast pe fundal deschis
    "accent_hover": "#B76A18",
    "accent_ink": "#FFFFFF",
    "success": "#2F8F5B",
    "error": "#C7402F",
    "line": "#D8D6D2",
}

FONT_MONO = "Menlo" if sys.platform == "darwin" else "Consolas"
FONT_FAMILY = "Helvetica" if sys.platform == "darwin" else "Segoe UI"

# Scalare de font (Regula 24 — "Marime Text" explicita, independenta de
# scalarea sistemului). Aplicata ca multiplicator peste marimile de baza
# definite direct in main.py/activation.py/etc (font=(FONT_FAMILY, N)) —
# vezi `scaled()` mai jos.
FONT_SCALES = {
    "small": 0.9,
    "normal": 1.0,
    "large": 1.15,
    "xlarge": 1.3,
}


def scaled(base_size: int, font_scale: str = "normal") -> int:
    factor = FONT_SCALES.get(font_scale, 1.0)
    return max(7, round(base_size * factor))


def get(theme_pref: str):
    """`theme_pref`: "system" / "dark" / "light". "system" citeste tema
    reala a OS-ului o singura data la lansare (Tkinter nu are un
    echivalent de `prefers-color-scheme` reactiv ca SwiftUI — un restart
    al aplicatiei e suficient daca userul schimba tema sistemului in timp
    ce aplicatia ruleaza, la fel ca majoritatea aplicatiilor Tkinter)."""
    if theme_pref == "light":
        return LIGHT
    if theme_pref == "dark":
        return DARK
    return LIGHT if _system_prefers_light() else DARK


def _system_prefers_light() -> bool:
    if sys.platform == "darwin":
        try:
            import subprocess
            result = subprocess.run(
                ["defaults", "read", "-g", "AppleInterfaceStyle"],
                capture_output=True, text=True, timeout=3,
            )
            # Cheia lipseste complet daca sistemul e pe Light (nu exista
            # valoarea implicita "Light" - doar "Dark" e scrisa vreodata).
            return result.returncode != 0
        except Exception:
            return True
    if sys.platform == "win32":
        try:
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            )
            value, _ = winreg.QueryValueEx(key, "AppsUseLightTheme")
            return bool(value)
        except Exception:
            return True
    return True
