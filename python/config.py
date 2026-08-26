# config.py
import json
import os
import sys
from pathlib import Path

# Sursa unica de adevar pentru versiunea afisata in UI si trimisa la
# actualizare de versiune (build-windows.spec / build-mac.spec citesc tot
# de-aici, prin --version, la fiecare tag nou) — actualizeaza aici la
# fiecare "git tag vX.Y.Z", sincron cu MARKETING_VERSION din varianta Swift.
APP_VERSION = "2.0.0"

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

CONFIG_PATH = _config_dir() / "settings.json"

DEFAULTS = {
    "language": "ro",
    "dark_mode": True,
    "last_destination": "",
    "last_mode": "rewrap",
    "last_codec": "ProRes 422 HQ",
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
