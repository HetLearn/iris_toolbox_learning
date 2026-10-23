# SW07 validation results (2026-10-17; filter re-run 2026-10-19)

IRIS 20230622, MATLAB R2025a. Model `../sw07.model` at `../sw07_params.m` (swX1 mode).
All checks **PASS**. The database has every observable missing (NaN) in
2020Q1-2020Q3 (the covid quarters are ignored; `covid_nan_quarters` in
`../data/build_database.m`); the filter treats them as missing data. The parameters are still
the swX1 mode, estimated with those quarters in the sample.

| check | script | criterion | result |
|---|---|---|---|
| Dynare decision rule is at the mode | `export_dynare_dr_irfs.py` | `M_.params`, shock stds = `swX1_mode.mat` to 1e-12 | max diff **0** (36 values) |
| IRFs, IRIS vs Dynare | `check_irfs.m` | max abs diff < 1e-10 | **6.9e-13** (7 shocks x 33 transition variables x 40 periods) |
| IRFs, measurement variables | `check_irfs.m` | (extra) | 1.8e-13 |
| steady state | `check_irfs.m` | `robs` = `conster`, `dy` = `ctrend` | diff 0, 0 (`conster` = 1.4201 % per quarter) |
| CSV round trip of the database | `../data/build_database.m` | < 1e-12; exactly the 21 covid values NaN | 0; 21 NaN, nothing else changed (2026-10-19) |
| smoothed observables = data | `check_filter.m` | < 1e-8 (quarters with data) | 0 |
| observables rebuilt from smoothed states via the measurement equations | `check_filter.m` | < 1e-8 (quarters with data) | **8.3e-14** (2026-10-19; 9.0e-14 before) |

## IRFs

- Dynare side: `export_dynare_dr_irfs.py` iterates `oo_.dr` (ghx, ghu) from
  `C:\dynare_work\sw_ext\swX1_out.mat` for 40 periods after a 1-sd shock (Cholesky of
  `Sigma_e`, diagonal here). Output: `dynare_irfs_swX1.csv`, `dynare_params_swX1.csv`.
  Because `M_` matched the mode exactly, no Dynare re-run was needed.
- IRIS side: `srf(m, 1:40)`. Its default `Size=@auto` sets each shock to its model std
  dev (`Legacy/@model/srf.m`), so both sides are 1-sd impulses in period 1. The srf
  output has 42 rows (two presample rows); the last 40 are compared.
- Per shock, the largest difference: ea 5.8e-14, eb 1.1e-13, eg 9.5e-14, eqs 2.3e-13,
  em 1.3e-13, epinf 6.9e-13 (inve), ew 6.1e-14. Full table: `irf_comparison.csv`.

## Filter / smoother (1965Q1-2026Q2, default IRIS initial conditions)

`[~, f] = filter(m, d, range, 'output','smooth','meanOnly',true)`. IRIS copies the data
into the smoothed measurement variables, so "smoothed observables = data" holds
mechanically; the rebuilt-observable test is the informative one. Smoothed transition
variables and shocks: `smoothed_history.csv`.

Output gap y - yf (percent): **2022Q2 -1.884**, **2026Q2 -4.717** (with the covid quarters
in the data: -1.974 and -4.693).

| quarter | em | epinf | ms |
|---|---|---|---|
| 2021Q1 | -0.3343 | 0.4246 | -0.4714 |
| 2021Q2 | -0.4726 | 0.2888 | -0.6337 |
| 2021Q3 | -0.2664 | 0.1018 | -0.4829 |
| 2021Q4 | -0.4251 | 0.1294 | -0.5901 |
| 2022Q1 | -0.4200 | 0.1982 | -0.6217 |
| 2022Q2 | -0.3441 | 0.3755 | -0.5565 |
| 2022Q3 | 0.1998 | -0.2908 | 0.0097 |
| 2022Q4 | 0.1817 | 0.0621 | 0.1850 |

Std devs at the mode: em 0.2324, epinf 0.1356. So em is -1.1 to -2.0 sd per quarter
through 2021Q1-2022Q2: with `robs` near zero the Taylor rule needs persistent negative
policy shocks (ms about -0.47 to -0.63 % per quarter, i.e. -1.9 to -2.5 pp annualised).
They switch sign in 2022Q3 when hikes begin. epinf is positive in every quarter from
2021Q1 to 2022Q2.

Covid quarters (2026-10-19). With 2020Q1-Q3 missing, the smoother fills them from the model
and the neighbouring data. Inflation (pinf, annualised deviation from the steady state),
the price mark-up shock and the output gap, with the covid data -> without:

| quarter | inflation | epinf | y - yf |
|---|---|---|---|
| 2019Q4 | -1.89 -> -1.89 | -0.015 -> -0.016 | 1.10 -> 1.13 |
| 2020Q1 | -1.16 -> -1.46 | -0.068 -> 0.095 | -0.25 -> -0.42 |
| 2020Q2 | -4.73 -> -1.50 | -0.051 -> 0.069 | -10.88 -> -2.48 |
| 2020Q3 | 0.51 -> -1.39 | 0.493 -> 0.045 | -6.16 -> -4.37 |
| 2020Q4 | -0.65 -> -0.65 | -0.322 -> -0.084 | -5.14 -> -4.14 |
| 2021Q1 | 1.93 -> 1.93 | 0.354 -> 0.425 | -4.14 -> -3.55 |
| 2021Q2 | 3.05 -> 3.05 | 0.259 -> 0.289 | -2.54 -> -2.18 |
| 2021Q3 | 2.97 -> 2.97 | 0.090 -> 0.102 | -2.51 -> -2.28 |
| 2021Q4 | 3.69 -> 3.69 | 0.126 -> 0.129 | -2.06 -> -1.90 |

Inflation is observed again from 2020Q4, so only the missing quarters change; the output gap
and the shocks change through 2021 because the unobserved states differ.

## Cross-check against Dynare's own smoother (informal)

Made on 2026-10-17 with the full data (covid quarters included); not redone after 2026-10-19.

`oo_.SmoothedVariables` / `oo_.SmoothedShocks` in `swX1_out.mat` (Dynare smoother at the
mode, `lik_init=2`), compared with `smoothed_history.csv` in Python (not a saved script):

| series | max abs diff, last 40 quarters |
|---|---|
| pinf, r | 4e-14 |
| em, ea | 5e-4, 1.2e-3 |
| epinf | 2.9e-3 |
| ms | 7.8e-4 |
| y | 0.043 (constant offset over the whole sample) |
| yf | 0.22 |

Dynare's output gap is -1.710 at 2022Q2 and -4.429 at 2026Q2, about 0.26 above the IRIS
numbers. The cause is the initial condition: Dynare's `lik_init=2` starts the smoother
from P0 = 10 x I, IRIS from the asymptotic distribution. The levels of y, c, inve and w
are only pinned up to a constant by the growth observables, and yf moves through
near-unit-root states (crhoa 0.96, crhog 0.97, capital), so the difference decays
slowly. Shocks and observed-block variables agree closely. Treat output-gap levels as
uncertain to about +/-0.3 pp from initialisation alone.

## IRIS issues met

None. The model parsed, solved and filtered on the first run. Two label edits to be safe
with the IRIS parser: apostrophes dropped (Tobin's q -> Tobin q, Firms' -> Firm) and
parentheses around label sub-clauses turned into commas; equations untouched.

## Re-run

```matlab
% IRIS on the path, then from models/sw07:
addpath(pwd, fullfile(pwd,'data'), fullfile(pwd,'validation'));
build_database(); check_irfs(); check_filter();
```
Dynare IRFs: `python export_dynare_dr_irfs.py C:/dynare_work/sw_ext/swX1_out.mat swX1 ../estimation/swX1_mode.mat` from `validation/`.
