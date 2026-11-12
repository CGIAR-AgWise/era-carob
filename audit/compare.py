"""Compare historical wide rows and screen original source rows without one-to-many joins."""
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
import csv, json, re, sys
from math import isfinite

cache = Path(sys.argv[1])
out = Path("report/audit")
out.mkdir(exist_ok=True, parents=True)
def write(name, columns, rows):
    with (out / name).open("w") as f:
        w = csv.writer(f, lineterminator="\n"); w.writerow(columns); w.writerows(rows)
def norm(x):
    return " ".join(str(x or "").strip().lower().split())
def number(x):
    try:
        v = float(x); return v if isfinite(v) else None
    except (TypeError,ValueError):
        return None
def day(x):
    try: return date.fromisoformat(x) if re.fullmatch(r'\d{4}-\d\d-\d\d',x or '') else None
    except ValueError: return None
def doi(x):
    x = re.sub(r'^(https?://(dx\.)?doi\.org/|doi:\s*)','',norm(x))
    # Preserve legal underscores inside DOI suffixes.
    x = re.sub(r'^(10\.\d{4,9})_',r'\1/',x)
    return x if re.fullmatch(r'10\.\d{4,9}/\S+',x) else None
def levels(a,b):
    return [len(a-b),len(a&b),len(b-a)]
def group(k,a,b):
    return "both" if k in a and k in b else "ERA only" if k in a else "Carob only"

master=json.loads(next(cache.glob("era_master_codes*.json")).read_text())
look=defaultdict(set)
alias={"sweetpotato":"sweet potato","faba bean":"fava bean","sugarcane":"sugar cane","lucerne":"alfalfa","peanut":"groundnut"}
def spelling(x): return alias.get(x,x)
for r in master["prod"]:
    if r.get("Product.Type")!="Plant": continue
    v=spelling(norm(r.get("Product.Simple")))
    if not v or re.search(r'unspecified|unknown|fallow|natural vegetation',v): continue
    for field in ("Product","Product.Simple","Latin.Name"):
        key=spelling(norm(r.get(field)))
        if key not in ("","na","no match"): look[key].add(v)
varieties={norm(r.get("V.Var")) for r in master["vars"]}
def resolve(k):
    if k in ("","na","n/a","none","unspecified"): return "", "missing or unspecified"
    hits=look.get(spelling(k),set())
    if len(hits)==1: return next(iter(hits)), "ERA prod vocabulary"
    if hits: return "", "ambiguous vocabulary"
    if re.search(r'[-;*]|\.\.',k): return "", "compound or qualified label"
    return "", "variety needs crop context" if k in varieties else "unmapped"

hist=Counter(); cs=Counter(); es=set(); ec=set(); cc=set(); cg=set(); trials=set(); records=set()
for r in csv.DictReader((cache/"historical_era.csv").open()):
    hist[r["crop"].strip().lower()]+=1; es.add(r["dataset_id"]); ec.add(r["country"])
meta=defaultdict(set)
for r in csv.DictReader((cache/"carob_agronomy_metadata-cc.csv").open()):
    p=doi(r["publication"])
    if p: meta[p].add(r["dataset_id"])
rows=list(csv.DictReader((cache/"historical_era.csv").open()))
links=sorted({(r["dataset_id"],p,c) for r in rows if (p:=doi(r["uri"])) for c in meta[p]})
del rows
write("publication_links.csv",["ERA study","publication DOI","Carob dataset"],links)
matched_era={r[0] for r in links}; matched_carob={r[2] for r in links}
qc=defaultdict(Counter)
def screen(src,lat,lon,start,end,year,yield_ok,crop,overlap):
    q=qc[src]; q["rows"]+=1
    a,b=number(lat),number(lon); coord=a is not None and b is not None and -90<=a<=90 and -180<=b<=180 and (a,b)!=(0,0)
    p,h=day(start),day(end)
    yrs={int(v) for v in re.findall(r'(?<!\d)(?:19|20)\d\d(?!\d)',str(year))}
    time_ok=bool(p and 1900<=p.year<=2025 and (not h or h>=p))
    if src=="era": time_ok=bool(time_ok and yrs=={p.year})
    tests={"valid coordinate pair":coord,"exact planting date":bool(p),"plausible planting date":time_ok,
           "valid location and date":coord and time_ok,"nonnegative yield convertible to kg/ha":yield_ok,"resolved crop":bool(crop),
           "screened yield rows outside publication overlap":coord and time_ok and yield_ok and bool(crop) and not overlap}
    q.update(k for k,v in tests.items() if v)
    return tests
for r in csv.DictReader((cache/"carob_agronomy-cc.csv").open()):
    k=r["crop"].strip().lower(); cs[k]+=1; cg.add(r["dataset_id"]);cc.add(r["country"])
    if r["trial_id"]:trials.add((r["dataset_id"],r["trial_id"]))
    if r["record_id"]:records.add((r["dataset_id"],r["record_id"]))
    y=number(r["yield"])
    screen("carob",r["latitude"],r["longitude"],r["planting_date"],r["harvest_date"],"",y is not None and y>=0,resolve(k)[0],r["dataset_id"] in matched_carob)
raw=[set(hist)-{""},set(cs)-{""}]
write("crop_labels.csv",["raw label","partition","ERA wide rows","Carob wide rows","resolved product","decision"],(
    (k,group(k,*raw) if k else "missing",hist[k],cs[k],*resolve(k)) for k in sorted(set(hist)|set(cs))))
can=[{resolve(k)[0] for k in s}-{""} for s in raw]
write("products.csv",["ERA product identity","partition"],((k,group(k,*can)) for k in sorted(set.union(*can))))
d=json.loads(next(cache.glob("agronomic_*.json")).read_text())["Data.Out"]
units=Counter()
for r in d:
    y=number(r.get("ED.Mean.T")); unit=str(r.get("Out.Unit") or "").strip()
    if r.get("Out.Subind")=="Crop Yield": units[unit]+=1
    ok=r.get("Out.Subind")=="Crop Yield" and y is not None and y>=0 and unit in {"kg/ha","t/ha","Mg/ha","g/m2"}
    screen("era",r.get("Site.LatD"),r.get("Site.LonD"),r.get("PD.Plant.Start") if r.get("PD.Plant.Variable")=="Planting" else None,r.get("PD.Harvest.End"),r.get("Time"),ok,resolve(norm(r.get("P.Product")))[0],r.get("B.Code") in matched_era)
write("yield_units.csv",["ERA source yield unit","Data.Out rows"],sorted(units.items()))
write("eligibility.csv",["test","ERA Data.Out rows","Carob wide rows"],((k,qc["era"][k],qc["carob"][k]) for k in sorted(set(qc["era"])|set(qc["carob"]))))
summary=dict(era_rows=sum(hist.values()),carob_rows=sum(cs.values()),merged=sum(hist.values())+sum(cs.values()),raw=levels(*raw),resolved=levels(*can),era_ids=len(es-{""}),carob_ids=len(cg-{""}),doi_edges=len(links),doi_studies=len(matched_era),trials=len(trials),record_keys=len(records),era_source=len(d),countries=len(ec-cc-{""}),era_missing=hist[""],carob_missing=cs[""])
(out/"summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print(summary)
