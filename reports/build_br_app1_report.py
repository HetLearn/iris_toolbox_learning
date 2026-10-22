#!/usr/bin/env python3
"""Build reports/sw07_br_app1_report.html: Application 1 for the bounded-rationality portfolio.

    python reports/build_br_app1_report.py          (from the project root, or any folder)
    python reports/build_br_app1_report.py --inputs DIR --out FILE

A separate page from the main report (build_report_v3.py). It reads only the tables in
results/br_portfolio/ written by run_br_app1.m: app1_variants.csv, app1_summary.csv,
app1_paths.csv, app1_shares.csv, app1_shares_2022Q2.csv and app1_events.csv. Every number in
the text and the charts is computed from them at build time; none is typed. Since 2026-10-22 the
portfolio has the seven variants that docs/BR_audit.txt keeps; the page says so in a dated note.
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

import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[1]
_AP = argparse.ArgumentParser(description="Build the BR portfolio Application 1 report from results/br_portfolio/.")
_AP.add_argument("--inputs", default=str(ROOT / "results" / "br_portfolio"), help="folder with the app1_*.csv tables")
_AP.add_argument("--out", default=str(ROOT / "reports" / "sw07_br_app1_report.html"), help="page to write")
_ARGS = _AP.parse_args()
INP = pathlib.Path(_ARGS.inputs)
OUT = pathlib.Path(_ARGS.out)
REPORT_DATE = "2026-10-22"
CUT_NOTE = ("<b>Note, 2026-10-22.</b> After an audit of the 21 variants built so far, the portfolio was cut to "
            "seven. Variants 1a, 1b, 4, 5a, 6, 17, 18, 20, 25a, 25b, 27, 29, 31 and 33 were dropped; "
            "docs/BR_audit.txt gives the reasons.")
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
table.sum td .no{font:600 12.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--fg);margin-right:4px}
table.sum td .src{display:block;color:var(--muted);font-size:11.5px;margin-top:3px}
table.sum td .chip{margin:3px 4px 0 0}
table.sum tr.ref td{background:var(--bg-2)}
table.sum tr.grp td{font-weight:600;color:var(--fg);background:var(--band-2);font-size:12.5px}
ul.flags{margin:6px 0 0;padding-left:1.1rem}
ul.flags li{margin-bottom:7px;max-width:88ch}
.famlist{color:var(--ink-2);font-size:14.5px}
.g-2 figure.sh .plot{min-height:120px}
"""


# ============================================================================= inputs
def rd(name, **kw):
    p = INP / name
    if not p.exists():
        raise SystemExit(f"missing input {p} (run run_br_app1('csv') first)")
    return pd.read_csv(p, keep_default_na=True, **kw)


VAR = rd("app1_variants.csv", dtype={"no": str})
SUM = rd("app1_summary.csv", dtype={"no": str, "stop_date": str, "gap_peak_date": str, "fac_first": str, "fac_last": str})
PTH = rd("app1_paths.csv")
SHR = rd("app1_shares.csv")
S22 = rd("app1_shares_2022Q2.csv")
EVT = rd("app1_events.csv")


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
LVNAME = {"pinf": "inflation"}


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
# One hue per variant within its family, the slots in their fixed order (the IRF page repeats this).
for fam, _ in FAMS:
    if len(FAMIDS[fam]) > len(SLOTS):
        raise SystemExit(f"family {fam}: more than {len(SLOTS)} hues needed")
    for k, i in enumerate(FAMIDS[fam]):
        ENT[i] = dict(name=label(i), short=RUN[i]["no"], color=SLOTS[k], style="solid")

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
               "hetlearn:engine:almUnstable": "the first model checked is already unstable"}.get(txt(i, "error_id"), "stops")
        return f"stops in {txt(i, 'stop_date')} ({txt(i, 'stop_stage')} stage): {why}"
    return f"error: {txt(i, 'error_message')[:120]}"


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
            ts = [t for t in types_of(i, lv) if INPOP.get((i, lv, t), 0) == 1]
            if MODE.get(i) != "switching" or (lv == "pinf" and two_type(i)) or len(ts) < 2:
                continue
            ss = []
            for k, t in enumerate(ts):
                ss.append(S(i, share_series(i, lv, t, X), name=t, short=t, style=DASHES[k % len(DASHES)]))
            v22 = ", ".join(f"{t} {f(S22D.get((i, lv, t)), 3)}" for t in ts)
            what = "inflation expectations" if lv == "pinf" else f"the expectation of {code(lv)}"
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
    "disc": "Agents shrink their forecasts of deviations from the steady state, more at longer horizons.",
    "info": "The expectation reacts too little or too much to news.",
    "learn": "The learners keep the baseline's switching against the RE agents but learn another object or use another gain.",
    "dist": "A third forecasting type joins the RE agents and the learners.",
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
    nf = sum(1 for i in IDS if fac_n(i) > 0)
    if STOPPED or ERRORS:
        out.append("<b>Stops.</b> " + " ".join(f"{esc(label(i))} {esc(stop_txt(i))}." for i in STOPPED + ERRORS))
    else:
        out.append(f"<b>No run stops.</b> With the {code(FAC)} facility all {len(IDS)} runs reach {END}. "
                   + (f"The facility acts in {nf} of them, listed next." if nf else
                      "The facility never acts, in the history or in the forecast."))
    for i in [i for i in IDS if fac_n(i) > 0]:
        extra = ""
        if two_type(i) and learners_2022(i) is not None and learners_2022(i) > 0.99:
            extra = (f" By the end of {ORIGIN} the learners hold {f(learners_2022(i), 3)} of inflation expectations, and "
                     f"{path_txt(i)}; average inflation is {pct(num(i, 'avg_pinf'))}.")
        out.append(f"<b>Facility, {esc(label(i))}.</b> {esc(fac_txt(i))}.{extra}")
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


def sec_notes(no):
    lines = ["% MATLAB, from the project root",
             f"run_br_app1('check')                         % options of the {len(IDS)} scenarios load",
             "run_br_app1('run')                           % the references, then the variants (help run_br_app1)",
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
            f"either, last quarter's shares stay in force (events {code('projection_alm')}, {code('projection_alm_shares')}). "
            f"Scenario files: {code('scenarios/sw07/br_portfolio/')}; runs in {code('results/<id>/')}; tables in "
            f"{code('results/br_portfolio/')}. The {len(IDS)} runs took {f(sum(rt), 0)} s of compute in total.</p>"
            f'<pre class="code"><code>{esc(chr(10).join(lines))}</code></pre>')
    return section("notes", no, "Definitions and reproduction", body)


# ============================================================================= assemble
PARTS = [sec_summary()]
for k, (fam, title) in enumerate(FAMS):
    PARTS.append(sec_family(k + 2, fam, title))
PARTS.append(sec_notes(len(FAMS) + 2))

n_ok = sum(1 for i in IDS if txt(i, "status") == "ok")
n_fac = sum(1 for i in IDS if fac_n(i) > 0)
toc = "".join(f'<a href="#{sid}"><span class="tn">{no}</span> {esc(t)}</a>' for sid, no, t in SEC)
bl = RUN["a1_learn"]
lede1 = (f"Application 1, the forecast from the {ORIGIN} inflation peak, for each of the {len(VARIANTS)} "
         f"bounded-rationality variants of the hetlearn portfolio (design: docs/DESIGN_br_extensions.md, section 3). Each variant "
         f"is the baseline scenario {code('a1_learn')} with one change to how expectations are formed. Every chart also "
         f"shows the baseline and the RE(t-1) benchmark.")
lede2 = (f"Baseline: the Smets-Wouters (2007) model at its published posterior mode. Inflation expectations mix RE agents, "
         f"who see data up to t-1, and AR(1) learners ({esc(lc1(bl['params']))}). RE values in the history come from the "
         f"one-sided filter. Projection facility {code(FAC)}. The forecast runs {H} quarters, {HOR[0]}-{END}, with zero "
         f"shocks. Variants are grouped by family, as in the literature review behind the design.")
body = f"""
<header class="top wrap">
  <p class="kicker">hetlearn toolbox report · {REPORT_DATE}</p>
  <h1>{len(VARIANTS)} expectation rules at the {ORIGIN} inflation peak</h1>
  <p class="lede">{lede1}</p>
  <p class="lede">{lede2}</p>
  <aside class="box" role="note"><p>{CUT_NOTE}</p></aside>
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
