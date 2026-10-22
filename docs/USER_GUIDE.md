# hetlearn user guide

`hetlearn` is a MATLAB toolbox on IRIS 20230622 (MATLAB R2025a) for forecasts and scenarios with
two kinds of agents: rational (RE) agents and adaptive learners (constant-gain RLS) whose
population shares switch on past forecast errors, after Özden (2025, IJCB 21(1)). This guide
shows how to rerun every case in the report, where each assumption lives, how to change it, and
what each output file holds.

Other documents: `docs/DESIGN.md` (algorithms, timing, file contracts), `docs/FEATURES.md`
(every feature, where it is set, whether you asked for it or it was ADDED during the build),
`README_PIPELINE.md` (pipeline map and status).

Checked against the code on 2026-10-19; the baseline (1.4) and the options it touches updated
on 2026-10-20; report section 12 (ijcb3, as07) removed on 2026-10-21; section 9 (bounded-rationality
expectation rules, the options of `docs/DESIGN_br_extensions.md`) added on 2026-10-21 and cut to the
seven kept portfolio variants on 2026-10-22 (9.10); run times measured on 2026-10-18. Line numbers are
given as `file` line N. They move when a file is edited, so each one comes with the code it
points to. All paths are relative to the project root
(`<project root>` below: the folder that holds `setup_paths.m`).

---

## 1. What is what

### 1.1 Project map

| Path | What it is | Who edits it |
|---|---|---|
| `setup_paths.m` | Starts IRIS (the folder in the environment variable `HETLEARN_IRIS_DIR`, else `IRIS-Toolbox-Release-20230622` next to the project root), then adds `toolbox/`, the IRIS patch, `config/` and `scenarios/` with every subfolder to the path | Nobody; set `HETLEARN_IRIS_DIR` if IRIS is elsewhere |
| `config/master_options.m` | Project-wide option values: the SW07 baseline of 2026-10-20 (lines 86-97, the `o.*` lines; 1.4), a dated table of the previous values above them, and commented knobs (lines 100-102) | You |
| `scenarios/sw07/<folder>/<id>.m` | The 52 SW07 scenario files, one function per file. Each calls its parent and sets what differs | You |
| `scenarios/ijcb3/app1_peak/`, `scenarios/as07/app1_peak/` | Application 1 on the two other models: `i1_re`, `i1_learn`, `a1as_re`, `a1as_learn`. Unused since 2026-10-21 (removed from the report; kept in place) | Nobody |
| `scenarios/sw07/INDEX.csv` | One row per SW07 scenario file (52 rows): folder, id, parent, options it sets, compare_with, has_results, title | `python scenarios/build_index.py` |
| `models/sw07/`, `models/ijcb3/`, `models/as07/` | Model packages: model file, parameters, data, `model_spec.m`, validation (1.2); ijcb3 and as07 unused since 2026-10-21 | You, when the model, its parameters or its data change |
| `run_applications.m` | Runner for the SW07 applications, model variants and forecast evaluation: run groups, run log, evaluation parts and merge | You, to change a group, the decompositions or the evaluation settings |
| `results/<id>/` | Output of one scenario run | Written by each run (overwritten) |
| `results/run_log.csv` | One row per run, decomposition and evaluation part | Appended by `run_applications` |
| `results/eval_sw07_v3/` | The forecast evaluation (parts and merged tables) | Written by `run_applications('eval')` |
| `results/summary_v3/build_summary_v3.m` | Summary tables and checks of the SW07 runs | You, when the report must show a new scenario or a changed setting (4.7) |
| `results/summary_v3/build_other_models.m` | Tables and checks of application 1 on ijcb3 and as07. Retired 2026-10-21 with report section 12: not run; its `other_models_*` files are kept but nothing reads them | Nobody |
| `results/summary_v3/*.csv`, `checks_v3.txt` | The summary tables: the report's data | Written by `build_summary_v3.m` |
| `results/summary_v3/FINDINGS_v3.md` | Results memo; numbers from `key_numbers.csv`. No script writes it | Edited by hand |
| `reports/build_report_v3.py` | Report builder (Python 3 with pandas) | You, when the report must show something new |
| `reports/sw07_learning_report.html` | The report: page content only, the claude.ai publisher wraps it | Written by the builder |
| `toolbox/+hetlearn/` | The toolbox | Nobody, for a scenario or model change |
| `toolbox/iris_patches/+model/Insertable.m` | Shadow copy of one IRIS file so that IRIS 20230622 optimal policy runs on R2025a; the IRIS installation is untouched | Nobody |
| `models/<name>/generated/` | Extended model files and RE filter caches | The toolbox (delete a file to force a rebuild) |
| `tests/` | `run_tests.m` (24 suites), toy NK package `tests/toy_nk/`, test scenarios `tests/scenarios/tsw07_*.m` and the test master options `tests/scenarios/master_options.m` (8.6), reference `tests/reference/`, test models of `test_re_info` `tests/models/` (hand-written SW07 RE(t-1) model, Dynare cross-check, closed-form Phillips curve) | Only when the toolbox changes |
| `tests/output/` | Test runs | Disposable |
| `archive/2026-10-18_rounds1-2/` | Round 1-2 scenarios, results, runners (`run_scenarios*.m`), report and code backups; `README.txt`. Not on the path | Nobody |
| `archive/2026-10-20_swX1_baseline/` | The previous SW07 baseline (swX1, to 2026-10-19): `results/summary_v3/`, the 40 `results/<id>/` folders, `results/eval_sw07_v3/`, the run log, the report, and the files changed on 2026-10-20 at their previous version (`code_pre_2026-10-20/`); `README.txt`. Not on the path | Nobody |
| `docs/` | This guide, `DESIGN.md`, `FEATURES.md` | |
| `.git/` | Repository https://github.com/tolgaozden/iris_toolbox_learning (public, MIT licence, branch `main`) | You (8.8) |

The rule: you write model packages, scenario files and the master options; the toolbox writes
`results/` and `generated/`. No scenario or model change needs a toolbox edit.

### 1.2 The three model packages

| Package | Model | Parameters | Observables, filter range | Forward-looking variables | `spec.policy` |
|---|---|---|---|---|---|
| `models/sw07/` | Smets-Wouters (2007) | Two sets: the published SW07 posterior mode for 1966Q1-2004Q4 (`sw07_params_original.m`, the baseline since 2026-10-20 through `model_params`), and the Dynare re-estimate `swX1` on 1966Q1-2026Q2 (`sw07_params.m` = `spec.params`, the default and the previous baseline) | `dy`, `dc`, `dinve`, `dw`, `labobs`, `pinfobs`, `robs`; 1965Q1-2026Q2; every observable NaN in 2020Q1-2020Q3 (covid quarters ignored, user decision 2026-10-19) | 12: `invef`, `rkf`, `pkf`, `cf`, `labf`, `inve`, `pinf`, `rk`, `pk`, `c`, `lab`, `w` | yes: Taylor rule by label; loss targets `pinf`, `ygap`, `r`, `dr` |
| `models/ijcb3/` | Three-equation NK model of IJCB (sec. 2.1) | IJCB Table 1, HE posterior means (`ijcb3_params.m`) | `yobs`, `pinfobs`, `robs`; 1960Q1-2026Q2; `robs` NaN in the 36 ELB quarters | `y`, `pinf` | no |
| `models/as07/` | An and Schorfheide (2007) | Herbst and Schorfheide (2016) published posterior means; measurement errors fixed as in the book's code (`as07_params.m`) | `dy`, `pinfobs`, `robs`; 1965Q1-2026Q2; `robs` NaN in the 36 ELB quarters | `y`, `pinf` | no |

Since 2026-10-21 only `models/sw07/` is in use: ijcb3 and as07 left the report and the portfolio (user
decision); their packages and scenario files stay in place, unused.

Each package has a `README.md` (model, parameters, units, open issues), `data/README.md` and
`data/build_database.m` (how the database is built and refreshed), and `validation/` (checks
against Dynare or the authors' code). Parameters are published values; nothing is estimated in
this project (user rule, 2026-10-18).

SW07 data note (2026-10-19): `models/sw07/data/build_database.m` sets all seven observables to
NaN in 2020Q1-2020Q3 (`covid_nan_quarters`; set it to `[]` to keep the covid quarters). The RE
filter treats those quarters as missing and its fit check skips them. Downstream: the learners
keep learning on the smoothed values there (on the filtered values under `history.re_states =
'filtered'`, 5.8), `hetlearn.evaluate` drops the targets in those
quarters, and the inversion history (`history.mode = 'inversion'`) has nothing to exogenise there,
so it differs from the RE smoother from 2020 on. The swX1 parameters were estimated with the covid
quarters.

### 1.3 How a run moves through the code

`hetlearn.run(cfg)` does, in order:

1. `hetlearn.load_options`: merges `hetlearn.defaults()` < `config/master_options.m` < `cfg`,
   checks every name and value.
2. `hetlearn.load_spec(cfg.model)`: reads `models/<name>/model_spec.m`.
3. `hetlearn.load_model`: writes (if needed) the extended model
   `generated/<name>_ext_<tag>.model` with `hetlearn.extend_model` (collapse test included),
   computes the anchored-RE coefficients (`hetlearn.re_anchor_coefficients`), loads and solves.
4. `hetlearn.re_filter`: RE Kalman filter and smoother (smoothed and filtered databanks),
   cached in `generated/refilter_*.mat`.
5. `hetlearn.engine.core`: initial state (`state_init`), history stage (`history`: learning on
   the RE-smoothed history, or the inversion), shocks (`build_shocks`), conditions
   (`conditions_prepare`), forecast quarter by quarter (`forecast`: `step`, then
   `update_learning`, which calls the projection facility `facility`), result (`assemble`).
6. `hetlearn.density.run`, when `density.enabled`.
7. `hetlearn.engine.save_results`: writes `results/<id>/`.

| Toolbox folder | Contents |
|---|---|
| `toolbox/+hetlearn/` | Public functions (section 7) |
| `+engine/` | `core`, `history` (with `history_db`, the databank of the history loop), `forecast`, `step`, `update_learning`, `facility`, `shares_for_mode`, `state_init`, `build_shocks`, `conditions_prepare`, `conditions_key`, `backward_simulate`, `solve_model`, `record`, `assemble`, `save_results`, `load_result` |
| `+plm/` | PLM system (`build_system`), PLM blocks for the facility (`blocks`), companion matrix, BR forecast text and values, anchored-RE parameter names |
| `+rls/update.m` | One RLS step (IJCB eq. 13) |
| `+gain/` | Gain rules `constant` and `koz`; `gain.rule` names the function |
| `+switching/` | `discrete_choice` (IJCB eqs. 14-15) and `init_fitness`; `switching.rule` names the function |
| `+init/` | Initial beliefs: `re_moments`, `training_ols`, `user` (`beliefs.init.method`) |
| `+policy/` | Ramsey setup, policy loss, `loss.csv` |
| `+density/` | Draws, RE fast path, quantiles, density outputs |
| `+util/` | Dates, MD5 hashes, CSV writer |

### 1.4 The baseline (since 2026-10-20)

User decision of 2026-10-20, in `config/master_options.m` lines 86-97, so every SW07 scenario
inherits it. The defaults of `hetlearn.defaults()` did not change; they are the previous
baseline, which the tests still use (8.6).

| Option | Baseline | Default (= the previous baseline, 2026-10-18/19) |
|---|---|---|
| `model_params` | `'sw07_params_original'`: published SW07 mode, 1966Q1-2004Q4 | `''` = `spec.params` (`sw07_params`, swX1, 1966Q1-2026Q2) |
| `gain.rule`, `gain.value` | `'koz'`, start gain 0.05 (other `gain.koz.*` at their defaults) | `'constant'`, 0.0585 |
| `switching.intensity`, `switching.memory` | 2, 0.8 | 0.51, 0.6 |
| `beliefs.plm.default`, `beliefs.info`, `shares.init_n2` | `'ar1'`, `'lagged'`, 0.5 | the same |
| `expectations.re_info` | `'lagged'`: RE agents use E_{t-1} x_{t+1} for the learning set | `'current'` |
| `expectations.re_variant` | `'anchored'` | the same |
| `history.re_states` | `'filtered'`: the RE forecasts, the learners' data and the realised values in the fitness errors come from the one-sided filter | `'smoothed'` |
| `projection.facility` | `'alm'` since 2026-10-21 (user decision): an ALM without a stable solution reverts the beliefs, then keeps last quarter's model shares (4.4.5). On 2026-10-20 it was `'none'`: nothing restricted, a quarter without a model solution stopped the run with `hetlearn:engine:noSolution` | `'plm_alm'` |

Where the baseline does not apply:

- **Application 4** (`a4_rule_re.m` line 25, `a4_rule_learn.m` line 19, inherited by the other
  twelve app-4 files): `expectations.re_info = 'current'`, because Ramsey policy is not supported
  with `'lagged'` (`hetlearn:options:unsupported`). The only deviation; the report says so.
- **`a6_inv_learn.m`** line 21: `history.re_states = 'smoothed'`, because `'filtered'` is an error
  with `history.mode = 'inversion'`; the inversion is one-sided already.
- **The other models** (`i1_re.m`, `a1as_re.m`; unused since 2026-10-21): their files pin the
  previous settings and set `model_params = ''`, so the SW07 baseline does not reach them.
- **The tests** read `tests/scenarios/master_options.m` (the previous values), not this file.

Consequences to know:

- Under the baseline's `'alm'` every project run completes (40 of 40 on 2026-10-21): where the
  model loses its solution the facility reverts the beliefs (and, if needed, keeps last
  quarter's shares). Under `'none'`
  (the baseline on 2026-10-20) a run can stop. Such a run is logged as `error` with the message,
  has no `results/<id>/` folder, and the summary lists it (check C8 accepts a `noSolution` stop
  only for a run whose own facility is `'none'`). On 2026-10-20 `v1_mc_learn` (model-consistent
  RE agents) stopped in 2022Q3, and five evaluation origins stopped (e03, e04).
- Under `'lagged'` the RE benchmark of an application is the RE model with t-1 information for
  inflation, not `models/sw07/sw07.model`; the summary checks the RE runs against the
  hand-written RE(t-1) model `tests/models/sw07_re_lagged_pinf.model` (C2, C3b).
- The published `constelab` (-0.103) is the 1966-2004 hours constant; `labobs` is demeaned over
  1947Q2-2026Q2 here, so the constant is not comparable across samples
  (`models/sw07/estimation/FINDINGS_estimates.md`).
- The previous baseline and its results are in `archive/2026-10-20_swX1_baseline/`. To rerun a
  scenario on it, set in that scenario `model_params = ''`, `gain.rule = 'constant'`,
  `gain.value = 0.0585`, `switching.intensity = 0.51`, `switching.memory = 0.6`,
  `expectations.re_info = 'current'`, `history.re_states = 'smoothed'`,
  `projection.facility = 'plm_alm'` (the defaults).

**`model_params`** (5.1) names a parameter function in the model package folder, used in place
of `spec.params` for that run: by `hetlearn.load_model`, and through it by the generator checks,
the anchored-RE coefficients, the policy discount and the RE filter, whose cache key hashes the
parameter values, so each set has its own caches. A name that is not a file of the package stops
the run (`hetlearn:load_model:params`). Example: `cfg.model_params = '';` runs a scenario on swX1.

---

## 2. Quick start

### 2.1 One application, in MATLAB

```matlab
cd('<project root>')
setup_paths                                   % once per MATLAB session
run_applications('app1')                      % a1_re, a1_learn: about 30 s
T = hetlearn.compare({'a1_re', 'a1_learn'}, {'pinfobs', 'robs'})   % levels and differences
```

`run_applications('app1')` writes `results/a1_re/` and `results/a1_learn/` (with
`compare_a1_re.csv`) and adds two rows to `results/run_log.csv`. One scenario without the
runner: `res = hetlearn.run(a1_learn());` (same results folder, no row in the run log).

Then the summary tables and the report:

```matlab
run('results/summary_v3/build_summary_v3.m')  % about 3 min
```

```powershell
cd "<project root>"
python reports/build_report_v3.py             # about 10 s; writes reports/sw07_learning_report.html
```

`build_summary_v3.m` reads the results of every SW07 scenario and of the evaluation, so after
one group it works only because the other results already exist. A fresh clone of the
repository has no `results/`: run everything first (2.3).

### 2.2 From PowerShell, without a MATLAB window

```powershell
& "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -batch "try, cd('<project root>'), run_applications('app1'), catch e, disp(getReport(e)), exit(1), end" -logfile app1.log
```

`-batch` does not start in the PowerShell folder, so the command starts with `cd`. MATLAB and
IRIS take about 15 s to start. `run_applications` calls `setup_paths` itself.

### 2.3 The whole report

| Step | Command (MATLAB from the root; step 3 in PowerShell) | Time |
|---|---|---|
| 1 | `run_applications('all')`: groups app1-app6, var1-var4, eval, in that order | about 3 hours: evaluation 2.7 h, app5 14 min, the other groups about 6.5 min |
| 2 | `run('results/summary_v3/build_summary_v3.m')` | about 3 min (includes unsaved check runs: two 10-draw densities, five model-consistent copies of app-4 RE runs, ten impulse runs) |
| 3 | `python reports/build_report_v3.py` | about 10 s |

Each step needs the one before it. With the evaluation in four parallel sessions, step 1 takes
about an hour (8.2). The other-model runs and `build_other_models.m` were dropped on 2026-10-21.

---

## 3. Reproduce the report

One row per report section. Every call is MATLAB from the project root. The builder reads every
summary file at start; most sections draw on `scenarios.csv`, `paths_long.csv`,
`learning_long.csv` and `key_numbers.csv`. The last column names each section's own tables and
its function in `reports/build_report_v3.py`. Summary step: `build_summary_v3.m` for the
baseline box and sections 1-11.

| Report section | Scenario files | Call | Results | Summary tables, builder function |
|---|---|---|---|---|
| Baseline box | `scenarios/sw07/base/sw07_re.m`, `sw07_learn.m`; `config/master_options.m` lines 86-97; `models/sw07/sw07_params_original.m`, `sw07_params.m` | none (parents of every SW07 file) | | reads the files; `sec_baseline` (the new-baseline paragraph at the top reads the archived master too) |
| 1 Application 1: the 2022Q2 peak forecast | `scenarios/sw07/app1_peak/`: `a1_re`, `a1_learn` | `run_applications('app1')` | `results/a1_re/`, `results/a1_learn/` | `sec_app1` |
| 2 Application 2: replay of the backed-out shocks | `app2_replay/`: `a2_re`, `a2_learn` | `run_applications('app2')` | `results/a2_re/`, `results/a2_learn/` | `sec_app2` |
| 3 Application 3: policy 100 bp looser or tighter than the Taylor rule | `app3_policy/`: `a3_loose_re`, `a3_tight_re`, `a3_loose_learn`, `a3_tight_learn` | `run_applications('app3')` | `results/a3_*/` | `app3_policy.csv`; `sec_app3` |
| 4 Application 4: Ramsey policy | `app4_ramsey/` (14 files): `a4_rule_re`, `a4_rule_learn`, `a4_ramsey_{balanced,hawk,dove,smooth}_{re,re_mc,learn}`; `_re_mc` = the RE Ramsey benchmark | `run_applications('app4')` | `results/a4_*/` (with `loss.csv`) | `app4_losses.csv` (its `RE_model_consistent` rows come from the `_re_mc` runs); `sec_app4` |
| 5 Application 5: density forecasts | `app5_density/`: `a5_markup_re`, `a5_demand_re`, `a5_markup_learn`, `a5_demand_learn` | `run_applications('app5')` | `results/a5_*/` (with `density.mat`, `density_quantiles.csv`, `density_events.csv`) | `app5_density.csv`, `app5_widths.csv`; `sec_app5` |
| 6 Application 6: history with the shocks backed out under learning | `app6_history/`: `a6_smooth_re`, `a6_smooth_learn`, `a6_inv_learn` | `run_applications('app6')` (runs the decompositions too; `run_applications('decompose')` runs only them) | `results/a6_*/` (with `decomposition.csv`, `decomposition_check.csv`) | `app6_decomp_long.csv`, `app6_shocks_long.csv`; `sec_app6` |
| 7 Model variant 1: anchored vs model-consistent RE | `var1_re_variant/`: `v1_mc_learn` | `run_applications('var1')` | `results/v1_mc_learn/` (the run completes under `'alm'`; on 2026-10-20, under `'none'`, it stopped, 1.4) | `scenarios.csv` (its error), `events_long.csv`, `eval_relative.csv`; `sec_var1` (`sec_var1_stopped` when the run stopped) |
| 8 Model variant 2: perceived laws of motion | `var2_plm/`: `v2_ar2`, `v2_ar1nc`, `v2_reg`, `v2_var3`, `v2_var12` | `run_applications('var2')` | `results/v2_*/` | `sec_var2` |
| 9 Model variant 3: learning on inflation only vs on all 12 variables | `var3_allvars/`: `v3_all` (facility `'alm'`, the baseline; the same run as `v3_all_alm`), `v3_all_plm_alm`, `v3_all_alm` | `run_applications('var3')` | `results/v3_*/` | `v3_facility.csv`; `sec_var3` |
| 10 Model variant 4: endogenous gain (baseline) vs a constant gain | `var4_gain/`: `v4_const`, `v4_const_full` (gain held at 0.05); the endogenous-gain side is `a1_learn` and `a6_smooth_learn` | `run_applications('var4')` | `results/v4_const/`, `results/v4_const_full/` | `sec_var4` |
| 11 Forecast evaluation | `eval/`: `e01_re` ... `e10_allvars`; settings in `run_applications.m` lines 164-178 | `run_applications('eval')`; in parallel: `run_applications('eval_part', variants, parts)`, then `run_applications('eval_merge')` | `results/eval_sw07_v3/` | `eval_metrics.csv`, `eval_relative.csv`, `eval_dm.csv`; `sec_eval` |
| 12 Caveats | | | | the Notes section of `FINDINGS_v3.md`; `sec_caveats` |
| 13 How to reproduce | | | | `scenarios.csv`, `run_applications.m`; `sec_reproduce` |
| 14 Validation | | | | `checks_v3.txt` (C1-C12); `sec_validation` |
| 15 Feature register | | | | `docs/FEATURES.md`; `sec_features` |

Then run steps 2-3 of 2.3. Points to know:

- **Run SW07 scenarios through `run_applications`**: a group, or one id such as
  `run_applications('a5_markup_learn')`, which is logged under its group (`app5`).
  `scenarios.csv` takes each status from `results/run_log.csv`: a scenario run with
  `hetlearn.run` directly shows `missing`, and check C8 fails.
- **The report date is a fixed string**: `REPORT_DATE = "2026-10-21"`, `build_report_v3.py`
  line 28 (with `BASELINE_DATE` and `ARCHIVE` below it). Change it when you rebuild on another day.
- **The memo is not regenerated.** `FINDINGS_v3.md` quotes `key_numbers.csv`; after a rerun its
  numbers stay as they are until you edit them. The report uses only its Notes section.
- **Results on this machine** (2026-10-20, the new baseline, 1.4): 39 of 40 runs ok and
  `v1_mc_learn` stopped (no model solution in 2022Q3); the evaluation ran 1380 runs, of which 5
  stopped (3 origins of `e03_learn_mc`, 2 of `e04_learn_all_learners`); checks 15 of 15
  (`checks_v3.txt`, C8 accepts such stops). The summary tables were rebuilt on 2026-10-20, the
  report on 2026-10-21 (section 12 removed); the published report
  (https://claude.ai/artifact/BvM5vuFBTYm943Z8eBpZR8) is republished by the main session. The
  previous baseline's results: `archive/2026-10-20_swX1_baseline/`.
- **One summary file is not in the report:** `app4_targets_long.csv` (6.5). The report reads the
  app-4 loss totals from `app4_losses.csv`; `app5_mechanism.csv` feeds the app-5 mechanism table.

---

## 4. Change an assumption

### 4.1 How a scenario gets its options

- **Precedence:** `hetlearn.defaults()` < `config/master_options.m` < the scenario's `cfg`.
  `hetlearn.load_options` merges field by field.
- **Inheritance is a function call.** A scenario file is a function that returns a partial option
  tree. It starts with its parent, `cfg = a1_learn();`, and sets only what differs. Some files
  copy one block from a sibling, e.g. `a3_loose_learn.m`: `c = a3_loose_re(); ...
  cfg.conditions = c.conditions;`.
- **Two groups are replaced, not merged:** `cfg.conditions` and `cfg.policy.loss`. A
  `policy.loss` struct without `dr` gives `dr` weight 0.
- **Names are checked.** A typo stops the run with `hetlearn:options:unknown` and the full option
  path. Removed options stop it with `hetlearn:options:removed`, naming the replacement (5.14).
- **Each result records its options:** `res.cfg` in `results/<id>/results.mat`.
- **Saved results never update themselves.** After an edit, rerun the scenario and everything
  below it in the tree (4.2); `run_applications` reruns whole groups in dependency order. A
  scenario named in `compare_with`, or used as a `'delta'` reference, is run first only when it
  has no results at all; after an edit, rerun it yourself.

### 4.2 The scenario tree

Indentation means "inherits from". "(block from X)" means the file copies one option block from
file X.

```
sw07_re                          base: every option listed, commented at its default
    e01_re
    a1_re                        RE parent of the applications
        a2_re
        a3_loose_re
            a3_tight_re
        a4_rule_re
            a4_ramsey_balanced_re
                a4_ramsey_balanced_re_mc     re_variant 'model_consistent': the RE Ramsey benchmark
                a4_ramsey_hawk_re
                    a4_ramsey_hawk_re_mc
                a4_ramsey_dove_re
                    a4_ramsey_dove_re_mc
                a4_ramsey_smooth_re
                    a4_ramsey_smooth_re_mc
        a5_markup_re
            a5_demand_re
        a6_smooth_re
    sw07_learn                   mode 'switching' (learning on inflation)
        e02_learn
            e04_learn_all_learners
        a1_learn                 learning parent of the applications and variants
            a2_learn
            a3_loose_learn       (block from a3_loose_re: conditions)
                a3_tight_learn
            a4_rule_learn
                a4_ramsey_<w>_learn   (block from a4_ramsey_<w>_re: policy), w = balanced, hawk, dove, smooth
            a5_markup_learn      (block from a5_markup_re: density)
            a5_demand_learn      (block from a5_demand_re: density)
            a6_smooth_learn
                a6_inv_learn
            v1_mc_learn
                e03_learn_mc
            v2_ar2
                e05_ar2
            v2_ar1nc
                e06_ar1nc
            v2_reg
                e07_reg
            v2_var3
                e08_var3
            v2_var12
                e09_var12
            v3_all               the baseline facility 'alm' (= v3_all_alm)
                v3_all_plm_alm, v3_all_alm, e10_allvars
            v4_const             constant gain 0.05 (the baseline gain is endogenous)
                v4_const_full
i1_re                            model ijcb3 (starts from struct(), not from sw07_re; unused since 2026-10-21)
    i1_learn
a1as_re                          model as07 (unused since 2026-10-21)
    a1as_learn
```

So an edit to `a1_learn.m` reaches every learning application and variant, and the evaluation
variants e03 and e05-e10 through their parents. The evaluation still overrides origin, horizon,
shocks, conditions, density and comparisons (4.4.13).

### 4.3 Where each assumption lives

| Assumption | Where (file, line) | Reaches | Rerun |
|---|---|---|---|
| The baseline: parameter set, gain rule and start gain, intensity of choice, memory, initial share, PLM, information sets, RE states, facility | `config/master_options.m` lines 86-97 (1.4) | every SW07 scenario; not the other models (`i1_re.m`, `a1as_re.m` pin the previous settings) | all groups (4.4.1) |
| Forecast origin, horizon | `scenarios/sw07/base/sw07_re.m` lines 38-44 | every SW07 file except the `a6_*` files and `v4_const_full` (their own origin and horizon) and the evaluation (set by the runner) | app1-app5, var1-var4 (4.4.2) |
| Expectations mode | `sw07_re.m` line 47 (`'rational'`), `sw07_learn.m` line 23 (`'switching'`), `e04_learn_all_learners.m` line 15 (`'learning'`) | children | per file |
| Variables that learn | `sw07_re.m` line 48 (`{'pinf'}`); `v3_all.m` line 19 (`'all'`) | children | 4.4.3 |
| RE variant | default `'anchored'` (`hetlearn.defaults`); `v1_mc_learn.m` line 15; `a4_ramsey_<w>_re_mc.m` line 18 | children | 4.4.4 |
| Projection facility | baseline `'alm'` since 2026-10-21, `'none'` on 2026-10-20 (`master_options.m` line 97; default `'plm_alm'`); `v3_all_plm_alm.m` line 17, `v3_all_alm.m` line 15 | | 4.4.5 |
| RE information set, RE states of the history | baseline `'lagged'` and `'filtered'` (`master_options.m` lines 94, 96); app 4: `a4_rule_re.m` line 25 and `a4_rule_learn.m` line 19 set `re_info = 'current'`; `a6_inv_learn.m` line 21 sets `re_states = 'smoothed'` | children | 4.4.7 |
| PLM | `v2_ar2.m` line 13, `v2_ar1nc.m` line 14, `v2_reg.m` lines 15-16, `v2_var3.m` lines 14-15, `v2_var12.m` lines 15-17 | the matching `e05`-`e09` | var2, eval (4.4.6) |
| Information timing of the learners | `'lagged'` (`master_options.m` line 93, = the default) | | 4.4.7 |
| Endogenous gain | baseline `gain.rule = 'koz'` (`master_options.m` line 87); the constant-gain variant `v4_const.m` lines 17-18 | `v4_const_full` | var4 (4.4.8) |
| Policy deviation: size, dates | `a3_loose_re.m` lines 17-19; sign: `a3_tight_re.m` line 12, `a3_tight_learn.m` line 12 | all four app3 files | app3 (4.4.9) |
| Ramsey loss weights | `a4_ramsey_balanced_re.m` line 18; `a4_ramsey_{hawk,dove,smooth}_re.m` line 12; `build_summary_v3.m` line 291 | the matching `_re_mc` and `_learn` files | app4 (4.4.10) |
| Loss horizon (80 quarters) | `a4_rule_re.m` line 24, `a4_rule_learn.m` line 18 | every app4 file | app4 |
| Density: shocks, draws, sigma, seed | `a5_markup_re.m` lines 16-21; `a5_demand_re.m` line 14 | the matching `_learn` file | app5 (4.4.11) |
| Shock replay | `a2_re.m` line 14, `a2_learn.m` line 15 | | app2 |
| History backed out with the learning model | `a6_inv_learn.m` line 20 | | app6 |
| Decomposition: groups, scenarios, range, variables | `run_applications.m` lines 204-207 and 212 | | `run_applications('decompose')` (4.4.12) |
| Evaluation: variants, benchmark, origins, horizon, parts, subsamples | `run_applications.m` lines 167-177 | | eval (4.4.13) |
| Run groups | `run_applications.m` lines 143-160 | | |
| Model parameters, data | `models/<name>/<name>_params.m` (`spec.params`), or another parameter file of the package named by `model_params` (SW07 baseline: `sw07_params_original.m`, `master_options.m` line 86); `models/<name>/data/build_database.m` | every scenario of that model | all; the RE filter cache key includes both, so the next run refilters |

### 4.4 Worked examples

#### 4.4.1 Learning calibration (gain, intensity of choice, memory, initial share)

```matlab
% config/master_options.m, lines 86-97 (the baseline since 2026-10-20, 1.4)
o.model_params = 'sw07_params_original';   % published SW07 (2007) mode, models/sw07/sw07_params_original.m
o.gain.rule = 'koz';                       % endogenous gain, Kostyshyna, Ozden and Zhang (2024) eq. 9
o.gain.value = 0.05;                       % initial (KOZ start) gain; was 0.0585 (IJCB constant gain)
o.switching.intensity = 2;                 % chi, intensity of choice (IJCB eq. 15); was 0.51
o.switching.memory = 0.8;                  % omega, memory in the fitness measure (IJCB eq. 14); was 0.6
o.shares.init_n2 = 0.5;                    % initial share of BR (learning) agents (unchanged)
o.beliefs.plm.default = 'ar1';             % AR(1) PLM with constant (unchanged)
o.beliefs.info = 'lagged';                 % learners see data up to t-1 (unchanged)
o.expectations.re_info = 'lagged';         % RE agents: E_{t-1} x_{t+1} for the learning set; was 'current'
o.expectations.re_variant = 'anchored';    % (unchanged)
o.history.re_states = 'filtered';          % RE forecasts and learners' data from the one-sided filter; was 'smoothed'
o.projection.facility = 'alm';             % facility on the actual law of motion (user, 2026-10-21); was 'none', before that 'plm_alm'
```

- Edit a value here and every SW07 scenario gets it on its next run. No SW07 scenario file sets
  these options, except application 4 (`re_info`), `a6_inv_learn` (`re_states`), the facility
  variants of V3 and the constant gain of V4 (1.4).
- Keep the `o.*` lines uncommented with plain values: the report reads them with regular
  expressions (`mopt` in `build_report_v3.py`) and the build stops if one is missing.
- One scenario and its children only: set it in the file, e.g. in `a1_learn.m` add
  `cfg.switching.intensity = 1;`.
- The other models pin their own values, so the master file does not reach them: `i1_re.m` and
  `a1as_re.m` (the settings of 2026-10-18 and `model_params = ''`), `i1_learn.m` lines 36-38
  (memory 0.62, IJCB Table 1) and `a1as_learn.m` lines 38-41.
- `re_info = 'lagged'` needs a learning set, so `hetlearn.load_options(struct())` with this master
  is an error; every SW07 scenario gets `{'pinf'}` from `sw07_re.m`.
- Units: chi multiplies squared forecast errors. IJCB's data and the three packages' model
  variables are in percent per quarter, so IJCB's 0.51 applied as estimated; the baseline's 2 is
  the user's choice. For annualised data divide chi by 16 for the same switching (the note on
  units in `master_options.m`).
- Rerun all groups. The RE runs keep their paths (all agents are RE); their learning
  diagnostics change.

A sweep without new files:

```matlab
for chi = [0.25 0.51 1]
    cfg = a1_learn();
    cfg.id = sprintf('sweep_chi%03d', round(100*chi));   % results/sweep_chi025/ ...
    cfg.switching.intensity = chi;
    hetlearn.run(cfg);
end
T = hetlearn.compare({'a1_re', 'sweep_chi025', 'sweep_chi100'}, {'pinfobs'});
```

#### 4.4.2 Forecast origin and horizon

```matlab
% scenarios/sw07/base/sw07_re.m, lines 38-44
spec = hetlearn.load_spec(cfg.model);
db = hetlearn.load_database(spec);
origin = hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4));
assert(hetlearn.util.date_eq(origin, qq(2022, 2)), ...
    'sw07_re: expected the inflation peak in 2022Q2, found %s.', char(dat2str(origin)));
cfg.forecast.origin = origin;                 % last quarter of data used
cfg.forecast.horizon = 16;                    % quarters: 2022Q3-2026Q2
```

- A fixed origin: replace lines 29-34 with `cfg.forecast.origin = qq(2023, 4);`.
- Another peak window: change line 31 and the assert on lines 32-33. Every SW07 file calls
  `sw07_re`, so a failing assert stops every SW07 run, the evaluation included.
- Horizon: line 35. Conditions must lie inside the horizon (app 3 uses 2022Q3-2023Q2).
- Files with their own origin: `a6_smooth_re.m` lines 15-16, `a6_smooth_learn.m` lines 15-16
  (`qq(2026, 2)`, horizon 4; `a6_inv_learn` inherits), `v4_const_full.m` lines 15-16. The other
  models: `i1_re.m` lines 38-44, `a1as_re.m` lines 39-45.
- The evaluation sets its own origins and horizon (4.4.13).
- Rerun: `run_applications({'app1', 'app2', 'app3', 'app4', 'app5', 'var1', 'var2', 'var3', 'var4'})`.
  The summary and report builders were written for the 2022Q2 origin and the 2022Q3-2026Q2
  horizon (4.7).

#### 4.4.3 Learning on other variables

```matlab
cfg.expectations.variables = {'pinf', 'w'};   % a subset (baseline: sw07_re.m line 48, {'pinf'})
cfg.expectations.variables = 'all';           % all 12 forward-looking variables (v3_all.m line 19)
```

- Each learning variable gets its own AR(1) learners and its own switching share
  (`shares.structure = 'per_variable'`).
- One share for several variables, driven by the summed squared errors of the master list:
  `cfg.shares.structure = 'universal'; cfg.shares.master = {'pinf'};`. Every master variable
  must learn (error `hetlearn:engine:master`).
- A name that is not forward-looking stops the load (`hetlearn:load_model:notForward`).
  `[m, info] = hetlearn.load_model(spec, opts)` lists the candidates in `info.meta.forward_vars`.
- With anchored RE and every forward-looking variable learning, the model has no leads; how
  the facility treats that case is in 5.7.
- Change line 48 of `sw07_re.m` to change the baseline for every scenario.

#### 4.4.4 RE variant: anchored or model-consistent

```matlab
% scenarios/sw07/var1_re_variant/v1_mc_learn.m, line 15
cfg.expectations.re_variant = 'model_consistent';
```

- `'anchored'` (default since 2026-10-18): RE agents use the pure-RE model's forecast at the
  current state (IJCB sec. 2.3.1); `hetlearn.re_anchor_coefficients` computes it.
- `'model_consistent'`: RE agents forecast the heterogeneous economy, which is re-solved every
  quarter with the current beliefs and shares.
- Project-wide: add `o.expectations.re_variant = 'model_consistent';` to
  `config/master_options.m`.
- Under the Taylor rule the two variants give the same RE path (check C11). Under Ramsey they do
  not: `a4_ramsey_<w>_re_mc.m` (line 18) set `'model_consistent'` to give the RE Ramsey
  benchmark (8.7).

#### 4.4.5 Projection facility

```matlab
% scenarios/sw07/var3_allvars/v3_all_alm.m, line 15
cfg.projection.facility = 'alm';      % 'plm_alm' (default), 'alm' (the baseline since 2026-10-21) or 'none'
```

The baseline sets `'alm'` project-wide since 2026-10-21 (`master_options.m` line 97; `'none'` on
2026-10-20); `v3_all_plm_alm.m` line 17 sets `'plm_alm'` and `v3_all_alm.m` line 15 `'alm'`.
Under `'none'` a run that loses the model solution stops and is logged as an error; it is not
moved to another facility. What each value does: 5.7.

#### 4.4.6 Perceived law of motion (PLM)

```matlab
% v2_ar2.m line 13 / v2_ar1nc.m line 14
cfg.beliefs.plm.default = 'ar2';                % or 'ar1_noconst'
% v2_reg.m lines 15-16
cfg.beliefs.plm.derived.ygap = 'y - yf';
cfg.beliefs.plm.by_var.pinf = struct('regressors', {{'pinf{-1}', 'ygap{-1}', 'r{-1}'}}, 'constant', true);
% v2_var3.m lines 14-15
cfg.beliefs.plm.derived.ygap = 'y - yf';
cfg.beliefs.plm.var = struct('variables', {{'pinf', 'ygap', 'r'}}, 'lags', 1, 'constant', true);
```

- `derived.<name>` adds a model variable defined by a linear expression; the PLM can use it.
- Regressors that do not learn get an auxiliary AR(1) PLM, learned the same way; VAR members
  that do not learn are auxiliary VAR equations.
- One PLM for every learning variable: `cfg.beliefs.plm.default = 'var1'` (a VAR(1) over the
  learning set). It cannot be combined with `beliefs.plm.var.variables`.
- `e05`-`e09` inherit these files, so an edit changes the evaluation too: rerun var2 and those
  variants' evaluation parts.

#### 4.4.7 Information timing of the learners

```matlab
cfg.beliefs.info = 'current';    % default and baseline 'lagged'; project-wide: master_options.m line 93
```

- `'lagged'`: learners see data up to t-1; AR(1) forecast `alpha + beta*(alpha + beta*x{-1})`.
- `'current'`: period-t data as in IJCB eq. 12; forecast `alpha + beta*x`. The extended model
  holds both forms behind the toggle `br_info_current`.
- The belief updates are the same under both; the forecasts, and so the shares, change.

The RE agents have the same choice (added 2026-10-19, DESIGN 19; `'lagged'` is the baseline since
2026-10-20, `master_options.m` line 94, and application 4 sets `'current'`):

```matlab
cfg = a1_learn();
cfg.id = 'a1_learn_reinfo';
cfg.expectations.re_info = 'current';    % baseline 'lagged' (default 'current'); RE agents forecast with data up to t
res = hetlearn.run(cfg, 'save', false);
```

- `'lagged'` replaces E_t x_{t+1} by E_{t-1} x_{t+1} for the learning variables (other
  variables keep E_t). With `beliefs.info = 'lagged'` both types then forecast x_{t+1} with
  data up to t-1, and both fitness errors are two-step errors.
- Everything RE in the scenario follows: the RE benchmark (mode `'rational'`) is the RE model
  with t-1 information, the anchored RE agents forecast with that model, and the RE history
  (filter, smoother, f^RE, RE-moment initial beliefs) uses it. So compare a lagged learning
  run with a lagged RE run: `c = a1_re(); c.expectations.re_info = 'lagged';`.
- The loader uses its own generated file, `<name>_ext_<tag>_relag.model`; the default files
  are untouched. Learning variables must have a maximum lead of 1, and Ramsey policy is not
  supported with `'lagged'` (both are errors).

#### 4.4.8 Endogenous gain (Kostyshyna, Özden and Zhang 2024)

```matlab
% config/master_options.m, lines 87-88: the baseline since 2026-10-20
o.gain.rule = 'koz';
o.gain.value = 0.05;                          % the KOZ start gain (gain.koz.gamma0 = [] takes it)
% scenarios/sw07/var4_gain/v4_const.m, lines 17-18: variant 4, the constant gain at the same value
cfg.gain.rule = 'constant';
cfg.gain.value = 0.05;
```

- `gain.koz.error_scale` (default 1) multiplies the signed error before it drives the gain. With
  1 the errors are in model units, percent per quarter: the units of the SW07 data and of chi
  (user decision 2026-10-19). The first SW07 runs used 4 (annualised percent). mu acts with the
  square of the factor, so 4 instead of 1 works like a 16 times larger mu. On the 2026-10-20
  baseline the gain stays within 0.047-0.052 over 1966Q1-2026Q2 (`key_numbers.csv`).
- Other knobs, all in 5.4 and all at their defaults in the baseline: `gain.koz.mu` (0.001),
  `.bounds` ([0.001 0.25]), `.error` (`'rls'` or `'forecast'`), `.structure` (`'common'` or
  `'per_variable'`), `.master`, `.gamma0`, `.Rg0`.
- With `mu = 0` the run equals the constant gain bit for bit.
- `v4_const_full` inherits the constant gain; the baseline's history to 2026Q2 is
  `a6_smooth_learn`. Rerun: `run_applications('var4')`.

#### 4.4.9 Policy deviation: size and dates

```matlab
% scenarios/sw07/app3_policy/a3_loose_re.m, lines 17-19
cfg.conditions = struct('variable', 'ms', 'shock', 'em', ...
    'dates', [qq(2022, 3), qq(2023, 2)], 'values', -0.25, ...
    'type', 'delta', 'reference', 'self');
```

- `ms` is the monetary shock process; it enters the SW07 rule one for one (r = rule + ms).
  `'delta'` with reference `'self'` holds `ms` 0.25 below its path in the same scenario without
  the condition, so the rate is 0.25% per quarter (100 bp a year) below what the rule gives at
  the same state. `em` adjusts each quarter, so agents are surprised every quarter.
- Size: `'values'`. For 50 bp a year use `-0.125` here and `cfg.conditions.values = 0.125;`
  in `a3_tight_re.m` line 12 and `a3_tight_learn.m` line 12 (today 0.25).
- Dates: two dates are read as a range. Both must lie inside the horizon.
- The learning files take the condition from `a3_loose_re` (`a3_loose_learn.m` lines 10 and
  14), so the edit reaches all four files.
- Rerun: `run_applications('app3')`.
- The summary assumes today's size and dates: check C3b (`build_summary_v3.m` line 543) expects
  `ms` at -1 / +1 in report units in the first four horizon quarters, and the labels on lines
  58-61 say "100 bp". Edit them with the condition.

To put the rate itself on a path instead:

```matlab
cfg.conditions = struct('variable', 'robs', 'shock', 'em', ...
    'dates', qq(2022,3):qq(2023,2), 'values', [0.5 0.8 1.1 1.2], ...
    'type', 'level', 'reference', 'self');
```

#### 4.4.10 Ramsey loss weights

```matlab
% scenarios/sw07/app4_ramsey/a4_ramsey_balanced_re.m, lines 16-18
cfg.policy.mode = 'ramsey';
cfg.policy.type = 'commitment';
cfg.policy.loss = struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0);
```

- Hawk, dove and smooth: line 12 of `a4_ramsey_hawk_re.m`, `a4_ramsey_dove_re.m`,
  `a4_ramsey_smooth_re.m`. Each `_re_mc` file inherits its `_re` file and only sets
  `re_variant = 'model_consistent'` (line 18); each `_learn` file copies the policy block of its
  `_re` file (`cfg.policy = r.policy;`, line 18). An edit of an `_re` file reaches all three.
- Why `_re_mc`: anchored RE agents keep the Taylor-rule RE forecast even under Ramsey policy, so
  `a4_ramsey_<w>_re` is not an RE Ramsey plan; `a4_ramsey_<w>_re_mc` is the RE benchmark.
- Target names come from `spec.policy.targets` (`models/sw07/model_spec.m` line 27): `pinf` =
  `4*pinf`, `ygap` = `y - yf`, `r` = `4*r`, `dr` = `4*(r - r{-1})`. The struct replaces the
  default as a whole; targets you leave out get weight 0.
- Discount: `spec.policy.discount` (`'$cbetabar$*$cgamma$'`, 0.99756), or set
  `cfg.policy.discount`.
- **Also edit `build_summary_v3.m` line 291**, which holds the same four weight sets:
  `app4_losses.csv` recomputes every loss from the target paths with these weights, the
  `RE_model_consistent` rows of the `_re_mc` runs included. The report reads the weights from
  the `a4_ramsey_<w>_re.m` files (`loss_weights`, `build_report_v3.py` line 705) and uses the
  `RE_model_consistent` rows as the RE Ramsey benchmark (`sec_app4`, lines 716-736).
- Check C12 compares the saved `_re_mc` runs with model-consistent copies of the `_re` runs that
  `build_summary_v3.m` makes without saving (lines 311-319).
- A new weight set needs three scenario files (`_re`, `_re_mc`, `_learn`), the app4 list in
  `run_applications.m` (lines 141-144), `W` and rows of `SC` in `build_summary_v3.m`, and
  `WSETS` in `build_report_v3.py` line 702.
- Rerun: `run_applications('app4')` (about 2.5 min).

#### 4.4.11 Density forecasts: shocks, draws, sigma

```matlab
% scenarios/sw07/app5_density/a5_markup_re.m, lines 16-21
cfg.density.enabled = true;
cfg.density.shocks = {'epinf', 'ew'};
cfg.density.sigma = 'calibrated';
cfg.density.method = 'normal';
cfg.density.ndraws = 500;
cfg.density.seed = 0;
```

- `a5_demand_re.m` line 14 changes only the shocks (`{'eb', 'eg', 'eqs'}`).
- The learning files copy the block (`cfg.density = d.density;`: `a5_markup_learn.m` line 16,
  `a5_demand_learn.m` line 13), so RE and learning use the same draws.
- Sigma from the smoothed shocks instead of the model's `std_<shock>`:
  `cfg.density.sigma = 'smoothed'; cfg.density.sigma_range = [qq(1966, 1), qq(2019, 4)];`.
- Time: an RE density uses the fast path (about 30 s for 500 draws); a learning density re-runs
  the forecast for each draw (0.71 s per draw, about 6.5 min for 500).
- The report reads `ndraws` and `seed` from `a5_markup_re.m` and the shocks from both `_re`
  files. The words "normal with the model's calibrated standard deviations" are fixed text in
  `sec_app5`. `app5_widths.csv` needs the 0.05 and 0.95 quantiles (`build_summary_v3.m`
  lines 378-379). The impulse runs behind `app5_mechanism.csv` have their own shock list
  (lines 403-404); edit it with the density shocks.
- Rerun: `run_applications('app5')` (14 min), or in parallel (8.2).

#### 4.4.12 Shock decomposition groups

```matlab
% run_applications.m, lines 204-207 (function decompose_app6)
groups = struct('demand', {{'eb', 'eg', 'eqs'}}, 'monetary', {{'em'}}, 'supply', {{'ea'}}, ...
    'price_markup', {{'epinf'}}, 'wage_markup', {{'ew'}});
ids = {'a6_smooth_re', 'a6_smooth_learn', 'a6_inv_learn'};
rng = [qq(1966, 1), qq(2026, 2)];
```

- The variables are on line 212 (`{'pinfobs', 'dy'}`). Shocks in no group stay single.
- Rerun: `run_applications('decompose')` (about 15 s; the app6 results must exist).
- The group names are also listed in `build_summary_v3.m` line 798 (`compsD`) and in
  `build_report_v3.py` line 910 (`GROUPS`, with colours). Edit them together.
- One decomposition by hand:
  `D = hetlearn.decompose('a6_inv_learn', {'pinfobs'}, [qq(2019,1), qq(2026,2)], struct('groups', groups));`
- RE runs use IRIS contributions. Learning runs use a time-varying decomposition with the model
  in force each quarter, plus the component `beliefs_constants` (the moving perceived means;
  `intercept_channel` in the summary). Without the inversion, the history of a learning run is
  the RE-smoothed history, so it is decomposed with the RE model.

#### 4.4.13 Forecast evaluation: origins, horizon, variants, subsamples

```matlab
% run_applications.m, lines 167-177 (function eval_settings)
E.name = 'sw07_v3';                                   % results/eval_sw07_v3/
E.variants = {'e01_re', 'e02_learn', 'e03_learn_mc', 'e04_learn_all_learners', 'e05_ar2', ...
    'e06_ar1nc', 'e07_reg', 'e08_var3', 'e09_var12', 'e10_allvars'};
E.benchmark = 'e01_re';
E.origins = qq(1990, 1):qq(2024, 2);                  % 138 origins
E.horizon = 8;
E.nparts = 6;                                         % parts per variant (23 origins each)
E.subsamples = struct('s1990_2007', [qq(1990, 1), qq(2007, 4)], ...
    's2008_2019', [qq(2008, 1), qq(2019, 4)], 's2020_2026', [qq(2020, 1), qq(2026, 2)]);
E.opts = struct('horizon', E.horizon, 'subsamples', E.subsamples, 'realtime', true, ...
    'dm', true, 'dm_hln', true, 'quiet', true);
```

- A variant is a scenario file in `scenarios/sw07/eval/`. For every origin `hetlearn.evaluate`
  sets the origin and horizon, zero future shocks, no conditions, no density, no comparisons and
  a real-time RE filter (data up to the origin), so only the expectations side of the file
  matters.
- Subsamples are ranges of target dates. Their names also appear in `build_summary_v3.m`
  line 858 and in `build_report_v3.py` line 1320 (`SAMPLES`).
- **Before a rerun with other origins, horizon or variants, move
  `results/eval_sw07_v3/parts/` aside** (PowerShell `Move-Item`). The merge reads every part
  folder there and stops on a part with other settings or with overlapping origins. Today's
  folder holds `e09_var12` as parts 1-3 of 6 plus parts 7-12 of 12, so a plain
  `run_applications('eval')` would add parts 4-6 of 6, which overlap parts 7-12 of 12, and the
  merge would stop.
- A new variant: a file in `scenarios/sw07/eval/`, its id in `E.variants`, a row in `SC` of
  `build_summary_v3.m` (the evaluation tables look up its label; without the row the summary
  stops), and an entry in `EVV` (`build_report_v3.py` line 1316) with a key of `ENT`
  (lines 236-249).
- `E.name` changes the folder, but `build_summary_v3.m` reads `results/eval_sw07_v3` (line 34).
- A separate evaluation by hand, outside the runner:

```matlab
E = hetlearn.evaluate('my_eval', {'e01_re', 'e02_learn'}, [qq(2010,1), qq(2024,2)], ...
    struct('horizon', 8, 'subsamples', struct('post2008', [qq(2008,1), qq(2019,4)])));
```

It writes `results/eval_my_eval/`. `hetlearn.evaluate_tables` rebuilds the tables from a saved
`errors_long.csv` without rerunning any forecast.

### 4.5 Add a scenario

1. **Write the file.** Copy the closest file, rename the function and the file, set `cfg.id` to
   the file name and change what differs. Ids are function names: `compare_with`, `'delta'`
   references and `run_applications` find scenarios by name, so names must be unique on the
   path. Any folder under `scenarios/` is on the path (`setup_paths` adds every subfolder; run
   it again after you create a new folder in an open session).
2. **Run it:** `run_applications('my_id')` (logged under its group, or under `single` while it
   is in none) or `res = hetlearn.run(my_id());`.
3. **Put it in a group:** `group_table` in `run_applications.m`, lines 143-160. Add the id to a
   group's list after its parents and comparison targets, or add a row such as
   `'app7', {'a7_re', 'a7_learn'}`. A new row is part of `'all'` automatically.
4. **Index:** `python scenarios/build_index.py` rewrites `scenarios/sw07/INDEX.csv` (it covers
   `scenarios/sw07/` only).
5. **Summary:** add a row to `SC` in `build_summary_v3.m` (lines 53-104): id, folder, group,
   label. That puts the run into `scenarios.csv`, `paths_long.csv`, `learning_long.csv` and
   `events_long.csv`. A table of its own needs a new block (pattern: the blocks from line 270
   on) and key numbers through `addk` (lines 680-972).
6. **Report:** extend the section function that shows the group (table in section 3), or write
   a new `sec_<name>()` that returns `section(sid, no, title, body)` and add it to `PARTS`
   (lines 1749-1755) and to `SECT_GROUPS` (lines 1645-1648, the reproduce table). Section
   numbers are literals in each `section(...)` call, so a new section means renumbering the ones
   after it. A `SECT_GROUPS` entry needs at least one row of that group in `scenarios.csv`.

### 4.6 Add a model package

The package contract is `models/<name>/model_spec.m`, a function with no inputs that returns
`spec`:

| Field | Meaning | sw07 | ijcb3 | as07 |
|---|---|---|---|---|
| `name` | Package name, used in generated file names | `'sw07'` | `'ijcb3'` | `'as07'` |
| `folder` | Always `fileparts(mfilename('fullpath'))` | | | |
| `model_file` | IRIS model file, relative to the folder | `'sw07.model'` | `'ijcb3.model'` | `'as07.model'` |
| `params` | Function returning a struct of every parameter, `std_<shock>` included | `'sw07_params'` | `'ijcb3_params'` | `'as07_params'` |
| `sstate` | Steady-state function for nonlinear models, or `''` | `''` | `''` | `''` |
| `linear` | Passed to IRIS | `true` | `true` | `true` |
| `assign` | Values of the model file's own `!if` switches | `struct()` | `struct()` | `struct()` |
| `database` | IRIS databank: CSV from `databank.toCSV`, or `.mat` | `'data/sw07_database.csv'` | `'data/ijcb3_database.csv'` | `'data/as07_database.csv'` |
| `filter_range` | `[first, last]` of the RE filter and smoother | 1965Q1-2026Q2 | 1960Q1-2026Q2 | 1965Q1-2026Q2 |
| `observables` | Measurement variables | 7 SW observables | `yobs`, `pinfobs`, `robs` | `dy`, `pinfobs`, `robs` |
| `policy` (optional) | Needed only for Ramsey: `instrument`, `rule_label` (exact label of the rule equation), `targets` (struct of expressions), `discount` | see 4.4.10 | none (comment in the file gives the fields) | none (likewise) |
| `report` (optional) | `labels`, `units`, `scale` per observable; scale 4 annualises a quarterly rate | `labobs` 1, the other six 4 | `yobs` 1, `pinfobs` 4, `robs` 4 | `dy` 4, `pinfobs` 1, `robs` 1 |

What the toolbox does with the model file (`hetlearn.extend_model`, DESIGN 3): every lead
`x{+k}` of a declared transition variable becomes an expectation variable (`x_exp1`; longer
leads `x_expk = x_exp(k-1){+1}`), and each forward-looking variable gets the block
`x_exp1 = n1_x*x_exp1_RE + n2_x*x_exp1_BR`. The file accepts `x{+1}`, `x{1}`, `x(+1)`, `x[+1]`,
`x{t+1}` and `//` or `/* */` comments, and converts them for IRIS. The blocks sit behind IRIS
`!if` toggles that the toolbox sets from the options:

| Toggle | Set from | Effect |
|---|---|---|
| `br_<x>` | `expectations.variables` | `true`: x's expectation is the RE/BR mix; `false`: pure RE |
| `re_anchored` | `expectations.re_variant` | Anchored RE agents instead of `x{+1}` |
| `ramsey` | `policy.mode` | Loss function in place of the rule equation |
| `br_info_current` | `beliefs.info` | Learners see period-t data |

`expectations.re_info = 'lagged'` is not a toggle: it selects a second generated file,
`<name>_ext_<tag>_relag.model`, whose RE expectations use information up to t-1 (DESIGN 19).

Every generated file passes a collapse test: with every RE share at 1 the extended model must
reproduce the original model's impulse responses to 1e-10 (a `_relag` file: with no variable
learning; with every lead-1 variable learning, its anchored and model-consistent forms must agree).

Steps, with ijcb3 and as07 as the worked examples (both unused since 2026-10-21, kept as templates):

1. Copy `models/ijcb3/` (the smallest package; as07 was built from it) to `models/<new>/`.
   Replace the model file, the parameter function and the data; edit `model_spec.m`.
   **Parameters: published values only, never estimated** (user rule). ijcb3 takes the HE
   posterior means of IJCB Table 1; as07 the published Herbst-Schorfheide means and the fixed
   measurement-error variances of the book's code.
2. Generate and check:

   ```matlab
   spec = hetlearn.load_spec('<new>');
   opts = hetlearn.load_options(struct('model', '<new>'));
   [m, info] = hetlearn.load_model(spec, opts);   % writes generated/<new>_ext_ar1.model, collapse test
   info.meta.forward_vars                         % the variables that can learn
   H = hetlearn.re_filter(spec, opts);            % RE filter; H.fit_error
   ```

   With at least as many shocks as observables, `re_filter` stops unless the smoothed states and
   shocks rebuild the data to 1e-8 (`H.fit_error`).
3. Validate against the original model or the authors' code, as in
   `models/ijcb3/validation/check_model.m` and `models/as07/validation/check_model.m` (results in
   `validation/RESULTS.txt`).
4. Scenarios: `scenarios/<new>/app1_peak/` with an RE parent that starts from `cfg = struct();`
   and sets `cfg.model = '<new>'`, the origin, the horizon and `expectations.variables`, plus a
   learning child. Templates: `i1_re.m`, `i1_learn.m`. Do not inherit from `sw07_re`: it loads
   SW07 and asserts the SW07 peak.
5. Run: `res = hetlearn.run(feval('<id>'));`. The report has no section for other packages
   since 2026-10-21; a new package needs its own report section.

What the two packages show:

- Missing data: `robs` is NaN in the ELB quarters; the filter skips the NaN and infers a shadow
  rate from the rule (`models/ijcb3/README.md`, "ELB treatment").
- Measurement errors: as07 declares them as IRIS measurement shocks (`std_me_dy`,
  `std_me_pinfobs`, `std_me_robs` in `as07_params.m`; 0 removes them).
- Units: as07's model `pinf` is in percent per quarter while its observables `pinfobs` and
  `robs` are annualised, hence `report.scale` 1 for them. chi = 0.51 applies because the
  learners forecast the model variable in percent per quarter.
- No `spec.policy`: `policy.mode = 'ramsey'` is an error for these packages and no loss is
  computed.
- Limits: anchored RE needs a linear model with plain state names
  (`hetlearn:load_model:anchored`). `spec.sstate` exists for nonlinear models; no package uses
  it.

### 4.7 What the summary and report builders assume

The toolbox takes any scenario. The two builders were written for today's set of scenarios.
After a change of assumptions, rebuild the summary, read the CSVs and `checks_v3.txt`, then
rebuild the report and reread its text.

| Assumption | `results/summary_v3/build_summary_v3.m` | `reports/build_report_v3.py` |
|---|---|---|
| Scenario lists | `SC` lines 53-104; app3 `pairs` line 274; app5 `cases` line 360; app6 `dcase` line 427; variant 3 `fids` line 459 | `ENT` lines 236-249; `WSETS` 702; `CASES` 798; `DCASES` 908; `GROUPS` 910; `PLMS` 1050; `EVV` 1316 |
| Dates | paths 2015Q1-2026Q2 (line 183); history 1966Q1-2026Q2 (line 443); `d22 = qq(2022, 2)` (line 680); fixed quarters in the key-number block (lines 680-972) | origin and horizon from `paths_long.csv` (lines 97-100); fixed quarters in some sentences (e.g. `'2022Q4'`, `'2023Q2'`, `'2024Q2'` in `sec_app1`); `REPORT_DATE` line 28 |
| App 3 size and dates | check C3b, line 543; labels lines 58-61 | section title says 100 bp |
| App 4 | weight sets `W` line 291; loss horizons 16 and 80 (lines 300, 331); the `_re_mc` ids are built from the weight-set names (line 330) | weights read from the scenario files; `RE_model_consistent` rows as the RE benchmark (lines 716-736) |
| App 5 | quantiles 0.05 and 0.95 (lines 378-379); impulse shocks of `app5_mechanism.csv` (lines 403-404) | `ndraws` and `seed` read from `a5_markup_re.m` |
| Evaluation | folder `results/eval_sw07_v3` (line 34); samples line 858 | `SAMPLES` line 1320 |
| Calibration and baseline | `pfun` from `model_params` of the merged SW07 options (line 48); RE checks C2, C3b on `tests/models/sw07_re_lagged_pinf.model` (re_info `'lagged'`) | the `o.*` lines of `master_options.m` read by regex (`mopt`); the previous baseline from `archive/2026-10-20_swX1_baseline/code_pre_2026-10-20/config/master_options.m` and `defaults.m` |

Every number in the report text is read from the summary files at build time, but the sentences
around the numbers are fixed. Some code also expects today's pattern: `sec_app1` looks for the
first forecast quarter in which the learning-minus-RE inflation gap turns negative and stops with
an error if there is none.

---

## 5. Options reference

Every option of `hetlearn.defaults()` (`toolbox/+hetlearn/defaults.m`), checked by
`hetlearn.load_options`. Defaults come first. `scenarios/sw07/base/sw07_re.m` lists each option
as a commented line at its default.

### 5.1 Identification and forecast

| Option | Values (default first) | Meaning |
|---|---|---|
| `id` | text | Results folder name; use the scenario function name |
| `title`, `description` | text | Shown in the summary and the report |
| `model` | text | Model folder under `models/`, or a folder path |
| `model_params` | `''` | Parameter function of the model package for this run, a `.m` file in the package folder, used instead of `spec.params` by `hetlearn.load_model` (and so by the anchored coefficients, the policy discount and the RE filter, whose cache key hashes the values). `''` = `spec.params`. A name that is not a file of the package stops the run (`hetlearn:load_model:params`). SW07 baseline since 2026-10-20: `'sw07_params_original'` (1.4) |
| `forecast.origin` | date (required) | Last quarter of data used; the forecast starts the quarter after |
| `forecast.horizon` | `16` | Quarters; a positive integer |
| `compare_with` | `{}` | Scenario ids; writes `compare_<id>.csv` (this minus that, observables, horizon) |
| `report.variables` | `{}` | Reserved: converted to a cellstr, read by no code |

### 5.2 Expectations

| Option | Values | Meaning |
|---|---|---|
| `expectations.mode` | `'rational'`, `'learning'`, `'fixed_shares'`, `'switching'` | All RE (BR share 0); all learners (BR share 1); fixed shares (`shares.fixed_n2`); shares switch on forecast performance |
| `expectations.variables` | `{}`, cellstr, `'all'` | Forward-looking variables whose expectations are the RE/BR mix; the rest stay RE. `'all'` = every forward-looking variable (SW07: 12) |
| `expectations.re_variant` | `'anchored'`, `'model_consistent'` | RE agents use the pure-RE forecast at the current state (IJCB sec. 2.3.1; the baseline since 2026-10-18), or forecast the heterogeneous economy, re-solved every quarter |
| `expectations.re_info` | `'current'`, `'lagged'` | RE agents' information set for the learning variables: E_t x_{t+1}, or E_{t-1} x_{t+1} (data up to t-1, the RE counterpart of `beliefs.info = 'lagged'`). With `'lagged'` the RE benchmark, the anchored forecast and the RE history use the RE model with t-1 information (4.4.7, DESIGN 19). Not with Ramsey policy; learning variables need a maximum lead of 1; needs a non-empty learning set. SW07 baseline since 2026-10-20: `'lagged'` (application 4: `'current'`) |
| `beliefs.info` | `'lagged'`, `'current'` | Learners see data up to t-1, or up to t (IJCB eq. 12). The belief updates are the same; the forecasts, and so the shares, differ |

In mode `'rational'` the learning variables keep their blocks with RE share 1: the run is
exactly RE, and beliefs and shares are tracked as diagnostics.

`expectations.types` (N agent types) and `expectations.transforms` (forecast transforms) are
described in section 9.

### 5.3 Beliefs and perceived laws of motion (PLM)

| Option | Values | Meaning |
|---|---|---|
| `beliefs.update` | `'rls'`, `'fixed'` | Beliefs learned by RLS, or held at their initial values. SAC (`'sac'`) and Kalman-filter learning (`'kf'`, `beliefs.kf`) were removed on 2026-10-22 (9.10) |
| `beliefs.plm.default` | `'ar1'`, `'ar2'`, `'ar1_noconst'`, `'var1'` | PLM of every learning variable without its own entry; `'var1'` = one VAR(1) over the learning set |
| `beliefs.plm.by_var.<x>` | text or struct | Per-variable PLM: a shorthand such as `'ar2'`, or `.regressors` (cellstr of lagged variables, lag 1 or more, e.g. `{'pinf{-1}', 'ygap{-1}', 'r{-1}'}`) and `.constant` (`true`). An entry for a variable that does not learn sets its auxiliary PLM |
| `beliefs.plm.derived.<name>` | text | A regressor defined as a linear expression in model variables, e.g. `'y - yf'`; it becomes a model variable |
| `beliefs.plm.var` | `variables` (`{}`), `lags` (`1`), `constant` (`true`) | A VAR PLM over a cellstr of variables or `'learning'`; members that do not learn become auxiliary VAR equations. Not together with `default = 'var1'` (error); VAR members take no `by_var` entry |
| `beliefs.init.method` | `'re_moments'`, `'training_ols'`, `'user'` | Initial beliefs from the RE model's moments (IJCB sec. 3.1), from OLS on a training range of the RE-smoothed history, or your values |
| `beliefs.init.date` | `[]` | Date of the initial beliefs; `[]` = first filter date + 4 quarters (SW07: 1966Q1) |
| `beliefs.init.values.<x>` | `.alpha`, `.beta` (or `.phi`), optional `.R` | Your initial beliefs; anything missing comes from the RE moments |
| `beliefs.init.training_range` | `[start, end]` | Required for `'training_ols'` |

**PLM consistency check (`hetlearn:load_model:plmMismatch`).** The generated model file gives
every forward-looking variable the default PLM as its own equation; a run gives a forward-looking
variable outside the learning set, used as a regressor in a learning variable's PLM, an auxiliary
AR(1). With `beliefs.plm.default = 'ar1'` the two agree. With a non-AR(1) default (`'ar2'`,
`'ar1_noconst'`, `'var1'`) and such a regressor they differ, and `hetlearn.load_model` stops with
`hetlearn:load_model:plmMismatch`. Fix: set `beliefs.plm.by_var.<u>` for that regressor `u`, so
that the generated file and the run use the same PLM for it. The same error is raised when a PLM
parameter is not declared in the generated file.

### 5.4 Gain

| Option | Values | Meaning |
|---|---|---|
| `gain.rule` | `'constant'`, `'koz'` | Constant gain, or the endogenous gain of Kostyshyna, Özden and Zhang (2024), eq. (9) (DESIGN 18). The name must be a function in `toolbox/+hetlearn/+gain/`. The decreasing gain (`'decreasing'`, `gain.decreasing`) was removed on 2026-10-22 (9.10) |
| `gain.value` | `0.0585` | Constant gain (IJCB posterior mean); also the start of `'koz'`. In (0, 1]. SW07 baseline: 0.05 with `gain.rule = 'koz'` (`master_options.m`) |
| `gain.by_var.<x>` | number | Gain of one variable (`'constant'`; with `'koz'` the start value under `'per_variable'`, ignored with a warning under `'common'`) |
| `gain.koz.mu` | `0.001` | Step size of the gain process ("gain on the gain"); 0 gives the constant gain exactly |
| `gain.koz.error` | `'rls'`, `'forecast'` | Signed error that drives the gain: the one-step PLM residual, or the learners' expectation error x_t - f^BR_{t-1} |
| `gain.koz.error_scale` | `1` | Factor on the error; 1 = model units (percent per quarter), the units of the SW07 data and of chi (user decision 2026-10-19; the first SW07 runs used 4, annualised). mu is scale dependent, effectively with the square of the factor |
| `gain.koz.bounds` | `[0.001 0.25]` | The gain stays inside, with 0 < lower <= upper <= 1; a `gain_bound` event each quarter a bound binds. The start gain must lie inside |
| `gain.koz.structure` | `'common'`, `'per_variable'` | One gain process for all PLM equations, driven by `gain.koz.master`, or one per equation driven by its own error |
| `gain.koz.master` | `''` | `'common'` only: `''` = the first learning variable; a list = the mean of their scaled errors. With a list, a quarter in which any driver's error is missing skips the gain update (gamma and Rg kept) |
| `gain.koz.gamma0`, `gain.koz.Rg0` | `[]`, `0` | Start values; `[]` = `gain.value` |

A missing error (NaN: missing data, or the first learning quarter under `gain.koz.error =
'forecast'`) leaves gamma and Rg unchanged that quarter. With `gain.koz.master` a list, FE_t is
the mean of the drivers' errors, so one missing driver is enough to skip the update for the
whole common process.

With `'koz'`, `res.learning.<x>` also holds `gain_R`. KOZ's Table 1 "R0 = 0.001" is the initial
RLS moment matrix: to use it, set `beliefs.init.method = 'user'` and only
`beliefs.init.values.<x>.R = 0.001*eye(k)`.

### 5.5 Shares

| Option | Values | Meaning |
|---|---|---|
| `shares.structure` | `'per_variable'`, `'universal'` | One BR share per learning variable, driven by its own errors; or one share for all, driven by `shares.master` |
| `shares.master` | name or cellstr | `'universal'` only (required there): variables whose squared errors drive the share (a list sums them, as IJCB does for inflation and the output gap). Each must learn |
| `shares.init_n2` | `0.5` | Initial BR share at `beliefs.init.date` (also set in `master_options.m`) |
| `shares.fixed_n2` | number, or struct by variable | Mode `'fixed_shares'` (required there, or `shares.fixed`): the BR share |

`shares.init` and `shares.fixed` (by type name) are in 9.2. The N-type switching options
`switching.inertia`, `.costs`, `.fitness` and `intensity = 'model:bma'` were removed on
2026-10-22 (9.10).

### 5.6 Switching

| Option | Values | Meaning |
|---|---|---|
| `switching.rule` | `'discrete_choice'` | IJCB eqs. (14)-(15); the name must be a function in `toolbox/+hetlearn/+switching/` |
| `switching.intensity` | `0.51` | Intensity of choice chi, IJCB's estimate as published. IJCB's data are in percent per quarter, the units of SW07, so no conversion applies (user decision 2026-10-18; the earlier 8 = 0.51 x 16 assumed annualised data). For annualised data divide by 16 for the same switching. Must be >= 0. SW07 baseline since 2026-10-20: 2 (`master_options.m`) |
| `switching.memory` | `0.6` | Memory omega of the fitness measure (IJCB sec. 4 text; Table 1 mean 0.62). In [0, 1). SW07 baseline since 2026-10-20: 0.8 |

The squared errors enter unscaled. With zero future shocks both fitness measures decay, so the
BR shares drift toward 0.5 by construction (there is no cost term for RE).

### 5.7 Projection facility

The only stabilising device. PLM = the learners' forecasting rule; ALM = the model with the
current beliefs and shares in it.

| Option | Values | Meaning |
|---|---|---|
| `projection.facility` | `'plm_alm'`, `'alm'`, `'none'` | `'plm_alm'`: check each PLM block, then the ALM. A block whose candidate beliefs have a root above 1 in modulus (AR(1): abs(beta) > 1) keeps its previous beliefs; the other blocks update. `'alm'`: check the ALM only; PLMs may be explosive while the model stays stable. If the model with the new beliefs has no stable solution, every belief goes back to its value before this quarter's update. `'none'`: no restriction; a quarter that must be simulated without a solution stops the run |

- **PLM block:** PLM equations linked through their regressors. A VAR is one block, an auxiliary
  PLM belongs to the block that uses it, separate AR(1)s are separate blocks.
- **Shares kept as the last step.** If the model is still unstable with every belief at its
  previous value, `'alm'` and `'plm_alm'` also keep last quarter's model shares for one quarter
  (event `projection_alm_shares`). Switching carries on underneath: the fitness and the
  discrete-choice shares `n1`, `n2` keep updating, the next quarter tries the new shares again,
  and `n1_model` records the share actually in the model.
- **Stops.** `'alm'` and `'plm_alm'` stop with `hetlearn:engine:almUnstable` only when there is
  no earlier solved model to fall back on (the initial beliefs and shares are unstable at the
  first check). Under `'none'` a quarter without a solution stops with
  `hetlearn:engine:noSolution` (date, stage, shares, each PLM block's largest root, IRIS flag).
  Exception: an anchored model in which every forward-looking variable learns has no leads, so
  under `'none'` it is simulated as it is (`explosive` events).
- **Every stage.** The same rules apply in the history (the model is solved each quarter only for
  the ALM check; `res.meta.history_alm_check_s` gives the time, 3-10 s for SW07), the inversion,
  the forecast, density draws, the evaluation and Ramsey runs. Mode `'rational'` skips the check.
- The endogenous gain updates from the forecast error whatever the facility does.

### 5.8 History before the forecast origin

| Option | Values | Meaning |
|---|---|---|
| `history.learn` | `true`, `false` | Learn beliefs and shares over the history; `false` = the initial beliefs apply at the origin |
| `history.mode` | `'re_smoother'`, `'inversion'`, `'kalman'` | Learning on the RE-smoothed history; or the history backed out with the learning model, one quarter at a time (observables exogenised, shocks endogenised); or a time-varying Kalman filter of the model in force each quarter, with one-step prediction errors and the log likelihood (9.6). `'inversion'` and `'kalman'` need `history.learn = true`; `'inversion'` does not take N agent types or transforms. `'hetero_filter'` is a reserved name: error `hetlearn:options:notImplemented`, pointing to `'kalman'` |
| `history.kalman.init` | `'stochastic'`, `'smoothed'` | `'kalman'` only: start from the asymptotic distribution of the first quarter's model, or at `beliefs.init.date` from the RE-smoothed state (9.6) |
| `history.re_states` | `'smoothed'`, `'filtered'` | `'re_smoother'` only. Source of the RE agents' forecasts, the learners' data and the realised values in the fitness errors: the two-sided Kalman smoother, or the one-sided filter (x_{t|t}, data up to t). With `'inversion'` and `'kalman'` it is an error. SW07 baseline since 2026-10-20: `'filtered'` (`a6_inv_learn` and the Kalman scenarios set `'smoothed'`) |
| `history.inversion.start` | `[]` | First inversion quarter; `[]` = `beliefs.init.date` |
| `history.inversion.shocks` | `{}` | Shocks backed out; `{}` = every transition shock (at least as many as observables) |
| `history.realtime` | `false`, `true` | RE filter on data up to the origin only (no look-ahead). Takes effect only under `history.mode = 're_smoother'`; ignored under `'kalman'` and `'inversion'`, whose histories are one-sided by construction (the full-sample RE filter only supplies their starting state) |

**RE states.** Under `'smoothed'` the RE agents' forecast made in t comes from states estimated
with data after t, which helps them in the fitness race. `'filtered'` removes that hindsight. For
an observed variable the two settings agree (SW07 inflation outside 2020Q1-Q3), so the option
moves the RE forecasts and, in the 2020Q1-Q3 gap, the learners' data, where the filtered value is
the RE prediction and the RE error is 0. The forecast still starts from the smoothed state;
`history.realtime = true` makes that state real time too, so `'filtered'` with `realtime = true`
is the fully real-time setup.

**Inversion accuracy.** The SW07 figures in DESIGN 15 (the RE inversion reproduces the
RE-smoothed shocks to 2.1e-13 over 1966Q1-2026Q2) were measured on 2026-10-18, before the covid
quarters 2020Q1-Q3 were set to NaN (1.2). The inversion has nothing to exogenise in those
quarters and backs out zero shocks, so it now equals the RE smoother only up to 2019Q4;
`test_inversion` S1 checks it there (below 1e-8).

### 5.9 Shocks over the horizon

| Option | Values | Meaning |
|---|---|---|
| `shocks.source` | `'none'`, `'smoothed'` | Zero shocks, or the RE-smoothed shocks |
| `shocks.range` | `[]` | Quarters that get smoothed shocks; `[]` = the horizon (dates outside it are ignored) |
| `shocks.exclude` | `{}` | Shocks set to zero, e.g. `{'em'}` |
| `shocks.add` | `{}` | Shocks added on top: `{{'em', qq(2022,3), -0.25}, ...}` (name, dates, values; values scalar or one per date) |

All shocks are unanticipated: every quarter is a new simulation.

### 5.10 Conditions: exogenise a variable, endogenise a shock

`cfg.conditions` is a struct array, one element per variable-shock pair; `[c1, c2]` for
several. It replaces the inherited value as a whole.

| Field | Values | Meaning |
|---|---|---|
| `variable` | name | Transition or measurement variable to put on a path, e.g. `'robs'`, `'ms'` |
| `shock` | name | Shock that adjusts to hit it |
| `dates` | dates, or `[start, end]` | Quarters of the condition, inside the horizon. Two dates are always read as a range |
| `values` | number or vector | Targets (scalar or one per date) |
| `type` | `'level'` (default), `'delta'` | The target is the value itself, or the value added to a reference path |
| `reference` | `'self'` (default) or a scenario id | For `'delta'`: the same scenario without conditions, or another scenario's path |

A variable conditioned twice in one quarter is an error. With more endogenised shocks than
targets, the smallest shocks in standard-deviation units are used
(`engine.conditions_weighting = 'std'`).

### 5.11 Monetary policy (Ramsey)

| Option | Values | Meaning |
|---|---|---|
| `policy.mode` | `'rule'`, `'ramsey'` | The model's own rule, or optimal policy from the origin (needs `spec.policy`) |
| `policy.type` | `'commitment'`, `'discretion'` | Commitment. Discretion is indeterminate in IRIS for SW07 |
| `policy.loss` | `struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0)` | Non-negative weights by `spec.policy.targets` name. Replaced as a whole: targets you leave out get weight 0 |
| `policy.discount` | `[]` or a number in (0, 1] | `[]` = `spec.policy.discount` |
| `policy.loss_horizon` | `[]` or quarters | Horizon of the reported loss; `[]` = the forecast horizon. A longer one continues the scenario with zero shocks and no conditions |

Every run of a package with `spec.policy` reports its loss with the `policy.loss` weights
(`results/<id>/loss.csv`), so rule and Ramsey runs compare on the same weights. The Ramsey plan
starts at the origin with zero Lagrange multipliers; with learning, the planner re-optimises
each quarter with the current beliefs and shares.

### 5.12 Density forecasts

| Option | Values | Meaning |
|---|---|---|
| `density.enabled` | `false` | Switch on |
| `density.shocks` | cellstr | Shocks to draw (required when enabled) |
| `density.sigma` | `'calibrated'`, `'smoothed'` | Model `std_<shock>`, or the sample std of the RE-smoothed shocks over `sigma_range` |
| `density.sigma_range` | `[]` | `[]` = the filter range |
| `density.method` | `'normal'`, `'bootstrap'` | Normal draws, or resampled whole quarters of smoothed shocks |
| `density.demean` | `true` | Bootstrap: demean the pool first |
| `density.ndraws` | `200` | Number of draws |
| `density.seed` | `0` | Random seed |
| `density.quantiles` | `[0.05 0.16 0.5 0.84 0.95]` | Reported quantiles |
| `density.range` | `[]` | Quarters with draws; `[]` = the horizon |
| `density.keep_draws` | `false` | Store every draw in `density.mat` |
| `density.fast_path` | `true` | Mode `'rational'` without conditions: one linear simulation per draw |

Draws come on top of the scenario's own shocks and conditions. With learning, each draw re-runs
the quarter-by-quarter forecast, so beliefs and shares respond to the drawn shocks.

### 5.13 Engine

| Option | Values | Meaning |
|---|---|---|
| `engine.step` | `'fast'`, `'iris'` | One-quarter step from the cached state-space solution, equal to IRIS `simulate` to about 1e-12, 2-3 times faster (about 20 times with the observables exogenised, as in the inversion); or IRIS `simulate` itself |
| `engine.conditions_weighting` | `'std'`, `'none'` | More shocks than targets: minimum norm in std units, or unweighted |

### 5.14 Removed options and option errors

Removed on 2026-10-18; setting one stops the run with `hetlearn:options:removed` and a message
that names the replacement:

| Removed | Replacement |
|---|---|
| `projection.max_root`, `projection.method`, `projection.scope`, `projection.on_failure` | `projection.facility` |
| `switching.error_scale`, `switching.error_scale_ref` | none: squared errors enter unscaled; the facility is the only stabilising device |

Removed on 2026-10-22 with the bounded-rationality variants dropped after the BR audit: the
options listed in 9.10. They also stop the run with `hetlearn:options:removed`; in a merged
tree saved before the cut they are dropped when they hold their old off values.

Other option errors: `hetlearn:options:unknown` (a name not in the defaults),
`hetlearn:options:type` (wrong type, e.g. a struct where a value is expected),
`hetlearn:options:value` (a value outside its enumeration or range), `hetlearn:options:missing`
(`'fixed_shares'` without `shares.fixed_n2`, `'universal'` without `shares.master`,
`'training_ols'` without `beliefs.init.training_range`, density without shocks).

Free-form subtrees, merged without name checks: `beliefs.init.values`, `beliefs.plm.by_var`,
`beliefs.plm.derived` (must hold strings), `gain.by_var`, `shares.fixed_n2` (as a struct),
`shocks.add`, `report`. Replaced as a whole, not merged: `conditions`, `policy.loss`,
`expectations.types`, `expectations.transforms`, `shares.init`, `shares.fixed`.

---

## 6. Outputs

### 6.1 `results/<id>/`

| File | Content |
|---|---|
| `results.mat` | `res`: `.cfg` (merged options), `.paths` (databank from the filter start to origin + H: RE-smoothed history, then the scenario; every variable and shock), `.learning`, `.events`, `.state`, `.dates`, `.meta` (runtimes, IRIS version, hashes, filter fit, collapse test, `history_alm_check_s`), `.loss` (packages with `spec.policy`) |
| `observables.csv` | date and every observable, filter start to origin + H, model units |
| `paths.csv` | date and every transition variable, horizon |
| `learning.csv` | long: date, variable, field, value (fields in 6.2) |
| `events.csv` | date, type, variable, detail, stage (6.2) |
| `compare_<id>.csv` | this run minus `<id>`, observables, horizon, model units (`compare_with`) |
| `loss.csv` | target, expression, weight, contribution, share, discount, horizon, continuation, mode, type; one row per target and a total row |
| `density.mat` | variable `density`: quantiles, means, stds and point forecasts of every summarised series, draw information, events (draws if kept); not inside `results.mat` |
| `density_quantiles.csv` | variable, date, quantile, value_model, value_report |
| `density_events.csv` | one row per draw: draw, status, projection_plm, projection_alm, projection_alm_shares, explosive_events, rls_missing, shares_nan, gain_bound, max_abs, message |
| `decomposition.csv` | after `hetlearn.decompose`: scenario, date, variable, component, value_model, value_report, label (with `total` rows) |
| `decomposition_check.csv` | app 6 only (`run_applications`): scenario, method, additivity_maxerr, recon_maxerr, n_solve, n_backward, runtime_s |

A run without density deletes density files left by an earlier run of the same id.

### 6.2 Learning fields, share names, events

`res.learning.<x>` (one per PLM target, auxiliary PLMs included) holds IRIS Series, also in
`learning.csv`:

- beliefs, named like the model parameters: `alpha_<x>`, `beta_<x>` for an AR(1) with constant;
  `alpha_<x>` and `beta_<x>__<u>_l<lag>` for other PLMs (e.g. `beta_pinf__ygap_l1` in
  `v2_var3`);
- `R_<param>`: the diagonal of the RLS moment matrix;
- `gain` (and `gain_R` with `gain.rule = 'koz'`);
- for learning variables also `n1`, `n2`, `n1_model`, `zetaRE`, `zetaBR` (fitness), `FE_RE`,
  `FE_BR` (squared one-step errors), `fRE`, `fBR` (one-step forecasts).

Share names. Type 1 = RE agents, type 2 = BR (learning) agents; the shares sum to 1.

| Name | Where | Meaning |
|---|---|---|
| `shares.init_n2`, `shares.fixed_n2` | options | BR share |
| `n1_<x>`, `n2_<x>` | model parameters | RE and BR shares of x's expectation in the model |
| `n1`, `n2` | `res.learning.<x>` | Discrete-choice shares computed at the end of each quarter (diagnostic unless the mode is `'switching'`) |
| `n1_model` | `res.learning.<x>` | RE share in the model that quarter (= `n1` of the quarter before under switching, unless the facility kept the shares) |
| `n2_model`, `n2_model_<x>` | summary CSVs, density outputs | 1 - `n1_model`: BR share in the model |

Event types (`events.csv`; column `stage` = `history`, `inversion` or `forecast`):

| Type | Meaning |
|---|---|
| `projection_plm` | `'plm_alm'`: a PLM block's candidate beliefs had a root above 1; that block kept its beliefs (detail names the block and the root) |
| `projection_alm` | The model with the new beliefs and shares had no stable solution; every belief went back to its value before this quarter's update |
| `projection_alm_shares` | Still unstable with the old beliefs: last quarter's model shares stayed in force for this quarter |
| `explosive` | A model without leads was simulated by the backward simulator without a stable IRIS solution |
| `rls_missing` | Missing data for a PLM equation; that equation kept its beliefs |
| `shares_nan` | The discrete choice gave non-finite shares; the previous fitness and shares were kept |
| `gain_bound` | The KOZ gain hit a bound of `gain.koz.bounds` |

### 6.3 `results/run_log.csv`

Columns: logged, group, id, status (`ok` or `error`), runtime_s, events, message. One row per
run, per decomposition (`decompose:<id>`), per evaluation part (`eval:<variant>_p<k>`) and per
merge (`eval:merge`). Rows are appended and never removed; the summary uses the last row of
each id. A failing scenario is printed, logged and skipped, and the next one runs.

### 6.4 `results/eval_<name>/`

| File | Content |
|---|---|
| `errors_long.csv` | variant, origin, target, h, variable, actual, forecast, error (actual minus forecast, report units) |
| `metrics.csv` | sample, variant, variable, h, n, rmse, me (bias), mae; sample `full` and each subsample |
| `relative_rmse.csv` | sample, variant, benchmark, variable, h, n, rmse, rmse_benchmark, relative_rmse |
| `dm.csv` | sample, variant, benchmark, variable, h, n, mean_loss_diff, dm_stat, p_value, kernel (Diebold-Mariano with the HLN correction; uniform kernel, Bartlett fallback where the variance is not positive) |
| `settings.mat` | `settings`: variants, origins, horizon, benchmark, subsamples, failed runs, events per run; the merged file of `run_applications` also coverage, parts, DM kernel and fallbacks |
| `parts/eval_<variant>_p<k>/` | `run_applications` only: one folder per part (`_p<k>of<K>` with another K), same files |

### 6.5 `results/summary_v3/`

From `build_summary_v3.m` (report units unless stated):

| File | Content |
|---|---|
| `scenarios.csv` | One row per `SC` entry (50: 40 runs, 10 evaluation variants): id, folder, app, label, description, status (from the run log), runtime_s, error_message, n_events, and `projection_plm`, `projection_alm`, `projection_alm_shares` counts by stage |
| `paths_long.csv` | app, scenario, date, variable, value, source (scenario or data), stage: `pinfobs`, `robs`, `dy`, `dc`, 2015Q1-2026Q2 |
| `learning_long.csv` | app, scenario, date, variable, field, value, stage: for every learning run and PLM target, `n2_model`, `n2`, belief parameters, persistence (largest root of the PLM block), perceived_mean (model units), perceived_mean_report (`pinf`, `r`: annualised level), gain, gain_R; non-finite rows left out |
| `events_long.csv` | app, scenario, date, stage, type, variable, detail |
| `app3_policy.csv` | expectations, variable, date, loose_minus_base, tight_minus_base, asymmetry (their sum); variables `pinfobs`, `robs`, `dy`, `dc`, `ygap`, `ms`, `n2_model_pinf` |
| `app4_losses.csv` | weights, expectations (RE, learning, `RE_model_consistent`: Ramsey from the saved `_re_mc` runs, rule from `a4_rule_re`), policy (rule or ramsey), horizon (16, 80), total, pinf, ygap, r, dr; every loss rebuilt with the weights of line 291 |
| `app4_targets_long.csv` | app, scenario, h, date, target, value: the four loss targets (`4*pinf`, `y - yf`, `4*r`, `4*(r - r{-1})`) of every app-4 run over the 80-quarter loss horizon |
| `app5_density.csv` | case, expectations, variable, date, quantile, value |
| `app5_widths.csv` | case, expectations, variable, date, width_90 (95th minus 5th percentile), ratio_to_re |
| `app5_mechanism.csv` | shock, case, expectations, variable, h, date, response: one unit of each density shock (`epinf`, `ew`, `eb`, `eg`, `eqs`) added in 2022Q3 to `a1_re` and `a1_learn` (ten unsaved runs); response = the difference from the saved run without it; variables `pinfobs`, `pinf_exp1`, `pinf_exp1_RE`, `pinf_exp1_BR`, `robs`, `dy`, `n2_model_pinf` (expectations x 4) |
| `app6_decomp_long.csv` | case (re_smooth, learn_smooth, learn_inv), date, variable, component (`intercept_channel` = toolbox `beliefs_constants`), value, label |
| `app6_shocks_long.csv` | date, shock, smoothed, inversion, diff, diff_sd (difference in model std units) |
| `v3_facility.csv` | scenario (`a1_learn`, `v3_all`, `v3_all_plm_alm`, `v3_all_alm`), facility, variables, status, error_message, error_date, event counts by type and stage (`explosive` included), average `pinfobs`, `robs`, `dy` over 2022Q3-2026Q2 |
| `eval_metrics.csv`, `eval_relative.csv`, `eval_dm.csv` | the merged evaluation tables with a `label` column |
| `key_numbers.csv` | name, value, unit, description (1,314 rows): every number the memo and the report quote |
| `checks_v3.txt` | checks C1-C12 (15 lines), PASS or FAIL with the value; C12: the saved `_re_mc` runs equal the unsaved model-consistent copies |

`FINDINGS_v3.md` is the memo (1.1). The four `other_models_*` files of the retired
`build_other_models.m` stay in the folder; nothing reads them since 2026-10-21.

### 6.6 The report

`reports/sw07_learning_report.html`, written by `python reports/build_report_v3.py`: 15
sections (section 12 on the other models removed 2026-10-21), 142 charts, about 643 KB. It is page content only (no `<html>` wrapper); the claude.ai
Artifact publisher wraps it, and a browser opens it as it is (fonts come from Google Fonts).
Published at https://claude.ai/artifact/BvM5vuFBTYm943Z8eBpZR8 (version 5, 2026-10-19, after
the reviewer's pass).

### 6.7 Units

- Model units: percent quarter on quarter; the policy rate in percent per quarter; SW07 hours
  100 x log. Reports multiply by `spec.report.scale` (4 annualises).
- ijcb3: `pinfobs`, `robs` percent per quarter (scale 4), `yobs` percent of trend output
  (scale 1). as07: `dy` percent q/q (scale 4); `pinfobs`, `robs` already percent a year
  (scale 1).
- Report units = model units x scale: the summary CSVs, `errors_long.csv`, `value_report`
  columns. Learning fields are in model units.

### 6.8 The estimation module (separate; not adopted)

`estimation/` estimates SW07 by Bayesian methods, under rational expectations and with the
a1_learn learning block (the 36 SW07 parameters plus the gain, the memory and the intensity of
choice), on 1966Q1-2026Q2 with the covid quarters missing. It is a separate module: nothing in
`toolbox/`, `models/` or `scenarios/` uses it, every scenario of this guide keeps the published
swX1 parameters, and it runs against a frozen copy of the toolbox (it also passes its gates
against the live toolbox). Run order, file formats and the final pass after the chains finish:
`estimation/README.md`. In short, from `estimation/`, one `matlab -batch` process per step:
the gates (`est_00_gates`), the modes, Hessians and chains (`est_01` to `est_05`), then
`est_06_post('final')` (or `'interim'` while the learning chains run), which writes
`results/estimation/tables/*.csv` and runs application 1 at the estimates
(`estimation/scenarios/e1_*.m` on the generated packages `estimation/models/sw07_est_*`).
The report is `reports/sw07_estimation_report.html`, built by
`python reports/build_estimation_report.py`; it is separate from the report of 6.6.

---

## 7. Functions

Project level:

| Call | What it does |
|---|---|
| `setup_paths()` | Starts IRIS unless started, adds the toolbox, the patch (first on the path), `config/` and `scenarios/` with subfolders |
| `L = run_applications(groups, ...)` | Groups `'app1'`-`'app6'`, `'var1'`-`'var4'`, `'eval'`, `'all'` (default), a scenario id (logged under its group, else `single`), or a cell of these; `'decompose'`; `'eval_part', variants, parts [, K]`; `'eval_merge'`. Returns this call's run-log rows. `help run_applications` gives the group table and times |
| `o = master_options()` | The project-wide partial option tree |
| `run_tests(only)` | Test suites (8.6) |

Toolbox (`help hetlearn.<name>` gives the full text):

| Signature | What it does |
|---|---|
| `res = hetlearn.run(cfg, 'save', true, 'results_dir', folder, 'quiet', false)` | One scenario run; also `'model'` (preloaded model, same options) and `'filter'` (RE filter output) |
| `T = hetlearn.run_files(names, <run options>)` | Runs scenario files in order (each re-run), returns a status table |
| `T = hetlearn.compare(ids, vars, range, 'results_dir', folder)` | Levels (`<var>__<id>`) and differences from the first id (`<var>__<id>_minus_<id1>`) of saved scenarios; runs a missing one first |
| `D = hetlearn.decompose(res, vars, range, opts)` | Shock decomposition of a result or a saved id; opts `.groups`, `.method` (`'auto'`, `'iris'`, `'tv'`), `.model`, `.save`, `.results_dir`, `.file`, `.quiet`; writes `decomposition.csv` |
| `E = hetlearn.evaluate(name, variants, origins, opts)` | Recursive real-time evaluation; opts `.horizon` (8), `.benchmark` (first variant), `.dm`, `.dm_hln` (true), `.dm_kernel`, `.subsamples`, `.realtime` (true), `.results_dir`, `.save`, `.quiet`; writes `results/eval_<name>/` |
| `T = hetlearn.evaluate_tables(errors, opts)` | Metrics, relative RMSE and DM from an error table, an `errors_long.csv` path or an `eval_<name>` folder |
| `o = hetlearn.defaults()` | The full option tree with defaults |
| `opts = hetlearn.load_options(cfg, master)` | Merge and validate; `master` replaces `master_options()` (tests) |
| `spec = hetlearn.load_spec(name)` | A package's `model_spec` (name under `models/`, or a folder path) |
| `[d, file] = hetlearn.load_database(spec)` | The package database as a databank |
| `[m, info] = hetlearn.load_model(spec, opts)` | Generate (if needed), load, parameterise and solve the extended model |
| `H = hetlearn.re_filter(spec, opts, 'force', false, 'end', date, 'model', MA)` | RE filter and smoother, cached; `'end'` for real-time data |
| `meta = hetlearn.extend_model(spec, plm, 'force', false, 'validate', true)` | Write the extended model file and run the collapse test |
| `[A, info] = hetlearn.re_anchor_coefficients(spec, P, ...)` | Coefficients of the anchored RE forecast |
| `[R, info] = hetlearn.anchor_coefficients(m, targets, states, 'lag', j, 'horizon', h, ...)` | Coefficients of E_{t-j} z_{t+h} in a solved economy, chain states solved out (9.5) |
| `A = hetlearn.agent_types(opts)` | The agent types of a run, resolved against the other options (9.1) |
| `T = hetlearn.engine.kalman_history('rmse', res, subsamples)` | One-step RMSE by observable and subsample, and the log likelihood, of a `history.mode = 'kalman'` result (9.6) |
| `t = hetlearn.find_peak(db, name, from, to)` | Date of a series' maximum in a window (first if tied) |

Options of `hetlearn.evaluate_tables(errors, opts)`. Every field is optional; an unknown field is
an error (`hetlearn:evaluate:option`). Unset fields come from `settings.mat` next to the errors
file when there is one, else from the defaults below.

| Field | Default | Meaning |
|---|---|---|
| `variants` | `settings.ids`, else the order of appearance | Variant ids, in output order |
| `variables` | `settings.observables`, else the order of appearance | Observables, in output order |
| `horizon` | `settings.horizon`, else the largest `h` | Horizon H |
| `origins` | `settings.origins`, else the distinct origins of the table | Origin dates |
| `benchmark` | `settings.benchmark`, else the first variant | Benchmark of the relative RMSE and DM tables |
| `subsamples` | `settings.subsamples`, else none | Struct of `[start, end]` target-date ranges |
| `dm`, `dm_hln`, `dm_kernel` | `true`, `true`, `''` | DM tests; HLN correction with t(n-1) p-values; long-run variance kernel (`''` = `'uniform'` with HLN, else `'bartlett'`) |
| `settings` | `[]` | A settings struct used instead of `settings.mat` (`[]` = read the file if there is one) |
| `save` | `false` | Write `metrics.csv`, `relative_rmse.csv`, `dm.csv` |
| `folder` | the folder of the errors file | Output folder for `save` |
| `write_errors` | `false` | Also write `errors_long.csv` (used by `hetlearn.evaluate` and `run_applications('eval_merge')`) |

---

## 8. Practical notes

### 8.1 Run times (SW07, 2026-10-18)

| Run | Time |
|---|---|
| Start MATLAB and IRIS | about 15 s |
| One scenario | 3-25 s |
| app1 / app2 / app3 / app4 / app6 | 30 s / 10 s / 30 s / 2.5 min / 40 s |
| var1 / var2 / var3 / var4 | 10 s / 70 s / 35 s / 10 s |
| app5 | 14 min: RE densities about 30 s each (fast path), learning densities about 6.5 min each (0.71 s per draw) |
| History backed out, 1966Q1-2026Q2 (`a6_inv_learn`) | 14 s |
| Evaluation | 2.7 hours of compute (10 variants x 138 origins); per variant RE 2.5 min, learning 10-23 min, `e09_var12` 41 min; one part 0.5-7 min; about 47 min in 4 parallel sessions |
| `build_summary_v3.m` / report | about 3 min / 10 s |
| Full test suite | more than 9 min |

### 8.2 Parallel sessions

Run one group first so that the model caches in `models/sw07/generated/` exist. Two sessions
must never write the same `results/<id>/` or the same evaluation part. A `compare_with` target
without results is run first, so give every target its results before starting parallel
sessions. One PowerShell window per session, each with its own log file:

```powershell
& "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -batch "try, cd('<project root>'), run_applications('eval_part', {'e01_re', 'e02_learn'}, 1:6), catch e, disp(getReport(e)), exit(1), end" -logfile eval_s1.log
```

- **Evaluation:** split the variants (or the parts) over the sessions with
  `run_applications('eval_part', variants, parts)`, then run `run_applications('eval_merge')`
  once all have finished; the merge checks that the parts cover every origin exactly once.
  Keep variants with the same PLM on different parts until their real-time filter caches exist.
  A slow variant can be cut finer: `run_applications('eval_part', 'e09_var12', 7:12, 12)` runs
  parts 7-12 of 12 (folders `eval_e09_var12_p<k>of12`); each variant's parts only need to cover
  its origins once.
- **Densities:** `run_applications({'a5_markup_re', 'a5_demand_re'})` first (about 1 min), then
  `run_applications('a5_markup_learn')` and `run_applications('a5_demand_learn')` in two
  sessions.

### 8.3 Caches: `models/<name>/generated/`

| File | What it is |
|---|---|
| `<name>_ext_<tag>.model`, `<name>_ext_<tag>_meta.mat` | Extended model and its metadata; tag `ar1` for the default PLM, else `p` and 8 hex digits of the PLM spec's MD5 |
| `<name>_ext_<tag>_relag.model`, `_relag_meta.mat` | The same with RE expectations on information up to t-1 (`expectations.re_info = 'lagged'`, generator version 5); its RE filter caches are separate and also hold the one-step predictions |
| `<name>_norm.model` | Only when the source needs notation changes: the source in IRIS notation (reference of the collapse test) |
| `refilter_<hash>.mat` | Full-sample RE filter; key: extended model text, parameters, `spec.assign`, database file bytes, filter range |
| `refilter_rt_<end>_<hash>.mat` | Real-time RE filter per end date (evaluation, `history.realtime`); per PLM spec and RE variant; about 1,850 files for SW07 |

A change of parameters, data or PLM spec gives a new key, so a stale cache is never used.
Delete a file, or the folder, only to force a rebuild; the next run is slower.
Since 2026-10-19 a filter cache also holds the filtered databank (`H.filtered`). A cache
written before has none: the first run that reads it filters again and rewrites it under the
same name, with the same smoothed history. Two sessions should not refresh the same file at
once, so run one session first before parallel ones.

### 8.4 OneDrive

The project sits on OneDrive. Copy and move files with PowerShell `Copy-Item` and `Move-Item`,
not Git Bash `cp` and `mv`.

### 8.5 MATLAB batch from PowerShell

```powershell
& "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -batch "try, cd('<project root>'), <commands>, catch e, disp(getReport(e)), exit(1), end" -logfile run.log
```

`-batch` does not start in the PowerShell folder, so put `cd('<project root>')` first.
`exit(1)` in the `catch` gives PowerShell a nonzero exit code. The OneDrive path has spaces:
keep it inside the MATLAB single quotes. `run_applications` and the two summary scripts call `setup_paths`
themselves; anything else needs `setup_paths` first.

### 8.6 Tests

- **The tests do not read the project baseline.** `tests/scenarios/master_options.m` holds the
  values `config/master_options.m` had until 2026-10-19 (= `hetlearn.defaults()`); `run_tests`
  and the SW07 suites put `tests/scenarios/` first on the path, and `run_tests` stops if
  `master_options` resolves elsewhere. A suite run on its own needs `addpath('tests/scenarios')`.
  The test scenarios `tsw07_*` also pin the settings the baseline changed (`model_params = ''`,
  constant gain, `re_info = 'current'`, `re_states = 'smoothed'`, facility `'plm_alm'`).
- **Exact references and threads.** `test_inversion` S3b, `test_gain` G14, `test_re_states` S1
  and `test_re_info` T6b compare with `tests/reference/` exactly. The references were made at the
  default thread count; with `maxNumCompThreads(2)` the runs differ by about 1e-12 and those four
  checks fail. Run them at the default thread count (2026-10-20: all pass that way).
- `run_tests` runs the 24 suites in `tests/run_tests.m` (364 checks on 2026-10-22, all pass; 403 checks
  in 25 suites on 2026-10-21, before the cut of the bounded-rationality portfolio; 296 checks in 19
  suites on 2026-10-20, before the extensions): more than 9 min in one session. The suites of the extensions are `test_kalman`, `test_ntypes`, `test_transforms`,
  `test_anchor` and `test_br_regression` (exact, run it at the default thread count).
  `test_learning_rules` (SAC, Kalman-filter learning, decreasing gain) and the checks of the
  other options removed on 2026-10-22 went with them (9.10).
- A subset: `run_tests({'test_options', 'test_rls', 'test_switching'})`. `test_re_info` alone
  takes about 8 min; `test_re_info('toy')`, `('sw07_model')`, `('sw07_runs')`,
  `('sw07_stages')` run its parts. Its Dynare check reads stored IRFs
  (`tests/reference/re_info_dynare_irfs.mat`); `tests/models/dynare/run_dynare_check.m`
  remakes them in a session without IRIS (Dynare 4.6.1, run in `C:\dynare_work\re_info_check\`).
- Run `run_tests({'test_generator'})` in a MATLAB session of its own (README_PIPELINE).
- `test_decompose`'s SW07 part reads outputs of `test_inversion` in `tests/output/results/`; run
  `test_inversion` first (`run_tests` orders them so).
- The tests never read `scenarios/` or `results/`: they use `tests/toy_nk/`,
  `tests/scenarios/tsw07_*.m` and `models/sw07/`, and write `tests/output/results/` and
  `tests/toy_nk/generated/`.
- `tests/scenarios/make_reference.m` rewrites `tests/reference/tsw07_switch_pinf_iris.mat` and
  `tsw07_switch_pinf_fast.mat` (the default `'fast'` step, compared exactly by
  `test_re_states`). Run it only after a deliberate change of the engine or the defaults, and
  record it in `README_PIPELINE.md`.

### 8.7 Known caveats

- **Anchored RE under Ramsey (open design question).** Anchored agents forecast with the RE
  solution under the Taylor rule, also in mode `'rational'`, so `a4_ramsey_<w>_re` are not RE
  Ramsey plans. The RE Ramsey benchmark is `a4_ramsey_<w>_re_mc` (model-consistent RE agents;
  rows `RE_model_consistent` in `app4_losses.csv`). In the `_learn` files the anchored RE agents
  still forecast with the Taylor-rule solution.
- **Model-consistent RE with many learning variables** can lose the stable solution. On SW07
  with all 12 variables learning, such a run completes only because the facility keeps the
  model shares: under `'plm_alm'` the origin's shares stay in force in all 16 forecast quarters
  (`README_PIPELINE.md`, track G). Check `events.csv` for `projection_alm_shares` before you
  read such a run.
- **Zero future shocks:** the shares drift toward 0.5 by construction (5.6).
- **Scenario names** are function names on the path; keep them unique (`which -all <name>`).

### 8.8 The git repository

https://github.com/tolgaozden/iris_toolbox_learning (public, MIT licence, branch `main`). Not versioned
(`.gitignore`): `results/` except `results/summary_v3/*.m` and `FINDINGS_v3.md`, every
`generated/` folder, `tests/output/`, `reports/*.html` and `archive/`. Everything else (code,
scenarios, model packages with their data, docs) is versioned once committed, and a clone
rebuilds every output with the steps in 2.3. Every versioned file is committed (269 commits on
2026-10-19). Project convention: one file per commit, authored by the user, each message
explaining the file.

---

## 9. Bounded-rationality expectation rules

Added 2026-10-21; cut on 2026-10-22 to the seven portfolio variants kept after the BR audit
(9.10). The options of this section let a scenario replace the two agent types (RE agents and
AR(1) learners) by a population of forecasting types, set their initial or fixed shares, and
transform the expectations the model uses. Every option is off by default, and a scenario that
sets none of them runs the two-type code of 2026-10-20 unchanged (`tests/test_br_regression.m`
checks that its results are bit-identical).

The design, the formulas and the evidence for each parameter value are in
`docs/DESIGN_br_extensions.md`: section 1 for the machinery (E1-E6 below), section 2 for the
mechanisms, section 3 for the portfolio variants, section 5 for the Kalman history, section 6
for what each phase built and tested, section 7 for the decisions behind proposed values.
`docs/BR_audit.txt` scores the 21 variants built on 2026-10-21 and gives the reasons for the cut.

| Extension | Options | Design |
|---|---|---|
| E1 N agent types | `expectations.types`, kinds `'re'`, `'plm'`, `'rule'`, `'re_mean'` | 1.1 |
| E2 shares over N types | `shares.init`, `shares.fixed` | 1.2 |
| E3 forecast transforms | `expectations.transforms`, kinds `'multiplier'`, `'diagnostic'`, `'myopia_anchoring'` | 1.3 |
| E4 generalised anchor | type kind `'re_mean'`; `hetlearn.anchor_coefficients` | 1.4 |
| E5 learning rules | mean-only PLM (`beliefs.plm.by_var`); the constant and KOZ gains of 5.4 | 1.5 |
| E6 Kalman history | `history.mode = 'kalman'`, `history.kalman.init` | 5 |

The seven portfolio scenarios are `scenarios/sw07/br_portfolio/br<NN><x>_<name>.m`. Each is
`cfg = a1_learn();` plus the lines of 9.7, so it inherits the project baseline (1.4).

### 9.1 Agent types: `expectations.types`

A struct array, or a cell array of structs, one struct per type, with these fields:

| Field | Values | Meaning |
|---|---|---|
| `name` | letters and digits, starting with a letter; required | Suffix of the type's forecast `<x>_exp1_<name>` and share `n_<name>_<x>` |
| `kind` | `'re'`, `'plm'`, `'rule'`, `'re_mean'`; required | The RE forecast (only the type named `RE`); a learned PLM; a fixed linear rule (9.1.1); the RE forecast plus a learned mean of its own error (9.5) |
| `rule` | text, or `struct('expr', <text>, 'params', struct(...))` | `'rule'` only, required (9.1.1) |

Everything else comes from the global options, the same for every type of a kind:

| Kind | Takes |
|---|---|
| `'re'` | `expectations.re_variant`, `expectations.re_info` |
| `'plm'` | `beliefs.plm`, `beliefs.info`, `beliefs.update`, `gain` |
| `'rule'` | `beliefs.info`; a rule has no beliefs |
| `'re_mean'` | the RE type's variant and information; `beliefs.update` and `gain` for its learned mean |

Rules of the population:
- Every type forecasts every learning variable (`expectations.variables`). The share groups follow
  `shares.structure` (5.5): one per learning variable, or one for all under `'universal'`.
- The RE type is always generated. When the list does not name it, it has share 0 and stays
  outside the logit, and it is still the RE limit that the RE filter and the history use. Only
  the type named `RE` can be of kind `'re'`.
- Modes: `'rational'` puts share 1 on the RE type; `'learning'` share 1 on the single non-RE
  type (an error when there are several); `'fixed_shares'` takes `shares.fixed` (struct by type
  name) or the two-type shorthand `shares.fixed_n2`; `'switching'` uses 9.2.
- Writing the default pair out, `{struct('name', 'RE', 'kind', 're'), struct('name', 'BR',
  'kind', 'plm')}`, takes the N-type generator and engine and gives the two-type results
  exactly (`test_ntypes` R3, `test_kalman` K6).

Generated file: `models/<name>/generated/<name>_ext_n<hash>.model` (generator version 6; 7 with
transforms; 8 with `'re_mean'` types).

#### 9.1.1 Rule syntax

A rule is a fixed linear expression in these terms (`hetlearn.plm.rule_terms`):

| Term | Meaning |
|---|---|
| `x{-k}` | The variable being forecast, k quarters back (k >= 1 under `'lagged'` information). The same rule applies to every learning variable |
| other transition variables, with lags (`y{-1}`) | As written, with the same lag rule |
| numbers, `+ - * / ( )` | As written |
| named constants | The fields of `params` in `struct('expr', <text>, 'params', struct(...))` |

A rule type learns nothing: it has no PLM and no beliefs, and its forecast enters fitness like
any other type's. The terms `self{-k}`, `mean`, `dn` and `re1(...)` were removed on 2026-10-22
(9.10).

Example, target believers beside the baseline pair (variant 19, Hommes and Lustenhouwer 2019):

```matlab
cfg = a1_learn();
cfg.id = 'my_tb';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'BR', 'kind', 'plm'), ...
    struct('name', 'TB', 'kind', 'rule', 'rule', '0')};          % TB forecasts the steady state
cfg.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
```

### 9.2 Shares over N types

In each share group with types k = 1..N (DESIGN_br_extensions 1.2):

    U_k,t = omega*U_k,t-1 - (1 - omega)*FE_k,t
    n_k,t = exp(chi*U_k,t) / sum_j exp(chi*U_j,t)

chi is `switching.intensity` (a number >= 0) and omega `switching.memory` (in [0, 1)), as in
5.6 and the same for every group: the baseline's normalized fitness (IJCB eqs. 14-15) over N
types. FE_k,t is the squared error of type k's forecast as it enters the model (9.3).

| Option | Values (default first) | Meaning |
|---|---|---|
| `shares.init` | `[]`, struct by type name | Initial shares, summing to 1 per group; `[]` = `shares.init_n2` for the default pair, equal shares otherwise. The initial fitness returns these shares through the logit |
| `shares.fixed` | `[]`, struct by type name | Mode `'fixed_shares'`; not together with `shares.fixed_n2` |

With two types, RE first, the engine calls the two-type `hetlearn.switching.discrete_choice`;
with more it calls `discrete_choice_n` and `init_fitness_n`. A published intensity beta of the
unnormalized Brock-Hommes form (U = omega*U - FE) corresponds to chi = beta/(1 - omega) here.
The units must match too: SW07's squared errors are in percent per quarter.

### 9.3 Forecast transforms: `expectations.transforms`

One struct per transform. A transform changes the expectation as it enters the model; the
type forecasts `<x>_exp1_<k>` stay as formed. Fitness, `FE_<k>` and `f_<k>` use the
transformed forecast; `fb_<k>` records the forecast before the transforms.

| `kind` | Expectation of a base forecast f | `value` (identity) |
|---|---|---|
| `'multiplier'` | m^h*f, h = 2 for a forecast made with t-1 information, else 1 (cognitive discounting) | m (1) |
| `'diagnostic'` | (1 + theta)*f - theta*f_ref, f_ref = the same forecast made one quarter earlier | theta (0) |
| `'myopia_anchoring'` | omega_f*f + b*x{-1} | `[omega_f b]` (`[1 0]`) |

| Field | Values | Meaning |
|---|---|---|
| `types` | `'all'` or type names; `[]` = `'all'` | `'all'` also covers the model-consistent expectations of variables outside the learning set |
| `scope` | `'learning'` (default), `'all'`, or a cellstr of variables and `'x@<label>'` entries | `'x@<label>'` acts in one equation only, given by its exact label in the model file (SW07: `'Phillips curve, price setting'`, `'Wage Phillips curve, wage setting'`, `'Consumption Euler equation'`, `'Arbitrage equation for the value of capital'`) |
| `exclude` | cellstr | Variables removed from the scope (the portfolio excludes the SW07 flex block) |

The values are model parameters, so one generated file covers every value of a transform.
Several transforms on one expectation apply in list order. Only one-step expectations are
transformed. Anchored RE agents take their coefficients from the variant's own RE limit, so
they know the transforms on the other expectations (D11).

A diagnostic transform must come first on its expectation, and it acts on RE types and on the
model-consistent expectations only: on a learned or rule type of a learning variable the run
stops. On the anchored RE(t-1) type its reference is the anchored E_{t-2} forecast
`<x>_DEg_RE`, with memory states such as `c_REt2` in the anchor economy (variant 10,
`test_anchor` A5). With period-t RE information that anchored reference is not built: set
`expectations.re_info = 'lagged'` or `re_variant = 'model_consistent'`.

Example, cognitive discounting on the learning set (variant 5b, Meggiorini and Milani 2021):

```matlab
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'multiplier', 'types', 'all', 'value', 0.94, ...
    'scope', 'learning', 'exclude', {FLEX});
```

### 9.4 Learning rules

Learning types update with `beliefs.update` (`'rls'` or `'fixed'`, 5.3) and the gain rules of
5.4 (`'constant'`, `'koz'`). Two portfolio variants change only these options:

| Option | Lines | Meaning |
|---|---|---|
| mean-only PLM | `beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true)` | The forecast is the learned mean: adaptive expectations by exponential smoothing (variant 24) |
| constant gain | `gain.rule = 'constant'; gain.value = 0.018` | In place of the baseline's KOZ gain (variant 26) |

SAC learning, Kalman-filter learning and the decreasing gain were removed on 2026-10-22 (9.10).

### 9.5 The intercept-only type and the generalised anchor

A `'re_mean'` type forecasts the RE type's forecast plus a learned mean of its own error,
abar: target `<x>_feRE = x - <x>_exp1_RE{-1}`, a mean-only PLM (`alpha_<x>_feRE__<k>`) updated
with `beliefs.update` and `gain`. This is intercept-only learning with RE slopes (variant 23).
The type takes the RE type's variant and information. With abar held at 0 it forecasts exactly
as the RE type (`test_anchor` A6).

`hetlearn.anchor_coefficients(m, targets, states, 'lag', j, 'horizon', h, ...)` gives the
coefficients of E_{t-j} z_{t+h} in any solved economy, with chain states (own lagged forecasts)
solved out; `hetlearn.re_anchor_coefficients` is a wrapper of it with unchanged outputs. The
anchored RE agents of an economy with diagnostic memory states (variant 10) take their
coefficients from it.

Example, intercept-only learners in place of the AR(1) learners (variant 23, Gáti 2023;
Carvalho, Eusepi, Moench and Preston 2023):

```matlab
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'IO', 'kind', 're_mean')};
```

### 9.6 The Kalman history: `history.mode = 'kalman'`

A time-varying Kalman filter of the model in force each quarter
(`hetlearn.engine.kalman_history`). In quarter t the ALM with the beliefs and shares from the end of t-1 is
solved, the filter predicts and updates with that quarter's data (quarters without data are
predictions only), and the agents learn from the filtered values in real time. Before
`beliefs.init.date` the ALM is the variant's RE limit.

| Option | Values | Meaning |
|---|---|---|
| `history.mode` | `'kalman'` | needs `history.learn = true` and `history.re_states = 'smoothed'` (the baseline sets `'filtered'`, which applies to the RE smoother only, so Kalman scenarios set `'smoothed'` again) |
| `history.kalman.init` | `'stochastic'`, `'smoothed'` | start from the asymptotic distribution of the first quarter's ALM (as IRIS `filter`), or at `beliefs.init.date` from the RE-smoothed state with P = 0 |

Agents' information: forecasts made in t with data to t-1 (the RE(t-1) type) are the
predictions x_{t|t-1}; forecasts with period-t data use x_{t|t}; realised values and PLM
regressors are the filtered values stored when each quarter was filtered, not revised later.
With N types (phase P6) every type's forecast comes from these data; the target of a
`'re_mean'` type is rebuilt from x_{t|t} and the RE forecast the agents used. The forecast stage
starts from the filtered state at the origin (D12).

Outputs: `res.kalman` (one-step predictions, errors, F_t, l_t, log likelihood, filtered and
predicted databanks, a and P at the origin), `kalman_errors.csv` in the results folder, and the
RMSE table by subsample:

```matlab
c = br19_target_believers();
c.history.mode = 'kalman';
c.history.re_states = 'smoothed';
c.forecast.origin = qq(2026, 2);
c.forecast.horizon = 4;
c.compare_with = {};
res = hetlearn.run(c, 'save', false);
T = hetlearn.engine.kalman_history('rmse', res);    % T.table: RMSE by observable and subsample
```

`res.kalman.ftypes_model_maxdiff` compares each type's forecast with the model's prediction of
`<x>_exp1_<k>`. It is rounding for a forecast that uses data of one date only: AR(1) and
mean-only PLMs, `'re_mean'` types, rules such as `x{-1}` or `0`, so every kept portfolio
variant. A forecast that also uses an earlier date (an AR(2) PLM, a rule in `x{-1} - x{-2}`)
differs, because the model's lagged states are the filter's revised values and the agents'
data the real-time ones; its RMSE and log likelihood are then not the variant's own.

### 9.7 The mechanisms, one example each

Each row is a scenario file in `scenarios/sw07/br_portfolio/`: `cfg = a1_learn();` plus the
lines shown (abbreviated: `T(...)` = `struct(...)`, `FLEX = {'invef', 'pkf', 'rkf', 'cf',
'labf'}`). "Proposed" marks a value with no published counterpart, chosen in the design and
approved with D8 (DESIGN_br_extensions 7). DESIGN_br_extensions 2 gives the formula, scope,
information timing and units of each. The last column is the audit's score (4-5 = keep) and
the caveat to state with the results (`docs/BR_audit.txt`, section 3).

| Variant | Mechanism (source) | Lines on `a1_learn` | Values and their source | Audit |
|---|---|---|---|---|
| `br05b_cd_learn` | Cognitive discounting on the learning set (Gabaix 2020) | `T('kind','multiplier','types','all','value',0.94,'scope','learning','exclude',{FLEX})` | m = 0.94, Meggiorini and Milani (2021), US 1960-2007 | 4; m comes from their model, not from SW07 |
| `br07_myopia_anchoring` | Myopia and anchoring (Angeletos and Huo 2021) | `T('kind','myopia_anchoring','types','all','value',[0.52 0.434],'scope',{{'pinf@Phillips curve, price setting'}})` | (omega_f, omega_b) = (0.52, 0.43), AH Table 1; b = 0.43/0.99 | 4; SW07 keeps its own indexation and habit, so the backward weight comes on top |
| `br10_diagnostic` | Diagnostic expectations, one-period memory (L'Huillier, Singh and Yoo 2024) | `T('kind','diagnostic','types',{{'RE'}},'value',0.44,'scope','all','exclude',{FLEX})` | theta = 0.44, LSY in SW07 with Rotemberg pricing | 4; no LSY current-variable terms, learners not diagnostic |
| `br19_target_believers` | Target believers (Hommes and Lustenhouwer 2019) | 9.1.1 | shares 1/3 each, proposed; switching as the baseline | 4; {RE, BR, TB} nests the baseline, HL use {TB, naive} |
| `br23_intercept_only` | Intercept-only learning (Gáti 2023; Carvalho, Eusepi, Moench and Preston 2023) | `types = {T('name','RE','kind','re'), T('name','IO','kind','re_mean')}` | baseline KOZ gain from 0.05 | 4; Gáti's anchoring function left out, so the paths stay close to RE |
| `br24_mean_only` | Mean-only learning, adaptive expectations | `beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true)` | baseline KOZ gain | 5 |
| `br26_experience` | Experience-based learning, aggregate (Malmendier and Nagel 2016; Nagel and Xu 2022) | `gain.rule = 'constant'; gain.value = 0.018` | 0.018 per quarter (Nagel and Xu; Malmendier and Nagel's 0.0175) | 4; no cohorts: a constant gain of 0.018, MN-calibrated |

The two references are `a1_re` (RE(t-1), the RE limit of the baseline) and `a1_learn`. All
seven variants learn on `{pinf}` as the baseline does, so `a1_re` is the RE reference of each.

### 9.8 Which stages take N types and transforms

| Stage | Status (2026-10-22) |
|---|---|
| History, `history.mode = 're_smoother'` | supported |
| History, `history.mode = 'kalman'` | supported (phase P6); the seven portfolio variants run through it |
| History, `history.mode = 'inversion'` | not supported: `hetlearn:options:unsupported` |
| Forecast and scenario stage | supported |
| Density forecasts (`density.enabled`) | supported on the general path (a draw re-runs the forecast stage); the fast path stays two-type. Summarised: `n_model_<k>_<x>` per type and the beliefs of each learning type (`alpha_pinf__BR`, ...) |
| `hetlearn.evaluate` | supported; a variant with N types or transforms gets the RE filter of its own RE limit |
| `hetlearn.decompose` | supported; a result of `history.mode = 'kalman'` stops with `hetlearn:options:unsupported` |
| Ramsey policy (`policy.mode = 'ramsey'`) | not supported: `hetlearn:options:unsupported` |

"N types" here means any run on the N-type path: `expectations.types`,
`expectations.transforms`, `shares.init` or `shares.fixed`. The refusals name the options that
put the run there.

### 9.9 Outputs of N-type runs

| Output | Content |
|---|---|
| `res.learning.<x>` | per type k: `n_<k>` (discrete-choice share at the end of t; 0 outside the population), `n_model_<k>` (share in the model in t), `U_<k>` (fitness), `FE_<k>` (squared error), `f_<k>` (forecast as it enters the aggregate), `fb_<k>` (before the transforms, only with transforms); `.types` |
| `res.learning.<target>__<k>` | belief series of each learning type (`alpha_pinf__BR`, `alpha_pinf_feRE__IO`, `R_...`, `gain`, the gain rule's series) |
| `res.paths.<x>_exp1_<k>` | the type's forecasts over the record dates (as `<x>_exp1_BR` in two-type runs) |
| `res.meta.types`, `res.meta.model_values` | the resolved types; the transform values (with transforms only) |
| events | the types of 6.2; the N-type path adds none |

`learning.csv` carries the same series in long form.

### 9.10 Removed on 2026-10-22

The user kept the seven variants that the BR audit scored 4 or 5 (`docs/BR_audit.txt`,
sections 0, 2 and 3) and dropped the other 14, including the four the audit marked "fix"
(score 3). The options that only the dropped variants used went with them. Setting one stops
the run with `hetlearn:options:removed`, naming the removal. A merged option tree saved before
the cut (`res.cfg`) still loads: removed fields that hold their old off values are dropped. The
old scenario files, results, code and tests are in `archive/2026-10-22_br_cleanup/`.

| Variant | Mechanism | Options removed with it | Audit reason (score) |
|---|---|---|---|
| 1a, 1b | Level-k on a learned level 0 (Evans, Gibbs and McGough 2025; Beaudry, Carter and Lahiri 2023) | type kind `'level'` (fields `base`, `k`), `hetlearn.engine.anchor_update`, event `projection_level`, error `levelNoSolution` | the learned level-0 seed is explosive at the 2022Q2 origin: an inflation cycle of about 25 pp and five facility events (2) |
| 4 | Shallow reasoning (Angeletos and Sastry 2021) | multiplier profile `'flat'` | monetary policy barely moves inflation, dLL -1960; the mapping of GHL's values to SW07 equations is ours (2) |
| 5a | Cognitive discounting on every expectation (Gabaix 2020) | none: 5b and 10 use its machinery | m = 0.62 comes from a re-estimated SW07 and sits on the published RE mode, dLL -4053 (3) |
| 6 | As-if hyperbolic discounting (Gabaix and Laibson) | multiplier profile `'hyperbolic'`, and with it the field `profile` | alpha unsourced; with h = 1 and 2 only it cannot be told apart from 5a (2) |
| 17 | Four heuristics (Anufriev and Hommes 2012) | rule terms `self{-k}` and `mean`, the per-type `gain`, `gain.rule = 'decreasing'`, `switching.inertia`, `switching.fitness = 'unnormalized'` | the intensity is in lab-price units, so the shares stay in 0.16-0.33 and the switching does nothing (3) |
| 18 | Targeters and extrapolators, optimists and pessimists (De Grauwe 2011) | the per-type `variables`, `variant` and `info`, a second `'re'` type, constant wedges | explosive IRF cycles; parameters picked by an outcome screen (1) |
| 20 | SAC learning (Hommes and Sorger 1998; HMOZ 2023) | `beliefs.update = 'sac'`, event `sac_bound` | gain column unconfirmed, HMOZ's structural estimates not used, dLL -1852 (3) |
| 25a, 25b | Kalman-filter learning (Slobodyan and Wouters 2012a) | `beliefs.update = 'kf'`, `beliefs.kf`, the per-type `plm` and `update` | inflation keeps falling at the end, 7-8 facility events, explosive IRFs (1) |
| 27 | Bayesian model averaging (Evans, Honkapohja, Sargent and Williams 2013) | `switching.intensity = 'model:bma'`, `switching.memory = 1` | the learners' share sits at 1.000 and inflation rises to 22.7% (1) |
| 29 | Survey belief wedge (Bhandari, Borovička and Ho 2025) | transform kind `'wedge'`: field `factor`, its shock and `xi_` state | no survey data to identify the wedge; the learners' share goes above 0.98 (2) |
| 31 | Confidence shocks (Angeletos, Collard and Dellas 2018) | wedge values `'model:acd51'` and `'model:projection'` | sigma and loadings calibrated by us, not ACD's (3) |
| 33 | Nominal-growth belief function (Farmer and Nicolò 2018) | rule terms `dn` and `re1(...)` | the path is RE's (FN share 0 in 2021Q2-2022Q4) and the inflation RMSE the worst, 1.39x (2) |
| none | | `switching.costs` and the type field `cost`, transform kind `'partial_adjustment'`, `'model:sd_ygap_half'` | no portfolio scenario used them |

To bring a dropped variant back, `docs/BR_audit.txt` section 4 lists the work it would need.
