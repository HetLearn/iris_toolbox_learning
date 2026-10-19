# sw07: Smets-Wouters (2007), re-estimated 1966Q1-2026Q2

The SW (2007, AER) medium-scale New Keynesian model, log-linear, seven shocks and seven
US observables, at the posterior mode of Dynare run `swX1` (2026-09-29, Dynare 4.6.1,
likelihood sample 1966Q1-2026Q2, log posterior -1578.2488). The equations are Pfeifer's
Dynare version of the AER `usmodel.mod`, translated line by line to IRIS. This is the
first model of the `hetlearn` portfolio and follows `docs/DESIGN.md` sec. 2.

## Files

| file | what |
|---|---|
| `model_spec.m` | package contract (name, files, filter range 1965Q1-2026Q2, observables, report labels/units/scale) |
| `sw07.model` | IRIS model file; Dynare names and equation order; derived steady-state ratios as nested `!substitutions` |
| `sw07_params.m` | swX1 mode: 29 estimated parameters, 7 `std_<shock>`, 5 fixed (generated from `estimation/swX1_mode.mat`) |
| `data/` | `build_database.m` -> `sw07_database.csv/.mat`; source panel and raw FRED provenance; `README.md` |
| `estimation/` | provenance copies of the Dynare run (not re-run); `README.md` |
| `validation/` | Dynare IRF export, `check_irfs.m`, `check_filter.m`, `RESULTS.md`, outputs |

## Load and solve

```matlab
m = Model.fromFile('sw07.model', 'linear', true);
m = assign(m, sw07_params());
[m, flag] = solve(m); m = sstate(m);   % hasSucceeded(flag) must be true
```

## Validation (2026-10-17, all pass; details in `validation/RESULTS.md`)

- IRFs to 1-sd shocks match Dynare's swX1 decision rule to 6.9e-13 (7 shocks, 33
  variables, 40 quarters).
- Filter/smoother over 1965Q1-2026Q2 reproduces the data from the smoothed states to
  8.3e-14 (quarters with data). Smoothed output gap y - yf: 2022Q2 -1.88, 2026Q2 -4.72
  (percent; -1.97 and -4.69 with the covid quarters in the data).
- Covid quarters: every observable is NaN in 2020Q1-2020Q3 (user decision 2026-10-19,
  `data/build_database.m`); the parameters are still the swX1 mode, estimated with them.

## Known quirks

- `constelab` (-3.00) is not comparable across samples or vintages: `labobs` is demeaned
  over the whole 1947Q2-2026Q2 panel, so the constant moves with the window.
- The ZLB years (2009-2015, 2020-2021) flatten the Taylor rule (`crpi` 1.51, `cry` 0.015,
  `crdy` 0.094) and raise `crhoms` from 0.13 to 0.34; the smoothed policy shocks are
  persistently negative while `robs` sits near zero. See `estimation/FINDINGS_estimates.md`.
- The January 2025 CPS population-control step in CNP16OV (+1.07 pp excess population
  growth in 2025Q1) drags 2025Q1 `dy` to -1.41 (-0.34 without it) and `dc`, `dinve` by the
  same amount. The data are left as estimated; see `data/README.md`.
- Output-gap levels depend on the smoother's initial condition: Dynare's `lik_init=2`
  smoother gives about 0.26 pp higher gaps than IRIS's default (asymptotic) start.
- The database ends 2026Q2; refresh steps are in `data/README.md`.
