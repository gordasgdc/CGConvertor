"""
dependency_panel.py — fereastra "Verificare & Dependențe Sistem" (Toplevel
modal), stil Shift, aceeași structură ca DependencyPanel.swift (Mac):
o listă de componente, fiecare cu bulină de stare + buton de acțiune.
"""

import threading
import tkinter as tk
from tkinter import ttk

import theme
from dependency_manager import STATE_OK, STATE_MISSING, STATE_OPTIONAL_MISSING, STATE_CHECKING


def _state_color(th, state):
    if state == STATE_OK:
        return th["success"]
    if state == STATE_MISSING:
        return th["error"]
    if state == STATE_OPTIONAL_MISSING:
        return "#E8A33D"  # amber - optional, nu blocant
    return th["fg_dim"]


def _state_label(t, lang, state):
    return {
        STATE_OK: t(lang, "deps_state_ok"),
        STATE_MISSING: t(lang, "deps_state_missing"),
        STATE_OPTIONAL_MISSING: t(lang, "deps_state_optional_missing"),
        STATE_CHECKING: t(lang, "deps_state_checking"),
    }.get(state, "")


class DependencyPanel(tk.Toplevel):
    def __init__(self, master, deps_manager, lang, t, on_change=None):
        super().__init__(master)
        self.deps = deps_manager
        self.lang = lang
        self.t = t
        self.on_change = on_change
        self.th = theme.get(True)

        self.title(self.t(self.lang, "deps_panel_title"))
        self.geometry("480x420")
        self.minsize(440, 360)
        self.configure(bg=self.th["bg"])

        self._build_ui()
        self.grab_set()
        self.transient(master)
        self._refresh_display()
        self._run_checks()

    def _build_ui(self):
        th = self.th
        body = tk.Frame(self, bg=th["bg"], padx=20, pady=20)
        body.pack(fill="both", expand=True)

        tk.Label(body, text=self.t(self.lang, "deps_panel_title"), font=(theme.FONT_FAMILY, 15, "bold"),
                 bg=th["bg"], fg=th["fg"]).pack(anchor="w")
        tk.Label(body, text=self.t(self.lang, "deps_panel_subtitle"), bg=th["bg"], fg=th["fg_dim"],
                 wraplength=420, justify="left", font=(theme.FONT_FAMILY, 10)).pack(anchor="w", pady=(2, 14))

        self.rows_frame = tk.Frame(body, bg=th["bg"])
        self.rows_frame.pack(fill="both", expand=True)

        self.error_label = tk.Label(body, text="", bg=th["bg"], fg=th["error"],
                                     wraplength=420, justify="left", font=(theme.FONT_FAMILY, 10))
        self.error_label.pack(anchor="w", pady=(6, 0))

        btn_row = tk.Frame(body, bg=th["bg"])
        btn_row.pack(fill="x", pady=(14, 0))
        ttk.Button(btn_row, text=self.t(self.lang, "deps_refresh"), command=self._run_checks).pack(side="left")
        ttk.Button(btn_row, text=self.t(self.lang, "deps_close"), command=self.destroy).pack(side="right")

    def _run_checks(self):
        threading.Thread(target=self._check_worker, daemon=True).start()

    def _check_worker(self):
        self.deps.refresh_all()
        self.after(0, self._refresh_display)
        if self.on_change:
            self.after(0, self.on_change)

    def _refresh_display(self):
        th = self.th
        for w in self.rows_frame.winfo_children():
            w.destroy()

        for item in self.deps.items:
            card = tk.Frame(self.rows_frame, bg=th["bg_panel"], highlightbackground=th["line"],
                             highlightthickness=1)
            card.pack(fill="x", pady=(0, 8))
            inner = tk.Frame(card, bg=th["bg_panel"], padx=12, pady=10)
            inner.pack(fill="x")

            header = tk.Frame(inner, bg=th["bg_panel"])
            header.pack(fill="x")
            dot = tk.Canvas(header, width=10, height=10, bg=th["bg_panel"], highlightthickness=0)
            dot.create_oval(1, 1, 9, 9, fill=_state_color(th, item.state), outline="")
            dot.pack(side="left", padx=(0, 8))
            tk.Label(header, text=item.name, font=(theme.FONT_FAMILY, 11, "bold"),
                     bg=th["bg_panel"], fg=th["fg"]).pack(side="left")
            tk.Label(header, text=_state_label(self.t, self.lang, item.state),
                     font=(theme.FONT_FAMILY, 9), bg=th["bg_panel"],
                     fg=_state_color(th, item.state)).pack(side="right")

            hint_key = "deps_ffmpeg_hint" if item.id == "ffmpeg" else "deps_homebrew_hint"
            tk.Label(inner, text=self.t(self.lang, hint_key), font=(theme.FONT_FAMILY, 9),
                     bg=th["bg_panel"], fg=th["fg_dim"], wraplength=400, justify="left").pack(anchor="w", pady=(4, 0))

            if item.id == "ffmpeg" and item.state == STATE_MISSING:
                if self.deps.is_downloading:
                    tk.Label(inner, text=self.t(self.lang, "deps_ffmpeg_downloading"),
                             font=(theme.FONT_FAMILY, 9), bg=th["bg_panel"], fg=th["fg_dim"]).pack(anchor="w", pady=(6, 0))
                else:
                    ttk.Button(inner, text=self.t(self.lang, "deps_ffmpeg_install"),
                               command=self._install_ffmpeg).pack(anchor="w", pady=(6, 0))
            elif item.id == "homebrew" and item.state == STATE_OPTIONAL_MISSING:
                btns = tk.Frame(inner, bg=th["bg_panel"])
                btns.pack(anchor="w", pady=(6, 0))
                ttk.Button(btns, text=self.t(self.lang, "deps_homebrew_copy"),
                           command=self._copy_homebrew_command).pack(side="left")
                ttk.Button(btns, text=self.t(self.lang, "deps_homebrew_open_site"),
                           command=self._open_homebrew_site).pack(side="left", padx=(6, 0))

    def _install_ffmpeg(self):
        self._refresh_display()
        threading.Thread(target=self._install_worker, daemon=True).start()

    def _install_worker(self):
        self.deps.download_and_install_ffmpeg()
        self.after(0, self._after_install)

    def _after_install(self):
        if self.deps.download_error:
            self.error_label.config(text=self.deps.download_error)
        self._refresh_display()
        if self.on_change:
            self.on_change()

    def _copy_homebrew_command(self):
        self.clipboard_clear()
        self.clipboard_append(self.deps.homebrew_install_command())

    def _open_homebrew_site(self):
        import webbrowser
        webbrowser.open("https://brew.sh")
