# production_meta.py
"""Metadatele productiei atasate unui offload + raport HTML brandat —
port 1:1 al `ProductionMeta.swift` (Mac), care la randul lui e portat din
DataMover. Vezi acolo pentru comentariile complete de design (raportul e
un DOCUMENT DE PREDARE, nu un log tehnic)."""

import base64
import html as html_module
import os


class ProductionMeta:
    def __init__(self, project="", card="", client="", operator_name="", camera="", notes="", logo_path=""):
        self.project = project
        self.card = card
        self.client = client
        self.operator_name = operator_name
        self.camera = camera
        self.notes = notes
        self.logo_path = logo_path

    def header_fields(self):
        fields = []
        if self.project: fields.append(("Proiect", self.project))
        if self.client: fields.append(("Client", self.client))
        if self.card: fields.append(("Card", self.card))
        if self.camera: fields.append(("Cameră", self.camera))
        if self.operator_name: fields.append(("Operator / DIT", self.operator_name))
        return fields


def _logo_data_uri(path):
    if not path or not os.path.isfile(path):
        return None
    try:
        size = os.path.getsize(path)
        if size > 3 * 1024 * 1024:
            return None
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return None
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    mime = "image/jpeg" if ext in ("jpg", "jpeg") else ("image/gif" if ext == "gif" else "image/png")
    return f"data:{mime};base64,{base64.b64encode(data).decode('ascii')}"


def _esc(s):
    return html_module.escape(str(s), quote=True)


def write_html_report(path, destination, folder_name, rows, meta, started_at, finished_at,
                       ok_count, mismatch_count, error_count, verification_label, mhl_path,
                       app_version, truncated_note=None):
    """`rows` = listă de dict-uri {rel_path, size_bytes, status, error}."""
    header_html = "<header>"
    logo = _logo_data_uri(meta.logo_path)
    if logo:
        header_html += f'<img src="{logo}" alt="logo">'
    header_html += "<div><h1>Raport de descărcare (offload)</h1>"
    header_html += f'<div class="sub">{_esc(folder_name)} → {_esc(destination)}</div></div></header>'

    meta_html = '<div class="meta">'
    for label, value in meta.header_fields():
        meta_html += f"<div><span>{_esc(label)}</span>{_esc(value)}</div>"
    meta_html += f'<div><span>Început</span>{started_at.strftime("%Y-%m-%d %H:%M:%S")}</div>'
    meta_html += f'<div><span>Terminat</span>{finished_at.strftime("%Y-%m-%d %H:%M:%S")}</div>'
    meta_html += f"<div><span>Verificare</span>{_esc(verification_label)}</div>"
    if mhl_path:
        meta_html += f"<div><span>MHL</span>{_esc(os.path.basename(mhl_path))}</div>"
    meta_html += "</div>"

    cards_html = '<div class="cards">'
    cards_html += f'<div class="card ok"><b>{ok_count}</b>copiate OK</div>'
    if mismatch_count > 0:
        cards_html += f'<div class="card mismatch"><b>{mismatch_count}</b>nepotriviri</div>'
    cards_html += f'<div class="card fail"><b>{error_count}</b>erori</div>'
    cards_html += "</div>"

    notes_html = ""
    if meta.notes:
        notes_html = f'<div class="notes">{_esc(meta.notes)}</div>'

    rows_html = ""
    for row in rows:
        status = row["status"]
        cls = "s-ok" if status.startswith("OK") else ("s-mismatch" if status == "NEPOTRIVIRE" else "s-fail")
        rows_html += (f"<tr><td>{_esc(row['rel_path'])}</td><td>{_format_bytes(row['size_bytes'])}</td>"
                      f"<td class=\"{cls}\">{_esc(status)}</td><td>{_esc(row.get('error', ''))}</td></tr>")

    truncated_html = f'<p class="sub">{_esc(truncated_note)}</p>' if truncated_note else ""

    html = f"""<!doctype html>
<html lang="ro"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Raport offload — {_esc(folder_name)}</title>
<style>
:root {{ color-scheme: dark; }}
body {{ margin:0; padding:24px; background:#14161A; color:#EDEFF2;
       font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }}
.wrap {{ max-width: 1100px; margin: 0 auto; }}
header {{ display:flex; align-items:center; gap:16px; border-bottom:1px solid #2A2F36; padding-bottom:16px; }}
header img {{ max-height:56px; max-width:200px; }}
h1 {{ font-size:20px; margin:0 0 4px; }}
.sub {{ color:#9AA3AE; font-size:13px; }}
.meta {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:8px 24px; margin:18px 0; }}
.meta div span {{ color:#9AA3AE; display:block; font-size:11px; text-transform:uppercase; letter-spacing:.04em; }}
.cards {{ display:flex; flex-wrap:wrap; gap:12px; margin:18px 0; }}
.card {{ background:#1A1D22; border:1px solid #2A2F36; border-radius:8px; padding:12px 16px; min-width:110px; }}
.card b {{ display:block; font-size:22px; }}
.ok b {{ color:#4ADE80; }} .mismatch b {{ color:#D08C40; }} .fail b {{ color:#F87171; }}
.notes {{ background:#1A1D22; border-left:3px solid #D08C40; padding:10px 14px; border-radius:4px; white-space:pre-wrap; }}
table {{ width:100%; border-collapse:collapse; margin-top:16px; font-size:12px; }}
th {{ text-align:left; color:#9AA3AE; font-weight:600; border-bottom:1px solid #2A2F36; padding:6px 8px; }}
td {{ padding:6px 8px; border-bottom:1px solid #20242A; word-break:break-all; }}
.s-ok {{ color:#4ADE80; }} .s-fail {{ color:#F87171; }} .s-mismatch {{ color:#D08C40; }}
footer {{ margin-top:24px; color:#6B737D; font-size:11px; }}
@media (max-width:700px){{ body{{padding:14px}} table{{font-size:11px}} }}
</style></head><body><div class="wrap">
{header_html}
{meta_html}
{cards_html}
{notes_html}
<table><thead><tr><th>Fișier</th><th>Mărime</th><th>Status</th><th>Eroare</th></tr></thead><tbody>
{rows_html}
</tbody></table>
{truncated_html}
<footer>Generat de CGConvertor {_esc(app_version)} — gordas.dev</footer>
</div></body></html>"""

    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        return True
    except OSError:
        return False


def _format_bytes(n):
    n = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"
