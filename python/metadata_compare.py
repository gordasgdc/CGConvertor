# metadata_compare.py
"""Motorul comparativ de metadate — unifica ffprobe (`media_inspector`),
Sony XML/rtmd (`sony_metadata`), EXIF/GPS si ID3 (`image_metadata`) intr-un
singur set de categorii ordonate. Port 1:1 al `MetadataCompare.swift`
(Mac) — vezi acolo pentru comentariile complete de design. Ruleaza la
cerere (cand userul deschide comparatia), NU la fiecare adaugare de
fisier in coada."""

import os

from media_inspector import probe, resolution_text
from sony_metadata import read as sony_read
from image_metadata import read_exif, read_id3

CATEGORY_ORDER = [
    "Fișier", "General", "Video", "Audio",
    "Imagine (EXIF)", "Audio (tag ID3)",
    "Setări captură (rtmd, primul cadru)", "Profil Cameră / Log (Sony XML)",
]


def _format_bytes(n):
    if n is None:
        return None
    n = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} {unit}"
        n /= 1024
    return None


def categories_for(path):
    """Intoarce o lista ordonata de (categorie, [(label, valoare), ...]) —
    esec silentios per-sursa (Sony/EXIF/ID3 gol daca nu se aplica fisierului
    curent), la fel ca pe Mac."""
    cats = {}

    def add(category, label, value):
        if value is None or value == "":
            return
        cats.setdefault(category, []).append((label, str(value)))

    try:
        size = os.path.getsize(path)
    except OSError:
        size = None
    add("Fișier", "Nume fișier", os.path.basename(path))
    add("Fișier", "Dimensiune", _format_bytes(size))

    meta = probe(path)
    if meta:
        add("General", "Durată", f"{meta['duration']:.1f}s" if meta.get("duration") else None)
        add("Video", "Codec", (meta.get("video_codec") or "").upper() or None)
        add("Video", "Rezoluție", resolution_text(meta))
        add("Video", "Cadre/s", meta.get("frame_rate"))
        add("Video", "Bitrate", _format_bytes(meta["video_bitrate"] / 8) + "/s" if meta.get("video_bitrate") else None)
        add("Video", "Format pixeli", meta.get("pix_fmt"))
        add("Video", "Spațiu de culoare", meta.get("color_space"))
        add("Video", "Curbă de transfer", meta.get("color_transfer"))
        add("Video", "Gamut culoare", meta.get("color_primaries"))
        add("Audio", "Codec", (meta.get("audio_codec") or "").upper() or None)
        add("Audio", "Canale", meta.get("channels"))
        add("Audio", "Frecvență eșantionare", f"{meta['sample_rate']} Hz" if meta.get("sample_rate") else None)
        add("Audio", "Bitrate", _format_bytes(meta["audio_bitrate"] / 8) + "/s" if meta.get("audio_bitrate") else None)

    sony = sony_read(path)
    for label, value in sony.get("camera_profile", {}).items():
        add("Profil Cameră / Log (Sony XML)", label, value)
    for label, value in sony.get("capture_settings", {}).items():
        add("Setări captură (rtmd, primul cadru)", label, value)

    for label, value in read_exif(path).items():
        add("Imagine (EXIF)", label, value)
    for label, value in read_id3(path).items():
        add("Audio (tag ID3)", label, value)

    known = set(CATEGORY_ORDER)
    rest = sorted(k for k in cats if k not in known)
    order = [c for c in CATEGORY_ORDER if c in cats] + rest
    return [(c, cats[c]) for c in order]
