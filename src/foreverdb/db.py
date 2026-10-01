"""SQLite schema. The database is a build-time artifact: it holds Blizzard-derived rows and is never committed."""
from __future__ import annotations

import sqlite3
from pathlib import Path

from .provenance import DatasetRecord
from .registry import Registry

SCHEMA_VERSION = 1

DDL = """
CREATE TABLE IF NOT EXISTS build (
  build_id TEXT PRIMARY KEY,
  product TEXT NOT NULL,
  verification TEXT NOT NULL CHECK (verification IN ('unverified','blizzard_current')),
  notes TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS build_evidence (
  id INTEGER PRIMARY KEY,
  build_id TEXT NOT NULL REFERENCES build(build_id),
  kind TEXT NOT NULL, source TEXT NOT NULL, note TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS dataset (
  dataset_id TEXT PRIMARY KEY,
  source_kind TEXT NOT NULL, source_uri TEXT NOT NULL, source_ref TEXT NOT NULL, path_in_source TEXT,
  retrieved_at TEXT NOT NULL, sha256 TEXT, content_id TEXT, size_bytes INTEGER,
  first_hand INTEGER NOT NULL, origin TEXT NOT NULL, mirror_of TEXT,
  license_id TEXT NOT NULL, license_status TEXT NOT NULL,
  redistributable INTEGER CHECK (redistributable IN (0,1)),
  claimed_build_id TEXT, claim_basis TEXT, build_claim_verified INTEGER NOT NULL DEFAULT 0,
  notes TEXT NOT NULL DEFAULT '',
  CHECK (sha256 IS NOT NULL OR content_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS quest (quest_id INTEGER PRIMARY KEY);
CREATE TABLE IF NOT EXISTS quest_client_row (
  quest_id INTEGER NOT NULL REFERENCES quest(quest_id),
  dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  claimed_build_id TEXT,
  unique_bit_flag INTEGER, ui_quest_details_theme_id INTEGER,
  PRIMARY KEY (quest_id, dataset_id)
);
CREATE TABLE IF NOT EXISTS evidence_scope (      -- "a source of this kind was loaded" (distinguishes 0 from NULL)
  evidence_kind TEXT NOT NULL CHECK (evidence_kind IN ('client_id_observed','era_baseline','att_observed','server_confirmed')),
  dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  PRIMARY KEY (evidence_kind, dataset_id)
);
CREATE TABLE IF NOT EXISTS quest_evidence (
  quest_id INTEGER NOT NULL REFERENCES quest(quest_id),
  evidence_kind TEXT NOT NULL CHECK (evidence_kind IN ('client_id_observed','era_baseline','att_observed','server_confirmed')),
  dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  locator TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (quest_id, evidence_kind, dataset_id, locator)
);
CREATE VIEW IF NOT EXISTS v_quest_shell AS
SELECT q.quest_id,
  CASE WHEN EXISTS (SELECT 1 FROM quest_evidence e WHERE e.quest_id=q.quest_id AND e.evidence_kind='client_id_observed') THEN 1
       WHEN EXISTS (SELECT 1 FROM evidence_scope s WHERE s.evidence_kind='client_id_observed') THEN 0 END AS client_id_observed,
  CASE WHEN EXISTS (SELECT 1 FROM quest_evidence e WHERE e.quest_id=q.quest_id AND e.evidence_kind='era_baseline') THEN 1
       WHEN EXISTS (SELECT 1 FROM evidence_scope s WHERE s.evidence_kind='era_baseline') THEN 0 END AS era_baseline,
  CASE WHEN EXISTS (SELECT 1 FROM quest_evidence e WHERE e.quest_id=q.quest_id AND e.evidence_kind='att_observed') THEN 1
       WHEN EXISTS (SELECT 1 FROM evidence_scope s WHERE s.evidence_kind='att_observed') THEN 0 END AS att_observed,
  CASE WHEN EXISTS (SELECT 1 FROM quest_evidence e WHERE e.quest_id=q.quest_id AND e.evidence_kind='server_confirmed') THEN 1
       WHEN EXISTS (SELECT 1 FROM evidence_scope s WHERE s.evidence_kind='server_confirmed') THEN 0 END AS server_confirmed
FROM quest q;

CREATE TABLE IF NOT EXISTS assertion (
  assertion_id INTEGER PRIMARY KEY,
  entity_type TEXT NOT NULL, entity_id INTEGER NOT NULL, field TEXT NOT NULL,
  value_json TEXT NOT NULL, value_hash TEXT NOT NULL,
  source_kind TEXT NOT NULL CHECK (source_kind IN ('client_table','harvest_observation','third_party_import','inferred')),
  source_dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  source_locator TEXT NOT NULL DEFAULT '',
  observed_build_id TEXT, claimed_build_id TEXT, claim_basis TEXT,
  method TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK (status IN ('observed','imported_unverified','verified','disputed','superseded','rejected')),
  confidence TEXT NOT NULL CHECK (confidence IN ('client_authoritative','observed_first_hand','third_party_unverified','inferred')),
  supersedes_id INTEGER REFERENCES assertion(assertion_id),
  created_at TEXT NOT NULL,
  UNIQUE (entity_type, entity_id, field, value_hash, source_dataset_id, source_locator)
);
CREATE INDEX IF NOT EXISTS ix_assertion_entity ON assertion (entity_type, entity_id, field);
CREATE TABLE IF NOT EXISTS assertion_status_log (
  id INTEGER PRIMARY KEY, assertion_id INTEGER NOT NULL REFERENCES assertion(assertion_id),
  old_status TEXT NOT NULL, new_status TEXT NOT NULL, changed_at TEXT NOT NULL, reason TEXT NOT NULL
);

-- immutable client-derived structure needed by the coordinate transform
CREATE TABLE IF NOT EXISTS client_taxi_node (
  node_id INTEGER NOT NULL, dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  name TEXT, continent_id INTEGER, world_x REAL, world_y REAL, world_z REAL,
  PRIMARY KEY (node_id, dataset_id)
);
CREATE TABLE IF NOT EXISTS client_ui_map_assignment (
  assignment_id INTEGER NOT NULL, dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  ui_map_id INTEGER NOT NULL, map_id INTEGER, area_id INTEGER, order_index INTEGER,
  ui_min_x REAL, ui_min_y REAL, ui_max_x REAL, ui_max_y REAL,
  region_min_x REAL, region_min_y REAL, region_min_z REAL, region_max_x REAL, region_max_y REAL, region_max_z REAL,
  PRIMARY KEY (assignment_id, dataset_id)
);
CREATE TABLE IF NOT EXISTS client_ui_map (
  ui_map_id INTEGER NOT NULL, dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  name TEXT, parent_ui_map_id INTEGER,
  PRIMARY KEY (ui_map_id, dataset_id)
);
-- rebuildable; never authoritative; original observation stays in `assertion`
CREATE TABLE IF NOT EXISTS derived_coordinate (
  assertion_id INTEGER NOT NULL REFERENCES assertion(assertion_id),
  transform_id TEXT NOT NULL,
  transform_dataset_id TEXT NOT NULL REFERENCES dataset(dataset_id),
  ui_map_id INTEGER, map_id INTEGER, world_x REAL, world_y REAL,
  status TEXT NOT NULL CHECK (status IN ('ok','no_assignment','unsupported_assignment','out_of_bounds')),
  PRIMARY KEY (assertion_id, transform_id)
);
"""


def connect(path: Path | str) -> sqlite3.Connection:
    if str(path) != ":memory:":
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(DDL)
    conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    conn.commit()


def insert_registry(conn: sqlite3.Connection, reg: Registry) -> None:
    for b in reg.builds:
        conn.execute(
            "INSERT INTO build(build_id, product, verification, notes) VALUES (?,?,?,?) "
            "ON CONFLICT(build_id) DO UPDATE SET verification=excluded.verification, notes=excluded.notes",
            (b.id, reg.product, b.verification, b.notes),
        )
        conn.execute("DELETE FROM build_evidence WHERE build_id=?", (b.id,))
        for e in b.evidence:
            conn.execute("INSERT INTO build_evidence(build_id, kind, source, note) VALUES (?,?,?,?)",
                         (b.id, e.kind, e.source, e.note))
    conn.commit()


def insert_dataset(conn: sqlite3.Connection, rec: DatasetRecord) -> str:
    conn.execute(
        """INSERT OR IGNORE INTO dataset(dataset_id, source_kind, source_uri, source_ref, path_in_source, retrieved_at,
             sha256, content_id, size_bytes, first_hand, origin, mirror_of, license_id, license_status, redistributable,
             claimed_build_id, claim_basis, build_claim_verified, notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (rec.dataset_id, rec.source_kind, rec.source_uri, rec.source_ref, rec.path_in_source, rec.retrieved_at,
         rec.sha256, rec.content_id, rec.size_bytes, int(rec.first_hand), rec.origin, rec.mirror_of, rec.license_id,
         rec.license_status, None if rec.redistributable is None else int(rec.redistributable),
         rec.claimed_build_id, rec.claim_basis, int(rec.build_claim_verified), rec.notes),
    )
    conn.commit()
    return rec.dataset_id
