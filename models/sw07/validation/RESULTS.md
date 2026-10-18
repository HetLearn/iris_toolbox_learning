# SW07 validation results (2026-10-17)

IRIS 20230622, MATLAB R2025a. Model `../sw07.model` at `../sw07_params.m` (swX1 mode).
All checks **PASS**.

| check | script | criterion | result |
|---|---|---|---|
| Dynare decision rule is at the mode | `export_dynare_dr_irfs.py` | `M_.params`, shock stds = `swX1_mode.mat` to 1e-12 | max diff **0** (36 values) |
| IRFs, IRIS vs Dynare | `check_irfs.m` | max abs diff < 1e-10 | **6.9e-13** (7 shocks x 33 transition variables x 40 periods) |
| IRFs, measurement variables | `check_irfs.m` | (extra) | 1.8e-13 |
| steady state | `check_irfs.m` | `robs` = `conster`, `dy` = `ctrend` | diff 0, 0 (`conster` = 1.4201 % per quarter) |
| CSV round trip of the database | `../data/build_database.m` | < 1e-12 | 0 |
| smoothed observables = data | `check_filter.m` | < 1e-8 | 0 |
| observables rebuilt from smoothed states via the measurement equations | `check_filter.m` | < 1e-8 | **9.0e-14** |

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

Output gap y - yf (percent): **2022Q2 -1.974**, **2026Q2 -4.693**.

| quarter | em | epinf | ms |
|---|---|---|---|
| 2021Q1 | -0.4017 | 0.3541 | -0.5083 |
| 2021Q2 | -0.4806 | 0.2593 | -0.6542 |
| 2021Q3 | -0.2708 | 0.0903 | -0.4943 |
| 2021Q4 | -0.4276 | 0.1257 | -0.5966 |
| 2022Q1 | -0.4216 | 0.1976 | -0.6254 |
| 2022Q2 | -0.3450 | 0.3760 | -0.5587 |
| 2022Q3 | 0.1991 | -0.2901 | 0.0082 |
| 2022Q4 | 0.1812 | 0.0626 | 0.1840 |

Std devs at the mode: em 0.2324, epinf 0.1356. So em is -1.2 to -2.1 sd per quarter
through 2021Q1-2022Q2: with `robs` near zero the Taylor rule needs persistent negative
policy shocks (ms about -0.5 to -0.65 % per quarter, i.e. -2 to -2.6 pp annualised).
They switch sign in 2022Q3 when hikes begin. epinf is positive in every quarter from
2021Q1 to 2022Q2.

## Cross-check against Dynare's own smoother (informal)

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
