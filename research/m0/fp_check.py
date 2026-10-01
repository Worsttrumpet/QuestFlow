"""THROWAWAY M0 check: do ATT flight-path map coordinates agree with TaxiNodes world positions
through UiMapAssignment?  Tries both axis orientations; prints residuals."""
import re, os, csv, sys, json
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import att_parse as A
W='AllTheThings/.contrib/.db/forever/.config/.wago/'
MAPC={}
for m in re.finditer(r'([A-Z0-9_]+)\s*=\s*(\d+)\s*;', open('AllTheThings/.contrib/.db/forever/.config/constants/maps.lua',encoding='utf-8-sig').read()):
    MAPC[m.group(1)]=int(m.group(2))
def load(t): return list(csv.DictReader(open(W+t+'.1.60.1.69913.csv',encoding='utf-8')))
tx={int(r['ID']):r for r in load('TaxiNodes')}
ua={}
for r in load('UiMapAssignment'):
    ua.setdefault(int(r['UiMapID']),[]).append(r)
def resolve(v):
    if isinstance(v,(int,float)): return v
    if isinstance(v,dict) and '_id' in v: return MAPC.get(v['_id'].split('.')[-1])
    return None
# collect ATT fp entries
fps=[]
root='AllTheThings/.contrib/.db/forever'
for dp,dn,fn in os.walk(root):
    dn[:]=[d for d in dn if d not in('zzOLD','.config')]
    for f in fn:
        if not f.endswith('.lua'): continue
        calls=A.parse_file(os.path.join(dp,f)); found=[]
        A.find_calls(calls,'fp',found)
        for node,_ in found:
            a=node['args']
            if not a or not isinstance(a[0],int): continue
            kv=a[1]['_kv'] if len(a)>1 and isinstance(a[1],dict) else {}
            c=kv.get('coord') or kv.get('coords')
            if isinstance(c,dict) and len(c['_pos'])>=3 and not isinstance(c['_pos'][0],dict):
                x,y,m=c['_pos'][0],c['_pos'][1],resolve(c['_pos'][2])
                fps.append((a[0],x,y,m,node.get('_name')))
print("fp entries with coords:",len(fps))
def predict(node,uimap,orient):
    rows=[r for r in ua.get(uimap,[]) if int(r['OrderIndex'])==0] or ua.get(uimap,[])
    r=rows[0]
    mn=(float(r['Region_0']),float(r['Region_1'])); mx=(float(r['Region_3']),float(r['Region_4']))
    wx,wy=float(node['Pos_0']),float(node['Pos_1'])
    # orientation A: Region_0/3 span world-x (north-south) -> map y ; Region_1/4 span world-y (east-west) -> map x
    if orient=='A':
        mapx=(wy-mn[1])/(mx[1]-mn[1]); mapy=(wx-mn[0])/(mx[0]-mn[0])
    else:
        mapx=(wx-mn[0])/(mx[0]-mn[0]); mapy=(wy-mn[1])/(mx[1]-mn[1])
    return mapx*100,mapy*100
res={}
for o in ('A','B','A-flip','B-flip'):
    errs=[]
    for i,x,y,m,name in fps:
        if i not in tx or m not in ua: continue
        o0=o[0]; px,py=predict(tx[i],m,o0)
        if o.endswith('flip'): px,py=100-px,100-py
        errs.append((i,name,round(abs(px-x),2),round(abs(py-y),2),round(px,1),round(py,1),x,y))
    res[o]=errs
    mae=sum(e[2]+e[3] for e in errs)/max(1,2*len(errs))
    print(f"orientation {o:7s}: n={len(errs)} mean abs error = {mae:.2f} map-% units")
best=min(res,key=lambda o:sum(e[2]+e[3] for e in res[o])/max(1,len(res[o])))
print("\nbest:",best)
for e in res[best]: print("  taxi",e[0],e[1] or '', "pred",(e[4],e[5]),"ATT",(e[6],e[7]),"err",(e[2],e[3]))
