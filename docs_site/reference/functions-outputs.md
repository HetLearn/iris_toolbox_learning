# Functions and outputs

`help hetlearn.<name>` in MATLAB gives the full text of each function. Abbreviations: RE,
rational expectations; PLM, perceived law of motion; RLS, recursive least squares; DM,
Diebold-Mariano; RMSE, root-mean-square error; SW07, the Smets and Wouters (2007) model.

## Project functions

| Call | What it does |
|---|---|
| `setup_paths()` | Starts IRIS unless started; adds the toolbox, the IRIS patch (first on the path), `config/` and `scenarios/` with subfolders |
| `L = run_applications(groups, ...)` | Runs groups `'app1'`-`'app6'`, `'var1'`-`'var4'`, `'eval'`, `'all'` (default), a scenario id, or a cell of these; `'decompose'`; `'eval_part', variants, parts [, K]`; `'eval_merge'`. Logs every run in `results/run_log.csv` and returns this call's rows |
| `o = master_options()` | The project-wide partial option tree (`config/master_options.m`) |
| `run_br_app1(cmd)` | The seven [further expectation rules](../applications/app7-rules.md) in Application 1: `'check'`, `'run'`, `'csv'`, `'ids'` |
| `run_br_portfolio(cmd)` | Their impulse responses and Kalman RMSE: `'irf'`, `'rmse'`, `'check'`, `'csv'`, `'ids'` |
| `run_tests(only)` | Test suites (in `tests/`; `addpath('tests')` first) |

## Toolbox functions

| Signature | What it does |
|---|---|
| `res = hetlearn.run(cfg, 'save', true, 'results_dir', folder, 'quiet', false)` | One scenario run. Also `'model'` (a preloaded model for the same options) and `'filter'` (an RE filter output to reuse) |
| `T = hetlearn.run_files(names, <run options>)` | Runs scenario files in order (each one re-run) and returns a status table |
| `T = hetlearn.compare(ids, vars, range, 'results_dir', folder)` | Levels (`<var>__<id>`) and differences from the first id (`<var>__<id>_minus_<id1>`) of saved scenarios; runs a missing one first |
| `D = hetlearn.decompose(res, vars, range, opts)` | Shock decomposition ([page](../options/decompositions.md)) |
| `E = hetlearn.evaluate(name, variants, origins, opts)` | Recursive real-time forecast evaluation ([page](../options/evaluation.md)) |
| `T = hetlearn.evaluate_tables(errors, opts)` | Metrics, relative RMSE and DM tables from saved forecast errors |
| `o = hetlearn.defaults()` | The full option tree with defaults |
| `opts = hetlearn.load_options(cfg, master)` | Merge and validate; `master` replaces `master_options()` |
| `spec = hetlearn.load_spec(name)` | A package's `model_spec` (name under `models/`, or a folder path) |
| `[d, file] = hetlearn.load_database(spec)` | The package database as an IRIS databank |
| `[m, info] = hetlearn.load_model(spec, opts)` | Generate (if needed), load, parameterize and solve the extended model |
| `H = hetlearn.re_filter(spec, opts, 'force', false, 'end', date, 'model', MA)` | RE Kalman filter and smoother, cached; `'end'` for real-time data |
| `meta = hetlearn.extend_model(spec, plm, 'force', false, 'validate', true)` | Write the extended model file and run the collapse test |
| `[A, info] = hetlearn.re_anchor_coefficients(spec, P, ...)` | Coefficients of the anchored RE forecast |
| `[R, info] = hetlearn.anchor_coefficients(m, targets, states, 'lag', j, 'horizon', h, ...)` | Coefficients of \(E_{t-j} z_{t+h}\) in a solved economy |
| `A = hetlearn.agent_types(opts)` | The agent types of a run, resolved against the other options |
| `T = hetlearn.engine.kalman_history('rmse', res, subsamples)` | One-step RMSE by observable and subsample, and the log likelihood, of a `history.mode = 'kalman'` result |
| `t = hetlearn.find_peak(db, name, from, to)` | Date of a series' maximum in a window (the first if tied) |

## The result struct `res`

| Field | Content |
|---|---|
| `res.cfg` | The merged options |
| `res.paths` | Databank from the filter start to origin + H: the RE history, then the scenario; every variable and shock |
| `res.learning.<x>` | Learning series of each PLM target (below) |
| `res.events` | Table: date, type, variable, detail, stage |
| `res.state` | The final learning state |
| `res.dates` | Origin, horizon and record dates |
| `res.meta` | Run times, IRIS version, model and filter hashes, filter fit, collapse test, history check time |
| `res.loss` | Discounted policy loss (packages with `spec.policy`) |
| `res.density` | Density results (with `density.enabled`) |
| `res.kalman` | Kalman-history results (with `history.mode = 'kalman'`) |

`res.learning.<x>` holds IRIS Series: the beliefs named like the model parameters
(`alpha_<x>`, `beta_<x>`, or `beta_<x>__<u>_l<lag>`), `R_<param>` (diagonal of the RLS moment
matrix), `gain` (and `gain_R` with the endogenous gain), and for learning variables `n1`, `n2`,
`n1_model`, `zetaRE`, `zetaBR`, `FE_RE`, `FE_BR`, `fRE`, `fBR`.

## Files in `results/<id>/`

| File | Content |
|---|---|
| `results.mat` | `res` (without the density) |
| `observables.csv` | Date and every observable, filter start to origin + H, model units |
| `paths.csv` | Date and every transition variable over the horizon |
| `learning.csv` | Long format: date, variable, field, value |
| `events.csv` | date, type, variable, detail, stage |
| `compare_<id>.csv` | This run minus `<id>`, observables over the horizon, model units |
| `loss.csv` | Policy loss by target and total |
| `density.mat`, `density_quantiles.csv`, `density_events.csv` | Density forecasts |
| `decomposition.csv`, `decomposition_check.csv` | After `hetlearn.decompose` (the check file from `run_applications`) |
| `kalman_errors.csv` | Kalman history: errors, predictions, variances, log-likelihood contributions |

## Events

| Type | Meaning |
|---|---|
| `projection_plm` | A PLM block kept its beliefs (facility `'plm_alm'`) |
| `projection_alm` | No stable model solution: every belief went back to its value before the update |
| `projection_alm_shares` | Still unstable: last quarter's model shares stayed in force |
| `explosive` | A model without leads was simulated without a stable solution |
| `rls_missing` | Missing data for a PLM equation; that equation kept its beliefs |
| `shares_nan` | Non-finite shares; the previous fitness and shares were kept |
| `gain_bound` | The endogenous gain hit a bound |

## Units

Model units are percent quarter on quarter (SW07: inflation and the policy rate in percent per
quarter, hours 100 x log). Report units multiply by `spec.report.scale` (4 annualizes). The
`value_report` columns, the evaluation errors and the summary tables are in report units;
learning series are in model units.

## Project-level files

| File | Written by |
|---|---|
| `results/run_log.csv` | `run_applications`: logged, group, id, status, runtime_s, events, message |
| `results/eval_<name>/` | `hetlearn.evaluate` and `run_applications('eval_merge')` |
| `results/summary_v3/*.csv`, `checks_v3.txt` | `results/summary_v3/build_summary_v3.m` |
| `results/br_portfolio/*.csv` | `run_br_app1('csv')`, `run_br_portfolio('csv')` |
| `models/<name>/generated/` | The toolbox: extended model files and RE filter caches |
