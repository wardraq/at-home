"""Shared application context."""

from __future__ import annotations

import threading
import time
from pathlib import Path

from server.config import ConfigStore
from server.metadata import MetadataDB
from server.netutil import get_lan_ip
from server.sessions import SessionStore


class AppContext:
    def __init__(self, data_dir: Path, storage_path: Path | None = None):
        self.lock = threading.RLock()
        self.data_dir = data_dir
        self.started_at = time.time()
        self.lan_ip = get_lan_ip()
        self.config = ConfigStore(data_dir / "config.json", self.lock, storage_path)
        self.sessions = SessionStore(data_dir / "sessions.json", self.lock)
        self.metadata = MetadataDB(data_dir / "metadata.db", self.lock)
        self.sessions.cleanup_expired()

    def api_addr(self) -> str:
        return f"{self.lan_ip}:{self.config.api_port}"

    def uptime_seconds(self) -> int:
        return int(time.time() - self.started_at)

    def qr_payload(self, user_id: str) -> dict[str, str]:
        return {
            "serverId": self.config.server_id,
            "userId": user_id,
            "addr": self.api_addr(),
        }
