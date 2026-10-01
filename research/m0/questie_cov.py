"""THROWAWAY M0 check: per-field coverage of Questie's Era quest table (analysis only; GPL data not copied)."""
import re, sys, json
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse as A
src=open('QuestieDB/data/Classic/classicQuestDB.lua',encoding='utf-8').read()
keys=dict((k,int(v)) for k,v in re.findall(r"\['(\w+)'\]\s*=\s*(\d+),",src[:src.find('questData')]))
i=src.find('[[return'); j=src.rfind(']]')
body=src[i+len('[[return'):j]
toks=A.tokenize(body); p=A.P(toks); tbl=p.table()
import csv
A_={int(r['ID']) for r in csv.DictReader(open('ForeverGuide/data-src/db2/QuestV2.1.60.1.69913.csv',encoding='utf-8-sig'))}
def isnil(v): return v is None or (isinstance(v,dict) and v.get('_id')=='nil')
def get(entry,name):
    pos=entry['_pos']; k=keys[name]-1
    return pos[k] if k<len(pos) else None
def nonempty(v):
    if isnil(v): return False
    if isinstance(v,dict) and '_pos' in v: return any(nonempty(x) for x in v['_pos'])
    if isinstance(v,(int,float)): return v!=0
    if isinstance(v,str): return v!=''
    return True
# top-level table has _kv keyed by str(id)
ents={int(k):v for k,v in tbl['_kv'].items() if isinstance(v,dict) and '_pos' in v}
print("Questie Era entries:",len(ents))
ov=[q for q in ents if q in A_]
print("overlap with QuestV2:",len(ov))
fields=['name','startedBy','finishedBy','requiredLevel','questLevel','objectivesText','objectives','preQuestGroup','preQuestSingle','exclusiveTo','nextQuestInChain','reputationReward','requiredSourceItems']
for f in fields:
    if f not in keys: print(f,'(key missing)'); continue
    n=sum(1 for q in ov if nonempty(get(ents[q],f)))
    print(f"  {f:20s}{n:5d} / {len(ov)}  ({100*n/len(ov):5.1f}%)")
print("keys with numbers (first 30):",sorted(keys.items(),key=lambda x:x[1])[:30])
# quests without giver at all; rewards field?
print("rewardItem-like keys:",[k for k in keys if 'eward' in k or 'tem' in k])
