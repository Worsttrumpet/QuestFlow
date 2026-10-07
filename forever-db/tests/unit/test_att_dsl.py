from foreverdb.att.dsl import Ident, Opaque, Table, parse_source, walk_calls

SRC = '''-- header comment
maproot(MAP.X, {
  --[[ block
  comment ]]
  groups = {
    n(QUESTS, {
      q(783, {  -- A Threat Within [Elwynn Forest]
        qg = 823,
        coord = { 48.1, 42.9, MAP.ELWYNN_FOREST },
        races = ALLIANCE_ONLY,
        isBreadcrumb = true,
        groups = {
          objective(1, {  -- 0/1 Thing
            provider = { "i", 182 },
            cr = 103,
          }),
          i(6076),  -- Tapered Pants
        },
      }),
      q(92461, {
        ["qg"] = 251361,
        ["coords"] = { { 42.1, 23.5, MAP.ZEPHRAS_ISLE }, { 1, 2, 3 } },
        ["sourceQuests"] = { 92460 },
        lvl = -1, x = nil, y = 1 + 2,
      }),
    }),
  },
});
'''


def _calls():
    r = parse_source(SRC)
    return r, {c.line: c for c in walk_calls(r.calls)}


def test_finds_all_calls_with_line_numbers_and_name_comments():
    r, calls = _calls()
    assert r.errors == []
    q = [c for c in walk_calls(r.calls) if c.name == "q"]
    assert [(c.args[0], c.line, c.comment) for c in q] == [(783, 7, "A Threat Within [Elwynn Forest]"), (92461, 20, None)]
    assert {c.name for c in walk_calls(r.calls)} >= {"maproot", "n", "q", "objective", "i"}


def test_field_syntaxes_are_normalisable():
    r, _ = _calls()
    q1, q2 = [c for c in walk_calls(r.calls) if c.name == "q"]
    body1, body2 = q1.args[1], q2.args[1]
    assert isinstance(body1, Table) and body1.kv["qg"] == 823 and body1.kv["isBreadcrumb"] is True
    assert body1.kv["coord"].pos[:2] == [48.1, 42.9] and body1.kv["coord"].pos[2] == Ident("MAP.ELWYNN_FOREST")
    assert body2.kv["qg"] == 251361                              # bracket-string key syntax
    assert len(body2.kv["coords"].pos) == 2                       # plural, table of tables
    assert body2.kv["sourceQuests"].pos == [92460]
    assert body2.kv["lvl"] == -1 and body2.kv["x"] is None
    assert isinstance(body2.kv["y"], Opaque)                      # binary expression kept opaque, not dropped


def test_unrecognised_characters_are_reported_but_parsing_continues():
    r = parse_source("q(1, { qg = 2 })\n$$\nq(3, { qg = 4 })")
    assert [c.args[0] for c in r.calls] == [1, 3] and any("unrecognised" in e for e in r.errors)


def test_truncated_input_does_not_hang_or_raise():
    for s in ("q(1, {", "q(1, { coord = { 1,", "((((", "{{{{", "q("):
        parse_source(s)


def test_string_escapes_and_hex():
    r = parse_source(r'x("a\"b", 0x10)')
    assert r.calls[0].args == ['a"b', 16]


def test_long_strings_are_values_not_syntax_errors():
    r = parse_source('q(1, { icon = [[~_.asset("X")]], qg = 2, note = [==[a]]b]==], lvl = 3 })')
    body = r.calls[0].args[1]
    assert r.errors == [] and body.kv["icon"] == '~_.asset("X")' and body.kv["note"] == "a]]b" and body.kv["qg"] == 2 and body.kv["lvl"] == 3
