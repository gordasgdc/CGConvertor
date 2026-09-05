# config.py
import json
import os
import sys
from pathlib import Path

# Sursa unica de adevar pentru versiunea afisata in UI si trimisa la
# actualizare de versiune (build-windows.spec / build-mac.spec citesc tot
# de-aici, prin --version, la fiecare tag nou) — actualizeaza aici la
# fiecare "git tag vX.Y.Z", sincron cu MARKETING_VERSION din varianta Swift.
APP_VERSION = "3.8.0"

def _config_dir():
    """Folder de configurare specific platformei."""
    if sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "CGConvertor"
    elif sys.platform == "win32":
        base = Path(os.environ.get("APPDATA", Path.home())) / "CGConvertor"
    else:
        base = Path.home() / ".config" / "CGConvertor"
    base.mkdir(parents=True, exist_ok=True)
    return base

def config_dir():
    """Alias public al `_config_dir()` — folosit de alte module
    (presets_manager.py) care au nevoie de acelasi folder de configurare,
    fara sa importe o functie cu nume "privat" peste granita de modul."""
    return _config_dir()

CONFIG_PATH = _config_dir() / "settings.json"

DEFAULTS = {
    "language": "ro",
    "dark_mode": True,
    "theme_pref": "system",       # "system" / "dark" / "light" — Regula 18
    "font_scale": "normal",       # "small" / "normal" / "large" / "xlarge" — Regula 24
    "gpu_vendor_override": "",    # "" = automat (gpu_probe.detect()), altfel un id din gpu_probe
    "max_parallel_jobs": 1,
    "last_destination": "",
    "last_preset_id": "builtin_rewrap",
    "user_name": "",
    "user_email": "",
    "watch_folders": [],          # [{"path": str, "enabled": bool}, ...] — Faza 2, Watch Folders
}

def load():
    if CONFIG_PATH.exists():
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            merged = DEFAULTS.copy()
            merged.update(data)
            return merged
        except (json.JSONDecodeError, OSError):
            pass
    return DEFAULTS.copy()

def save(settings):
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=2, ensure_ascii=False)
    except OSError:
        pass
