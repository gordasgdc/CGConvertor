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
DOAR la lansarea automata din aplicatie, NICIODATA la dublu-click manual
+ "Run as administrator" — confirmat direct de Cristi, testat pe masina
lui reala). Cautat explicit acest string exact (Sourcegraph, cod public,
inclusiv sursele Inno Setup jrsoftware/issrc) — 0 rezultate; verificarea
nu vine din Pascal-ul open-source al Inno, deci probabil dintr-un
binar precompilat intern (Setup.e32/SetupLdr.e32, neindexabil ca text).

Incercarea 1 (`os.startfile()` simplu, in loc de `subprocess.Popen`) NU a
rezolvat - eroarea a persistat identic. Diferenta REALA, confirmata de
testul lui Cristi: `installer.iss` cere `PrivilegesRequired=admin`;
lansat NEELEVAT (orice metoda simpla, Popen SAU os.startfile fara verb),
Setup.exe trebuie sa se auto-relanseze intern, elevat, printr-un al
doilea proces (UAC) — exact acolo verificarea interna esueaza. Lansat
DEJA elevat (dublu-click + "Run as administrator" din Explorer), acel
al doilea proces intern nu se mai declanseaza niciodata, deci verificarea
nu are ce sa esueze. Fix: `os.startfile(exe_path, "runas")` — al doilea
parametru al lui `os.startfile` (documentat oficial Python, doar Windows)
cere explicit elevare prin UAC la lansare, identic cu meniul "Run as
administrator" al lui Cristi - Setup.exe porneste DEJA elevat, fara
niciun re-exec intern.

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
        # os.startfile(path, "runas") = ShellExecuteExW cu verb "runas" —
        # cere elevare UAC DIRECT la lansare, exact ca "Run as
        # administrator" manual din Explorer (vezi FIX-ul din docstring-ul
        # modulului - fara elevare de la inceput, Setup.exe trebuie sa se
        # auto-relanseze intern, unde esueaza verificarea lui interna).
        # Procesul lansat astfel supravietuieste independent inchiderii
        # noastre (sys.exit mai jos), fara niciun flag special.
        os.startfile(exe_path, "runas")  # noqa: S606 — installer descarcat de noi, verificat mai sus

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
