# history_view.py
"""Dialog Tkinter pentru istoricul offload-urilor — port al `HistoryView.swift`
(Mac), stilizat ca restul aplicației. Vezi `history_store.py`."""

import os
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox, ttk

from history_store import shared as history_shared


def _open_in_file_manager(path):
    if sys.platform == "darwin":
        subprocess.run(["open", "-R", path])
    elif sys.platform == "win32":
        subprocess.run(["explorer", "/select,", path])


class HistoryDialog(tk.Toplevel):
    def __init__(self, parent, app):
        super().__init__(parent)
        self.app = app
        th = app.th
        self.title(self._t("history_title"))
        self.configure(bg=th["bg"])
        self.geometry("520x480")

        header = tk.Frame(self, bg=th["bg"])
        header.pack(fill="x", padx=16, pady=(16, 8))
        tk.Label(header, text=self._t("history_title"), bg=th["bg"], fg=th["fg"],
                 font=app._f(13, "bold")).pack(side="left")
        ttk.Button(header, text=self._t("history_clear_all"), style="Stop.TButton", cursor="hand2",
                   command=self._clear_all).pack(side="right")

        self.list_frame = tk.Frame(self, bg=th["bg"])
        self.list_frame.pack(fill="both", expand=True, padx=16)
        self._render()

        ttk.Button(self, text=self._t("history_close"), style="Ghost.TButton", cursor="hand2",
                   command=self.destroy).pack(pady=12)

    def _t(self, key, **kwargs):
        from translations import t
        return t(self.app.lang, key, **kwargs)

    def _render(self):
        th = self.app.th
        for w in self.list_frame.winfo_children():
            w.destroy()
        entries = list(reversed(history_shared().entries))
        if not entries:
            tk.Label(self.list_frame, text=self._t("history_empty"), bg=th["bg"], fg=th["fg_faint"],
                     font=self.app._fm(10)).pack(pady=20)
            return
        canvas = tk.Canvas(self.list_frame, bg=th["bg"], highlightthickness=0)
        scrollbar = ttk.Scrollbar(self.list_frame, orient="vertical", command=canvas.yview)
        inner = tk.Frame(canvas, bg=th["bg"])
        inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=inner, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        for idx, entry in enumerate(entries):
            real_idx = len(history_shared().entries) - 1 - idx
            card = tk.Frame(inner, bg=th["bg_panel"], highlightbackground=th["line"], highlightthickness=1)
            card.pack(fill="x", pady=4, padx=2)
            tk.Label(card, text=entry["folder_name"], bg=th["bg_panel"], fg=th["fg"],
                     font=self.app._f(10, "bold"), anchor="w").pack(fill="x", padx=10, pady=(8, 0))
            tk.Label(card, text=entry["date_text"], bg=th["bg_panel"], fg=th["fg_faint"],
                     font=self.app._fm(9), anchor="w").pack(fill="x", padx=10)
            tk.Label(card, text=f"{self._t('history_source')}: {entry['sources_summary']}", bg=th["bg_panel"],
                     fg=th["fg_dim"], font=self.app._fm(9), anchor="w").pack(fill="x", padx=10)
            tk.Label(card, text=f"{self._t('history_destination')}: {entry['dest_summary']}", bg=th["bg_panel"],
                     fg=th["fg_dim"], font=self.app._fm(9), anchor="w").pack(fill="x", padx=10)
            counts_color = th.get("error", "#F87171") if entry["error_count"] > 0 else th["fg_dim"]
            tk.Label(card, text=f"{self._t('history_ok')}: {entry['ok_count']}  {self._t('history_mismatch')}: "
                                 f"{entry['mismatch_count']}  {self._t('history_errors')}: {entry['error_count']}",
                     bg=th["bg_panel"], fg=counts_color, font=self.app._fm(9), anchor="w").pack(fill="x", padx=10)

            links = tk.Frame(card, bg=th["bg_panel"])
            links.pack(fill="x", padx=10, pady=(2, 8))
            for path in entry.get("source_paths", []):
                lbl = tk.Label(links, text=f"{self._t('history_open_source')}: {os.path.basename(path)}",
                               bg=th["bg_panel"], fg=th["accent"], cursor="hand2", font=self.app._fm(9))
                lbl.pack(anchor="w")
                lbl.bind("<Button-1>", lambda e, p=path: _open_in_file_manager(p))
            for path in entry.get("destination_target_paths", []):
                lbl = tk.Label(links, text=f"{self._t('history_open_destination')}: {os.path.basename(path)}",
                               bg=th["bg_panel"], fg=th["accent"], cursor="hand2", font=self.app._fm(9))
                lbl.pack(anchor="w")
                lbl.bind("<Button-1>", lambda e, p=path: _open_in_file_manager(p))

            del_btn = tk.Label(card, text="✕", bg=th["bg_panel"], fg=th["fg_faint"], cursor="hand2", font=self.app._fm(9))
            del_btn.place(relx=1.0, y=8, anchor="ne", x=-8)
            del_btn.bind("<Button-1>", lambda e, i=real_idx: self._delete(i))

    def _delete(self, index):
        history_shared().delete(index)
        self._render()

    def _clear_all(self):
        if messagebox.askyesno(self._t("history_clear_all"), self._t("history_clear_all_confirm")):
            history_shared().clear_all()
            self._render()
