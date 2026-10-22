"""Figures, tables and figure notes for the hetlearn paper (Computational Economics), SW07 results.

Reads only the CSVs of results/summary_v3/ (the 2026-10-21 baseline: published SW07 parameters, AR(1)
learners with the KOZ gain, RE agents and learners on t-1 information, filtered RE history, facility 'alm').
Nothing is re-run.

Writes
  paper/figures/fig_app1.{pdf,png}     Application 1: forecast from the 2022Q2 peak + learners' share
  paper/figures/fig_history.{pdf,png}  learners' share and perceived persistence, 1966-2026
  paper/figures/fig_app3.{pdf,png}     Application 3: policy 100 bp looser / tighter, effects and asymmetry
  paper/figures/fig_app4.{pdf,png}     Application 4: Ramsey vs the Taylor rule, RE and learning
  paper/figures/fig_density.{pdf,png}  Application 5: 90% bands, mark-up and demand shocks
  paper/figures/fig_plm.{pdf,png}      AR(1) vs AR(2) and VAR(1) learners
  paper/tables/tab_app1.tex, tab_app3.tex, tab_app4.tex, tab_plm.tex   (booktabs)
  paper/figures/FIGURE_NOTES.txt       what each figure shows and its key numbers

A figure whose input series is missing is skipped with a message naming the series; the others are made.
Run from any folder:  python paper/figures/make_figures.py
"""
import math
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.gridspec import GridSpec  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SUM = ROOT / "results" / "summary_v3"
FIGDIR = HERE
TABDIR = ROOT / "paper" / "tables"
TABDIR.mkdir(parents=True, exist_ok=True)


class Missing(Exception):
    """A series a figure or table needs is not in the CSVs."""


# =============================================================================== inputs (CSVs only)
paths = pd.read_csv(SUM / "paths_long.csv")
learn = pd.read_csv(SUM / "learning_long.csv")
learn = learn[learn.variable == "pinf"]          # every figure uses the inflation learners only
a3 = pd.read_csv(SUM / "app3_policy.csv")
a4 = pd.read_csv(SUM / "app4_losses.csv")
a4t = pd.read_csv(SUM / "app4_targets_long.csv")
dens = pd.read_csv(SUM / "app5_density.csv")
wid = pd.read_csv(SUM / "app5_widths.csv")
scen = pd.read_csv(SUM / "scenarios.csv").set_index("id")
kn = pd.read_csv(SUM / "key_numbers.csv")
KN = dict(zip(kn.name, kn.value))


def K(name):
    if name not in KN:
        raise Missing(f"key_numbers.csv: {name}")
    return float(KN[name])


def qx(q):
    """'2022Q2' -> 2022.25 (start of the quarter)."""
    return int(q[:4]) + (int(q[-1]) - 1) / 4


def qrange(a, b):
    y, q = int(a[:4]), int(a[-1])
    out = []
    while f"{y}Q{q}" <= b:
        out.append(f"{y}Q{q}")
        q += 1
        if q == 5:
            y, q = y + 1, 1
    return out


def _cut(s, a, b):
    if a:
        s = s[s.index >= a]
    if b:
        s = s[s.index <= b]
    return s


def pser(sc, var, a=None, b=None, cover=True):
    """A path from paths_long.csv as a Series indexed by quarter; Missing if absent or incomplete."""
    d = paths[(paths.scenario == sc) & (paths.variable == var)]
    if d.empty:
        raise Missing(f"paths_long.csv: scenario {sc}, variable {var}")
    s = _cut(d.drop_duplicates("date").set_index("date").value.sort_index(), a, b)
    if cover and a and b:
        miss = [q for q in qrange(a, b) if q not in s.index]
        if miss:
            raise Missing(f"paths_long.csv: scenario {sc}, variable {var}, quarters {miss[0]}-{miss[-1]}")
    return s


def lser(sc, field, a=None, b=None, stage=None, cover=True):
    """A learning field of the inflation learners (learning_long.csv) as a Series indexed by quarter."""
    d = learn[(learn.scenario == sc) & (learn.field == field)]
    if stage:
        d = d[d.stage == stage]
    if d.empty:
        raise Missing(f"learning_long.csv: scenario {sc}, variable pinf, field {field}" + (f", stage {stage}" if stage else ""))
    s = _cut(d.drop_duplicates("date").set_index("date").value.sort_index(), a, b)
    if cover and a and b:
        miss = [q for q in qrange(a, b) if q not in s.index]
        if miss:
            raise Missing(f"learning_long.csv: scenario {sc}, field {field}, quarters {miss[0]}-{miss[-1]}")
    return s


# ---------------------------------------------------------------------------- dates of the baseline
ORIGIN = paths[(paths.scenario == "a1_learn") & (paths.stage == "history")].date.max()      # 2022Q2
HOR = sorted(paths[(paths.scenario == "a1_learn") & (paths.stage == "forecast")].date.unique())
END = HOR[-1]                                                                               # 2026Q2
NH = len(HOR)
FIRST = learn[learn.scenario == "a1_learn"].date.min()                                      # 1966Q1
VAR4 = ["pinfobs", "robs", "dy", "dc"]

# ================================================================================ style
TEXTW = 16 / 2.54            # 16 cm text width, inches
INK, INK2, GRIDC, ZEROC, SHADE = "#000000", "#333333", "#dddddd", "#8c8c8c", "#ececec"
# Okabe-Ito colours (safe for the common colour-vision deficiencies); greyscale is carried by the line styles
COL = dict(data="#000000", re="#0072B2", learn="#D55E00", ar2="#009E73", var3="#CC79A7", var12="#E69F00")
DASH = (0, (4.0, 1.8))
STYLE = {
    "data": dict(color=COL["data"], ls="-", lw=0.75, marker="o", ms=1.9, mew=0, zorder=3, label="Data"),
    "re": dict(color=COL["re"], ls=DASH, lw=1.35, zorder=4, label="RE benchmark"),
    "learn": dict(color=COL["learn"], ls="-", lw=1.6, zorder=5, label="Learning (AR(1) learners, baseline)"),
    "ar2": dict(color=COL["ar2"], ls=(0, (5.0, 1.4, 1.2, 1.4)), lw=1.3, zorder=6, label="AR(2) learners"),
    "var3": dict(color=COL["var3"], ls=(0, (1.0, 1.1)), lw=1.7, zorder=6,
                 label="VAR(1) learners: inflation, output gap, rate"),
    "var12": dict(color=COL["var12"], ls=(0, (6.0, 2.0)), lw=1.1, marker="^", ms=2.8, mfc="white", mew=0.7,
                  markevery=2, zorder=6, label="VAR(1) learners: 12 forward-looking variables"),
}
ND = "–"                # en dash for date ranges in figure text
plt.rcParams.update({
    "font.family": "serif", "font.serif": ["Times New Roman", "STIXGeneral", "DejaVu Serif"],
    "mathtext.fontset": "stix", "font.size": 8, "axes.titlesize": 9, "axes.labelsize": 8,
    "xtick.labelsize": 8, "ytick.labelsize": 8, "legend.fontsize": 8, "axes.titlelocation": "left",
    "axes.titlepad": 3.5, "axes.linewidth": 0.6, "axes.edgecolor": INK2, "axes.labelcolor": INK,
    "xtick.color": INK, "ytick.color": INK, "xtick.major.width": 0.6, "ytick.major.width": 0.6,
    "xtick.minor.width": 0.4, "xtick.major.size": 2.8, "ytick.major.size": 2.8, "xtick.minor.size": 1.6,
    "axes.spines.top": False, "axes.spines.right": False, "legend.frameon": False,
    "legend.handlelength": 3.0, "legend.columnspacing": 1.4, "legend.handletextpad": 0.5,
    "hatch.linewidth": 0.5, "pdf.fonttype": 42, "ps.fonttype": 42, "savefig.dpi": 600,
    "figure.dpi": 100, "lines.solid_capstyle": "butt", "lines.dash_capstyle": "butt",
})

TITLE = {"pinfobs": "Inflation (GDP deflator)", "robs": "Policy rate (federal funds rate)",
         "dy": "Output growth (per capita)", "dc": "Consumption growth (per capita)"}
UNIT = {"pinfobs": "% q/q, annualised", "robs": "% annualised", "dy": "% q/q, annualised",
        "dc": "% q/q, annualised"}


def plot(ax, s, key, **kw):
    st = {k: v for k, v in STYLE[key].items() if k != "label"}
    st.update(kw)
    ax.plot([qx(q) for q in s.index], np.asarray(s.values, dtype=float), **st)


def handle(key, label=None, **kw):
    st = {k: v for k, v in STYLE[key].items() if k not in ("label", "zorder")}
    st.update(kw)
    st.pop("markevery", None)
    if "marker" in st and "ms" in st:
        st["markersize"] = st.pop("ms") * 1.3
    return Line2D([], [], label=label or STYLE[key]["label"], **st)


def axes_style(ax, zero=True):
    ax.grid(axis="y", color=GRIDC, lw=0.4)
    ax.set_axisbelow(True)
    lo, hi = ax.get_ylim()
    if zero and lo < 0 < hi:
        ax.axhline(0, color=ZEROC, lw=0.5, zorder=1)


def date_axis(ax, a, b, step=1, minor=True, pad=0.12):
    ax.set_xlim(qx(a) - pad, qx(b) + pad)
    y0 = int(a[:4]) if a.endswith("Q1") else int(a[:4]) + 1
    y0 = -(-y0 // step) * step                  # first multiple of the step (1970, 1975, ... for step 5)
    yrs = list(range(y0, int(b[:4]) + 1, step))
    ax.set_xticks(yrs)
    ax.set_xticklabels([str(y) for y in yrs])
    if minor:
        ax.set_xticks([qx(q) for q in qrange(a, b)], minor=True)


def shade(ax, a, b, color=SHADE, centred=False):
    """Shade quarters a..b: from the point a to one quarter after b, or centred on the points (centred=True)."""
    if centred:
        ax.axvspan(qx(a) - 0.125, qx(b) + 0.125, color=color, lw=0, zorder=0)
    else:
        ax.axvspan(qx(a), qx(b) + 0.25, color=color, lw=0, zorder=0)


def save(fig, name):
    fig.savefig(FIGDIR / f"{name}.pdf")
    fig.savefig(FIGDIR / f"{name}.png", dpi=600)
    plt.close(fig)


def fmt(x, d=2):
    return f"{x:.{d}f}"


def pct(x, d=2):
    return f"{x:.{d}f}%"


def pp(x, d=2):
    return f"{x:+.{d}f} pp"


def tex(x, d=2, sign=False):
    """A number for LaTeX: true minus sign."""
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "--"
    s = f"{x:+.{d}f}" if sign else f"{x:.{d}f}"
    return s.replace("-", "$-$") if s.startswith("-") else s


def avg(s, a, b):
    return float(_cut(s, a, b).mean())


def argmax_abs(s):
    q = s.abs().idxmax()
    return q, float(s[q])


def check(name, value, tol=1e-6):
    """Cross-check a computed number against key_numbers.csv (when the key exists)."""
    if name in KN and not (math.isnan(KN[name]) and math.isnan(value)):
        if abs(float(KN[name]) - value) > tol * max(1.0, abs(value)):
            print(f"  WARNING: {name}: computed {value} vs key_numbers.csv {KN[name]}")


NOTES = {}      # figure/table name -> list of note lines
TABLES = []

# ================================================================================ figure: application 1


def fig_app1():
    re_, le, X0 = "a1_re", "a1_learn", "2018Q1"
    D = {v: pser("data", v, X0, END) for v in VAR4}
    R = {v: pser(re_, v, ORIGIN, END) for v in VAR4}
    Lg = {v: pser(le, v, ORIGIN, END) for v in VAR4}
    n2 = lser(le, "n2", X0, END)

    fig = plt.figure(figsize=(TEXTW, 5.55))
    gs = GridSpec(3, 2, figure=fig, height_ratios=[1, 1, 0.72], left=0.083, right=0.988, top=0.905,
                  bottom=0.048, hspace=0.55, wspace=0.26)
    axes = [fig.add_subplot(gs[i // 2, i % 2]) for i in range(4)]
    for k, (ax, v) in enumerate(zip(axes, VAR4)):
        shade(ax, ORIGIN, END)
        plot(ax, D[v], "data")
        plot(ax, R[v], "re")
        plot(ax, Lg[v], "learn")
        ax.set_title(f"({'abcd'[k]}) {TITLE[v]}")
        ax.set_ylabel(UNIT[v])
        date_axis(ax, X0, END)
        axes_style(ax)
    axs = fig.add_subplot(gs[2, :])
    shade(axs, ORIGIN, END)
    axs.axhline(0.5, color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), zorder=1)
    plot(axs, n2, "learn")
    axs.set_title("(e) Learners' share of inflation expectations, end of quarter ($n_2$)")
    axs.set_ylabel("share of agents")
    date_axis(axs, X0, END)
    lo, hi = float(n2.min()), float(n2.max())
    axs.set_ylim(min(lo, 0.5) - 0.03, max(hi, 0.5) + 0.03)
    axes_style(axs, zero=False)
    hs = [handle("data"), handle("re", "RE benchmark (all agents RE)"),
          handle("learn", "Learning (RE agents and AR(1) learners)"),
          Patch(facecolor=SHADE, edgecolor="none", label="Forecast, zero shocks"),
          Line2D([], [], color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), label="Share 0.5")]
    fig.legend(handles=hs, loc="upper center", bbox_to_anchor=(0.5, 0.995), ncol=3, borderaxespad=0.2)
    save(fig, "fig_app1")

    # ---- notes
    al, ar_ = avg(Lg["pinfobs"], HOR[0], END), avg(R["pinfobs"], HOR[0], END)
    check("avg_pinfobs__a1_learn", al)
    check("avg_pinfobs__a1_re", ar_)
    gap = (Lg["pinfobs"] - R["pinfobs"]).loc[HOR]
    qg = gap.idxmax()
    neg = [q for q in HOR if gap[q] < 0]
    nf = n2.loc[HOR]
    qn = nf.idxmax()
    D_avg = {v: avg(D[v], HOR[0], END) for v in VAR4}
    NOTES["fig_app1"] = [
        f"Shows: unconditional forecast (zero future shocks) from the {ORIGIN} inflation peak, {HOR[0]}-{END}, "
        f"for the RE benchmark (a1_re: every agent rational, RE information t-1) and the learning economy "
        f"(a1_learn: anchored RE agents and AR(1) learners on inflation expectations, switching shares). "
        f"Panels a-d: inflation, policy rate, output and consumption growth, {X0}-{END}, with the data; "
        f"the forecast is shaded and the model lines start at the {ORIGIN} value. Panel e: the learners' "
        f"end-of-quarter share n2 (it is the share in force in the next quarter, n2_model). The data line has "
        f"a gap in 2020Q1-2020Q3 (covid quarters treated as missing).",
        f"Average inflation {HOR[0]}-{END}: learning {pct(al)}, RE {pct(ar_)} (+{fmt(al - ar_)} pp); data "
        f"{pct(D_avg['pinfobs'])}.",
        f"Inflation gap learning - RE peaks at {pp(float(gap[qg]))} in {qg}; learning inflation falls below RE "
        f"from {neg[0]} ({END}: {pct(float(Lg['pinfobs'][END]))} vs {pct(float(R['pinfobs'][END]))})."
        if neg else f"Inflation gap learning - RE peaks at {pp(float(gap[qg]))} in {qg} and stays positive.",
        f"Policy rate average {pct(avg(Lg['robs'], HOR[0], END))} learning vs {pct(avg(R['robs'], HOR[0], END))} "
        f"RE; output growth {pct(avg(Lg['dy'], HOR[0], END))} vs {pct(avg(R['dy'], HOR[0], END))}; consumption "
        f"growth {pct(avg(Lg['dc'], HOR[0], END))} vs {pct(avg(R['dc'], HOR[0], END))}.",
        f"Learners' share n2: {fmt(float(n2['2021Q2']), 3)} at the end of 2021Q2, {fmt(float(n2[ORIGIN]), 3)} at the "
        f"end of {ORIGIN}; in the forecast it peaks at {fmt(float(nf[qn]), 3)} ({qn}) and is "
        f"{fmt(float(nf[END]), 3)} in {END}.",
        f"Learners' AR(1) coefficient at the origin: beta = {fmt(K('a1_beta_origin'), 3)} (above 1, so the "
        f"perceived law of motion is explosive and has no finite perceived mean). The projection facility "
        f"('alm') never acts in a1_learn ({int(scen.loc['a1_learn', 'n_events'])} engine events).",
    ]


# ================================================================================ figure: history


def fig_history():
    hid, le = "a6_smooth_learn", "a1_learn"
    n2h = lser(hid, "n2", FIRST, END, stage="history")
    bh = lser(hid, "beta_pinf", FIRST, END, stage="history")
    n2a = lser(le, "n2", FIRST, END)
    ba = lser(le, "beta_pinf", FIRST, END)
    # a6_smooth_learn is a1_learn with the origin moved to 2026Q2: the two must agree through 2022Q2
    d_n2 = float((n2h.loc[:ORIGIN] - n2a.loc[:ORIGIN]).abs().max())
    d_b = float((bh.loc[:ORIGIN] - ba.loc[:ORIGIN]).abs().max())
    fn2, fb = n2a.loc[ORIGIN:END], ba.loc[ORIGIN:END]

    fig, (a1, a2) = plt.subplots(2, 1, figsize=(TEXTW, 3.95), sharex=True,
                                 gridspec_kw=dict(left=0.083, right=0.988, top=0.865, bottom=0.075, hspace=0.36))
    fc_kw = dict(ls=(0, (3.0, 1.2, 1.0, 1.2)), lw=1.0, zorder=6, color=COL["learn"])
    for ax, h, f_, ref in ((a1, n2h, fn2, 0.5), (a2, bh, fb, 1.0)):
        ax.axvline(qx(ORIGIN), color=INK2, lw=0.5, ls=(0, (2, 2)), zorder=2)
        ax.axhline(ref, color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), zorder=1)
        plot(ax, h, "learn", lw=0.9)
        ax.plot([qx(q) for q in f_.index], f_.values, **fc_kw)
        axes_style(ax, zero=False)
    a1.set_title("(a) Learners' share of inflation expectations, end of quarter ($n_2$)")
    a1.set_ylabel("share of agents")
    a2.set_title(r"(b) Perceived persistence: AR(1) coefficient $\beta$ of the learners' inflation PLM")
    a2.set_ylabel(r"$\beta$")
    date_axis(a2, FIRST, END, step=5, minor=False, pad=0.4)
    a2.set_xticks(list(range(1966, 2027)), minor=True)
    hs = [handle("learn", f"Learning on the RE-filtered history, {FIRST}{ND}{END}", lw=0.9),
          Line2D([], [], label=f"Application 1 forecast from {ORIGIN} (zero shocks)", **{k: v for k, v in fc_kw.items() if k != "zorder"}),
          Line2D([], [], color=INK2, lw=0.5, ls=(0, (2, 2)), label=f"{ORIGIN}: origin of Application 1"),
          Line2D([], [], color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), label=r"Reference: share 0.5, $\beta$ = 1")]
    fig.legend(handles=hs, loc="upper center", bbox_to_anchor=(0.5, 0.998), ncol=2, borderaxespad=0.2)
    save(fig, "fig_history")

    # ---- notes
    hh = n2h.loc[:ORIGIN]
    bb = bh.loc[:ORIGIN]
    post = n2h.loc[HOR]
    check("a1_n2_hist_mean", float(hh.mean()))
    check("a1_n2_hist_min", float(hh.min()))
    check("a1_n2_hist_max", float(hh.max()))
    above = [q for q in bh.index if bh[q] >= 1]
    NOTES["fig_history"] = [
        f"Shows: the inflation learners' end-of-quarter share n2 (panel a) and the AR(1) coefficient beta of "
        f"their perceived law of motion (panel b), learned on the RE-filtered history {FIRST}-{END} (scenario "
        f"{hid}, which is a1_learn with the origin moved to {END}; the two agree through {ORIGIN}, largest "
        f"difference {d_n2:.1g} in n2 and {d_b:.1g} in beta). The dash-dot line is the Application 1 forecast "
        f"from {ORIGIN} with zero shocks (a1_learn). The learners keep learning through the 2020Q1-2020Q3 gap on "
        f"the filtered values (the RE prediction).",
        f"Share n2 over {FIRST}-{ORIGIN}: mean {fmt(float(hh.mean()), 3)}, min {fmt(float(hh.min()), 3)} "
        f"({hh.idxmin()}), max {fmt(float(hh.max()), 3)} ({hh.idxmax()}).",
        f"Share n2: {fmt(float(n2h['2019Q4']), 3)} at the end of 2019Q4, {fmt(float(n2h['2021Q2']), 3)} at the "
        f"end of 2021Q2, {fmt(float(n2h[ORIGIN]), 3)} at the end of {ORIGIN}, {fmt(float(n2h[END]), 3)} at the end "
        f"of {END} on the data (zero-shock forecast: {fmt(float(fn2[END]), 3)}). On the data after {ORIGIN} the "
        f"share falls to {fmt(float(post.min()), 3)} ({post.idxmin()})"
        + (f", its lowest value since {FIRST}" if float(post.min()) < float(hh.min()) else "") + ", while the "
        f"zero-shock forecast has it rising to {fmt(float(fn2.max()), 3)} ({fn2.idxmax()}): realised inflation fell "
        f"faster than the learners' AR(1) predicted.",
        f"beta over {FIRST}-{ORIGIN}: mean {fmt(float(bb.mean()), 3)}, min {fmt(float(bb.min()), 3)} "
        f"({bb.idxmin()}), max {fmt(float(bb.max()), 3)} ({bb.idxmax()}); {fmt(float(bh['2019Q4']), 3)} in 2019Q4, "
        f"{fmt(float(bh[ORIGIN]), 3)} in {ORIGIN}, {fmt(float(bh[END]), 3)} in {END} on the data.",
        f"beta is at or above 1 in {len(above)} quarters of {FIRST}-{END}"
        + (f": {', '.join(above)}." if len(above) <= 8 else f", first {above[0]}, last {above[-1]}."),
    ]


# ================================================================================ figure: application 3


def a3ser(exp, var, col):
    d = a3[(a3.expectations == exp) & (a3.variable == var)]
    if d.empty:
        raise Missing(f"app3_policy.csv: expectations {exp}, variable {var}")
    s = d.set_index("date")[col].sort_index()
    miss = [q for q in HOR if q not in s.index]
    if miss:
        raise Missing(f"app3_policy.csv: {exp}/{var}/{col}, quarters {miss[0]}-{miss[-1]}")
    return s.loc[HOR]


def a3_window():
    """Quarters in which the rate is held off the rule: the policy-shock state ms sits at its first-quarter
    deviation (it decays as an AR(1) once the condition ends)."""
    ms = a3ser("RE", "ms", "loose_minus_base")
    m0 = abs(float(ms[HOR[0]]))
    win = []
    for q in HOR:
        if abs(abs(float(ms[q])) - m0) > 1e-9:
            break
        win.append(q)
    return win, m0


def with_origin(s, v0=0.0):
    """Prepend the origin quarter: the deviations from the baseline are zero there."""
    return pd.concat([pd.Series([v0], index=[ORIGIN]), s])


def fig_app3():
    V = ["pinfobs", "dy"]
    win, _ = a3_window()
    fig = plt.figure(figsize=(TEXTW, 3.95))
    gs = GridSpec(2, 2, figure=fig, height_ratios=[1, 0.62], left=0.083, right=0.988, top=0.875, bottom=0.075,
                  hspace=0.55, wspace=0.26)
    for j, v in enumerate(V):
        ax = fig.add_subplot(gs[0, j])
        shade(ax, win[0], win[-1], centred=True)
        for exp, key in (("RE", "re"), ("learning", "learn")):
            for col in ("loose_minus_base", "tight_minus_base"):
                plot(ax, with_origin(a3ser(exp, v, col)), key)
        ax.set_title(f"({'ab'[j]}) {TITLE[v].split(' (')[0]}: deviation from the baseline")
        ax.set_ylabel("pp")
        date_axis(ax, ORIGIN, END)
        lo, hi = ax.get_ylim()
        ax.set_ylim(lo * 1.22, hi * 1.22)
        axes_style(ax)
        lo_l, ti_l = a3ser("learning", v, "loose_minus_base"), a3ser("learning", v, "tight_minus_base")
        q1, v1 = argmax_abs(lo_l)
        q2, v2 = argmax_abs(ti_l)
        for q, val, txt in ((q1, v1, "100 bp looser"), (q2, v2, "100 bp tighter")):
            ax.annotate(txt, (qx(q), val), xytext=(0, 4 if val > 0 else -4), textcoords="offset points",
                        ha="center", va="bottom" if val > 0 else "top", fontsize=8, color=INK)
        ax2 = fig.add_subplot(gs[1, j], sharex=ax)
        plot(ax2, with_origin(a3ser("RE", v, "asymmetry")), "re")
        plot(ax2, with_origin(a3ser("learning", v, "asymmetry")), "learn")
        ax2.set_title(f"({'cd'[j]}) {TITLE[v].split(' (')[0]}: looser + tighter (asymmetry)")
        ax2.set_ylabel("pp")
        date_axis(ax2, ORIGIN, END)
        axes_style(ax2)
    hs = [handle("re", "RE benchmark"), handle("learn", "Learning"),
          Patch(facecolor=SHADE, edgecolor="none", label=f"Rate held 100 bp off the rule, {win[0]}{ND}{win[-1]}")]
    fig.legend(handles=hs, loc="upper center", bbox_to_anchor=(0.5, 0.995), ncol=3, borderaxespad=0.2)
    save(fig, "fig_app3")

    # ---- notes
    n = []
    for v in ("pinfobs", "dy", "robs"):
        lr = a3ser("RE", v, "loose_minus_base")
        ll, tl, asl = (a3ser("learning", v, c) for c in ("loose_minus_base", "tight_minus_base", "asymmetry"))
        n.append((v, argmax_abs(lr), argmax_abs(ll), argmax_abs(tl), argmax_abs(asl)))
        check(f"a3_re_loose_peak_{v}", argmax_abs(lr)[1])
        check(f"a3_learning_loose_peak_{v}", argmax_abs(ll)[1])
        check(f"a3_learning_asym_peak_{v}", argmax_abs(asl)[1])
    re_asym = max(float(a3ser("RE", v, "asymmetry").abs().max()) for v in ("pinfobs", "dy", "robs", "dc"))
    shl = a3ser("learning", "n2_model_pinf", "loose_minus_base")
    sht = a3ser("learning", "n2_model_pinf", "tight_minus_base")
    pi, dy_, r_ = n
    win, m0 = a3_window()
    NOTES["fig_app3"] = [
        f"Shows: the policy rate held 100 bp a year below (looser) or above (tighter) the Taylor rule for "
        f"{len(win)} quarters, {win[0]}-{win[-1]} (shaded; the policy-shock process ms is held {m0:g} pp "
        f"annualised off its own path and the monetary shock em is endogenised to deliver it), from "
        f"the {ORIGIN} peak; deviations from the same scenario without the condition (Application 1), under RE "
        f"(a3_*_re) and learning (a3_*_learn). Top: inflation and output growth; bottom: looser + tighter, which "
        f"is zero if the two responses are symmetric. Units: pp of the annualised rates.",
        f"Inflation, largest effect: RE {pp(pi[1][1], 3)} ({pi[1][0]}); learning looser {pp(pi[2][1], 3)} "
        f"({pi[2][0]}), tighter {pp(pi[3][1], 3)} ({pi[3][0]}). Learning delays the inflation effect and makes "
        f"it slightly larger.",
        f"Output growth, largest effect: RE {pp(dy_[1][1], 3)} ({dy_[1][0]}); learning looser {pp(dy_[2][1], 3)} "
        f"({dy_[2][0]}). Policy rate (including the rule's response): RE {pp(r_[1][1], 3)} ({r_[1][0]}), learning "
        f"{pp(r_[2][1], 3)} ({r_[2][0]}).",
        f"Asymmetry under learning, largest |looser + tighter|: inflation {pp(pi[4][1], 4)} ({pi[4][0]}), about "
        f"{100 * abs(pi[4][1]) / abs(pi[2][1]):.0f}% of the effect; output growth {pp(dy_[4][1], 4)} ({dy_[4][0]}). "
        f"Under RE the responses are symmetric to {re_asym:.1e}.",
        f"The asymmetry comes from the learning states: looser policy raises the learners' share in force by up "
        f"to {fmt(float(shl.max()), 4)} ({shl.idxmax()}), tighter policy lowers it by up to "
        f"{fmt(float(-sht.min()), 4)} ({sht.idxmin()}).",
    ]


# ================================================================================ figure: application 4


def tser(sc, target):
    d = a4t[(a4t.scenario == sc) & (a4t.target == target)]
    if d.empty:
        raise Missing(f"app4_targets_long.csv: scenario {sc}, target {target}")
    s = d.drop_duplicates("date").set_index("date").value.sort_index()
    miss = [q for q in HOR if q not in s.index]
    if miss:
        raise Missing(f"app4_targets_long.csv: scenario {sc}, target {target}, quarters {miss[0]}-{miss[-1]}")
    return s.loc[HOR]


A4RUNS = {("re", "rule"): "a4_rule_re", ("re", "ramsey"): "a4_ramsey_balanced_re_mc",
          ("learn", "rule"): "a4_rule_learn", ("learn", "ramsey"): "a4_ramsey_balanced_learn"}


def loss(w, e, p, h):
    d = a4[(a4.weights == w) & (a4.expectations == e) & (a4.policy == p) & (a4.horizon == h)]
    if d.empty:
        raise Missing(f"app4_losses.csv: weights {w}, expectations {e}, policy {p}, horizon {h}")
    return float(d.total.iloc[0])


def fig_app4():
    cols = [("pinfobs", "Inflation", "% q/q, annualised"), ("ygap", "Output gap", "% of flexible-price output"),
            ("robs", "Policy rate", "% annualised")]
    data = {}
    for (e, p), sid in A4RUNS.items():
        data[(e, p, "pinfobs")] = pser(sid, "pinfobs", HOR[0], END)
        data[(e, p, "robs")] = pser(sid, "robs", HOR[0], END)
        data[(e, p, "ygap")] = tser(sid, "ygap")
    ram_kw = dict(ls=(0, (1.0, 1.2)), lw=1.3, marker="o", ms=2.6, mfc="white", mew=0.7)
    fig, axs = plt.subplots(2, 3, figsize=(TEXTW, 4.0), sharex=True, sharey="col",
                            gridspec_kw=dict(left=0.075, right=0.988, top=0.84, bottom=0.07, hspace=0.55,
                                             wspace=0.36))
    for j, (v, nm, un) in enumerate(cols):
        for i, (e, row) in enumerate((("re", "RE"), ("learn", "learning"))):
            ax = axs[i, j]
            plot(ax, data[(e, "rule", v)], e)
            plot(ax, data[(e, "ramsey", v)], e, **ram_kw)
            ax.set_title(f"({'abcdef'[3 * i + j]}) {nm}, {row}")
            ax.set_ylabel(un)
            date_axis(ax, HOR[0], END, pad=0.2)
            ax.tick_params(labelbottom=True)
        for i in range(2):
            axes_style(axs[i, j])
    hs = [handle("re", "RE, Taylor rule"),
          handle("re", "RE, Ramsey (model-consistent RE agents)", **ram_kw),
          handle("learn", "Learning, Taylor rule"),
          handle("learn", "Learning, Ramsey (anchored RE agents)", **ram_kw)]
    fig.legend(handles=hs, loc="upper center", bbox_to_anchor=(0.5, 0.998), ncol=2, borderaxespad=0.2)
    save(fig, "fig_app4")

    # ---- notes
    MC = "RE_model_consistent"
    lb = {k: loss("balanced", *k, 80) for k in ((MC, "rule"), (MC, "ramsey"), ("learning", "rule"), ("learning", "ramsey"))}
    av = {(e, p, v): float(data[(e, p, v)].mean()) for (e, p) in A4RUNS for v in ("pinfobs", "robs", "ygap")}
    NOTES["fig_app4"] = [
        f"Shows: Ramsey policy under commitment against the Taylor rule from the {ORIGIN} peak, balanced loss "
        f"weights (inflation 1, output gap 0.5, rate 0.1), zero shocks, {HOR[0]}-{END}; inflation, output gap "
        f"(y - y^f, the loss target) and policy rate; top row RE, bottom row learning. RE Ramsey = the saved "
        f"model-consistent RE plan a4_ramsey_balanced_re_mc; learning Ramsey = a4_ramsey_balanced_learn. All "
        f"application 4 runs use period-t RE information (Ramsey policy is not supported with t-1 RE "
        f"information), so the rule paths differ from Application 1.",
        f"Discounted loss over 80 quarters, balanced weights: RE rule {fmt(lb[(MC, 'rule')], 1)} vs RE Ramsey "
        f"{fmt(lb[(MC, 'ramsey')], 1)}; learning rule {fmt(lb[('learning', 'rule')], 1)} vs learning Ramsey "
        f"{fmt(lb[('learning', 'ramsey')], 1)}.",
        f"Average inflation {HOR[0]}-{END}: RE rule {pct(av[('re', 'rule', 'pinfobs')])}, RE Ramsey "
        f"{pct(av[('re', 'ramsey', 'pinfobs')])}; learning rule {pct(av[('learn', 'rule', 'pinfobs')])}, learning "
        f"Ramsey {pct(av[('learn', 'ramsey', 'pinfobs')])}. Average output gap: RE rule "
        f"{fmt(av[('re', 'rule', 'ygap')])}%, RE Ramsey {fmt(av[('re', 'ramsey', 'ygap')])}%; learning rule "
        f"{fmt(av[('learn', 'rule', 'ygap')])}%, learning Ramsey {fmt(av[('learn', 'ramsey', 'ygap')])}%.",
        f"Policy rate in {HOR[0]}: RE rule {pct(float(data[('re', 'rule', 'robs')][HOR[0]]))}, RE Ramsey "
        f"{pct(float(data[('re', 'ramsey', 'robs')][HOR[0]]))}, learning rule "
        f"{pct(float(data[('learn', 'rule', 'robs')][HOR[0]]))}, learning Ramsey "
        f"{pct(float(data[('learn', 'ramsey', 'robs')][HOR[0]]))} (origin value "
        f"{pct(float(pser('a4_rule_re', 'robs', ORIGIN, ORIGIN).iloc[0]))}). Ramsey trades a slower fall in "
        f"inflation for a much smaller output gap under both expectation regimes.",
        "Caveat for the text: the anchored RE agents in the learning Ramsey run forecast with the RE solution "
        "under the Taylor rule, not under the Ramsey policy, so the learning Ramsey loss is not a clean gain "
        "from optimal policy (open design question in the project). Under learning the planner treats the "
        "current PLM coefficients and shares as permanent (anticipated utility) and re-optimises every quarter, "
        "honouring past multipliers (docs/DESIGN.md). The anchored RE Ramsey runs (a4_ramsey_*_re) are not RE "
        "plans and are left out of the figure; their losses are in the notes of tab_app4.",
    ]


# ================================================================================ figure: densities


def dq(case, exp, var, q):
    d = dens[(dens.case == case) & (dens.expectations == exp) & (dens.variable == var) &
             (np.isclose(dens["quantile"], q))]
    if d.empty:
        raise Missing(f"app5_density.csv: case {case}, expectations {exp}, variable {var}, quantile {q}")
    s = d.drop_duplicates("date").set_index("date").value.sort_index()
    miss = [x for x in HOR if x not in s.index]
    if miss:
        raise Missing(f"app5_density.csv: {case}/{exp}/{var}/q{q}, quarters {miss[0]}-{miss[-1]}")
    return s.loc[HOR]


def wavg(case, exp, var):
    d = wid[(wid.case == case) & (wid.expectations == exp) & (wid.variable == var)]
    if d.empty:
        raise Missing(f"app5_widths.csv: case {case}, expectations {exp}, variable {var}")
    s = d.set_index("date").width_90.sort_index()
    return float(s.loc[HOR].mean()), s


def fig_density():
    cases = [("markup", "Mark-up (supply) shocks"), ("demand", "Demand shocks")]
    V = ["pinfobs", "dy"]
    Q = {(c, e, v, q): dq(c, e, v, q) for c, _ in cases for e in ("RE", "learning") for v in V
         for q in (0.05, 0.5, 0.95)}
    fig, axs = plt.subplots(2, 2, figsize=(TEXTW, 4.35), sharex=True,
                            gridspec_kw=dict(left=0.083, right=0.988, top=0.855, bottom=0.07, hspace=0.42,
                                             wspace=0.26))
    x = [qx(q) for q in HOR]
    for i, (c, cname) in enumerate(cases):
        for j, v in enumerate(V):
            ax = axs[i, j]
            lo, hi = Q[(c, "learning", v, 0.05)].values, Q[(c, "learning", v, 0.95)].values
            ax.fill_between(x, lo, hi, facecolor=COL["learn"], alpha=0.22, lw=0, zorder=1)
            ax.plot(x, lo, color=COL["learn"], lw=0.6, zorder=2)
            ax.plot(x, hi, color=COL["learn"], lw=0.6, zorder=2)
            rlo, rhi = Q[(c, "RE", v, 0.05)].values, Q[(c, "RE", v, 0.95)].values
            ax.fill_between(x, rlo, rhi, facecolor="none", edgecolor=COL["re"], hatch="//////", lw=0, zorder=3)
            ax.plot(x, rlo, color=COL["re"], lw=0.7, ls=DASH, zorder=3)
            ax.plot(x, rhi, color=COL["re"], lw=0.7, ls=DASH, zorder=3)
            plot(ax, Q[(c, "RE", v, 0.5)], "re", zorder=5)
            plot(ax, Q[(c, "learning", v, 0.5)], "learn", zorder=6)
            ax.set_title(f"({'abcd'[2 * i + j]}) {cname}: {TITLE[v].split(' (')[0].lower()}")
            ax.set_ylabel(UNIT[v])
            date_axis(ax, HOR[0], END, pad=0.2)
            ax.tick_params(labelbottom=True)
            axes_style(ax)
    hs = [handle("re", "RE: median"),
          Patch(facecolor="none", edgecolor=COL["re"], hatch="//////", lw=0.7, ls="--", label="RE: 90% band"),
          handle("learn", "Learning: median"),
          Patch(facecolor=COL["learn"], alpha=0.35, edgecolor=COL["learn"], lw=0.6, label="Learning: 90% band")]
    fig.legend(handles=hs, loc="upper center", bbox_to_anchor=(0.5, 0.998), ncol=2, borderaxespad=0.2)
    save(fig, "fig_density")

    # ---- notes
    W = {(c, e, v): wavg(c, e, v)[0] for c, _ in cases for e in ("RE", "learning") for v in ("pinfobs", "dy", "robs")}
    for c, _ in cases:
        for e, ek in (("RE", "re"), ("learning", "learn")):
            for v in ("pinfobs", "dy", "robs"):
                check(f"a5_w90_avg_{c}_{ek}_{v}", W[(c, e, v)])
    h16 = HOR[-1]
    NOTES["fig_density"] = [
        f"Shows: 90% bands (5th-95th percentiles) and medians of 500 stochastic forecasts from the {ORIGIN} peak, "
        f"{HOR[0]}-{END}, with normal draws of the calibrated shock standard deviations (seed 0). Rows: mark-up "
        f"(supply) shocks, price and wage mark-up (epinf, ew); demand shocks, risk premium, government spending "
        f"and investment (eb, eg, eqs). Columns: inflation and output growth (% q/q annualised). RE band "
        f"hatched with dashed edges; learning band filled. The 68% bands are in app5_density.csv, not drawn.",
        f"Mark-up shocks, average width of the 90% inflation band: learning {fmt(W[('markup', 'learning', 'pinfobs')])} "
        f"pp vs RE {fmt(W[('markup', 'RE', 'pinfobs')])} pp (ratio "
        f"{fmt(W[('markup', 'learning', 'pinfobs')] / W[('markup', 'RE', 'pinfobs')])}); in {h16} the learning band "
        f"runs from {pct(float(Q[('markup', 'learning', 'pinfobs', 0.05)][h16]))} to "
        f"{pct(float(Q[('markup', 'learning', 'pinfobs', 0.95)][h16]))} (RE "
        f"{pct(float(Q[('markup', 'RE', 'pinfobs', 0.05)][h16]))} to {pct(float(Q[('markup', 'RE', 'pinfobs', 0.95)][h16]))}). "
        f"The learning distribution is skewed upwards: inflation shocks feed the learners' explosive AR(1) beliefs "
        f"(beta {fmt(K('a1_beta_origin'), 3)} at the origin) and their share.",
        f"Mark-up shocks, output growth band: learning {fmt(W[('markup', 'learning', 'dy')])} pp vs RE "
        f"{fmt(W[('markup', 'RE', 'dy')])} pp.",
        f"Demand shocks: the bands are about the same under learning and RE; inflation "
        f"{fmt(W[('demand', 'learning', 'pinfobs')])} vs {fmt(W[('demand', 'RE', 'pinfobs')])} pp, output growth "
        f"{fmt(W[('demand', 'learning', 'dy')])} vs {fmt(W[('demand', 'RE', 'dy')])} pp.",
        f"All 500 draws are used in both cases; the projection facility ('alm') acts in "
        f"{int(K('a5_fac_draws_markup_learn'))} of the 500 learning mark-up draws "
        f"({int(K('a5_fac_alm_markup_learn'))} quarters with beliefs reverted, {int(K('a5_fac_shares_markup_learn'))} "
        f"with shares kept) and in {int(K('a5_fac_draws_demand_learn'))} demand draws.",
    ]


# ================================================================================ figure: PLMs

PLMS = [("a1_learn", "learn", "AR(1), baseline"), ("v2_ar2", "ar2", "AR(2)"),
        ("v2_var3", "var3", "VAR(1): inflation, output gap, rate"),
        ("v2_var12", "var12", "VAR(1): 12 forward-looking variables")]


def fig_plm():
    X0 = "2018Q1"
    dat = pser("data", "pinfobs", X0, END)
    rr = pser("a1_re", "pinfobs", ORIGIN, END)
    pi = {s: pser(s, "pinfobs", ORIGIN, END) for s, _, _ in PLMS}
    n2 = {s: lser(s, "n2", X0, END) for s, _, _ in PLMS}
    pr = {s: lser(s, "persistence", X0, END) for s, _, _ in PLMS}
    fig = plt.figure(figsize=(TEXTW, 5.9))
    gs = GridSpec(3, 1, figure=fig, height_ratios=[1.35, 0.8, 0.8], left=0.083, right=0.988, top=0.855,
                  bottom=0.048, hspace=0.5)
    a1 = fig.add_subplot(gs[0])
    a2 = fig.add_subplot(gs[1], sharex=a1)
    a3_ = fig.add_subplot(gs[2], sharex=a1)
    for ax in (a1, a2, a3_):
        shade(ax, ORIGIN, END)
    plot(a1, dat, "data")
    plot(a1, rr, "re")
    for s, key, _ in PLMS:
        plot(a1, pi[s], key)
        plot(a2, n2[s], key)
        plot(a3_, pr[s], key)
    a1.set_title("(a) Inflation (GDP deflator): forecast from the 2022Q2 peak")
    a1.set_ylabel(UNIT["pinfobs"])
    a2.set_title("(b) Learners' share of inflation expectations, end of quarter ($n_2$)")
    a2.set_ylabel("share of agents")
    a2.axhline(0.5, color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), zorder=1)
    a3_.set_title("(c) Perceived persistence: largest root of the learners' PLM")
    a3_.set_ylabel("largest root")
    a3_.axhline(1.0, color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), zorder=1)
    for ax in (a1, a2, a3_):
        date_axis(ax, X0, END)
        axes_style(ax, zero=(ax is a1))
    lab = {"learn": "AR(1) learners (baseline)", "ar2": "AR(2) learners",
           "var3": "VAR(1) learners: inflation, output gap, rate", "var12": "VAR(1) learners: 12 variables"}
    hs = [handle("data"), handle("re", "RE benchmark"),
          Patch(facecolor=SHADE, edgecolor="none", label="Forecast, zero shocks"),
          Line2D([], [], color=ZEROC, lw=0.7, ls=(0, (1, 1.5)), label="Reference: share 0.5, root 1")] + \
         [handle(k, lab[k]) for _, k, _ in PLMS]
    fig.legend(handles=hs, loc="upper center", bbox_to_anchor=(0.5, 0.998), ncol=2, borderaxespad=0.2)
    save(fig, "fig_plm")

    # ---- notes
    av = {s: avg(pi[s], HOR[0], END) for s, _, _ in PLMS}
    for s in av:
        check(f"avg_pinfobs__{s}", av[s])
        check(f"n2_origin__{s}", float(n2[s][ORIGIN]))
        check(f"persist_origin__{s}", float(pr[s][ORIGIN]))
    hist_root = {s: float(lser(s, "persistence", FIRST, ORIGIN).mean()) for s, _, _ in PLMS}
    nm = {s: n for s, _, n in PLMS}
    NOTES["fig_plm"] = [
        f"Shows: Application 1 (forecast from the {ORIGIN} peak, zero shocks) with four perceived laws of motion "
        f"(PLMs) for the inflation learners: the baseline AR(1) (a1_learn), AR(2) (v2_ar2), a VAR(1) in "
        f"inflation, output gap and policy rate (v2_var3) and a VAR(1) in the 12 forward-looking variables of "
        f"SW07 (v2_var12). Only the inflation expectation uses the PLM; the other VAR equations only forecast "
        f"the regressors. Panels: inflation with the data and the RE benchmark; the learners' end-of-quarter "
        f"share n2; the largest root of the PLM (for the AR(1) the coefficient beta). {X0}-{END}, forecast shaded.",
        "Average inflation " + f"{HOR[0]}-{END}: " + "; ".join(f"{nm[s]} {pct(av[s])}" for s in av)
        + f"; RE {pct(avg(rr, HOR[0], END))}.",
        "Share n2 at the end of " + f"{ORIGIN}: " + "; ".join(f"{nm[s]} {fmt(float(n2[s][ORIGIN]), 3)}" for s in av)
        + f". Peak share in the forecast: AR(2) {fmt(float(n2['v2_ar2'].loc[HOR].max()), 3)}, AR(1) "
          f"{fmt(float(n2['a1_learn'].loc[HOR].max()), 3)}, VAR(1) 3 variables "
          f"{fmt(float(n2['v2_var3'].loc[HOR].max()), 3)}.",
        "Largest root at " + f"{ORIGIN}: " + "; ".join(f"{nm[s]} {fmt(float(pr[s][ORIGIN]), 3)}" for s in av)
        + " (all at or above 1, so no PLM has a finite perceived mean at the origin).",
        f"Mean largest root over {FIRST}-{ORIGIN}: " + "; ".join(f"{nm[s]} {fmt(hist_root[s], 3)}" for s in av)
        + ". The VAR learners perceive inflation as close to a unit root throughout the history. No projection-"
          "facility events in any of the four runs.",
    ]


# ================================================================================ tables (booktabs)


def write_table(name, caption, label, colspec, head, body, note):
    lines = [r"\begin{table}[tbp]", r"\centering", r"\small", rf"\caption{{{caption}}}", rf"\label{{{label}}}",
             rf"\begin{{tabular}}{{{colspec}}}", r"\toprule"] + head + [r"\midrule"] + body + \
            [r"\bottomrule", r"\end{tabular}", r"\par\smallskip", r"\begin{minipage}{\linewidth}\footnotesize",
             note, r"\end{minipage}", r"\end{table}", ""]
    (TABDIR / f"{name}.tex").write_text("\n".join(lines), encoding="utf-8")
    TABLES.append(name)


def tab_app1():
    yr1 = HOR[:4]
    rows = []
    for v in VAR4:
        d, r, l_ = pser("data", v, HOR[0], END), pser("a1_re", v, HOR[0], END), pser("a1_learn", v, HOR[0], END)
        cells = []
        for a, b in ((yr1[0], yr1[-1]), (HOR[0], END)):
            m = [avg(d, a, b), avg(r, a, b), avg(l_, a, b)]
            cells += [tex(m[0]), tex(m[1]), tex(m[2]), tex(m[2] - m[1], sign=True)]
        rows.append(f"{TITLE[v].split(' (')[0]} & " + " & ".join(cells) + r" \\")
    n2 = lser("a1_learn", "n2", ORIGIN, END)
    head = [rf"& \multicolumn{{4}}{{c}}{{{yr1[0]}--{yr1[-1]}}} & \multicolumn{{4}}{{c}}{{{HOR[0]}--{END}}} \\",
            r"\cmidrule(lr){2-5}\cmidrule(lr){6-9}",
            r"Variable & Data & RE & Learning & L $-$ RE & Data & RE & Learning & L $-$ RE \\"]
    note = (rf"\textit{{Notes:}} Averages of the forecast from the {ORIGIN} inflation peak with zero future "
            rf"shocks, in \% (inflation: GDP deflator, q/q annualised; output and consumption growth: per capita, "
            rf"q/q annualised; policy rate: federal funds rate, \% a year). L $-$ RE: learning minus RE, pp. "
            rf"RE: every agent rational, RE information $t-1$. Learning: anchored RE agents and AR(1) "
            rf"learners on inflation expectations with switching shares (KOZ gain, $\chi=2$, memory 0.8). Data: "
            rf"the realised values, for comparison. Learners' share at the end of {ORIGIN}: "
            rf"{tex(float(n2[ORIGIN]), 3)}; peak in the forecast {tex(float(n2.loc[HOR].max()), 3)} "
            rf"({n2.loc[HOR].idxmax()}); learners' AR(1) coefficient at the origin {tex(K('a1_beta_origin'), 3)}. "
            r"Source: \texttt{paths\_long.csv}, \texttt{learning\_long.csv}.")
    write_table("tab_app1", f"Application 1: forecast from the {ORIGIN} peak, average outcomes", "tab:app1",
                "l" + "r" * 8, head, rows, note)


def tab_app3():
    def stats(exp, var, col):
        s = a3ser(exp, var, col)
        q, v = argmax_abs(s)
        return v, q, float(s.mean())
    body = []
    for v, nm in (("pinfobs", "Inflation"), ("dy", "Output growth"), ("robs", "Policy rate")):
        re_l = stats("RE", v, "loose_minus_base")
        le_l = stats("learning", v, "loose_minus_base")
        le_t = stats("learning", v, "tight_minus_base")
        asy = stats("learning", v, "asymmetry")
        body += [rf"{nm} & largest effect & {tex(re_l[0], 3, True)} & {tex(le_l[0], 3, True)} & "
                 rf"{tex(le_t[0], 3, True)} & {tex(asy[0], 4, True)} \\",
                 rf" & quarter & {re_l[1]} & {le_l[1]} & {le_t[1]} & {asy[1]} \\",
                 rf" & average effect & {tex(re_l[2], 3, True)} & {tex(le_l[2], 3, True)} & {tex(le_t[2], 3, True)} & "
                 rf"{tex(asy[2], 4, True)} \\"]
        if v != "robs":
            body.append(r"\addlinespace")
    sl = stats("learning", "n2_model_pinf", "loose_minus_base")
    st = stats("learning", "n2_model_pinf", "tight_minus_base")
    sa = stats("learning", "n2_model_pinf", "asymmetry")
    body += [r"\addlinespace",
             rf"Learners' share in force & largest effect & -- & {tex(sl[0], 4, True)} & {tex(st[0], 4, True)} & "
             rf"{tex(sa[0], 4, True)} \\",
             rf" & quarter & -- & {sl[1]} & {st[1]} & {sa[1]} \\"]
    re_asym = max(float(a3ser("RE", v, "asymmetry").abs().max()) for v in ("pinfobs", "dy", "robs", "dc"))
    win, _ = a3_window()
    head = [r"& & RE & \multicolumn{3}{c}{Learning} \\", r"\cmidrule(lr){3-3}\cmidrule(lr){4-6}",
            r"Variable & Statistic & Looser & Looser & Tighter & Looser $+$ tighter \\"]
    note = (rf"\textit{{Notes:}} Deviations from Application 1 in pp (annualised rates) when the policy rate is "
            rf"held 100 bp a year below (looser) or above (tighter) the Taylor rule in {win[0]}--{win[-1]}; "
            rf"forecast {HOR[0]}--{END}. Largest effect: the deviation with the largest absolute value, and its quarter; "
            rf"average effect: mean over the {NH} quarters. Under RE the tighter run is the mirror image of the "
            rf"looser one (largest $|$looser $+$ tighter$|$ below $10^{{{math.ceil(math.log10(re_asym))}}}$). The "
            r"policy rate "
            r"includes the rule's response. Source: \texttt{app3\_policy.csv}.")
    write_table("tab_app3", "Application 3: policy 100 bp looser or tighter than the Taylor rule", "tab:app3",
                "llrrrr", head, body, note)


def loss_weights():
    out = {}
    for w in ("balanced", "hawk", "dove", "smooth"):
        sid = f"a4_ramsey_{w}_re"
        if sid not in scen.index:
            raise Missing(f"scenarios.csv: {sid}")
        m = re.search(r"inflation ([\d.]+), output gap ([\d.]+), rate ([\d.]+)(?:, rate change ([\d.]+))?",
                      scen.loc[sid, "description"])
        if not m:
            raise Missing(f"scenarios.csv: loss weights in the description of {sid}")
        out[w] = tuple(float(x) if x else 0.0 for x in m.groups())
    return out


def tab_app4():
    MC = "RE_model_consistent"
    lw = loss_weights()
    body = []
    for h in (80, 16):
        body.append(rf"\multicolumn{{10}}{{l}}{{\textit{{Discounted loss over {h} quarters}}}} \\")
        for w in ("balanced", "hawk", "dove", "smooth"):
            r1, r2 = loss(w, MC, "rule", h), loss(w, MC, "ramsey", h)
            l1, l2 = loss(w, "learning", "rule", h), loss(w, "learning", "ramsey", h)
            wt = lw[w]
            body.append(rf"\quad {w.capitalize()} & {wt[1]:g} & {wt[2]:g} & {wt[3]:g} & {tex(r1, 1)} & "
                        rf"{tex(r2, 1)} & {tex(r2 / r1, 2)} & {tex(l1, 1)} & {tex(l2, 1)} & {tex(l2 / l1, 2)} \\")
        body.append(r"\addlinespace")
    # balanced weights: average outcomes
    body.append(rf"\multicolumn{{10}}{{l}}{{\textit{{Balanced weights: averages {HOR[0]}--{END}}}}} \\")
    for v, nm, src in (("pinfobs", r"Inflation (\%)", "p"), ("ygap", r"Output gap (\%)", "t"),
                       ("robs", r"Policy rate (\%)", "p")):
        vals = {}
        for k, sid in A4RUNS.items():
            s = pser(sid, v, HOR[0], END) if src == "p" else tser(sid, v)
            vals[k] = float(s.mean())
        body.append(rf"\quad {nm} & & & & {tex(vals[('re', 'rule')])} & {tex(vals[('re', 'ramsey')])} & & "
                    rf"{tex(vals[('learn', 'rule')])} & {tex(vals[('learn', 'ramsey')])} & \\")
    anch = ", ".join(f"{w} {tex(loss(w, 'RE', 'ramsey', 80), 1)}" for w in ("balanced", "hawk", "dove", "smooth"))
    head = [r"& \multicolumn{3}{c}{Loss weights} & \multicolumn{3}{c}{RE} & \multicolumn{3}{c}{Learning} \\",
            r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}\cmidrule(lr){8-10}",
            r"Weights & $\lambda_y$ & $\lambda_r$ & $\lambda_{\Delta r}$ & Rule & Ramsey & Ratio & Rule & Ramsey & "
            r"Ratio \\"]
    note = (rf"\textit{{Notes:}} Taylor rule against Ramsey policy under commitment from the {ORIGIN} peak, zero "
            r"shocks. Loss $= \sum_h \delta^h(\hat\pi_h^2 + \lambda_y x_h^2 + \lambda_r \hat r_h^2 + \lambda_{\Delta r} "
            r"(\Delta \hat r_h)^2)$, where $\hat\pi = 4\pi$ and $\hat r = 4r$ are annualised deviations of inflation "
            r"and the policy rate from the steady state, $x = y-y^f$ is the output gap, the weight on inflation is 1 "
            r"and $\delta = \bar\beta\gamma$ is the discount of the SW07 Phillips curve; the "
            r"80-quarter loss continues the forecast with zero shocks. Ratio: Ramsey / rule. RE Ramsey: the "
            r"model-consistent RE plan (RE agents "
            r"forecast the economy under the Ramsey policy). Learning Ramsey: the anchored RE agents keep the "
            r"Taylor-rule RE forecast, so its loss is not a clean gain from optimal policy. All runs use period-$t$ "
            rf"RE information. Anchored RE Ramsey losses over 80 quarters (not RE plans): {anch}. "
            r"Source: \texttt{app4\_losses.csv}, \texttt{app4\_targets\_long.csv}, \texttt{paths\_long.csv}.")
    write_table("tab_app4", "Application 4: Ramsey policy against the Taylor rule", "tab:app4",
                "lrrrrrrrrr", head, body, note)


def tab_plm():
    rows_def = [("a1_learn", "AR(1), baseline"), ("v2_ar1nc", "AR(1), no constant"), ("v2_ar2", "AR(2)"),
                ("v2_reg", r"Regression on $\pi$, $x$, $r$"),
                ("v2_var3", r"VAR(1) in $\pi$, $x$, $r$"), ("v2_var12", "VAR(1) in 12 variables")]
    body = []
    r_ = {v: avg(pser("a1_re", v, HOR[0], END), HOR[0], END) for v in ("pinfobs", "robs", "dy")}
    body.append(rf"RE benchmark & {tex(r_['pinfobs'])} & {tex(r_['robs'])} & {tex(r_['dy'])} & -- & -- & -- & -- \\")
    body.append(r"\addlinespace")
    for s, nm in rows_def:
        a = {v: avg(pser(s, v, HOR[0], END), HOR[0], END) for v in ("pinfobs", "robs", "dy")}
        n2 = lser(s, "n2", FIRST, END)
        n2m = lser(s, "n2_model", HOR[0], END)
        pr = lser(s, "persistence", FIRST, END)
        ev = scen.loc[s, "n_events"] if s in scen.index else float("nan")
        if not (isinstance(ev, float) and math.isnan(ev)) and int(ev) > 0:
            print(f"  note: {s} has {int(ev)} engine events")
        body.append(rf"{nm} & {tex(a['pinfobs'])} & {tex(a['robs'])} & {tex(a['dy'])} & "
                    rf"{tex(float(n2[ORIGIN]), 3)} & {tex(float(n2m.max()), 3)} & {tex(float(pr[ORIGIN]), 3)} & "
                    rf"{tex(float(pr.loc[:ORIGIN].mean()), 3)} \\")
    head = [rf"& \multicolumn{{3}}{{c}}{{Average {HOR[0]}--{END} (\%)}} & \multicolumn{{2}}{{c}}{{Learners' share}} & "
            r"\multicolumn{2}{c}{Largest root} \\",
            r"\cmidrule(lr){2-4}\cmidrule(lr){5-6}\cmidrule(lr){7-8}",
            rf"PLM for inflation & Inflation & Rate & Output gr. & {ORIGIN} & Peak & {ORIGIN} & "
            rf"Mean {FIRST[:4]}--{ORIGIN[:4]} \\"]
    note = (rf"\textit{{Notes:}} Application 1 (forecast from the {ORIGIN} peak, zero shocks) with alternative "
            r"perceived laws of motion (PLMs) for the inflation learners; everything else as in the baseline. "
            r"$\pi$: inflation, $x$: output gap, $r$: policy rate; the regression uses their first lags, the "
            r"12-variable VAR the 12 forward-looking variables of SW07. "
            r"Only the inflation expectation uses the PLM; the other equations of the regression and VAR PLMs "
            rf"only forecast the regressors. Learners' share: end-of-quarter share $n_2$ at {ORIGIN}, and the peak "
            rf"share in force ($n_2$ of the previous quarter) over {HOR[0]}--{END}. Largest root of the PLM block "
            rf"(the AR(1) coefficient for the AR(1) PLMs) at {ORIGIN} and its mean over {FIRST}--{ORIGIN}. No "
            r"projection-facility events in any of these runs. Source: \texttt{paths\_long.csv}, "
            r"\texttt{learning\_long.csv}.")
    write_table("tab_plm", "Perceived laws of motion: Application 1 with alternative PLMs", "tab:plm",
                "lrrrrrrr", head, body, note)


# ================================================================================ run everything


def main():
    skipped = []
    for fn in (fig_app1, fig_history, fig_app3, fig_app4, fig_density, fig_plm,
               tab_app1, tab_app3, tab_app4, tab_plm):
        try:
            fn()
            print(f"ok    {fn.__name__}")
        except Missing as e:
            plt.close("all")
            skipped.append((fn.__name__, str(e)))
            print(f"SKIP  {fn.__name__}: missing {e}")
    # ---- FIGURE_NOTES.txt
    T = {"fig_app1": "fig_app1 - Application 1: forecast from the 2022Q2 inflation peak",
         "fig_history": "fig_history - learners' share and perceived persistence, 1966-2026",
         "fig_app3": "fig_app3 - Application 3: policy 100 bp looser or tighter than the rule",
         "fig_app4": "fig_app4 - Application 4: Ramsey policy against the Taylor rule",
         "fig_density": "fig_density - Application 5: density forecasts, mark-up and demand shocks",
         "fig_plm": "fig_plm - perceived laws of motion: AR(1) against AR(2) and VAR(1) learners"}
    out = ["FIGURE NOTES - hetlearn paper (Computational Economics), SW07 results",
           "Written by paper/figures/make_figures.py from results/summary_v3/*.csv only; do not edit by hand.",
           "Baseline (2026-10-21): published SW07 parameters (1966Q1-2004Q4 mode), AR(1) learners on inflation with "
           "the KOZ endogenous gain from 0.05, intensity of choice chi 2, memory 0.8, RE agents and learners on t-1 "
           "information, anchored RE agents, filtered RE history, projection facility 'alm', data 1966Q1-2026Q2 "
           "with 2020Q1-2020Q3 treated as missing.",
           "Units: inflation, output and consumption growth in % q/q annualised (growth per capita); policy rate "
           "in % a year; pp = percentage points. Colours: data black (thin, dots), RE blue dashed, learning "
           "vermillion solid; alternative PLMs green dash-dot, purple dotted, orange long dash with open "
           "triangles; Ramsey runs dotted with open circles (Okabe-Ito colours).",
           "Each figure is a PDF (vector) and a PNG (600 dpi), 16 cm wide, 8-9 pt type.", ""]
    for k, title in T.items():
        out.append("=" * 100)
        out.append(title)
        out.append(f"Files: paper/figures/{k}.pdf, {k}.png")
        if k in NOTES:
            out.append("- " + NOTES[k][0])
            out.append("Key numbers:")
            out += [f"  * {x}" for x in NOTES[k][1:]]
        else:
            out.append("- NOT MADE: " + next((m for n, m in skipped if n == k), "unknown"))
        out.append("")
    out.append("=" * 100)
    out.append("Tables (paper/tables/, booktabs; \\input them, they need \\usepackage{booktabs}):")
    desc = {"tab_app1": "Application 1 averages: data, RE, learning, first year and full horizon",
            "tab_app3": "Application 3: largest and average effects of looser/tighter policy, asymmetry, share",
            "tab_app4": "Application 4: discounted losses (80 and 16 quarters), four weight sets, RE and learning; "
                        "balanced-weight averages",
            "tab_plm": "PLM comparison: averages, learners' share, largest root, for six PLMs and RE"}
    for t, d in desc.items():
        out.append(f"  {t}.tex: {d}" + ("" if t in TABLES else "  [NOT MADE: "
                                         + next((m for n, m in skipped if n == t), "unknown") + "]"))
    if skipped:
        out += ["", "Skipped because a series is missing:"] + [f"  {n}: {m}" for n, m in skipped]
    (FIGDIR / "FIGURE_NOTES.txt").write_text("\n".join(out) + "\n", encoding="utf-8")
    print("written", FIGDIR / "FIGURE_NOTES.txt")
    return 1 if skipped else 0


if __name__ == "__main__":
    sys.exit(main())
