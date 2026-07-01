"""SQLite metadata for assets and uploads."""

from __future__ import annotations

import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class MetadataDB:
    def __init__(self, path: Path, lock: threading.RLock):
        self._path = path
        self._lock = lock
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self) -> None:
        with self._lock:
            with self._connect() as conn:
                conn.execute("PRAGMA journal_mode=WAL")
                conn.executescript(
                    """
                    CREATE TABLE IF NOT EXISTS assets (
                        user_id TEXT NOT NULL,
                        local_identifier TEXT NOT NULL,
                        current_version INTEGER NOT NULL,
                        current_modification_date TEXT NOT NULL,
                        creation_date TEXT NOT NULL,
                        original_filename TEXT,
                        updated_at TEXT NOT NULL,
                        PRIMARY KEY (user_id, local_identifier)
                    );

                    CREATE TABLE IF NOT EXISTS uploads (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id TEXT NOT NULL,
                        local_identifier TEXT NOT NULL,
                        version INTEGER NOT NULL,
                        part TEXT NOT NULL,
                        modification_date TEXT NOT NULL,
                        file_path TEXT NOT NULL,
                        file_size INTEGER NOT NULL,
                        content_hash TEXT,
                        uploaded_at TEXT NOT NULL,
                        UNIQUE (user_id, local_identifier, version, part)
                    );
                    """
                )
                conn.commit()

    def get_asset(self, user_id: str, local_identifier: str) -> dict[str, Any] | None:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT user_id, local_identifier, current_version,
                           current_modification_date, creation_date,
                           original_filename, updated_at
                    FROM assets
                    WHERE user_id = ? AND local_identifier = ?
                    """,
                    (user_id, local_identifier),
                ).fetchone()
                return dict(row) if row else None

    def upsert_asset(
        self,
        user_id: str,
        local_identifier: str,
        version: int,
        modification_date: str,
        creation_date: str,
        original_filename: str | None,
    ) -> None:
        now = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO assets (
                        user_id, local_identifier, current_version,
                        current_modification_date, creation_date,
                        original_filename, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(user_id, local_identifier) DO UPDATE SET
                        current_version = excluded.current_version,
                        current_modification_date = excluded.current_modification_date,
                        creation_date = excluded.creation_date,
                        original_filename = excluded.original_filename,
                        updated_at = excluded.updated_at
                    """,
                    (
                        user_id,
                        local_identifier,
                        version,
                        modification_date,
                        creation_date,
                        original_filename,
                        now,
                    ),
                )
                conn.commit()

    def upsert_upload(
        self,
        user_id: str,
        local_identifier: str,
        version: int,
        part: str,
        modification_date: str,
        file_path: str,
        file_size: int,
    ) -> None:
        now = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO uploads (
                        user_id, local_identifier, version, part,
                        modification_date, file_path, file_size, uploaded_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(user_id, local_identifier, version, part) DO UPDATE SET
                        modification_date = excluded.modification_date,
                        file_path = excluded.file_path,
                        file_size = excluded.file_size,
                        uploaded_at = excluded.uploaded_at
                    """,
                    (
                        user_id,
                        local_identifier,
                        version,
                        part,
                        modification_date,
                        file_path,
                        file_size,
                        now,
                    ),
                )
                conn.commit()

    def count_assets(self, user_id: str) -> int:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT COUNT(*) AS c FROM assets WHERE user_id = ?",
                    (user_id,),
                ).fetchone()
                return int(row["c"]) if row else 0

    def last_upload_at(self, user_id: str) -> str | None:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT uploaded_at FROM uploads
                    WHERE user_id = ?
                    ORDER BY uploaded_at DESC
                    LIMIT 1
                    """,
                    (user_id,),
                ).fetchone()
                return row["uploaded_at"] if row else None

    def recent_uploads(self, limit: int = 50) -> list[dict[str, Any]]:
        limit = max(1, min(limit, 200))
        with self._lock:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT user_id, local_identifier, version, part,
                           file_path, file_size, uploaded_at
                    FROM uploads
                    ORDER BY uploaded_at DESC
                    LIMIT ?
                    """,
                    (limit,),
                ).fetchall()
                return [dict(row) for row in rows]
