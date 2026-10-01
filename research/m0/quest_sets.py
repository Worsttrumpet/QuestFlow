"""M0 verification: set relationships between the client's QuestV2, Questie's Era quest set,
ATT's Forever quest set, and ForeverGuide's collected overlay.  Read-only; prints numbers.
Run from the directory that contains the clones (see setup_sources.sh) AFTER att_parse.py."""
import csv, re, json
def qids(p):
    s = open(p, encoding='utf-8', errors='replace').read()
    return {int(m) for m in re.findall(r'^\s*\[(\d+)\]\s*=\s*\{', s, re.M)}
QV2 = {int(r['ID']) for r in csv.DictReader(open('ForeverGuide/data-src/db2/QuestV2.1.60.1.69913.csv', encoding='utf-8-sig'))}
ERA = qids('QuestieDB/data/Classic/classicQuestDB.lua')
ATT = {r['id'] for r in json.load(open('forever_quests.json'))}
FG = {int(k) for k in json.load(open('ForeverGuide/data-src/forever.json'))['quests']}
new = QV2 - ERA
print('QuestV2 (69913):', len(QV2), '| Questie Era:', len(ERA), '| intersection:', len(QV2 & ERA))
print('QuestV2 - Era:', len(new), '(<30000:', sum(i < 30000 for i in new), ' >=30000:', sum(i >= 30000 for i in new), ')')
print('Era - QuestV2:', len(ERA - QV2))
print('QuestV2 ids >=30000:', sum(i >= 30000 for i in QV2))
print('ATT:', len(ATT), '| in QuestV2:', len(ATT & QV2), '| not in QuestV2:', len(ATT - QV2))
print('ATT ∩ new:', len(ATT & new), '| ForeverGuide new records:', len(FG - ERA), '| new covered by ATT or FG:', len(new & (ATT | FG)))
