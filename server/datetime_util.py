"""ISO 8601 datetime parsing and comparison."""

from __future__ import annotations

from datetime import datetime, timezone


def parse_iso8601(value: str) -> datetime:
    """Parse ISO 8601 string to timezone-aware datetime."""
    normalized = value.replace("Z", "+00:00")
    dt = datetime.fromisoformat(normalized)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def compare_modification_dates(left: str, right: str) -> int:
    """Return -1, 0, or 1 comparing two ISO 8601 datetimes."""
    left_dt = parse_iso8601(left)
    right_dt = parse_iso8601(right)
    if left_dt < right_dt:
        return -1
    if left_dt > right_dt:
        return 1
    return 0
