// M2 independent verification of a raw WDC5 .db2 file's container header.
//
// This is a from-scratch reimplementation, written without copying db2tool's
// own wdc/wdc5.go, so agreement between this program's output and db2tool's
// behavior is a real independent cross-check, not the same code running twice.
// It reads only the self-describing container header -- no row decoding,
// no DBD definition needed, no dependencies beyond the Go standard library.
//
// Usage (run from the wowsims/mop repo root):
//
//	go run ./tools/db2tool/m2verify <path to a raw .db2 file>
package main

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"os"
)

const (
	headerFixedSize   = 204 // bytes before per-section headers begin
	sectionHeaderSize = 40  // 8-byte TactKeyLookup + 8 x int32
	// Expected for QuestV2 at builds 1.60.1.69876/69893/69913, per WoWDBDefs
	// commit 02b1fa9a4714 -- our own cross-check, not something db2tool
	// itself verifies (it selects a DBD version by build number instead).
	expectedQuestV2LayoutHash = "1854BDB9"
)

type section struct {
	Index         int    `json:"index"`
	TactKeyLookup uint64 `json:"tact_key_lookup"`
	Encrypted     bool   `json:"encrypted"`
	NumRecords    int32  `json:"num_records"`
	FileOffset    int32  `json:"file_offset"`
}

type result struct {
	Path                                 string    `json:"path"`
	SizeBytes                            int       `json:"size_bytes"`
	SHA256                               string    `json:"sha256"`
	Magic                                string    `json:"magic"`
	SchemaVersion                        uint32    `json:"schema_version"`
	SchemaString                         string    `json:"schema_string"`
	HeaderRecordCount                    int32     `json:"header_record_count"`
	FieldCount                           int32     `json:"field_count"`
	RecordSize                           int32     `json:"record_size"`
	StringTableSize                      int32     `json:"string_table_size"`
	TableHash                            string    `json:"table_hash"`
	LayoutHash                           string    `json:"layout_hash"`
	LayoutHashMatchesQuestV2Definition   bool      `json:"layout_hash_matches_questv2_definition"`
	MinID                                int32     `json:"min_id"`
	MaxID                                int32     `json:"max_id"`
	IDFieldIndex                         uint16    `json:"id_field_index"`
	SectionsCount                        int32     `json:"sections_count"`
	SectionsTotalRecords                 int64     `json:"sections_total_records"`
	EncryptedSections                    int       `json:"encrypted_sections"`
	Sections                             []section `json:"sections"`
	EvidenceNote                         string    `json:"evidence_note"`
}

func parseWDC5(path string) (*result, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(data) < headerFixedSize {
		return nil, fmt.Errorf("file is only %d bytes, shorter than the fixed %d-byte WDC5 header -- not a valid DB2 file", len(data), headerFixedSize)
	}
	magic := string(data[0:4])
	if magic != "WDC5" {
		return nil, fmt.Errorf("magic is %q, not \"WDC5\" -- this program only understands WDC5; do not guess further, report the magic value", magic)
	}

	le := binary.LittleEndian
	schemaVersion := le.Uint32(data[4:8])
	schemaStringRaw := data[8:136]
	nul := 0
	for nul < len(schemaStringRaw) && schemaStringRaw[nul] != 0 {
		nul++
	}
	schemaString := string(schemaStringRaw[:nul])

	i32 := func(off int) int32 { return int32(le.Uint32(data[off : off+4])) }

	recordCount := i32(136)
	fieldCount := i32(140)
	recordSize := i32(144)
	stringTableSize := i32(148)
	tableHash := le.Uint32(data[152:156])
	layoutHash := le.Uint32(data[156:160])
	minID := i32(160)
	maxID := i32(164)
	// locale at 168, unused here

	idFieldIndex := le.Uint16(data[174:176])

	sectionsCount := i32(200) // offset 176 + 6*4 = 200: 7th int32 of the tail block (index 6)

	pos := headerFixedSize
	var sections []section
	var totalRecords int64
	encrypted := 0
	for i := 0; i < int(sectionsCount); i++ {
		if pos+sectionHeaderSize > len(data) {
			return nil, fmt.Errorf("file is truncated inside section header %d of %d declared -- it may not have been fully written/copied", i, sectionsCount)
		}
		tactKeyLookup := le.Uint64(data[pos : pos+8])
		numRecords := i32(pos + 12) // FileOffset at pos+8, NumRecords at pos+12
		fileOffset := i32(pos + 8)
		sec := section{
			Index:         i,
			TactKeyLookup: tactKeyLookup,
			Encrypted:     tactKeyLookup != 0,
			NumRecords:    numRecords,
			FileOffset:    fileOffset,
		}
		if sec.Encrypted {
			encrypted++
		}
		totalRecords += int64(numRecords)
		sections = append(sections, sec)
		pos += sectionHeaderSize
	}

	layoutHashHex := fmt.Sprintf("%08X", layoutHash)
	sum := sha256.Sum256(data)

	return &result{
		Path: path, SizeBytes: len(data), SHA256: fmt.Sprintf("%x", sum),
		Magic: magic, SchemaVersion: schemaVersion, SchemaString: schemaString,
		HeaderRecordCount: recordCount, FieldCount: fieldCount, RecordSize: recordSize,
		StringTableSize: stringTableSize,
		TableHash:       fmt.Sprintf("%08X", tableHash),
		LayoutHash:      layoutHashHex,
		LayoutHashMatchesQuestV2Definition: layoutHashHex == expectedQuestV2LayoutHash,
		MinID: minID, MaxID: maxID, IDFieldIndex: idFieldIndex,
		SectionsCount: sectionsCount, SectionsTotalRecords: totalRecords,
		EncryptedSections: encrypted, Sections: sections,
		EvidenceNote: "[V] this program parsed these bytes itself, independently of db2tool's own wdc5.go. " +
			"header_record_count vs Blizzard's intent is [2nd] at best. layout_hash_matches_questv2_definition " +
			"is only meaningful if this file is actually QuestV2 -- it is our own added consistency check.",
	}, nil
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: go run ./tools/db2tool/m2verify <path to a raw .db2 file>")
		os.Exit(1)
	}
	r, err := parseWDC5(os.Args[1])
	if err != nil {
		out, _ := json.MarshalIndent(map[string]string{"error": err.Error()}, "", "  ")
		fmt.Println(string(out))
		os.Exit(1)
	}
	out, _ := json.MarshalIndent(r, "", "  ")
	fmt.Println(string(out))
}
