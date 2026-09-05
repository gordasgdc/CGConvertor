# watch_folders.py
"""Watch Folders — orice fisier video nou aparut intr-un folder urmarit
intra automat in coada de conversie. Port 1:1 al `WatchFolders.swift`
(Mac) — vezi acolo pentru motivul deciziei de scanare periodica (polling)
in loc de un API nativ de evenimente de sistem (identic pe ambele
platforme, fara dependinte noi, comportament garantat acelasi)."""

import os
import threading

# ACELASI set ca pe Mac (WatchFolders.swift, `watchFolderExtensions`) — un
# fisier "vazut" de watcher se comporta identic indiferent de platforma.
WATCH_EXTENSIONS = {"mov", "mp4", "mxf", "mkv", "avi", "m4v"}

POLL_INTERVAL_SECONDS = 2.0


class WatchFolderManager:
    def __init__(self, settings, save_settings):
        self.settings = settings
        self.save_settings = save_settings
        self.on_new_files = None  # callback(list_of_paths), apelat din thread-ul de fundal
        self._stop_event = threading.Event()
        self._thread = None
        self._pending_sizes = {}   # path -> ultima marime vazuta
        self._known_paths = set()  # path -> deja adaugat SAU ignorat ca preexistent
        self._baseline_done = set()  # id-uri de foldere care si-au stabilit deja baseline-ul

    @property
    def folders(self):
        return self.settings.get("watch_folders", [])

    def add_folder(self, path):
        if any(f["path"] == path for f in self.folders):
            return
        self.settings.setdefault("watch_folders", []).append({"path": path, "enabled": True})
        self.save_settings(self.settings)

    def list_existing_files(self, path):
        """Listeaza (READ-ONLY, fara efecte secundare) fisierele deja
        existente intr-un folder proaspat adaugat — apelata la adaugare,
        ca userul sa aleaga CE anume vrea sa adauge acum in coada
        (2026-09-05, feedback direct de la Cristi: fara asta, indicarea
        unui folder care deja contine clipurile lui nu facea NIMIC —
        baseline-ul ignora deliberat tot ce exista deja, ca sa nu arunce
        orice folder ales in coada. Cristi ar fi trebuit sa copieze/mute
        fisierele ca sa "para noi" — exact duplicarea pe care n-o vrea)."""
        try:
            entries = os.listdir(path)
        except OSError:
            return []
        return [
            os.path.join(path, name) for name in entries
            if "." in name and name.rsplit(".", 1)[-1].lower() in WATCH_EXTENSIONS
        ]

    def mark_baseline_known(self, path, files):
        """Marcheaza TOATE fisierele deja existente (indiferent ce a ales
        userul sa adauge acum) ca "cunoscute" — apelata o singura data,
        dupa ce userul a raspuns la dialogul de selectie (adauga unele,
        toate, sau anuleaza), ca scanarea periodica sa nu le mai
        re-detecteze ca fiind "noi"."""
        self._known_paths.update(files)
        self._baseline_done.add(path)

    def remove_folder(self, path):
        self.settings["watch_folders"] = [f for f in self.folders if f["path"] != path]
        self._baseline_done.discard(path)
        self.save_settings(self.settings)

    def toggle_folder(self, path):
        for f in self.folders:
            if f["path"] == path:
                f["enabled"] = not f["enabled"]
                break
        self.save_settings(self.settings)

    def start(self):
        if self._thread is not None:
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop_event.set()

    def _run(self):
        while not self._stop_event.is_set():
            self._scan_all()
            self._stop_event.wait(POLL_INTERVAL_SECONDS)

    def _scan_all(self):
        stable_new_files = []

        for folder in self.folders:
            if not folder.get("enabled", True):
                continue
            path = folder["path"]
            try:
                entries = os.listdir(path)
            except OSError:
                continue
            candidates = [
                os.path.join(path, name) for name in entries
                if name.rsplit(".", 1)[-1].lower() in WATCH_EXTENSIONS and "." in name
            ]

            if path not in self._baseline_done:
                # Prima trecere pe acest folder — doar stabilim baseline-ul,
                # NU adaugam fisierele deja existente.
                self._known_paths.update(candidates)
                self._baseline_done.add(path)
                continue

            for candidate in candidates:
                if candidate in self._known_paths:
                    continue
                try:
                    size = os.path.getsize(candidate)
                except OSError:
                    continue
                last_size = self._pending_sizes.get(candidate)
                if last_size is not None and last_size == size:
                    # Marime neschimbata fata de trecerea anterioara —
                    # fisierul s-a terminat de scris.
                    del self._pending_sizes[candidate]
                    self._known_paths.add(candidate)
                    stable_new_files.append(candidate)
                else:
                    self._pending_sizes[candidate] = size

        if stable_new_files and self.on_new_files:
            self.on_new_files(stable_new_files)
