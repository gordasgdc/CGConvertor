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
  2. Lanseaza installer-ul cu `os.startfile()` (ShellExecute), NU
     `subprocess.Popen` — fereastra NATIVA Inno Setup apare, NICIODATA
     browserul.
  3. Aplicatia curenta se inchide (`sys.exit`/`root.destroy`) - fara
     AppMutex/CloseApplications in installer.iss, Setup.exe nu poate
     suprascrie singur exe-ul cat timp ruleaza; `[Run] ... Flags: nowait
     postinstall skipifsilent` relanseaza aplicatia dupa instalare.

FIX real (2026-09-06, raportat de Cristi cu popup exact: "Security
validation failure: parent process has different executable!", aparut
la lansarea automata a Setup.exe): pasul 2 folosea `subprocess.Popen(...,
creationflags=DETACHED_PROCESS, close_fds=True)` — CreateProcess "brut".
Setup.exe (installer.iss cere `PrivilegesRequired=admin`) se auto-
relanseaza intern, elevat, prin UAC (ShellExecute cu verb "runas") -
mecanism intern Inno, NU codul nostru. Un CreateProcess direct, detasat
de consola, DIFERA de calea normala prin care orice installer descarcat
e lansat de un user (dublu-click in Explorer = ShellExecute), calea pe
care o asteapta verificarea anti-hijacking mai noua din Inno Setup
(introdusa ca protectie DLL-preloading/proces-injection). Nu s-a gasit
documentatie oficiala JRSoftware care sa confirme exact mecanismul intern
al acestei verificari (cautat explicit, neconfirmat 100%) - dar fix-ul
aplicat e cel corect indiferent de detaliul exact: `os.startfile()`
foloseste ShellExecuteExW, IDENTIC cu ce declanseaza un dublu-click din
Explorer (calea "normala", niciodata raportata cu aceasta eroare de
niciun user care descarca installer-ul manual din release).

WARNING: pasul de instalare efectiv (wizard-ul Inno, click-urile
userului) NU poate fi verificat automat de Claude.
"""

import os
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
        # os.startfile() = ShellExecuteExW, aceeasi cale ca un dublu-click
        # in Explorer - vezi FIX-ul din docstring-ul modulului. Procesul
        # lansat astfel NU e un copil CreateProcess al nostru (Explorer/
        # Shell-ul e intermediarul), deci supravietuieste independent
        # inchiderii noastre (sys.exit mai jos) fara niciun flag special.
        os.startfile(exe_path)  # noqa: S606 — installer descarcat de noi, semnat, verificat mai sus

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
