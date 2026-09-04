"""
settings_dialog.py — Setari (CLAUDE.md, Faza 1 v3.0.0, sectiunile B/E):
tema System/Dark/Light (Regula 18), marime text (Regula 24), accelerare
GPU (selector manual peste detectia automata din gpu_probe.py), joburi
simultane, si profilul afisat in sidebar (Nume/Email — Regula 12).
"""

import tkinter as tk
from tkinter import ttk

import config
import gpu_probe
import theme


class SettingsDialog(tk.Toplevel):
    def __init__(self, master, settings, lang, t, on_save):
        super().__init__(master)
        self.th = master.th
        self.lang = lang
        self.t = t
        self.on_save = on_save
        self.settings = dict(settings)

        self.title(self.t(self.lang, "settings_dialog_title"))
        self.geometry("420x480")
        self.resizable(False, False)
        self.configure(bg=self.th["bg"])

        self._build_maps()
        self._build_ui()
        self.grab_set()
        self.transient(master)

    def _build_maps(self):
        lang, t = self.lang, self.t
        self.theme_ids = ["system", "dark", "light"]
        self.theme_labels = {tid: t(lang, f"settings_theme_{tid}") for tid in self.theme_ids}
        self.theme_labels_rev = {v: k for k, v in self.theme_labels.items()}

        self.font_ids = ["small", "normal", "large", "xlarge"]
        self.font_labels = {fid: t(lang, f"settings_font_{fid}") for fid in self.font_ids}
        self.font_labels_rev = {v: k for k, v in self.font_labels.items()}

        available = gpu_probe.available_vendors()
        self.gpu_ids = [""] + sorted(available)  # "" = Automat
        self.gpu_labels = {"": t(lang, "settings_gpu_auto")}
        self.gpu_labels.update({gid: gpu_probe.GPU_LABELS.get(gid, gid) for gid in available})
        self.gpu_labels_rev = {v: k for k, v in self.gpu_labels.items()}

    def _build_ui(self):
        th = self.th
        body = tk.Frame(self, bg=th["bg"], padx=18, pady=18)
        body.pack(fill="both", expand=True)

        self.theme_var = tk.StringVar(value=self.theme_labels.get(self.settings.get("theme_pref", "system")))
        self._combo_row(body, "settings_theme", self.theme_var, list(self.theme_labels.values()))

        self.font_var = tk.StringVar(value=self.font_labels.get(self.settings.get("font_scale", "normal")))
        self._combo_row(body, "settings_font_size", self.font_var, list(self.font_labels.values()))

        self.gpu_var = tk.StringVar(value=self.gpu_labels.get(self.settings.get("gpu_vendor_override", "")))
        self._combo_row(body, "settings_gpu_vendor", self.gpu_var, list(self.gpu_labels.values()))

        self.jobs_var = tk.IntVar(value=int(self.settings.get("max_parallel_jobs", 1)))
        row = tk.Frame(body, bg=th["bg"])
        row.pack(fill="x", pady=6)
        tk.Label(row, text=self.t(self.lang, "settings_parallel_jobs"), bg=th["bg"], fg=th["fg"],
                 width=18, anchor="w", font=(theme.FONT_FAMILY, 10)).pack(side="left")
        ttk.Spinbox(row, from_=1, to=4, textvariable=self.jobs_var, width=5).pack(side="left")

        tk.Frame(body, bg=th["line"], height=1).pack(fill="x", pady=12)

        self.name_var = tk.StringVar(value=self.settings.get("user_name", ""))
        self._entry_row(body, "settings_user_name", self.name_var)
        self.email_var = tk.StringVar(value=self.settings.get("user_email", ""))
        self._entry_row(body, "settings_user_email", self.email_var)

        ttk.Button(body, text=self.t(self.lang, "settings_save"), command=self._save,
                   style="Accent.TButton").pack(anchor="e", pady=(18, 0))

    def _combo_row(self, parent, key, var, values):
        th = self.th
        row = tk.Frame(parent, bg=th["bg"])
        row.pack(fill="x", pady=6)
        tk.Label(row, text=self.t(self.lang, key), bg=th["bg"], fg=th["fg"],
                 width=18, anchor="w", font=(theme.FONT_FAMILY, 10)).pack(side="left")
        ttk.Combobox(row, textvariable=var, values=values, state="readonly", width=20).pack(side="left")

    def _entry_row(self, parent, key, var):
        th = self.th
        row = tk.Frame(parent, bg=th["bg"])
        row.pack(fill="x", pady=6)
        tk.Label(row, text=self.t(self.lang, key), bg=th["bg"], fg=th["fg"],
                 width=18, anchor="w", font=(theme.FONT_FAMILY, 10)).pack(side="left")
        tk.Entry(row, textvariable=var, bg=th["bg_elevated"], fg=th["fg"],
                 insertbackground=th["fg"], relief="flat").pack(side="left", fill="x", expand=True, ipady=3)

    def _save(self):
        self.settings["theme_pref"] = self.theme_labels_rev.get(self.theme_var.get(), "system")
        self.settings["font_scale"] = self.font_labels_rev.get(self.font_var.get(), "normal")
        self.settings["gpu_vendor_override"] = self.gpu_labels_rev.get(self.gpu_var.get(), "")
        self.settings["max_parallel_jobs"] = max(1, min(4, int(self.jobs_var.get() or 1)))
        self.settings["user_name"] = self.name_var.get().strip()
        self.settings["user_email"] = self.email_var.get().strip()
        config.save(self.settings)
        self.on_save(self.settings)
        self.destroy()
