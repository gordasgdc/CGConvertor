# image_metadata.py
"""EXIF/GPS pentru imagini + tag-uri ID3v2 pentru MP3 — echivalentul
Windows al `ImageMetadata.swift` (Mac). Mac foloseste ImageIO nativ (zero
dependinte); Windows nu are un echivalent nativ comparabil in stdlib, deci
foloseste `exifread` (pip, pur Python, activ intretinut, suporta GPS) —
noua dependinta minima, la fel de justificata ca `xxhash` in v3.1.0."""

import os
import struct

try:
    import exifread
except ImportError:
    exifread = None

EXIF_LABELS = {
    "EXIF LensModel": "Obiectiv",
    "EXIF DateTimeOriginal": "Data capturare",
    "EXIF ExposureTime": "Timp expunere",
    "EXIF FNumber": "Diafragmă",
    "EXIF ISOSpeedRatings": "ISO",
    "EXIF FocalLength": "Distanță focală",
    "EXIF ExposureProgram": "Program expunere",
    "Image WhiteBalance": "Balans de alb",
    "EXIF Flash": "Bliț",
    "Image Make": "Producător cameră",
    "Image Model": "Model cameră",
    "Image Software": "Software",
}


def _gps_to_decimal(values, ref):
    try:
        deg, minutes, seconds = (float(v.num) / float(v.den) for v in values)
    except (AttributeError, ZeroDivisionError, TypeError):
        return None
    decimal = deg + minutes / 60 + seconds / 3600
    return -decimal if ref in ("S", "W") else decimal


def read_exif(path):
    """Gol daca fisierul nu e o imagine / nu are EXIF, sau `exifread`
    lipseste — esec silentios, ca in Swift/JS."""
    if exifread is None:
        return {}
    try:
        with open(path, "rb") as f:
            tags = exifread.process_file(f, details=False)
    except (OSError, ValueError):
        return {}
    if not tags:
        return {}

    cat = {}
    for key, label in EXIF_LABELS.items():
        if key in tags:
            cat[label] = str(tags[key])

    lat = tags.get("GPS GPSLatitude")
    lon = tags.get("GPS GPSLongitude")
    if lat and lon:
        lat_ref = str(tags.get("GPS GPSLatitudeRef", "N"))
        lon_ref = str(tags.get("GPS GPSLongitudeRef", "E"))
        lat_dec = _gps_to_decimal(lat.values, lat_ref)
        lon_dec = _gps_to_decimal(lon.values, lon_ref)
        if lat_dec is not None and lon_dec is not None:
            cat["Coordonate GPS"] = f"{lat_dec:.5f}, {lon_dec:.5f}"

    return cat


FRAME_MAP = {"TIT2": "Titlu", "TPE1": "Artist", "TALB": "Album",
             "TYER": "An", "TDRC": "Data", "TCON": "Gen"}


def _synchsafe(b0, b1, b2, b3):
    return (b0 << 21) | (b1 << 14) | (b2 << 7) | b3


def read_id3(path):
    """Port 1:1 al parserului ID3v2 din index.html — citește doar primii
    512KB (header-ul e mereu la începutul fișierului)."""
    if os.path.splitext(path)[1].lower() != ".mp3":
        return {}
    try:
        with open(path, "rb") as f:
            data = f.read(512 * 1024)
    except OSError:
        return {}
    if len(data) < 10 or data[0:3] != b"ID3":
        return {}

    version = data[3]
    size = _synchsafe(data[6], data[7], data[8], data[9])
    cat = {}
    offset = 10
    end = min(10 + size, len(data))

    while offset + 10 <= end:
        frame_id = data[offset:offset + 4]
        try:
            frame_id_str = frame_id.decode("ascii")
        except UnicodeDecodeError:
            break
        if not frame_id_str.isalnum() or not frame_id_str.isupper():
            break
        if version >= 4:
            frame_size = _synchsafe(data[offset + 4], data[offset + 5], data[offset + 6], data[offset + 7])
        else:
            frame_size = struct.unpack(">I", data[offset + 4:offset + 8])[0]
        if frame_size <= 0 or offset + 10 + frame_size > len(data):
            break

        if frame_id_str in FRAME_MAP:
            encoding = data[offset + 10]
            text_bytes = data[offset + 11:offset + 10 + frame_size]
            try:
                text = text_bytes.decode("utf-16" if encoding in (1, 2) else "utf-8", errors="ignore")
            except (UnicodeDecodeError, LookupError):
                text = ""
            cat[FRAME_MAP[frame_id_str]] = text.replace("\x00", "").strip()

        offset += 10 + frame_size

    return cat
