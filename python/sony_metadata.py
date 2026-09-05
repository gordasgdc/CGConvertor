# sony_metadata.py
"""Extractie profunda de metadate Sony (Log/Gamma, EI, ISO/expunere/diafragma
per-cadru, XML sidecar) — port 1:1 al `SonyMetadata.swift` (Mac), care la
randul lui e portat din parserul JS scris de mana in GDC_Metadata_View_Premium.
Vezi SonyMetadata.swift pentru comentariile complete de design (pista rtmd e
un format binar Sony nedocumentat oficial, dedus prin efort al comunitatii)."""

import os
import struct
import xml.etree.ElementTree as ET

CONTAINER_TYPES = {"moov", "trak", "mdia", "minf", "stbl", "udta", "edts", "dinf", "meta"}

EXPOSURE_MODE_LABELS = {
    0x01010000: "Manual", 0x01020000: "Auto complet",
    0x01030000: "Auto cu prioritate câștig", 0x01040000: "Auto cu prioritate diafragmă",
    0x01050000: "Auto cu prioritate timp expunere",
}

ITEM_LABELS = {
    "CaptureGammaEquation": "Curbă Gamma (Log)", "CaptureColorPrimaries": "Gamut culoare (Log)",
    "CodingEquations": "Ecuații de codare (matrice)", "CaptureFrameRate": "Cadre/s la captură",
    "CaptureBitDepth": "Adâncime biți captură", "CodingEIFlag": "Flag EI (Exposure Index)",
    "ExposureIndexOfPictureProfile": "Exposure Index (EI)", "WhiteBalance": "Balans de alb",
    "ColorTemperature": "Temperatură culoare", "ElectricalExtenderMagnification": "Extender electronic",
    "ImagerDimension": "Dimensiune senzor", "MasterBlackLevel": "Nivel negru master",
    "MasterGainAdjustment": "Ajustare câștig master", "ImagerScanMode": "Mod scanare senzor",
    "AutoSlowShutter": "Slow shutter automat", "NDFilter": "Filtru ND",
}


def read(path):
    """Intoarce {"camera_profile": {...}, "capture_settings": {...}} — gol
    daca fisierul nu e Sony / nu are nimic de extras (esec silentios, ca in
    JS — asta nu e un fisier obligatoriu de citit cu succes)."""
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    result = {"camera_profile": {}, "capture_settings": {}}

    if ext == "xml":
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                _parse_sony_xml(f.read(), result["camera_profile"])
        except OSError:
            pass
        return result

    if ext not in ("mp4", "mov", "m4v"):
        return result

    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            file_size = f.tell()
            f.seek(0)

            state = {"xml_text": None, "handlers": [], "rtmd_offset": None, "rtmd_size": None}

            def on_box(box):
                if box["type"] == "hdlr":
                    handler = _read(f, box["content_start"] + 8, 4)
                    if handler:
                        state["handlers"].append(handler.decode("ascii", "ignore"))
                last_handler = state["handlers"][-1] if state["handlers"] else None

                if last_handler == "rtmd" and state["rtmd_size"] is None and box["type"] == "stsz":
                    head = _read(f, box["content_start"] + 4, 8)
                    if head:
                        sample_size, sample_count = struct.unpack(">II", head)
                        if sample_size != 0:
                            state["rtmd_size"] = sample_size
                        elif sample_count > 0:
                            first = _read(f, box["content_start"] + 12, 4)
                            if first:
                                state["rtmd_size"] = struct.unpack(">I", first)[0]

                if last_handler == "rtmd" and state["rtmd_offset"] is None and box["type"] in ("stco", "co64"):
                    count_bytes = _read(f, box["content_start"] + 4, 4)
                    if count_bytes and struct.unpack(">I", count_bytes)[0] > 0:
                        if box["type"] == "stco":
                            off_bytes = _read(f, box["content_start"] + 8, 4)
                            if off_bytes:
                                state["rtmd_offset"] = struct.unpack(">I", off_bytes)[0]
                        else:
                            off_bytes = _read(f, box["content_start"] + 8, 8)
                            if off_bytes:
                                state["rtmd_offset"] = struct.unpack(">Q", off_bytes)[0]

                if box["type"] == "meta" and state["xml_text"] is None:
                    state["xml_text"] = _try_extract_sony_xml_box(f, box)

            _walk_iso_boxes(f, 0, file_size, on_box)

            if state["xml_text"]:
                _parse_sony_xml(state["xml_text"], result["camera_profile"])
            if state["rtmd_offset"] is not None and state["rtmd_size"]:
                sample = _read(f, state["rtmd_offset"], state["rtmd_size"])
                if sample:
                    result["capture_settings"] = _parse_sony_rtmd_sample(sample)
    except OSError:
        pass

    return result


# ---------- cutii ISO-BMFF ----------

def _read(f, offset, count):
    if count <= 0:
        return None
    f.seek(offset)
    data = f.read(count)
    return data if len(data) == count else None


def _read_box_header(f, offset):
    head = _read(f, offset, 8)
    if not head:
        return None
    size = struct.unpack(">I", head[0:4])[0]
    box_type = head[4:8].decode("ascii", "ignore")
    header_size = 8
    if size == 1:
        ext = _read(f, offset + 8, 8)
        if not ext:
            return None
        size = struct.unpack(">Q", ext)[0]
        header_size = 16
    elif size == 0:
        return None
    if size < 8:
        return None
    return {"type": box_type, "size": size, "start": offset,
            "content_start": offset + header_size, "end": offset + size}


def _walk_iso_boxes(f, start, end, on_box):
    offset = start
    while offset + 8 <= end:
        box = _read_box_header(f, offset)
        if not box or box["end"] > end or box["end"] <= box["start"]:
            break
        on_box(box)
        if box["type"] in CONTAINER_TYPES:
            child_start = box["content_start"]
            if box["type"] == "meta":
                if _try_extract_sony_xml_box(f, box) is None:
                    child_start += 4
                else:
                    child_start = None
            if child_start is not None:
                _walk_iso_boxes(f, child_start, box["end"], on_box)
        offset = box["end"]


def _try_extract_sony_xml_box(f, box):
    length = box["end"] - box["content_start"]
    if length <= 0 or length >= 8 * 1024 * 1024:
        return None
    raw = _read(f, box["content_start"], length)
    if not raw:
        return None
    try:
        text = raw.decode("utf-8", errors="ignore")
    except UnicodeDecodeError:
        return None
    idx = text.find("<?xml")
    if idx == -1:
        return None
    nul_idx = text.find("\x00", idx)
    xml_part = text[idx:] if nul_idx == -1 else text[idx:nul_idx]
    return xml_part.strip()


# ---------- decodor rtmd (KLV binar, primul esantion) ----------

def _parse_sony_rtmd_sample(sample):
    pos = 0
    end = len(sample)
    if end >= 17 and sample[0] == 0x06:
        pos = 16
        b0 = sample[pos]
        pos += (1 + (b0 & 0x7F)) if (b0 & 0x80) else 1
    out = {}
    while pos + 4 <= end:
        tag, length = struct.unpack(">HH", sample[pos:pos + 4])
        pos += 4
        if pos + length > end:
            break
        label_value = _decode_rtmd_field(tag, sample, pos, length)
        if label_value and label_value[0] not in out:
            out[label_value[0]] = label_value[1]
        pos += length
    return out


def _decode_rtmd_field(tag, buf, offset, length):
    chunk = buf[offset:offset + length]
    try:
        if tag == 0x810B and length >= 2:
            return ("ISO (rtmd, primul cadru)", str(struct.unpack(">H", chunk[:2])[0]))
        if tag in (0x8119, 0xE301) and length >= 4:
            return ("ISO (rtmd, primul cadru)", str(struct.unpack(">I", chunk[:4])[0]))
        if tag == 0x8109 and length >= 8:
            num, den = struct.unpack(">II", chunk[:8])
            if num and den:
                return ("Timp expunere (rtmd, primul cadru)", f"1/{round(den / num)} s")
            return None
        if tag == 0x8000 and length >= 2:
            raw = struct.unpack(">H", chunk[:2])[0]
            fstop = 2 ** (8 * (1 - raw / 65536))
            return ("Diafragmă (rtmd, primul cadru)", f"f/{fstop:.1f}")
        if tag == 0x810E and length >= 2:
            return ("Balans de alb (rtmd, primul cadru)", f"{struct.unpack('>H', chunk[:2])[0]} K")
        if tag == 0x8100 and length >= 16:
            mode = struct.unpack(">I", chunk[12:16])[0]
            label = EXPOSURE_MODE_LABELS.get(mode)
            return ("Mod expunere (rtmd, primul cadru)", label) if label else None
        if tag == 0x8106 and length >= 8:
            num, den = struct.unpack(">II", chunk[:8])
            if den:
                return ("Cadre/s captură (rtmd, primul cadru)", f"{num / den:.2f}")
            return None
    except struct.error:
        return None
    return None


# ---------- XML Sony (sidecar sau embedat) ----------

def _attr(el, *names):
    for n in names:
        v = el.get(n)
        if v:
            return v
    return None


def _parse_sony_xml(text, cat):
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        return

    device = root.find(".//Device")
    if device is not None:
        man = _attr(device, "manufacturer", "Manufacturer")
        model = _attr(device, "modelName", "ModelName")
        serial = _attr(device, "serialNo", "SerialNo")
        if man:
            cat["Producător cameră"] = man
        if model:
            cat["Model cameră"] = model
        if serial:
            cat["Serie cameră"] = serial

    creation_date = root.find(".//CreationDate")
    if creation_date is not None:
        v = _attr(creation_date, "value", "Value")
        if v:
            cat["Data creare clip"] = v

    video_frame = root.find(".//VideoFrame")
    if video_frame is not None:
        codec = _attr(video_frame, "videoCodec", "VideoCodec")
        cap_fps = _attr(video_frame, "captureFps", "CaptureFps")
        fmt_fps = _attr(video_frame, "formatFps", "FormatFps")
        aspect = _attr(video_frame, "aspectRatio", "AspectRatio")
        if codec:
            cat["Codec video (XML)"] = codec
        if cap_fps:
            cat["FPS captură (XML)"] = cap_fps
        if fmt_fps:
            cat["FPS format (XML)"] = fmt_fps
        if aspect:
            cat["Aspect ratio (XML)"] = aspect

    video_layout = root.find(".//VideoLayout")
    if video_layout is not None:
        w = _attr(video_layout, "pixel", "Pixel")
        h = _attr(video_layout, "numOfVerticalLine", "NumOfVerticalLine")
        if w and h:
            cat["Rezoluție (XML)"] = f"{w} x {h}"

    for item in root.iter("Item"):
        name = _attr(item, "name", "Name")
        value = _attr(item, "value", "Value")
        if not name or not value:
            continue
        label = ITEM_LABELS.get(name, name)
        if label not in cat:
            cat[label] = value
