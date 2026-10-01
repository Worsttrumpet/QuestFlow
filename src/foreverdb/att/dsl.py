"""Tolerant parser for ATT's Lua-based data DSL.

ATT files are Lua source such as ``q(783, { qg = 823, coord = { 48.1, 42.9, MAP.ELWYNN_FOREST } })``.
We do not execute Lua. We parse the subset ATT uses, record line numbers, and collect (never raise on)
anything unexpected so a syntax surprise cannot silently drop data.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Iterator, NamedTuple

_TOKEN = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<bcomment>--\[(?P<eq>=*)\[.*?\](?P=eq)\])
  | (?P<comment>--[^\n]*)
  | (?P<lstr>\[(?P<leq2>=*)\[.*?\](?P=leq2)\])
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<num>-?(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?))
  | (?P<id>[A-Za-z_][A-Za-z_0-9.]*)
  | (?P<p>==|~=|<=|>=|\.\.|[(){}\[\],=;+\-*/#<>~!:.|&^%])
    """,
    re.X | re.S,
)
_BINOPS = {"+", "-", "*", "/", "..", "|", "&"}


class Token(NamedTuple):
    kind: str
    text: str
    line: int


@dataclass(frozen=True)
class Ident:
    name: str


@dataclass(frozen=True)
class Opaque:
    text: str


@dataclass
class Table:
    pos: list[Any]
    kv: dict[str, Any]
    line: int
    comment: str | None = None


@dataclass
class Call:
    name: str
    args: list[Any]
    line: int
    comment: str | None = None   # comment on the same line right after the first `{`, ATT's name convention


@dataclass
class ParseResult:
    calls: list[Call]
    errors: list[str] = field(default_factory=list)


def tokenize(src: str) -> tuple[list[Token], list[str]]:
    toks: list[Token] = []
    errors: list[str] = []
    pos, line, n = 0, 1, len(src)
    while pos < n:
        m = _TOKEN.match(src, pos)
        if not m:
            errors.append(f"line {line}: unrecognised character {src[pos]!r}")
            pos += 1
            continue
        kind = {"eq": "bcomment", "leq2": "str"}.get(m.lastgroup or "", m.lastgroup or "ws")
        kind = "str" if kind == "lstr" else kind
        text = m.group(0)
        if kind != "ws":
            toks.append(Token(kind, text, line))
        line += text.count("\n")
        pos = m.end()
    return toks, errors


def _num(text: str) -> int | float:
    if text.lower().lstrip("-").startswith("0x"):
        return int(text, 16)
    return float(text) if any(c in text for c in ".eE") else int(text)


def _unquote(text: str) -> str:
    if text.startswith("[") and text.endswith("]"):          # Lua long string [[...]] / [=[...]=]
        m = re.match(r"\[(=*)\[(.*)\]\1\]$", text, re.S)
        return m.group(2) if m else text
    body = text[1:-1]
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), body)


class _Parser:
    def __init__(self, toks: list[Token]) -> None:
        self.t = toks
        self.sig = [i for i, tk in enumerate(toks) if tk.kind not in ("comment", "bcomment")]
        self.i = 0
        self.errors: list[str] = []

    def peek(self, k: int = 0) -> Token | None:
        j = self.i + k
        return self.t[self.sig[j]] if j < len(self.sig) else None

    def next(self) -> Token | None:
        tk = self.peek()
        if tk is not None:
            self.i += 1
        return tk

    def _is(self, tk: Token | None, text: str) -> bool:
        return tk is not None and tk.kind == "p" and tk.text == text

    def value(self) -> Any:
        tk = self.peek()
        if tk is None:
            return None
        if self._is(tk, "{"):
            v: Any = self.table()
        elif tk.kind == "num":
            self.next()
            v = _num(tk.text)
        elif tk.kind == "str":
            self.next()
            v = _unquote(tk.text)
        elif tk.kind == "id":
            self.next()
            if tk.text == "nil":
                v = None
            elif tk.text in ("true", "false"):
                v = tk.text == "true"
            elif self._is(self.peek(), "("):
                v = self.call(tk)
            else:
                v = Ident(tk.text)
        else:
            self.errors.append(f"line {tk.line}: unexpected {tk.text!r}")
            self.next()
            return None
        while (nxt := self.peek()) is not None and nxt.kind == "p" and nxt.text in _BINOPS:
            self.next()
            rhs = self.value()
            v = Opaque(f"{v!r} {nxt.text} {rhs!r}")
        return v

    def call(self, name_tok: Token) -> Call:
        self.next()  # (
        args: list[Any] = []
        comment: str | None = None
        while (tk := self.peek()) is not None and not self._is(tk, ")"):
            if self._is(tk, ","):
                self.next()
                continue
            before = self.i
            a = self.value()
            args.append(a)
            if isinstance(a, Table) and comment is None:
                comment = a.comment
            if self.i == before:  # guarantee progress
                self.next()
        self.next()  # )
        return Call(name_tok.text, args, name_tok.line, comment)

    def table(self) -> Table:
        open_tok = self.next()
        assert open_tok is not None
        raw_idx = self.sig[self.i - 1]
        comment = None
        if raw_idx + 1 < len(self.t):
            nxt = self.t[raw_idx + 1]
            if nxt.kind == "comment" and nxt.line == open_tok.line:
                comment = nxt.text[2:].strip()
        tbl = Table([], {}, open_tok.line, comment)
        while (tk := self.peek()) is not None and not self._is(tk, "}"):
            if tk.kind == "p" and tk.text in (",", ";"):
                self.next()
                continue
            before = self.i
            nk = self.peek(1)
            if tk.kind == "id" and self._is(nk, "="):
                self.next(); self.next()
                tbl.kv[tk.text] = self.value()
            elif self._is(tk, "["):
                self.next()
                key = self.value()
                if self._is(self.peek(), "]"):
                    self.next()
                if self._is(self.peek(), "="):
                    self.next()
                tbl.kv[str(key)] = self.value()
            else:
                tbl.pos.append(self.value())
            if self.i == before:
                self.next()
        self.next()  # }
        return tbl


def parse_source(text: str) -> ParseResult:
    toks, errors = tokenize(text)
    p = _Parser(toks)
    calls: list[Call] = []
    while (tk := p.peek()) is not None:
        if tk.kind == "id":
            v = p.value()
            if isinstance(v, Call):
                calls.append(v)
        else:
            p.next()
    return ParseResult(calls, errors + p.errors)


def walk_calls(node: Any) -> Iterator[Call]:
    """Every Call in the tree, depth-first, including calls nested in tables and arguments."""
    if isinstance(node, Call):
        yield node
        for a in node.args:
            yield from walk_calls(a)
    elif isinstance(node, Table):
        for v in node.pos:
            yield from walk_calls(v)
        for v in node.kv.values():
            yield from walk_calls(v)
    elif isinstance(node, list):
        for v in node:
            yield from walk_calls(v)
