#!/usr/bin/env python3
"""Build reports/sw07_estimation_report.html from results/estimation/tables/ (pipeline step 8, report).

    python reports/build_estimation_report.py        (from the project root, or any folder)
    python reports/build_estimation_report.py --tables DIR --gates FILE --out FILE   (other inputs or output)

The estimation report is separate from the main report (build_report_v3.py). It reads only
results/estimation/tables/*.csv (written by estimation/est_06_post.m) and
results/estimation/gates.txt; every number in the prose is computed from them at build time.
It writes one page (content only, no <html>/<head>/<body>, like the main report: the claude.ai
artifact publisher wraps it).

Two kinds of tables: chain-based ('interim' or 'final', est_06_post('interim'/'final')) and
modes-only ('modes', est_06_post('modes'), written while the MCMC is paused). The status in
post_meta.csv picks the page: the modes page has no posterior means, bands, MHM, R-hat or ESS.

The CSS, the theme tokens (light/dark) and the JS chart engine are those of build_report_v3.py:
its string constants CSS, CSS_EXTRA, JS and FONTS are read with ast (nothing in that file is
executed). Three additions are patched into the JS here, each checked against its anchor: shaded
episodes (spec.shades), a numeric x-axis (spec.xnum) for the density charts, and explicit y ticks
(spec.yticks: the axis runs exactly from the first to the last tick, as the captions say).
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
EST = ROOT / "results" / "estimation"
_AP = argparse.ArgumentParser(description="Build the SW07 estimation report from results/estimation/tables/.")
_AP.add_argument("--tables", default=str(EST / "tables"), help="folder with the tables (default results/estimation/tables)")
_AP.add_argument("--gates", default=str(EST / "gates.txt"), help="gate log (default results/estimation/gates.txt)")
_AP.add_argument("--out", default=str(ROOT / "reports" / "sw07_estimation_report.html"), help="page to write")
_ARGS = _AP.parse_args()
TAB = pathlib.Path(_ARGS.tables)
GATES = pathlib.Path(_ARGS.gates)
OUT = pathlib.Path(_ARGS.out)
esc = html.escape
MINUS = "−"
NAN = float("nan")


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
CSS, CSS_EXTRA, FONTS = _E["CSS"], _E["CSS_EXTRA"], _E["FONTS"]
JS = _E["JS"]
_A1 = "bt.textContent = spec.band[2]; } }\n"
_P1 = ("  (spec.shades || []).forEach(function(b, k){ var sa = X.indexOf(b[0]), sb = X.indexOf(b[1]); if (sa < 0 || sb < 0) return;\n"
       "    mk('rect', {x: xs(sa), y: M.t, width: Math.max(1, xs(sb) - xs(sa)), height: ph, fill: 'var(--band-2)'}, svg);\n"
       "    if (b[2] && !narrow){ var st = mk('text', {x: xs(sa) + 3, y: M.t + 11 + (k % 2) * 12, 'class': 'note'}, svg); st.textContent = b[2]; } });\n")
_A2 = "  if (spec.xcat){ var ce = Math.max(1, Math.ceil(28 / (pw / Math.max(1, n - 1))));"
_P2 = ("  if (spec.xnum){ var x0n = spec.xnum[0], x1n = spec.xnum[1], tx = ticks(x0n, x1n, narrow ? 3 : 5), tdx = decs(tx.step);\n"
       "    tx.t.forEach(function(v){ if (v < x0n - 1e-12 || v > x1n + 1e-12) return; var px = M.l + (v - x0n) / (x1n - x0n) * pw;\n"
       "      mk('line', {x1: px, x2: px, y1: M.t + ph, y2: M.t + ph + 4, stroke: 'var(--axis)', 'stroke-width': 1}, svg);\n"
       "      var t = mk('text', {x: px, y: M.t + ph + 16, 'text-anchor': 'middle', 'class': 'tick'}, svg); t.textContent = fmt(v, tdx); }); }\n"
       "  else ")
# explicit y ticks (spec.yticks): the axis runs exactly from the first to the last tick; values outside are clipped
_A3 = "if (spec.yfix){ tk = {t: [0, 0.25, 0.5, 0.75, 1], step: 0.25}; }"
_P3 = " else if (spec.yticks){ tk = {t: spec.yticks, step: spec.yticks[1] - spec.yticks[0]}; }"
for _a in (_A1, _A2, _A3):
    if JS.count(_a) != 1:
        raise SystemExit(f"JS anchor not found once in build_report_v3.py: {_a[:60]}")
JS = JS.replace(_A1, _A1 + _P1).replace(_A2, _P2 + _A2.lstrip(" ")).replace(_A3, _A3 + _P3)

CSS_EST = r"""
.banner{border-left:4px solid var(--chip-bd);background:var(--chip-bg);color:var(--chip-fg);border-radius:6px;padding:12px 16px;margin:18px 0 6px;max-width:92ch}
.banner p{margin:0;color:var(--chip-fg)}
table.par td{white-space:nowrap}
table.par td:first-child{white-space:normal;min-width:170px}
table.par td .lab{color:var(--muted);font-size:11.5px;display:block;font-family:"IBM Plex Sans",system-ui,sans-serif}
table.par tr.grp td{font-weight:600;color:var(--fg);background:var(--bg-2);font-family:"IBM Plex Sans",system-ui,sans-serif;font-size:13px}
table.par td.flag{color:var(--fg);font-weight:600}
table.mdd td{white-space:nowrap}
table.mdd td:first-child{white-space:normal;min-width:190px}
table.gates td:nth-child(3){font-size:12px;min-width:320px}
table.sens td:first-child{white-space:normal;min-width:200px}
.small{font-size:13px;color:var(--ink-2)}
"""


# ============================================================================= inputs
def rd(name):
    p = TAB / name
    if not p.exists():
        hint = (" (written by estimation/est_06b_app1_post.m)" if name in ("app1_post_long.csv", "app1_post_summary.csv",
                                                                           "share_sensitivity.csv") else "")
        raise SystemExit(f"{p} is missing{hint}")
    return pd.read_csv(p)


par = rd("params.csv")
mdd = rd("mdd.csv")
ppl = rd("prior_post_long.csv")
lpd = rd("lpd_long.csv")
rms = rd("rmse.csv")
pth = rd("paths_long.csv")
irf = rd("irfs_long.csv")
app = rd("app1_long.csv")
dia = rd("diagnostics.csv")
met = rd("post_meta.csv")
ap2 = rd("app1_post_long.csv")          # application 1 consistent with the likelihood (est_06b_app1_post)
aps = rd("app1_post_summary.csv")
sns = rd("share_sensitivity.csv")
gates_txt = GATES.read_text(encoding="utf-8")

META = dict(zip(met.key, met.value.astype(str)))
STATUS = META["status"]
MODES = STATUS == "modes"                      # est_06_post('modes'): posterior modes only, no chain read
INTERIM = STATUS not in ("final", "modes")
_ALL = (par, mdd, ppl, lpd, rms, pth, irf, app, dia, ap2, aps, sns)
STATUSES = sorted(set().union(*[set(d.status.astype(str)) for d in _ALL]))
if MODES and STATUSES != ["modes"]:
    raise SystemExit(f"post_meta.csv says 'modes' but the tables have status {STATUSES}: run est_06_post('modes') "
                     f"with all parts (it also runs est_06b_app1_post('modes')).")
DRAWS_SET = sorted(set().union(*[set(d.learn_draws.astype(int)) for d in _ALL]))
# which learning draws (est_06_post 'draws': stage1 = learn/chains, burn-in 50%; stage2 = learn/chains2, burn-in 10%)
DSRC = META.get("learn_draws_source", "stage1")
DSRC_SET = sorted({x for d in _ALL if "draws" in d.columns for x in d.draws.astype(str) if x in ("stage1", "stage2")} | {DSRC})
BURN = float(META.get("learn_burn_share", "0.5"))
BURN_TXT = "the first half of each" if abs(BURN - 0.5) < 1e-9 else f"the first {BURN * 100:.0f}% of each"
STAGE_TXT = ("the stage-2 chains (proposal: the covariance of the stage-1 draws; stage 1 counted as adaptation)"
             if DSRC == "stage2" else "the stage-1 chains")
CREATED = META["created"]
REPORT_DATE = CREATED[:10]
LDRAWS = int(META["learn_draws"])
LPOST = 0 if MODES else int(META["learn_post_draws"])
LPER = [] if MODES else [int(x) for x in META["learn_draws_per_chain"].split()]
RPER = [] if MODES else [int(x) for x in META["re_draws_per_chain"].split()]


# ============================================================================= formatting
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


def num(n):
    return f"{int(n):,}"


def code(s):
    return f"<code>{esc(s)}</code>"


def lc1(s):
    """Lower-case a leading capital for use mid-sentence (keeps RE, AR(1))."""
    return s[0].lower() + s[1:] if len(s) > 1 and s[0].isupper() and s[1].islower() else s


def plural(n, one, many):
    return one if n == 1 else many


def names_and(xs):
    xs = list(xs)
    return xs[0] if len(xs) == 1 else (", ".join(xs[:-1]) + " and " + xs[-1])


def clean(v, nd=5):
    try:
        x = float(v)
    except (TypeError, ValueError):
        return None
    if math.isnan(x) or math.isinf(x):
        return None
    return round(x, nd)


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


def qshift(q, k):
    y, n = int(q[:4]), int(q[-1]) - 1 + k
    return f"{y + n // 4}Q{n % 4 + 1}"


# ============================================================================= accessors
PV = {(r.name, r.source, r.stat): float(r.value) for r in par.itertuples()}
PTX = {(r.name, r.source, r.stat): (r.text if isinstance(r.text, str) else "") for r in par.itertuples()}
NAMES = list(dict.fromkeys(par.name))
LAB = dict(zip(par.name, par.label))
GRP = dict(zip(par.name, par.group))
STRUCT = [n for n in NAMES if GRP[n] != "learning"]
LEARNP = [n for n in NAMES if GRP[n] == "learning"]


def pv(n, src, st):
    return PV.get((n, src, st), NAN)


MD = {}
for _r in mdd.itertuples():
    MD[(_r.model, _r.method, None if pd.isna(_r.p) else round(float(_r.p), 2))] = float(_r.value)


def md(model, method, p=None):
    return MD[(model, method, p)]


def mrange(model, method):
    v = [x for (m, me, p), x in MD.items() if m == model and me == method and p is not None]
    return min(v), max(v)


DG = {}
for _r in dia.itertuples():
    DG[(_r.model, _r.chain, _r.parameter if isinstance(_r.parameter, str) else "", _r.metric)] = (
        float(_r.value), _r.text if isinstance(_r.text, str) else "")


def dg(model, chain, param, metric):
    return DG[(model, chain, param, metric)][0]


def dgt(model, chain, param, metric):
    return DG[(model, chain, param, metric)][1]


PH = {(r.date, r.variable, r.source, r.stat): float(r.value) for r in pth.itertuples()}
LP = {(r.date, r.series): float(r.value) for r in lpd.itertuples()}
IR = {(r.model, r.shock, r.variable, int(r.h)): float(r.value) for r in irf.itertuples()}
AP = {}
APS = {}
for _r in app.itertuples():
    AP[(_r.scenario, _r.variable, str(_r.date))] = float(_r.value)
    APS[(_r.scenario, _r.variable, str(_r.date))] = _r.stage
RM = {(r.model, r.variable, r.sample): (float(r.rmse), int(r.n)) for r in rms.itertuples()}
RMS_UNITS = dict(zip(rms.variable, rms.units))
A2 = {(r.variable, str(r.date), r.model, r.statistic): float(r.value) for r in ap2.itertuples()}
ASUM = {r.model: r for r in aps.itertuples()}
SENS = list(sns.itertuples())

QL = list(dict.fromkeys(lpd.date))                      # likelihood quarters, 1966Q1-2026Q2
FIRST, LAST = QL[0], QL[-1]
MISSING = [q for q in QL if LP[(q, "llt_re_mode")] == 0 and LP[(q, "llt_learn_mode")] == 0]
NANTXT = f"{MISSING[0]}-{MISSING[-1]}" if MISSING else ""
NOBS = len(QL) - len(MISSING)
MOVERS = META["movers"].split()

# ============================================================================= chart registry
ENT = {
    "data": dict(name="Data", short="Data", color="ink", width=2.2),
    "re": dict(name="RE estimate", short="RE", color="s1"),
    "learn": dict(name="Learning estimate", short="Learning", color="s2"),
    "calib": dict(name="Calibrated history (a1_learn)", short="Calibrated", color="s3"),
    "prior": dict(name="Prior", short="Prior", color="g0", style="dashed"),
}
CHARTS, LEGENDS = {}, {}
FIGN = [0]
ML = 46


def S(ent, v, **kw):
    d = dict(ENT[ent])
    d["v"] = v
    d.update(kw)
    return d


def fig_title(t):
    FIGN[0] += 1
    return f'<p class="fig"><span class="fn">Figure {FIGN[0]}.</span> {t}</p>'


def line(cid, group, title, cap, x, series, **kw):
    spec = dict(id=cid, group=group, title=title, x=x, series=series, origin=None, legend=False)
    spec.update(kw)
    CHARTS[cid] = spec
    return (f'<figure class="chart"><figcaption class="ct">{esc(title)}</figcaption>'
            f'<div class="plot" data-chart="{cid}"></div><p class="cap">{cap}</p></figure>')


def endw(series):
    if 2 <= len(series) <= 4:
        return round(min(92, max(len(s.get("short") or s["name"]) for s in series) * 6.2 + 14), 1)
    return 12


def stacked(gid, title_html, cap, panels, h=190, extra=None):
    """Charts on the same x-axis and margins, one below the other, in one figure."""
    mr = max(endw(s) for _, _, s, _ in panels)
    parts = []
    for k, (st, x, ser, kw) in enumerate(panels):
        cid = f"{gid}-{k}"
        spec = dict(id=cid, group=gid, title=st, x=x, series=ser, origin=None, legend=False, ml=ML, mr=mr, h=h, dec=3)
        if extra:
            spec.update(extra)
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


def html_table(hdr, rows, num_from=1, caption=None, cls=""):
    h = "".join(f"<th>{x if x.startswith('<') else x.replace('<', '&lt;').replace('>', '&gt;')}</th>" for x in hdr)
    body = []
    for r in rows:
        if isinstance(r, str):
            body.append(r)
            continue
        body.append("<tr>" + "".join(f'<td class="{"n" if k >= num_from else ""}">{c}</td>' for k, c in enumerate(r)) + "</tr>")
    cap = f"<caption>{caption}</caption>" if caption else ""
    return f'<div class="tw"><table class="{cls}">{cap}<thead><tr>{h}</tr></thead><tbody>{"".join(body)}</tbody></table></div>'


SEC = []


def section(sid, no, title, body):
    SEC.append((sid, no, title))
    return f'<section id="{sid}">\n<h2><span class="no">{no:02d}</span>{esc(title)}</h2>\n{body}\n</section>\n'


# ============================================================================= derived numbers
def fp(name, v):
    """A parameter value: 4 decimals for the gain, 3 otherwise."""
    return f(v, 4 if name == "gain" else 3)


lapR, lapL = md("re", "laplace"), md("learn", "laplace")
lapC, lapK = md("learn_current", "laplace"), md("learn_calib", "laplace")
BF, BF10 = md("learn_vs_re", "laplace_logbf"), md("learn_vs_re", "laplace_log10bf")
llR, llL = md("re", "log_likelihood_at_mode"), md("learn", "log_likelihood_at_mode")
lpR, lpL = md("re", "log_posterior_at_mode"), md("learn", "log_posterior_at_mode")
lpS, llS = md("swx1_new_conventions", "log_posterior_at_mode"), md("swx1_new_conventions", "log_likelihood_at_mode")
if not MODES:   # chain-based numbers (the modes tables have none)
    lapF, lapZ = md("learn_fixed_beliefs", "laplace_baseline_hessian"), md("learn_freeze", "laplace_baseline_hessian")
    MHR, MHL = mrange("re", "mhm"), mrange("learn", "mhm")
    BFM, BFM10 = mrange("learn_vs_re", "mhm_logbf"), mrange("learn_vs_re", "mhm_log10bf")
    RHAT_MAX, RHAT_PAR = dg("learn", "all", "", "rhat_max"), dgt("learn", "all", "", "rhat_max")
    ESS_MIN, ESS_PAR = dg("learn", "all", "", "ess_min"), dgt("learn", "all", "", "ess_min")
    NCH_L, NCH_R = int(dg("learn", "all", "", "chains")), int(dg("re", "all", "", "chains"))
    ACC_L = [dg("learn", f"chain_{k:02d}", "", "acceptance") for k in range(1, 7) if ("learn", f"chain_{k:02d}", "", "acceptance") in DG]
    ACC_R = [dg("re", f"chain_{k:02d}", "", "acceptance") for k in range(1, 5) if ("re", f"chain_{k:02d}", "", "acceptance") in DG]


def rule_pass(model, names):
    ok = [n for n in names if dg(model, "all", n, "rhat") < 1.1 and dg(model, "all", n, "ess_bulk") > 100]
    return ok


if not MODES:
    L_OK = rule_pass("learn", LEARNP)
    S_OK = rule_pass("learn", STRUCT)
    GO_INTERIM = len(L_OK) == len(LEARNP) and len(S_OK) >= 0.8 * len(STRUCT)
GONOGO = DG.get(("learn", "gonogo", "", "decision"))


def ident(n):
    """Posterior against prior for a learning parameter: shift and narrowing."""
    m, s = pv(n, "learn", "mean"), pv(n, "learn", "sd")
    pm, ps = pv(n, "prior", "mean"), pv(n, "prior", "sd")
    r = s / ps
    word = "well identified" if r < 0.5 else ("partly identified" if r < 0.8 else "weakly identified")
    return dict(m=m, s=s, pm=pm, ps=ps, r=r, shift=(m - pm) / ps, word=word, q05=pv(n, "learn", "q05"),
                q95=pv(n, "learn", "q95"), mode=pv(n, "learn", "mode"))


ID = {n: ident(n) for n in LEARNP}
PNAME = {"gain": "gain", "omega": "memory", "chi": "intensity of choice"}

# episodes (likelihood comparison): a partition of the sample; the shaded ones carry a label
EPIS = [("1966Q1", "1979Q2", "Great Inflation", True), ("1979Q3", "1983Q4", "Volcker disinflation", True),
        ("1984Q1", "2008Q3", "Great Moderation", False), ("2008Q4", "2015Q4", "2008-15 ELB", True),
        ("2016Q1", "2020Q4", "2016-20 (covid gap " + NANTXT + ")", False), ("2021Q1", "2022Q4", "2021-22 surge", True),
        ("2023Q1", LAST, "2023-26", False)]
EPROSE = {"Great Inflation": "the Great Inflation", "Volcker disinflation": "the Volcker disinflation",
          "Great Moderation": "the Great Moderation", "2008-15 ELB": "the 2008-15 ELB years",
          "2021-22 surge": "the 2021-22 surge"}
EPS, EPQ = {}, {}
for _a, _b, _n, _sh in EPIS:
    qs = qrange(_a, _b)
    EPS[_n] = sum(LP[(q, "llt_diff_mode")] for q in qs)
    EPQ[_n] = len([q for q in qs if q not in MISSING])


def ep(n):
    return EPROSE.get(n, n)
TOT_DIFF = LP[(LAST, "cum_diff_mode")]

# surge numbers (filter at the mode, posterior, calibrated, inversion of app 1)
ORIGIN = "2022Q2"
n2m = {q: PH.get((q, "n2", "mode", "value")) for q in qrange("2019Q4", "2023Q4")}
n2med = {q: PH.get((q, "n2", "post", "q50")) for q in qrange("2019Q4", "2023Q4")}
N2_O = dict(mode=PH[(ORIGIN, "n2", "mode", "value")], q50=PH.get((ORIGIN, "n2", "post", "q50"), NAN),
            q05=PH.get((ORIGIN, "n2", "post", "q05"), NAN), q95=PH.get((ORIGIN, "n2", "post", "q95"), NAN),
            cal=PH[(ORIGIN, "n2", "calibrated", "value")], inv=AP[("e1_learn", "n2", ORIGIN)],
            smo=AP[("e1_learn_smoothed", "n2", ORIGIN)])
N2_19 = dict(mode=PH[("2019Q4", "n2", "mode", "value")], cal=PH[("2019Q4", "n2", "calibrated", "value")],
             inv=AP[("e1_learn", "n2", "2019Q4")])
_sq = qrange("2020Q4", ORIGIN)
Q_LOW = min(_sq, key=lambda q: n2m[q])
N2_LOW = n2m[Q_LOW]
# first quarter where the inversion and the filter differ by more than 0.05 in n2
_inv = {q: AP.get(("e1_learn", "n2", q)) for q in qrange("2018Q1", ORIGIN)}
SPLIT_Q = next((q for q in qrange("2018Q1", ORIGIN) if _inv[q] is not None and abs(_inv[q] - PH[(q, "n2", "mode", "value")]) > 0.05),
               None)


def fcast_at(q, var):
    """Forecast of inflation for quarter q, made in q-1 (annualised level), at the mode."""
    return PH.get((qshift(q, -1), var, "mode", "value"))


_fq = qrange("2021Q1", ORIGIN)
FE_RE = math.sqrt(sum((PH[(q, "pinfobs", "data", "value")] - fcast_at(q, "fRE")) ** 2 for q in _fq) / len(_fq))
FE_BR = math.sqrt(sum((PH[(q, "pinfobs", "data", "value")] - fcast_at(q, "fBR")) ** 2 for q in _fq) / len(_fq))

SHORT = {"epinf": "the price mark-up shock sd", "cprobp": "price stickiness", "ctrend": "trend growth",
         "cmap": "the price mark-up MA term", "crhopinf": "price mark-up persistence", "crhow": "wage mark-up persistence",
         "cmaw": "the wage mark-up MA term", "cindp": "price indexation", "csigl": "the inverse Frisch elasticity",
         "chabb": "habit persistence", "crr": "interest-rate smoothing", "constepinf": "steady-state inflation"}
LRMK = {m: (pv("crhopinf", m, "mode") - pv("cmap", m, "mode")) / (1 - pv("crhopinf", m, "mode")) for m in ("re", "learn")}
SPLIT_F = qshift(SPLIT_Q, -1) if SPLIT_Q else None
FRE_SPLIT = dict(filt=PH.get((SPLIT_F, "fRE", "mode", "value")), inv=AP.get(("e1_learn", "fRE", SPLIT_F))) if SPLIT_Q else {}

# application 1
HZ = qrange("2022Q3", "2026Q2")
APP_SC = ["data", "a1_re", "a1_learn", "e1_re", "e1_learn_re", "e1_learn_smoothed", "e1_learn"]
APP_NM = {"data": "Data", "a1_re": "Calibrated, RE (a1_re)", "a1_learn": "Calibrated, learning (a1_learn)",
          "e1_re": "RE estimate (e1_re)", "e1_learn_re": "Learning estimate, every agent RE (e1_learn_re)",
          "e1_learn_smoothed": "Learning estimate, learning on, RE-smoother history (e1_learn_smoothed)",
          "e1_learn": "Learning estimate, learning on, inversion history (e1_learn)"}
VAR4 = ["pinfobs", "robs", "dy", "dc"]
VLAB = {"pinfobs": "Inflation", "robs": "Policy rate", "dy": "Output growth", "dc": "Consumption growth"}


def aavg(sc, v):
    xs = [AP.get((sc, v, q)) for q in HZ]
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return sum(xs) / len(xs) if len(xs) == len(HZ) else NAN


AV = {(sc, v): aavg(sc, v) for sc in APP_SC for v in VAR4}
DEC = dict(params=AV[("e1_learn_re", "pinfobs")] - AV[("e1_re", "pinfobs")],
           learning=AV[("e1_learn_smoothed", "pinfobs")] - AV[("e1_learn_re", "pinfobs")],
           history=AV[("e1_learn", "pinfobs")] - AV[("e1_learn_smoothed", "pinfobs")])

# application 1 consistent with the likelihood (est_06b_app1_post): filtered state at the origin, zero shocks
HZL = f"{HZ[0]}-{HZ[-1]}"
STATS4 = ("mode", "median", "p05", "p95")


def a2avg(var, model):
    return {s: A2.get((f"avg_{var}", HZL, model, s), NAN) for s in STATS4}


AVP = {(m, v): a2avg(v, m) for m in ("re", "learn") for v in VAR4}
APL, APR = AVP[("learn", "pinfobs")], AVP[("re", "pinfobs")]
N2P = {s: A2.get(("n2_origin", ORIGIN, "learn", s), NAN) for s in STATS4}
NPOST = {m: int(ASUM[m].n_draws) for m in ("re", "learn")}
NFAIL = {m: int(ASUM[m].n_failed) for m in ("re", "learn")}
CAL1 = dict(re=AV[("a1_re", "pinfobs")], learn=AV[("a1_learn", "pinfobs")])
SV = {r.variant: r for r in SENS}
SN2 = {r.variant: float(r.n2_2022Q2) for r in SENS}
SN2_LO, SN2_HI = min(SN2.values()), max(SN2.values())


def band(d, dec=2, unit="%"):
    return f"{f(d['p05'], dec)}{unit}-{f(d['p95'], dec)}{unit}"


# ============================================================================= sections
def banner():
    if not INTERIM and len(STATUSES) == 1:
        return ""
    mix = ""
    if len(STATUSES) > 1 or len(DRAWS_SET) > 1 or len(DSRC_SET) > 1:
        mix = (f" The tables come from more than one run (status {', '.join(STATUSES)}; learning draws "
               f"{', '.join(num(x) for x in DRAWS_SET)}; draws {', '.join(DSRC_SET)}); rerun "
               f"{code(chr(39).join(['est_06_post(', 'interim', ')']))} with all parts and "
               f"{code(chr(39).join(['est_06b_app1_post(', 'interim', ')']))}.")
    stg = "stage-2 " if DSRC == "stage2" else ""
    return (f'<aside class="banner" role="note"><p><b>Interim results ({num(LDRAWS)} learning draws).</b> The learning chains '
            f'are still running. This page uses the {NCH_L} {stg}chains as they stood on {CREATED} ({", ".join(num(x) for x in LPER)} '
            f'draws), drops {BURN_TXT} and pools {num(LPOST)} draws. They have not converged: the largest split '
            f'R-hat is {f(RHAT_MAX)} ({esc(RHAT_PAR)}) and the smallest bulk ESS {f(ESS_MIN, 0)}. Posterior means, bands and '
            f'the modified harmonic mean of the learning model will move. The modes, the Laplace values and everything '
            f'computed at the modes will not. Rebuild after {code("est_06_post(" + chr(39) + "final" + chr(39) + ")")} and '
            f'{code("est_06b_app1_post(" + chr(39) + "final" + chr(39) + ")")}.{mix}</p></aside>')


def where_text():
    """Summary item: where over the sample the likelihood gain of learning accrues (at the modes)."""
    top = sorted([e for e in EPIS], key=lambda e: -EPS[e[2]])
    pos = [e for e in top if EPS[e[2]] > 0]
    neg = [e for e in top if EPS[e[2]] < 0]
    bq = max(EPS, key=lambda n: EPS[n] / max(1, EPQ[n]))
    return (f"<b>The gain is spread over the sample and is largest per quarter in {esc(ep(bq))}.</b> Of the "
            f"{f(TOT_DIFF)} log points by which learning beats RE at the modes over {FIRST}-{LAST}, "
            f"{f(EPS[pos[0][2]])} accrue in {esc(ep(pos[0][2]))} ({pos[0][0]}-{pos[0][1]}, {EPQ[pos[0][2]]} quarters) and "
            f"{f(EPS[pos[1][2]])} in {esc(ep(pos[1][2]))} ({pos[1][0]}-{pos[1][1]}). Per quarter the gain is largest in "
            f"{esc(ep(bq))} ({f(EPS[bq] / EPQ[bq], 3, True)} a quarter over {EPQ[bq]} quarters)"
            + (f". Learning loses ground in {names_and([esc(ep(e[2])) + ' (' + f(EPS[e[2]], 2) + ')' for e in neg])}" if neg else "")
            + ".")


def sec_summary():
    il, ig, io = ID["chi"], ID["gain"], ID["omega"]
    fit = (f"<b>Learning fits better.</b> The Laplace log marginal data density is {f(lapL)} for the learning model and "
           f"{f(lapR)} under RE: a log Bayes factor of {f(BF)} ({f(BF10)} in log10"
           + ("; decisive on Jeffreys' scale, which starts at 2" if BF10 > 2 else "") + "). "
           f"The modified harmonic mean gives {f(BFM[0])} to {f(BFM[1])} ({f(BFM10[0])} to {f(BFM10[1])} in log10)"
           + (" on the interim draws" if INTERIM else "") + f". At the modes the log likelihood is {f(llL - llR)} higher, "
           f"for {len(LEARNP)} extra parameters.")
    where = where_text()
    well = ["the " + PNAME[n] for n in LEARNP if ID[n]["r"] < 0.5]
    weak = ["the " + PNAME[n] for n in LEARNP if ID[n]["r"] >= 0.8]
    head = ""
    if well:
        head += f"The data narrow {names_and(well)}"
    if weak:
        head += ("; " if head else "") + (f"{names_and(weak)} {plural(len(weak), 'is', 'are')} no better pinned down "
                                          f"than by the prior")
    idt = (f"<b>{head[0].upper() + head[1:]}.</b> Posterior means "
           f"(90% intervals): gain {fp('gain', ig['m'])} ({fp('gain', ig['q05'])}-{fp('gain', ig['q95'])}; prior mean "
           f"{fp('gain', ig['pm'])}), memory {f(io['m'], 3)} ({f(io['q05'], 3)}-{f(io['q95'], 3)}; prior {f(io['pm'], 3)}), "
           f"intensity {f(il['m'], 2)} ({f(il['q05'], 2)}-{f(il['q95'], 2)}; prior {f(il['pm'], 2)}, sd {f(il['ps'], 2)}). "
           f"Posterior sds relative to the prior's: gain {f(ig['r'], 2)}, memory {f(io['r'], 2)}, intensity {f(il['r'], 2)}"
           + (" (interim)" if INTERIM else "") + ". The gain's posterior mean moves towards IJCB's "
           f"{fp('gain', pv('gain', 'ijcb_survey', 'mean'))}. Without survey expectations IJCB "
           f"estimated {f(pv('chi', 'ijcb_nosurvey', 'mean'), 2)}; the toolbox calibration, "
           f"{f(pv('chi', 'calibration', 'value'), 2)}, is IJCB's estimate with survey data and lies "
           + ("below" if pv("chi", "calibration", "value") < il["q05"] else "inside") + " the 90% interval.")
    fl = [n for n in STRUCT if pv(n, "compare", "flag_mean_2sd") == 1]
    mv = MOVERS
    mvh = names_and([f"{SHORT.get(n, LAB[n])} {'up' if pv(n, 'learn', 'mode') > pv(n, 're', 'mode') else 'down'}" for n in mv])
    mvtxt = ", ".join(f"{code(n)} {fp(n, pv(n, 're', 'mode'))} to {fp(n, pv(n, 'learn', 'mode'))} "
                      f"({f(pv(n, 'compare', 'diff_mode_in_re_sd'), 1, True)} sd)" for n in mv)
    flt = ", ".join(code(n) for n in fl)
    lrR, lrL = LRMK["re"], LRMK["learn"]
    cp_dn = pv("cprobp", "learn", "mode") < pv("cprobp", "re", "mode")
    why = (f" One reading: beliefs and shares add inflation persistence of their own, so the model needs less of it from "
           f"price stickiness and the mark-up process. The cumulative response of the price mark-up to its own shock, "
           f"(crhopinf - cmap)/(1 - crhopinf), is {f(lrR, 1)} at the RE mode and {f(lrL, 1)} at the learning mode."
           if cp_dn and lrL < lrR and pv("epinf", "learn", "mode") > pv("epinf", "re", "mode") else "")
    struct = (f"<b>The largest moves: {mvh}.</b> Between the modes, in RE posterior sds: {mvtxt}. Between the posterior "
              f"means, {len(fl)} of {len(STRUCT)} parameters move by more than 2 RE posterior sds ({flt}"
              + ("; interim means" if INTERIM else "") + ")." + why)
    surge = (f"<b>In the estimated model the learners' share fell during the 2021-22 surge.</b> The end-of-quarter share was "
             f"{f(N2_19['mode'], 2)} at the end of 2019Q4 and {f(N2_O['mode'], 2)} at the end of {ORIGIN} (posterior median "
             f"{f(N2_O['q50'], 2)}, 90% band {f(N2_O['q05'], 2)}-{f(N2_O['q95'], 2)}), with a low of {f(N2_LOW, 2)} in "
             f"{Q_LOW}. The calibrated history has {f(N2_O['cal'], 2)} at {ORIGIN}. Over 2021Q1-{ORIGIN} the RE agents' "
             f"forecasts missed inflation by {f(FE_RE, 2)} pp (root mean square, annualised) and the learners' by "
             f"{f(FE_BR, 2)} pp. The share at the origin is fragile: at the same parameters it ends {ORIGIN} between "
             f"{f(SN2_LO, 2)} and {f(SN2_HI, 2)} depending on how the three quarters without data in {NANTXT} are bridged "
             f"(the engine's inversion history {f(SN2['inversion'], 2)}, its RE-smoothed history {f(SN2['re_smoother'], 2)}, "
             f"no updating in the gap {f(SN2['freeze'], 2)}, the 2020 data put back {f(SN2['covid_data'], 2)}). With an "
             f"intensity of choice of {f(pv('chi', 'learn', 'mode'), 1)}, the different 2020Q4 starting points and 2021 "
             f"forecast errors move the share a lot.")
    gap_p = APL["mode"] - APR["mode"]
    gap_c = CAL1["learn"] - CAL1["re"]
    app1 = (f"<b>Application 1 from the estimated models' own state: inflation averages {pct(APL['mode'])} with learning "
            f"and {pct(APR['mode'])} under RE.</b> The forecasts start from the likelihood's filtered state at {ORIGIN} and "
            f"run {HZL} with zero shocks as the engine's forecast stage does (gate G8). At the learning mode average inflation "
            f"is {pct(APL['mode'])} (posterior median {pct(APL['median'])}, 90% band {band(APL)}), at the RE mode "
            f"{pct(APR['mode'])} (median {pct(APR['median'])}, band {band(APR)}): {pp(gap_p)} at the modes, against "
            f"{pct(CAL1['learn'])} and {pct(CAL1['re'])} ({pp(gap_c)}) in the calibrated runs. The RE mode has a near "
            f"unit-root price mark-up ({code('crhopinf')} {f(pv('crhopinf', 're', 'mode'), 3)}; posterior mean "
            f"{f(pv('crhopinf', 're', 'mean'), 3)}). From the engine's inversion history instead of the filter the learning "
            f"mode gives {pct(AV[('e1_learn', 'pinfobs')])}.")
    cav = (("<b>Caveats.</b> The learning chains have not converged yet (largest R-hat "
            f"{f(RHAT_MAX)}, smallest ESS {f(ESS_MIN, 0)}). " if INTERIM else "<b>Caveats.</b> ")
           + "There are no survey expectations, so the intensity of choice rests on its prior. Neither model has an "
             "effective lower bound. The variants other than 'current' are evaluated at the baseline mode only.")
    items = [fit, where, idt, struct, surge, app1, cav]
    lis = "".join(f'<li class="ans"><span class="al">{k}</span><div><p>{t}</p></div></li>' for k, t in enumerate(items, 1))
    body = f"""{banner()}
<ol class="answers">{lis}</ol>"""
    return section("summary", 0, "Summary", body)


def setup_items():
    """Set-up bullets shared by both pages: data, models, priors and likelihood; and the lower bound."""
    ns = len(STRUCT)
    pr = {n: (PTX[(n, "prior", "mean")], pv(n, "prior", "mean"), pv(n, "prior", "sd")) for n in LEARNP}
    shp = {"gamma": "Gamma", "beta": "Beta", "normal": "Normal", "inv_gamma_1": "inverse Gamma"}
    ptxt = ", ".join(f"{PNAME[n]} {shp[pr[n][0]]}({fp(n, pr[n][1])}, {fp(n, pr[n][2])})" for n in LEARNP)
    common = f"""<li><b>Data.</b> The seven SW07 observables (output, consumption, investment and real wage growth, hours, GDP-deflator
inflation, the federal funds rate), {FIRST}-{LAST}: {len(QL)} quarters in the likelihood, {NOBS} with data. Every
observable is missing in {NANTXT} ({len(MISSING)} quarters). 1965 is a presample, filtered with the RE model in both
cases, so the two marginal likelihoods use the same data.</li>
<li><b>Models.</b> RE: SW07 with {ns} estimated parameters. Learning: the {code('a1_learn')} model of the main report.
Inflation expectations mix anchored RE agents and learners with an AR(1) perceived law of motion, updated by
constant-gain least squares with information up to t-1. The shares switch on past squared forecast errors (memory,
intensity of choice), start at 0.5, and the projection facility {code('plm_alm')} guards the beliefs and the model.
Initial beliefs are the RE moments at each parameter draw. {ns + len(LEARNP)} parameters.</li>
<li><b>Priors.</b> The SW07 parameters keep the priors and bounds of the Dynare run swX1. For the learning parameters,
IJCB App. C: {ptxt} (mean, sd). The prior is not renormalised for the bounds, as in Dynare.</li>
<li><b>Likelihood.</b> A Kalman filter on the actual law of motion, re-solved every quarter for the beliefs and
shares in force. Beliefs and shares are updated from the filtered estimates, so the likelihood is conditional on that
path. This is the likelihood of Slobodyan and Wouters (2012) and of IJCB App. D, without IJCB's regime switching.
Stochastic initialisation from the RE model's mean and covariance.</li>"""
    nolb = """<li><b>No lower bound.</b> Neither model has an effective lower bound on the policy rate; the rate is an observable at
its floor in 2009-15 and 2020-21.</li>"""
    return common, nolb


def toolbox_note():
    """Which toolbox the tables were computed against (post_meta.csv toolbox_root)."""
    root = META.get("toolbox_root", "")
    if "scratchpad" in root or root.rstrip("\\/").endswith("snap"):
        return ("The estimation runs against a frozen snapshot of the toolbox, so edits to the live toolbox cannot change\n"
                "a running chain. The same gates pass against the live toolbox (<a href=\"#diagnostics\">diagnostics</a>).")
    return ("The tables on this page were computed against the live toolbox (" + code(root) + "). The mode searches and "
            "the chains ran against a frozen snapshot of it, which was retired on 2026-10-20 after gates G3-G5 and the "
            "log likelihoods and log posteriors at all four modes matched against the live toolbox "
            "(<a href=\"#diagnostics\">diagnostics</a>).")


def sec_setup():
    common, nolb = setup_items()
    body = f"""<ul class="mech">
{common}
<li><b>Sampler.</b> Random-walk Metropolis-Hastings with the inverse Hessian at the mode as proposal. RE: {NCH_R}
chains of {", ".join(num(x) for x in sorted(set(RPER)))} draws, acceptance {f(min(ACC_R), 3)}-{f(max(ACC_R), 3)}.
{"Learning, stage 2: " if DSRC == "stage2" else "Learning: "}{NCH_L} chains, {", ".join(num(x) for x in LPER)} draws{"" if not INTERIM else " so far"}, acceptance {f(min(ACC_L), 3)}-{f(max(ACC_L), 3)}{
"; their proposal is the covariance of the stage-1 draws (six chains with the inverse Hessian as proposal), which count as adaptation" if DSRC == "stage2" else ""}.
Burn-in: {BURN_TXT} {"stage-2 " if DSRC == "stage2" else ""}chain{"" if DSRC == "stage2" else " (RE: the same)"}{"; RE: the first half" if DSRC == "stage2" else ""}. Marginal likelihood: Laplace at the mode and Geweke's modified harmonic mean
(MHM) with truncation p = 0.1 to 0.9.</li>
{nolb}
</ul>
<p class="small">{toolbox_note()}</p>"""
    return section("setup", 1, "Set-up in brief", body)


GROUPS = [("shocks", "Shocks"), ("frictions", "Frictions"), ("policy", "Monetary policy"),
          ("trends", "Trends, constants and the capital share"), ("learning", "Learning")]


def ci(n, src):
    return f"{fp(n, pv(n, src, 'mean'))} [{fp(n, pv(n, src, 'q05'))}, {fp(n, pv(n, src, 'q95'))}]"


def sec_params():
    shp = {"gamma": "G", "beta": "B", "normal": "N", "inv_gamma_1": "IG"}
    rows = []
    for g, gt in GROUPS:
        rows.append(f'<tr class="grp"><td colspan="11">{esc(gt)}</td></tr>')
        for n in [x for x in NAMES if GRP[x] == g]:
            sh = shp[PTX[(n, "prior", "mean")]]
            prior = f"{sh}({fp(n, pv(n, 'prior', 'mean'))}, {fp(n, pv(n, 'prior', 'sd'))})"
            isS = g != "learning"
            mv = ""
            if isS:
                dm, dmo = pv(n, "compare", "diff_mean_in_re_sd"), pv(n, "compare", "diff_mode_in_re_sd")
                mv = f"{f(dm, 2, True)} ({f(dmo, 2, True)})"
                if pv(n, "compare", "flag_mean_2sd") == 1:
                    mv += ' <span class="chip">&gt; 2 sd</span>'
            rows.append([
                f"{code(n)}<span class=\"lab\">{esc(LAB[n])}</span>", prior,
                fp(n, pv(n, "published_sw07", "mode")) if isS else "",
                fp(n, pv(n, "swx1", "mode")) if isS else "",
                fp(n, pv(n, "re", "mode")) if isS else "", ci(n, "re") if isS else "",
                fp(n, pv(n, "learn", "mode")), ci(n, "learn"),
                fp(n, pv(n, "learn_current", "mode")), fp(n, pv(n, "learn_calib", "mode")), mv])
    hdr = ["Parameter", "Prior", "SW07 1966-2004", "swX1 1966-2026", "RE mode", "RE mean [5%, 95%]", "Learning mode",
           "Learning mean [5%, 95%]", "'current' mode", "'calib' mode", "Learning minus RE"]
    tbl = html_table(hdr, rows, num_from=1, cls="par")
    lrows = []
    for n in LEARNP:
        lrows.append([f"{code(n)}<span class=\"lab\">{esc(LAB[n])}</span>",
                      f"{shp[PTX[(n, 'prior', 'mean')]]}({fp(n, pv(n, 'prior', 'mean'))}, {fp(n, pv(n, 'prior', 'sd'))})",
                      f"{fp(n, pv(n, 'ijcb_survey', 'mean'))} [{fp(n, pv(n, 'ijcb_survey', 'lo'))}, {fp(n, pv(n, 'ijcb_survey', 'hi'))}]",
                      f"{fp(n, pv(n, 'ijcb_nosurvey', 'mean'))} [{fp(n, pv(n, 'ijcb_nosurvey', 'lo'))}, {fp(n, pv(n, 'ijcb_nosurvey', 'hi'))}]",
                      fp(n, pv(n, "calibration", "value")),
                      f"{fp(n, pv(n, 'learn', 'mode'))} ({fp(n, pv(n, 'learn', 'sd_hessian'))})", ci(n, "learn"),
                      f"{fp(n, pv(n, 'learn_calib', 'mode'))} under {shp[PTX[(n, 'prior_calib', 'mean')]]}"
                      f"({fp(n, pv(n, 'prior_calib', 'mean'))}, {fp(n, pv(n, 'prior_calib', 'sd'))})"])
    ltbl = html_table(["Parameter", "Prior", "IJCB, with survey data", "IJCB, no expectations data", "Toolbox calibration",
                       "Mode (Hessian sd)", "Posterior mean [5%, 95%]", "'calib' mode under its prior"], lrows, cls="par")
    fl = [n for n in STRUCT if pv(n, "compare", "flag_mean_2sd") == 1]
    flm = [n for n in STRUCT if pv(n, "compare", "flag_mode_2sd") == 1]
    big = max(STRUCT, key=lambda n: abs(pv(n, "compare", "diff_mean_in_re_sd")))
    ans = (f"{len(fl)} of the {len(STRUCT)} SW07 parameters differ by more than 2 RE posterior sds between the posterior "
           f"means ({', '.join(code(n) for n in fl)}); between the modes {len(flm)} {plural(len(flm), 'does', 'do')} "
           f"({', '.join(code(n) for n in flm)}). "
           f"The largest is {code(big)} ({esc(LAB[big])}): {fp(big, pv(big, 're', 'mean'))} under RE and "
           f"{fp(big, pv(big, 'learn', 'mean'))} with learning, {f(pv(big, 'compare', 'diff_mean_in_re_sd'), 1, True)} sd.")
    swx = [n for n in STRUCT if abs(pv(n, "re", "mode") - pv(n, "swx1", "mode")) > 2 * pv(n, "re", "sd")]
    swx_s = len([n for n in swx if GRP[n] == "shocks"])
    body = f"""<p class="answer">{ans}</p>
<p>Columns: the published SW07 mode (1966-2004); swX1, the project's own Dynare re-estimation on 1966-2026 with the covid quarters kept
(the parameters of every scenario in the main report); the RE re-estimate here (covid quarters missing, stochastic
initialisation); the learning estimate; the modes of the two learning variants ('current' information, and priors
centred on the calibration). Prior: shape (B beta, G gamma, N normal, IG inverse gamma) with mean and sd. The last column
is the learning minus the RE posterior mean in RE posterior sds, with the same for the modes in brackets; the chip marks
moves of more than 2 sd{" (interim means: they will move)" if INTERIM else ""}. Under the new conventions the RE mode
differs from swX1 by more than 2 RE posterior sds in {len(swx)} parameters ({", ".join(code(n) for n in swx)}); {swx_s}
of them belong to the shock processes. Gate G7 below lists the largest moves.</p>
{tbl}
<h3 class="sub">The learning parameters against IJCB and the calibration</h3>
<p>IJCB intervals as printed in the paper. The 'calib' variant re-estimates the model with priors centred on the
calibration (last column).</p>
{ltbl}"""
    return section("params", 2, "Parameters: RE against learning", body)


def dens_chart(n, gid):
    d = ppl[ppl.param == n]
    xs = sorted(set(d[d.density == "prior"].x))
    X = [f"{v:.6g}" for v in xs]
    get = {k: dict(zip(g.x, g.value)) for k, g in d.groupby("density")}
    ser = [S("prior", [clean(get["prior"].get(v)) for v in xs])]
    if "re" in get:
        ser.append(S("re", [clean(get["re"].get(v)) for v in xs], name="RE posterior", short="RE"))
    ser.append(S("learn", [clean(get["learn"].get(v)) for v in xs], name="Learning posterior", short="Learning"))
    rules = []
    if n in LEARNP:
        c = pv(n, "calibration", "value")
        if xs[0] <= c <= xs[-1]:
            k = min(range(len(xs)), key=lambda i: abs(xs[i] - c))
            rules.append(dict(x=X[k], label="calibration"))
    if n in LEARNP:
        cap = (f"Prior mean {fp(n, pv(n, 'prior', 'mean'))}, sd {fp(n, pv(n, 'prior', 'sd'))}; posterior mean "
               f"{fp(n, pv(n, 'learn', 'mean'))}, sd {fp(n, pv(n, 'learn', 'sd'))}; mode {fp(n, pv(n, 'learn', 'mode'))}.")
    else:
        cap = (f"Posterior mean {fp(n, pv(n, 're', 'mean'))} (RE) and {fp(n, pv(n, 'learn', 'mean'))} (learning); modes "
               f"{fp(n, pv(n, 're', 'mode'))} and {fp(n, pv(n, 'learn', 'mode'))}.")
    mx = max(v for s in ser for v in s["v"] if v is not None)
    dec = 1 if mx >= 10 else (2 if mx >= 1 else 3)
    return line(f"pp-{n}", gid, f"{n}: {LAB[n]}", cap, X, ser, xnum=[xs[0], xs[-1]], xHead=n, dec=dec, h=180,
                yr=[0.048 * mx, mx], endLabels=False, rules=rules)


def sec_priorpost():
    ch = "".join(dens_chart(n, "pp") for n in LEARNP + MOVERS)
    il = ID
    parts = [f"{PNAME[n]} {f(il[n]['shift'], 1, True)} and {f(il[n]['r'], 2)}" for n in LEARNP]
    narrowed = ["the " + PNAME[n] for n in LEARNP if il[n]["r"] < 0.5]
    ans = ("Posterior mean minus prior mean, in prior sds, and posterior sd relative to the prior sd: "
           + "; ".join(parts) + "."
           + (f" Only {names_and(narrowed)} {plural(len(narrowed), 'is', 'are')} narrowed by the data." if narrowed else
              " None is narrowed much by the data.") + (" Interim draws." if INTERIM else ""))
    body = f"""<p class="answer">{ans}</p>
<p>Prior densities as used in the log posterior (not renormalised for the bounds). Posterior densities are Gaussian
kernel estimates on the pooled post burn-in draws{" (interim)" if INTERIM else ""}. The first three panels are the
learning parameters, with their calibrated values marked. The other four are the SW07 parameters whose modes differ
most between the two models, measured in RE posterior sds.</p>
{fig_title("Prior and posterior densities")}
{legend("pp", [leg("prior"), leg("re", name="RE posterior"), leg("learn", name="Learning posterior")])}
<div class="grid g-3">{ch}</div>
{tables("pp")}"""
    return section("priorpost", 3, "Prior against posterior", body)


def sec_mdd():
    rows = []
    mh = lambda m: f"{f(mrange(m, 'mhm')[0])} to {f(mrange(m, 'mhm')[1])}"
    rows.append(["RE (36 parameters)", f(lpR), f(llR), f(lapR), mh("re"), "0", "0"])
    rows.append(["Learning, 'lagged' (39; baseline)", f(lpL), f(llL), f(lapL), mh("learn"), f(BF, 2, True), f(BF10, 2, True)])
    rows.append(["Learning, 'current' information", f(md("learn_current", "log_posterior_at_mode")),
                 f(md("learn_current", "log_likelihood_at_mode")), f(lapC), "", f(lapC - lapR, 2, True), f((lapC - lapR) / math.log(10), 2, True)])
    rows.append(["Learning, priors centred on the calibration", f(md("learn_calib", "log_posterior_at_mode")),
                 f(md("learn_calib", "log_likelihood_at_mode")), f(lapK), "", "not comparable", ""])
    rows.append(["Learning, fixed initial beliefs (at the baseline mode)", f(md("learn_fixed_beliefs", "log_posterior_at_mode")),
                 f(md("learn_fixed_beliefs", "log_likelihood_at_mode")), f(lapF) + "*", "", f(lapF - lapR, 2, True) + "*", ""])
    rows.append(["Learning, 'freeze' in the covid gap (at the baseline mode)", f(md("learn_freeze", "log_posterior_at_mode")),
                 f(md("learn_freeze", "log_likelihood_at_mode")), f(lapZ) + "*", "", f(lapZ - lapR, 2, True) + "*", ""])
    rows.append(["swX1 mode under this likelihood", f(lpS), f(llS), "", "", "", ""])
    tbl = html_table(["Model", "Log posterior at the mode", "Log likelihood at the mode", "Laplace log MDD", "MHM log MDD (p = 0.1-0.9)",
                      "Log Bayes factor vs RE (Laplace)", "log10"], rows, cls="mdd")
    ev = dgt("learn", "mode", "", "mode_events_plm")
    evC = dgt("learn_current", "mode", "", "mode_events_plm")
    nS = int(dg("learn", "mode", "", "mode_starts"))
    nC = int(dg("learn_current", "mode", "", "mode_starts"))
    nK = int(dg("learn_calib", "mode", "", "mode_starts"))
    ans = (f"Learning beats RE by {f(BF)} log points on the Laplace approximation ({f(BF10)} in log10) and by {f(BFM[0])} to "
           f"{f(BFM[1])} on the modified harmonic mean (each model's MHM against the other's at the same p). The two "
           f"approximations agree on the sign. ")
    ans += (f"With 'current' information the learning model is no better than RE ({f(lapC - lapR, 2, True)}) and "
            f"{f(lapL - lapC)} log points worse than the baseline 'lagged' timing.")
    body = f"""<p class="answer">{ans}</p>
<p>Like is compared with like: Laplace with Laplace and MHM with MHM. The RE MHM (from {num(sum(RPER) // 2)} post burn-in
draws) is {f(MHR[0])} to {f(MHR[1])}, {f(MHR[0] - lapR, 1)} to {f(MHR[1] - lapR, 1)} above its Laplace value. The
learning MHM ({num(LPOST)} draws{", interim" if INTERIM else ""}) is {f(MHL[0])} to {f(MHL[1])}, {f(lapL - MHL[1], 1)} to
{f(lapL - MHL[0], 1)} below its Laplace value; {"with chains that have not converged the MHM is not reliable yet" if INTERIM
else "the gap reflects the non-Gaussian posterior of the learning parameters"}. The swX1 mode, the parameters of the main
report, has a log posterior {f(lpR - lpS)} below the RE re-estimate under these conventions.</p>
{tbl}
<p class="small">* Evaluated at the baseline learning mode, not re-optimised; the Laplace column uses the baseline
Hessian (an approximation). The variant with priors centred on the calibration has a different prior, so its marginal
likelihood is not a test of the model against the baseline. 'current' mode from {nC} starts, 'calib' from {nK}, baseline
from {nS} (all reaching the same mode). Projection-facility events at the modes: baseline {esc(ev)}; 'current' {esc(evC)};
no ALM reverts at any mode.</p>"""
    return section("mdd", 4, "Model comparison", body)


def sec_lpd():
    X = QL
    shades = [[a, b, n] for a, b, n, sh in EPIS if sh]
    cm = [clean(LP[(q, "cum_diff_mode")], 3) for q in X]
    q50 = [clean(LP[(q, "cum_diff_q50")], 3) for q in X]
    bands = [dict(name="Posterior 90% band", lo=[clean(LP[(q, "cum_diff_q05")], 3) for q in X],
                  hi=[clean(LP[(q, "cum_diff_q95")], 3) for q in X], color="s2", op=0.2)]
    ser = [S("learn", cm, name="At the modes", short="Modes"),
           S("learn", q50, name="Posterior median", short="Median", style="dashed")]
    cap = (f"Sum from {FIRST} of the log likelihood of the learning model minus that of RE, per quarter. At the modes it ends "
           f"at {f(TOT_DIFF)} in {LAST}; posterior median {f(LP[(LAST, 'cum_diff_q50')])}, 90% band "
           f"{f(LP[(LAST, 'cum_diff_q05')])} to {f(LP[(LAST, 'cum_diff_q95')])} ({META.get('lpd_learn_draws', '?')} learning "
           f"path draws paired with {META.get('lpd_re_draws', '?')} re-evaluated RE draws). Shaded: "
           + "; ".join(f"{n} {a}-{b}" for a, b, n in shades) + ".")
    ch = line("lpd-0", "lpd", "Cumulative log-likelihood difference, learning minus RE", cap, X, ser, bands=bands,
              shades=shades, zero=True, refs=[dict(y=0, label="")], dec=2, endLabels=False, h=260)
    rows = [[esc(n), f"{a}-{b}", str(EPQ[n]), f(EPS[n], 2, True), f(EPS[n] / max(1, EPQ[n]), 3, True)] for a, b, n, sh in EPIS]
    rows.append(["Total", f"{FIRST}-{LAST}", str(NOBS), f(TOT_DIFF, 2, True), f(TOT_DIFF / NOBS, 3, True)])
    tbl = html_table(["Episode", "Dates", "Quarters with data", "Sum of l_t differences at the modes", "Per quarter"], rows,
                     num_from=2)
    best = max(EPS, key=EPS.get)
    worst = min(EPS, key=EPS.get)
    ans = (f"Learning gains most in {esc(ep(best))} ({f(EPS[best], 2, True)} log points at the modes) and "
           + (f"loses most in {esc(ep(worst))} ({f(EPS[worst], 2, True)})." if EPS[worst] < 0 else
              f"gains least in {esc(ep(worst))} ({f(EPS[worst], 2, True)}).")
           + f" Over the posterior the total is {f(LP[(LAST, 'cum_diff_q50')], 2, True)} (median), with a 90% band of "
             f"{f(LP[(LAST, 'cum_diff_q05')], 2, True)} to {f(LP[(LAST, 'cum_diff_q95')], 2, True)}"
           + (" (interim)." if INTERIM else "."))
    body = f"""<p class="answer">{ans}</p>
{fig_title("Where the fit differs: cumulative log-likelihood difference, learning minus RE")}
{legend("lpd", [leg("learn", name="At the modes"), leg("learn", name="Posterior median", style="dashed"),
               dict(name="Posterior 90% band", color="s2", kind="band", op=0.25), dict(name="Episode", color="axis", kind="band", op=0.6)])}
<div class="grid g-1w">{ch}</div>
{tables("lpd")}
{tbl}"""
    return section("fit", 5, "Where the fit differs", body)


SAMPLES = ["1966Q1-2026Q2", "1966Q1-1983Q4", "1984Q1-2007Q4", "2008Q1-2019Q4", "2020Q4-2026Q2"]
OBS7 = ["dy", "dc", "dinve", "dw", "labobs", "pinfobs", "robs"]
OLAB = {"dy": "Output growth", "dc": "Consumption growth", "dinve": "Investment growth", "dw": "Real wage growth",
        "labobs": "Hours", "pinfobs": "Inflation", "robs": "Policy rate"}


def sec_rmse():
    ch = []
    ratios = {}
    for s in SAMPLES:
        v = [clean(RM[("learn", o, s)][0] / RM[("re", o, s)][0], 4) for o in OBS7]
        for o, x in zip(OBS7, v):
            ratios[(o, s)] = x
        spec = dict(id=f"rm-{s}", group="rm", title=s, type="dots", cats=[OLAB[o] for o in OBS7], x=[OLAB[o] for o in OBS7],
                    series=[dict(name="Learning RMSE / RE RMSE", color="s2", v=v)], ref=1, refColor="s1", refLabel="RE = 1",
                    dec=3, catHead="Observable")
        CHARTS[spec["id"]] = spec
        n = RM[("re", "pinfobs", s)][1]
        ch.append(f'<figure class="chart"><figcaption class="ct">{esc(s)} ({n} quarters)</figcaption>'
                  f'<div class="plot" data-chart="{spec["id"]}"></div></figure>')
    full = {o: ratios[(o, SAMPLES[0])] for o in OBS7}
    lo, hi = min(full.values()), max(full.values())
    bestS = min(SAMPLES[1:], key=lambda s: ratios[("pinfobs", s)])
    worstS = max(SAMPLES[1:], key=lambda s: ratios[("pinfobs", s)])
    ans = (f"The one-step-ahead errors barely differ. Over the full sample the learning model's RMSE is {f(lo, 3)} to "
           f"{f(hi, 3)} times RE's across the seven observables. For inflation the ratio is {f(full['pinfobs'], 3)}: "
           f"{f(ratios[('pinfobs', bestS)], 3)} in {bestS} and {f(ratios[('pinfobs', worstS)], 3)} in {worstS}.")
    rows = []
    for o in OBS7:
        rows.append([OLAB[o]] + [f"{f(RM[('re', o, s)][0], 3)} / {f(RM[('learn', o, s)][0], 3)}" for s in SAMPLES])
    tbl = html_table(["Observable (RE / learning)"] + SAMPLES, rows, num_from=1)
    body = f"""<p class="answer">{ans}</p>
<p>Root mean squared one-step-ahead prediction errors of the two Kalman filters at the modes, in report units (growth
rates, inflation and the rate in % annualised; hours 100 x log). Each panel is one subsample; a dot below 1 means the
learning model predicts that observable better.</p>
{fig_title("One-step-ahead RMSE, learning relative to RE")}
<div class="grid g-3">{"".join(ch)}</div>
<details class="tables"><summary>Table view: RMSE levels</summary>{tbl}</details>"""
    return section("rmse", 6, "One-step-ahead forecast errors", body)


QF = qrange("1966Q1", LAST)
PMEAN_TICKS = [-5, 0, 5, 10, 15, 20]       # perceived-mean panels: the axis runs exactly from -5% to 20%


def pser(var, src, stat, X, scale=1.0):
    return [None if (q, var, src, stat) not in PH else clean(PH[(q, var, src, stat)] * scale, 4) for q in X]


def path_panel(var, X, yr=None, inv=False, smo=False):
    ser = [S("learn", pser(var, "mode", "value", X), name="Learning, at the mode", short="Mode"),
           S("learn", pser(var, "post", "q50", X), name="Learning, posterior median", short="Median", style="dashed")]
    if any(v is not None for v in pser(var, "calibrated", "value", X)):
        ser.append(S("calib", pser(var, "calibrated", "value", X), name="Calibrated history (a1_learn)", short="Calibrated"))
    if inv:
        ser.append(S("learn", [clean(AP.get(("e1_learn", var, q)), 4) for q in X], name="Engine inversion history at the mode",
                     short="Inversion", style="dotted"))
    if smo:
        ser.append(S("learn", [clean(AP.get(("e1_learn_smoothed", var, q)), 4) for q in X],
                     name="Engine RE-smoothed history at the mode", short="Smoother", style="dashdot"))
    bands = [dict(name="Posterior 90% band", lo=pser(var, "post", "q05", X), hi=pser(var, "post", "q95", X), color="s2", op=0.2)]
    kw = dict(bands=bands)
    if yr:
        kw["yr"] = yr
    return ser, kw


def sec_paths():
    shades = [[a, b, n] for a, b, n, sh in EPIS if sh]
    s1, k1 = path_panel("n2", QF)
    s2, k2 = path_panel("beta", QF)
    s3, k3 = path_panel("pmean", QF)
    k3["yticks"] = PMEAN_TICKS
    for k in (k1, k2, k3):
        k["shades"] = shades
    k1["refs"] = [dict(y=0.5, label="")]
    k1["yfix"] = True
    cap = (f"Learning: filtered paths of the estimation at the mode, and the posterior median and 90% band of the stored "
           f"paths ({META.get('paths_post_draws', '?')} draws). Calibrated: the engine's history of {code('a1_learn')} "
           f"(swX1 parameters, gain 0.0585, memory 0.6, intensity 0.51, RE-smoothed history). The perceived mean is "
           f"4 (alpha / (1 - beta) + steady-state inflation), % annualised; the axis is cut at {PMEAN_TICKS[0]}% and "
           f"{PMEAN_TICKS[-1]}%.")
    fig = stacked("pa", "Learners' share and beliefs, " + f"{QF[0]}-{QF[-1]}", cap,
                  [("End-of-quarter share of learners (n2)", QF, s1, k1),
                   ("Perceived persistence of inflation (beta)", QF, s2, k2),
                   ("Perceived mean inflation, % annualised", QF, s3, k3)], h=170)
    n2 = {q: PH[(q, "n2", "mode", "value")] for q in QF if (q, "n2", "mode", "value") in PH}
    avg = sum(n2.values()) / len(n2)
    cal = {q: PH[(q, "n2", "calibrated", "value")] for q in QF if (q, "n2", "calibrated", "value") in PH}
    cavg = sum(cal.values()) / len(cal)
    qmin, qmax = min(n2, key=n2.get), max(n2, key=n2.get)
    sd_m = (sum((v - avg) ** 2 for v in n2.values()) / len(n2)) ** 0.5
    sd_c = (sum((v - cavg) ** 2 for v in cal.values()) / len(cal)) ** 0.5
    b22 = PH[(ORIGIN, "beta", "mode", "value")]
    bc22 = PH[(ORIGIN, "beta", "calibrated", "value")]
    ans = (f"With the estimated intensity of choice the share of learners swings far more than in the calibrated history. "
           f"At the mode it averages {f(avg, 2)} over {QF[0]}-{QF[-1]} with a standard deviation of {f(sd_m, 2)}, between "
           f"{f(n2[qmin], 2)} ({qmin}) and {f(n2[qmax], 2)} ({qmax}); the calibrated history averages {f(cavg, 2)} with a "
           f"standard deviation of {f(sd_c, 3)}. The perceived persistence follows the data in both: at {ORIGIN} it is "
           f"{f(b22, 3)} at the mode and {f(bc22, 3)} in the calibrated history.")
    body = f"""<p class="answer">{ans}</p>
{fig_title("Learners' share, perceived persistence and perceived mean, " + f"{QF[0]}-{QF[-1]}")}
{legend("pa", [leg("learn", name="Learning, at the mode"), leg("learn", name="Learning, posterior median", style="dashed"),
              dict(name="Posterior 90% band", color="s2", kind="band", op=0.25), leg("calib")])}
<div class="grid g-1w">{fig}</div>
{tables("pa")}"""
    return section("paths", 7, "Learners' share and beliefs, 1966-2026", body)


def sec_surge():
    X = qrange("2019Q4", "2023Q4")
    data = [clean(PH.get((q, "pinfobs", "data", "value")), 3) for q in X]

    def fx(var, src, stat):
        return [clean(PH.get((qshift(q, -1), var, src, stat)), 3) for q in X]

    ser = [S("data", data, name="Inflation (data)"),
           S("re", fx("fRE", "mode", "value"), name="RE agents' forecast (mode)", short="RE agents"),
           S("learn", fx("fBR", "mode", "value"), name="Learners' forecast (mode)", short="Learners")]
    bands = [dict(name="RE agents, posterior 90%", lo=fx("fRE", "post", "q05"), hi=fx("fRE", "post", "q95"), color="s1", op=0.16),
             dict(name="Learners, posterior 90%", lo=fx("fBR", "post", "q05"), hi=fx("fBR", "post", "q95"), color="s2", op=0.16)]
    s2, k2 = path_panel("n2", X, inv=True, smo=True)
    k2.update(dict(refs=[dict(y=0.5, label="")], yfix=True))
    cap = (f"Top: inflation and the two groups' forecasts of it, plotted at the quarter they forecast (made one quarter "
           f"earlier), % annualised; bands from {META.get('paths_fx_draws', '?')} re-evaluated posterior draws. Bottom: the "
           f"end-of-quarter share of learners from the estimation filter (mode, posterior median and band; application 1 "
           f"starts from it), the calibrated history, and the engine's inversion and RE-smoothed histories at the learning "
           f"mode (the sensitivity runs of application 1). The covid quarters {NANTXT} have no data.")
    fig = stacked("su", f"The 2021-22 surge, {X[0]}-{X[-1]}", cap,
                  [("Inflation and its forecasts, % annualised", X, ser, dict(bands=bands, h=230, dec=2)),
                   ("End-of-quarter share of learners (n2)", X, s2, dict(k2, h=150))], h=170)
    ans = (f"The estimated share fell while inflation rose: {f(n2m['2020Q4'], 2)} at the end of 2020Q4, {f(N2_LOW, 2)} in "
           f"{Q_LOW} and {f(N2_O['mode'], 2)} at the end of {ORIGIN} (mode). The RE agents' forecasts tracked the rise better "
           f"({f(FE_RE, 2)} pp RMS error over 2021Q1-{ORIGIN} against {f(FE_BR, 2)} pp for the learners), and with an "
           f"intensity of choice of {f(pv('chi', 'learn', 'mode'), 2)} the shares respond strongly to that difference.")
    split, frag, stbl = surge_blocks()
    body = f"""<p class="answer">{ans}</p>
{split}
{fig_title(f"The surge close-up, {X[0]}-{X[-1]}")}
{legend("su", [leg("data", name="Inflation (data)"), leg("re", name="RE agents' forecast"), leg("learn", name="Learners' forecast / share at the mode"),
              leg("learn", name="Share, posterior median", style="dashed"), leg("calib"),
              leg("learn", name="Share, engine inversion history", style="dotted"),
              leg("learn", name="Share, engine RE-smoothed history", style="dashdot")])}
<div class="grid g-1w">{fig}</div>
{tables("su")}
{frag}
{stbl}"""
    return section("surge", 8, "The 2021-22 surge", body)


def surge_blocks():
    """The surge section's mode-based blocks (both pages): the inversion split, the fragility paragraph and the
    share-sensitivity table (est_06b_app1_post part sens)."""
    split = ""
    if SPLIT_Q:
        split = (f"<p>The engine's inversion history gives a different share after the covid gap: "
                 f"{f(_inv[SPLIT_Q], 2)} at the end of {SPLIT_Q} against {f(PH[(SPLIT_Q, 'n2', 'mode', 'value')], 2)} in the "
                 f"filter, and {f(N2_O['inv'], 2)} against {f(N2_O['mode'], 2)} at {ORIGIN}. The two shares agree to within "
                 f"{f(max(abs(_inv[q] - PH[(q, 'n2', 'mode', 'value')]) for q in qrange('2018Q1', SPLIT_F)), 3)} up to "
                 f"{SPLIT_F}, the first quarter with data after the gap. In that quarter the RE agents' forecast of the next "
                 f"quarter's inflation is {pct(FRE_SPLIT['filt'])} in the filter and {pct(FRE_SPLIT['inv'])} in the "
                 f"inversion. After three quarters without data the filter spreads the {SPLIT_F} surprise over its uncertain "
                 f"state estimate, while the inversion backs out every shock in that one quarter. The forecast errors of "
                 f"{SPLIT_Q}, and with them the shares, then differ. Learning on the RE-smoothed history, which also "
                 f"spreads the surprise, gives {f(N2_O['smo'], 2)} at {ORIGIN}, close to the filter's "
                 f"{f(N2_O['mode'], 2)}. The likelihood uses the filter's path, and application 1 starts from it.</p>")
    # share sensitivity at the learning mode (est_06b_app1_post part sens)
    order = ["filter", "inversion", "re_smoother", "freeze", "covid_data"]
    srows = []
    whys = []
    for k in [k for k in order if k in SV] + [k for k in SV if k not in order]:
        r = SV[k]
        srows.append([esc(r.label), f(r.n2_2021Q2, 3), f(r.n2_2021Q4, 3), f(r.n2_2022Q2, 3), pct(r.fRE_made_2020Q4),
                      pct(r.avg_inflation_2022Q3_2026Q2)])
        whys.append(f"<li><b>{esc(r.label)}.</b> {esc(r.why)}</li>")
    stbl = (html_table(["History at the learning mode", "n2 2021Q2", "n2 2021Q4", f"n2 {ORIGIN}", "RE forecast made in 2020Q4",
                        f"Inflation {HZL}"], srows, num_from=1, cls="sens",
                       caption=("Learners' end-of-quarter share under five histories at the same parameters (the learning "
                                "mode); the RE agents' forecast made in 2020Q4 and the average inflation of the forecast "
                                "from each history, % annualised"))
            + f'<p class="small"><b>Why they differ</b></p><ul class="cav small">{"".join(whys)}</ul>')
    act = [r for r in SENS if r.variant != "covid_data"]
    frag = (f"<p><b>Why the share at the origin is fragile.</b> In {NANTXT} there are no observations, so the filter, the "
            f"engine's inversion and the RE smoother each attribute the 2020Q4 catch-up differently, and the RE agents' "
            f"forecast made in 2020Q4 ranges from {pct(min(r.fRE_made_2020Q4 for r in SENS))} to "
            f"{pct(max(r.fRE_made_2020Q4 for r in SENS))} across the five histories. The shares then follow the squared "
            f"forecast errors of 2021-22, and with an intensity of choice of {f(pv('chi', 'learn', 'mode'), 1)} at the mode "
            f"(the calibration has {f(pv('chi', 'calibration', 'value'), 2)}) small differences in those errors become large "
            f"differences in the share: at {ORIGIN} it lies between {f(SN2_LO, 2)} and {f(SN2_HI, 2)}. With the data as "
            f"they are, the forecast's average inflation stays between {pct(min(r.avg_inflation_2022Q3_2026Q2 for r in act))} "
            f"and {pct(max(r.avg_inflation_2022Q3_2026Q2 for r in act))} across the four histories"
            + (f"; with the 2020 data put back it is {pct(SV['covid_data'].avg_inflation_2022Q3_2026Q2)}, because the filtered "
               f"state at the origin changes as well" if "covid_data" in SV else "") + ".</p>")
    return split, frag, stbl


def sec_irfs():
    H = list(range(0, 21))
    X = [str(h) for h in H]
    models = [("re", "RE estimate", "s1", "solid"), ("learn_all_re", "Learning estimate, every agent RE", "s3", "solid"),
              ("learn_2019Q4", "Learning ALM, beliefs and shares of 2019Q4", "s2", "dashed"),
              ("learn_2022Q2", "Learning ALM, beliefs and shares of 2022Q2", "s2", "solid")]
    vars_ = [("pinfobs", "Inflation"), ("dy", "Output growth"), ("robs", "Policy rate")]
    shocks = [("em", "monetary policy shock"), ("epinf", "price mark-up shock")]
    ch = []
    for sh, shn in shocks:
        for v, vn in vars_:
            ser = [dict(name=nm, short=nm.split(",")[0], color=col, style=sty,
                        v=[clean(IR.get((m, sh, v, h)), 4) for h in H]) for m, nm, col, sty in models]
            pk = {m: max(H, key=lambda h: abs(IR[(m, sh, v, h)])) for m, *_ in models}
            short = {"re": "RE", "learn_all_re": "learning, all RE", "learn_2019Q4": "2019Q4 beliefs",
                     "learn_2022Q2": "2022Q2 beliefs"}
            cap = ("Largest response: " + "; ".join(f"{short[m]} {f(IR[(m, sh, v, pk[m])], 2, True)} (h = {pk[m]})"
                                                    for m, *_ in models) + ".")
            ch.append(line(f"ir-{sh}-{v}", "ir", f"{vn}, one-sd {shn}", cap, X, ser, xcat=True, xpre="h = ", xHead="Horizon",
                           dec=3, h=180, zero=True, refs=[dict(y=0, label="")], endLabels=False))
    st = {m: (IR[(m, "setting", "n2_model", 0)], IR.get((m, "setting", "beta", 0))) for m, *_ in models}
    pk_p = {m: IR[(m, "epinf", "pinfobs", 0)] for m, *_ in models}
    s4 = lambda m: sum(IR[(m, "epinf", "pinfobs", h)] for h in range(0, 8)) / 8
    ans = (f"With the beliefs and shares of 2022Q2 (learners' share in force {f(st['learn_2022Q2'][0], 2)}, perceived "
           f"persistence {f(st['learn_2022Q2'][1], 3)}), a one-sd price mark-up shock moves inflation by "
           f"{f(pk_p['learn_2022Q2'], 2, True)} pp on impact and {f(s4('learn_2022Q2'), 2, True)} pp a quarter on average over "
           f"two years; with those of 2019Q4 (share {f(st['learn_2019Q4'][0], 2)}, persistence {f(st['learn_2019Q4'][1], 3)}) "
           f"{f(pk_p['learn_2019Q4'], 2, True)} and {f(s4('learn_2019Q4'), 2, True)}; at the RE estimate "
           f"{f(pk_p['re'], 2, True)} and {f(s4('re'), 2, True)}. Part of the difference is the size of the shock: one sd "
           f"of {code('epinf')} is {f(IR[('learn', 'setting', 'sd_epinf', 0)], 3)} in the learning estimate and "
           f"{f(IR[('re', 'setting', 'sd_epinf', 0)], 3)} in the RE estimate.")
    sd = (f"One sd: {code('em')} {f(IR[('re', 'setting', 'sd_em', 0)], 3)} (RE) and {f(IR[('learn', 'setting', 'sd_em', 0)], 3)} "
          f"(learning); {code('epinf')} {f(IR[('re', 'setting', 'sd_epinf', 0)], 3)} and {f(IR[('learn', 'setting', 'sd_epinf', 0)], 3)}.")
    body = f"""<p class="answer">{ans}</p>
<p>Impulse responses at the modes, in percentage points, annualised (inflation, the rate and output growth, all as
deviations from the steady state). The learning lines use the actual law of motion with the beliefs and model shares in
force in that quarter, held fixed over the horizon: no learning and no switching after the shock. {sd}</p>
{fig_title("Impulse responses at the modes")}
{legend("ir", [dict(name=nm, color=col, style=sty) for _, nm, col, sty in models])}
<div class="grid g-3">{"".join(ch)}</div>
{tables("ir")}"""
    return section("irfs", 9, "Impulse responses at the modes", body)


Q18 = qrange("2018Q1", "2026Q2")


def sec_app1():
    X = Q18

    def a2s(var, model, stat):
        return [clean(A2.get((var, q, model, stat)), 4) for q in X]

    # ---- primary: the likelihood-consistent forecasts with posterior bands (est_06b_app1_post)
    def var_panel(v):
        # data last, so it is drawn on top of the model lines (which equal it wherever there are data)
        ser = [S("re", a2s(v, "re", "mode"), name="RE estimate, at the mode", short="RE"),
               S("learn", a2s(v, "learn", "mode"), name="Learning estimate, at the mode", short="Learning"),
               S("data", a2s(v, "data", "value"), name=f"{VLAB[v]} (data)", short="Data")]
        bands = [dict(name="RE, posterior 90%", lo=a2s(v, "re", "p05"), hi=a2s(v, "re", "p95"), color="s1", op=0.16),
                 dict(name="Learning, posterior 90%", lo=a2s(v, "learn", "p05"), hi=a2s(v, "learn", "p95"), color="s2", op=0.18)]
        return ser, bands

    si, bi = var_panel("pinfobs")
    sh = [S("learn", a2s("n2", "learn", "mode"), name="Learners' share, at the mode", short="Mode"),
          S("learn", a2s("n2", "learn", "median"), name="Learners' share, posterior median", short="Median", style="dashed")]
    bh = [dict(name="Posterior 90%", lo=a2s("n2", "learn", "p05"), hi=a2s("n2", "learn", "p95"), color="s2", op=0.2)]
    cap = (f"Top: inflation (data) and the forecasts from the {ORIGIN} origin, {HZL}, at the two modes, with the 90% band over "
           f"{NPOST['re']} RE and {NPOST['learn']} learning posterior draws{' (interim)' if INTERIM else ''}; % annualised. "
           f"Up to {ORIGIN} the model lines are each filter's estimate of the observables: equal to the data where there are "
           f"data, the filter's prediction in {NANTXT}. Bottom: the learners' share at the end of each quarter, from the "
           f"likelihood's filter up to {ORIGIN} and from the forecast after it. The shaded area is the forecast.")
    fig = stacked("a1p", f"Application 1 from the estimated models' own state, {X[0]}-{X[-1]}", cap,
                  [("Inflation, % annualised", X, si, dict(bands=bi, origin=ORIGIN, h=240, dec=2)),
                   ("Learners' share at the end of the quarter (n2)", X, sh,
                    dict(bands=bh, origin=ORIGIN, h=150, refs=[dict(y=0.5, label="")], yfix=True))], h=170)
    others = []
    for v in ("robs", "dy", "dc"):
        s_, b_ = var_panel(v)
        a = AVP[("learn", v)]
        r = AVP[("re", v)]
        cp = (f"Average {HZL}: learning {pct(a['mode'])} at the mode (median {pct(a['median'])}, 90% {band(a)}); RE "
              f"{pct(r['mode'])} (median {pct(r['median'])}, 90% {band(r)}).")
        others.append(line(f"a1p-{v}", "a1q", f"{VLAB[v]}, % annualised", cp, X, s_, bands=b_, origin=ORIGIN, dec=2,
                           endLabels=False, h=200))
    rows = []
    for v in VAR4:
        a, r = AVP[("learn", v)], AVP[("re", v)]
        rows.append([VLAB[v], pct(r["mode"]), f"{pct(r['median'])} [{band(r)}]", pct(a["mode"]),
                     f"{pct(a['median'])} [{band(a)}]", pct(AV[("a1_re", v)]), pct(AV[("a1_learn", v)])])
    tbl = html_table(["Average " + HZL, "RE mode", "RE median [90%]", "Learning mode", "Learning median [90%]",
                      "Calibrated RE (a1_re)", "Calibrated learning (a1_learn)"], rows, num_from=1,
                     caption=f"Averages over {HZL}, % annualised; posterior from {NPOST['re']} RE and {NPOST['learn']} learning "
                             f"draws{' (interim)' if INTERIM else ''}")
    gap = APL["mode"] - APR["mode"]
    crp = pv("crhopinf", "re", "mode")
    ans = (f"Started from what each estimated model says about {ORIGIN}, average inflation over {HZL} is "
           f"{pct(APL['mode'])} at the learning mode (posterior median {pct(APL['median'])}, 90% band {band(APL)}) and "
           f"{pct(APR['mode'])} at the RE mode (median {pct(APR['median'])}, band {band(APR)}), a gap of {pp(gap)} at the modes. The "
           f"calibrated runs of the main report give {pct(CAL1['learn'])} and {pct(CAL1['re'])}. The learners' share at "
           f"the origin is {f(N2P['mode'], 2)} at the mode (median {f(N2P['median'], 2)}, band {f(N2P['p05'], 2)}-"
           f"{f(N2P['p95'], 2)}); in the calibrated history it is {f(N2_O['cal'], 2)}.")
    why = (f"<p>Both forecasts start from the likelihood's own filtered state at {ORIGIN} (data after {ORIGIN} play no part) "
           f"and run 16 quarters with zero shocks: each quarter the actual law of motion in force (beliefs and model shares "
           f"from the end of the previous quarter), the RE and learners' forecasts, errors, fitness and shares from the "
           f"simulated inflation, the constant-gain update and the projection facility, as in the engine's forecast "
           f"stage (gate G8: {code('hlest.forecast_learn')} and {code('hlest.forecast_re')} reproduce the engine's forecast to "
           f"2e-12 from the same origin state)."
           + ((f" The RE path is the higher one at the modes: the RE estimate's price mark-up is close to a unit root at "
               f"the mode ({code('crhopinf')} {f(crp, 3)}, posterior mean {f(pv('crhopinf', 're', 'mean'), 3)})"
               + (f", so the posterior median ({pct(APR['median'])}) is below the mode's path and the RE band is "
                  f"{f(APR['p95'] - APR['p05'], 2)} pp wide" if APR["median"] < APR["mode"] else "")
               + ".") if APR["mode"] > APL["mode"] else "")
           + ((f" At the learning mode the price mark-up is less persistent ({code('crhopinf')} "
               f"{f(pv('crhopinf', 'learn', 'mode'), 3)}) and part of the persistence comes from the beliefs, whose "
               f"perceived persistence at the end of {ORIGIN} is {f(PH[(ORIGIN, 'beta', 'mode', 'value')], 3)}.")
              if pv("crhopinf", "learn", "mode") < crp else "")
           + "</p>")
    sens = app1_engine_sens()
    body = f"""<p class="answer">{ans}</p>
{why}
{fig_title(f"Application 1 consistent with the likelihood, {X[0]}-{X[-1]}. The shaded area is the forecast")}
{legend("a1p", [leg("data", name="Data"), leg("re", name="RE estimate, at the mode"), leg("learn", name="Learning estimate, at the mode"),
               dict(name="RE, posterior 90%", color="s1", kind="band", op=0.25), dict(name="Learning, posterior 90%", color="s2", kind="band", op=0.25),
               leg("learn", name="Learners' share, posterior median", style="dashed")])}
<div class="grid g-1w">{fig}</div>
<div class="grid g-3">{"".join(others)}</div>
{tables("a1p")}
{tables("a1q", "Table view: policy rate, output and consumption growth")}
{tbl}
{sens}"""
    return section("app1", 10, "Application 1 at the estimates", body)


def app1_engine_sens():
    """Application 1 sensitivity (both pages): the engine-based runs at the modes (est_06_post part app1)."""
    erows = [[esc(APP_NM[sc])] + [pct(AV[(sc, v)]) for v in VAR4] for sc in APP_SC if sc != "data"]
    etbl = html_table(["Engine run", "Inflation", "Policy rate", "Output growth", "Consumption growth"], erows,
                      num_from=1, caption=f"Averages {HZL}, % annualised")
    drows = [["SW07 parameters (e1_learn_re minus e1_re)", pp(DEC["params"])],
             ["Learning, RE-smoothed history (e1_learn_smoothed minus e1_learn_re)", pp(DEC["learning"])],
             ["History method (e1_learn minus e1_learn_smoothed)", pp(DEC["history"])],
             ["Total (e1_learn minus e1_re)", pp(AV[("e1_learn", "pinfobs")] - AV[("e1_re", "pinfobs")])]]
    dtbl = html_table(["Step", "Average inflation, pp"], drows, num_from=1,
                      caption=f"The engine-based gap split into steps, averages {HZL}")
    n2i = AP[("e1_learn", "n2_model", HZ[0])]
    n2s = AP[("e1_learn_smoothed", "n2_model", HZ[0])]
    sens = (f"<h3 class=\"sub\">Sensitivity: the engine's own histories</h3><p>The same modes run through the toolbox engine "
            f"start from the engine's histories instead of the filter's state ({code('estimation/scenarios/e1_*.m')}): "
            f"{code('e1_re')} (RE mode, RE-smoothed state, two-sided) gives {pct(AV[('e1_re', 'pinfobs')])}; "
            f"{code('e1_learn')} (learning mode, history backed out by the learning model, {code(chr(39) + 'inversion' + chr(39))}) "
            f"{pct(AV[('e1_learn', 'pinfobs')])} with a learners' share in force of {f(n2i, 2)} at the start of the forecast; "
            f"{code('e1_learn_smoothed')} (learning on the RE-smoothed history) {pct(AV[('e1_learn_smoothed', 'pinfobs')])} "
            f"with {f(n2s, 2)}; {code('e1_learn_re')} (learning mode's SW07 parameters, every agent RE) "
            f"{pct(AV[('e1_learn_re', 'pinfobs')])}. The RE run hardly depends on the history ({pct(AV[('e1_re', 'pinfobs')])} "
            f"against {pct(APR['mode'])} from the filter). The learning run does, through the share at the origin: the "
            f"inversion attributes the 2020Q4 catch-up to that quarter's shocks and keeps more learners "
            f"(<a href=\"#surge\">surge section</a>).</p>"
            f"<details class=\"tables\"><summary>Table view: engine-based runs and the gap split into steps</summary>{etbl}{dtbl}"
            f"</details>")
    return sens


def parse_gates(text):
    """Latest line per gate of the estimation runs, the G4 note, and the live toolbox check lines."""
    runs, cur = [], None
    for ln in text.splitlines():
        m = re.match(r"^# (est_00_gates|est_00_g8|est_01_mode_re|live toolbox check) (\d{4}-\d\d-\d\d[ \d:]*)(.*)$", ln)
        if m:
            cur = dict(kind=m.group(1), date=m.group(2).strip(), head=ln[2:], lines=[])
            runs.append(cur)
            continue
        g = re.match(r"^(G\d\w*|L\d) (PASS|FAIL)\s+(.*)$", ln)
        if g and cur is not None:
            cur["lines"].append((g.group(1), g.group(2), g.group(3).strip()))
    notes, lines_ = [], text.splitlines()
    for i, ln in enumerate(lines_):
        if ln.startswith("# note"):
            buf = [ln[2:]]
            j = i + 1
            while j < len(lines_) and lines_[j].startswith("# ") and not re.match(r"^# (est_|live|note)", lines_[j]):
                buf.append(lines_[j][2:])
                j += 1
            notes.append(" ".join(buf))
    est = {}
    for r in runs:
        for gid, st, tx in r["lines"]:
            if r["kind"] != "live toolbox check":
                est[gid] = (st, tx, r["date"])
    live_head = [r for r in runs if r["kind"] == "live toolbox check"]
    # the lines of the latest live toolbox check only
    live = [(gid, st, tx, live_head[-1]["date"]) for gid, st, tx in live_head[-1]["lines"]] if live_head else []
    return est, live, notes, live_head


def gates_blocks(override=None):
    """Validation gates (latest line per gate; override: {gate: text shown instead}), the gate notes and the latest
    live toolbox check (both pages)."""
    est, live, notes, lh = parse_gates(gates_txt)
    grows = []
    for gid in sorted(est):
        st, tx, d = est[gid]
        tx = (override or {}).get(gid, tx)
        grows.append([f'<span class="st st-{"pass" if st == "PASS" else "fail"}">{st}</span>', code(gid), esc(tx)])
    gt = html_table(["Status", "Gate", "Result (latest run, results/estimation/gates.txt)"], grows, num_from=99, cls="gates")
    lrows = [[f'<span class="st st-{"pass" if st == "PASS" else "fail"}">{st}</span>', code(gid), esc(tx)] for gid, st, tx, d in live]
    lt = html_table(["Status", "Gate", "Result against the live toolbox"], lrows, num_from=99, cls="gates") if lrows else ""
    live_ok = bool(live) and all(st == "PASS" for _, st, _, _ in live)
    g4note = "".join(f'<p class="small">{esc(n[0].upper() + n[1:])}</p>' for n in notes)
    live_txt = ""
    if lh:
        has_l1 = any(gid == "L1" for gid, *_ in live)
        live_txt = (f"<h3 class=\"sub\">Live toolbox check</h3><p>Gates G3, G4 (the degenerate-start version) and G5 (at the "
                    f"calibration and 5 prior draws, both timings), plus the log likelihoods at the two modes"
                    + (" and the log posteriors at all four modes" if has_l1 else "") + ", run against the "
                    f"live {code('toolbox/')} in a separate process ({code('est_00_gates_live')}, {esc(lh[-1]['date'])}). "
                    + ("All pass: the estimator works with the live toolbox, including its two new options "
                       f"{code('history.re_states')} and {code('expectations.re_info')} at their defaults, without changes."
                       if live_ok else "Not all pass; see the lines below.") + f"</p>{lt}")
    return gt, g4note, live_txt


def sec_diag():
    gt, g4note, live_txt = gates_blocks()
    crow = []
    for m, nm in (("re", "RE"), ("learn", "Learning")):
        nch = int(dg(m, "all", "", "chains"))
        dr = [int(dg(m, f"chain_{k:02d}", "", "draws")) for k in range(1, nch + 1)]
        ac = [dg(m, f"chain_{k:02d}", "", "acceptance") for k in range(1, nch + 1)]
        crow.append([nm, str(nch), ", ".join(num(x) for x in dr), f"{f(min(ac), 3)}-{f(max(ac), 3)}",
                     num(dg(m, "all", "", "post_draws_pooled")),
                     f"{f(dg(m, 'all', '', 'rhat_max'), 3)} ({esc(dgt(m, 'all', '', 'rhat_max'))})",
                     f"{f(dg(m, 'all', '', 'ess_min'), 0)} ({esc(dgt(m, 'all', '', 'ess_min'))})",
                     f"{int(dg(m, 'all', '', 'n_rhat_lt_1.1'))} / {int(dg(m, 'all', '', 'n_ess_gt_100'))}"])
    ct = html_table(["Model", "Chains", "Draws per chain", "Acceptance", "Pooled post burn-in draws", "Largest split R-hat",
                     "Smallest bulk ESS", "Parameters with R-hat < 1.1 / ESS > 100"], crow, num_from=1)
    prow = []
    for n in NAMES:
        r = [code(n)]
        for m in ("re", "learn"):
            if (m, "all", n, "rhat") in DG:
                r += [f(dg(m, "all", n, "rhat"), 3), f(dg(m, "all", n, "ess_bulk"), 0)]
            else:
                r += ["", ""]
        prow.append(r)
    pt = html_table(["Parameter", "RE R-hat", "RE ESS", "Learning R-hat", "Learning ESS"], prow, num_from=1)
    if GONOGO:
        gtxt = (f"{code('est_gonogo')} on the learning chains at the design's 2-hour check: <b>{esc(GONOGO[1])}</b> "
                f"({esc(dgt('learn', 'gonogo', '', 'created'))}, {num(dg('learn', 'gonogo', '', 'draws_per_chain'))} draws per chain).")
    else:
        gtxt = f"{code('est_gonogo')} has not been run on the learning chains yet ({code('results/estimation/learn/gonogo.txt')} does not exist)."
    ov = {k[3]: v[1] for k, v in DG.items() if k[0] == "learn" and k[1] == "gonogo_override"}
    if ov.get("decision") == "overridden":
        pl = ov.get("plan", "")
        gtxt += (f" <b>The rule was overridden</b> ({esc(ov.get('by', ''))}): {esc(ov.get('action', ''))}. Reasons: "
                 f"{esc(ov.get('reason', ''))}." + (f" {esc(pl[:1].upper() + pl[1:])}." if pl else ""))
    g2 = {k[3]: v for k, v in DG.items() if k[0] == "learn" and k[1] == "gonogo2"}
    if "stage1_converged" in g2:
        def first(s):
            return s.split(" (")[0]
        gtxt += (f" {code('est_gonogo2')} ({esc(g2.get('created', (0, ''))[1])}): stage 1 converged: "
                 f"{esc(g2['stage1_converged'][1])}; design rule {esc(first(g2.get('stage1_rule', (0, 'n/a'))[1]))}; "
                 f"stage 2 {esc(first(g2.get('stage_2', (0, 'n/a'))[1]))}"
                 + (f"; stage-2 chains converged: {esc(g2['stage2_converged'][1])}" if "stage2_converged" in g2 else "")
                 + ".")
    rule = (f"Applied to the draws on this page, the design's rule (R-hat below 1.1 and ESS above 100 for the gain, memory and "
            f"intensity, and for at least 80% of the {len(STRUCT)} SW07 parameters) gives "
            f"<b>{'GO' if GO_INTERIM else 'NO-GO'}</b>: {len(L_OK)} of {len(LEARNP)} learning parameters and {len(S_OK)} of "
            f"{len(STRUCT)} SW07 parameters pass.")
    shp = dg("learn", "all", "", "share_draws_plm")
    mep = dg("learn", "all", "", "mean_events_plm")
    sha = dg("learn", "all", "", "share_draws_alm")
    shk = dg("learn", "all", "", "share_draws_alm_shares")
    fac = (f"Projection facility: {f(100 * shp, 1)}% of the pooled learning draws have at least one PLM-block event (the "
           f"candidate beliefs have a root above 1 and the previous ones are kept), {f(mep, 2)} per draw on average; "
           f"{f(100 * sha, 1)}% have an ALM revert and {f(100 * shk, 1)}% kept shares. At the mode: "
           f"{esc(dgt('learn', 'mode', '', 'mode_events_plm'))}.")
    body = f"""<p class="answer">{rule}</p>
<p>{gtxt}</p>
<p>{fac}</p>
{ct}
<h3 class="sub">Validation gates</h3>
{g4note}
{gt}
{live_txt}
<details class="tables"><summary>R-hat and ESS by parameter</summary>{pt}</details>"""
    return section("diagnostics", 11, "Diagnostics", body)


def sec_caveats():
    il = ID["chi"]
    nC = int(dg("learn_current", "mode", "", "mode_starts"))
    nK = int(dg("learn_calib", "mode", "", "mode_starts"))
    items = []
    if INTERIM:
        items.append(f"<b>Interim draws.</b> {num(LDRAWS)} learning draws; largest R-hat {f(RHAT_MAX)}, smallest ESS "
                     f"{f(ESS_MIN, 0)}. Rerun {code('est_06_post(' + chr(39) + 'final' + chr(39) + ')')}, "
                     f"{code('est_06b_app1_post(' + chr(39) + 'final' + chr(39) + ')')} and this builder when "
                     f"the chains finish; the learning MHM, posterior means and bands will change.")
    items.append(f"<b>No survey expectations.</b> The intensity of choice is identified mainly by its prior (posterior sd "
                 f"{f(il['r'], 2)} times the prior's). IJCB pinned it at {f(pv('chi', 'ijcb_survey', 'mean'), 2)} with survey "
                 f"data. Next: add the SPF one-quarter-ahead inflation expectation as an eighth observable with a measurement "
                 f"error, as IJCB eq. 22.")
    items.append("<b>No lower bound.</b> The policy rate sits at its floor in 2009-15 and 2020-21 in both models, and the "
                 "learning model may use beliefs to absorb those years. A cheap variant: treat the rate as missing in the "
                 "lower-bound quarters, so both filters work with a shadow rate.")
    items.append(f"<b>Variants.</b> The 'current' mode comes from {nC} starts and the 'calib' mode from {nK}. Fixed initial "
                 f"beliefs and 'freeze' in the covid gap are evaluated at the baseline mode only, with the baseline Hessian "
                 f"for the Laplace value.")
    items.append(f"<b>History method.</b> The share path depends on how the covid gap is bridged: at the learning mode the "
                 f"share at {ORIGIN} ranges from {f(SN2_LO, 2)} to {f(SN2_HI, 2)} across five histories (the estimation "
                 f"filter {f(SN2['filter'], 2)}, the engine's inversion {f(SN2['inversion'], 2)}). Application 1 starts from "
                 f"the likelihood's filter; the engine's histories are a sensitivity check.")
    items.append(f"<b>RE mode in the tail.</b> The RE mode has {code('crhopinf')} {f(pv('crhopinf', 're', 'mode'), 3)} against a "
                 f"posterior mean of {f(pv('crhopinf', 're', 'mean'), 3)} (90% {f(pv('crhopinf', 're', 'q05'), 3)}-"
                 f"{f(pv('crhopinf', 're', 'q95'), 3)}). The application 1 forecast at the RE mode inherits that persistence "
                 f"({pct(APR['mode'])} average inflation against a posterior median of {pct(APR['median'])}).")
    items.append("<b>Gate G4 changed after the first run.</b> The design's decay criterion could not hold for SW07: four "
                 "observables are first differences, so the filter's state uncertainty does not collapse and a filter "
                 "started from the stochastic initial condition keeps a permanent distance from the inversion. The gate now "
                 "starts the filter from the engine's own 1965Q4 state with zero uncertainty, where the two must agree "
                 "exactly, and reports the stochastic-start distances as information.")
    nxt = ("<b>To adopt estimation in the main toolbox.</b> (1) Final chains that pass est_gonogo2 (stage 1, or stage 2 "
           "if needed); (2) the user's approval for model packages with parameters estimated here (the packaging rule of "
           "2026-10-18); (3) a parameter override in "
           f"{code('hetlearn.load_model')}, which would make the copies in {code('estimation/models/')} unnecessary; (4) "
           f"{code('hetlearn.re_filter')} returning the RE log likelihood; (5) the learning filter as an engine function, tied "
           "to the inversion by gate G4, with tests; (6) the gates in the test suite and step 8 in the run order.")
    body = ('<ul class="cav">' + "".join(f"<li>{t}</li>" for t in items) + "</ul>"
            f'<div class="box next"><p>{nxt}</p></div>')
    return section("caveats", 12, "Caveats and next steps", body)


# ============================================================================= modes-only page
# est_06_post('modes'): every table at the posterior modes and no chain read (the MCMC is paused). This page has no
# posterior means, bands, MHM, R-hat or ESS; standard deviations are Hessian-based and the MDD is the Laplace value.
def identm(n):
    """A learning parameter at the mode: Hessian sd against the prior sd and against the prior's local sd there."""
    m, s = pv(n, "learn", "mode"), pv(n, "learn", "sd_hessian")
    pm, ps = pv(n, "prior", "mean"), pv(n, "prior", "sd")
    return dict(m=m, s=s, pm=pm, ps=ps, r=s / ps, loc=pv(n, "prior", "sd_local_learn_mode"), shift=(m - pm) / ps)


def chain_progress():
    """Draws in complete blocks and the target of every chain, by set (re, stage1, stage2), from diagnostics.csv."""
    out = {}
    for (model, chain, _p, metric), (v, tx) in DG.items():
        if metric.endswith("_draws_in_blocks"):
            st = metric[: -len("_draws_in_blocks")]
            tgt = DG.get((model, chain, "", st + "_ndraws"), (NAN, ""))[0]
            out.setdefault(st, []).append(dict(chain=chain, n=int(v), target=int(tgt), text=tx))
    return {k: sorted(v, key=lambda d: d["chain"]) for k, v in out.items()}


def nrange(lst):
    lo, hi = min(d["n"] for d in lst), max(d["n"] for d in lst)
    return num(lo) if lo == hi else f"{num(lo)}-{num(hi)}"


def msd(n, src):
    """Mode with the Hessian sd in brackets."""
    return f"{fp(n, pv(n, src, 'mode'))} ({fp(n, pv(n, src, 'sd_hessian'))})"


def evfmt(txt):
    """'2022Q1 plm; 2022Q2 plm' -> 'PLM block in 2022Q1 and 2022Q2' ('' -> 'none')."""
    kind = {"plm": "PLM block", "alm": "ALM revert", "alm_shares": "kept shares"}
    by = {}
    for item in [s.strip() for s in (txt or "").split(";") if s.strip()]:
        q, ty = item.split(" ", 1)
        by.setdefault(kind.get(ty, ty), []).append(q)
    return "; ".join(f"{k} in {names_and(v)}" for k, v in by.items()) if by else "none"


def f2(n, v):
    """A parameter value in prose: 4 decimals for the gain, 2 for the intensity of choice, 3 otherwise."""
    return f(v, 4 if n == "gain" else (2 if n == "chi" else 3))


if MODES:
    DMO = {n: pv(n, "compare", "diff_mode_in_re_sd_hessian") for n in STRUCT}
    FLAGM = sorted([n for n in STRUCT if pv(n, "compare", "flag_mode_2sd_hessian") == 1], key=lambda n: -abs(DMO[n]))
    TOPM = sorted(STRUCT, key=lambda n: -abs(DMO[n]))[:6]
    IDM = {n: identm(n) for n in LEARNP}
    PAUSE = {k[3]: v[1] for k, v in DG.items() if k[0] == "learn" and k[1] == "mcmc_paused"}
    CHS = chain_progress()
    MODEL_KEYS = ("learn", "learn_current", "learn_calib")
    NSTART = {k: int(dg(k, "mode", "", "mode_starts")) for k in ("re",) + MODEL_KEYS}
    NREACH = {k: int(dg(k, "mode", "", "mode_starts_reached")) for k in ("re",) + MODEL_KEYS}
    NO_ALM = all(dg(k, "mode", "", "mode_events_alm") == 0 and dg(k, "mode", "", "mode_events_alm_shares") == 0
                 for k in MODEL_KEYS)
    # the converged RE posterior, quoted once (application 1): params.csv re_posterior and the RE rows of app1_post_long
    REPM = dict(crp=pv("crhopinf", "re_posterior", "mean"), med=APR["median"], p05=APR["p05"], p95=APR["p95"],
                n=int(ASUM["re"].n_draws))
    if not all(math.isfinite(v) for v in REPM.values()) or REPM["n"] < 1:
        raise SystemExit("The modes tables lack the RE posterior (params.csv source re_posterior; RE median/p05/p95 in "
                         "app1_post_long.csv): rerun est_06_post('modes').")


def banner_m():
    return ('<aside class="banner" role="note"><p><b>Posterior modes only. MCMC paused; posterior means and bands will '
            'follow if the modes look right.</b> Both models are compared at their posterior modes: standard deviations '
            'come from the inverse Hessian at each mode, marginal likelihoods from the Laplace approximation, and the '
            'paths, impulse responses and application 1 are computed at the modes. The chains are kept and can be resumed '
            '(<a href="#diagnostics">diagnostics</a>).</p></aside>')


def level_txt(d):
    """'is level with RE' / 'beats RE by x' / 'is x below RE' for a Laplace difference d."""
    return "is level with RE" if abs(d) < 1 else (f"beats RE by {f(d)}" if d > 0 else f"is {f(-d)} below RE")


def sec_summary_m():
    ig, io, il = IDM["gain"], IDM["omega"], IDM["chi"]
    cur = lapC - lapR
    fit = (f"<b>Learning fits better at the modes.</b> The Laplace log marginal data density is {f(lapL)} for the learning "
           f"model and {f(lapR)} under RE: a log Bayes factor of {f(BF)} ({f(BF10)} in log10"
           + ("; decisive on Jeffreys' scale, which starts at 2" if BF10 > 2 else "") + "). "
           f"At the modes the log likelihood is {f(llL - llR)} higher and the log posterior {f(lpL - lpR)} higher, for "
           f"{len(LEARNP)} extra parameters. With 'current' instead of lagged information the learning model "
           f"{level_txt(cur)} ({f(cur, 2, True)}).")
    well = ["the " + PNAME[n] for n in LEARNP if IDM[n]["r"] < 0.5]
    weak = ["the " + PNAME[n] for n in LEARNP if IDM[n]["r"] >= 0.8]
    head = "At the mode"
    if well:
        head += f" the data narrow {names_and(well)}"
    if weak:
        head += ("; " if well else " ") + (f"{names_and(weak)} {plural(len(weak), 'is', 'are')} no better pinned down "
                                           f"than by the prior")
    over = [n for n in LEARNP if IDM[n]["r"] > 1 and IDM[n]["s"] > IDM[n]["loc"]]
    ovt = "".join(f" The Hessian sd of the {PNAME[n]}, {f2(n, IDM[n]['s'])}, is above its prior sd ({f2(n, IDM[n]['ps'])}) "
                  f"and above the prior's own local sd at the mode ({f2(n, IDM[n]['loc'])}), so the likelihood does not "
                  f"narrow it there." for n in over)
    cal = pv("chi", "calibration", "value")
    idt = (f"<b>{head}.</b> Modes (Hessian sd): gain {fp('gain', ig['m'])} ({fp('gain', ig['s'])}; prior mean "
           f"{fp('gain', ig['pm'])}, sd {fp('gain', ig['ps'])}), memory {f(io['m'], 3)} ({f(io['s'], 3)}; prior mean "
           f"{f(io['pm'], 3)}, sd {f(io['ps'], 3)}), intensity of choice {f(il['m'], 2)} ({f(il['s'], 2)}; prior mean "
           f"{f(il['pm'], 2)}, sd {f(il['ps'], 2)}). Hessian sd relative to the prior sd: gain {f(ig['r'], 2)}, memory "
           f"{f(io['r'], 2)}, intensity {f(il['r'], 2)}.{ovt} IJCB estimated the gain at "
           f"{fp('gain', pv('gain', 'ijcb_survey', 'mean'))} with survey data and the intensity at "
           f"{f(pv('chi', 'ijcb_nosurvey', 'mean'), 2)} without them. The toolbox calibration of the intensity, {f(cal, 2)}, "
           f"lies {f((il['m'] - cal) / il['s'], 1)} Hessian sds below the mode.")
    mvh = names_and([f"{SHORT.get(n, LAB[n])} {'up' if pv(n, 'learn', 'mode') > pv(n, 're', 'mode') else 'down'}"
                     for n in TOPM[:4]])
    mvtxt = ", ".join(f"{code(n)} {fp(n, pv(n, 're', 'mode'))} to {fp(n, pv(n, 'learn', 'mode'))} ({f(DMO[n], 1, True)} sd)"
                      for n in TOPM)
    lrR, lrL = LRMK["re"], LRMK["learn"]
    cp_dn = pv("cprobp", "learn", "mode") < pv("cprobp", "re", "mode")
    why = (f" One reading: beliefs and shares add inflation persistence of their own, so the model needs less of it from "
           f"price stickiness and the mark-up process. The cumulative response of the price mark-up to its own shock, "
           f"(crhopinf - cmap)/(1 - crhopinf), is {f(lrR, 1)} at the RE mode and {f(lrL, 1)} at the learning mode."
           if cp_dn and lrL < lrR and pv("epinf", "learn", "mode") > pv("epinf", "re", "mode") else "")
    struct = (f"<b>The largest moves between the modes: {mvh}.</b> RE mode to learning mode, with the move in RE Hessian "
              f"sds: {mvtxt}. {len(FLAGM)} of {len(STRUCT)} parameters move by more than 2 RE Hessian sds "
              f"({', '.join(code(n) for n in FLAGM)})." + why)
    surge = (f"<b>At the learning mode the learners' share fell during the 2021-22 surge.</b> The end-of-quarter share was "
             f"{f(N2_19['mode'], 2)} at the end of 2019Q4 and {f(N2_O['mode'], 2)} at the end of {ORIGIN}, with a low of "
             f"{f(N2_LOW, 2)} in {Q_LOW}. The calibrated history has {f(N2_O['cal'], 2)} at {ORIGIN}. Over 2021Q1-{ORIGIN} "
             f"the RE agents' forecasts missed inflation by {f(FE_RE, 2)} pp (root mean square, annualised) and the learners' "
             f"by {f(FE_BR, 2)} pp. The share at the origin is fragile: at the same parameters it ends {ORIGIN} between "
             f"{f(SN2_LO, 2)} and {f(SN2_HI, 2)} depending on how the three quarters without data in {NANTXT} are bridged "
             f"(the engine's inversion history {f(SN2['inversion'], 2)}, its RE-smoothed history {f(SN2['re_smoother'], 2)}, "
             f"no updating in the gap {f(SN2['freeze'], 2)}, the 2020 data put back {f(SN2['covid_data'], 2)}). With an "
             f"intensity of choice of {f(pv('chi', 'learn', 'mode'), 1)}, small differences in the 2020Q4 starting point "
             f"and in the 2021 forecast errors move the share a lot.")
    gap_p = APL["mode"] - APR["mode"]
    gap_c = CAL1["learn"] - CAL1["re"]
    app1 = (f"<b>Application 1 from the estimated models' own state: inflation averages {pct(APL['mode'])} at the learning "
            f"mode and {pct(APR['mode'])} at the RE mode.</b> The forecasts start from the likelihood's filtered state at "
            f"{ORIGIN} and run {HZL} with zero shocks as the engine's forecast stage does (gate G8). Learning minus RE is "
            f"{pp(gap_p)} at the modes and {pp(gap_c)} in the calibrated runs ({pct(CAL1['learn'])} and "
            f"{pct(CAL1['re'])}). The RE mode "
            f"has a near unit-root price mark-up ({code('crhopinf')} {f(pv('crhopinf', 're', 'mode'), 3)}, Hessian sd "
            f"{f(pv('crhopinf', 're', 'sd_hessian'), 3)}); over the converged RE posterior the median of RE average "
            f"inflation is {pct(REPM['med'])}. From the engine's inversion history instead of the filter the learning mode "
            f"gives {pct(AV[('e1_learn', 'pinfobs')])}.")
    cav = ("<b>Caveats.</b> These are modes: the standard deviations are local (the inverse Hessian) and the marginal "
           "likelihoods are Laplace approximations. There are no survey expectations, so the intensity of choice rests on "
           "its prior. Neither model has an effective lower bound. The variants other than 'current' are evaluated at the "
           "baseline mode only.")
    items = [fit, where_text(), idt, struct, surge, app1, cav]
    lis = "".join(f'<li class="ans"><span class="al">{k}</span><div><p>{t}</p></div></li>' for k, t in enumerate(items, 1))
    body = f"""{banner_m()}
<ol class="answers">{lis}</ol>"""
    return section("summary", 0, "Summary", body)


def sec_setup_m():
    common, nolb = setup_items()
    s1, s2, sr = CHS.get("stage1", []), CHS.get("stage2", []), CHS.get("re", [])
    pause = ""
    if s1:
        pause = (f" The MCMC is paused: the {len(s1)} stage-1 learning chains hold {nrange(s1)} of {num(s1[0]['target'])} "
                 f"draws" + (f" and the {len(s2)} stage-2 chains {nrange(s2)} of {num(s2[0]['target'])}" if s2 else "")
                 + "; they can be resumed (<a href=\"#diagnostics\">diagnostics</a>).")
    rel = ""
    if sr and "have converged" in META.get("re_posterior", ""):
        rel = (f" The RE chains ({len(sr)} x {num(sr[0]['target'])} draws) have converged; apart from one comparison in "
               f"application 1, that posterior is left out so that both models are compared at their modes.")
    body = f"""<ul class="mech">
{common}
<li><b>Estimation.</b> Posterior modes by csminwel, with the bounded parameters transformed to the real line. RE: one
search from the swX1 mode, restarted from its result. Learning: {NSTART['learn']} starts (the RE mode with the best values
of a search over the three learning parameters, the RE mode with the learning prior means, and a perturbed RE mode with
the calibrated learning parameters), {NREACH['learn']} of which reach the same mode; the 'current' variant from
{NSTART['learn_current']} starts ({NREACH['learn_current']} reach its mode), the 'calib' variant from
{NSTART['learn_calib']} {plural(NSTART['learn_calib'], 'start', 'starts')}. At each mode, the Hessian of minus the log posterior by central differences, standard
deviations from its inverse, and the Laplace approximation of the marginal likelihood.{pause}{rel}</li>
{nolb}
</ul>
<p class="small">{toolbox_note()}</p>"""
    return section("setup", 1, "Set-up in brief", body)


def sec_params_m():
    shp = {"gamma": "G", "beta": "B", "normal": "N", "inv_gamma_1": "IG"}
    rows = []
    for g, gt in GROUPS:
        rows.append(f'<tr class="grp"><td colspan="9">{esc(gt)}</td></tr>')
        for n in [x for x in NAMES if GRP[x] == g]:
            sh = shp[PTX[(n, "prior", "mean")]]
            prior = f"{sh}({fp(n, pv(n, 'prior', 'mean'))}, {fp(n, pv(n, 'prior', 'sd'))})"
            isS = g != "learning"
            mv = ""
            if isS:
                mv = f(DMO[n], 2, True)
                if pv(n, "compare", "flag_mode_2sd_hessian") == 1:
                    mv += ' <span class="chip">&gt; 2 sd</span>'
            rows.append([f"{code(n)}<span class=\"lab\">{esc(LAB[n])}</span>", prior,
                         fp(n, pv(n, "published_sw07", "mode")) if isS else "",
                         fp(n, pv(n, "swx1", "mode")) if isS else "",
                         msd(n, "re") if isS else "", msd(n, "learn"),
                         fp(n, pv(n, "learn_current", "mode")), fp(n, pv(n, "learn_calib", "mode")), mv])
    hdr = ["Parameter", "Prior", "SW07 1966-2004", "swX1 1966-2026", "RE mode (Hessian sd)", "Learning mode (Hessian sd)",
           "'current' mode", "'calib' mode", "Learning minus RE, RE Hessian sds"]
    tbl = html_table(hdr, rows, num_from=1, cls="par")
    lrows = []
    for n in LEARNP:
        d = IDM[n]
        lrows.append([f"{code(n)}<span class=\"lab\">{esc(LAB[n])}</span>",
                      f"{shp[PTX[(n, 'prior', 'mean')]]}({fp(n, d['pm'])}, {fp(n, d['ps'])})",
                      f"{fp(n, pv(n, 'ijcb_survey', 'mean'))} [{fp(n, pv(n, 'ijcb_survey', 'lo'))}, {fp(n, pv(n, 'ijcb_survey', 'hi'))}]",
                      f"{fp(n, pv(n, 'ijcb_nosurvey', 'mean'))} [{fp(n, pv(n, 'ijcb_nosurvey', 'lo'))}, {fp(n, pv(n, 'ijcb_nosurvey', 'hi'))}]",
                      fp(n, pv(n, "calibration", "value")), msd(n, "learn"), f(d["r"], 2), fp(n, d["loc"]),
                      f"{fp(n, pv(n, 'learn_calib', 'mode'))} under {shp[PTX[(n, 'prior_calib', 'mean')]]}"
                      f"({fp(n, pv(n, 'prior_calib', 'mean'))}, {fp(n, pv(n, 'prior_calib', 'sd'))})"])
    ltbl = html_table(["Parameter", "Prior", "IJCB, with survey data", "IJCB, no expectations data", "Toolbox calibration",
                       "Mode (Hessian sd)", "Hessian sd / prior sd", "Prior's local sd at the mode",
                       "'calib' mode under its prior"], lrows, cls="par")
    big = max(STRUCT, key=lambda n: abs(DMO[n]))
    ans = (f"{len(FLAGM)} of the {len(STRUCT)} SW07 parameters differ by more than 2 RE Hessian sds between the modes "
           f"({', '.join(code(n) for n in FLAGM)}). The largest is {code(big)} ({esc(LAB[big])}): "
           f"{fp(big, pv(big, 're', 'mode'))} at the RE mode and {fp(big, pv(big, 'learn', 'mode'))} at the learning mode, "
           f"{f(DMO[big], 1, True)} sd.")
    swx = [n for n in STRUCT if abs(pv(n, "re", "mode") - pv(n, "swx1", "mode")) > 2 * pv(n, "re", "sd_hessian")]
    swx_s = len([n for n in swx if GRP[n] == "shocks"])
    body = f"""<p class="answer">{ans}</p>
<p>Columns: the published SW07 mode (1966-2004); swX1, the project's own Dynare re-estimation on 1966-2026 with the covid
quarters kept (the parameters of every scenario in the main report); the RE re-estimate here (covid quarters missing,
stochastic initialisation) and the learning estimate, each at its mode with the Hessian sd in brackets; the modes of the
two learning variants ('current' information, and priors centred on the calibration). Prior: shape (B beta, G gamma, N
normal, IG inverse gamma) with mean and sd. The last column is the learning mode minus the RE mode in RE Hessian sds (the
square roots of the diagonal of the inverse Hessian at the RE mode); the chip marks moves of more than 2 sd. Under the new
conventions the RE mode differs from swX1 by more than 2 RE Hessian sds in {len(swx)} parameters
({", ".join(code(n) for n in swx)}); {swx_s} of them belong to the shock processes. Gate G7 below lists the largest
moves.</p>
{tbl}
<h3 class="sub">The learning parameters against IJCB and the calibration</h3>
<p>IJCB intervals as printed in the paper. The prior's local sd is 1/sqrt(-d<sup>2</sup> log p/dx<sup>2</sup>) of the
marginal prior at the learning mode: the Hessian sd would equal it if the likelihood did not depend on that parameter.
The 'calib' variant re-estimates the model with priors centred on the calibration (last column).</p>
{ltbl}"""
    return section("params", 2, "Parameters: RE against learning, at the modes", body)


def dens_chart_m(n, gid):
    d = ppl[ppl.param == n]
    xs = sorted(set(d[d.density == "prior"].x))
    X = [f"{v:.6g}" for v in xs]
    get = {k: dict(zip(g.x, g.value)) for k, g in d.groupby("density")}
    ser = [S("prior", [clean(get["prior"].get(v)) for v in xs])]
    if "re_laplace" in get:
        ser.append(S("re", [clean(get["re_laplace"].get(v)) for v in xs], name="RE, Laplace approximation", short="RE"))
    ser.append(S("learn", [clean(get["learn_laplace"].get(v)) for v in xs], name="Learning, Laplace approximation",
                 short="Learning"))
    rules = []
    if n in LEARNP:
        c = pv(n, "calibration", "value")
        if xs[0] <= c <= xs[-1]:
            k = min(range(len(xs)), key=lambda i: abs(xs[i] - c))
            rules.append(dict(x=X[k], label="calibration"))
        cap = (f"Prior mean {fp(n, pv(n, 'prior', 'mean'))}, sd {fp(n, pv(n, 'prior', 'sd'))}; learning mode "
               f"{fp(n, pv(n, 'learn', 'mode'))}, Hessian sd {fp(n, pv(n, 'learn', 'sd_hessian'))}.")
    else:
        cap = (f"Modes {fp(n, pv(n, 're', 'mode'))} (RE) and {fp(n, pv(n, 'learn', 'mode'))} (learning), Hessian sds "
               f"{fp(n, pv(n, 're', 'sd_hessian'))} and {fp(n, pv(n, 'learn', 'sd_hessian'))}: {f(DMO[n], 1, True)} RE sd.")
    mx = max(v for s in ser for v in s["v"] if v is not None)
    dec = 1 if mx >= 10 else (2 if mx >= 1 else 3)
    return line(f"pp-{n}", gid, f"{n}: {LAB[n]}", cap, X, ser, xnum=[xs[0], xs[-1]], xHead=n, dec=dec, h=180,
                yr=[0.048 * mx, mx], endLabels=False, rules=rules)


def sec_priorpost_m():
    ch = "".join(dens_chart_m(n, "pp") for n in LEARNP + MOVERS)
    parts = [f"{PNAME[n]} {f(IDM[n]['shift'], 1, True)} and {f(IDM[n]['r'], 2)}" for n in LEARNP]
    narrowed = ["the " + PNAME[n] for n in LEARNP if IDM[n]["r"] < 0.5]
    ans = ("Mode minus prior mean, in prior sds, and Hessian sd relative to the prior sd: " + "; ".join(parts) + "."
           + (f" Only {names_and(narrowed)} {plural(len(narrowed), 'is', 'are')} narrowed by the data at the mode."
              if narrowed else " None is narrowed much by the data at the mode."))
    body = f"""<p class="answer">{ans}</p>
<p>Prior densities as used in the log posterior (not renormalised for the bounds). The other curves are the Laplace
approximations at the modes: normal densities with the mode as mean and the standard deviation from the inverse Hessian,
not truncated at the bounds. They show the curvature at each mode, not the posterior; the posterior densities will come
from the chains. The first three panels are the learning parameters, with their calibrated values marked. The other four
are the SW07 parameters whose modes differ most between the two models, measured in RE Hessian sds.</p>
{fig_title("Prior densities and the Laplace approximations at the modes")}
{legend("pp", [leg("prior"), leg("re", name="RE, Laplace approximation"), leg("learn", name="Learning, Laplace approximation")])}
<div class="grid g-3">{ch}</div>
{tables("pp")}"""
    return section("priorpost", 3, "Prior against the Laplace approximation", body)


def sec_mdd_m():
    l10 = math.log(10)
    rows = [["RE (36 parameters)", f(lpR), f(llR), f(lapR), "0", "0"],
            ["Learning, 'lagged' (39; baseline)", f(lpL), f(llL), f(lapL), f(BF, 2, True), f(BF10, 2, True)],
            ["Learning, 'current' information", f(md("learn_current", "log_posterior_at_mode")),
             f(md("learn_current", "log_likelihood_at_mode")), f(lapC), f(lapC - lapR, 2, True), f((lapC - lapR) / l10, 2, True)],
            ["Learning, priors centred on the calibration", f(md("learn_calib", "log_posterior_at_mode")),
             f(md("learn_calib", "log_likelihood_at_mode")), f(lapK), "not comparable", ""],
            ["swX1 mode under this likelihood", f(lpS), f(llS), "", "", ""]]
    tbl = html_table(["Model", "Log posterior at the mode", "Log likelihood at the mode", "Laplace log MDD",
                      "Log Bayes factor vs RE (Laplace)", "log10"], rows, cls="mdd")
    vrows = []
    for key, nm in (("learn_fixed_beliefs", "Fixed initial beliefs (RE moments at the RE mode, as in IJCB)"),
                    ("learn_freeze", "'freeze': no learning in the covid gap")):
        vrows.append([nm, f(md(key, "log_likelihood_at_baseline_mode")), f(md(key, "log_likelihood_minus_baseline"), 2, True),
                      f(md(key, "log_posterior_at_baseline_mode"))])
    vtbl = html_table(["Variant, at the baseline learning mode", "Log likelihood", "Minus the baseline log likelihood",
                       "Log posterior"], vrows, cls="mdd",
                      caption="Likelihoods at the baseline learning mode, not re-optimised: not marginal likelihoods")
    dF, dZ = md("learn_fixed_beliefs", "log_likelihood_minus_baseline"), md("learn_freeze", "log_likelihood_minus_baseline")
    cur = lapC - lapR
    ans = (f"Learning beats RE by {f(BF)} log points on the Laplace approximation ({f(BF10)} in log10). With 'current' "
           f"information the learning model {level_txt(cur)} ({f(cur, 2, True)}) and is {f(lapL - lapC)} log points below the "
           f"baseline 'lagged' timing. At the baseline mode, fixed initial beliefs change the log likelihood by "
           f"{f(dF, 2, True)} and 'freeze' in the covid gap by {f(dZ, 2, True)}; these are likelihoods at the baseline "
           f"parameters, not marginal likelihoods.")
    ev = dgt("learn", "mode", "", "mode_events_plm")
    evC = dgt("learn_current", "mode", "", "mode_events_plm")
    body = f"""<p class="answer">{ans}</p>
<p>Laplace with Laplace: each model's log posterior at its mode plus the log volume of the normal approximation given by
the Hessian. The variant with priors centred on the calibration has a different prior, so its marginal likelihood is not
a test of the model against the baseline. The swX1 mode, the parameters of the main report, has a log posterior
{f(lpR - lpS)} below the RE re-estimate under these conventions.</p>
{tbl}
<h3 class="sub">Two variants at the baseline mode</h3>
<p>Fixed initial beliefs and 'freeze' were evaluated at the baseline learning mode only. The table gives their log
likelihoods at those parameters: they are neither re-optimised nor marginal likelihoods.</p>
{vtbl}
<p class="small">'current' mode from {NSTART['learn_current']} starts, 'calib' from {NSTART['learn_calib']}, baseline from
{NSTART['learn']} (every start reaching the same mode). Projection-facility events at the modes: baseline
{esc(evfmt(ev))}, 'current' {esc(evfmt(evC))}{"; no ALM reverts or kept shares at any mode" if NO_ALM else ""}.</p>"""
    return section("mdd", 4, "Model comparison at the modes", body)


def sec_lpd_m():
    X = QL
    shades = [[a, b, n] for a, b, n, sh in EPIS if sh]

    def ser(key, nd):
        return [None if q in MISSING else clean(LP[(q, key)], nd) for q in X]

    # the two l_t paths nearly coincide: RE thick and solid underneath, learning thin and dashed on top
    p1 = [S("re", ser("llt_re_mode", 3), name="RE, at the mode", short="RE", width=3.2),
          S("learn", ser("llt_learn_mode", 3), name="Learning, at the mode", short="Learning", style="dashed", width=1.6)]
    p2 = [S("learn", ser("llt_diff_mode", 4), name="Learning minus RE", short="Difference")]
    p3 = [S("learn", [clean(LP[(q, "cum_diff_mode")], 3) for q in X], name="Cumulative difference", short="Cumulative")]
    ref0 = [dict(y=0, label="")]
    cap = (f"Top: the log-likelihood contribution l_t of each quarter at the two modes (RE thick and solid, learning dashed; "
           f"the two nearly coincide). Middle: their difference, learning minus RE. Bottom: its sum from {FIRST}, which ends "
           f"at {f(TOT_DIFF)} in {LAST}, the difference between the log likelihoods at the modes. The {len(MISSING)} quarters without data ({NANTXT}) contribute nothing. Shaded: "
           + "; ".join(f"{n} {a}-{b}" for a, b, n in shades) + ".")
    fig = stacked("lpd", f"Log-likelihood contributions at the modes, {FIRST}-{LAST}", cap,
                  [("Log-likelihood contribution l_t", X, p1, dict(shades=shades, h=170, dec=2)),
                   ("Learning minus RE, per quarter", X, p2, dict(shades=shades, h=150, dec=2, zero=True, refs=ref0)),
                   (f"Cumulative difference from {FIRST}", X, p3, dict(shades=shades, h=210, dec=2, zero=True, refs=ref0))],
                  h=170)
    rows = [[esc(n), f"{a}-{b}", str(EPQ[n]), f(EPS[n], 2, True), f(EPS[n] / max(1, EPQ[n]), 3, True)] for a, b, n, sh in EPIS]
    rows.append(["Total", f"{FIRST}-{LAST}", str(NOBS), f(TOT_DIFF, 2, True), f(TOT_DIFF / NOBS, 3, True)])
    tbl = html_table(["Episode", "Dates", "Quarters with data", "Sum of l_t differences at the modes", "Per quarter"], rows,
                     num_from=2)
    best = max(EPS, key=EPS.get)
    worst = min(EPS, key=EPS.get)
    big = sorted(((q, LP[(q, "llt_diff_mode")]) for q in X if q not in MISSING), key=lambda t: -abs(t[1]))[:3]
    ans = (f"Learning gains most in {esc(ep(best))} ({f(EPS[best], 2, True)} log points at the modes) and "
           + (f"loses most in {esc(ep(worst))} ({f(EPS[worst], 2, True)})." if EPS[worst] < 0 else
              f"gains least in {esc(ep(worst))} ({f(EPS[worst], 2, True)}).")
           + " The largest single quarters are " + names_and([f"{q} ({f(v, 2, True)})" for q, v in big])
           + f"; over {FIRST}-{LAST} the total is {f(TOT_DIFF, 2, True)}.")
    body = f"""<p class="answer">{ans}</p>
{fig_title("Where the fit differs: log-likelihood contributions at the modes")}
{legend("lpd", [leg("re", name="RE, at the mode", width=3.2), leg("learn", name="Learning, at the mode", style="dashed"),
               leg("learn", name="Learning minus RE (middle and bottom)"), dict(name="Episode", color="axis", kind="band", op=0.6)])}
<div class="grid g-1w">{fig}</div>
{tables("lpd")}
{tbl}"""
    return section("fit", 5, "Where the fit differs", body)


def outside_runs(var, src, lo, hi, X):
    """Runs of consecutive quarters in which PH[(q, var, src, 'value')] lies outside [lo, hi]: (first, last, max |value|)."""
    qs = [q for q in X if (q, var, src, "value") in PH and not lo <= PH[(q, var, src, "value")] <= hi]
    runs = []
    for q in qs:
        if runs and qshift(runs[-1][-1], 1) == q:
            runs[-1].append(q)
        else:
            runs.append([q])
    return [(r[0], r[-1], max(abs(PH[(q, var, src, "value")]) for q in r), r) for r in runs]


def axis_cut_txt(var, lo, hi, X):
    """Caption text: the axis range and which quarters of which series it cuts off (from the data)."""
    parts = []
    for src, nm in (("mode", "the path at the mode"), ("calibrated", "the calibrated history")):
        runs = outside_runs(var, src, lo, hi, X)
        if runs:
            spans = names_and([(a if a == b else f"{a}-{b}") + f" (up to {m:.0f}%)" for a, b, m, _ in runs])
            bmax = max(PH.get((q, "beta", src, "value"), NAN) for *_, r in runs for q in r)
            parts.append(f"{nm} leaves it in {spans}, quarters in which its perceived persistence reaches {f(bmax, 3)}")
    return (f"the axis runs from {lo}% to {hi}%" + ("; " + "; ".join(parts) if parts else "; no quarter leaves it"))


def sec_paths_m():
    shades = [[a, b, n] for a, b, n, sh in EPIS if sh]
    panels = []
    for var, title in (("n2", "End-of-quarter share of learners (n2)"),
                       ("beta", "Perceived persistence of inflation (beta)"),
                       ("pmean", "Perceived mean inflation, % annualised"),
                       ("fRE", "RE agents' forecast of next quarter's inflation, made in t, % annualised"),
                       ("fBR", "Learners' forecast of next quarter's inflation, made in t, % annualised")):
        ser = [S("learn", pser(var, "mode", "value", QF), name="Learning, at the mode", short="Mode"),
               S("calib", pser(var, "calibrated", "value", QF), name="Calibrated history (a1_learn)", short="Calibrated")]
        kw = dict(shades=shades)
        if var == "pmean":
            kw["yticks"] = PMEAN_TICKS
        if var == "n2":
            kw.update(refs=[dict(y=0.5, label="")], yfix=True)
        panels.append((title, QF, ser, kw))
    cap = (f"Learning: filtered paths of the estimation at the learning mode. Calibrated: the engine's history of "
           f"{code('a1_learn')} (swX1 parameters, gain 0.0585, memory 0.6, intensity 0.51, RE-smoothed history, to the "
           f"{ORIGIN} origin). The perceived mean is 4 (alpha / (1 - beta) + steady-state inflation), % annualised; "
           f"{axis_cut_txt('pmean', PMEAN_TICKS[0], PMEAN_TICKS[-1], QF)}. The forecasts are those made in t of inflation "
           f"in t+1, plotted at t.")
    fig = stacked("pa", "Learners' share, beliefs and forecasts, " + f"{QF[0]}-{QF[-1]}", cap, panels, h=160)
    n2 = {q: PH[(q, "n2", "mode", "value")] for q in QF if (q, "n2", "mode", "value") in PH}
    avg = sum(n2.values()) / len(n2)
    cal = {q: PH[(q, "n2", "calibrated", "value")] for q in QF if (q, "n2", "calibrated", "value") in PH}
    cavg = sum(cal.values()) / len(cal)
    qmin, qmax = min(n2, key=n2.get), max(n2, key=n2.get)
    sd_m = (sum((v - avg) ** 2 for v in n2.values()) / len(n2)) ** 0.5
    sd_c = (sum((v - cavg) ** 2 for v in cal.values()) / len(cal)) ** 0.5

    def rmsgap(var):
        qs = [q for q in QF if (q, var, "mode", "value") in PH and (q, var, "calibrated", "value") in PH]
        return (sum((PH[(q, var, "mode", "value")] - PH[(q, var, "calibrated", "value")]) ** 2 for q in qs) / len(qs)) ** 0.5, qs

    gR, qs = rmsgap("fRE")
    gB, _ = rmsgap("fBR")
    b22 = PH[(ORIGIN, "beta", "mode", "value")]
    bc22 = PH[(ORIGIN, "beta", "calibrated", "value")]
    ans = (f"With the estimated intensity of choice the share of learners swings far more than in the calibrated history. "
           f"At the mode it averages {f(avg, 2)} over {QF[0]}-{QF[-1]} with a standard deviation of {f(sd_m, 2)}, between "
           f"{f(n2[qmin], 2)} ({qmin}) and {f(n2[qmax], 2)} ({qmax}); the calibrated history averages {f(cavg, 2)} with a "
           f"standard deviation of {f(sd_c, 3)}. The perceived persistence follows the data in both: at {ORIGIN} it is "
           f"{f(b22, 3)} at the mode and {f(bc22, 3)} in the calibrated history. The two groups' forecasts made at the mode "
           f"differ from the calibrated ones by {f(gR, 2)} pp (RE agents) and {f(gB, 2)} pp (learners), root mean square "
           f"over {qs[0]}-{qs[-1]}.")
    body = f"""<p class="answer">{ans}</p>
{fig_title("Learners' share, perceived persistence and mean, and the two forecasts, " + f"{QF[0]}-{QF[-1]}")}
{legend("pa", [leg("learn", name="Learning, at the mode"), leg("calib")])}
<div class="grid g-1w">{fig}</div>
{tables("pa")}"""
    return section("paths", 7, "Learners' share, beliefs and forecasts, 1966-2026", body)


def sec_surge_m():
    X = qrange("2019Q4", "2023Q4")
    data = [clean(PH.get((q, "pinfobs", "data", "value")), 3) for q in X]

    def fx(var, src):
        return [clean(PH.get((qshift(q, -1), var, src, "value")), 3) for q in X]

    ser = [S("data", data, name="Inflation (data)"),
           S("re", fx("fRE", "mode"), name="RE agents' forecast (mode)", short="RE agents"),
           S("learn", fx("fBR", "mode"), name="Learners' forecast (mode)", short="Learners"),
           S("re", fx("fRE", "calibrated"), name="RE agents' forecast (calibrated)", short="RE, cal.", style="dashed"),
           S("learn", fx("fBR", "calibrated"), name="Learners' forecast (calibrated)", short="Learners, cal.", style="dashed")]
    s2 = [S("learn", pser("n2", "mode", "value", X), name="Learning, at the mode (filter)", short="Filter"),
          S("calib", pser("n2", "calibrated", "value", X), name="Calibrated history (a1_learn)", short="Calibrated"),
          S("learn", [clean(AP.get(("e1_learn", "n2", q)), 4) for q in X], name="Engine inversion history at the mode",
            short="Inversion", style="dotted"),
          S("learn", [clean(AP.get(("e1_learn_smoothed", "n2", q)), 4) for q in X],
            name="Engine RE-smoothed history at the mode", short="Smoother", style="dashdot")]
    cap = (f"Top: inflation and the two groups' forecasts of it, at the learning mode and in the calibrated history, plotted "
           f"at the quarter they forecast (made one quarter earlier), % annualised; the calibrated history ends at the "
           f"{ORIGIN} origin. Bottom: the end-of-quarter share of learners from the estimation filter at the mode "
           f"(application 1 starts from it), the calibrated history, and the engine's inversion and RE-smoothed histories at "
           f"the learning mode (the sensitivity runs of application 1). The covid quarters {NANTXT} have no data.")
    fig = stacked("su", f"The 2021-22 surge, {X[0]}-{X[-1]}", cap,
                  [("Inflation and its forecasts, % annualised", X, ser, dict(h=230, dec=2)),
                   ("End-of-quarter share of learners (n2)", X, s2, dict(refs=[dict(y=0.5, label="")], yfix=True, h=150))],
                  h=170)
    ans = (f"At the learning mode the share fell while inflation rose: {f(n2m['2020Q4'], 2)} at the end of 2020Q4, "
           f"{f(N2_LOW, 2)} in {Q_LOW} and {f(N2_O['mode'], 2)} at the end of {ORIGIN}. The RE agents' forecasts tracked the "
           f"rise better ({f(FE_RE, 2)} pp RMS error over 2021Q1-{ORIGIN} against {f(FE_BR, 2)} pp for the learners), and "
           f"with an intensity of choice of {f(pv('chi', 'learn', 'mode'), 2)} the shares respond strongly to that "
           f"difference.")
    split, frag, stbl = surge_blocks()
    body = f"""<p class="answer">{ans}</p>
{split}
{fig_title(f"The surge close-up, {X[0]}-{X[-1]}")}
{legend("su", [leg("data", name="Inflation (data)"), leg("re", name="RE agents' forecast, at the mode"),
              leg("learn", name="Learners' forecast / share, at the mode"),
              leg("re", name="RE agents' forecast, calibrated", style="dashed"),
              leg("learn", name="Learners' forecast, calibrated", style="dashed"), leg("calib", name="Share, calibrated history"),
              leg("learn", name="Share, engine inversion history", style="dotted"),
              leg("learn", name="Share, engine RE-smoothed history", style="dashdot")])}
<div class="grid g-1w">{fig}</div>
{tables("su")}
{frag}
{stbl}"""
    return section("surge", 8, "The 2021-22 surge", body)


def sec_app1_m():
    X = Q18

    def a2s(var, model, stat):
        return [clean(A2.get((var, q, model, stat)), 4) for q in X]

    def var_panel(v):
        # data last, so it is drawn on top of the model lines (which equal it wherever there are data)
        return [S("re", a2s(v, "re", "mode"), name="RE estimate, at the mode", short="RE"),
                S("learn", a2s(v, "learn", "mode"), name="Learning estimate, at the mode", short="Learning"),
                S("data", a2s(v, "data", "value"), name=f"{VLAB[v]} (data)", short="Data")]

    sh = [S("learn", a2s("n2", "learn", "mode"), name="Learners' share, at the mode", short="Mode")]
    cap = (f"Top: inflation (data) and the forecasts from the {ORIGIN} origin, {HZL}, at the two modes; % annualised. Up to "
           f"{ORIGIN} the model lines are each filter's estimate of the observables: equal to the data where there are data, "
           f"the filter's prediction in {NANTXT}. Bottom: the learners' share at the end of each quarter, from the "
           f"likelihood's filter up to {ORIGIN} and from the forecast after it. The shaded area is the forecast.")
    fig = stacked("a1p", f"Application 1 from the estimated models' own state, {X[0]}-{X[-1]}", cap,
                  [("Inflation, % annualised", X, var_panel("pinfobs"), dict(origin=ORIGIN, h=240, dec=2)),
                   ("Learners' share at the end of the quarter (n2)", X, sh,
                    dict(origin=ORIGIN, h=150, refs=[dict(y=0.5, label="")], yfix=True))], h=170)
    others = []
    for v in ("robs", "dy", "dc"):
        a, r = AVP[("learn", v)], AVP[("re", v)]
        cp = f"Average {HZL}: learning {pct(a['mode'])}, RE {pct(r['mode'])}, at the modes."
        others.append(line(f"a1p-{v}", "a1q", f"{VLAB[v]}, % annualised", cp, X, var_panel(v), origin=ORIGIN, dec=2,
                           endLabels=False, h=200))
    rows = []
    for v in VAR4:
        a, r = AVP[("learn", v)], AVP[("re", v)]
        rows.append([VLAB[v], pct(r["mode"]), pct(a["mode"]), pp(a["mode"] - r["mode"]), pct(AV[("a1_re", v)]),
                     pct(AV[("a1_learn", v)])])
    tbl = html_table(["Average " + HZL, "RE mode", "Learning mode", "Learning minus RE", "Calibrated RE (a1_re)",
                      "Calibrated learning (a1_learn)"], rows, num_from=1, caption=f"Averages over {HZL}, % annualised")
    gap = APL["mode"] - APR["mode"]
    crp = pv("crhopinf", "re", "mode")
    ans = (f"Started from what each estimated model says about {ORIGIN}, average inflation over {HZL} is {pct(APL['mode'])} "
           f"at the learning mode and {pct(APR['mode'])} at the RE mode: learning minus RE is {pp(gap)}. The calibrated runs "
           f"of the main report give {pct(CAL1['learn'])} and {pct(CAL1['re'])}. The learners' share at the origin is "
           f"{f(N2P['mode'], 2)} at the mode; in the calibrated history it is {f(N2_O['cal'], 2)}.")
    retail = (f"<p>The RE comparison here is at the RE mode, which sits in the tail of the converged RE posterior: "
              f"{code('crhopinf')} is {f(crp, 3)} at the mode against a posterior mean of {f(REPM['crp'], 3)}, and over "
              f"{REPM['n']} draws of that posterior average inflation {HZL} has a median of {pct(REPM['med'])} (90% band "
              f"{pct(REPM['p05'])}-{pct(REPM['p95'])}) against {pct(APR['mode'])} at the mode. The learning model's "
              f"posterior is not shown because its chains are paused.</p>")
    why = (f"<p>Both forecasts start from the likelihood's own filtered state at {ORIGIN} (data after {ORIGIN} play no part) "
           f"and run {len(HZ)} quarters with zero shocks: each quarter the actual law of motion in force (beliefs and model "
           f"shares from the end of the previous quarter), the RE and learners' forecasts, errors, fitness and shares from the "
           f"simulated inflation, the constant-gain update and the projection facility, as in the engine's forecast stage "
           f"(gate G8: {code('hlest.forecast_learn')} and {code('hlest.forecast_re')} reproduce the engine's forecast to "
           f"2e-12 from the same origin state)."
           + (f" The RE path is the higher one: the RE mode's price mark-up is close to a unit root ({code('crhopinf')} "
              f"{f(crp, 3)}, Hessian sd {f(pv('crhopinf', 're', 'sd_hessian'), 3)})." if APR["mode"] > APL["mode"] else "")
           + ((f" At the learning mode the price mark-up is less persistent ({code('crhopinf')} "
               f"{f(pv('crhopinf', 'learn', 'mode'), 3)}) and part of the persistence comes from the beliefs, whose "
               f"perceived persistence at the end of {ORIGIN} is {f(PH[(ORIGIN, 'beta', 'mode', 'value')], 3)}.")
              if pv("crhopinf", "learn", "mode") < crp else "")
           + "</p>")
    body = f"""<p class="answer">{ans}</p>
{retail}
{why}
{fig_title(f"Application 1 consistent with the likelihood, at the modes, {X[0]}-{X[-1]}. The shaded area is the forecast")}
{legend("a1p", [leg("data", name="Data"), leg("re", name="RE estimate, at the mode"), leg("learn", name="Learning estimate, at the mode")])}
<div class="grid g-1w">{fig}</div>
<div class="grid g-3">{"".join(others)}</div>
{tables("a1p")}
{tables("a1q", "Table view: policy rate, output and consumption growth")}
{tbl}
{app1_engine_sens()}"""
    return section("app1", 10, "Application 1 at the modes", body)


def sec_diag_m():
    est, live, _notes, _lh = parse_gates(gates_txt)
    # G6 validates the sampler and the MDD estimators on a Gaussian target: its numbers concern the chains, not the modes.
    # G7's log line calls the inverse-Hessian sd at the RE mode a "posterior sd" (est_01_mode_re): at the modes, say so.
    ovr = {"G6": "the sampler and the marginal-likelihood estimators on a 39-dimensional Gaussian target "
                 "(results/estimation/gates.txt); it matters once the chains resume"}
    g7 = "G7" in est and "posterior sd" in est["G7"][1]
    if g7:
        ovr["G7"] = est["G7"][1].replace("posterior sd", "Hessian sd")
    gt, g4note, live_txt = gates_blocks(ovr)
    if g7:
        gt += ("<p class=\"small\">The sds in G7 are Hessian sds: the square roots of the diagonal of the inverse Hessian at "
               "the RE mode (est_01_mode_re). The gate's line in gates.txt words this differently.</p>")
    all_pass = all(st == "PASS" for st, _tx, _d in est.values())
    live_ok = bool(live) and all(st == "PASS" for _g, st, _t, _d in live)
    names = {"re": "RE", "learn": "Learning, 'lagged' (baseline)", "learn_current": "Learning, 'current'",
             "learn_calib": "Learning, priors centred on the calibration"}
    mrows = []
    for k, nm in names.items():
        ev = dgt(k, "mode", "", "mode_events_plm") if (k, "mode", "", "mode_events_plm") in DG else ""
        mrows.append([nm, str(NSTART[k]), f"{NREACH[k]} of {NSTART[k]}", f(md(k, "log_posterior_at_mode"), 3),
                      ("yes" if dg(k, "mode", "", "hessian_pd") == 1 else "no") + f" ({esc(dgt(k, 'mode', '', 'hessian_pd'))})",
                      esc(evfmt(ev)) if k != "re" else "no learning"])
    mtbl = html_table(["Model", "Starts", "Reached the mode", "Log posterior at the mode", "Hessian positive definite",
                       "Facility events at the mode"], mrows, num_from=1)
    det = "; ".join(f"{names[k]}: {esc(dgt(k, 'mode', '', 'mode_starts_reached'))}" for k in MODEL_KEYS)
    vev = "; ".join(f"{nm}: {esc(evfmt(dgt(k, 'baseline_mode', '', 'events')))}" for k, nm in
                    (("learn_fixed_beliefs", "fixed initial beliefs"), ("learn_freeze", "'freeze'")))
    same = all(dgt(k, "baseline_mode", "", "events") == dgt("learn", "mode", "", "mode_events_plm")
               for k in ("learn_fixed_beliefs", "learn_freeze"))
    fac = (f"Projection facility at the modes: PLM-block events (the candidate beliefs have a root above 1 and the previous "
           f"ones are kept) as listed in the table{'; no ALM reverts and no kept shares at any mode' if NO_ALM else ''}. At "
           f"the baseline mode the two variants have {'the same events as the baseline' if same else 'these events'} "
           f"({vev}).")
    crows = []
    for st, nm, folder, resume in (("re", "RE", "re/chains", "done; not used on this page"),
                                   ("stage1", "Learning, stage 1", "learn/chains", PAUSE.get("resume_stage1", "")),
                                   ("stage2", "Learning, stage 2", "learn/chains2", PAUSE.get("resume_stage2", ""))):
        lst = CHS.get(st, [])
        if lst:
            crows.append([nm, code(folder), str(len(lst)), ", ".join(num(d["n"]) for d in lst), num(lst[0]["target"]),
                          esc(resume)])
    ctbl = html_table(["Chains", "Folder", "Number", "Draws in complete blocks, by chain", "Target", "To resume"], crows,
                      num_from=2)
    ptxt = (f"<b>The MCMC is paused.</b> It was paused by {esc(PAUSE.get('by', 'the user'))}. Every chain is kept unchanged "
            f"and resumes from the end of its last complete block; a chain's {code('progress.txt')} still says "
            f"{code('running')}. After the chains: {esc(PAUSE.get('then', ''))}.")
    ans = (f"Every mode search reached its mode: {NREACH['learn']} of {NSTART['learn']} starts for the learning model, "
           f"{NREACH['learn_current']} of {NSTART['learn_current']} for 'current', {NREACH['learn_calib']} of "
           f"{NSTART['learn_calib']} for 'calib'; the RE mode comes from one search from swX1. Every Hessian is positive "
           f"definite. " + ("All gates pass" if all_pass else "Not all gates pass")
           + (", and the live toolbox check passes too." if live_ok else ".") + " The MCMC is paused (below).")
    body = f"""<p class="answer">{ans}</p>
{mtbl}
<p class="small">{det}.</p>
<p>{fac}</p>
<h3 class="sub">MCMC: paused</h3>
<p>{ptxt}</p>
{ctbl}
<h3 class="sub">Validation gates</h3>
{g4note}
{gt}
{live_txt}"""
    return section("diagnostics", 11, "Diagnostics", body)


def sec_caveats_m():
    il = IDM["chi"]
    crp, crs = pv("crhopinf", "re", "mode"), pv("crhopinf", "re", "sd_hessian")
    items = [("<b>Modes only.</b> The MCMC is paused, so this page has no posterior means or bands. The standard deviations "
              "are the inverse Hessian at each mode and the marginal likelihoods are Laplace approximations. The learning "
              "likelihood is only piecewise smooth (the projection facility switches on and off between nearby parameter "
              "values), so its Hessian is a local measure."),
             (f"<b>No survey expectations.</b> The data do not narrow the intensity of choice at the mode (Hessian sd "
              f"{f(il['s'], 2)} against a prior sd of {f(il['ps'], 2)}). IJCB pinned it at "
              f"{f(pv('chi', 'ijcb_survey', 'mean'), 2)} with survey data. Next: add the SPF one-quarter-ahead inflation "
              f"expectation as an eighth observable with a measurement error, as IJCB eq. 22."),
             ("<b>No lower bound.</b> The policy rate sits at its floor in 2009-15 and 2020-21 in both models, and the "
              "learning model may use beliefs to absorb those years. A cheap variant: treat the rate as missing in the "
              "lower-bound quarters, so both filters work with a shadow rate."),
             (f"<b>Variants.</b> The 'current' mode comes from {NSTART['learn_current']} starts and the 'calib' mode from "
              f"{NSTART['learn_calib']}. Fixed initial beliefs and 'freeze' in the covid gap are evaluated at the baseline "
              f"mode only, as likelihoods."),
             (f"<b>History method.</b> The share path depends on how the covid gap is bridged: at the learning mode the share "
              f"at {ORIGIN} ranges from {f(SN2_LO, 2)} to {f(SN2_HI, 2)} across five histories (the estimation filter "
              f"{f(SN2['filter'], 2)}, the engine's inversion {f(SN2['inversion'], 2)}). Application 1 starts from the "
              f"likelihood's filter; the engine's histories are a sensitivity check."),
             (f"<b>RE mode near a unit root.</b> The RE mode has {code('crhopinf')} {f(crp, 3)} with a Hessian sd of "
              f"{f(crs, 3)}, in the tail of the converged RE posterior (posterior mean {f(REPM['crp'], 3)}). The application "
              f"1 forecast at the RE mode inherits that persistence: {pct(APR['mode'])} average inflation against a median "
              f"of {pct(REPM['med'])} over the RE posterior."),
             ("<b>Gate G4 changed after the first run.</b> The design's decay criterion could not hold for SW07: four "
              "observables are first differences, so the filter's state uncertainty does not collapse and a filter "
              "started from the stochastic initial condition keeps a permanent distance from the inversion. The gate now "
              "starts the filter from the engine's own 1965Q4 state with zero uncertainty, where the two must agree "
              "exactly, and reports the stochastic-start distances as information.")]
    nxt = (f"<b>Next.</b> If the modes look right: resume the chains ({code('est_05_mcmc_learn(k, 75000)')} for stage 1 and "
           f"{code('est_07_mcmc_stage2(k, 40000)')} for stage 2, k = 1..6), then {code('est_gonogo2')}, "
           f"{code('est_06_post(' + chr(39) + 'final' + chr(39) + ')')} and this builder for posterior means and bands. "
           "<b>To adopt estimation in the main toolbox:</b> (1) final chains that pass est_gonogo2; (2) the user's approval "
           "for model packages with parameters estimated here (the packaging rule of 2026-10-18); (3) a parameter override "
           f"in {code('hetlearn.load_model')}, which would make the copies in {code('estimation/models/')} unnecessary; (4) "
           f"{code('hetlearn.re_filter')} returning the RE log likelihood; (5) the learning filter as an engine function, "
           "tied to the inversion by gate G4, with tests; (6) the gates in the test suite and step 8 in the run order.")
    body = ('<ul class="cav">' + "".join(f"<li>{t}</li>" for t in items) + "</ul>"
            f'<div class="box next"><p>{nxt}</p></div>')
    return section("caveats", 12, "Caveats and next steps", body)


# ============================================================================= assemble
if MODES:
    PARTS = [sec_summary_m(), sec_setup_m(), sec_params_m(), sec_priorpost_m(), sec_mdd_m(), sec_lpd_m(), sec_rmse(),
             sec_paths_m(), sec_surge_m(), sec_irfs(), sec_app1_m(), sec_diag_m(), sec_caveats_m()]
    st_txt = "Posterior modes only"
    meta_extra = "<span>MCMC paused</span>"
    lede_tail = ", at the posterior modes"
else:
    PARTS = [sec_summary(), sec_setup(), sec_params(), sec_priorpost(), sec_mdd(), sec_lpd(), sec_rmse(), sec_paths(),
             sec_surge(), sec_irfs(), sec_app1(), sec_diag(), sec_caveats()]
    st_txt = (f"Interim: {num(LDRAWS)} learning draws" if INTERIM else f"Final: {num(LDRAWS)} learning draws")
    meta_extra = f"<span>RE: {NCH_R} chains x {num(RPER[0])}</span>"
    lede_tail = ""
toc = "".join(f'<a href="#{sid}"><span class="tn">{no}</span> {esc(t)}</a>' for sid, no, t in SEC)
body = f"""
<header class="top wrap">
  <p class="kicker">hetlearn estimation report · {REPORT_DATE}</p>
  <h1>Estimating SW07 with inflation learners</h1>
  <p class="lede">Bayesian estimates of the Smets-Wouters (2007) model under rational expectations and with the
  a1_learn learning block (anchored RE agents and AR(1) inflation learners whose shares switch on past forecast errors),
  on US data {FIRST}-{LAST}{lede_tail}. This report is separate from the main hetlearn report, which keeps the swX1 parameters
  (the project's Dynare re-estimation on 1966-2026, covid quarters kept).</p>
  <p class="meta"><span>{CREATED}</span><span>{st_txt}</span>{meta_extra}
  <span>Inputs: results/estimation/tables/</span></p>
  <nav class="toc" aria-label="Sections">{toc}</nav>
</header>
<main class="wrap">
{"".join(PARTS)}
<footer class="foot"><p>Built by <code>reports/build_estimation_report.py</code> from <code>results/estimation/tables/</code>
(written by <code>estimation/est_06_post.m</code>, status {esc(STATUS)}, {CREATED}) and <code>results/estimation/gates.txt</code>.
Charts: hover or focus a chart (arrow keys move along it) for values; most charts have a table view.</p></footer>
</main>
"""


def check_specs():
    bad = []
    for k, c in CHARTS.items():
        sers = c.get("series") or []
        if not sers or not any(v is not None for s in sers for v in s["v"]):
            bad.append(k)
        if c.get("type") == "dots":
            continue
        for s in sers:
            if len(s["v"]) != len(c.get("x", s["v"])):
                bad.append(k + " (length)")
        for b in c.get("bands") or []:
            if len(b["lo"]) != len(c["x"]) or len(b["hi"]) != len(c["x"]):
                bad.append(k + " (band length)")
    if bad:
        raise SystemExit(f"charts without data: {bad}")


check_specs()
data_json = json.dumps({"charts": CHARTS, "legends": LEGENDS}, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
data_json = data_json.replace("</", "<\\/")
page = ('<meta charset="utf-8">\n'
        "<title>SW07 estimation report</title>\n"
        f'<link rel="stylesheet" href="{FONTS}">\n'
        f"<style>{CSS}{CSS_EXTRA}{CSS_EST}</style>\n"
        f"{body}\n"
        f'<script type="application/json" id="report-data">{data_json}</script>\n'
        f"<script>{JS}</script>\n")
if "—" in page:
    raise SystemExit("em dash in the page")
OUT.write_text(page, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB), {len(CHARTS)} charts, {FIGN[0]} figures, status {STATUS}, "
      f"{LDRAWS} learning draws")
