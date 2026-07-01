"""Session token storage (memory + JSON persistence)."""

from __future__ import annotations

import json
import secrets
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


SESSION_TTL_DAYS = 7


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _new_token() -> str:
    return f"st-{secrets.token_urlsafe(32)}"


class SessionStore:
    def __init__(self, path: Path, lock: threading.RLock):
        self._path = path
        self._lock = lock
        self._sessions: list[dict[str, Any]] = []
        self._load()

    def _load(self) -> None:
        with self._lock:
            if not self._path.exists():
                self._sessions = []
                return
            try:
                data = json.loads(self._path.read_text(encoding="utf-8"))
                self._sessions = data if isinstance(data, list) else []
            except (json.JSONDecodeError, OSError):
                backup = self._path.with_suffix(".json.bak")
                if self._path.exists():
                    self._path.rename(backup)
                self._sessions = []

    def _save_unlocked(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(
            json.dumps(self._sessions, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    def cleanup_expired(self) -> None:
        with self._lock:
            now = _now()
            self._sessions = [
                session
                for session in self._sessions
                if datetime.fromisoformat(session["expiresAt"].replace("Z", "+00:00")) > now
            ]
            self._save_unlocked()

    def issue(self, user_id: str, device_name: str) -> dict[str, Any]:
        with self._lock:
            self.cleanup_expired()
            created = _now()
            expires = created + timedelta(days=SESSION_TTL_DAYS)
            session = {
                "token": _new_token(),
                "userId": user_id,
                "deviceName": device_name,
                "createdAt": created.astimezone().isoformat(timespec="seconds"),
                "expiresAt": expires.astimezone().isoformat(timespec="seconds"),
            }
            self._sessions.append(session)
            self._save_unlocked()
            return dict(session)

    def validate(self, token: str) -> dict[str, Any] | None:
        with self._lock:
            now = _now()
            for session in self._sessions:
                if session["token"] != token:
                    continue
                expires = datetime.fromisoformat(session["expiresAt"].replace("Z", "+00:00"))
                if expires <= now:
                    return None
                return dict(session)
            return None

    def revoke_user(self, user_id: str) -> None:
        with self._lock:
            self._sessions = [s for s in self._sessions if s["userId"] != user_id]
            self._save_unlocked()
