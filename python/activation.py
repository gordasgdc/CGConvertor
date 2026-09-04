"""
activation.py — dialog de activare pentru CG Convertor, localizat
(RO/EN/ES), stilizat in tema "Shift" (aceeasi paleta ca theme.py /
CGConvertor/Theme.swift pe Mac). Port 1:1 al activation.py din DataMover.

Integrare in main.py:

    import activation
    if __name__ == "__main__":
        app = CGConvertorApp()
        app.mainloop()

(Spre deosebire de DataMover — unde `require_license()` blocheaza
pornirea aplicatiei INAINTE de fereastra principala — CG Convertor
gateaza doar butonul "Porneste conversia", la fel ca varianta Swift; vezi
LicenseManager.is_unlocked() folosit direct din main.py.)
"""

import os
import threading
import time
import urllib.parse
import webbrowser
import tkinter as tk
from tkinter import ttk, messagebox

import config as cfg
import license_validator
import machine_id
import pricing_checker
import theme

TRIAL_DAYS = 15
WHATSAPP_PHONE = "34643109970"

TEXTS = {
    "ro": {
        "title": "Activare CG Convertor",
        "heading": "Activează CG Convertor",
        "sub": "Introdu codul serial primit la activare.",
        "sub_trial_expired": "Perioada ta de probă de {days} zile s-a încheiat. Introdu codul serial ca să continui.",
        "machine_label": "ID mașină (trimite-mi asta dacă nu ai încă un cod):",
        "code_label": "Cod serial:",
        "activate": "Activează",
        "cancel": "Anulează",
        "empty_error": "Introdu un cod serial.",
        "success_title": "Activat",
        "success_msg": "CG Convertor a fost activat cu succes.",
        "whatsapp_btn": "💬 Scrie-mi pe WhatsApp",
        "whatsapp_prefill": "Salut! Vreau sa activez CG Convertor. ID masina: {id}",
        "copy": "Copiază",
        # {price} e completat dinamic din pricing.json (Regula 27) — vezi
        # pricing_checker.py; fallback pe suma hardcodată daca fara conexiune.
        "donation_note": "Donație de {price} pentru continuarea dezvoltării aplicației și a platformei — nu un preț de listă, nu o vânzare. Se activează după cele 15 zile de probă gratuită.",
        "promo_line": "🔥 {label}: {price} (în loc de {base})",
    },
    "en": {
        "title": "Activate CG Convertor",
        "heading": "Activate CG Convertor",
        "sub": "Enter the serial code you received at activation.",
        "sub_trial_expired": "Your {days}-day trial has ended. Enter your serial code to continue.",
        "machine_label": "Machine ID (send me this if you don't have a code yet):",
        "code_label": "Serial code:",
        "activate": "Activate",
        "cancel": "Cancel",
        "empty_error": "Enter a serial code.",
        "success_title": "Activated",
        "success_msg": "CG Convertor was activated successfully.",
        "whatsapp_btn": "💬 Message me on WhatsApp",
        "whatsapp_prefill": "Hi! I'd like to activate CG Convertor. Machine ID: {id}",
        "copy": "Copy",
        "donation_note": "A {price} donation to support ongoing development of the app and the platform — not a list price, not a sale. Applies after the 15-day free trial.",
        "promo_line": "🔥 {label}: {price} (instead of {base})",
    },
    "es": {
        "title": "Activar CG Convertor",
        "heading": "Activar CG Convertor",
        "sub": "Introduce el código de serie recibido al activar.",
        "sub_trial_expired": "Tu prueba de {days} días ha terminado. Introduce tu código de serie para continuar.",
        "machine_label": "ID de máquina (envíamelo si aún no tienes un código):",
        "code_label": "Código de serie:",
        "activate": "Activar",
        "cancel": "Cancelar",
        "empty_error": "Introduce un código de serie.",
        "success_title": "Activado",
        "success_msg": "CG Convertor se activó correctamente.",
        "whatsapp_btn": "💬 Escríbeme por WhatsApp",
        "whatsapp_prefill": "Hola! Quiero activar CG Convertor. ID de máquina: {id}",
        "copy": "Copiar",
        "donation_note": "Una donación de {price} para apoyar el desarrollo continuo de la app y la plataforma — no un precio de lista, no una venta. Se activa tras los 15 días de prueba gratuita.",
        "promo_line": "🔥 {label}: {price} (en lugar de {base})",
    },
}


def _format_price(value, currency):
    is_whole = float(value) == int(value)
    amount = str(int(value)) if is_whole else str(value)
    symbol = "€" if currency == "EUR" else currency
    return f"{amount} {symbol}"


def _current_language():
    try:
        settings = cfg.load()
        lang = settings.get("language", "ro")
        return lang if lang in TEXTS else "ro"
    except Exception:
        return "ro"


def _trial_file_path():
    return os.path.expanduser(f"~/.{license_validator.PRODUCT_ID}_trial")


def trial_days_remaining():
    """Porneste automat proba la prima lansare — fisier local separat de
    licenta reala. Intoarce un numar <= 0 daca proba a expirat."""
    path = _trial_file_path()
    if not os.path.isfile(path):
        try:
            with open(path, "w") as f:
                f.write(str(int(time.time())))
        except OSError:
            pass
        return float(TRIAL_DAYS)

    try:
        with open(path) as f:
            started_at = int(f.read().strip())
    except (ValueError, OSError):
        started_at = int(time.time())

    elapsed_days = (time.time() - started_at) / 86400
    return TRIAL_DAYS - elapsed_days


def is_licensed():
    saved = license_validator.load_saved_license()
    return bool(saved and saved.valid)


def is_unlocked():
    return is_licensed() or trial_days_remaining() > 0


def _make_button(parent, text, command, bg, fg, hover_bg):
    """Buton 'fals', din Label + binding de clic — tk.Button ignora bg/fg
    pe unele combinatii macOS/temă, un Label cu clic nu are aceasta
    problema (vezi aceeași notă în DataMover/activation.py)."""
    lbl = tk.Label(parent, text=text, bg=bg, fg=fg, padx=14, pady=7,
                    font=(theme.FONT_FAMILY, 11), cursor="hand2")
    lbl.bind("<Button-1>", lambda e: command())
    lbl.bind("<Enter>", lambda e: lbl.configure(bg=hover_bg))
    lbl.bind("<Leave>", lambda e: lbl.configure(bg=bg))
    return lbl


class ActivationDialog(tk.Toplevel):
    def __init__(self, master, trial_expired=False):
        super().__init__(master)
        self.th = theme.get(cfg.load().get("theme_pref", "system"))
        self.t = TEXTS[_current_language()]
        self.trial_expired = trial_expired
        self.title(self.t["title"])
        self.geometry("540x560")
        self.resizable(False, False)
        self.configure(bg=self.th["bg"])
        self.activated = False

        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        th = self.th
        body = tk.Frame(self, bg=th["bg"], padx=24, pady=24)
        body.pack(fill="both", expand=True)

        sub_text = self.t["sub_trial_expired"].format(days=TRIAL_DAYS) if self.trial_expired else self.t["sub"]
        tk.Label(body, text=self.t["heading"], font=(theme.FONT_FAMILY, 15, "bold"),
                 bg=th["bg"], fg=th["fg"]).pack(anchor="w")
        tk.Label(body, text=sub_text, bg=th["bg"], fg=th["fg_dim"],
                 wraplength=470, justify="left").pack(anchor="w", pady=(2, 16))

        tk.Label(body, text=self.t["machine_label"], bg=th["bg"], fg=th["fg_dim"],
                 wraplength=470, justify="left").pack(anchor="w")
        machine_id_value = machine_id.get_machine_id_display()
        id_row = tk.Frame(body, bg=th["bg"])
        id_row.pack(fill="x", pady=(4, 16))
        id_entry = tk.Entry(id_row, bg=th["bg_elevated"], fg=th["fg"],
                             insertbackground=th["fg"], relief="flat")
        id_entry.insert(0, machine_id_value)
        id_entry.configure(state="readonly", readonlybackground=th["bg_elevated"])
        id_entry.pack(side="left", fill="x", expand=True, ipady=4)
        _make_button(id_row, self.t["copy"], lambda: self._copy_to_clipboard(machine_id_value),
                     bg=th["bg_elevated"], fg=th["fg"], hover_bg=th["line"]).pack(side="left", padx=(6, 0))

        # Terminologie obligatorie: DONATIE, niciodata "pret"/"cumpara"/
        # "vanzare" - vezi CLAUDE.md, sectiunea Faza C / terminologie financiara.
        # Pret dinamic (Regula 27) - port Windows al PricingChecker.swift
        # (Mac): pornim cu suma hardcodata (fallback instant, fara sa
        # blocam deschiderea dialogului), apoi o inlocuim cu cea reala
        # din pricing.json cand fetch-ul de fundal se termina.
        self._price_frame = tk.Frame(body, bg=th["bg_elevated"])
        self._price_frame.pack(fill="x", pady=(0, 12))
        self._promo_label = tk.Label(self._price_frame, bg=th["bg_elevated"], fg=th["accent"],
                                      font=(theme.FONT_FAMILY, 9, "bold"), wraplength=450,
                                      justify="left", padx=10)
        self._donation_label = tk.Label(
            self._price_frame,
            text=self.t["donation_note"].format(price=_format_price(pricing_checker.FALLBACK_PRICE, pricing_checker.FALLBACK_CURRENCY)),
            bg=th["bg_elevated"], fg=th["fg_dim"], font=(theme.FONT_FAMILY, 9),
            wraplength=450, justify="left", padx=10, pady=8)
        self._donation_label.pack(fill="x")
        threading.Thread(target=self._fetch_price_worker, daemon=True).start()

        _make_button(body, self.t["whatsapp_btn"], lambda: self._open_whatsapp(machine_id_value),
                     bg="#25D366", fg="white", hover_bg="#1EBE5A").pack(anchor="w", pady=(0, 16))

        tk.Label(body, text=self.t["code_label"], bg=th["bg"], fg=th["fg"]).pack(anchor="w")
        self.entry = tk.Text(body, height=4, wrap="char", font=(theme.FONT_MONO, 10),
                              bg=th["bg_elevated"], fg=th["fg"], insertbackground=th["fg"], relief="flat")
        self.entry.pack(fill="x", pady=(4, 12), ipady=4)
        self.entry.focus_set()

        self.status_var = tk.StringVar(value="")
        tk.Label(body, textvariable=self.status_var, bg=th["bg"], fg=th["error"],
                 wraplength=470, justify="left").pack(anchor="w", pady=(0, 12))

        btn_row = tk.Frame(body, bg=th["bg"])
        btn_row.pack(fill="x")
        _make_button(btn_row, self.t["activate"], self._try_activate,
                     bg=th["accent"], fg=th["accent_ink"], hover_bg=th["accent_hover"]).pack(side="left")
        _make_button(btn_row, self.t["cancel"], self._on_close,
                     bg=th["bg_elevated"], fg=th["fg"], hover_bg=th["line"]).pack(side="left", padx=(8, 0))

    def _fetch_price_worker(self):
        result = pricing_checker.fetch_effective_price()
        # Widget-ul poate fi deja distrus (dialog inchis inainte ca
        # fetch-ul de retea sa termine) - `winfo_exists()` evita un
        # TclError la actualizarea unui label disparut.
        if not self.winfo_exists():
            return
        self.after(0, lambda: self._apply_price(result))

    def _apply_price(self, result):
        if not self.winfo_exists():
            return
        price_text = _format_price(result["price"], result["currency"])
        self._donation_label.config(text=self.t["donation_note"].format(price=price_text))
        if result.get("promo_label"):
            base_text = _format_price(result["base_price"], result["currency"])
            self._promo_label.config(text=self.t["promo_line"].format(
                label=result["promo_label"], price=price_text, base=base_text))
            self._promo_label.pack(fill="x", before=self._donation_label)

    def _copy_to_clipboard(self, text):
        self.clipboard_clear()
        self.clipboard_append(text)

    def _open_whatsapp(self, machine_id_value):
        message = self.t["whatsapp_prefill"].format(id=machine_id_value)
        url = f"https://wa.me/{WHATSAPP_PHONE}?text={urllib.parse.quote(message)}"
        webbrowser.open(url)

    def _try_activate(self):
        serial = self.entry.get("1.0", "end").strip()
        if not serial:
            self.status_var.set(self.t["empty_error"])
            return

        result = license_validator.check(serial)
        if result.valid:
            license_validator.save_license(serial)
            self.activated = True
            messagebox.showinfo(self.t["success_title"], self.t["success_msg"])
            self.destroy()
        else:
            self.status_var.set(result.error or "—")

    def _on_close(self):
        self.activated = False
        self.destroy()


def open_activation_dialog(parent, trial_expired=False):
    """Deschide dialogul de activare — apelat dintr-un buton din
    fereastra principala. Intoarce True daca activarea a reusit."""
    dialog = ActivationDialog(parent, trial_expired=trial_expired)
    dialog.grab_set()
    dialog.transient(parent)
    parent.wait_window(dialog)
    return dialog.activated
