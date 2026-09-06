"""
gpu_probe.py — detectie automata a acceleratorului hardware disponibil
pentru encodare (CLAUDE.md, Faza 1 v3.0.0, sectiunea B). Rezultatul e
folosit de format_registry.py ca sa aleaga argumentele FFmpeg corecte
pentru H.264/HEVC 10-bit/AV1 fara interventie manuala — dar userul poate
oricand suprascrie din Setari (vezi `gpu_override` in format_registry.py).

Pe Mac, accelerarea e mereu VideoToolbox — nu exista alt vanzator posibil
(Apple Silicon si Intel Mac au ambele VideoToolbox), deci nu se mai
ruleaza deloc `ffmpeg -encoders` pe acea platforma. Pe Windows/Linux,
se ruleaza `ffmpeg -hide_banner -encoders` o singura data (rezultat
cache-uit in proces) si se cauta encoderele NVENC/AMF/QSV, in aceasta
ordine — daca sistemul are mai multe placi, ordinea conteaza doar ca
alegere IMPLICITA; selectorul manual din Setari ramane calea corecta
pentru un sistem cu setup neobisnuit (ex. NVENC dezactivat de driver).
"""

import subprocess
import sys
import threading

import dependency_manager

# Vanzatori posibili — DEFINITI AICI (sursa canonica), reimportati de
# format_registry.py. Nu se redefinesc in alta parte, ca sa nu diverga.
GPU_SOFTWARE = "software"
GPU_VIDEOTOOLBOX = "videotoolbox"  # Mac, mereu disponibil daca binarul ffmpeg il suporta
GPU_NVIDIA = "nvidia"
GPU_AMD = "amd"
GPU_INTEL = "intel"

GPU_LABELS = {
    GPU_SOFTWARE: "CPU (software)",
    GPU_VIDEOTOOLBOX: "Apple VideoToolbox",
    GPU_NVIDIA: "Nvidia NVENC",
    GPU_AMD: "AMD AMF",
    GPU_INTEL: "Intel Quick Sync",
}

_lock = threading.Lock()
_cached_vendor = None
_cached_available = None  # set de vanzatori gasiti, pentru afisarea in Setari (nu doar cel implicit)


def _run_encoders_list():
    ffmpeg = dependency_manager.find_ffmpeg()
    if not ffmpeg:
        return ""
    try:
        result = subprocess.run(
            [ffmpeg, "-hide_banner", "-encoders"],
            capture_output=True, text=True, timeout=10,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        return result.stdout or ""
    except Exception:
        return ""


def _probe_uncached():
    if sys.platform == "darwin":
        return GPU_VIDEOTOOLBOX, {GPU_VIDEOTOOLBOX}

    encoders_text = _run_encoders_list()
    found = set()
    if "h264_nvenc" in encoders_text or "hevc_nvenc" in encoders_text:
        found.add(GPU_NVIDIA)
    if "h264_amf" in encoders_text or "hevc_amf" in encoders_text:
        found.add(GPU_AMD)
    if "h264_qsv" in encoders_text or "hevc_qsv" in encoders_text:
        found.add(GPU_INTEL)

    if GPU_NVIDIA in found:
        return GPU_NVIDIA, found
    if GPU_AMD in found:
        return GPU_AMD, found
    if GPU_INTEL in found:
        return GPU_INTEL, found
    return GPU_SOFTWARE, found


def refresh():
    """Reruleaza detectia (thread de fundal, apelata o data la lansare —
    la fel ca `DependencyManager.refresh_all()`). Rezultatul se cacheuiaza,
    citit apoi instant de `detect()`/`available_vendors()`."""
    def _worker():
        vendor, available = _probe_uncached()
        global _cached_vendor, _cached_available
        with _lock:
            _cached_vendor = vendor
            _cached_available = available
    threading.Thread(target=_worker, daemon=True).start()


def detect() -> str:
    """Vanzatorul implicit — GPU_SOFTWARE daca inca nu s-a rulat `refresh()`
    sau daca niciun accelerator compatibil n-a fost gasit."""
    with _lock:
        if _cached_vendor is not None:
            return _cached_vendor
    return GPU_VIDEOTOOLBOX if sys.platform == "darwin" else GPU_SOFTWARE


def available_vendors():
    """Multimea vanzatorilor gasiti pe acest sistem — folosita de dialogul
    de Setari ca sa afiseze doar optiuni reale (plus 'Automat'/'Software',
    mereu disponibile)."""
    with _lock:
        if _cached_available is not None:
            return set(_cached_available)
    return {GPU_VIDEOTOOLBOX} if sys.platform == "darwin" else set()
