"""
presets_dialog.py — CRUD complet pentru Presets Manager (CLAUDE.md, Faza 1
v3.0.0, sectiunea D). Layout list-detail: Listbox cu toate presetarile in
stanga, formular de editare in dreapta. Presetarile `is_builtin` pot fi
doar duplicate, nu editate/sterse direct (un punct de plecare stabil,
mereu disponibil, indiferent cate presetari custom adauga/strica userul).
"""

import os
import uuid
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

import format_registry
import presets_manager as pm
import theme


class PresetsDialog(tk.Toplevel):
    def __init__(self, master, presets, lang, t, on_change):
        super().__init__(master)
        self.th = master.th
        self.lang = lang
        self.t = t
        self.on_change = on_change
        self.presets = [pm.OutputPreset.from_dict(p.to_dict()) for p in presets]  # copie de lucru
        self.selected_index = None
        self._suspend_trace = False

        self.title(self.t(self.lang, "presets_dialog_title"))
        self.geometry("760x480")
        self.minsize(680, 440)
        self.configure(bg=self.th["bg"])

        self._build_maps()
        self._build_ui()
        self._refresh_list()
        if self.presets:
            self.listbox.selection_set(0)
            self._on_select(None)

        self.grab_set()
        self.transient(master)
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # ── Mapari afisare <-> id intern ─────────────────────────────────
    def _build_maps(self):
        lang, t = self.lang, self.t
        self.target_app_ids = ["davinci", "premiere", "fcp", "avid", "web", "custom"]
        self.target_app_labels = {tid: t(lang, f"target_app_{tid}") for tid in self.target_app_ids}
        self.target_app_labels_rev = {v: k for k, v in self.target_app_labels.items()}

        self.profile_ids = [pm.REWRAP_PROFILE_ID] + [p.id for p in format_registry.ALL_PROFILES]
        self.profile_labels = {pm.REWRAP_PROFILE_ID: t(lang, "rewrap")}
        self.profile_labels.update({p.id: p.label for p in format_registry.ALL_PROFILES})
        self.profile_labels_rev = {v: k for k, v in self.profile_labels.items()}

        self.audio_ids = [pm.AUDIO_PASSTHROUGH, pm.AUDIO_PCM16, pm.AUDIO_PCM24, pm.AUDIO_AAC]
        self.audio_labels = {aid: t(lang, f"audio_{aid}") for aid in self.audio_ids}
        self.audio_labels_rev = {v: k for k, v in self.audio_labels.items()}

        self.channel_ids = [pm.CHANNEL_ORIGINAL, pm.CHANNEL_STEREO, pm.CHANNEL_5_1]
        channel_key = {pm.CHANNEL_ORIGINAL: "channel_original", pm.CHANNEL_STEREO: "channel_stereo", pm.CHANNEL_5_1: "channel_5_1"}
        self.channel_labels = {cid: t(lang, channel_key[cid]) for cid in self.channel_ids}
        self.channel_labels_rev = {v: k for k, v in self.channel_labels.items()}

    # ── UI ────────────────────────────────────────────────────────────
    def _build_ui(self):
        th = self.th
        body = tk.Frame(self, bg=th["bg"])
        body.pack(fill="both", expand=True, padx=16, pady=16)

        left = tk.Frame(body, bg=th["bg_panel"], width=240)
        left.pack(side="left", fill="y", padx=(0, 12))
        left.pack_propagate(False)

        self.listbox = tk.Listbox(left, bg=th["bg_elevated"], fg=th["fg"],
                                   selectbackground=th["accent"], selectforeground=th["accent_ink"],
                                   relief="flat", highlightthickness=0, activestyle="none")
        self.listbox.pack(fill="both", expand=True, padx=8, pady=8)
        self.listbox.bind("<<ListboxSelect>>", self._on_select)

        btn_row = tk.Frame(left, bg=th["bg_panel"])
        btn_row.pack(fill="x", padx=8, pady=(0, 4))
        ttk.Button(btn_row, text=self.t(self.lang, "presets_new"), command=self._new_preset,
                   style="Ghost.TButton").pack(side="left")
        ttk.Button(btn_row, text=self.t(self.lang, "presets_duplicate"), command=self._duplicate_preset,
                   style="Ghost.TButton").pack(side="left", padx=4)

        btn_row2 = tk.Frame(left, bg=th["bg_panel"])
        btn_row2.pack(fill="x", padx=8, pady=(0, 8))
        ttk.Button(btn_row2, text=self.t(self.lang, "presets_delete"), command=self._delete_preset,
                   style="Ghost.TButton").pack(side="left")

        io_row = tk.Frame(left, bg=th["bg_panel"])
        io_row.pack(fill="x", padx=8, pady=(0, 8))
        ttk.Button(io_row, text=self.t(self.lang, "presets_import"), command=self._import_presets,
                   style="Ghost.TButton").pack(side="left")
        ttk.Button(io_row, text=self.t(self.lang, "presets_export"), command=self._export_presets,
                   style="Ghost.TButton").pack(side="left", padx=4)

        # ── Formular de editare (dreapta) ──
        right = tk.Frame(body, bg=th["bg"])
        right.pack(side="left", fill="both", expand=True)

        self.builtin_hint = tk.Label(right, text=self.t(self.lang, "presets_builtin_hint"),
                                      bg=th["bg_elevated"], fg=th["accent"], wraplength=440,
                                      justify="left", padx=10, pady=6)

        self.form = tk.Frame(right, bg=th["bg_panel"])
        self.form.pack(fill="both", expand=True, pady=(8, 0))

        self.label_var = tk.StringVar()
        self.suffix_var = tk.StringVar()
        self.target_app_var = tk.StringVar()
        self.profile_var = tk.StringVar()
        self.audio_var = tk.StringVar()
        self.channel_var = tk.StringVar()

        self._entry_row("presets_label", self.label_var)
        self._entry_row("presets_suffix", self.suffix_var)
        self._combo_row("presets_target_app", self.target_app_var, list(self.target_app_labels.values()))
        self._combo_row("presets_profile", self.profile_var, list(self.profile_labels.values()))
        self._combo_row("presets_audio_mode", self.audio_var, list(self.audio_labels.values()))
        self._combo_row("presets_channels", self.channel_var, list(self.channel_labels.values()))

        self.save_btn = ttk.Button(self.form, text=self.t(self.lang, "presets_save"),
                                    command=self._save_current, style="Accent.TButton")
        self.save_btn.pack(anchor="w", padx=14, pady=(16, 0))

        bottom = tk.Frame(self, bg=th["bg"])
        bottom.pack(fill="x", padx=16, pady=(0, 16))
        ttk.Button(bottom, text=self.t(self.lang, "presets_close"), command=self._on_close,
                   style="Ghost.TButton").pack(side="right")

    def _entry_row(self, key, var):
        th = self.th
        row = tk.Frame(self.form, bg=th["bg_panel"])
        row.pack(fill="x", padx=14, pady=6)
        tk.Label(row, text=self.t(self.lang, key), bg=th["bg_panel"], fg=th["fg"],
                 width=16, anchor="w", font=(theme.FONT_FAMILY, 10)).pack(side="left")
        tk.Entry(row, textvariable=var, bg=th["bg_elevated"], fg=th["fg"],
                 insertbackground=th["fg"], relief="flat").pack(side="left", fill="x", expand=True, ipady=3)

    def _combo_row(self, key, var, values):
        th = self.th
        row = tk.Frame(self.form, bg=th["bg_panel"])
        row.pack(fill="x", padx=14, pady=6)
        tk.Label(row, text=self.t(self.lang, key), bg=th["bg_panel"], fg=th["fg"],
                 width=16, anchor="w", font=(theme.FONT_FAMILY, 10)).pack(side="left")
        ttk.Combobox(row, textvariable=var, values=values, state="readonly").pack(side="left", fill="x", expand=True)

    # ── Lista ─────────────────────────────────────────────────────────
    def _refresh_list(self):
        self.listbox.delete(0, "end")
        for p in self.presets:
            suffix = " ★" if p.is_builtin else ""
            self.listbox.insert("end", f"{p.label}{suffix}")

    def _on_select(self, event):
        selection = self.listbox.curselection()
        if not selection:
            self.selected_index = None
            self.form.pack_forget()
            self.builtin_hint.pack_forget()
            return
        self.selected_index = selection[0]
        preset = self.presets[self.selected_index]

        self._suspend_trace = True
        self.label_var.set(preset.label)
        self.suffix_var.set(preset.file_suffix)
        self.target_app_var.set(self.target_app_labels.get(preset.target_app, preset.target_app))
        self.profile_var.set(self.profile_labels.get(preset.profile_id, preset.profile_id))
        self.audio_var.set(self.audio_labels.get(preset.audio_mode, preset.audio_mode))
        self.channel_var.set(self.channel_labels.get(preset.channel_layout, preset.channel_layout))
        self._suspend_trace = False

        if preset.is_builtin:
            self.builtin_hint.pack(fill="x", pady=(0, 4))
        else:
            self.builtin_hint.pack_forget()
        self.form.pack(fill="both", expand=True, pady=(8, 0))
        self._set_form_state("disabled" if preset.is_builtin else "normal")

    def _set_form_state(self, state):
        for child in self.form.winfo_children():
            for widget in child.winfo_children():
                try:
                    widget.configure(state=state)
                except tk.TclError:
                    pass
        # Butonul de Salvare ramane mereu vizibil, dar inactiv pe un builtin
        # (userul e ghidat spre "Duplica" prin `builtin_hint`, nu blocat tacut).
        try:
            self.save_btn.configure(state=state)
        except tk.TclError:
            pass

    # ── Actiuni CRUD ──────────────────────────────────────────────────
    def _new_preset(self):
        new_id = f"custom_{uuid.uuid4().hex[:8]}"
        preset = pm.OutputPreset(id=new_id, label=self.t(self.lang, "presets_new"),
                                  target_app="custom", profile_id="prores422hq",
                                  audio_mode=pm.AUDIO_PASSTHROUGH, file_suffix="_custom")
        self.presets.append(preset)
        self._refresh_list()
        self.listbox.selection_clear(0, "end")
        self.listbox.selection_set(len(self.presets) - 1)
        self._on_select(None)

    def _duplicate_preset(self):
        if self.selected_index is None:
            return
        source = self.presets[self.selected_index]
        new_id = f"custom_{uuid.uuid4().hex[:8]}"
        clone = pm.duplicate(source, new_id, f"{source.label} (copie)")
        self.presets.append(clone)
        self._refresh_list()
        self.listbox.selection_clear(0, "end")
        self.listbox.selection_set(len(self.presets) - 1)
        self._on_select(None)

    def _delete_preset(self):
        if self.selected_index is None:
            return
        preset = self.presets[self.selected_index]
        if preset.is_builtin:
            return
        if not messagebox.askyesno(self.t(self.lang, "presets_dialog_title"),
                                    self.t(self.lang, "presets_delete_confirm", name=preset.label)):
            return
        del self.presets[self.selected_index]
        self.selected_index = None
        self._refresh_list()
        self._on_select(None)

    def _save_current(self):
        if self.selected_index is None:
            return
        preset = self.presets[self.selected_index]
        if preset.is_builtin:
            return
        preset.label = self.label_var.get().strip() or preset.label
        preset.file_suffix = self.suffix_var.get().strip() or preset.file_suffix
        preset.target_app = self.target_app_labels_rev.get(self.target_app_var.get(), preset.target_app)
        preset.profile_id = self.profile_labels_rev.get(self.profile_var.get(), preset.profile_id)
        preset.audio_mode = self.audio_labels_rev.get(self.audio_var.get(), preset.audio_mode)
        preset.channel_layout = self.channel_labels_rev.get(self.channel_var.get(), preset.channel_layout)
        self._refresh_list()
        self.listbox.selection_set(self.selected_index)

    def _export_presets(self):
        path = filedialog.asksaveasfilename(defaultextension=".json",
                                             filetypes=[("JSON", "*.json")],
                                             initialfile="cgconvertor_presets.json")
        if not path:
            return
        pm.export_to_file(self.presets, path)

    def _import_presets(self):
        path = filedialog.askopenfilename(filetypes=[("JSON", "*.json")])
        if not path or not os.path.isfile(path):
            return
        try:
            imported = pm.import_from_file(path)
        except (OSError, ValueError):
            messagebox.showerror(self.t(self.lang, "presets_dialog_title"), path)
            return
        existing_ids = {p.id for p in self.presets}
        for preset in imported:
            if preset.id in existing_ids:
                preset.id = f"custom_{uuid.uuid4().hex[:8]}"
            preset.is_builtin = False  # un preset importat nu e niciodata "builtin" local
            self.presets.append(preset)
        self._refresh_list()

    def _on_close(self):
        pm.save(self.presets)
        self.on_change(self.presets)
        self.destroy()
