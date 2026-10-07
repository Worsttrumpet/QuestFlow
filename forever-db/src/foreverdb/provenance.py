"""Dataset provenance: where bytes came from, when, with what hash and what rights."""
from __future__ import annotations

import hashlib
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SOURCE_KINDS = frozenset({"git", "wago", "user_file"})
ORIGINS = frozenset({"direct", "mirror", "user_supplied"})
LICENSE_STATUSES = frozenset({"verified", "unresolved"})


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while block := fh.read(chunk):
            h.update(block)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class DatasetRecord:
    source_kind: str
    source_uri: str
    source_ref: str                     # commit sha or build id
    path_in_source: str | None
    retrieved_at: str
    sha256: str | None                  # files
    content_id: str | None              # snapshots (git tree id)
    size_bytes: int | None
    first_hand: bool                    # the pipeline read the bytes itself
    origin: str                         # direct | mirror | user_supplied
    mirror_of: str | None
    license_id: str
    license_status: str                 # verified | unresolved
    redistributable: bool | None        # None = unresolved (default)
    claimed_build_id: str | None
    claim_basis: str | None
    build_claim_verified: bool = False
    notes: str = ""

    def __post_init__(self) -> None:
        if self.source_kind not in SOURCE_KINDS:
            raise ValueError(f"bad source_kind {self.source_kind!r}")
        if self.origin not in ORIGINS:
            raise ValueError(f"bad origin {self.origin!r}")
        if self.license_status not in LICENSE_STATUSES:
            raise ValueError(f"bad license_status {self.license_status!r}")
        if not (self.sha256 or self.content_id):
            raise ValueError("a dataset needs a sha256 (file) or content_id (snapshot)")
        if self.origin == "mirror" and not self.mirror_of:
            raise ValueError("mirror datasets must say what they mirror")

    @property
    def dataset_id(self) -> str:
        """Deterministic: re-importing identical bytes never creates a second dataset."""
        ident = (self.sha256 or self.content_id or "")[:12]
        return f"{self.source_kind}:{self.source_ref[:12]}:{self.path_in_source or '.'}:{ident}"

    def may_commit(self) -> bool:
        """Only data whose redistribution is *established* may be committed."""
        return self.redistributable is True

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["dataset_id"] = self.dataset_id
        return d
