# lut_player.py
"""Playerul real-time LUT/LOG pe Windows (2026-09-05) — arhitectură
DIFERITĂ față de Mac (`LUTPlayerSheet.swift`, AVFoundation), fiindcă
Windows/Tkinter nu are un echivalent nativ gratuit: `mpv.exe` (descărcat
opțional prin `dependency_manager.py`, vezi `find_mpv()`) rulat ca
subproces, ÎNCORPORAT în fereastra Tkinter prin `--wid=<hwnd>` —
`Frame.winfo_id()` întoarce direct handle-ul nativ de fereastră pe
Windows (spre deosebire de X11/macOS, unde ar fi doar un id logic Tk).

Redarea, audio-ul, scrubbing-ul și play/pause rămân EXCLUSIV controalele
native mpv (OSC — apar la mișcarea mouse-ului peste video) — NICIO
reimplementare Tkinter a transportului (decizie de scop confirmată
explicit înainte de implementare, AskUserQuestion). Python trimite DOAR
comenzi ONE-WAY (fără să aștepte/citească răspuns) către pipe-ul IPC al
mpv, pentru schimbarea LUT-ului — IPC bidirecțional pe Windows ar cere
`pywin32`/overlapped I/O (documentat ca fragil fără el, vezi CLAUDE.md),
evitat deliberat pentru acest scop redus.

WARNING, nu încă verificat interactiv (necesită mașina Windows reală a
lui Cristi, Parallels): sintaxa exactă a filtrului mpv (`lavfi=[lut3d=
file=...]`, confirmată din documentația oficială mpv/FFmpeg, nu din
presupunere) și comportamentul embed-ului `--wid` sub un build PyInstaller
înghețat rămân de confirmat manual, o dată, înainte de a declara feature-ul
complet dovedit — la fel ca restul funcționalităților Windows din acest
repo care au necesitat testare reală pe Parallels.
"""

import json
import os
import subprocess
import sys
import tempfile
import tkinter as tk
from tkinter import filedialog, ttk

from dependency_manager import find_mpv

# Fix (2026-09-06, raportat de Cristi, testat pe Windows real): fara
# "--vo" explicit, mpv face auto-probe intre driverele de output video
# disponibile — in contextul de embed printr-un HWND strain (`--wid`,
# vezi mai jos), auto-probe-ul alege des un vo care nu poate desena in
# fereastra Tkinter primita (ecran negru, audio se aude, NICIUN control
# OSC vizibil fiindca OSC se randeaza peste suprafata video, care nu
# exista).
#
# Incercarea initiala (`--vo=gpu-next,gpu,direct3d11,gdi`) NU a rezolvat
# complet - Cristi a semnalat corect cauza suplimentara: testeaza pe
# Windows RULAT IN PARALLELS (deja mentionat in avertismentul de mai sus,
# scris inainte sa apara acest bug), deci placa grafica e VIRTUALIZATA
# (Parallels Display Adapter), cu suport partial/neconform pentru
# compunere GPU D3D11/OpenGL - initializarea "reuseste" (mpv nu trece la
# urmatoarea optiune din lista), dar randeaza gresit (dreptunghi gri
# suprapus peste negru = cadru de compunere GPU corupt, simptom clasic
# de driver grafic de VM). "--vo" accepta o LISTA prioritara separata
# prin virgula (documentat oficial, man mpv), dar lista NU ajuta aici -
# fix-ul e sa se sara direct la randorul care NU foloseste deloc
# compunere GPU: "--vo=gdi" (blit direct GDI, exact ca desenul obisnuit
# Win32 pe o fereastra - functioneaza identic pe hardware real si pe
# orice placa virtuala de VM/RDP). Decodarea ramane software
# ("--hwdec=no") din acelasi motiv - decodare hardware ar depinde tot de
# driverul GPU (posibil virtualizat) al mediului de rulare; aplicarea
# LUT-ului insasi (`lavfi=[lut3d=...]`) ruleaza deja pe CPU, prin
# libavfilter, deci nu pierde nimic din calitate.
_WINDOWS_MPV_VIDEO_ARGS = [
    "--vo=gdi",
    "--hwdec=no",
] if sys.platform.startswith("win") else []


class LUTPlayerWindow(tk.Toplevel):
    def __init__(self, parent, app, path):
        super().__init__(parent)
        self.app = app
        self.path = path
        self.th = app.th

        self.title(self._t("player_title", name=os.path.basename(path)))
        self.configure(bg=self.th["bg"])
        self.geometry("820x520")
        self.minsize(480, 320)

        self.mpv_process = None
        self.ipc_path = None
        self.lut_path = None

        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        # Mic delay — winfo_id() e valid imediat, dar geometria ferestrei
        # trebuie realizata (update_idletasks) inainte ca hwnd-ul sa
        # corespunda unei zone vizibile reale in care mpv sa randeze.
        self.after(50, self._launch_mpv)

    def _t(self, key, **kwargs):
        from translations import t
        return t(self.app.lang, key, **kwargs)

    def _build_ui(self):
        th = self.th
        header = tk.Frame(self, bg=th["bg_panel"])
        header.pack(fill="x")
        tk.Label(header, text=os.path.basename(self.path), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(12, "bold")).pack(side="left", padx=12, pady=8)

        # Fundal negru — daca mpv nu porneste (dependinta lipsa), zona
        # ramane vizibil goala in loc sa arate ca un bug de layout.
        self.video_frame = tk.Frame(self, bg="black")
        self.video_frame.pack(fill="both", expand=True)

        footer = tk.Frame(self, bg=th["bg_panel"])
        footer.pack(fill="x")
        self.lut_label = tk.Label(footer, text=self._t("preview_no_lut"), bg=th["bg_panel"], fg=th["fg_dim"],
                                   font=self.app._fm(9))
        self.lut_label.pack(side="left", padx=12, pady=8)
        ttk.Button(footer, text=self._t("preview_choose_lut"), style="Ghost.TButton",
                   command=self._choose_lut, cursor="hand2").pack(side="right", padx=(0, 6), pady=8)
        self.clear_lut_btn = ttk.Button(footer, text=self._t("preview_clear_lut"), style="Ghost.TButton",
                                         command=self._clear_lut, cursor="hand2")
        # afisat doar cand exista un LUT ales — vezi _choose_lut/_clear_lut

    def _launch_mpv(self):
        mpv_exe = find_mpv()
        if not mpv_exe:
            tk.Label(self.video_frame, text=self._t("player_mpv_missing"), bg="black", fg=self.th["fg_dim"],
                     wraplength=440, justify="center", font=self.app._f(10)).pack(expand=True)
            return

        self.update_idletasks()
        hwnd = self.video_frame.winfo_id()
        self.ipc_path = rf"\\.\pipe\cgconvertor_mpv_{os.getpid()}_{id(self)}"
        # Diagnostic (2026-09-06, dupa 2 incercari esuate de fix "oarbe"
        # pe combinatia --vo/--hwdec, fara sa avem vreo dovada REALA a
        # motivului pentru care randarea esueaza pe masina lui Cristi -
        # mpv insusi ruleaza cu consola ascunsa (`CREATE_NO_WINDOW` mai
        # jos), deci orice mesaj de eroare al lui era pierdut, invizibil,
        # atat pentru user cat si pentru noi. `--log-file` + verbozitate
        # scriu jurnalul REAL al mpv intr-un fisier - urmatorul raport
        # trebuie sa includa continutul lui, nu o alta presupunere.
        self.mpv_log_path = os.path.join(tempfile.gettempdir(), f"cgconvertor_mpv_{os.getpid()}.log")

        args = [
            mpv_exe,
            f"--wid={hwnd}",
            f"--input-ipc-server={self.ipc_path}",
            f"--log-file={self.mpv_log_path}",
            "--msg-level=all=v",
            *_WINDOWS_MPV_VIDEO_ARGS,
            "--osc=yes",
            "--keep-open=yes",
            "--border=no",
            "--force-window=yes",
            self.path,
        ]
        creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        try:
            self.mpv_process = subprocess.Popen(args, creationflags=creationflags)
        except OSError:
            self.mpv_process = None
            return
        # Daca mpv moare imediat (crash la pornire, argument invalid etc.),
        # aratam explicit eroarea + calea jurnalului, in loc sa lasam
        # fereastra neagra "muta" sa para doar un bug de randare tacut.
        self.after(1500, self._check_mpv_alive)

    def _check_mpv_alive(self):
        if self.mpv_process and self.mpv_process.poll() is not None:
            for widget in self.video_frame.winfo_children():
                widget.destroy()
            tk.Label(self.video_frame, bg="black", fg=self.th["fg_dim"], justify="center",
                     wraplength=440, font=self.app._f(10),
                     text=self._t("player_mpv_crashed", log_path=self.mpv_log_path)).pack(expand=True)

    def _send_ipc_command(self, command_list):
        """Trimite o comanda JSON one-way catre mpv, prin named pipe —
        NU asteapta/citeste raspuns (vezi nota de arhitectura din
        docstring-ul modulului: IPC bidirectional pe Windows ar cere
        pywin32/overlapped I/O). Esec silentios daca pipe-ul nu exista
        inca sau mpv s-a inchis intre timp — nu blocheaza UI-ul niciodata."""
        if not self.ipc_path:
            return
        try:
            payload = json.dumps({"command": command_list}).encode("utf-8") + b"\n"
            with open(self.ipc_path, "wb", buffering=0) as pipe:
                pipe.write(payload)
        except OSError:
            pass

    def _choose_lut(self):
        path = filedialog.askopenfilename(filetypes=[("LUT .cube", "*.cube")])
        if not path:
            return
        self.lut_path = path
        self.lut_label.config(text=os.path.basename(path))
        self.clear_lut_btn.pack(side="right", padx=(0, 6), pady=8)
        self._apply_lut(path)

    def _clear_lut(self):
        self.lut_path = None
        self.lut_label.config(text=self._t("preview_no_lut"))
        self.clear_lut_btn.pack_forget()
        self._send_ipc_command(["vf", "set", ""])

    def _apply_lut(self, lut_path):
        # Filtrul `lut3d` nu e nativ mpv — se aplica prin puntea `lavfi`
        # catre FFmpeg's libavfilter (confirmat direct din documentatia
        # oficiala mpv, vf.rst — mpv NU are propriul lut3d). Escaparea
        # caii (backslash->slash, ':' -> '\:') e identica cu cea deja
        # testata pentru ffmpeg in media_inspector.py — aceeasi sintaxa
        # de graf libavfilter, acelasi motiv (litera de disc Windows
        # "C:" ar rupe altfel parsarea bazata pe ':' a filtrului).
        escaped = lut_path.replace("\\", "/").replace(":", "\\:")
        self._send_ipc_command(["vf", "set", f"lavfi=[lut3d=file='{escaped}']"])

    def _on_close(self):
        if self.mpv_process:
            try:
                self.mpv_process.terminate()
            except OSError:
                pass
        self.destroy()
