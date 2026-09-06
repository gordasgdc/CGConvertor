# media_inspector.py
"""Inspectie/Metadata profunda + thumbnail cu LUT static (Faza 2). Ruleaza
ffprobe/ffmpeg — ACELEASI binare deja folosite de converter.py pentru
conversie, fara nicio dependinta noua. Port 1:1 al `MediaInspector.swift`
(Mac) — vezi acolo pentru comentariile complete de design."""

import base64
import json
import os
import subprocess
import sys
import tempfile
import time

from converter import get_ffmpeg_path, get_ffprobe_path

# Vezi comentariul din converter.py — acelasi fix pentru "fereastra
# neagra care clipeste" pe Windows (aici, cel mai vizibil: un apel
# ffmpeg PER MISCARE de slider in previzualizarea interactiva).
_NO_WINDOW = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0


def probe(path):
    """Ruleaza ffprobe -show_format -show_streams si parseaza JSON-ul brut
    manual (nu un model rigid) — campurile difera mult intre containere/
    codecuri, un parsing tolerant esueaza mai gratios decat unul strict."""
    ffprobe_path = get_ffprobe_path()
    try:
        result = subprocess.run(
            [ffprobe_path, "-v", "error", "-print_format", "json",
             "-show_format", "-show_streams", path],
            capture_output=True, text=True, check=True, creationflags=_NO_WINDOW,
        )
        data = json.loads(result.stdout)
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return None

    meta = {
        "duration": None, "video_codec": None, "width": None, "height": None,
        "frame_rate": None, "video_bitrate": None, "pix_fmt": None,
        "color_space": None, "color_transfer": None, "color_primaries": None,
        "audio_codec": None, "sample_rate": None, "channels": None, "audio_bitrate": None,
    }
    fmt = data.get("format", {})
    try:
        meta["duration"] = float(fmt.get("duration"))
    except (TypeError, ValueError):
        pass

    streams = data.get("streams", [])
    video = next((s for s in streams if s.get("codec_type") == "video"), None)
    if video:
        meta["video_codec"] = video.get("codec_name")
        meta["width"] = video.get("width")
        meta["height"] = video.get("height")
        meta["pix_fmt"] = video.get("pix_fmt")
        meta["color_space"] = video.get("color_space")
        meta["color_transfer"] = video.get("color_transfer")
        meta["color_primaries"] = video.get("color_primaries")
        try:
            meta["video_bitrate"] = int(video.get("bit_rate"))
        except (TypeError, ValueError):
            pass
        rate = video.get("r_frame_rate", "")
        if "/" in rate:
            num, _, den = rate.partition("/")
            try:
                num, den = float(num), float(den)
                if den:
                    meta["frame_rate"] = f"{num / den:.3f}"
            except ValueError:
                pass

    audio = next((s for s in streams if s.get("codec_type") == "audio"), None)
    if audio:
        meta["audio_codec"] = audio.get("codec_name")
        meta["channels"] = audio.get("channels")
        try:
            meta["sample_rate"] = int(audio.get("sample_rate"))
        except (TypeError, ValueError):
            pass
        try:
            meta["audio_bitrate"] = int(audio.get("bit_rate"))
        except (TypeError, ValueError):
            pass

    return meta


def resolution_text(meta):
    if meta and meta.get("width") and meta.get("height"):
        return f"{meta['width']}×{meta['height']}"
    return None


def generate_thumbnail(path, lut_path, output_path, at_seconds=1.0, width=320):
    """Extrage un cadru static (implicit ~1s in clip, sau `at_seconds` daca
    specificat — folosit de preview-ul interactiv, vezi media_preview.py)
    ca thumbnail, optional cu un LUT .cube aplicat prin filtrul nativ
    `lut3d` al FFmpeg — NU un player real-time. Formatul e dat de extensia
    din `output_path` — apelantul (main.py) foloseste `.png`, NU `.jpg`:
    `tk.PhotoImage` nativ (fara Pillow, dependinta pe care acest repo nu o
    are) suporta PNG dar nu JPEG. Mac (`MediaInspector.swift`) foloseste
    .jpg — NSImage citeste ambele formate nativ, nicio constrangere acolo.
    `width` (nou, 2026-09-05): 320 implicit pentru coada (rapid, mic);
    preview-ul fullscreen cere o latime mult mai mare (vezi media_preview.py)."""
    ffmpeg_path = get_ffmpeg_path()
    vf = f"scale={width}:-2"
    if lut_path:
        # ffmpeg cere backslash-escape pentru ':' din calea Windows
        # (C\:/...) in interiorul unui lant de filtre — vezi documentatia
        # oficiala a filtergraph-ului (caracterele : , [ ] au sens special).
        escaped = lut_path.replace("\\", "/").replace(":", "\\:")
        vf += f",lut3d=file='{escaped}'"
    try:
        result = subprocess.run(
            [ffmpeg_path, "-y", "-ss", f"{max(0.0, at_seconds):.3f}", "-i", path,
             "-frames:v", "1", "-vf", vf, output_path],
            capture_output=True, check=False, creationflags=_NO_WINDOW,
        )
        return result.returncode == 0 and os.path.isfile(output_path)
    except FileNotFoundError:
        return False


def thumbnails_folder():
    folder = os.path.join(tempfile.gettempdir(), "CGConvertorThumbs")
    os.makedirs(folder, exist_ok=True)
    return folder


def generate_html_report(jobs, statuses_text):
    """Raport HTML per lot — un singur fisier auto-continut (thumbnail-uri
    ca data URI base64). NEIMPLEMENTAT deliberat: varianta PDF — vezi
    CLAUDE.md pentru motiv."""
    rows = []
    for job in jobs:
        thumb_path = job.get("thumbnail_path")
        if thumb_path and os.path.isfile(thumb_path):
            with open(thumb_path, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("ascii")
            mime = "image/png" if thumb_path.lower().endswith(".png") else "image/jpeg"
            thumb_tag = f'<img src="data:{mime};base64,{b64}" width="160">'
        else:
            thumb_tag = '<span class="muted">—</span>'

        meta = job.get("metadata") or {}
        meta_parts = [
            resolution_text(meta),
            (meta.get("video_codec") or "").upper() or None,
            f"{meta['frame_rate']} fps" if meta.get("frame_rate") else None,
            f"{meta['duration']:.1f}s" if meta.get("duration") else None,
            (meta.get("audio_codec") or "").upper() or None,
        ]
        meta_text = " · ".join(p for p in meta_parts if p) or "—"
        status_text = statuses_text.get(id(job), job.get("status", ""))

        rows.append(f"""
        <tr>
          <td>{thumb_tag}</td>
          <td>{os.path.basename(job["path"])}</td>
          <td>{meta_text}</td>
          <td>{status_text}</td>
        </tr>""")

    html = f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<title>Raport CG Convertor</title>
<style>
body{{font-family:-apple-system,Helvetica,Arial,sans-serif;background:#14161A;color:#EDEFF2;padding:24px}}
h1{{color:#E8963C}}
table{{border-collapse:collapse;width:100%}}
td,th{{border-bottom:1px solid #2B2F36;padding:10px;text-align:left;vertical-align:middle}}
.muted{{color:#5C6169}}
</style></head><body>
<h1>Raport conversie — CG Convertor</h1>
<p>{len(jobs)} fișiere · generat {time.strftime("%Y-%m-%d %H:%M")}</p>
<table><tr><th>Thumbnail</th><th>Fișier</th><th>Metadata</th><th>Status</th></tr>
{"".join(rows)}
</table></body></html>"""

    output_path = os.path.join(tempfile.gettempdir(), f"CGConvertor_Raport_{int(time.time())}.html")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)
    return output_path
