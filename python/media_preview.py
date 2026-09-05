# media_preview.py
"""Preview interactiv — versiunea REDUSA, deliberat, a unui player
real-time LUT/LOG (vezi CLAUDE.md: acela ramane un TODO separat, pipeline
GPU propriu). Aici: scrubbing pe o bara de progres regenereaza un
thumbnail STATIC la momentul respectiv, cu un LUT .cube optional aplicat —
nu e redare video, dar e util imediat, fara nicio constructie noua de
decodare/randare. Port 1:1 al `MediaPreviewSheet.swift` (Mac)."""

import os
import threading
import tkinter as tk
from tkinter import filedialog, ttk

import media_inspector
from translations import t


class MediaPreviewDialog(tk.Toplevel):
    def __init__(self, parent, app, job):
        super().__init__(parent)
        self.app = app
        self.job = job
        self.lut_path = None
        self._debounce_id = None
        self._photo_ref = None  # referinta obligatorie (Tkinter altfel colecteaza imaginea)

        duration = (job.get("metadata") or {}).get("duration") or 10.0

        th = app.th
        self.title(os.path.basename(job["path"]))
        self.configure(bg=th["bg"])
        self.resizable(False, False)

        self.image_label = tk.Label(self, bg=th["bg_elevated"], width=480, height=270)
        self.image_label.pack(padx=16, pady=(16, 8))

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

        self._refresh_texts()
        self._extract_and_show()

    def _refresh_texts(self):
        lang = self.app.lang
        self.lut_label.config(text=t(lang, "preview_no_lut"))
        self.lut_btn.config(text=t(lang, "preview_choose_lut"))
        self.clear_lut_btn.config(text=t(lang, "preview_clear_lut"))

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

        def run():
            out_path = os.path.join(media_inspector.thumbnails_folder(), f"preview_{id(self.job)}.png")
            ok = media_inspector.generate_thumbnail(self.job["path"], lut, out_path, at_seconds=pos)
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
