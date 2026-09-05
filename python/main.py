# main.py
import concurrent.futures
import os
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
    # Testare REALA, nu doar import — pe Windows ARM64 (confirmat live,
    # Parallels pe Apple Silicon), `tkinterdnd2` se importa cu succes dar
    # `TkinterDnD.Tk()` arunca la CONSTRUCTIE ("interpreter uses an
    # incompatible stubs mechanism" / "Unable to load tkdnd library") —
    # biblioteca nativa tkdnd bundle-uita in pachet nu e compatibila cu
    # acest Tcl/Tk. Un simplu try/except pe IMPORT (cum era inainte) nu
    # prindea deloc acest caz — aplicatia crapa abia la lansare, in
    # `CGConvertorApp.__init__`. Se testeaza instantierea reala o
    # singura data, aici, cu o fereastra ascunsa imediat si distrusa —
    # daca esueaza, aplicatia porneste normal, doar fara drag-and-drop
    # (butonul "Alege fisiere..." ramane functional).
    _test_root = TkinterDnD.Tk()
    _test_root.withdraw()
    _test_root.destroy()
    HAS_DND = True
except Exception:
    HAS_DND = False
    # BUG REAL gasit live (Windows ARM64): cand TkinterDnD.Tk() esueaza,
    # `tkinter.Tk.__init__` (clasa de baza) a rulat DEJA cu succes INAINTE
    # ca eroarea specifica tkdnd sa fie aruncata (in linia urmatoare din
    # tkinterdnd2) — acel obiect a fost deja inregistrat ca
    # `tkinter._default_root`, dar noi n-am apucat sa-l atribuim lui
    # `_test_root` (exceptia intrerupe chiar acea linie), deci ramane
    # ORFAN: "viu" la nivel de interpretor Tcl, fara nicio referinta
    # Python, blocand pentru tot restul rularii slotul `_default_root`.
    # Efect real, reprodus: fereastra principala functioneaza normal (isi
    # gaseste propriile widget-uri direct), dar orice `tk.StringVar()`/
    # `IntVar()` FARA `master` explicit din alta fereastra (PresetsDialog,
    # SettingsDialog) arunca ulterior "Too early to create variable: no
    # default root window", pentru ca root-ul REAL nu a putut revendica
    # slotul (deja ocupat de orfan) la propria initializare.
    orphan = tk._default_root
    if orphan is not None:
        try:
            orphan.destroy()
        except Exception:
            pass
        tk._default_root = None

import activation
import config
import format_registry
import gpu_probe
import machine_id
import media_inspector
from media_preview import MediaPreviewDialog
import offload_engine
import presets_manager as presets_mod
import revocation_check
import self_updater
import theme
import update_checker
from translations import t
from converter import Converter
from dependency_manager import DependencyManager
from dependency_panel import DependencyPanel
from offload_view import OffloadPanel
from presets_dialog import PresetsDialog
from settings_dialog import SettingsDialog
from watch_folders import WatchFolderManager

BASE_CLASS = TkinterDnD.Tk if HAS_DND else tk.Tk


def _resource_path(name):
    """Cale catre un fisier bundle-uit (icon etc.) — in interiorul .exe/.app
    PyInstaller (sys._MEIPASS) sau langa main.py in dezvoltare, la fel ca
    get_ffmpeg_path()/get_ffprobe_path() din converter.py."""
    if getattr(sys, "frozen", False):
        base_path = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, name)


class CGConvertorApp(BASE_CLASS):
    def __init__(self):
        super().__init__()

        self.settings = config.load()
        self.lang = self.settings["language"]
        self.th = theme.get(self.settings.get("theme_pref", "system"))
        # Instanta "principala" - folosita doar pentru is_available()/
        # get_duration() rapide. Fiecare job din coada isi creeaza propria
        # instanta Converter() (vezi _run_queue) - necesar pentru
        # procesare paralela (Regula Faza 1, sectiunea F): un singur
        # _stop_requested comun ar opri gresit joburile concurente.
        self.converter = Converter()
        self.deps = DependencyManager()

        self.presets = presets_mod.load()
        self.selected_preset_id = self.settings.get("last_preset_id") or (
            self.presets[0].id if self.presets else None)

        self.jobs = []  # list of dicts: {path, status, progress, output, item_id}
        self.is_running = False
        self.is_paused = False
        self._stop_all = False
        self._active_converters = []
        self._active_converters_lock = threading.Lock()

        # Offload/Checksum (Faza 2) — starea motorului supravietuieste
        # `_rebuild_ui()` (schimbare tema/marime font), exact ca `self.jobs`
        # pentru coada de conversie; panoul (OffloadPanel) e reconstruit la
        # fiecare rebuild, dar se leaga de acelasi `OffloadRunner`.
        self.main_mode = "convert"
        self.offload_runner = offload_engine.OffloadRunner(self.settings)
        self.offload_source_path = None
        self.offload_destinations = []
        self.offload_verify_model = "xxhash64"

        # Watch Folders (Faza 2) — motorul e independent de UI, ruleaza pe
        # thread propriu; callback-ul marcheaza fisierele noi in coada prin
        # `self.after(0, ...)` (Tkinter nu e thread-safe, la fel ca restul
        # aplicatiei — self_updater foloseste acelasi tipar).
        self.watch_folder_manager = WatchFolderManager(self.settings, config.save)
        self.watch_folder_manager.on_new_files = lambda paths: self.after(0, lambda: self._add_files(paths))
        self.watch_folder_manager.start()

        self.title(t(self.lang, "app_title"))
        self.geometry("920x620")
        self.minsize(780, 540)
        self.configure(bg=self.th["bg"])
        self._set_window_icon()

        self._setup_style()
        self._build_ui()
        self._refresh_texts()

        # BUG real prins la testare (2026-08-26): pornirea thread-ului de
        # verificare SINCRON, direct din __init__, risca sa cheme
        # self.after(...) din thread-ul de fundal INAINTE ca self.mainloop()
        # sa fi pornit efectiv (fereastra nu e inca "in main loop") -
        # Tkinter arunca "RuntimeError: main thread is not in main loop".
        # Fix: intarziat cu self.after(...), exact ca update checker-ul de
        # mai jos, care avea deja acest tipar corect - garanteaza ca
        # mainloop() a pornit pana se executa thread-ul.
        self.after(100, self._refresh_dependencies)
        self.after(150, self._refresh_gpu_detection)

        # Verificare automata de actualizari la lansare, o singura data,
        # tacuta daca nu e nimic nou — la fel ca UpdateChecker.swift (Mac).
        self.after(800, self._check_updates_silently)

        # Revocare de licenta (Regula 12) - fail-open, verificare de fundal
        # la lansare + la fiecare 6h; nu atinge deloc Tk direct (doar
        # actualizeaza un flag intern), deci nu are nevoie de self.after().
        revocation_check.start_periodic_refresh(machine_id.get_machine_id_display)

    # ── Iconita fereastra (title bar / taskbar) ─────────────────────────
    # Iconita executabilului insusi vine deja din build-windows.spec/
    # build-mac.spec (icon='CGConvertor.ico'/'.icns') — asta seteaza
    # explicit si iconita FERESTREI (title bar + Alt-Tab + taskbar pe
    # Windows), care altfel ramane iconita implicita Tk (o frunza), chiar
    # daca .exe-ul insusi are iconita corecta.
    def _set_window_icon(self):
        if sys.platform == "win32":
            ico_path = _resource_path("CGConvertor.ico")
            if os.path.isfile(ico_path):
                try:
                    self.iconbitmap(default=ico_path)
                except tk.TclError:
                    pass
        # Pe Mac, iconita Dock-ului vine din bundle-ul .app (.icns, deja
        # setat in build-mac.spec) — Tk nu are echivalent de title-bar icon
        # acolo, deci nimic suplimentar de facut.

    # ── Stil ──────────────────────────────────────────────────────────

    def _f(self, base_size, weight=None):
        """Font (Regula 24 — Marime Text explicita): scaleaza `base_size`
        dupa `self.settings["font_scale"]`, citit LA FIECARE apel (nu
        cache-uit) - un `_rebuild_ui()` dupa schimbarea din Setari
        reconstruieste toate widget-urile cu noua scalare, fara repornire."""
        scale = self.settings.get("font_scale", "normal")
        size = theme.scaled(base_size, scale)
        return (theme.FONT_FAMILY, size, weight) if weight else (theme.FONT_FAMILY, size)

    def _fm(self, base_size):
        scale = self.settings.get("font_scale", "normal")
        return (theme.FONT_MONO, theme.scaled(base_size, scale))

    def _setup_style(self):
        """
        tk.Button ignora bg/fg pe macOS (tema Aqua nativa nu permite recolorare).
        Trecem pe tema 'clam', care respecta culorile custom pe ambele platforme,
        si definim stiluri ttk pentru fiecare tip de buton.
        """
        th = self.th
        style = ttk.Style(self)
        style.theme_use("clam")

        def make_button_style(name, bg, fg, hover_bg):
            style.configure(name, background=bg, foreground=fg, borderwidth=0,
                             focusthickness=0, padding=(10, 8),
                             font=self._f(10))
            style.map(name,
                      background=[("active", hover_bg), ("disabled", th["line"])],
                      foreground=[("disabled", th["fg_dim"])])

        make_button_style("Accent.TButton", th["accent"], th["accent_ink"], th["accent_hover"])
        make_button_style("Stop.TButton", th["error"], "#ffffff", "#ec6f61")
        make_button_style("Ghost.TButton", th["bg_elevated"], th["fg"], th["line"])
        make_button_style("Lang.TButton", th["bg_elevated"], th["fg"], th["accent"])
        make_button_style("LangActive.TButton", th["accent"], th["accent_ink"], th["accent_hover"])

        style.configure("TCombobox", fieldbackground=th["bg_elevated"],
                         background=th["bg_elevated"], foreground=th["fg"])
        style.configure("TCheckbutton", background=th["bg_panel"], foreground=th["fg"])
        style.map("TCheckbutton", background=[("active", th["bg_panel"])])
        style.configure("TRadiobutton", background=th["bg_panel"], foreground=th["fg"])
        style.map("TRadiobutton", background=[("active", th["bg_panel"])])
        style.configure("Treeview", background=th["bg_elevated"], fieldbackground=th["bg_elevated"],
                         foreground=th["fg"], borderwidth=0)
        style.configure("Treeview.Heading", background=th["bg_panel"], foreground=th["fg_dim"])
        style.map("Treeview", background=[("selected", th["accent"])],
                  foreground=[("selected", th["accent_ink"])])

    # ── UI construction ──────────────────────────────────────────────

    def _build_ui(self):
        th = self.th

        header = tk.Frame(self, bg=th["bg"])
        header.pack(fill="x", padx=20, pady=(18, 8))

        title_row = tk.Frame(header, bg=th["bg"])
        title_row.pack(fill="x")
        self.title_label = tk.Label(title_row, font=self._f(20, "bold"),
                                     bg=th["bg"], fg=th["fg"])
        self.title_label.pack(side="left")
        self.version_label = tk.Label(title_row, text=f"v{config.APP_VERSION}",
                                       font=self._fm(10), bg=th["bg"], fg=th["fg_faint"])
        self.version_label.pack(side="left", padx=(8, 0), pady=(6, 0))

        self.update_btn = tk.Label(title_row, text="⟳", font=self._f(13),
                                    bg=th["bg"], fg=th["fg_dim"], cursor="hand2")
        self.update_btn.pack(side="right")
        self.update_btn.bind("<Button-1>", lambda e: self._check_updates_manually())

        # Badge Manager de Dependinte — bulina + text, click deschide
        # panoul "Verificare & Dependinte Sistem" (dependency_panel.py).
        self.deps_badge = tk.Frame(title_row, bg=th["bg_elevated"], cursor="hand2")
        self.deps_badge.pack(side="right", padx=(0, 10))
        self.deps_dot = tk.Canvas(self.deps_badge, width=8, height=8, bg=th["bg_elevated"], highlightthickness=0)
        self.deps_dot_id = self.deps_dot.create_oval(1, 1, 7, 7, fill=th["error"], outline="")
        self.deps_dot.pack(side="left", padx=(8, 4), pady=5)
        self.deps_label = tk.Label(self.deps_badge, font=self._f(9, "bold"),
                                    bg=th["bg_elevated"], fg=th["fg"])
        self.deps_label.pack(side="left", padx=(0, 8), pady=5)
        for w in (self.deps_badge, self.deps_dot, self.deps_label):
            w.bind("<Button-1>", lambda e: self._open_dependency_panel())

        self.subtitle_label = tk.Label(header, font=self._f(11),
                                        bg=th["bg"], fg=th["fg_dim"])
        self.subtitle_label.pack(anchor="w")

        # ── Comutator mod: Convertor / Offload (Faza 2) ──
        mode_row = tk.Frame(header, bg=th["bg"])
        mode_row.pack(anchor="w", pady=(8, 0))
        self.mode_buttons = {}
        for mode in ("convert", "offload"):
            btn = ttk.Button(mode_row, command=lambda m=mode: self._set_main_mode(m),
                              style="LangActive.TButton" if mode == self.main_mode else "Lang.TButton",
                              cursor="hand2")
            btn.pack(side="left", padx=(0, 4))
            self.mode_buttons[mode] = btn

        # ── Banner proba/licenta/revocare ──
        self.trial_frame = tk.Frame(self, bg=th["bg_elevated"])
        self.trial_label = tk.Label(self.trial_frame, font=self._f(10),
                                     bg=th["bg_elevated"], fg=th["fg_dim"])
        self.trial_label.pack(side="left", padx=14, pady=6)
        self.trial_activate_btn = tk.Label(self.trial_frame, font=self._f(10, "bold"),
                                            bg=th["bg_elevated"], fg=th["accent"], cursor="hand2")
        self.trial_activate_btn.pack(side="right", padx=14, pady=6)
        self.trial_activate_btn.bind("<Button-1>", lambda e: self._open_activation())

        body = tk.Frame(self, bg=th["bg"])
        self.body_frame = body
        if self.main_mode == "convert":
            body.pack(fill="both", expand=True, padx=20, pady=10)

        # ── Panou stanga: setari ──
        left = tk.Frame(body, bg=th["bg_panel"], width=260)
        left.pack(side="left", fill="y", padx=(0, 14))
        left.pack_propagate(False)

        # ── Preset de iesire (Presets Manager, Faza 1 v3.0.0) — inlocuieste
        # vechiul dropdown fix Mod(Rewrap/Transcode)+Codec. ──
        self.preset_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                      font=self._f(11, "bold"))
        self.preset_label.pack(anchor="w", padx=14, pady=(16, 4))

        self.preset_var = tk.StringVar()
        self.preset_menu = ttk.Combobox(left, textvariable=self.preset_var, state="readonly")
        self.preset_menu.pack(fill="x", padx=14)
        self.preset_menu.bind("<<ComboboxSelected>>", lambda e: self._on_preset_change())

        self.preset_hint_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_dim"],
                                           font=self._f(9), wraplength=220,
                                           justify="left")
        self.preset_hint_label.pack(anchor="w", padx=14, pady=(4, 0))

        self.edit_presets_btn = ttk.Button(left, command=self._open_presets_dialog,
                                            style="Ghost.TButton", cursor="hand2")
        self.edit_presets_btn.pack(fill="x", padx=14, pady=(6, 0))

        # Accelerare GPU detectata (Faza 1, sectiunea B) — informativ, cu
        # override manual din Setari (rotita din sidebar-ul de mai jos).
        self.gpu_badge_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_faint"],
                                         font=self._f(9), wraplength=220, justify="left")
        self.gpu_badge_label.pack(anchor="w", padx=14, pady=(6, 0))

        self.dest_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                    font=self._f(11, "bold"))
        self.dest_label.pack(anchor="w", padx=14, pady=(20, 4))

        self.dest_path_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_dim"],
                                         font=self._f(9), wraplength=220,
                                         justify="left")
        self.dest_path_label.pack(anchor="w", padx=14)

        self.choose_folder_btn = ttk.Button(left, command=self._choose_destination,
                                             style="Ghost.TButton", cursor="hand2")
        self.choose_folder_btn.pack(fill="x", padx=14, pady=8)

        # ── Watch Folders (Faza 2) ──
        self.watch_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                     font=self._f(11, "bold"))
        self.watch_label.pack(anchor="w", padx=14, pady=(16, 4))
        self.watch_list_frame = tk.Frame(left, bg=th["bg_panel"])
        self.watch_list_frame.pack(fill="x", padx=14)
        self.watch_add_btn = ttk.Button(left, command=self._add_watch_folder,
                                         style="Ghost.TButton", cursor="hand2")
        self.watch_add_btn.pack(fill="x", padx=14, pady=(4, 0))

        self.shortcuts_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_faint"],
                                         font=self._fm(8))
        self.shortcuts_label.pack(anchor="w", padx=14, pady=(0, 6), side="bottom")

        self.start_btn = ttk.Button(left, command=self._start_queue,
                                     style="Accent.TButton", cursor="hand2")
        self.stop_btn = ttk.Button(left, command=self._stop_queue,
                                    style="Stop.TButton", cursor="hand2")
        self.pause_btn = ttk.Button(left, command=self._toggle_pause,
                                     style="Ghost.TButton", cursor="hand2")
        self.start_btn.pack(fill="x", padx=14, pady=(24, 8), side="bottom")

        # limba
        lang_frame = tk.Frame(left, bg=th["bg_panel"])
        lang_frame.pack(fill="x", padx=14, pady=(0, 8), side="bottom")
        self.lang_buttons = {}
        for code in ("ro", "en", "es"):
            btn = ttk.Button(lang_frame, text=code.upper(), width=3,
                              command=lambda c=code: self._set_language(c),
                              style="Lang.TButton", cursor="hand2")
            btn.pack(side="left", padx=2)
            self.lang_buttons[code] = btn

        # ── Profil GDC + Setari (Regula 12 — profil/HWID vizibil in
        # sidebar, pe toate aplicatiile GDC cu licentiere) ──
        profile_frame = tk.Frame(left, bg=th["bg_elevated"])
        profile_frame.pack(fill="x", padx=14, pady=(0, 8), side="bottom")
        profile_info = tk.Frame(profile_frame, bg=th["bg_elevated"])
        profile_info.pack(side="left", fill="both", expand=True, padx=8, pady=6)
        self.profile_name_label = tk.Label(profile_info, bg=th["bg_elevated"], fg=th["fg"],
                                            font=self._f(10, "bold"), anchor="w")
        self.profile_name_label.pack(fill="x")
        self.profile_id_label = tk.Label(profile_info, bg=th["bg_elevated"], fg=th["fg_faint"],
                                          font=self._fm(8), anchor="w")
        self.profile_id_label.pack(fill="x")
        self.settings_gear_btn = tk.Label(profile_frame, text="⚙", font=self._f(14),
                                           bg=th["bg_elevated"], fg=th["fg_dim"], cursor="hand2", padx=10)
        self.settings_gear_btn.pack(side="right")
        self.settings_gear_btn.bind("<Button-1>", lambda e: self._open_settings_dialog())

        # ── Panou dreapta: lista de fisiere ──
        right = tk.Frame(body, bg=th["bg"])
        right.pack(side="left", fill="both", expand=True)

        self.drop_frame = tk.Frame(right, bg=th["bg_panel"], highlightbackground=th["line"],
                                    highlightthickness=1)
        self.drop_frame.pack(fill="both", expand=True)

        self.drop_label = tk.Label(self.drop_frame, bg=th["bg_panel"], fg=th["fg_dim"],
                                    font=self._f(13))
        self.drop_label.pack(pady=(40, 6))

        self.choose_files_btn = ttk.Button(self.drop_frame, command=self._choose_files,
                                            style="Ghost.TButton", cursor="hand2")
        self.choose_files_btn.pack()

        self.tree = ttk.Treeview(self.drop_frame, columns=("meta", "status"), show="tree headings",
                                  height=14)
        self.tree.heading("#0", text="Fisier")
        self.tree.heading("meta", text="")
        self.tree.heading("status", text="Status")
        self.tree.column("#0", width=340)
        self.tree.column("meta", width=180)
        self.tree.column("status", width=200)
        self._thumb_images = {}  # item_id -> tk.PhotoImage, referinta obligatorie (Tkinter le colecteaza altfel)

        # Actiuni post-conversie + reordonare: dublu-click SAU click-dreapta
        # pe un rand -> "Deschide fisierul" / "Arata in Explorer" (daca
        # finalizat) si "Muta sus"/"Muta jos" (daca coada nu ruleaza).
        self.tree.bind("<Double-Button-1>", self._on_tree_double_click)
        self.tree.bind("<Button-3>", self._on_tree_right_click)

        bottom_bar = tk.Frame(right, bg=th["bg"])
        bottom_bar.pack(fill="x", pady=(8, 0))
        self.clear_btn = ttk.Button(bottom_bar, command=self._clear_list,
                                     style="Ghost.TButton", cursor="hand2")
        self.clear_btn.pack(side="left")
        self.report_btn = ttk.Button(bottom_bar, command=self._generate_report,
                                      style="Ghost.TButton", cursor="hand2")
        self.report_btn.pack(side="left", padx=(6, 0))
        self.add_more_btn = ttk.Button(bottom_bar, command=self._choose_files,
                                        style="Ghost.TButton", cursor="hand2")
        self.add_more_btn.pack(side="right")

        if HAS_DND:
            self.drop_frame.drop_target_register(DND_FILES)
            self.drop_frame.dnd_bind("<<Drop>>", self._on_drop)

        # Taste rapide (portate din varianta Swift — Cmd/Ctrl+O, Cmd/Ctrl+K)
        modifier = "Command" if sys.platform == "darwin" else "Control"
        self.bind(f"<{modifier}-o>", lambda e: self._choose_files())
        self.bind(f"<{modifier}-k>", lambda e: self._clear_list())
        self.bind(f"<{modifier}-Return>", lambda e: self._start_queue())

        # ── Panoul Offload (Faza 2) — construit intotdeauna, vizibil doar
        # in modul "offload" (`self.main_mode`). Motorul (`offload_runner`)
        # traieste separat pe `self`, supravietuieste `_rebuild_ui()`.
        self.offload_panel = OffloadPanel(self, self)
        if self.main_mode == "offload":
            self.offload_panel.pack(fill="both", expand=True, padx=20, pady=10)

    def _set_main_mode(self, mode):
        if mode == self.main_mode:
            return
        self.main_mode = mode
        if mode == "convert":
            self.offload_panel.pack_forget()
            self.body_frame.pack(fill="both", expand=True, padx=20, pady=10)
        else:
            self.body_frame.pack_forget()
            self.offload_panel.pack(fill="both", expand=True, padx=20, pady=10)
        for m, btn in self.mode_buttons.items():
            btn.configure(style="LangActive.TButton" if m == mode else "Lang.TButton")

    def _refresh_texts(self):
        lang = self.lang
        self.title(t(lang, "app_title"))
        self.title_label.config(text=t(lang, "app_title"))
        self.subtitle_label.config(text=t(lang, "app_subtitle"))
        for m, btn in self.mode_buttons.items():
            btn.config(text=t(lang, f"mode_{m}"))
        self.preset_label.config(text=t(lang, "output_preset"))
        self._reload_preset_menu()
        self.edit_presets_btn.config(text=t(lang, "edit_presets"))
        self._refresh_gpu_badge()
        self.dest_label.config(text=t(lang, "destination_folder"))
        dest = self.settings.get("last_destination") or t(lang, "same_as_source")
        self.dest_path_label.config(text=dest)
        self.choose_folder_btn.config(text=t(lang, "choose_folder"))
        self.watch_label.config(text=t(lang, "watch_folders_title"))
        self.watch_add_btn.config(text=t(lang, "add_watch_folder"))
        self._render_watch_folders()
        self.start_btn.config(text=t(lang, "start_conversion"))
        self.stop_btn.config(text=t(lang, "stop_conversion"))
        self.pause_btn.config(text=t(lang, "resume_conversion") if self.is_paused else t(lang, "pause_conversion"))
        self.drop_label.config(text=f'{t(lang, "drag_files_here")}\n{t(lang, "drag_files_hint")}')
        self.choose_files_btn.config(text=t(lang, "choose_files"))
        self.clear_btn.config(text=t(lang, "clear_list"))
        self.report_btn.config(text=t(lang, "generate_report"))
        self.add_more_btn.config(text=t(lang, "add_files"))
        self.shortcuts_label.config(text=t(lang, "shortcuts_hint"))
        self._refresh_profile_labels()
        for code, btn in self.lang_buttons.items():
            btn.configure(style="LangActive.TButton" if code == lang else "Lang.TButton")
        self._refresh_trial_banner()

    def _reload_preset_menu(self):
        labels = [p.label for p in self.presets]
        self.preset_menu.configure(values=labels)
        current = self._preset_by_id(self.selected_preset_id) or (self.presets[0] if self.presets else None)
        if current:
            self.preset_var.set(current.label)
            self.selected_preset_id = current.id
            self._refresh_preset_hint(current)

    def _preset_by_label(self, label):
        return next((p for p in self.presets if p.label == label), None)

    def _preset_by_id(self, preset_id):
        return next((p for p in self.presets if p.id == preset_id), None)

    def _on_preset_change(self):
        preset = self._preset_by_label(self.preset_var.get())
        if not preset:
            return
        self.selected_preset_id = preset.id
        self.settings["last_preset_id"] = preset.id
        config.save(self.settings)
        self._refresh_preset_hint(preset)

    def _refresh_preset_hint(self, preset):
        if preset.profile_id == presets_mod.REWRAP_PROFILE_ID:
            self.preset_hint_label.config(text="")
        else:
            profile = format_registry.get(preset.profile_id)
            self.preset_hint_label.config(text=t(self.lang, profile.hint_key))

    def _open_presets_dialog(self):
        PresetsDialog(self, self.presets, self.lang, t, on_change=self._on_presets_changed)

    def _on_presets_changed(self, presets):
        self.presets = presets
        self._reload_preset_menu()

    def _refresh_gpu_detection(self):
        gpu_probe.refresh()
        # gpu_probe.refresh() porneste un thread propriu (ruleaza
        # "ffmpeg -encoders", de obicei sub 1s) - repopulam badge-ul dupa
        # un delay scurt in loc de un callback exact, acelasi compromis
        # pragmatic ca restul verificarilor de fundal din acest fisier.
        self.after(1200, self._refresh_gpu_badge)

    def _refresh_gpu_badge(self):
        vendor = self.settings.get("gpu_vendor_override") or gpu_probe.detect()
        label = gpu_probe.GPU_LABELS.get(vendor, vendor)
        self.gpu_badge_label.config(text=f'{t(self.lang, "gpu_accel_prefix")} {label}')

    def _refresh_profile_labels(self):
        lang = self.lang
        name = self.settings.get("user_name") or t(lang, "sidebar_anonymous")
        self.profile_name_label.config(text=name)
        self.profile_id_label.config(text=f'{t(lang, "sidebar_machine_id")}: {machine_id.get_machine_id_display()}')

    def _open_settings_dialog(self):
        SettingsDialog(self, self.settings, self.lang, t, on_save=self._on_settings_saved)

    def _on_settings_saved(self, settings):
        theme_or_font_changed = (settings.get("theme_pref") != self.settings.get("theme_pref")
                                  or settings.get("font_scale") != self.settings.get("font_scale"))
        self.settings = settings
        if theme_or_font_changed:
            self._rebuild_ui()  # Regula 18/24 - aplicat imediat, FARA repornire
        else:
            self._refresh_gpu_badge()
            self._refresh_profile_labels()

    def _rebuild_ui(self):
        """Reconstruieste intreaga interfata cu tema/marimea de font
        curente (Regula 18/24 - "aplicat imediat fara repornire"). Tkinter
        nu re-aplica retroactiv `bg=`/`font=` pe widget-uri deja create
        cand o variabila se schimba - teardown+rebuild complet e mai
        simplu si mai sigur decat sa umbli manual prin tot arborele de
        widget-uri, si costa doar cateva milisecunde."""
        for child in self.winfo_children():
            child.destroy()
        self.th = theme.get(self.settings.get("theme_pref", "system"))
        self.configure(bg=self.th["bg"])
        self._setup_style()
        self._build_ui()
        self._refresh_texts()
        self._restore_jobs_into_tree()
        if self.is_running:
            self.start_btn.pack_forget()
            self.stop_btn.pack(fill="x", padx=14, pady=(4, 8), side="bottom")
            self.pause_btn.config(text=t(self.lang, "resume_conversion") if self.is_paused else t(self.lang, "pause_conversion"))
            self.pause_btn.pack(fill="x", padx=14, pady=(24, 4), side="bottom")

    def _restore_jobs_into_tree(self):
        """Dupa `_rebuild_ui()`, arborele nou e gol - joburile existente
        (posibil inca in curs de procesare intr-un worker thread) sunt
        reintroduse, cu `item_id` actualizat pe fiecare (referinta la
        dict-ul jobului, nu o copie - workerul vede automat noul id la
        urmatoarea actualizare de status/progres)."""
        if not self.jobs:
            return
        self.drop_label.pack_forget()
        self.choose_files_btn.pack_forget()
        self.tree.pack(fill="both", expand=True, padx=10, pady=10)
        for job in self.jobs:
            item_id = self.tree.insert("", "end", text=os.path.basename(job["path"]),
                                        values=(job["status"],))
            job["item_id"] = item_id
        self._update_deps_badge()

    # ── Proba / Licenta / Revocare ──────────────────────────────────────

    def _refresh_trial_banner(self):
        lang = self.lang
        if revocation_check.is_revoked():
            self.trial_label.config(text=t(lang, "license_revoked"), fg=self.th["error"])
            self.trial_activate_btn.config(text=t(lang, "trial_activate"))
            self.trial_frame.pack(fill="x")
            return
        if activation.is_licensed():
            self.trial_frame.pack_forget()
            return
        remaining = activation.trial_days_remaining()
        if remaining > 0:
            self.trial_label.config(
                text=t(lang, "trial_days_left", days=max(1, int(remaining + 0.999))))
            self.trial_label.config(fg=self.th["fg_dim"])
        else:
            self.trial_label.config(text=t(lang, "trial_expired"), fg=self.th["error"])
        self.trial_activate_btn.config(text=t(lang, "trial_activate"))
        # Bannerul e creat (in _build_ui) INAINTE de `body`, deci un pack()
        # simplu il reaseaza mereu corect intre header si body, indiferent
        # de cate ori e ascuns/aratat din nou.
        self.trial_frame.pack(fill="x")

    def _open_activation(self):
        trial_expired = activation.trial_days_remaining() <= 0
        if activation.open_activation_dialog(self, trial_expired=trial_expired):
            self._refresh_trial_banner()

    # ── Actiuni ───────────────────────────────────────────────────────

    def _set_language(self, code):
        self.lang = code
        self.settings["language"] = code
        config.save(self.settings)
        self._refresh_texts()

    def _choose_destination(self):
        folder = filedialog.askdirectory()
        if folder:
            self.settings["last_destination"] = folder
            config.save(self.settings)
            self.dest_path_label.config(text=folder)

    def _add_watch_folder(self):
        folder = filedialog.askdirectory()
        if folder:
            self.watch_folder_manager.add_folder(folder)
            self._render_watch_folders()

    def _render_watch_folders(self):
        th = self.th
        for w in self.watch_list_frame.winfo_children():
            w.destroy()
        for entry in self.watch_folder_manager.folders:
            row = tk.Frame(self.watch_list_frame, bg=th["bg_panel"])
            row.pack(fill="x", pady=1)
            var = tk.BooleanVar(value=entry.get("enabled", True))
            chk = ttk.Checkbutton(row, variable=var,
                                   command=lambda p=entry["path"]: self.watch_folder_manager.toggle_folder(p))
            chk.pack(side="left")
            tk.Label(row, text=os.path.basename(entry["path"]), bg=th["bg_panel"], fg=th["fg_dim"],
                     font=self._fm(9), anchor="w").pack(side="left", fill="x", expand=True)
            remove_lbl = tk.Label(row, text="✕", bg=th["bg_panel"], fg=th["fg_faint"], cursor="hand2",
                                   font=self._fm(9))
            remove_lbl.pack(side="right")
            remove_lbl.bind("<Button-1>", lambda e, p=entry["path"]: self._remove_watch_folder(p))

    def _remove_watch_folder(self, path):
        self.watch_folder_manager.remove_folder(path)
        self._render_watch_folders()

    def _choose_files(self):
        paths = filedialog.askopenfilenames(
            filetypes=[("Video", "*.mov *.mp4 *.mxf *.mkv *.avi *.m4v")])
        self._add_files(paths)

    def _on_drop(self, event):
        paths = self.tk.splitlist(event.data)
        self._add_files(paths)

    def _add_files(self, paths):
        for p in paths:
            if os.path.isfile(p) and not any(j["path"] == p for j in self.jobs):
                job = {"path": p, "status": t(self.lang, "status_waiting"), "progress": 0.0,
                       "metadata": None, "thumbnail_path": None}
                self.jobs.append(job)
                item_id = self.tree.insert("", "end", text=os.path.basename(p),
                                            values=("", job["status"]))
                job["item_id"] = item_id
                self._analyze_file_async(job)
        if self.jobs:
            self.drop_label.pack_forget()
            self.choose_files_btn.pack_forget()
            self.tree.pack(fill="both", expand=True, padx=10, pady=10)
        self._update_deps_badge()

    def _analyze_file_async(self, job):
        """Inspectie/Metadata profunda + thumbnail (Faza 2) — porneste
        automat la adaugare, ruleaza pe thread de fundal (ffprobe/ffmpeg pot
        dura cateva sute de ms), actualizeaza UI-ul doar prin
        `self.after(0, ...)` (Tkinter nu e thread-safe, la fel ca restul
        aplicatiei)."""
        def run():
            meta = media_inspector.probe(job["path"])
            thumb_path = os.path.join(media_inspector.thumbnails_folder(), f"{id(job)}.png")
            ok = media_inspector.generate_thumbnail(job["path"], None, thumb_path)
            self.after(0, lambda: self._apply_analysis_result(job, meta, thumb_path if ok else None))
        threading.Thread(target=run, daemon=True).start()

    def _apply_analysis_result(self, job, meta, thumb_path):
        job["metadata"] = meta
        job["thumbnail_path"] = thumb_path
        if not self.tree.exists(job["item_id"]):
            return  # jobul a fost sters intre timp (Golește lista)
        parts = []
        if meta:
            res = media_inspector.resolution_text(meta)
            if res:
                parts.append(res)
            if meta.get("video_codec"):
                parts.append(meta["video_codec"].upper())
            if meta.get("frame_rate"):
                parts.append(f"{meta['frame_rate']} fps")
            if meta.get("duration"):
                parts.append(f"{meta['duration']:.1f}s")
        self.tree.set(job["item_id"], "meta", " · ".join(parts))
        if thumb_path:
            try:
                photo = tk.PhotoImage(file=thumb_path)
                self._thumb_images[job["item_id"]] = photo
                self.tree.item(job["item_id"], image=photo)
            except tk.TclError:
                pass

    def _generate_report(self):
        statuses_text = {id(j): j["status"] for j in self.jobs}
        report_path = media_inspector.generate_html_report(self.jobs, statuses_text)
        if sys.platform == "darwin":
            subprocess.run(["open", report_path])
        elif sys.platform == "win32":
            os.startfile(report_path)  # noqa: S606 — deschidere fisier local, generat de noi

    def _clear_list(self):
        if self.is_running:
            return
        self.jobs.clear()
        self.tree.delete(*self.tree.get_children())
        self._thumb_images.clear()
        self.tree.pack_forget()
        self._update_deps_badge()
        self.drop_label.pack(pady=(40, 6))
        self.choose_files_btn.pack()

    # ── Coada de conversie (pauza/reluare + procesare paralela, Faza 1 F) ──

    def _start_queue(self):
        if self.is_running or not self.jobs:
            if not self.jobs:
                messagebox.showinfo(t(self.lang, "app_title"), t(self.lang, "no_files_selected"))
            return
        if revocation_check.is_revoked():
            messagebox.showerror(t(self.lang, "app_title"), t(self.lang, "license_revoked"))
            return
        if not activation.is_unlocked():
            self._open_activation()
            return

        self.is_running = True
        self.is_paused = False
        self._stop_all = False
        self.start_btn.pack_forget()
        self.stop_btn.pack(fill="x", padx=14, pady=(4, 8), side="bottom")
        self.pause_btn.config(text=t(self.lang, "pause_conversion"))
        self.pause_btn.pack(fill="x", padx=14, pady=(24, 4), side="bottom")
        threading.Thread(target=self._run_queue, daemon=True).start()

    def _toggle_pause(self):
        # Pauza opreste doar PORNIREA jobului urmator — un job deja
        # inceput (proces ffmpeg activ) termina natural, nu e intrerupt
        # brutal la mijloc (spec Faza 1, sectiunea F).
        self.is_paused = not self.is_paused
        self.pause_btn.config(text=t(self.lang, "resume_conversion") if self.is_paused else t(self.lang, "pause_conversion"))

    def _stop_queue(self):
        # Stop TOTAL — spre deosebire de pauza, opreste si joburile deja
        # in curs (terminate() pe fiecare Converter activ).
        self._stop_all = True
        self.is_paused = False
        with self._active_converters_lock:
            for conv in self._active_converters:
                conv.stop()

    def _run_queue(self):
        preset = self._preset_by_id(self.selected_preset_id)
        dest_dir = self.settings.get("last_destination") or ""
        gpu_override = self.settings.get("gpu_vendor_override") or None
        max_workers = max(1, min(4, int(self.settings.get("max_parallel_jobs", 1))))

        def process_one(job):
            # Pauza: jobul asteapta AICI, inainte sa porneasca ffmpeg -
            # un job deja dispatch-uit unui worker dar neinceput inca nu
            # se lanseaza pana la reluare (sau stop total).
            while self.is_paused and not self._stop_all:
                time.sleep(0.2)
            if self._stop_all:
                self._update_status(job, t(self.lang, "status_waiting"))
                return

            src = job["path"]
            base = os.path.splitext(os.path.basename(src))[0]
            ext = self.converter.output_extension(preset)
            out_dir = dest_dir or os.path.dirname(src)
            out_path = os.path.join(out_dir, f"{base}{preset.file_suffix}.{ext}")
            job["output"] = out_path

            self._update_status(job, t(self.lang, "status_processing"))

            conv = Converter()
            with self._active_converters_lock:
                self._active_converters.append(conv)
            try:
                def on_progress(p, job=job):
                    self._update_progress(job, p)
                result = conv.convert(src, out_path, preset, gpu_override, on_progress)
            finally:
                with self._active_converters_lock:
                    if conv in self._active_converters:
                        self._active_converters.remove(conv)

            if result["success"]:
                self._update_status(job, self._integrity_status_text(conv, src, out_path))
            elif "Anulat" in (result["error"] or ""):
                self._update_status(job, t(self.lang, "status_canceled"))
            else:
                self._update_status(job, t(self.lang, "error") + ": " + (result["error"] or ""))

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(process_one, job) for job in self.jobs]
            concurrent.futures.wait(futures)

        was_stopped = self._stop_all
        self.is_running = False
        self.is_paused = False
        self.after(0, lambda: self._on_queue_finished(was_stopped))

    def _on_queue_finished(self, was_stopped):
        self.stop_btn.pack_forget()
        self.pause_btn.pack_forget()
        self.start_btn.pack(fill="x", padx=14, pady=(24, 8), side="bottom")
        if not was_stopped:
            self._notify_queue_done()

    def _notify_queue_done(self):
        # Notificare nativa DOAR la finalul intregii cozi, nu per fisier
        # (ar fi zgomotos) - Faza 1, sectiunea F.
        lang = self.lang
        title = t(lang, "app_title")
        message = t(lang, "conversion_complete")
        if sys.platform == "darwin":
            try:
                subprocess.Popen(["osascript", "-e",
                                   f'display notification "{message}" with title "{title}"'])
                return
            except Exception:
                pass
        self._show_toast_fallback(title, message)

    def _show_toast_fallback(self, title, message):
        """Fallback fara nicio dependinta noua (Windows/Linux — pe Mac se
        foloseste notificarea nativa osascript, de mai sus): o fereastra
        mica, fara chrome, langa colțul din dreapta-jos al ferestrei
        principale, care se auto-distruge dupa 4 secunde."""
        th = self.th
        toast = tk.Toplevel(self)
        toast.overrideredirect(True)
        try:
            toast.attributes("-topmost", True)
        except tk.TclError:
            pass
        toast.configure(bg=th["bg_elevated"])
        tk.Label(toast, text=title, font=self._f(10, "bold"),
                 bg=th["bg_elevated"], fg=th["fg"]).pack(anchor="w", padx=14, pady=(10, 0))
        tk.Label(toast, text=message, font=self._f(10),
                 bg=th["bg_elevated"], fg=th["fg_dim"]).pack(anchor="w", padx=14, pady=(0, 10))
        self.update_idletasks()
        x = self.winfo_rootx() + self.winfo_width() - 300
        y = self.winfo_rooty() + self.winfo_height() - 90
        toast.geometry(f"280x70+{max(0, x)}+{max(0, y)}")
        toast.after(4000, toast.destroy)

    def _integrity_status_text(self, conv, src_path, out_path):
        """Verificare de siguranta post-conversie (2026-09-05, cerere
        explicita) - cod de iesire 0 la ffmpeg NU garanteaza un fisier
        complet. Compara durata sursa vs. destinatie (ffprobe) - toleranta
        de 1s absoarbe rotunjirile normale, nu maschează o trunchiere reala.
        get_duration() intoarce 0.0 la eroare - daca ORICARE dintre cele
        doua e 0.0, nu putem verifica nimic real, deci ramane succes simplu
        (fail-open, ca restul verificarilor optionale din aplicatie)."""
        src_duration = conv.get_duration(src_path)
        out_duration = conv.get_duration(out_path)
        if src_duration <= 0.0 or out_duration <= 0.0:
            return t(self.lang, "conversion_complete")
        if abs(src_duration - out_duration) <= 1.0:
            return t(self.lang, "conversion_complete")
        detail = t(self.lang, "integrity_mismatch").format(src=src_duration, dst=out_duration)
        return f'{t(self.lang, "integrity_warning")} ({detail})'

    def _update_status(self, job, text):
        self.after(0, lambda: self.tree.set(job["item_id"], "status", text))

    def _update_progress(self, job, fraction):
        pct = int(fraction * 100)
        self.after(0, lambda: self.tree.set(job["item_id"], "status",
                                             f'{t(self.lang, "status_processing")} {pct}%'))

    # ── Actiuni post-conversie + reordonare ───────────────────────────

    def _job_for_item(self, item_id):
        return next((j for j in self.jobs if j.get("item_id") == item_id), None)

    def _finished_output_path(self, job):
        """Intoarce calea fisierului convertit DOAR daca jobul chiar s-a
        finalizat cu succes si fisierul inca exista pe disc — altfel None
        (jobul e inca in asteptare/eroare/anulat, sau fisierul a fost
        mutat/sters intre timp)."""
        if not job:
            return None
        output = job.get("output")
        if output and os.path.isfile(output):
            return output
        return None

    def _open_file(self, path):
        try:
            if sys.platform == "win32":
                os.startfile(path)
            elif sys.platform == "darwin":
                subprocess.run(["open", path])
            else:
                subprocess.run(["xdg-open", path])
        except Exception:
            pass

    def _show_in_explorer(self, path):
        try:
            if sys.platform == "win32":
                subprocess.run(["explorer", "/select,", path])
            elif sys.platform == "darwin":
                subprocess.run(["open", "-R", path])
            else:
                subprocess.run(["xdg-open", os.path.dirname(path)])
        except Exception:
            pass

    def _on_tree_double_click(self, event):
        item_id = self.tree.identify_row(event.y)
        path = self._finished_output_path(self._job_for_item(item_id))
        if path:
            self._open_file(path)

    def _on_tree_right_click(self, event):
        item_id = self.tree.identify_row(event.y)
        if not item_id:
            return
        # Pastram selectia multipla existenta daca randul apasat e deja
        # parte din ea (Ctrl/Shift+click inainte de click-dreapta) - altfel
        # butonul "Compara metadatele (N)" de mai jos n-ar avea niciodata
        # sens (selection_set(item_id) ar reduce mereu la un singur rand).
        current_selection = self.tree.selection()
        if item_id not in current_selection:
            self.tree.selection_set(item_id)
            current_selection = (item_id,)
        menu = tk.Menu(self, tearoff=0)
        job = self._job_for_item(item_id)
        path = self._finished_output_path(job)
        if len(current_selection) < 2 and path:
            menu.add_command(label=t(self.lang, "job_open_file"), command=lambda: self._open_file(path))
            menu.add_command(label=t(self.lang, "job_show_in_explorer"), command=lambda: self._show_in_explorer(path))
            menu.add_separator()
        if len(current_selection) < 2 and job and job.get("metadata"):
            menu.add_command(label=t(self.lang, "preview_open"), command=lambda: self._open_preview(job))
            # Player real-time LUT/LOG (Windows, 2026-09-05) — fereastra
            # SEPARATA, pe langa preview-ul static de mai sus (identic ca
            # decizie de scop cu portul Mac v3.9.0 — niciunul nu il
            # inlocuieste pe celalalt). Vezi lut_player.py.
            menu.add_command(label=t(self.lang, "player_open"), command=lambda: self._open_lut_player(job))
            menu.add_separator()
        if len(current_selection) >= 2:
            selected_jobs = [j for iid in current_selection for j in [self._job_for_item(iid)] if j]
            menu.add_command(label=t(self.lang, "compare_button", n=len(selected_jobs)),
                              command=lambda: self._open_metadata_compare(selected_jobs))
            menu.add_separator()
        if len(current_selection) < 2 and not self.is_running:
            menu.add_command(label=t(self.lang, "queue_move_up"), command=lambda: self._move_job(item_id, -1))
            menu.add_command(label=t(self.lang, "queue_move_down"), command=lambda: self._move_job(item_id, 1))
        menu.tk_popup(event.x_root, event.y_root)

    def _open_metadata_compare(self, jobs):
        from metadata_compare_view import MetadataCompareDialog
        cleaned = [{"path": j["path"], "name": os.path.basename(j["path"])} for j in jobs]
        MetadataCompareDialog(self, self, cleaned)

    def _open_preview(self, job):
        MediaPreviewDialog(self, self, job)

    def _open_lut_player(self, job):
        from lut_player import LUTPlayerWindow
        LUTPlayerWindow(self, self, job["path"])

    def _move_job(self, item_id, delta):
        job = self._job_for_item(item_id)
        if not job:
            return
        idx = self.jobs.index(job)
        new_idx = idx + delta
        if new_idx < 0 or new_idx >= len(self.jobs):
            return
        self.jobs[idx], self.jobs[new_idx] = self.jobs[new_idx], self.jobs[idx]
        self.tree.move(item_id, "", new_idx)

    # ── Manager de Dependinte ────────────────────────────────────────

    def _refresh_dependencies(self):
        """Verificare headless, rulata la lansare + dupa orice schimbare
        din panou — actualizeaza doar badge-ul, fara sa deschida nimic."""
        threading.Thread(target=self._deps_check_worker, daemon=True).start()

    def _deps_check_worker(self):
        self.deps.refresh_all()
        self.after(0, self._update_deps_badge)

    def _update_deps_badge(self):
        th = self.th
        ready = self.deps.is_ready
        self.deps_dot.itemconfig(self.deps_dot_id, fill=th["success"] if ready else th["error"])
        self.deps_label.config(text=t(self.lang, "deps_badge_ok" if ready else "deps_badge_missing"))
        self.start_btn.config(state="normal" if (ready and self.jobs) else "disabled")

    def _open_dependency_panel(self):
        DependencyPanel(self, self.deps, self.lang, t, on_change=self._update_deps_badge)

    # ── Actualizari ──────────────────────────────────────────────────

    def _check_updates_silently(self):
        def worker():
            result = update_checker.check_for_updates(config.APP_VERSION)
            if result["available"]:
                dismissed_key = f"_dismissed_update_{result['version']}"
                if self.settings.get(dismissed_key):
                    return
                self.after(0, lambda: self._show_update_popup(result["version"], result.get("download_url"), silent=True))
        threading.Thread(target=worker, daemon=True).start()

    def _check_updates_manually(self):
        def worker():
            result = update_checker.check_for_updates(config.APP_VERSION)
            if result.get("error"):
                self.after(0, lambda: messagebox.showerror(t(self.lang, "app_title"), t(self.lang, "update_error")))
            elif result["available"]:
                self.after(0, lambda: self._show_update_popup(result["version"], result.get("download_url"), silent=False))
            else:
                self.after(0, lambda: messagebox.showinfo(
                    t(self.lang, "app_title"), t(self.lang, "update_none")))
        threading.Thread(target=worker, daemon=True).start()

    def _show_update_popup(self, version, download_url, silent):
        lang = self.lang
        body = t(lang, "update_available_body", version=version, current=config.APP_VERSION)
        answer = messagebox.askyesno(t(lang, "update_available_title"), body)
        if silent:
            self.settings[f"_dismissed_update_{version}"] = True
            config.save(self.settings)
        if answer:
            self._start_self_update(version, download_url)

    def _start_self_update(self, version, download_url):
        """Descarca si lanseaza installer-ul FARA sa treaca prin browser -
        vezi self_updater.py si CLAUDE.md Partea 1, Regula 20."""
        lang = self.lang
        progress = tk.Toplevel(self)
        progress.title(t(lang, "app_title"))
        progress.resizable(False, False)
        progress.transient(self)
        title_label = ttk.Label(progress, text=f"CG Convertor {version}", font=("TkDefaultFont", 11, "bold"))
        title_label.pack(padx=20, pady=(16, 4), anchor="w")
        status_label = ttk.Label(progress, text=t(lang, "update_downloading"))
        status_label.pack(padx=20, pady=(0, 10), anchor="w")
        bar = ttk.Progressbar(progress, mode="indeterminate", length=280)
        bar.pack(padx=20, pady=(0, 16))
        bar.start(12)
        progress.grab_set()

        def on_status(stage):
            text = t(lang, "update_downloading") if stage == "downloading" else t(lang, "update_launching")
            self.after(0, lambda: status_label.config(text=text))

        def on_done(error):
            def finish():
                bar.stop()
                progress.destroy()
                if error is None:
                    self.destroy()
                    sys.exit(0)
                else:
                    if messagebox.askyesno(
                        t(lang, "update_failed_title"),
                        t(lang, "update_failed_body", error=str(error)),
                    ):
                        import webbrowser
                        webbrowser.open(update_checker.RELEASES_PAGE_URL)
            self.after(0, finish)

        threading.Thread(
            target=self_updater.download_and_install,
            args=(download_url, version),
            kwargs={"on_status": on_status, "on_done": on_done},
            daemon=True,
        ).start()


if __name__ == "__main__":
    app = CGConvertorApp()
    app.mainloop()
