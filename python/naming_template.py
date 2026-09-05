# naming_template.py
"""Sablon configurabil pentru numele folderului de destinatie — port 1:1
al `NamingTemplate.swift` (Mac), care la randul lui e portat din DataMover.
Sablonul implicit reproduce EXACT comportamentul vechi (`<data>_<Proiect>_
<Card>`), deci nimeni nu e afectat daca nu-l schimba."""

import re
from datetime import datetime

DEFAULT_TEMPLATE = "{data}_{proiect}_{card}"
TOKENS = ["{data}", "{ora}", "{proiect}", "{card}", "{camera}", "{operator}"]

_FORBIDDEN = re.compile(r'[/\\:*?"<>|]')


def _sanitize(value):
    value = value.strip()
    value = _FORBIDDEN.sub("", value)
    return value.replace(" ", "_")


def _fallback(value, implicit):
    trimmed = value.strip()
    return _sanitize(trimmed if trimmed else implicit)


def _clean_up(value):
    while "__" in value:
        value = value.replace("__", "_")
    while "--" in value:
        value = value.replace("--", "-")
    value = value.strip("_- ")
    return value or "Transfer"


def _expand(template, project, card, camera, operator_name, date, include_time_tokens):
    template = template or DEFAULT_TEMPLATE
    replacements = [
        ("{data}", date.strftime("%Y-%m-%d") if include_time_tokens else ""),
        ("{ora}", date.strftime("%H-%M") if include_time_tokens else ""),
        ("{proiect}", _fallback(project, "Proiect")),
        ("{card}", _fallback(card, "Card")),
        ("{camera}", _sanitize(camera)),
        ("{operator}", _sanitize(operator_name)),
    ]
    out = template
    for token, value in replacements:
        out = re.sub(re.escape(token), value, out, flags=re.IGNORECASE)
    return _clean_up(out)


def render(template, project="", card="", camera="", operator_name="", date=None):
    return _expand(template, project, card, camera, operator_name, date or datetime.now(), True)


def stable_core(template, project="", card="", camera="", operator_name="", date=None):
    """Miezul stabil al numelui (fara tokenii de data/ora) — folosit pentru
    a recunoaste un transfer anterior al ACELUIASI card, inceput in alta
    zi (vezi CLAUDE.md)."""
    return _expand(template, project, card, camera, operator_name, date or datetime.now(), False)
