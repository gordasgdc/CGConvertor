# camera_card_detector.py
"""Recunoasterea structurii unui card de camera — port 1:1 al
`CameraCardDetector.swift` (Mac), care la randul lui e portat din
DataMover. Pur informativ — NU blocheaza niciodata transferul, doar
avertizeaza userul."""

import os

MEDIA_EXTENSIONS = {
    "r3d", "ari", "arx", "mxf", "braw", "mov", "mp4", "crm", "cr2", "cr3",
    "nev", "mts", "m2ts", "dng", "wav", "avi", "insv",
}

SCAN_LIMIT = 60_000


def detect(root):
    """Intoarce {"card_type", "clip_count", "warnings"} sau None daca nu
    recunoaste nicio structura cunoscuta."""
    if not os.path.isdir(root):
        return None
    try:
        entries = os.listdir(root)
    except OSError:
        return None
    names = {e.upper() for e in entries}

    card_type = None
    if any(e.upper().endswith(".RDM") for e in entries):
        card_type = "RED (R3D)"
    elif "AVID" in names or any(e.upper().endswith(".ARI") for e in entries):
        card_type = "ARRI"
    elif "XDROOT" in names:
        card_type = "Sony XDCAM"
    elif "PRIVATE" in names:
        private_root = os.path.join(root, "PRIVATE")
        try:
            sub = {s.upper() for s in os.listdir(private_root)}
        except OSError:
            sub = set()
        if "M4ROOT" in sub:
            card_type = "Sony XAVC"
        elif "AVCHD" in sub:
            card_type = "Panasonic AVCHD"
        else:
            card_type = "Card video (PRIVATE)"
    elif "CONTENTS" in names:
        card_type = "Panasonic P2"
    elif any(e.lower().endswith(".braw") for e in entries):
        card_type = "Blackmagic BRAW"
    elif "CLIPS001" in names or ("DCIM" in names and "MISC" in names):
        card_type = "Canon"
    elif "DCIM" in names:
        card_type = "Card foto/video (DCIM)"

    if card_type is None:
        return None

    clip_count = 0
    zero_byte_files = []
    scanned = 0
    truncated = False
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for name in filenames:
            scanned += 1
            if scanned > SCAN_LIMIT:
                truncated = True
                break
            if name.startswith("."):
                continue
            ext = os.path.splitext(name)[1].lower().lstrip(".")
            if ext not in MEDIA_EXTENSIONS:
                continue
            clip_count += 1
            full = os.path.join(dirpath, name)
            try:
                if os.path.getsize(full) == 0 and len(zero_byte_files) < 5:
                    zero_byte_files.append(name)
            except OSError:
                pass
        if truncated:
            break

    warnings = []
    if clip_count == 0:
        warnings.append("Cardul pare gol — nu s-a găsit niciun fișier media.")
    if zero_byte_files:
        warnings.append(f"Fișiere de 0 octeți (posibil clipuri incomplete): {', '.join(zero_byte_files)}")
    if truncated:
        warnings.append("Card foarte mare — numărătoarea de clipuri e orientativă.")

    return {"card_type": card_type, "clip_count": clip_count, "warnings": warnings}


def summary(info):
    if not info:
        return ""
    text = info["card_type"]
    if info.get("clip_count") is not None:
        text += f" — {info['clip_count']} clip(uri)"
    return text


def parent_looks_like_card(path):
    """Urca pana la 3 nivele in sus si verifica daca parintele arata a
    card — cazul in care userul a selectat un SUBFOLDER, nu radacina."""
    current = os.path.dirname(path)
    for _ in range(3):
        if len(current) <= 1 or current in ("/", os.path.splitdrive(current)[0] + os.sep):
            return None
        if detect(current) is not None:
            return current
        parent = os.path.dirname(current)
        if parent == current:  # radacina discului (Windows "C:\\") — nu mai urca
            return None
        current = parent
    return None
