"""THROWAWAY M0 verification script: tolerant parser for ATT's Lua DSL.
Purpose: count what quest data ATT's Forever database actually contains.
Not intended as the M1 importer."""
import re, sys, json, os

TOK = re.compile(r'''
    (?P<ws>\s+)
  | (?P<bcomment>--\[(?P<eq>=*)\[.*?\](?P=eq)\])
  | (?P<comment>--[^\n]*)
  | (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')
  | (?P<num>-?\d+\.?\d*(?:[eE][-+]?\d+)?)
  | (?P<id>[A-Za-z_][A-Za-z_0-9.]*)
  | (?P<p>[(){}\[\],=;+\-*/#<>~!:.|&^%])
''', re.X | re.S)


def tokenize(src):
    out = []
    for m in TOK.finditer(src):
        k = m.lastgroup
        if k == 'eq':
            k = 'bcomment'
        if k == 'ws':
            continue
        out.append((k, m.group(0)))
    return out


class P:
    def __init__(self, toks):
        self.t = toks
        self.i = 0

    def peek(self, o=0):
        j = self.i
        n = 0
        while j < len(self.t):
            if self.t[j][0] not in ('comment', 'bcomment'):
                if n == o:
                    return self.t[j]
                n += 1
            j += 1
        return (None, None)

    def next_noncomment(self):
        while self.i < len(self.t) and self.t[self.i][0] in ('comment', 'bcomment'):
            self.i += 1
        tok = self.t[self.i] if self.i < len(self.t) else (None, None)
        self.i += 1
        return tok

    def first_comment_after_brace(self):
        # comment token immediately at current position (before next real token)
        j = self.i
        if j < len(self.t) and self.t[j][0] == 'comment':
            return self.t[j][1][2:].strip()
        return None

    def value(self):
        k, v = self.peek()
        if k is None:
            return None
        if v == '{':
            return self.table()
        if k == 'num':
            self.next_noncomment()
            return float(v) if ('.' in v or 'e' in v.lower()) else int(v)
        if k == 'str':
            self.next_noncomment()
            return v[1:-1]
        if k == 'id':
            self.next_noncomment()
            nk, nv = self.peek()
            if nv == '(':
                self.next_noncomment()
                args = []
                cmt = None
                while True:
                    k2, v2 = self.peek()
                    if v2 == ')' or k2 is None:
                        self.next_noncomment()
                        break
                    if v2 == ',':
                        self.next_noncomment()
                        continue
                    if v2 == '{' and cmt is None:
                        # capture comment right after the opening brace
                        save = self.i
                        # advance to the brace token index
                        while self.t[self.i][0] in ('comment', 'bcomment'):
                            self.i += 1
                        self.i += 1  # brace consumed logically below
                        cmt = self.first_comment_after_brace()
                        self.i = save
                    args.append(self.value())
                return {'_call': v, 'args': args, '_name': cmt}
            # binary operators on identifiers (e.g. A .. B, A + B) are skipped
            return {'_id': v}
        # unknown punct: consume
        self.next_noncomment()
        return None

    def table(self):
        self.next_noncomment()  # {
        d = {'_pos': [], '_kv': {}}
        while True:
            k, v = self.peek()
            if k is None:
                break
            if v == '}':
                self.next_noncomment()
                break
            if v in (',', ';'):
                self.next_noncomment()
                continue
            # key = value ?
            k1, v1 = self.peek(1)
            if k == 'id' and v1 == '=':
                self.next_noncomment(); self.next_noncomment()
                d['_kv'][v] = self.value()
                continue
            if v == '[':
                self.next_noncomment()
                key = self.value()
                self.next_noncomment()  # ]
                self.next_noncomment()  # =
                d['_kv'][str(key)] = self.value()
                continue
            val = self.value()
            d['_pos'].append(val)
            # swallow binary operator chains
            while self.peek()[1] in ('+', '-', '*', '/', '..', '|', '&'):
                self.next_noncomment(); self.value()
        return d


def find_calls(node, name, out, parent_chain=()):
    if isinstance(node, dict):
        if node.get('_call') == name:
            out.append((node, parent_chain))
        if '_call' in node:
            for a in node['args']:
                find_calls(a, name, out, parent_chain + (node,))
        if '_kv' in node:
            for v in node['_kv'].values():
                find_calls(v, name, out, parent_chain)
            for v in node['_pos']:
                find_calls(v, name, out, parent_chain)
    elif isinstance(node, list):
        for v in node:
            find_calls(v, name, out, parent_chain)


def parse_file(path):
    src = open(path, encoding='utf-8-sig', errors='replace').read()
    toks = tokenize(src)
    p = P(toks)
    calls = []
    # top-level: sequence of calls
    while True:
        k, v = p.peek()
        if k is None:
            break
        if k == 'id':
            node = p.value()
            if isinstance(node, dict):
                calls.append(node)
            continue
        p.next_noncomment()
    return calls


def quest_records(calls, path):
    found = []
    find_calls(calls, 'q', found)
    recs = []
    for node, chain in found:
        args = node['args']
        if not args or not isinstance(args[0], int):
            continue
        qid = args[0]
        body = args[1] if len(args) > 1 and isinstance(args[1], dict) else {'_kv': {}, '_pos': []}
        kv = body.get('_kv', {})
        groups = kv.get('groups')
        objs = []
        items = []
        if isinstance(groups, dict) and '_pos' in groups:
            g = []
            for c in groups['_pos']:
                g.append(c)
            for c in g:
                if isinstance(c, dict) and c.get('_call') == 'objective':
                    objs.append(c)
                elif isinstance(c, dict) and c.get('_call') == 'i':
                    items.append(c)
        recs.append({
            'id': qid,
            'file': path,
            'name': node.get('_name'),
            'keys': sorted(kv.keys()),
            'has_qg': 'qg' in kv,
            'has_coord': 'coord' in kv or 'coords' in kv,
            'has_lvl': 'lvl' in kv,
            'has_sourceQuest': 'sourceQuest' in kv or 'sourceQuests' in kv,
            'n_objectives': len(objs),
            'n_item_children': len(items),
            'raw_kv': kv,
        })
    return recs


if __name__ == '__main__':
    root = sys.argv[1]
    out = sys.argv[2]
    allrecs = []
    nfiles = 0
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in ('zzOLD', '.config')]
        for f in fn:
            if f.endswith('.lua'):
                path = os.path.join(dp, f)
                try:
                    calls = parse_file(path)
                    recs = quest_records(calls, os.path.relpath(path, root))
                    allrecs.extend(recs)
                    nfiles += 1
                except Exception as e:
                    print('ERR', path, repr(e), file=sys.stderr)
    json.dump(allrecs, open(out, 'w'), default=str)
    print('files parsed:', nfiles, 'quest records:', len(allrecs), 'unique ids:', len({r['id'] for r in allrecs}))
