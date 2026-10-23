# ijcb3 database

Three observables and four helper series, quarterly, 1957Q1-2026Q2 (278 quarters), FRED
vintage **2026-09-29**, built by `build_database.m` (MATLAB, IRIS) from
`raw/canova_raw_fred_data.csv`.

## Chain

| step | file | what happens |
|---|---|---|
| 1 | FRED | GDPC1, CPIAUCSL and FEDFUNDS (with the SW07 series), pulled by `ucur-dsge/gather_data.py` on 2026-09-29 |
| 2 | `raw/canova_raw_fred_data.csv` | quarterly file with quarter-start dates; the monthly CPI and fed funds are already quarterly averages. Copy of `models/sw07/data/raw/canova_raw_fred_data.csv` (SHA-256 `5962950D7610D83202C3520FB61D873D054A6D180BAFCDDF6DFD90EC937EEF11`, identical) |
| 3 | `build_database.m` | the transformations below; writes `ijcb3_database.csv` (`databank.toCSV`, `%.17g`) and `ijcb3_database.mat` (struct `d`); CSV round trip checked to 1e-12 (result: 0) |

## Series

| series | definition | units |
|---|---|---|
| `yobs` | output gap: Hamilton (2018) regression filter on y = 100 log GDPC1, h = 8, p = 4, with the coefficients of IJCB's own sample: OLS of y_{t+8} on a constant and y_t, ..., y_{t-3} over the gap dates 1957Q1-2019Q4. At every date the gap is y_{t+8} minus the fitted value from those coefficients with z in the regressors: z = y, except that z for 2020Q1-2020Q3 lies on a straight line between the 2019Q4 and 2020Q4 values (the dependent variable keeps the data). Through 2019Q4 this is the regression's own residual; from 2020Q1 it is out of sample | % of trend output |
| `pinfobs` | 100 Δlog CPIAUCSL, quarterly average of the monthly index; equals the raw file's `inflation_cpi_q` (checked) | % q/q, not annualised |
| `robs` | FEDFUNDS, quarterly average, divided by 4; NaN in ELB quarters | % per quarter |
| `ffr` | FEDFUNDS/4 in every quarter: `robs` before the ELB blanking | % per quarter |
| `elb` | 1 in ELB quarters, 0 otherwise | |
| `yobs_hamilton` | helper, not an observable: the plain Hamilton gap, OLS over 1957Q1-2026Q2 on unadjusted GDP | % of trend output |
| `yobs_fullsample` | helper, not an observable: covid-adjusted regressors, OLS over 1957Q1-2026Q2 (an earlier definition of `yobs`) | % of trend output |

Only `yobs`, `pinfobs` and `robs` are observables (`../model_spec.m`). IJCB uses the same FRED
series (App. B) and applies the Hamilton filter "to log(GDP_t) over the estimation sample".
`yobs` follows that: the regression runs over IJCB's sample with its burn-in, gap dates
1957Q1-2019Q4, so over 1960Q1-2019Q4 `yobs` is IJCB's construction on this vintage
(`build_database.m` checks that it equals the regression residuals there). From 2020Q1 the same
coefficients extend it.

| regression | gap dates | regressors | constant | y_t | y_{t-1} | y_{t-2} | y_{t-3} | series |
|---|---|---|---|---|---|---|---|---|
| IJCB sample | 1957Q1-2019Q4 | data (no covid quarters in the sample) | 23.51 | 1.295 | -0.406 | -0.177 | 0.269 | `yobs` |
| full sample, adjusted | 1957Q1-2026Q2 | covid-adjusted | 23.30 | 1.290 | -0.416 | -0.190 | 0.297 | `yobs_fullsample` |
| full sample, plain | 1957Q1-2026Q2 | data | 23.21 | 0.943 | -0.075 | -0.063 | 0.176 | `yobs_hamilton` |

The covid rows tilt the plain full-sample slopes; with adjusted regressors the full-sample
slopes are close to the IJCB-sample ones. Estimating the `yobs` coefficients from 1949Q4, the
earliest date the data allow, instead of 1957Q1 moves the gap by at most 0.86 pp over
1960Q1-2026Q2.

## Units

Percent per quarter for inflation and the rate, as in IJCB's estimation (evidence in
`../README.md`, "Units"). Reports annualise both (scale 4 in `model_spec.m`). Sample moments,
1960Q1-2019Q4: `pinfobs` mean 0.905, std 0.753; FEDFUNDS/4 mean 1.249; `yobs` mean 0.20,
std 3.07.

## Effective lower bound

ELB quarters are those where the quarterly average of FEDFUNDS is below 0.25% a year:
2009Q1-2015Q4 and 2020Q2-2022Q1, 36 quarters. `build_database.m` asserts this set. In these
quarters `robs` is NaN, so the Kalman filter infers the policy rate from inflation and the gap
through the Taylor rule, and the smoothed rate is a shadow rate (`../README.md`, "ELB
treatment"). FEDFUNDS/4 averaged 0.032 over 2009Q1-2015Q4 (std 0.0095). The first quarter
after the covid episode, 2022Q2, is observed (`robs` 0.1925, 0.77% a year) and is also the
application-1 origin.

## Covid adjustment of the output gap

No dummies; the 2020 quarters stay in. The plain Hamilton gap at t+8
is the error of a projection from y_t, ..., y_{t-3}, so the lockdown trough of 2020Q2 comes
back eight quarters later, when it is a regressor: +9.0 in 2022Q2, the application-1 origin.
With the IJCB-sample coefficients and the 2020Q1-Q3 regressors on a straight line, `yobs` is
1.00 there. The dependent variable is untouched, so `yobs` still records the 2020 collapse
itself (-9.6 in 2020Q2, its minimum).

| quarter | `yobs_hamilton` (plain) | `yobs_fullsample` | `yobs` |
|---|---|---|---|
| 2020Q2 | -9.809 | -9.624 | -9.600 |
| 2022Q1 | 1.374 | 0.799 | 0.828 |
| 2022Q2 | 9.009 | 0.942 | 0.998 |
| 2022Q3 | 1.857 | 1.618 | 1.699 |
| 2022Q4 | 1.758 | 2.533 | 2.614 |
| 2023Q1 | 3.172 | 1.395 | 1.468 |
| 2023Q2 | 1.065 | 0.445 | 0.494 |
| 2026Q2 | -0.038 | 0.000 | 0.043 |

IJCB's 1960-2019 sample. Over 1960Q1-2019Q4 `yobs` is identical to IJCB's construction: neither
the covid quarters nor the interpolation enter its coefficients or its regressors there. The
helpers differ from it by up to 1.23 pp (`yobs_hamilton`) and 0.14 pp (`yobs_fullsample`) over
those years, because their coefficients include the post-2019 rows.

## Refresh

1. In `Desktop/ucur-dsge`, run `python gather_data.py` (latest FRED vintage).
2. Copy the new `canova_raw_fred_data.csv` into `raw/` with PowerShell `Copy-Item` (OneDrive
   path).
3. Update the end quarter in `build_database.m` (`iLast`, `endDate`) and `filter_range` in
   `../model_spec.m`, then run `build_database`. The ELB assert fails if a new episode starts.
4. `scenarios/ijcb3/app1_peak/i1_re.m` asserts the 2022Q2 peak and fails if a revision moves it.
