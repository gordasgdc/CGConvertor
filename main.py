# main.py
import os
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
    HAS_DND = True
except ImportError:
    HAS_DND = False

import config
import theme
from translations import t
from converter import Converter, CODEC_ARGS

BASE_CLASS = TkinterDnD.Tk if HAS_DND else tk.Tk


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
        self.geometry("880x600")
        self.minsize(760, 520)
        self.configure(bg=self.th["bg"])

        self._build_ui()
        self._refresh_texts()

        if not self.converter.is_available():
            self._show_ffmpeg_warning()

    # ── UI construction ──────────────────────────────────────────────

    def _build_ui(self):
        th = self.th

        header = tk.Frame(self, bg=th["bg"])
        header.pack(fill="x", padx=20, pady=(18, 8))

        self.title_label = tk.Label(header, font=(theme.FONT_FAMILY, 20, "bold"),
                                     bg=th["bg"], fg=th["fg"])
        self.title_label.pack(anchor="w")
        self.subtitle_label = tk.Label(header, font=(theme.FONT_FAMILY, 11),
                                        bg=th["bg"], fg=th["fg_dim"])
        self.subtitle_label.pack(anchor="w")

        body = tk.Frame(self, bg=th["bg"])
        body.pack(fill="both", expand=True, padx=20, pady=10)

        # ── Panou stanga: setari ──
        left = tk.Frame(body, bg=th["bg_panel"], width=260)
        left.pack(side="left", fill="y", padx=(0, 14))
        left.pack_propagate(False)

        self.mode_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                    font=(theme.FONT_FAMILY, 11, "bold"))
        self.mode_label.pack(anchor="w", padx=14, pady=(16, 4))

        self.mode_var = tk.StringVar(value=self.settings["last_mode"])
        self.rewrap_radio = tk.Radiobutton(
            left, variable=self.mode_var, value="rewrap",
            bg=th["bg_panel"], fg=th["fg"], selectcolor=th["bg_elevated"],
            activebackground=th["bg_panel"], command=self._on_mode_change)
        self.rewrap_radio.pack(anchor="w", padx=10)
        self.transcode_radio = tk.Radiobutton(
            left, variable=self.mode_var, value="transcode",
            bg=th["bg_panel"], fg=th["fg"], selectcolor=th["bg_elevated"],
            activebackground=th["bg_panel"], command=self._on_mode_change)
        self.transcode_radio.pack(anchor="w", padx=10)

        self.codec_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                     font=(theme.FONT_FAMILY, 11, "bold"))
        self.codec_label.pack(anchor="w", padx=14, pady=(16, 4))

        self.codec_var = tk.StringVar(value=self.settings["last_codec"])
        self.codec_menu = ttk.Combobox(left, textvariable=self.codec_var,
                                        values=list(CODEC_ARGS.keys()),
                                        state="readonly")
        self.codec_menu.pack(fill="x", padx=14)

        self.dest_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg"],
                                    font=(theme.FONT_FAMILY, 11, "bold"))
        self.dest_label.pack(anchor="w", padx=14, pady=(20, 4))

        self.dest_path_label = tk.Label(left, bg=th["bg_panel"], fg=th["fg_dim"],
                                         font=(theme.FONT_FAMILY, 9), wraplength=220,
                                         justify="left")
        self.dest_path_label.pack(anchor="w", padx=14)

        self.choose_folder_btn = tk.Button(left, command=self._choose_destination,
                                            bg=th["bg_elevated"], fg=th["fg"],
                                            relief="flat", cursor="hand2")
        self.choose_folder_btn.pack(fill="x", padx=14, pady=8)

        self.start_btn = tk.Button(left, command=self._start_queue,
                                    bg=th["accent"], fg="#141414",
                                    relief="flat", cursor="hand2",
                                    font=(theme.FONT_FAMILY, 11, "bold"), height=2)
        self.start_btn.pack(fill="x", padx=14, pady=(24, 14), side="bottom")

        # limba
        lang_frame = tk.Frame(left, bg=th["bg_panel"])
        lang_frame.pack(fill="x", padx=14, pady=(0, 8), side="bottom")
        for code in ("ro", "en", "es"):
            tk.Button(lang_frame, text=code.upper(), width=3,
                      command=lambda c=code: self._set_language(c),
                      bg=th["bg_elevated"], fg=th["fg"], relief="flat",
                      cursor="hand2").pack(side="left", padx=2)

        # ── Panou dreapta: lista de fisiere ──
        right = tk.Frame(body, bg=th["bg"])
        right.pack(side="left", fill="both", expand=True)

        self.drop_frame = tk.Frame(right, bg=th["bg_panel"], highlightbackground=th["line"],
                                    highlightthickness=1)
        self.drop_frame.pack(fill="both", expand=True)

        self.drop_label = tk.Label(self.drop_frame, bg=th["bg_panel"], fg=th["fg_dim"],
                                    font=(theme.FONT_FAMILY, 13))
        self.drop_label.pack(pady=(40, 6))

        self.choose_files_btn = tk.Button(self.drop_frame, command=self._choose_files,
                                           bg=th["bg_elevated"], fg=th["fg"],
                                           relief="flat", cursor="hand2")
        self.choose_files_btn.pack()

        self.tree = ttk.Treeview(self.drop_frame, columns=("status",), show="tree headings",
                                  height=14)
        self.tree.heading("#0", text="Fisier")
        self.tree.heading("status", text="Status")
        self.tree.column("#0", width=420)
        self.tree.column("status", width=200)

        bottom_bar = tk.Frame(right, bg=th["bg"])
        bottom_bar.pack(fill="x", pady=(8, 0))
        self.clear_btn = tk.Button(bottom_bar, command=self._clear_list,
                                    bg=th["bg_elevated"], fg=th["fg"], relief="flat",
                                    cursor="hand2")
        self.clear_btn.pack(side="left")

        if HAS_DND:
            self.drop_frame.drop_target_register(DND_FILES)
            self.drop_frame.dnd_bind("<<Drop>>", self._on_drop)

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
        self.drop_label.config(text=f'{t(lang, "drag_files_here")}\n{t(lang, "drag_files_hint")}')
        self.choose_files_btn.config(text=t(lang, "choose_files"))
        self.clear_btn.config(text=t(lang, "clear_list"))
        self._on_mode_change()

    def _on_mode_change(self):
        if self.mode_var.get() == "transcode":
            self.codec_menu.pack(fill="x", padx=14)
        else:
            self.codec_menu.pack_forget()

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
        self.settings["last_mode"] = self.mode_var.get()
        self.settings["last_codec"] = self.codec_var.get()
        config.save(self.settings)

        self.is_running = True
        self.start_btn.config(state="disabled")
        threading.Thread(target=self._run_queue, daemon=True).start()

    def _run_queue(self):
        mode = self.mode_var.get()
        codec = self.codec_var.get()
        dest_dir = self.settings.get("last_destination") or ""

        for job in self.jobs:
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
            else:
                self._update_status(job, t(self.lang, "error") + ": " + (result["error"] or ""))

        self.is_running = False
        self.after(0, lambda: self.start_btn.config(state="normal"))

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


if __name__ == "__main__":
    app = CGConvertorApp()
    app.mainloop()
