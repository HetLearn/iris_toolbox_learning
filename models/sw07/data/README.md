# SW07 database

Seven quarterly observables, 1965Q1-2026Q2 (246 quarters), FRED vintage **2026-09-29**.
This is the exact panel the Dynare run `swX1` was estimated on (file hash identical to
`C:\dynare_work\sw_ext\sw_ext_1966_latest.csv` and `ucur-dsge/sw07-extended/data/`).

## Chain

| step | file | what happens |
|---|---|---|
| 1 | FRED | monthly/quarterly series, pulled with `END=None` (latest vintage) |
| 2 | `raw/gather_data.py` | download, quarterly averages, writes `canova_raw_fred_data.csv`; `build_dataset_sw` builds the observables |
| 3 | `raw/canova_dataset_SW_observables_balanced.csv` | balanced panel 1954Q3-2026Q2 |
| 4 | `sw_ext_1966_latest.csv` | 1965Q1-2026Q2 slice, columns unchanged (made in `ucur-dsge/sw07-extended/data`) |
| 5 | `build_database.m` | IRIS databank: `sw07_database.csv` (`databank.toCSV`, `%.17g`) and `sw07_database.mat` (struct `d`); checks the CSV round trip to 1e-12 (result: 0) |

`raw/` holds provenance copies of `ucur-dsge/gather_data.py`, `canova_raw_fred_data.csv`
and `canova_dataset_SW_observables_balanced.csv`. Nothing in `raw/` is read by the package.

## Conventions (SW 2007 appendix)

| obs | definition | units |
|---|---|---|
| `dy` | 100 dlog(GDPC1 / CNP16OV) | % q/q, per capita |
| `dc` | 100 dlog(PCE / GDPDEF / CNP16OV) | % q/q, per capita; nominal deflated by the GDP deflator |
| `dinve` | 100 dlog(FPI / GDPDEF / CNP16OV) | % q/q, per capita; fixed investment, nominal deflated by the GDP deflator |
| `dw` | 100 dlog(COMPNFB / GDPDEF) | % q/q |
| `labobs` | 100 log(PRS85006023 x CE16OV / CNP16OV), demeaned over 1947Q2-2026Q2 | 100 x log |
| `pinfobs` | 100 dlog(GDPDEF) | % q/q |
| `robs` | FEDFUNDS / 4 (quarterly average) | % per quarter |

- Covid quarters 2020Q1-Q3: the raw panel keeps them (`EXCLUDE_COVID = False`, no dummies), but
  since 2026-10-19 `build_database.m` sets all seven observables to NaN in 2020Q1-2020Q3
  (`covid_nan_quarters`; user decision 2026-10-19: ignore the covid quarters). The database
  therefore has exactly 21 missing values, and the RE filter treats those quarters as missing.
  The swX1 parameters were estimated with the covid quarters in the sample.
- Because `labobs` is demeaned over the full panel, `constelab` moves with the
  demeaning window and is not comparable across samples or vintages.

## CNP16OV break in January 2025

The 2025Q1 per-capita growth rates (`dy` -1.41, `dc` -1.14) are mostly a population
artefact. The raw file holds quarterly averages of CNP16OV (monthly values are not
stored). Its 2025Q1 average is 272.85 million against 269.46 million in 2024Q4:
+3.39 million, or **+1.25% (log) in one quarter**, against an average of 0.18% per
quarter over 2023Q2-2024Q4 and 0.16% over 2025Q2-2026Q2. The excess, 1.07 pp
(about 2.9 million people), is consistent with the January 2025 CPS population-control
adjustment, which is introduced as a level step and not revised back into history.

- `dy` 2025Q1 is -1.41; with normal population growth it would be **-0.34**
  (aggregate real GDP growth was -0.16% q/q). `dc` would be -0.07 instead of -1.14.
  `dinve` is shifted by the same 1.07 pp.
- `labobs` is barely affected: CE16OV, the numerator, jumped by the same step (+1.33%).
- Earlier January steps of the same kind are in the series (largest quarterly CNP16OV
  growth since 1990: 2000Q1 1.39%, 2025Q1 1.25%, 2012Q1 0.83%, 1990Q1 0.80%,
  2003Q1 0.71%, 2023Q1 0.53%).

The data are left unchanged here because the estimation used them as they are.
A fix would smooth CNP16OV over the break (e.g. replace the 2025Q1 step by trend growth)
before forming per-capita series.

## Refresh

1. In `Desktop/ucur-dsge`, run `python gather_data.py` (pulls the latest FRED vintage,
   rewrites the raw and balanced CSVs).
2. Slice 1965Q1-latest into `sw_ext_1966_latest.csv` (same columns) and copy it here
   with PowerShell `Copy-Item` (OneDrive path).
3. Update the end date in `build_database.m` and in `model_spec.m` (`filter_range`), then
   run `build_database`.
4. The parameters in `sw07_params.m` stay at the swX1 mode unless the model is re-estimated.
