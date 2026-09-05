# volume_info.py
"""Discuri/carduri montate — port al `list_mounted_volumes()` din
`~/Developer/DataMover/core/offload_engine.py`, extins cu nume afișabil +
spațiu liber per volum (echivalentul Windows al `VolumeInfo.swift` din
CGConvertor/DataMover Mac). Preluat la cererea explicită a lui Cristi
(repetată de două ori): panoul Offload trebuie să arate discurile reale,
nu doar un câmp de path text simplu."""

import ctypes
import os
import platform
import shutil
import string


def _free_bytes(path):
    try:
        return shutil.disk_usage(path).free
    except OSError:
        return None


def format_bytes(n):
    if n is None:
        return "—"
    n = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


def _windows_volume_label(drive):
    """Eticheta volumului (ex. "SANDISK128") via GetVolumeInformationW —
    fallback tacut pe litera de drive daca nu poate fi citita (card gol,
    fara label, sau eroare API)."""
    try:
        buf = ctypes.create_unicode_buffer(261)
        ok = ctypes.windll.kernel32.GetVolumeInformationW(
            ctypes.c_wchar_p(drive), buf, ctypes.sizeof(buf),
            None, None, None, None, 0)
        if ok and buf.value:
            return buf.value
    except Exception:
        pass
    return drive.rstrip("\\")


def list_volumes():
    """Intoarce o lista de dict-uri {name, path, free_bytes}, sortata dupa
    nume — macOS (/Volumes), Windows (litere de drive, exclus C:\\ — de
    obicei discul de sistem, ca sa evidentiem carduri/drive-uri externe),
    sau lista goala pe alte sisteme/erori (fail-open, nu o eroare)."""
    system = platform.system()
    result = []

    if system == "Darwin":
        volumes_dir = "/Volumes"
        if os.path.isdir(volumes_dir):
            try:
                for name in sorted(os.listdir(volumes_dir)):
                    full = os.path.join(volumes_dir, name)
                    if os.path.isdir(full):
                        result.append({"name": name, "path": full, "free_bytes": _free_bytes(full)})
            except OSError:
                pass
    elif system == "Windows":
        try:
            bitmask = ctypes.windll.kernel32.GetLogicalDrives()
            for i, letter in enumerate(string.ascii_uppercase):
                if bitmask & (1 << i) and letter != "C":
                    drive = f"{letter}:\\"
                    if os.path.exists(drive):
                        label = _windows_volume_label(drive)
                        name = f"{label} ({letter}:)" if label != letter else f"{letter}:"
                        result.append({"name": name, "path": drive, "free_bytes": _free_bytes(drive)})
        except Exception:
            pass
    else:
        for base in (f"/media/{os.environ.get('USER', '')}", "/media", "/mnt"):
            if base and os.path.isdir(base):
                try:
                    for name in sorted(os.listdir(base)):
                        full = os.path.join(base, name)
                        if os.path.isdir(full):
                            result.append({"name": name, "path": full, "free_bytes": _free_bytes(full)})
                except OSError:
                    pass

    return sorted(result, key=lambda v: v["name"].lower())
