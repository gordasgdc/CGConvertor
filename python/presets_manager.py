"""
presets_manager.py — Presets Manager (CLAUDE.md, Faza 1 v3.0.0, sectiunea
D). Inlocuieste picker-ul fix Mod(Rewrap/Transcode)+Codec cu o lista de
presetari denumite, editabile, importabile/exportabile — fiecare preset
leaga un `EncoderProfile` (format_registry.py) de un mod audio si un
sufix de nume de fisier.

Persistat in acelasi folder ca `config.py` (`~/Library/Application
Support/CGConvertor/presets.json` pe Mac, `%APPDATA%\\CGConvertor\\
presets.json` pe Windows) — nu un fisier nou de configurare separat.
"""

import copy
import json
from dataclasses import asdict, dataclass
from typing import List

from config import config_dir  # acelasi folder, un singur loc care stie calea

PRESETS_PATH = config_dir() / "presets.json"

AUDIO_PASSTHROUGH = "passthrough"
AUDIO_PCM16 = "pcm16"
AUDIO_PCM24 = "pcm24"
AUDIO_AAC = "aac"

CHANNEL_ORIGINAL = "original"
CHANNEL_STEREO = "stereo"
CHANNEL_5_1 = "5.1"

_AUDIO_ARGS = {
    AUDIO_PASSTHROUGH: ["-c:a", "copy"],
    AUDIO_PCM16: ["-c:a", "pcm_s16le"],
    AUDIO_PCM24: ["-c:a", "pcm_s24le"],
    AUDIO_AAC: ["-c:a", "aac", "-b:a", "320k"],
}
_CHANNEL_ARGS = {
    CHANNEL_ORIGINAL: [],
    CHANNEL_STEREO: ["-ac", "2"],
    CHANNEL_5_1: ["-ac", "6"],
}


def audio_ffmpeg_args(audio_mode: str, channel_layout: str) -> List[str]:
    args = list(_AUDIO_ARGS.get(audio_mode, _AUDIO_ARGS[AUDIO_PASSTHROUGH]))
    if audio_mode != AUDIO_PASSTHROUGH:
        args += _CHANNEL_ARGS.get(channel_layout, [])
    return args


FRAME_RATE_OPTIONS = ["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"]


@dataclass
class OutputPreset:
    id: str
    label: str
    target_app: str  # "davinci" / "premiere" / "fcp" / "avid" / "web" / "custom"
    profile_id: str  # id din format_registry.ALL_PROFILES, sau "rewrap"
    audio_mode: str = AUDIO_PASSTHROUGH
    channel_layout: str = CHANNEL_ORIGINAL
    file_suffix: str = "_convertit"
    is_builtin: bool = False  # seturile implicite (needitabile direct, dar duplicabile)
    # Cadre/s la iesire (2026-09-05, cerut explicit de Cristi) — None
    # (implicit) pastreaza fps-ul sursei, comportamentul de dinainte.
    # Retrocompatibil: presetarile deja salvate pe disc, fara aceasta
    # cheie, primesc None prin `from_dict` (filtreaza doar campurile
    # cunoscute, campurile lipsa raman pe valoarea implicita a dataclass-ului).
    # Se aplica DOAR la transcodare — Rewrap ("-c copy") nu poate resample
    # fps fara re-encode.
    frame_rate: str = None

    def to_dict(self):
        return asdict(self)

    @staticmethod
    def from_dict(data: dict) -> "OutputPreset":
        known = {f for f in OutputPreset.__dataclass_fields__}
        return OutputPreset(**{k: v for k, v in data.items() if k in known})


REWRAP_PROFILE_ID = "rewrap"  # nu e in format_registry — mod special, "-c copy" total


def _default_presets() -> List[OutputPreset]:
    return [
        OutputPreset(id="builtin_rewrap", label="Rewrap Rapid", target_app="custom",
                     profile_id=REWRAP_PROFILE_ID, audio_mode=AUDIO_PASSTHROUGH,
                     file_suffix="_rewrap", is_builtin=True),
        OutputPreset(id="builtin_prores422hq", label="ProRes 422 HQ (Mezzanine DaVinci/FCP)",
                     target_app="davinci", profile_id="prores422hq",
                     audio_mode=AUDIO_PASSTHROUGH, file_suffix="_proresHQ", is_builtin=True),
        OutputPreset(id="builtin_dnxhrhq", label="DNxHR HQ (Mezzanine Avid/Premiere)",
                     target_app="avid", profile_id="dnxhrhq",
                     audio_mode=AUDIO_PASSTHROUGH, file_suffix="_dnxhr", is_builtin=True),
        OutputPreset(id="builtin_h264_web", label="H.264 1080p (YouTube/Web)",
                     target_app="web", profile_id="h264",
                     audio_mode=AUDIO_AAC, channel_layout=CHANNEL_STEREO,
                     file_suffix="_web", is_builtin=True),
        OutputPreset(id="builtin_hevc_master", label="HEVC 10-bit (Master Delivery)",
                     target_app="custom", profile_id="hevc10",
                     audio_mode=AUDIO_AAC, channel_layout=CHANNEL_ORIGINAL,
                     file_suffix="_master", is_builtin=True),
        OutputPreset(id="builtin_av1_web", label="AV1 (Web modern)",
                     target_app="web", profile_id="av1",
                     audio_mode=AUDIO_AAC, channel_layout=CHANNEL_STEREO,
                     file_suffix="_av1", is_builtin=True),
        OutputPreset(id="builtin_uncompressed", label="Uncompressed 10-bit (Arhivare)",
                     target_app="custom", profile_id="uncompressed",
                     audio_mode=AUDIO_PCM24, file_suffix="_uncompressed", is_builtin=True),
    ]


def load() -> List[OutputPreset]:
    """La prima rulare, seed cu presetarile implicite (scrise pe disc, ca
    userul sa le poata duplica/edita ca punct de plecare). Presetarile
    corupte individual (JSON valid dar camp lipsa) sunt sarite, nu opresc
    incarcarea restului listei."""
    if not PRESETS_PATH.exists():
        defaults = _default_presets()
        save(defaults)
        return defaults
    try:
        with open(PRESETS_PATH, "r", encoding="utf-8") as f:
            raw = json.load(f)
        presets = []
        for item in raw:
            try:
                presets.append(OutputPreset.from_dict(item))
            except TypeError:
                continue
        return presets or _default_presets()
    except (json.JSONDecodeError, OSError):
        return _default_presets()


def save(presets: List[OutputPreset]) -> None:
    try:
        with open(PRESETS_PATH, "w", encoding="utf-8") as f:
            json.dump([p.to_dict() for p in presets], f, indent=2, ensure_ascii=False)
    except OSError:
        pass


def duplicate(preset: OutputPreset, new_id: str, new_label: str) -> OutputPreset:
    clone = copy.deepcopy(preset)
    clone.id = new_id
    clone.label = new_label
    clone.is_builtin = False
    return clone


def export_to_file(presets: List[OutputPreset], path: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump([p.to_dict() for p in presets], f, indent=2, ensure_ascii=False)


def import_from_file(path: str) -> List[OutputPreset]:
    """Intoarce presetarile importate — apelantul decide daca le adauga
    la lista existenta sau o inlocuieste. Nu suprascrie automat."""
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    result = []
    for item in raw:
        try:
            result.append(OutputPreset.from_dict(item))
        except TypeError:
            continue
    return result
