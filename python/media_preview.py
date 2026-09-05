# media_preview.py
"""Preview interactiv — versiunea REDUSA, deliberat, a unui player
real-time LUT/LOG (vezi CLAUDE.md: acela ramane un TODO separat, pipeline
GPU propriu). Aici: scrubbing pe o bara de progres regenereaza un
thumbnail STATIC la momentul respectiv, cu un LUT .cube optional aplicat —
nu e redare video, dar e util imediat, fara nicio constructie noua de
decodare/randare. Port 1:1 al `MediaPreviewSheet.swift` (Mac).

Fullscreen (2026-09-05, cerere explicita): buton de marire care extinde
fereastra pe tot ecranul (`attributes('-fullscreen', ...)`) SI regenereaza
cadrul la o latime mult mai mare — un thumbnail de 320px intins pe tot
ecranul ar fi vizibil pixelat."""

import os
import threading
import tkinter as tk
from tkinter import filedialog, ttk

import media_inspector
from translations import t

LATIME_COMPACT = 320
LATIME_FULLSCREEN = 1920


class MediaPreviewDialog(tk.Toplevel):
    def __init__(self, parent, app, job):
        super().__init__(parent)
        self.app = app
        self.job = job
        self.lut_path = None
        self._debounce_id = None
        self._photo_ref = None  # referinta obligatorie (Tkinter altfel colecteaza imaginea)
        self._is_fullscreen = False

        duration = (job.get("metadata") or {}).get("duration") or 10.0

        th = app.th
        self.title(os.path.basename(job["path"]))
        self.configure(bg=th["bg"])
        # Fereastra e liber redimensionabila (cerere explicita: "sa trag
        # de el sa-l pot ajusta") — nu mai fortam o dimensiune fixa.
        self.resizable(True, True)
        self.geometry("560x420")

        header = tk.Frame(self, bg=th["bg"])
        header.pack(fill="x", padx=16, pady=(16, 0))
        self.fullscreen_btn = ttk.Button(header, command=self._toggle_fullscreen,
                                          style="Ghost.TButton", cursor="hand2")
        self.fullscreen_btn.pack(side="right")

        self.image_label = tk.Label(self, bg=th["bg_elevated"])
        self.image_label.pack(padx=16, pady=(8, 8), fill="both", expand=True)

        self.position = tk.DoubleVar(value=min(1.0, duration))
        self.scale = ttk.Scale(self, from_=0, to=duration, orient="horizontal",
                                variable=self.position, command=self._on_scale_change)
        self.scale.pack(fill="x", padx=16)

        self.time_label = tk.Label(self, bg=th["bg"], fg=th["fg_faint"], font=app._fm(9))
        self.time_label.pack(anchor="e", padx=16)

        lut_row = tk.Frame(self, bg=th["bg"])
        lut_row.pack(fill="x", padx=16, pady=(4, 16))
        self.lut_label = tk.Label(lut_row, bg=th["bg"], fg=th["fg_dim"], font=app._f(10), anchor="w")
        self.lut_label.pack(side="left", fill="x", expand=True)
        self.lut_btn = ttk.Button(lut_row, command=self._choose_lut, style="Ghost.TButton", cursor="hand2")
        self.lut_btn.pack(side="right")
        self.clear_lut_btn = ttk.Button(lut_row, command=self._clear_lut, style="Ghost.TButton", cursor="hand2")

        self.bind("<Escape>", lambda _e: self._exit_fullscreen())

        self._refresh_texts()
        self._extract_and_show()

    def _refresh_texts(self):
        lang = self.app.lang
        self.lut_label.config(text=t(lang, "preview_no_lut"))
        self.lut_btn.config(text=t(lang, "preview_choose_lut"))
        self.clear_lut_btn.config(text=t(lang, "preview_clear_lut"))
        self.fullscreen_btn.config(
            text=t(lang, "preview_exit_fullscreen" if self._is_fullscreen else "preview_fullscreen"))

    def _toggle_fullscreen(self):
        self._is_fullscreen = not self._is_fullscreen
        try:
            self.attributes("-fullscreen", self._is_fullscreen)
        except tk.TclError:
            pass  # unele platforme (ex. Mac X11) nu suporta atributul — degradare fara crash
        self._refresh_texts()
        self._extract_and_show()

    def _exit_fullscreen(self):
        if self._is_fullscreen:
            self._toggle_fullscreen()

    def _on_scale_change(self, _value):
        if self._debounce_id:
            self.after_cancel(self._debounce_id)
        self._debounce_id = self.after(150, self._extract_and_show)

    def _extract_and_show(self):
        self._debounce_id = None
        pos = self.position.get()
        duration = (self.job.get("metadata") or {}).get("duration") or 10.0
        self.time_label.config(text=f"{pos:.1f}s / {duration:.1f}s")
        lut = self.lut_path
        latime = LATIME_FULLSCREEN if self._is_fullscreen else LATIME_COMPACT

        def run():
            out_path = os.path.join(media_inspector.thumbnails_folder(), f"preview_{id(self.job)}.png")
            ok = media_inspector.generate_thumbnail(self.job["path"], lut, out_path, at_seconds=pos, width=latime)
            self.after(0, lambda: self._apply(ok, out_path))

        threading.Thread(target=run, daemon=True).start()

    def _apply(self, ok, out_path):
        if not ok:
            return
        try:
            photo = tk.PhotoImage(file=out_path)
        except tk.TclError:
            return
        self._photo_ref = photo
        self.image_label.config(image=photo)

    def _choose_lut(self):
        path = filedialog.askopenfilename(filetypes=[("LUT", "*.cube")])
        if path:
            self.lut_path = path
            self.lut_label.config(text=os.path.basename(path))
            self.clear_lut_btn.pack(side="right", padx=(0, 6))
            self._extract_and_show()

    def _clear_lut(self):
        self.lut_path = None
        self.lut_label.config(text=t(self.app.lang, "preview_no_lut"))
        self.clear_lut_btn.pack_forget()
        self._extract_and_show()
