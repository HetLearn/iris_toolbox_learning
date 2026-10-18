# What changes when the SW(2007) sample runs to 2026 instead of 2004

Run 2026-09-29. Both estimates use the same model file, the same priors and the
same settings (`mode_compute=4`, `first_obs=1`, `presample=4`, `lik_init=2`,
`prefilter=0`, `mh_replic=0`, `cova_compute=1`), and the same FRED vintage
(2026-09-29, COVID quarters kept). The only difference is the last quarter of data.

| | replication | extended |
|---|---|---|
| panel | `data/sw_repl_1966_2004.csv` | `data/sw_ext_1966_latest.csv` |
| likelihood sample | 1966Q1-2004Q4, 156 obs | 1966Q1-2026Q2, 242 obs |
| log posterior at mode | -819.673 | -1578.249 |
| Laplace log data density | -900.607 | -1668.883 |
| Hessian | PD (min eig 0.87) | PD (min eig 0.51) |

Starting the extended run from the replication mode and from the `.mod` initial
values gives the same answer: log posteriors -1578.248814 and -1578.248815, and a
largest parameter gap of 5.2e-4 (in `csigl`, whose posterior s.d. is 0.62). No
newrat fallback was needed.

Per-parameter numbers are in `mode_original_vs_extended.csv`; the figure is
`fig_mode_comparison.png`. The column `diff_in_combined_sd` divides the change by
sqrt(sd_repl^2 + sd_ext^2). **That ratio is a reading aid, not a test.** The two
samples are nested, the second contains the first, so the two modes are not
independent draws and the denominator has no sampling interpretation. Use it to
rank the moves, not to assign significance.

## In order of size

Fifteen of the 36 parameters move by more than two combined s.d. The twelve
largest are below; the other three are the persistence parameters `crhoms` (2.13),
`crhopinf` (2.06) and `crhoqs` (2.01), discussed under Persistence.

| | repl | ext | change | comb. s.d. |
|---|---|---|---|---|
| `ew` wage markup shock s.d. | 0.253 | 0.417 | +65% | 4.97 |
| `cfc` fixed cost / gross markup | 1.629 | 1.225 | -0.404 | -4.26 |
| `eb` risk premium shock s.d. | 0.240 | 0.429 | +79% | 4.25 |
| `crdy` policy response to output growth | 0.226 | 0.094 | -0.132 | -4.15 |
| `ea` TFP shock s.d. | 0.442 | 0.609 | +38% | 4.07 |
| `constelab` hours constant | 2.086 | -3.002 | -5.089 | -2.91 |
| `cry` policy response to output gap | 0.087 | 0.015 | -0.073 | -2.82 |
| `eqs` investment shock s.d. | 0.425 | 0.285 | -33% | -2.63 |
| `czcap` utilisation cost | 0.565 | 0.869 | +0.304 | 2.50 |
| `ctrend` quarterly trend growth | 0.431 | 0.386 | -0.045 | -2.38 |
| `crpi` policy response to inflation | 2.014 | 1.507 | -0.507 | -2.35 |
| `cgy` TFP to spending feedback | 0.549 | 0.310 | -0.239 | -2.26 |

### Shock standard deviations

Three grow and two shrink. The risk premium shock (`eb`) grows most in
proportional terms, +79%; the wage markup shock (`ew`) +65%; TFP (`ea`) +38%.
Against that, the investment-specific shock (`eqs`) falls by a third, 0.425 to
0.285, and government spending (`eg`) falls slightly, 0.518 to 0.491. The monetary
shock (`em`, 0.237 to 0.232) and the price markup shock (`epinf`, 0.122 to 0.136)
are unchanged for practical purposes.

The raw data say where most of this comes from. Standard deviations of the
observables, with and without the four 2020 quarters:

| | 1966-2004 | 1966-2026 | 1966-2026 ex-2020 |
|---|---|---|---|
| `dc` | 0.693 | 1.058 | 0.686 |
| `dy` | 0.850 | 1.058 | 0.777 |
| `dw` | 0.592 | 0.854 | 0.742 |
| `labobs` | 2.931 | 4.321 | 4.067 |
| `dinve` | 2.057 | 2.066 | 1.976 |
| `pinfobs` | 0.604 | 0.582 | 0.581 |

Consumption is the clear case: its extra volatility over the long sample is
entirely the 2020 quarters (1.058 with them, 0.686 without, against 0.693 before
2004). `eb` enters the consumption Euler equation, so the +79% in `eb` is close to
a pure COVID artefact. The same holds in weaker form for `dy` and so for `ea`,
which also has to absorb the 2020Q2 hours collapse (`labobs` = -19.8, against a
pre-2004 standard deviation of 2.9). `dw` is intermediate: 0.592 to 0.854 with
COVID, 0.742 without, so roughly half of the wage shock increase survives dropping
2020. The fall in `eqs` runs the other way and is not COVID: investment volatility
is the same in both samples (2.06 vs 2.06), and `eqs` falls because the extended
sample raises the persistence of the investment shock instead.

### Persistence

The AR roots move toward one. The price markup process goes from 0.882 to 0.976,
close to a unit root, and the investment-specific process from 0.695 to 0.836. The
MA terms rise with them (`cmap` 0.722 to 0.792, `cmaw` 0.883 to 0.925). The three
already-persistent processes barely move (`crhoa` 0.960 to 0.962, `crhog` 0.971 to
0.972, `crhow` 0.967 to 0.942).

The exception is the monetary policy shock. `crhoms` goes from 0.132 to 0.342,
from near white noise to visibly serially correlated. That is what a zero lower
bound looks like to a model with no ZLB: `robs` sits within a few basis points of
zero from 2009Q1 to 2015Q4 and again in 2020-2021, so the Taylor residual has to
be persistently negative for years at a stretch. This is a sample-extension
effect, not a COVID one; the 2009-2015 episode is six years long and the 2020-2021
one is two.

### Stickiness and indexation

Both Calvo probabilities rise. Prices go from 0.699 to 0.754, an implied mean
contract length of 3.3 to 4.1 quarters. Wages go from 0.738 to 0.849, or 3.8 to
6.6 quarters. Neither passes two combined s.d. (1.52 for `cprobw`, 0.94 for
`cprobp`), but both move in the same direction and the wage move is large in
economic terms.

Indexation splits. Wage indexation rises, 0.620 to 0.766; price indexation falls
by about as much in the other direction, 0.320 to 0.176, back toward the published
0.228. Both have wide posteriors (combined s.d. 0.87 and -1.08), so neither is
pinned down. The joint picture, stickier wages with more backward-looking wage
setting and less backward-looking price setting, is the usual result from
estimating this class of model through the flat Phillips curve of the 2010s.

### Policy rule

All three non-inertial coefficients fall, and the two real-activity ones fall a
lot. The inflation response `crpi` goes from 2.01 to 1.51, landing on its prior
mean. The output-gap response `cry` goes from 0.087 to 0.015, effectively to zero.
The output-growth response `crdy` more than halves, 0.226 to 0.094. The smoothing
coefficient `crr` is unchanged, 0.814 to 0.800.

Read this together with `crhoms`. The ZLB years supply seven-plus years in which
`robs` does not respond to anything, and the estimator splits the difference
between a flatter rule and a persistent policy residual. It is not evidence that
the reaction function changed in the way the numbers literally say. Anyone using
the extended estimates for policy analysis should treat the rule as the least
credible block, and should consider a ZLB-aware treatment (shadow rate,
occasionally binding constraint, or dropping 2009-2015) before drawing conclusions
from it.

### Other structural parameters

`cfc` falls from 1.629 to 1.225, the second-largest move in the table, and now
sits close to its 1.25 prior mean. `czcap` rises from 0.565 to 0.869, so capital
utilisation is much more costly to vary, which is the usual partner of a smaller
investment shock. Adjustment cost `csadjcost` rises 5.61 to 6.75 and habit `chabb`
rises 0.680 to 0.747, both inside one combined s.d. Risk aversion `csigma` falls
1.50 to 1.33 and the labour supply elasticity `csigl` falls 2.00 to 1.68, neither
meaningfully. The capital share `calfa` is unchanged at 0.21.

### Trend growth and the constants

`ctrend` falls from 0.431 to 0.386 quarterly, that is from 1.73% to 1.54% a year.
This is a real and unsurprising result: the extended sample adds two decades of
slower measured productivity growth. `cgy` falls from 0.549 to 0.310.
Steady-state inflation `constepinf` is essentially unchanged (0.836 to 0.784, or
3.34% to 3.13% annualised) and `constebeta` is unchanged (0.134 to 0.119).

**`constelab` moves from +2.086 to -3.002 and should not be compared.** `labobs`
is demeaned over the whole available panel, currently 1947Q2-2026Q2, before either
sample is sliced out of it. The constant therefore shifts one-for-one with the
demeaning window and with the vintage, and carries no information about the
estimation sample. The same caveat applies to the published mode (-0.103): the gap
to our replication value is the demeaning convention, not a difference in fit. It
is reported and flagged in the CSV, and omitted from the figure.

## What is least stable

The `dw`-related parameters, `ew`, `cprobw`, `cindw`, `crhow` and `cmaw`, are the
softest numbers here. The wage observable is the noisiest of the seven across data
vintages: the 2026-09-02 and 2026-09-29 FRED pulls differ by up to 0.035 in `dw`
and by essentially zero in the other six series, and the database validation found
`dw` to be the one series that matches `usmodel_data.mat` only up to a visible
noise band rather than to revision noise. `ew` is also the largest single move in
the table and about half COVID by the variance decomposition above. Treat the
direction, wages stickier and wage shocks bigger, as informative and the
magnitudes as not.

## COVID vs sample extension, summarised

| Change | Most likely driver |
|---|---|
| `eb` +79% | COVID. Consumption volatility ex-2020 is unchanged from the pre-2004 sample. |
| `ea` +38%, `ew` +65% | Mixed; roughly half of the `dy` / `dw` variance increase survives dropping 2020. |
| `crhoms` 0.13 to 0.34 | ZLB, 2009-2015 more than 2020. |
| `crpi`, `cry`, `crdy` all down | ZLB, same mechanism. |
| `crhopinf` to 0.976, `crhoqs` to 0.836 | Sample extension. |
| `cprobw` to 0.849, `cindw` to 0.766 | Sample extension, but see the `dw` caveat. |
| `ctrend` 0.431 to 0.386 | Sample extension. Slower post-2004 productivity growth. |
| `cfc` 1.63 to 1.23, `czcap` 0.57 to 0.87 | Sample extension. |
| `constelab` +2.09 to -3.00 | Neither. Demeaning-window artefact. |

A covid-blanked or covid-dummied re-estimation would settle the first two rows. It
was not run here because `EXCLUDE_COVID = False` is the standing instruction for
this branch.
