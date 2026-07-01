"""Photo file storage helpers."""

from __future__ import annotations

import re
import shutil
from datetime import datetime
from pathlib import Path

from server.datetime_util import parse_iso8601

_INVALID_CHARS = re.compile(r'[\\/:*?"<>|]')


def sanitize_local_identifier(local_identifier: str) -> str:
    sanitized = local_identifier.replace("/", "_")
    return _INVALID_CHARS.sub("_", sanitized)


def infer_extension(original_filename: str | None, mime_type: str | None) -> str:
    if original_filename:
        suffix = Path(original_filename).suffix
        if suffix:
            return suffix.lstrip(".").lower()

    mime_map = {
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/png": "png",
        "image/heic": "heic",
        "image/heif": "heif",
        "video/quicktime": "mov",
        "video/mp4": "mp4",
    }
    if mime_type and mime_type in mime_map:
        return mime_map[mime_type]
    return "bin"


def build_relative_path(
    user_name: str,
    creation_date: str,
    local_identifier: str,
    version: int,
    part: str,
    extension: str,
) -> str:
    created = parse_iso8601(creation_date)
    sanitized = sanitize_local_identifier(local_identifier)
    filename = f"{sanitized}_v{version}_{part}.{extension}"
    return str(Path(user_name) / f"{created.year:04d}" / f"{created.month:02d}" / filename)


def save_upload_file(
    storage_root: Path,
    relative_path: str,
    source_path: Path,
) -> Path:
    target = storage_root / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(source_path), str(target))
    return target
