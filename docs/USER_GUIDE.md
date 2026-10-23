# HetLearn user guide

HetLearn is a MATLAB toolbox on IRIS 20230622 (MATLAB R2025a) for forecasts and scenarios with
two kinds of agents: rational-expectations (RE) agents and adaptive learners, who forecast with a
perceived law of motion (PLM) updated by recursive least squares (RLS) and whose population shares
switch on past forecast errors, after Özden (2025, International Journal of Central Banking (IJCB)
21(1)). This guide covers the project's model packages and scenario tree, where each assumption
lives, the checks every option is subject to, the outputs and the project runner.

This version describes the toolbox as of 23 October 2026.

The website, <https://tolgaozden.net/iris_toolbox_learning/> (source in `docs_site/`), is the
introduction: installation, quick start, the Application 1 tutorial, the applications, one page
per option group, the option table and the function list. This guide is the reference behind it
and does not repeat those pages. The equations, timing conventions and algorithms are in the
technical appendix, `docs/technical_appendix/`; the design specification (generator, engine
stages, file contracts, tests and their tolerances) is `docs/DESIGN.md`. Section numbers such as
"DESIGN 19" refer to it. All paths are relative to the project root, the folder that holds
`setup_paths.m` (`<project root>` in commands).

---

## 1. What is what

### 1.1 Project map

The README gives the short layout; this table adds who writes each file.

| Path | What it is | Edited |
|---|---|---|
| `setup_paths.m` | Starts IRIS (the folder in the environment variable `HETLEARN_IRIS_DIR`, else `IRIS-Toolbox-Release-20230622` next to the project root), then adds `toolbox/`, the IRIS patch, `config/` and `scenarios/` with every subfolder to the path | Not edited; set `HETLEARN_IRIS_DIR` if IRIS is elsewhere |
| `config/master_options.m` | Project-wide option values: the project baseline (the `o.*` lines; 1.4) and commented knobs below them | By hand |
| `scenarios/sw07/<folder>/<id>.m` | The scenario files (61) of the Smets and Wouters (2007; SW07) package, one function per file. Each calls its parent and sets what differs | By hand |
| `scenarios/ijcb3/app1_peak/`, `scenarios/as07/app1_peak/` | Application 1 on the two template packages: `i1_re`, `i1_learn`, `a1as_re`, `a1as_learn` (3.6) | By hand |
| `scenarios/sw07/INDEX.csv` | One row per SW07 scenario file: folder, id, parent, options it sets, compare_with, has_results, title | Written by `python scenarios/build_index.py` |
| `models/sw07/`, `models/ijcb3/`, `models/as07/` | Model packages: model file, parameters, data, `model_spec.m`, validation (1.2); ijcb3 and as07 are templates | By hand, when the model, its parameters or its data change |
| `run_applications.m` | Runner for the SW07 applications, model variants and forecast evaluation: run groups, run log, evaluation parts and merge | By hand, to change a group, the decompositions or the evaluation settings |
| `run_br_app1.m`, `run_br_portfolio.m` | Runners of the seven further expectation rules (section 7): Application 1, then impulse responses and the Kalman one-step errors; both write `results/br_portfolio/` | By hand |
| `results/<id>/` | Output of one scenario run (5.1) | Written by each run (overwritten) |
| `results/run_log.csv` | One row per run, decomposition and evaluation part | Appended by `run_applications` |
| `results/eval_sw07_v3/` | The project's forecast evaluation: parts and merged tables (5.3) | Written by `run_applications('eval')` |
| `results/summary_v3/build_summary_v3.m` | Summary tables and checks of the SW07 runs | By hand |
| `reports/build_estimation_report.py` | Builder of the HTML report of the estimation module (Python 3 with pandas); the HTML it writes is not versioned | By hand |
| `estimation/` | A separate Bayesian estimation module (5.5) | By hand |
| `toolbox/+hetlearn/` | The toolbox | Not edited for a scenario or model change |
| `toolbox/iris_patches/+model/Insertable.m` | Shadow copy of one IRIS file so that IRIS 20230622 optimal policy runs on R2025a; the IRIS installation is untouched | Not edited |
| `models/<name>/generated/` | Extended model files and RE filter caches (6.2) | Written by the toolbox; delete a file to force a rebuild |
| `tests/` | `run_tests.m` (24 suites), the toy New Keynesian (NK) package `tests/toy_nk/`, test scenarios `tests/scenarios/tsw07_*.m` and the test master options `tests/scenarios/master_options.m` (6.3), references `tests/reference/`, the test models of `test_re_info` in `tests/models/` (a hand-written SW07 model in which RE agents use t-1 information, the RE(t-1) model; a Dynare cross-check, a closed-form Phillips curve) | Only when the toolbox changes |
| `tests/output/` | Test runs | Disposable |
| `docs/` | This guide, `DESIGN.md`, `technical_appendix/` | By hand |
| `docs_site/`, `mkdocs.yml`, `.github/workflows/docs.yml` | The website: its MkDocs sources, the configuration, and the workflow that builds and publishes it on every push to `main` that touches the site | By hand |
| `LICENSE` | MIT license | |

Model packages, scenario files and the master options are written by hand; the toolbox writes
`results/` and `generated/`. No scenario or model change needs a toolbox edit.

### 1.2 The three model packages

| Package | Model | Parameters | Observables, filter range | Forward-looking variables | `spec.policy` |
|---|---|---|---|---|---|
| `models/sw07/` | Smets and Wouters (2007) | Two sets: the published SW07 posterior mode for 1966Q1-2004Q4 (`sw07_params_original.m`, selected by the project baseline through `model_params`), and swX1, a Dynare re-estimate on 1966Q1-2026Q2 (`sw07_params.m` = `spec.params`, the toolbox default) | `dy`, `dc`, `dinve`, `dw`, `labobs`, `pinfobs`, `robs`; 1965Q1-2026Q2; every observable NaN in the COVID-19 quarters 2020Q1-2020Q3 | 12: `invef`, `rkf`, `pkf`, `cf`, `labf`, `inve`, `pinf`, `rk`, `pk`, `c`, `lab`, `w` | yes: Taylor rule by label; loss targets `pinf`, `ygap`, `r`, `dr` |
| `models/ijcb3/` | Three-equation NK model of IJCB (sec. 2.1) | IJCB Table 1, posterior means of the heterogeneous-expectations model (`ijcb3_params.m`) | `yobs`, `pinfobs`, `robs`; 1960Q1-2026Q2; `robs` NaN in the 36 quarters at the effective lower bound (ELB) | `y`, `pinf` | no |
| `models/as07/` | An and Schorfheide (2007) | Herbst and Schorfheide (2016) published posterior means; measurement errors fixed as in the book's code (`as07_params.m`) | `dy`, `pinfobs`, `robs`; 1965Q1-2026Q2; `robs` NaN in the 36 ELB quarters | `y`, `pinf` | no |

Every scenario in this guide runs on `models/sw07/`; ijcb3 and as07 are kept as templates for new
packages (3.6).

Each package has a `README.md` (model, parameters, units, open issues), `data/README.md` and
`data/build_database.m` (how the database is built and refreshed), and `validation/` (checks
against Dynare or the authors' code). The toolbox does not estimate parameters: scenarios use the
parameter sets in the table. swX1 was estimated with Dynare 4.6.1 outside this repository;
`models/sw07/estimation/` holds copies of that run (`swX1.mod`, the mode, the log, a comparison
with the published mode) for provenance, and nothing re-runs them. The repository also holds a
separate Bayesian estimation module, `estimation/` (5.5). No scenario in this guide depends on it.

SW07 data note. `models/sw07/data/build_database.m` sets all seven observables to NaN in
2020Q1-2020Q3 (`covid_nan_quarters`; `[]` keeps those quarters). The RE filter treats them as
missing and its fit check skips them. Downstream, the learners keep learning on the smoothed
values there (on the filtered values under `history.re_states = 'filtered'`, 4.7),
`hetlearn.evaluate` drops the targets in those quarters, and the inversion history
(`history.mode = 'inversion'`) has nothing to exogenize there, so it differs from the RE smoother
from 2020 on. swX1 was estimated with those quarters in the data.

### 1.3 How a run moves through the code

`hetlearn.run(cfg)` does, in order:

1. `hetlearn.load_options`: merges `hetlearn.defaults()` < `config/master_options.m` < `cfg`,
   checks every name and value (section 4).
2. `hetlearn.load_spec(cfg.model)`: reads `models/<name>/model_spec.m`.
3. `hetlearn.load_model`: writes (if needed) the extended model
   `generated/<name>_ext_<tag>.model` with `hetlearn.extend_model` (collapse test included),
   computes the anchored-RE coefficients (`hetlearn.re_anchor_coefficients`), loads and solves.
4. `hetlearn.re_filter`: RE Kalman filter and smoother (smoothed and filtered databanks),
   cached in `generated/refilter_*.mat`.
5. `hetlearn.engine.core`: initial state (`state_init`), history stage (`history`: learning on
   the RE-smoothed history, the inversion or the Kalman history), shocks (`build_shocks`),
   conditions (`conditions_prepare`), forecast quarter by quarter (`forecast`: `step`, then
   `update_learning`, which calls the projection facility `facility`), result (`assemble`).
6. `hetlearn.density.run`, when `density.enabled`.
7. `hetlearn.engine.save_results`: writes `results/<id>/`.

| Toolbox folder | Contents |
|---|---|
| `toolbox/+hetlearn/` | Public functions (listed on the website's Functions and outputs page) |
| `+engine/` | `core`, `history` (with `history_db`, the databank of the history loop), `forecast`, `step`, `update_learning`, `facility`, `shares_for_mode`, `state_init`, `build_shocks`, `conditions_prepare`, `conditions_key`, `backward_simulate`, `solve_model`, `record`, `assemble`, `save_results`, `load_result`, `kalman_history` |
| `+plm/` | PLM system (`build_system`), PLM blocks for the facility (`blocks`), companion matrix, the learners' forecast expressions and values, anchored-RE parameter names, rule terms |
| `+rls/update.m` | One RLS step (IJCB eq. 13) |
| `+gain/` | Gain rules `constant` and `koz` (the endogenous gain, 4.4); `gain.rule` names the function |
| `+switching/` | `discrete_choice` (IJCB eqs. 14-15), `init_fitness` and their N-type versions; `switching.rule` names the function |
| `+init/` | Initial beliefs: `re_moments`, `training_ols`, `user` (`beliefs.init.method`) |
| `+policy/` | Ramsey setup, policy loss, `loss.csv` |
| `+density/` | Draws, the RE fast path, quantiles, density outputs |
| `+util/` | Dates, MD5 hashes, the writer of comma-separated values (CSV) files |

### 1.4 The project baseline

`config/master_options.m` sets it, so every SW07 scenario inherits it. `hetlearn.defaults()` holds
the toolbox defaults, which the tests use (6.3).

| Option | Project baseline | Toolbox default |
|---|---|---|
| `model_params` | `'sw07_params_original'`: published SW07 mode, 1966Q1-2004Q4 | `''` = `spec.params` (`sw07_params`, swX1, 1966Q1-2026Q2) |
| `gain.rule`, `gain.value` | `'koz'`, the endogenous gain (4.4), start gain 0.05 (the other `gain.koz.*` at their defaults) | `'constant'`, 0.0585 |
| `switching.intensity`, `switching.memory` | 2, 0.8 | 0.51, 0.6 |
| `beliefs.plm.default`, `beliefs.info`, `shares.init_n2` | `'ar1'`, `'lagged'`, 0.5 | the same |
| `expectations.re_info` | `'lagged'`: RE agents use E_{t-1} x_{t+1} for the learning set | `'current'` |
| `expectations.re_variant` | `'anchored'` | the same |
| `history.re_states` | `'filtered'`: the RE forecasts, the learners' data and the realized values in the fitness errors come from the one-sided filter | `'smoothed'` |
| `projection.facility` | `'alm'`: an actual law of motion (ALM) without a stable solution reverts the beliefs, then keeps last quarter's model shares (4.6) | `'plm_alm'` |

Where the project baseline does not apply:

- **Application 4** (`a4_rule_re.m` and `a4_rule_learn.m`, the `cfg.expectations.re_info` line,
  inherited by the other twelve app-4 files): `'current'`, because Ramsey policy is not supported
  with `'lagged'` (`hetlearn:options:unsupported`). This is the only deviation among the
  applications.
- **The inversion and the Kalman history** (`a6_inv_learn.m`, `a6_kalman_re.m`,
  `a6_kalman_learn.m`, the `cfg.history.re_states` line): `'smoothed'`, because `'filtered'` is
  an error with `history.mode = 'inversion'` or `'kalman'`; those histories are one-sided
  already.
- **Variants that change one baseline setting on purpose:** `v3_all_plm_alm` (facility
  `'plm_alm'`), `v4_const` (a constant gain of 0.05) and `br26_experience` (a constant gain of
  0.018).
- **The templates** (`i1_re.m`, `a1as_re.m`) pin their own settings and set `model_params = ''`,
  so the project baseline does not reach them.
- **The tests** read `tests/scenarios/master_options.m` (the toolbox defaults), not this file.

Under `expectations.re_info = 'lagged'` the RE benchmark of an application is the RE model with
t-1 information for inflation, the RE(t-1) model, not `models/sw07/sw07.model` (4.2).

To run a scenario on the toolbox defaults, set in it `model_params = ''`,
`gain.rule = 'constant'`, `gain.value = 0.0585`, `switching.intensity = 0.51`,
`switching.memory = 0.6`, `expectations.re_info = 'current'`, `history.re_states = 'smoothed'`
and `projection.facility = 'plm_alm'`.

**`model_params`** names a parameter function in the model package folder, used in place of
`spec.params` for that run: by `hetlearn.load_model`, and through it by the generator checks, the
anchored-RE coefficients, the policy discount and the RE filter, whose cache key hashes the
parameter values, so each set has its own caches. A name that is not a file of the package stops
the run (`hetlearn:load_model:params`). Example: `cfg.model_params = '';` runs a scenario on swX1.

---

## 2. Quick start

Installation, a first run and the Application 1 tutorial are on the website (Installation, Quick
start, Application 1). From MATLAB, in short:

```matlab
cd('<project root>')
setup_paths                                   % once per MATLAB session
run_applications('app1')                      % a1_re, a1_learn; two rows in results/run_log.csv
T = hetlearn.compare({'a1_re', 'a1_learn'}, {'pinfobs', 'robs'})   % levels and differences
```

`res = hetlearn.run(a1_learn());` runs one scenario without the runner (same results folder, no
row in the run log). A fresh clone has no `results/`; `run_applications('all')` runs every SW07
group (app1-app6, var1-var4, eval), about three hours on one laptop, most of it the evaluation
(6.1 runs it faster in parallel sessions).

---

## 3. Change an assumption

### 3.1 How a scenario gets its options

- **Precedence:** `hetlearn.defaults()` < `config/master_options.m` < the scenario's `cfg`,
  merged field by field; the checks are in section 4.
- **Inheritance is a function call.** A scenario file is a function that returns a partial option
  tree. It starts with its parent, `cfg = a1_learn();`, and sets only what differs. Some files
  copy one block from a sibling, e.g. `a3_loose_learn.m`: `c = a3_loose_re(); ...
  cfg.conditions = c.conditions;`.
- **Each result records its options:** `res.cfg` in `results/<id>/results.mat`.
- **Saved results never update themselves.** After an edit, rerun the scenario and everything
  below it in the tree (3.2); `run_applications` reruns whole groups in dependency order. A
  scenario named in `compare_with`, or used as a `'delta'` reference, is run first only when it
  has no results at all; after an edit it needs an explicit rerun.

### 3.2 The scenario tree

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
            a6_kalman_re         history.mode 'kalman': RE(t-1) benchmark of the Kalman history
    sw07_learn                   mode 'switching' (learning on inflation)
        e02_learn
            e04_learn_all_learners
        a1_learn                 learning parent of the applications, variants and further rules
            a2_learn
            a3_loose_learn       (block from a3_loose_re: conditions)
                a3_tight_learn
            a4_rule_learn
                a4_ramsey_<w>_learn   (block from a4_ramsey_<w>_re: policy), w = balanced, hawk, dove, smooth
            a5_markup_learn      (block from a5_markup_re: density)
            a5_demand_learn      (block from a5_demand_re: density)
            a6_smooth_learn
                a6_inv_learn
                a6_kalman_learn  history.mode 'kalman'
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
            v3_all               learning on all 12 variables, facility 'alm' as in the project baseline
                v3_all_plm_alm, v3_all_alm, e10_allvars
            v4_const             constant gain 0.05 (the project baseline gain is endogenous)
                v4_const_full
            br05b_cd_learn, br07_myopia_anchoring, br10_diagnostic, br19_target_believers,
            br23_intercept_only, br24_mean_only, br26_experience      further rules (section 7)
i1_re                            ijcb3 template (starts from struct(), not from sw07_re)
    i1_learn
a1as_re                          as07 template
    a1as_learn
```

An edit to `a1_learn.m` therefore reaches every learning application and variant, the seven
further rules, and the evaluation variants e03 and e05-e10 through their parents. The evaluation
still overrides origin, horizon, shocks, conditions, density and comparisons (5.3).

The groups of `run_applications` (function `group_table`) are app1-app6, var1-var4 and eval. The
app6 group does not run the Kalman pair: `hetlearn.run(a6_kalman_re())` and
`hetlearn.run(a6_kalman_learn())` run it. No group holds the `br*` files; `run_br_app1('run')`
runs them with `a1_re` and `a1_learn` (section 7).

### 3.3 Where each assumption lives

Files are in `scenarios/sw07/` unless a path is given. Each entry names the line or block to edit.

| Assumption | Where | Reaches | Rerun |
|---|---|---|---|
| The project baseline: parameter set, gain rule and start gain, intensity of choice, memory, initial share, PLM, information sets, RE states, facility | `config/master_options.m`, the `o.*` lines (1.4) | every SW07 scenario; not the templates | all groups |
| Forecast origin, horizon | `base/sw07_re.m`, the block under "forecast origin and horizon": `hetlearn.find_peak` over 2020Q1-2024Q4, the assert on 2022Q2, `cfg.forecast.horizon = 16` | every SW07 file except the `a6_*` files and `v4_const_full` (their own `cfg.forecast.*` lines) and the evaluation (set by the runner) | app1-app5, var1-var4 |
| Expectations mode | the `cfg.expectations.mode` line of `base/sw07_re.m` (`'rational'`), `base/sw07_learn.m` (`'switching'`), `eval/e04_learn_all_learners.m` (`'learning'`) | children | per file |
| Variables that learn | the `cfg.expectations.variables` line of `base/sw07_re.m` (`{'pinf'}`) and `var3_allvars/v3_all.m` (`'all'`) | children | var3 |
| RE variant | toolbox default `'anchored'`; `var1_re_variant/v1_mc_learn.m` and `app4_ramsey/a4_ramsey_<w>_re_mc.m` set `'model_consistent'` | children | var1, app4 |
| Projection facility | project baseline `'alm'`; `var3_allvars/v3_all_plm_alm.m` sets `'plm_alm'`, `v3_all_alm.m` `'alm'` | | var3 |
| RE information set, RE states of the history | project baseline `'lagged'`, `'filtered'`; `app4_ramsey/a4_rule_re.m` and `a4_rule_learn.m` set `re_info = 'current'`; `app6_history/a6_inv_learn.m` and the `a6_kalman_*` files set `re_states = 'smoothed'` | children | app4, app6 |
| PLM | the `cfg.beliefs.plm.*` lines of `var2_plm/v2_ar2.m`, `v2_ar1nc.m`, `v2_reg.m`, `v2_var3.m`, `v2_var12.m` | the matching `e05`-`e09` | var2, eval |
| Information timing of the learners | `beliefs.info = 'lagged'` (project baseline and toolbox default) | | |
| Gain | project baseline: the endogenous gain from 0.05; `var4_gain/v4_const.m` (`gain.rule = 'constant'`, 0.05) and `br_portfolio/br26_experience.m` (0.018) set a constant gain | `v4_const_full` | var4 |
| Policy deviation: size, dates | the `cfg.conditions` struct of `app3_policy/a3_loose_re.m`; sign: `cfg.conditions.values = 0.25` in `a3_tight_re.m` and `a3_tight_learn.m` | all four app3 files | app3 |
| Ramsey loss weights | the `cfg.policy.loss` line of `app4_ramsey/a4_ramsey_balanced_re.m` and of the hawk, dove and smooth files; the summary builder repeats them (`W` in `build_summary_v3.m`) | the matching `_re_mc` and `_learn` files | app4 |
| Loss horizon (80 quarters) | the `cfg.policy.loss_horizon` line of `app4_ramsey/a4_rule_re.m` and `a4_rule_learn.m` | every app4 file | app4 |
| Density: shocks, draws, sigma, seed | the `cfg.density.*` lines of `app5_density/a5_markup_re.m`; `a5_demand_re.m` changes `cfg.density.shocks` | the matching `_learn` file (copies the block) | app5 |
| Shock replay | `cfg.shocks.source = 'smoothed'` in `app2_replay/a2_re.m` and `a2_learn.m` | | app2 |
| History backed out with the learning model | `cfg.history.mode = 'inversion'` in `app6_history/a6_inv_learn.m`; `'kalman'` in the `a6_kalman_*` files | | app6; the Kalman pair directly |
| Decomposition: groups, scenarios, range, variables | `run_applications.m`, function `decompose_app6` (`groups`, `ids`, `rng` and the variables of the `hetlearn.decompose` call) | | `run_applications('decompose')` |
| Evaluation: variants, benchmark, origins, horizon, parts, subsamples | `run_applications.m`, function `eval_settings` (`E.variants`, `E.benchmark`, `E.origins`, `E.horizon`, `E.nparts`, `E.subsamples`) | | eval |
| Run groups | `run_applications.m`, function `group_table` | | |
| Further expectation rules | `br_portfolio/br*.m` (7.7) | | `run_br_app1('run')` |
| Model parameters, data | `models/<name>/<name>_params.m` (`spec.params`), or another parameter file of the package named by `model_params` (project baseline: `sw07_params_original.m`); `models/<name>/data/build_database.m` | every scenario of that model | all; the RE filter cache key includes both, so the next run filters again |

Every SW07 file calls `sw07_re`, so an assert that fails there stops every SW07 run, the
evaluation included. A fixed origin replaces the `find_peak` block by
`cfg.forecast.origin = qq(2023, 4);`. Conditions must lie inside the horizon (app 3 uses
2022Q3-2023Q2).

### 3.4 Two worked examples

The website's option pages show each option with working code. Two patterns are not there.

A sweep over the intensity of choice without new files:

```matlab
for chi = [0.25 0.51 1]
    cfg = a1_learn();
    cfg.id = sprintf('sweep_chi%03d', round(100*chi));   % results/sweep_chi025/ ...
    cfg.switching.intensity = chi;
    hetlearn.run(cfg);
end
T = hetlearn.compare({'a1_re', 'sweep_chi025', 'sweep_chi100'}, {'pinfobs'});
```

A separate forecast evaluation by hand, outside the runner:

```matlab
E = hetlearn.evaluate('my_eval', {'e01_re', 'e02_learn'}, [qq(2010,1), qq(2024,2)], ...
    struct('horizon', 8, 'subsamples', struct('post2008', [qq(2008,1), qq(2019,4)])));
```

It writes `results/eval_my_eval/`. `hetlearn.evaluate_tables` rebuilds the tables from a saved
`errors_long.csv` without rerunning any forecast.

### 3.5 Add a scenario

1. **Write the file.** Copy the closest file, rename the function and the file, set `cfg.id` to
   the file name and change what differs. Ids are function names: `compare_with`, `'delta'`
   references and `run_applications` find scenarios by name, so names must be unique on the
   path. Any folder under `scenarios/` is on the path (`setup_paths` adds every subfolder; run
   it again after a new folder is created in an open session).
2. **Run it:** `run_applications('my_id')` (logged under its group, or under `single` while it
   is in none) or `res = hetlearn.run(my_id());`.
3. **Put it in a group:** function `group_table` in `run_applications.m`. Add the id to a group's
   list after its parents and comparison targets, or add a row such as
   `'app7', {'a7_re', 'a7_learn'}`. A new row is part of `'all'` automatically.
4. **Index:** `python scenarios/build_index.py` rewrites `scenarios/sw07/INDEX.csv` (it covers
   `scenarios/sw07/` only).

### 3.6 Add a model package

The website's page on a new model (`docs_site/adding-a-model.md`) takes a model file to a first
run: the package contract `model_spec.m`, the generated toggles, the collapse test, the first
scenarios and the limits. The two template packages show what SW07 does not:

- **Missing data:** ijcb3's `robs` is NaN in the ELB quarters; the filter skips the NaN and
  infers a shadow rate from the rule (`models/ijcb3/README.md`, "ELB treatment").
- **Measurement errors:** as07 declares them as IRIS measurement shocks (`std_me_dy`,
  `std_me_pinfobs`, `std_me_robs` in `as07_params.m`; 0 removes them).
- **Units:** as07's model `pinf` is in percent per quarter while its observables `pinfobs` and
  `robs` are annualized, hence `report.scale` 1 for them. chi = 0.51 applies because the
  learners forecast the model variable in percent per quarter.
- **No `spec.policy`:** `policy.mode = 'ramsey'` is an error for these packages and no loss is
  computed.
- **Validation:** `models/ijcb3/validation/check_model.m` and `models/as07/validation/check_model.m`
  check each package against the original model or the authors' code (results in
  `validation/RESULTS.txt`).

ijcb3 is the smallest package (as07 was built from it), so a new package starts as a copy of
`models/ijcb3/`. New scenarios start from `cfg = struct();` as `i1_re.m` does, not from
`sw07_re`, which loads SW07 and asserts the SW07 peak. A new package needs its own report
section.

---

## 4. Option checks and errors

The option table, with every option's default, values, project baseline and website page, is
the website's Options reference (`docs_site/reference/options.md`);
`scenarios/sw07/base/sw07_re.m` lists each option as a commented line at its default. This
section gives what the table leaves out: the checks `hetlearn.load_options` and the loader apply,
the meanings that need more than a table cell, and every option error. Function signatures are on
the website's Functions and outputs page and in `help hetlearn.<name>`.

### 4.1 Identification and forecast

- `id`: the results folder name; use the scenario function name.
- `model`: a folder under `models/`, or a folder path.
- `model_params`: see 1.4. A name that is not a file of the package stops the run
  (`hetlearn:load_model:params`).
- `forecast.origin` is required: the last quarter of data used; the forecast starts the quarter
  after. `forecast.horizon` is a positive integer.
- `compare_with`: writes `compare_<id>.csv` (this run minus that one, observables, horizon); a
  target without results is run first.
- `report.variables`: reserved; converted to a cellstr and read by no code.

### 4.2 Expectations

- `expectations.mode`: `'rational'` sets the learners' share to 0, `'learning'` to 1,
  `'fixed_shares'` to `shares.fixed_n2`, and `'switching'` lets it switch on forecast
  performance. In mode `'rational'` the learning variables keep their blocks with RE share 1:
  the run is exactly RE, and beliefs and shares are tracked as diagnostics.
- `expectations.variables`: the forward-looking variables whose expectations mix RE agents and
  learners; the rest stay RE. `'all'` is every forward-looking variable (SW07: 12). A name that
  is not forward-looking stops the load (`hetlearn:load_model:notForward`);
  `[m, info] = hetlearn.load_model(spec, opts)` lists the candidates in
  `info.meta.forward_vars`. With anchored RE and every forward-looking variable learning, the
  model has no leads; 4.6 says how the facility treats that case.
- `expectations.re_variant`: `'anchored'` (IJCB sec. 2.3.1): RE agents use the pure-RE model's
  forecast at the current state, which `hetlearn.re_anchor_coefficients` computes.
  `'model_consistent'`: RE agents forecast the heterogeneous economy, which is re-solved every
  quarter with the current beliefs and shares. Under the Taylor rule the two give the same RE
  path; under Ramsey policy they do not (6.4).
- `expectations.re_info`: `'lagged'` replaces E_t x_{t+1} by E_{t-1} x_{t+1} for the learning
  variables; other variables keep E_t. With `beliefs.info = 'lagged'` both types then forecast
  x_{t+1} with data up to t-1, and both fitness errors are two-step errors. Everything RE in the
  scenario follows: the RE benchmark (mode `'rational'`) is the RE(t-1) model, the anchored RE
  agents forecast with it, and the RE history (filter, smoother, RE forecasts, RE-moment initial
  beliefs) uses it. A lagged learning run therefore compares with a lagged RE run. The loader
  uses its own generated file, `<name>_ext_<tag>_relag.model` (DESIGN 19). Checks: learning
  variables need a maximum lead of 1 (`hetlearn:load_model:reInfo`); the learning set must not
  be empty, so `hetlearn.load_options(struct())` under the project master is an error (every
  SW07 scenario gets `{'pinf'}` from `sw07_re.m`); Ramsey policy is not supported
  (`hetlearn:options:unsupported`).
- `beliefs.info`: `'lagged'`: learners see data up to t-1; the forecast of a first-order autoregressive (AR(1)) PLM is
  `alpha + beta*(alpha + beta*x{-1})`. `'current'`: period-t data as in IJCB eq. 12; forecast
  `alpha + beta*x`. The extended model holds both forms behind the toggle `br_info_current`. The
  belief updates are the same under both; the forecasts, and so the shares, differ.
- `expectations.types` and `expectations.transforms`: section 7.

### 4.3 Beliefs and perceived laws of motion

- `beliefs.update`: `'rls'`, or `'fixed'` (held at the initial values).
- `beliefs.plm.default`: the PLM of every learning variable without an entry of its own;
  `'var1'` is one vector autoregression of order 1 (VAR(1)) over the learning set and cannot be
  combined with `beliefs.plm.var.variables`.
- `beliefs.plm.by_var.<x>`: a shorthand such as `'ar2'`, or `.regressors` (a cellstr of lagged
  variables, lag 1 or more, e.g. `{'pinf{-1}', 'ygap{-1}', 'r{-1}'}`) and `.constant` (`true`).
  An entry for a variable that does not learn sets its auxiliary PLM. VAR members take no
  `by_var` entry.
- `beliefs.plm.derived.<name>`: a regressor defined as a linear expression in model variables,
  e.g. `'y - yf'`; it becomes a model variable. The expression may use declared names, numbers,
  `+ - * /` and parentheses only.
- `beliefs.plm.var`: a VAR PLM over a cellstr of variables or `'learning'`.
- Regressors that do not learn get an auxiliary AR(1) PLM, learned the same way; VAR members
  that do not learn are auxiliary VAR equations.
- `beliefs.init.method`: `'re_moments'` (the RE model's moments, IJCB sec. 3.1),
  `'training_ols'` (ordinary least squares (OLS) on `beliefs.init.training_range` of the
  RE-smoothed history; the range is required), or `'user'` (`beliefs.init.values.<x>` with
  `.alpha`, `.beta` or `.phi`, optional `.R`; anything missing comes from the RE moments).
- `beliefs.init.date`: `[]` = the first filter date + 4 quarters (SW07: 1966Q1).

**PLM consistency check (`hetlearn:load_model:plmMismatch`).** The generated model file gives
every forward-looking variable the default PLM as its own equation; a run gives a forward-looking
variable outside the learning set, used as a regressor in a learning variable's PLM, an auxiliary
AR(1). With `beliefs.plm.default = 'ar1'` the two agree. With a non-AR(1) default (`'ar2'`,
`'ar1_noconst'`, `'var1'`) and such a regressor they differ, and `hetlearn.load_model` stops.
The fix is to set `beliefs.plm.by_var.<u>` for that regressor `u`, so that the generated file and
the run use the same PLM for it. The same error is raised when a PLM parameter is not declared in
the generated file.

### 4.4 Gain

The endogenous gain (`gain.rule = 'koz'`) is eq. (9) of Kostyshyna, Özden and Zhang (2024),
"Endogenous Credibility and Wage-Price Spirals", Bank of Canada Staff Working Paper 2024-14
(DESIGN 18). The function name `koz` and the options `gain.koz.*` stay as named in the code.

- `gain.rule`: `'constant'` or `'koz'`; the name must be a function in `toolbox/+hetlearn/+gain/`.
- `gain.value`: in (0, 1]; the constant gain (toolbox default 0.0585, the IJCB posterior mean)
  and the start of the endogenous gain.
- `gain.by_var.<x>`: the gain of one variable. With `'koz'` it is the start value under
  `gain.koz.structure = 'per_variable'` and is ignored with a warning under `'common'`.
- `gain.koz.mu`: the step size of the gain process ("gain on the gain"), >= 0; 0 gives the
  constant gain bit for bit.
- `gain.koz.error`: the signed error that drives the gain: `'rls'`, the one-step PLM residual,
  or `'forecast'`, the learners' expectation error (x_t minus their forecast made in t-1).
- `gain.koz.error_scale` (> 0): a factor on the error. With 1 the errors are in model units,
  percent per quarter, the units of the SW07 data and of chi. mu acts with the square of the
  factor, so a scale of 4 (annualized percent) works like a 16 times larger mu. Under the
  project baseline the gain stays within 0.047-0.052 over 1966Q1-2026Q2.
- `gain.koz.bounds`: 0 < lower <= upper <= 1, and the start gain must lie inside; a
  `gain_bound` event is logged in each quarter a bound binds.
- `gain.koz.structure`, `gain.koz.master`: one gain process for all PLM equations, driven by
  `gain.koz.master` (`''` = the first learning variable; a list = the mean of their scaled
  errors), or one process per equation driven by its own error.
- `gain.koz.gamma0`, `gain.koz.Rg0`: start values; `gamma0 = []` takes `gain.value`.

A missing error (NaN: missing data, or the first learning quarter under
`gain.koz.error = 'forecast'`) leaves gamma and Rg unchanged that quarter. With
`gain.koz.master` a list, the driving error is the mean of the drivers' errors, so one missing
driver skips the update of the whole common process.

With `'koz'`, `res.learning.<x>` also holds `gain_R`. The "R0 = 0.001" in Table 1 of
Kostyshyna, Özden and Zhang is the initial RLS moment matrix: to use it, set
`beliefs.init.method = 'user'` and only `beliefs.init.values.<x>.R = 0.001*eye(k)`.

### 4.5 Shares and switching

- `shares.structure`, `shares.master`: under `'universal'` one share for all learning variables,
  driven by the squared errors of `shares.master`, which is then required
  (`hetlearn:options:missing`). A list sums the squared errors, as IJCB does for inflation and
  the output gap. Every master variable must learn (`hetlearn:engine:master`).
- `shares.init_n2`: the initial learners' share at `beliefs.init.date`.
- `shares.fixed_n2`: a number or a struct by variable; required in mode `'fixed_shares'`
  (or `shares.fixed`, 7.2).
- `switching.rule`: the name must be a function in `toolbox/+hetlearn/+switching/`.
- `switching.intensity`: chi, >= 0. It multiplies squared forecast errors. IJCB's data and the
  three packages' model variables are in percent per quarter, so IJCB's 0.51 applies as
  estimated; the project baseline sets 2. For annualized data divide chi by 16 for the same
  switching.
- `switching.memory`: omega, in [0, 1) (IJCB sec. 4 text; Table 1 mean 0.62).

The squared errors enter unscaled. With zero future shocks both fitness measures decay, so the
learners' shares drift toward 0.5 by construction (there is no cost term for RE).

### 4.6 Projection facility

The facility is the toolbox's only stabilizing device. PLM is the learners' forecasting rule; ALM
is the model with the current beliefs and shares in it.

- `'plm_alm'`: check each PLM block, then the ALM. A block whose candidate beliefs have a root
  above 1 in modulus (AR(1): abs(beta) > 1) keeps its previous beliefs; the other blocks update.
- `'alm'`: check the ALM only; PLMs may be explosive while the model stays stable. If the model
  with the new beliefs has no stable solution, every belief goes back to its value before this
  quarter's update.
- `'none'`: no restriction; a quarter that must be simulated without a solution stops the run.
  The run is logged as an error, not moved to another facility.

Details:

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

### 4.7 History before the forecast origin

- `history.learn`: `false` makes the initial beliefs apply at the origin. `'inversion'` and
  `'kalman'` need `true`.
- `history.mode`: `'re_smoother'` (learning on the RE-smoothed history); `'inversion'` (the
  history backed out with the learning model, one quarter at a time, observables exogenized and
  shocks endogenized; it does not take N agent types or transforms); `'kalman'` (a time-varying
  Kalman filter of the model in force each quarter, 7.6). `'hetero_filter'` is a reserved name:
  error `hetlearn:options:notImplemented`, pointing to `'kalman'`.
- `history.kalman.init`: `'kalman'` only (7.6).
- `history.re_states`: `'re_smoother'` only; with `'inversion'` and `'kalman'` it is an error
  (`hetlearn:options:value`). Source of the RE agents' forecasts, the learners' data and the
  realized values in the fitness errors: the two-sided Kalman smoother (`'smoothed'`) or the
  one-sided filter (`'filtered'`, x_{t|t}, data up to t).
- `history.inversion.start`: `[]` = `beliefs.init.date`. `history.inversion.shocks`: `{}` =
  every transition shock; at least as many shocks as observables.
- `history.realtime`: the RE filter on data up to the origin only (no look-ahead). It takes
  effect only under `'re_smoother'` and is ignored under `'kalman'` and `'inversion'`, whose
  histories are one-sided by construction (the full-sample RE filter only supplies their
  starting state).

**RE states.** Under `'smoothed'` the RE agents' forecast made in t comes from states estimated
with data after t, which helps them in the fitness race. `'filtered'` removes that hindsight. For
an observed variable the two settings agree (SW07 inflation outside 2020Q1-Q3), so the option
moves the RE forecasts and, in the 2020Q1-Q3 gap, the learners' data, where the filtered value is
the RE prediction and the RE error is 0. The forecast still starts from the smoothed state;
`history.realtime = true` makes that state real time too, so `'filtered'` with `realtime = true`
is the fully real-time setup.

**Inversion accuracy.** The SW07 figures in DESIGN 15 (the RE inversion reproduces the
RE-smoothed shocks to 2.1e-13 over 1966Q1-2026Q2) were measured with the 2020Q1-Q3 quarters still
in the data (1.2). The inversion has nothing to exogenize in those quarters and backs out zero
shocks, so it equals the RE smoother only up to 2019Q4; `test_inversion` S1 checks it there
(below 1e-8).

### 4.8 Shocks and conditions

- `shocks.range`: the quarters that get smoothed shocks; `[]` = the horizon, and dates outside
  it are ignored.
- `shocks.add`: `{{'em', qq(2022,3), -0.25}, ...}` (name, dates, values; values scalar or one per
  date), added on top.
- All shocks are unanticipated: every quarter is a new simulation.

`cfg.conditions` is a struct array, one element per variable-shock pair (`[c1, c2]` for several),
and replaces the inherited value as a whole:

| Field | Values | Meaning |
|---|---|---|
| `variable` | name | Transition or measurement variable to put on a path, e.g. `'robs'`, `'ms'` |
| `shock` | name | Shock that adjusts to hit it |
| `dates` | dates, or `[start, end]` | Quarters of the condition, inside the horizon. Two dates are always read as a range |
| `values` | number or vector | Targets (scalar or one per date) |
| `type` | `'level'` (default), `'delta'` | The target is the value itself, or the value added to a reference path |
| `reference` | `'self'` (default) or a scenario id | For `'delta'`: the same scenario without conditions, or another scenario's path |

A variable conditioned twice in one quarter is an error. With more endogenized shocks than
targets, the smallest shocks in standard-deviation units are used
(`engine.conditions_weighting = 'std'`).

### 4.9 Monetary policy (Ramsey)

- `policy.mode = 'ramsey'`: optimal policy from the origin. It needs `spec.policy`, and it is not
  supported with `expectations.re_info = 'lagged'` or on the N-type path (7.8).
- `policy.type`: `'commitment'`; discretion is indeterminate in IRIS for SW07.
- `policy.loss`: non-negative weights by `spec.policy.targets` name (SW07, in
  `models/sw07/model_spec.m`: `pinf` = `4*pinf`, `ygap` = `y - yf`, `r` = `4*r`,
  `dr` = `4*(r - r{-1})`). Replaced as a whole: targets left out get weight 0.
- `policy.discount`: `[]` = `spec.policy.discount` (SW07: `'$cbetabar$*$cgamma$'`, 0.99756), or a
  number in (0, 1].
- `policy.loss_horizon`: `[]` = the forecast horizon. A longer one continues the scenario with
  zero shocks and no conditions.

Every run of a package with `spec.policy` reports its loss with the `policy.loss` weights
(`results/<id>/loss.csv`), so rule and Ramsey runs compare on the same weights. The Ramsey plan
starts at the origin with zero Lagrange multipliers; with learning, the planner re-optimizes each
quarter with the current beliefs and shares.

### 4.10 Density forecasts

- `density.shocks`: required when `density.enabled` (`hetlearn:options:missing`).
- `density.sigma`: `'calibrated'` (the model's `std_<shock>`) or `'smoothed'` (the sample
  standard deviation of the RE-smoothed shocks over `density.sigma_range`, `[]` = the filter
  range).
- `density.method = 'bootstrap'` resamples whole quarters of smoothed shocks; `density.demean`
  demeans the pool first.
- `density.fast_path`: in mode `'rational'` without conditions, one linear simulation per draw.
- `density.keep_draws`: store every draw in `density.mat`.

Draws come on top of the scenario's own shocks and conditions. With learning, each draw re-runs
the quarter-by-quarter forecast, so beliefs and shares respond to the drawn shocks. On SW07 an RE
density of 500 draws takes about 30 s on the fast path; a learning density takes about 0.7 s per
draw.

### 4.11 Engine

- `engine.step`: `'fast'` takes each one-quarter step from the cached state-space solution, equal
  to IRIS `simulate` to about 1e-12 and two to three times faster (about 20 times with the
  observables exogenized, as in the inversion); `'iris'` uses IRIS `simulate` itself.
- `engine.conditions_weighting`: with more shocks than targets, the minimum norm in
  standard-deviation units (`'std'`) or unweighted (`'none'`).

### 4.12 Removed options and option errors

Setting a removed option stops the run with `hetlearn:options:removed`; the message names the
replacement.

| Removed | Use instead |
|---|---|
| `projection.max_root`, `projection.method`, `projection.scope`, `projection.on_failure` | `projection.facility` |
| `switching.error_scale`, `switching.error_scale_ref` | none: squared errors enter unscaled |
| `beliefs.update = 'sac'` or `'kf'`, `beliefs.kf` | `beliefs.update = 'rls'` or `'fixed'` |
| `gain.rule = 'decreasing'`, `gain.decreasing` | `gain.rule = 'constant'` or `'koz'` |
| `switching.inertia`, `switching.costs`, `switching.fitness`; a model-implied `switching.intensity` such as `'model:bma'` | a number >= 0; the normalized fitness of 4.5 |
| type kind `'level'`; type fields `base`, `k`, `variables`, `variant`, `info`, `plm`, `update`, `gain`, `cost`; a second type of kind `'re'` | the type fields and kinds of 7.1 |
| transform kinds `'wedge'` and `'partial_adjustment'`; transform fields `profile` and `factor` | the transform kinds of 7.3 |

The rule terms `self{-k}`, `mean`, `dn` and `re1(...)` are no longer accepted either; the rule
parser rejects them (7.1). A merged option tree saved by an older version (`res.cfg`) still
loads: removed fields at their old off values are dropped.

| Identifier | Cause |
|---|---|
| `hetlearn:options:unknown` | A name that is not in the defaults; the message gives the full option path |
| `hetlearn:options:type` | Wrong type, e.g. a struct where a value is expected |
| `hetlearn:options:value` | A value outside its list or range |
| `hetlearn:options:missing` | `'fixed_shares'` without `shares.fixed_n2`, `'universal'` without `shares.master`, `'training_ols'` without `beliefs.init.training_range`, density without shocks |
| `hetlearn:options:unsupported` | A combination that is not supported: Ramsey policy with `re_info = 'lagged'`; agent types or transforms with Ramsey policy or the inversion |
| `hetlearn:options:removed` | A removed option (tables above) |
| `hetlearn:options:types`, `hetlearn:options:transforms` | An invalid `expectations.types` or `expectations.transforms` entry |
| `hetlearn:options:notImplemented` | `history.mode = 'hetero_filter'` |

Free-form subtrees, merged without name checks: `beliefs.init.values`, `beliefs.plm.by_var`,
`beliefs.plm.derived` (must hold strings), `gain.by_var`, `shares.fixed_n2` (as a struct),
`shocks.add`, `report`. Replaced as a whole, not merged: `conditions`, `policy.loss`,
`expectations.types`, `expectations.transforms`, `shares.init`, `shares.fixed`. A `policy.loss`
struct without `dr` therefore gives `dr` weight 0.

---

## 5. Outputs

### 5.1 `results/<id>/`

| File | Content |
|---|---|
| `results.mat` | `res`: `.cfg` (merged options), `.paths` (databank from the filter start to origin + H: the RE history, then the scenario; every variable and shock), `.learning`, `.events`, `.state`, `.dates`, `.meta` (run times, IRIS version, hashes, filter fit, collapse test, `history_alm_check_s`), `.loss` (packages with `spec.policy`), `.kalman` (Kalman history) |
| `observables.csv` | date and every observable, filter start to origin + H, model units |
| `paths.csv` | date and every transition variable, horizon |
| `learning.csv` | long: date, variable, field, value (fields in 5.2) |
| `events.csv` | date, type, variable, detail, stage (5.2) |
| `compare_<id>.csv` | this run minus `<id>`, observables, horizon, model units (`compare_with`) |
| `loss.csv` | target, expression, weight, contribution, share, discount, horizon, continuation, mode, type; one row per target and a total row |
| `density.mat` | variable `density`: quantiles, means, standard deviations and point forecasts of every summarized series, draw information, events (draws if kept); not inside `results.mat` |
| `density_quantiles.csv` | variable, date, quantile, value_model, value_report |
| `density_events.csv` | one row per draw: draw, status, projection_plm, projection_alm, projection_alm_shares, explosive_events, rls_missing, shares_nan, gain_bound, max_abs, message |
| `decomposition.csv` | after `hetlearn.decompose`: scenario, date, variable, component, value_model, value_report, label (with `total` rows) |
| `decomposition_check.csv` | app 6 only (`run_applications`): scenario, method, additivity_maxerr, recon_maxerr, n_solve, n_backward, runtime_s |
| `kalman_errors.csv` | `history.mode = 'kalman'` only: date, number of observables, log-likelihood contribution, and the error, prediction and variance of each observable |

A run without density deletes density files left by an earlier run of the same id.

### 5.2 Learning fields, share names, events

`res.learning.<x>` (one per PLM target, auxiliary PLMs included) holds IRIS Series, also in
`learning.csv`:

- beliefs, named like the model parameters: `alpha_<x>`, `beta_<x>` for an AR(1) with constant;
  `alpha_<x>` and `beta_<x>__<u>_l<lag>` for other PLMs (e.g. `beta_pinf__ygap_l1` in
  `v2_var3`);
- `R_<param>`: the diagonal of the RLS moment matrix;
- `gain` (and `gain_R` with `gain.rule = 'koz'`);
- for learning variables also `n1`, `n2`, `n1_model`, `zetaRE`, `zetaBR` (fitness), `FE_RE`,
  `FE_BR` (squared one-step errors), `fRE`, `fBR` (one-step forecasts).

Share names. Type 1 is the RE agents, type 2 the learners (`BR` in option and variable names);
the shares sum to 1.

| Name | Where | Meaning |
|---|---|---|
| `shares.init_n2`, `shares.fixed_n2` | options | Learners' share |
| `n1_<x>`, `n2_<x>` | model parameters | RE agents' and learners' shares of x's expectation in the model |
| `n1`, `n2` | `res.learning.<x>` | Discrete-choice shares computed at the end of each quarter (diagnostic unless the mode is `'switching'`) |
| `n1_model` | `res.learning.<x>` | RE share in the model that quarter (= `n1` of the quarter before under switching, unless the facility kept the shares) |
| `n2_model`, `n2_model_<x>` | summary CSVs, density outputs | 1 - `n1_model`: the learners' share in the model |

Event types (`events.csv`; column `stage` = `history`, `inversion` or `forecast`):

| Type | Meaning |
|---|---|
| `projection_plm` | `'plm_alm'`: a PLM block's candidate beliefs had a root above 1; that block kept its beliefs (detail names the block and the root) |
| `projection_alm` | The model with the new beliefs and shares had no stable solution; every belief went back to its value before this quarter's update |
| `projection_alm_shares` | Still unstable with the old beliefs: last quarter's model shares stayed in force for this quarter |
| `explosive` | A model without leads was simulated by the backward simulator without a stable IRIS solution |
| `rls_missing` | Missing data for a PLM equation; that equation kept its beliefs |
| `shares_nan` | The discrete choice gave non-finite shares; the previous fitness and shares were kept |
| `gain_bound` | The endogenous gain hit a bound of `gain.koz.bounds` |

### 5.3 `results/eval_<name>/`

For every origin `hetlearn.evaluate` sets the origin and horizon, zero future shocks, no
conditions, no density, no comparisons and a real-time RE filter (data up to the origin), so only
the expectations side of a variant's scenario file matters.

| File | Content |
|---|---|
| `errors_long.csv` | variant, origin, target, h, variable, actual, forecast, error (actual minus forecast, report units) |
| `metrics.csv` | sample, variant, variable, h, n, rmse (root mean squared error, RMSE), me (bias), mae; sample `full` and each subsample |
| `relative_rmse.csv` | sample, variant, benchmark, variable, h, n, rmse, rmse_benchmark, relative_rmse |
| `dm.csv` | sample, variant, benchmark, variable, h, n, mean_loss_diff, dm_stat, p_value, kernel (Diebold-Mariano (DM) test with the Harvey, Leybourne and Newbold (1997) correction; uniform kernel, Bartlett fallback where the variance is not positive) |
| `settings.mat` | `settings`: variants, origins, horizon, benchmark, subsamples, failed runs, events per run; the merged file of `run_applications` also coverage, parts, DM kernel and fallbacks |
| `parts/eval_<variant>_p<k>/` | `run_applications` only: one folder per part (`_p<k>of<K>` with another K), same files |

### 5.4 Units

- Model units: percent quarter on quarter; the policy rate in percent per quarter; SW07 hours
  100 x log. Reports multiply by `spec.report.scale` (4 annualizes).
- ijcb3: `pinfobs`, `robs` in percent per quarter (scale 4), `yobs` in percent of trend output
  (scale 1). as07: `dy` in percent quarter on quarter (scale 4); `pinfobs`, `robs` already in
  percent a year (scale 1).
- Report units = model units x scale: the summary CSVs, `errors_long.csv`, the `value_report`
  columns. Learning fields are in model units.

### 5.5 The estimation module

`estimation/` estimates SW07 by Bayesian methods, under rational expectations and with a learning
block like that of `a1_learn` (anchored RE agents, AR(1) inflation learners with a constant gain),
on 1966Q1-2026Q2 with 2020Q1-Q3 missing. It calls the toolbox's loaders but carries its own
solver, filter and learning recursion, and nothing in `toolbox/`, `models/` or `scenarios/` uses
it. Run order, outputs and status: `estimation/README.md`.

---

## 6. Practical notes

### 6.1 Parallel sessions

Run one group first so that the model caches in `models/sw07/generated/` exist. Two sessions
must never write the same `results/<id>/` or the same evaluation part. A `compare_with` target
without results is run first, so every target needs its results before parallel sessions start.
One PowerShell window per session, each with its own log file:

```powershell
& "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -batch "try, cd('<project root>'), run_applications('eval_part', {'e01_re', 'e02_learn'}, 1:6), catch e, disp(getReport(e)), exit(1), end" -logfile eval_s1.log
```

- **Evaluation:** split the variants (or the parts) over the sessions with
  `run_applications('eval_part', variants, parts)`, then run `run_applications('eval_merge')`
  once all have finished; the merge checks that the parts cover every origin exactly once.
  Keep variants with the same PLM on different parts until their real-time filter caches exist.
  A slow variant can be cut finer: `run_applications('eval_part', 'e09_var12', 7:12, 12)` runs
  parts 7-12 of 12 (folders `eval_e09_var12_p<k>of12`); each variant's parts only need to cover
  its origins once. The merge reads every part folder in `results/eval_sw07_v3/parts/` and stops
  on a part with other settings or overlapping origins, so that folder must be moved aside before
  a rerun with other origins, horizon or variants.
- **Densities:** `run_applications({'a5_markup_re', 'a5_demand_re'})` first (about 1 min), then
  `run_applications('a5_markup_learn')` and `run_applications('a5_demand_learn')` in two
  sessions.

### 6.2 Caches: `models/<name>/generated/`

| File | What it is |
|---|---|
| `<name>_ext_<tag>.model`, `<name>_ext_<tag>_meta.mat` | Extended model and its metadata; tag `ar1` for the default PLM, else `p` and 8 hex digits of the PLM spec's MD5 hash |
| `<name>_ext_<tag>_relag.model`, `_relag_meta.mat` | The same with RE expectations on information up to t-1 (`expectations.re_info = 'lagged'`, generator version 5); its RE filter caches are separate and also hold the one-step predictions |
| `<name>_ext_n<hash>.model` | Runs with agent types or transforms (7.1) |
| `<name>_norm.model` | Only when the source needs notation changes: the source in IRIS notation (reference of the collapse test) |
| `refilter_<hash>.mat` | Full-sample RE filter; key: extended model text, parameters, `spec.assign`, database file bytes, filter range |
| `refilter_rt_<end>_<hash>.mat` | Real-time RE filter per end date (evaluation, `history.realtime`); per PLM spec and RE variant; about 1,850 files for SW07 |

A change of parameters, data or PLM spec gives a new key, so a stale cache is never used.
Delete a file, or the folder, only to force a rebuild; the next run is slower. A filter cache
also holds the filtered databank (`H.filtered`). A cache written by an older version has none:
the first run that reads it filters again and rewrites it under the same name, with the same
smoothed history. Two sessions should not refresh the same file at once, so one session runs
first before parallel ones.

### 6.3 Tests

- **The tests do not read the project baseline.** `tests/scenarios/master_options.m` holds the
  toolbox defaults (`hetlearn.defaults()`); `run_tests` and the SW07 suites put
  `tests/scenarios/` first on the path, and `run_tests` stops if `master_options` resolves
  elsewhere. A suite run on its own needs `addpath('tests/scenarios')`. The test scenarios
  `tsw07_*` also pin the settings the project baseline changes (`model_params = ''`, constant
  gain, `re_info = 'current'`, `re_states = 'smoothed'`, facility `'plm_alm'`). Run the tests in
  a MATLAB session of their own, since project runs in the same session would pick up the test
  settings.
- **Exact references and threads.** `test_inversion` S3b, `test_gain` G14, `test_re_states` S1,
  `test_re_info` T6b and `test_br_regression` compare with `tests/reference/` exactly. The
  references were made at the default thread count; with `maxNumCompThreads(2)` the runs differ
  by about 1e-12 and those checks fail, so they run at the default thread count.
- `run_tests` runs the 24 suites in `tests/run_tests.m` (364 checks), more than 9 min in one
  session. The suites of the further expectation rules are `test_kalman`, `test_ntypes`,
  `test_transforms`, `test_anchor` and `test_br_regression`.
- A subset: `run_tests({'test_options', 'test_rls', 'test_switching'})`. `test_re_info` alone
  takes about 8 min; `test_re_info('toy')`, `('sw07_model')`, `('sw07_runs')` and
  `('sw07_stages')` run its parts. Its Dynare check reads stored impulse responses
  (`tests/reference/re_info_dynare_irfs.mat`); `tests/models/dynare/run_dynare_check.m` remakes
  them in a session without IRIS (Dynare 4.6.1, run outside OneDrive-synced folders, where
  Dynare can fail).
- `run_tests({'test_generator'})` runs in a MATLAB session of its own.
- `test_decompose`'s SW07 part reads outputs of `test_inversion` in `tests/output/results/`, so
  `test_inversion` runs first (`run_tests` orders them so).
- The tests never read `scenarios/` or `results/`: they use `tests/toy_nk/`,
  `tests/scenarios/tsw07_*.m` and `models/sw07/`, and write `tests/output/results/` and
  `tests/toy_nk/generated/`.
- `tests/scenarios/make_reference.m` rewrites `tests/reference/tsw07_switch_pinf_iris.mat` and
  `tsw07_switch_pinf_fast.mat` (the default `'fast'` step, compared exactly by
  `test_re_states`). It is run only after a deliberate change of the engine or the defaults.

### 6.4 Known caveats

- **Anchored RE under Ramsey (open design question).** Anchored agents forecast with the RE
  solution under the Taylor rule, also in mode `'rational'`, so `a4_ramsey_<w>_re` are not RE
  Ramsey plans. The RE Ramsey benchmark is `a4_ramsey_<w>_re_mc` (model-consistent RE agents;
  rows `RE_model_consistent` in `app4_losses.csv`). In the `_learn` files the anchored RE agents
  still forecast with the Taylor-rule solution.
- **Model-consistent RE with many learning variables** can lose the stable solution. On SW07
  with all 12 variables learning, such a run completes only because the facility keeps the
  model shares: under `'plm_alm'` the origin's shares stay in force in all 16 forecast quarters.
  `events.csv` shows `projection_alm_shares` for such a run, so check it before reading the run.
- **Zero future shocks:** the shares drift toward 0.5 by construction (4.5).
- **Scenario names** are function names on the path; keep them unique (`which -all <name>`).

---

## 7. Further expectation rules

The options of this section let a scenario replace the two agent types (RE agents and AR(1)
learners) by a population of forecasting types, set their initial or fixed shares, and transform
the expectations the model uses. Every option is off by default, and a scenario that sets none of
them runs the two-type code unchanged (`tests/test_br_regression.m` checks that its results are
bit-identical). The website's Further expectation rules page
(`docs_site/options/further-expectation-rules.md`) has the formulas, the seven scenario files
with their sources and the results; the technical appendix has the equations. This section gives
the checks, the stages each option supports and the outputs.

| Extension | Options |
|---|---|
| N agent types | `expectations.types`, kinds `'re'`, `'plm'`, `'rule'`, `'re_mean'` (7.1) |
| Shares over N types | `shares.init`, `shares.fixed` (7.2) |
| Forecast transforms | `expectations.transforms`, kinds `'multiplier'`, `'diagnostic'`, `'myopia_anchoring'` (7.3) |
| Generalized anchor | type kind `'re_mean'`; `hetlearn.anchor_coefficients` (7.5) |
| Learning rules | mean-only PLM (`beliefs.plm.by_var`); the constant and endogenous gains of 4.4 (7.4) |
| Kalman history | `history.mode = 'kalman'`, `history.kalman.init` (7.6) |

The seven scenarios are `scenarios/sw07/br_portfolio/br<NN><x>_<name>.m`. Each is
`cfg = a1_learn();` plus the lines of 7.7, so it inherits the project baseline (1.4).
`run_br_app1('run')` runs them in Application 1 with `a1_re` and `a1_learn`;
`run_br_portfolio('irf')` and `('rmse')` add their impulse responses and Kalman histories;
`('csv')` writes `results/br_portfolio/`.

### 7.1 Agent types: `expectations.types`

A struct array, or a cell array of structs, one struct per type:

| Field | Values | Meaning |
|---|---|---|
| `name` | letters and digits, starting with a letter; required; unique | Suffix of the type's forecast `<x>_exp1_<name>` and share `n_<name>_<x>` |
| `kind` | `'re'`, `'plm'`, `'rule'`, `'re_mean'`; required | The RE forecast (only the type named `RE`); a learned PLM; a fixed linear rule (below); the RE forecast plus a learned mean of its own error (7.5) |
| `rule` | text, or `struct('expr', <text>, 'params', struct(...))` | `'rule'` only, required |

Everything else comes from the global options, the same for every type of a kind:

| Kind | Takes |
|---|---|
| `'re'` | `expectations.re_variant`, `expectations.re_info` |
| `'plm'` | `beliefs.plm`, `beliefs.info`, `beliefs.update`, `gain` |
| `'rule'` | `beliefs.info`; a rule has no beliefs |
| `'re_mean'` | the RE type's variant and information; `beliefs.update` and `gain` for its learned mean |

Rules of the population:

- Every type forecasts every learning variable (`expectations.variables`). The share groups follow
  `shares.structure` (4.5): one per learning variable, or one for all under `'universal'`.
- The RE type is always generated. When the list does not name it, it has share 0 and stays
  outside the logit, and it is still the RE limit that the RE filter and the history use. Only
  the type named `RE` can be of kind `'re'`, and it must be.
- Modes: `'rational'` puts share 1 on the RE type; `'learning'` share 1 on the single non-RE
  type (an error when there are several); `'fixed_shares'` takes `shares.fixed` (struct by type
  name) or the two-type shorthand `shares.fixed_n2`; `'switching'` uses 7.2.
- Writing the default pair out, `{struct('name', 'RE', 'kind', 're'), struct('name', 'BR',
  'kind', 'plm')}`, takes the N-type generator and engine and gives the two-type results
  exactly (`test_ntypes` R3, `test_kalman` K6).

Generated file: `models/<name>/generated/<name>_ext_n<hash>.model` (generator version 6; 7 with
transforms; 8 with `'re_mean'` types).

**Rule syntax.** A rule is a fixed linear expression in these terms (`hetlearn.plm.rule_terms`):

| Term | Meaning |
|---|---|
| `x{-k}` | The variable being forecast, k quarters back (k >= 1 under `'lagged'` information). The same rule applies to every learning variable |
| other transition variables, with lags (`y{-1}`) | As written, with the same lag rule |
| numbers, `+ - * / ( )` | As written |
| named constants | The fields of `params` in `struct('expr', <text>, 'params', struct(...))` |

Rules take no functions. A rule type learns nothing: it has no PLM and no beliefs, and its
forecast enters fitness like any other type's.

### 7.2 Shares over N types

In each share group with types k = 1..N:

    U_k,t = omega*U_k,t-1 - (1 - omega)*FE_k,t
    n_k,t = exp(chi*U_k,t) / sum_j exp(chi*U_j,t)

chi is `switching.intensity` (a number >= 0) and omega `switching.memory` (in [0, 1)), as in
4.5 and the same for every group: the normalized fitness of IJCB eqs. 14-15 over N types. FE_k,t
is the squared error of type k's forecast as it enters the model (7.3).

- `shares.init`: initial shares, summing to 1 per group; `[]` = `shares.init_n2` for the default
  pair, equal shares otherwise. The initial fitness returns these shares through the logit.
- `shares.fixed`: mode `'fixed_shares'`; not together with `shares.fixed_n2`.

With two types, RE first, the engine calls the two-type `hetlearn.switching.discrete_choice`;
with more it calls `discrete_choice_n` and `init_fitness_n`. A published intensity beta of the
unnormalized Brock-Hommes form (U = omega*U - FE) corresponds to chi = beta/(1 - omega) here.
The units must match too: SW07's squared errors are in percent per quarter.

### 7.3 Forecast transforms: `expectations.transforms`

A transform changes the expectation as it enters the model; the type forecasts `<x>_exp1_<k>`
stay as formed. Fitness, `FE_<k>` and `f_<k>` use the transformed forecast; `fb_<k>` records the
forecast before the transforms. The kinds, their values and the fields `types`, `scope` and
`exclude` are on the website's page.

- The values are model parameters, so one generated file covers every value of a transform.
- Several transforms on one expectation apply in list order. Only one-step expectations are
  transformed.
- An equation-specific scope `'x@<label>'` names the equation by its exact label in the model
  file (SW07: `'Phillips curve, price setting'`, `'Wage Phillips curve, wage setting'`,
  `'Consumption Euler equation'`, `'Arbitrage equation for the value of capital'`).
- Anchored RE agents take their coefficients from the variant's own RE limit, so they know the
  transforms on the other expectations.
- A diagnostic transform must come first on its expectation, and it acts on RE types and on the
  model-consistent expectations only: on a learned or rule type of a learning variable the run
  stops. On the anchored RE(t-1) type its reference is the anchored E_{t-2} forecast
  `<x>_DEg_RE`, with memory states such as `c_REt2` in the anchor economy (variant 10,
  `test_anchor` A5). With period-t RE information that anchored reference is not built, so the
  run needs `expectations.re_info = 'lagged'` or `re_variant = 'model_consistent'`.

### 7.4 Learning rules

Learning types update with `beliefs.update` (`'rls'` or `'fixed'`, 4.3) and the gain rules of
4.4. Two of the seven rules change only these options: a mean-only PLM,
`beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true)`, whose forecast is the
learned mean (adaptive expectations by exponential smoothing, variant 24), and a constant gain of
0.018 in place of the endogenous gain (variant 26).

### 7.5 The intercept-only type and the generalized anchor

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

### 7.6 The Kalman history: `history.mode = 'kalman'`

A time-varying Kalman filter of the model in force each quarter
(`hetlearn.engine.kalman_history`). In quarter t the ALM with the beliefs and shares from the end
of t-1 is solved, the filter predicts and updates with that quarter's data (quarters without
data are predictions only), and the agents learn from the filtered values in real time. Before
`beliefs.init.date` the ALM is the variant's RE limit.

- `history.mode = 'kalman'` needs `history.learn = true` and `history.re_states = 'smoothed'`.
  The project baseline sets `'filtered'`, which applies to the RE smoother only, so Kalman
  scenarios set `'smoothed'` again.
- `history.kalman.init`: `'stochastic'` starts from the asymptotic distribution of the first
  quarter's ALM (as IRIS `filter` does); `'smoothed'` starts at `beliefs.init.date` from the
  RE-smoothed state with P = 0.

Agents' information: forecasts made in t with data to t-1 (the RE(t-1) type) are the
predictions x_{t|t-1}; forecasts with period-t data use x_{t|t}; realized values and PLM
regressors are the filtered values stored when each quarter was filtered, not revised later.
With N types every type's forecast comes from these data; the target of a `'re_mean'` type is
rebuilt from x_{t|t} and the RE forecast the agents used. The forecast stage starts from the
filtered state at the origin.

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
mean-only PLMs, `'re_mean'` types, rules such as `x{-1}` or `0`, so each of the seven rules of
7.7. A forecast that also uses an earlier date (an AR(2) PLM, a rule in `x{-1} - x{-2}`)
differs, because the model's lagged states are the filter's revised values and the agents' data
the real-time ones; its RMSE and log likelihood are then not the variant's own.

### 7.7 The seven rules

Each row is a scenario file in `scenarios/sw07/br_portfolio/`: `cfg = a1_learn();` plus the
lines shown (abbreviated: `T(...)` = `struct(...)`, `FLEX = {'invef', 'pkf', 'rkf', 'cf',
'labf'}`). "Proposed" marks a value with no published counterpart. The last column is the caveat
to state with the results.

| Variant | Mechanism (source) | Lines on `a1_learn` | Values and their source | Caveat |
|---|---|---|---|---|
| `br05b_cd_learn` | Cognitive discounting on the learning set (Gabaix 2020) | `T('kind','multiplier','types','all','value',0.94,'scope','learning','exclude',{FLEX})` | m = 0.94, Meggiorini and Milani (2021), US 1960-2007 | m comes from their model, not from SW07 |
| `br07_myopia_anchoring` | Myopia and anchoring (Angeletos and Huo 2021) | `T('kind','myopia_anchoring','types','all','value',[0.52 0.434],'scope',{{'pinf@Phillips curve, price setting'}})` | (omega_f, omega_b) = (0.52, 0.43), their Table 1; b = 0.43/0.99 | SW07 keeps its own indexation and habit, so the backward weight comes on top |
| `br10_diagnostic` | Diagnostic expectations, one-period memory (L'Huillier, Singh and Yoo 2024) | `T('kind','diagnostic','types',{{'RE'}},'value',0.44,'scope','all','exclude',{FLEX})` | theta = 0.44, their estimate in SW07 with Rotemberg pricing | no current-variable terms of L'Huillier, Singh and Yoo; the learners are not diagnostic |
| `br19_target_believers` | Target believers (Hommes and Lustenhouwer 2019) | three types, the third `T('name','TB','kind','rule','rule','0')`; `shares.init` a third each | shares 1/3 each, proposed; switching as in the project baseline | the three types nest the baseline pair; Hommes and Lustenhouwer use target believers and naive forecasters |
| `br23_intercept_only` | Intercept-only learning (Gáti 2023; Carvalho, Eusepi, Moench and Preston 2023) | `types = {T('name','RE','kind','re'), T('name','IO','kind','re_mean')}` | the endogenous gain of the project baseline, from 0.05 | Gáti's anchoring function is left out, so the paths stay close to RE |
| `br24_mean_only` | Mean-only learning, adaptive expectations | `beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true)` | the endogenous gain of the project baseline | none |
| `br26_experience` | Experience-based learning, aggregate (Malmendier and Nagel 2016; Nagel and Xu 2022) | `gain.rule = 'constant'; gain.value = 0.018` | 0.018 per quarter (Nagel and Xu; Malmendier and Nagel's 0.0175) | no cohorts: a constant gain of 0.018 at Malmendier and Nagel's value |

The two references are `a1_re` (RE(t-1), the RE limit of the baseline) and `a1_learn`. All
seven variants learn on `{pinf}` as the baseline does, so `a1_re` is the RE reference of each.

### 7.8 Which stages take N types and transforms

| Stage | Status |
|---|---|
| History, `history.mode = 're_smoother'` | supported |
| History, `history.mode = 'kalman'` | supported; the seven rules run through it |
| History, `history.mode = 'inversion'` | not supported: `hetlearn:options:unsupported` |
| Forecast and scenario stage | supported |
| Density forecasts (`density.enabled`) | supported on the general path (a draw re-runs the forecast stage); the fast path stays two-type. Summarized: `n_model_<k>_<x>` per type and the beliefs of each learning type (`alpha_pinf__BR`, ...) |
| `hetlearn.evaluate` | supported; a variant with N types or transforms gets the RE filter of its own RE limit |
| `hetlearn.decompose` | supported; a result of `history.mode = 'kalman'` stops with `hetlearn:options:unsupported` |
| Ramsey policy (`policy.mode = 'ramsey'`) | not supported: `hetlearn:options:unsupported` |

"N types" here means any run on the N-type path: `expectations.types`,
`expectations.transforms`, `shares.init` or `shares.fixed`. The refusals name the options that
put the run there.

### 7.9 Outputs of N-type runs

| Output | Content |
|---|---|
| `res.learning.<x>` | per type k: `n_<k>` (discrete-choice share at the end of t; 0 outside the population), `n_model_<k>` (share in the model in t), `U_<k>` (fitness), `FE_<k>` (squared error), `f_<k>` (forecast as it enters the aggregate), `fb_<k>` (before the transforms, only with transforms); `.types` |
| `res.learning.<target>__<k>` | belief series of each learning type (`alpha_pinf__BR`, `alpha_pinf_feRE__IO`, `R_...`, `gain`, the gain rule's series) |
| `res.paths.<x>_exp1_<k>` | the type's forecasts over the record dates (as `<x>_exp1_BR` in two-type runs) |
| `res.meta.types`, `res.meta.model_values` | the resolved types; the transform values (with transforms only) |
| events | the types of 5.2; the N-type path adds none |

`learning.csv` carries the same series in long form.
