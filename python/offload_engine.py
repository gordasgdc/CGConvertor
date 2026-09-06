# offload_engine.py
"""Offload/Checksum — copiere sursa->destinatie(i) cu verificare integrala
(MD5/SHA-1/SHA-256/xxHash64/doar-marime), pentru offload de card media.

Etapa 2026-09-05 (paritate cu `OffloadEngine.swift`/Mac, port al fluxului
profesional din DataMover, Etapa 2026-09-03): sablon de denumire folder
(`naming_template.py`), MHL alaturi de CSV (`mhl_writer.py`), reincercare
automata a fisierelor esuate, verificare de spatiu liber INAINTE de
transfer, raport HTML brandat cu date de productie (`production_meta.py`),
istoric persistat (`history_store.py`). NU se porteaza inca sincronizarea
Cloud (rclone) — vezi CLAUDE.md, deliberat amanat (cere un cont real
pentru testare end-to-end)."""

import csv
import hashlib
import os
import shutil
import threading
import time
from datetime import datetime

import xxhash

import history_store
import io_settings
import mhl_writer
import naming_template
import production_meta

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


def has_enough_space(destination_root, needed_bytes):
    """Verificare de spatiu liber INAINTE de primul octet copiat (port
    DataMover) — marja: 1% din transfer, minim 100 MB. Intoarce
    (ok, available_bytes) — available_bytes=None daca nu s-a putut citi
    (nu blocam transferul pe o necunoscuta)."""
    try:
        available = shutil.disk_usage(destination_root).free
    except OSError:
        return True, None
    margin = max(int(needed_bytes * 0.01), 100 * 1024 * 1024)
    return available >= needed_bytes + margin, available


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
    """Copiaza + verifica toate fisierele sursa catre O destinatie, intr-un
    subfolder generat cu `naming_template` (radacina `destination` ramane
    discul/folderul ales de user, la fel ca `OffloadEngine.swift`). Rulat
    pe un thread de fundal, niciodata pe thread-ul UI (Tkinter).

    Etapa 2026-09-05: reincercare automata (o singura data) a fisierelor
    esuate/nepotrivite, MHL alaturi de CSV, raport HTML brandat cu
    `production_meta`."""

    def __init__(self, destination, folder_name, files, model, meta, cancel_event, pause_event, cfg,
                 on_file_done, on_activity, app_version="?"):
        self.destination = destination
        self.folder_name = folder_name
        self.files = files
        self.model = model
        self.meta = meta
        self.cancel_event = cancel_event
        self.pause_event = pause_event
        self.cfg = cfg
        self.on_file_done = on_file_done
        self.on_activity = on_activity
        self.app_version = app_version
        self.started_at = datetime.now()

    def run(self):
        target_root = os.path.join(self.destination, self.folder_name)
        os.makedirs(target_root, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_path = os.path.join(target_root, f"offload_report_{timestamp}.csv")
        mhl_path_target = os.path.join(target_root, f"{self.folder_name}.mhl")
        mhl = mhl_writer.make_writer(mhl_path_target, self.model, "CGConvertor", self.started_at)

        chunk_size = io_settings.get_chunk_size_bytes(self.cfg)
        rows = []
        failed_entries = []  # [(entry, was_error)]
        ok = mismatch = errors = 0

        with open(csv_path, "w", newline="", encoding="utf-8") as csv_file:
            writer = csv.writer(csv_file)
            writer.writerow(["fisier", "marime_bytes", "verificare_sursa", "verificare_destinatie", "status", "eroare"])
            csv_file.flush()

            def process_one(entry, is_retry):
                """O singura trecere de copiere+verificare — IDENTICA la
                prima trecere SI la reincercare (port DataMover: cele doua
                cai nu trebuie sa diveraga). Intoarce "ok"/"mismatch"/"error"
                — NU incrementeaza contoarele, apelantul decide."""
                if self.cancel_event.is_set():
                    return "error"
                while self.pause_event.is_set() and not self.cancel_event.is_set():
                    time.sleep(0.2)
                if self.cancel_event.is_set():
                    return "error"
                io_settings.wait_if_over_ram_limit(
                    self.cancel_event, self.cfg, on_warning=lambda: self.on_activity("ram_wait"),
                )

                dst_path = os.path.join(target_root, entry["rel_path"])
                if is_retry and os.path.exists(dst_path):
                    os.remove(dst_path)  # fisierul partial anterior nu trebuie sa induca in eroare verificarea

                status_ok = "OK (reîncercat)" if is_retry else "OK"
                try:
                    copy_file_cancelable(entry["full_path"], dst_path, self.cancel_event, chunk_size)
                    if self.model == "size_only":
                        dst_size = os.path.getsize(dst_path)
                        if dst_size == entry["size"]:
                            row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": status_ok, "error": "", "dest_path": dst_path}
                            writer.writerow([entry["rel_path"], entry["size"], "", "", status_ok, ""])
                            rows.append(row)
                            if mhl:
                                mhl.add(entry["rel_path"], entry["size"], "", datetime.now())
                            return "ok"
                        row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": "NEPOTRIVIRE", "error": "marime diferita", "dest_path": dst_path}
                        writer.writerow([entry["rel_path"], entry["size"], "", "", "NEPOTRIVIRE", "marime diferita"])
                        rows.append(row)
                        return "mismatch"
                    src_hash = hash_of_file(entry["full_path"], self.model, self.cancel_event, chunk_size)
                    dst_hash = hash_of_file(dst_path, self.model, self.cancel_event, chunk_size)
                    if src_hash == dst_hash:
                        row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": status_ok, "error": "", "dest_path": dst_path}
                        writer.writerow([entry["rel_path"], entry["size"], src_hash, dst_hash, status_ok, ""])
                        rows.append(row)
                        if mhl:
                            mhl.add(entry["rel_path"], entry["size"], src_hash, datetime.now())
                        return "ok"
                    row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": "NEPOTRIVIRE", "error": "hash diferit", "dest_path": dst_path}
                    writer.writerow([entry["rel_path"], entry["size"], src_hash, dst_hash, "NEPOTRIVIRE", "hash diferit"])
                    rows.append(row)
                    self.on_activity(("mismatch", entry["rel_path"]))
                    return "mismatch"
                except _OffloadCancelled:
                    return "error"
                except OSError as e:
                    row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": "EROARE", "error": str(e)}
                    writer.writerow([entry["rel_path"], entry["size"], "", "", "EROARE", str(e)])
                    rows.append(row)
                    self.on_activity(("error", entry["rel_path"], str(e)))
                    return "error"
                finally:
                    csv_file.flush()

            for entry in self.files:
                if self.cancel_event.is_set():
                    break
                outcome = process_one(entry, is_retry=False)
                if outcome == "ok":
                    ok += 1
                elif outcome == "mismatch":
                    mismatch += 1
                    failed_entries.append((entry, False))
                else:
                    errors += 1
                    failed_entries.append((entry, True))
                self.on_file_done(entry["size"])

            # Reincercare automata, o singura data — fisierele care mai
            # esueaza a doua oara raman definitiv NEPOTRIVIRE/EROARE, fara
            # dubla numarare.
            recovered = 0
            if not self.cancel_event.is_set() and failed_entries:
                self.on_activity(("retrying", len(failed_entries)))
                for entry, was_error in failed_entries:
                    if self.cancel_event.is_set():
                        break
                    outcome = process_one(entry, is_retry=True)
                    if outcome == "ok":
                        ok += 1
                        recovered += 1
                        if was_error:
                            errors = max(0, errors - 1)
                        else:
                            mismatch = max(0, mismatch - 1)

        mhl_final_path = mhl.close(datetime.now()) if mhl else None
        html_path = os.path.join(target_root, f"Raport_{timestamp}.html")
        verification_labels = {"xxhash64": "xxHash64", "md5": "MD5", "sha1": "SHA-1", "sha256": "SHA-256", "size_only": "Doar mărime"}
        html_ok = production_meta.write_html_report(
            html_path, self.destination, self.folder_name, rows, self.meta,
            self.started_at, datetime.now(), ok, mismatch, errors,
            verification_labels.get(self.model, self.model), mhl_final_path, self.app_version,
        )

        return {
            "destination": self.destination, "target_root": target_root,
            "ok": ok, "mismatch": mismatch, "errors": errors, "recovered": recovered,
            "csv_path": csv_path, "mhl_path": mhl_final_path, "html_path": html_path if html_ok else None,
        }


def _format_bytes(n):
    n = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


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
        self.insufficient_space_warning = None

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

    def start(self, source_root, destinations, model, translate, meta=None, naming_tmpl="",
              app_version="?", ignore_space_warning=False):
        if not destinations:
            return
        self._cancel_event = threading.Event()
        self._pause_event = threading.Event()
        self.is_paused = False
        self.activity_log = []
        self.last_results = []
        self.insufficient_space_warning = None
        meta = meta or production_meta.ProductionMeta()

        files = list_all_files(source_root)
        if not files:
            self.status_text = translate("offload_no_files")
            self._notify()
            return

        needed_bytes = sum(f["size"] for f in files)
        folder_name = naming_template.render(
            naming_tmpl, project=meta.project, card=meta.card, camera=meta.camera, operator_name=meta.operator_name,
        )

        if not ignore_space_warning:
            for dest in destinations:
                os.makedirs(dest, exist_ok=True)
                ok_space, available = has_enough_space(dest, needed_bytes)
                if not ok_space:
                    self.insufficient_space_warning = translate(
                        "offload_insufficient_space", d=os.path.basename(dest),
                        needed=_format_bytes(needed_bytes), available=_format_bytes(available or 0),
                    )
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
                elif item[0] == "retrying":
                    line = translate("offload_retrying_log", n=item[1])
                else:
                    line = translate("offload_error_log", f=item[1], e=item[2])
                self.activity_log.append(line)
                if len(self.activity_log) > self._activity_limit:
                    self.activity_log = self.activity_log[-self._activity_limit:]
                self._notify()

            job = DestinationJob(dest, folder_name, files, model, meta, self._cancel_event, self._pause_event,
                                  self.cfg, on_file_done, on_activity, app_version)
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
            total_recovered = sum(r["recovered"] for r in results)
            if self._cancel_event.is_set():
                self.status_text = translate("offload_cancelled")
            else:
                self.status_text = (
                    translate("offload_done_recovered", ok=total_ok, mismatch=total_mismatch, err=total_errors, rec=total_recovered)
                    if total_recovered > 0 else
                    translate("offload_done", ok=total_ok, mismatch=total_mismatch, err=total_errors)
                )
                history_store.shared().record(
                    folder_name=folder_name, source_path=source_root,
                    destination_targets=[r["target_root"] for r in results],
                    ok_count=total_ok, mismatch_count=total_mismatch, error_count=total_errors,
                )
            self._notify()

        threading.Thread(target=wait_all, daemon=True).start()

    def _notify(self):
        if self._on_update:
            self._on_update()
