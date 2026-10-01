#!/usr/bin/env python3
"""
M2 independent verification of a raw WDC5 .db2 file's container header.

Pure standard library (hashlib, struct, json) — nothing to install, runs on
Windows/macOS/Linux with any Python 3.7+.

This does NOT decode row data (that needs the full per-build DBD field layout
and is what the extraction tool does). It only reads the self-describing
container header: magic, schema string, record/field counts, table hash,
layout hash, and per-section metadata (record counts, encryption flag).

Byte offsets [V]: read directly from wowsims/mop tools/db2tool/wdc/wdc5.go
(MIT license), commit adbbb9824059712ed299bc89ec1b3b08c1f28a97 (2026-09-21),
function `read()`. This is
an independent Python re-implementation of the same header layout, written
without reusing any of that file's code, so a match between this script's
output and db2tool's own behavior is a real cross-check, not the same bug
twice.

Usage:
    python verify_db2_header.py <path to a raw .db2 file>
"""
import hashlib
import json
import struct
import sys

HEADER_FIXED_SIZE = 204   # bytes before the per-section headers begin
SECTION_HEADER_SIZE = 40  # 8-byte TactKeyLookup + 8 x int32
EXPECTED_QUESTV2_LAYOUT_HASH = "1854BDB9"  # from WoWDBDefs QuestV2.dbd at the
# pinned commit 02b1fa9a4714 -- our own cross-check, not something db2tool
# itself verifies (db2tool selects a DBD version by build number, not by
# layout hash; see NOTES below).


def parse_wdc5(path: str) -> dict:
    with open(path, "rb") as fh:
        data = fh.read()

    if len(data) < HEADER_FIXED_SIZE:
        raise ValueError(
            f"file is only {len(data)} bytes, shorter than the fixed "
            f"{HEADER_FIXED_SIZE}-byte WDC5 header -- this is not a valid DB2 file"
        )

    magic = data[0:4]
    if magic != b"WDC5":
        raise ValueError(
            f"magic is {magic!r}, not b'WDC5'. This script only understands "
            "WDC5 (the format wowdev.wiki and db2tool document for this game "
            "version). A different magic means either a different DB2 "
            "version or that this file was not read correctly -- do not "
            "guess further, report the magic value."
        )

    schema_version, = struct.unpack_from("<I", data, 4)
    schema_string = data[8:136].split(b"\x00", 1)[0].decode("ascii", "replace")

    (record_count, field_count, record_size, string_table_size,
     table_hash, layout_hash, min_id, max_id, locale) = struct.unpack_from("<9i", data, 136)

    flags, id_field_index = struct.unpack_from("<2H", data, 172)

    (total_field_count, packed_data_offset, lookup_column_count,
     column_meta_data_size, common_data_size, pallet_data_size,
     sections_count) = struct.unpack_from("<7i", data, 176)

    pos = HEADER_FIXED_SIZE
    sections = []
    for i in range(sections_count):
        if pos + SECTION_HEADER_SIZE > len(data):
            raise ValueError(
                f"file is truncated inside section header {i} of {sections_count} "
                f"declared -- the file may not have been fully written/copied"
            )
        tact_key_lookup, = struct.unpack_from("<Q", data, pos)
        (file_offset, num_records, sect_string_table_size,
         offset_records_end_offset, index_data_size, parent_lookup_data_size,
         offset_map_id_count, copy_table_count) = struct.unpack_from("<8i", data, pos + 8)
        sections.append({
            "index": i,
            "tact_key_lookup": tact_key_lookup,
            "encrypted": tact_key_lookup != 0,
            "num_records": num_records,
            "file_offset": file_offset,
        })
        pos += SECTION_HEADER_SIZE

    layout_hash_hex = f"{layout_hash & 0xFFFFFFFF:08X}"

    return {
        "path": path,
        "size_bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "magic": magic.decode("ascii"),
        "schema_version": schema_version,
        "schema_string": schema_string,
        "header_record_count": record_count,
        "field_count": field_count,
        "record_size": record_size,
        "string_table_size": string_table_size,
        "table_hash": f"{table_hash & 0xFFFFFFFF:08X}",
        "layout_hash": layout_hash_hex,
        "layout_hash_matches_questv2_definition": layout_hash_hex == EXPECTED_QUESTV2_LAYOUT_HASH,
        "min_id": min_id,
        "max_id": max_id,
        "id_field_index": id_field_index,
        "sections_count": sections_count,
        "sections_total_records": sum(s["num_records"] for s in sections),
        "encrypted_sections": sum(1 for s in sections if s["encrypted"]),
        "sections": sections,
        "evidence_note": (
            "[V] this script parsed these bytes itself. header_record_count vs "
            "Blizzard's intent is [2nd] at best (we have no independent oracle "
            "for 'correct' row count). layout_hash_matches_questv2_definition "
            "is only meaningful if this file is actually QuestV2 -- it is a "
            "consistency check we added, not something the extractor itself checks."
        ),
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: python verify_db2_header.py <path to a raw .db2 file>", file=sys.stderr)
        raise SystemExit(1)
    try:
        result = parse_wdc5(sys.argv[1])
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}, indent=2))
        raise SystemExit(1)
    print(json.dumps(result, indent=2))
