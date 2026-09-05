# history_store.py
"""Istoricul offload-urilor efectuate — port 1:1 al `HistoryStore.swift`
(Mac), care la randul lui e portat din DataMover. Persistat in
%AppData%\\CGConvertor\\ (Windows), intre lansari ale aplicatiei."""

import json
import os
import platform
from datetime import datetime

MAX_ENTRIES = 200


def _app_support_dir():
    if platform.system() == "Windows":
        base = os.environ.get("APPDATA", os.path.expanduser("~"))
    else:
        base = os.path.expanduser("~/Library/Application Support")
    path = os.path.join(base, "CGConvertor")
    os.makedirs(path, exist_ok=True)
    return path


class HistoryStore:
    def __init__(self):
        self.path = os.path.join(_app_support_dir(), "offload_history.json")
        self.entries = self._load()

    def _load(self):
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return []

    def _save(self):
        try:
            with open(self.path, "w", encoding="utf-8") as f:
                json.dump(self.entries, f, ensure_ascii=False, indent=2)
        except OSError:
            pass

    def record(self, folder_name, source_path, destination_targets, ok_count, mismatch_count, error_count):
        entry = {
            "date_text": datetime.now().strftime("%d.%m.%Y %H:%M"),
            "folder_name": folder_name,
            "sources_summary": os.path.basename(source_path),
            "dest_summary": ", ".join(os.path.basename(p) for p in destination_targets),
            "ok_count": ok_count, "mismatch_count": mismatch_count, "error_count": error_count,
            "source_paths": [source_path], "destination_target_paths": destination_targets,
        }
        self.entries.append(entry)
        if len(self.entries) > MAX_ENTRIES:
            self.entries = self.entries[-MAX_ENTRIES:]
        self._save()

    def delete(self, index):
        if 0 <= index < len(self.entries):
            del self.entries[index]
            self._save()

    def clear_all(self):
        self.entries = []
        self._save()


_shared = None


def shared():
    global _shared
    if _shared is None:
        _shared = HistoryStore()
    return _shared
