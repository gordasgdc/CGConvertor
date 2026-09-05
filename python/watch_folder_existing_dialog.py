# watch_folder_existing_dialog.py
"""Dialog de selectie a fisierelor deja existente intr-un folder proaspat
adaugat la Watch Folders (2026-09-05, feedback direct de la Cristi — vezi
watch_folders.py, list_existing_files/mark_baseline_known). "Selecteaza
tot"/"Deselecteaza tot" cerute explicit, ca alternativa la un simplu
Da/Nu — userul vede EXACT ce fisiere exista si alege liber. Port 1:1 al
WatchFolderExistingFilesSheet.swift (Mac)."""

import os
import tkinter as tk
from tkinter import ttk


class WatchFolderExistingDialog(tk.Toplevel):
    def __init__(self, parent, app, files, on_decide):
        super().__init__(parent)
        self.app = app
        self.files = files
        self.on_decide = on_decide
        self.th = app.th

        self.title(self._t("watch_existing_title"))
        self.configure(bg=self.th["bg"])
        self.geometry("420x360")
        self.minsize(360, 300)
        self.resizable(True, True)

        # Implicit toate selectate — cazul comun e "da, adauga tot ce e deja acolo".
        self.selected_vars = {f: tk.BooleanVar(value=True) for f in files}

        self._build_ui()
        self.grab_set()
        self.transient(parent)
        self.protocol("WM_DELETE_WINDOW", self._cancel)

    def _t(self, key, **kwargs):
        from translations import t
        return t(self.app.lang, key, **kwargs)

    def _build_ui(self):
        th = self.th
        body = tk.Frame(self, bg=th["bg"], padx=16, pady=16)
        body.pack(fill="both", expand=True)

        tk.Label(body, text=self._t("watch_existing_title"), font=self.app._f(13, "bold"),
                 bg=th["bg"], fg=th["fg"]).pack(anchor="w")
        tk.Label(body, text=self._t("watch_existing_subtitle", n=len(self.files)),
                 bg=th["bg"], fg=th["fg_dim"], wraplength=380, justify="left",
                 font=self.app._fm(9)).pack(anchor="w", pady=(2, 10))

        btn_row = tk.Frame(body, bg=th["bg"])
        btn_row.pack(fill="x", pady=(0, 8))
        ttk.Button(btn_row, text=self._t("watch_existing_select_all"), style="Ghost.TButton",
                   command=self._select_all, cursor="hand2").pack(side="left")
        ttk.Button(btn_row, text=self._t("watch_existing_select_none"), style="Ghost.TButton",
                   command=self._select_none, cursor="hand2").pack(side="left", padx=(6, 0))

        list_frame = tk.Frame(body, bg=th["bg_panel"], highlightbackground=th["line"], highlightthickness=1)
        list_frame.pack(fill="both", expand=True)
        canvas = tk.Canvas(list_frame, bg=th["bg_panel"], highlightthickness=0)
        scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=canvas.yview)
        inner = tk.Frame(canvas, bg=th["bg_panel"])
        inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=inner, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        for f in self.files:
            row = tk.Frame(inner, bg=th["bg_panel"])
            row.pack(fill="x", padx=8, pady=2)
            ttk.Checkbutton(row, variable=self.selected_vars[f]).pack(side="left")
            tk.Label(row, text=os.path.basename(f), bg=th["bg_panel"], fg=th["fg_dim"],
                     font=self.app._fm(9), anchor="w").pack(side="left", fill="x", expand=True)

        bottom = tk.Frame(body, bg=th["bg"])
        bottom.pack(fill="x", pady=(10, 0))
        ttk.Button(bottom, text=self._t("watch_existing_cancel"), style="Ghost.TButton",
                   command=self._cancel, cursor="hand2").pack(side="right")
        self.add_btn = ttk.Button(bottom, style="Accent.TButton", command=self._add, cursor="hand2")
        self.add_btn.pack(side="right", padx=(0, 6))
        self._refresh_add_label()
        for var in self.selected_vars.values():
            var.trace_add("write", lambda *_a: self._refresh_add_label())

    def _refresh_add_label(self):
        count = sum(1 for var in self.selected_vars.values() if var.get())
        self.add_btn.config(text=self._t("watch_existing_add", n=count), state="normal" if count else "disabled")

    def _select_all(self):
        for var in self.selected_vars.values():
            var.set(True)
        self._refresh_add_label()

    def _select_none(self):
        for var in self.selected_vars.values():
            var.set(False)
        self._refresh_add_label()

    def _add(self):
        selected = [f for f, var in self.selected_vars.items() if var.get()]
        self.on_decide(selected)
        self.destroy()

    def _cancel(self):
        self.on_decide([])
        self.destroy()
