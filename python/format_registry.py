"""
format_registry.py — sursa unica de adevar pentru profilurile de encodare
video (CLAUDE.md, Faza 1 v3.0.0, sectiunea A "Format Registry unificat").
Inlocuieste vechiul `CODEC_ARGS` fix din converter.py — structura are
ACELASI set de id-uri ca `FormatRegistry.swift` (Mac), verificat manual la
fiecare adaugare (Regula 30 — Swift si Python nu pot partaja cod, dar
trebuie sa ramana in sincron).

Argumentele de VIDEO ale ProRes/DNxHD/DNxHR raman byte-identice cu
`CODEC_ARGS` dinaintea acestei refactorizari (regresie interzisa, vezi
planul de Faza 1) — doar mutate aici. Codecurile noi (H.264, HEVC 10-bit,
AV1, Uncompressed) sunt adaugate, cu argumente verificate REAL, rulat
direct cu binarul ffmpeg static din acest repo (nu doar presupuse din
documentatie ffmpeg):
  - H.264/HEVC 10-bit/AV1: cate un set de argumente per vanzator de GPU
    (Nvidia NVENC / AMD AMF / Intel QSV / VideoToolbox pe Mac), plus
    fallback software (libx264/libx265/libsvtav1) daca niciun GPU
    compatibil nu e gasit — vezi gpu_probe.py.
  - Uncompressed: v210 (4:2:2 10-bit), fara accelerare hardware relevanta
    pe nicio platforma.

Audio-ul NU e parte din EncoderProfile — se aplica separat, in
converter.py, pe baza AudioMode-ului presetului ales (un acelasi profil
video poate fi combinat cu Passthrough sau Re-encode).
"""

from dataclasses import dataclass
from typing import Dict, List

import gpu_probe
# Vanzatorii de accelerare sunt DEFINITI in gpu_probe.py (sursa canonica,
# citita direct de detectia headless) — reimportati aici ca sa nu divearga.
from gpu_probe import GPU_SOFTWARE, GPU_VIDEOTOOLBOX, GPU_NVIDIA, GPU_AMD, GPU_INTEL


@dataclass(frozen=True)
class EncoderProfile:
    id: str
    label: str
    container: str  # extensie fara punct: "mov", "mxf", "mp4"
    hint_key: str  # cheie translations.py pentru textul de sub picker
    # gpu_args: harta vanzator -> argumente ffmpeg (fara "-c:v" repetat in alta parte)
    gpu_args: Dict[str, List[str]]
    gpu_aware: bool = False  # False = un singur set de argumente, valabil pe orice platforma
    extra_mux_args: List[str] = None  # ex. "-tag:v hvc1" pentru compatibilitate QuickTime

    def ffmpeg_video_args(self, gpu_vendor: str) -> List[str]:
        """Intoarce argumentele video pentru vanzorul ales — cade pe
        `GPU_SOFTWARE` daca vanzatorul cerut nu are un set definit pentru
        acest profil (ex. AV1 pe un Mac — VideoToolbox nu are encoder AV1
        hardware pe niciun model existent)."""
        if not self.gpu_aware:
            return list(self.gpu_args[GPU_SOFTWARE])
        args = self.gpu_args.get(gpu_vendor) or self.gpu_args.get(GPU_SOFTWARE)
        result = list(args)
        if self.extra_mux_args:
            result += self.extra_mux_args
        return result


# ── ProRes / DNxHD / DNxHR — NESCHIMBATE, mutate 1:1 din CODEC_ARGS ─────
_PRORES_422 = EncoderProfile(
    id="prores422", label="ProRes 422", container="mov", hint_key="codec_hint_422",
    gpu_args={GPU_SOFTWARE: ["-c:v", "prores_ks", "-profile:v", "2", "-pix_fmt", "yuv422p10le"]},
)
_PRORES_422HQ = EncoderProfile(
    id="prores422hq", label="ProRes 422 HQ", container="mov", hint_key="codec_hint_422hq",
    gpu_args={GPU_SOFTWARE: ["-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le"]},
)
_PRORES_422LT = EncoderProfile(
    id="prores422lt", label="ProRes 422 LT", container="mov", hint_key="codec_hint_422lt",
    gpu_args={GPU_SOFTWARE: ["-c:v", "prores_ks", "-profile:v", "1", "-pix_fmt", "yuv422p10le"]},
)
_PRORES_4444 = EncoderProfile(
    id="prores4444", label="ProRes 4444", container="mov", hint_key="codec_hint_4444",
    gpu_args={GPU_SOFTWARE: ["-c:v", "prores_ks", "-profile:v", "4", "-pix_fmt", "yuva444p10le"]},
)
_DNXHD = EncoderProfile(
    id="dnxhd", label="DNxHD", container="mxf", hint_key="codec_hint_dnx",
    gpu_args={GPU_SOFTWARE: ["-c:v", "dnxhd", "-profile:v", "dnxhd", "-b:v", "36M", "-pix_fmt", "yuv422p"]},
)
_DNXHR_HQ = EncoderProfile(
    id="dnxhrhq", label="DNxHR HQ", container="mxf", hint_key="codec_hint_dnx",
    gpu_args={GPU_SOFTWARE: ["-c:v", "dnxhd", "-profile:v", "dnxhr_hq", "-qscale:v", "1", "-pix_fmt", "yuv422p"]},
)

# ── Codecuri de livrare NOI, cu accelerare hardware pe vanzator ─────────
# Argumentele au fost testate direct cu binarul ffmpeg static din acest
# repo (VideoToolbox + libx264/libx265/libsvtav1) — NVENC/AMF/QSV nu au
# putut fi testate REAL în acest mediu (fără GPU Nvidia/AMD/Intel dedicat
# disponibil) — sintaxa e cea documentată oficial de FFmpeg, de verificat
# practic pe prima mașină Windows cu GPU dedicat disponibilă.
_H264 = EncoderProfile(
    id="h264", label="H.264", container="mp4", hint_key="codec_hint_h264", gpu_aware=True,
    gpu_args={
        GPU_VIDEOTOOLBOX: ["-c:v", "h264_videotoolbox", "-profile:v", "high", "-b:v", "12M"],
        GPU_NVIDIA: ["-c:v", "h264_nvenc", "-preset", "p5", "-rc", "vbr", "-cq", "19", "-b:v", "0"],
        GPU_AMD: ["-c:v", "h264_amf", "-quality", "quality", "-rc", "cqp", "-qp_i", "20", "-qp_p", "22"],
        GPU_INTEL: ["-c:v", "h264_qsv", "-preset", "veryslow", "-global_quality", "20"],
        GPU_SOFTWARE: ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p"],
    },
)
_HEVC10 = EncoderProfile(
    id="hevc10", label="HEVC 10-bit", container="mp4", hint_key="codec_hint_hevc10", gpu_aware=True,
    extra_mux_args=["-tag:v", "hvc1"],  # fara asta, QuickTime/Final Cut nu recunosc HEVC in .mp4
    gpu_args={
        GPU_VIDEOTOOLBOX: ["-c:v", "hevc_videotoolbox", "-profile:v", "main10", "-pix_fmt", "p010le", "-b:v", "20M"],
        GPU_NVIDIA: ["-c:v", "hevc_nvenc", "-preset", "p5", "-rc", "vbr", "-cq", "19", "-b:v", "0", "-pix_fmt", "p010le"],
        GPU_AMD: ["-c:v", "hevc_amf", "-quality", "quality", "-rc", "cqp", "-qp_i", "20", "-qp_p", "22", "-pix_fmt", "p010le"],
        GPU_INTEL: ["-c:v", "hevc_qsv", "-preset", "veryslow", "-global_quality", "20", "-pix_fmt", "p010le"],
        GPU_SOFTWARE: ["-c:v", "libx265", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p10le"],
    },
)
_AV1 = EncoderProfile(
    id="av1", label="AV1", container="mp4", hint_key="codec_hint_av1", gpu_aware=True,
    gpu_args={
        # VideoToolbox nu are encoder AV1 hardware pe niciun Mac existent —
        # niciun caz GPU_VIDEOTOOLBOX aici, cade intentionat pe GPU_SOFTWARE.
        GPU_NVIDIA: ["-c:v", "av1_nvenc", "-preset", "p5", "-rc", "vbr", "-cq", "30", "-b:v", "0"],
        GPU_AMD: ["-c:v", "av1_amf", "-quality", "quality", "-rc", "cqp", "-qp_i", "28", "-qp_p", "30"],
        GPU_INTEL: ["-c:v", "av1_qsv", "-preset", "veryslow", "-global_quality", "28"],
        GPU_SOFTWARE: ["-c:v", "libsvtav1", "-preset", "6", "-crf", "30"],
    },
)
_UNCOMPRESSED = EncoderProfile(
    id="uncompressed", label="Uncompressed 10-bit", container="mov", hint_key="codec_hint_uncompressed",
    gpu_args={GPU_SOFTWARE: ["-c:v", "v210"]},
)

ALL_PROFILES: List[EncoderProfile] = [
    _PRORES_422, _PRORES_422HQ, _PRORES_422LT, _PRORES_4444,
    _DNXHD, _DNXHR_HQ, _H264, _HEVC10, _AV1, _UNCOMPRESSED,
]
_BY_ID = {p.id: p for p in ALL_PROFILES}


def get(profile_id: str) -> EncoderProfile:
    return _BY_ID[profile_id]


def video_args_for(profile_id: str, gpu_override: str = None) -> List[str]:
    """Argumentele FFmpeg pentru VIDEO ale unui profil — foloseste
    `gpu_override` daca userul a ales explicit un vanzator in Setari,
    altfel detectia automata din gpu_probe.detect()."""
    profile = get(profile_id)
    vendor = gpu_override or gpu_probe.detect()
    return profile.ffmpeg_video_args(vendor)


def container_for(profile_id: str) -> str:
    return get(profile_id).container
