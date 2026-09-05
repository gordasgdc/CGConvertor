# offload_view.py
"""Panou Tkinter pentru Offload/Checksum — vezi `offload_engine.py` pentru
scopul deliberat redus fata de `DataMover`. Construit din nou la fiecare
`_rebuild_ui()` (Regula 18/24 — teardown+rebuild complet la schimbare de
tema/marime font, acelasi tipar ca restul aplicatiei) — starea motorului
(`OffloadRunner`) traieste separat, pe `app.offload_runner`, si
supravietuieste rebuild-urilor."""

import os
import subprocess
import sys
import tkinter as tk
from tkinter import filedialog, ttk

import io_settings
import volume_info
from offload_engine import VERIFICATION_MODELS


def _open_in_file_manager(path):
    if sys.platform == "darwin":
        subprocess.run(["open", "-R", path])
    elif sys.platform == "win32":
        subprocess.run(["explorer", "/select,", path])


class OffloadPanel(tk.Frame):
    def __init__(self, parent, app):
        super().__init__(parent, bg=app.th["bg"])
        self.app = app
        self.th = app.th
        self.runner = app.offload_runner
        self.destinations = list(getattr(app, "offload_destinations", []))
        self.source_path = getattr(app, "offload_source_path", None)
        self.verify_var = tk.StringVar(value=getattr(app, "offload_verify_model", "xxhash64"))
        self.chunk_var = tk.StringVar(value=io_settings.formatted_mb(
            app.settings.get("offload_chunk_mb", io_settings.DEFAULT_CHUNK_MB)))
        self.ram_var = tk.StringVar(value=io_settings.formatted_mb(
            app.settings.get("offload_ram_limit_mb", io_settings.DEFAULT_RAM_LIMIT_MB)))

        self.runner.set_on_update(lambda: self.after(0, self._refresh_from_runner))
        self._build()
        self._refresh_from_runner()

    def _t(self, key, **kwargs):
        from translations import t
        return t(self.app.lang, key, **kwargs)

    def _build(self):
        th = self.th
        pad = {"padx": 14, "pady": 8}

        # ttk "clam" (setat global de `_setup_style`) nu mosteneste implicit
        # fundalul intunecat pe TRadiobutton — configurat explicit aici,
        # prima data cand acest panou apare, ca textul sa nu ramana pe un
        # fundal deschis nepotrivit temei.
        style = ttk.Style(self)
        style.configure("Offload.TRadiobutton", background=th["bg_panel"], foreground=th["fg"], font=self.app._f(10))
        style.map("Offload.TRadiobutton", background=[("active", th["bg_panel"])])

        # ── Discuri detectate (2026-09-05, cerere explicita, repetata —
        # vezi CLAUDE.md): listeaza discurile/cardurile montate, cu spatiu
        # liber, in loc sa lase userul sa scrie/aleaga doar dintr-un dialog
        # de folder gol — la fel ca panoul echivalent din DataMover. ──
        vol_frame = tk.Frame(self, bg=th["bg_panel"])
        vol_frame.pack(fill="x", **pad)
        vol_head = tk.Frame(vol_frame, bg=th["bg_panel"])
        vol_head.pack(fill="x", padx=12, pady=(10, 2))
        tk.Label(vol_head, text=self._t("offload_volumes_title"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(side="left")
        ttk.Button(vol_head, text="↻", width=3, style="Ghost.TButton",
                   command=self._refresh_volumes, cursor="hand2").pack(side="right")
        self.volumes_row = tk.Frame(vol_frame, bg=th["bg_panel"])
        self.volumes_row.pack(fill="x", padx=12, pady=(0, 10))
        self._refresh_volumes()

        # ── Sursa ──
        src_frame = tk.Frame(self, bg=th["bg_panel"])
        src_frame.pack(fill="x", **pad)
        tk.Label(src_frame, text=self._t("offload_source"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 2))
        row = tk.Frame(src_frame, bg=th["bg_panel"])
        row.pack(fill="x", padx=12, pady=(0, 10))
        self.source_label = tk.Label(row, text=self.source_path or self._t("offload_choose_source"),
                                      bg=th["bg_panel"], fg=th["fg_dim"] if self.source_path else th["fg_faint"],
                                      font=self.app._fm(9), anchor="w")
        self.source_label.pack(side="left", fill="x", expand=True)
        ttk.Button(row, text=self._t("offload_choose_source"), style="Ghost.TButton",
                   command=self._choose_source, cursor="hand2").pack(side="right")

        # ── Destinatii ──
        dest_frame = tk.Frame(self, bg=th["bg_panel"])
        dest_frame.pack(fill="x", **pad)
        head = tk.Frame(dest_frame, bg=th["bg_panel"])
        head.pack(fill="x", padx=12, pady=(10, 2))
        tk.Label(head, text=self._t("offload_destinations"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(side="left")
        ttk.Button(head, text=self._t("offload_add_destination"), style="Ghost.TButton",
                   command=self._add_destination, cursor="hand2").pack(side="right")
        self.dest_list_frame = tk.Frame(dest_frame, bg=th["bg_panel"])
        self.dest_list_frame.pack(fill="x", padx=12, pady=(0, 10))
        self._render_destinations()

        # ── Verificare ──
        verify_frame = tk.Frame(self, bg=th["bg_panel"])
        verify_frame.pack(fill="x", **pad)
        tk.Label(verify_frame, text=self._t("offload_verify"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 2))
        vrow = tk.Frame(verify_frame, bg=th["bg_panel"])
        vrow.pack(fill="x", padx=12, pady=(0, 10))
        labels = {
            "xxhash64": f"xxHash64 ({self._t('offload_verify_recommended')})",
            "md5": "MD5", "sha1": "SHA-1", "sha256": "SHA-256",
            "size_only": self._t("offload_size_only"),
        }
        for model in VERIFICATION_MODELS:
            ttk.Radiobutton(vrow, text=labels[model], variable=self.verify_var, value=model,
                            style="Offload.TRadiobutton").pack(anchor="w")

        # ── Buffer & Memorie ──
        io_frame = tk.Frame(self, bg=th["bg_panel"])
        io_frame.pack(fill="x", **pad)
        tk.Label(io_frame, text=self._t("offload_io_title"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 4))
        brow = tk.Frame(io_frame, bg=th["bg_panel"])
        brow.pack(fill="x", padx=12)
        tk.Label(brow, text=self._t("offload_buffer"), bg=th["bg_panel"], fg=th["fg_dim"],
                 font=self.app._fm(9)).pack(side="left")
        chunk_combo = ttk.Combobox(brow, textvariable=self.chunk_var, state="readonly", width=8,
                                    values=[io_settings.formatted_mb(mb) for mb in io_settings.CHUNK_SIZE_CHOICES_MB])
        chunk_combo.pack(side="right")
        chunk_combo.bind("<<ComboboxSelected>>", lambda e: self._save_io_settings())
        rrow = tk.Frame(io_frame, bg=th["bg_panel"])
        rrow.pack(fill="x", padx=12, pady=(6, 10))
        tk.Label(rrow, text=self._t("offload_ram_limit"), bg=th["bg_panel"], fg=th["fg_dim"],
                 font=self.app._fm(9)).pack(side="left")
        ram_combo = ttk.Combobox(rrow, textvariable=self.ram_var, state="readonly", width=8,
                                  values=[io_settings.formatted_mb(mb) for mb in io_settings.RAM_LIMIT_CHOICES_MB])
        ram_combo.pack(side="right")
        ram_combo.bind("<<ComboboxSelected>>", lambda e: self._save_io_settings())
        preset_row = tk.Frame(io_frame, bg=th["bg_panel"])
        preset_row.pack(fill="x", padx=12, pady=(0, 10))
        for preset in io_settings.PRESETS:
            ttk.Button(preset_row, text=preset["name"], style="Lang.TButton", cursor="hand2",
                       command=lambda p=preset: self._apply_preset(p)).pack(side="left", padx=(0, 4))

        # ── Activitate ──
        self.activity_frame = tk.Frame(self, bg=th["bg_panel"])
        tk.Label(self.activity_frame, text=self._t("offload_activity"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 2))
        self.activity_text = tk.Text(self.activity_frame, height=6, bg=th["bg_elevated"], fg=th["fg_dim"],
                                      font=self.app._fm(9), relief="flat", wrap="word")
        self.activity_text.pack(fill="x", padx=12, pady=(0, 10))
        self.activity_text.configure(state="disabled")

        # ── Rezultate ──
        self.results_frame = tk.Frame(self, bg=th["bg_panel"])
        tk.Label(self.results_frame, text=self._t("offload_result"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 2))
        self.results_inner = tk.Frame(self.results_frame, bg=th["bg_panel"])
        self.results_inner.pack(fill="x", padx=12, pady=(0, 10))

        # ── Footer: progres + butoane ──
        footer = tk.Frame(self, bg=th["bg"])
        self.footer = footer
        footer.pack(fill="x", padx=14, pady=(0, 14))
        self.progress_bar = ttk.Progressbar(footer, mode="determinate", maximum=100)
        self.progress_bar.pack(fill="x")
        status_row = tk.Frame(footer, bg=th["bg"])
        status_row.pack(fill="x", pady=(4, 8))
        self.status_label = tk.Label(status_row, bg=th["bg"], fg=th["fg_dim"], font=self.app._fm(9), anchor="w")
        self.status_label.pack(side="left")
        self.speed_label = tk.Label(status_row, bg=th["bg"], fg=th["fg_faint"], font=self.app._fm(9))
        self.speed_label.pack(side="right")

        btn_row = tk.Frame(footer, bg=th["bg"])
        btn_row.pack(fill="x")
        self.start_btn = ttk.Button(btn_row, text=self._t("offload_start"), style="Accent.TButton",
                                     cursor="hand2", command=self._start)
        self.pause_btn = ttk.Button(btn_row, text=self._t("offload_pause"), style="Ghost.TButton",
                                     cursor="hand2", command=self._toggle_pause)
        self.cancel_btn = ttk.Button(btn_row, text=self._t("offload_cancel"), style="Stop.TButton",
                                      cursor="hand2", command=self.runner.cancel)
        self.start_btn.pack(side="left")

    def _render_destinations(self):
        for w in self.dest_list_frame.winfo_children():
            w.destroy()
        if not self.destinations:
            tk.Label(self.dest_list_frame, text=self._t("offload_no_destinations"),
                      bg=self.th["bg_panel"], fg=self.th["fg_faint"], font=self.app._fm(9)).pack(anchor="w")
            return
        for dest in self.destinations:
            row = tk.Frame(self.dest_list_frame, bg=self.th["bg_panel"])
            row.pack(fill="x", pady=1)
            tk.Label(row, text=dest, bg=self.th["bg_panel"], fg=self.th["fg_dim"],
                     font=self.app._fm(9), anchor="w").pack(side="left", fill="x", expand=True)
            tk.Label(row, text="✕", bg=self.th["bg_panel"], fg=self.th["fg_faint"], cursor="hand2",
                     font=self.app._fm(9)).pack(side="right")
            row.winfo_children()[-1].bind("<Button-1>", lambda e, d=dest: self._remove_destination(d))

    def _refresh_volumes(self):
        for w in self.volumes_row.winfo_children():
            w.destroy()
        volumes = volume_info.list_volumes()
        if not volumes:
            tk.Label(self.volumes_row, text=self._t("offload_no_volumes"),
                     bg=self.th["bg_panel"], fg=self.th["fg_faint"], font=self.app._fm(9)).pack(anchor="w")
            return
        for vol in volumes:
            chip = tk.Frame(self.volumes_row, bg=self.th["bg_elevated"],
                             highlightbackground=self.th["line"], highlightthickness=1)
            chip.pack(side="left", padx=(0, 8), pady=2)
            tk.Label(chip, text=vol["name"], bg=self.th["bg_elevated"], fg=self.th["fg"],
                     font=self.app._f(9, "bold")).pack(anchor="w", padx=8, pady=(6, 0))
            tk.Label(chip, text=volume_info.format_bytes(vol["free_bytes"]), bg=self.th["bg_elevated"],
                     fg=self.th["fg_faint"], font=self.app._fm(8)).pack(anchor="w", padx=8)
            btn_row = tk.Frame(chip, bg=self.th["bg_elevated"])
            btn_row.pack(anchor="w", padx=6, pady=(2, 6))
            ttk.Button(btn_row, text=self._t("offload_use_as_source"), style="Ghost.TButton", cursor="hand2",
                       command=lambda p=vol["path"]: self._use_volume_as_source(p)).pack(side="left")
            ttk.Button(btn_row, text="+", width=2, style="Ghost.TButton", cursor="hand2",
                       command=lambda p=vol["path"]: self._use_volume_as_destination(p)).pack(side="left", padx=(4, 0))

    def _use_volume_as_source(self, path):
        self.source_path = path
        self.app.offload_source_path = path
        self.source_label.config(text=path, fg=self.th["fg_dim"])

    def _use_volume_as_destination(self, path):
        if path not in self.destinations:
            self.destinations.append(path)
            self.app.offload_destinations = list(self.destinations)
            self._render_destinations()

    def _choose_source(self):
        path = filedialog.askdirectory()
        if path:
            self.source_path = path
            self.app.offload_source_path = path
            self.source_label.config(text=path, fg=self.th["fg_dim"])

    def _add_destination(self):
        path = filedialog.askdirectory()
        if path and path not in self.destinations:
            self.destinations.append(path)
            self.app.offload_destinations = list(self.destinations)
            self._render_destinations()

    def _remove_destination(self, dest):
        self.destinations = [d for d in self.destinations if d != dest]
        self.app.offload_destinations = list(self.destinations)
        self._render_destinations()

    def _apply_preset(self, preset):
        self.chunk_var.set(io_settings.formatted_mb(preset["chunk_mb"]))
        self.ram_var.set(io_settings.formatted_mb(preset["ram_limit_mb"]))
        self.app.settings["offload_chunk_mb"] = preset["chunk_mb"]
        self.app.settings["offload_ram_limit_mb"] = preset["ram_limit_mb"]
        import config
        config.save(self.app.settings)

    def _save_io_settings(self):
        def parse(label, choices):
            for mb in choices:
                if io_settings.formatted_mb(mb) == label:
                    return mb
            return choices[0]
        self.app.settings["offload_chunk_mb"] = parse(self.chunk_var.get(), io_settings.CHUNK_SIZE_CHOICES_MB)
        self.app.settings["offload_ram_limit_mb"] = parse(self.ram_var.get(), io_settings.RAM_LIMIT_CHOICES_MB)
        import config
        config.save(self.app.settings)

    def _start(self):
        if not self.source_path or not self.destinations:
            return
        self.app.offload_verify_model = self.verify_var.get()
        self.runner.cfg = self.app.settings
        self.runner.start(self.source_path, list(self.destinations), self.verify_var.get(), self._t)

    def _toggle_pause(self):
        self.runner.toggle_pause()

    def _refresh_from_runner(self):
        r = self.runner
        self.progress_bar["value"] = r.progress_percent
        self.status_label.config(text=r.status_text)
        self.speed_label.config(text=r.speed_text if r.is_running else "")

        self.activity_text.configure(state="normal")
        self.activity_text.delete("1.0", "end")
        self.activity_text.insert("end", "\n".join(r.activity_log[-50:]))
        self.activity_text.configure(state="disabled")
        if r.activity_log:
            if not self.activity_frame.winfo_ismapped():
                self.activity_frame.pack(fill="x", padx=14, pady=8, before=self.footer)
        else:
            self.activity_frame.pack_forget()

        for w in self.results_inner.winfo_children():
            w.destroy()
        if r.last_results:
            if not self.results_frame.winfo_ismapped():
                self.results_frame.pack(fill="x", padx=14, pady=8, before=self.footer)
            for result in r.last_results:
                row = tk.Frame(self.results_inner, bg=self.th["bg_panel"])
                row.pack(fill="x", anchor="w", pady=2)
                text = f"{os.path.basename(result['destination'])} — OK: {result['ok']} · " \
                       f"{result['mismatch']} · {result['errors']}"
                tk.Label(row, text=text, bg=self.th["bg_panel"], fg=self.th["fg"],
                         font=self.app._fm(10)).pack(side="left")
                link = tk.Label(row, text=self._t("offload_open_report"), bg=self.th["bg_panel"],
                                 fg=self.th["accent"], cursor="hand2", font=self.app._fm(9))
                link.pack(side="left", padx=(10, 0))
                link.bind("<Button-1>", lambda e, p=result["csv_path"]: _open_in_file_manager(p))

        if r.is_running:
            self.start_btn.pack_forget()
            self.pause_btn.config(text=self._t("offload_resume") if r.is_paused else self._t("offload_pause"))
            self.pause_btn.pack(side="left")
            self.cancel_btn.pack(side="left", padx=(6, 0))
        else:
            self.pause_btn.pack_forget()
            self.cancel_btn.pack_forget()
            self.start_btn.pack(side="left")
