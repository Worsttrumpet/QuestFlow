"""Evidence ranking. Which assertion 'wins' is policy, kept in code and tested; nothing is deleted."""
from __future__ import annotations

SOURCE_KINDS = ("client_table", "harvest_observation", "third_party_import", "inferred")
STATUSES = ("observed", "imported_unverified", "verified", "disputed", "superseded", "rejected")
CONFIDENCES = ("client_authoritative", "observed_first_hand", "third_party_unverified", "inferred")

SOURCE_RANK = {"client_table": 400, "harvest_observation": 300, "third_party_import": 200, "inferred": 100}
CONFIDENCE_RANK = {"client_authoritative": 4, "observed_first_hand": 3, "third_party_unverified": 2, "inferred": 1}
STATUS_ADJUST = {"observed": 0, "imported_unverified": 0, "verified": 50, "disputed": -50}
EXCLUDED_STATUSES = frozenset({"superseded", "rejected"})


def rank(source_kind: str, confidence: str, status: str) -> int | None:
    """Higher wins. None = excluded from resolution (kept in history)."""
    if status in EXCLUDED_STATUSES:
        return None
    return SOURCE_RANK[source_kind] + CONFIDENCE_RANK[confidence] * 10 + STATUS_ADJUST[status]
