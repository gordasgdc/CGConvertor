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
import sys
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

# [2026-09-06] Port al imbunatatirilor din Data Mover v2.14.0 (M1+M2,
# vezi CLAUDE.md acelui repo) — motorul vechi (mai jos, `DestinationJob`)
# citea fiecare fisier sursa de 3 ori PER DESTINATIE: o data la copiere
# (`copy_file_cancelable`), apoi separat pentru hash-ul sursei si hash-ul
# destinatiei (`hash_of_file` x2) — exact ineficienta identificata si
# rezolvata in Data Mover (acolo, 4 citiri cu 2 destinatii). Noul motor
# (`copy_and_verify_fanout`) citeste sursa O SINGURA DATA, scrie catre
# TOATE destinatiile din acelasi flux de octeti, si calculeaza hash-ul
# sursei SI al fiecarei destinatii incremental, pe masura ce datele trec
# prin bucla — zero re-cititri. Spre deosebire de Data Mover (Swift/C#,
# thread-uri separate per destinatie cu ring-buffer/backpressure reala),
# aici scrierea catre destinatii ramane secventiala in acelasi thread per
# fisier (simplitate — Python/Tkinter, nu un motor de transfer de mare
# performanta) - castigul real (o singura citire a sursei, nu N) ramane
# identic, doar paralelismul intre destinatii nu e la fel de fin.


class IncrementalHasher:
    """Hash calculat INCREMENTAL, pe masura ce chunk-urile trec prin
    bucla de copiere — nu o trecere separata peste fisier (vezi nota de
    mai sus). `.size_only` nu calculeaza niciun hash (compatibil cu
    modelul `size_only` existent, care compara doar marimea)."""

    def __init__(self, model):
        self.model = model
        if model == "size_only":
            self._h = None
        elif model == "xxhash64":
            self._h = xxhash.xxh64(seed=0)
        else:
            self._h = {"md5": hashlib.md5, "sha1": hashlib.sha1, "sha256": hashlib.sha256}[model]()

    def update(self, chunk):
        if self._h is not None:
            self._h.update(chunk)

    def hexdigest(self):
        return self._h.hexdigest() if self._h is not None else ""


def physical_flush(f):
    """Flush FIZIC pe disc (port Data Mover M2) — `f.flush()` (Python) +
    `os.fsync()` (buffer-ul OS) NU garanteaza ca datele au ajuns fizic pe
    suportul de stocare, doar ca au parasit buffer-ul procesului/OS-ului;
    pe un card care se scoate imediat dupa offload, un flush incomplet
    poate insemna date pierdute la o intrerupere de curent/deconectare
    brusca. Pe macOS, `fsync()` simplu NU e suficient (documentat de
    Apple) — trebuie `fcntl(fd, F_FULLFSYNC)` pentru flush fizic real, cu
    fallback pe `fsync()` daca discul nu suporta `F_FULLFSYNC` (ex. unele
    unitati de retea — `ENOTSUP`). Pe Windows, `os.fsync()` apeleaza deja
    nativ `FlushFileBuffers` (documentat de Microsoft) — niciun cod
    suplimentar necesar. Identic ca logica cu `FanOutCopier.swift`/`.cs`
    din Data Mover (M2)."""
    f.flush()
    fd = f.fileno()
    if sys.platform == "darwin":
        import fcntl
        F_FULLFSYNC = getattr(fcntl, "F_FULLFSYNC", 51)  # 51 = valoarea reala pe macOS, fallback daca modulul nu o expune
        try:
            fcntl.fcntl(fd, F_FULLFSYNC)
            return
        except OSError:
            pass  # ENOTSUP pe unele sisteme de fisiere — fallback pe fsync() simplu, mai jos
    os.fsync(fd)


def copy_and_verify_fanout(src_path, dest_paths, model, cancel_event, pause_event, cfg, chunk_size):
    """Citeste `src_path` O SINGURA DATA, scrie simultan catre TOATE
    caile din `dest_paths` (listă), calculand hash-ul sursei si al
    fiecarei destinatii INCREMENTAL, in aceeasi bucla — vezi comentariul
    de la `IncrementalHasher`/`physical_flush` mai sus.

    Intoarce (source_hash, bytes_read, {dest_path: (ok, dest_hash, error)}).
    O eroare de scriere la O destinatie NU opreste scrierea celorlalte —
    fiecare destinatie e independenta (port `FanOutResult`/Data Mover)."""
    os.makedirs(os.path.dirname(src_path) or ".", exist_ok=True)  # no-op pt sursa, simetrie cu bucla de mai jos
    for dst in dest_paths:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            os.remove(dst)

    src_hasher = IncrementalHasher(model)
    dest_handles = {}
    dest_hashers = {}
    dest_errors = {}
    for dst in dest_paths:
        try:
            dest_handles[dst] = open(dst, "wb")
            dest_hashers[dst] = IncrementalHasher(model)
        except OSError as e:
            dest_errors[dst] = str(e)

    bytes_read = 0
    try:
        with open(src_path, "rb") as fsrc:
            while True:
                if cancel_event.is_set():
                    raise _OffloadCancelled()
                while pause_event.is_set() and not cancel_event.is_set():
                    time.sleep(0.2)
                if cancel_event.is_set():
                    raise _OffloadCancelled()
                io_settings.wait_if_over_ram_limit(cancel_event, cfg, on_warning=lambda: None)

                chunk = fsrc.read(chunk_size)
                if not chunk:
                    break
                bytes_read += len(chunk)
                src_hasher.update(chunk)
                for dst, handle in list(dest_handles.items()):
                    if dst in dest_errors:
                        continue
                    try:
                        handle.write(chunk)
                        dest_hashers[dst].update(chunk)
                    except OSError as e:
                        dest_errors[dst] = str(e)
    finally:
        for dst, handle in dest_handles.items():
            try:
                if dst not in dest_errors:
                    physical_flush(handle)
            except OSError as e:
                dest_errors.setdefault(dst, str(e))
            finally:
                handle.close()

    results = {}
    for dst in dest_paths:
        if dst in dest_errors:
            results[dst] = (False, "", dest_errors[dst])
        else:
            try:
                stat = os.stat(src_path)
                os.utime(dst, (stat.st_atime, stat.st_mtime))
            except OSError:
                pass
            results[dst] = (True, dest_hashers[dst].hexdigest(), None)
    return src_hasher.hexdigest(), bytes_read, results


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


class DestinationContext:
    """Bookkeeping pentru O destinatie (CSV, MHL, rows, contoare) — port
    simplificat al `DestinationContext.swift`/`.cs` din Data Mover (fara
    checkpoint/resume, care nu exista inca in acest motor — nimic de
    pastrat acolo). Nu mai contine bucla de copiere in sine — aceea e
    acum UNICA, in `OffloadRunner.start()`, o singura data per FISIER,
    cu fan-out catre toate destinatiile (vezi comentariul de la
    `copy_and_verify_fanout`)."""

    def __init__(self, destination, folder_name, model, meta, cfg, app_version, started_at):
        self.destination = destination
        self.folder_name = folder_name
        self.model = model
        self.meta = meta
        self.app_version = app_version
        self.started_at = started_at
        self.target_root = os.path.join(destination, folder_name)
        os.makedirs(self.target_root, exist_ok=True)
        timestamp = started_at.strftime("%Y%m%d_%H%M%S")
        self.timestamp = timestamp
        self.csv_path = os.path.join(self.target_root, f"offload_report_{timestamp}.csv")
        mhl_path_target = os.path.join(self.target_root, f"{folder_name}.mhl")
        self.mhl = mhl_writer.make_writer(mhl_path_target, model, "CGConvertor", started_at)
        self.csv_file = open(self.csv_path, "w", newline="", encoding="utf-8")
        self.writer = csv.writer(self.csv_file)
        self.writer.writerow(["fisier", "marime_bytes", "verificare_sursa", "verificare_destinatie", "status", "eroare"])
        self.csv_file.flush()
        self.rows = []
        self.ok = 0
        self.mismatch = 0
        self.errors = 0
        self.recovered = 0
        self.failed_entries = []  # [(entry, was_error)]

    def dst_path(self, entry):
        return os.path.join(self.target_root, entry["rel_path"])

    def record_ok(self, entry, is_retry, src_hash):
        dst_path = self.dst_path(entry)
        status = "OK (reîncercat)" if is_retry else "OK"
        row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": status, "error": "", "dest_path": dst_path}
        self.writer.writerow([entry["rel_path"], entry["size"], src_hash, src_hash, status, ""])
        self.rows.append(row)
        if self.mhl:
            self.mhl.add(entry["rel_path"], entry["size"], src_hash, datetime.now())
        self.csv_file.flush()

    def record_mismatch(self, entry, src_hash, dst_hash, reason):
        dst_path = self.dst_path(entry)
        row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": "NEPOTRIVIRE", "error": reason, "dest_path": dst_path}
        self.writer.writerow([entry["rel_path"], entry["size"], src_hash, dst_hash, "NEPOTRIVIRE", reason])
        self.rows.append(row)
        self.csv_file.flush()

    def record_error(self, entry, error):
        row = {"rel_path": entry["rel_path"], "size_bytes": entry["size"], "status": "EROARE", "error": error}
        self.writer.writerow([entry["rel_path"], entry["size"], "", "", "EROARE", error])
        self.rows.append(row)
        self.csv_file.flush()

    def finalize(self):
        self.csv_file.close()
        mhl_final_path = self.mhl.close(datetime.now()) if self.mhl else None
        html_path = os.path.join(self.target_root, f"Raport_{self.timestamp}.html")
        verification_labels = {"xxhash64": "xxHash64", "md5": "MD5", "sha1": "SHA-1", "sha256": "SHA-256", "size_only": "Doar mărime"}
        html_ok = production_meta.write_html_report(
            html_path, self.destination, self.folder_name, self.rows, self.meta,
            self.started_at, datetime.now(), self.ok, self.mismatch, self.errors,
            verification_labels.get(self.model, self.model), mhl_final_path, self.app_version,
        )
        return {
            "destination": self.destination, "target_root": self.target_root,
            "ok": self.ok, "mismatch": self.mismatch, "errors": self.errors, "recovered": self.recovered,
            "csv_path": self.csv_path, "mhl_path": mhl_final_path, "html_path": html_path if html_ok else None,
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
    """Orchestreaza un `DestinationContext` per destinatie (bookkeeping),
    dar bucla de copiere efectivă e UNICĂ, pe un singur thread de fundal —
    o iterație per fișier, fan-out către toate destinațiile deodată (vezi
    `copy_and_verify_fanout`). Stare citită de UI (Tkinter) prin polling
    (`.after(...)`), la fel ca restul aplicației (coada de conversie
    existentă) — nu prin
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

        # [2026-09-06] Port Data Mover v2.14.0 (M1+Faza 2) — bucla unica,
        # o iteratie PE FISIER, fan-out catre toate destinatiile deodata
        # (`copy_and_verify_fanout`), in loc de N job-uri complet separate
        # (unul per destinatie, fiecare recitind sursa) ca inainte. Vezi
        # comentariul de la `copy_and_verify_fanout`/`IncrementalHasher`.
        started_at = datetime.now()
        contexts = [
            DestinationContext(dest, folder_name, model, meta, self.cfg, app_version, started_at)
            for dest in destinations
        ]
        chunk_size = io_settings.get_chunk_size_bytes(self.cfg)

        def on_file_progress(size):
            with self._lock:
                self.files_done += 1
                self._bytes_done += size
                self.progress_percent = (self.files_done / self.total_files) * 100 if self.total_files else 0
                elapsed = max(time.time() - self._started_at, 0.001)
                self.speed_text = format_speed(self._bytes_done / elapsed)
            self._notify()

        def log_activity(item):
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

        def process_entry(entry, ctxs, is_retry):
            """O singura citire a sursei (`copy_and_verify_fanout`), fan-out
            catre TOATE `ctxs` ramase active pentru acest fisier — la
            reincercare, doar contextele care au esuat prima data (nu se
            recitesc/rescriu destinatiile deja reusite). Intoarce
            {context: "ok"/"mismatch"/"error"}."""
            dest_paths = [c.dst_path(entry) for c in ctxs]
            try:
                src_hash, _, write_results = copy_and_verify_fanout(
                    entry["full_path"], dest_paths, model, self._cancel_event, self._pause_event,
                    self.cfg, chunk_size,
                )
            except _OffloadCancelled:
                return {c: "error" for c in ctxs}
            outcomes = {}
            for c in ctxs:
                dst = c.dst_path(entry)
                ok_write, dst_hash, error = write_results[dst]
                if not ok_write:
                    c.record_error(entry, error)
                    log_activity(("error", entry["rel_path"], error))
                    outcomes[c] = "error"
                    continue
                if model == "size_only":
                    dst_size = os.path.getsize(dst) if os.path.exists(dst) else -1
                    if dst_size == entry["size"]:
                        c.record_ok(entry, is_retry, "")
                        outcomes[c] = "ok"
                    else:
                        c.record_mismatch(entry, "", "", "marime diferita")
                        outcomes[c] = "mismatch"
                    continue
                if dst_hash == src_hash:
                    c.record_ok(entry, is_retry, src_hash)
                    outcomes[c] = "ok"
                else:
                    c.record_mismatch(entry, src_hash, dst_hash, "hash diferit")
                    log_activity(("mismatch", entry["rel_path"]))
                    outcomes[c] = "mismatch"
            return outcomes

        def run_all():
            failed_per_context = {c: [] for c in contexts}
            for entry in files:
                if self._cancel_event.is_set():
                    break
                outcomes = process_entry(entry, contexts, is_retry=False)
                for c, outcome in outcomes.items():
                    if outcome == "ok":
                        c.ok += 1
                    elif outcome == "mismatch":
                        c.mismatch += 1
                        failed_per_context[c].append((entry, False))
                    else:
                        c.errors += 1
                        failed_per_context[c].append((entry, True))
                    on_file_progress(entry["size"])

            # Reincercare automata, o singura data, grupata PE FISIER (nu
            # pe destinatie) — daca acelasi fisier a esuat la 2 destinatii
            # deodata, reincercarea tot citeste sursa o singura data.
            if not self._cancel_event.is_set():
                total_failed = sum(len(v) for v in failed_per_context.values())
                if total_failed:
                    log_activity(("retrying", total_failed))
                by_entry = {}
                for c, entries in failed_per_context.items():
                    for entry, was_error in entries:
                        by_entry.setdefault(entry["rel_path"], (entry, []))[1].append((c, was_error))
                for entry, ctx_pairs in by_entry.values():
                    if self._cancel_event.is_set():
                        break
                    ctxs = [c for c, _ in ctx_pairs]
                    was_error_map = dict(ctx_pairs)
                    outcomes = process_entry(entry, ctxs, is_retry=True)
                    for c, outcome in outcomes.items():
                        if outcome == "ok":
                            c.ok += 1
                            c.recovered += 1
                            if was_error_map[c]:
                                c.errors = max(0, c.errors - 1)
                            else:
                                c.mismatch = max(0, c.mismatch - 1)

            results = [c.finalize() for c in contexts]
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

        threading.Thread(target=run_all, daemon=True).start()

    def _notify(self):
        if self._on_update:
            self._on_update()
