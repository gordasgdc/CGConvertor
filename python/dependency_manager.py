"""
dependency_manager.py — verificare + (re)instalare a dependintelor
native ale aplicatiei (in primul rand FFmpeg), organizat modular ca sa
fie usor de extins cu alte componente in viitor. Port 1:1 al arhitecturii
din DependencyManager.swift (Mac) - vezi CLAUDE.md, "Directiva strategica:
panou modular de dependinte", 2026-08-26, standard pentru tot ecosistemul
GDC de-acum.

Pe Windows build-ul ffmpeg.exe bundle-uit vine deja dintr-un build STATIC
(gyan.dev "release-essentials", vezi .github/workflows/build-windows.yml)
- nu are bug-ul de dependinte dylib al variantei Mac (Homebrew), dar
panoul ramane util: verificare transparenta + optiune de reinstalare daca
binarul e vreodata corupt/lipsa, fara sa astepte un fix de aplicatie.
"""

import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import urllib.error
import zipfile

# Vezi comentariul din converter.py — acelasi fix pentru "fereastra
# neagra care clipeste" pe Windows (aici: verificarea ffmpeg/mpv la
# pornirea panoului de dependinte).
_NO_WINDOW = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0

STATE_OK = "ok"
STATE_MISSING = "missing"
STATE_OPTIONAL_MISSING = "optional_missing"
STATE_CHECKING = "checking"
STATE_UNKNOWN = "unknown"

FFMPEG_WINDOWS_URL = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

# mpv (Playerul real-time LUT, 2026-09-05, doar Windows) — NU exista un
# build oficial "libmpv" pentru Windows distribuit ca .zip (doar .7z, prin
# canale comunitare shinchiro/zhongfly, ceea ce ar cere o dependinta noua
# grea doar pentru dezarhivare 7z). In schimb, mpv-player/mpv publica
# PLAYERUL STANDALONE (mpv.exe) ca .zip, sub tag-ul mereu-actualizat
# "git-release" (NU marcat "Latest" pe GitHub — de asta se citeste
# API-ul de release-uri dupa TAG, nu releases/latest). Numele exact al
# fisierului include un hash de commit, se schimba la fiecare build — de
# asta URL-ul de descarcare se citeste DINAMIC din assets[], niciodata
# hardcodat (acelasi principiu ca SelfUpdater-ul aplicatiei insesi).
MPV_RELEASE_API_URL = "https://api.github.com/repos/mpv-player/mpv/releases/tags/git-release"
MPV_ASSET_PATTERN = re.compile(r"^mpv-.*-x86_64-pc-windows-msvc\.zip$")


def _app_support_bin_dir():
    if sys.platform == "win32":
        base = os.environ.get("APPDATA", os.path.expanduser("~"))
        return os.path.join(base, "CGConvertor", "bin")
    return os.path.expanduser("~/Library/Application Support/CGConvertor/bin")


def _mpv_download_dir():
    """[FIX REAL 2026-09-06] `PermissionError [Errno 13]` raportat de
    Cristi la scrierea in `%APPDATA%\\CGConvertor\\bin\\mpv\\` — `%APPDATA%`
    (Roaming) e sincronizat de politici de domeniu/OneDrive pe multe
    instalari Windows si poate fi temporar blocat de indexare/sincronizare
    exact cat un fisier nou e scris acolo. `%LOCALAPPDATA%` NU se
    sincronizeaza niciodata (e explicit local per-masina) — e locul corect
    pentru un binar executabil descarcat, nu pentru date de sincronizat
    intre calculatoare. Foloseste DOAR pentru mpv (ffmpeg ramane pe calea
    veche, neatinsa — nu s-a raportat nicio problema acolo)."""
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA", os.path.expanduser("~"))
        return os.path.join(base, "CGConvertor", "bin")
    return _app_support_bin_dir()


def _copy_with_retry(src, dst, attempts=5, delay_seconds=0.6):
    """[FIX REAL 2026-09-06] Antivirusul de sistem (Windows Defender sau
    orice alt AV real-time) scaneaza sincron orice `.exe` nou scris pe disc
    — pe durata scanarii, orice a doua incercare de scriere/mutare a
    ACELUIASI fisier poate primi `PermissionError [Errno 13]`, tranzitoriu
    (dispare in cateva sute de ms, dupa ce scanarea se termina). O simpla
    reincercare cu pauza scurta intre incercari rezolva marea majoritate a
    acestor cazuri, fara sa ceara userului nimic."""
    last_error = None
    for attempt in range(attempts):
        try:
            shutil.copy2(src, dst)
            return
        except PermissionError as e:
            last_error = e
            if attempt < attempts - 1:
                time.sleep(delay_seconds)
    raise last_error


def _verify_runs(path):
    if not path or not os.path.isfile(path):
        return False
    try:
        result = subprocess.run([path, "-version"], capture_output=True, timeout=10, creationflags=_NO_WINDOW)
        return result.returncode == 0
    except Exception:
        return False


def _find_binary(binary_name):
    """Acelasi ordin de cautare ca MotorFFmpeg.gasesteBinar() (Mac):
    (1) copie descarcata prin acest manager, (2) bundle-uit langa exe
    (PyInstaller/dezvoltare), (3) PATH-ul sistemului."""
    ext = ".exe" if sys.platform == "win32" else ""
    filename = f"{binary_name}{ext}"

    downloaded = os.path.join(_app_support_bin_dir(), filename)
    if os.path.isfile(downloaded):
        return downloaded

    if getattr(sys, "frozen", False):
        base_path = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
        bundled = os.path.join(base_path, filename)
        if os.path.isfile(bundled):
            return bundled

    return shutil.which(binary_name)


def find_ffmpeg():
    return _find_binary("ffmpeg")


def find_ffprobe():
    return _find_binary("ffprobe")


def find_mpv():
    """[2026-09-06] De la acest build, mpv.exe e BUNDLE-UIT direct in
    instalator (vezi build-windows.spec + .github/workflows/build-windows.yml)
    — marea majoritate a userilor nu mai ajung NICIODATA la descarcarea de
    mai jos, deci nici la bug-ul de permisiuni raportat pe ea. Cautarea
    verifica DE-ACUM bundle-ul INTAI (motivul principal, mereu functional,
    fara retea), apoi o copie descarcata anterior (fallback pentru userii
    care au deja o instalare veche, ne-bundle-uita), apoi PATH-ul de sistem."""
    if sys.platform != "win32":
        return None
    if getattr(sys, "frozen", False):
        base_path = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
        bundled = os.path.join(base_path, "mpv", "mpv.exe")
        if os.path.isfile(bundled):
            return bundled
    for base_dir in (_mpv_download_dir(), _app_support_bin_dir()):
        downloaded = os.path.join(base_dir, "mpv", "mpv.exe")
        if os.path.isfile(downloaded):
            return downloaded
    return shutil.which("mpv")


class DependencyItem:
    def __init__(self, item_id, name, is_optional, check_fn, action_fn=None, action_label=""):
        self.id = item_id
        self.name = name
        self.is_optional = is_optional
        self.check_fn = check_fn
        self.action_fn = action_fn
        self.action_label = action_label
        self.state = STATE_UNKNOWN


def _check_ffmpeg():
    return STATE_OK if _verify_runs(find_ffmpeg()) else STATE_MISSING


def _verify_mpv_runs(path):
    if not path or not os.path.isfile(path):
        return False
    try:
        # mpv foloseste "--version" (dublu liniuta) - spre deosebire de
        # ffmpeg, "-v" la mpv inseamna verbose, nu versiune.
        result = subprocess.run([path, "--version"], capture_output=True, timeout=10, creationflags=_NO_WINDOW)
        return result.returncode == 0
    except Exception:
        return False


def _check_mpv():
    return STATE_OK if _verify_mpv_runs(find_mpv()) else STATE_OPTIONAL_MISSING


def _check_homebrew():
    # Homebrew e specific Mac - pe Windows nu se aplica deloc, dar
    # componenta ramane in lista (vezi build_items()) doar pe Mac.
    candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    return STATE_OK if any(os.path.isfile(p) and os.access(p, os.X_OK) for p in candidates) else STATE_OPTIONAL_MISSING


class DependencyManager:
    """Instanta unica, folosita din main.py — lista de componente e
    construita o singura data, fiecare cu propriul check headless."""

    def __init__(self):
        self.items = self._build_items()
        self.is_downloading = False
        self.download_error = None

    def _build_items(self):
        items = [
            DependencyItem("ffmpeg", "FFmpeg", is_optional=False,
                            check_fn=_check_ffmpeg,
                            action_fn=self.download_and_install_ffmpeg,
                            action_label=None),  # setat din translations, la afisare
        ]
        if sys.platform == "darwin":
            items.append(DependencyItem("homebrew", "Homebrew", is_optional=True,
                                         check_fn=_check_homebrew,
                                         action_fn=None, action_label=None))
        if sys.platform == "win32":
            # Optional (nu blocheaza bulina globala 🔴/🟢) — necesar DOAR
            # pentru playerul real-time cu LUT live (2026-09-05); restul
            # aplicatiei (conversie, offload, metadata) nu are nevoie de mpv.
            items.append(DependencyItem("mpv", "mpv", is_optional=True,
                                         check_fn=_check_mpv,
                                         action_fn=self.download_and_install_mpv,
                                         action_label=None))
        return items

    def refresh_all(self):
        for item in self.items:
            item.state = STATE_CHECKING
        for item in self.items:
            item.state = item.check_fn()

    @property
    def is_ready(self):
        return all(item.state == STATE_OK for item in self.items if not item.is_optional)

    def download_and_install_ffmpeg(self, progress_callback=None):
        """Descarca build-ul static Windows (gyan.dev essentials — acelasi
        folosit si de CI) si il instaleaza in App Data\\CGConvertor\\bin.
        Ruleaza SINCRON — apelantul (main.py) o porneste intr-un thread
        separat, la fel ca la conversie."""
        self.is_downloading = True
        self.download_error = None
        try:
            dest_dir = _app_support_bin_dir()
            os.makedirs(dest_dir, exist_ok=True)

            with tempfile.TemporaryDirectory() as tmp:
                zip_path = os.path.join(tmp, "ffmpeg.zip")
                request = urllib.request.Request(FFMPEG_WINDOWS_URL, headers={"User-Agent": "CGConvertor-DependencyManager"})
                with urllib.request.urlopen(request, timeout=120) as response, open(zip_path, "wb") as out:
                    shutil.copyfileobj(response, out)

                with zipfile.ZipFile(zip_path) as zf:
                    zf.extractall(tmp)

                extracted_root = next(
                    (os.path.join(tmp, d) for d in os.listdir(tmp) if d.startswith("ffmpeg-") and os.path.isdir(os.path.join(tmp, d))),
                    None,
                )
                if not extracted_root:
                    raise RuntimeError("Arhiva descărcată nu conține folderul așteptat.")

                bin_dir = os.path.join(extracted_root, "bin")
                for name in ("ffmpeg.exe", "ffprobe.exe"):
                    src = os.path.join(bin_dir, name)
                    if not os.path.isfile(src):
                        raise RuntimeError(f"Arhiva nu conține {name}.")
                    shutil.copy2(src, os.path.join(dest_dir, name))

            item = next((i for i in self.items if i.id == "ffmpeg"), None)
            if item:
                item.state = item.check_fn()
        except (urllib.error.URLError, OSError, RuntimeError, zipfile.BadZipFile) as e:
            self.download_error = str(e)
        finally:
            self.is_downloading = False

    def download_and_install_mpv(self, progress_callback=None):
        """Descarca playerul standalone mpv.exe (build-ul oficial
        mpv-player/mpv, tag "git-release" — vezi comentariul de la
        MPV_RELEASE_API_URL de ce URL-ul exact se citeste dinamic din
        assets[], niciodata hardcodat) si il instaleaza in App Data\\
        CGConvertor\\bin\\mpv\\. Necesar DOAR pentru playerul real-time cu
        LUT live (`lut_player.py`) — restul aplicatiei nu-l foloseste.
        Ruleaza SINCRON — apelantul (main.py/dependency_panel.py) o
        porneste intr-un thread separat, la fel ca la ffmpeg."""
        self.is_downloading = True
        self.download_error = None
        try:
            request = urllib.request.Request(MPV_RELEASE_API_URL, headers={"User-Agent": "CGConvertor-DependencyManager"})
            with urllib.request.urlopen(request, timeout=30) as response:
                release = json.load(response)

            asset = next(
                (a for a in release.get("assets", []) if MPV_ASSET_PATTERN.match(a.get("name", ""))),
                None,
            )
            if not asset:
                raise RuntimeError("Nu s-a găsit un asset mpv.exe (x86_64, msvc) în release-ul GitHub.")

            # [FIX REAL 2026-09-06] `%LOCALAPPDATA%`, nu `%APPDATA%` — vezi
            # comentariul din `_mpv_download_dir()`.
            dest_dir = os.path.join(_mpv_download_dir(), "mpv")
            os.makedirs(dest_dir, exist_ok=True)

            with tempfile.TemporaryDirectory() as tmp:
                # BUG REAL gasit la testare (2026-09-05): descarcarea
                # arhivei DIRECT in `tmp`, apoi extractall() TOT in `tmp`,
                # lasa fisierul .zip insusi alaturi de continutul extras —
                # cum arhiva oficiala e "plata" (mpv.exe la radacina, fara
                # subfolder), bucla de copiere de mai jos ("tot ce e in
                # source_dir") copia din greseala si `mpv.zip` in
                # instalarea finala. Fix: zip-ul descarcat traieste in
                # `tmp` insusi, extractia merge intr-un SUBfolder dedicat.
                zip_path = os.path.join(tmp, "mpv.zip")
                dl_request = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": "CGConvertor-DependencyManager"})
                with urllib.request.urlopen(dl_request, timeout=120) as response, open(zip_path, "wb") as out:
                    shutil.copyfileobj(response, out)

                extract_dir = os.path.join(tmp, "extracted")
                os.makedirs(extract_dir, exist_ok=True)
                with zipfile.ZipFile(zip_path) as zf:
                    zf.extractall(extract_dir)

                # Arhiva oficiala e "plata" (mpv.exe direct la radacina a
                # extractiei, fara subfolder), dar cautam recursiv ca plasa
                # de siguranta daca formatul se schimba vreodata intr-un
                # build viitor.
                mpv_exe = None
                for root, _dirs, files in os.walk(extract_dir):
                    if "mpv.exe" in files:
                        mpv_exe = os.path.join(root, "mpv.exe")
                        source_dir = root
                        break
                if not mpv_exe:
                    raise RuntimeError("Arhiva descărcată nu conține mpv.exe.")

                for name in os.listdir(source_dir):
                    src = os.path.join(source_dir, name)
                    if os.path.isfile(src):
                        _copy_with_retry(src, os.path.join(dest_dir, name))

            item = next((i for i in self.items if i.id == "mpv"), None)
            if item:
                item.state = item.check_fn()
        except (urllib.error.URLError, OSError, RuntimeError, zipfile.BadZipFile, json.JSONDecodeError) as e:
            self.download_error = str(e)
        finally:
            self.is_downloading = False

    @staticmethod
    def homebrew_install_command():
        return '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
