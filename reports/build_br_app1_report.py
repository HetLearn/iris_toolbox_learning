#!/usr/bin/env python3
"""Build reports/sw07_br_app1_report.html: Application 1 for the bounded-rationality portfolio.

    python reports/build_br_app1_report.py          (from the project root, or any folder)
    python reports/build_br_app1_report.py --inputs DIR --out FILE

A separate page from the main report (build_report_v3.py). It reads only the tables in
results/br_portfolio/ written by run_br_app1.m: app1_variants.csv, app1_summary.csv,
app1_paths.csv, app1_shares.csv, app1_shares_2022Q2.csv, app1_events.csv and app1_calib18.csv.
Every number in the text and the charts is computed from them at build time; none is typed.
The CSS, the theme tokens (light/dark) and the JS chart engine are those of build_report_v3.py:
its string constants CSS, CSS_EXTRA, JS and FONTS are read with ast (nothing in that file is
executed). Writes one page (content only, no <html>/<head>/<body>: the claude.ai artifact
publisher wraps it).
"""
import argparse
import ast
import html
import json
import math
import pathlib
import re

import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[1]
_AP = argparse.ArgumentParser(description="Build the BR portfolio Application 1 report from results/br_portfolio/.")
_AP.add_argument("--inputs", default=str(ROOT / "results" / "br_portfolio"), help="folder with the app1_*.csv tables")
_AP.add_argument("--out", default=str(ROOT / "reports" / "sw07_br_app1_report.html"), help="page to write")
_ARGS = _AP.parse_args()
INP = pathlib.Path(_ARGS.inputs)
OUT = pathlib.Path(_ARGS.out)
REPORT_DATE = "2026-10-21"
esc = html.escape
MINUS = "−"


# ============================================================================= engine (main report)
def _engine():
    src = (ROOT / "reports" / "build_report_v3.py").read_text(encoding="utf-8")
    want = {"CSS", "CSS_EXTRA", "JS", "FONTS"}
    out = {}
    for node in ast.parse(src).body:
        if (isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id in want):
            out[node.targets[0].id] = ast.literal_eval(node.value)
    if want - set(out):
        raise SystemExit(f"build_report_v3.py lacks {sorted(want - set(out))}")
    return out


_E = _engine()
CSS, CSS_EXTRA, FONTS, JS = _E["CSS"], _E["CSS_EXTRA"], _E["FONTS"], _E["JS"]

CSS_BR = r"""
.wrap{padding-left:max(clamp(16px,4vw,44px),env(safe-area-inset-left,0px));padding-right:max(clamp(16px,4vw,44px),env(safe-area-inset-right,0px))}
table.sum{font-size:12.5px}
table.sum td,table.sum th{padding:6px 7px}
table.sum thead th{white-space:normal;vertical-align:bottom}
table.sum td:nth-child(1){min-width:128px}
table.sum td:nth-child(2){min-width:84px}
table.sum td:nth-child(3){min-width:160px}
table.sum td:nth-child(4){min-width:200px}
table.sum td:nth-child(5),table.sum td:nth-child(6){white-space:nowrap}
table.sum td:nth-child(7){min-width:130px}
table.sum td:nth-child(8){min-width:100px}
table.cal thead th{white-space:normal;vertical-align:bottom}
table.sum td .no{font:600 12.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--fg);margin-right:4px}
table.sum td .src{display:block;color:var(--muted);font-size:11.5px;margin-top:3px}
table.sum td .chip{margin:3px 4px 0 0}
table.sum tr.ref td{background:var(--bg-2)}
table.sum tr.grp td{font-weight:600;color:var(--fg);background:var(--band-2);font-size:12.5px}
table.cal td{white-space:nowrap}
table.cal td:first-child{white-space:normal;min-width:230px}
table.cal tr.pick td{font-weight:600}
ul.flags{margin:6px 0 0;padding-left:1.1rem}
ul.flags li{margin-bottom:7px;max-width:88ch}
.famlist{color:var(--ink-2);font-size:14.5px}
.g-2 figure.sh .plot{min-height:120px}
"""


# ============================================================================= inputs
def rd(name, **kw):
    p = INP / name
    if not p.exists():
        raise SystemExit(f"missing input {p} (run run_br_app1('csv') and run_br_app1('calib18') first)")
    return pd.read_csv(p, keep_default_na=True, **kw)


VAR = rd("app1_variants.csv", dtype={"no": str})
SUM = rd("app1_summary.csv", dtype={"no": str, "stop_date": str, "gap_peak_date": str, "fac_first": str, "fac_last": str})
PTH = rd("app1_paths.csv")
SHR = rd("app1_shares.csv")
S22 = rd("app1_shares_2022Q2.csv")
EVT = rd("app1_events.csv")
CAL = rd("app1_calib18.csv")


def nz(x):
    """None for NaN / missing, else the value."""
    if x is None:
        return None
    try:
        if isinstance(x, float) and math.isnan(x):
            return None
    except TypeError:
        pass
    if isinstance(x, str) and x.strip() == "":
        return None
    return x


RUN = {}
for r in VAR.to_dict("records"):
    RUN[r["id"]] = dict(r)
for r in SUM.to_dict("records"):
    RUN.setdefault(r["id"], {}).update({k: v for k, v in r.items() if k not in ("no", "family")})
IDS = [r["id"] for r in sorted(VAR.to_dict("records"), key=lambda d: (d["family_order"], d["order"]))]
REFS = ["a1_re", "a1_learn"]
FAMS = []
for r in sorted(VAR.to_dict("records"), key=lambda d: (d["family_order"], d["order"])):
    if r["family"] != "ref" and r["family"] not in [f for f, _ in FAMS]:
        FAMS.append((r["family"], r["family_label"]))
FAMIDS = {f: [i for i in IDS if RUN[i]["family"] == f] for f, _ in FAMS}
VARIANTS = [i for i in IDS if i not in REFS]
P = {(r.variant, r.variable, r.date): float(r.value) for r in PTH.itertuples()}
COMPLETE = {i: int(RUN[i].get("complete", 0) or 0) == 1 for i in IDS}
RAN = {i: any(k[0] == i for k in P) for i in IDS}


def qrange(a, b):
    y, q = int(a[:4]), int(a[-1])
    yb, qb = int(b[:4]), int(b[-1])
    out = []
    while (y, q) <= (yb, qb):
        out.append(f"{y}Q{q}")
        q += 1
        if q == 5:
            y, q = y + 1, 1
    return out


ORIGIN = max(r.date for r in PTH.itertuples() if r.variant == "a1_learn" and r.stage == "history")
HOR = sorted({r.date for r in PTH.itertuples() if r.variant == "a1_learn" and r.stage == "forecast"})
END = HOR[-1]
H = len(HOR)
X = qrange("2018Q1", END)
COVID = [q for q in qrange("2020Q1", "2020Q4") if q in X]
NODATA = [q for q in COVID if ("data", "pinfobs", q) not in P or math.isnan(P[("data", "pinfobs", q)])]
VAR4 = ["pinfobs", "robs", "dy", "dc"]
VLAB = {"pinfobs": "Inflation", "robs": "Policy rate", "dy": "Output growth", "dc": "Consumption growth"}
VWORD = {"pinfobs": "inflation", "robs": "the policy rate", "dy": "output growth", "dc": "consumption growth"}
UNIT = "% annualised"
LVNAME = {"pinf": "inflation", "c": "consumption"}


# ----------------------------------------------------------------------------- formatting
def f(x, d=2, sign=False):
    if x is None or (isinstance(x, float) and (math.isnan(x) or math.isinf(x))):
        return "n/a"
    s = f"{abs(x):.{d}f}"
    if float(s) == 0:
        return s
    if x < 0:
        return MINUS + s
    return ("+" + s) if sign else s


def pct(x, d=2):
    return f(x, d) + "%"


def pp(x, d=2, sign=True):
    return f(x, d, sign) + " pp"


def code(s):
    return f"<code>{esc(s)}</code>"


def fnum(x):
    """A parameter value as written in the tables (%g)."""
    return re.sub(r"^-", MINUS, f"{x:g}")


def g3(x):
    """Three significant digits."""
    return re.sub(r"^-", MINUS, f"{x:.3g}")


def lc1(s):
    return s[0].lower() + s[1:] if len(s) > 1 and s[0].isupper() and s[1].islower() else s


def joinand(items):
    items = list(items)
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


def num(i, k):
    v = nz(RUN[i].get(k))
    return None if v is None else float(v)


def txt(i, k):
    v = nz(RUN[i].get(k))
    return "" if v is None else str(v)


def label(i, short=False):
    r = RUN[i]
    if i == "a1_re":
        return "RE(t-1)"
    if i == "a1_learn":
        return "Baseline"
    return f"{r['no']}" if short else f"{r['no']} {r['name']}"


def series(v, var, xs, start=None):
    out = []
    for q in xs:
        if start and q < start:
            out.append(None)
            continue
        x = P.get((v, var, q))
        out.append(None if x is None or math.isnan(x) else round(x, 4))
    return out


def avg(i, var):
    xs = [P.get((i, var, q)) for q in HOR]
    if any(x is None or math.isnan(x) for x in xs):
        return None
    return sum(xs) / len(xs)


# ============================================================================= entities and colours
ENT = {"data": dict(name="Data", short="Data", color="ink", width=2.2),
       "a1_re": dict(name="RE(t-1) benchmark", short="RE(t-1)", color="s1"),
       "a1_learn": dict(name="Baseline (RE agents and AR(1) learners)", short="Baseline", color="s2")}
SLOTS = ["s3", "s4", "s5", "s6", "s7", "s8"]
# Variants that share a mechanism share a hue and differ by line style (composite encoding), so that the
# slots are assigned in their fixed order without skipping and no figure needs more than four variant hues.
HUE_LEAD = {"1b": "1a", "5b": "5a", "25a": "20", "25b": "20", "24": "23", "33": "19", "31": "29"}
HUE_WHY = {"1a": "level-k reasoning", "5a": "cognitive discounting", "20": "every agent learns the seven sticky expectations",
           "23": "learners of a mean", "19": "a fixed forecasting rule beside the RE agents", "29": "an AR(1) wedge on expectations"}
STYLES = ["solid", "dashed", "dotted"]
HUE_GROUPS = {}
for fam, _ in FAMS:
    k = -1
    seen = {}
    for i in FAMIDS[fam]:
        no = RUN[i]["no"]
        lead = HUE_LEAD.get(no, no)
        if lead in seen:
            col = seen[lead][0]
            sty = STYLES[len(seen[lead][1])]
            seen[lead][1].append(i)
        else:
            k += 1
            if k >= len(SLOTS):
                raise SystemExit(f"family {fam}: more than {len(SLOTS)} hues needed")
            col, sty = SLOTS[k], "solid"
            seen[lead] = (col, [i])
        ENT[i] = dict(name=label(i), short=no, color=col, style=sty)
    HUE_GROUPS[fam] = {lead: ids for lead, (_, ids) in seen.items() if len(ids) > 1}

CHARTS, LEGENDS = {}, {}
FIGN = [0]
ML = 46


def S(ent, v, **kw):
    d = {k: x for k, x in ENT[ent].items()}
    d["v"] = v
    d.update(kw)
    return d


def leg(ent, **kw):
    d = {k: x for k, x in ENT[ent].items() if k in ("name", "color", "style", "width")}
    d.update(kw)
    return d


def fig_title(t):
    FIGN[0] += 1
    return f'<p class="fig"><span class="fn">Figure {FIGN[0]}.</span> {t}</p>'


def chart(cid, group, title, cap, x, ser, cls="", **kw):
    spec = dict(id=cid, group=group, title=title, x=x, series=ser, origin=ORIGIN, ml=ML, mr=12, endLabels=False)
    spec.update(kw)
    CHARTS[cid] = spec
    return (f'<figure class="chart{(" " + cls) if cls else ""}"><figcaption class="ct">{esc(title)}</figcaption>'
            f'<div class="plot" data-chart="{cid}"></div><p class="cap">{cap}</p></figure>')


def legend(gid, items):
    LEGENDS[gid] = items
    return f'<div class="legend" data-legend="{gid}"></div>'


def tables(gid, label_="Table view: the plotted numbers"):
    return (f'<details class="tables"><summary>{esc(label_)}</summary>'
            f'<div class="tblhost" data-tables="{gid}"></div></details>')


def chip(t, cls=""):
    return f'<span class="chip{(" " + cls) if cls else ""}">{esc(t)}</span>'


# ============================================================================= shares
SHL = {}
for r in SHR.itertuples():
    SHL[(r.variant, r.variable, r.type, r.date)] = (r.n_end, r.n_model)
INPOP = {(r.variant, r.variable, r.type): int(r.in_population) for r in SHR.itertuples()}
MODE = {i: txt(i, "mode") for i in IDS}


def types_of(i, lv="pinf"):
    seen = []
    for (v, x, t) in INPOP:
        if v == i and x == lv and t not in seen:
            seen.append(t)
    return seen


def learn_vars(i):
    out = []
    for (v, x, t) in INPOP:
        if v == i and x not in out:
            out.append(x)
    return out


def share_series(i, lv, t, xs):
    out = []
    for q in xs:
        v = SHL.get((i, lv, t, q))
        out.append(None if v is None or v[0] is None or math.isnan(v[0]) else round(float(v[0]), 4))
    return out


def two_type(i):
    """The non-RE type of a switching run with RE and one other type in the population (pinf), else None."""
    if MODE.get(i) != "switching":
        return None
    ts = [t for t in types_of(i) if INPOP.get((i, "pinf", t), 0) == 1]
    if len(ts) == 2 and "RE" in ts:
        return [t for t in ts if t != "RE"][0]
    return None


S22D = {}
for r in S22.itertuples():
    S22D[(r.variant, r.variable, r.type)] = None if math.isnan(r.share) else float(r.share)


def shares_txt(i, html_=True):
    lvs = learn_vars(i)
    if not lvs:
        return "n/a"
    per = []
    for lv in lvs:
        items = []
        for t in types_of(i, lv):
            s = S22D.get((i, lv, t))
            if s is None:
                continue
            if INPOP.get((i, lv, t), 1) == 0 and abs(s) < 1e-12:
                continue
            if MODE.get(i) != "switching" and t == "RE" and abs(s) < 1e-12:
                continue
            items.append((t, s))
        per.append((lv, items))
    if not any(items for _, items in per):
        return "n/a"

    def fmt(items):
        vals = {round(s, 3) for _, s in items}
        if len(items) > 2 and len(vals) == 1:
            return f"{items[0][0]}-{items[-1][0]} {f(items[0][1], 3)} each"
        return ", ".join(f"{t} {f(s, 3)}" for t, s in items)

    if len(per) > 1 and all(fmt(it) == fmt(per[0][1]) for _, it in per):
        return f"{fmt(per[0][1])} (each of the {len(per)} variables)"
    if len(per) == 1:
        return fmt(per[0][1])
    return "; ".join(f"{LVNAME.get(lv, lv)}: {fmt(it)}" for lv, it in per)


def learners_2022(i):
    t = two_type(i)
    if t is None:
        return None
    return S22D.get((i, "pinf", t))


# ============================================================================= facility events and stops
EVF = EVT[EVT.type.astype(str).str.startswith("projection")] if len(EVT) else EVT
FAC = txt("a1_learn", "facility")


def fac_n(i):
    a, b = num(i, "fac_events_history"), num(i, "fac_events_forecast")
    return int((a or 0) + (b or 0))


def fac_dates(i):
    return sorted(EVF[EVF.variant == i].date.astype(str).tolist()) if len(EVF) else []


def fac_txt(i, short=False):
    n = fac_n(i)
    if n == 0:
        return "none"
    d = fac_dates(i)
    h, fo = int(num(i, "fac_events_history") or 0), int(num(i, "fac_events_forecast") or 0)
    tys = ", ".join(sorted(set(EVF[EVF.variant == i].type.astype(str))))
    if short:
        return f"{n} ({h} history, {fo} forecast), {d[0]}-{d[-1]}"
    return f"{n} event{'s' if n != 1 else ''} ({tys}): {h} in the history, {fo} in the forecast, {d[0]} to {d[-1]}"


STOPPED = [i for i in IDS if txt(i, "status") == "stopped"]
ERRORS = [i for i in IDS if txt(i, "status") not in ("ok", "stopped")]


def stop_txt(i):
    st = txt(i, "status")
    if st == "ok":
        return "none"
    if st == "stopped":
        why = {"hetlearn:engine:noSolution": "no model solution",
               "hetlearn:engine:levelNoSolution": "a level economy has no stable solution",
               "hetlearn:engine:almUnstable": "the first model checked is already unstable"}.get(txt(i, "error_id"), "stops")
        return f"stops in {txt(i, 'stop_date')} ({txt(i, 'stop_stage')} stage): {why}"
    return f"error: {txt(i, 'error_message')[:120]}"


# level-k: the first facility event's detail (beliefs and the level-1 loading)
def levelk_facts():
    out = {}
    ids = [i for i in VARIANTS if RUN[i]["no"] in ("1a", "1b")]
    for i in ids:
        ev = EVF[(EVF.variant == i) & (EVF.type == "projection_level")].sort_values("date")
        if not len(ev):
            continue
        d0 = ev.iloc[0]
        m_b = re.search(r"pinf__L0 = \[([-0-9.e]+) ([-0-9.e]+)\]", str(d0.detail))
        m_l = re.search(r"coefficient on pinf\{-1\} ([-0-9.e]+)", str(d0.detail))
        m_j = re.search(r"the level-(\d+) economy", str(d0.detail))
        out[i] = dict(date=str(d0.date), stage=str(d0.stage), beta=float(m_b.group(2)) if m_b else None,
                      alpha=float(m_b.group(1)) if m_b else None, load=float(m_l.group(1)) if m_l else None,
                      level=int(m_j.group(1)) if m_j else None, dates=ev.date.astype(str).tolist(),
                      levels=[int(x) for x in re.findall(r"the level-(\d+) economy", " ".join(ev.detail.astype(str)))])
    return out


LK = levelk_facts()


# ============================================================================= variant 18 calibration
CALR = CAL.to_dict("records")
CDES = next((r for r in CALR if r["tag"] == "design"), None)
CPUB = next((r for r in CALR if int(r["published"]) == 1), None)
CPICK = next((r for r in CALR if int(r["chosen"]) == 1), None)
NPASS = int(CAL["pass"].sum())
ID18 = next((i for i in VARIANTS if RUN[i]["no"] == "18"), None)
DG_SRC = txt(ID18, "source") if ID18 else ""


def dg_val(name):
    m = re.search(name + r" = ([0-9.]+)", DG_SRC)
    return m.group(1) if m else "n/a"


# ============================================================================= figure builders
def offscale(ser_ref, ser_var):
    """Variant series that would dominate the scale: beyond the range of data, RE(t-1) and the baseline
    by more than three times its span and 15 pp. Returns (off series, y-range of the rest or None)."""
    ref = [v for s in ser_ref for v in s["v"] if v is not None]
    if not ref:
        return [], None
    lo, hi = min(ref), max(ref)
    tol = max(3 * (hi - lo), 15.0)
    off = [s for s in ser_var if any(v is not None and (v > hi + tol or v < lo - tol) for v in s["v"])]
    if not off:
        return [], None
    rest = ref + [v for s in ser_var if s not in off for v in s["v"] if v is not None]
    return off, [min(rest), max(rest)]


def main_panels(gid, ids):
    out = []
    for var in VAR4:
        clip = []
        if var in ("dy", "dc") and COVID:
            cv = [abs(P[("data", var, q)]) for q in COVID if ("data", var, q) in P and not math.isnan(P[("data", var, q)])]
            ot = [abs(P[("data", var, q)]) for q in X if q not in COVID and ("data", var, q) in P
                  and not math.isnan(P[("data", var, q)])]
            if cv and ot and max(cv) > 2 * max(ot):
                clip = COVID
        ref = [S("data", series("data", var, X)), S("a1_re", series("a1_re", var, X, ORIGIN)),
               S("a1_learn", series("a1_learn", var, X, ORIGIN))]
        vs = []
        for i in ids:
            if not RAN[i]:
                continue
            s = S(i, series(i, var, X, ORIGIN))
            if not COMPLETE[i]:
                last = max(k for k, v in enumerate(s["v"]) if v is not None)
                s["rings"] = [last]
            vs.append(s)
        refc = [dict(s, v=[None if X[k] in clip else v for k, v in enumerate(s["v"])]) for s in ref]
        off, yr = offscale(refc, vs)
        kw = dict(clip=clip)
        pieces = [f"{label(i, True) if i not in REFS else ('RE(t-1)' if i == 'a1_re' else 'baseline')} "
                  f"{pct(avg(i, var))}" for i in REFS + [i for i in ids if RAN[i] and COMPLETE[i]]]
        cap = f"Average {HOR[0]}-{END}: " + "; ".join(pieces)
        dv = [P.get(("data", var, q)) for q in HOR]
        if all(x is not None and not math.isnan(x) for x in dv):
            cap += f"; data {pct(sum(dv) / len(dv))}"
        cap += "."
        part = [i for i in ids if RAN[i] and not COMPLETE[i]]
        if part:
            cap += " " + "; ".join(f"{label(i, True)} stops in {txt(i, 'stop_date')}, its line ends at the ring" for i in part) + "."
        if off:
            kw["yr"] = yr
            for s in off:
                i = next(k for k in ids if ENT[k]["name"] == s["name"])
                vals = [v for v in s["v"] if v is not None]
                cap += (f" {label(i, True)} leaves the scale ({f(min(vals), 1)} to {f(max(vals), 1)} over "
                        f"{HOR[0]}-{END}; values in the table view).")
        if clip:
            cap += " The 2020 quarters run off the scale (values in the table view)."
        out.append(chart(f"{gid}-{var}", gid, f"{VLAB[var]}, {UNIT}", cap, X, ref + vs, legend=False, **kw))
    return out


DASHES = ["solid", "dashed", "dotted", "dashdot"]


def share_panels(gid, ids):
    out, notes = [], []
    two = [i for i in ids if RAN[i] and two_type(i)]
    ser = [S("a1_learn", share_series("a1_learn", "pinf", "BR", X), name="Baseline: AR(1) learners")]
    for i in two:
        t = two_type(i)
        ser.append(S(i, share_series(i, "pinf", t, X), name=f"{label(i, True)}: {t}"))
    if two:
        vals = [f"baseline {f(learners_2022('a1_learn'), 3)}"] + [f"{label(i, True)} {f(learners_2022(i), 3)}" for i in two]
        others = [f"{two_type(i)} in {label(i, True)}" for i in two if two_type(i) != "BR"]
        who = "the AR(1) learners" + (f"; {joinand(others)}" if others else "")
        cap = (f"Share of the type beside the RE agents ({who}), computed by discrete choice at the end of each quarter "
               f"and in force in the next. At the end of {ORIGIN}: {'; '.join(vals)}. Thin line: 0.5.")
        out.append(chart(f"{gid}-sh", gid, "Learners' share of inflation expectations, end of quarter (0 to 1)", cap, X,
                         ser, cls="sh", h=170, dec=3, yfix=True, refs=[dict(y=0.5, label="")]))
    for i in ids:
        if not RAN[i]:
            continue
        for lv in learn_vars(i):
            if lv not in ("pinf", "c"):
                continue
            ts = [t for t in types_of(i, lv) if INPOP.get((i, lv, t), 0) == 1]
            if MODE.get(i) != "switching" or (lv == "pinf" and two_type(i)) or len(ts) < 2:
                continue
            ss = []
            for k, t in enumerate(ts):
                ss.append(S(i, share_series(i, lv, t, X), name=t, short=t, style=DASHES[k % len(DASHES)]))
            v22 = ", ".join(f"{t} {f(S22D.get((i, lv, t)), 3)}" for t in ts)
            what = "inflation expectations" if lv == "pinf" else "the consumption expectation"
            cap = (f"Shares of the {len(ts)} types in {what}, computed by discrete choice at the end of each quarter and "
                   f"in force in the next; one line style per type. At the end of {ORIGIN}: {v22}.")
            out.append(chart(f"{gid}-sh-{RUN[i]['no']}-{lv}", gid,
                             f"{label(i, True)}: type shares, {LVNAME.get(lv, lv)}, end of quarter (0 to 1)",
                             cap, X, ss, cls="sh", h=170, dec=3, yfix=True))
    lrn = [i for i in ids if RAN[i] and MODE.get(i) == "learning"]
    fix = [i for i in ids if RAN[i] and MODE.get(i) == "fixed_shares"]
    bits = []
    if lrn:
        n = len(learn_vars(lrn[0]))
        bits.append(f"{joinand(label(i, True) for i in lrn)}, where every agent learns (share 1"
                    f"{f' in each of the {n} learned expectations' if n > 1 else ''})")
    for i in fix:
        n = len(learn_vars(i))
        bits.append(f"{label(i, True)}, whose shares are fixed ({shares_txt(i).split(' (each')[0]}"
                    f"{f' in each of the {n} learned expectations' if n > 1 else ''})")
    if bits:
        notes.append("No share panel for " + joinand(bits))
    return out, notes


def family_figure(gid, fam, title):
    ids = FAMIDS[fam]
    items = [leg("data"), leg("a1_re"), leg("a1_learn")] + [leg(i) for i in ids if RAN[i]]
    main = main_panels(gid, ids)
    shp, notes = share_panels(gid, ids)
    missing = [i for i in ids if not RAN[i]]
    t = (f"{title}: forecast from the {ORIGIN} peak, {X[0]}-{END}. The shaded area is the forecast; lines start at the "
         f"origin." + (f" The data line has a gap in {NODATA[0]}-{NODATA[-1]}, the covid quarters left out." if NODATA else ""))
    grp = HUE_GROUPS.get(fam, {})
    if grp:
        t += (" Variants drawn in one hue share a mechanism and differ by line style: " + "; ".join(
            f"{joinand(label(i, True) for i in ids)} ({HUE_WHY.get(lead, 'same mechanism')})" for lead, ids in grp.items()) + ".")
    extra = ""
    if notes or missing:
        bits = notes + [f"{label(i, True)} has no path ({stop_txt(i)})" for i in missing]
        extra = f'<p class="cap">{esc("; ".join(bits))}.</p>'
    return (f"{fig_title(t)}\n{legend(gid, items)}\n<div class=\"grid g-2\">{''.join(main + shp)}</div>\n{extra}\n"
            f"{tables(gid)}")


# ============================================================================= prose
def rank_txt(ids):
    c = [i for i in ids if COMPLETE[i] and num(i, "avg_pinf") is not None]
    return sorted(c, key=lambda i: num(i, "avg_pinf"))


def fam_answer(fam):
    ids = FAMIDS[fam]
    c = rank_txt(ids)
    b, re_ = num("a1_learn", "avg_pinf"), num("a1_re", "avg_pinf")
    parts = []
    if c:
        lst = "; ".join(f"{label(i, True)} {pct(num(i, 'avg_pinf'))}" for i in sorted(c, key=lambda i: IDS.index(i)))
        above = [i for i in ids if i in c and num(i, "avg_pinf") > b]
        below = [i for i in ids if i in c and num(i, "avg_pinf") < b]
        lead = (f"Average inflation over {HOR[0]}-{END} is {lst}, against {pct(b)} for the baseline and {pct(re_)} "
                f"for RE(t-1).")
        if above and not below:
            lead += f" Every variant here ends up above the baseline."
        elif below and not above:
            lead += f" Every variant here ends up below the baseline."
        else:
            if above:
                lead += f" Above the baseline: {joinand(label(i, True) for i in above)}."
            if below:
                lead += f" Below it: {joinand(label(i, True) for i in below)}."
        parts.append(lead)
        gi = max(c, key=lambda i: abs(num(i, "gap_peak")))
        parts.append(f"The largest gap to RE(t-1) in this group is {pp(num(gi, 'gap_peak'))} ({label(gi, True)}, "
                     f"{txt(gi, 'gap_peak_date')}); the baseline's is {pp(num('a1_learn', 'gap_peak'))} in "
                     f"{txt('a1_learn', 'gap_peak_date')}.")
    two = [i for i in ids if RAN[i] and learners_2022(i) is not None]
    if two:
        lo = min(two, key=lambda i: learners_2022(i))
        hi = max(two, key=lambda i: learners_2022(i))
        if lo == hi:
            parts.append(f"At the end of {ORIGIN} the learners hold {f(learners_2022(lo), 3)} of inflation expectations "
                         f"in {label(lo, True)}, against {f(learners_2022('a1_learn'), 3)} in the baseline.")
        else:
            parts.append(f"At the end of {ORIGIN} the learners hold between {f(learners_2022(lo), 3)} ({label(lo, True)}) "
                         f"and {f(learners_2022(hi), 3)} ({label(hi, True)}) of inflation expectations in the two-type "
                         f"variants, against {f(learners_2022('a1_learn'), 3)} in the baseline.")
    ev = [i for i in ids if fac_n(i) > 0]
    if ev:
        def one(i):
            d = fac_dates(i)
            h = int(num(i, "fac_events_history") or 0)
            when = span_txt(d) if len(d) <= 4 else f"between {d[0]} and {d[-1]}"
            return (f"{label(i, True)} ({fac_n(i)} quarter{'s' if fac_n(i) != 1 else ''}, {when}"
                    f"{f'; {h} of them in the history' if 0 < h < fac_n(i) else ('; all in the history' if h == fac_n(i) else '')})")
        parts.append("The facility acts in " + joinand(one(i) for i in ev) + ".")
    elif FAC != "none":
        parts.append(f"The facility ({code(FAC)}) never acts in this group.")
    st = [i for i in ids if i in STOPPED or i in ERRORS]
    if st:
        parts.append(" ".join(f"{label(i, True)} {stop_txt(i)}." for i in st))
    return " ".join(parts)


def var_list(fam):
    return "".join(f"<li><b>{esc(RUN[i]['no'])}</b> {esc(RUN[i]['name'])}. {esc(RUN[i]['mechanism'])}.</li>"
                   for i in FAMIDS[fam])


FAM_INTRO = {
    "depth": "Agents form their inflation forecast by working out how others forecast, for a limited number of steps.",
    "disc": "Agents shrink their forecasts of deviations from the steady state, more at longer horizons.",
    "info": "The expectation reacts too little or too much to news.",
    "learn": "Other forecasting rules and learning algorithms take the learners' place.",
    "dist": "Forecasters with a bias, an extra forecasting type, or another way to weight the forecasters.",
}


def span_txt(dates):
    """'2022Q3-2023Q1' for consecutive quarters, else a list."""
    if not dates:
        return ""
    allq = qrange(dates[0], dates[-1])
    if len(dates) > 2 and allq == dates:
        return f"{dates[0]}-{dates[-1]}"
    return joinand(dates)


def path_txt(i):
    return (f"inflation peaks at {pct(num(i, 'pinf_max'), 1)} in {txt(i, 'pinf_max_date')} and is "
            f"{pct(num(i, 'pinf_end'), 1)} in {END}")


def flag_items():
    out = []
    if STOPPED or ERRORS:
        out.append("<b>Stops.</b> " + " ".join(f"{esc(label(i))} {esc(stop_txt(i))}." for i in STOPPED + ERRORS))
    else:
        out.append(f"<b>No run stops.</b> With the {code(FAC)} facility all {len(IDS)} runs reach {END}. The facility "
                   f"acts in {sum(1 for i in IDS if fac_n(i) > 0)} of them, listed next.")
    if LK:
        ids = list(LK)
        d1 = LK[ids[0]]
        same = all(LK[i]["dates"] == d1["dates"] for i in ids)
        bylev = {}
        for q, lv in zip(d1["dates"], d1["levels"]):
            bylev.setdefault(lv, []).append(q)
        fails = "; ".join(f"level {lv} in {span_txt(qs)}" for lv, qs in sorted(bylev.items(), reverse=True))
        evs = (span_txt(d1["dates"]) if same else
               "; ".join(f"{label(i, True)}: {span_txt(LK[i]['dates'])}" for i in ids))
        out.append(f"<b>Level-k ({joinand(label(i, True) for i in ids)}).</b> In {d1['date']} the level-{d1['level']} economy "
                   f"has no stable solution once the learners' persistence passes 1: after that quarter's update the "
                   f"level-0 learners' AR(1) coefficient is {f(d1['beta'], 3)}, and the level-1 forecast loads "
                   f"{f(d1['load'], 3)} on inflation at t-1. Under the facility {code('none')} the run stops there. Under "
                   f"{code(FAC)} the facility returns the learners' beliefs to their value before the update and keeps the "
                   f"previous levels, in {evs} (the economy without a solution: {fails}); after that the beliefs update "
                   f"again. The paths swing widely: " + "; ".join(f"in {label(i, True)} {path_txt(i)}" for i in ids) + ".")
    others = [i for i in IDS if fac_n(i) > 0 and i not in LK]
    for i in others:
        extra = ""
        if two_type(i) and learners_2022(i) is not None and learners_2022(i) > 0.99:
            extra = (f" By the end of {ORIGIN} the learners hold {f(learners_2022(i), 3)} of inflation expectations, and "
                     f"{path_txt(i)}; average inflation is {pct(num(i, 'avg_pinf'))}.")
        out.append(f"<b>Facility, {esc(label(i))}.</b> {esc(fac_txt(i))}.{extra}")
    if ID18 and CDES and CPICK:
        out.append(f"<b>{esc(label(ID18))} is recalibrated.</b> The design's calibration (bias "
                   f"g = sd(y - yf)/2 = {f(CDES['g_value'], 2)} in the RE limit, intensity {fnum(CDES['chi'])}, memory "
                   f"{fnum(CDES['omega'])}) produces a deflation spiral: inflation falls to {pct(CDES['pinf_min'], 1)} and "
                   f"consumption growth swings between {pct(CDES['dc_min'], 0)} and {pct(CDES['dc_max'], 0)} "
                   f"(annualised). This report uses bias {fnum(CPICK['g_value'])}, intensity {fnum(CPICK['chi'])} and "
                   f"memory {fnum(CPICK['omega'])}, the setting closest to De Grauwe's published values that passes the "
                   f"three checks of <a href=\"#calib\">section 7</a>.")
    elif ID18 is None and CDES is not None:
        out.append("<b>Variant 18 is left out.</b> No calibration passed the checks of <a href=\"#calib\">section 7</a>.")
    return out


def summary_table():
    hdr = ["Variant", "Family", "Mechanism", "Key parameters and source", "Average inflation, %",
           "Peak gap to RE(t-1), pp", f"Shares, end of {ORIGIN}", "Facility events", "Stop"]
    rows = []
    for i in IDS:
        r = RUN[i]
        cls = "ref" if i in REFS else ""
        flags = []
        if i in STOPPED:
            flags.append(chip("stops", "rm"))
        if i in LK:
            flags.append(chip("facility at origin"))
        if i == ID18:
            flags.append(chip("recalibrated"))
        name = (f'<span class="no">{esc(r["no"])}</span>{esc(r["name"])}' + ("<br>" + "".join(flags) if flags else ""))
        par = f'{esc(r["params"])}<span class="src">{esc(r["source"])}</span>'
        a = num(i, "avg_pinf")
        g = num(i, "gap_peak")
        gap = "n/a" if g is None else (f"{pp(g)}<br><span class=\"muted\">{esc(txt(i, 'gap_peak_date'))}</span>"
                                       if i != "a1_re" else "0")
        fe = fac_txt(i, True) if fac_n(i) else "none"
        cells = [name, esc(r["family_label"]), esc(r["mechanism"]), par, f(a) if a is not None else "n/a", gap,
                 esc(shares_txt(i)), esc(fe), esc(stop_txt(i))]
        rows.append(f'<tr class="{cls}">' + "".join(
            f'<td class="{"n" if k in (4, 5) else ""}">{c}</td>' for k, c in enumerate(cells)) + "</tr>")
    head = "".join(f"<th>{esc(h)}</th>" for h in hdr)
    return (f'<div class="tw"><table class="sum"><caption>One row per run, in the order of the figures. Average inflation '
            f'(GDP deflator, annualised) over {HOR[0]}-{END}. Peak gap: the variant minus RE(t-1), its largest absolute '
            f'value over the forecast, with the quarter. Shares: the discrete-choice shares at the end of {ORIGIN} for '
            f'switching runs, the fixed shares otherwise. Facility events: quarters in which the {esc(FAC)} facility acts, '
            f'with the history quarters among them.</caption><thead><tr>{head}</tr></thead>'
            f'<tbody>{"".join(rows)}</tbody></table></div>')


# ============================================================================= sections
SEC = []


def section(sid, no, title, body):
    SEC.append((sid, no, title))
    return f'<section id="{sid}">\n<h2><span class="no">{no:02d}</span>{esc(title)}</h2>\n{body}\n</section>\n'


def sec_summary():
    c = rank_txt(VARIANTS)
    b, re_ = num("a1_learn", "avg_pinf"), num("a1_re", "avg_pinf")
    above = [i for i in c if num(i, "avg_pinf") > b]
    lo, hi = c[0], c[-1]
    ans = (f"Across the {len(c)} variants that complete, average inflation over {HOR[0]}-{END} runs from "
           f"{pct(num(lo, 'avg_pinf'))} ({esc(label(lo))}) to {pct(num(hi, 'avg_pinf'))} ({esc(label(hi))}). "
           f"The baseline gives {pct(b)} and RE(t-1) {pct(re_)}; {len(above)} of the {len(c)} variants end up above "
           f"the baseline.")
    fl = "".join(f"<li>{x}</li>" for x in flag_items())
    body = (f'<p class="answer">{ans}</p>\n<aside class="box warn" role="note"><h3>Read these first</h3>'
            f'<ul class="flags">{fl}</ul></aside>\n{summary_table()}')
    return section("summary", 1, "Summary", body)


def sec_family(no, fam, title):
    body = (f'<p class="answer">{fam_answer(fam)}</p>\n'
            f'<p class="famlist">{esc(FAM_INTRO.get(fam, ""))}</p>\n<ul class="mech famlist">{var_list(fam)}</ul>\n'
            f'{family_figure(fam, fam, title)}')
    return section(fam, no, title, body)


def sec_calib(no):
    if CDES is None:
        return ""
    rows = [r for r in CALR if r["tag"] == "design" or int(r["published"]) == 1 or int(r["pass"]) == 1]

    def row(r, pick=False):
        crit = "".join("yes " if int(r[k]) else "no " for k in ("c1", "c2", "c3")).strip().replace(" ", " / ")
        lab = "design (P4)" if r["tag"] == "design" else ("published, converted" if int(r["published"]) else "nearby")
        return (f'<tr class="{"pick" if pick else ""}"><td>{esc(lab)}{" (used)" if pick else ""}</td>'
                f'<td class="n">{g3(r["g_value"])}</td><td class="n">{g3(r["chi"])}</td><td class="n">{g3(r["omega"])}</td>'
                f'<td class="n">{f(r["pinf_min"], 1)} to {f(r["pinf_max"], 1)}</td><td class="n">{f(r["dc_min"], 1)} to {f(r["dc_max"], 1)}</td>'
                f'<td class="n">{f(r["ext_sd"], 3)} / {f(r["ext_corner"], 2)}</td><td class="n">{f(r["pes_sd"], 3)} / {f(r["pes_corner"], 2)}</td>'
                f'<td>{crit}</td></tr>')

    hdr = ["Setting", "Bias g", "Intensity", "Memory", "Inflation, min to max, %", "Consumption growth, min to max, %",
           "EXT share: sd / fraction of quarters at 0 or 1", "PES share: sd / fraction of quarters at 0 or 1",
           "C1 / C2 / C3"]
    head = "".join(f"<th>{esc(h)}</th>" for h in hdr)
    body_rows = "".join(row(r, int(r["chosen"]) == 1) for r in rows)
    allrows = "".join(row(r, int(r["chosen"]) == 1) for r in CALR)
    r0 = CALR[0]
    pub = CPUB
    pk = CPICK
    p1 = (f"The design gave the optimists and pessimists of variant 18 a bias of half the RE limit's standard deviation of "
          f"the output gap and kept the baseline's switching. De Grauwe calibrates in decimal units with months as the "
          f"time unit (CESifo WP 2418, Appendix A: fixed divergence beta = {dg_val('beta')}, variable divergence delta = "
          f"{dg_val('delta')}, intensity gamma = {dg_val('gamma')}, memory rho = {dg_val('rho')}). In this model's units, "
          f"percent and quarters, that is a bias g = beta/2 = {fnum(pub['g_value'])} (a level, so no time conversion; "
          f"delta = 0, the paper's constant-bias case), an intensity of {fnum(pub['chi'])} per squared percentage point, "
          f"and a memory of {fnum(pub['omega'])} per quarter (rho cubed, as a quarter has three months). The search ran {len(CALR) - 1} "
          f"settings around these values plus the design's: bias {joinand(g3(v) for v in sorted({r['g_value'] for r in CALR[1:]}))} "
          f"(the third adds delta times the RE limit's variance of y - yf), intensity "
          f"{joinand(g3(v) for v in sorted({r['chi'] for r in CALR[1:]}))} (1/9 converts the inflation errors from monthly "
          f"to quarterly rates; 2 is the baseline) and memory {joinand(g3(v) for v in sorted({r['omega'] for r in CALR[1:]}))}.")
    p2 = (f"Three checks, fixed before the runs. C1: the run completes. C2: inflation and consumption growth stay inside "
          f"their {f(r0['data_pinf_min'], 1)} to {f(r0['data_pinf_max'], 1)}% and {f(r0['data_dc_min'], 1)} to "
          f"{f(r0['data_dc_max'], 1)}% ranges of 1966Q1-2019Q4 (annualised) in every forecast quarter. C3: in each share "
          f"group the second type's share (EXT for inflation, PES for consumption) is below 0.02 or above 0.98 in at most "
          f"10% of the quarters 1966Q1-{END} and has a standard deviation of at least 0.02. Of the {len(CALR)} settings, "
          f"{NPASS} pass.")
    if pk is not None:
        p3 = (f"The published values, converted, fail C2: consumption growth swings between {pct(pub['dc_min'], 0)} and "
              f"{pct(pub['dc_max'], 0)}. The setting used, the passing one closest to them (fewest values changed, then the "
              f"smallest log distance), is bias {fnum(pk['g_value'])}, intensity {fnum(pk['chi'])} and memory "
              f"{fnum(pk['omega'])}: inflation stays between {pct(pk['pinf_min'], 1)} and {pct(pk['pinf_max'], 1)}, "
              f"consumption growth between {pct(pk['dc_min'], 1)} and {pct(pk['dc_max'], 1)}, and the shares move "
              f"(standard deviation {f(pk['ext_sd'], 3)} for EXT and {f(pk['pes_sd'], 3)} for PES) without sitting at 0 or 1.") \
            if int(pub["pass"]) == 0 else (f"The published values, converted, pass and are used.")
    else:
        p3 = "No setting passes, so variant 18 is left out of this report."
    body = (f"<p>{p1}</p>\n<p>{p2}</p>\n<p>{p3}</p>\n"
            f'<div class="tw"><table class="cal"><caption>The design\'s setting, the converted published values and every '
            f'setting that passes (forecast {HOR[0]}-{END}; shares over 1966Q1-{END}).</caption><thead><tr>{head}</tr></thead>'
            f'<tbody>{body_rows}</tbody></table></div>\n'
            f'<details class="tables"><summary>All {len(CALR)} settings</summary><div class="tw"><table class="cal">'
            f'<thead><tr>{head}</tr></thead><tbody>{allrows}</tbody></table></div></details>')
    return section("calib", no, "Variant 18: calibration search", body)


def sec_notes(no):
    lines = ["% MATLAB, from the project root",
             "run_br_app1('check')                         % options of the 23 scenarios load",
             "run_br_app1('run', {'a1_re', 'a1_learn'})    % the references first",
             "run_br_app1('run', ids)                      % the variants, in up to four sessions (help run_br_app1)",
             "run_br_app1('calib18')                       % the variant-18 search, results/br_portfolio/app1_calib18.csv",
             "run_br_app1('csv')                           % results/br_portfolio/app1_*.csv",
             "",
             "# Python",
             "python reports/build_br_app1_report.py"]
    rt = [num(i, "runtime_s") for i in IDS if num(i, "runtime_s") is not None]
    body = (f"<p>Units: inflation (GDP deflator), the policy rate, output growth and consumption growth in % annualised; "
            f"pp = percentage points. Gap: the variant's inflation minus that of RE(t-1), in each forecast quarter. Shares: "
            f"the discrete-choice share computed at the end of a quarter and in force in the next (switching runs), or the "
            f"shares a mode fixes ({code('learning')}: every agent learns; {code('fixed_shares')}). Facility "
            f"{code(FAC)}: each quarter the model with the new beliefs and shares is solved; if it has no unique stable "
            f"solution, every belief goes back to its value before that quarter's update, and if that does not solve "
            f"either, last quarter's shares stay in force (events {code('projection_alm')}, {code('projection_alm_shares')}); "
            f"a level economy without a solution reverts the beliefs the same way ({code('projection_level')}). "
            f"Scenario files: {code('scenarios/sw07/br_portfolio/')}; runs in {code('results/<id>/')}; tables in "
            f"{code('results/br_portfolio/')}. The {len(IDS)} runs took {f(sum(rt), 0)} s of compute in total.</p>"
            f'<pre class="code"><code>{esc(chr(10).join(lines))}</code></pre>')
    return section("notes", no, "Definitions and reproduction", body)


# ============================================================================= assemble
PARTS = [sec_summary()]
for k, (fam, title) in enumerate(FAMS):
    PARTS.append(sec_family(k + 2, fam, title))
PARTS.append(sec_calib(len(FAMS) + 2))
PARTS.append(sec_notes(len(FAMS) + 3))

n_ok = sum(1 for i in IDS if txt(i, "status") == "ok")
n_fac = sum(1 for i in IDS if fac_n(i) > 0)
toc = "".join(f'<a href="#{sid}"><span class="tn">{no}</span> {esc(t)}</a>' for sid, no, t in SEC)
bl = RUN["a1_learn"]
lede1 = (f"Application 1, the forecast from the {ORIGIN} inflation peak, for each of the {len(VARIANTS)} "
         f"bounded-rationality variants built into hetlearn (docs/DESIGN_br_extensions.md, section 3). Each variant "
         f"is the baseline scenario {code('a1_learn')} with one change to how expectations are formed. Every chart also "
         f"shows the baseline and the RE(t-1) benchmark.")
lede2 = (f"Baseline: the Smets-Wouters (2007) model at its published posterior mode. Inflation expectations mix RE agents, "
         f"who see data up to t-1, and AR(1) learners ({esc(lc1(bl['params']))}). RE values in the history come from the "
         f"one-sided filter. Projection facility {code(FAC)}. The forecast runs {H} quarters, {HOR[0]}-{END}, with zero "
         f"shocks. Variants are grouped by the five families of the literature review behind the design.")
body = f"""
<header class="top wrap">
  <p class="kicker">hetlearn toolbox report · {REPORT_DATE}</p>
  <h1>{len(VARIANTS)} expectation rules at the {ORIGIN} inflation peak</h1>
  <p class="lede">{lede1}</p>
  <p class="lede">{lede2}</p>
  <p class="meta"><span>{REPORT_DATE}</span><span>{len(IDS)} runs, {n_ok} complete{f", {len(IDS) - n_ok} stop" if n_ok < len(IDS) else ""}</span>
  <span>facility {esc(FAC)}: events in {n_fac} run{'s' if n_fac != 1 else ''}</span><span>Inputs: results/br_portfolio/</span></p>
  <nav class="toc" aria-label="Sections">{toc}</nav>
</header>
<main class="wrap">
{"".join(PARTS)}
<footer class="foot"><p>Built by <code>reports/build_br_app1_report.py</code> from <code>results/br_portfolio/app1_*.csv</code> on {REPORT_DATE}.
Charts: hover or focus a chart (arrow keys move along it) for values; every figure has a table view.</p></footer>
</main>
"""


def check_specs():
    bad = []
    for k, c in CHARTS.items():
        sers = c.get("series") or []
        if not sers or not any(v is not None for s in sers for v in s["v"]):
            bad.append(k)
        for s in sers:
            if len(s["v"]) != len(c.get("x", s["v"])):
                bad.append(k + " (length)")
    if bad:
        raise SystemExit(f"charts without data: {bad}")


check_specs()
data_json = json.dumps({"charts": CHARTS, "legends": LEGENDS}, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
data_json = data_json.replace("</", "<\\/")
page = ('<meta charset="utf-8">\n'
        '<title>hetlearn BR portfolio</title>\n'
        '<meta name="claude:viewport-fit-sides" content="cover">\n'
        f'<link rel="stylesheet" href="{FONTS}">\n'
        f"<style>{CSS}{CSS_EXTRA}{CSS_BR}</style>\n"
        f"{body}\n"
        f'<script type="application/json" id="report-data">{data_json}</script>\n'
        f"<script>{JS}</script>\n")
if "—" in page:
    raise SystemExit("em dash in the page")
OUT.write_text(page, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB), {len(CHARTS)} charts, {FIGN[0]} figures, "
      f"{len(IDS)} runs ({n_ok} complete), facility events in {n_fac} runs")
