# mhl_writer.py
"""Generator de fisier MHL (Media Hash List, v1.1) — port 1:1 al
`MHLWriter.swift` (Mac), care la randul lui e portat din DataMover.
Standardul de facto prin care un ofloader de platou preda datele catre
post-productie (citit de Silverstack, YoYotta, ShotPut Pro, Resolve).

MEMORIE: intrarile se scriu incremental intr-un fisier `.part`; la
`close()` se compune fisierul final (antet + corp) — motivul: `<creatorinfo>`
sta obligatoriu PRIMUL si contine `<finishdate>`, cunoscut abia la sfarsit."""

import getpass
import os
import socket
import xml.sax.saxutils as sax
from datetime import datetime, timezone

_ELEMENT_FOR_MODEL = {
    "md5": "md5", "sha1": "sha1", "xxhash64": "xxhash64be",
    # sha256/size_only nu fac parte din schema MHL 1.1
}


def element_for(model):
    return _ELEMENT_FOR_MODEL.get(model)


def is_supported(model):
    return element_for(model) is not None


def _iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class MHLWriter:
    def __init__(self, path, model, tool_name, started_at):
        self.hash_element = element_for(model)
        if self.hash_element is None:
            raise ValueError(f"Model de verificare '{model}' nu e suportat de MHL 1.1")
        self.final_path = path
        self.part_path = path + ".part"
        self.tool_name = tool_name
        self.started_at = started_at
        self.entry_count = 0
        self._part_file = open(self.part_path, "w", encoding="utf-8")

    def add(self, rel_path, size, hash_hex, hashed_at, modification_date=None):
        """Doar pentru fisiere verificate cu succes (OK/SARIT) — un MHL nu
        are voie sa contina un fisier care n-a trecut verificarea."""
        if not hash_hex:
            return
        rel_path = rel_path.replace(os.sep, "/")  # cai relative portabile intre Mac/Windows
        xml = "  <hash>\n"
        xml += f"    <file>{sax.escape(rel_path)}</file>\n"
        xml += f"    <size>{size}</size>\n"
        if modification_date:
            xml += f"    <lastmodificationdate>{_iso(modification_date)}</lastmodificationdate>\n"
        xml += f"    <{self.hash_element}>{hash_hex}</{self.hash_element}>\n"
        xml += f"    <hashdate>{_iso(hashed_at)}</hashdate>\n"
        xml += "  </hash>\n"
        self._part_file.write(xml)
        self.entry_count += 1

    def close(self, finished_at):
        """Scrie fisierul MHL final. Intoarce calea lui, sau None daca n-a
        existat nicio intrare valida."""
        self._part_file.close()
        try:
            if self.entry_count == 0:
                return None

            header = '<?xml version="1.0" encoding="UTF-8"?>\n'
            header += '<hashlist version="1.1">\n'
            header += "  <creatorinfo>\n"
            try:
                full_name = getpass.getuser()
            except Exception:
                full_name = "unknown"
            header += f"    <name>{sax.escape(full_name)}</name>\n"
            header += f"    <username>{sax.escape(full_name)}</username>\n"
            header += f"    <hostname>{sax.escape(socket.gethostname())}</hostname>\n"
            header += f"    <tool>{sax.escape(self.tool_name)}</tool>\n"
            header += f"    <startdate>{_iso(self.started_at)}</startdate>\n"
            header += f"    <finishdate>{_iso(finished_at)}</finishdate>\n"
            header += "  </creatorinfo>\n"

            with open(self.final_path, "w", encoding="utf-8") as out:
                out.write(header)
                with open(self.part_path, "r", encoding="utf-8") as part:
                    while True:
                        chunk = part.read(256 * 1024)
                        if not chunk:
                            break
                        out.write(chunk)
                out.write("</hashlist>\n")
            return self.final_path
        finally:
            try:
                os.remove(self.part_path)
            except OSError:
                pass


def make_writer(path, model, tool_name, started_at):
    """Fabrica sigura — None daca modelul nu e suportat de MHL 1.1, in loc
    sa ridice o exceptie (verificarea/rapoartele CSV raman complete oricum)."""
    if not is_supported(model):
        return None
    return MHLWriter(path, model, tool_name, started_at)
