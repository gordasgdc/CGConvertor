# transfer_profile.py
"""Profile de transfer salvate — port 1:1 al `TransferProfile.swift`
(Mac), care la randul lui e portat din DataMover. O configuratie completa,
numita de user, reutilizabila fara sa retastezi cai/optiuni de fiecare
data."""

import json
import os

from history_store import _app_support_dir


class TransferProfileStore:
    def __init__(self):
        self.path = os.path.join(_app_support_dir(), "transfer_profiles.json")
        self.profiles = self._load()

    def _load(self):
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return []

    def _save(self):
        try:
            with open(self.path, "w", encoding="utf-8") as f:
                json.dump(self.profiles, f, ensure_ascii=False, indent=2)
        except OSError:
            pass

    def upsert(self, profile):
        """`profile` = dict cu cheia "name" + restul campurilor."""
        for i, existing in enumerate(self.profiles):
            if existing["name"] == profile["name"]:
                self.profiles[i] = profile
                self._save()
                return
        self.profiles.append(profile)
        self._save()

    def delete(self, name):
        self.profiles = [p for p in self.profiles if p["name"] != name]
        self._save()


_shared = None


def shared():
    global _shared
    if _shared is None:
        _shared = TransferProfileStore()
    return _shared
