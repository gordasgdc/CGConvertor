# converter.py
import subprocess
import os
import sys
import re
import threading

import dependency_manager
import format_registry
import presets_manager

def get_ffmpeg_path():
    """Returneaza calea catre ffmpeg — vezi dependency_manager.find_ffmpeg()
    pentru ordinea reala de cautare (descarcat manual > bundle-uit > PATH).
    Fallback pe "ffmpeg" simplu (asteapta-l in PATH) doar daca nimic nu a
    fost gasit, ca subprocess.run sa dea o eroare clara FileNotFoundError,
    nu un None care ar crapa mai criptic mai departe."""
    return dependency_manager.find_ffmpeg() or "ffmpeg"

def get_ffprobe_path():
    return dependency_manager.find_ffprobe() or "ffprobe"

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

    def output_extension(self, preset: presets_manager.OutputPreset) -> str:
        if preset.profile_id == presets_manager.REWRAP_PROFILE_ID:
            return "mov"
        return format_registry.container_for(preset.profile_id)

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

    def convert(self, input_path, output_path, preset: presets_manager.OutputPreset,
                gpu_override: str = None, progress_callback=None):
        """
        Converteste un fisier dupa `preset` (format_registry.py +
        presets_manager.py — inlocuieste vechiul cuplu mode/codec).
        `gpu_override`: id de vanzator (gpu_probe.GPU_*) ales explicit din
        Setari, sau None pentru detectia automata (gpu_probe.detect()).
        Ruleaza SINCRON — apelantul trebuie sa-l porneasca intr-un thread
        separat ca sa nu blocheze interfata Tkinter.
        Returneaza {"success": bool, "error": str|None}.
        """
        self._stop_requested = False
        duration = self.get_duration(input_path)

        args = [self.ffmpeg_path, "-y", "-i", input_path]
        if preset.profile_id == presets_manager.REWRAP_PROFILE_ID:
            # Rewrap: doar schimbare container, fara re-encode — copiaza
            # TOATE stream-urile (video+audio+date) 1:1, exact ca inainte.
            args += ["-c", "copy"]
        else:
            args += format_registry.video_args_for(preset.profile_id, gpu_override)
            # Cadre/s la iesire (2026-09-05) — None pastreaza fps-ul sursei,
            # comportamentul de dinainte. Doar la transcodare (Rewrap
            # foloseste -c copy mai sus, fara re-encode posibil).
            if preset.frame_rate:
                args += ["-r", preset.frame_rate]
            # Etichetare spatiu de culoare (2026-09-05) — doar tag-uri
            # container/VUI, nu transformare reala a pixelilor.
            if preset.color_space:
                args += presets_manager.color_space_ffmpeg_args(preset.color_space)
            # FIX istoric (aliniere cu varianta Swift, MotorFFmpeg.swift):
            # audio-ul urmeaza AudioMode-ul presetului — Passthrough
            # ("-c:a copy") pastreaza exact bit depth-ul original al
            # sursei; presetele de livrare web re-codeaza explicit in
            # AAC, cu layout de canale ales (vezi presets_manager.py).
            args += presets_manager.audio_ffmpeg_args(preset.audio_mode, preset.channel_layout)
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
