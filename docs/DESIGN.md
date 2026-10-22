# hetlearn: design specification

`hetlearn` is a MATLAB wrapper around the IRIS toolbox (tested on IRIS 20230622,
MATLAB R2025a). It takes a self-contained IRIS model (model file, parameterisation,
optional steady-state solver) and an IRIS-readable database, and runs forecasts and
scenarios in which expectations are a time-varying mix of rational expectations (RE)
and adaptive learning (bounded rationality, BR). The switching follows Özden (2025),
"Heterogeneous Expectations and the Business Cycle", IJCB 21(1), eqs. (12)-(16) and
Appendix D. Estimation is out of scope.

This file is the contract for the code. Every user-facing option is listed in
`docs/FEATURES.md` with where it is set and whether the user asked for it or it was
added during the build.

---------------------------------------------------------------------------------------

## 1. Folder layout

```
iris_toolbox_learning/
  setup_paths.m              adds IRIS + toolbox/ to the path, runs iris.startup
  run_applications.m         runs the application groups, decompositions and evaluation parts
  config/master_options.m    project-wide option overrides (user edits this)
  toolbox/+hetlearn/         the toolbox source (the user never edits this)
  models/<name>/             one self-contained folder per model (sec. 2)
  scenarios/<name>/*.m       one file per scenario (sec. 6)
  results/<scenario_id>/     outputs of each scenario run (sec. 9)
  reports/                   HTML reports
  tests/                     unit tests (toy NK model) and model validation tests
  docs/                      DESIGN.md (this file), FEATURES.md
```

## 2. Model package contract

A model folder `models/<name>/` must contain `model_spec.m`, a function with no inputs
returning a struct:

| field | meaning |
|---|---|
| `name` | model name, e.g. `'sw07'` |
| `model_file` | IRIS model file, relative to the folder |
| `params` | function name (in the folder) returning a struct of parameter values, incl. `std_<shock>` |
| `sstate` | optional function handle name `m = f(m)`; empty for linear models |
| `linear` | true/false (passed to `Model.fromFile`) |
| `assign` | struct of the model file's own `!if` switches (may be empty) |
| `database` | IRIS-readable databank file (CSV written by `databank.toCSV`, or .mat) |
| `filter_range` | `[start, end]` dates for the RE filter |
| `observables` | cellstr of measurement variable names |
| `report` | struct: labels and transformations for reporting (sec. 10) |
| `policy` | optional (sec. 13): `instrument`, `rule_label` (exact label of the rule equation), `targets` (struct of expressions in model variables, lags `x{-k}` allowed), `discount` (expression, `$substitutions$` allowed, or a number). Without it there is no Ramsey mode and no loss accounting |

Everything the toolbox generates for a model goes into `models/<name>/generated/`.

## 3. Extended model generator: `hetlearn.extend_model`

```
meta = hetlearn.extend_model(spec, plmSpec)   % writes generated/<name>_ext_<plmtag>.model + _meta.mat
```

### 3.1 Lead detection
- Leads are detected only on declared **transition variables**, only inside
  `!transition_equations` (alias `!equations`) and `!substitutions` sections, and only in
  the dynamic part of an equation (text before `!!`).
- Comment text and quoted labels (`"..."`, `'...'`) are never modified. IRIS 20230622
  accepts only `%` and `%{ %}` comments, so `//` and `/* */` delimiters in a source file
  are converted to `%%` and `%{ %}` (text unchanged).
- Accepted lead notations (whitespace tolerant), all normalised to the IRIS form:
  `x{+k}`, `x{k}`, `x{t+k}`, `x[+k]` (IrisPie), `x(+k)` (Dynare), for integer k >= 1.
  Non-IRIS lag forms (`x[-k]`, `x{t-k}`, `x(-k)`) are normalised to `x{-k}`. IRIS cannot
  load the non-IRIS forms, so the collapse test (3.4) compares against
  `generated/<name>_norm.model`, the source with only its subscripts normalised.
- Pseudo-functions that create leads (`diff`, `difflog`, `mov*` with a lead or a forward
  window) are rejected with an error that names the equation; the user rewrites them.
- Files using `!for` or `!import`/`!include` are expanded with the IRIS preparser first.
- The model's own `!if`/`!switch` blocks (switches from `spec.assign`) stay in the generated
  file, but forward-looking variables and max leads are detected on the branches that
  `spec.assign` selects (IRIS preparser; review m6, 2026-10-18). A variable whose leads sit
  only in inactive branches is not forward-looking and keeps `x{+k}` there. The cache key
  includes `spec.assign`.
- Name collisions with generated names are an error.

### 3.2 Rewriting
For each forward-looking variable `x` with maximum lead K:
1. Replace every `x{+k}` by `x_expk` (k = 1..K).
2. Append definitions (new sections appended at the end of the file; IRIS allows
   repeated sections, so the user's declaration blocks are not touched):

```
!transition_variables
    "Aggregate expectation of x{+1}" x_exp1
    "Aggregate expectation of x{+k}" x_expk                 (k = 2..K)
    !if br_x
        "RE expectation of x{+1}" x_exp1_RE
        "BR (adaptive learning) expectation of x{+1}" x_exp1_BR
    !end
!parameters
    n1_x, n2_x, alpha_x, beta_x     (belief names depend on the PLM, sec. 4.2)
!transition_equations
    !if br_x
        x_exp1 = n1_x*x_exp1_RE + n2_x*x_exp1_BR;
        x_exp1_RE = x{+1};
        x_exp1_BR = <PLM forecast expression, sec. 4.2>;
    !else
        x_exp1 = x{+1};
    !end
    x_expk = x_exp(k-1){+1};          (k = 2..K)
```

Parameters are declared unconditionally (unused parameters are harmless); variables and
equations sit inside the `br_x` toggle. With `expectations.re_info = 'lagged'` the loader
uses a separate file with an E_{t-1} x_{t+1} block instead (`<name>_ext_<tag>_relag.model`,
sec. 19).

### 3.3 Model-file toggles
`br_<x>` (one per forward-looking variable) is an IRIS `!if` switch. The loader sets it
from the scenario's list of learning variables (`true` = this variable's expectation is
the RE/BR mix, `false` = pure RE, with no extra variables in the model). The model's own
`!if` switches are passed through from `spec.assign`.

### 3.4 Generator checks (run every time a file is generated)
- The extended model with every `br_x = true`, `n1_x = 1`, `n2_x = 0` must reproduce the
  original model: IRFs to every shock, all original variables, 40 periods, max abs
  difference < 1e-10. The same with every `br_x = false`.
- `meta` records: source file, source hash, PLM spec, forward variables, max leads,
  generated variable/parameter names, toggle names, timestamp.
- Regenerate only if the source hash or the PLM spec changed.

## 4. Expectations

### 4.1 Aggregate expectation
`x_exp1_t = n1_x * x_exp1_RE_t + n2_x * x_exp1_BR_t`, with `n1_x + n2_x = 1` enforced by
the toolbox (it always sets `n2_x = 1 - n1_x`). The shares used in period t are the shares
computed at the end of period t-1 (IJCB eq. 16, footnote 13).

RE agents: `cfg.expectations.re_variant` (sec. 11). The baseline since 2026-10-18 (user
decision) is `'anchored'`: RE agents use the pure-RE model's forecast at the current
state. The alternative `'model_consistent'` is `x_exp1_RE = x{+1}`, the model-consistent
expectation in the heterogeneous economy, under anticipated utility (beliefs and shares
are treated as permanent when the model is solved; re-solved every quarter).

### 4.2 Perceived law of motion (PLM) and the BR forecast
Information assumption (user spec): in period t, BR agents observe data up to t-1. A PLM
equation for variable v is

    v_t = alpha_v + sum_j beta_{v,j} * u_j,{t-l_j} + error,    l_j >= 1

where the regressors `u_j{-l_j}` are lags of model variables. The 1-step-ahead BR forecast
of x_{t+1} is built by iterating the PLMs forward from the information set {.., t-1}:

    E(v, h) = alpha_v + sum_j beta_{v,j} * T(u_j, h - l_j)          (forecast of v_{t+h})
    T(u, k) = u{k}        if k <= -1      (observed)
            = E(u, k)     if k >= 0       (must itself be forecast)
    x_exp1_BR = E(x, 1)

For the default AR(1) PLM this gives exactly the user's form

    x_exp1_BR = alpha_x + beta_x*(alpha_x + beta_x*x{-1});

Option `beliefs.info` (added 2026-10-18, review s5 / user question D2): `'lagged'` (default)
is the information assumption above. `'current'` follows IJCB eq. (12): BR agents see
period-t data, `E_t x_{t+1} = alpha_{t-1} + beta_{t-1} x_t`, determined jointly with x_t,
and beliefs are updated after x_t is realised, so the forecast in t still uses phi_{t-1}.
The recursion is the same with T(u,k) = u{k} for k <= 0; since every lag is >= 1, E(x,1)
never recurses: AR(1) `alpha_x + beta_x*x`, AR(2) `alpha + b1*x + b2*x{-1}`, VAR
`alpha + B X_t`, derived and auxiliary regressors dated t. The generator writes both forms
inside each `br_x` block under the global toggle `!if br_info_current` (the loader sets it
from the option; generator version 4). RLS and switching are unchanged: FE_t compares x_t
with the forecast made in t-1 (under `'current'`, alpha_{t-2} + beta_{t-2} x_{t-1}), and
the RLS regressors are dated t-1 and earlier. The engine's per-period timing assert and the
history stage use the same information set (`sys.info`).

Any regressor variable that is not a learning variable gets an auxiliary PLM (default:
AR(1) with constant), estimated by the same RLS, so that the system is closed. The
generator writes E(x,1) as nested text.

Belief parameter names: AR(1) with constant on own lag only -> `alpha_x`, `beta_x`.
Any other PLM -> `alpha_x`, `beta_x__<u>_l<l>`. Constant optional (`constant=false` drops
`alpha_x`).

PLM spec format: `plm.default = 'ar1'`; `plm.by_var.<x> = struct('regressors',{{'x{-1}','x{-2}'}}, 'constant', true)`.
Shorthands: `'ar1'`, `'ar2'`, `'ar1_noconst'`.

### 4.3 Belief updating: constant-gain RLS (IJCB eq. 13)
For each PLM equation e with regressor vector z_{t-1} = [1; regressors dated <= t-1] and
target v_t, after v_t is realised:

    R_t   = R_{t-1} + g_t * (z_{t-1} z_{t-1}' - R_{t-1})
    phi_t = phi_{t-1} + g_t * R_t^{-1} z_{t-1} (v_t - phi_{t-1}' z_{t-1})

phi_t is used in period t+1. Equation by equation, each with its own R.
Gain `g_t` comes from a gain rule `hetlearn.gain.<rule>`: `'constant'` (`gain.value`,
`gain.by_var.<x>`) or `'koz'`, the endogenous gain of sec. 18. The rule interface (calls
`'fields'`, `'init'`, `'gain'`, `'update'`, with the rule's state kept in the learning state)
is described in sec. 18.

Belief modes: `'rls'` (endogenous) or `'fixed'` (held at their initial values).

### 4.4 Projection facility (as built 2026-10-18, track G)
User decision 2026-10-18: the projection facility is the only stabilising device. Partial
updates, shrinking, the joint (system) check, the root threshold `max_root`, keep-previous
and error-out as separate fallbacks, and switching error scaling were removed; their option
names now raise `hetlearn:options:removed`, which points to `projection.facility`. Terms:
PLM = the agents' forecasting rule; ALM = the model with the beliefs and shares plugged in.

`projection.facility` (`hetlearn.engine.facility`, called from `update_learning` and the
stages):
- `'none'`: no restriction. A model that cannot be solved in a period where it must be
  simulated stops the run: `hetlearn:engine:noSolution` with the date, the stage, the BR
  shares, the largest root of each PLM block, the beliefs and the IRIS stability flag. A
  linear model without leads (anchored RE, every forward-looking variable learning) has a
  solution for any beliefs and shares: the backward simulator runs it as is and logs an
  `explosive` event (sec. 11). A history stage that does not simulate the model (the
  RE-smoothed history) solves nothing.
- `'alm'` (restrict the ALM only): the PLMs are never touched; explosive PLMs are allowed
  while the ALM is stable. When the ALM is unstable (IRIS finds no unique stable solution;
  for a model without leads, a backward transition root with modulus above 1), every
  belief (phi and R of every PLM equation, auxiliary ones included) goes back to its value
  before this period's update (`S.prev`), the model is solved again, event
  `projection_alm`. No search for the forecast that causes the instability.
- `'plm_alm'` (default): first the PLM blocks, case by case, then the ALM check as under
  `'alm'`. A PLM block is a connected set of PLM equations (linked through their
  regressors; a VAR is one block; an auxiliary equation belongs to the block of the
  equations that use it; separate AR(1) PLMs are separate blocks; `hetlearn.plm.blocks`).
  A block whose candidate beliefs have a largest companion root above 1 in modulus
  (AR(1): |beta| > 1; non-finite candidates count as explosive) keeps its previous phi and
  R, event `projection_plm` with the block and its root; the other blocks update. Every
  candidate comes from phi_{t-1}, R_{t-1} and each block is judged on its own equations,
  so the outcome does not depend on the equation order.
- Under `'alm'` and `'plm_alm'`, a model still unstable with every belief at its previous
  value (the shares alone make it unstable) also keeps the previous quarter's model shares
  (user decision 2026-10-18, second ruling): the beliefs and model shares last in force,
  which solved, stay in the model for that quarter, event `projection_alm_shares` ("beliefs
  and model shares kept at the previous quarter's values"; `projection_alm` stays the
  beliefs-only step, and each check logs at most one of the two). Switching carries on:
  the fitness measures and the discrete-choice shares (`S.zetaRE`, `S.zetaBR`, `S.n1`,
  recorded `n1`/`n2`) keep updating from the forecast errors, and the next quarter tries
  the new shares again. The kept shares sit in `S.n1m_keep` for one quarter
  (`hetlearn.engine.shares_for_mode` returns them; `update_learning` clears them before the
  next check); `S.n1m_last` holds the model shares in force in the period being updated.
  Fixed-share modes never reach this step (their shares do not change).
- The run stops only when no earlier solved model exists: the initial beliefs and shares are
  already unstable at the first check of a run (the first history quarter, or the first
  forecast quarter with `history.learn = false`). Error `hetlearn:engine:almUnstable`: date,
  stage, shares, beliefs, IRIS flag, "no stable solution and no earlier solved model to
  fall back on". The same applies to a stage whose model differs from the one checked
  before (a Ramsey forecast model at the origin), when the previous quarter's beliefs and
  shares do not solve that model either.

Where the check runs. Beliefs formed at the end of t (phi_t, with the shares n_t) are in
force in t+1, so the ALM check solves the model of t+1 at the end of t, right after the
RLS and PLM step, and the solved model is reused when t+1 is simulated (no extra solve,
except one after the last forecast period). The same rules apply in every stage that
updates beliefs, with one or many learning variables: the RE-smoothed history (the model
is solved only for the check; the history model before the origin, the rule model of a
Ramsey scenario, and the forecast model at the origin), the inversion history, the
forecast, density draws, `hetlearn.evaluate` runs and the Ramsey continuation. The solve
is skipped when every BR model share is 0 (mode `'rational'`): the ALM is then the RE
model. A start-of-period solve that still fails (a model not checked at the end of the
previous period, e.g. `history.learn = false`) goes through the same rules; a revert there
rewrites the record of the previous period, and kept shares are the shares of that
period. `res.learning` therefore holds the beliefs actually in force (reverted ones
included) and `n1_model` the model shares in force (kept ones included) over the forecast
and the inversion, which `hetlearn.decompose` uses; `n1`/`n2` remain the discrete-choice
shares. Over the RE-smoothed history `n1_model` stays NaN (no model is simulated there);
the kept shares are carried in the state, so the next check and the forecast's first
period use them.

Gain processes (`gain.rule = 'koz'`) update from FE_t whatever the facility does (sec.
18); the facility never touches `S.gain`. Order in `update_learning`: errors from
phi_{t-1}; `rule('gain', ...)`; RLS candidates; PLM blocks; ALM check; `rule('update',
...)`.

Events (`res.events`, `events.csv`, with a `stage` column: history, inversion, forecast):
`projection_plm`, `projection_alm`, `projection_alm_shares`, `explosive`, `rls_missing` (missing data, that
equation keeps its beliefs), `shares_nan` (non-finite shares, previous fitness and shares
kept), `gain_bound` (sec. 18). `res.meta.history_alm_check_s`, `.history_alm_n_check`,
`.history_alm_n_solve` measure the history-stage check; `res.meta.forecast_n_solve` the
forecast solves. Tests: `tests/test_facility.m`.

### 4.5 Switching (IJCB eqs. 14-15)
Forecast errors are 1-step-ahead errors of the forecasts made in t-1 (both types):

    FE^RE_t = sum_{v in G} (v_t - x_exp1_RE_{v,t-1})^2
    FE^BR_t = sum_{v in G} (v_t - x_exp1_BR_{v,t-1})^2
    zeta^i_t = -(1 - omega) FE^i_t + omega zeta^i_{t-1}
    n1_t = exp(chi zeta^RE_t) / (exp(chi zeta^RE_t) + exp(chi zeta^BR_t)),   n2_t = 1 - n1_t

G is the share group: `shares.structure = 'per_variable'` -> one group per learning
variable, G = {x}; `'universal'` -> one group for all learning variables, G =
`shares.master` (one variable name; a cellstr sums the squared errors, as the IJCB paper
does for inflation and the output gap). Computed in a numerically stable form. The
squared errors enter unscaled (switching error scaling was removed on 2026-10-18). chi =
0.51 by default, IJCB's estimate on quarterly data, the units of SW07 (user decision
2026-10-18; it was 8 = 0.51 x 16 on the wrong reading that IJCB's data are annualised).
Initial fitness: zeta^RE_0 = 0 and zeta^BR_0 set so that n2_0 = `shares.init_n2`.

### 4.6 Expectation modes (`cfg.expectations.mode`)
| mode | n2 for learning variables | shares updated | beliefs updated |
|---|---|---|---|
| `'rational'` | 0 | no (fitness tracked as a diagnostic) | per `beliefs.update` (diagnostic only) |
| `'learning'` | 1 | no | per `beliefs.update` |
| `'fixed_shares'` | `shares.fixed_n2` (scalar or per variable) | no | per `beliefs.update` |
| `'switching'` | endogenous, sec. 4.5 | yes | per `beliefs.update` |

Variables not in `cfg.expectations.variables` are pure RE (`br_x = false`). `'all'` selects
every forward-looking variable. In `'rational'` mode the learning variables keep their
`br_x = true` blocks with n1 = 1, so the RE scenario has the same model structure as the
learning scenarios it is compared with (the collapse test in 3.4 makes this exact RE).

### 4.7 Belief initialisation (`cfg.beliefs.init`)
- `method = 're_moments'` (default, as in IJCB sec. 3.1): phi_0 = E[z z']^{-1} E[z v] and
  R_0 = E[z z'], from the unconditional moments of the RE model (`acf`, with the steady
  state supplying the means).
- `method = 'training_ols'`: OLS on the RE-smoothed history over `init.training_range`;
  R_0 = sample second-moment matrix.
- `method = 'user'`: `init.values.<x>.alpha`, `.beta` (or `.phi` vector), optional `.R`;
  anything missing falls back to `re_moments`.
- `init.date`: the period whose beliefs these are (they are phi_{t-1} for t = init.date: they
  make the BR forecast in init.date, and the first RLS update uses the data of init.date).
  With `history.learn = true` (default) the beliefs then evolve endogenously over the
  history up to the forecast origin. With `history.learn = false` the initial beliefs and
  shares apply directly at the origin (phi_origin = initial beliefs, no update at the origin).

## 5. Engine

### 5.1 RE benchmark filter (cached per model + data hash)
The extended model with all chosen `br_x = true`, n1 = 1 (= the RE model) is run through
the IRIS Kalman filter/smoother over `spec.filter_range` (with `expectations.re_info =
'lagged'`: the RE(t-1) model of the scenario's learning set, plus the one-step
predictions, sec. 19). Output: smoothed paths of every
variable (including `x_exp1_RE`, i.e. the RE agents' forecast at each date) and smoothed
shocks. Check: the observables rebuilt from the smoothed states and shocks through the
measurement equations (`lhsmrhs`, data on the left) reproduce the data (max abs error
< 1e-8 when there are at least as many shocks as observables). Comparing the smoothed
observables themselves is vacuous: IRIS copies the data into them.

As built 2026-10-19: one call `filter(m, d, range, 'output', 'filter,smooth', 'meanOnly',
true)` gives both databanks, `H.smooth` (two-sided, x_{t|T}) and `H.filtered` (one-sided,
x_{t|t}: data up to t). In IRIS 20230622 (`model/filter`, `hdataobj.hdatafinal`) two
requested outputs come back as a struct with fields `.filter` and `.smooth`; one output is the
databank itself. The smoothed output is identical with or without the filter output (SW07:
max diff 0). The filtered series have no presample lag rows and start one period before the
range. Observed measurement variables equal the data in both. Where every observable is
missing (SW07 2020Q1-Q3) the filtered value is the one-step prediction and the filtered
shocks are 0. The cache key is unchanged. A cache without `H.filtered` (written before
2026-10-19) is filtered again and rewritten under the same name the first time it is read.

### 5.2 History stage (`history.mode = 're_smoother'`)
Learning states are run over [init.date, origin] on the RE-smoothed history. For
t = init.date .. origin:
1. realised v_t: smoothed value; f^RE_t = smoothed x_exp1_RE_t; f^BR_t = E(x,1) evaluated
   numerically with beliefs phi_{t-1} and data up to t-1 (same recursion as 4.2);
2. FE_t from f_{t-1}; fitness, shares n_t (4.5);
3. RLS update -> phi_t (4.3), projection facility (4.4).
The history itself does not depend on the learning states; agents learn while watching the
RE-smoothed economy. Future option (not implemented): `history.mode = 'hetero_filter'`,
a time-varying Kalman filter in which the heterogeneous model is solved every period and
beliefs are updated on the filtered states (IJCB App. D).

**RE states: `history.re_states` (as built 2026-10-19).** `'smoothed'` (default) is the loop
above. The smoothed `x_exp1_RE_t` is the RE forecast from states estimated with data after t,
which gives the RE agents hindsight in the fitness race. `'filtered'` takes every value of the
loop from `H.filtered` instead (`hetlearn.engine.history_db`): f^RE_t = filtered `x_exp1_RE_t`
= E_t x_{t+1} from s_{t|t}, the learners' data, and the realised v_t in both fitness errors,
so the loop is one-sided. Under `'filtered'`:
- f^RE_t equals the Kalman filter's one-step prediction x_{t+1|t} of the RE model, and FE^RE_t
  is the squared one-step prediction error.
- An observed variable has filtered = smoothed = data (SW07 inflation outside 2020Q1-Q3). The
  option moves f^RE everywhere, since it depends on unobserved states. On SW07 the largest
  |filtered - smoothed| of `pinf_exp1_RE` per decade (% per quarter) falls from 0.12 in the
  1960s to 0.01 in the 2010s, then reaches 0.07 in 2020Q4, after the data gap. It moves the
  learners' data only where observations are missing.
- In a quarter without data the filtered value is the RE prediction, so FE^RE_t = 0 there.
- `history.learn = false` takes f^i at the origin from the same databank, and so does
  `beliefs.init.method = 'training_ols'`.
- The forecast stage still starts from the smoothed state at the origin (`build_shocks`), and
  the RE run is unchanged.
- `history.realtime` is orthogonal. The filtered values up to the origin do not depend on later
  data, so the history loop is the same with or without it; realtime only clips the smoother
  at the origin and moves the forecast's starting state. `'filtered'` with
  `history.realtime = true` is the fully real-time setup.
- `'inversion'` is one-sided already, so `'filtered'` with it is an error
  (`hetlearn:options:value`). A silently ignored option would give a run equal to the
  `'smoothed'` one.
- Densities, decompositions, the Ramsey continuation and `hetlearn.evaluate` need no change.
  They start from the history's end state, or run `hetlearn.run` with filters that carry both
  databanks. Their own uses of `H.smooth` (shock pools, the forecast databank) are not
  learners' information.

Tests: `tests/test_re_states.m`.

### 5.3 Forecast / scenario stage
For t = origin+1 .. origin+H:
1. Set `alpha_x, beta_x, ...` from phi_{t-1}; `n1_x = n1_{t-1}` (mode-dependent, 4.6);
   `n2_x = 1 - n1_x`.
2. `solve` (and `sstate` if the model is nonlinear). Projection facility on failure (4.4).
3. Simulate one period, t:t, from the databank holding history up to t-1 (the RE-smoothed
   history up to the origin, the scenario's own simulated values after), with this
   period's shocks (5.4) and conditions (5.5). All shocks and conditions are
   unanticipated: each period is a new linear simulation.
4. Store every variable at t. f^RE_t = x_exp1_RE_t and f^BR_t = x_exp1_BR_t.
5. FE_t, fitness, shares n_t; RLS update phi_t; projection facility.

With mode `'rational'` the result equals one IRIS `simulate` of the RE model over the whole
horizon (unanticipated shocks). This is a regression test.

### 5.4 Shocks over the forecast horizon (`cfg.shocks`)
- `source = 'none'` (default): zero shocks.
- `source = 'smoothed'`: the RE-smoothed shocks (5.1) over `shocks.range` (default: the
  forecast horizon). `shocks.exclude = {...}` zeroes some of them.
- `shocks.add = {{name, dates, values}, ...}`: added on top.
With `source = 'smoothed'` and mode `'rational'` from the smoothed state, the scenario
reproduces the data (regression test).

### 5.5 Conditions: exogenise/endogenise pairs (`cfg.conditions`)
Each condition is a struct: `variable`, `shock`, `dates`, `values`, `type`
(`'level'` | `'delta'`), `reference` (`'self'` = the same scenario run without any
conditions | a scenario id). `variable` may be a transition or a measurement variable.
In each period the engine solves for the endogenised shocks that put the exogenised
variables on target. Because each one-period simulation is linear in the shocks, the
engine builds the response matrix by unit-shock simulations and solves the linear system
(exactly determined: solve; more shocks than targets: minimum-norm; fewer: error).
Checked against IRIS `Plan` exogenize/endogenize in a test. As built (review finding m10,
2026-10-18): the minimum norm is taken in units of each shock's standard deviation,
delta = S pinv(M S) gap with S = diag(`std_<shock>`) (`engine.conditions_weighting =
'std'`, default; `'none'` = unweighted pinv); the exactly determined case is unchanged.
For `'delta'`, the engine first runs the reference and sets target = reference path + delta.

## 6. Scenario files and options

### 6.1 Precedence
`hetlearn.defaults()` < `config/master_options.m` < scenario file. Unknown field names are
an error (catches typos). The full merged options are saved with every result.

### 6.2 Scenario file
A function in `scenarios/<model>/` returning `cfg`. Inheriting from another scenario is a
plain function call:

```matlab
function cfg = sw07_peak_switch_pinf()
cfg = sw07_peak_re();                      % start from the RE scenario
cfg.id = 'sw07_peak_switch_pinf';
cfg.title = 'Peak-inflation forecast, switching on inflation';
cfg.expectations.mode = 'switching';
cfg.expectations.variables = {'pinf'};
cfg.compare_with = {'sw07_peak_re'};
end
```

### 6.3 Option tree (defaults in brackets)
```
id, title, description, model (model folder name, e.g. 'sw07')
model_params               [''] = spec.params, or the name of a parameter function (.m file) in the
                           package folder, e.g. 'sw07_params_original' (2026-10-20; checked by load_model)
forecast.origin            date (last period of data used)
forecast.horizon           [16]
expectations.mode          ['rational'] | 'learning' | 'fixed_shares' | 'switching'
expectations.variables     [{}] cellstr or 'all'
expectations.re_variant    ['anchored'] | 'model_consistent'  (sec. 11; anchored default since 2026-10-18)
expectations.re_info       ['current'] | 'lagged'  (RE expectations of the learning set E_{t-1} x_{t+1}, sec. 19)
beliefs.update             ['rls'] | 'fixed'
beliefs.info               ['lagged'] | 'current'  (BR information set, sec. 4.2)
beliefs.plm.default        ['ar1'] | 'ar2' | 'ar1_noconst' | 'var1';  beliefs.plm.by_var.<x>  (sec. 12)
beliefs.plm.derived.<name> linear expression in model variables  (sec. 12)
beliefs.plm.var            variables [{}] (cellstr | 'learning'), lags [1], constant [true]  (sec. 12)
beliefs.init.method        ['re_moments'] | 'training_ols' | 'user'
beliefs.init.date          [first filter date + 4]
beliefs.init.values        struct
beliefs.init.training_range
gain.rule                  ['constant'] | 'koz' (sec. 18);  gain.value [0.0585];  gain.by_var.<x>
gain.koz                   mu [0.001], gamma0 [[] = gain.value], Rg0 [0], bounds [[0.001 0.25]],
                           error ['rls'] | 'forecast', error_scale [1],
                           structure ['common'] | 'per_variable', master ['' = first learning variable]
shares.structure           ['per_variable'] | 'universal'
shares.master              name or cellstr (universal only)
shares.init_n2             [0.5]
shares.fixed_n2            scalar or struct by variable
switching.rule             ['discrete_choice']
switching.intensity        chi [0.51]  (IJCB estimate, quarterly data; user decision 2026-10-18, was 8;
                           calibration set live in config/master_options.m, sources there)
switching.memory           omega [0.6]
projection.facility        ['plm_alm'] | 'alm' | 'none'  (sec. 4.4; the only stabilising device)
                           removed 2026-10-18 (error hetlearn:options:removed): projection.max_root,
                           .on_failure, .method, .scope; switching.error_scale, .error_scale_ref
engine.step                ['fast'] | 'iris';  engine.conditions_weighting ['std'] | 'none'
history.learn              [true]
history.mode               ['re_smoother'] | 'inversion'  (sec. 15) | 'kalman'  (time-varying Kalman
                           filter of the ALM, one-step prediction errors; DESIGN_br_extensions 5)
history.re_states          ['smoothed'] | 'filtered'  (sec. 5.2; 're_smoother' only)
history.inversion          start [[] = beliefs.init.date], shocks [{} = every transition shock]
history.kalman.init        ['stochastic'] (asymptotic distribution, as IRIS) | 'smoothed' (P0 = 0 at
                           the RE-smoothed state before the start); 'kalman' only
history.realtime           [false]  (RE filter on data up to the origin, sec. 17; 're_smoother' only)
shocks.source              ['none'] | 'smoothed';  shocks.range [[] = horizon];  shocks.exclude [{}];  shocks.add [{}]
conditions                 struct array (5.5); replaced as a whole
density                    enabled [false], shocks [{}], sigma ['calibrated'] | 'smoothed',
                           sigma_range [[] = filter range], method ['normal'] | 'bootstrap',
                           demean [true], ndraws [200], seed [0],
                           quantiles [0.05 0.16 0.5 0.84 0.95], range [[] = horizon],
                           keep_draws [false], fast_path [true]  (sec. 14)
policy                     mode ['rule'] | 'ramsey', type ['commitment'] | 'discretion',
                           loss [pinf 1, ygap 0.5, r 0.1, dr 0; replaced as a whole],
                           discount [[] = spec.policy.discount],
                           loss_horizon [[] = forecast.horizon]  (sec. 13)
compare_with               [{}] cellstr of scenario ids
report.variables           [{}]  reserved; not read by the toolbox
expectations.types, expectations.transforms, shares.init, shares.fixed
                           [empty] BR options, replaced as a whole (DESIGN_br_extensions 1.1-1.3)
```
The user-facing version of this tree, with meanings and recipes, is `docs/USER_GUIDE.md` sec. 5.

## 7. Public API
```
hetlearn.defaults()                  default option tree
hetlearn.load_options(cfg)           merge defaults < master < cfg, validate
hetlearn.extend_model(spec, plm)     generator (sec. 3)
hetlearn.load_model(spec, cfg)       generate if needed, load with toggles, assign, solve
hetlearn.re_filter(spec, cfg)        RE benchmark filter (5.1), cached
hetlearn.run(cfg)                    full scenario run, saves results/<id>/
                                     (call options 'save', 'results_dir', 'quiet')
hetlearn.run_files(list)             batch, returns a summary table
hetlearn.compare(ids, vars, range)   comparison tables (levels and differences)
hetlearn.find_peak(db, name, from, to)   helper for origins
hetlearn.load_spec(name), hetlearn.load_database(spec)   package and data readers
hetlearn.decompose(res|id, vars, range, opts)   shock decomposition (sec. 16)
hetlearn.evaluate(name, variants, origins, opts)   recursive real-time evaluation (sec. 17)
hetlearn.evaluate_tables(errors, opts)   metrics, relative RMSE and DM from an error table,
                                     an errors_long.csv file or an eval_<name> folder
hetlearn.re_anchor_coefficients(spec, P)   anchored-RE coefficients (sec. 11; 're_info', 'lagged': sec. 19)
```
Engine stages are in `toolbox/+hetlearn/+engine/` (`core`, `state_init`, `history`,
`forecast`, `step`, `update_learning`, `shares_for_mode`, `build_shocks`,
`conditions_prepare`, `record`, `assemble`, `save_results`).

## 8. Tests (`tests/`)
Toy model: 3-equation hybrid NK (IJCB eq. 1) with an extra 2-step lead, written with mixed
lead notations (`tests/toy_nk/`). `tests/run_tests.m` runs 19 suites (257 checks on
2026-10-18, track G; 293 on 2026-10-19 with `test_re_info`, whose test models are in
`tests/models/`); `run_tests({'suite', ...})` runs a subset, because the whole run
exceeds one 9-minute batch call. The tests do not read `scenarios/` or `results/`: SW07
runs use the test scenarios `tests/scenarios/tsw07_*.m` (calibration written out), and
the stored reference for the 2026-10-18 defaults is `tests/reference/tsw07_switch_pinf_iris.mat`
(made by `tests/scenarios/make_reference.m`; compared by test_gain G14, test_info I5,
test_inversion S3b). Internal pins stay: fast step = IRIS step, collapse tests, RE = IRIS
simulate, conditions = IRIS Plan, inversion = smoother.

| Suite | Covers |
|---|---|
| `test_options` | merge order, unknown names, enumerations, cross-field rules |
| `test_rls`, `test_switching`, `test_plm` | RLS against a hand-coded loop and OLS; eqs. 14-15; PLM systems and forecasts |
| `test_generator` | notations, comments, `x{+2}` recursion, `!if` branches with `spec.assign`, collapse tests |
| `test_engine` | period-by-period RE = IRIS simulate; conditions = IRIS Plan; fully-BR forecasts = PLM formula; non-circular timing (FE from the paths, E11); weighted shocks (E12); toy switching run = stored toy reference with `re_variant` pinned `'model_consistent'` (E9) |
| `test_sw07` | SW07 collapse test, smoothed-shock replay = data, template scenarios |
| `test_density`, `test_evaluate` | draws, seeds, fast path = general path, quantiles; DM kernels, real-time filters |
| `test_anchored`, `test_plm2` | anchored RE, backward simulator; VAR learning, derived regressors, AR(2) |
| `test_inversion`, `test_decompose` | RE inversion = smoother, real time by construction; decomposition = IRIS, path reconstruction, `'tv'` with the beliefs in force after the facility (C6) |
| `test_ramsey` | optimal policy against IRIS, loss accounting, multipliers at the origin |
| `test_info` | `beliefs.info = 'current'`: forecasts = IRIS `x_exp1_BR`, timing assert, unchanged RLS |
| `test_gain` | endogenous gain: recursion = a hand-coded loop, mu = 0 = constant gain bit for bit, bounds and events, signed-error behaviour, `'common'` vs `'per_variable'`, `'rls'` vs `'forecast'` errors, the gain state through history, inversion, evaluation, density and Ramsey; SW07 smoke run |
| `test_facility` | projection facility (sec. 4.4): AR(1) block rule under each value, one explosive block among several and order independence, block detection, unstable ALM reverts every belief, history-stage ALM check, model shares kept when reverting the beliefs is not enough (F10: the run completes, `n1_model` kept while `n1` moves, `'tv'` rebuilds the paths), `almUnstable` (no earlier solved model) and `noSolution` errors, the explosive no-lead path under `'none'`, KOZ gain at revert periods, which stages solve |
| `test_re_states` | `history.re_states` (sec. 5.2): default = pre-change run, filtered databank, f^RE = IRIS prediction, covid gap, realtime orthogonal, `history.learn = false`, `training_ols` |
| `test_re_info` | `expectations.re_info` (sec. 19): options; SW07 RE(t-1) model = hand-written IRIS reference and Dynare `EXPECTATION(-1)`; closed form; n1 = 1 collapse; end-to-end runs (f^RE = independent two-step forecasts) and every stage; default files and runs unchanged |

## 9. Outputs (`results/<id>/`)
- `results.mat`: `cfg` (merged), `paths` (databank, history + horizon, all variables incl.
  observables; `x_exp1_BR` over the history = the BR agents' history-stage forecasts),
  `learning` (per PLM target incl. auxiliary PLMs: belief paths by parameter name, R
  diagonal, gain; learning variables also n1, n2 (shares at the end of t), n1_model (share
  in the model in t), zeta, own squared FE, f^RE, f^BR), `events` (table), `meta`
  (timestamps, IRIS version, hashes, runtime).
- `observables.csv`, `paths.csv` (transition variables, horizon), `learning.csv` (long),
  `events.csv`; `compare_<id>.csv` for each `compare_with` entry (differences of the
  observables over the horizon). Dates as text, e.g. `2022Q3`.
- `loss.csv` (and `res.loss`) for every run of a package with `spec.policy` (sec. 13);
  `density.mat`, `density_quantiles.csv`, `density_events.csv` with `density.enabled`
  (sec. 14); `decomposition.csv` after `hetlearn.decompose` (sec. 16).
- `hetlearn.evaluate` writes `results/eval_<name>/` (sec. 17).
- Share names: options give the BR share (`init_n2`, `fixed_n2`); the model has `n1_<x>`
  (RE) and `n2_<x>` (BR); results hold `n1`, `n2` (discrete-choice shares at the end of t)
  and `n1_model` (RE share in the model in t); summary CSVs and density outputs use
  `n2_model` = 1 - `n1_model`.

## 10. Reporting conventions
Model units: growth rates and inflation in percent quarter on quarter, `robs` in percent per
quarter, `labobs` in 100 x log deviation. Reports show growth, inflation and the policy rate
annualised (x4), hours as is. Labels and transformations come from `spec.report`.

---------------------------------------------------------------------------------------

# Part II: extensions (specified 2026-10-17)

Requested by the user after the first report: an anchored RE variant, Ramsey policy,
density forecasts, history backed out with the learning model, shock decompositions,
recursive forecast evaluation, more PLMs, and (after a review round) an endogenous gain.
Every new option goes into `docs/FEATURES.md` (Origin `asked` unless it goes beyond the
request, then `ADDED` with a reason).

## 11. RE variants (`expectations.re_variant`)
- Default since 2026-10-18 (user decision): `'anchored'`, the baseline of the toolbox;
  `'model_consistent'` is the alternative. Tests that check the model-consistent variant
  pin it (`re_variant = 'model_consistent'`).
- `'model_consistent'` (sec. 4.1): `x_exp1_RE = x{+1}` in the heterogeneous
  economy; the model is re-solved every period given the current beliefs and shares.
- `'anchored'` (default; IJCB sec. 2.3.1): RE agents use the forecast of the pure-RE model,
  evaluated at the current state of the heterogeneous economy:
  `x_exp1_RE_t = k_x + sum_j c_{x,j} s_{j,t}`, where `s_t` is the predetermined
  (backward-looking) state vector of the original RE model in IRIS's solution (current
  values of variables that appear with lags, IRIS auxiliary lags such as `y{-1}`, the
  exogenous processes), and `E_t x_{t+1} = k_x + c_x' s_t` on the RE solution. The
  coefficients are computed by the toolbox from the RE solution (from `sspace`/`xVector`,
  checked against unit-perturbation simulations) and enter the model as parameters named
  `are_<x>__<v>` (current), `are_<x>__<v>_l<k>` (lag k) and `are_<x>__const`. They are
  recomputed whenever the RE model's parameters change.
- Generator: inside each `!if br_x` block, `!if re_anchored` selects the anchored
  equation, `!else` keeps `x_exp1_RE = x{+1}`. `re_anchored` is a global model-file toggle
  set from the option. One generated file serves both variants.
- Collapse test (3.4) is extended: with `re_anchored = true` and every `n1 = 1`, the
  extended model reproduces the RE model's IRFs (< 1e-10).
- Existence: when every forward-looking variable is a learning variable, the anchored
  model has no leads, so a solution exists for any beliefs and shares, possibly explosive.
  IRIS `solve` rejects explosive solutions even in purely backward models (NO_STABLE;
  tested 2026-10-17), so the engine then simulates with its own backward recursion from
  the first-order system matrices (`system(m)`), `hetlearn.engine.backward_simulate`, and
  logs an `explosive` event with the largest root. As built 2026-10-18: this is the
  `projection.facility = 'none'` case; under `'alm'` and `'plm_alm'` a backward root above
  1 is an unstable ALM (sec. 4.4: beliefs reverted, then the previous model shares kept;
  `hetlearn:engine:almUnstable` only without an earlier solved model). If
  leads remain (some forward-looking variable is not learning) and `solve` fails, the
  projection facility of 4.4 applies.
  The backward simulator must equal IRIS `simulate` whenever IRIS has a solution (test).
  As built (2026-10-18): the trigger is the active model, not the learning list:
  `get(m,'maxLead') = 0` and a linear model. A variable with a lead of 2 or more keeps
  `x_exp2 = x_exp1{+1}` (3.2), so such a model keeps leads even when every variable learns
  (the toy `nk3` with `pie{+2}`; SW07 has only 1-step leads). `solve_model` stores the
  backward system in the IRIS model's user data and reports success; `step` simulates
  with it and returns the `explosive` event, which `forecast` appends (two-line change
  there). The state vector is IRIS's `xbVector`, which also holds measured variables
  without lags (their coefficients are 0).
- History under `re_smoother` is the same for both variants (the RE-smoothed path
  satisfies both). As built, the RE filter model carries the `re_anchored` toggle of the
  scenario (own cache file); the smoothed history equals the model-consistent one to
  1e-13 (toy test).
- With `expectations.re_info = 'lagged'` both variants use information up to t-1; the
  anchored coefficients then come from the RE(t-1) model of the learning set (sec. 19).

## 12. More perceived laws of motion (`beliefs.plm`)
- `'ar2'`: univariate AR(2) with constant (exists; verify on SW07).
- Per-variable regressors (exists): `beliefs.plm.by_var.<x>.regressors = {'pinf{-1}', ...}`,
  `.constant`.
- Derived regressors (new): `beliefs.plm.derived.<name> = '<linear expression in
  current-dated model variables>'`, e.g. `derived.ygap = 'y - yf'`. The generator adds a
  transition variable `<name>` with equation `<name> = <expr>;` (outside every toggle;
  a name collision is an error). Derived variables can be regressors at any lag >= 1 and
  get auxiliary PLMs like any other regressor. As built: the expression may use declared
  names, numbers, + - * / and parentheses only (no subscripts or functions) and must
  reference a transition variable; derived variables may also be VAR members.
- VAR learning (new): `beliefs.plm.var = struct('variables', <cellstr | 'learning'>,
  'lags', 1, 'constant', true)`. Every variable in the set gets the PLM equation
  `v_t = alpha_v + sum_{u in set} sum_{l=1..p} beta_{v,u,l} u_{t-l}`; learning variables in
  the set use it for their expectations, other members are auxiliary equations of the same
  VAR. Shorthand `beliefs.plm.default = 'var1'` = VAR(1) over the learning set. A `by_var`
  entry for a VAR member is an error. The BR forecast is the VAR's own two-step forecast
  (the recursion of 4.2). RLS equation by equation (common regressors, so identical to
  system RLS); projection facility on the VAR companion; initial beliefs from RE moments.
  As built: `hetlearn.load_model` resolves `'learning'` and `'var1'` to the scenario's
  learning variables before calling the generator (which gives every forward-looking
  variable a primary PLM), so the generated file depends on the learning set; regressors
  are ordered lag first, then members in the order given.

## 13. Ramsey policy (`policy.*`)
- `policy.mode = 'rule'` (default) | `'ramsey'`; `policy.type = 'commitment'` (default) |
  `'discretion'`; `policy.loss` = weights by target name; `policy.discount` (default from
  the spec).
- Model spec: `spec.policy.instrument` (`'r'`), `spec.policy.rule_label` (label of the
  rule equation to switch off), `spec.policy.targets` (struct of target expressions; SW07:
  `pinf: 4*pinf`, `ygap: y - yf`, `r: 4*r`, `dr: 4*(r - r{-1})`), `spec.policy.discount`.
- Generator: the rule equation is wrapped in `!if ~ramsey ... !else
  min(<discount>) sum_k w_<k>*(<target_k>)^2; !end`, weights `w_<k>` declared as
  parameters. Loaded with `Model.fromFile(..., 'optimal', {'type', <type>})`.
- IRIS fix: the optimal-policy parser of IRIS 20230622 fails on MATLAB R2025a (non-scalar
  colon operand in `model.Insertable/insert`). The toolbox ships a shadow copy
  `toolbox/iris_patches/+model/Insertable.m` (`where = where(1)`) that `setup_paths` puts
  ahead of IRIS. The IRIS installation is not modified. Tested 2026-10-17: the commitment
  targeting rule pi_t + (lambda/kappa)(y_t - y_{t-1}) = 0 holds to 2e-15 on a 3-equation
  NK model; discretion gives pi_t + (lambda/kappa) y_t = 0 to 4e-15.
- Timing: the history is always the rule-based RE filter (the estimated model). The Ramsey
  model applies from the forecast origin; Lagrange multipliers (IRIS `Mu_Eq<k>`) start at
  zero at the origin (the plan starts there) and their lags are carried forward. With
  learning, the planner treats the current PLM coefficients and shares as permanent
  (anticipated utility), re-optimises every period and honours past multipliers.
- Loss accounting: every scenario reports the discounted loss over the horizon,
  `sum_h discount^h sum_k w_k target_k^2`, with the scenario's weights (rule scenarios use
  `policy.loss` too, so rule and Ramsey runs can be compared with the same weights).
- As built (2026-10-18, generator version 3; `hetlearn.policy.*`):
  - The wrap is `!if ramsey <loss>; !else <rule> !end` (same as above). The discount is
    written as `(1 - ramsey_disc_on)*(<spec discount>) + ramsey_disc_on*ramsey_disc`, so
    `policy.discount` (a number) needs no new file. `ramsey_disc_on` and `ramsey_disc` are
    declared with the `w_<k>` in a trailing parameter block. IRIS accepts
    `$cbetabar$*$cgamma$` (0.997561 at swX1). The reference file is never wrapped and the
    collapse test runs with `ramsey = false`. A missing label sets `meta.policy.ok =
    false` and is an error only for mode `'ramsey'`. Without `spec.policy` the output is
    unchanged (SW07 file identical to version 2).
  - `policy.loss` replaces the default struct (it is not merged); targets not named get
    weight 0.
  - The loader solves the rule model first and keeps it in `info.policy.rule_model`. The
    RE-moment initial beliefs and the error scales come from the rule model, so the
    history and the origin state equal those of the rule run. `re_filter` always loads
    mode `'rule'`, and when it is passed a Ramsey model (`hetlearn.evaluate`) it filters
    with that model's rule model. Anchored RE uses the coefficients of the rule-based RE
    model: anchored agents keep the estimated reduced form.
  - The multipliers enter the RE history as zero series (`hetlearn.policy.prepare` in
    `run`); `hetlearn.policy.forecast_setup` (called from `forecast`) sets them to 0 at
    and before the origin.
  - The generator finds the rule-only names: rule variables used only in their own law
    of motion, and shocks used only in those equations (SW07 `ms`, `em`; toy `e_r`).
    Shocks or conditions on them run with no effect, with one warning per run.
    Conditions whose endogenised shocks are all rule shocks keep only their rule-only
    targets.
  - `res.loss` (`hetlearn.policy.loss`) holds the total, the contribution of each target,
    per-period values and the discount, and is also written to `loss.csv`. When
    `policy.loss_horizon` > H, the loss is evaluated on a continuation of the scenario
    from `res.state`: zero shocks, no conditions, learning on. In the toy, this equals a
    200-quarter forecast to 1e-10.
  - Discretion in IRIS (leads taken as given) is indeterminate (MULTIPLE_STABLE) at some
    parameter points: the toy at base parameters with an `r` weight, any learning
    variable at the RE point (n1 = 1, zero beliefs, where `load_model` solves), and SW07
    RE. Interior shares do solve. Commitment solves in every case tested. On the
    textbook toy the discretion rule holds to 2.5e-16.

## 14. Density forecasts (`density.*`)
- `density.enabled` (false), `density.shocks` (cellstr, required), `density.sigma =
  'calibrated'` (model std) | `'smoothed'` (sample std of the RE-smoothed shocks over
  `density.sigma_range`, default the filter range), `density.method = 'normal'` |
  `'bootstrap'` (resample whole dates of the RE-smoothed shocks jointly), `density.ndraws`
  (200), `density.seed` (0), `density.quantiles` ([0.05 0.16 0.5 0.84 0.95]),
  `density.range` (default the horizon), `density.keep_draws` (false).
- Draws are added on top of the scenario's own shocks and conditions, unanticipated.
  Each draw is a full period-by-period run from the same origin state (history computed
  once). For a constant model (mode `'rational'` with no conditions) one linear simulation
  per draw may be used; it must equal the general path (test).
- Outputs in `results/<id>/`: `density.mat` (quantiles and mean of every observable and of
  n2, alpha, beta per learning variable; draws if kept), `density_quantiles.csv` (long),
  `density_events.csv` (per draw: `draw, status`, the event counts in the fixed order
  `projection_plm, projection_alm, projection_alm_shares, explosive_events, rls_missing,
  shares_nan, gain_bound`,
  then `max_abs, message`; columns since 2026-10-18). Draws that
  explode (any |value| > 1e6) are excluded from the quantiles and counted; a draw the
  facility stops (`almUnstable`, `noSolution`) is an `'error'` draw with its message.
- As built (2026-10-18): `hetlearn.engine.core` returns a forecast-stage bundle F (origin
  state, starting databank, conditions, model); `hetlearn.density.run` adds each draw to
  the scenario's shocks at `density.range` (dates outside the horizon ignored) and calls
  `hetlearn.engine.forecast` from F with the point forecast's period-1 solve reused
  (`fopt.warm`). Conditions keep their targets, so endogenised shocks offset draws on the
  same shock. Fast path (`density.fast_path`, default true): one IRIS simulate per draw,
  learning diagnostics replayed on the simulated path (= general path, test). Random
  numbers from `RandStream('mt19937ar', 'Seed', seed)` draw by draw (global stream
  untouched). Bootstrap draws are demeaned over `sigma_range` unless `density.demean =
false` (B2, 2026-10-18); `density.sigma` is then unused. Draws whose
  forecast stage errors count as `'error'` and are excluded too. Quantiles: own helper
  `hetlearn.density.quantile`, same definition as the Statistics Toolbox default. Summarised
  series: observables, `n2_model_<x>` and the PLM coefficients of each learning variable
  (q, mean, std, point; report units x `spec.report.scale`). `density.mat` holds variable
  `density`; the mean is not in the CSV. `res.density` is in memory only (not in
  `results.mat`); a run without density deletes old density files of that id. SW07
  (2026-10-18): 0.07 s per draw (fast path), 0.6-0.8 s per draw (general path, 16 periods).

## 15. History backed out with the learning model (`history.mode = 'inversion'`)
- Symmetric to forecasts: the history is simulated one period at a time with the learning
  model, exogenising every observable at its data value and endogenising
  `history.inversion.shocks` (default: every transition shock; at least as many as
  observables, minimum norm if more). Same step as a forecast period (5.3) with these
  conditions: beliefs and shares in the model, solve (projection facility, sec. 4.4), solve
  for the shocks, then fitness, shares and RLS from the model's own `x_exp1_RE` / `x_exp1_BR`.
- `history.inversion.start` (default `beliefs.init.date`); state before the start from the
  RE smoother; learning states from `beliefs.init`.
- Outputs: the backed-out history (all variables and shocks) and learning paths over
  [start, origin]; the forecast starts from this history.
- Check: mode `'rational'` inversion from the smoothed state reproduces the RE-smoothed
  shocks (report the max difference over the sample; target < 1e-8).
- As built (2026-10-18): the loop is in `hetlearn.engine.history` and calls
  `hetlearn.engine.step` (observables with data at t as targets) and
  `hetlearn.engine.update_learning`; solves go through `hetlearn.engine.facility`, shared
  with `hetlearn.engine.forecast` (since 2026-10-18). A start after
  `beliefs.init.date` first runs the 5.2 learning on the smoothed history up to start-1;
  a start before it, or `history.learn = false`, is an error. Data come from the RE
  filter's `H.data`. Ramsey scenarios back out the history with `info.policy.rule_model`
  (untested). `res.inversion` holds the parameter values in the model each period
  (`params`, `param_names`), observable misses, the distance of the shocks and paths from
  the smoothed ones, solves and runtime. `res.meta.history_mode`, `res.meta.engine_step`.
  Checks: toy RE inversion = smoothed shocks to 7e-14; SW07 1966Q1-2026Q2 (242 quarters)
  to 2.1e-13 (paths 4.4e-12), flat over the decades, so rounding does not grow (no
  invertibility problem with 7 shocks for 7 observables). Runtime with `engine.step =
  'fast'` (the default): 6.5-7 s (RE), 5-9 s (switching on pinf); with `'iris'` each period
  costs about 0.25 s (9 simulations): 77 s for the RE inversion (same 2.1e-13). These SW07
  figures predate the covid treatment (2026-10-19: every observable NaN in 2020Q1-Q3). The
  inversion has nothing to exogenise in those quarters, so it now equals the RE smoother only
  up to 2019Q4; `test_inversion` S1 checks the shocks there (below 1e-8).
- Evaluation (17): one inversion per variant to the last origin on the full-sample RE
  filter (it only supplies the state before the start), state kept at every origin
  (`ctx.inv_snapshots`); each forecast starts from it (`ctx.history_cache` of
  `hetlearn.engine.core`). Self references of delta conditions reuse the history.
- Engine step (B2): `engine.step = 'fast'` simulates each period from the state-space
  solution (`sspace(m, 'triangular', false)`, cached in the model's user data at each
  successful solve) with the exact response matrix for conditions; = IRIS to rounding
  (1e-14 per period). Default `'fast'` since 2026-10-18 (review finding s2): not
  bit-identical to `'iris'` (8.9e-16 on the toy reference of test_engine E9; 1.5e-12 on
  `sw07_peak_switch_pinf`), so the bit-identity tests use 1e-10 and test_inversion S3b
  pins `'iris'` = `results/` exactly.

## 16. Shock decomposition (`hetlearn.decompose`)
- `D = hetlearn.decompose(res, vars, range, opts)`; default vars `{'pinfobs', 'dy'}` as
  deviations from their RE steady state.
- RE: IRIS contributions (`simulate(..., 'contributions', true)`) from the start of the
  history: one component per shock plus initial conditions.
- Learning (inversion history): time-varying linear decomposition with the realised model
  of each period: component paths `x^c_t = Phi_t(x^c_{t-1}, eps^c_t)` without constants
  (one-period simulate with `'deviation', true`), c in {each shock, initial conditions};
  "beliefs and constants" = total deviation minus the sum of the components (the
  time-varying intercepts and their propagation). Additive by construction; on the RE
  model it must equal the IRIS decomposition (test).
- `opts.groups` (struct of shock groups); output long CSV (scenario, date, variable,
  component, value, report units).
- As built (2026-10-18): `opts.method = 'auto'` uses IRIS for mode `'rational'` and the
  time-varying (`'tv'`) decomposition otherwise. The `'tv'` periods use the state-space
  matrices of each period's solution directly (the deviation form of the one-period
  simulate, without constants; the backward system when IRIS has none) instead of one
  simulate per component. The model in force: the RE model before the learning model
  applies (the RE-smoothed history), `res.inversion.params` over the inversion, and over
  the forecast horizon phi_{t-1} and `n1_model(t)` from `res.learning`, which records the
  beliefs in force after the projection facility, reverted ones included (sec. 4.4; test
  C6). The decomposition starts at the first date with initial
  conditions in `res.paths`; the RE steady state is computed from the RE model's
  state-space solution. Components: each shock (model order) or group, `init`,
  `beliefs_constants`; the CSV (`results/<id>/decomposition.csv`) adds `total` rows and
  has columns `value_model`, `value_report`. Checks: RE `'tv'` = IRIS (toy 1.2e-13, SW07
  2e-13); the period matrices with constants rebuild the paths (SW07 8.5e-13). Ramsey
  results are rejected for now. SW07 2019Q1-2026Q2: 0.6-1.8 s (IRIS), 3-5 s (`'tv'`,
  242 solves).
- Review fixes (m12, 2026-10-18): the `allow_partial` option and the partial-update code
  were removed with partial updates (track G). The CSV gains a last column `label` ('intercept channel
  (perceived means)' for `beliefs_constants`, model-file shock labels); ids unchanged.
  Reading: slope beliefs and shares act inside every shock component through each
  period's transition matrices; `beliefs_constants` is the intercept channel only.

## 17. Recursive forecast evaluation (`hetlearn.evaluate`)
- `E = hetlearn.evaluate(name, variants, origins, opts)`: variants = scenario function
  names; for each variant and origin the scenario is run with that origin, horizon
  `opts.horizon` (default 8) and zero future shocks.
- Real-time information: with `history.mode = 're_smoother'` the RE filter and smoother
  are rerun on data truncated at the origin (cached per origin, shared across variants);
  with `'inversion'` one full-sample inversion is real time by construction and each
  forecast starts from its state at the origin. Parameters stay at the full-sample
  estimates.
- Errors `actual - forecast` in report units for every observable and h = 1..H; metrics by
  variant, variable and horizon: RMSE, mean error (bias), MAE, n; relative RMSE against
  `opts.benchmark` (default the first variant); Diebold-Mariano test with Newey-West
  variance (`opts.dm`, default true).
- Outputs in `results/eval_<name>/`: `errors_long.csv`, `metrics.csv`,
  `relative_rmse.csv`, `dm.csv`, `settings.mat`.
- As built (2026-10-18): option `history.realtime` (default false; `evaluate` sets it
  through `opts.realtime`, default true) makes `hetlearn.run` call `hetlearn.re_filter(...,
  'end', origin)`: every database series clipped at the origin, filter over [filter start,
  origin], cache `generated/refilter_rt_<date>_<hash>.mat` with the hash over the clipped
  data. Each variant gets zero shocks, no conditions, density off and no comparisons;
  its model is loaded once and every origin's filter is computed once and passed to
  `hetlearn.run` (`'model'`, `'filter'` call options). Targets without data are skipped.
  Relative RMSE and DM use the targets both variants have; DM loss differential
  `e_variant^2 - e_benchmark^2`, h-1 autocovariances; kernel `opts.dm_kernel` (review
  finding m2, 2026-10-18): `'uniform'` gamma_0 + 2 sum_{k<h} gamma_k (the rectangular
  estimator for which HLN derived their factor; default when `dm_hln` is true; Bartlett
  fallback where it is not positive, `kernel` column `bartlett_fallback`) or `'bartlett'`
  weights `1 - k/h` (default without `dm_hln`); with `opts.dm_hln` (default
  true, B2) the Harvey-Leybourne-Newbold factor sqrt((n + 1 - 2h + h(h-1)/n)/n) and
  t(n-1) p-values, else p = `erfc(|DM|/sqrt(2))`. The tables come from
  `hetlearn.evaluate_tables(errors, opts)`, which also rebuilds them from a saved
  `errors_long.csv` (+ `settings.mat`) without re-running forecasts. `opts.subsamples` are target-date ranges
  (`sample` column). Inversion variants: see 15 (as built). Findings: on the toy, data changed after the origin move the full-sample
  forecast by only ~3e-14 (later data uninformative there; the test uses data changed AT
  the origin as its control); on SW07 the real-time filter moves the 8-quarter forecasts
  by up to 0.12-0.18 pp annualised (inflation, growth, policy rate; origins 2010Q1,
  2015Q1, 2020Q1). SW07 2010Q1-2024Q2, H = 8, 2 variants: 116 runs in about 90 s.
- With `history.re_states = 'filtered'` (5.2) the real-time filters supply `H.filtered`
  as well. The variant's history loop is then the same as on the full-sample filter, and
  the real-time part is the forecast's starting state.

## 18. Endogenous gain (`gain.rule = 'koz'`, as built 2026-10-18)
Kostyshyna, Özden and Zhang (2024, Bank of Canada SWP 2024-14), eq. (9), the adaptive
step-size algorithm of Kostyshyna (2012). For each gain process, after x_t is realised:

    gamma_t = P[ gamma_{t-1} + mu * Rg_{t-1} * FE_t ]
    Rg_t    = (1 - gamma_{t-1}) * Rg_{t-1} + FE_t

P projects onto `gain.koz.bounds`. The RLS update at the end of t (sec. 4.3; their eq. 8)
uses g = gamma_{t-1}.

**Timing in `hetlearn.engine.update_learning`, period t.** (1) Errors from phi_{t-1}: the
residual of every PLM equation and the signed BR error x_t - f^BR_{t-1}. (2) `g =
rule('gain', S.gain, errors, opts.gain)`. (3) RLS and the projection facility. (4) A separate
block, `[S.gain, ev] = rule('update', S.gain, errors, opts.gain)`, whatever the facility did
with the candidates: the error is observed either way, so a reverted belief update does not
revert the gain. With `beliefs.update = 'fixed'` the gain is frozen.

**Interface.** Every rule answers four calls: `'fields'` (extra series it records),
`'init'`, `'gain'` and `'update'`. Its state lives in `S.gain`, so every stage that carries
the learning state (history, inversion, forecast, density draws, evaluation origins, the
Ramsey continuation) carries the gain. `'constant'` keeps its old two-argument form too.

**Options and the choices behind them** (each flagged in FEATURES):
- Signed error: the paper's text says the gain rises when errors keep their sign and falls
  when they alternate, which squared errors cannot do.
- `gain.koz.error`: `'rls'` (default), the PLM's one-step residual v_t - phi_{t-1}' z_{t-1},
  the error of the RLS update itself; or `'forecast'`, the BR agents' expectation error
  x_t - f^BR_{t-1} (a two-step error under `beliefs.info = 'lagged'`; auxiliary equations
  use their residual).
- `gain.koz.bounds` [0.001 0.25]: Kostyshyna (2012) projects the gain onto an interval; KOZ
  give none. A `gain_bound` event is logged in each period a bound binds; Rg is not
  projected.
- `gain.koz.error_scale` [1]: mu is scale dependent, and FE enters both equations, so mu
  effectively scales with error_scale squared. The round 1-2 SW07 KOZ scenarios used 4
  (quarterly to annualised percent, the units assumption behind the old chi = 8, which
  the user withdrew on 2026-10-18: IJCB's data are quarterly, chi = 0.51).
- `gain.koz.structure`: `'common'` (default; KOZ footnote 7, one process for every PLM
  equation, driven by the error of `gain.koz.master`, default the first learning variable; a
  list = the mean of the scaled errors) or `'per_variable'` (one process per PLM equation,
  auxiliary ones included, each driven by its own error).
- `gain.koz.Rg0` [0]: the derivative of the initial estimate with respect to the gain; the
  paper is silent. `gain.koz.gamma0` [[] = `gain.value`]; `gain.koz.mu` [0.001], >= 0
  (mu = 0 reproduces the constant gain bit for bit).
- KOZ Table 1's "R0 = 0.001" is the initial RLS moment matrix (0.001 x I), not Rg_0. It needs
  no new option: `beliefs.init.method = 'user'` with only `beliefs.init.values.<x>.R` set
  keeps the RE-moment phi and replaces R.

**Outputs.** `gain` (the gamma used in t) and `gain_R` (Rg_t) per PLM equation in
`res.learning.<x>` and `learning.csv`; `gain_bound` events; the final state in
`res.state.gain`. Constant-gain runs record no `gain_R`. Tests: `tests/test_gain.m`.

## 19. RE information set (`expectations.re_info`, as built 2026-10-19)

User request 2026-10-19: the learners have a t and a t-1 information set (`beliefs.info`),
but the RE fixed point uses period-t information only; add an RE version with t-1
information.

**Definition.** `'current'` (default, unchanged): the RE expectation of a learning
variable x is E_t x_{t+1}. `'lagged'`: it is E_{t-1} x_{t+1}, formed with information up
to t-1, for every x in the learning set (`expectations.variables`). Expectations of the
other variables stay E_t. This is the RE counterpart of `beliefs.info = 'lagged'`: the
forecast made in t of x_{t+1} uses information up to t-1, so the RE agents' fitness error
FE^RE_t = (x_t - f^RE_{t-1})^2 is a two-step-ahead error, like the lagged learners'. In a
lagged scenario every RE object refers to the RE(t-1) model of its learning set: the
original model with E_{t-1} x_{t+1} in place of E_t x_{t+1} for the learning set, solved
as an RE fixed point with t-1 information. That model is the RE benchmark (mode
`'rational'`), the anchored RE agents' model, the RE filter and smoother of the history,
and the source of the RE-moment initial beliefs (the loaded model at n1 = 1).

**Construction.** `hetlearn.extend_model(spec, plm, 're_info', 'lagged')` writes its own
file, `generated/<name>_ext_<plmtag>_relag.model` with `_relag_meta.mat` (generator
version 5; meta fields `re_info`, `re_chain`, `collapse_lagged_sets`). The default files
keep version 4 and are byte-identical to the pre-change output (test T6a). The lagged file
equals the default one except inside each `!if br_x` block:

```
x_exp1 = n1_x*x_exp1_RE + n2_x*x_exp1_BR;
!if re_anchored
    x_exp1_RE = are_x__const + sum_j are_x__<s_j>*s_j{-1};    % every state one period earlier
!else
    x_exp1_RE = x_REt2{-1};
    x_REt2 = x_REt1{+1};
    x_REt1 = x{+1};
!end
```

x_REt1_t = E_t x_{t+1} and x_REt2_t = E_t x_REt1_{t+1} = E_t x_{t+2}, so x_exp1_RE_t =
x_REt2_{t-1} = E_{t-1} x_{t+1}; the chain variables are declared under `!if
~re_anchored`. IRIS 20230622 accepts `x{+2}` directly, but it then adds a lead element
`x{1}` to the transition vector, which the fast step cannot read; the chain keeps every
lead at +1 (the closed-form test T3 matches to 6e-16). With mode
`'model_consistent'`, x_REt2 comes from the heterogeneous model in force at t-1, so
x_exp1_RE_t is the forecast the RE agents made at t-1 under anticipated utility, and it
is predetermined in t. A learning variable with a lead of 2 or more is an error under
`'lagged'` (`hetlearn:load_model:reInfo`): its `x_exp2 = x_exp1{+1}` would keep period-t
information.

**Anchored RE agents with t-1 information (derivation).** Write the solution of the RE(t-1)
model (the model-consistent lagged model at n1 = 1, zero beliefs) as [xf; xb]_t = T xb_{t-1}
+ K + R e_t, with xb = (s, z): s the original model's states (`meta.re_states`, the same
names as for `'current'`; they keep their lag structure) and z the chain states, z_{x,t} =
x_REt2_t (one per learning variable). Iterating two periods from the state at t-1,

    E_{t-1} x_{t+1} = K_x + T_x (K_b + T_b xb_{t-1}) = k_x + C_s(x,:) s_{t-1} + C_z(x,:) z_{t-1},

which holds for any xb_{t-1}. The RE agents evaluate it at the heterogeneous economy's
state at t-1. The original states map by name: the economy's own variables at t-1, with
auxiliary lags one period further back. The chain state z_{t-1} = E_{t-1} x_{t+1} is the RE
agents' own forecast formed with information up to t-1, and in the heterogeneous economy
that object is x_exp1_RE_t itself. Stacking the learning set, f_t = k + C_s s_{t-1} + C_z
f_t, so

    x_exp1_RE_t = (I - C_z)^{-1} (k + C_s s_{t-1}),

a linear function of predetermined variables dated t-1 and earlier, with nothing the
heterogeneous model does not have. On the RE(t-1) path the date-(t-1) equation z_{t-1} =
E_{t-1} x_{t+1} is the same fixed point, so the anchored model at n1 = 1 is the RE(t-1)
model: the anchored and model-consistent lagged models agree at n1 = 1 (SW07 {pinf}
4.5e-13, every lead-1 variable learning 7.6e-14, toy 1.7e-14). SW07 {pinf}: C_z = 0.139
(the agents' own lagged forecast enters x_t's equations and through them x_{t+1}); in the
closed-form test model C_z = 0. Other states of the lagged model (PLM lags, derived
regressors) carry zero coefficients at n1 = 1 (checked, error above 1e-12); a singular
I - C_z is an error.

- `hetlearn.re_anchor_coefficients(spec, P, 're_info', 'lagged', 'model', mMC, 'vars',
  learnVars, 'states', meta.re_states, 'chain', meta.re_chain)` returns the values of the
  same `are_x__*` parameters (0 for variables outside the learning set), checked against
  two-period unit-perturbation simulations of mMC (SW07 2e-16). `hetlearn.load_model`
  loads mMC (the lagged file with `re_anchored = false`, n1 = 1) for every anchored lagged
  scenario, since the coefficients depend on the learning set, and checks the IRFs of the
  anchored and model-consistent models against each other (< 1e-10;
  `info.re_info_check`).
- Alternative, not built (for the user to decide): map z_{t-1} to the aggregate
  expectation that entered the economy, x_exp1_t = n1 x_exp1_RE_t + n2 x_exp1_BR_t. With one
  learning variable, x_exp1_RE_t = (k + C_s s_{t-1} + C_z n2 x_exp1_BR_t) / (1 - C_z n1):
  the RE agents would then know and use the learners' forecast in their own. Both versions
  coincide at n2 = 0. Mapping z_{t-1} to x_exp1_RE_{t-1} (a forecast of x_t, not x_{t+1})
  would mismatch the forecast target.

**Collapse test of a lagged file** (`collapse_test_lagged` in `extend_model`; n1 = 1, zero
beliefs, IRFs of every original variable to every shock, 40 periods, < 1e-10): (1) every
br = false reproduces the original model (`collapse_maxdiff(2)`; SW07 3.4e-13); (2) every
forward-looking variable with max lead 1 learning, `re_anchored = false`: the RE(t-1) model
of that set must solve (SW07: all 12, determinate); (3) the same with `re_anchored = true`
reproduces (2) (`collapse_maxdiff(3)`); (4) (2) with `br_info_current = true` reproduces (2)
(`collapse_info_maxdiff`). `collapse_maxdiff(1)` is NaN (with lagged RE information the
extended model differs from the original by construction). If (2) has no unique stable
solution for the whole set, (2)-(4) run one variable at a time.

**RE history (5.1-5.2).** `hetlearn.re_filter` keeps the scenario's learning set for a
lagged scenario (not `'all'`: the RE(t-1) model depends on it) with the scenario's
`re_variant`; the cache key changes through the `_relag` model text and the assign struct
(learning-set toggles), so the default caches are untouched. The same filter call also
returns the one-step predictions x_{t|t-1} (`'output', 'pred,filter,smooth'`; `H.predicted`,
lagged caches only). f^RE_t in the history is the RE agents' forecast made in t of x_{t+1}
with information up to t-1:
- `'smoothed'`: H.smooth.x_exp1_RE(t) = E_{t-1} x_{t+1} at the smoothed state at t-1 (the
  smoothed path satisfies the model, so this equals the two-step forecast from s_{t-1|T};
  test 8.4e-13 against the hand-written reference).
- `'filtered'`: H.predicted.x_exp1_RE(t) = E[x_exp1_RE_t | data to t-1] = E[x_{t+1} | data to
  t-1] (x_exp1_RE_t is a function of the t-1 state), the filter's two-step prediction of
  x_{t+1} (test 5.1e-13 against IRIS `'ahead', 2` on the reference). H.filtered.x_exp1_RE(t)
  would use data dated t. The learners' data and the realised values stay x_{t|t}
  (`hetlearn.engine.history_db`).
- `history.realtime`: unchanged logic (filter on data to the origin); the 'filtered' history
  is the same with or without it (test 0).
The forecast starts from the smoothed state at the origin, so x_exp1_RE in the first
forecast quarter is the smoothed value (predetermined, test 8e-15).

**Stages.** Supported with `'lagged'` (each covered by `tests/test_re_info.m`): every mode,
both `re_variant` values, both `beliefs.info` values, both `history.re_states`,
`history.realtime`, `history.mode = 'inversion'` (the RE inversion reproduces the lagged
RE-smoothed shocks), `history.learn = false` (f^RE from the same databank), conditions,
`hetlearn.decompose` (IRIS and `'tv'`), densities (fast path = general path),
`hetlearn.evaluate` (a lagged variant gets its own real-time filters: the filter group key
adds `re_info`, the learning set and `re_variant`; default variants keep the PLM-key
grouping), the projection facility and the endogenous gain (model-independent). Blocked:
`policy.mode = 'ramsey'` with `'lagged'` (`hetlearn:options:unsupported` in
`load_options`): the Ramsey plan with predetermined RE expectations, and the anchored
variant under it (already an open design question, see sec. 13 and the README), has not
been derived or tested. Also errors: `'lagged'` with an empty learning set
(`hetlearn:options:value`) and learning variables with leads of 2 or more.

Tests: `tests/test_re_info.m` (T0 options; T1 hand-written IRIS reference
`tests/models/sw07_re_lagged_pinf.model`; T2 Dynare 4.6.1 with `EXPECTATION(-1)(pinf(+1))`,
`tests/models/dynare/`, stored IRFs `tests/reference/re_info_dynare_irfs.mat`; T3 closed
form `tests/models/nkpc/`; T4 n1 = 1 collapse; T5 end-to-end runs and stages; T6 defaults
unchanged).
