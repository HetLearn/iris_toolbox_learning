#!/usr/bin/env python3
"""Build reports/sw07_br_portfolio_report.html: impulse responses and in-sample RMSE of the BR portfolio.

    python reports/build_br_portfolio_report.py          (from the project root, or any folder)
    python reports/build_br_portfolio_report.py --inputs DIR --out FILE

A separate page from the main report and from the Application 1 page. It reads only tables in
results/br_portfolio/: irf_long.csv, irf_runs.csv, states_2019Q4.csv, rmse_long.csv, rmse_runs.csv and
irf_check.csv (written by run_br_portfolio.m), and app1_variants.csv (variant names, families, parameters
and sources, written by run_br_app1.m). Every number in the text, the tables and the charts is computed
from them at build time; none is typed. The CSS, the theme tokens (light/dark) and the JS chart engine are
those of build_report_v3.py, read with ast (nothing in that file is executed), as in
build_br_app1_report.py, whose variant colours this page repeats. Writes one page (content only, no
<html>/<head>/<body>: the claude.ai artifact publisher wraps it).
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
_AP = argparse.ArgumentParser(description="Build the BR portfolio IRF and RMSE report from results/br_portfolio/.")
_AP.add_argument("--inputs", default=str(ROOT / "results" / "br_portfolio"), help="folder with the CSV tables")
_AP.add_argument("--out", default=str(ROOT / "reports" / "sw07_br_portfolio_report.html"), help="page to write")
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
# The tab switch below redraws the charts of the figure it shows with the engine's own draw(), so that charts drawn
# while their figure was hidden (at the engine's fallback width) get their panel width at once, without waiting for
# the engine's ResizeObserver and requestAnimationFrame. One line is added after the engine's first draw loop.
_DRAW_AT = "Array.prototype.forEach.call(plots, draw);"
if JS.count(_DRAW_AT) != 1:
    raise SystemExit("chart engine changed: the draw loop to export is not found exactly once")
JS = JS.replace(_DRAW_AT, _DRAW_AT + "\nwindow.__brDraw = draw;")

CSS_BR = r"""
.wrap{padding-left:max(clamp(16px,4vw,44px),env(safe-area-inset-left,0px));padding-right:max(clamp(16px,4vw,44px),env(safe-area-inset-right,0px))}
table.rm{font-size:12.5px}
table.rm td,table.rm th{padding:5px 7px}
table.rm thead th{white-space:normal;vertical-align:bottom}
table.rm thead tr.top th{text-align:center;border-bottom:1px solid var(--rule)}
table.rm td.n{white-space:nowrap;text-align:right}
table.rm td .v{display:block}
table.rm td .r{display:block;font-size:11.5px;color:var(--muted)}
table.rm td .r.sig{color:var(--fg);font-weight:600}
table.rm td:first-child{min-width:200px}
table.rm td .no{font:600 12.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--fg);margin-right:4px}
table.rm td .chip{margin:3px 4px 0 0}
table.rm tr.ref td{background:var(--bg-2)}
table.rm tr.grp td{font-weight:600;color:var(--fg);background:var(--band-2);font-size:12.5px}
table.gates td{white-space:normal}
table.gates td.n{white-space:nowrap}
ul.flags{margin:6px 0 0;padding-left:1.1rem}
ul.flags li{margin-bottom:7px;max-width:88ch}
ul.find{padding-left:1.15rem}
ul.find li{margin-bottom:8px}
.seg.tabs{margin:4px 0 6px}
.seg.tabs button{padding:6px 10px}
p.choose{margin:18px 0 0;font-size:14px;color:var(--ink-2)}
h3.fam{font-size:16.5px;margin:30px 0 4px}
h3.fam .ids{font:500 12.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted);margin-left:6px}
.shockfig .legend{margin-top:6px}
details.full{margin:10px 0 4px;border-top:1px solid var(--rule);padding-top:8px}
details.full summary{cursor:pointer;font-size:14px;color:var(--ink-2);font-weight:600}
details.full summary:hover{color:var(--accent)}
"""

TABS_JS = r"""
(function(){
'use strict';
var bar = document.querySelector('[data-shocktabs]');
if (!bar) return;
var btns = bar.querySelectorAll('button[data-shock]');
var figs = document.querySelectorAll('[data-shockfig]');
function show(s){
  Array.prototype.forEach.call(figs, function(f){ f.hidden = f.getAttribute('data-shockfig') !== s; });
  Array.prototype.forEach.call(btns, function(b){ b.setAttribute('aria-pressed', b.getAttribute('data-shock') === s ? 'true' : 'false'); });
  if (window.__brDraw) Array.prototype.forEach.call(figs, function(f){ if (!f.hidden)
    Array.prototype.forEach.call(f.querySelectorAll('.plot[data-chart]'), window.__brDraw); });
}
Array.prototype.forEach.call(btns, function(b){ b.addEventListener('click', function(){ show(b.getAttribute('data-shock')); }); });
})();
"""


# ============================================================================= inputs
def rd(name, required=True, **kw):
    p = INP / name
    if not p.exists():
        if not required:
            return None
        raise SystemExit(f"missing input {p} (run run_br_portfolio('csv') first; app1_variants.csv: run_br_app1('csv'))")
    return pd.read_csv(p, keep_default_na=True, **kw)


VAR = rd("app1_variants.csv", dtype={"no": str})
IRF = rd("irf_long.csv", dtype={"no": str, "date": str})
IRR = rd("irf_runs.csv", dtype={"no": str, "stop_date": str, "facility_first": str, "facility_last": str,
                                "facility_types": str, "error_id": str, "message": str, "hist_facility_types": str,
                                "hist_facility_first": str, "hist_facility_last": str})
STA = rd("states_2019Q4.csv", dtype={"no": str})
RML = rd("rmse_long.csv", dtype={"no": str, "extra_shock": str})
RMR = rd("rmse_runs.csv", dtype={"no": str, "extra_shock": str, "facility_types": str, "facility_first": str,
                                 "facility_last": str, "model_gap_by_type": str, "error_id": str, "message": str})
CHK = rd("irf_check.csv", required=False)


def nz(x):
    """None for NaN / missing / empty, else the value."""
    if x is None:
        return None
    if isinstance(x, float) and math.isnan(x):
        return None
    if isinstance(x, str) and x.strip() == "":
        return None
    return x


def fl(x):
    x = nz(x)
    return None if x is None else float(x)


RUN = {r["id"]: dict(r) for r in VAR.to_dict("records")}
IDS = [r["id"] for r in sorted(VAR.to_dict("records"), key=lambda d: (d["family_order"], d["order"]))]
REFS = ["a1_re", "a1_learn"]
FAMS = []
for r in sorted(VAR.to_dict("records"), key=lambda d: (d["family_order"], d["order"])):
    if r["family"] != "ref" and r["family"] not in [f for f, _ in FAMS]:
        FAMS.append((r["family"], r["family_label"]))
FAMIDS = {f: [i for i in IDS if RUN[i]["family"] == f] for f, _ in FAMS}
VARIANTS = [i for i in IDS if i not in REFS]
NO = {RUN[i]["no"]: i for i in IDS}
_missing = [i for i in IDS if i not in set(IRR.variant)] + [i for i in IDS if i not in set(RMR.variant)]
if _missing:
    raise SystemExit(f"runs missing from irf_runs.csv / rmse_runs.csv: {sorted(set(_missing))}")


def ids_of(*nos):
    return [NO[n] for n in nos if n in NO]


DISC_ALL = ids_of("4", "5a", "6")          # every forward expectation scaled down (design section 3)
ST7 = ids_of("20", "25a", "25b")           # every agent learns the seven sticky expectations


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


def g3(x):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    return re.sub(r"^-", MINUS, f"{x:.3g}")


def sci(x):
    """A small difference: 0, or two significant digits in e-notation."""
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "n/a"
    if x == 0:
        return "0"
    m, e = f"{x:.1e}".split("e")
    return f"{m}e{MINUS if int(e) < 0 else ''}{abs(int(e))}"


def span(vals, d=2, sign=False):
    vals = [v for v in vals if v is not None]
    if not vals:
        return "n/a"
    lo, hi = min(vals), max(vals)
    if f(lo, d) == f(hi, d):
        return f(lo, d, sign)
    return f"{f(lo, d, sign)} to {f(hi, d, sign)}"


def code(s):
    return f"<code>{esc(s)}</code>"


def joinand(items):
    items = list(items)
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


def label(i, short=False):
    if i == "a1_re":
        return "RE(t-1)"
    if i == "a1_learn":
        return "Baseline"
    r = RUN[i]
    return f"{r['no']}" if short else f"{r['no']} {r['name']}"


def lab_s(i):
    return label(i, True)


def chip(t, cls=""):
    return f'<span class="chip{(" " + cls) if cls else ""}">{esc(t)}</span>'


# ============================================================================= IRF data
SHOCK_ORDER = ["em", "epinf", "ew", "ea", "eb", "eg", "eqs", "e_wpinf", "e_xi"]
SHOCK_WORDS = {"em": "monetary policy", "epinf": "price mark-up", "ew": "wage mark-up", "ea": "technology",
               "eb": "risk premium", "eg": "government spending", "eqs": "investment",
               "e_wpinf": "inflation-expectation wedge", "e_xi": "confidence"}
SHOCK_TAB = {"em": "Monetary", "epinf": "Price mark-up", "ew": "Wage mark-up", "ea": "Technology", "eb": "Risk premium",
             "eg": "Government spending", "eqs": "Investment", "e_wpinf": "Wedge (29)", "e_xi": "Confidence (31)"}
VAR5 = ["pinfobs", "dy", "robs", "dc", "pinf_exp1"]
VLAB = {"pinfobs": "Inflation", "dy": "Output growth", "robs": "Policy rate", "dc": "Consumption growth",
        "pinf_exp1": "Aggregate inflation expectation"}
SHOCKS = [s for s in SHOCK_ORDER if s in set(IRF.shock)]
SW7 = [s for s in SHOCKS if s not in ("e_wpinf", "e_xi")]
HMAX = int(IRF.h.max())
NH = HMAX + 1
XH = [str(h) for h in range(NH)]
DATE0 = IRF[IRF.h == 0].date.iloc[0]
DATE_END = IRF[IRF.h == HMAX].date.iloc[0]

G = {}            # (variant, shock, sign, variable) -> list of value_report (None for NaN)
GST = {}          # (variant, shock, sign) -> status of the rows (shock_not_in_model for the zero rows)
for (v, s, sg, var), d in IRF.groupby(["variant", "shock", "sign", "variable"], sort=False):
    d = d.sort_values("h")
    G[(v, s, int(sg), var)] = [None if (isinstance(x, float) and math.isnan(x)) else float(x) for x in d.value_report]
    GST[(v, s, int(sg))] = str(d.status.iloc[0])

RUNROW = {(r.variant, r.shock, int(r.sign)): r._asdict() for r in IRR.itertuples()}
SD = {}
for r in IRR.itertuples():
    if r.shock != "none" and int(r.sign) == 1 and r.shock not in SD and fl(r.size) is not None:
        SD[r.shock] = float(r.size)
MODE = {i: str(RUN[i]["mode"]) for i in IDS}


def girf(i, s, var, sign=1):
    return G.get((i, s, sign, var))


def has_shock(i, s):
    st = GST.get((i, s, 1))
    return st is not None and st != "shock_not_in_model"


def peak(vals):
    best = None
    for h, x in enumerate(vals or []):
        if x is None:
            continue
        if best is None or abs(x) > abs(best[1]) + 1e-15:
            best = (h, x)
    return best


def share_types(i, lv="pinf"):
    """Types of the switching population whose share rows exist (n_<type>_<lv>)."""
    pre, suf = "n_", f"_{lv}"
    out = []
    for (v, s, sg, var) in G:
        if v == i and s == "em" and sg == 1 and var.startswith(pre) and not var.startswith("n_model_") and var.endswith(suf):
            t = var[len(pre):-len(suf)]
            if t not in out:
                out.append(t)
    return out


def share_vars(i):
    out = []
    for (v, s, sg, var) in G:
        if v == i and s == "em" and sg == 1 and var.startswith("n_") and not var.startswith("n_model_"):
            lv = var.rsplit("_", 1)[1]
            if lv not in out:
                out.append(lv)
    return out


def two_type(i):
    """The non-RE type of a switching run whose inflation population is RE and one other type, else None."""
    ts = share_types(i)
    if len(ts) == 2 and "RE" in ts and len(share_vars(i)) == 1:
        return [t for t in ts if t != "RE"][0]
    return None


def multi_type(i):
    """Switching runs with more than two types, or more than one share group."""
    return MODE.get(i) == "switching" and two_type(i) is None and bool(share_types(i) or share_vars(i))


# ============================================================================= RMSE data
SAMPLES = [("full", "1966Q1-2026Q2"), ("y1966_1983", "1966-1983"), ("y1984_2007", "1984-2007"),
           ("y2008_2019", "2008-2019"), ("y2020Q4_2026Q2", "2020Q4-2026Q2")]
SLAB = dict(SAMPLES)
OBS7 = ["dy", "dc", "dinve", "dw", "labobs", "pinfobs", "robs"]
OLAB = {"dy": "Output growth", "dc": "Consumption growth", "dinve": "Investment growth", "dw": "Real wage growth",
        "labobs": "Hours", "pinfobs": "Inflation", "robs": "Policy rate"}
OUNIT = {"labobs": "100 x log"}
RM = {(r.variant, r.sample, r.variable): r._asdict() for r in RML.itertuples()}
RR = {r.variant: r._asdict() for r in RMR.itertuples()}
SFIRST = {s: str(RML[RML["sample"] == s]["first"].iloc[0]) for s, _ in SAMPLES}
SLAST = {s: str(RML[RML["sample"] == s]["last"].iloc[0]) for s, _ in SAMPLES}


def rm(i, s, var, k):
    r = RM.get((i, s, var))
    return None if r is None else fl(r.get(k))


def rok(i):
    return str(RR[i]["status"]) == "ok"


def ll(i, s="full"):
    return rm(i, s, "pinfobs", "loglik")


def lld(i, s="full"):
    return rm(i, s, "pinfobs", "loglik_minus_baseline")


WEDGE = [i for i in IDS if nz(RR[i].get("extra_shock"))]
GAP = [i for i in IDS if (fl(RR[i].get("model_gap_max")) or 0) > 1e-8]
FACR = [i for i in IDS if (fl(RR[i].get("facility_events")) or 0) > 0]
RSTOP = [i for i in IDS if not rok(i)]


def gaps_of(i):
    """[(type, gap)] above rounding, from model_gap_by_type ('RE 0; ADA 0.205; ...')."""
    out = []
    for part in str(RR[i].get("model_gap_by_type") or "").split(";"):
        bits = part.strip().split(" ")
        if len(bits) == 2:
            try:
                g = float(bits[1])
            except ValueError:
                continue
            if g > 1e-8:
                out.append((bits[0], g))
    return sorted(out, key=lambda t: -t[1])


def irf_fac(i):
    return int(IRR[IRR.variant == i].facility_events.fillna(0).sum())


def irf_hfac(i):
    """Facility events of the history stage up to 2019Q4 (the starting state of every IRF run of i)."""
    d = IRR[(IRR.variant == i) & (IRR.shock == "none")]
    if not len(d) or "hist_facility_events" not in d:
        return 0, "", "", ""
    r = d.iloc[0]
    return (int(fl(r.hist_facility_events) or 0), str(nz(r.hist_facility_types) or ""), str(nz(r.hist_facility_first) or ""),
            str(nz(r.hist_facility_last) or ""))


FACI = [i for i in IDS if irf_fac(i) > 0]
FACH = [i for i in IDS if irf_hfac(i)[0] > 0]
ISTOP = sorted({(r.variant, r.shock, int(r.sign)) for r in IRR.itertuples() if str(r.status) != "ok"},
               key=lambda k: (IDS.index(k[0]), k[1], -k[2]))

# ============================================================================= entities and colours (as the Application 1 page)
ENT = {"a1_re": dict(name="RE(t-1) benchmark", short="RE(t-1)", color="s1"),
       "a1_learn": dict(name="Baseline (RE agents and AR(1) learners)", short="Baseline", color="s2")}
SLOTS = ["s3", "s4", "s5", "s6", "s7", "s8"]
HUE_LEAD = {"1b": "1a", "5b": "5a", "25a": "20", "25b": "20", "24": "23", "33": "19", "31": "29"}
HUE_WHY = {"1a": "level-k reasoning", "5a": "cognitive discounting", "20": "every agent learns the seven sticky expectations",
           "23": "learners of a mean", "19": "a fixed forecasting rule beside the RE agents", "29": "an AR(1) wedge on expectations"}
STYLES = ["solid", "dashed", "dotted"]
DASHES = ["solid", "dashed", "dotted", "dashdot"]
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
    spec = dict(id=cid, group=group, title=title, x=x, series=ser, origin=None, xcat=True, xpre="h = ", xHead="Horizon",
                ml=ML, mr=12, endLabels=False, h=190, zero=True, dec=3)
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


# ============================================================================= IRF figures
def clean(vals, d=4):
    return [None if x is None else round(x, d) for x in vals]


def offscale(sers):
    """Series that would flatten the rest: max |value| more than 6 times that of every other series and above
    0.05. Returns (names of the off-scale series, y-range of the rest or None)."""
    mx = {s["name"]: max([abs(x) for x in s["v"] if x is not None] or [0]) for s in sers}
    off = []
    for s in sers:
        others = [mx[t["name"]] for t in sers if t is not s and t["name"] not in off]
        if others and mx[s["name"]] > 0.05 and mx[s["name"]] > 6 * max(others):
            off.append(s["name"])
    if not off:
        return [], None
    rest = [x for s in sers if s["name"] not in off for x in s["v"] if x is not None] + [0.0]
    lo, hi = min(rest), max(rest)
    pad = 0.08 * (hi - lo or 1.0)
    return off, [lo - pad, hi + pad]


def pk_txt(i, vals, d=3):
    p = peak(vals)
    if p is None:
        return f"{lab_s(i)} n/a"
    return f"{lab_s(i)} {f(p[1], d, sign=True)} (h = {p[0]})"


def stop_note(i, s):
    r = RUNROW.get((i, s, 1))
    if r is None or str(r["status"]) == "ok":
        return ""
    n = int(fl(r["n_solved"]) or 0)
    return (f" {lab_s(i)} stops in {r['stop_date']} ({esc(str(r['error_id']))}); its line ends after {n} quarter"
            f"{'s' if n != 1 else ''}.")


def main_panel(gid, s, fam, var, ids):
    refs = [i for i in REFS if girf(i, s, var) is not None]
    vs = [i for i in ids if girf(i, s, var) is not None]
    ser = []
    for i in refs + vs:
        sv = S(i, clean(girf(i, s, var)))
        r = RUNROW.get((i, s, 1))
        known = [k for k, x in enumerate(sv["v"]) if x is not None]
        if r is not None and str(r["status"]) != "ok" and known:
            sv["rings"] = [known[-1]]
        ser.append(sv)
    kw = {}
    off, yr = offscale(ser)
    vp = [i for i in vs if peak(girf(i, s, var)) is not None]
    cap = "Peak: " + "; ".join(pk_txt(i, girf(i, s, var)) for i in refs)
    if len(vp) <= 3:
        cap += "".join(f"; {pk_txt(i, girf(i, s, var))}" for i in vp)
    elif vp:
        lo = min(vp, key=lambda i: abs(peak(girf(i, s, var))[1]))
        hi = max(vp, key=lambda i: abs(peak(girf(i, s, var))[1]))
        cap += (f"; largest among these variants {pk_txt(hi, girf(hi, s, var))}, smallest "
                f"{pk_txt(lo, girf(lo, s, var))}")
    cap += "."
    if s in ("e_wpinf", "e_xi"):
        cap += " The references have no such shock, so their lines are 0."
    if off:
        kw["yr"] = yr
        for nm in off:
            i = next(k for k in refs + vs if ENT[k]["name"] == nm)
            xs = [x for x in girf(i, s, var) if x is not None]
            cap += f" {lab_s(i)} leaves the scale ({f(min(xs), 2)} to {f(max(xs), 2)}; values in the table view)."
    for i in vs:
        cap += stop_note(i, s)
    return chart(f"{gid}-{fam}-{var}", gid, f"{VLAB[var]}, response in pp (annualised)", cap, XH, ser, legend=False, **kw)


def share_panel(gid, s, fam, ids):
    two = [i for i in ids if two_type(i)]
    ser = []
    if girf("a1_learn", s, "n_BR_pinf") is not None:
        ser.append(S("a1_learn", clean(girf("a1_learn", s, "n_BR_pinf")), name="Baseline: AR(1) learners"))
    for i in two:
        t = two_type(i)
        ser.append(S(i, clean(girf(i, s, f"n_{t}_pinf")), name=f"{lab_s(i)}: {t}"))
    if not ser:
        return ""
    who = [f"{t} in {lab_s(i)}" for i in two for t in [two_type(i)] if t != "BR"]
    pieces = [pk_txt("a1_learn", girf("a1_learn", s, "n_BR_pinf"), 2)] + [
        pk_txt(i, girf(i, s, f"n_{two_type(i)}_pinf"), 2) for i in two]
    cap = ("Change in the end-of-quarter share of the type beside the RE agents (the AR(1) learners"
           + (f"; {joinand(who)}" if who else "") + "), the share in force in the next quarter. Largest change: "
           + "; ".join(pieces) + ". RE(t-1) has no learners.")
    if s in ("e_wpinf", "e_xi"):
        cap += " The baseline has no such shock (0)."
    others = [i for i in ids if MODE.get(i) != "switching"]
    if others:
        cap += f" No share line for {joinand(lab_s(i) for i in others)}: shares fixed, or every agent learns."
    multi = [i for i in ids if multi_type(i)]
    if multi:
        cap += f" {joinand(lab_s(i) for i in multi)}: own panel{'s' if len(multi) > 1 else ''}."
    return chart(f"{gid}-{fam}-sh", gid, "Learners' share, response in pp of the population", cap, XH, ser,
                 legend=False, dec=3)


def multi_panels(gid, s, fam, ids):
    out = []
    for i in ids:
        if not multi_type(i):
            continue
        for lv in share_vars(i):
            ts = share_types(i, lv)
            ser = [S(i, clean(girf(i, s, f"n_{t}_{lv}")), name=t, short=t, style=DASHES[k % len(DASHES)])
                   for k, t in enumerate(ts) if girf(i, s, f"n_{t}_{lv}") is not None]
            if not ser:
                continue
            what = "inflation expectations" if lv == "pinf" else "the consumption expectation"
            parts = []
            for t in ts:
                p = peak(girf(i, s, f"n_{t}_{lv}"))
                if p is not None:
                    parts.append(f"{t} {f(p[1], 2, sign=True)} (h = {p[0]})")
            cap = (f"Change in the end-of-quarter share of each of the {len(ts)} types in {what}; one line style per type. "
                   f"Largest change: " + "; ".join(parts) + ".")
            nm = "inflation" if lv == "pinf" else ("consumption" if lv == "c" else lv)
            out.append(chart(f"{gid}-{fam}-sh-{RUN[i]['no']}-{lv}", gid,
                             f"{lab_s(i)}: type shares, {nm}, response in pp of the population", cap, XH, ser, dec=3))
    return out


def family_block(gid, s, fam, title, ids):
    if not ids:
        return ""
    items = [leg("a1_re"), leg("a1_learn")] + [leg(i) for i in ids]
    panels = [main_panel(gid, s, fam, v, ids) for v in VAR5]
    sp = share_panel(gid, s, fam, ids)
    if sp:
        panels.append(sp)
    panels += multi_panels(gid, s, fam, ids)
    grp = {lead: g for lead, g in HUE_GROUPS.get(fam, {}).items() if all(k in ids for k in g)}
    note = ""
    if grp:
        note = ('<p class="cap">Variants drawn in one hue share a mechanism and differ by line style: ' + esc("; ".join(
            f"{joinand(lab_s(i) for i in g)} ({HUE_WHY.get(lead, 'same mechanism')})" for lead, g in grp.items())) + ".</p>")
    return (f'<h3 class="fam">{esc(title)}<span class="ids">{esc(", ".join(lab_s(i) for i in ids))}</span></h3>\n'
            f'{legend(f"lg-{s}-{fam}", items)}\n{note}<div class="grid g-3">{"".join(panels)}</div>\n')


def shock_figure(s, first):
    gid = f"irf-{s}"
    sd = SD.get(s)
    who = ""
    if s in ("e_wpinf", "e_xi"):
        own = [i for i in VARIANTS if has_shock(i, s)]
        who = f"; the shock exists only in {joinand(label(i) for i in own)}"
    t = (f"Responses to a one-standard-deviation {SHOCK_WORDS.get(s, s)} shock ({code(s)}, {f(sd, 3)} in model units"
         f"{who}) in {DATE0}, from each variant's own 2019Q4 state: shocked minus unshocked path, h = 0 ({DATE0}) to "
         f"h = {HMAX} ({DATE_END}). Inflation, growth rates, the policy rate and the inflation expectation in pp of "
         f"annualised rates; shares in percentage points of the population.")
    blocks = []
    if s in ("e_wpinf", "e_xi"):
        blocks.append(family_block(gid, s, "dist", dict(FAMS)["dist"], [i for i in FAMIDS["dist"] if has_shock(i, s)]))
    else:
        for fam, title in FAMS:
            blocks.append(family_block(gid, s, fam, title, FAMIDS[fam]))
    hid = "" if first else " hidden"
    return f'<div class="shockfig" data-shockfig="{s}"{hid}>\n{fig_title(t)}\n{"".join(blocks)}\n{tables(gid)}\n</div>\n'


# ============================================================================= IRF metrics for the prose
def cum(i, s, var):
    v = girf(i, s, var)
    if v is None or any(x is None for x in v):
        return None
    return sum(v)


def imp(i, s, var):
    v = girf(i, s, var)
    return None if v is None or v[0] is None else v[0]


def rcum(i, s, var):
    a, b = cum(i, s, var), cum("a1_learn", s, var)
    if a is None or b is None or abs(b) < 1e-9:
        return None
    return a / b


def departure(i):
    """Mean over the 7 SW07 shocks and the 4 observables of sum_h |GIRF_i - GIRF_baseline| / sum_h |GIRF_baseline|."""
    vals = []
    for s in SW7:
        for var in ("pinfobs", "dy", "robs", "dc"):
            a, b = girf(i, s, var), girf("a1_learn", s, var)
            if a is None or b is None or any(x is None for x in a + b):
                continue
            den = sum(abs(x) for x in b)
            if den > 1e-9:
                vals.append(sum(abs(x - y) for x, y in zip(a, b)) / den)
    return sum(vals) / len(vals) if vals else None


DEP = {i: departure(i) for i in VARIANTS + ["a1_re"]}
DEP_RANK = sorted([i for i in VARIANTS if DEP[i] is not None], key=lambda i: -DEP[i])


def irf_findings():
    out = []
    bl = "a1_learn"
    if "em" in SHOCKS and DISC_ALL:
        r = [rcum(i, "em", "pinfobs") for i in DISC_ALL]
        word = ("barely move inflation" if max(r) < 0.1 else
                "move inflation much less than the baseline" if max(r) < 0.5 else "move inflation")
        out.append(f"After a monetary policy shock, the variants that scale down every forward expectation "
                   f"({joinand(lab_s(i) for i in DISC_ALL)}) {word}: summed over the {NH} quarters, the inflation response "
                   f"is {span(r)} times the baseline's ({f(cum(bl, 'em', 'pinfobs'))} pp). The impact response of output "
                   f"growth is {span([imp(i, 'em', 'dy') for i in DISC_ALL])} pp, against {f(imp(bl, 'em', 'dy'))} pp in the "
                   f"baseline, and the policy rate stays up longer: its response sums to "
                   f"{span([cum(i, 'em', 'robs') for i in DISC_ALL], 1)} pp, against {f(cum(bl, 'em', 'robs'), 1)} pp.")
    if "em" in SHOCKS and "epinf" in SHOCKS and ST7:
        r = [rcum(i, "epinf", "pinfobs") for i in ST7]
        h17 = ids_of("17")
        tail = (f" The four heuristics of 17 give {f(rcum(h17[0], 'epinf', 'pinfobs'))} times."
                if h17 and rcum(h17[0], "epinf", "pinfobs") is not None else "")
        out.append(f"When every agent learns all seven sticky-price expectations ({joinand(lab_s(i) for i in ST7)}), output "
                   f"reacts less on impact and inflation reacts more to cost shocks. The impact response of output growth to "
                   f"the monetary shock is {span([imp(i, 'em', 'dy') for i in ST7])} pp (baseline "
                   f"{f(imp(bl, 'em', 'dy'))}), and the inflation response to a price mark-up shock sums to {span(r)} times "
                   f"the baseline's.{tail}")
    de = ids_of("10")
    if de and "em" in SHOCKS and "eb" in SHOCKS:
        i = de[0]
        a, b = imp(i, "em", "dy"), imp(i, "eb", "dy")
        a0, b0 = imp(bl, "em", "dy"), imp(bl, "eb", "dy")
        out.append(f"Diagnostic expectations (10) amplify the impact of demand shocks on output: output growth moves by "
                   f"{f(a)} pp on impact after the monetary shock and by {f(b, sign=True)} pp after the risk premium shock, "
                   f"{f(a / a0)} and {f(b / b0)} times the baseline's ({f(a0)} and {f(b0, sign=True)}).")
    rev = []
    k25 = ids_of("25b")
    if k25 and "em" in SHOCKS:
        i = k25[0]
        pe, pi = peak(girf(i, "em", "pinf_exp1")), peak(girf(i, "em", "pinfobs"))
        pb = peak(girf(bl, "em", "pinf_exp1"))
        if pe and pi and pb and pe[1] > 0 > pb[1]:
            rev.append(f"in 25b, where two of the five averaged models have the lagged policy rate as a regressor, a "
                       f"contractionary monetary shock raises the inflation expectation ({f(pe[1], 3, sign=True)} pp at "
                       f"h = {pe[0]}) and inflation ({f(pi[1], 3, sign=True)} pp at h = {pi[0]})")
    k18 = ids_of("18")
    if k18 and "eb" in SHOCKS:
        i = k18[0]
        p0, pk_ = imp(i, "eb", "dy"), peak(girf(i, "eb", "dy"))
        sh = peak(girf(i, "eb", "n_PES_c"))
        if pk_ and p0 is not None and pk_[1] * p0 < 0:
            rev.append(f"in 18, the output response to a risk premium shock turns around late in the horizon "
                       f"({f(p0, 2, sign=True)} pp on impact, {f(pk_[1], 2, sign=True)} pp at h = {pk_[0]})"
                       + (f", while the pessimists' share of the consumption expectation moves by "
                          f"{f(sh[1], 1, sign=True)} pp (h = {sh[0]})" if sh else ""))
    if rev:
        out.append("Two responses change sign: " + "; ".join(rev) + ".")
    zero = [i for i in IDS if all(imp(i, s, "pinf_exp1") is not None and abs(imp(i, s, "pinf_exp1")) < 1e-9 for s in SW7)]
    ep = [imp(i, "epinf", "pinfobs") for i in IDS if imp(i, "epinf", "pinfobs") is not None] if "epinf" in SHOCKS else []
    blsh = [(abs(peak(girf(bl, s, "n_BR_pinf"))[1]), s, peak(girf(bl, s, "n_BR_pinf"))) for s in SW7
            if peak(girf(bl, s, "n_BR_pinf"))]
    txt = (f"No inflation expectation moves on impact: the aggregate expectation's impact response is 0 in "
           f"{len(zero)} of the {len(IDS)} runs for every shock, because every inflation forecast in the portfolio uses "
           f"data up to t-1.")
    if ep:
        txt += f" On impact, a price mark-up shock moves inflation by {span(ep, 3)} pp across the {len(ep)} runs."
    if blsh:
        m = max(blsh)
        txt += (f" The switching shares move little: the baseline learners' share changes by at most {f(m[2][1], 2, sign=True)} pp "
                f"({SHOCK_WORDS[m[1]]} shock, h = {m[2][0]}).")
    out.append(txt)
    return out


# ============================================================================= RMSE findings
def count_better(var, smp="full"):
    vs = [i for i in VARIANTS if rok(i) and rm(i, smp, var, "rel_baseline") is not None]
    lower = [i for i in vs if rm(i, smp, var, "rel_baseline") < 1]
    sig_lower = [i for i in lower if (rm(i, smp, var, "dm_p") or 1) < 0.10]
    sig_higher = [i for i in vs if rm(i, smp, var, "rel_baseline") > 1 and (rm(i, smp, var, "dm_p") or 1) < 0.10]
    best = min(vs, key=lambda i: rm(i, smp, var, "rel_baseline")) if vs else None
    worst = max(vs, key=lambda i: rm(i, smp, var, "rel_baseline")) if vs else None
    return dict(n=len(vs), lower=lower, sig_lower=sig_lower, sig_higher=sig_higher, best=best, worst=worst, vs=vs)


def rmse_sentence(var, smp="full"):
    c = count_better(var, smp)
    b = rm("a1_learn", smp, var, "rmse_report")
    re_ = rm("a1_re", smp, var, "rel_baseline")
    nq = int(rm("a1_learn", smp, var, "n") or 0)
    s = (f"{OLAB[var]}, {SLAB[smp]} ({nq} quarters): the baseline's RMSE is {f(b, 3)} pp and RE(t-1)'s is {f(re_, 3)} "
         f"times that. {len(c['lower'])} of the {c['n']} variants have smaller errors than the baseline, "
         f"{len(c['sig_lower']) or 'none'} of them with a DM p-value below 0.10"
         + (f" ({joinand(lab_s(i) for i in c['sig_lower'])})" if 0 < len(c['sig_lower']) <= 8 else "")
         + f"; {len(c['sig_higher'])} have significantly larger errors"
         + (f" ({joinand(lab_s(i) for i in c['sig_higher'])})" if 0 < len(c['sig_higher']) <= 8 else "")
         + f". Smallest: {label(c['best'])} ({f(rm(c['best'], smp, var, 'rel_baseline'), 3)} of the baseline); largest: "
           f"{label(c['worst'])} ({f(rm(c['worst'], smp, var, 'rel_baseline'), 3)}).")
    return s


def rmse_findings():
    out = [rmse_sentence("pinfobs"), rmse_sentence("dy"), rmse_sentence("robs")]
    if DISC_ALL:
        out.append(f"Smaller inflation errors can come with larger errors elsewhere: {joinand(lab_s(i) for i in DISC_ALL)} "
                   f"have inflation RMSEs of {span([rm(i, 'full', 'pinfobs', 'rel_baseline') for i in DISC_ALL], 3)} times "
                   f"the baseline's, but output-growth RMSEs of {span([rm(i, 'full', 'dy', 'rel_baseline') for i in DISC_ALL], 3)} "
                   f"times and log likelihoods {span([-lld(i) for i in DISC_ALL], 0)} below it.")
    better = sorted([i for i in VARIANTS if rok(i) and i not in WEDGE and (lld(i) or -1) > 0], key=lambda i: -lld(i))
    b = ll("a1_learn")
    txt = (f"Log likelihood, {SLAB['full']}: baseline {f(b, 1)}, RE(t-1) {f(ll('a1_re'), 1)}. Without an extra shock, "
           f"{len(better)} variants fit better than the baseline by this measure: "
           + joinand(f"{lab_s(i)} ({f(lld(i), 1, sign=True)})" for i in better) + ".")
    if ST7:
        txt += (f" The variants with the smallest output-growth errors, {joinand(lab_s(i) for i in ST7)} "
                f"({span([rm(i, 'full', 'dy', 'rel_baseline') for i in ST7], 3)} of the baseline), have log likelihoods "
                f"{span([-lld(i) for i in ST7], 0)} below it.")
    out.append(txt)
    c = count_better("pinfobs", "y2020Q4_2026Q2")
    nq = int(rm("a1_learn", "y2020Q4_2026Q2", "pinfobs", "n") or 0)
    out.append(f"After the covid gap ({SLAB['y2020Q4_2026Q2']}, {nq} quarters) {len(c['lower'])} of the {c['n']} variants "
               f"have smaller inflation errors than the baseline (RMSE {f(rm('a1_learn', 'y2020Q4_2026Q2', 'pinfobs', 'rmse_report'), 3)} pp), "
               f"{len(c['sig_lower']) or 'none'} of them significantly; the ratios run from "
               f"{f(min(rm(i, 'y2020Q4_2026Q2', 'pinfobs', 'rel_baseline') for i in c['vs']), 3)} to "
               f"{f(max(rm(i, 'y2020Q4_2026Q2', 'pinfobs', 'rel_baseline') for i in c['vs']), 3)}.")
    return out


# ============================================================================= flags
def flag_items(short=False):
    out = []
    if WEDGE:
        w = []
        for i in WEDGE:
            xs = str(RR[i]["extra_shock"]).split(" ")[0]
            w.append(f"{esc(lab_s(i) if short else label(i))} ({code(xs)}, std {f(fl(RR[i]['extra_shock_std']), 3)}: log "
                     f"likelihood {f(lld(i), 1, sign=True)} against the baseline, inflation RMSE "
                     f"{f(rm(i, 'full', 'pinfobs', 'rel_baseline'), 3)} of the baseline's)")
        if short:
            out.append(f"<b>Extra shock ({joinand(lab_s(i) for i in WEDGE)}).</b> One more source of variance in the "
                       f"filter, so their rows are not like-for-like; read them with the log likelihood.")
        else:
            out.append(f"<b>Extra shock, not like-for-like.</b> {joinand(w)}. The filter can attribute part of each "
                       f"prediction error to the belief shock, so these rows do not compare like for like with the others. "
                       f"The log likelihood accounts for the larger predicted variance; the RMSE does not.")
    if GAP:
        g = [f"{esc(lab_s(i))}: " + ", ".join(f"{t} {g3(v)}" for t, v in gaps_of(i)) for i in GAP]
        rest = max(fl(RR[i]['model_gap_max']) or 0 for i in IDS if i not in GAP)
        if short:
            out.append(f"<b>Model gap ({joinand(lab_s(i) for i in GAP)}).</b> In their Kalman histories the forecasts in the "
                       f"model differ from the ones the agents score, by up to "
                       f"{g3(max(fl(RR[i]['model_gap_max']) for i in GAP))} percentage points (model units, % per quarter).")
        else:
            out.append(f"<b>Model gap ({joinand(lab_s(i) for i in GAP)}).</b> These types forecast with data of two dates "
                       f"(for example x(t-1) and x(t-2), or their own last forecast). In the Kalman history the model's "
                       f"lagged states are the filter's revised estimates while the agents use the real-time values, so the "
                       f"forecasts in the model the filter runs differ from the forecasts the agents record and score. "
                       f"Largest gap by type, in percentage points of model units (% per quarter): {'; '.join(g)}. In every other run the gap is rounding (at most "
                       f"{sci(rest)}).")
    if FACR:
        fac = [f"{esc(lab_s(i))} {int(fl(RR[i]['facility_events']))} ({esc(str(RR[i]['facility_types']))}, "
               f"{RR[i]['facility_first']} to {RR[i]['facility_last']})" for i in FACR]
        if short:
            out.append(f"<b>Facility events.</b> Kalman histories: " + ", ".join(
                f"{esc(lab_s(i))} {int(fl(RR[i]['facility_events']))}" for i in FACR) + ". "
                + ("Impulse-response starting states: " + ", ".join(f"{esc(lab_s(i))} {irf_hfac(i)[0]}" for i in FACH) + ". "
                   if FACH else "")
                + ("None in the impulse-response forecasts." if not FACI else
                   "Impulse-response forecasts: " + ", ".join(f"{esc(lab_s(i))} {irf_fac(i)}" for i in FACI) + "."))
        else:
            out.append(f"<b>Facility events in the Kalman histories</b> (baseline facility {code('alm')}): {joinand(fac)}. "
                       f"In each of those quarters the model with the updated beliefs, or for {code('projection_level')} one "
                       f"of the level economies, had no stable solution, and the facility returned the beliefs to their "
                       f"values before the update.")
    elif not short:
        out.append("<b>Facility.</b> No facility event in the Kalman history of any run.")
    if not short:
        if FACH:
            hh = []
            for i in FACH:
                n, t, a, b = irf_hfac(i)
                hh.append(f"{esc(lab_s(i))} {n} ({esc(t)}, {a} to {b})")
            out.append(f"<b>Facility events before the impulse responses.</b> In the history stage up to 2019Q4, which sets "
                       f"the state every impulse response starts from: {joinand(hh)}.")
        if FACI:
            out.append(f"<b>Facility events in the impulse-response forecasts.</b> " + "; ".join(
                f"{esc(lab_s(i))} {irf_fac(i)}" for i in FACI) + " (summed over the unshocked and shocked runs; irf_runs.csv "
                "lists them by run).")
        else:
            out.append("<b>No facility event in the impulse-response forecasts.</b> From the 2019Q4 states the model solves "
                       "in every quarter of every shocked and unshocked forecast.")
    if ISTOP or RSTOP:
        out.append("<b>Stops.</b> " + "; ".join(
            [f"{esc(lab_s(v))} {s} {'+' if g > 0 else MINUS}1 sd: {esc(str(RUNROW[(v, s, g)]['status']))} in "
             f"{RUNROW[(v, s, g)]['stop_date']}" for v, s, g in ISTOP]
            + [f"{esc(label(i))} (Kalman history): {esc(str(RR[i]['status']))}" for i in RSTOP]) + ".")
    else:
        out.append(f"<b>No run stops.</b> All {len(IRR[IRR.shock != 'none'])} shocked forecasts, the {len(IDS)} unshocked "
                   f"ones and the {len(IDS)} Kalman histories reach their end.")
    return out


# ============================================================================= sections
SEC = []


def section(sid, no, title, body):
    SEC.append((sid, no, title))
    return f'<section id="{sid}">\n<h2><span class="no">{no:02d}</span>{esc(title)}</h2>\n{body}\n</section>\n'


def rel_line(i, smp, var):
    if i == "a1_learn":
        return '<span class="r">baseline</span>'
    rel = rm(i, smp, var, "rel_baseline")
    p = rm(i, smp, var, "dm_p")
    sig = p is not None and p < 0.10
    return f'<span class="r{" sig" if sig else ""}">{f(rel, 3)} ({f(p, 2)}){" *" if sig else ""}</span>'


def relcell(i, smp, var):
    v = rm(i, smp, var, "rmse_report")
    if v is None:
        return "n/a"
    return f'<span class="v">{f(v, 3)}</span>{rel_line(i, smp, var)}'


def fullcell(i, smp, var):
    v = rm(i, smp, var, "rmse_report")
    if v is None:
        return "n/a"
    re_ = '<span class="r">RE(t-1)</span>' if i == "a1_re" else f'<span class="r">{f(rm(i, smp, var, "rel_re"), 3)}</span>'
    return f'<span class="v">{f(v, 3)}</span>{rel_line(i, smp, var)}{re_}'


def flag_chips(i):
    c = []
    if i in WEDGE:
        c.append(chip("extra shock"))
    if i in GAP:
        c.append(chip(f"model gap {g3(fl(RR[i]['model_gap_max']))}"))
    if i in FACR:
        c.append(chip(f"facility {int(fl(RR[i]['facility_events']))}"))
    if i in RSTOP:
        c.append(chip("stops", "rm"))
    return "<br>" + "".join(c) if c else ""


def name_cell(i):
    if i in REFS:
        return f'<span class="no">{esc(label(i))}</span>{flag_chips(i)}'
    return f'<span class="no">{esc(RUN[i]["no"])}</span>{esc(RUN[i]["name"])}{flag_chips(i)}'


def ll_cell(i, smp):
    v, d = ll(i, smp), lld(i, smp)
    if v is None:
        return "n/a"
    if i == "a1_learn":
        return f'<span class="v">{f(v, 1)}</span><span class="r">baseline</span>'
    return f'<span class="v">{f(v, 1)}</span><span class="r">{f(d, 1, sign=True)}</span>'


def grouped_rows(cells_of, ncols):
    rows = []
    for i in REFS:
        rows.append(f'<tr class="ref"><td>{name_cell(i)}</td>{cells_of(i)}</tr>')
    for fam, title in FAMS:
        rows.append(f'<tr class="grp"><td colspan="{ncols}">{esc(title)}</td></tr>')
        for i in FAMIDS[fam]:
            rows.append(f'<tr><td>{name_cell(i)}</td>{cells_of(i)}</tr>')
    return "".join(rows)


def main_rmse_table():
    MAINV = ["pinfobs", "dy", "robs"]
    MAINS = ["full", "y2020Q4_2026Q2"]
    top = "".join(f'<th colspan="{len(MAINS)}">{esc(OLAB[v])}</th>' for v in MAINV)
    sub = "".join(f"<th>{esc(SLAB[s])}</th>" for v in MAINV for s in MAINS)

    def cells(i):
        c = "".join(f'<td class="n">{relcell(i, s, v)}</td>' for v in MAINV for s in MAINS)
        return c + "".join(f'<td class="n">{ll_cell(i, s)}</td>' for s in MAINS)

    ncols = 1 + len(MAINV) * len(MAINS) + len(MAINS)
    head = (f'<thead><tr class="top"><th rowspan="2">Variant</th>{top}<th colspan="{len(MAINS)}">Log likelihood</th></tr>'
            f'<tr>{sub}{"".join(f"<th>{esc(SLAB[s])}</th>" for s in MAINS)}</tr></thead>')
    cap = ("One-step-ahead RMSE in pp of annualised rates (first line); below it the ratio to the baseline's RMSE with the "
           "Diebold-Mariano p-value against the baseline in brackets, * p &lt; 0.10. A ratio below 1 means smaller errors "
           "than the baseline. Log likelihood: the sum of the one-step log densities of all seven observables over the "
           "sample; below it the difference to the baseline. Chips: extra shock (not like-for-like), model gap (largest, "
           "% per quarter), facility (quarters in which the facility acts in the Kalman history).")
    return (f'<div class="tw"><table class="rm"><caption>{cap}</caption>{head}<tbody>{grouped_rows(cells, ncols)}'
            f'</tbody></table></div>')


def full_rmse_table(smp):
    top = "".join(f"<th>{esc(OLAB[v])}{' (' + OUNIT[v] + ')' if v in OUNIT else ''}</th>" for v in OBS7)

    def cells(i):
        return f'<td class="n">{ll_cell(i, smp)}</td>' + "".join(f'<td class="n">{fullcell(i, smp, v)}</td>' for v in OBS7)

    n = int(rm("a1_learn", smp, "pinfobs", "n") or 0)
    head = f'<thead><tr><th>Variant</th><th>Log likelihood</th>{top}</tr></thead>'
    cap = (f"{esc(SLAB[smp]) + ': ' if SLAB[smp] != SFIRST[smp] + '-' + SLAST[smp] else ''}{SFIRST[smp]}-{SLAST[smp]}, {n} one-step errors per observable. Each cell: the RMSE (pp of "
           f"annualised rates; hours in 100 x log), the ratio to the baseline with the DM p-value against it (* p &lt; "
           f"0.10), and the ratio to RE(t-1). Log likelihood of the sample and its difference to the baseline.")
    return (f'<div class="tw"><table class="rm"><caption>{cap}</caption>{head}<tbody>{grouped_rows(cells, 9)}</tbody>'
            f'</table></div>')


def sec_summary(no):
    cp, cd, cr = count_better("pinfobs"), count_better("dy"), count_better("robs")
    better = [i for i in VARIANTS if rok(i) and i not in WEDGE and (lld(i) or -1) > 0]
    top = DEP_RANK[:7]
    ans1 = (f"In sample, {SLAB['full']}, with the original SW07 parameters, {len(cp['lower'])} of the {len(VARIANTS)} "
            f"variants predict inflation better than the baseline ({len(cp['sig_lower'])} with a DM p-value below 0.10), "
            f"but only {len(cd['lower'])} predict output growth better and {len(cr['lower'])} the policy rate. Without an "
            f"extra shock, {len(better)} have a higher log likelihood than the baseline; the largest gain is "
            f"{label(max(better, key=lld))} ({f(lld(max(better, key=lld)), 1, sign=True)})." if better else "")
    ans2 = (f"The impulse responses from 2019Q4 depart most from the baseline's in {joinand(lab_s(i) for i in top)}: the "
            f"variants that scale down every forward expectation or let every agent learn all seven sticky expectations, "
            f"plus diagnostic expectations." if set(top) >= set(DISC_ALL + ST7 + ids_of("10"))
            else f"The impulse responses from 2019Q4 depart most from the baseline's in {joinand(lab_s(i) for i in top)}"
            + (" (18 mainly through late swings of output growth, after its consumption shares move)" if top and RUN[top[0]]["no"] == "18" else "") + ".")
    fl_ = "".join(f"<li>{x}</li>" for x in flag_items(short=True))
    body = (f'<p class="answer">{ans1} {ans2}</p>\n'
            f'<p class="intro">Details: <a href="#rmse">section 2</a> (tables), <a href="#irf">section 3</a> (one figure '
            f'per shock), <a href="#notes">section 4</a> (flags in full, method, checks).</p>\n'
            f'<aside class="box warn" role="note"><h3>Read these first</h3><ul class="flags">{fl_}</ul></aside>')
    return section("summary", no, "Summary", body)


def sec_rmse(no):
    intro = (f"Each run filters the data 1965Q1-2026Q2 with its own law of motion, quarter by quarter: the model in "
             f"force has the beliefs and shares of the end of the quarter before, the Kalman filter predicts the seven "
             f"observables, and the agents learn from the filtered values ({code('history.mode')} = {code('kalman')}, "
             f"{code('stochastic')} start). The errors are the one-step predictions from {SFIRST['full']} to "
             f"{SLAST['full']}; 2020Q1-Q3 have no data, so the 2020Q4 prediction is four quarters ahead.")
    full = "".join(f'<details class="full"{" open" if s == "full" else ""}><summary>{esc(SLAB[s])}</summary>'
                   f'{full_rmse_table(s)}</details>' for s, _ in SAMPLES)
    body = (f"<p>{intro}</p>\n<ul class=\"find\">" + "".join(f"<li>{x}</li>" for x in rmse_findings()) + "</ul>\n"
            f'<h3 class="sub">Main table: inflation, output growth and the policy rate</h3>\n{main_rmse_table()}\n'
            f'<h3 class="sub">Full table: seven observables, five samples</h3>\n'
            f'<p class="intro">One table per sample; the full sample is open.</p>\n{full}')
    return section("rmse", no, "In-sample RMSE", body)


def sec_irf(no):
    tabs = "".join(f'<button type="button" data-shock="{s}" aria-pressed="{"true" if k == 0 else "false"}">'
                   f'{esc(SHOCK_TAB.get(s, s))}</button>' for k, s in enumerate(SHOCKS))
    sizes = "; ".join(f"{code(s)} {f(SD.get(s), 3)}" for s in SHOCKS)
    intro = (f"Generalised impulse responses. Each run filters the history to 2019Q4 with its own beliefs, gains and "
             f"shares (the baseline's RE smoother with filtered RE states), then forecasts {NH} quarters, "
             f"{DATE0}-{DATE_END}, twice from that state: with no shock, and with a one-standard-deviation shock in "
             f"{DATE0}. Beliefs, gains and shares keep updating. The response is the difference of the two paths. Shock "
             f"sizes in model units: {sizes}. Every panel shows the baseline and RE(t-1); the variants are grouped by "
             f"family as on the Application 1 page, with the same colours.")
    figs = "".join(shock_figure(s, k == 0) for k, s in enumerate(SHOCKS))
    body = (f"<p>{intro}</p>\n<ul class=\"find\">" + "".join(f"<li>{x}</li>" for x in irf_findings()) + "</ul>\n"
            f'<p class="choose">Choose a shock (one figure each):</p>\n'
            f'<div class="seg tabs" role="group" aria-label="Shock" data-shocktabs>{tabs}</div>\n{figs}')
    return section("irf", no, "Impulse responses", body)


def asym_txt():
    d = IRR[(IRR.shock != "none") & (IRR.sign == 1)]
    d = d[d.asym_rel.notna()]
    if not len(d):
        return ""
    r = d.sort_values("asym_rel", ascending=False).iloc[0]
    over = d[d.asym_rel > 0.10]
    return (f"Nonlinearity check: max_h |GIRF(+1 sd) + GIRF(-1 sd)| over the five paths, relative to max_h |GIRF(+1 sd)|, "
            f"has a median of {f(float(d.asym_rel.median()), 4)} over the {len(d)} variant-shock pairs; "
            f"{len(over)} pairs are above 0.10"
            + (f" ({', '.join(sorted({lab_s(v) for v in over.variant}, key=lambda x: IDS.index(NO[x])))})" if len(over) else "")
            + f", the largest {f(float(r.asym_rel), 3)} ({esc(lab_s(r.variant))}, {code(r.shock)}). The minus-one-sd "
              f"runs are in irf_long.csv (sign -1).")


def gates_table():
    rows = []
    gb = IRR[IRR.shock == "none"].gate_base.dropna()
    rows.append(["Unshocked forecast-stage rerun = core's own forecast (every scenario, five paths)",
                 sci(float(gb.max())) if len(gb) else "n/a"])
    gs = IRR[(IRR.shock == "none") & IRR.gate_srf.notna()]
    if len(gs):
        rows.append(["RE(t-1) responses = IRIS srf of its solved model (7 shocks, five paths, 20 quarters)",
                     sci(float(gs.gate_srf.max()))])
    if CHK is not None and len(CHK):
        rows.append([f"Forecast-stage reruns = full hetlearn.run calls with shocks.add, {len(CHK)} pairs ("
                     + ", ".join(f"{lab_s(r.variant)} {r.shock}" for r in CHK.itertuples())
                     + "): response, unshocked path, shares",
                     f"{sci(float(CHK.girf_maxdiff.max()))}, {sci(float(CHK.base_maxdiff.max()))}, "
                     f"{sci(float(CHK.shares_maxdiff.max()))}"])
    else:
        rows.append(["Forecast-stage reruns = full hetlearn.run calls (irf_check.csv)", "not run"])
    ck = RMR.rmse_check_maxdiff.dropna()
    rows.append(["RMSE from the error table (evaluate_tables) = each run's kalman_history('rmse') table",
                 sci(float(ck.max())) if len(ck) else "n/a"])
    return ('<div class="tw"><table class="gates"><thead><tr><th>Check</th><th>Max abs difference</th></tr></thead><tbody>'
            + "".join(f'<tr><td>{esc(a)}</td><td class="n">{b}</td></tr>' for a, b in rows) + "</tbody></table></div>")


def sec_notes(no):
    fl_ = "".join(f"<li>{x}</li>" for x in flag_items())
    fac = str(RR["a1_learn"]["facility"])
    meth_irf = (f"Impulse responses ({code('run_br_portfolio irf')}). Each scenario with origin 2019Q4 and horizon {NH}: "
                f"the steps of {code('hetlearn.run')} up to the engine core run once (the history and a zero-shock "
                f"forecast); the forecast stage then reruns from the same state with the shock added in {DATE0}, as the "
                f"density forecasts do. Nothing is saved in {code('results/<id>/')}. The SW07 shocks have the standard "
                f"deviations of the published mode; the wedge shocks of 29 and 31 the ones their transforms set. The "
                f"responses of inflation, output growth, consumption growth and the policy rate are those of the "
                f"observables ({code('pinfobs')}, {code('dy')}, {code('dc')}, {code('robs')}) times 4. The inflation "
                f"expectation is {code('pinf_exp1')}, the aggregate forecast of next quarter's inflation that enters the "
                f"model, times 4; in variant 4 the Phillips curves use their own copies, so its {code('pinf_exp1')} is the "
                f"untransformed aggregate. Shares: the discrete-choice share at the end of the quarter, for the types in "
                f"the switching population. {asym_txt()}")
    meth_rm = (f"In-sample RMSE ({code('run_br_portfolio rmse')}). {code('history.mode')} = {code('kalman')} with "
               f"{code('history.re_states')} = {code('smoothed')} (required with the Kalman history, which is one-sided "
               f"anyway), the {code('stochastic')} start, origin 2026Q2; facility {code(fac)}. Errors are y(t) minus the "
               f"one-step prediction; RMSE over the quarters with data in each sample, by target date. Diebold-Mariano "
               f"tests on the squared errors against the baseline (and against RE(t-1) in rmse_long.csv), h = 1: the "
               f"variance of the loss difference without autocorrelation terms, the Harvey-Leybourne-Newbold factor and "
               f"a two-sided t(n-1) p-value ({code('hetlearn.evaluate_tables')}). The log likelihood is the sum of the "
               f"Gaussian one-step log densities of all seven observables, so it also charges for the predicted variance. "
               f"Original SW07 parameters (the published mode); nothing is re-estimated.")
    dep = (f"Departure from the baseline (summary): for each of the 7 SW07 shocks and the four observables, "
           f"sum_h |response - baseline response| / sum_h |baseline response|, averaged; largest: "
           + ", ".join(f"{lab_s(i)} {f(DEP[i])}" for i in DEP_RANK[:7]) + f"; RE(t-1) {f(DEP['a1_re'])}.")
    units = ("Units: pp = percentage points of annualised rates (model units of % per quarter times 4); share responses in "
             "percentage points of the population (share x 100); hours worked in 100 x log. h = 0 is the quarter of the shock.")
    lines = ["% MATLAB, from the project root (four sessions at most; help run_br_portfolio)",
             "run_br_portfolio('irf', ids)     % one compact file per scenario in results/br_portfolio/irf_runs/",
             "run_br_portfolio('rmse', ids)    % results/br_portfolio/rmse_runs/",
             "run_br_portfolio('check')        % gate: reruns = full hetlearn.run calls, irf_check.csv",
             "run_br_portfolio('csv')          % irf_long, irf_runs, states_2019Q4, rmse_long, rmse_runs (.csv)",
             "",
             "# Python",
             "python reports/build_br_portfolio_report.py"]
    rt_i = float(IRR[IRR.shock == "none"].runtime_s.sum())
    rt_r = float(RMR.runtime_s.sum())
    body = (f'<h3 class="sub">Flags</h3><ul class="flags">{fl_}</ul>'
            f'<h3 class="sub">Method</h3><p>{meth_irf}</p><p>{meth_rm}</p><p>{dep}</p><p>{units}</p>'
            f'<h3 class="sub">Checks</h3>{gates_table()}'
            f'<h3 class="sub">Reproduction</h3><p>Scenario files: {code("scenarios/sw07/br_portfolio/")} (variants) and '
            f'{code("scenarios/sw07/app1_peak/")} (references). Tables: {code("results/br_portfolio/")}. The runs took '
            f'{f(rt_i, 0)} s (impulse responses) and {f(rt_r, 0)} s (Kalman histories) of compute.</p>'
            f'<pre class="code"><code>{esc(chr(10).join(lines))}</code></pre>')
    return section("notes", no, "Notes: flags, method, checks", body)


# ============================================================================= assemble
PARTS = [sec_summary(1), sec_rmse(2), sec_irf(3), sec_notes(4)]
toc = "".join(f'<a href="#{sid}"><span class="tn">{no}</span> {esc(t)}</a>' for sid, no, t in SEC)
n_irf = int((IRR.shock != "none").sum())
lede1 = (f"Impulse responses and in-sample forecast errors for the {len(VARIANTS)} bounded-rationality variants of "
         f"hetlearn (docs/DESIGN_br_extensions.md, sections 3-5), each against the baseline and the RE(t-1) benchmark. "
         f"Every variant is the baseline scenario {code('a1_learn')} with one change to how expectations are formed.")
lede2 = (f"All runs use the published Smets-Wouters (2007) parameters and inherit the baseline's options, including "
         f"the projection facility {code(str(RR['a1_learn']['facility']))}. The impulse responses start from each "
         f"variant's own 2019Q4 state; the forecast errors are one-step predictions of each variant's own Kalman filter, "
         f"1966Q1-2026Q2.")
body = f"""
<header class="top wrap">
  <p class="kicker">hetlearn toolbox report · {REPORT_DATE}</p>
  <h1>{len(VARIANTS)} expectation rules: impulse responses and in-sample fit</h1>
  <p class="lede">{lede1}</p>
  <p class="lede">{lede2}</p>
  <p class="meta"><span>{REPORT_DATE}</span><span>{len(IDS)} scenarios</span><span>{n_irf} shocked forecasts</span>
  <span>{len(IDS)} Kalman histories</span><span>Inputs: results/br_portfolio/</span></p>
  <nav class="toc" aria-label="Sections">{toc}</nav>
</header>
<main class="wrap">
{"".join(PARTS)}
<footer class="foot"><p>Built by <code>reports/build_br_portfolio_report.py</code> from <code>results/br_portfolio/</code>
(irf_long, irf_runs, states_2019Q4, rmse_long, rmse_runs, irf_check, app1_variants) on {REPORT_DATE}.
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
        '<title>hetlearn BR portfolio IRFs</title>\n'
        '<meta name="claude:viewport-fit-sides" content="cover">\n'
        f'<link rel="stylesheet" href="{FONTS}">\n'
        f"<style>{CSS}{CSS_EXTRA}{CSS_BR}</style>\n"
        f"{body}\n"
        f'<script type="application/json" id="report-data">{data_json}</script>\n'
        f"<script>{JS}</script>\n"
        f"<script>{TABS_JS}</script>\n")
if "—" in page:
    raise SystemExit("em dash in the page")
OUT.write_text(page, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB), {len(CHARTS)} charts, {FIGN[0]} figures, {len(SHOCKS)} shocks, "
      f"{len(IDS)} scenarios; departure ranking: " + ", ".join(f"{lab_s(i)} {DEP[i]:.2f}" for i in DEP_RANK[:8]))
