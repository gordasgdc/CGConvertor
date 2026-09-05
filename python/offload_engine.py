# offload_engine.py
"""Offload/Checksum — copiere sursa->destinatie(i) cu verificare integrala
(MD5/SHA-1/SHA-256/xxHash64/doar-marime), pentru offload de card media
(Faza 2 din planul CGConvertor v3.0.0).

SCOP DELIBERAT REDUS fata de `DataMover` (aplicatia sora din ecosistemul
GDC, unde acest tipar a fost dezvoltat initial): NU se porteaza aici MHL,
sincronizare Cloud (rclone), detectie structura de card de camera,
sabloane de denumire, coada automata de carduri, ejectare automata, sau
rapoarte PDF/HTML brandate. Ce urmeaza e nucleul: copiere fiabila,
verificata, cu buffer/backpressure conform Regulii 21, plus un raport CSV
incremental — vezi `OffloadEngine.swift` (Mac) pentru portul identic ca
model de date, si `DataMover/core/offload_engine.py` daca se cere vreodata
restul fluxului profesional."""

import csv
import hashlib
import os
import threading
import time
from datetime import datetime

import xxhash

import io_settings

VERIFICATION_MODELS = ["xxhash64", "md5", "sha1", "sha256", "size_only"]
DEFAULT_VERIFICATION_MODEL = "xxhash64"


def is_excluded(filename):
    return filename.startswith(".")  # fisiere ascunse — .DS_Store etc.


def list_all_files(root):
    """Scanare recursiva simpla — NU streaming (vezi nota din
    `offload_listAllFiles`/Swift: un card media tipic ramane confortabil
    sub pragul unde streaming-ul ar conta; `DataMover` are deja varianta
    lazy/manifest daca se dovedeste necesara vreodata aici)."""
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not is_excluded(d)]
        for name in filenames:
            if is_excluded(name):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            try:
                size = os.path.getsize(full)
            except OSError:
                size = 0
            out.append({"full_path": full, "rel_path": rel, "size": size})
    return out


def copy_file_cancelable(src, dst, cancel_event, chunk_size):
    """Copiere in bucati, cancelabila — citire mereu sincron cu scrierea
    (Regula 21: fara buffer de "read-ahead" care ar acumula date nescrise
    in RAM)."""
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.exists(dst):
        os.remove(dst)
    with open(src, "rb") as fsrc, open(dst, "wb") as fdst:
        while True:
            if cancel_event.is_set():
                fdst.close()
                if os.path.exists(dst):
                    os.remove(dst)
                raise _OffloadCancelled()
            chunk = fsrc.read(chunk_size)
            if not chunk:
                break
            fdst.write(chunk)
    try:
        stat = os.stat(src)
        os.utime(dst, (stat.st_atime, stat.st_mtime))
    except OSError:
        pass


class _OffloadCancelled(Exception):
    pass


def hash_of_file(path, model, cancel_event, chunk_size):
    if model == "size_only":
        return ""
    hasher = {"md5": hashlib.md5, "sha1": hashlib.sha1, "sha256": hashlib.sha256,
              "xxhash64": lambda: xxhash.xxh64(seed=0)}[model]()
    with open(path, "rb") as f:
        while True:
            if cancel_event.is_set():
                raise _OffloadCancelled()
            chunk = f.read(chunk_size)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


class DestinationJob:
    """Copiaza + verifica toate fisierele sursa catre O destinatie. Rulat
    pe un thread de fundal, niciodata pe thread-ul UI (Tkinter)."""

    def __init__(self, destination, files, model, cancel_event, pause_event, cfg,
                 on_file_done, on_activity):
        self.destination = destination
        self.files = files
        self.model = model
        self.cancel_event = cancel_event
        self.pause_event = pause_event
        self.cfg = cfg
        self.on_file_done = on_file_done
        self.on_activity = on_activity

    def run(self):
        os.makedirs(self.destination, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_path = os.path.join(self.destination, f"offload_report_{timestamp}.csv")
        ok = mismatch = errors = 0
        chunk_size = io_settings.get_chunk_size_bytes(self.cfg)

        with open(csv_path, "w", newline="", encoding="utf-8") as csv_file:
            writer = csv.writer(csv_file)
            writer.writerow(["fisier", "marime_bytes", "verificare_sursa", "verificare_destinatie", "status", "eroare"])
            csv_file.flush()

            for entry in self.files:
                if self.cancel_event.is_set():
                    break
                while self.pause_event.is_set() and not self.cancel_event.is_set():
                    time.sleep(0.2)
                if self.cancel_event.is_set():
                    break

                io_settings.wait_if_over_ram_limit(
                    self.cancel_event, self.cfg,
                    on_warning=lambda: self.on_activity("ram_wait"),
                )

                dst_path = os.path.join(self.destination, entry["rel_path"])
                try:
                    copy_file_cancelable(entry["full_path"], dst_path, self.cancel_event, chunk_size)
                    if self.model == "size_only":
                        dst_size = os.path.getsize(dst_path)
                        if dst_size == entry["size"]:
                            ok += 1
                            writer.writerow([entry["rel_path"], entry["size"], "", "", "OK", ""])
                        else:
                            mismatch += 1
                            writer.writerow([entry["rel_path"], entry["size"], "", "", "NEPOTRIVIRE", "marime diferita"])
                    else:
                        src_hash = hash_of_file(entry["full_path"], self.model, self.cancel_event, chunk_size)
                        dst_hash = hash_of_file(dst_path, self.model, self.cancel_event, chunk_size)
                        if src_hash == dst_hash:
                            ok += 1
                            writer.writerow([entry["rel_path"], entry["size"], src_hash, dst_hash, "OK", ""])
                        else:
                            mismatch += 1
                            writer.writerow([entry["rel_path"], entry["size"], src_hash, dst_hash, "NEPOTRIVIRE", "hash diferit"])
                            self.on_activity(("mismatch", entry["rel_path"]))
                except _OffloadCancelled:
                    break
                except OSError as e:
                    errors += 1
                    writer.writerow([entry["rel_path"], entry["size"], "", "", "EROARE", str(e)])
                    self.on_activity(("error", entry["rel_path"], str(e)))
                csv_file.flush()
                self.on_file_done(entry["size"])

        return {"destination": self.destination, "ok": ok, "mismatch": mismatch, "errors": errors, "csv_path": csv_path}


def format_speed(bytes_per_second):
    mb = bytes_per_second / (1024 * 1024)
    if mb >= 1024:
        return f"{mb / 1024:.1f} GB/s"
    return f"{mb:.1f} MB/s"


class OffloadRunner:
    """Orchestreaza un `DestinationJob` per destinatie, in threaduri
    paralele. Stare citita de UI (Tkinter) prin polling (`.after(...)`),
    la fel ca restul aplicatiei (coada de conversie existenta) — nu prin
    callback-uri directe pe thread-ul UI."""

    def __init__(self, cfg):
        self.cfg = cfg
        self.is_running = False
        self.is_paused = False
        self.progress_percent = 0.0
        self.files_done = 0
        self.total_files = 0
        self.status_text = ""
        self.speed_text = ""
        self.activity_log = []
        self.last_results = []
        self._activity_limit = 200
        self._cancel_event = threading.Event()
        self._pause_event = threading.Event()
        self._lock = threading.Lock()
        self._bytes_done = 0
        self._started_at = 0.0
        self._on_update = None  # callback fara argumente, apelat din threadurile de fundal

    def set_on_update(self, callback):
        self._on_update = callback

    def toggle_pause(self):
        if self._pause_event.is_set():
            self._pause_event.clear()
            self.is_paused = False
        else:
            self._pause_event.set()
            self.is_paused = True
        self._notify()

    def cancel(self):
        self._cancel_event.set()
        self.status_text = "cancelling"
        self._notify()

    def start(self, source_root, destinations, model, translate):
        if not destinations:
            return
        self._cancel_event = threading.Event()
        self._pause_event = threading.Event()
        self.is_paused = False
        self.activity_log = []
        self.last_results = []

        files = list_all_files(source_root)
        if not files:
            self.status_text = translate("offload_no_files")
            self._notify()
            return

        self.total_files = len(files) * len(destinations)
        self.files_done = 0
        self._bytes_done = 0
        self.progress_percent = 0.0
        self.is_running = True
        self._started_at = time.time()
        self.status_text = translate("offload_running", n=len(files), d=len(destinations))
        self._notify()

        results = []
        results_lock = threading.Lock()
        threads = []

        def run_one(dest):
            def on_file_done(size):
                with self._lock:
                    self.files_done += 1
                    self._bytes_done += size
                    self.progress_percent = (self.files_done / self.total_files) * 100 if self.total_files else 0
                    elapsed = max(time.time() - self._started_at, 0.001)
                    self.speed_text = format_speed(self._bytes_done / elapsed)
                self._notify()

            def on_activity(item):
                if item == "ram_wait":
                    line = translate("offload_ram_wait_log")
                elif item[0] == "mismatch":
                    line = translate("offload_mismatch_log", f=item[1])
                else:
                    line = translate("offload_error_log", f=item[1], e=item[2])
                self.activity_log.append(line)
                if len(self.activity_log) > self._activity_limit:
                    self.activity_log = self.activity_log[-self._activity_limit:]
                self._notify()

            job = DestinationJob(dest, files, model, self._cancel_event, self._pause_event, self.cfg,
                                  on_file_done, on_activity)
            result = job.run()
            with results_lock:
                results.append(result)

        for dest in destinations:
            th = threading.Thread(target=run_one, args=(dest,), daemon=True)
            threads.append(th)
            th.start()

        def wait_all():
            for th in threads:
                th.join()
            self.is_running = False
            self.last_results = results
            total_ok = sum(r["ok"] for r in results)
            total_mismatch = sum(r["mismatch"] for r in results)
            total_errors = sum(r["errors"] for r in results)
            if self._cancel_event.is_set():
                self.status_text = translate("offload_cancelled")
            else:
                self.status_text = translate("offload_done", ok=total_ok, mismatch=total_mismatch, err=total_errors)
            self._notify()

        threading.Thread(target=wait_all, daemon=True).start()

    def _notify(self):
        if self._on_update:
            self._on_update()
