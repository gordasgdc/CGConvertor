# metadata_compare_view.py
"""Comparatia de metadate — REFACUTA COMPLET (2026-09-06), port 1:1 al
`MetadataCompareSheet.swift` (Mac), refacut acolo dupa feedback direct de
la Cristi ("nu pot sa vad... trebuie sa fie ca un HTML... nu ca un
pop-up mic"). Fostul `MetadataCompareDialog` (Toplevel + ttk.Treeview,
980x640 fix) e eliminat — generam acum aceeasi pagina HTML autonoma
(cautare + evidentiere diferente + ascundere identice, JS simplu, fara
dependinte) si o deschidem cu vizualizatorul implicit, exact ca
"Genereaza raport" (`media_inspector.generate_html_report`)."""

import base64
import html as html_lib
import os
import tempfile
import time

from media_inspector import generate_thumbnail, thumbnails_folder
from metadata_compare import categories_for


def _thumbnail_img_tag(job):
    """Thumbnail per coloana (2026-09-06, cerut de Cristi, port 1:1 al
    Mac): reutilizeaza thumbnail-ul deja generat pentru coada
    (`job["thumbnail_path"]`) daca exista; altfel il genereaza pe loc."""
    path = job.get("thumbnail_path")
    if not path or not os.path.isfile(path):
        path = os.path.join(thumbnails_folder(), f"compare_{os.path.basename(job['path'])}.jpg")
        if not generate_thumbnail(job["path"], None, path):
            return ""
    try:
        with open(path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
    except OSError:
        return ""
    return f'<img class="thumb" src="data:image/jpeg;base64,{b64}">'


def _value(categories_per_path, path, category, label):
    for cat, rows in categories_per_path.get(path, []):
        if cat == category:
            for lbl, val in rows:
                if lbl == label:
                    return val
    return None


def open_comparison(jobs):
    """jobs: [{"path": ..., "name": ...}, ...]. Ruleaza analiza (poate
    dura putin pe fisiere multe/Sony XML mari), genereaza HTML-ul in
    temp si il deschide — apelantul decide cum (open/os.startfile)."""
    categories_per_path = {}
    for job in jobs:
        try:
            categories_per_path[job["path"]] = categories_for(job["path"])
        except Exception:
            categories_per_path[job["path"]] = []

    order = []
    labels_by_category = {}
    for job in jobs:
        for category, rows in categories_per_path.get(job["path"], []):
            if category not in labels_by_category:
                labels_by_category[category] = []
                order.append(category)
            for label, _ in rows:
                if label not in labels_by_category[category]:
                    labels_by_category[category].append(label)

    rows_html = []
    for category in order:
        labels = labels_by_category.get(category, [])
        if not labels:
            continue
        rows_html.append(
            f'<tr class="cat"><td colspan="{len(jobs) + 1}">{html_lib.escape(category.upper())}</td></tr>'
        )
        for label in labels:
            values = [_value(categories_per_path, job["path"], category, label) or "—" for job in jobs]
            identic = len(set(values)) <= 1
            cells = "".join(f"<td>{html_lib.escape(v)}</td>" for v in values)
            search = html_lib.escape((category + " " + label).lower())
            row_class = "row identic" if identic else "row diferit"
            rows_html.append(
                f'<tr class="{row_class}" data-search="{search}"><td class="label">{html_lib.escape(label)}</td>{cells}</tr>'
            )

    header_cols = "".join(
        f'<th>{_thumbnail_img_tag(job)}<div class="fname">{html_lib.escape(job["name"])}</div></th>'
        for job in jobs
    )

    html_doc = f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<title>Comparație metadate — CG Convertor</title>
<style>
:root {{ color-scheme: dark; }}
body{{font-family:Segoe UI,-apple-system,Helvetica,Arial,sans-serif;background:#14161A;color:#EDEFF2;margin:0;padding:28px 32px 60px}}
h1{{color:#E8963C;font-size:20px;margin:0 0 4px}}
.subtitle{{color:#8A8F98;font-size:13px;margin:0 0 20px}}
.toolbar{{position:sticky;top:0;background:#14161A;padding:10px 0 16px;display:flex;gap:16px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #2B2F36;margin-bottom:10px}}
input[type=text]{{background:#1A1D22;border:1px solid #2B2F36;color:#EDEFF2;border-radius:6px;padding:7px 10px;font-size:13px;width:240px}}
label{{font-size:13px;color:#C9CDD3;display:flex;align-items:center;gap:6px;cursor:pointer}}
table{{border-collapse:collapse;width:100%;font-size:12.5px}}
th,td{{border-bottom:1px solid #23262C;padding:8px 10px;text-align:left;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:320px}}
th{{position:sticky;top:56px;background:#1A1D22;color:#EDEFF2;font-size:11.5px;z-index:2;white-space:normal;vertical-align:top}}
th .thumb{{display:block;width:100%;max-width:220px;height:auto;aspect-ratio:16/9;object-fit:cover;border-radius:6px;margin:0 0 6px;border:1px solid #2B2F36}}
th .fname{{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:220px}}
td.label{{color:#9AA0A8;font-weight:500}}
tr.cat td{{background:rgba(232,150,60,0.08);color:#E8963C;font-weight:700;font-size:10.5px;letter-spacing:.04em;position:sticky;left:0}}
tr.diferit.highlight td{{background:rgba(232,150,60,0.10)}}
tr.hide-identical.identic{{display:none}}
td{{font-family:Consolas,ui-monospace,SFMono-Regular,Menlo,monospace}}
</style></head><body>
<h1>Comparație metadate</h1>
<p class="subtitle">{len(jobs)} fișiere · generat {time.strftime("%Y-%m-%d %H:%M")}</p>
<div class="toolbar">
  <input type="text" id="search" placeholder="Caută…" oninput="filtreaza()">
  <label><input type="checkbox" id="highlight" checked onchange="filtreaza()"> Evidențiază diferențele</label>
  <label><input type="checkbox" id="hideIdentical" onchange="filtreaza()"> Ascunde identice</label>
</div>
<table id="tbl">
<thead><tr><th>Parametru</th>{header_cols}</tr></thead>
<tbody>
{"".join(rows_html)}
</tbody>
</table>
<script>
function filtreaza() {{
  var q = document.getElementById('search').value.toLowerCase();
  var highlight = document.getElementById('highlight').checked;
  var hideIdentical = document.getElementById('hideIdentical').checked;
  document.querySelectorAll('tr.row').forEach(function(tr) {{
    var matches = !q || tr.getAttribute('data-search').indexOf(q) !== -1;
    tr.style.display = matches ? '' : 'none';
    tr.classList.toggle('highlight', highlight);
    tr.classList.toggle('hide-identical', hideIdentical);
  }});
  document.querySelectorAll('tr.cat').forEach(function(tr) {{
    var next = tr.nextElementSibling, any = false;
    while (next && !next.classList.contains('cat')) {{
      if (next.style.display !== 'none') any = true;
      next = next.nextElementSibling;
    }}
    tr.style.display = any ? '' : 'none';
  }});
}}
filtreaza();
</script>
</body></html>"""

    output_path = os.path.join(tempfile.gettempdir(), f"CGConvertor_Comparatie_{int(time.time())}.html")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_doc)
    return output_path
