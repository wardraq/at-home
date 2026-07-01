"""Server-side version assignment."""

from __future__ import annotations

from dataclasses import dataclass

from server.datetime_util import compare_modification_dates
from server.metadata import MetadataDB


@dataclass(frozen=True)
class VersionDecision:
    version: int
    regression: bool = False


def decide_version(
    metadata: MetadataDB,
    user_id: str,
    local_identifier: str,
    modification_date: str,
) -> VersionDecision:
    asset = metadata.get_asset(user_id, local_identifier)
    if asset is None:
        return VersionDecision(version=1)

    cmp = compare_modification_dates(
        modification_date,
        asset["current_modification_date"],
    )
    if cmp < 0:
        return VersionDecision(version=0, regression=True)
    if cmp == 0:
        return VersionDecision(version=int(asset["current_version"]))
    return VersionDecision(version=int(asset["current_version"]) + 1)
