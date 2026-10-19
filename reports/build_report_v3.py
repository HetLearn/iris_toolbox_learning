#!/usr/bin/env python3
"""Build reports/sw07_learning_report.html from results/summary_v3/ (pipeline step 7).

    python reports/build_report_v3.py        (from the project root, or any folder)

Reads the CSVs, checks_v3.txt and the memo FINDINGS_v3.md (its Notes section) in
results/summary_v3/, docs/FEATURES.md, config/master_options.m, run_applications.m and the
scenario files in scenarios/sw07/; writes one page (content only, no <html>/<head>/<body>:
the claude.ai artifact publisher wraps it; the file name stays so the published link stays).
Every number in the prose is read from those files at build time (K() for key_numbers.csv,
the dictionaries below for the other CSVs); none is typed by hand. Rerunnable, offline.
The CSS and the JS chart engine (lines, fan bands, stacked bars, dots, table views, legends,
light/dark themes, palette slots s1-s8) come from the round 1-2 builder, now in
archive/2026-10-18_rounds1-2/reports/build_report_round2.py.
"""
import html
import json
import math
import pathlib
import re

import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parents[1]
SUM = ROOT / "results" / "summary_v3"
SCN = ROOT / "scenarios" / "sw07"
OUT = ROOT / "reports" / "sw07_learning_report.html"
REPORT_DATE = "2026-10-19"
esc = html.escape

# ============================================================================= inputs
sc = pd.read_csv(SUM / "scenarios.csv").set_index("id")
pth = pd.read_csv(SUM / "paths_long.csv")
a3 = pd.read_csv(SUM / "app3_policy.csv")
a4 = pd.read_csv(SUM / "app4_losses.csv")
dns = pd.read_csv(SUM / "app5_density.csv")
wid = pd.read_csv(SUM / "app5_widths.csv")
dcl = pd.read_csv(SUM / "app6_decomp_long.csv")
shk = pd.read_csv(SUM / "app6_shocks_long.csv")
evl = pd.read_csv(SUM / "events_long.csv")
fac = pd.read_csv(SUM / "v3_facility.csv").set_index("scenario")
emet = pd.read_csv(SUM / "eval_metrics.csv")
erel = pd.read_csv(SUM / "eval_relative.csv")
edm = pd.read_csv(SUM / "eval_dm.csv")
kn = pd.read_csv(SUM / "key_numbers.csv")
checks_txt = (SUM / "checks_v3.txt").read_text(encoding="utf-8")
memo = (SUM / "FINDINGS_v3.md").read_text(encoding="utf-8")
features_md = (ROOT / "docs" / "FEATURES.md").read_text(encoding="utf-8")
master_m = (ROOT / "config" / "master_options.m").read_text(encoding="utf-8")
runapp_m = (ROOT / "run_applications.m").read_text(encoding="utf-8")

# learning_long.csv is 8.4 MB: keep only the variables and fields the charts use
LFIELDS = {"n2", "n2_model", "beta_pinf", "beta_c", "persistence", "gain", "perceived_mean_report"}
_ll = pd.read_csv(SUM / "learning_long.csv")
N12 = int(_ll[(_ll.scenario == "v3_all") & (_ll.field == "n2")].variable.nunique())   # forward-looking variables of SW07
_ll = _ll[_ll.variable.isin(["pinf", "c"]) & (_ll.field.isin(LFIELDS) | _ll.field.str.startswith("beta_pinf__"))]
LL = {(r.scenario, r.variable, r.field, r.date): float(r.value) for r in _ll.itertuples()}
LSTAGE = {(r.scenario, r.date): r.stage for r in _ll.itertuples()}

PTH = {(r.scenario, r.variable, r.date): float(r.value) for r in pth.itertuples()}
KN = dict(zip(kn.name, kn.value))
A3 = {(r.expectations, r.variable, r.date): r for r in a3.itertuples()}
DN = {(r.case, r.expectations, r.variable, r.date, round(float(r.quantile), 2)): float(r.value) for r in dns.itertuples()}
WD = {(r.case, r.expectations, r.variable, r.date): float(r.width_90) for r in wid.itertuples()}
DC = {(r.case, r.variable, r.component, r.date): float(r.value) for r in dcl.itertuples()}
EM = {(r.sample, r.variant, r.variable, int(r.h)): r for r in emet.itertuples()}
ER = {(r.sample, r.variant, r.variable, int(r.h)): float(r.relative_rmse) for r in erel.itertuples()}
DMP = {(r.sample, r.variant, r.variable, int(r.h)): float(r.p_value) for r in edm.itertuples()}
LOSS = {(r.weights, r.expectations, r.policy, int(r.horizon)): float(r.total) for r in a4.itertuples()}


def K(name):
    """A number from key_numbers.csv (KeyError if H1 did not write it)."""
    return float(KN[name])


def rx(pattern, text, group=1, flags=0):
    m = re.search(pattern, text, flags)
    if not m:
        raise ValueError(f"pattern not found: {pattern}")
    return m.group(group)


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


# ----------------------------------------------------------------------------- dates
ORIGIN = max(pth[(pth.scenario == "a1_learn") & (pth.stage == "history")].date)
HOR = sorted(pth[(pth.scenario == "a1_learn") & (pth.stage == "forecast")].date.unique())
END = HOR[-1]
H = len(HOR)
FIRST = min(d for (s, v, f, d) in LL if s == "a1_learn")
Q18 = qrange("2018Q1", END)
QH0 = [ORIGIN] + HOR
QF = qrange(FIRST, END)
COVID = qrange("2020Q1", "2020Q4")
HQ = {h: HOR[h - 1] for h in (1, 4, 8, 16) if h <= H}

# ----------------------------------------------------------------------------- formatting
MINUS = "−"


def clean(v, nd=4):
    if v is None:
        return None
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    if math.isnan(x) or math.isinf(x):
        return None
    return round(x, nd)


def f(x, d=2, sign=False):
    """Number for prose: typographic minus, optional plus sign."""
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


def sci(x):
    m, e = f"{x:.0e}".split("e")
    return f"{m}e{int(e)}"


def code(s):
    return f"<code>{esc(s)}</code>"


def lc1(s):
    """Lower-case a leading capital for use mid-sentence (keeps AR(2), RE, VAR(1))."""
    return s[0].lower() + s[1:] if len(s) > 1 and s[0].isupper() and s[1].islower() else s


def times(n):
    return {0: "never", 1: "once", 2: "twice"}.get(n, f"{n} times")


def md_inline(s):
    s = esc(s)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
    return s


# ----------------------------------------------------------------------------- series access
def P(scen, var, q):
    return PTH[(scen, var, q)]


def pavg(scen, var, X=None):
    xs = [PTH[(scen, var, q)] for q in (X or HOR)]
    return sum(xs) / len(xs)


def L(scen, var, field, q):
    return LL[(scen, var, field, q)]


def pser(scen, var, X, start=None):
    return [None if (start and q < start) else clean(PTH.get((scen, var, q))) for q in X]


def lser(scen, var, field, X, start=None, end=None):
    return [None if ((start and q < start) or (end and q > end)) else clean(LL.get((scen, var, field, q)))
            for q in X]


def idx(X, dates):
    return [X.index(q) for q in dates if q in X]


def ev_dates(scen, stage="forecast", types=None):
    d = evl[(evl.scenario == scen) & (evl.stage == stage)]
    if types:
        d = d[d.type.isin(types)]
    return sorted(d.date.unique().tolist())


def ev_count(scen, kind, stage):
    v = sc.loc[scen, f"projection_{kind}_{stage}"]
    return int(v) if not pd.isna(v) else 0


def argmax(d):
    k = max(d, key=lambda q: d[q])
    return k, d[k]


def argmin(d):
    k = min(d, key=lambda q: d[q])
    return k, d[k]


# ----------------------------------------------------------------------------- checks_v3.txt
CHK = {}
_cl = checks_txt.splitlines()
for _i, _ln in enumerate(_cl):
    _m = re.match(r"^(PASS|FAIL)\s+(C\w+)\s+(.*)$", _ln)
    if _m:
        _det = []
        _j = _i + 1
        while _j < len(_cl) and _cl[_j].startswith("      "):
            _det.append(_cl[_j].strip())
            _j += 1
        _nums = re.findall(r"[-+]?\d+(?:\.\d+)?e[-+]?\d+", " ".join(_det))
        CHK[_m.group(2)] = dict(status=_m.group(1), text=_m.group(3), detail=" ".join(_det),
                                first=float(_nums[0]) if _nums else None, nums=[float(x) for x in _nums])
N_PASS = sum(1 for c in CHK.values() if c["status"] == "PASS")
CHK_SUMMARY = rx(r"^(\d+ of \d+ checks pass)\s*$", checks_txt, flags=re.M)

# ============================================================================= chart registry
ENT = {
    "data": dict(name="Data", short="Data", color="ink", width=2.2),
    "re": dict(name="RE", short="RE", color="s1"),
    "learn": dict(name="Learning (inflation)", short="Learning", color="s2"),
    "mc": dict(name="Learning, model-consistent RE agents", short="Model-cons.", color="s3"),
    "all12": dict(name="Learning on all 12 variables", short="All 12", color="s3"),
    "ar2": dict(name="AR(2)", short="AR(2)", color="s3"),
    "ar1nc": dict(name="AR(1) without constant", short="AR(1) no const.", color="s3"),
    "reg": dict(name="Inflation on lagged inflation, output gap and rate", short="Regression", color="s3"),
    "var3": dict(name="VAR(1) in inflation, output gap and rate", short="VAR(1), 3", color="s3"),
    "var12": dict(name="VAR(1) in the 12 forward-looking variables", short="VAR(1), 12", color="s3"),
    "koz": dict(name="Endogenous gain (KOZ)", short="KOZ gain", color="s3"),
    "alll": dict(name="All agents learn", short="All learn", color="s3"),
}
VAR4 = ["pinfobs", "robs", "dy", "dc"]
VLAB = {"pinfobs": "Inflation", "robs": "Policy rate", "dy": "Output growth", "dc": "Consumption growth"}
UNIT = "% annualised"
CHARTS, LEGENDS = {}, {}
FIGN = [0]


def S(ent, v, **kw):
    d = dict(ENT[ent])
    d["v"] = v
    d.update(kw)
    return d


def fig_title(t):
    FIGN[0] += 1
    return f'<p class="fig"><span class="fn">Figure {FIGN[0]}.</span> {t}</p>'


def line(cid, group, title, cap, x, series, **kw):
    spec = dict(id=cid, group=group, title=title, x=x, series=series, origin=ORIGIN)
    spec.update(kw)
    CHARTS[cid] = spec
    return (f'<figure class="chart"><figcaption class="ct">{esc(title)}</figcaption>'
            f'<div class="plot" data-chart="{cid}"></div><p class="cap">{cap}</p></figure>')


def endw(series):
    if 2 <= len(series) <= 4:
        return round(min(92, max(len(s.get("short") or s["name"]) for s in series) * 6.2 + 14), 1)
    return 12


ML = 46


def panel(cid, group, title, cap, x, series, shares=None, **kw):
    """A chart; with shares, share-of-learners panels below it on the same x-axis and margins."""
    if not shares:
        return line(cid, group, title, cap, x, series, legend=False, **kw)
    mr = endw(series)
    main = dict(id=cid, group=group, title=title, x=x, series=series, origin=ORIGIN, legend=False, ml=ML, mr=mr)
    main.update(kw)
    CHARTS[cid] = main
    out = [f'<figure class="chart pair"><figcaption class="ct">{esc(title)}</figcaption>'
           f'<div class="plot" data-chart="{cid}"></div>']
    for k, (stitle, tip, sser, skw) in enumerate(shares):
        sid = f"{cid}-sh{k}"
        el = 2 <= len(sser) <= 4 and mr > 12
        spec = dict(id=sid, group=group, title=stitle, x=x, series=sser, origin=main["origin"], legend=False, ml=ML,
                    mr=mr, h=120, dec=3, endLabels=el, refs=[dict(y=0.5, label="")])
        if "bandForecast" in kw:
            spec["bandForecast"] = kw["bandForecast"]
        spec.update(skw)
        CHARTS[sid] = spec
        out.append(f'<p class="subt" title="{esc(tip)}">{esc(stitle)}</p><div class="plot sh" data-chart="{sid}"></div>')
    out.append(f'<p class="cap">{cap}</p></figure>')
    return "".join(out)


def stacked(gid, title_html, cap, panels, h=190):
    """Charts on the same x-axis and margins, one below the other, in one figure."""
    mr = max(endw(s) for _, _, s, _ in panels)
    parts = []
    for k, (st, x, ser, kw) in enumerate(panels):
        cid = f"{gid}-{k}"
        spec = dict(id=cid, group=gid, title=st, x=x, series=ser, origin=ORIGIN, legend=False, ml=ML, mr=mr, h=h, dec=3)
        spec.update(kw)
        CHARTS[cid] = spec
        parts.append(f'<p class="subt">{esc(st)}</p><div class="plot" data-chart="{cid}"></div>')
    return (f'<figure class="chart hist"><figcaption class="ct">{title_html}</figcaption>{"".join(parts)}'
            f'<p class="cap">{cap}</p></figure>')


def legend(gid, items):
    LEGENDS[gid] = items
    return f'<div class="legend" data-legend="{gid}"></div>'


def leg(ent, **kw):
    d = {k: v for k, v in ENT[ent].items() if k in ("name", "color", "style", "width")}
    d.update(kw)
    return d


def tables(gid, label="Table view: the plotted numbers"):
    return (f'<details class="tables"><summary>{esc(label)}</summary>'
            f'<div class="tblhost" data-tables="{gid}"></div></details>')


def html_table(hdr, rows, num_from=1, caption=None, cls="", raw=True):
    h = "".join(f"<th>{x if raw else esc(x)}</th>" for x in hdr)
    body = []
    for r in rows:
        cells = []
        for k, c in enumerate(r):
            cells.append(f'<td class="{"n" if k >= num_from else ""}">{c if raw else esc(str(c))}</td>')
        body.append("<tr>" + "".join(cells) + "</tr>")
    cap = f"<caption>{caption}</caption>" if caption else ""
    return f'<div class="tw"><table class="{cls}">{cap}<thead><tr>{h}</tr></thead><tbody>{"".join(body)}</tbody></table></div>'


# ----------------------------------------------------------------------------- scenario-file lines
def scen_lines(folder, sid):
    return scen_lines_path(SCN / folder / f"{sid}.m")


def scen_lines_path(path):
    """The option lines of a scenario file, verbatim: the parent call and every cfg.* line except
    id, title, description and compare_with (continuation lines included)."""
    lines = path.read_text(encoding="utf-8").splitlines()
    out, cont = [], False
    for ln in lines:
        s = ln.strip()
        if cont:
            out.append(ln)
            cont = s.endswith("...")
            continue
        if re.match(r"^(cfg|r|d|c)\s*=\s*\w+\(\);", s):
            out.append(s)
        elif s.startswith("cfg.") and not re.match(r"cfg\.(id|title|description|compare_with)\b", s):
            out.append(ln)
            cont = s.endswith("...")
    return out


def file_block(path, start_pat, end_pat):
    lines = path.read_text(encoding="utf-8").splitlines()
    i0 = next(i for i, ln in enumerate(lines) if re.search(start_pat, ln))
    i1 = next(i for i, ln in enumerate(lines) if i >= i0 and re.search(end_pat, ln))
    return lines[i0:i1 + 1]


def codeblock(relpath, lines):
    return (f'<p class="codelab">{code(relpath)}</p>'
            f'<pre class="code"><code>{esc(chr(10).join(lines))}</code></pre>')


def scode(folder, sid):
    return codeblock(f"scenarios/sw07/{folder}/{sid}.m", scen_lines(folder, sid))


def desc(sid):
    return str(sc.loc[sid, "description"])


# ============================================================================= shared figure builders
def default_cap(var, lines, data, X):
    pieces = [f"{lc1(ln['name'] if 'name' in ln else ENT[ln['ent']]['name'])} {pct(pavg(ln['scen'], var))}" for ln in lines]
    cap = f"Average {HOR[0]}-{END}: " + "; ".join(pieces)
    if data:
        cap += f"; data {pct(pavg('data', var))}"
    cap += "."
    if var in ("dy", "dc") and any(q in X for q in COVID):
        cap += " The 2020 quarters run off the scale (values in the table view)."
    return cap


def share_series(lines, X, lvar="pinf"):
    out = []
    for ln in lines:
        kw = {k: ln[k] for k in ("name", "short") if k in ln}
        s = S(ln["ent"], lser(ln["scen"], lvar, "n2_model", X), **kw)
        if ln.get("share_rings"):
            s["rings"] = idx(X, ln["share_rings"])
        out.append(s)
    return out


def forecast_grid(gid, lines, X=None, data=True, shares=None, caps=None, band=True, data_name=None, grid="g-2", group=None):
    """Inflation, policy rate, output growth, consumption growth; lines drawn from the origin.
    shares: {var: [(title, tooltip, lines, lvar)]}: share panels under that variable's chart."""
    X = X or Q18
    out = []
    for var in VAR4:
        ser = []
        if data:
            ser.append(S("data", pser("data", var, X), **({"name": data_name, "short": "Data"} if data_name else {})))
        for ln in lines:
            kw = {k: ln[k] for k in ("name", "short") if k in ln}
            s = S(ln["ent"], pser(ln["scen"], var, X, ORIGIN), **kw)
            if ln.get("rings") and var == "pinfobs":
                s["rings"] = idx(X, ln["rings"])
            ser.append(s)
        cap = caps[var] if caps and var in caps else default_cap(var, lines, data, X)
        kw = dict(clip=COVID if var in ("dy", "dc") else [])
        if not band:
            kw["bandForecast"] = False
        sh = None
        if shares and var in shares:
            sh = [(t, tip, share_series(sl, X, lvar), {}) for t, tip, sl, lvar in shares[var]]
        out.append(panel(f"{gid}-{var}", group or gid, f"{VLAB[var]}, {UNIT}", cap, X, ser, shares=sh, **kw))
    return f'<div class="grid {grid}">{"".join(out)}</div>'


def history_figure(gid, title, cap, share_lines, pers_lines):
    """Full history: share of learners (n2) and perceived persistence, one panel each."""
    sh = [S(e, lser(s, v, "n2", QF), **kw) for e, s, v, kw in share_lines]
    pe = [S(e, lser(s, v, fld, QF), **kw) for e, s, v, fld, kw in pers_lines]
    return stacked(gid, title, cap, [("End-of-quarter share of learners (n2)", QF, sh, {}),
                                     ("Perceived persistence (beta, the learners' AR(1) coefficient)", QF, pe, {})])


def range_txt(xs, d=3):
    return f"{f(min(xs), d)}-{f(max(xs), d)}"


# ============================================================================= sections
SEC = []


def section(sid, no, title, body):
    SEC.append((sid, no, title))
    return f'<section id="{sid}">\n<h2><span class="no">{no:02d}</span>{esc(title)}</h2>\n{body}\n</section>\n'


# ----------------------------------------------------------------------------- baseline
def sec_baseline():
    g = rx(r"o\.gain\.value\s*=\s*([0-9.]+)", master_m)
    chi = rx(r"o\.switching\.intensity\s*=\s*([0-9.]+)", master_m)
    om = rx(r"o\.switching\.memory\s*=\s*([0-9.]+)", master_m)
    n0 = rx(r"o\.shares\.init_n2\s*=\s*([0-9.]+)", master_m)
    n12 = N12
    mo =[ln for ln in master_m.splitlines() if re.match(r"^o\.(gain\.value|switching\.intensity|switching\.memory|shares\.init_n2)\b", ln)]
    base = file_block(SCN / "base" / "sw07_re.m", r"^cfg\.model\s*=", r"cfg\.expectations\.re_variant")
    learn = [ln for ln in scen_lines("base", "sw07_learn")]
    return f"""<section id="baseline"><div class="box base">
<h3>Baseline, used everywhere unless a section says otherwise</h3>
<p>Smets-Wouters (2007) model. RE agents use the anchored RE forecast: the RE model's forecast at the current state.
Learning is on inflation only: inflation expectations mix RE agents and learners, who forecast with an AR(1) perceived
law of motion (PLM) updated by constant-gain least squares; the other {n12 - 1} forward-looking variables are RE. The two
shares switch on past forecast performance (discrete choice on squared forecast errors). Each quarter the projection
facility checks the PLMs and then the model (the actual law of motion, ALM). Calibration: gain {g}, intensity of choice
{chi} (IJCB's estimate, on quarterly data), memory {om}, initial share of learners {n0}. Beliefs and shares are learned
over the RE-smoothed history from {FIRST} to {ORIGIN}. Forecasts start at the {ORIGIN} inflation peak and run {H} quarters
({HOR[0]}-{END}) with zero shocks unless stated.</p>
<p>Units: inflation, the policy rate and growth rates in % annualised; pp = percentage points. Two share measures
appear: the share in force ({code('n2_model')}) is the learners' share of inflation expectations used in the model in a
quarter; the end-of-quarter share ({code('n2')}) is the discrete-choice share computed at the end of a quarter, in force
in the next one. Colours: line charts use data grey, RE blue, the baseline learning model orange, and teal for the
alternative it is compared with, named in each chart or panel title; no line chart has more than these four hues, a set
that passes the colour-blindness checks in light and dark mode. The decomposition bars use five component colours plus
grey, stacked so that neighbouring segments pass the same checks.</p>
<details class="tables"><summary>The lines that set the baseline</summary>
{codeblock("config/master_options.m", mo)}
{codeblock("scenarios/sw07/base/sw07_re.m (every option is listed in this file)", base)}
{codeblock("scenarios/sw07/base/sw07_learn.m", learn)}
</details>
</div></section>
"""


# ----------------------------------------------------------------------------- application 1
def sec_app1():
    re_, le = "a1_re", "a1_learn"
    gap = {q: P(le, "pinfobs", q) - P(re_, "pinfobs", q) for q in HOR}
    qmax, gmax = argmax(gap)
    run = []
    for q in HOR:
        if gap[q] > 0:
            run.append(q)
        else:
            break
    last_pos = run[-1]
    first_neg = next(q for q in HOR if q > last_pos and gap[q] < 0)
    n2m = {q: L(le, "pinf", "n2_model", q) for q in HOR}
    mono = all(n2m[HOR[i + 1]] > n2m[HOR[i]] for i in range(H - 1))
    avl, avr = K(f"avg_pinfobs__{le}"), K(f"avg_pinfobs__{re_}")
    n_ev = int(sc.loc[le, "n_events"])
    hist_ev = sum(ev_count(le, k, "history") for k in ("plm", "alm", "alm_shares"))
    q22, q24 = "2022Q4", "2024Q2"
    ans = (f"Learning raises the inflation path. Average inflation over {HOR[0]}-{END} is {pct(avl)} with learning and "
           f"{pct(avr)} under RE, {f(avl - avr)} pp higher. The gap peaks at {pp(gmax)} in {qmax}, stays positive through {last_pos} "
           f"and is slightly negative from {first_neg} ({END}: {pct(P(le, 'pinfobs', END))} vs {pct(P(re_, 'pinfobs', END))}).")
    p2 = (f"Inflation was {pct(K('a1_pinf_data_2022Q2'))} in {ORIGIN} (data). At the origin the learners' beliefs are alpha "
          f"{f(K('a1_alpha_origin'), 3)} and beta {f(K('a1_beta_origin'), 3)}: a perceived mean of {pct(K('a1_pmean_origin'))} "
          f"against a steady state of {pct(K('ss_pinf'))}. The perceived mean falls to {pct(K('a1_pmean_2026Q2'))} by {END}. "
          f"The policy rate follows inflation, {pct(K('avg_robs__' + le))} vs {pct(K('avg_robs__' + re_))} on average, and "
          f"output growth is lower, {pct(K('avg_dy__' + le))} vs {pct(K('avg_dy__' + re_))}."
          + (" No projection-facility events in the history or the forecast." if n_ev == 0 and hist_ev == 0 else ""))
    p3 = (f"A higher share of learners does not go with a higher inflation forecast here. The share in force ({code('n2_model')}) rises "
          f"{'in every quarter' if mono else 'over the horizon'}, from {f(n2m[HOR[0]], 3)} in {HOR[0]} to "
          f"{f(n2m['2023Q2'], 3)} in 2023Q2, {f(n2m[q24], 3)} in {q24} and {f(n2m[END], 3)} in {END}, while the inflation gap "
          f"narrows: {pp(gap[q22])} at a share of {f(n2m[q22], 3)} in {q22}, {pp(gap[q24])} at {f(n2m[q24], 3)} in {q24}. "
          f"With zero shocks both fitness measures decay, so the shares drift towards 0.5 by construction "
          f"(<a href=\"#caveats\">caveats</a>). Over the history {FIRST}-{ORIGIN} the end-of-quarter share ({code('n2')}) averaged {f(K('a1_n2_hist_mean'), 3)} "
          f"(range {f(K('a1_n2_hist_min'), 3)}-{f(K('a1_n2_hist_max'), 3)}); it was {f(K('a1_n2_2019Q4'), 3)} at the end of "
          f"2019Q4 and {f(K('a1_n2_2021Q2'), 3)} at the end of 2021Q2.")
    lines = [dict(ent="re", scen=re_), dict(ent="learn", scen=le)]
    shares = {"pinfobs": [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf",
                           [dict(ent="learn", scen=le)], "pinf")]}
    caps = {"pinfobs": default_cap("pinfobs", lines, True, Q18) +
            f" Share in force (n2_model): {f(n2m[HOR[0]], 3)} in {HOR[0]}, {f(n2m[END], 3)} in {END} (thin line: 0.5)."}
    g1 = forecast_grid("a1", lines, shares=shares, caps=caps)
    b26 = L(le, "pinf", "beta_pinf", END)
    hcap = (f"History: discrete-choice share at the end of each quarter, learned on the RE-smoothed history; after {ORIGIN} "
            f"the forecast. End-of-quarter share (n2) {f(K('n2_origin__' + le), 3)} at the end of {ORIGIN}; beta {f(K('a1_beta_origin'), 3)} at "
            f"{ORIGIN} and {f(b26, 3)} in {END}.")
    g2 = history_figure("a1h", "Share of learners and perceived persistence, inflation", hcap,
                        [("learn", le, "pinf", {})], [("learn", le, "pinf", "beta_pinf", {})])
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
<p>{p3}</p>
{fig_title(f"Forecast from the {ORIGIN} peak, {Q18[0]}-{END}. The shaded area is the forecast.")}
{legend("a1", [leg("data"), leg("re"), leg("learn")])}
{g1}
{tables("a1")}
{fig_title(f"The learners' share and perceived persistence, {FIRST}-{END}")}
<div class="grid g-1w">{g2}</div>
{tables("a1h")}"""
    return section("app1", 1, f"Application 1: the {ORIGIN} peak forecast", body)


# ----------------------------------------------------------------------------- application 2
def sec_app2():
    le = "a2_learn"
    gap = {q: P(le, "pinfobs", q) - P("data", "pinfobs", q) for q in HOR}
    qg, _ = argmax({q: abs(v) for q, v in gap.items()})

    def worst(var):
        g = {q: P(le, var, q) - P("data", var, q) for q in HOR}
        q, _ = argmax({k: abs(v) for k, v in g.items()})
        return g[q], q
    rows = []
    for var, nm in (("robs", "policy rate"), ("dy", "output growth"), ("dc", "consumption growth")):
        w, q = worst(var)
        rows.append(f"{nm} {f(K('a2_rmse_' + var))} pp (largest {pp(w)}, {q})")
    first4 = ", ".join(pp(K(f"a2_gap_pinf_{q}")) for q in HOR[:4])
    late = [gap[q] for q in HOR[4:]]
    flips = sum(1 for a, b in zip(late, late[1:]) if (a > 0) != (b > 0))
    after = ("alternates in sign" if flips >= 3 else "keeps its sign" if flips == 0 else "changes sign")
    ans = (f"Fed the same RE-smoothed shocks, the learning economy misses the data by {f(K('a2_rmse_pinfobs'))} pp (RMS) on "
           f"inflation over {HOR[0]}-{END}. Most of the miss is early: {pp(gap[qg])} in {qg}, and "
           f"{f(100 * K('a2_sqgap_share_first4'), 0)}% of the squared gap falls in {HOR[0]}-{HOR[3]}.")
    p2 = (f"Under RE the replay reproduces the data (largest error {sci(CHK['C1']['first'])}, check C1), so the data line is "
          f"also the RE replay. Learning replay minus data, inflation, {HOR[0]}-{HOR[3]}: {first4}; after that the gap "
          f"{after}, within {f(K('a2_gap_pinf_absmax_after_2023Q2'))} pp. Average inflation is "
          f"{pct(K('avg_pinfobs__' + le))} in the learning replay and {pct(K('a2_avg_pinf_data'))} in the data "
          f"({pp(K('avg_pinfobs__' + le) - K('a2_avg_pinf_data'))}). RMS gaps: {'; '.join(rows)}. The share in force ({code('n2_model')}) goes "
          f"from {f(K('n2_model_2022Q3__' + le), 3)} in {HOR[0]} to {f(K('n2_model_2026Q2__' + le), 3)} in {END} (highest "
          f"{f(K('n2_model_max__' + le), 3)}).")
    lines = [dict(ent="learn", scen=le, name="Learning replay", short="Learning")]
    shares = {"pinfobs": [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf",
                           [dict(ent="learn", scen=le, name="Learning replay")], "pinf")]}
    caps = {}
    for var in VAR4:
        caps[var] = (f"Average {HOR[0]}-{END}: learning replay {pct(pavg(le, var))}, data {pct(pavg('data', var))}."
                     + (" The 2020 quarters run off the scale (values in the table view)." if var in ("dy", "dc") else ""))
    g1 = forecast_grid("a2", lines, shares=shares, caps=caps, data_name="Data (= RE replay)")
    hcap = (f"The history is the one of application 1; after {ORIGIN} the replay. End-of-quarter share (n2) {f(K('n2_origin__' + le), 3)} at the "
            f"end of {ORIGIN}, {f(L(le, 'pinf', 'n2', END), 3)} at the end of {END}.")
    g2 = history_figure("a2h", "Share of learners and perceived persistence, inflation", hcap,
                        [("learn", le, "pinf", dict(name="Learning replay"))],
                        [("learn", le, "pinf", "beta_pinf", dict(name="Learning replay"))])
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
{scode("app2_replay", "a2_learn")}
{fig_title(f"Replay of the RE-smoothed shocks, {Q18[0]}-{END}")}
{legend("a2", [leg("data", name="Data (= RE replay)"), leg("learn", name="Learning replay")])}
{g1}
{tables("a2")}
{fig_title(f"The learners' share and perceived persistence in the replay, {FIRST}-{END}")}
<div class="grid g-1w">{g2}</div>
{tables("a2h")}"""
    return section("app2", 2, "Application 2: replay of the backed-out shocks", body)


# ----------------------------------------------------------------------------- application 3
def sec_app3():
    def ser(exp, var, col):
        return {q: float(getattr(A3[(exp, var, q)], col)) for q in HOR}
    lo_l, ti_l, as_l = (ser("learning", "pinfobs", c) for c in ("loose_minus_base", "tight_minus_base", "asymmetry"))
    lo_r = ser("RE", "pinfobs", "loose_minus_base")
    qpk, lpk = argmax(lo_l)
    tpk = ti_l[qpk]
    qas, _ = argmax({q: abs(v) for q, v in as_l.items()})
    qre, rpk = argmax(lo_r)
    r_l, r_r = ser("learning", "robs", "loose_minus_base"), ser("RE", "robs", "loose_minus_base")
    qrl, rl = argmin(r_l)
    qrr, rr = argmin(r_r)
    rt_l = ser("learning", "robs", "tight_minus_base")[qrl]
    dyr_q, dyr = argmax(ser("RE", "dy", "loose_minus_base"))
    sh_lo, sh_ti = ser("learning", "n2_model_pinf", "loose_minus_base"), ser("learning", "n2_model_pinf", "tight_minus_base")
    qsl, shl = argmax(sh_lo)
    qst, sht = argmin(sh_ti)
    avg_lo = sum(lo_l.values()) / H
    avg_ti = sum(ti_l.values()) / H
    words = []
    words.append("delays" if qpk > qre else ("brings forward" if qpk < qre else "keeps the timing of"))
    words.append("damps" if lpk < rpk else "amplifies")
    ans = (f"Under learning the response is asymmetric, but only slightly. At the peak, {qpk}, looser policy raises inflation "
           f"by {f(lpk, 3)} pp and tighter policy lowers it by {f(-tpk, 3)} pp; the largest asymmetry (loose + tight) is "
           f"{pp(as_l[qas], 3)} ({qas}), about {f(100 * abs(as_l[qas]) / lpk, 0)}% of the effect. Under RE the two responses "
           f"are exactly symmetric (largest |loose + tight| over 7 series {sci(CHK['C3a']['first'])}, check C3a).")
    p2 = (f"{esc(desc('a3_loose_re').split(';')[0])}, a surprise each quarter. The tight runs hold it the same amount above. "
          f"Each run is measured against the same scenario without the condition (application 1).")
    p3 = (f"Under RE, looser policy raises inflation by up to {f(rpk)} pp ({qre}), lowers the rate by up to {f(-rr)} pp "
          f"({qrr}, including the rule's response) and raises output growth by up to {f(dyr)} pp ({dyr_q}). Learning "
          f"{words[0]} and slightly {words[1]} the inflation effect (peak {f(lpk)} pp in {qpk} vs {f(rpk)} pp in {qre}) and "
          f"{'enlarges' if rl < rr else 'reduces'} the rate effect ({f(-rl)} vs {f(-rr)} pp; tight {pp(rt_l)}). Average "
          f"inflation effects under learning: {pp(avg_lo, 3)} (loose) and {pp(avg_ti, 3)} (tight). The asymmetry comes from "
          f"the learning states, which respond nonlinearly to the paths: looser policy raises the learners' share in force ({code('n2_model')}) by up to "
          f"{f(shl, 3)} ({qsl}) and tighter policy lowers it by up to {f(-sht, 3)} ({qst}).")
    out = []
    for var in VAR4:
        ser_ = []
        for exp, ent in (("RE", "re"), ("learning", "learn")):
            for col, kind in (("loose_minus_base", "loose"), ("tight_minus_base", "tight")):
                nm = f"{'RE' if exp == 'RE' else 'Learning'}, 100 bp {'looser' if kind == 'loose' else 'tighter'}"
                sh_ = f"{'RE' if exp == 'RE' else 'Learn.'} {kind}"
                ser_.append(S(ent, [clean(getattr(A3[(exp, var, q)], col)) for q in HOR], name=nm, short=sh_,
                              **({"style": "dashed"} if kind == "tight" else {})))
        lo, lor = ser("learning", var, "loose_minus_base"), ser("RE", var, "loose_minus_base")
        qq_, _ = argmax({q: abs(v) for q, v in lo.items()})
        qr_, _ = argmax({q: abs(v) for q, v in lor.items()})
        cap = f"Largest loose effect: learning {pp(lo[qq_])} ({qq_}), RE {pp(lor[qr_])} ({qr_})."
        sh = None
        if var == "pinfobs":
            sh = [("Share of learners in force (n2_model), deviation from the baseline", "toolbox field n2_model of pinf",
                   [S("learn", [clean(getattr(A3[("learning", "n2_model_pinf", q)], c)) for q in HOR], name=n, short=s_,
                      **kw) for c, n, s_, kw in (("loose_minus_base", "Learning, 100 bp looser", "Learn. loose", {}),
                                                 ("tight_minus_base", "Learning, 100 bp tighter", "Learn. tight",
                                                  {"style": "dashed"}))], dict(refs=[dict(y=0, label="")]))]
            cap += f" Share in force: {f(shl, 3, True)} loose ({qsl}), {f(sht, 3, True)} tight ({qst})."
        out.append(panel(f"a3-{var}", "a3", f"{VLAB[var]}, deviation from the baseline, pp", cap, HOR, ser_, shares=sh,
                         origin=None, zero=True))
    asy = []
    for var in VAR4:
        sl = ser("learning", var, "asymmetry")
        q_, v_ = argmax({q: abs(v) for q, v in sl.items()})
        asy.append(line(f"a3a-{var}", "a3a", f"{VLAB[var]}: loose + tight, pp",
                        f"Learning: largest {pp(sl[q_], 3)} ({q_}).", HOR,
                        [S("re", [clean(getattr(A3[("RE", var, q)], "asymmetry"), 5) for q in HOR]),
                         S("learn", [clean(getattr(A3[("learning", var, q)], "asymmetry"), 5) for q in HOR])],
                        origin=None, legend=False, h=150, dec=3, zero=True))
    leg3 = [dict(name="RE, 100 bp looser", color="s1"), dict(name="RE, 100 bp tighter", color="s1", style="dashed"),
            dict(name="Learning, 100 bp looser", color="s2"), dict(name="Learning, 100 bp tighter", color="s2", style="dashed")]
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
<p>{p3}</p>
{scode("app3_policy", "a3_loose_re")}
{scode("app3_policy", "a3_tight_re")}
{fig_title(f"Policy 100 bp looser or tighter than the rule, {HOR[0]}-{HOR[3]}: deviations from the baseline")}
{legend("a3", leg3)}
<div class="grid g-2">{"".join(out)}</div>
{tables("a3")}
{fig_title("Asymmetry: loose + tight deviation (zero if the responses are symmetric)")}
{legend("a3a", [leg("re"), leg("learn")])}
<div class="grid g-4">{"".join(asy)}</div>
{tables("a3a")}"""
    return section("app3", 3, "Application 3: policy 100 bp looser or tighter than the Taylor rule", body)


# ----------------------------------------------------------------------------- application 4
WSETS = ["balanced", "hawk", "dove", "smooth"]


def loss_weights(w):
    sid = f"a4_ramsey_{w}_re"
    txt = (SCN / "app4_ramsey" / f"{sid}.m").read_text(encoding="utf-8")
    m = re.search(r"policy\.loss\s*=\s*struct\((.*?)\);", txt)
    pairs = re.findall(r"'(\w+)',\s*([0-9.]+)", m.group(1))
    return ", ".join(f"{k} {v}" for k, v in pairs)


def sec_app4():
    def lc(w, e, p):
        return f"{f(LOSS[(w, e, p, 80)], 1)} <span class=\"muted\">({f(LOSS[(w, e, p, 16)], 1)})</span>"
    MC = "RE_model_consistent"          # rows from the saved runs a4_ramsey_<w>_re_mc
    mc80 = {w: (LOSS[(w, MC, "ramsey", 80)], LOSS[(w, "RE", "rule", 80)]) for w in WSETS}
    beats80 = [w for w in WSETS if mc80[w][0] < mc80[w][1]]
    lose16 = [w for w in WSETS if LOSS[(w, MC, "ramsey", 16)] > LOSS[(w, "RE", "rule", 16)]]
    l_beats = [w for w in WSETS if LOSS[(w, "learning", "ramsey", 80)] < LOSS[(w, "learning", "rule", 80)]
               and LOSS[(w, "learning", "ramsey", 16)] < LOSS[(w, "learning", "rule", 16)]]
    every = "for every weight set" if len(beats80) == len(WSETS) else "for " + ", ".join(beats80)
    b = "balanced"
    ans = (f"With model-consistent RE agents, the saved RE Ramsey plans ({code('a4_ramsey_<w>_re_mc')}), Ramsey policy has a "
           f"lower loss than the Taylor rule over 80 quarters {every} (balanced weights: {f(mc80[b][0], 1)} vs {f(mc80[b][1], 1)})"
           + (f"; over 16 quarters it loses with {', '.join(lose16)} weights ("
              + "; ".join(f"{f(LOSS[(w, MC, 'ramsey', 16)], 1)} vs {f(LOSS[(w, 'RE', 'rule', 16)], 1)}" for w in lose16)
              + ")." if lose16 else "."))
    ratio = LOSS[(b, MC, "ramsey", 80)] / LOSS[(b, "RE", "ramsey", 80)]
    n2m = L("a4_ramsey_balanced_learn", "pinf", "n2_model", HOR[0])
    caveat = (f"<b>Read the Ramsey runs with anchored agents as open.</b> Anchored RE agents forecast with the RE solution "
              f"under the Taylor rule, not under the Ramsey policy; IJCB's anchored agents use the RE solution of the policy in "
              f"force. In these runs inflation expectations stay on the Taylor-rule forecast function while the planner moves "
              f"the rate. This holds for the anchored RE Ramsey runs too (in mode {code('rational')} the inflation block keeps "
              f"the anchored forecast), so they are not RE Ramsey plans: their 80-quarter loss is about {f(ratio, 0)} times "
              f"smaller than the model-consistent one ({b}: {f(LOSS[(b, 'RE', 'ramsey', 80)], 1)} vs "
              f"{f(LOSS[(b, MC, 'ramsey', 80)], 1)}); they appear in the loss table only. Under learning the anchored RE "
              f"agents (a share 1 - {code('n2_model')} = {f(1 - n2m, 3)} in {HOR[0]}) carry the same exploitable forecast, so "
              f"the learning Ramsey losses, and their ratios to the rule, are not gains from optimal policy. This design "
              f"question is open.")
    avg = {(w, v): K(f"avg_{v}__a4_ramsey_{w}_re_mc") for w in WSETS for v in ("pinfobs", "robs", "dy")}
    rule = {v: K(f"avg_{v}__a4_rule_re") for v in ("pinfobs", "robs", "dy")}

    def lst(v):
        return ", ".join(f"{pct(avg[(w, v)])} {w}" for w in WSETS)
    hi_pi = all(avg[(w, "pinfobs")] > rule["pinfobs"] for w in WSETS)
    hi_r = all(avg[(w, "robs")] > rule["robs"] for w in WSETS)
    p2 = (f"Rule losses are the same with anchored and model-consistent RE agents (check C11: inflation paths to "
          f"{sci(CHK['C11']['nums'][0])}, loss to {sci(CHK['C11']['nums'][1])}), and the saved RE Ramsey runs reproduce the "
          f"earlier in-script diagnostic (check C12). Average {HOR[0]}-{END} under the RE Ramsey plans: inflation {lst('pinfobs')} "
          f"({'all above' if hi_pi else 'against'} the rule's {pct(rule['pinfobs'])}); policy rate {lst('robs')} "
          f"({'all above' if hi_r else 'against'} {pct(rule['robs'])}); output growth {lst('dy')} (rule {pct(rule['dy'])}). "
          f"Under learning, Ramsey has the lower loss "
          f"{'for every weight set' if len(l_beats) == len(WSETS) else 'for ' + ', '.join(l_beats)} at both horizons; given the "
          f"caveat, these numbers are not read as policy gains.")
    targets = rx(r"\(targets (.*?\))\)", (SCN / "app4_ramsey" / "a4_ramsey_balanced_re.m").read_text(encoding="utf-8"))
    rows = [[w, esc(loss_weights(w)), lc(w, "RE", "rule"), lc(w, MC, "ramsey"), lc(w, "learning", "rule"),
             lc(w, "learning", "ramsey"), lc(w, "RE", "ramsey")] for w in WSETS]
    tbl = html_table(["Weights", "Loss weights", "Taylor rule, RE", "Ramsey, RE agents (model-consistent, saved runs)",
                      "Taylor rule, learning", "Ramsey, learning (anchored agents: open)",
                      "Ramsey, anchored RE agents (not an RE plan)"], rows, num_from=2, cls="loss",
                     caption=f"Discounted loss over 80 quarters (16 in brackets); targets {esc(targets)}. "
                             f"Source: app4_losses.csv (model-consistent rows from the runs a4_ramsey_&lt;w&gt;_re_mc).")
    lines = [dict(ent="re", scen="a4_rule_re", name="RE, Taylor rule", short="RE rule"),
             dict(ent="re", scen="a4_ramsey_balanced_re_mc", name="RE agents, Ramsey", short="RE Ramsey", style="dashed"),
             dict(ent="learn", scen="a4_rule_learn", name="Learning, Taylor rule", short="Learn. rule"),
             dict(ent="learn", scen="a4_ramsey_balanced_learn", name="Learning, Ramsey (anchored RE agents: open)",
                  short="Learn. Ramsey", style="dashed")]
    out = []
    for var in VAR4:
        ser = []
        for ln in lines:
            sr = S(ln["ent"], pser(ln["scen"], var, QH0, ORIGIN), name=ln["name"], short=ln["short"])
            if ln.get("style"):
                sr["style"] = ln["style"]
            ser.append(sr)
        sh = None
        if var == "pinfobs":
            sser = []
            for ln in lines[2:]:
                sr = S("learn", lser(ln["scen"], "pinf", "n2_model", QH0), name=ln["name"], short=ln["short"])
                if ln.get("style"):
                    sr["style"] = ln["style"]
                sser.append(sr)
            sh = [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf", sser, {})]
        out.append(panel(f"a4-{var}", "a4", f"{VLAB[var]}, {UNIT}", default_cap(var, lines, False, QH0), QH0, ser, shares=sh,
                         bandForecast=False))
    leg4 = [dict(name="RE, Taylor rule", color="s1"), dict(name="RE agents, Ramsey (model-consistent, saved run)", color="s1", style="dashed"),
            dict(name="Learning, Taylor rule", color="s2"), dict(name="Learning, Ramsey (anchored RE agents: open)", color="s2", style="dashed")]
    body = f"""<p class="answer">{ans}</p>
<aside class="box warn" role="note"><p>{caveat}</p></aside>
{tbl}
<p>{p2}</p>
{scode("app4_ramsey", "a4_ramsey_balanced_re")}
{scode("app4_ramsey", "a4_ramsey_balanced_re_mc")}
{scode("app4_ramsey", "a4_ramsey_hawk_re")}
{fig_title(f"Taylor rule vs Ramsey policy, balanced weights, {ORIGIN}-{END}")}
{legend("a4", leg4)}
<div class="grid g-2">{"".join(out)}</div>
{tables("a4")}"""
    return section("app4", 4, "Application 4: Ramsey policy", body)


# ----------------------------------------------------------------------------- application 5
CASES = [("markup", "Mark-up shock uncertainty", "a5_markup"), ("demand", "Demand shock uncertainty", "a5_demand")]


def dens_shocks(case):
    sid = f"a5_{case}_re"
    txt = (SCN / "app5_density" / f"{sid}.m").read_text(encoding="utf-8")
    return re.findall(r"'(\w+)'", rx(r"density\.shocks\s*=\s*\{([^}]*)\}", txt))


SHOCK_WORDS = {"epinf": "price mark-up", "ew": "wage mark-up", "eb": "risk premium", "eg": "government spending",
               "eqs": "investment", "em": "monetary", "ea": "technology"}


def sec_app5():
    def w(case, exp, var, h="avg"):
        return K(f"a5_w90_{h}_{case}_{exp}_{var}")
    mk, dm = "markup", "demand"
    r_mk = w(mk, "learn", "pinfobs") / w(mk, "re", "pinfobs")
    r_dm = w(dm, "learn", "pinfobs") / w(dm, "re", "pinfobs")

    def cmpw(case, h, var="pinfobs"):
        a, b_ = w(case, "learn", var, h), w(case, "re", var, h)
        return a, b_, ("wider" if a > b_ else "narrower")
    hs = ["h4", "h8", "h16"]
    mk_w = [cmpw(mk, h) for h in hs]
    dm_w = [cmpw(dm, h) for h in hs]
    ans = (f"Learning narrows the average 90% inflation band a little under mark-up shock uncertainty and more under demand "
           f"shock uncertainty: {f(w(mk, 'learn', 'pinfobs'))} vs {f(w(mk, 're', 'pinfobs'))} pp (ratio {f(r_mk)}) and "
           f"{f(w(dm, 'learn', 'pinfobs'))} vs {f(w(dm, 're', 'pinfobs'))} pp ({f(100 * (1 - r_dm), 0)}% narrower).")

    def hwords(ws):
        return "; ".join(f"h = {h[1:]}: {f(a)} vs {f(b_)} ({word})" for h, (a, b_, word) in zip(hs, ws))
    p2 = (f"Mark-up shocks, inflation band by horizon, learning vs RE: {hwords(mk_w)}; the output-growth band widens, "
          f"{f(w(mk, 'learn', 'dy'))} vs {f(w(mk, 're', 'dy'))} pp. Demand shocks: {hwords(dm_w)}; the rate band "
          f"{'narrows' if w(dm, 'learn', 'robs') < w(dm, 're', 'robs') else 'widens'} ({f(w(dm, 'learn', 'robs'))} vs "
          f"{f(w(dm, 're', 'robs'))} pp) and the output-growth band is about the same ({f(w(dm, 'learn', 'dy'))} vs "
          f"{f(w(dm, 're', 'dy'))} pp). The learners' share in force ({code('n2_model')}) moves with the draws: its 90% band averages "
          f"{f(w(mk, 'learn', 'n2_model_pinf'), 3)} wide under mark-up shocks and {f(w(dm, 'learn', 'n2_model_pinf'), 3)} under "
          f"demand shocks. Median inflation averages {pct(K('a5_med_avg_markup_learn_pinfobs'))} and "
          f"{pct(K('a5_med_avg_demand_learn_pinfobs'))} with learning (point forecast {pct(K('avg_pinfobs__a1_learn'))}).")
    mtxt = (SCN / "app5_density" / "a5_markup_re.m").read_text(encoding="utf-8")
    nd = int(rx(r"density\.ndraws\s*=\s*(\d+)", mtxt))
    seed = rx(r"density\.seed\s*=\s*(\d+)", mtxt)
    used = [int(K(f"a5_n_used_{c}_learn")) for c in (mk, dm)]
    p3 = (f"{nd} draws per case, normal with the model's calibrated standard deviations, seed {seed}; "
          + ("all draws are used (none explosive or failed). " if all(u == nd for u in used) else
             f"{used[0]} and {used[1]} draws are used. ")
          + f"Learning runs take {f(K('a5_s_per_draw_markup_learn'))} s per draw; the RE runs use the fast linear "
          f"path, equal to the general path to {sci(CHK['C5']['nums'][-1])} on a 10-draw check (C5).")
    mech = pd.read_csv(SUM / "app5_mechanism.csv")
    MR = {(r.shock, r.expectations, r.variable, int(r.h)): float(r.response) for r in mech.itertuples()}
    MSH = [("epinf", "price mark-up"), ("ew", "wage mark-up"), ("eb", "risk premium"), ("eg", "government spending"),
           ("eqs", "investment")]
    HM = sorted({h for (_, _, _, h) in MR})
    br1 = max(abs(MR[(sh, "learning", "pinf_exp1_BR", 1)]) for sh, _ in MSH)
    exr = [MR[(sh, "learning", "pinf_exp1", 1)] / MR[(sh, "RE", "pinf_exp1", 1)] for sh, _ in MSH]
    cross, sums = {}, {}
    for sh, _ in MSH:
        cross[sh] = next(h for h in HM if abs(MR[(sh, "learning", "pinfobs", h)]) > abs(MR[(sh, "RE", "pinfobs", h)]))
        sums[sh] = (sum(abs(MR[(sh, "learning", "pinfobs", h)]) for h in HM) / sum(abs(MR[(sh, "RE", "pinfobs", h)]) for h in HM))
    n2mv = max(abs(v) for (sh, e, var, h), v in MR.items() if e == "learning" and var == "n2_model_pinf")
    a3l = {q: float(A3[("learning", "pinfobs", q)].loose_minus_base) for q in HOR}
    a3r = {q: float(A3[("RE", "pinfobs", q)].loose_minus_base) for q in HOR}
    q3l, q3r = argmax(a3l)[0], argmax(a3r)[0]
    bi = code("beliefs.info = 'lagged'")
    mech_p = (f"Why the bands narrow: a timing effect, not switching that reduces uncertainty. In the quarter a shock hits, "
              f"the learners' expectation does not move ({f(br1)} on impact for every shock), because they forecast from data "
              f"up to t-1 ({bi}, the user's specification). The aggregate inflation expectation "
              f"therefore moves about half as much as under RE (learning / RE {f(min(exr))}-{f(max(exr))} on impact), and "
              f"inflation responds less on impact (table). From h = {min(cross.values())}-{max(cross.values())} on the learning "
              f"response is the larger one; summed over {len(HM)} quarters the absolute responses are close (learning / RE "
              f"{f(min(sums.values()))}-{f(max(sums.values()))}), and the share in force ({code('n2_model')}) moves by at most "
              f"{f(n2mv, 3)}. A band at horizon h adds up the squared responses to all earlier draws, so the smaller impact "
              f"responses narrow it. The same one-quarter delay explains the later inflation peak in application 3 ({q3l} "
              f"under learning vs {q3r} under RE).")
    mrows = [[f"{nm_} ({sh})", f(MR[(sh, "RE", "pinfobs", 1)]), f(MR[(sh, "learning", "pinfobs", 1)]),
              f(MR[(sh, "RE", "pinf_exp1", 1)]), f(MR[(sh, "learning", "pinf_exp1", 1)]), f"h = {cross[sh]}", f(sums[sh])]
             for sh, nm_ in MSH]
    mech_tbl = html_table(["One unit of the shock in " + HOR[0], "Inflation on impact, RE", "Learning",
                           "Aggregate inflation expectation on impact, RE", "Learning", "Learning response larger from",
                           f"Sum of |inflation response| over {len(HM)} quarters, learning / RE"], mrows, num_from=1,
                          caption="Responses in pp (inflation annualised). Source: app5_mechanism.csv.")
    XM = [str(h) for h in HM]
    mech_fig = ('<div class="grid g-2">'
                + line("a5m-pi", "a5m", "Inflation response to one unit of the price mark-up shock, pp",
                       f"Impact: RE {f(MR[('epinf', 'RE', 'pinfobs', 1)])}, learning {f(MR[('epinf', 'learning', 'pinfobs', 1)])}; "
                       f"the learning response is larger from h = {cross['epinf']}.", XM,
                       [S("re", [clean(MR[("epinf", "RE", "pinfobs", h)]) for h in HM]),
                        S("learn", [clean(MR[("epinf", "learning", "pinfobs", h)]) for h in HM])],
                       origin=None, xcat=True, xpre="h = ", xHead="Horizon", h=190, zero=True)
                + line("a5m-ex", "a5m", "Aggregate inflation expectation, same shock, pp",
                       f"Impact: RE {f(MR[('epinf', 'RE', 'pinf_exp1', 1)])}, learning {f(MR[('epinf', 'learning', 'pinf_exp1', 1)])} "
                       f"(the learners' part is {f(br1)} on impact).", XM,
                       [S("re", [clean(MR[("epinf", "RE", "pinf_exp1", h)]) for h in HM]),
                        S("learn", [clean(MR[("epinf", "learning", "pinf_exp1", h)]) for h in HM])],
                       origin=None, xcat=True, xpre="h = ", xHead="Horizon", h=190, zero=True)
                + "</div>")
    figs = []
    for case, ctitle, pre in CASES:
        shocks = dens_shocks(case)
        sw = ", ".join(f"{SHOCK_WORDS.get(s, s)} ({s})" for s in shocks)
        cells = []
        for var in VAR4:
            vals = [DN[(case, e, var, q, k)] for e in ("RE", "learning") for q in HOR for k in (0.05, 0.95)]
            yr = [round(min(vals), 3), round(max(vals), 3)]
            for exp, ent, lab in (("RE", "re", "RE"), ("learning", "learn", "Learning")):
                ek = "re" if exp == "RE" else "learn"
                cap = (f"90% band {f(DN[(case, exp, var, HQ[4], 0.05)])} to {f(DN[(case, exp, var, HQ[4], 0.95)])} at "
                       f"h = 4; average width {f(w(case, ek, var))} pp.")
                cells.append(fan(f"a5-{case}-{var}-{ek}", f"a5{case}", f"{lab}: {VLAB[var].lower()}, {UNIT}", cap, case, exp,
                                 var, ent, yr=yr))
        cap = (f"Median {f(DN[(case, 'learning', 'n2_model_pinf', END, 0.5)], 3)} in {END}; 90% band width "
               f"{f(w(case, 'learn', 'n2_model_pinf', 'h4'), 3)} at h = 4, {f(w(case, 'learn', 'n2_model_pinf', 'h16'), 3)} at "
               f"h = 16.")
        cells.append(fan(f"a5-{case}-n2", f"a5{case}", "Learning: share of learners in force (n2_model), inflation", cap, case,
                         "learning", "n2_model_pinf", "learn", dec=3))
        figs.append(f"""<h3 class="sub">{esc(ctitle)}: {esc(sw)}</h3>
{fig_title(f"{ctitle}: median, 68% and 90% bands, {HOR[0]}-{END}")}
<div class="grid g-fan">{"".join(cells)}</div>
{tables(f"a5{case}")}""")
    rows = []
    for case, ctitle, _ in CASES:
        for var in VAR4 + ["n2_model_pinf"]:
            nmv = VLAB.get(var, "Share of learners")
            d = 3 if var == "n2_model_pinf" else 2
            ratio = w(case, "learn", var) / w(case, "re", var) if w(case, "re", var) > 0 else None
            rows.append([ctitle if var == "pinfobs" else "", nmv, f(w(case, "re", var), d), f(w(case, "learn", var), d),
                         f(ratio) if ratio is not None else "",
                         *[f"{f(w(case, 're', var, h), d)} / {f(w(case, 'learn', var, h), d)}" for h in hs]])
    tbl = html_table(["Case", "Variable", "RE", "Learning", "Learning / RE", "h = 4, RE / learning", "h = 8", "h = 16"],
                     rows, num_from=2, caption="Width of the 90% band (q95 - q05), pp; average over the 16 quarters and at "
                                               "three horizons. Source: key_numbers.csv, app5_widths.csv.")
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
<p>{p3}</p>
{tbl}
<h3 class="sub">Why the bands narrow</h3>
<p>{mech_p}</p>
{mech_tbl}
{fig_title(f"Impulse responses to one unit of the price mark-up shock in {HOR[0]}")}
{mech_fig}
{tables("a5m")}
{scode("app5_density", "a5_markup_re")}
{scode("app5_density", "a5_demand_re")}
{legend("a5", [dict(name="Median", color="ink"), dict(name="68% band", color="ink", kind="band", op=0.42),
               dict(name="90% band", color="ink", kind="band", op=0.2), leg("re", kind="box"), leg("learn", kind="box")])}
{"".join(figs)}"""
    return section("app5", 5, "Application 5: density forecasts", body)


def fan(cid, group, title, cap, case, exp, var, ent, yr=None, dec=2):
    q = {k: [clean(DN.get((case, exp, var, d, k))) for d in HOR] for k in (0.05, 0.16, 0.5, 0.84, 0.95)}
    col = ENT[ent]["color"]
    ser = [dict(name="Median", short="Median", color=col, v=q[0.5], width=2)]
    bands = [dict(name="90% band", lo=q[0.05], hi=q[0.95], color=col, op=0.16),
             dict(name="68% band", lo=q[0.16], hi=q[0.84], color=col, op=0.3)]
    extra = [dict(name=n, v=q[k], dec=dec) for n, k in (("q05", 0.05), ("q16", 0.16), ("q84", 0.84), ("q95", 0.95))]
    kw = dict(bands=bands, extra=extra, legend=False, endLabels=False, dec=dec, origin=None)
    if yr:
        kw["yr"] = yr
    return line(cid, group, title, cap, HOR, ser, **kw)


# ----------------------------------------------------------------------------- application 6
DCASES = [("re_smooth", "RE smoother"), ("learn_smooth", "Learning on the RE-smoothed history"),
          ("learn_inv", "Learning, shocks backed out by the learning model")]
# five component colours plus grey, stacked so that neighbouring segments pass the colour checks in light and dark mode
# (grey-s4, s4-s5, s5-s6, s6-s7, s7-s8); same-sign components sit next to each other in the 2021-2023 bars
GROUPS = [("init", "Initial conditions", "g0"), ("markups", "Mark-ups, price and wage (epinf, ew)", "s4"),
          ("intercept_channel", "Intercept channel (perceived means)", "s5"), ("monetary", "Monetary (em)", "s6"),
          ("demand", "Demand (eb, eg, eqs)", "s7"), ("supply", "Supply (ea)", "s8")]
DV = [("pinfobs", "Inflation"), ("dy", "Output growth")]
for _k in [k for k in list(DC) if k[2] == "price_markup"]:
    DC[(_k[0], _k[1], "markups", _k[3])] = DC[_k] + DC[(_k[0], _k[1], "wage_markup", _k[3])]


def davg(case, var, comp, a, b):
    xs = [DC[(case, var, comp, q)] for q in qrange(a, b)]
    return sum(xs) / len(xs)


def sec_app6():
    XA = sorted({d for (c, v, k, d) in DC})
    q15 = "2015Q1"
    sd = {}
    for s_ in ["epinf", "ew", "eqs", "eb", "em", "ea", "eg"]:
        d = shk[shk.shock == s_].set_index("date").diff_sd
        qd = d.abs().idxmax()
        sd[s_] = (K(f"a6_shock_rms_sd_{s_}"), K(f"a6_shock_rms_sd_2021_2023_{s_}"), float(d[qd]), qd)
    a, b = "2021Q1", "2023Q4"
    COMPS = ["demand", "monetary", "supply", "price_markup", "wage_markup", "markups", "intercept_channel", "init", "total"]
    dv = {(c, v, k): davg(c, v, k, a, b) for c, _ in DCASES for v, _ in DV for k in COMPS}
    e = sd["epinf"]
    ans = (f"Backed out with the learning model, the history needs mainly different price mark-up shocks: the inversion minus "
           f"the RE-smoothed shocks has an RMS of {f(e[0])} sd over {FIRST}-{END} and {f(e[1])} sd over 2021-2023, largest "
           f"{f(e[2])} sd in {e[3]}. Over {a}-{b} the learning decomposition gives less of the inflation surge to price "
           f"mark-ups ({f(dv[('learn_inv', 'pinfobs', 'price_markup')])} vs {f(dv[('re_smooth', 'pinfobs', 'price_markup')])} pp) "
           f"and monetary shocks ({f(dv[('learn_inv', 'pinfobs', 'monetary')])} vs {f(dv[('re_smooth', 'pinfobs', 'monetary')])}), "
           f"almost nothing to wage mark-ups ({f(dv[('learn_inv', 'pinfobs', 'wage_markup')])} vs "
           f"{f(dv[('re_smooth', 'pinfobs', 'wage_markup')])}) and {pp(dv[('learn_inv', 'pinfobs', 'intercept_channel')])} to the "
           f"intercept channel.")
    others = "; ".join(f"{SHOCK_WORDS[s_]} {f(sd[s_][0], 3 if sd[s_][0] < 0.1 else 2)} sd" +
                       (f" ({f(sd[s_][1], 2)} in 2021-2023)" if s_ in ("ew", "eqs") else "") for s_ in ["ew", "eqs", "eb", "em", "ea", "eg"])
    p2 = (f"Other shocks, RMS of the change over {FIRST}-{END}: {others}. The inversion fits the 7 observables to "
          f"{sci(CHK['C9']['first'])} (check C9). The end-of-quarter share ({code('n2')}) at the end of {ORIGIN} is "
          f"{f(K('a6_n2_2022Q2_inv'), 3)} in the inversion and {f(K('a6_n2_2022Q2_smooth'), 3)} on the RE-smoothed history; "
          f"{f(K('a6_n2_2026Q2_inv'), 3)} vs {f(K('a6_n2_2026Q2_smooth'), 3)} at the end of {END} (last figure). For output "
          f"growth the learning decomposition gives more to demand ({f(dv[('learn_inv', 'dy', 'demand')])} vs "
          f"{f(dv[('re_smooth', 'dy', 'demand')])} pp) and {pp(dv[('learn_inv', 'dy', 'intercept_channel')])} to the intercept channel.")
    p3 = (f"The intercept channel is the toolbox component {code('beliefs_constants')}: the contribution of the learners' "
          f"moving perceived mean. Slope beliefs and shares act inside every shock component. Learning on the RE-smoothed "
          f"history gives the RE decomposition (to {sci(CHK['C6b']['first'])}, check C6b): without the inversion the history is "
          f"the RE-smoothed one, decomposed with the RE model. All three decompositions rebuild their paths (C6). Bars: "
          f"contributions in pp, deviations from the RE steady state; line: the total. The charts draw price and wage mark-ups "
          f"together; the table keeps them apart.")
    charts = []
    for var, vl in DV:
        clip = COVID if var == "dy" else []
        yrs = {}
        for start in (q15, XA[0]):
            vals = []
            for c, _ in DCASES:
                for q in XA:
                    if q < start or q in clip:
                        continue
                    cs = [DC[(c, var, k, q)] for k, _, _ in GROUPS]
                    vals += [sum(x for x in cs if x > 0), sum(x for x in cs if x < 0), DC[(c, var, "total", q)]]
            yrs[start] = [round(min(vals), 3), round(max(vals), 3)]
        for c, cl in DCASES:
            series = [dict(name=gl, color=col, v=[clean(DC[(c, var, k, q)]) for q in XA]) for k, gl, col in GROUPS]
            total = dict(name="Total deviation", v=[clean(DC[(c, var, "total", q)]) for q in XA])
            cid = f"a6-{var}-{c}"
            CHARTS[cid] = {"id": cid, "type": "stack", "group": "a6", "title": f"{vl}: {cl}", "x": XA, "series": series,
                           "total": total, "yrs": yrs, "clip": clip, "legend": False, "origin": None, "toggle": "a6r",
                           "from": q15}
            cap = (f"Average {a}-{b}: mark-ups {f(dv[(c, var, 'markups')])}, monetary {f(dv[(c, var, 'monetary')])}, "
                   f"demand {f(dv[(c, var, 'demand')])}, intercept channel {f(dv[(c, var, 'intercept_channel')], 2, True)}; total "
                   f"{f(dv[(c, var, 'total')])} pp." + (" The 2020 bars run off the scale." if clip else ""))
            charts.append(((c, var), f'<figure class="chart"><figcaption class="ct">{esc(vl)}: {esc(cl)}</figcaption>'
                                     f'<div class="plot" data-chart="{cid}"></div><p class="cap">{cap}</p></figure>'))
    byk = dict(charts)
    ordered = [byk[(c, var)] for c, _ in DCASES for var, _ in DV]   # rows = histories, columns = variables
    tcomps = [("demand", "Demand"), ("monetary", "Monetary"), ("supply", "Supply"), ("price_markup", "Price mark-up"),
              ("wage_markup", "Wage mark-up"), ("intercept_channel", "Intercept channel"), ("init", "Initial conditions"),
              ("total", "Total")]
    rows = []
    for var, vl in DV:
        for c, cl in DCASES:
            rows.append([vl if c == "re_smooth" else "", cl] + [f(dv[(c, var, k)]) for k, _ in tcomps])
    tbl = html_table(["Variable", "History"] + [t for _, t in tcomps], rows, num_from=2,
                     caption=f"Average contribution {a}-{b}, pp deviation from the RE steady state. Source: app6_decomp_long.csv.")
    seg = (f'<div class="seg" role="group" aria-label="Range of the bar charts" data-toggle="a6r">'
           f'<button type="button" data-from="{q15}" aria-pressed="true">{q15[:4]}-{END[:4]}</button>'
           f'<button type="button" data-from="{XA[0]}" aria-pressed="false">{XA[0][:4]}-{END[:4]} (full sample)</button></div>')
    n2c = (f"End of {ORIGIN}: inversion {f(K('a6_n2_2022Q2_inv'), 3)}, RE-smoothed history {f(K('a6_n2_2022Q2_smooth'), 3)}; end of "
           f"{END}: {f(K('a6_n2_2026Q2_inv'), 3)} vs {f(K('a6_n2_2026Q2_smooth'), 3)}; average {FIRST}-{END}: "
           f"{f(K('a6_n2_hist_mean_inv'), 3)} vs {f(K('a6_n2_hist_mean_smooth'), 3)}.")
    n2fig = line("a6-n2", "a6n2", "End-of-quarter share of learners (n2), inflation", n2c, QF,
                 [S("learn", lser("a6_smooth_learn", "pinf", "n2", QF, end=END), name="Learning on the RE-smoothed history",
                    short="RE-smoothed"),
                  S("learn", lser("a6_inv_learn", "pinf", "n2", QF, end=END), color="s3",
                    name="Learning, shocks backed out (inversion)", short="Inversion")], origin=None, h=210, dec=3)
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
<p>{p3}</p>
{scode("app6_history", "a6_inv_learn")}
{fig_title("Shock decompositions of inflation and output growth: three histories")}
{seg}
{legend("a6", [dict(name=gl, color=col, kind="box") for _, gl, col in GROUPS] + [dict(name="Total deviation", color="fg", width=1.5)])}
<div class="grid g-2">{"".join(ordered)}</div>
{tables("a6")}
{tbl}
{fig_title(f"The learners' end-of-quarter share with the shocks backed out vs on the RE-smoothed history, {FIRST}-{END}")}
<div class="grid g-1w">{n2fig}</div>
{tables("a6n2")}"""
    return section("app6", 6, "Application 6: history with the shocks backed out under learning", body)


# ----------------------------------------------------------------------------- variant 1
def sec_var1():
    mc, le, re_ = "v1_mc_learn", "a1_learn", "a1_re"
    evd = ev_dates(mc)
    roots = [float(x) for x in re.findall(r"largest root ([0-9.]+)", " ".join(
        evl[(evl.scenario == mc) & (evl.stage == "forecast")].sort_values("date").detail))]
    pq = [q for q in ("2022Q3", "2023Q2", "2024Q2", "2025Q2", "2026Q2") if f"v1_pinf_{q}" in KN]
    items = [f"{pct(K('v1_pinf_' + q))} in {q}" for q in pq]
    path = ", ".join(items[:-1]) + " and " + items[-1]
    pm = {q: LL[(mc, "pinf", "perceived_mean_report", q)] for q in HOR}
    qmx, pmx = argmax(pm)
    held = f"{evd[0]}-{evd[-1]}" if len(evd) > 1 else evd[0]
    qpk, vpk = argmax({q: P(mc, "pinfobs", q) for q in HOR})
    ans = (f"With model-consistent RE agents learning raises average inflation by {f(K('avg_pinfobs__' + mc) - K('avg_pinfobs__' + re_))} pp "
           f"over RE instead of {f(K('avg_pinfobs__' + le) - K('avg_pinfobs__' + re_))} pp: {pct(K('avg_pinfobs__' + mc))} vs "
           f"{pct(K('avg_pinfobs__' + le))} (anchored) and {pct(K('avg_pinfobs__' + re_))} (RE). The average hides a boom and bust: "
           f"inflation is {path}.")
    p2 = (f"The learners' perceived mean inflation goes from {pct(K('v1_pmean_2022Q3'), 1)} (end of {HOR[0]}) to {pct(pmx, 1)} "
          f"({qmx}, its high) and {pct(K('v1_pmean_2026Q2'), 1)} ({END}); the projection facility holds the beliefs in {held} "
          f"(candidate roots {' and '.join(f(r, 3) for r in roots)}; rings on the line). Mechanism: model-consistent RE agents "
          f"forecast the heterogeneous economy as if the learners' current beliefs were permanent, so they first amplify the "
          f"learners' high perceived mean and then its fall.")
    p3 = (f"Anchored RE agents use the forecast of the pure-RE model at the current state. Model-consistent RE agents forecast "
          f"the heterogeneous economy itself ({code('x{+1}')} of the model with the learners in it), which is re-solved every "
          f"quarter with the current beliefs and shares. Policy rate {pct(K('avg_robs__' + mc))} vs {pct(K('avg_robs__' + le))}; "
          f"output growth {pct(K('avg_dy__' + mc))} vs {pct(K('avg_dy__' + le))}. The end-of-quarter share ({code('n2')}) at the "
          f"end of {ORIGIN} is the same ({f(K('n2_origin__' + mc), 3)}: the history is the same RE-smoothed history), but the "
          f"share in force ({code('n2_model')}) differs: {f(K('v1_n2_model_2022Q4'), 3)} in 2022Q4, {f(K('v1_n2_model_2024Q1'), 3)} "
          f"in 2024Q1, {f(K('v1_n2_model_2025Q2'), 3)} in 2025Q2 and {f(K('n2_model_2026Q2__' + mc), 3)} in {END}. In the "
          f"evaluation it is the weakest inflation variant (relative RMSE "
          f"{' / '.join(f(ER[('full', 'e03_learn_mc', 'pinfobs', h)], 3) for h in (1, 4, 8))} at h = 1 / 4 / 8, "
          f"<a href=\"#evaluation\">section 11</a>).")
    lines = [dict(ent="re", scen=re_), dict(ent="learn", scen=le, name="Learning, anchored RE agents", short="Anchored"),
             dict(ent="mc", scen=mc, rings=evd)]
    shares = {"pinfobs": [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf", lines[1:], "pinf")]}
    caps = {"pinfobs": default_cap("pinfobs", lines, True, Q18) + f" Model-consistent: {path}; beliefs held by the facility in "
                                                                 f"{held} (rings)."}
    g1 = forecast_grid("v1", lines, shares=shares, caps=caps)
    hcap = (f"The two runs share the history to {ORIGIN}; they part in the forecast. Beta at {ORIGIN}: "
            f"{f(K('coef_origin__' + mc + '__beta_pinf'), 3)} in both.")
    g2 = history_figure("v1h", "Share of learners and perceived persistence, inflation", hcap,
                        [("learn", le, "pinf", dict(name="Anchored", short="Anchored")), ("mc", mc, "pinf", {})],
                        [("learn", le, "pinf", "beta_pinf", dict(name="Anchored", short="Anchored")),
                         ("mc", mc, "pinf", "beta_pinf", {})])
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
<p>{p3}</p>
{scode("var1_re_variant", "v1_mc_learn")}
{fig_title(f"Anchored vs model-consistent RE agents, {Q18[0]}-{END}: with model-consistent RE agents inflation peaks at {pct(vpk)} in {qpk} and falls to {pct(P(mc, 'pinfobs', END))} in {END}")}
{legend("v1", [leg("data"), leg("re"), leg("learn", name="Learning, anchored RE agents (baseline)"), leg("mc"),
               dict(name="Projection-facility event (beliefs kept)", color="s3", kind="dot")])}
{g1}
{tables("v1")}
{fig_title(f"Share and perceived persistence, both RE variants, {FIRST}-{END}")}
<div class="grid g-1w">{g2}</div>
{tables("v1h")}"""
    return section("var1", 7, "Model variant 1: anchored vs model-consistent RE", body)


# ----------------------------------------------------------------------------- variant 2
PLMS = [("a1_learn", "learn", "AR(1), the baseline", "AR(1)", "var2_plm", None),
        ("v2_ar2", "ar2", None, None, "var2_plm", "v2_ar2"),
        ("v2_ar1nc", "ar1nc", None, None, "var2_plm", "v2_ar1nc"),
        ("v2_reg", "reg", None, None, "var2_plm", "v2_reg"),
        ("v2_var3", "var3", None, None, "var2_plm", "v2_var3"),
        ("v2_var12", "var12", None, None, "var2_plm", "v2_var12")]
V12W = {"pinf": "inflation", "c": "consumption", "inve": "investment", "lab": "hours", "w": "real wage", "pk": "Tobin's q",
        "rk": "rental rate of capital", "cf": "consumption, flex-price", "invef": "investment, flex-price",
        "labf": "hours, flex-price", "pkf": "Tobin's q, flex-price", "rkf": "rental rate, flex-price"}


def plm_name(sid, ent, nm):
    return nm or ENT[ent]["name"]


def pshort(sid):
    p = next(x for x in PLMS if x[0] == sid)
    return p[3] or ENT[p[1]]["short"]


def sec_var2():
    ids = [p[0] for p in PLMS]
    avg = {s: K(f"avg_pinfobs__{s}") for s in ids}
    n2o = {s: K(f"n2_origin__{s}") for s in ids}
    pmo = {s: K(f"pmean_origin__{s}") for s in ids}
    ans = (f"The PLM moves the learners' end-of-quarter share ({code('n2')}) at the origin ({range_txt(n2o.values())}) and their perceived mean "
           f"({range_txt(pmo.values(), 1)}%) far more than average inflation ({range_txt(avg.values(), 2)}%).")
    v3 = "v2_var3"
    v3_min_q, v3_min = argmin({q: L(v3, "pinf", "n2_model", q) for q in HOR})
    kept_sh = ev_dates(v3, types=["projection_alm_shares"])
    kept_b = ev_dates(v3, types=["projection_plm"])
    QO = qrange(FIRST, ORIGIN)
    ar2_ev = sorted((n.rsplit("_", 1)[1], v) for n, v in KN.items() if n.startswith("v2_ar2_hist_event_"))
    pre = [(d, r) for d, r in ar2_ev if d in QO[-4:]]
    held2 = QO[QO.index(pre[0][0]) - 1] if pre else ORIGIN
    other = [d for d, _ in ar2_ev if d not in dict(pre)]
    unchanged = float(K(f"v2_ar2_belief_change_{held2}_{ORIGIN}")) == 0 if f"v2_ar2_belief_change_{held2}_{ORIGIN}" in KN else False
    ar2_txt = (f"The AR(2) beliefs in force at the origin are those of {held2}: the facility rejected the updates of "
               f"{', '.join(d for d, _ in pre)} (candidate roots {', '.join(f(r, 3) for _, r in pre)}), so the AR(2) "
               f"coefficients at {ORIGIN} {'are unchanged since' if unchanged else 'come from'} {held2}"
               + (f"; its other history event is {', '.join(other)}." if other else "."))
    p2 = (f"Only the inflation expectation uses the PLM; the other equations of the regression and VAR PLMs (output gap, "
          f"rate, and the 11 other variables of the 12-variable VAR) are auxiliary: learned the same way and used only to "
          f"forecast the regressors. The VAR(1) in inflation, output gap and rate leans on the projection facility: its beliefs "
          f"are kept in {int(K('plm_quarters_forecast__' + v3))} of the {H} forecast quarters ({kept_b[0]}-{kept_b[-1]}, roots "
          f"{f(K('plm_root_forecast_min__' + v3))}-{f(K('plm_root_forecast_max__' + v3))}) and the shares in force ({code('n2_model')}) are "
          f"held at {f(K('v2_var3_n2_model_2023Q1'), 3)} in {len(kept_sh)} ({kept_sh[0]}-{kept_sh[-1]}). Its share in force then falls to "
          f"{f(v3_min, 3)} in {v3_min_q}. Read its path with that in mind; the regression and the 12-variable VAR also have "
          f"forecast events (rings on the lines, counts in the table). " + ar2_txt)
    rows = []
    for sid, ent, nm, _, _, _ in PLMS:
        coefs = [(n.split("__", 2)[2], v) for n, v in KN.items() if n.startswith(f"coef_origin__{sid}__")]
        if sid == "v2_var12":
            own = [(c, v) for c, v in coefs if c in ("alpha_pinf", "beta_pinf__pinf_l1")]
            oth = sorted([(c, v) for c, v in coefs if c not in ("alpha_pinf", "beta_pinf__pinf_l1")], key=lambda t: -abs(t[1]))[:4]
            coefs = own + oth
        ctxt = ", ".join(f"{code(c)} {f(v, 3)}" for c, v in coefs)
        hist = sum(ev_count(sid, k, "history") for k in ("plm", "alm", "alm_shares"))
        fc = [ev_count(sid, k, "forecast") for k in ("plm", "alm", "alm_shares")]
        fct = f"{fc[0]}" + (f" + {fc[1]} ALM" if fc[1] else "") + (f" + {fc[2]} with shares kept" if fc[2] else "")
        pm = f"{pct(pmo[sid])}" + (" (fixed at the steady state)" if sid == "v2_ar1nc" else "")
        rows.append([esc(plm_name(sid, ent, nm)), pct(avg[sid]), f(n2o[sid], 3), f(K(f"persist_origin__{sid}"), 3), pm, ctxt,
                     f"{hist} / {fct}"])
    tbl = html_table(["PLM for inflation", "Average inflation", f"End-of-quarter share (n2), {ORIGIN}", f"Largest root, {ORIGIN}",
                      f"Perceived mean, {ORIGIN}", f"Coefficients at {ORIGIN}", "Facility events, history / forecast"],
                     rows, num_from=1, cls="plm", caption="Average inflation over the forecast; 12-variable VAR: own lag "
                                                          f"and the four largest other coefficients. AR(2): the coefficients of {held2}, held by the facility (text). "
                                                          "Source: key_numbers.csv, "
                                                          "scenarios.csv.")
    PS = {"v2_ar2": "AR(2)", "v2_ar1nc": "AR(1) nc", "v2_reg": "Regr.", "v2_var3": "VAR(1) 3", "v2_var12": "VAR(1) 12"}
    base = dict(ent="learn", scen="a1_learn", name="AR(1), the baseline", short="AR(1)")
    rows_html = []
    for sid, ent, _, _, _, _ in PLMS[1:]:
        ln = dict(ent=ent, scen=sid, short=PS[sid])
        fe = ev_dates(sid)
        if fe:
            ln["rings"] = fe
        if sid == v3:
            ln["share_rings"] = kept_sh
        lines = [dict(ent="re", scen="a1_re"), base, ln]
        caps = {var: (f"Average {HOR[0]}-{END}: {PS[sid]} {pct(pavg(sid, var))}; AR(1) {pct(pavg('a1_learn', var))}; RE "
                      f"{pct(pavg('a1_re', var))}." + (" 2020 runs off the scale." if var in ("dy", "dc") else ""))
                for var in VAR4}
        shares = {"pinfobs": [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf", [base, ln], "pinf")]}
        g = forecast_grid(f"v2-{sid}", lines, shares=shares, caps=caps, grid="g-4", group="v2")
        hist = sum(ev_count(sid, k, "history") for k in ("plm", "alm", "alm_shares"))
        fb, fs = ev_count(sid, "plm", "forecast"), ev_count(sid, "alm_shares", "forecast")
        flag = (f"projection facility: {hist} event{'s' if hist != 1 else ''} in the history; "
                + (f"beliefs kept in {fb} forecast quarters, model shares in {fs}" if fs else
                   (f"{fb} in the forecast" if fb else "none in the forecast")))
        if sid == "v2_ar2" and pre:
            flag = (f"projection facility: {hist} events in the history, {len(pre)} of them in the quarters just before the "
                    f"origin, so the {held2} beliefs are in force at {ORIGIN}; none in the forecast")
        rows_html.append(f'<h4 class="rowt">{esc(ENT[ent]["name"])} <span class="muted">({flag})</span></h4>{g}')
    figs = [f"""{fig_title(f"Forecast from the {ORIGIN} peak with each alternative PLM, {Q18[0]}-{END}: one row per PLM")}
{legend("v2", [leg("data"), leg("re"), leg("learn", name="AR(1), the baseline"), dict(name="The PLM named above the row", color="s3"),
               dict(name="Projection-facility event in the forecast (on inflation: beliefs kept; on the share: shares kept)", color="s3", kind="dot")])}
{"".join(rows_html)}
{tables("v2")}"""]
    COEF = {"v2_ar2": [("beta_pinf__pinf_l1", "lag 1", "solid"), ("beta_pinf__pinf_l2", "lag 2", "dashed")],
            "v2_ar1nc": [("beta_pinf__pinf_l1", "lag 1", "solid")],
            "v2_reg": [("beta_pinf__pinf_l1", "inflation", "solid"), ("beta_pinf__ygap_l1", "output gap", "dashed"),
                       ("beta_pinf__r_l1", "rate", "dotted")],
            "v2_var3": [("beta_pinf__pinf_l1", "inflation", "solid"), ("beta_pinf__ygap_l1", "output gap", "dashed"),
                        ("beta_pinf__r_l1", "rate", "dotted")],
            "v2_var12": [("beta_pinf__pinf_l1", "inflation", "solid")]}
    WORD = {"lag 1": "first lag of inflation", "lag 2": "second lag of inflation", "inflation": "lagged inflation",
            "output gap": "lagged output gap", "rate": "lagged policy rate"}
    bb = L("a1_learn", "pinf", "beta_pinf", ORIGIN)
    crow = []
    for sid, ent, _, _, _, _ in PLMS[1:]:
        ser = [S(ent, lser(sid, "pinf", fld, QF), name=f"{ENT[ent]['short']}: coefficient on the {WORD[lab]} ({fld.split('__')[1]})",
                 short=lab, **({"style": st} if st != "solid" else {})) for fld, lab, st in COEF[sid]]
        ser.append(S("learn", lser("a1_learn", "pinf", "beta_pinf", QF), name="AR(1), the baseline: beta", short="AR(1) beta"))
        cap = (f"At {ORIGIN}: " + ", ".join(f"{lab} {f(L(sid, 'pinf', fld, ORIGIN), 3)}" for fld, lab, _ in COEF[sid])
               + f"; AR(1) beta {f(bb, 3)}." + (" The other 11 coefficients are in the next figure." if sid == "v2_var12" else ""))
        c1 = line(f"v2c-{sid}", "v2c", f"Coefficients of the inflation equation", cap, QF, ser, legend=False, h=180, dec=3)
        pser_ = [S(ent, lser(sid, "pinf", "persistence", QF), name=f"{ENT[ent]['short']}: largest root", short=PS[sid]),
                 S("learn", lser("a1_learn", "pinf", "persistence", QF), name="AR(1), the baseline", short="AR(1)")]
        c2 = line(f"v2p-{sid}", "v2c", "Perceived persistence: largest root of the PLM block",
                  f"At {ORIGIN}: {f(K('persist_origin__' + sid), 3)} (AR(1) {f(K('persist_origin__a1_learn'), 3)}).", QF, pser_,
                  legend=False, h=180, dec=3, refs=[dict(y=1, label="1")])
        c3 = line(f"v2s-{sid}", "v2c", "End-of-quarter share of learners (n2)",
                  f"End of {ORIGIN}: {f(K('n2_origin__' + sid), 3)} (AR(1) {f(K('n2_origin__a1_learn'), 3)}).", QF,
                  [S(ent, lser(sid, "pinf", "n2", QF), name=f"{ENT[ent]['short']}: end-of-quarter share (n2)", short=PS[sid]),
                   S("learn", lser("a1_learn", "pinf", "n2", QF), name="AR(1), the baseline: end-of-quarter share (n2)",
                     short="AR(1)")], legend=False, h=180, dec=3)
        crow.append(f'<h4 class="rowt">{esc(ENT[ent]["name"])}</h4><div class="grid g-3">{c1}{c2}{c3}</div>')

    def cser(sid, fld, **kw):
        p = next(x for x in PLMS if x[0] == sid)
        d = dict(name=p[2], short=p[3]) if p[2] else {}
        d.update(kw)
        return S(p[1], lser(sid, "pinf", fld, QF), **d)
    v12 = [(n.split("__", 2)[2], v) for n, v in KN.items() if n.startswith("coef_origin__v2_var12__beta_pinf__")]
    v12 = sorted(v12, key=lambda t: -abs(t[1]))
    sm = []
    for cname, cv in v12:
        u = cname.replace("beta_pinf__", "").replace("_l1", "")
        wd = V12W.get(u, u)
        sm.append(line(f"v2v-{u}", "v2v", f"{wd[0].upper() + wd[1:]} ({u}{{-1}})", f"{ORIGIN}: {f(cv, 3)}", QF,
                       [cser("v2_var12", cname)], legend=False, h=135, dec=3, zero=True))
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
{tbl}
<details class="tables"><summary>The scenario lines for the five PLMs</summary>
{"".join(scode("var2_plm", s) for s in ("v2_ar2", "v2_ar1nc", "v2_reg", "v2_var3", "v2_var12"))}
</details>
{"".join(figs)}
{fig_title(f"Belief coefficients, perceived persistence and the learners' end-of-quarter share for each PLM, {FIRST}-{END}")}
{legend("v2c", [leg("learn", name="AR(1), the baseline: beta"), dict(name="The PLM named above the row (coefficients: solid, dashed, dotted as labelled)", color="s3")])}
{"".join(crow)}
{tables("v2c")}
{fig_title(f"VAR(1) in the 12 forward-looking variables: the 12 coefficients of the inflation equation, {FIRST}-{END}, ordered by size at {ORIGIN}")}
<div class="grid g-sm">{"".join(sm)}</div>
{tables("v2v")}"""
    return section("var2", 8, "Model variant 2: perceived laws of motion", body)


# ----------------------------------------------------------------------------- variant 3
def sec_var3():
    le, al = "a1_learn", "v3_all"
    ans = (f"Learning on all {N12} forward-looking variables raises average inflation to {pct(K('avg_pinfobs__' + al))}, "
           f"against {pct(K('avg_pinfobs__' + le))} with learning on inflation only and {pct(K('avg_pinfobs__a1_re'))} under RE.")
    avs = {s: float(fac.loc[s, "avg_pinfobs_2022Q3_2026Q2"]) for s in ("v3_all", "v3_all_alm", "v3_all_none")}
    spread = max(avs.values()) - min(avs.values())
    fe = ev_dates(al)
    p2 = (f"End-of-quarter shares ({code('n2')}) at the end of {ORIGIN}, mean over the {N12} variables: {f(K('n2_origin_mean_all__' + al), 3)} (highest "
          f"{f(K('n2_origin_max_all__' + al), 3)}); inflation {f(K('n2_origin__' + al), 3)}. The run leans on the projection "
          f"facility: {ev_count(al, 'plm', 'history')} PLM-block events in the history and {ev_count(al, 'plm', 'forecast')} in "
          f"the forecast (rings mark the {len(fe)} forecast quarters with an event in any block). Policy rate "
          f"{pct(K('avg_robs__' + al))} vs {pct(K('avg_robs__' + le))}; output growth {pct(K('avg_dy__' + al))} vs "
          f"{pct(K('avg_dy__' + le))}.")
    lines = [dict(ent="re", scen="a1_re"), dict(ent="learn", scen=le, name="Learning on inflation only", short="Infl. only"),
             dict(ent="all12", scen=al, rings=fe)]
    shares = {"pinfobs": [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf", lines[1:], "pinf")],
              "dc": [("Share of learners in force (n2_model), consumption (all 12 variables)", "toolbox field n2_model of c",
                      [lines[2]], "c")]}
    g1 = forecast_grid("v3", lines, shares=shares)
    hcap = (f"Inflation, both cases, and consumption, all-variables case. At the end of {ORIGIN}: end-of-quarter share (n2) "
            f"{f(L(le, 'pinf', 'n2', ORIGIN), 3)} / {f(L(al, 'pinf', 'n2', ORIGIN), 3)} / {f(L(al, 'c', 'n2', ORIGIN), 3)}; "
            f"beta {f(L(le, 'pinf', 'beta_pinf', ORIGIN), 3)} / {f(L(al, 'pinf', 'beta_pinf', ORIGIN), 3)} / "
            f"{f(L(al, 'c', 'beta_c', ORIGIN), 3)}.")
    g2 = stacked("v3h", "Share of learners and perceived persistence", hcap, [
        ("End-of-quarter share of learners (n2)", QF,
         [S("learn", lser(le, "pinf", "n2", QF), name="Inflation, learning on inflation only", short="Infl., infl. only"),
          S("all12", lser(al, "pinf", "n2", QF), name="Inflation, all 12", short="Infl., all 12"),
          S("all12", lser(al, "c", "n2", QF), name="Consumption, all 12", short="Cons., all 12", style="dashed")], {}),
        ("Perceived persistence (beta)", QF,
         [S("learn", lser(le, "pinf", "beta_pinf", QF), name="Inflation, learning on inflation only", short="Infl., infl. only"),
          S("all12", lser(al, "pinf", "beta_pinf", QF), name="Inflation, all 12", short="Infl., all 12"),
          S("all12", lser(al, "c", "beta_c", QF), name="Consumption, all 12", short="Cons., all 12", style="dashed")], {})])
    frows = []
    for s in ("a1_learn", "v3_all", "v3_all_alm", "v3_all_none"):
        r = fac.loc[s]
        em = "" if pd.isna(r.error_message) else esc(str(r.error_message))
        frows.append([code(s), code(r.facility), "inflation" if r.variables == "pinf" else f"all {N12}", esc(str(r.status)),
                      em or "none", f"{int(r.projection_plm_history)} / {int(r.projection_plm_forecast)}",
                      f"{int(r.projection_alm_history)} / {int(r.projection_alm_forecast)}",
                      f"{int(r.projection_alm_shares_history)} / {int(r.projection_alm_shares_forecast)}",
                      f"{int(r.explosive_history)} / {int(r.explosive_forecast)}", pct(float(r.avg_pinfobs_2022Q3_2026Q2))])
    ftbl = html_table(["Run", "Facility", "Learning on", "Status", "Error message", "PLM-block events", "ALM events",
                       "Shares kept", "Explosive quarters", "Average inflation"], frows, num_from=5,
                      caption="Events as history / forecast. Source: v3_facility.csv.")
    rn = fac.loc["v3_all_none"]
    stopped = not pd.isna(rn.error_message)
    p3 = (f"{code('plm_alm')} keeps a block's previous beliefs when its largest root would exceed 1: "
          f"{int(fac.loc['v3_all', 'projection_plm_history'])} times in the history and "
          f"{int(fac.loc['v3_all', 'projection_plm_forecast'])} in the forecast. {code('alm')} lets the PLMs go explosive and "
          f"reverts every belief only when the model has no stable solution: {times(int(fac.loc['v3_all_alm', 'projection_alm_history']))} "
          f"in the history and {times(int(fac.loc['v3_all_alm', 'projection_alm_forecast']))} in the forecast. {code('none')} restricts "
          f"nothing; " + (f"the run stopped: {esc(str(rn.error_message))}." if stopped else
                          f"{code('v3_all_none')} ran to the end without stopping: with anchored RE and every forward-looking "
                          f"variable learning the model has no leads, so it is simulated as it is, and "
                          f"{'no quarter was explosive' if int(rn.explosive_history) + int(rn.explosive_forecast) == 0 else 'some quarters were explosive'}.")
          + f" The facility choice moves average inflation by at most {f(spread, 1)} pp here.")
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
{scode("var3_allvars", "v3_all")}
{fig_title(f"Learning on inflation only vs on all {N12} forward-looking variables, {Q18[0]}-{END}")}
{legend("v3", [leg("data"), leg("re"), leg("learn", name="Learning on inflation only"), leg("all12"),
               dict(name="Quarter with a projection-facility event (all 12)", color="s3", kind="dot")])}
{g1}
{tables("v3")}
{fig_title(f"Share and perceived persistence, {FIRST}-{END}")}
<div class="grid g-1w">{g2}</div>
{tables("v3h")}
<h3 class="sub">Projection facility options on the all-variables run</h3>
<p>{p3}</p>
{ftbl}
{scode("var3_allvars", "v3_all_alm")}
{scode("var3_allvars", "v3_all_none")}"""
    return section("var3", 9, "Model variant 3: learning on inflation only vs on all 12 variables", body)


# ----------------------------------------------------------------------------- variant 4
def sec_var4():
    kz, kf, le = "v4_koz", "v4_koz_full", "a1_learn"
    gq = {q: LL[(kf, "pinf", "gain", q)] for q in qrange(FIRST, END) if (kf, "pinf", "gain", q) in LL}
    qmin, gmin = argmin(gq)
    qmx, gmx = argmax(gq)
    g0 = float(rx(r"o\.gain\.value\s*=\s*([0-9.]+)", master_m))
    es = rx(r"gain\.koz\.error_scale\s*=\s*([0-9.]+)", (SCN / "var4_gain" / "v4_koz.m").read_text(encoding="utf-8"))
    hev = sum(ev_count(kz, k, "history") for k in ("plm", "alm", "alm_shares"))
    fev = sum(ev_count(kz, k, "forecast") for k in ("plm", "alm", "alm_shares"))
    hev0 = sum(ev_count(le, k, "history") for k in ("plm", "alm", "alm_shares"))
    ans = (f"The endogenous gain barely moves, so the variant changes little. With the errors in quarterly units the gain "
           f"averages {f(K('v4_gain_hist_mean'), 4)} over {FIRST}-{END} against the constant {g0}, and average inflation is "
           f"{pct(K('avg_pinfobs__' + kz), 3)} against {pct(K('avg_pinfobs__' + le), 3)} with the constant gain.")
    p2 = (f"Kostyshyna, Özden and Zhang (2024) let the gain rise while the learners' errors keep their sign and fall when they "
          f"alternate. The errors enter in model units, percent per quarter ({code('gain.koz.error_scale = ' + es)}). On the "
          f"RE-smoothed history the gain ranges from {f(gmin, 4)} ({qmin}) to {f(gmx, 4)} ({qmx}): {f(K('v4_gain_2020Q2'), 4)} in "
          f"2020Q2, {f(K('v4_gain_2021Q4'), 4)} in 2021Q4, {f(K('v4_gain_2022Q2'), 4)} in {ORIGIN}, {f(K('v4_gain_2023Q4'), 4)} in "
          f"2023Q4 and {f(K('v4_gain_2026Q2_full'), 4)} in {END}. "
          + ("No bound binds. " if int(K("v4_gain_bound_events")) == 0 else f"{int(K('v4_gain_bound_events'))} bound events. ")
          + f"In the forecast it averages {f(K('v4_gain_2022Q3_2026Q2_mean'), 4)} and ends at {f(K('v4_gain_end_forecast'), 4)}. "
          f"Beliefs at the origin: alpha {f(K('coef_origin__' + kz + '__alpha_pinf'), 3)}, beta "
          f"{f(K('coef_origin__' + kz + '__beta_pinf'), 3)} (constant gain {f(K('coef_origin__' + le + '__alpha_pinf'), 3)}, "
          f"{f(K('coef_origin__' + le + '__beta_pinf'), 3)}), a perceived mean of {pct(K('pmean_origin__' + kz))} "
          f"({pct(K('pmean_origin__' + le))}). Policy rate {pct(K('avg_robs__' + kz))} vs {pct(K('avg_robs__' + le))}, output "
          f"growth {pct(K('avg_dy__' + kz))} vs {pct(K('avg_dy__' + le))}. End-of-quarter share ({code('n2')}) at the end of "
          f"{ORIGIN}: {f(K('n2_origin__' + kz), 3)} vs {f(K('n2_origin__' + le), 3)}; share in force ({code('n2_model')}) in "
          f"{END}: {f(K('n2_model_2026Q2__' + kz), 3)} vs {f(K('n2_model_2026Q2__' + le), 3)}. Projection facility: {hev} "
          f"event{'s' if hev != 1 else ''} in the history (constant gain: {hev0}), {fev} in the forecast.")
    gfull = line("v4g-full", "v4g", f"Gain, RE-smoothed history {FIRST}-{END}",
                 f"Average {f(K('v4_gain_hist_mean'), 4)}; thin line: the constant gain {g0}.", QF,
                 [S("koz", lser(kf, "pinf", "gain", QF, end=END), name="Endogenous gain (KOZ), history to " + END)],
                 legend=False, h=200, dec=4, refs=[dict(y=g0, label=f"constant {g0}")], origin=None)
    gfc = line("v4g-fc", "v4g", f"Gain in the forecast from {ORIGIN}, {Q18[0]}-{END}",
               f"{f(K('v4_gain_origin'), 4)} at the origin, {f(K('v4_gain_end_forecast'), 4)} in {END}.", Q18,
               [S("koz", lser(kz, "pinf", "gain", Q18))], legend=False, h=200, dec=4,
               refs=[dict(y=g0, label=f"constant {g0}")])
    hcap = (f"End-of-quarter share (n2) at the end of {ORIGIN}: KOZ {f(K('n2_origin__' + kz), 3)}, constant gain "
            f"{f(K('n2_origin__' + le), 3)}; beta {f(K('coef_origin__' + kz + '__beta_pinf'), 3)} vs "
            f"{f(K('coef_origin__' + le + '__beta_pinf'), 3)}.")
    g2 = history_figure("v4h", "Share of learners and perceived persistence, inflation", hcap,
                        [("learn", le, "pinf", dict(name="Constant gain", short="Constant")), ("koz", kz, "pinf", {})],
                        [("learn", le, "pinf", "beta_pinf", dict(name="Constant gain", short="Constant")),
                         ("koz", kz, "pinf", "beta_pinf", {})])
    lines = [dict(ent="re", scen="a1_re"), dict(ent="learn", scen=le, name="Learning, constant gain", short="Constant gain"),
             dict(ent="koz", scen=kz)]
    shares = {"pinfobs": [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf", lines[1:], "pinf")]}
    g1 = forecast_grid("v4", lines, shares=shares)
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
{scode("var4_gain", "v4_koz")}
{fig_title("The endogenous gain")}
<div class="grid g-2">{gfull}{gfc}</div>
{tables("v4g")}
{fig_title(f"Share of learners and perceived persistence, endogenous vs constant gain, {FIRST}-{END}")}
<div class="grid g-1w">{g2}</div>
{tables("v4h")}
{fig_title(f"Endogenous vs constant gain, {Q18[0]}-{END}")}
{legend("v4", [leg("data"), leg("re"), leg("learn", name="Learning, constant gain (baseline)"), leg("koz")])}
{g1}
{tables("v4")}"""
    return section("var4", 10, "Model variant 4: endogenous gain (Kostyshyna, Özden and Zhang 2024)", body)


# ----------------------------------------------------------------------------- evaluation
EVV = [("e01_re", "re"), ("e02_learn", "learn"), ("e03_learn_mc", "mc"), ("e04_learn_all_learners", "alll"),
       ("e05_ar2", "ar2"), ("e06_ar1nc", "ar1nc"), ("e07_reg", "reg"), ("e08_var3", "var3"), ("e09_var12", "var12"),
       ("e10_allvars", "all12")]
EVNAME = {"e02_learn": "Learning on inflation (anchored)"}
SAMPLES = [("full", "Full sample"), ("s1990_2007", "1990-2007"), ("s2008_2019", "2008-2019"), ("s2020_2026", "2020-2026")]


def evname(vid, ent):
    return EVNAME.get(vid, ENT[ent]["name"])


def sec_eval():
    o0, o1 = re.search(r"origin \((\d{4}Q\d)-(\d{4}Q\d)\)", (SCN / "eval" / "e04_learn_all_learners.m").read_text(
        encoding="utf-8")).groups()
    hmax = max(h for (_, _, _, h) in EM)
    cells = [(vid, h, ER[("full", vid, "pinfobs", h)], DMP[("full", vid, "pinfobs", h)]) for vid, _ in EVV[1:] for h in range(1, hmax + 1)]
    sig_better = [c for c in cells if c[2] < 1 and c[3] < 0.10]
    best = min(cells, key=lambda c: c[2])
    bl = [ER[("full", "e02_learn", "pinfobs", h)] for h in (1, 4, 8)]
    blp = [DMP[("full", "e02_learn", "pinfobs", h)] for h in (1, 4, 8)]
    dy1 = {vid: (ER[("full", vid, "dy", 1)], DMP[("full", vid, "dy", 1)]) for vid, _ in EVV[1:]}
    below = [vid for vid in dy1 if dy1[vid][0] < 1]
    nm = {vid: evname(vid, ent) for vid, ent in EVV}
    ans = ((f"No variant forecasts inflation significantly better than RE over the full sample. " if not sig_better else
            f"{len(sig_better)} full-sample inflation cells are better than RE at p < 0.10. ")
           + f"The lowest relative RMSE is {lc1(nm[best[0]])} at h = {best[1]}, {f(best[2], 3)} (DM p {f(best[3])}); baseline "
             f"learning is {' / '.join(f(x, 3) for x in bl)} at h = 1 / 4 / 8 (p {f(min(blp))}-{f(max(blp))}). On output "
             f"growth the learning variants are slightly worse at h = 1 (baseline {f(dy1['e02_learn'][0], 3)}, p "
             f"{f(dy1['e02_learn'][1])}); below 1 there: " + " and ".join(
               f"{lc1(nm[v])} ({f(dy1[v][0], 3)}, p {f(dy1[v][1])})" for v in sorted(below, key=lambda v: dy1[v][0])) + ".")
    re_r = lambda var: " / ".join(f(EM[("full", "e01_re", var, h)].rmse) for h in (1, 4, 8))
    p2 = (f"{int(K('ev_n_runs'))} runs ({len(EVV)} variants x {int(EM[('full', 'e01_re', 'pinfobs', 1)].n)} origins, "
          f"{o0}-{o1}), {'no' if int(K('ev_failures')) == 0 else int(K('ev_failures'))} failures; horizons 1-{hmax}; zero future shocks, real-time filters; "
          f"benchmark RE. Diebold-Mariano tests use the uniform kernel with the HLN correction ({int(K('ev_dm_fallbacks'))} "
          f"cells fall back to Bartlett). RE RMSE, full sample, h = 1 / 4 / 8: inflation {re_r('pinfobs')} pp, output growth "
          f"{re_r('dy')} pp. Subsamples by target date ({int(K('ev_n_targets_s2020_2026_h1'))} targets in 2020-2026 at h = 1, "
          f"{int(K('ev_n_targets_s2020_2026_h8'))} at h = 8, so those p-values are fragile). The evaluation records only the "
          f"total number of engine events per run, not their type.")
    X = [str(h) for h in range(1, hmax + 1)]
    ch = []
    H8 = list(range(1, hmax + 1))
    for var, vl in (("pinfobs", "Inflation"), ("dy", "Output growth")):
        cells = []
        allr = [ER[("full", v, var, h)] for v, _ in EVV[1:] for h in H8] + [1.0]
        yr = [round(min(allr), 3), round(max(allr), 3)]          # one scale for every panel of the variable
        for v, ent in EVV[1:]:
            ser = []
            if v != "e02_learn":
                ser.append(S("learn", [clean(ER[("full", "e02_learn", var, h)], 4) for h in H8],
                             name=nm["e02_learn"] + " (baseline)", short="Baseline"))
            sv = S(ent, [clean(ER[("full", v, var, h)], 4) for h in H8], name=nm[v],
                   **({"short": "Baseline"} if v == "e02_learn" else {}))
            sv["rings"] = [h - 1 for h in H8 if DMP[("full", v, var, h)] < 0.10]
            ser.append(sv)
            cap = (f"h = 1 / 4 / {hmax}: " + " / ".join(f(ER[("full", v, var, h)], 3) for h in (1, 4, hmax))
                   + " (DM p " + " / ".join(f(DMP[("full", v, var, h)]) for h in (1, 4, hmax)) + ").")
            cells.append(line(f"ev-{var}-{v}", "ev", nm[v], cap, X, ser, origin=None, xcat=True, xpre="h = ", xHead="Horizon",
                              dec=3, legend=False, h=170, yr=yr, refs=[dict(y=1, label="")]))
        ch.append(f"""{fig_title(f"{vl}: RMSE relative to RE by horizon, full sample; one panel per variant, below 1 = better than RE")}
<div class="grid g-3">{"".join(cells)}</div>""")

    def relcell(smp, vid, var, h):
        r, p = ER[(smp, vid, var, h)], DMP[(smp, vid, var, h)]
        s = f"{f(r, 3)} <span class=\"p\">({f(p)})</span>"
        return f'<span class="sig">{s} *</span>' if p < 0.10 else s
    def relcell_c(smp, vid, var, h):
        r, p = ER[(smp, vid, var, h)], DMP[(smp, vid, var, h)]
        return f'<span class="sig">{f(r, 3)} *</span>' if p < 0.10 else f(r, 3)
    rtabs = []
    for var, vl in (("pinfobs", "Inflation"), ("dy", "Output growth")):
        rows = [[esc(nm["e01_re"]) + " (RMSE, pp)"] + [f(EM[("full", "e01_re", var, h)].rmse, 3) for h in range(1, hmax + 1)]]
        rows += [[esc(nm[v])] + [relcell("full", v, var, h) for h in range(1, hmax + 1)] for v, _ in EVV[1:]]
        rtabs.append(html_table(["Variant"] + [f"h = {h}" for h in range(1, hmax + 1)], rows, num_from=1, cls="rel",
                                caption=f"{vl}, full sample: RMSE relative to RE (DM p-value). * p &lt; 0.10. Below 1 = "
                                        f"better than RE. Source: eval_relative.csv, eval_dm.csv."))
    stabs = []
    for var, vl in (("pinfobs", "Inflation"), ("dy", "Output growth")):
        hdr = ["Variant"] + [f"{sl}, h = {h}" for _, sl in SAMPLES[1:] for h in (1, 4, 8)]
        rows = [[esc(nm["e01_re"]) + " (RMSE, pp)"] + [f(EM[(s, "e01_re", var, h)].rmse) for s, _ in SAMPLES[1:] for h in (1, 4, 8)]]
        rows += [[esc(nm[v])] + [relcell_c(s, v, var, h) for s, _ in SAMPLES[1:] for h in (1, 4, 8)] for v, _ in EVV[1:]]
        ns = "; ".join(f"{sl} " + " / ".join(str(int(EM[(s, 'e01_re', var, h)].n)) for h in (1, 4, 8)) for s, sl in SAMPLES[1:])
        stabs.append(html_table(hdr, rows, num_from=1, cls="rel sub",
                                caption=f"{vl}, subsamples by target date: relative RMSE; * DM p &lt; 0.10 (p-values in eval_dm.csv). Targets at "
                                        f"h = 1 / 4 / 8: {ns}."))
    crow = []
    for v, ent in EVV[1:]:
        crow.append([esc(nm[v]), f"{int(K(f'ev_dm_better_{v}_pinfobs'))} / {int(K(f'ev_dm_worse_{v}_pinfobs'))}",
                     f"{int(K(f'ev_dm_better_{v}_dy'))} / {int(K(f'ev_dm_worse_{v}_dy'))}", f"{int(K(f'ev_events_total__{v}'))}"])
    ncell = len([1 for s, _ in SAMPLES for h in range(1, hmax + 1)])
    ctab = html_table(["Variant", "Inflation: better / worse", "Output growth: better / worse", "Engine events, all runs"],
                      crow, num_from=1, caption=f"Cells with DM p &lt; 0.10, better / worse than RE, out of {ncell} per variable "
                                                f"(h = 1-{hmax} x {len(SAMPLES)} samples); engine events summed over the "
                                                f"{int(EM[('full', 'e01_re', 'pinfobs', 1)].n)} runs of each variant (all types).")
    body = f"""<p class="answer">{ans}</p>
<p>{p2}</p>
{scode("eval", "e04_learn_all_learners")}
{legend("ev", [dict(name="RE = 1 (reference line)", color="ink", width=1), leg("learn", name="Learning on inflation (anchored), the baseline"),
               dict(name="The variant named in the panel title", color="s3"), dict(name="DM p < 0.10 (ring on the variant)", color="s3", kind="dot")])}
{"".join(ch)}
{tables("ev")}
<h3 class="sub">Relative RMSE and Diebold-Mariano tests</h3>
{"".join(rtabs)}
{ctab}
<h3 class="sub">Subsamples</h3>
{"".join(stabs)}"""
    return section("evaluation", 11, "Forecast evaluation", body)


# ----------------------------------------------------------------------------- application 1 on two other models
OM_FILES = ["other_models_paths_long.csv", "other_models_learning_long.csv", "other_models_key_numbers.csv",
            "other_models_checks.txt"]


def model_line(name):
    p = ROOT / "models" / name / "README.md"
    if not p.exists():
        return ""
    for ln in p.read_text(encoding="utf-8").splitlines():
        s = ln.strip()
        if s and not s.startswith("#"):
            return md_inline(s)
    return ""


def sec_other():
    have = all((SUM / fn).exists() for fn in OM_FILES)
    intro = ("Application 1 (data, RE, learning on inflation, forecast from the inflation peak) on two more models: the "
             "three-equation New Keynesian model of IJCB (<code>models/ijcb3/</code>, parameters at the IJCB Table 1 "
             "heterogeneous-expectations posterior means) and the An-Schorfheide (2007) model (<code>models/as07/</code>, "
             "parameters at the published Herbst-Schorfheide (2016) posterior means).")
    if not have:
        missing = [fn for fn in OM_FILES if not (SUM / fn).exists()]
        body = (f'<p class="answer">Results pending.</p><p>{intro}</p><aside class="box pending" role="note"><p>Track M3 is '
                f'running these scenarios. This section is built from {", ".join(code("results/summary_v3/" + m) for m in OM_FILES)} '
                f'and the memo section in {code("FINDINGS_v3.md")}; missing now: {", ".join(code(m) for m in missing)}. '
                f'Rerun {code("python reports/build_report_v3.py")} once they exist.</p></aside>')
        return section("othermodels", 12, "Application 1 on two other models", body), False
    return section("othermodels", 12, "Application 1 on two other models", other_models_body(intro)), True


OMODELS = [
    dict(model="ijcb3", re="i1_re", learn="i1_learn", out="yobs", outlab="Output gap", outunit="% of trend output",
         title="IJCB three-equation model",
         desc=("The three-equation New Keynesian model of IJCB (sec. 2.1: hybrid IS curve, hybrid Phillips curve, Taylor "
               "rule with smoothing; output gap, CPI inflation and the funds rate observed) at the posterior means of IJCB's "
               "heterogeneous-expectations model (Table 1), with IJCB's learning estimates.")),
    dict(model="as07", re="a1as_re", learn="a1as_learn", out="dy", outlab="Output growth", outunit="% annualised, per capita",
         title="An and Schorfheide (2007)",
         desc=("The small New Keynesian model of An and Schorfheide (2007) (Euler equation, Phillips curve, Taylor rule with "
               "smoothing; output growth, CPI inflation and the funds rate observed with measurement errors) at the published "
               "Herbst-Schorfheide (2016) posterior means for 1983Q1-2002Q4, with the toolbox learning calibration.")),
]


def parse_checks(text):
    out, lines = [], text.splitlines()
    for i, ln in enumerate(lines):
        m = re.match(r"^(PASS|FAIL)\s+(\w+)\s+(.*)$", ln)
        if m:
            det, j = [], i + 1
            while j < len(lines) and lines[j].startswith("      "):
                det.append(lines[j].strip())
                j += 1
            out.append(dict(status=m.group(1), id=m.group(2), text=m.group(3), detail=" ".join(det)))
    return out


_m = re.search(r"(The package keeps IJCB's HE column.*?a year\.)", memo, re.S)
IJCB_HE = " ".join(_m.group(1).split()) if _m else ""


def other_models_body(intro):
    op = pd.read_csv(SUM / "other_models_paths_long.csv")
    OP = {(r.model, r.scenario, r.variable, r.date): float(r.value) for r in op.itertuples()}
    ol = pd.read_csv(SUM / "other_models_learning_long.csv")
    OL = {(r.scenario, r.variable, r.field, r.date): float(r.value) for r in ol.itertuples()}
    okn = pd.read_csv(SUM / "other_models_key_numbers.csv")
    OK = dict(zip(okn.name, okn.value))
    ODESC = dict(zip(okn.name, okn.description))
    ochk = parse_checks((SUM / "other_models_checks.txt").read_text(encoding="utf-8"))

    def ok(name):
        return float(OK[name])

    def opser(mdl, scen, var, X, start=None):
        return [None if (start and q < start) else clean(OP.get((mdl, scen, var, q))) for q in X]

    def olser(scen, field, X):
        return [clean(OL.get((scen, "pinf", field, q))) for q in X]

    def oavg(mdl, scen, var):
        xs = [OP[(mdl, scen, var, q)] for q in HOR]
        return sum(xs) / len(xs)
    parts, comp = [], {}
    for M in OMODELS:
        mdl, re_, le, ov = M["model"], M["re"], M["learn"], M["out"]
        gap = {q: OP[(mdl, le, "pinfobs", q)] - OP[(mdl, re_, "pinfobs", q)] for q in HOR}
        qg, gmax = argmax(gap)
        neg = [q for q in HOR if gap[q] < 0]
        npos = sum(1 for q in HOR if gap[q] > 0)
        al, ar = ok(f"avg_pinfobs__{le}"), ok(f"avg_pinfobs__{re_}")
        evh = re.findall(r"(\d{4}Q\d) projection_plm", ODESC.get(f"n_events__{le}", ""))
        fe = int(ok(f"ev_projection_plm_forecast__{le}") + ok(f"ev_projection_alm_forecast__{le}")
                 + ok(f"ev_projection_alm_shares_forecast__{le}"))
        hfirst = min(d for (s, v, fl, d) in OL if s == le)
        XF = qrange(hfirst, END)
        n2m = {q: OL[(le, "pinf", "n2_model", q)] for q in HOR}
        qlo, nlo = argmin(n2m)
        ans = (f"Learning {'raises' if al > ar else 'lowers'} average inflation over {HOR[0]}-{END} by {f(abs(al - ar))} pp: "
               f"{pct(al)} vs {pct(ar)} under RE. The gap is largest in {qg} ({pp(gmax)}) "
               + (f"and stays positive in all {H} quarters ({pp(gap[END])} in {END})." if npos == H else
                  f"and is negative from {neg[0]} ({pp(gap[END])} in {END})."))
        p1 = (f"Inflation was {pct(ok(f'{mdl}_data_pinfobs_2022Q2'))} in {ORIGIN} (data); the RE forecast for {HOR[0]} is "
              f"{pct(ok(f'pinfobs_{HOR[0]}__{re_}'))}, learning {pct(ok(f'pinfobs_{HOR[0]}__{le}'))}. Policy rate "
              f"{pct(ok(f'avg_robs__{le}'))} vs {pct(ok(f'avg_robs__{re_}'))} on average; "
              f"{M['outlab'].lower()} {f(ok(f'avg_{ov}__{le}'))} vs {f(ok(f'avg_{ov}__{re_}'))}. The end-of-quarter share "
              f"({code('n2')}) is {f(ok(f'n2_origin__{le}'), 3)} at the end of {ORIGIN}; the share in force ({code('n2_model')}) "
              f"is {f(ok(f'n2_model_2026Q2__{le}'), 3)} in {END} (lowest {f(nlo, 3)}, {qlo}); over {hfirst}-{ORIGIN} "
              f"{code('n2')} averaged {f(ok(f'n2_hist_mean__{le}'), 3)}. "
              f"Beliefs at the origin: alpha {f(ok(f'alpha_origin__{le}'), 3)}, beta {f(ok(f'beta_origin__{le}'), 3)}, a "
              f"perceived mean of {pct(ok(f'pmean_origin__{le}'))} (steady state {pct(ok(f'{mdl}_ss_pinfobs'))}); "
              f"{pct(ok(f'pmean_2026Q2__{le}'))} by {END}. Projection facility: {len(evh)} PLM-block events in the history "
              f"({', '.join(evh)}), {fe if fe else 'none'} in the forecast.")
        if mdl == "ijcb3":
            cav = (f"Read the rate paths with two caveats. The package has no ELB regime: in the ELB quarters the filter "
                   f"infers a shadow rate from the rule ({pct(ok('ijcb3_shadow_min_2009Q1_2015Q4'))} at its 2009-2015 trough). "
                   f"At IJCB's estimates the trend real rate is {pct(ok('ijcb3_trend_real_rate'))} a year, so the RE forecast "
                   f"settles at a funds rate of {pct(ok('ijcb3_ss_robs'))} with inflation of {pct(ok('ijcb3_ss_pinfobs'))}; "
                   f"the funds rate averaged {pct(ok('ijcb3_data_avg_robs_2022Q3_2026Q2'))} over {HOR[0]}-{END} in the data "
                   f"({code('models/ijcb3/README.md')}, open issue 1). " + esc(IJCB_HE))
        else:
            cav = (f"Read the paths with two caveats. The forecast returns to the 1983-2002 steady state (inflation "
                   f"{pct(ok('as07_ss_pinfobs'))}, funds rate {pct(ok('as07_ss_robs'))}, output growth "
                   f"{pct(ok('as07_ss_dy'))}); the funds rate averaged {pct(ok('as07_data_avg_robs_2022Q3_2026Q2'))} over "
                   f"{HOR[0]}-{END} in the data. The observables carry measurement errors, and the learners learn model "
                   f"inflation net of the error: {pct(ok('as07_model_pinfobs_2022Q2'))} at the origin, not the "
                   f"{pct(ok('as07_data_pinfobs_2022Q2'))} in the data.")
        cells = []
        for var, lab, unit in (("pinfobs", "Inflation", UNIT), ("robs", "Policy rate", UNIT), (ov, M["outlab"], M["outunit"])):
            dvar = "ffr" if var == "robs" else var
            ser = [S("data", opser(mdl, "data", dvar, Q18), **({"name": "Data (funds rate)"} if var == "robs" else {})),
                   S("re", opser(mdl, re_, var, Q18, ORIGIN)), S("learn", opser(mdl, le, var, Q18, ORIGIN))]
            cap = (f"Average {HOR[0]}-{END}: RE {pct(oavg(mdl, re_, var))}; learning {pct(oavg(mdl, le, var))}"
                   + (f"; data (funds rate) {pct(sum(OP[(mdl, 'data', 'ffr', q)] for q in HOR) / H)}" if var == "robs" else
                      f"; data {pct(sum(OP[(mdl, 'data', var, q)] for q in HOR) / H)}") + "."
                   + (" The 2020 quarters run off the scale (values in the table view)." if var == ov else ""))
            sh = None
            if var == "pinfobs":
                sh = [("Share of learners in force (n2_model), inflation", "toolbox field n2_model of pinf",
                       [S("learn", olser(le, "n2_model", Q18))], {})]
            cells.append(panel(f"om-{mdl}-{var}", f"om{mdl}", f"{lab}, {unit}", cap, Q18, ser, shares=sh,
                               clip=COVID if var == ov else []))
        hcap = (f"Learned on the RE-smoothed history from {hfirst}; after {ORIGIN} the forecast. End-of-quarter share (n2) "
                f"{f(ok(f'n2_origin__{le}'), 3)} at the end of {ORIGIN}; beta {f(ok(f'beta_origin__{le}'), 3)} at {ORIGIN}, "
                f"{f(ok(f'beta_2026Q2__{le}'), 3)} in {END}.")
        hist = stacked(f"om{mdl}h", "Share of learners and perceived persistence, inflation", hcap,
                       [("End-of-quarter share of learners (n2)", XF, [S("learn", olser(le, "n2", XF))], {}),
                        ("Perceived persistence (beta, the learners' AR(1) coefficient)", XF,
                         [S("learn", olser(le, "beta_pinf", XF))], {})])
        folder = f"scenarios/{mdl}/app1_peak"
        lines = scen_lines_path(ROOT / folder / f"{le}.m")
        parts.append(f"""<h3 class="sub">{esc(M['title'])} ({code(mdl)})</h3>
<p class="mdesc">{esc(M['desc'])} Learning: gain {f(ok(f'gain__{le}'), 4)}, memory {f(ok(f'memory__{le}'), 2)}, intensity of
choice {f(ok(f'intensity__{le}'), 2)}.</p>
<p class="answer">{ans}</p>
<p>{p1}</p>
<p>{cav}</p>
{codeblock(f"{folder}/{le}.m", lines)}
{fig_title(f"{M['title']}: forecast from the {ORIGIN} peak, {Q18[0]}-{END}")}
{legend(f"om{mdl}", [leg("data"), leg("re"), leg("learn")])}
<div class="grid g-2">{"".join(cells)}</div>
{tables(f"om{mdl}")}
{fig_title(f"{M['title']}: the learners' share and perceived persistence, {hfirst}-{END}")}
<div class="grid g-1w">{hist}</div>
{tables(f"om{mdl}h")}""")
        comp[mdl] = dict(avg=(ar, al), gap=(ok(f"gap_avg_pinfobs__{mdl}"), gmax, qg), end=gap[END],
                         n2=(ok(f"n2_origin__{le}"), ok(f"n2_model_2026Q2__{le}")),
                         bel=(ok(f"beta_origin__{le}"), ok(f"pmean_origin__{le}"), ok(f"{mdl}_ss_pinfobs")),
                         d22=(ok(f"{mdl}_data_pinfobs_2022Q2"), ok(f"pinfobs_{HOR[0]}__{re_}")),
                         ev=(len(evh), fe))
    sgap = {q: P("a1_learn", "pinfobs", q) - P("a1_re", "pinfobs", q) for q in HOR}
    sq, sg = argmax(sgap)
    comp["sw07"] = dict(avg=(K("avg_pinfobs__a1_re"), K("avg_pinfobs__a1_learn")),
                        gap=(K("avg_pinfobs__a1_learn") - K("avg_pinfobs__a1_re"), sg, sq), end=sgap[END],
                        n2=(K("n2_origin__a1_learn"), K("n2_model_2026Q2__a1_learn")),
                        bel=(K("a1_beta_origin"), K("a1_pmean_origin"), K("ss_pinf")),
                        d22=(K("a1_pinf_data_2022Q2"), P("a1_re", "pinfobs", HOR[0])),
                        ev=(sum(ev_count("a1_learn", k, "history") for k in ("plm", "alm", "alm_shares")),
                            sum(ev_count("a1_learn", k, "forecast") for k in ("plm", "alm", "alm_shares"))))
    order = ["sw07", "ijcb3", "as07"]
    rows = [
        [f"Average inflation {HOR[0]}-{END}, RE / learning"] + [f"{pct(comp[m]['avg'][0])} / {pct(comp[m]['avg'][1])}" for m in order],
        ["Learning minus RE, average / largest"] + [f"{pp(comp[m]['gap'][0])} / {pp(comp[m]['gap'][1])} ({comp[m]['gap'][2]})" for m in order],
        [f"Learning minus RE in {END}"] + [pp(comp[m]["end"]) for m in order],
        [f"Learners' share: n2 at the end of {ORIGIN} / n2_model in {END}"] + [f"{f(comp[m]['n2'][0], 3)} / {f(comp[m]['n2'][1], 3)}" for m in order],
        ["Inflation PLM at the origin: beta / perceived mean (steady state)"] +
        [f"{f(comp[m]['bel'][0], 3)} / {pct(comp[m]['bel'][1])} ({pct(comp[m]['bel'][2])})" for m in order],
        [f"Inflation in {ORIGIN}, data / RE forecast for {HOR[0]}"] + [f"{pct(comp[m]['d22'][0])} / {pct(comp[m]['d22'][1])}" for m in order],
        ["Facility events, history / forecast"] + [f"{comp[m]['ev'][0]} / {comp[m]['ev'][1]}" for m in order],
    ]
    tbl = html_table(["", "SW07", "ijcb3", "as07"], rows, num_from=1, cls="cmp",
                     caption="Application 1 in three models. SW07 observes GDP-deflator inflation, ijcb3 and as07 CPI "
                             "inflation. Sources: key_numbers.csv, other_models_key_numbers.csv, the paths files.")
    allpos = all(comp[m]["avg"][1] > comp[m]["avg"][0] for m in order)
    lead = (f"{'Learning raises the inflation path after the peak in all three models' if allpos else 'The sign of the learning effect differs across the models'}: "
            f"by {f(comp['sw07']['gap'][0])} pp in SW07, {f(comp['ijcb3']['gap'][0])} pp in ijcb3 and {f(comp['as07']['gap'][0])} pp "
            f"in as07 on average over {HOR[0]}-{END}."
            + (" The gap is largest in the first two forecast quarters in all three."
               if all(HOR.index(comp[m]["gap"][2]) <= 1 for m in order) else ""))
    nck = sum(1 for c in ochk if c["status"] == "PASS")
    p0 = (f"{intro} Both packages ran without toolbox changes; {nck} of {len(ochk)} checks in "
          f"{code('other_models_checks.txt')} pass (<a href=\"#validation\">validation</a>). The RE runs equal the original "
          f"models: each model's own Kalman smoother gives the run's history and its zero-shock simulation the forecast "
          f"(ijcb3 {sci(ok('ijcb3_re_vs_original_forecast'))}, as07 {sci(ok('as07_re_vs_original_forecast'))}).")
    return f"""<p class="answer">{lead}</p>
<p>{p0}</p>
{tbl}
{"".join(parts)}"""


# ----------------------------------------------------------------------------- caveats, reproduce, validation, features
def sec_caveats():
    m = re.search(r"^## Notes\s*$(.*?)(?=^## )", memo, re.M | re.S)
    items, cur = [], None
    for ln in m.group(1).splitlines():
        if ln.startswith("- "):
            if cur:
                items.append(cur)
            cur = ln[2:].strip()
        elif ln.startswith("  ") and cur is not None:
            cur += " " + ln.strip()
    if cur:
        items.append(cur)
    def la(scen):
        return " / ".join(f(K(f"lookahead_{scen}_{v}"), 3) for v in VAR4)
    mcv = max(VAR4, key=lambda v: K(f"lookahead_v1_mc_learn_{v}"))
    look = (f"The peak forecasts start from the full-sample smoothed state. Against the real-time evaluation forecasts from "
            f"the same origin ({ORIGIN}), the largest difference over h = 1-8 is {la('a1_re')} pp under RE (inflation, rate, "
            f"output growth, consumption growth), {la('a1_learn')} pp with learning, and up to "
            f"{f(K(f'lookahead_v1_mc_learn_{mcv}'), 2)} pp ({VLAB[mcv].lower()}) with model-consistent RE agents. The evaluation "
            f"itself uses real-time filters.")
    items = [esc(look) if x.startswith("The peak forecasts start from the full-sample smoothed state") else x for x in items]
    lis = "".join(f"<li>{x if x.startswith('The peak forecasts') else md_inline(x)}</li>" for x in items)
    body = f"""<p>From the Notes of the results memo, {code('results/summary_v3/FINDINGS_v3.md')}.</p>
<ul class="cav">{lis}</ul>"""
    return section("caveats", 13, "Caveats", body)


SECT_GROUPS = [("app1", "1 Application 1"), ("app2", "2 Application 2"), ("app3", "3 Application 3"),
               ("app4", "4 Application 4"), ("app5", "5 Application 5"), ("app6", "6 Application 6"),
               ("var1", "7 Variant 1"), ("var2", "8 Variant 2"), ("var3", "9 Variant 3"), ("var4", "10 Variant 4"),
               ("eval", "11 Evaluation")]


def sec_reproduce():
    evdir = rx(r"(results/eval_\w+/)errors_long\.csv", runapp_m)
    rows = []
    for grp, lab in SECT_GROUPS:
        d = sc[sc.app == grp]
        folder = d.folder.iloc[0]
        files = ", ".join(code(i + ".m") for i in d.index)
        out = code(evdir) if grp == "eval" else ", ".join(code(f"results/{i}/") for i in d.index)
        call = code(f"run_applications('{grp}')")
        if grp == "app6":
            call += " (decompositions only: " + code("run_applications('decompose')") + ")"
        if grp == "eval":
            call += ("; in parallel: " + code("run_applications('eval_part', variants, parts)") + ", then "
                     + code("run_applications('eval_merge')"))
        rows.append([lab, code(f"scenarios/sw07/{folder}/"), files, call, out])
    rows.append(["12 Other models", code("scenarios/ijcb3/app1_peak/") + ", " + code("scenarios/as07/app1_peak/"),
                 ", ".join(code(i + ".m") for i in ("i1_re", "i1_learn", "a1as_re", "a1as_learn")),
                 code("res = hetlearn.run(feval(id))") + " for each id, then "
                 + code("run('results/summary_v3/build_other_models.m')"),
                 ", ".join(code(f"results/{i}/") for i in ("i1_re", "i1_learn", "a1as_re", "a1as_learn")) + "; "
                 + ", ".join(code(m) for m in OM_FILES)])
    rows.append(["Summary tables", code("results/summary_v3/"), code("build_summary_v3.m"),
                 code("run('results/summary_v3/build_summary_v3.m')"), code("results/summary_v3/") + " (CSVs, checks_v3.txt)"])
    rows.append(["This page", code("reports/"), code("build_report_v3.py"), code("python reports/build_report_v3.py"),
                 code("reports/sw07_learning_report.html")])
    tbl = html_table(["Section", "Folder", "Files", "Call (MATLAB from the project root, or Python)", "Output"], rows,
                     num_from=99, cls="repro")
    body = f"""<p>Every scenario is one file; it inherits from a parent and changes a few options, so each file reads as the
difference from its parent. The parents are {code('scenarios/sw07/base/sw07_re.m')} (every option is listed there) and
{code('sw07_learn.m')}; {code('scenarios/sw07/INDEX.csv')} lists the parent and the changed options of every file.
{code('run_applications')} runs groups in dependency order; {code('help run_applications')} gives the run times. Each run
overwrites {code('results/<id>/')}.</p>
{tbl}"""
    return section("reproduce", 14, "How to reproduce", body)


def sec_validation():
    rows = []
    for cid, c in CHK.items():
        st = f'<span class="st st-{"pass" if c["status"] == "PASS" else "fail"}">{c["status"]}</span>'
        rows.append([st, code(cid), esc(c["text"]), esc(c["detail"])])
    tbl = html_table(["Status", "Check", "What is checked", "Result"], rows, num_from=99, cls="val")
    extra = ""
    op = SUM / "other_models_checks.txt"
    if op.exists():
        otxt = op.read_text(encoding="utf-8")
        oc = parse_checks(otxt)
        orows = [[f'<span class="st st-{"pass" if c["status"] == "PASS" else "fail"}">{c["status"]}</span>', code(c["id"]),
                  esc(c["text"]), esc(c["detail"])] for c in oc]
        osum = rx(r"^(\d+ of \d+ checks pass)\s*$", otxt, flags=re.M)
        extra = (f"<h3 class=\"sub\">Application 1 on the other models</h3><p>{esc(osum)}. Every line of "
                 f"{code('results/summary_v3/other_models_checks.txt')}, written by {code('build_other_models.m')}.</p>"
                 + html_table(["Status", "Check", "What is checked", "Result"], orows, num_from=99, cls="val"))
    body = f"""<p>{esc(CHK_SUMMARY)}. Every line of {code('results/summary_v3/checks_v3.txt')}, written by
{code('build_summary_v3.m')}.</p>
{tbl}
{extra}"""
    return section("validation", 15, "Validation", body)


def sec_features():
    rows, n_add, n_rm, n, n_mixed = [], 0, 0, 0, 0
    for ln in features_md.splitlines():
        m = re.match(r"^\|\s*(\d+)\s*\|", ln)
        if not m:
            continue
        cells = [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", ln.strip().strip("|"))]
        num_, feat, opt, where, origin, status = cells[:6]
        n += 1
        added = "ADDED" in origin
        n_mixed += added and "asked" in origin
        removed = status.startswith("REMOVED")
        n_add += added
        n_rm += removed
        org = (f'<span class="chip">ADDED</span> {md_inline(origin.replace("ADDED", "").strip(" ()/"))}' if added and origin.strip() != "ADDED"
               else ('<span class="chip">ADDED</span>' if added else md_inline(origin)))
        if added and "asked" in origin:
            org = md_inline(origin).replace("ADDED", '<span class="chip">ADDED</span>')
        stt = md_inline(status).replace("REMOVED", '<span class="chip rm">REMOVED</span>')
        rows.append((removed, [num_, md_inline(feat), md_inline(opt) + f' <span class="muted">({md_inline(where)})</span>', org, stt]))
    body_rows = "".join(f'<tr id="feat-{r[0]}" class="{"removed" if rm else ""}">' + "".join(
        f'<td>{c}</td>' for c in r) + "</tr>" for rm, r in rows)
    tbl = (f'<div class="tw"><table class="feat"><thead><tr><th>#</th><th>Feature</th><th>Option (where it is set)</th>'
           f'<th>Asked or ADDED</th><th>Status</th></tr></thead><tbody>{body_rows}</tbody></table></div>')
    hooks = re.search(r"Not implemented, planned hooks:(.*)$", features_md, re.S)
    hk = md_inline(" ".join(hooks.group(1).split())) if hooks else ""
    body = f"""<p>All {n} rows of {code('docs/FEATURES.md')}: what is configurable and where. {n_add} rows are marked
<span class="chip">ADDED</span>: added during the build and flagged for review ({n_mixed} of them partly asked for). The
others were asked for. {n_rm} rows are
<span class="chip rm">REMOVED</span>: the stabilising devices that the projection facility replaced on 2026-10-18 (the
options raise an error naming the replacement).</p>
{tbl}
<p><b>Not implemented, planned hooks:</b> {hk}</p>"""
    return section("features", 16, "Feature register", body), n, n_add, n_rm


# ============================================================================= assemble
BASE_HTML = sec_baseline()
PARTS = [sec_app1(), sec_app2(), sec_app3(), sec_app4(), sec_app5(), sec_app6(), sec_var1(), sec_var2(), sec_var3(),
         sec_var4(), sec_eval()]
OM_HTML, OM_DONE = sec_other()
PARTS.append(OM_HTML)
PARTS += [sec_caveats(), sec_reproduce(), sec_validation()]
FEAT_HTML, N_FEAT, N_ADD, N_RM = sec_features()
PARTS.append(FEAT_HTML)

n_scen = len(sc)
n_eval = int((sc.app == "eval").sum())
n_ok = int((sc.status == "ok").sum())
toc = "".join(f'<a href="#{sid}"><span class="tn">{no}</span> {esc(t.split(":")[0])}</a>' for sid, no, t in SEC)
body = f"""
<header class="top wrap">
  <p class="kicker">hetlearn toolbox report · {REPORT_DATE}</p>
  <h1>hetlearn: heterogeneous expectations in DSGE models</h1>
  <p class="lede">hetlearn is a MATLAB toolbox on IRIS that mixes rational-expectations agents with adaptive learners
  whose shares switch on past forecast performance (Özden 2025, IJCB 21(1)). This report applies it to a re-estimated
  Smets-Wouters (2007) model: six applications from the {ORIGIN} inflation peak, four model variants, a real-time forecast
  evaluation, and application 1 on two other models.</p>
  <p class="meta"><span>{REPORT_DATE}</span><span>{n_scen} scenarios ({n_scen - n_eval} runs, {n_eval} evaluation variants), {n_ok} ok</span>
  <span>{esc(CHK_SUMMARY)}</span><span>Inputs: results/summary_v3/</span></p>
  <nav class="toc" aria-label="Sections">{toc}</nav>
</header>
<main class="wrap">
{BASE_HTML}
{"".join(PARTS)}
<footer class="foot"><p>Built by <code>reports/build_report_v3.py</code> from <code>results/summary_v3/</code> on {REPORT_DATE}.
Charts: hover or focus a chart (arrow keys move along it) for values; every chart has a table view.</p></footer>
</main>
"""

CSS = r"""
:root{
  --bg:#fcfcfd; --bg-2:#f1f3f5; --fg:#14171a; --ink-2:#4a5159; --muted:#6c747d; --grid:#e4e7ea; --axis:#c2c7cd; --rule:#dadee2;
  --band:#f0f3f6; --band-2:#e5ebf1; --accent:#1d5d84; --chip-bg:#f6ecd8; --chip-fg:#5e4310; --chip-bd:#d6bf93;
  --pass-fg:#1f5f2e; --pass-bg:#e5f1e7; --fail-fg:#8a2323; --fail-bg:#f8e3e1;
  --s1:#2a78d6; --s2:#eb6834; --s3:#1baf7a; --s4:#eda100; --s5:#e87ba4; --s6:#008300; --s7:#4a3aa7; --s8:#e34948;
  --o1:#ff946d; --o3:#a63d0c; --g0:#9aa1a9; --tip-bg:#ffffff; --tip-bd:rgba(20,23,26,.14); --shadow:rgba(20,23,26,.10);
  color-scheme: light;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --bg:#171a1d; --bg-2:#1f2327; --fg:#eceef0; --ink-2:#b9c0c7; --muted:#8f97a0; --grid:#2a2f34; --axis:#454c54; --rule:#30363c;
    --band:#1c2125; --band-2:#232a31; --accent:#7cbbe0; --chip-bg:#3b3020; --chip-fg:#f0d9a6; --chip-bd:#6b5730;
    --pass-fg:#9fd8aa; --pass-bg:#1e3324; --fail-fg:#f2a7a2; --fail-bg:#3d2221;
    --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --s5:#d55181; --s6:#008300; --s7:#9085e9; --s8:#e66767;
    --o1:#ac441a; --o3:#f08e6b; --g0:#737b84; --tip-bg:#202428; --tip-bd:rgba(255,255,255,.14); --shadow:rgba(0,0,0,.45);
    color-scheme: dark;
  }
}
:root[data-theme="dark"]{
  --bg:#171a1d; --bg-2:#1f2327; --fg:#eceef0; --ink-2:#b9c0c7; --muted:#8f97a0; --grid:#2a2f34; --axis:#454c54; --rule:#30363c;
  --band:#1c2125; --band-2:#232a31; --accent:#7cbbe0; --chip-bg:#3b3020; --chip-fg:#f0d9a6; --chip-bd:#6b5730;
  --pass-fg:#9fd8aa; --pass-bg:#1e3324; --fail-fg:#f2a7a2; --fail-bg:#3d2221;
  --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --s5:#d55181; --s6:#008300; --s7:#9085e9; --s8:#e66767;
  --o1:#ac441a; --o3:#f08e6b; --g0:#737b84; --tip-bg:#202428; --tip-bd:rgba(255,255,255,.14); --shadow:rgba(0,0,0,.45);
  color-scheme: dark;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.58 "IBM Plex Sans",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  -webkit-text-size-adjust:100%;overflow-wrap:break-word}
.wrap{max-width:1180px;margin:0 auto;padding-inline:clamp(16px,4vw,44px)}
.top{padding-block:clamp(28px,6vw,64px) 8px}
.kicker{margin:0 0 10px;font:500 12.5px/1.3 "IBM Plex Mono",ui-monospace,Consolas,monospace;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
h1,h2{font-family:"Bricolage Grotesque","Avenir Next","Segoe UI",system-ui,sans-serif;font-weight:650;letter-spacing:-.018em;color:var(--fg)}
h1{font-size:clamp(32px,5.4vw,52px);line-height:1.04;margin:0 0 14px;max-width:18ch}
.lede{font-size:clamp(17px,2vw,19.5px);line-height:1.5;color:var(--ink-2);max-width:66ch;margin:0 0 14px}
.meta{display:flex;flex-wrap:wrap;gap:4px 18px;margin:0 0 20px;font:13px/1.5 "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted)}
.toc{display:flex;flex-wrap:wrap;gap:6px 18px;padding-block:12px;border-top:1px solid var(--rule);border-bottom:1px solid var(--rule);font-size:14px}
.toc a{color:var(--ink-2);text-decoration:none}
.toc a:hover{color:var(--accent);text-decoration:underline}
a{color:var(--accent)}
section{padding-block:36px 8px}
h2{font-size:clamp(25px,3.2vw,33px);line-height:1.12;margin:0 0 16px;display:flex;align-items:baseline;gap:14px}
h2 .no{font:500 14px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted);letter-spacing:.04em}
h3{font-size:17px;line-height:1.35;margin:0 0 6px;font-weight:600}
h3.sub{margin:34px 0 8px;font-size:18px}
p,li{max-width:76ch}
p{margin:0 0 12px}
.intro{color:var(--ink-2);font-size:15px}
code{font-family:"IBM Plex Mono",ui-monospace,Consolas,monospace;font-size:.88em;overflow-wrap:anywhere}
.num{font-family:"IBM Plex Mono",ui-monospace,Consolas,monospace;font-variant-numeric:tabular-nums;font-size:.92em}
ol.answers{list-style:none;padding:0;margin:8px 0 0;display:grid;gap:22px}
li.ans{display:grid;grid-template-columns:3.2rem minmax(0,1fr);gap:0 6px;max-width:none}
li.ans p{max-width:82ch}
.al{font:600 26px/1.1 "Bricolage Grotesque","Avenir Next",system-ui,sans-serif;color:var(--accent)}
ul.mech,ul.cav,ul.hooks{padding-left:1.15rem}
ul.mech li,ul.cav li{margin-bottom:8px}
.box{background:var(--bg-2);border:1px solid var(--rule);border-radius:6px;padding:16px 20px;margin:26px 0 8px;max-width:88ch}
.box h3{margin-bottom:4px}
.box ul{margin:6px 0 0;padding-left:1.1rem}
.box li{margin-bottom:5px}
.box.next{margin-top:28px}
.grid{display:grid;gap:26px 26px;margin:6px 0 4px}
.grid>*{min-width:0}
.g-obs{grid-template-columns:repeat(auto-fill,minmax(min(100%,300px),1fr))}
.g-sm{grid-template-columns:repeat(auto-fill,minmax(min(100%,220px),1fr));gap:18px 22px}
.g-3{grid-template-columns:repeat(auto-fill,minmax(min(100%,320px),1fr))}
.g-4{grid-template-columns:repeat(auto-fill,minmax(min(100%,250px),1fr))}
.g-2{grid-template-columns:repeat(auto-fill,minmax(min(100%,420px),1fr))}
.g-1{grid-template-columns:minmax(0,1fr);max-width:820px}
.g-rem{grid-template-columns:minmax(0,1.6fr) minmax(0,1fr);align-items:start}
@media (max-width:860px){.g-rem{grid-template-columns:minmax(0,1fr)}}
figure.chart{margin:0;min-width:0}
.ct{font-size:14.5px;font-weight:600;line-height:1.35;margin-bottom:2px;color:var(--fg)}
.cap{font-size:13px;line-height:1.45;color:var(--ink-2);margin:4px 0 0}
.plot{position:relative;min-height:150px;width:100%}
svg.viz{display:block;overflow:visible;touch-action:pan-y;max-width:100%}
svg.viz:focus{outline:none}
svg.viz:focus-visible{outline:2px solid var(--accent);outline-offset:3px;border-radius:2px}
.viz text{font-family:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif}
.viz .tick{fill:var(--muted);font-size:11px;font-variant-numeric:tabular-nums}
.viz .note{fill:var(--ink-2);font-size:10.5px;paint-order:stroke;stroke:var(--bg);stroke-width:3px;stroke-linejoin:round}
.viz .endlab{fill:var(--ink-2);font-size:11px;paint-order:stroke;stroke:var(--bg);stroke-width:3px;stroke-linejoin:round}
.viz .cat{fill:var(--ink-2);font-size:12px}
.legend{display:flex;flex-wrap:wrap;gap:4px 18px;font-size:13px;color:var(--ink-2);margin:10px 0 14px}
.legend .li{display:inline-flex;align-items:center;gap:7px}
.plot .legend{margin:2px 0 4px;font-size:12px;gap:2px 12px}
svg.key{flex:none;overflow:visible}
.tip{position:absolute;z-index:5;pointer-events:none;background:var(--tip-bg);color:var(--fg);border:1px solid var(--tip-bd);border-radius:6px;
  box-shadow:0 6px 18px var(--shadow);padding:7px 10px 8px;font-size:12px;line-height:1.45;min-width:150px;max-width:min(270px,92%)}
.tip[hidden]{display:none}
.tip-h{font:500 11px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted);margin-bottom:3px}
.tip-r{display:flex;align-items:center;gap:7px;white-space:nowrap}
.tip-r b{font:500 12px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--fg);min-width:4.6em;text-align:right;font-variant-numeric:tabular-nums}
.tip-r span{color:var(--ink-2);overflow:hidden;text-overflow:ellipsis}
details.tables{margin:14px 0 6px;border-top:1px solid var(--rule);padding-top:8px}
details.tables summary{cursor:pointer;font-size:13.5px;color:var(--ink-2)}
details.tables summary:hover{color:var(--accent)}
.tblhost{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,360px),1fr));gap:18px 24px;margin-top:10px}
.tblhost>*{min-width:0}
.tw{overflow-x:auto;max-width:100%;margin:10px 0}
table{border-collapse:collapse;font-size:13px;line-height:1.4;width:100%}
caption{text-align:left;font-size:12.5px;color:var(--muted);padding-bottom:6px}
th,td{padding:5px 9px;border-bottom:1px solid var(--rule);text-align:left;vertical-align:top}
thead th{font-weight:600;color:var(--ink-2);border-bottom:1px solid var(--axis);white-space:nowrap}
td.n,.tblhost td{font-family:"IBM Plex Mono",ui-monospace,Consolas,monospace;font-variant-numeric:tabular-nums;font-size:12.5px}
.tblhost td{text-align:right}
.tblhost th[scope=row]{font:500 12.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--ink-2)}
table.feat td{font-size:13px}
table.diag td:first-child,table.diag th:first-child{min-width:150px}
table.diag td:last-child{min-width:120px}
table.feat td:first-child{color:var(--muted)}
table.feat tr:target{background:var(--band-2)}
table.val td:nth-child(2){font-size:12.5px}
.chip{display:inline-block;font:600 10.5px/1.7 "IBM Plex Mono",ui-monospace,Consolas,monospace;letter-spacing:.05em;padding:0 7px;border-radius:999px;
  background:var(--chip-bg);color:var(--chip-fg);border:1px solid var(--chip-bd);white-space:nowrap}
.asked{font:500 11px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted)}
.st{display:inline-block;font:600 10.5px/1.7 "IBM Plex Mono",ui-monospace,Consolas,monospace;padding:0 7px;border-radius:4px}
.st-pass{background:var(--pass-bg);color:var(--pass-fg)}
.st-fail{background:var(--fail-bg);color:var(--fail-fg)}
pre{max-width:100%}
pre.code{background:var(--bg-2);border:1px solid var(--rule);border-radius:6px;padding:12px 14px;overflow-x:auto;font-size:12.5px;line-height:1.5;margin:8px 0 14px}
pre.code code{font-size:inherit;overflow-wrap:normal;white-space:pre}
pre.mermaid{background:var(--bg-2);border:1px solid var(--rule);border-radius:6px;padding:12px;overflow-x:auto;font-size:12px;line-height:1.45;white-space:pre}
ol.timing{padding-left:1.2rem;font-size:15px}
ol.timing li{margin-bottom:6px}
.tb>div{min-width:0}
.foot{padding-block:28px 48px;color:var(--muted);font-size:13px;border-top:1px solid var(--rule);margin-top:36px}
@media (max-width:520px){li.ans{grid-template-columns:2.2rem minmax(0,1fr)} .al{font-size:21px} h2{gap:10px}}
@media (prefers-reduced-motion: no-preference){html{scroll-behavior:smooth}}
@media (prefers-reduced-motion: reduce){*{animation:none!important;transition:none!important;scroll-behavior:auto!important}}
.g-fan{grid-template-columns:repeat(2,minmax(0,1fr))}
@media (max-width:620px){.g-fan{grid-template-columns:minmax(0,1fr)}}
.g-plm{grid-template-columns:repeat(auto-fill,minmax(min(100%,260px),1fr))}
.part{margin:60px 0 0;padding:22px 0 2px;border-top:3px solid var(--fg)}
.part .kicker{margin-bottom:6px}
.part-t{font:650 clamp(24px,3vw,30px)/1.15 "Bricolage Grotesque","Avenir Next","Segoe UI",system-ui,sans-serif;margin:0 0 10px;letter-spacing:-.015em;color:var(--fg)}
.toc .tp{font:500 11.5px/1.9 "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
.box h4{font-size:14.5px;margin:12px 0 2px}
.opts{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,440px),1fr));gap:2px 26px}
.opts>div{min-width:0}
.opts h4{font-size:14.5px;margin:16px 0 2px;font-weight:600}
.opts pre.code{margin:4px 0 2px}
.tip-t{border-top:1px solid var(--rule);margin-top:3px;padding-top:3px}
.st-info{background:var(--bg-2);color:var(--ink-2);border:1px solid var(--rule)}
"""

CSS_EXTRA = r"""
.answer{font-size:17px;line-height:1.5;color:var(--fg);max-width:78ch;margin:0 0 14px;padding:2px 0 2px 14px;border-left:3px solid var(--accent)}
.fig{font-size:14px;line-height:1.4;color:var(--ink-2);margin:30px 0 6px;max-width:88ch}
.fig .fn{font:600 12.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted);margin-right:4px}
.subt{font-size:12.5px;line-height:1.3;color:var(--ink-2);margin:8px 0 0;font-weight:500;max-width:none}
.plot.sh{min-height:96px}
.g-1w{grid-template-columns:minmax(0,1fr)}
.toc a{white-space:nowrap}
.toc .tn{font:500 11.5px "IBM Plex Mono",ui-monospace,Consolas,monospace;color:var(--muted)}
.box.base{max-width:none;margin-top:8px}
.box.warn{border-left:4px solid var(--chip-bd);max-width:92ch}
.box.pending{border-left:4px solid var(--axis)}
.seg{display:inline-flex;flex-wrap:wrap;border:1px solid var(--rule);border-radius:6px;overflow:hidden;margin:6px 0 2px}
.seg button{font:500 13px/1.3 "IBM Plex Sans",system-ui,sans-serif;background:var(--bg);color:var(--ink-2);border:0;padding:6px 12px;cursor:pointer}
.seg button+button{border-left:1px solid var(--rule)}
.seg button[aria-pressed="true"]{background:var(--bg-2);color:var(--fg);font-weight:600}
.seg button:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
.codelab{margin:14px 0 0;font-size:12.5px;color:var(--muted)}
.codelab+pre.code{margin-top:4px}
.muted{color:var(--muted)}
table.rel td .p{color:var(--muted);font-size:11.5px}
table.rel td .sig{font-weight:600;color:var(--fg)}
table.rel td{white-space:nowrap}
table.rel td,table.rel th{padding:4px 5px}
table.rel td .p{font-size:10.5px}
table.rel td:first-child{white-space:normal;min-width:150px}
table.loss td{white-space:nowrap}
table.loss td:nth-child(2){white-space:normal;min-width:150px}
table.plm td:nth-child(6){min-width:260px}
table.feat td:nth-child(2){min-width:260px}
table.feat td:nth-child(3){min-width:180px}
table.feat tr.removed td{color:var(--muted)}
table.feat tr.removed td code{color:var(--muted)}
table.repro td{font-size:12.5px}
table.val td:first-child{white-space:nowrap}
.chip.rm{background:var(--fail-bg);color:var(--fail-fg);border-color:var(--fail-bg)}
figure.hist .subt:first-of-type{margin-top:4px}
"""

JS = r"""
(function(){
'use strict';
var D = JSON.parse(document.getElementById('report-data').textContent);
var NS = 'http://www.w3.org/2000/svg', MINUS = '−';
var DASH = {solid: null, dashed: '6 4', dotted: '0.6 3.4', dashdot: '9 3 1.5 3'};
function fmt(v, d){ if (v === null || v === undefined || !isFinite(v)) return 'n/a';
  var s = Math.abs(v).toFixed(d); if (v < 0 && Number(s) !== 0) s = MINUS + s; return s; }
function mk(tag, attrs, parent){ var e = document.createElementNS(NS, tag);
  if (attrs) for (var k in attrs) if (attrs[k] !== null && attrs[k] !== undefined) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e); return e; }
function cvar(c){ return c === 'ink' ? 'var(--ink-2)' : 'var(--' + c + ')'; }
function niceStep(range, n){ var raw = range / Math.max(1, n), p = Math.pow(10, Math.floor(Math.log10(raw))), f = raw / p;
  return (f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10) * p; }
function ticks(lo, hi, n){ if (hi - lo < 1e-9){ lo -= 1; hi += 1; } var st = niceStep(hi - lo, n), a = Math.floor(lo / st) * st,
  b = Math.ceil(hi / st) * st, out = []; for (var v = a; v <= b + st * 1e-6; v += st) out.push(Math.abs(v) < st * 1e-9 ? 0 : v);
  return {t: out, step: st}; }
function decs(step){ return step >= 1 ? 0 : step >= 0.1 ? 1 : step >= 0.01 ? 2 : 3; }
function niceEvery(raw){ var c = [1, 2, 5, 10, 20, 50]; for (var i = 0; i < c.length; i++) if (c[i] >= raw) return c[i]; return 100; }
var MARK = {
  square: function(g, x, y, r, c){ var s = r * 0.9; return mk('rect', {x: x - s, y: y - s, width: 2 * s, height: 2 * s, rx: 1, fill: c, stroke: 'var(--bg)', 'stroke-width': 1.5}, g); },
  diamond: function(g, x, y, r, c){ var s = r * 1.3; return mk('path', {d: 'M' + x + ',' + (y - s) + 'L' + (x + s) + ',' + y + 'L' + x + ',' + (y + s) + 'L' + (x - s) + ',' + y + 'Z',
    fill: c, stroke: 'var(--bg)', 'stroke-width': 1.5}, g); },
  tri: function(g, x, y, r, c){ var s = r * 1.25; return mk('path', {d: 'M' + x + ',' + (y - s) + 'L' + (x + s) + ',' + (y + s * 0.85) + 'L' + (x - s) + ',' + (y + s * 0.85) + 'Z',
    fill: c, stroke: 'var(--bg)', 'stroke-width': 1.5}, g); }
};
function drawMark(g, kind, x, y, r, c){ var cc = cvar(c);
  if (kind === 'ring') return mk('circle', {cx: x, cy: y, r: r, fill: 'var(--bg)', stroke: cc, 'stroke-width': 2}, g);
  if (MARK[kind]) return MARK[kind](g, x, y, r, cc);
  return mk('circle', {cx: x, cy: y, r: r, fill: cc, stroke: 'var(--bg)', 'stroke-width': 2}, g); }
function key(s, w){ w = w || 22; var svg = mk('svg', {width: w, height: 10, 'aria-hidden': 'true', 'class': 'key'});
  if (s.kind === 'box') mk('rect', {x: w / 2 - 5, y: 0, width: 10, height: 10, rx: 2, fill: cvar(s.color)}, svg);
  else if (s.kind === 'band') mk('rect', {x: 1, y: 0, width: w - 2, height: 10, rx: 2, fill: cvar(s.color), 'fill-opacity': s.op || 0.25}, svg);
  else if (s.kind) drawMark(svg, s.kind, w / 2, 5, 4, s.color);
  else mk('line', {x1: 1, y1: 5, x2: w - 1, y2: 5, stroke: cvar(s.color), 'stroke-width': s.width || 2, 'stroke-linecap': 'round',
    'stroke-dasharray': DASH[s.style || 'solid']}, svg);
  return svg; }
function legendInto(host, items){ var wrap = document.createElement('div'); wrap.className = 'legend';
  items.forEach(function(it){ var sp = document.createElement('span'); sp.className = 'li'; sp.appendChild(key(it));
    var t = document.createElement('span'); t.textContent = it.name; sp.appendChild(t); wrap.appendChild(sp); });
  host.appendChild(wrap); }

function renderLine(host, spec){
  var W = Math.max(220, Math.floor(host.clientWidth || 320));
  host.textContent = '';
  if (spec.legend !== false && spec.series.length >= 2) legendInto(host, spec.series);
  var X = spec.x, n = X.length, d = (spec.dec === undefined) ? 2 : spec.dec;
  var narrow = W < 360, H = spec.h || (narrow ? 200 : 226);
  var skip = {}; (spec.clip || []).forEach(function(q){ skip[q] = 1; });
  var lo = Infinity, hi = -Infinity;
  spec.series.forEach(function(s){ s.v.forEach(function(v, i){ if (v === null || skip[X[i]]) return; if (v < lo) lo = v; if (v > hi) hi = v; }); });
  (spec.refs || []).forEach(function(r){ lo = Math.min(lo, r.y); hi = Math.max(hi, r.y); });
  (spec.bands || []).forEach(function(b){ [b.lo, b.hi].forEach(function(arr){ arr.forEach(function(v, i){
    if (v === null || skip[X[i]]) return; if (v < lo) lo = v; if (v > hi) hi = v; }); }); });
  if (spec.zero){ lo = Math.min(lo, 0); hi = Math.max(hi, 0); }
  if (spec.yr){ lo = spec.yr[0]; hi = spec.yr[1]; }
  var tk;
  if (spec.yfix){ tk = {t: [0, 0.25, 0.5, 0.75, 1], step: 0.25}; }
  else { var pad = (hi - lo) * 0.05 || 0.5; tk = ticks(lo - pad, hi + pad, H < 170 ? 3 : (narrow ? 4 : 5)); }
  var y0 = tk.t[0], y1 = tk.t[tk.t.length - 1], td = spec.yfix ? 2 : decs(tk.step);
  var tl = tk.t.map(function(v){ return fmt(v, td); });
  var maxLab = Math.max.apply(null, tl.map(function(s){ return s.length; }));
  var showEnd = spec.endLabels !== false && spec.series.length >= 2 && spec.series.length <= 4;
  var endW = showEnd ? Math.min(92, Math.max.apply(null, spec.series.map(function(s){ return (s.short || s.name).length; })) * 6.2 + 14) : 12;
  var M = {l: spec.ml || (maxLab * 6.4 + 10), r: (spec.mr !== undefined && spec.mr !== null) ? spec.mr : endW, t: 16, b: 22};
  var pw = Math.max(60, W - M.l - M.r), ph = H - M.t - M.b;
  function xs(i){ return M.l + (n === 1 ? pw / 2 : i * pw / (n - 1)); }
  function ys(v){ return M.t + (y1 - v) / (y1 - y0) * ph; }
  var svg = mk('svg', {width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': spec.title, tabindex: 0, 'class': 'viz'});
  host.appendChild(svg);
  var clipId = 'clip-' + spec.id;
  var cp = mk('clipPath', {id: clipId}, mk('defs', null, svg)); mk('rect', {x: M.l - 1, y: M.t - 2, width: pw + 2, height: ph + 4}, cp);
  var oi = X.indexOf(spec.origin);
  if (oi >= 0 && spec.bandForecast !== false) mk('rect', {x: xs(oi), y: M.t, width: xs(n - 1) - xs(oi), height: ph, fill: 'var(--band)'}, svg);
  if (spec.band){ var ba = X.indexOf(spec.band[0]), bb = X.indexOf(spec.band[1]);
    if (ba >= 0 && bb >= 0){ mk('rect', {x: xs(ba), y: M.t, width: xs(bb) - xs(ba), height: ph, fill: 'var(--band-2)'}, svg);
      var bt = mk('text', {x: xs(ba) + 3, y: M.t + ph - 5, 'class': 'note'}, svg); bt.textContent = spec.band[2]; } }
  tk.t.forEach(function(v, k){ var y = ys(v);
    mk('line', {x1: M.l, x2: M.l + pw, y1: y, y2: y, stroke: v === 0 ? 'var(--axis)' : 'var(--grid)', 'stroke-width': 1, 'shape-rendering': 'crispEdges'}, svg);
    var t = mk('text', {x: M.l - 6, y: y + 3.5, 'text-anchor': 'end', 'class': 'tick'}, svg); t.textContent = tl[k]; });
  if (spec.xcat){ var ce = Math.max(1, Math.ceil(28 / (pw / Math.max(1, n - 1))));
    X.forEach(function(q, i){ if (i % ce) return;
      mk('line', {x1: xs(i), x2: xs(i), y1: M.t + ph, y2: M.t + ph + 4, stroke: 'var(--axis)', 'stroke-width': 1}, svg);
      var t = mk('text', {x: xs(i), y: M.t + ph + 16, 'text-anchor': 'middle', 'class': 'tick'}, svg);
      t.textContent = (spec.xpre && i === 0 ? spec.xpre : '') + q; }); }
  else { var every = niceEvery(36 / (pw / Math.max(1, n / 4)));
  X.forEach(function(q, i){ if (!/Q1$/.test(q)) return; var yr = +q.slice(0, 4); if (every > 1 && yr % every !== 0) return;
    mk('line', {x1: xs(i), x2: xs(i), y1: M.t + ph, y2: M.t + ph + 4, stroke: 'var(--axis)', 'stroke-width': 1}, svg);
    var t = mk('text', {x: xs(i), y: M.t + ph + 16, 'text-anchor': 'middle', 'class': 'tick'}, svg); t.textContent = String(yr); }); }
  mk('line', {x1: M.l, x2: M.l + pw, y1: M.t + ph, y2: M.t + ph, stroke: 'var(--axis)', 'stroke-width': 1, 'shape-rendering': 'crispEdges'}, svg);
  if (oi > 0){ mk('line', {x1: xs(oi), x2: xs(oi), y1: M.t, y2: M.t + ph, stroke: 'var(--axis)', 'stroke-width': 1}, svg);
    var ot = mk('text', {x: xs(oi) - 3, y: M.t - 5, 'text-anchor': 'end', 'class': 'note'}, svg); ot.textContent = spec.origin; }
  (spec.rules || []).forEach(function(r){ var i = X.indexOf(r.x); if (i < 0) return;
    mk('line', {x1: xs(i), x2: xs(i), y1: M.t, y2: M.t + ph, stroke: 'var(--ink-2)', 'stroke-width': 1, 'stroke-opacity': 0.7}, svg);
    var t = mk('text', {x: xs(i) + 3, y: M.t - 5, 'class': 'note'}, svg); t.textContent = r.label; });
  (spec.refs || []).forEach(function(r){ var y = ys(r.y);
    mk('line', {x1: M.l, x2: M.l + pw, y1: y, y2: y, stroke: 'var(--ink-2)', 'stroke-width': 1, 'stroke-opacity': 0.6}, svg);
    var t = mk('text', {x: M.l + 4, y: y - 4, 'class': 'note'}, svg); t.textContent = r.label; });
  var g = mk('g', {'clip-path': 'url(#' + clipId + ')'}, svg);
  (spec.bands || []).forEach(function(b){ var up = [], dn = [];
    b.lo.forEach(function(v, i){ if (v === null || b.hi[i] === null) return; up.push(xs(i).toFixed(1) + ',' + ys(b.hi[i]).toFixed(1));
      dn.unshift(xs(i).toFixed(1) + ',' + ys(v).toFixed(1)); });
    if (up.length > 1) mk('path', {d: 'M' + up.join('L') + 'L' + dn.join('L') + 'Z', fill: cvar(b.color), 'fill-opacity': b.op || 0.18, stroke: 'none'}, g); });
  spec.series.forEach(function(s){
    var segs = [], cur = [];
    s.v.forEach(function(v, i){ if (v === null){ if (cur.length) segs.push(cur); cur = []; } else cur.push(i); });
    if (cur.length) segs.push(cur);
    segs.forEach(function(seg){
      var df = s.dashFrom, parts;
      if (df !== undefined && df !== null && seg[seg.length - 1] > df && seg[0] <= df)
        parts = [[seg.filter(function(i){ return i <= df; }), s.style || 'solid'], [seg.filter(function(i){ return i >= df; }), 'dashed']];
      else parts = [[seg, s.style || 'solid']];
      parts.forEach(function(p){ var ix = p[0]; if (ix.length < 2) return;
        var dd = ix.map(function(i, k){ return (k ? 'L' : 'M') + xs(i).toFixed(1) + ',' + ys(s.v[i]).toFixed(1); }).join('');
        mk('path', {d: dd, fill: 'none', stroke: cvar(s.color), 'stroke-width': s.width || 2, 'stroke-linejoin': 'round',
          'stroke-linecap': 'round', 'stroke-dasharray': DASH[p[1]]}, g); });
    });
    (s.rings || []).forEach(function(i){ if (s.v[i] === null) return;
      mk('circle', {cx: xs(i), cy: ys(s.v[i]), r: 4, fill: cvar(s.color), stroke: 'var(--bg)', 'stroke-width': 2}, g); });
  });
  if (showEnd){
    var labs = [];
    spec.series.forEach(function(s){ var i = s.v.length - 1; while (i >= 0 && s.v[i] === null) i--; if (i < 0) return;
      var y = ys(s.v[i]); if (y < M.t - 2 || y > M.t + ph + 2) return; labs.push({s: s, i: i, y: y, y0: y}); });
    labs.sort(function(a, b){ return a.y - b.y; });
    var gap = 12, k;
    for (k = 1; k < labs.length; k++) if (labs[k].y - labs[k - 1].y < gap) labs[k].y = labs[k - 1].y + gap;
    var bot = M.t + ph + 6;
    if (labs.length && labs[labs.length - 1].y > bot){ var sh = labs[labs.length - 1].y - bot; labs.forEach(function(o){ o.y -= sh; }); }
    labs.forEach(function(o){ var x0 = xs(o.i) + 3, xl = M.l + pw + 8;
      if (Math.abs(o.y - o.y0) > 2.5) mk('path', {d: 'M' + x0 + ',' + o.y0 + 'L' + (xl - 2) + ',' + o.y, stroke: 'var(--muted)', 'stroke-width': 1, fill: 'none'}, svg);
      var t = mk('text', {x: xl, y: o.y + 3.5, 'class': 'endlab'}, svg); t.textContent = o.s.short || o.s.name; });
  }
  var cross = mk('line', {y1: M.t, y2: M.t + ph, stroke: 'var(--ink-2)', 'stroke-width': 1, visibility: 'hidden'}, svg);
  var dots = spec.series.map(function(s){ return mk('circle', {r: 3.5, fill: cvar(s.color), stroke: 'var(--bg)', 'stroke-width': 2, visibility: 'hidden'}, svg); });
  var hit = mk('rect', {x: M.l - 6, y: 0, width: pw + 12, height: M.t + ph, fill: 'transparent', 'pointer-events': 'all'}, svg);
  var tip = document.createElement('div'); tip.className = 'tip'; tip.hidden = true; host.appendChild(tip);
  var curI = -1;
  function show(i){ i = Math.max(0, Math.min(n - 1, i)); curI = i; var x = xs(i);
    cross.setAttribute('x1', x); cross.setAttribute('x2', x); cross.setAttribute('visibility', 'visible');
    spec.series.forEach(function(s, k){ var v = s.v[i]; if (v === null || ys(v) < M.t - 1 || ys(v) > M.t + ph + 1){ dots[k].setAttribute('visibility', 'hidden'); return; }
      dots[k].setAttribute('cx', x); dots[k].setAttribute('cy', ys(v)); dots[k].setAttribute('visibility', 'visible'); });
    tip.textContent = ''; var h = document.createElement('div'); h.className = 'tip-h';
    h.textContent = (spec.xpre || '') + X[i] + (oi >= 0 && i > oi && spec.bandForecast !== false ? '  forecast' : ''); tip.appendChild(h);
    spec.series.forEach(function(s){ var v = s.v[i]; if (v === null) return; var r = document.createElement('div'); r.className = 'tip-r';
      r.appendChild(key(s, 14)); var b = document.createElement('b'); b.textContent = fmt(v, d); r.appendChild(b);
      var sp = document.createElement('span'); sp.textContent = s.name; r.appendChild(sp); tip.appendChild(r); });
    (spec.bands || []).forEach(function(b){ if (b.lo[i] === null) return; var r = document.createElement('div'); r.className = 'tip-r';
      r.appendChild(key({kind: 'band', color: b.color, op: (b.op || 0.18) + 0.2}, 14)); var bb = document.createElement('b');
      bb.textContent = fmt(b.lo[i], d) + ' to ' + fmt(b.hi[i], d); r.appendChild(bb); var sp = document.createElement('span');
      sp.textContent = b.name; r.appendChild(sp); tip.appendChild(r); });
    tip.hidden = false;
    var top = svg.offsetTop + M.t + 6, tw = tip.offsetWidth, left = x + 14;
    if (left + tw > W) left = x - 14 - tw; if (left < 0) left = Math.max(0, W - tw);
    tip.style.left = left + 'px'; tip.style.top = top + 'px'; }
  function hide(){ cross.setAttribute('visibility', 'hidden'); dots.forEach(function(c){ c.setAttribute('visibility', 'hidden'); }); tip.hidden = true; }
  function move(e){ var r = svg.getBoundingClientRect(); var px = (e.clientX - r.left) * (W / r.width); show(Math.round((px - M.l) / (pw / Math.max(1, n - 1)))); }
  hit.addEventListener('pointermove', move); hit.addEventListener('pointerdown', move); hit.addEventListener('pointerleave', hide);
  svg.addEventListener('focus', function(){ show(curI < 0 ? n - 1 : curI); }); svg.addEventListener('blur', hide);
  svg.addEventListener('keydown', function(e){ if (e.key === 'ArrowLeft'){ show(curI - 1); e.preventDefault(); }
    else if (e.key === 'ArrowRight'){ show(curI + 1); e.preventDefault(); } else if (e.key === 'Escape') hide(); });
}

function renderDots(host, spec){
  var W = Math.max(240, Math.floor(host.clientWidth || 320)); host.textContent = '';
  var cats = spec.cats, d = spec.dec || 3, labW = Math.max.apply(null, cats.map(function(c){ return c.length; })) * 6.6 + 12;
  var rowH = spec.rowH || 28, M = {l: labW, r: 16, t: 10, b: 24}, H = M.t + M.b + rowH * cats.length, pw = Math.max(60, W - M.l - M.r);
  var hasRef = spec.ref !== null && spec.ref !== undefined, lo = hasRef ? spec.ref : Infinity, hi = hasRef ? spec.ref : -Infinity;
  spec.series.forEach(function(s){ s.v.forEach(function(v){ if (v === null) return; lo = Math.min(lo, v); hi = Math.max(hi, v); }); });
  var pad = (hi - lo) * 0.06 || 0.05, l0 = lo - pad; if (spec.xmin !== undefined && l0 < spec.xmin) l0 = spec.xmin;
  var tk = ticks(l0, hi + pad, W < 360 ? 3 : 5), x0 = tk.t[0], x1 = tk.t[tk.t.length - 1], td = decs(tk.step);
  function xs(v){ return M.l + (v - x0) / (x1 - x0) * pw; }
  function ys(i){ return M.t + rowH * (i + 0.5); }
  var svg = mk('svg', {width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': spec.title, 'class': 'viz'}); host.appendChild(svg);
  tk.t.forEach(function(v){ mk('line', {x1: xs(v), x2: xs(v), y1: M.t, y2: H - M.b, stroke: 'var(--grid)', 'stroke-width': 1, 'shape-rendering': 'crispEdges'}, svg);
    var t = mk('text', {x: xs(v), y: H - M.b + 15, 'text-anchor': 'middle', 'class': 'tick'}, svg); t.textContent = fmt(v, td); });
  (spec.sep || []).forEach(function(i){ var y = M.t + rowH * i;
    mk('line', {x1: 0, x2: M.l + pw, y1: y, y2: y, stroke: 'var(--axis)', 'stroke-width': 1, 'shape-rendering': 'crispEdges'}, svg); });
  if (hasRef) mk('line', {x1: xs(spec.ref), x2: xs(spec.ref), y1: M.t, y2: H - M.b, stroke: cvar(spec.refColor || 's1'), 'stroke-width': 2}, svg);
  cats.forEach(function(c, i){ var t = mk('text', {x: M.l - 10, y: ys(i) + 4, 'text-anchor': 'end', 'class': 'cat'}, svg); t.textContent = c;
    mk('line', {x1: M.l, x2: M.l + pw, y1: ys(i), y2: ys(i), stroke: 'var(--grid)', 'stroke-width': 1}, svg); });
  var tip = document.createElement('div'); tip.className = 'tip'; tip.hidden = true; host.appendChild(tip);
  var ring = mk('circle', {r: 9, fill: 'none', stroke: 'var(--ink-2)', 'stroke-width': 1.5, visibility: 'hidden'}, svg);
  spec.series.forEach(function(s){ s.v.forEach(function(v, i){ if (v === null) return;
    var cx = xs(v), cy = ys(i), col = s.colors ? s.colors[i] : s.color, note = s.notes ? s.notes[i] : null;
    drawMark(svg, s.kind || 'dot', cx, cy, rowH < 24 ? 4.2 : 5, col);
    var h = mk('circle', {cx: cx, cy: cy, r: Math.max(9, rowH / 2), fill: 'transparent', tabindex: 0, 'pointer-events': 'all',
      'aria-label': cats[i] + ', ' + s.name + ': ' + fmt(v, d) + (note ? ', ' + note : '')}, svg);
    function on(){ ring.setAttribute('cx', cx); ring.setAttribute('cy', cy); ring.setAttribute('visibility', 'visible');
      tip.textContent = ''; var hh = document.createElement('div'); hh.className = 'tip-h'; hh.textContent = cats[i]; tip.appendChild(hh);
      var r = document.createElement('div'); r.className = 'tip-r'; r.appendChild(key({kind: s.kind || 'dot', color: col}, 14));
      var b = document.createElement('b'); b.textContent = fmt(v, d); r.appendChild(b);
      var sp = document.createElement('span'); sp.textContent = s.name + (note ? ', ' + note : ''); r.appendChild(sp); tip.appendChild(r); tip.hidden = false;
      var tw = tip.offsetWidth, left = cx + 14; if (left + tw > W) left = cx - 14 - tw; tip.style.left = Math.max(0, left) + 'px'; tip.style.top = (cy - 10) + 'px'; }
    function off(){ ring.setAttribute('visibility', 'hidden'); tip.hidden = true; }
    h.addEventListener('pointerenter', on); h.addEventListener('pointerleave', off); h.addEventListener('focus', on); h.addEventListener('blur', off); }); });
  if (hasRef && spec.refLabel){ var rl = mk('text', {x: xs(spec.ref) + 4, y: M.t + 2, 'class': 'note', 'dominant-baseline': 'hanging'}, svg); rl.textContent = spec.refLabel; }
}

function segPath(x, y, w, h, r, outer){
  if (!r || !outer) return 'M' + x + ',' + y + 'h' + w + 'v' + h + 'h' + (-w) + 'Z';
  if (outer === 'top') return 'M' + x + ',' + (y + h) + 'V' + (y + r) + 'Q' + x + ',' + y + ' ' + (x + r) + ',' + y + 'H' + (x + w - r) +
    'Q' + (x + w) + ',' + y + ' ' + (x + w) + ',' + (y + r) + 'V' + (y + h) + 'Z';
  return 'M' + x + ',' + y + 'V' + (y + h - r) + 'Q' + x + ',' + (y + h) + ' ' + (x + r) + ',' + (y + h) + 'H' + (x + w - r) +
    'Q' + (x + w) + ',' + (y + h) + ' ' + (x + w) + ',' + (y + h - r) + 'V' + y + 'Z';
}

function renderStack(host, spec){
  var W = Math.max(240, Math.floor(host.clientWidth || 320)); host.textContent = '';
  var X = spec.x, n = X.length, d = (spec.dec === undefined) ? 2 : spec.dec, narrow = W < 360, H = spec.h || (narrow ? 210 : 240);
  var skip = {}; (spec.clip || []).forEach(function(q){ skip[q] = 1; });
  var lo = 0, hi = 0, i;
  for (i = 0; i < n; i++){ if (skip[X[i]]) continue; var p = 0, q = 0, tv = spec.total ? spec.total.v[i] : null;
    spec.series.forEach(function(s){ var v = s.v[i]; if (v === null) return; if (v > 0) p += v; else q += v; });
    lo = Math.min(lo, q, tv === null ? 0 : tv); hi = Math.max(hi, p, tv === null ? 0 : tv); }
  if (spec.yr){ lo = spec.yr[0]; hi = spec.yr[1]; }
  var pad = (hi - lo) * 0.04 || 0.5, tk = ticks(lo - pad, hi + pad, narrow ? 4 : 5), y0 = tk.t[0], y1 = tk.t[tk.t.length - 1], td = decs(tk.step);
  var tl = tk.t.map(function(v){ return fmt(v, td); }), maxLab = Math.max.apply(null, tl.map(function(s){ return s.length; }));
  var M = {l: maxLab * 6.4 + 10, r: 10, t: 14, b: 22}, pw = Math.max(60, W - M.l - M.r), ph = H - M.t - M.b;
  var slot = pw / n, dense = slot < 5, bw = dense ? Math.max(0.8, slot * 0.86) : Math.min(24, Math.max(3, slot * 0.72));
  function xc(k){ return M.l + slot * (k + 0.5); }
  function ys(v){ return M.t + (y1 - v) / (y1 - y0) * ph; }
  var svg = mk('svg', {width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': spec.title, tabindex: 0, 'class': 'viz'});
  host.appendChild(svg);
  var clipId = 'clip-' + spec.id, cp = mk('clipPath', {id: clipId}, mk('defs', null, svg));
  mk('rect', {x: M.l - 1, y: M.t - 2, width: pw + 2, height: ph + 4}, cp);
  tk.t.forEach(function(v, k){ var y = ys(v);
    mk('line', {x1: M.l, x2: M.l + pw, y1: y, y2: y, stroke: 'var(--grid)', 'stroke-width': 1, 'shape-rendering': 'crispEdges'}, svg);
    var t = mk('text', {x: M.l - 6, y: y + 3.5, 'text-anchor': 'end', 'class': 'tick'}, svg); t.textContent = tl[k]; });
  var every = niceEvery(36 / (slot * 4));
  X.forEach(function(q, k){ if (!/Q1$/.test(q)) return; var yr = +q.slice(0, 4); if (every > 1 && yr % every !== 0) return;
    var x = M.l + slot * k; mk('line', {x1: x, x2: x, y1: M.t + ph, y2: M.t + ph + 4, stroke: 'var(--axis)', 'stroke-width': 1}, svg);
    if (n - k < 3) return;
    var t = mk('text', {x: Math.min(x + slot * 2, M.l + pw - 12), y: M.t + ph + 16, 'text-anchor': 'middle', 'class': 'tick'}, svg); t.textContent = String(yr); });
  var hl = mk('rect', {y: M.t, width: slot, height: ph, fill: 'var(--fg)', 'fill-opacity': 0.07, visibility: 'hidden'}, svg);
  var g = mk('g', {'clip-path': 'url(#' + clipId + ')'}, svg);
  for (i = 0; i < n; i++){
    var up = 0, dn = 0, segs = [], lastP = -1, lastN = -1;
    spec.series.forEach(function(s, k){ var v = s.v[i]; if (v === null || v === 0) return; segs.push({k: k, v: v}); });
    segs.forEach(function(o, j){ if (o.v > 0) lastP = j; else lastN = j; });
    segs.forEach(function(o, j){ var a, b; if (o.v > 0){ a = up; b = up + o.v; up = b; } else { a = dn; b = dn + o.v; dn = b; }
      var yt = ys(Math.max(a, b)), yb = ys(Math.min(a, b)), hgt = Math.max(0.5, yb - yt), x0 = xc(i) - bw / 2;
      var outer = (o.v > 0 && j === lastP) ? 'top' : ((o.v < 0 && j === lastN) ? 'bottom' : null), r = Math.min(3, bw / 3, hgt / 2);
      mk('path', {d: segPath(x0, yt, bw, hgt, dense ? 0 : r, outer), fill: cvar(spec.series[o.k].color), stroke: dense ? 'none' : 'var(--bg)', 'stroke-width': dense ? 0 : 2,
        'stroke-linejoin': 'round'}, g); });
  }
  mk('line', {x1: M.l, x2: M.l + pw, y1: ys(0), y2: ys(0), stroke: 'var(--axis)', 'stroke-width': 1, 'shape-rendering': 'crispEdges'}, svg);
  if (spec.total){ var tvv = spec.total.v, dd = '', on = false;
    tvv.forEach(function(v, k){ if (v === null){ on = false; return; } dd += (on ? 'L' : 'M') + xc(k).toFixed(1) + ',' + ys(v).toFixed(1); on = true; });
    mk('path', {d: dd, fill: 'none', stroke: 'var(--fg)', 'stroke-width': 1.5, 'stroke-linejoin': 'round', 'stroke-linecap': 'round'}, g);
    if (!dense) tvv.forEach(function(v, k){ if (v === null) return; mk('circle', {cx: xc(k), cy: ys(v), r: 2.6, fill: 'var(--fg)', stroke: 'var(--bg)', 'stroke-width': 1.5}, g); }); }
  var tip = document.createElement('div'); tip.className = 'tip'; tip.hidden = true; host.appendChild(tip);
  var hit = mk('rect', {x: M.l, y: 0, width: pw, height: M.t + ph, fill: 'transparent', 'pointer-events': 'all'}, svg);
  var curI = -1;
  function row(kd, val, name, cls){ var r = document.createElement('div'); r.className = 'tip-r' + (cls ? ' ' + cls : ''); r.appendChild(key(kd, 14));
    var b = document.createElement('b'); b.textContent = fmt(val, d); r.appendChild(b);
    var sp = document.createElement('span'); sp.textContent = name; r.appendChild(sp); tip.appendChild(r); }
  function show(k){ k = Math.max(0, Math.min(n - 1, k)); curI = k; hl.setAttribute('x', M.l + slot * k); hl.setAttribute('visibility', 'visible');
    tip.textContent = ''; var h = document.createElement('div'); h.className = 'tip-h'; h.textContent = X[k]; tip.appendChild(h);
    spec.series.forEach(function(s){ if (s.v[k] !== null) row({kind: 'box', color: s.color}, s.v[k], s.name); });
    if (spec.total && spec.total.v[k] !== null) row({color: 'fg', width: 2}, spec.total.v[k], spec.total.name, 'tip-t');
    tip.hidden = false; var x = xc(k), tw = tip.offsetWidth, left = x + 16; if (left + tw > W) left = x - 16 - tw; if (left < 0) left = Math.max(0, W - tw);
    tip.style.left = left + 'px'; tip.style.top = (svg.offsetTop + M.t + 4) + 'px'; }
  function hide(){ hl.setAttribute('visibility', 'hidden'); tip.hidden = true; }
  function move(e){ var r = svg.getBoundingClientRect(); var px = (e.clientX - r.left) * (W / r.width); show(Math.floor((px - M.l) / slot)); }
  hit.addEventListener('pointermove', move); hit.addEventListener('pointerdown', move); hit.addEventListener('pointerleave', hide);
  svg.addEventListener('focus', function(){ show(curI < 0 ? n - 1 : curI); }); svg.addEventListener('blur', hide);
  svg.addEventListener('keydown', function(e){ if (e.key === 'ArrowLeft'){ show(curI - 1); e.preventDefault(); }
    else if (e.key === 'ArrowRight'){ show(curI + 1); e.preventDefault(); } else if (e.key === 'Escape') hide(); });
}

function tableFor(spec){
  var t = document.createElement('table'), cap = t.createCaption(); cap.textContent = spec.title;
  var d = (spec.dec === undefined) ? 2 : spec.dec, hr = t.createTHead().insertRow(), isDots = spec.type === 'dots';
  var extra = isDots ? [] : (spec.extra || []).slice();
  if (spec.total) extra.unshift({name: spec.total.name, v: spec.total.v, dec: d});
  var cols = [isDots ? (spec.catHead || 'Variable') : (spec.xHead || 'Quarter')].concat(spec.series.map(function(s){ return s.name; }), extra.map(function(e){ return e.name; }));
  cols.forEach(function(c){ var th = document.createElement('th'); th.textContent = c; hr.appendChild(th); });
  var tb = t.createTBody(), rowsN = isDots ? spec.cats.length : spec.x.length;
  for (var i = 0; i < rowsN; i++){
    var vals = spec.series.map(function(s){ return {v: s.v[i], d: d, n: s.notes ? s.notes[i] : null}; })
      .concat(extra.map(function(e){ return {v: e.v[i], d: e.dec === undefined ? 3 : e.dec}; }));
    if (vals.every(function(o){ return o.v === null; })) continue;
    var r = tb.insertRow(), th = document.createElement('th'); th.scope = 'row'; th.textContent = isDots ? spec.cats[i] : (spec.xpre || '') + spec.x[i]; r.appendChild(th);
    vals.forEach(function(o){ r.insertCell().textContent = o.v === null ? '' : fmt(o.v, o.d) + (o.n ? ' (' + o.n + ')' : ''); });
  }
  var w = document.createElement('div'); w.className = 'tw'; w.appendChild(t); return w;
}

var plots = document.querySelectorAll('.plot[data-chart]');
function view(spec){ var key = spec.from || spec.x[0], i0 = spec.from ? spec.x.indexOf(spec.from) : 0;
  if (!spec.yrs && i0 <= 0) return spec;
  var o = {}, k; for (k in spec) o[k] = spec[k];
  if (spec.yrs && spec.yrs[key]) o.yr = spec.yrs[key];
  if (i0 > 0){ var cut = function(a){ return a ? a.slice(i0) : a; };
    o.x = spec.x.slice(i0);
    o.series = spec.series.map(function(s){ var c = {}, j; for (j in s) c[j] = s[j]; c.v = cut(s.v); return c; });
    if (spec.total) o.total = {name: spec.total.name, v: cut(spec.total.v)};
    if (spec.bands) o.bands = spec.bands.map(function(b){ var c = {}, j; for (j in b) c[j] = b[j]; c.lo = cut(b.lo); c.hi = cut(b.hi); return c; }); }
  return o; }
function draw(host){ var spec = D.charts[host.getAttribute('data-chart')]; if (!spec) return;
  try { spec = view(spec); if (spec.type === 'dots') renderDots(host, spec); else if (spec.type === 'stack') renderStack(host, spec); else renderLine(host, spec); host._w = host.clientWidth; }
  catch (err) { host.textContent = 'Chart failed to render: ' + err.message;
    if (window.console) console.error('chart ' + host.getAttribute('data-chart') + ': ' + err.message); } }
Array.prototype.forEach.call(plots, draw);
Array.prototype.forEach.call(document.querySelectorAll('[data-legend]'), function(h){ var it = D.legends[h.getAttribute('data-legend')]; if (it) legendInto(h, it); });
Array.prototype.forEach.call(document.querySelectorAll('[data-tables]'), function(h){ var gid = h.getAttribute('data-tables'),
  det = h.closest ? h.closest('details') : null;
  function build(){ if (h._built) return; h._built = true;
    Object.keys(D.charts).forEach(function(k){ var s = D.charts[k]; if (s.group === gid) h.appendChild(tableFor(s)); }); }
  if (det && !det.open) det.addEventListener('toggle', function(){ if (det.open) build(); }); else build(); });
Array.prototype.forEach.call(document.querySelectorAll('[data-toggle]'), function(g){ var tg = g.getAttribute('data-toggle'),
  btns = g.querySelectorAll('button');
  Array.prototype.forEach.call(btns, function(b){ b.addEventListener('click', function(){
    Array.prototype.forEach.call(btns, function(o){ o.setAttribute('aria-pressed', o === b ? 'true' : 'false'); });
    Array.prototype.forEach.call(plots, function(h){ var s = D.charts[h.getAttribute('data-chart')];
      if (s && s.toggle === tg){ s.from = b.getAttribute('data-from'); draw(h); } }); }); }); });
document.getElementById('report-data').setAttribute('data-drawn', String(plots.length));
if (window.ResizeObserver){ var pending = new Set(), raf = 0;
  var ro = new ResizeObserver(function(entries){ entries.forEach(function(e){ var h = e.target; if (Math.abs((h._w || 0) - h.clientWidth) > 1) pending.add(h); });
    if (!raf) raf = requestAnimationFrame(function(){ raf = 0; pending.forEach(draw); pending.clear(); }); });
  Array.prototype.forEach.call(plots, function(h){ ro.observe(h); }); }
})();
"""

FONTS = ("https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,650"
         "&family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&display=swap")


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
        f"<title>hetlearn results report</title>\n"
        f'<link rel="stylesheet" href="{FONTS}">\n'
        f"<style>{CSS}{CSS_EXTRA}</style>\n"
        f"{body}\n"
        f'<script type="application/json" id="report-data">{data_json}</script>\n'
        f"<script>{JS}</script>\n")
if "—" in page:
    raise SystemExit("em dash in the page")
OUT.write_text(page, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB), {len(CHARTS)} charts, {FIGN[0]} figures, "
      f"other models: {'built' if OM_DONE else 'pending'}; features {N_FEAT} ({N_ADD} ADDED, {N_RM} REMOVED); "
      f"checks {N_PASS}/{len(CHK)} PASS")
