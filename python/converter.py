# converter.py
import subprocess
import os
import sys
import re
import threading

def get_ffmpeg_path():
    """Returneaza calea catre ffmpeg inclus in aplicatie (sau din PATH in dezvoltare)."""
    if getattr(sys, 'frozen', False):
        base_path = getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
        return os.path.join(base_path, "ffmpeg.exe" if sys.platform == "win32" else "ffmpeg")
    return "ffmpeg"

def get_ffprobe_path():
    if getattr(sys, 'frozen', False):
        base_path = getattr(sys, '_MEIPASS', os.path.dirname(sys.executable))
        return os.path.join(base_path, "ffprobe.exe" if sys.platform == "win32" else "ffprobe")
    return "ffprobe"

# Codecuri: fiecare valoare e o LISTA de argumente, niciodata un string cu mai multe flag-uri
# (bug-ul din varianta initiala trimitea "prores_ks -profile:v 3" ca UN singur argument catre FFmpeg)
CODEC_ARGS = {
    "ProRes 422":      ["-c:v", "prores_ks", "-profile:v", "2", "-pix_fmt", "yuv422p10le"],
    "ProRes 422 HQ":   ["-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le"],
    "ProRes 422 LT":   ["-c:v", "prores_ks", "-profile:v", "1", "-pix_fmt", "yuv422p10le"],
    "ProRes 4444":     ["-c:v", "prores_ks", "-profile:v", "4", "-pix_fmt", "yuva444p10le"],
    "DNxHD":           ["-c:v", "dnxhd", "-profile:v", "dnxhd", "-b:v", "36M", "-pix_fmt", "yuv422p"],
    "DNxHR HQ":        ["-c:v", "dnxhd", "-profile:v", "dnxhr_hq", "-qscale:v", "1", "-pix_fmt", "yuv422p"],
}

CODEC_EXTENSION = {
    "DNxHD": "mxf",
    "DNxHR HQ": "mxf",
}

TIME_RE = re.compile(r"time=(\d+):(\d+):(\d+)\.(\d+)")


class Converter:
    def __init__(self):
        self.ffmpeg_path = get_ffmpeg_path()
        self.ffprobe_path = get_ffprobe_path()
        self._stop_requested = False

    def is_available(self):
        try:
            subprocess.run([self.ffmpeg_path, "-version"], capture_output=True, check=True)
            return True
        except (FileNotFoundError, subprocess.CalledProcessError):
            return False

    def stop(self):
        self._stop_requested = True

    def output_extension(self, mode, codec):
        if mode == "rewrap":
            return "mov"
        return CODEC_EXTENSION.get(codec, "mov")

    def get_duration(self, input_path):
        try:
            result = subprocess.run(
                [self.ffprobe_path, "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", input_path],
                capture_output=True, text=True, check=True
            )
            return float(result.stdout.strip())
        except (subprocess.CalledProcessError, ValueError, FileNotFoundError):
            return 0.0

    def convert(self, input_path, output_path, mode, codec, progress_callback=None):
        """
        Converteste un fisier. Ruleaza SINCRON — apelantul trebuie sa-l porneasca
        intr-un thread separat ca sa nu blocheze interfata Tkinter.
        Returneaza {"success": bool, "error": str|None}.
        """
        self._stop_requested = False
        duration = self.get_duration(input_path)

        args = [self.ffmpeg_path, "-y", "-i", input_path]
        if mode == "rewrap":
            args += ["-c", "copy"]
        else:
            args += CODEC_ARGS.get(codec, CODEC_ARGS["ProRes 422 HQ"])
            # FIX (aliniere cu varianta Swift, MotorFFmpeg.swift): "-c:a copy"
            # pastreaza exact bit depth-ul original al sursei (16/24/32-bit
            # PCM sau orice alt codec audio) — fortarea la "pcm_s16le" (cum
            # facea acest fisier inainte) DEGRADEAZA silentios orice sursa
            # cu audio pe mai mult de 16 biti, fara niciun avertisment.
            args += ["-c:a", "copy"]
        args += ["-map_metadata", "0", "-map", "0", "-ignore_unknown", output_path]

        try:
            process = subprocess.Popen(
                args, stderr=subprocess.PIPE, stdout=subprocess.DEVNULL,
                universal_newlines=True, bufsize=1
            )
        except FileNotFoundError:
            return {"success": False, "error": "FFmpeg nu a fost gasit."}

        stderr_lines = []
        for line in process.stderr:
            if self._stop_requested:
                process.terminate()
                return {"success": False, "error": "Anulat de utilizator."}
            stderr_lines.append(line)
            match = TIME_RE.search(line)
            if match and duration > 0 and progress_callback:
                h, m, s, cs = match.groups()
                elapsed = int(h) * 3600 + int(m) * 60 + int(s) + int(cs) / 100
                progress_callback(min(elapsed / duration, 1.0))

        process.wait()
        if process.returncode != 0:
            tail = "".join(stderr_lines[-8:])
            return {"success": False, "error": tail.strip() or f"FFmpeg a esuat (cod {process.returncode})"}

        if progress_callback:
            progress_callback(1.0)
        return {"success": True, "error": None}
