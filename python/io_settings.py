# io_settings.py
"""Setari de buffer/RAM pentru Offload — port scopit din `DataMover`
(core/io_settings.py), aceeasi filozofie: Regula 21 din CLAUDE.md (Memory
& I/O Performance) — buffer fix, configurabil, plus un plafon orientativ
de memorie cu backpressure (pauza scurta intre fisiere daca procesul
depaseste plafonul), nu o limita impusa strict de OS."""

import time

CHUNK_SIZE_CHOICES_MB = [1, 2, 4, 8, 16, 32, 64, 128]
RAM_LIMIT_CHOICES_MB = [0, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]  # 0 = fara limita

PRESETS = [
    {"name": "Eco", "chunk_mb": 4, "ram_limit_mb": 1024},
    {"name": "Standard", "chunk_mb": 8, "ram_limit_mb": 4096},
    {"name": "High", "chunk_mb": 32, "ram_limit_mb": 16384},
    {"name": "Extreme", "chunk_mb": 64, "ram_limit_mb": 32768},
]

DEFAULT_CHUNK_MB = 8
DEFAULT_RAM_LIMIT_MB = 1024


def get_chunk_size_bytes(cfg):
    mb = cfg.get("offload_chunk_mb", DEFAULT_CHUNK_MB)
    if mb not in CHUNK_SIZE_CHOICES_MB:
        mb = DEFAULT_CHUNK_MB
    return mb * 1024 * 1024


def get_ram_limit_bytes(cfg):
    mb = cfg.get("offload_ram_limit_mb", DEFAULT_RAM_LIMIT_MB)
    if mb not in RAM_LIMIT_CHOICES_MB:
        mb = DEFAULT_RAM_LIMIT_MB
    return mb * 1024 * 1024


def formatted_mb(mb):
    if mb == 0:
        return "—"
    if mb >= 1024:
        return f"{mb / 1024:.0f} GB"
    return f"{mb} MB"


def current_resident_memory_bytes():
    """RSS curent al procesului — fara nicio dependinta noua (`resource`,
    stdlib), suficient pentru backpressure (nu o cerinta de precizie
    absoluta). Pe Windows, `resource` nu exista — foloseste `psutil` DACA
    e deja instalat (nu e o dependinta noua pentru acest repo — verifica
    inainte de a te baza pe el); altfel intoarce 0 (backpressure devine
    un no-op, nu un crash)."""
    try:
        import resource
        usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        # macOS/BSD: octeti. Linux: KB. Windows nu ajunge aici (ImportError).
        import sys
        return usage if sys.platform == "darwin" else usage * 1024
    except ImportError:
        try:
            import ctypes
            import ctypes.wintypes as wintypes

            class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
                _fields_ = [
                    ("cb", wintypes.DWORD),
                    ("PageFaultCount", wintypes.DWORD),
                    ("PeakWorkingSetSize", ctypes.c_size_t),
                    ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t),
                    ("PeakPagefileUsage", ctypes.c_size_t),
                ]

            counters = PROCESS_MEMORY_COUNTERS()
            counters.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
            handle = ctypes.windll.kernel32.GetCurrentProcess()
            if ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
                return counters.WorkingSetSize
        except Exception:
            pass
        return 0


def wait_if_over_ram_limit(cancel_event, cfg, on_warning=None):
    """Backpressure: daca memoria procesului depaseste plafonul configurat,
    asteapta in pasi de 0.5s (max 30s), verificat intre FISIERE. `cancel_event`
    (threading.Event) intrerupe imediat asteptarea daca userul apasa
    Anuleaza."""
    limit = get_ram_limit_bytes(cfg)
    if limit <= 0:
        return
    warned = False
    waited = 0.0
    while current_resident_memory_bytes() > limit and waited < 30.0:
        if cancel_event.is_set():
            return
        if not warned and on_warning:
            on_warning()
            warned = True
        time.sleep(0.5)
        waited += 0.5
