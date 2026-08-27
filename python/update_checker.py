"""
update_checker.py — verificare manuala/automata de versiune noua pentru
CG Convertor, citind ultimul tag de pe GitHub Releases (acelasi API pe
care il foloseste varianta Swift, UpdateChecker.swift — nu update.json,
CG Convertor nu are unul separat). Nu e updater silentios/automat — doar
anunta si ofera un link de descarcare, la fel ca restul ecosistemului GDC.
"""

import json
import re
import urllib.request
import urllib.error

LATEST_RELEASE_API_URL = "https://api.github.com/repos/gordasgdc/CGConvertor/releases/latest"
RELEASES_PAGE_URL = "https://github.com/gordasgdc/CGConvertor/releases/latest"


def _version_tuple(version_string):
    parts = []
    for piece in re.split(r"[.\-]", version_string.strip().lstrip("vV")):
        match = re.match(r"\d+", piece)
        parts.append(int(match.group()) if match else 0)
    return tuple(parts) if parts else (0,)


def is_newer_version(candidate, current):
    return _version_tuple(candidate) > _version_tuple(current)


def check_for_updates(current_version, timeout=10):
    """Intoarce {"available": bool, "version": str|None, "download_url": str|None, "error": str|None}.

    `download_url` e link-ul DIRECT al asset-ului installer-ului
    (`CGConvertor-Windows-Setup.exe`, nume stabil publicat de CI la
    fiecare release) - folosit de self_updater.py, NU de un browser.
    Vezi CLAUDE.md Partea 1, Regula 20.
    """
    try:
        request = urllib.request.Request(
            LATEST_RELEASE_API_URL,
            headers={"User-Agent": "CGConvertor-Updater", "Accept": "application/vnd.github+json"},
        )
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = json.loads(response.read().decode("utf-8"))
        tag = str(data.get("tag_name", "")).strip()
        if not tag:
            return {"available": False, "error": "Raspuns invalid de la GitHub."}
        latest = tag[1:] if tag.lower().startswith("v") else tag
        if is_newer_version(latest, current_version):
            download_url = None
            for asset in data.get("assets", []):
                if asset.get("name") == "CGConvertor-Windows-Setup.exe":
                    download_url = asset.get("browser_download_url")
                    break
            return {"available": True, "version": latest, "download_url": download_url, "error": None}
        return {"available": False, "error": None}
    except urllib.error.URLError as e:
        return {"available": False, "error": f"Nu am putut contacta GitHub: {e.reason}"}
    except Exception as e:
        return {"available": False, "error": str(e)}
