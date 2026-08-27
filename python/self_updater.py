"""
self_updater.py - descarca si lanseaza automat installer-ul de update pe
Windows, fara sa mai treaca prin browser/pagina de GitHub. Vezi CLAUDE.md
Partea 1, Regula 20 - portul Python al SelfUpdater.swift/.cs din
GDCVault/GDCPluginManagerWin (adaptat la stack-ul Tkinter/PyInstaller al
acestei aplicatii).

Flux:
  1. Descarca `download_url` (CGConvertor-Windows-Setup.exe, nume stabil)
     cu urllib direct pe disc, in %TEMP%, redenumit cu versiunea
     (Regula 17).
  2. Lanseaza installer-ul (`subprocess.Popen`, fara sa astepte) -
     fereastra NATIVA Inno Setup apare, NICIODATA browserul.
  3. Aplicatia curenta se inchide (`sys.exit`/`root.destroy`) - fara
     AppMutex/CloseApplications in installer.iss, Setup.exe nu poate
     suprascrie singur exe-ul cat timp ruleaza; `[Run] ... Flags: nowait
     postinstall skipifsilent` relanseaza aplicatia dupa instalare.

WARNING: pasul de instalare efectiv (wizard-ul Inno, click-urile
userului) NU poate fi verificat automat de Claude.
"""

import os
import subprocess
import sys
import tempfile
import urllib.request
import urllib.error


class UpdateError(Exception):
    pass


def download_and_install(download_url, version, on_status=None, on_done=None):
    """Descarca si lanseaza installer-ul intr-un thread separat (apelantul
    e responsabil sa porneasca thread-ul - vezi main.py). `on_status(text)`
    si `on_done(error_or_none)` sunt apelate din acest thread; apelantul
    trebuie sa le marshaling-uiasca pe thread-ul UI (ex. `self.after(0, ...)`).
    """
    try:
        if not download_url:
            raise UpdateError("Lipsește link-ul de descărcare pentru Windows în release-ul GitHub.")

        if on_status:
            on_status("downloading")
        tmp_dir = tempfile.mkdtemp(prefix="cgconvertor-update-")
        exe_path = os.path.join(tmp_dir, f"CGConvertor-Setup-{version}.exe")
        _download(download_url, exe_path)

        if on_status:
            on_status("launching")
        # DETACHED_PROCESS: installer-ul supravietuieste dupa ce procesul
        # nostru se inchide (sys.exit mai jos) - fara asta, pe Windows
        # copilul ar putea fi omorat odata cu parintele in unele configuratii.
        creationflags = subprocess.DETACHED_PROCESS if sys.platform == "win32" else 0
        subprocess.Popen([exe_path], creationflags=creationflags, close_fds=True)

        if on_done:
            on_done(None)
    except Exception as e:
        if on_done:
            on_done(e)


def _download(url, destination):
    request = urllib.request.Request(url, headers={"User-Agent": "CGConvertor-Updater"})
    try:
        with urllib.request.urlopen(request, timeout=300) as response, open(destination, "wb") as out_file:
            while True:
                chunk = response.read(1024 * 256)
                if not chunk:
                    break
                out_file.write(chunk)
    except urllib.error.URLError as e:
        raise UpdateError(f"Descărcarea a eșuat: {e.reason}") from e
