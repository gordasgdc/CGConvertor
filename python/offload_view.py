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
import webbrowser
from tkinter import filedialog, messagebox, simpledialog, ttk

import camera_card_detector
import io_settings
import naming_template
import production_meta
import transfer_profile
import volume_info
from history_store import shared as history_shared
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

        # ── Producție/branding + șablon nume + card cameră + profile
        # (port DataMover, Etapa 2026-09-03/2026-09-05) ──
        self.meta = production_meta.ProductionMeta()
        self.naming_template_var = tk.StringVar(value=naming_template.DEFAULT_TEMPLATE)
        self.preview_var = tk.StringVar(value="")
        self.card_info_var = tk.StringVar(value="")
        self.parent_warning_var = tk.StringVar(value="")
        self.meta_vars = {
            "project": tk.StringVar(), "card": tk.StringVar(), "client": tk.StringVar(),
            "camera": tk.StringVar(), "operator_name": tk.StringVar(),
        }
        for key, var in self.meta_vars.items():
            var.trace_add("write", lambda *_a, k=key, v=var: (setattr(self.meta, k, v.get()), self._update_preview()))
        self.naming_template_var.trace_add("write", lambda *_a: self._update_preview())

        self.runner.set_on_update(lambda: self.after(0, self._refresh_from_runner))
        self._build()
        self._refresh_from_runner()
        self._update_preview()
        self._update_card_info()

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
        # Bug UX real, raportat de Cristi (2026-09-05): fara buton de
        # golire a Sursei, trebuia sa navigheze in fata/spate sau sa
        # reporneasca aplicatia. Identic vizual cu "x"-ul destinatiilor.
        self.source_clear_btn = tk.Label(row, text="✕", bg=th["bg_panel"], fg=th["fg_faint"],
                                          cursor="hand2", font=self.app._fm(9))
        self.source_clear_btn.bind("<Button-1>", lambda e: self._clear_source())
        if self.source_path:
            self.source_clear_btn.pack(side="right", padx=(0, 8))
        # Recunoasterea structurii de card (port DataMover) — pur informativ.
        tk.Label(src_frame, textvariable=self.card_info_var, bg=th["bg_panel"], fg=th["accent"],
                 font=self.app._fm(9), anchor="w", wraplength=420, justify="left").pack(fill="x", padx=12)
        tk.Label(src_frame, textvariable=self.parent_warning_var, bg=th["bg_panel"], fg="#D08C40",
                 font=self.app._fm(9), anchor="w", wraplength=420, justify="left").pack(fill="x", padx=12, pady=(0, 6))

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

        # ── Producție/branding (port DataMover ProductionMeta) ──
        prod_frame = tk.Frame(self, bg=th["bg_panel"])
        prod_frame.pack(fill="x", **pad)
        tk.Label(prod_frame, text=self._t("offload_production_title"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 4))
        grid = tk.Frame(prod_frame, bg=th["bg_panel"])
        grid.pack(fill="x", padx=12, pady=(0, 6))
        fields = [
            ("project", self._t("offload_production_project")), ("card", self._t("offload_production_card")),
            ("client", self._t("offload_production_client")), ("camera", self._t("offload_production_camera")),
            ("operator_name", self._t("offload_production_operator")),
        ]
        for i, (key, label) in enumerate(fields):
            r, c = divmod(i, 2)
            cell = tk.Frame(grid, bg=th["bg_panel"])
            cell.grid(row=r, column=c, sticky="ew", padx=(0, 10), pady=3)
            tk.Label(cell, text=label, bg=th["bg_panel"], fg=th["fg_dim"], font=self.app._fm(9), width=12, anchor="w").pack(side="left")
            tk.Entry(cell, textvariable=self.meta_vars[key], bg=th["bg_elevated"], fg=th["fg"],
                     insertbackground=th["fg"], relief="flat", font=self.app._fm(9)).pack(side="left", fill="x", expand=True)
        grid.grid_columnconfigure(0, weight=1)
        grid.grid_columnconfigure(1, weight=1)
        logo_row = tk.Frame(prod_frame, bg=th["bg_panel"])
        logo_row.pack(fill="x", padx=12, pady=(0, 10))
        tk.Label(logo_row, text=self._t("offload_production_logo"), bg=th["bg_panel"], fg=th["fg_dim"], font=self.app._fm(9)).pack(side="left")
        self.logo_label = tk.Label(logo_row, text=self._t("offload_no_logo"), bg=th["bg_panel"], fg=th["fg_faint"], font=self.app._fm(9))
        self.logo_label.pack(side="left", padx=8)
        ttk.Button(logo_row, text=self._t("offload_choose_logo"), style="Ghost.TButton", cursor="hand2",
                   command=self._choose_logo).pack(side="right")

        # ── Sablon nume folder (port DataMover NamingTemplate) ──
        naming_frame = tk.Frame(self, bg=th["bg_panel"])
        naming_frame.pack(fill="x", **pad)
        tk.Label(naming_frame, text=self._t("offload_naming_title"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(anchor="w", padx=12, pady=(10, 4))
        tk.Entry(naming_frame, textvariable=self.naming_template_var, bg=th["bg_elevated"], fg=th["fg"],
                 insertbackground=th["fg"], relief="flat", font=self.app._fm(9)).pack(fill="x", padx=12)
        tok_row = tk.Frame(naming_frame, bg=th["bg_panel"])
        tok_row.pack(fill="x", padx=12, pady=(4, 0))
        for token in naming_template.TOKENS:
            ttk.Button(tok_row, text=token, style="Lang.TButton", cursor="hand2",
                       command=lambda t=token: self.naming_template_var.set(self.naming_template_var.get() + t)
                       ).pack(side="left", padx=(0, 4))
        tk.Label(naming_frame, textvariable=self.preview_var, bg=th["bg_panel"], fg=th["accent"],
                 font=self.app._fm(9)).pack(anchor="w", padx=12, pady=(4, 10))

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

        # ── Profile de transfer (port DataMover TransferProfile) ──
        profiles_frame = tk.Frame(self, bg=th["bg_panel"])
        profiles_frame.pack(fill="x", **pad)
        prow = tk.Frame(profiles_frame, bg=th["bg_panel"])
        prow.pack(fill="x", padx=12, pady=(10, 2))
        tk.Label(prow, text=self._t("offload_profiles_title"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(11, "bold")).pack(side="left")
        ttk.Button(prow, text=self._t("offload_save_profile"), style="Ghost.TButton", cursor="hand2",
                   command=self._save_profile).pack(side="right")
        self.profiles_list_frame = tk.Frame(profiles_frame, bg=th["bg_panel"])
        self.profiles_list_frame.pack(fill="x", padx=12, pady=(0, 10))
        self._render_profiles()

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
        ttk.Button(btn_row, text=self._t("offload_history"), style="Ghost.TButton", cursor="hand2",
                   command=self._show_history).pack(side="right")
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
        self._refresh_source_clear_btn()

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
            self._update_card_info()
            self._refresh_source_clear_btn()

    def _clear_source(self):
        """Bug UX real, raportat de Cristi (2026-09-05) — vezi butonul
        "x" adaugat langa Sursa in _build."""
        self.source_path = None
        self.app.offload_source_path = None
        self.source_label.config(text=self._t("offload_choose_source"), fg=self.th["fg_faint"])
        self._update_card_info()
        self._refresh_source_clear_btn()

    def _refresh_source_clear_btn(self):
        if self.source_path:
            self.source_clear_btn.pack(side="right", padx=(0, 8))
        else:
            self.source_clear_btn.pack_forget()

    def _update_card_info(self):
        """Recunoasterea structurii de card (port DataMover) — pur
        informativ, NU blocheaza niciodata transferul."""
        if not self.source_path:
            self.card_info_var.set("")
            self.parent_warning_var.set("")
            return
        info = camera_card_detector.detect(self.source_path)
        self.card_info_var.set(camera_card_detector.summary(info) if info else "")
        if info and info["warnings"]:
            self.card_info_var.set(self.card_info_var.get() + "  ⚠ " + " · ".join(info["warnings"]))
        parent = camera_card_detector.parent_looks_like_card(self.source_path)
        self.parent_warning_var.set(
            self._t("offload_card_parent_warning", p=os.path.basename(parent)) if parent else ""
        )

    def _update_preview(self):
        name = naming_template.render(
            self.naming_template_var.get(), project=self.meta.project, card=self.meta.card,
            camera=self.meta.camera, operator_name=self.meta.operator_name,
        )
        self.preview_var.set(f"{self._t('offload_naming_preview')}: {name}")

    def _choose_logo(self):
        path = filedialog.askopenfilename(filetypes=[("Imagini", "*.png *.jpg *.jpeg")])
        if path:
            self.meta.logo_path = path
            self.logo_label.config(text=os.path.basename(path))

    def _render_profiles(self):
        for w in self.profiles_list_frame.winfo_children():
            w.destroy()
        profiles = transfer_profile.shared().profiles
        if not profiles:
            tk.Label(self.profiles_list_frame, text=self._t("offload_no_profiles"),
                     bg=self.th["bg_panel"], fg=self.th["fg_faint"], font=self.app._fm(9)).pack(anchor="w")
            return
        for profile in profiles:
            row = tk.Frame(self.profiles_list_frame, bg=self.th["bg_panel"])
            row.pack(fill="x", pady=1)
            tk.Label(row, text=profile["name"], bg=self.th["bg_panel"], fg=self.th["fg"],
                     font=self.app._fm(9), anchor="w").pack(side="left", fill="x", expand=True)
            ttk.Button(row, text=self._t("offload_load_profile"), style="Ghost.TButton", cursor="hand2",
                       command=lambda p=profile: self._load_profile(p)).pack(side="right")
            tk.Label(row, text="✕", bg=self.th["bg_panel"], fg=self.th["fg_faint"], cursor="hand2",
                     font=self.app._fm(9)).pack(side="right", padx=(0, 6))
            row.winfo_children()[-1].bind("<Button-1>", lambda e, p=profile: self._delete_profile(p))

    def _save_profile(self):
        name = simpledialog.askstring(self._t("offload_profile_name_prompt"), self._t("offload_profile_name_prompt"), parent=self)
        if not name:
            return
        profile = {
            "name": name, "source_paths": [self.source_path] if self.source_path else [],
            "destination_paths": list(self.destinations), "verification_model": self.verify_var.get(),
            "chunk_mb": self._parse_combo(self.chunk_var.get(), io_settings.CHUNK_SIZE_CHOICES_MB),
            "ram_limit_mb": self._parse_combo(self.ram_var.get(), io_settings.RAM_LIMIT_CHOICES_MB),
            "naming_template": self.naming_template_var.get(), "project": self.meta.project,
            "client": self.meta.client, "camera": self.meta.camera, "operator_name": self.meta.operator_name,
        }
        transfer_profile.shared().upsert(profile)
        self._render_profiles()

    def _parse_combo(self, label, choices):
        for mb in choices:
            if io_settings.formatted_mb(mb) == label:
                return mb
        return choices[0]

    def _load_profile(self, profile):
        if profile.get("source_paths"):
            self.source_path = profile["source_paths"][0]
            self.app.offload_source_path = self.source_path
            self.source_label.config(text=self.source_path, fg=self.th["fg_dim"])
            self._update_card_info()
            self._refresh_source_clear_btn()
        self.destinations = list(profile.get("destination_paths", []))
        self.app.offload_destinations = list(self.destinations)
        self._render_destinations()
        self.verify_var.set(profile.get("verification_model", "xxhash64"))
        self.chunk_var.set(io_settings.formatted_mb(profile.get("chunk_mb", io_settings.DEFAULT_CHUNK_MB)))
        self.ram_var.set(io_settings.formatted_mb(profile.get("ram_limit_mb", io_settings.DEFAULT_RAM_LIMIT_MB)))
        self._save_io_settings()
        self.naming_template_var.set(profile.get("naming_template", naming_template.DEFAULT_TEMPLATE))
        self.meta.project = profile.get("project", "")
        self.meta.client = profile.get("client", "")
        self.meta.camera = profile.get("camera", "")
        self.meta.operator_name = profile.get("operator_name", "")
        for key in ("project", "client", "camera", "operator_name"):
            self.meta_vars[key].set(getattr(self.meta, key))

    def _delete_profile(self, profile):
        transfer_profile.shared().delete(profile["name"])
        self._render_profiles()

    def _show_history(self):
        from history_view import HistoryDialog
        HistoryDialog(self, self.app)

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

    def _start(self, ignore_space_warning=False):
        if not self.source_path or not self.destinations:
            return
        self.app.offload_verify_model = self.verify_var.get()
        self.runner.cfg = self.app.settings
        import config
        app_version = config.APP_VERSION
        self.runner.start(self.source_path, list(self.destinations), self.verify_var.get(), self._t,
                           meta=self.meta, naming_tmpl=self.naming_template_var.get(),
                           app_version=app_version, ignore_space_warning=ignore_space_warning)
        if self.runner.insufficient_space_warning:
            proceed = messagebox.askyesno(
                self._t("offload_insufficient_space_title"),
                f"{self.runner.insufficient_space_warning}\n\n{self._t('offload_insufficient_space_confirm')}",
            )
            if proceed:
                self._start(ignore_space_warning=True)

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
                if result.get("recovered"):
                    text += f" · ↻{result['recovered']}"
                tk.Label(row, text=text, bg=self.th["bg_panel"], fg=self.th["fg"],
                         font=self.app._fm(10)).pack(side="left")
                report_path = result.get("html_path") or result["csv_path"]
                link = tk.Label(row, text=self._t("offload_open_report"), bg=self.th["bg_panel"],
                                 fg=self.th["accent"], cursor="hand2", font=self.app._fm(9))
                link.pack(side="left", padx=(10, 0))
                if result.get("html_path"):
                    link.bind("<Button-1>", lambda e, p=report_path: webbrowser.open(f"file://{p}"))
                else:
                    link.bind("<Button-1>", lambda e, p=report_path: _open_in_file_manager(p))
                if result.get("mhl_path"):
                    tk.Label(row, text="✓ MHL", bg=self.th["bg_panel"], fg=self.th.get("success", "#4ADE80"),
                             font=self.app._fm(9)).pack(side="left", padx=(10, 0))

        if r.is_running:
            self.start_btn.pack_forget()
            self.pause_btn.config(text=self._t("offload_resume") if r.is_paused else self._t("offload_pause"))
            self.pause_btn.pack(side="left")
            self.cancel_btn.pack(side="left", padx=(6, 0))
        else:
            self.pause_btn.pack_forget()
            self.cancel_btn.pack_forget()
            self.start_btn.pack(side="left")
