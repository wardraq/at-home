"""config.json persistence and user management."""

from __future__ import annotations

import json
import secrets
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def _new_server_id() -> str:
    return f"srv-{secrets.token_hex(6).upper()}"


def _new_user_id() -> str:
    return f"usr-{secrets.token_hex(8)}"


class ConfigStore:
    def __init__(self, path: Path, lock: threading.RLock, storage_path: Path | None = None):
        self._path = path
        self._lock = lock
        self._data: dict[str, Any] = {}
        self._load(storage_path)

    def _load(self, storage_path: Path | None) -> None:
        with self._lock:
            if self._path.exists():
                self._data = json.loads(self._path.read_text(encoding="utf-8"))
                return

            default_storage = storage_path or (self._path.parent / "photos")
            self._data = {
                "serverId": _new_server_id(),
                "storagePath": str(default_storage),
                "apiPort": 6060,
                "adminPort": 6061,
                "users": [],
            }
            self._save_unlocked()

    def _save_unlocked(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(
            json.dumps(self._data, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    def save(self) -> None:
        with self._lock:
            self._save_unlocked()

    @property
    def server_id(self) -> str:
        return self._data["serverId"]

    @property
    def storage_path(self) -> Path:
        return Path(self._data["storagePath"])

    @storage_path.setter
    def storage_path(self, value: Path) -> None:
        with self._lock:
            self._data["storagePath"] = str(value)
            self._save_unlocked()

    @property
    def api_port(self) -> int:
        return int(self._data.get("apiPort", 6060))

    @api_port.setter
    def api_port(self, value: int) -> None:
        with self._lock:
            self._data["apiPort"] = value
            self._save_unlocked()

    @property
    def admin_port(self) -> int:
        return int(self._data.get("adminPort", 6061))

    @admin_port.setter
    def admin_port(self, value: int) -> None:
        with self._lock:
            self._data["adminPort"] = value
            self._save_unlocked()

    def list_users(self) -> list[dict[str, Any]]:
        with self._lock:
            return [dict(user) for user in self._data.get("users", [])]

    def get_user(self, user_id: str) -> dict[str, Any] | None:
        with self._lock:
            for user in self._data.get("users", []):
                if user["id"] == user_id:
                    return dict(user)
            return None

    def create_user(self, name: str) -> dict[str, Any]:
        with self._lock:
            for user in self._data.get("users", []):
                if user["name"] == name and user.get("status") == "active":
                    raise ValueError(f"active user with name '{name}' already exists")

            user = {
                "id": _new_user_id(),
                "name": name,
                "status": "active",
                "createdAt": _now_iso(),
            }
            self._data.setdefault("users", []).append(user)
            self._save_unlocked()
            return dict(user)

    def revoke_user(self, user_id: str) -> dict[str, Any] | None:
        with self._lock:
            for user in self._data.get("users", []):
                if user["id"] == user_id:
                    user["status"] = "revoked"
                    self._save_unlocked()
                    return dict(user)
            return None
