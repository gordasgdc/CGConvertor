# metadata_compare_view.py
"""Tabel comparativ multi-fisier — port 1:1 al `MetadataCompareSheet.swift`
(Mac): randuri = un parametru tehnic, coloane = fisierele selectate,
evidentierea diferentelor si ascunderea randurilor identice. Spre
deosebire de Mac (grid SwiftUI construit manual), aici e un `ttk.Treeview`
cu coloane dinamice (o coloana per fisier) — tiparul nativ Tkinter pentru
tabele, mai simplu decat un grid manual pe acest toolkit."""

import csv
import threading
import tkinter as tk
from tkinter import filedialog, ttk

from metadata_compare import categories_for


class MetadataCompareDialog(tk.Toplevel):
    def __init__(self, parent, app, jobs):
        super().__init__(parent)
        self.app = app
        self.jobs = jobs  # [{"path": ..., "name": ...}, ...]
        th = app.th
        self.th = th

        self.title(self._t("compare_title"))
        self.configure(bg=th["bg_panel"])
        self.geometry("980x640")
        self.minsize(700, 420)

        self.categories_per_path = {}
        self.search_var = tk.StringVar()
        self.hide_identical_var = tk.BooleanVar(value=False)
        self.highlight_diffs_var = tk.BooleanVar(value=True)

        self._build_loading()
        threading.Thread(target=self._load, daemon=True).start()

    def _t(self, key, **kwargs):
        from translations import t
        return t(self.app.lang, key, **kwargs)

    def _build_loading(self):
        self.loading_label = tk.Label(self, text=self._t("compare_loading"),
                                       bg=self.th["bg_panel"], fg=self.th["fg_dim"],
                                       font=self.app._f(11))
        self.loading_label.pack(expand=True, fill="both")

    def _load(self):
        result = {}
        for job in self.jobs:
            try:
                result[job["path"]] = categories_for(job["path"])
            except Exception:
                result[job["path"]] = []
        self.categories_per_path = result
        self.after(0, self._build_table)

    # ── UI principal, construit dupa ce analiza s-a terminat ──────────────

    def _build_table(self):
        self.loading_label.destroy()
        th = self.th

        header = tk.Frame(self, bg=th["bg_panel"])
        header.pack(fill="x")
        tk.Label(header, text=self._t("compare_title"), bg=th["bg_panel"], fg=th["fg"],
                 font=self.app._f(13, "bold")).pack(side="left", padx=12, pady=10)
        tk.Label(header, text="✕", bg=th["bg_panel"], fg=th["fg_faint"], cursor="hand2",
                 font=self.app._fm(11)).pack(side="right", padx=12)
        header.winfo_children()[-1].bind("<Button-1>", lambda e: self.destroy())

        ttk.Separator(self).pack(fill="x")

        # Merge-ul de categorii+labeluri intalnite in ORICE fisier, in
        # ordinea CATEGORY_ORDER (deja aplicata per-fisier de
        # categories_for) — pastram ordinea primului fisier care aduce
        # fiecare categorie/label nou, ca pe Mac (`randuriMerge`).
        self.order = []
        labels_by_category = {}
        for job in self.jobs:
            for category, rows in self.categories_per_path.get(job["path"], []):
                if category not in labels_by_category:
                    labels_by_category[category] = []
                    self.order.append(category)
                for label, _ in rows:
                    if label not in labels_by_category[category]:
                        labels_by_category[category].append(label)
        self.labels_by_category = labels_by_category

        columns = tuple(f"c{i}" for i in range(len(self.jobs)))
        self.tree = ttk.Treeview(self, columns=columns, show="tree headings", height=18)
        self.tree.heading("#0", text=self._t("compare_parameter"))
        self.tree.column("#0", width=240, stretch=False)
        for i, job in enumerate(self.jobs):
            self.tree.heading(columns[i], text=job["name"])
            self.tree.column(columns[i], width=200, stretch=False)
        self.tree.tag_configure("category", background=th["bg_elevated"], foreground=th["accent"])
        self.tree.tag_configure("diff", background="#3A2A14")
        self.tree.pack(fill="both", expand=True, padx=10, pady=(6, 0))

        footer = tk.Frame(self, bg=th["bg_panel"])
        footer.pack(fill="x", padx=10, pady=8)
        ttk.Entry(footer, textvariable=self.search_var, width=24).pack(side="left")
        self.search_var.trace_add("write", lambda *a: self._render_rows())
        ttk.Checkbutton(footer, text=self._t("compare_highlight_diffs"),
                         variable=self.highlight_diffs_var, command=self._render_rows).pack(side="left", padx=(10, 0))
        ttk.Checkbutton(footer, text=self._t("compare_hide_identical"),
                         variable=self.hide_identical_var, command=self._render_rows).pack(side="left", padx=(10, 0))
        ttk.Button(footer, text=self._t("compare_export_csv"), style="Ghost.TButton",
                   command=self._export_csv, cursor="hand2").pack(side="right")

        self._render_rows()

    # ── randare / filtrare ────────────────────────────────────────────────

    def _value(self, path, category, label):
        for cat, rows in self.categories_per_path.get(path, []):
            if cat == category:
                for lbl, val in rows:
                    if lbl == label:
                        return val
        return None

    def _is_identical(self, category, label):
        values = {self._value(job["path"], category, label) or "—" for job in self.jobs}
        return len(values) <= 1

    def _matches(self, text):
        query = self.search_var.get().strip().lower()
        return not query or query in text.lower()

    def _render_rows(self):
        self.tree.delete(*self.tree.get_children())
        hide_identical = self.hide_identical_var.get()
        highlight = self.highlight_diffs_var.get()

        for category in self.order:
            labels = self.labels_by_category.get(category, [])
            visible = []
            for label in labels:
                if not (self._matches(label) or self._matches(category)):
                    continue
                if hide_identical and self._is_identical(category, label):
                    continue
                visible.append(label)
            if not visible:
                continue

            self.tree.insert("", "end", text=category.upper(), values=("",) * len(self.jobs), tags=("category",))
            for label in visible:
                values = tuple(self._value(job["path"], category, label) or "—" for job in self.jobs)
                tags = ("diff",) if highlight and not self._is_identical(category, label) else ()
                self.tree.insert("", "end", text=label, values=values, tags=tags)

    def _export_csv(self):
        path = filedialog.asksaveasfilename(defaultextension=".csv", initialfile="Comparatie_Metadata.csv",
                                             filetypes=[("CSV", "*.csv")])
        if not path:
            return
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["Categorie", "Parametru"] + [job["name"] for job in self.jobs])
            for category in self.order:
                for label in self.labels_by_category.get(category, []):
                    row = [category, label] + [self._value(job["path"], category, label) or "" for job in self.jobs]
                    writer.writerow(row)
