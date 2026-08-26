# main.py
import os
import sys
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
    HAS_DND = True
except ImportError:
    HAS_DND = False

import activation
import config
import theme
import update_checker
from translations import t
from converter import Converter, CODEC_ARGS

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
        self.th = theme.get(self.settings["dark_mode"])
        self.converter = Converter()

        self.jobs = []  # list of dicts: {path, status, progress, output}
        self.is_running = False

        self.title(t(self.lang, "app_title"))
        self.geometry("920x620")
        self.minsize(780, 540)
        self.configure(bg=self.th["bg"])
        self._set_window_icon()

        self._setup_style()
        self._build_ui()
        self._refresh_texts()

        if not self.converter.is_available():
            self._show_ffmpeg_warning()

        # Verificare automata de actualizari la lansare, o singura data,
        # tacuta daca nu e nimic nou — la fel ca UpdateChecker.swift (Mac).
        self.after(800, self._check_updates_silently)

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
                             font=(theme.FONT_FAMILY, 10))
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
        self.title_label = tk.Label(title_row, font=(theme.FONT_FAMILY, 20, "bold"),
                                     bg=th["bg"], fg=th["fg"])
        self.title_label.pack(side="left")
        self.version_label = tk.Label(title_row, text=f"v{config.APP_VERSION}",
                                       font=(theme.FONT_MONO, 10), bg=th["bg"], fg=th["fg_faint"])
        self.version_label.pack(side="left", padx=(8, 0), pady=(6, 0))

        self.update_btn = tk.Label(title_row, text="⟳", font=(theme.FONT_FAMILY, 13),
                                    bg=th["bg"], fg=th["fg_dim"], cursor="hand2")
        self.update_btn.pack(side="right")
        self.update_btn.bind("<Button-1>", lambda e: self._check_updates_manually())

        self.subtitle_label = tk.Label(header, font=(theme.FONT_FAMILY, 11),
                                        bg=th["bg"], fg=th["fg_dim"])
        self.subtitle_label.pack(anchor="w")

        # ── Banner proba/licenta ──
        self.trial_frame = tk.Frame(self, bg=th["bg_elevated"])
        self.trial_label = tk.Label(self.trial_frame, font=(theme.FONT_FAMILY, 10),
                                     bg=th["bg_elevated"], fg=th["fg_dim"])
        self.trial_label.pack(side="left", padx=14, pady=6)
        self.trial_activate_btn = tk.Label(self.trial_frame, font=(theme.FONT_FAMILY, 10, "bold"),
                                            bg=th["bg_elevated"], fg=th["accent"], cursor="hand2")
        self.trial_activate_btn.pack(side="right", padx=14, pady=6)
        self.trial_activate_btn.bind("<Button-1>", lambda e: self._open_activation())

        body = tk.Frame(self, bg=th["bg"])
        body.pack(fill="both", expand=True, padx=20, pady=10)

        # ── Panou stanga: setari ──
        left = tk.Frame(body, bg=th["bg_panel"], width=260)
        left.pack(side="left", fill="y", padx=(0, 14))
        left.pack_propagate(False)

        self.mode_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                    font=(theme.FONT_FAMILY, 11, "bold"))
        self.mode_label.pack(anchor="w", padx=14, pady=(16, 4))

        style = ttk.Style(self)
        style.configure("TRadiobutton", background=th["bg_panel"], foreground=th["fg"])
        style.map("TRadiobutton", background=[("active", th["bg_panel"])])

        self.mode_var = tk.StringVar(value=self.settings["last_mode"])
        self.rewrap_radio = ttk.Radiobutton(
            left, variable=self.mode_var, value="rewrap", command=self._on_mode_change)
        self.rewrap_radio.pack(anchor="w", padx=10)
        self.transcode_radio = ttk.Radiobutton(
            left, variable=self.mode_var, value="transcode", command=self._on_mode_change)
        self.transcode_radio.pack(anchor="w", padx=10)

        self.codec_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                     font=(theme.FONT_FAMILY, 11, "bold"))
        self.codec_label.pack(anchor="w", padx=14, pady=(16, 4))

        self.codec_var = tk.StringVar(value=self.settings["last_codec"])
        self.codec_menu = ttk.Combobox(left, textvariable=self.codec_var,
                                        values=list(CODEC_ARGS.keys()),
                                        state="readonly")
        self.codec_menu.pack(fill="x", padx=14)
        self.codec_menu.bind("<<ComboboxSelected>>", lambda e: self._on_codec_change())

        self.codec_hint_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_dim"],
                                          font=(theme.FONT_FAMILY, 9), wraplength=220,
                                          justify="left")
        self.codec_hint_label.pack(anchor="w", padx=14, pady=(4, 0))

        self.dest_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                    font=(theme.FONT_FAMILY, 11, "bold"))
        self.dest_label.pack(anchor="w", padx=14, pady=(20, 4))

        self.dest_path_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_dim"],
                                         font=(theme.FONT_FAMILY, 9), wraplength=220,
                                         justify="left")
        self.dest_path_label.pack(anchor="w", padx=14)

        self.choose_folder_btn = ttk.Button(left, command=self._choose_destination,
                                             style="Ghost.TButton", cursor="hand2")
        self.choose_folder_btn.pack(fill="x", padx=14, pady=8)

        self.shortcuts_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_faint"],
                                         font=(theme.FONT_MONO, 8))
        self.shortcuts_label.pack(anchor="w", padx=14, pady=(0, 6), side="bottom")

        self.start_btn = ttk.Button(left, command=self._start_queue,
                                     style="Accent.TButton", cursor="hand2")
        self.stop_btn = ttk.Button(left, command=self._stop_queue,
                                    style="Stop.TButton", cursor="hand2")
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

        # ── Panou dreapta: lista de fisiere ──
        right = tk.Frame(body, bg=th["bg"])
        right.pack(side="left", fill="both", expand=True)

        self.drop_frame = tk.Frame(right, bg=th["bg_panel"], highlightbackground=th["line"],
                                    highlightthickness=1)
        self.drop_frame.pack(fill="both", expand=True)

        self.drop_label = tk.Label(self.drop_frame, bg=th["bg_panel"], fg=th["fg_dim"],
                                    font=(theme.FONT_FAMILY, 13))
        self.drop_label.pack(pady=(40, 6))

        self.choose_files_btn = ttk.Button(self.drop_frame, command=self._choose_files,
                                            style="Ghost.TButton", cursor="hand2")
        self.choose_files_btn.pack()

        self.tree = ttk.Treeview(self.drop_frame, columns=("status",), show="tree headings",
                                  height=14)
        self.tree.heading("#0", text="Fisier")
        self.tree.heading("status", text="Status")
        self.tree.column("#0", width=420)
        self.tree.column("status", width=200)

        bottom_bar = tk.Frame(right, bg=th["bg"])
        bottom_bar.pack(fill="x", pady=(8, 0))
        self.clear_btn = ttk.Button(bottom_bar, command=self._clear_list,
                                     style="Ghost.TButton", cursor="hand2")
        self.clear_btn.pack(side="left")
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

    def _refresh_texts(self):
        lang = self.lang
        self.title(t(lang, "app_title"))
        self.title_label.config(text=t(lang, "app_title"))
        self.subtitle_label.config(text=t(lang, "app_subtitle"))
        self.mode_label.config(text=t(lang, "conversion_mode"))
        self.rewrap_radio.config(text=t(lang, "rewrap"))
        self.transcode_radio.config(text=t(lang, "transcode"))
        self.codec_label.config(text=t(lang, "output_codec"))
        self.dest_label.config(text=t(lang, "destination_folder"))
        dest = self.settings.get("last_destination") or t(lang, "same_as_source")
        self.dest_path_label.config(text=dest)
        self.choose_folder_btn.config(text=t(lang, "choose_folder"))
        self.start_btn.config(text=t(lang, "start_conversion"))
        self.stop_btn.config(text=t(lang, "stop_conversion"))
        self.drop_label.config(text=f'{t(lang, "drag_files_here")}\n{t(lang, "drag_files_hint")}')
        self.choose_files_btn.config(text=t(lang, "choose_files"))
        self.clear_btn.config(text=t(lang, "clear_list"))
        self.add_more_btn.config(text=t(lang, "add_files"))
        self.shortcuts_label.config(text=t(lang, "shortcuts_hint"))
        for code, btn in self.lang_buttons.items():
            btn.configure(style="LangActive.TButton" if code == lang else "Lang.TButton")
        self._on_mode_change()
        self._on_codec_change()
        self._refresh_trial_banner()

    def _on_mode_change(self):
        if self.mode_var.get() == "transcode":
            self.codec_menu.pack(fill="x", padx=14)
            self.codec_hint_label.pack(anchor="w", padx=14, pady=(4, 0))
        else:
            self.codec_menu.pack_forget()
            self.codec_hint_label.pack_forget()

    def _on_codec_change(self):
        hint_key = {
            "ProRes 422": "codec_hint_422",
            "ProRes 422 HQ": "codec_hint_422hq",
            "ProRes 422 LT": "codec_hint_422lt",
            "ProRes 4444": "codec_hint_4444",
            "DNxHD": "codec_hint_dnx",
            "DNxHR HQ": "codec_hint_dnx",
        }.get(self.codec_var.get(), "codec_hint_422hq")
        self.codec_hint_label.config(text=t(self.lang, hint_key))

    # ── Proba / Licenta ──────────────────────────────────────────────

    def _refresh_trial_banner(self):
        lang = self.lang
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
                job = {"path": p, "status": t(self.lang, "status_waiting"), "progress": 0.0}
                self.jobs.append(job)
                item_id = self.tree.insert("", "end", text=os.path.basename(p),
                                            values=(job["status"],))
                job["item_id"] = item_id
        if self.jobs:
            self.drop_label.pack_forget()
            self.choose_files_btn.pack_forget()
            self.tree.pack(fill="both", expand=True, padx=10, pady=10)

    def _clear_list(self):
        if self.is_running:
            return
        self.jobs.clear()
        self.tree.delete(*self.tree.get_children())
        self.tree.pack_forget()
        self.drop_label.pack(pady=(40, 6))
        self.choose_files_btn.pack()

    def _start_queue(self):
        if self.is_running or not self.jobs:
            if not self.jobs:
                messagebox.showinfo(t(self.lang, "app_title"), t(self.lang, "no_files_selected"))
            return
        if not activation.is_unlocked():
            self._open_activation()
            return
        self.settings["last_mode"] = self.mode_var.get()
        self.settings["last_codec"] = self.codec_var.get()
        config.save(self.settings)

        self.is_running = True
        self.start_btn.pack_forget()
        self.stop_btn.pack(fill="x", padx=14, pady=(24, 8), side="bottom")
        threading.Thread(target=self._run_queue, daemon=True).start()

    def _stop_queue(self):
        # Portat din varianta Python originala (Converter.stop()/
        # _stop_requested) care exista deja in converter.py dar nu era
        # niciodata apelata din UI — varianta Swift avea aceeasi lipsa
        # (nicio cale de a opri o coada in curs), reparata acum pe ambele.
        self.converter.stop()

    def _run_queue(self):
        mode = self.mode_var.get()
        codec = self.codec_var.get()
        dest_dir = self.settings.get("last_destination") or ""

        for job in self.jobs:
            if self.converter._stop_requested:
                self._update_status(job, t(self.lang, "status_waiting"))
                continue

            src = job["path"]
            base = os.path.splitext(os.path.basename(src))[0]
            ext = self.converter.output_extension(mode, codec)
            out_dir = dest_dir or os.path.dirname(src)
            out_path = os.path.join(out_dir, f"{base}_convertit.{ext}")

            self._update_status(job, t(self.lang, "status_processing"))

            def on_progress(p, job=job):
                self._update_progress(job, p)

            result = self.converter.convert(src, out_path, mode, codec, on_progress)

            if result["success"]:
                self._update_status(job, t(self.lang, "conversion_complete"))
            elif "Anulat" in (result["error"] or ""):
                self._update_status(job, t(self.lang, "status_canceled"))
            else:
                self._update_status(job, t(self.lang, "error") + ": " + (result["error"] or ""))

        self.is_running = False
        self.after(0, self._on_queue_finished)

    def _on_queue_finished(self):
        self.stop_btn.pack_forget()
        self.start_btn.pack(fill="x", padx=14, pady=(24, 8), side="bottom")

    def _update_status(self, job, text):
        self.after(0, lambda: self.tree.set(job["item_id"], "status", text))

    def _update_progress(self, job, fraction):
        pct = int(fraction * 100)
        self.after(0, lambda: self.tree.set(job["item_id"], "status",
                                             f'{t(self.lang, "status_processing")} {pct}%'))

    def _show_ffmpeg_warning(self):
        messagebox.showwarning(
            t(self.lang, "app_title"),
            "FFmpeg nu a fost gasit. Aplicatia standalone ar trebui sa il includa — "
            "verifica build-ul PyInstaller."
        )

    # ── Actualizari ──────────────────────────────────────────────────

    def _check_updates_silently(self):
        def worker():
            result = update_checker.check_for_updates(config.APP_VERSION)
            if result["available"]:
                dismissed_key = f"_dismissed_update_{result['version']}"
                if self.settings.get(dismissed_key):
                    return
                self.after(0, lambda: self._show_update_popup(result["version"], silent=True))
        threading.Thread(target=worker, daemon=True).start()

    def _check_updates_manually(self):
        def worker():
            result = update_checker.check_for_updates(config.APP_VERSION)
            if result.get("error"):
                self.after(0, lambda: messagebox.showerror(t(self.lang, "app_title"), t(self.lang, "update_error")))
            elif result["available"]:
                self.after(0, lambda: self._show_update_popup(result["version"], silent=False))
            else:
                self.after(0, lambda: messagebox.showinfo(
                    t(self.lang, "app_title"), t(self.lang, "update_none")))
        threading.Thread(target=worker, daemon=True).start()

    def _show_update_popup(self, version, silent):
        lang = self.lang
        body = t(lang, "update_available_body", version=version, current=config.APP_VERSION)
        answer = messagebox.askyesno(t(lang, "update_available_title"), body)
        if answer:
            import webbrowser
            webbrowser.open(update_checker.RELEASES_PAGE_URL)
        if silent:
            self.settings[f"_dismissed_update_{version}"] = True
            config.save(self.settings)


if __name__ == "__main__":
    app = CGConvertorApp()
    app.mainloop()
