# as07 database

`build_database.m` -> `as07_database.csv` (`databank.toCSV`, `%.17g`), `as07_database.mat`
(struct `d`) and `us_txt_match.csv`. Quarterly, 1964Q1-2026Q2 (250 quarters). 1964 is a
presample; `spec.filter_range` starts in 1965Q1, like SW07's. Needs IRIS on the path.

## Source

`raw/canova_raw_fred_data.csv`, FRED vintage 2026-09-29, a copy of
`models/sw07/data/raw/canova_raw_fred_data.csv` (identical, SHA-256 5962950D7610D83202C3520FB61D873D054A6D180BAFCDDF6DFD90EC937EEF11).
`gather_data.py` (in `models/sw07/data/raw/`) has already averaged the monthly series to
quarters. Columns used: `real_gdp` (GDPC1), `civ_pop` (CNP16OV, quarterly average), `cpi`
(CPIAUCSL, quarterly average), `fedfunds` (FEDFUNDS, quarterly average); `gdp_deflator`
(GDPDEF) and `cpi_core` (CPILFESL) enter only the definition check. The book's estimation data
are `../estimation/hs2016/us.txt` (1983Q1-2002Q4, ygr, infl, int); `book_data/dsge1_data.csv` is
the same 80 rows with a header (checked to 1e-6).

## Series

| series | definition | units |
|---|---|---|
| `dy` | 100 Δlog GDPC1 - 100 Δ HP trend (λ = 1600) of log CNP16OV; trend fitted over 1948Q1-2026Q2 | % q/q, per capita |
| `pinfobs` | 400 Δlog CPIAUCSL | % a year |
| `robs` | FEDFUNDS; NaN when FEDFUNDS < 0.25% a year | % a year |
| `dy_rawpop` | helper, not observed: 100 Δlog(GDPC1 / CNP16OV), the SW07 definition | % q/q |
| `ffr` | FEDFUNDS in every quarter (`robs` before the ELB blanking) | % a year |
| `elb` | 1 in ELB quarters, 0 otherwise | |

Units are the book's: YGR in % per quarter, INFL and INT annualised. The model's `pinf` and `r`
are in % per quarter; the measurement equations multiply them by 4 (`../README.md`, "Units").

## Definitions: match with us.txt

The replication files do not state the definitions (`ReadMe.txt` points to the book's
appendix). The authors' Chapter 4 slides
(https://web.sas.upenn.edu/schorf/files/2017/05/chapter4_sl_0-1sxxi8g.pdf, "Observables for
Small-Scale New Keynesian Model") describe them in words: per capita output growth in q/q
percent, CPI inflation in annualised q/q percent, and the average annualised effective funds
rate of each quarter. They do not name the population series. `build_database.m` therefore
builds candidates and compares each with us.txt over 1983Q1-2002Q4, and asserts that the chosen
ones have the smallest rms difference. Constructed minus book:

| candidate | us.txt | corr | mean diff | max abs diff | rms diff | chosen |
|---|---|---|---|---|---|---|
| per capita, HP-trend CNP16OV | ygr | 0.9819 | +0.0093 | 0.301 (1998Q2) | 0.110 | yes |
| per capita, raw CNP16OV | ygr | 0.9498 | +0.0113 | 0.980 (2000Q1) | 0.189 | |
| total GDP growth | ygr | 0.9798 | +0.3031 | 0.648 | 0.325 | |
| CPI, 400 Δlog CPIAUCSL | infl | 0.9984 | +0.0028 | 0.442 (2002Q4) | 0.082 | yes |
| GDP deflator | infl | 0.6828 | -0.6291 | 3.766 | 1.242 | |
| core CPI | infl | 0.6140 | +0.3103 | 5.265 | 1.207 | |
| FEDFUNDS, quarterly average | int | 1.0000 | -2e-9 | 3.3e-7 | 4.6e-8 | yes |

- Inflation is CPI inflation, the funds rate the quarterly average of FEDFUNDS (us.txt rounds
  it to seven decimals).
- Output growth is per capita: total GDP growth is 0.30 pp a quarter too high on average. With
  the raw CNP16OV the January population-control steps are misses (2000Q1: 0.98 pp), while
  us.txt has no steps, so the book's population series was smooth. An HP trend of log CNP16OV
  matches best. Also tried, in a scratch run outside the package: λ = 10^4 (rms 0.110),
  λ = 10^5 (0.118), total growth minus a constant (0.117), Q1 steps replaced by the median growth
  of the eight neighbouring quarters (0.127).
- What is left (max 0.30 for ygr, 0.44 for infl, largest in 1998-2002) is revisions since the
  book's vintage: GDP benchmark revisions and the CPI seasonal factors, which BLS revises for
  the latest five years.

## CNP16OV steps

Largest quarterly CNP16OV growth in the sample (median 0.283%): 2000Q1 1.39%, 2025Q1 1.25%,
1972Q1 1.13%, 2012Q1 0.83%, 1990Q1 0.80%, 2003Q1 0.71%. Per capita growth in those quarters:

| quarter | `dy_rawpop` | `dy` |
|---|---|---|
| 2000Q1 | -1.03 | -0.00 |
| 2025Q1 | -1.41 | -0.43 |
| 1972Q1 | 0.69 | 1.26 |
| 2012Q1 | 0.00 | 0.58 |
| 1990Q1 | 0.29 | 0.81 |
| 2003Q1 | -0.19 | 0.19 |

The HP trend spreads each step over nearby quarters rather than removing it: over
2023Q1-2026Q2 trend population growth averages 0.258% a quarter against 0.274% raw. At the
application-1 origin (2022Q2) `dy` is 0.067 below `dy_rawpop`. The models/sw07 data README
describes the 2025Q1 step.

## Effective lower bound

`robs` is NaN when the quarterly average of FEDFUNDS is below 0.25% a year: 2009Q1-2015Q4 and
2020Q2-2022Q1, 36 quarters. `build_database.m` asserts this set. The Kalman filter then infers
the rate from the other observables, so the smoothed rate is a shadow rate (`../README.md`, "ELB
treatment"). The rule is the same as in IJCB3.

## Summary statistics

| | `dy` | `pinfobs` | `robs` |
|---|---|---|---|
| mean 1965Q1-2026Q2 (robs: non-ELB quarters) | 0.387 | 3.850 | 5.759 |
| us.txt mean, 1983Q1-2002Q4 | 0.557 | 3.082 | 6.045 |
| us.txt std | 0.580 | 1.471 | 2.238 |
| model steady state (`as07_params`, published means) | 0.520 | 3.300 | 5.800 |

CPI inflation peaks in 2022Q2 at 9.30% a year (2.32% q/q) within 2020Q1-2024Q4, the
application-1 origin.

## Refresh

Copy a new `canova_raw_fred_data.csv` into `raw/` with PowerShell `Copy-Item`, then run
`build_database` in MATLAB with IRIS on the path. The assertions stop the build if the ELB
quarters change or a chosen definition stops matching us.txt best. The HP trend, and with it
`dy` near the end of the sample, moves with each vintage.
