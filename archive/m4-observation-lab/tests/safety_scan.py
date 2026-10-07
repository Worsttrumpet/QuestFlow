#!/usr/bin/env python3
"""
Static safety scanner for the M4 Observation Lab.

Detects executable references to forbidden committing functions
(GetQuestReward, AcceptQuest, CompleteQuest, TurnInQuest) by properly
tokenizing the Lua source -- stripping comments and string literals first,
then searching only the remaining executable-code tokens. This is
deliberately not a plain grep: a plain grep can't tell "-- never calls
GetQuestReward()" (a comment, allowed) from an actual call (forbidden),
and would either produce false positives (blocking legitimate
documentation) or, if written carelessly to avoid that, false negatives
(missing a real call disguised inside a string).

Exit code 0 = clean. Exit code 1 = a forbidden reference was found, or a
different safety check failed. This is meant to be run as a hard gate, not
advisory output -- per the requirement that the test "fail rather than
merely warn."
"""
import re
import sys
from pathlib import Path

FORBIDDEN = ["GetQuestReward", "AcceptQuest", "CompleteQuest", "TurnInQuest"]


def strip_to_executable_code(text: str) -> str:
    """Return only the executable-code portions of a Lua source file,
    with comments and string literals replaced by blank space of the same
    length (so line/column numbers of anything found afterward still line
    up with the original file for a useful error message)."""
    out = []
    pos = 0
    n = len(text)
    while pos < n:
        # long comment --[[ ... ]] / --[=[ ... ]=]
        m = re.match(r"--\[(=*)\[", text[pos:])
        if m:
            eq = m.group(1)
            end = text.find(f"]{eq}]", pos + m.end())
            end = (end + len(eq) + 2) if end != -1 else n
            out.append(" " * (end - pos))
            pos = end
            continue
        # line comment
        if text[pos:pos + 2] == "--":
            end = text.find("\n", pos)
            end = end if end != -1 else n
            out.append(" " * (end - pos))
            pos = end
            continue
        # long string [[ ... ]] / [=[ ... ]=]
        m = re.match(r"\[(=*)\[", text[pos:])
        if m:
            eq = m.group(1)
            end = text.find(f"]{eq}]", pos + m.end())
            end = (end + len(eq) + 2) if end != -1 else n
            out.append(" " * (end - pos))
            pos = end
            continue
        # short string "..." or '...'
        if text[pos] in ("'", '"'):
            quote = text[pos]
            i = pos + 1
            while i < n and text[i] != quote:
                if text[i] == "\\":
                    i += 1
                i += 1
            end = min(i + 1, n)
            out.append(" " * (end - pos))
            pos = end
            continue
        # ordinary code character
        out.append(text[pos])
        pos += 1
    return "".join(out)


def scan_file(path: Path):
    text = path.read_text(encoding="utf-8")
    code_only = strip_to_executable_code(text)
    findings = []
    for name in FORBIDDEN:
        for m in re.finditer(r"\b" + re.escape(name) + r"\b", code_only):
            line_no = code_only.count("\n", 0, m.start()) + 1
            line_text = text.splitlines()[line_no - 1].strip()
            findings.append((path, line_no, name, line_text))
    return findings


def check_no_raw_guid_pattern(path: Path):
    """Heuristic: a call to UnitGUID whose result is stored into a table
    field or returned directly (not immediately fed into a parser) is a
    smell. This can't be perfectly certain statically, so it is reported
    as a warning-level note, not a hard failure -- the authoritative check
    is the runtime test (run_lab_tests.lua) that scans actual exported
    data for the literal GUID string."""
    text = path.read_text(encoding="utf-8")
    code_only = strip_to_executable_code(text)
    # Flag only the suspicious pattern: assigning UnitGUID's result to a
    # table field or a var without immediately parsing it, e.g. "rec.guid ="
    hits = re.findall(r"\.\s*guid\s*=\s*[a-zA-Z_][a-zA-Z0-9_]*\s*(?!\))", code_only)
    return len(hits)


def check_no_network_calls(paths):
    """Look for common WoW networking/comm primitives that would indicate
    automatic transmission. Not exhaustive, but covers the well-known
    surface (chat-channel comms is exactly the anti-pattern flagged in the
    M4 research against QuestieLearnerComms)."""
    NET_APIS = ["SendChatMessage", "SendAddonMessage", "JoinChannel", "C_ChatInfo"]
    findings = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        code_only = strip_to_executable_code(text)
        for api in NET_APIS:
            if re.search(r"\b" + re.escape(api) + r"\b", code_only):
                findings.append((path, api))
    return findings


def main():
    if len(sys.argv) < 2:
        print("usage: safety_scan.py <addon_root_dir>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    lua_files = sorted(root.rglob("*.lua"))
    if not lua_files:
        print(f"ERROR: no .lua files found under {root}", file=sys.stderr)
        return 1

    print(f"Scanning {len(lua_files)} Lua files under {root} ...")
    all_findings = []
    for f in lua_files:
        all_findings.extend(scan_file(f))

    ok = True
    if all_findings:
        ok = False
        print("FAIL: forbidden committing-function references found in executable code:")
        for path, line_no, name, line_text in all_findings:
            print(f"  {path}:{line_no}: {name}  -->  {line_text}")
    else:
        print(f"PASS: zero executable references to {FORBIDDEN} in any file "
              f"(comments/strings excluded from the scan by design)")

    net_findings = check_no_network_calls(lua_files)
    if net_findings:
        ok = False
        print("FAIL: networking/comms API references found:")
        for path, api in net_findings:
            print(f"  {path}: {api}")
    else:
        print("PASS: zero networking/comms API references found")

    guid_note_total = 0
    for f in lua_files:
        n = check_no_raw_guid_pattern(f)
        guid_note_total += n
        if n:
            print(f"NOTE (non-fatal heuristic): {f} has {n} pattern(s) matching '.guid = <var>' -- manually verify")
    if guid_note_total == 0:
        print("PASS: heuristic raw-GUID-field-assignment pattern not found in any file "
              "(authoritative check is the runtime data scan in run_lab_tests.lua)")

    print()
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
