# Bounded-rationality extensions: design

Design for adding the bounded-rationality rules 1, 4, 5, 6, 7, 10, 17, 18, 19, 20, 23, 24, 25,
26 (aggregate), 27, 29 (reduced form), 31 (approximate) and 33 of
`docs/lit_review/reports/Bounded rationality expectation rules.md` to hetlearn, and for the IRF
and in-sample RMSE portfolios that compare them with the baseline. Written 2026-10-20. Design
only: no toolbox, model, scenario, test or result file was changed. Formulas marked *derived* are
ours; every other value cites its source (the review and its research notes hold the links).

Notation. SW07 in deviations from steady state, % per quarter. `s_t`: the 25 predetermined states
of the original model (`meta.re_states`). `f^k_t`: type k's forecast of `x_{t+1}` made in t. With
t-1 information it uses data dated t-1 or earlier. `h` = target date minus information date
(h = 1 for `E_t x_{t+1}`, h = 2 for `E_{t-1} x_{t+1}`). Baseline (`config/master_options.m`):
published SW07 mode, learning set `{pinf}`, types {RE anchored with `re_info = 'lagged'`, AR(1)
learner with `beliefs.info = 'lagged'`}, KOZ gain from 0.05, chi 2, memory 0.8, init n2 0.5,
`history.re_states = 'filtered'`, `projection.facility = 'none'` (`'alm'` since 2026-10-21, user decision).

**Note 2026-10-22 (user decision after the audit `docs/BR_audit.txt`): the portfolio is cut to seven
variants, 5b, 7, 10, 19, 23, 24 and 26.** The other fourteen (1a, 1b, 4, 5a, 6, 17, 18, 20, 25a, 25b,
27, 29, 31, 33) are dropped, and so is every option and code path that only they used. Section 8 lists
what was removed and why. Sections 1-7 below are the design as built on 2026-10-20/21; headings and
table rows of dropped mechanisms are marked "[dropped 2026-10-22]".

Prototype evidence (scratchpad `br_design/`, run on a copy of the project; the scripts
`br_proto1.m` to `br_proto4.m` and their logs are listed at the end) is quoted where it settles
a design choice.

---------------------------------------------------------------------------------------------

## 1. Architecture

Five extensions cover all 18 mechanisms, plus one engine feature for the RMSE portfolio (E6).
Each one generalises a piece that exists today, and each is off by default.

| # | Extension | Generalises | Mechanisms |
|---|---|---|---|
| E1 | N agent types: a list of type objects (rule, information timing, share group) | the fixed pair `x_exp1_RE`, `x_exp1_BR` | 1, 17, 18, 19, 23, 25b, 27, 33 (and every other variant runs through it) |
| E2 | N-type shares: multinomial logit per share group, with inertia, type costs and a fitness-normalisation switch, or fixed shares | `hetlearn.switching.discrete_choice` (two types) | 1, 17, 18, 19, 25b, 27 |
| E3 | Forecast-transform layer: multiplier with a horizon profile, diagnostic difference, myopia and anchoring, partial adjustment, additive wedge with its own AR(1) and shock; scope = learning set, every forward expectation, or named equations | nothing (expectations are used as formed today) | 4, 5, 6, 7, 10, 18, 29, 31 |
| E4 | Generalised anchor: anchored coefficients of `E_{t-j} z_{t+h}` for any variable, any j in {0, 1, 2}, h >= 1, computed from any solved "anchor economy", including per quarter | `hetlearn.re_anchor_coefficients` (pure-RE model, j in {0, 1}, h = 1) | 1 (T-map), 10 (reference forecast), 23 (RE slopes), 33 (expected real growth), 31 (loadings) |
| E5 | New PLM, update and gain rules: SAC update, Kalman-filter (KF) learning, intercept-on-RE PLM, decreasing gain, mean-only PLM | `beliefs.update = 'rls'`, `gain.rule`, `beliefs.plm` | 17 (LAA), 20, 23, 24, 25, 26 |
| E6 | `history.mode = 'kalman'`: time-varying Kalman filter of each variant's ALM | the RE filter and the inversion history | RMSE portfolio (section 5) |

### 1.1 E1: N agent types

A learning variable's aggregate expectation becomes

    x_exp1 = sum_k n_{g(x),k} * T_k( x_exp1_<k> )          (shares from the end of t-1, as now)

where k runs over the types that forecast x, `g(x)` is the share group of x and `T_k` the
transforms applied to type k (E3; identity by default). A type is one struct of the new option
`expectations.types`:

| Field | Values | Meaning |
|---|---|---|
| `name` | identifier (`'RE'`, `'BR'`, `'L1'`, `'ADA'`, ...) | suffix of the generated forecast `x_exp1_<name>` and of the share `n_<name>_x` |
| `kind` | `'re'`, `'plm'`, `'rule'`, `'level'`, `'re_mean'` | anchored or model-consistent RE (as `x_exp1_RE` today); a learned PLM (as `x_exp1_BR`); a fixed linear rule; level k on another type (E4); RE forecast plus a learned mean of its own error (E5) |
| `variant`, `info` | `'anchored'`/`'model_consistent'`; `'lagged'`/`'current'` | `[]` = `expectations.re_variant` / `re_info` for `'re'`, `'level'`, `'re_mean'`; `beliefs.info` for the others |
| `plm`, `update`, `gain` | `beliefs.plm` subtree; `'rls'`, `'sac'`, `'kf'`, `'fixed'`; `gain` subtree | `[]` = the global `beliefs.plm`, `beliefs.update`, `gain` |
| `rule` | `struct('expr', 'c1*x{-1} + c2*self{-1}', 'params', struct('c1', 0.65, 'c2', 0.35))` | `'rule'` only. `x` = the variable, `self` = this type's own forecast, lags >= 1 under `'lagged'` information. Named terms: `dn` (nominal growth `y - y{-1} + pinf`), `mean` (a mean-only belief of this type), `re1(...)` (anchored E_{t-1} of a linear expression, E4); see 17 and 33 |
| `base`, `k` | type name, integer >= 1 | `'level'` only |
| `variables` | cellstr | learning variables this type forecasts (`[]` = all); defines the share groups for mixed sets (18) |
| `cost` | number (0) | Brock-Hommes cost C_k in the fitness |

Defaults. With `expectations.types` empty (the default), the toolbox builds the two types of
today, `RE` (`kind 're'`) and `BR` (`kind 'plm'`), and takes the **existing code path unchanged**
(`make_block`, `make_block_lagged`, `discrete_choice`): generated files and results stay
bit-identical (regression test in 1.7). Writing the same two types out explicitly takes the new
path and must agree to 1e-12.

The RE type is always generated. A population without RE agents (1a, 17, 18, 20, 25) gives it
a fixed share of 0; its RE limit (n_RE = 1) is still the RE filter model of the history stage and
the anchor for level and FN types. `info` and `variant` may differ by variable: in 18 the RE type
of c is current and model-consistent while that of pinf is the baseline's t-1 anchored one, so the
RE(t-1) chain of DESIGN 19 is written only for variables whose RE type is lagged (today
`re_info = 'lagged'` applies to the whole learning set).

Mode semantics with N types: `'rational'` = share 1 on the (single) `'re'` type; `'learning'`
= share 1 on the single non-RE type of each group (error otherwise); `'fixed_shares'` = the new
`shares.fixed` (struct by type name; `shares.fixed_n2` stays as the two-type shorthand);
`'switching'` = E2.

Generated text (new writer `make_block_ntype`, generator version 6; the default files stay at
versions 4 and 5): per learning variable x and type k a transition variable `x_exp1_<k>` with its
equation, the share parameters `n_<k>_x`, the type's own parameters (PLM coefficients
`alpha_x__<k>`, `beta_x__<k>`; rule constants; level coefficients `lev<k>_x__<state>`), and the
aggregate line above. A rule with `self{-1}` (ADA) is a backward equation in its own lag. The
`!if br_x` toggle and the `re_anchored` / `br_info_current` toggles keep their meaning.

### 1.2 E2: shares over N types

For share group g with types k = 1..N_g:

    U_{k,t} = omega * U_{k,t-1} - c_norm * FE_{k,t},   c_norm = 1 - omega ('normalized', today) or 1 ('unnormalized', Anufriev-Hommes)
    n_{k,t} = delta * n_{k,t-1} + (1 - delta) * exp(chi*(U_{k,t} - C_k)) / sum_j exp(chi*(U_{j,t} - C_j))

computed with log-sum-exp. New options: `switching.inertia` delta [0], `switching.costs` (struct
by type) [0], `switching.fitness` [`'normalized'`] | `'unnormalized'`, `shares.init` (struct by
type; `[]` = `init_n2` for the default pair, equal shares otherwise). Initial fitness: chosen so
that the logit returns `shares.init` (generalising `init_fitness`). Share groups keep
`shares.structure` (`'per_variable'` / `'universal'`); a group's types are those whose
`variables` include the group's variables. New function `hetlearn.switching.discrete_choice_n`;
for N = 2, delta = 0, C = 0, `'normalized'` the engine keeps calling the current
`discrete_choice` (bit-identity). Translation of published intensities: with memory omega,
`chi_normalized = beta_unnormalized / (1 - omega)`, so Anufriev-Hommes' beta 0.4 at eta 0.7 is a
normalised chi of 1.33 (the baseline uses 2); the units of the squared errors still differ (lab
prices against % per quarter).

### 1.3 E3: forecast-transform layer

New option `expectations.transforms`, a struct array; each entry has `kind`, `types` (`'all'`
or type names; `'all'` also covers the model-consistent expectations of variables outside the
learning set), `scope` and parameters:

| kind | Transform of a base forecast f with horizon h | Parameters |
|---|---|---|
| `'multiplier'` | `D(h)*f`, `D(h)` = m^h (`profile 'geometric'`), lambda (`'flat'`), 1/(1+alpha*h) (`'hyperbolic'`) | `value` |
| `'diagnostic'` | `(1+theta)*f - theta*f_ref`, f_ref = the same type's forecast of the same target made one period earlier | `value` theta |
| `'myopia_anchoring'` | `omega_f*f + b*x_{t-1}` | `value` [omega_f, b] |
| `'partial_adjustment'` | `g*f + (1-g)*self_{t-1}` | `value` g |
| `'wedge'` | `f + w_t`, `w_t = mu + lambda_x*xi_t`, `xi_t = rho*xi_{t-1} + sigma*e_xi,t` | `factor` struct: `rho`, `std`, `mean`, `loadings` (struct by variable), `shock` (new shock name) |

`scope`: `'learning'` (the learning set), `'all'` (every forward-looking variable; `exclude`
removes some, e.g. the flex block), a cellstr of variables, or equation-specific entries
`'pinf@Phillips curve, price setting'` (exact equation label, as `spec.policy.rule_label`).

Where the transform goes in the generated text:
- learning variable x: inside the aggregation, `n_k_x * T_k(x_exp1_<k>)`; a wedge on all types
  can equivalently be added once after aggregation (shares sum to 1);
- variable outside the learning set: `x_exp1 = T(x{+1})`, a transform of the model-consistent
  expectation, which is Gabaix's and LSY's construction;
- equation-specific scope: the generator writes a copy `x_exp1__<tag>` (tag from the label) and
  rewrites `x{+1}` in that equation only. This needs the equation of each occurrence; the
  generator already locates equations by label for the Ramsey wrap (`find_rule`), and the
  occurrence list `occ` carries positions.

Diagnostic references in generated text (all *derived*): model-consistent `f_ref` =
`x_REt2{-1}` with the existing chain (`x_REt1 = x{+1}`, `x_REt2 = x_REt1{+1}`), one more chain
element when the base is already t-1 dated; anchored `f_ref` = a generated auxiliary
`x_DEg_<k> = (anchored E_{t-1} x_{t+2})` read at `{-1}` (E4, h = 3 from the t-1 information
date), so the reference is the forecast actually formed last quarter; learned types: an
auxiliary carrying last quarter's PLM forecast of `x_{t+1}` (three-step), read at `{-1}`.

Wedge: the generator declares `xi_<name>` (transition variable) and the shock; `std_<shock>`
comes from the transform, not from the package's parameter file. Loadings are numbers, or
`'model:<rule>'` computed once at load time from the variant's RE limit (E4).

Anchor model with transforms (decision D11): anchored RE coefficients come from the variant's own
RE limit (the generated file at n_RE = 1, model-consistent), so transforms on the other
expectations are part of what anchored agents know, the collapse test "anchored = model-
consistent at n_RE = 1" of DESIGN 19 still holds, and mode `'rational'` is the variant's RE
benchmark. Wedge processes are switched off in that anchor model (anchored agents do not foresee
belief shocks).

### 1.4 E4: generalised anchor

`hetlearn.anchor_coefficients(m_a, vars, states, 'lag', j, 'horizon', h, 'chain', ...)` returns
`k`, `C` with `E_{t-j} z_{t+h} = k + C s_{t-j}` in the solved economy `m_a`, from
`sspace(m_a, 'triangular', false)`: `C = T_z T_b^(j+h-1)`, `k` the matching sum of constants
(*derived*), the chain-state fixed point of DESIGN 19 when `m_a` is a model-consistent lagged
model, an error when the forecast loads on a state outside `states` (> 1e-12, as
`lagged_coefficients`), and the unit-perturbation check. `re_anchor_coefficients` becomes a
wrapper (j = 0 or 1, h = 1, `m_a` = pure-RE or RE(t-1) model) and stays bit-identical.

Per-quarter use (level-k). New engine step `hetlearn.engine.anchor_update(ctx, m, S)` runs after
the belief update and before the ALM check: for j = 0..K-1 it solves the level-j economy (the
extended model with share 1 on level j: on the base type for j = 0, on `L<j>` otherwise; all
other expectations model-consistent), computes `lev<j+1>` coefficients with j = 1 (t-1
information), and stores them in `S.levels` so `facility('params')` assigns them. K extra IRIS
solves per quarter (3 ms each on SW07, prototype P2). With t-1 information there is no
simultaneity: the level-(j+1) forecast is the two-step forecast of the level-j economy from
`s_{t-1}` (the review's `F_{j+1} = H_j^2`, `a_{j+1} = (I + H_j)c_j` in IRIS form).

Prototype P3 (2019Q4 baseline beliefs, alpha -0.274, beta 0.317): the T-map of the anchored RE(t-1)
economy returns its own coefficients to 1.0e-14 (the "level 0 = RE gives RE at every level" gate).
Levels on the learned level 0 converge slowly in the intercept and fast in the slope:

| level | 0 (AR(1)) | 1 | 2 | 3 | 5 | RE |
|---|---|---|---|---|---|---|
| constant | -0.362 | -0.362 | -0.353 | -0.339 | -0.306 | 0 |
| coefficient on pinf_{t-1} | 0.101 | 0.077 | 0.070 | 0.069 | 0.070 | 0.065 |

So in SW07 a level-k reasoner keeps most of the learners' perceived mean and switches to
RE-like dynamics.

### 1.5 E5: new PLM, update and gain rules

| Rule | Where | Recursion |
|---|---|---|
| `beliefs.update = 'sac'` | new `+rls/sac.m` | constant-gain SAC on (mean a, autocorrelation b, variance R): `a_t = a_{t-1} + k(x_t - a_{t-1})`; `R_t = R_{t-1} + k((x_t - a_{t-1})^2 - R_{t-1})`; `b_t = b_{t-1} + k R_t^{-1}[(x_t - a_{t-1})(x_{t-1} - a_{t-1}) - b_{t-1}(x_t - a_{t-1})^2]` (HMOZ eq. 2.8 with 1/(t+1) -> k, finite-sample terms dropped), b clipped to [-1, 1] with a `sac_bound` event. Maps onto the existing AR(1) parameters `alpha = a(1-b)`, `beta = b`, so the generated text does not change (forecast `a + b^2 (x_{t-1} - a)`) |
| `beliefs.update = 'kf'` | new `+rls/kf.m` | coefficients a random walk: predicted `P = P_prev + V`, `phi_t = phi_{t-1} + P z (z'Pz + s2)^{-1} e_t`, updated `P = P - P z (z'Pz + s2)^{-1} z'P`; `V = gamma^2/(1-gamma) * s2 * R0^{-1}`, the constant-gain-equivalent choice (*derived*, scalar steady state gain = gamma), `s2` = the PLM residual variance at the RE moments, `P_0 = gamma * s2 * R0^{-1}` |
| `kind 're_mean'` | generator + `+plm` | target `z_t = x_t - x_exp1_RE_{t-1}` (generated variable), PLM `z_t = abar` (mean only), forecast `x_exp1_IO = x_exp1_RE + abar` |
| mean-only PLM | exists | `beliefs.plm.by_var.<x> = struct('regressors', {{}}, 'constant', true)`: forecast `alpha`; check that `forecast_expr` handles no regressors |
| `gain.rule = 'decreasing'` | new `+gain/decreasing.m` | `g_t = 1/(t - t0 + n0)` (n0 = 1): sample-mean learning for the LAA anchor |

All rules use t-1 information by default and keep the model conditionally linear (HMOZ's
argument), so E6 applies unchanged.

### 1.6 What changes where

| File | Change |
|---|---|
| `defaults.m`, `load_options.m` | new subtrees `expectations.types`, `expectations.transforms`; `switching.inertia`, `.costs`, `.fitness`; `shares.init`, `shares.fixed`; `beliefs.update` values `'sac'`, `'kf'` and `beliefs.kf.*`; `gain.rule = 'decreasing'`; `history.mode = 'kalman'`, `history.kalman.init`; validation and errors (`hetlearn:options:types`, `:transforms`) |
| `extend_model.m` | `make_block_ntype` (types, transforms, equation copies, wedge states and shocks, level and DE auxiliaries); occurrence-to-equation map for equation scope; plmtag key covers types and transforms; collapse tests: every transform at its identity value and n_RE = 1 reproduce the variant's RE limit |
| `load_model.m` | type and transform parameters; anchored, level, DE-reference, FN and loading coefficients through E4; per-type PLM systems (`build_system` per learner type, names suffixed `__<type>`) |
| `re_anchor_coefficients.m` | wrapper over the new `anchor_coefficients.m` |
| `+engine/state_init.m`, `update_learning.m`, `shares_for_mode.m`, `facility.m` (`params`, PLM blocks per learner type), `record.m`, `assemble.m`, `save_results.m`, `history_db.m` | N types: beliefs, gains and fitness per type, share vectors, per-type forecasts read from `x_exp1_<k>` (timing assert per learner type), outputs `n_<k>`, `f_<k>`, `FE_<k>`, `U_<k>` |
| `+engine/forecast.m`, `history.m` | read N forecasts; call `anchor_update` when level types exist. On the RE-smoothed history nothing is simulated, so each type's forecast is evaluated on the history databank: PLM types as today (`forecast_value`), rule types from their expression, level and `re_mean` types from their coefficients at the filtered states (the `H.predicted` convention of `history_db` for t-1 types) |
| new | `+switching/discrete_choice_n.m`, `anchor_coefficients.m`, `+engine/anchor_update.m`, `+engine/kalman_history.m`, `+rls/sac.m`, `+rls/kf.m`, `+gain/decreasing.m` |
| later (phase 6) | `decompose.m`, `+density/*`, `evaluate.m`, `+policy/*`: N types, or an explicit `hetlearn:options:unsupported` (done 2026-10-21: density, evaluate and decompose take N types, Ramsey and the inversion are refused; "P6 done" in section 6) |

### 1.7 Regression test

New suite `tests/test_br_regression.m`, references frozen from the current code before phase 1
(`tests/reference/br_freeze.mat`, made by `tests/scenarios/make_br_freeze.m`):
- R1: the default and `_relag` generated SW07 and toy files are byte-identical (MD5) to the
  frozen ones.
- R2: `tsw07_peak_re`, `tsw07_switch_pinf`, the baseline `a1_learn`/`a1_re` and the 2019Q4 IRF
  runs of section 4 equal the frozen results (max diff 0 with `engine.step = 'iris'`, <= 1e-12
  with `'fast'`); `tests/reference/tsw07_switch_pinf_iris.mat` and `_fast.mat` still pass.
- R3: the baseline written in N-type syntax (types RE and BR spelled out) equals the legacy run
  to <= 1e-12 (paths, shares, beliefs, gains, events).
- R4: every transform at its identity value (m = 1, theta = 0, omega_f = 1 and b = 0, wedge std
  0) equals the baseline to <= 1e-12.
- All 19 existing suites (296 checks) pass unchanged.

---------------------------------------------------------------------------------------------

## 2. The mechanisms

Each block: formula; scope and types; information; mapping; parameters (value, source, units);
limits; validation. "Prototype" = scripts P1 to P4, original SW07 parameters. Determinacy in P3
and P4 is for the model-consistent version on SW07; impact responses in % per quarter
(RE: pinf to em -0.040, y to em -0.187, pinf to epinf 0.244, y to eb 0.419).

### 1 Level-k on a learned level 0 (Evans, Gibbs and McGough 2025; Beaudry, Carter and Lahiri 2023) [dropped 2026-10-22]
- Formula: `f^L0_t = alpha + beta(alpha + beta*pinf_{t-1})` (the baseline learner);
  `f^L(j+1)_t = E^(j)_{t-1} pinf_{t+1} = k_{j+1} + C_{j+1} s_{t-1}`, the two-step forecast in the
  homogeneous level-j economy (every inflation expectation `f^Lj`, all other expectations
  model-consistent). *Derived* matrix form of the EGM/Qiu "perceived = actual one level below".
- Scope: inflation (EGM's NK block forecast of the aggregate; BCL's wage setters' inflation
  nowcast). Other expectations RE as in the baseline.
- Information: t-1 for every level (EGM `E_{t-1} y_t`; BCL t-1 nowcast). Level 0 does not see
  policy changes; levels >= 1 do (EGM fn. 7), which matters for applications 3-4.
- Mapping: E1 (`kind 'level'`, `base 'L0'`), E4 per quarter, E2 switching.
- Parameters: K = 2 (BCL calibration, "middle of FW's 1-4"); level 0 = the baseline learner
  (AR(1), KOZ from 0.05). EGM's replicator (gain 0.2, rate 500) is replaced by hetlearn's logit
  at chi 2, memory 0.8 (no translation exists; flagged). Initial shares equal (proposed).
- Limits: each level-j economy must have a unique stable solution; under facility `'none'` a
  failure stops the run (`hetlearn:engine:levelNoSolution`). Prototype P2: the level-0 economy
  (n_BR = 1) solves in all 241 quarters 1966Q1-2026Q1 at the baseline's history beliefs (max
  beta 1.061). Discrete levels need iterative E-stability; record the spectral radius of the
  T-map Jacobian per quarter as a diagnostic (`res.learning.levels`). Slow intercept convergence
  (1.4) means levels stay close to level 0 in mean. k and the gain are weakly identified without
  surveys.
- Validation: (a) level 0 = anchored RE(t-1) returns RE at every level (P3: 1.0e-14);
  (b) EGM closed form on a scalar economy `y_t = mu + b*E y_t + e_t`: `T^k(a) = mu(1 + b + ... +
  b^(k-1)) + b^k a` (toy package); (c) K = 0 equals mode `'learning'`.

### 4 Shallow reasoning (Angeletos and Sastry 2021; parameters from Gust, Herbst and López-Salido 2020) [dropped 2026-10-22]
- Formula: `E^SR_t z_{t+h} = lambda * E_t z_{t+h}`, lambda the same at every h.
- Scope: every forward expectation of the RE type (others' GE responses), equation-specific as in
  the only estimate of this "Angeletos-Lian form": households' expectations (c, lab in the Euler
  equation, inve, pk, rk) lambda_h; price and wage setters' expectations (pinf in the Phillips
  curve, pinf and w in the wage curve) lambda_f; expected inflation in the real rate (Euler and Q
  equations) lambda_pi. Flex block RE (D1). Learners are not transformed (they do not reason about
  others).
- Information: baseline (pinf RE type t-1, others E_t). The flat profile gives lambda also for the
  h = 2 inflation forecast, which is what separates it from CD.
- Mapping: E3 `'multiplier'`, `profile 'flat'`, `types {'RE'}`, three equation-specific entries.
- Parameters: lambda_h 0.76, lambda_f 0.86, lambda_pi 0.08 (GHL FEDS 2020-003, posterior means of
  the Angeletos-Lian form, US 1966Q1-2007Q4, three equations; unitless). Angeletos-Sastry give no
  value. The mapping of GHL's three coefficients to SW07's equations by agent role is ours
  (flagged).
- Limits: lambda_pi = 0.08 nearly removes expected inflation from the real rate (GHL's money
  illusion); in EE form shallow reasoning equals one-step CD, so with one-step expectations the
  family members differ only through h = 2 and their values.
- Validation: P3: determinate; pinf to em -0.0020, y to em -0.076. lambda = 1 equals the baseline;
  equal values in the three copies equal the global multiplier (1e-12); generated model = the
  hand-written P3 file `p3_v06.model` at n_RE = 1.

### 5 Cognitive discounting (Gabaix 2020; Meggiorini 2023; Meggiorini and Milani 2021) [5a dropped 2026-10-22, 5b kept]
- Formula: `E^CD_t z_{t+h} = zbar + m^h (E_t z_{t+h} - zbar)`, zbar = 0 in SW07 (Gabaix's default
  reference point; it also pulls the learners' intercept to the steady state, as Meggiorini and
  Milani do).
- Scope: 5a every forward expectation with one m, expected inflation in the real rate included
  (Meggiorini's behavioral SW07: "the discounting parameter multiplicatively in front of all
  expectational variables"); 5b the learning set only (CD stacked on learners, Meggiorini-Milani).
  Flex block RE (D1).
- Types: all (Gabaix's behavioral agents are the RE type; Meggiorini-Milani discount the learners'
  forecasts).
- Information: baseline; profile geometric, so the t-1 inflation forecasts get m^2 (Gabaix
  Lemma 2.2); Meggiorini-Milani use one M with t-1 information (D5).
- Parameters: 5a m = 0.62 (Meggiorini 2023, behavioral SW07, US 1982-2004, the seven SW
  observables, uniform prior); 5b m = 0.94 (Meggiorini-Milani 2021, EE learning with CD, US
  1960-2007). Unitless.
- Limits: CD enlarges the determinacy region (Gabaix Prop. 3.1). With fixed shares n1 + n2 m is
  one number; here both types discount, so switching is not mechanically biased against CD. The
  anchored RE type discounts a forecast of the variant's RE limit (D11), not Gabaix's behavioral
  equilibrium.
- Validation: P3 m = 0.62: determinate, pinf to em -0.0005 (RE -0.040), y to em -0.056; flex
  block in or out leaves the impact responses to em, epinf and eb unchanged at 4 decimals.
  m = 1 equals the baseline; generated = hand-written `p3_v02.model`; Gabaix's three-equation IS
  and Phillips curves with M = m on the toy package against their closed form.

### 6 As-if hyperbolic discounting (Gabaix and Laibson, NBER WP 23254) [dropped 2026-10-22]
- Formula: `E^H_t z_{t+h} = E_t z_{t+h} / (1 + alpha h)`.
- Scope, types, information: as 5a (it is CD with a hyperbolic horizon profile).
- Mapping: E3 `'multiplier'`, `profile 'hyperbolic'`.
- Parameters: alpha = 0.25, **proposed** (no macro calibration found): an as-if half-life of one
  year, `D(4) = 0.5`, the attention half-life of Gabaix's M = 0.85 calibration. Then D(1) = 0.80,
  D(2) = 0.67.
- Limits: SW07 has only h = 1 and h = 2 forecasts, so the hyperbolic and geometric profiles are
  close here (at matched D(1), 0.74 against 0.72 at h = 2); the variant mainly shows D(1).
- Validation: P3 with alpha = 0.176 (D(1) = 0.850) matches CD m = 0.85 to about 1e-4 in the
  impact responses, determinate. alpha = 0 equals the baseline.

### 7 Myopia and anchoring (Angeletos and Huo 2021)
- Formula: in the price Phillips curve, `E_t pinf_{t+1} -> omega_f E_t pinf_{t+1} +
  (omega_b/chi) pinf_{t-1}`, i.e. AH Cor. 2 `pi_t = kappa mc_t + chi omega_f E_t pi_{t+1} +
  omega_b pi_{t-1}`.
- Scope: the inflation expectation in `'Phillips curve, price setting'` only (AH's calibrated
  application); equation copy `pinf_exp1__pc`. Types: all (AH's weights match the consensus
  forecast, an aggregate).
- Information: the anchoring lag pinf_{t-1} is in the t-1 information set; no conflict.
- Mapping: E3 `'myopia_anchoring'`, equation scope.
- Parameters: (omega_f, omega_b) = (0.52, 0.43), AH Table 1 with Coibion-Gorodnichenko K_CG =
  1.193; chi = 0.99, so b = 0.434. Unitless.
- Limits: SW07 keeps its price indexation (0.228, published mode) and habit, so backward weight is
  added on top (AH's warning); the weights are not policy-invariant.
- Validation: P3: determinate; pinf to em -0.0105 on impact and -0.0385 at h = 4 (impact damped,
  later peak, as AH report). (1, 0) equals the baseline; generated = `p3_v12.model`.

### 10 Diagnostic expectations, one-period memory (L'Huillier, Singh and Yoo 2024; Bianchi, Ilut and Saijo 2024)
- Formula: `E^theta_t z_{t+1} = (1+theta) E_t z_{t+1} - theta E_{t-1} z_{t+1}`.
- Scope: every forward expectation (LSY's DE NK model); flex block RE (D1). Types: replaces RE
  (DE agents instead of RE agents, as in LSY); learners unchanged.
- Information: non-learning variables E_t (model-consistent, LSY chain `x_REt2{-1}`); the pinf DE
  type is t-1 dated, so its reference is `E_{t-2} pinf_{t+1}` (anchored, BIS's "naive" agents
  projecting with the shadow law, through the auxiliary `x_DEg{-1}`, E4 with h = 3).
- Mapping: E3 `'diagnostic'`, `types {'RE'}`, scope all; E4 for the anchored reference.
- Parameters: theta = 0.44 (LSY, Smets-Wouters with Rotemberg pricing, 90% band 0.18-0.69, no
  survey data). Unitless. BIS's distant-memory 1.97 is not used (needs anchored backward blocks,
  not requested).
- Limits: the toolbox transforms only t+1 expectations; LSY also transform current variables
  inside the operator, and their SW07 is Rotemberg (D4). Large theta amplifies and may push
  learning runs to explosive regions with no facility.
- Validation: P3 theta 0.44: determinate; pinf to em -0.074, y to em -0.333 (amplified); 0.73 also
  determinate. theta = 0 equals the baseline; generated = `p3_v09.model`; anchored DE = model-
  consistent DE at n_RE = 1 (the DESIGN 19 collapse check with one more chain element).

### 17 Heuristic switching, four rules (Anufriev and Hommes 2012) [dropped 2026-10-22]
- Formulas (t-1 information, AH KER eqs. 4-8): ADA `f_t = 0.65 pinf_{t-1} + 0.35 f_{t-1}`; WTR
  `pinf_{t-1} + 0.4 dpinf_{t-1}`; STR `pinf_{t-1} + 1.3 dpinf_{t-1}`; LAA `0.5(pbar_{t-1} +
  pinf_{t-1}) + dpinf_{t-1}`, pbar the running sample mean; `dpinf_{t-1} = pinf_{t-1} -
  pinf_{t-2}`. Shares `n_{t,h} = delta n_{t-1,h} + (1-delta) softmax(beta U_{t-1})`,
  `U_{t,h} = -(pinf_t - f_{t-1,h})^2 + eta U_{t-1,h}`.
- Scope: inflation. Population: the four heuristics replace both baseline types (AH has neither RE
  nor RLS learners).
- Information: t-1, exactly AH's timing (forecast of p_{t+1} submitted before p_t).
- Mapping: E1 `kind 'rule'` x 4 (ADA with `self{-1}`; LAA with a mean-only belief updated with
  `gain.rule = 'decreasing'`); E2 with inertia and `'unnormalized'` fitness.
- Parameters: rule coefficients 0.65, 0.4, 1.3, 0.5 (AH); beta 0.4, eta 0.7, delta 0.9 (AH
  benchmark, fixed across groups, not fitted). beta is in squared lab price units; used as is in
  (% per quarter)^2 (flagged; = normalised chi 1.33). Initial shares 0.25 each.
- Limits: P4: all-STR (share 1) has NO_STABLE solution; equal shares, all-ADA, all-WTR, all-LAA are
  determinate. With no facility a run stops if STR comes to dominate.
- Validation: AH's asset-pricing model `p_t = (p^e_{t+1} + 3)/1.05` on the toy (p^f = 60):
  reproduce the KER patterns (convergence, persistent and damped oscillation from different
  initial prices); four identical rules keep shares at 0.25; delta = 0, `'normalized'`, N = 2
  equals `discrete_choice`.

### 18 Fundamentalists and extrapolators, optimists and pessimists (De Grauwe 2011) [dropped 2026-10-22]
- Formulas: inflation targeters `f = pi* = 0` (deviations), extrapolators `f = pinf_{t-1}`;
  consumption optimists `E_t c_{t+1} + g`, pessimists `E_t c_{t+1} - g`, `g = d/2`, `d = beta +
  delta var(y)` (CESifo WP 2418).
- Scope: two share groups, inflation {TAR, EXT} and the Euler-equation consumption expectation
  {OPT, PES} (SW07 has no output-gap expectation; c is the IS-curve term, flagged). Population:
  replaces RE and learners for inflation; c's base stays model-consistent RE (D6).
- Information: t-1 for the inflation rules (De Grauwe's `pi_{t-1}`), E_t for c.
- Mapping: E1 (`'rule'` types; OPT/PES as `kind 're'` with `variant 'model_consistent'`, `info
  'current'`, `variables {'c'}`), E3 constant wedges +g and -g per type, E2 two groups.
- Parameters: **proposed** g = sigma(y - yf)/2 under the variant's RE limit, delta = 0 (De
  Grauwe's constant-bias case; his values are not in the notes, Jang-Sacht estimate euro-area
  values by SMM); intensity and memory as the baseline (De Grauwe's gamma not sourced).
- Limits: P4: with De Grauwe's literal base (c expectation = steady state) the model has no stable
  solution once extrapolators hold all inflation expectations (NO_STABLE); with c's base
  model-consistent it is the stable "naive inflation" case (P4: determinate). A symmetric pair
  has zero mean bias when shares balance.
- Validation: equal fixed OPT/PES shares give c's expectation = RE exactly; TAR/EXT at fixed shares
  with c model-consistent = a hand-written model in the style of the P4 files.

### 19 Target believers, a credibility type (Hommes and Lustenhouwer 2019)
- Formula: `f^TB_t = pi* = 0` (the steady state; SW07's constepinf 0.818% q/q).
- Scope: inflation. Population: added beside RE and learners, {RE, BR, TB} (HL's fundamentalists
  beside RE, as the review's N-type table lists it; HL's own {TB, naive} pair is variant 18's
  inflation block). Credibility = the TB share.
- Information: none needed (a constant).
- Mapping: E1 `'rule'` (expr `'0'`), E2.
- Parameters: none for the rule; switching as the baseline (HL's intensity not in the notes);
  initial shares 1/3 each (proposed).
- Limits: a constant forecast has low errors only near steady state, so its share rises in calm
  periods. P4 (TB 1/3 with model-consistent RE 2/3): determinate.
- Validation: TB share fixed at 0 equals the baseline; a TB-only population (share 1) equals the
  model with `pinf_exp1 = 0` written by hand.

### 20 SAC learning (Hommes and Sorger 1998; Hommes, Mavromatis, Özden and Zhu 2023) [dropped 2026-10-22]
- Formula: `f_t = a_{t-1} + b_{t-1}^2 (x_{t-1} - a_{t-1})`, (a, b, R) by the SAC recursion (1.5).
- Scope: the seven sticky-economy forward expectations, all formed by SAC learners, no RE type
  (HMOZ's SW07: every forward variable learned); flex block RE (D1, D2).
- Information: t-1 (HMOZ's timing).
- Mapping: E5 `update 'sac'` on the existing AR(1) PLM; mode `'learning'`, learning set the seven
  variables.
- Parameters: constant gain kappa = 0.006 (HMOZ Table 1, SAC column; the column assignment is
  inferred from the table order, flagged). Initial beliefs from the RE moments (the toolbox
  default; HMOZ use regressions on data simulated from the BLE).
- Limits: b in [-1, 1] keeps every PLM stationary, but the ALM can still lose its solution with
  seven learned expectations under facility `'none'` (`v3_all` is explosive with RLS). Gain 0.006
  is 8 times below the baseline's start gain, so the variant also differs by speed.
- Validation: decreasing-gain SAC equals the batch formulas (HMOZ 2.6) to machine precision;
  constant-gain recursion = hand loop; a PLM with b clipped logs `sac_bound`.

### 23 Intercept-only learning (Gáti 2023; Carvalho, Eusepi, Moench and Preston 2023)
- Formula: `f^IO_t = abar_{t-1} + f^RE_t` with `abar_t = abar_{t-1} + g_t (pinf_t -
  x_exp1_RE_{t-1} - abar_{t-1})`: RE slopes (the anchored RE(t-1) forecast) plus a learned mean of
  the RE forecast's own error. *Derived* t-1 analogue of Gáti's `pibar_t = pibar_{t-1} + k_t
  f_{t|t-1}`.
- Scope: inflation (Gáti learns only the inflation intercept). Population: replaces the AR(1)
  learner, {RE, IO}, with switching (the review's nesting of Özden switching with CEMP anchoring).
- Information: t-1.
- Mapping: E1 `kind 're_mean'`, E5.
- Parameters: gain as the baseline (KOZ from 0.05; Gáti's comparison gain is a constant 0.05).
  Gáti's smooth anchoring function (knots 0.82, 0.61, 0, 0.33, 0.45) is not used: the knot
  locations are not in the notes (flagged); CEMP's unanchored gain 0.145 is the alternative.
- Limits: mean-only beliefs are a convex combination of errors, no explosive PLM.
- Validation: abar fixed at 0 makes IO = RE, so switching between identical forecasts gives the
  RE(t-1) run; recursion = hand loop.

### 24 Mean-only learning, adaptive expectations
- Formula: `f_t = abar_{t-1}`, `abar_t = abar_{t-1} + g_t (pinf_t - abar_{t-1})` (exponential
  smoothing with t-1 data).
- Scope and population: the baseline slot (learner on inflation, {RE, BR}), PLM restricted to the
  mean.
- Mapping: existing PLM option (empty regressor list). `forecast_expr`, `build_system` parameter
  names and `re_moments` handle an empty list (read in the code, not run): forecast `alpha_pinf`,
  initial belief = the RE mean. The new PLM tag writes its own generated file.
- Parameters: gain as the baseline (KOZ from 0.05; isolates the PLM restriction). The lab ADA gain
  0.65 is used in 17, the experience gain 0.018 in 26.
- Limits: no facility needed. Validation: RLS with regressor [1] = hand loop.

### 25 Kalman-filter learning and small-model averaging (Slobodyan and Wouters 2012a) [dropped 2026-10-22]
- Formula: PLM coefficients learned by the KF of 1.5; 25a AR(2) PLM per variable; 25b the five
  small models per variable (AR(1); AR(1) + r_{t-1}, pinf_{t-1}; AR(2); AR(1) + pinf_{t-1};
  AR(1) + r_{t-1}, pinf_{t-1}, y_{t-1}) with equal fixed weights 0.2.
- Scope: the seven sticky forward expectations, all learners (SW's SW07 learning model); flex
  block RE (D2).
- Information: t-1 (the baseline; SW 2012b used jointly determined expectations, which HMOZ call
  inconsistent).
- Mapping: E5 `update 'kf'`; 25b E1 with five `'plm'` types and `mode 'fixed_shares'`.
- Parameters: gamma = 0.031, sigma = 0.003 (SW 2008 draft, KF parameters fixed at posterior means);
  the mapping of (gamma, sigma) to V and the noise variance is not in the notes, so V uses the
  constant-gain equivalent of 1.5 (proposed, flagged; check against openICPSR 114246).
- Limits: AR(2) rules can extrapolate (HMOZ); seven learned expectations under facility `'none'`
  risk stops (D3). 35 PLM equations in 25b.
- Validation: KF learning with V from gamma converges to constant-gain RLS (scalar steady-state
  gain = gamma); equal-weight averaging of five identical models = one model.

### 26 Experience-based learning, aggregate (Malmendier and Nagel 2016; Nagel and Xu 2022)
- Formula: AR(1) PLM (MN cohorts estimate AR(1)s) with a constant gain.
- Scope and population: the baseline slot (inflation, {RE, BR}).
- Mapping: existing options, `gain.rule = 'constant'`, `gain.value = 0.018`.
- Parameters: 0.018 per quarter (Nagel-Xu, from MN's best-matching constant gain 0.0175; MN theta
  = 3.006 on Michigan data). Cohorts are out of scope (aggregate only, as requested).
- Validation: none new (existing gain rule).

### 27 Bayesian model averaging (Evans, Honkapohja, Sargent and Williams 2013; Cho and Kasa 2017) [dropped 2026-10-22]
- Formula: `n_{i,t} proportional to n_{i,0} exp(-SSE_{i,t}/(2 sigma^2))`: logit in cumulative
  squared errors (*derived*, the review).
- Scope and population: the baseline's two models (EHSW average an RE forecast and a time-varying
  learned model), shares = posterior model probabilities.
- Mapping: E2 with `fitness 'unnormalized'`, memory 1, intensity 1/(2 sigma^2), prior shares 0.5.
- Parameters: sigma^2 = the RE(t-1) model's two-step forecast-error variance of inflation at the
  original parameters, computed at load time (**proposed**: the Gaussian predictive variance of
  the approximating model; EHSW's own value is for a Muth model).
- Limits: no forgetting, so shares converge to 0 or 1 (EHSW's selection result).
- Validation: shares = posterior probabilities computed from the recorded errors (hand loop).

### 29 Survey belief wedge, reduced form (Bhandari, Borovička and Ho 2025; Milani 2011, 2017) [dropped 2026-10-22]
- Formula: `pinf_exp1 = sum_k n_k f^k + w_t`, `w_t = rho w_{t-1} + sigma e_w,t`.
- Scope: inflation expectations, all types (BBH's household wedge; Milani's sentiment on observed
  expectations).
- Information: w_t is a belief state; it enters the t-1-dated expectation like any type forecast.
- Mapping: E3 `'wedge'`, one factor, loading 1, new shock `e_wpinf`.
- Parameters: rho = 0.714 (BBH, autocorrelation of the wedges' first principal component,
  quarterly); unconditional std 0.26% per quarter = BBH's inflation-wedge volatility 1.03 pp
  annualised / 4, so sigma = 0.26 sqrt(1 - 0.714^2) = 0.182 (the /4 mapping from a one-year
  Michigan wedge to the one-quarter expectation is ours, flagged); mean 0 (BBH's 1.2 pp mean
  belongs to survey levels; SW07's observable constants are the RE ones).
- Limits: an extra shock; the RMSE comparison is not like-for-like (section 5). Anchored RE agents
  do not foresee w (D11).
- Validation: sigma = 0 equals the baseline; the impact response of `pinf_exp1` to `e_wpinf` is
  sigma.

### 31 Confidence shocks, approximate (Angeletos, Collard and Dellas 2018) [dropped 2026-10-22]
- Formula: `z_exp1 = E_t z_{t+1} + Lambda_z xi_t` for z in {c, inve, lab}, `xi_t = rho xi_{t-1} +
  sigma e_xi,t`: a common bias in expected activity (ACD's bias about others' output) on the
  model-consistent household expectations.
- Scope: c, inve, lab expectations (real activity); types: all (non-learning variables). Inflation
  untouched.
- Mapping: E3 `'wedge'`, loadings `'model:projection'`: `Lambda_z = Cov(z, y)/Var(y)` in the RE
  limit, so xi = 1 means expected output 1% above the model forecast (**proposed** loading).
- Parameters: rho = 0.833 (ACD sticky-price posterior, 0.717-0.911); sigma **calibrated** so that
  xi explains 51% of output variance at 6-32 quarters in the variant's RE limit (ACD Table 2,
  sticky prices; spectral band computed with IRIS `xsf`), because ACD's sigma is not in the
  notes.
- Limits: approximate (no ACD two-stage timing, fixed loadings); extra shock (section 5).
- Validation: sigma = 0 equals the baseline; the band variance share of output equals 51% by
  construction (calibration check).

### 33 Naive nominal-growth belief function (Farmer and Nicolò 2018) [dropped 2026-10-22]
- Formula: `E_t dn_{t+1} = dn_t` with `dn = dy + pinf` (deviations); the type's inflation forecast
  `f^FN_t = dn_{t-1} - E^RE_{t-1}(y_{t+1} - y_t)`: last nominal growth minus the anchored RE(t-1)
  forecast of real growth (*derived*: the belief function as a type, not as a replacement of the
  Phillips curve).
- Scope: inflation. Population: replaces the learner, {RE, FN}, with switching (FN is a naive
  rule; D7).
- Information: t-1.
- Mapping: E1 `'rule'` with named terms; E4 for `E_{t-1}(y_{t+1} - y_t)`.
- Parameters: none.
- Limits: a model change in FN's paper; here only expectations change.
- Validation: the forecast recorded by the engine = the formula from the recorded paths (1e-12).

---------------------------------------------------------------------------------------------

## 3. Portfolio variants

Scenario files `scenarios/sw07/br_portfolio/br<NN><x>_<name>.m`, each `cfg = a1_learn();` plus the
changes below (everything else is the baseline). Notation: `T(name, kind, field, value, ...)` is
one element of `cfg.expectations.types`, `X(kind, field, value, ...)` one element of
`cfg.expectations.transforms`. `ST7 = {'inve','pk','rk','c','lab','pinf','w'}`, `FLEX =
{'invef','pkf','rkf','cf','labf'}`, `RE = T('RE','re')`, `BR = T('BR','plm')`.

| Variant | Population (against {RE, BR}) | cfg changes |
|---|---|---|
| br01a_levelk_egm [dropped 2026-10-22] | replaces RE by levels 1 and 2 | `types = [T('L0','plm'), T('L1','level','base','L0','k',1), T('L2','level','base','L0','k',2)]`; `shares.init = struct('L0',1/3,'L1',1/3,'L2',1/3)` |
| br01b_levelk_bcl [dropped 2026-10-22] | everyone level 2 on the learned seed | `types` as 01a without L1; `mode = 'fixed_shares'`; `shares.fixed = struct('L0',0,'L2',1)` |
| br04_shallow [dropped 2026-10-22] | unchanged | `transforms = [X('multiplier','profile','flat','types',{'RE'},'value',0.76,'scope',{'c','lab','inve','pk','rk'}), X(..,'value',0.86,'scope',{'w','pinf@Phillips curve, price setting','pinf@Wage Phillips curve, wage setting'}), X(..,'value',0.08,'scope',{'pinf@Consumption Euler equation','pinf@Arbitrage equation for the value of capital'})]` |
| br05a_cd [dropped 2026-10-22] | unchanged | `transforms = X('multiplier','profile','geometric','types','all','value',0.62,'scope','all','exclude',FLEX)` |
| br05b_cd_learn | unchanged | as 05a with `'value',0.94,'scope','learning'` |
| br06_hyperbolic [dropped 2026-10-22] | unchanged | as 05a with `'profile','hyperbolic','value',0.25` |
| br07_myopia_anchoring | unchanged | `transforms = X('myopia_anchoring','types','all','value',[0.52 0.434],'scope',{'pinf@Phillips curve, price setting'})` |
| br10_diagnostic | DE agents replace RE agents | `transforms = X('diagnostic','types',{'RE'},'value',0.44,'scope','all','exclude',FLEX)` |
| br17_heuristics [dropped 2026-10-22] | four rules replace both types | `types = [T('ADA','rule','expr','0.65*x{-1} + 0.35*self{-1}'), T('WTR','rule','expr','x{-1} + 0.4*(x{-1} - x{-2})'), T('STR','rule','expr','x{-1} + 1.3*(x{-1} - x{-2})'), T('LAA','rule','expr','0.5*(mean + x{-1}) + (x{-1} - x{-2})','gain',struct('rule','decreasing'))]`; `switching.intensity = 0.4; .memory = 0.7; .inertia = 0.9; .fitness = 'unnormalized'`; shares 0.25 |
| br18_degrauwe [dropped 2026-10-22] | TAR/EXT replace RE/BR for inflation; OPT/PES on c | `expectations.variables = {'pinf','c'}`; `types = [T('TAR','rule','expr','0','variables',{'pinf'}), T('EXT','rule','expr','x{-1}','variables',{'pinf'}), T('OPT','re','variant','model_consistent','info','current','variables',{'c'}), T('PES', same)]`; `transforms = [X('wedge','types',{'OPT'},'factor',struct('mean',g)), X('wedge','types',{'PES'},'factor',struct('mean',-g))]`, g = `'model:sd_ygap_half'` |
| br19_target_believers | adds TB | `types = [RE, BR, T('TB','rule','expr','0')]`; shares 1/3 each |
| br20_sac [dropped 2026-10-22] | SAC learners on ST7, no RE | `expectations.variables = ST7; mode = 'learning'; beliefs.update = 'sac'; gain.rule = 'constant'; gain.value = 0.006` |
| br23_intercept_only | IO replaces the learner | `types = [RE, T('IO','re_mean')]` |
| br24_mean_only | unchanged | `beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true)` |
| br25a_kf_ar2 [dropped 2026-10-22] | KF learners on ST7, no RE | `expectations.variables = ST7; mode = 'learning'; beliefs.plm.default = 'ar2'; beliefs.update = 'kf'; beliefs.kf = struct('gamma',0.031)` |
| br25b_kf_average [dropped 2026-10-22] | five KF models on ST7, equal weights | `expectations.variables = ST7; mode = 'fixed_shares'`; five `'plm'` types with the SW regressor sets, `update 'kf'`; `shares.fixed` 0.2 each |
| br26_experience | unchanged | `gain.rule = 'constant'; gain.value = 0.018` |
| br27_bma [dropped 2026-10-22] | unchanged | `switching.fitness = 'unnormalized'; switching.memory = 1; switching.intensity = 'model:bma'` (= 1/(2 sigma^2)) |
| br29_wedge [dropped 2026-10-22] | unchanged | `transforms = X('wedge','types','all','scope',{'pinf'},'factor',struct('rho',0.714,'std',0.182,'mean',0,'shock','e_wpinf'))` |
| br31_confidence [dropped 2026-10-22] | unchanged | `transforms = X('wedge','types','all','scope',{'c','inve','lab'},'factor',struct('rho',0.833,'std','model:acd51','loadings','model:projection','shock','e_xi'))` |
| br33_farmer [dropped 2026-10-22] | FN replaces the learner | `types = [RE, T('FN','rule','expr','dn{-1} - re1(y{+1} - y)')]` (`re1` = anchored E_{t-1}, E4) |

`'model:<rule>'` values are computed by `load_model` from the variant's RE limit and recorded in
`res.meta.model_values`. The RE references: `br00_re` = `a1_re` (RE(t-1) for `{pinf}`), and for
variants whose learning set differs (18, 20, 25) their own RE limit (`mode = 'rational'` of the
same file; for 20 and 25 the RE(t-1) model of ST7, from the RE type that is always generated and
has share 0 in those variants).

---------------------------------------------------------------------------------------------

## 4. Impulse responses

Primary method: conditional generalised IRFs from the 2019Q4 state.
- Each variant runs its own history stage (the baseline's `re_smoother` with `'filtered'` RE
  states) to the origin 2019Q4, so beliefs, gains and shares at 2019Q4 are the variant's own. Two
  forecast runs, horizon 20 (2020Q1-2024Q4), zero future shocks: without and with a one-sd shock
  in 2020Q1 (`shocks.add = {{shock, qq(2020,1), std}}`); GIRF = difference. Beliefs, gains and
  shares keep updating. Each run is the existing forecast stage, so no new engine code is needed.
- Why this one: learning models are state dependent, so an IRF needs a state; 2019Q4 is the last
  quarter before the covid gap (the forecast simulates through 2020, no data involved); the run is
  deterministic and cheap; for RE it is the IRF itself. Prototype P1 (baseline): 0.8 s per run;
  2019Q4 state alpha -0.274, beta 0.317, n2 0.527; the RE(t-1) GIRF equals IRIS `srf` to 4.5e-14;
  the asymmetry `GIRF(+sd) + GIRF(-sd)` on pinfobs is at most 3e-3 against peak responses of
  0.08-0.14 (epinf, ew), so one-sd responses are close to linear here. Report the minus-one-sd run
  as a nonlinearity diagnostic.
- Secondary (optional): the 2022Q2 state (application 1's origin) for state dependence, and a
  frozen-beliefs IRF (`beliefs.update = 'fixed'`, `mode = 'fixed_shares'` at the 2019Q4 shares) to
  separate the expectation structure from learning dynamics.
- Shocks: the seven SW07 shocks at one sd of the published mode (ea 0.452, eb 0.242, eg 0.520, eqs
  0.450, em 0.240, epinf 0.141, ew 0.244); plus `e_wpinf` (29) and `e_xi` (31) for those variants.
- Variables: pinfobs, dy, robs, dc (annualised x 4 for reporting), and the expectation paths:
  `pinf_exp1`, each type's forecast `f_<k>`, the model shares `n_<k>` and the learners' beta.
- References in every panel: the baseline GIRF from its own 2019Q4 state, and the RE(t-1)
  benchmark IRF (`br00_re`); variants 18, 20, 25 also show their own RE limit; the original SW07
  (E_t) IRF as a thin line.
- Stops: under facility `'none'` a run without a solution is reported as failed with its date, as
  in the baseline.
- Outputs: `results/br_portfolio/irf_long.csv` (variant, shock, sign, variable, h, value_model,
  value_report), `states_2019Q4.csv`, `run_log`. Cost about 21 variants x 15 runs x 1 s, a few
  minutes.

---------------------------------------------------------------------------------------------

## 5. In-sample RMSE: `history.mode = 'kalman'`

Engine feature (E6), new `+engine/kalman_history.m`, dispatched from `core.m`; generalises
`hlest.loglik_learn` (one fixed configuration, its own QZ solver) to any configuration by reusing
the engine's own solve, `update_learning` and facility.

Quarter t, filter range 1965Q1-2026Q2:
1. The ALM in force in t (beliefs and shares from the end of t-1, `anchor_update` for level types)
   is solved by IRIS through `facility('solve')`; its state space (T, R, K, Z, H, D) on the full
   transition vector `[xf; xb]` (xf rows load only on `xb_{t-1}`).
2. Kalman prediction, log density `l_t`, update with `y_t` (missing rows dropped; 2020Q1-Q3:
   prediction only).
3. Agents' information: forecasts made in t with data to t-1 are the predictions `x_{t|t-1}` (the
   RE(t-1) and level types), forecasts with period-t data the filtered `x_{t|t}`; realised values
   and PLM regressors are the filtered values stored in real time.
4. `update_learning` (unchanged) with the facility's ALM check.
- Before `beliefs.init.date` (1965Q1-Q4) the ALM is the variant's RE limit. Initial condition
  `history.kalman.init = 'stochastic'` (asymptotic distribution, as IRIS) or `'smoothed'` (P0 = 0
  at the RE-smoothed state before the start). The forecast stage starts from the filtered state at
  the origin (D12).
- Outputs: `res.kalman` (one-step predictions, errors, F_t, l_t, filtered states), the learning
  record as in the other modes, `kalman_errors.csv`.

RMSE: one-step-ahead prediction errors of the seven observables, 1966Q1-2026Q2 (2020Q1-Q3 have no
data; 2020Q4 is a four-step prediction, kept in the last subsample and flagged), full sample and
1966-83, 1984-2007, 2008-19, 2020Q4-2026Q2; original SW07 parameters, no re-estimation. Tables:
RMSE by observable (model units and annualised), relative RMSE against the baseline and against
RE(t-1), the log-likelihood `sum l_t` (it penalises the predicted variance, which RMSE ignores),
and DM tests on squared one-step errors through `hetlearn.evaluate_tables` (horizon 1).

Gates (in `tests/test_kalman.m`):

| Gate | Check | Prototype P2 |
|---|---|---|
| K1 | every agent RE (`mode 'rational'`): errors = IRIS filter of the RE(t-1) model (`H.predicted`) | 8.9e-13 over 1,701 observations |
| K2 | `'smoothed'` init, P0 = 0 at the RE-smoothed 1965Q4 state: beliefs and shares = the inversion history from 1966Q1 (existing two-type case), to 2019Q4 | 1.9e-16 (alpha), 3.3e-16 (beta), 1.4e-14 (n1); they part after the covid gap by construction |
| K3 | fixed beliefs and shares: = IRIS filter of that fixed ALM | to build |
| K4 | `re_info = 'current'`, a1_learn settings: = `hlest.loglik_learn` at the same parameters | to build |

Prototype numbers (baseline, `'stochastic'` init, 2.5 s, 243 solves, no stop under `'none'`):
full-sample RMSE in % q/q, baseline / RE(t-1) / original SW07 (E_t): dy 0.839 / 0.829 / 0.824;
dc 0.728 / 0.712 / 0.711; dinve 1.747 / 1.759 / 1.753; dw 0.791 / 0.795 / 0.797; labobs 0.857 /
0.838 / 0.849; pinfobs 0.309 / 0.371 / 0.307; robs 0.242 / 0.247 / 0.229. Inflation by subsample
(baseline / RE(t-1)): 0.369 / 0.409, 0.186 / 0.243, 0.296 / 0.435, 0.491 / 0.513. Log-likelihood
1966Q1-2026Q2: baseline -1839.8, RE(t-1) -2182.1. Under the Kalman history the 2019Q4 learners'
share is 0.544 (0.527 on the RE-filtered history); beta is the same (inflation is observed).

Wedge variants (29, 31) add a shock. The filter uses the literature variance (29: sigma 0.182;
31: the ACD-calibrated sigma), so part of each prediction error is attributed to the wedge and the
RMSE is mechanically helped. Their rows are flagged "extra shock, not like-for-like", with the
log-likelihood shown next to the RMSE.

Stops: under `'none'` a quarter without a solution ends the filter; the variant's row shows the
date. A variant that stops is not rerun with a facility (baseline rule); D3 offers a flagged
sensitivity.

---------------------------------------------------------------------------------------------

## 6. Implementation plan

| Phase | Delivers | Tests | Files | Effort |
|---|---|---|---|---|
| P0 freeze | references from the current code | `test_br_regression` R1, R2 | tests only | 0.5 day |
| P1 Kalman history | `history.mode = 'kalman'`; RMSE for the baseline and the 24, 26 variants (existing options) | K1-K4 | new `kalman_history.m`; `core.m` dispatch; `load_options`/`defaults` (history subtree); `assemble`/`save_results` | 2-3 days |
| P2 N-type core | E1, E2; variants 17, 19, 27 (and 24, 26) | R3; AH asset-pricing reproduction; HL; BMA closed form; inertia, costs, normalisation | `extend_model` (`make_block_ntype`), `load_model`, `+plm/build_system` (type suffixes), `state_init`, `update_learning`, `shares_for_mode`, `facility`, `record`, `assemble`, `save_results`, new `discrete_choice_n` | 5-6 days |
| P3 transforms | E3; variants 4, 5a, 5b, 6, 7, 10 (model-consistent part), 18, 29, 31 | R4; hand-written reference models (P3/P4 files); equation copies | `extend_model` (transform writer, equation map, wedge states), `load_model` | 3-4 days |
| P4 generalised anchor | E4; variants 1a, 1b, 10 (anchored reference), 23, 33 | fixed-point gate; EGM scalar closed form; K = 0; anchored DE = MC at n_RE = 1 | new `anchor_coefficients`, `anchor_update`; `re_anchor_coefficients` wrapper; `forecast`, `history` calls | 3-4 days |
| P5 learning rules | E5; variants 20, 23 (PLM part), 25a, 25b | SAC batch identity; hand loops; KF to RLS limit | new `+rls/sac.m`, `+rls/kf.m`, `+gain/decreasing.m`; one dispatch line in `update_learning` | 2-3 days |
| P6 propagation and docs | density, evaluate, decompose, Ramsey (support or explicit errors); DESIGN, USER_GUIDE, FEATURES rows 200+, README | existing suites | as listed | 2 days |
| P7 portfolio | 21 scenario files, `br_portfolio.m` runner (IRFs and Kalman RMSE), summary CSVs, report section | gates of sections 4 and 5 rerun | `scenarios/sw07/br_portfolio/`, `results/br_portfolio/` | 2 days |

Order: P0, then P1 and P2 in parallel; P3 and P4 after P2 (both edit the generator and
`load_model`, so one owner each in sequence, P3 first); P5 in parallel with P3 and P4 (new files
only; it touches `update_learning` at one dispatch line after P2 has landed); P6 and P7 last.
P1 and P2 share only `load_options.m` and `defaults.m`: give the option edits to one owner or merge
P1's history subtree first. Total about 20-25 working days.

**P0 done (2026-10-20).** The freeze and the full option schema are in place, so later phases need not
edit `defaults.m` or `load_options.m` beyond deleting their own guard lines.
- `tests/test_br_regression.m` (14 checks, about 75 s, registered last in `tests/run_tests.m`).
  R1: 7 generated files (SW07, toy `nk3` and `nk3l1`, default and `_relag`, plus `nk3_norm.model`)
  written by `tests/scenarios/br_generate.m` into a temporary copy of each package, compared by MD5
  and bytes. R2: 30 runs in 7 groups, re-run from their stored partial option trees and compared
  exactly: paths, learning records, events, final state, dates, loss, hashes and every frozen
  option. `tsw07_peak_re`; `tsw07_switch_pinf` `'fast'` and `'iris'` (also against both existing
  references); the baseline as `tsw07_a1_re` and `tsw07_a1_learn` (`'fast'` and `'iris'`); the
  2019Q4 runs of section 4, RE(t-1) and baseline, no shock and +1 sd of each shock, plus the
  baseline at -1 sd. `'fast'` runs are also held to 0, so the 1e-12 allowance of 1.7 is not used.
  Options and outputs added after the freeze are listed, not failed.
- References: `tests/reference/br_freeze.mat` (4.5 MB), from `tests/scenarios/make_br_freeze.m` on
  the code before any P0 option edit. That script checks that the test copies merge to the same
  option trees as `a1_re`/`a1_learn` under `config/master_options.m`, and that the two existing
  references still match. Mutation test: one ulp in a path, 1e-15 in a share, one event string,
  one option value, the final state and one byte of a generated file each fail their group.
- Schema (`defaults.m` comments, `load_options.m` validation; all off). Until its phase lands, a
  feature stops with `hetlearn:options:notImplemented`, which lists every unimplemented option of
  the run with its phase (function `not_implemented`). `test_options` BR2 checks that every
  variant of section 3 passes validation and gets exactly its phases. BR3 checks 24 malformed
  settings. Choices made for the later phases:
  - A rule is the type field `rule` (the expression, or `struct('expr', ..., 'params', ...)`),
    not a top-level `expr` as in the `T(...)` notation of section 3.
  - A cost goes in the type (`cost`) or in `switching.costs`, not both.
  - `switching.memory = 1` is allowed only with `fitness 'unnormalized'`.
  - `shares.init`/`.fixed` take one scalar per type and must sum to 1 per share group (an
    unlisted RE type gets 0). `fixed_n2` and `shares.fixed` cannot both be set.
  - `'model:<rule>'` strings are accepted for `switching.intensity` and for the wedge `std`,
    `mean` (`'-model:<rule>'` for De Grauwe's pessimists) and `loadings`.
  - `beliefs.kf` takes `gamma` (`[]` = `gain.value`) and `s2` (`'re_moments'` or a number).
    `gain.decreasing` takes `n0` (1).
  - `history.re_states = 'filtered'` with `'kalman'` is an error, as with `'inversion'`, so
    Kalman scenarios built on the baseline set `'smoothed'`. `'hetero_filter'` points to `'kalman'`
    (D9).
- Not done (P6): USER_GUIDE and FEATURES rows for the new options.

**P1 done (2026-10-20).** `history.mode = 'kalman'` runs in the engine.
- New `toolbox/+hetlearn/+engine/kalman_history.m`, called from `core.m` in place of
  `engine.history` (dispatch, a progress line, the forecast databank, `res.kalman`). Each quarter:
  `facility('solve', ..., 'kalman')`, the state space on [xf; xb] (the fast-step system cached by
  `solve_model`, else `step('build')`; a backward system is converted), prediction and update with
  the rows without data dropped (written for measurement shocks too), the agents' information of
  step 3, `update_learning` unchanged (ALM check under `'alm'`/`'plm_alm'`), `record` with the model
  shares in force. `'stochastic'`: asymptotic mean and covariance of the first quarter's ALM (real
  Schur form, IRIS `covfun.lyapunov`; an error for a root on or outside the unit circle).
  `'smoothed'`: the filter starts at `beliefs.init.date` from the RE-smoothed state of the quarter
  before with P = 0, and the agents' earlier data are RE-smoothed (the inversion's convention), so
  its one-step errors start at the init date. D12: `core` copies the filtered history over the
  RE-smoothed one; the state's lag elements at the origin take their values in a_{origin|origin}.
  These differ from the real-time values because P_{t|t} never collapses (four observables are
  first differences; max diag P about 9 at 2026Q2). `history.learn = false` is an error.
- Outputs: `res.kalman` (one-step predictions, errors, F_t, l_t, filtered and predicted
  databanks, a and P at the origin, `fbr_model_maxdiff`); `kalman_errors.csv` (date, n_obs, llt,
  err_/pred_/var_ per observable). `core` cannot tell whether a run will be saved, so the file is
  written by one line in `hetlearn.run` after `save_results`. A later non-Kalman run of the id
  deletes it. `kalman_history('rmse', res)` gives the RMSE table by subsample.
- Guard lines removed from `load_options.m`; `test_options` BR2 now expects the `'kalman'` entry
  to load (one line).
- Gates, `tests/test_kalman.m` (9 checks, about 80 s; registered before `test_br_regression`):
  K1 8.7e-13 over 1,701 observations; K2 alpha 2.1e-16, beta 3.3e-16, n1 1.4e-14 (fRE 8.4e-14,
  fBR 1.4e-14); K3 (fixed beliefs and shares, `'smoothed'` start, against IRIS `filter` with
  `InitCond` = the smoothed databank): errors 2.8e-13 over 1,673 observations, filtered states
  2.1e-12; K4 (`re_info = 'current'`, a1_learn settings of the test calibration): l_t 1.6e-12, log
  likelihood -1411.3326921 in both (diff 4.6e-13), beliefs, shares and forecasts within 7.9e-14,
  facility events 2022Q1 and 2022Q2 in both. K5: D12 exact, `kalman_errors.csv` written and
  removed.
- SW07 run: `scenarios/sw07/app6_history/a6_kalman_learn.m` and `a6_kalman_re.m` (origin 2026Q2,
  `re_states = 'smoothed'`), saved in `results/a6_kalman_*`. They reproduce the prototype numbers
  above to the digits shown, including the learners' share 0.544 at 2019Q4 (0.709 at 2026Q2).
- Notes. For an AR(1) PLM the learners' forecast on real-time data equals the model's
  `<x>_exp1_BR` prediction to rounding (1e-14). With two lags of one variable, the ALM's forecast
  uses the filter's revised lag and the recorded forecast the real-time one. Events of the Kalman
  history are labelled stage `'history'` (`assemble`).
- Not done: USER_GUIDE and FEATURES rows (P6); the `defaults.m` comment that names P1 among the
  guarded options; `run_applications` and `scenarios/sw07/INDEX.csv` do not list the two new
  scenarios; the RMSE rows of variants 24 and 26 (existing options) are left to the P7 portfolio
  (this phase ran the baseline only).

**P2 done (2026-10-21).** N agent types (E1) and shares over N types (E2) run in the engine.
- Options now read: `expectations.types` with kinds `'re'`, `'plm'`, `'rule'` (`'level'` and
  `'re_mean'` keep their guards, P4/P5), `shares.init`, `shares.fixed`, `switching.inertia`,
  `.costs` (or the type's `cost`), `.fitness`, `switching.intensity = 'model:bma'`. The P2 guard
  lines are gone from `load_options.m`; `test_options` BR2 expects br19, br27 and the spelled-out
  pair to load and the other variants to name only their later phases.
- New files: `agent_types.m` (resolves the types: RE first, always generated, share 0 and outside
  the logit when not listed; the RE type follows `expectations.re_variant` and `.re_info`, since
  the RE filter and `history_db` read them), `+switching/discrete_choice_n.m`, `init_fitness_n.m`,
  `+plm/rule_terms.m` (rule parser of generator and engine; terms `x`, `self{-k}`, `mean`, `dn`,
  constants, model variables; linear, lags >= 1 under `'lagged'`), `+engine/ntypes.m` (state,
  every type's forecasts, seeding of the rules' own lags at the forecast start).
- Generator version 6 (`extend_model(..., 'types', ...)`, `<name>_ext_n<hash>.model`): per forward
  variable one `<x>_exp1_<k>` per type, shares `n_<k>_x`, PLM parameters with `__<k>` (new suffix
  argument of `build_system`), mean beliefs `alpha_<x>__<k>` of rule types (a mean-only PLM, RLS
  with the type's gain), rule constants `<p>__<k>`. A type that inherits `re_variant` or
  `beliefs.info` keeps the `re_anchored` / `br_info_current` switch, a type with its own gets one
  branch. The lagged RE chain is written only for variables with a lagged `'re'` type. With the
  types RE and BR the block has the lines of the two-type writer in the same order. Collapse tests
  at the RE limit (`n_RE_x = 1`) as for the two-type files. The default files are unchanged (R1).
- Engine: `load_model` returns `info.nt` and a keyed system `info.sys` (targets `<x>__<k>`) of all
  learning types; `state_init`, `update_learning`, `shares_for_mode`, `facility` (PLM blocks per
  type, share parameters, skip when every share is on RE), `record` and `assemble` branch on
  `ctx.nt`. Two small branches outside the P2 file list were needed: `history.m` (two places) and
  `forecast.m` read every type's forecast through `ntypes('forecasts')`, which asserts the PLM and
  rule types against the model each quarter (1e-9). `core.m` is unchanged. Without types and with
  the default switching options the two-type code runs as before; the default pair with any E2
  option runs the two-type file on the N-type engine path (variant 27). Two types with RE first,
  no inertia, no costs and `'normalized'` call `discrete_choice`.
- Outputs: `res.learning.<x>.n_<k>`, `n_model_<k>`, `U_<k>`, `FE_<k>`, `f_<k>` (plus `.types`),
  `res.learning.<x>__<k>` (PLM series of each learning type), `paths.<x>_exp1_<k>` (the type's
  forecasts over the record), `res.meta.types`, `res.meta.model_values` (`bma.sigma2`, `.chi`).
  `learning.csv` carries them through the existing writer (`save_results` unchanged).
- Not supported with N types yet (explicit errors): `history.mode` `'inversion'` and `'kalman'`,
  density forecasts, Ramsey policy, a second `'re'` type other than model-consistent with period-t
  information or a copy of the RE type (P4). `evaluate`, `decompose` with N types: P6.
- Fix: `build_system` failed on a PLM with an empty regressor list (`strcat` of empty cells), so
  the mean-only PLM of variant 24 did not run before (the 24/26 note of P0 said "existing
  options"); it runs now (Application 1 test copy: 3.08%, learners' share 0.290 at 2022Q2).
- Gates, `tests/test_ntypes.m` (20 checks, about 50 s; registered before `test_br_regression`):
  U1-U5 share rule and rule parser (two-type case = `discrete_choice` 5.6e-17, inertia and costs
  2.8e-17, unnormalized at beta = normalized at beta/(1-omega) 3.3e-16, edge cases, 7 malformed
  rules rejected); R3a-d the types RE and BR spelled out = the two-type run (SW07 baseline, its
  RE(t-1) benchmark, the two-type file on the N-type engine, the toy), max diff 0 in paths,
  shares, fitness, forecasts, beliefs, gains, events and final state, with both RE filters
  recomputed in the session (the cached baseline filter differs from a fresh one by 1.8e-11,
  thread-count noise); H1 a target-believer type at share 0 leaves the baseline unchanged
  (learning 5.6e-13, state 8.7e-14, paths 2.3e-11 from the larger state space of the filter);
  H2 a TB-only population = SW07 with the four `pinf{+1}` replaced by 0 (IRFs 2.1e-13); B1 BMA
  shares = prior x exp(-chi SSE)/sum (2.2e-16, toy), chi = 1/(2 sigma^2) with sigma^2 from `srf`;
  B2 SW07 RE(t-1): sigma^2 0.0524766 = the two-step FEV of pinf, chi 9.53; S1 inertia 0.6, a cost
  and unnormalized fitness = the hand recursion (1.1e-16); M1 mode semantics (`'fixed_shares'` with
  `shares.fixed` 2.4e-15, `'learning'` on the single non-RE type 1.6e-15, `'rational'` without a
  listed RE type = the RE run 1.1e-13, `'learning'` with two non-RE types an error); M2
  `history.learn = false` with RE and BR spelled out = the two-type run (0), an AR(1) and an AR(2)
  learner beside RE under `'plm_alm'`; A1-A3 Anufriev-Hommes four heuristics
  (beta 0.4, eta 0.7, delta 0.9) on the new test package `tests/models/ah` (p^f = 60, the LAA
  anchor on the test gain rule `ah_sample_mean`, the sample mean): engine = an independent loop of
  the AH equations, prices within 1.9e-13 and shares within 5.3e-15, monotone convergence (prices
  55, 60, 50, equal shares), damped oscillation (55, 50, 55, LAA 0.85), persistent oscillation
  (50, 55, 60, STR 0.7); A4 four identical rules keep shares at 0.25 (5.6e-17). Whole suite at
  the default thread count (`test_generator` alone, `test_re_info` alone, the rest in two
  sessions): 342 checks in 22 suites, all pass; `test_br_regression` exact (R1 files
  byte-identical, R2 max diff 0), `test_kalman` 9 of 9.
- Application 1 (live baseline, `a1_learn` plus the section 3 changes, not saved): average
  inflation 2022Q3-2026Q2 (annualised) and shares at the end of 2022Q2: baseline 3.45% (BR 0.591);
  17 four heuristics 7.03% (ADA 0.256, WTR 0.263, STR 0.238, LAA 0.243; the LAA anchor learns on
  the baseline gain until P5 builds `gain.rule = 'decreasing'`; with the sample mean of the test
  rule 5.45%); 19 target believers 3.38% (RE 0.340, BR 0.491, TB 0.169); 27 BMA stops under
  facility `'none'` in 2022Q4 (`noSolution`, NO_STABLE: the learners' share is 1.000 by 2022Q2,
  RE 6.7e-63, AR(1) beta 1.105), sigma^2 0.0525, chi 9.53.
- Not done: scenario files and the portfolio runner (P7), USER_GUIDE and FEATURES rows (P6), the
  LAA anchor's decreasing gain (P5), N types in the Kalman history (`kalman_history` passes the
  two-type forecasts to `update_learning`; it is refused for N types until it calls
  `ntypes('forecasts')`). Left as they were: the `defaults.m` comment that lists P2 among the
  guarded options, the header of `test_br_regression.m` (R3 lives in `test_ntypes.m`), and the
  helper `struct2cell_or_empty` in `load_options.m`, unused since its only caller was a P2 guard.

**P3 done (2026-10-21).** Forecast transforms (E3) run through the generator and `load_model`; no
engine file changed.
- Options: `expectations.transforms`, all five kinds. The P3 guard is gone from `load_options.m`;
  `test_options` BR2 expects br04, 05a, 05b, 06, 07, 10, 18, 29 and 31 to load. Without
  `expectations.types`, `agent_types` spells out the default pair (RE `'re'`, BR `'plm'`), so a
  transform always takes the N-type writer.
- Generator version 7 (`extend_model(..., 'types', ..., 'transforms', ...)`, `<name>_ext_n<hash>.model`,
  key = types plus the transforms' structure). Every factor is a parameter `tf<i>_*` that
  `load_model` sets from the options, so values do not regenerate the file (05a and 06 share one).
  Learning branch: `x_exp1 = sum_k n_k_x*T_k(x_exp1_<k>)`, the type forecasts `x_exp1_<k>` stay
  untransformed; outside the learning set `x_exp1 = T(x{+1})`. Several transforms on one
  expectation apply in list order. Scope `'learning'` acts in the learning branch of every forward
  variable, `'all'` and named variables in both branches (minus `exclude`); outside the learning
  set a transform acts when its types are `'all'` or include RE. `'x@<label>'` writes a copy
  `x_exp1__<tag>` (tag = initials of the label up to its first comma: pc, wpc, cee, aeftvoc) that
  replaces x{+1} in that equation only and carries the global transforms of x plus its own. The
  aggregate x_exp1 stays; when copies cover every equation of x (variant 04) the model does not use
  it, and `res.paths.pinf_exp1` is then the untransformed aggregate. Only t+1 expectations are
  transformed (x_expk, k >= 2, keep the chain).
- Text by kind. Multiplier: `tf<i>_D__<k>*f` per type, D(h) with h = 2 under t-1 information (m^h,
  lambda, 1/(1 + alpha h)), `tf<i>_d1` for the model-consistent expectations. Myopia:
  `omega*f + b*x{-1}`. Diagnostic: `(1 + theta)*f - theta*f_ref`, f_ref = `x_REt2{-1}` for period-t
  types and the model-consistent expectations (chain x_REt1, x_REt2 written where missing) and
  `x_REt3{-2}` for t-1 types (one more chain element beside the lagged RE chain). Partial
  adjustment: a state `<x>_pa<i>_<k>` (`_0` outside the learning set). Wedge: `f + mu + lam_x*xi`,
  `xi_<shock> = rho*xi_<shock>{-1} + <shock>` with the shock declared in the block and
  `std_<shock>` set by `load_model`; a constant wedge (std 0, no shock) adds mu only.
- Not built in P3, left out of the type's forecast and refused by `load_model` when the variable
  learns (`meta.transforms.blocked`): a diagnostic of a learned or rule type (reference not
  built) or of an explicitly anchored RE type, partial adjustment of a learned or rule type (its
  state would start the forecast from the RE-limit history). A diagnostic on the RE type that
  follows `re_variant` is written in the model-consistent branch only (`meta.transforms.deferred`)
  and refused under `re_variant = 'anchored'` (P4).
- `load_model` (D11). The anchor economy is the same file at n_RE = 1, `re_anchored` false, every
  wedge loading 0 (means kept): `re_anchor_coefficients('lagged')` on it, or with period-t
  information the coefficients of its state space on the original states (new local
  `tf_anchor_current`; without transforms the source model is used as before). The IRFs of the
  anchored and the model-consistent RE limits must agree on every shock but the wedge shocks
  (1e-10; `info.re_info_check`, `info.re_transform_check`). If the anchored forecast loads on a state
  that a transform adds (diagnostic memory of other variables, partial-adjustment states), the run
  stops with a message naming P4. Model values: `model:sd_ygap_half` (mean, sd(y - yf)/2) and
  `model:projection` (loadings, Cov(z, y)/Var(y)) from the wedge-free RE limit by IRIS `acf`;
  `model:acd51` (std) from the RE limit with the loadings, `acf` with `Filter 'per>=6 & per<=32'`,
  contributions by shock, NFreq 2048, sigma^2 = 0.51/0.49 * V_other/V_xi. Recorded in
  `res.meta.model_values` (`.sd_ygap_half`, `.projection`, `.acd51`, `.transforms` with every
  factor). The factors enter `info.params`, so the RE filter's cache key separates them.
- Fitness, as 1.1 is written: the forecasts that the engine reads, assesses and records (f_<k>,
  FE_<k>) are the untransformed `x_exp1_<k>`; the transforms act in the aggregate that enters the
  model. Consequence for 18: OPT and PES have the same base forecast, so their fitness is equal and
  their shares stay at 0.5 (c's expectation is then model-consistent exactly). Fitness on
  transformed forecasts needs an engine change: `ntypes('forecasts')` applying each type's global
  transform (multiplier, myopia and wedge from the databank; partial adjustment and diagnostic need
  state). Left to the main session (decision).
- Gates, `tests/test_transforms.m` (31 checks, about 3 min; registered before `test_br_regression`).
  N1-N8 each kind at its neutral value (m = 1, lambda = 1 with copies, alpha = 0, myopia [1 0],
  theta = 0, g = 1, wedge std 0, De Grauwe means 0) on the baseline = its RE limit (IRFs 0 to
  3.7e-13, the anchored = model-consistent check 1.9e-13 to 3.8e-13); N9 period-t anchored: m = 1
  equals the source-model anchor. H1-H7 generated = hand-written (the prototype's text edits, built
  in the test from `sw07.model`): CD 0.62, GHL shallow reasoning with four copies, hyperbolic
  0.176, DE 0.44, myopia (0.52, 0.4343), DE with inflation RE(t-1) (`pinf_REt3{-2}`) and partial
  adjustment 0.6 (pinf's RE type and the model-consistent w; 0.6 on c has no stable solution):
  1.2e-13 to 8.1e-13; the hand models reproduce the impact responses of `proto3.log`. C1 equal copies = one
  global multiplier (3.8e-13); C2 the copies replace pinf{+1} in their four equations only; C3 bad
  labels rejected. W1 e_wpinf enters with std 0.182, impact of pinf_exp1 = sigma, xi at h = 2 =
  rho*sigma; W2 = a hand-written AR(1) wedge model (2.9e-13); W3 a 2019Q4 forecast run with
  `shocks.add` moves pinf_exp1 by 0.182 on impact; W4 loadings c 0.8157, inve 1.7491, lab 0.4139
  (independent Lyapunov 3e-13), std 0.2446 gives a band share of 0.51001 by Simpson on the transfer
  function. V1 g = 2.160 (sd(y - yf) 4.32, independent Lyapunov), equal OPT/PES shares = OPT alone
  without bias (4.5e-13, steady state 0). E1 seven settings stop with their errors. R4a-f (R4):
  the baseline run with a transform at its identity value against the two-type run, both on the
  transform model's RE filter: 0 for the multiplier without copies; where the transform adds model
  variables (copies, chains, states, the wedge factor) learning <= 5.9e-13, final state <= 1.9e-13,
  paths <= 5.8e-12 (IRIS solves a larger system, as test_ntypes H1). On their own fresh filters:
  paths <= 1.6e-11, learning <= 1.4e-12. Whole suite at the default thread count
  (`test_generator` alone, `test_re_info` alone, the rest in two sessions): 388 checks in 24
  suites, all pass; `test_br_regression` exact (R1 byte-identical, R2 max diff 0), `test_ntypes` R3
  max diff 0. The first pass failed only H7, then set with g = 0.6 on c as well (no stable
  solution); H7 now uses pinf and w.
- Application 1 (live baseline, `a1_learn` plus the section 3 changes, not saved; average
  inflation 2022Q3-2026Q2 annualised, shares at the end of 2022Q2): baseline 3.45% (BR 0.591); 04
  6.71% (RE 0.395, BR 0.605); 05a 4.60% (0.319, 0.681); 05b 4.01% (0.415, 0.585); 06 4.92% (0.362,
  0.638); 07 3.42% (0.483, 0.517); 10 is refused as defined (anchored RE: P4) and its
  model-consistent part (`re_variant = 'model_consistent'`) stops under facility `'none'` in 2022Q3
  (forecast stage, NO_STABLE; shares in force RE 0.429, BR 0.571, beta 1.059; the baseline with
  model-consistent RE, `v1_mc_learn`, stops at the same date); 18 5.72% (c: OPT 0.500, PES 0.500;
  pinf: TAR 0.215, EXT 0.785; g = 2.16, a 2.16% bias on expected consumption); 29 stops in 2023Q2
  (NO_STABLE; RE 0.189, BR 0.811 at 2022Q2, BR 0.998 and beta 1.146 by 2023Q1; the RE filter puts
  xi = 0.34 into the 2022Q2 state); 31 3.07% (RE 0.432, BR 0.568; std of e_xi 0.245).
- Known limits: with `re_info = 'current'` the RE filter loads every forward variable as learning
  (`re_filter`), so a transform with scope `'learning'` acts on all of them in the filter model but
  only on the learning set in the run; the Kalman history refuses N types and so transforms.
- Not done: the anchored diagnostic reference and anchors over transform states (P4), fitness on
  transformed forecasts (decision above), USER_GUIDE and FEATURES rows (P6), scenario files (P7).
  For P4, variant 10 needs more than `x_DEg`: in the DE economy the anchored base forecast of pinf
  loads on the diagnostic memory states of the other expectations (`c_REt2`, `inve_REt2`, ...), so
  the anchored expression must take those states too; E4 as written in 1.4 refuses a loading
  outside `states` (E1's second case shows the refusal).

**P5 done (2026-10-21).** SAC learning, Kalman-filter (KF) learning and the decreasing gain (E5)
run in the engine.
- New `toolbox/+hetlearn/+rls/sac.m`, `+rls/kf.m`, `+gain/decreasing.m`. The dispatch took four
  one-line edits of `update_learning.m`, not one: P2 split the update into a two-type and an
  N-type path, each with its own `'rls'` gate and RLS call. Both gates admit `'sac'` and `'kf'`
  and both calls send them to `hetlearn.rls.<rule>`; `'rls'` keeps the original call, so default
  runs are unchanged. P5's guard lines are gone from `load_options.m` (the `'sac'`, `'kf'` and
  `'decreasing'` entries of `not_implemented`, and the two wrappers that skipped the rule-existence
  check for `'decreasing'`); the `'re_mean'` guard (`'P4, P5'`) stays. `test_options`: BR2 expects
  br17, br20, br25a and br25b to load, and "bad gain.rule rejected" uses a rule that does not
  exist (it used `'decreasing'`).
- SAC: the recursion of 1.5 with the period's gain. (a, b, R) live in the AR(1) PLM state,
  phi = [a(1 - b); b] and R = [1, a; a, a^2 + R], so the generated text, the RE-moment initial
  beliefs, the record and the facility's keep and revert need no change. The PLM must be an AR(1)
  with a constant on the own lag (`hetlearn:rls:sacPlm`); b outside [-1, 1] is clipped, event
  `sac_bound`. The batch identity of 2.20 needs HMOZ's finite-sample terms, which 1.5 drops:
  `sac('step', s, x, xlag, g, x0)` keeps them (*derived*: the factor (1 - g) on e^2 and the term
  g e (x0 - a_t) in the b update) and with gain 1/(t+1) equals HMOZ 2.6 to 1e-15. The engine runs
  the form of 1.5. With gain 1/(t+1) that form gives autocovariance over variance computed from
  the deviations from the running mean rather than the full-sample mean; in the test sample it is
  0.039 from HMOZ 2.6 at t = 10, 0.016 at t = 100 and 0.0055 at t = 400.
- KF: the covariance recursion of 1.5, V = gamma^2/(1 - gamma) s2 inv(R0), P0 = gamma s2 inv(R0),
  R0 the initial moment matrix; gamma = `beliefs.kf.gamma` ([] = `gain.by_var.<x>`, else
  `gain.value`); s2 a number, or `'re_moments'` = E[x^2] - phi0' R0 phi0 with E[x^2] read from
  R0 at the own lag (needs the own lag and RE-moment initial beliefs, `hetlearn:rls:kfS2`).
  State: `S.R.<target>` holds M = gamma s2 inv(P) (M0 = R0, the record's R stays a moment
  diagonal, keep and revert restore P), `S.kf.<target>` the constants. Two findings. s2 cancels
  from the beliefs, because V and P scale with it. The step is the RLS step with gain gamma and
  M_t = (M_{t-1}^-1 + gamma/(1 - gamma) R0^-1)^-1 + gamma z z', so the first update from R0 is
  the constant-gain RLS step and a mean-only PLM is constant-gain RLS in every period (the RLS
  limit of 2.25). The gain rule's period gain is not used, but `res.learning.<x>.gain` still
  records it (under the baseline's KOZ rule an unused KOZ path): P7's 25a/25b files can set
  `gain.rule = 'constant'`, `gain.value = 0.031` to show gamma there, with the same beliefs.
- Decreasing gain: 1/(k - 1 + n0) at the k-th update of an equation, i.e. 1/(t - t0 + n0) with
  t0 = `beliefs.init.date` when every quarter has data (a quarter without data does not count).
  n0 = 1 gives the sample mean from t0; the gains equal those of the P2 test rule
  `ah_sample_mean`.
- Gates, `tests/test_learning_rules.m` (15 checks, 15-30 s; registered before
  `test_br_regression`). Unit: L1 SAC batch identity (finite-sample form = HMOZ 2.6 over t =
  1..400: mean 5.6e-16, variance 1.1e-15, autocorrelation 1.0e-15; engine form = its own batch
  moments 1.1e-15); L2 SAC constant gain = hand loop (1.6e-15); L3 clipping and `sac_bound`, four
  non-AR(1) PLMs rejected; L4 KF = hand loop of the covariance recursion (2.6e-16 relative); L5
  RLS limit (z = 1: 2.2e-16 from RLS, gain within 6.9e-18 of gamma; from 50 x P0 the gain reaches
  gamma to 4.2e-17; first step = RLS 1.4e-16); L6 s2 cancels (1.7e-16), s2 `'re_moments'` of an
  AR(1) = sigma^2, errors; L7 decreasing gain = hand count (0), n0 = t0 + 1 after OLS gives 1/t
  exactly and full-sample OLS (5.6e-16). Toy engine: L8 SAC = hand loop (1.4e-14); L9 the bound
  binds from forced initial beliefs (2 events, = hand loop); L10 KF with AR(2) PLMs = hand loop
  (4.3e-15); L11 KF on mean-only PLMs = RLS (2.8e-14); L12 s2 `'re_moments'` vs 2.5 (8e-13); L13
  decreasing gain = running mean (1.8e-15), with n0 = 8 = hand RLS loop (0); L14 RE and BR
  spelled out with BR `'sac'` or `'kf'` = the two-type runs (0). AH: L15 the LAA anchor on
  `'decreasing'` = on `ah_sample_mean` (0, three cases). `test_options` 27, `test_ntypes` 20 and
  `test_br_regression` 14 (R1 byte-identical, R2 max diff 0) pass.
- Application 1 (live baseline, `a1_learn` plus the section 3 changes, not saved; average
  inflation 2022Q3-2026Q2 annualised, shares at the end of 2022Q2): baseline 3.45% (BR 0.591); 17
  with the decreasing LAA anchor 5.45% (ADA 0.256, WTR 0.261, STR 0.236, LAA 0.247; anchor = the
  sample mean of pinf from 1966Q1, gain 1/226 at 2022Q2; P2's test-rule run gave 5.45%); 20 SAC
  5.88% (BR 1 in the model, mode 'learning'; autocorrelations at 2022Q2 0.30 (pk) to 0.99 (c),
  never clipped); 25a stops under facility `'none'` in 2022Q4 (forecast stage, NO_STABLE; largest
  PLM roots pinf 1.0067 and w 1.0185 after the 2022Q3 update, w already 1.0148 at the origin);
  25b 5.65% (M1-M5 0.2 each in the model; 35 KF equations plus auxiliary r and y; for pinf M4 =
  M1). 25b used `beliefs.kf.gamma = 0.031` from mechanism 25: its section 3 row names only
  `update 'kf'`, and without it gamma would be `gain.value` (0.05).
- Variant 23 (left to P4, guard kept). Its PLM part needs no new P5 code: abar is a mean-only PLM
  on the generated target z_t = x_t - x_exp1_RE_{t-1}, and once the `'re_mean'` type has a PLM
  system (`ty.sys`, `eq.var` = the generated target, parameters with the type suffix, as the
  rule types' `mean` beliefs) `update_learning` updates it with the type's `update` and `gain`:
  `'rls'` with the KOZ gain (mechanism 23) or `'decreasing'`; `'kf'` only with a numeric s2 (a
  mean-only PLM has no own lag); `'sac'` is refused. P4 supplies the generated variable z in the
  variant's model and in its RE limit (the history databank must hold it, built on the RE
  forecasts the history uses: the predictions under `'filtered'` RE states), the forecast
  x_exp1_IO = x_exp1_RE + abar, the type's system and its `ntypes('forecasts')` branch (history:
  f^RE + abar; model: read and assert), and the removal of the `'re_mean'` guards in
  `load_options.m` and `agent_types.m` (br23 in `test_options` BR2 then loads).
- Not done: USER_GUIDE and FEATURES rows (P6), scenario files (P7). Left as they were: the header
  of `update_learning.m` (describes the 'rls' step only), the `defaults.m` comment that lists P5
  among the guarded options, and the summary label of `test_options` BR2.

**P4 done (2026-10-21).** The generalised anchor (E4) with level types, the intercept-only type, the
term `re1(...)`, the anchored diagnostic reference, and fitness on transformed forecasts.
- New `toolbox/+hetlearn/anchor_coefficients.m`: `E_{t-j} z_{t+h} = k + C s_{t-j}` for any list of
  targets (variable, h >= 0, j + h >= 1) in a solved economy, from `sspace` (`k = K_z`, `c = T_z`,
  then p = j + h - 1 times `k = c K_b + k`, `c = c T_b`). Chain entries (state, target, lag) are solved
  out: `F_t = (I - C_0)^{-1}(k + C_s s_{t-j} + sum_l C_l F_{t-l})`, so a chain state may also stand for
  the agents' own forecast made l periods earlier. A loading of 1e-12 or more on any other state is an
  error, and there is a unit-perturbation check over j + h periods. `re_anchor_coefficients` is now a
  wrapper that performs the same operations in the same order, so A and info are bitwise unchanged
  (SW07: 312 parameters with period-t information, 26 lagged).
- Options: kinds `'level'` and `'re_mean'` and the rule term `re1(...)` run. Their guards are gone from
  `load_options.m` (`not_implemented` now lists nothing) and from `agent_types.m`. A level type
  resolves `info` (`[]` = `expectations.re_info`), has update `'fixed'`, and its base must be a
  non-level type that forecasts its variables. A `'re_mean'` type takes the RE type's variant and
  information.
- Generator: files with level or `'re_mean'` types or `re1` terms are version 8. Transform files keep
  version 7; their key adds the extra anchored terms when there are any, so the P3 files without
  them stay as they were. Level type: `x_exp1_<k> = lev<k>_x__const + sum lev<k>_x__<s>*s{-1}`
  (`s` with period-t information). `'re_mean'`: `x_feRE = x - x_exp1_RE{-1}` (inside `br_x`, so the
  RE limit and the RE filter hold it) and `x_exp1_<k> = x_exp1_RE + alpha_x_feRE__<k>`. `re1(e)`:
  `rule_terms` parses e into targets (`v{+h}`, h >= 0) and weights, and the generator writes the
  anchored expression `re1<k><q>_x__*` on the states dated t-1. The RE type's anchored expression now
  runs over the original states plus extra terms (`anchor_extra`):
  - the memory states `z_REt2` of diagnostic expectations outside the learning set, written in
    `!if ~br_z` blocks inside the equation (IRIS accepts them; checked);
  - partial-adjustment states;
  - with a diagnostic transform on the lagged RE type, `x_DEg_RE{-1}`.

  The anchored version of the aggregate is `(1 + theta)*x_exp1_RE - theta*x_DEg_RE{-1}`, where
  `x_DEg_RE` = anchored `E_{t-1} x_{t+2}` (declared under `!if re_anchored`).
- `load_model`: `anchor_general` computes the RE type's coefficients for files with extra terms. It
  calls `anchor_coefficients` in the model-consistent RE limit (D11) with targets (x, 1) and (x, 2)
  and chains `x_REt2` (lag 0), `x_REt3` (lag 0) and `x_REt3{-1}` (lag 1: the own lag
  `x_DEg_RE{-1}`). Terms whose state does not exist under the toggles are 0. The `re1` values come
  from the model-consistent RE limit with the lagged RE chains solved out (`res.meta.model_values.re1`).
  The level chains (`info.nt.levels`) have one entry per level-0 type; the slot of the economies
  j >= 1 is the level type with the largest k. Refused: an anchored diagnostic reference with
  period-t RE information.
- Engine. New `+engine/anchor_update.m` (`'compute'`, `'params'`, `'value'`) runs in `update_nt`
  after the belief update and before the ALM check. Each chain needs K IRIS solves per quarter: the
  level-0 economy has share 1 on the base, and economy j >= 1 puts share 1 on the slot with the level-j
  coefficients. The initial levels are computed in `ntypes('init')`. A level economy without a
  solution raises `levelNoSolution` under `'none'`; the message gives the base's beliefs and the level
  coefficient on x{-1}. Under `'alm'` and `'plm_alm'` the beliefs revert (event `projection_level`).
  Other engine changes:
  - `facility`: the level coefficients enter the parameter vector (fifth argument of `make_params`);
    the ALM revert restores `S.prev.levels`.
  - `ntypes('forecasts')`: level types use `S.levels` on the history databank (states dated t-1),
    `'re_mean'` = RE forecast + abar, and `re1` terms use their coefficients. In the forecast stage
    all three are asserted against the model (1e-9).
  - `history_db`: under `'filtered'` + `'lagged'`, `x_DEg_RE` comes from `H.predicted` and `x_feRE`
    is rebuilt from the predictions.
  - `ntypes('seed')`: the RE forecast of the history at the origin goes into the forecast databank,
    so `x_feRE` of t0 + 1 uses it.
- Fitness on transformed forecasts (the P3 decision). `ntypes('forecasts')` applies to each type's
  forecast the transforms of its term in `x_exp1` (`score_steps`, from `meta.transforms`):
  multiplier, myopia, diagnostic with its reference, and wedge, all read from the databank. Partial
  adjustment uses the engine's previous value in the history stage and the model's state in the
  forecast stage. The transformed forecast feeds fitness, `FE_<k>`, `f_<k>` and the KOZ forecast
  errors. The untransformed one feeds the rule types' own lags and the paths `x_exp1_<k>`; the record
  carries it as `fb_<k>` when there are transforms. Without transforms nothing changes.
- Gates, `tests/test_anchor.m` (8 checks, about 2 min; registered before `test_br_regression`):
  - A1 fixed-point gate: the anchored RE(t-1) limit's two-step forecast vs its own coefficients
    1.0e-14 (relative); the level-k T-map with level 0 = RE gives RE at levels 1 and 2 (4.6e-15).
  - A2 EGM closed form on the new test package `tests/models/egm` (y = mu + b E y{+1} + u, u AR(1);
    levels 1-3 with information up to t-1 and with period-t information): 8.9e-16.
  - A3 K = 0: a level type at share 0 beside the learner = the two-type `'learning'` run (paths
    1.1e-11, beliefs 2.3e-14).
  - A4 level k on level 0 = RE equals RE: level forecasts vs RE 4.5e-14 over 242 quarters; paths vs
    `tsw07_a1_re` 1.1e-11.
  - A5 anchored DE = model-consistent DE at n_RE = 1: load check 3.0e-13, independent IRFs 3.0e-13.
    The anchored expression loads on the six memory states (up to 0.044) and on `pinf_DEg_RE{-1}`
    (0.084).
  - A6 variant 23 with abar held at 0 = RE: forecasts 1.8e-15, shares 0.5 exactly, paths 7.3e-12.
  - A7 variant 33: re1 = a two-period simulation of the RE limit (9.5e-14 over 16 quarters).
  - A8 variant 18: f_OPT - f_PES = 2g (1.3e-13); OPT share 0.018 at 2022Q2.
  - Against the design prototype (scratch, `proto1.mat` of `br_proto1.m`), levels 1, 2 and 5 at the
    2019Q4 beliefs equal its T-map to 1.3e-14, 1.4e-14 and 3.7e-14.
- Tests whose premise changed: `test_options` BR2 (br01a, br01b, br23, br33 load), `test_ntypes` U5
  (`re1(y{+1} - y)` is valid, so the malformed entry is now `re1(y{-1})`), `test_transforms` E1 (its
  two P4-boundary cases load; replaced by the anchored DE with period-t information, still refused).
- Whole suite at the default thread count (`test_generator` alone, `test_re_info` alone, the rest in
  two sessions): 396 checks in 25 suites, all pass. `test_br_regression` is exact (R1
  byte-identical, R2 max diff 0), `test_ntypes` R3 max diff 0, `test_learning_rules` L14 0;
  `test_transforms` R4 is within its tolerances (R4a 0; R4b-f learning 5.8e-13 or less, paths 1.6e-11
  or less on their own filters).
- Application 1 (live baseline, `a1_learn` plus the section 3 changes, not saved; average inflation
  2022Q3-2026Q2 annualised, discrete-choice shares at the end of 2022Q2):
  - baseline: 3.45% (BR 0.591).
  - 01a and 01b stop in the history stage at the origin, 2022Q2 (`levelNoSolution`). With the
    learners' beliefs at the end of 2022Q2 (alpha 0.083, beta 1.061), the level-1 forecast loads 1.168
    on inflation at t-1, and the level-1 economy has no stable solution (NO_STABLE).
  - 10 (anchored DE): 4.75% (RE 0.456, BR 0.544).
  - 23: 2.94% (RE 0.388, IO 0.612).
  - 33: 2.61% (RE 1.000, FN 0.000).
  - 18: -17.86% (c: OPT 0.018, PES 0.982; pinf: TAR 0.215, EXT 0.785). With fitness on the biased
    forecasts and g = 2.16 at chi 2, the c shares jump between the corners (OPT below 0.1 in 132 of
    242 quarters). From PES 0.98 the forecast runs off (c at -127 by 2023Q2), with no stop, since the
    ALM solves every quarter. Not usable as calibrated: g and chi for 18 (D8) need revisiting before P7.
  - Scoring reruns: 05a 4.59% (RE 0.396, BR 0.604; P3 4.60%), 05b 4.09% (0.416, 0.584; 4.01%), 06 4.97%
    (0.384, 0.616; 4.92%). 29 no longer stops: 6.67% (RE 0.345, BR 0.655; P3 stopped in 2023Q2).
- Left for P6 and later:
  - propagation: the Kalman history, density forecasts, `evaluate`, `decompose` and Ramsey refuse N
    types (and so transforms);
  - the T-map Jacobian diagnostic (`res.learning.levels`) is not recorded;
  - level types on a base whose forecast has its own state (a rule with `self{-k}`, an AR(2) PLM)
    stop at their first quarter;
  - not built: a second RE type other than model-consistent with period-t information or a copy of
    RE; the anchored DE reference with period-t information; `re1` in economies whose transforms add
    states;
  - USER_GUIDE and FEATURES rows, and the `defaults.m` and `load_options.m` header comments that still
    describe the phase guards (no option is guarded now);
  - scenario files (P7).

**P6 done (2026-10-21).** N agent types and transforms in the Kalman history, the other stages
supported or refused, and the documentation.
- Kalman history (`+engine/kalman_history.m`). With `ctx.nt` it builds the RE-limit share vectors
  (1 on RE before `beliefs.init.date`) and puts the level coefficients in force into the ALM
  parameters (`anchor_update('params')`). Each type's forecast made in t comes from
  `ntypes('forecasts', ..., 'history', t)` on the agents' data. These are the real-time filtered
  values x_{s|s}, with two exceptions:
  - under `re_info = 'lagged'` every `<x>_exp1_RE` and `<x>_DEg_RE` is the prediction x_{t|t-1},
    the convention `history_db` follows with `H.predicted`;
  - the `'re_mean'` target `<x>_feRE` is rebuilt as x_{t|t} minus the RE forecast of t-1 in those
    data, so it is the error of the forecast the agents used (rebuilt under `'current'` too).

  `update_learning` takes its N-type path unchanged. New output
  `res.kalman.ftypes_model_maxdiff`: per type, |forecast before the transforms - the model's
  `<x>_exp1_<k>`|, predicted for t-1 information and filtered for period t. The forecast stage
  needs no change. `ntypes('seed')` writes the rule types' own forecasts, and with a `'re_mean'`
  type the RE forecast, at the origin, so those elements of the starting state are the agents'
  values, not a_{origin|origin}. `ntypes('init')` accepts `'kalman'` and still refuses
  `'inversion'`. Two-type runs keep the old code path unchanged.
- Stages:

  | Stage | Choice | How |
  |---|---|---|
  | Density forecasts | support | general path for N types (each draw re-runs the forecast stage, which takes N types); the fast path stays two-type; summarised series `n_model_<k>_<x>` per type and the beliefs of each learning type's PLM equation of x (`alpha_pinf__BR`, `alpha_pinf_feRE__IO`); the refusal in `ntypes('init')` is gone |
  | `hetlearn.evaluate` | support | an N-type variant shares an RE filter only with variants of the same generated file, parameter and std values, toggles and learning set (its RE filter model is its own RE limit; before, it could be grouped with a two-type variant of the same PLM) |
  | `hetlearn.decompose` | support, two refusals | `'tv'` over the forecast takes the keyed beliefs and every type's `n_model_<k>` as its share parameter; in the RE-model periods the type forecasts (`'plm'`, `'rule'`, `'level'`, `'re_mean'`) are left out of the reconstruction check, as `<x>_exp1_BR`. Refused with `hetlearn:options:unsupported`: `'tv'` with level types (their coefficients are not recorded), and any result of `history.mode = 'kalman'`, two-type ones included (the filtered path is not a model path with the filtered shocks, since P_{t|t} never collapses) |
  | Ramsey policy | refuse | `load_options` (`validate_ntype_stages`): `policy.mode = 'ramsey'` with types, transforms or an E2 switching option, `hetlearn:options:unsupported`, naming the options; the Ramsey wrap of the N-type file is not built. The `load_model` errors stay as a fallback |
  | Inversion history | refuse | same function and message pattern (the inversion reads the two-type forecasts from the model) |
- Portfolio through the Kalman history: every scenario of `scenarios/sw07/br_portfolio/` with
  `history.mode = 'kalman'`, `history.re_states = 'smoothed'`, origin 2026Q2, horizon 4,
  `'stochastic'` start, under `config/master_options.m` (facility `'alm'`). Not saved; scratch
  script `p6/p6_variants.m`. All 23 runs (21 variants, `a1_re`, `a1_learn`) complete, 3-12 s each.
  The baseline reproduces P1 (log likelihood -1839.753, inflation RMSE 0.3093). Log likelihood
  from 1966Q1, one-step RMSE 1966Q1-2026Q2 (% per quarter) and facility events:

  | Run | log lik | RMSE pinfobs | RMSE dy | events |
  |---|---|---|---|---|
  | a1_re | -2182.12 | 0.3707 | 0.8287 | |
  | a1_learn | -1839.75 | 0.3093 | 0.8386 | |
  | br01a | -1835.25 | 0.3060 | 0.8618 | 1 projection_level |
  | br01b | -1914.91 | 0.3208 | 0.8546 | 1 projection_level |
  | br04 | -3799.52 | 0.2876 | 1.3109 | |
  | br05a | -5892.81 | 0.2823 | 1.4803 | |
  | br05b | -1709.37 | 0.2799 | 0.8513 | |
  | br06 | -3543.44 | 0.2716 | 1.2485 | |
  | br07 | -1825.28 | 0.3023 | 0.8471 | |
  | br10 | -2025.72 | 0.3312 | 0.8780 | |
  | br17 | -2080.81 | 0.3467 | 0.8831 | |
  | br18 | -2854.69 | 0.2784 | 0.9364 | |
  | br19 | -1723.22 | 0.2803 | 0.8656 | |
  | br20 | -3692.23 | 0.2886 | 0.6974 | |
  | br23 | -2192.77 | 0.3721 | 0.8295 | |
  | br24 | -1702.58 | 0.2814 | 0.8366 | |
  | br25a | -4111.73 | 0.2905 | 0.7113 | 7 projection_alm |
  | br25b | -3661.56 | 0.2915 | 0.6783 | 8 projection_alm |
  | br26 | -1857.61 | 0.3117 | 0.8395 | |
  | br27 | -1785.35 | 0.2953 | 0.8729 | |
  | br29 | -1579.75 | 0.3229 | 0.8407 | |
  | br31 | -1788.24 | 0.3089 | 0.7216 | |
  | br33 | -2487.29 | 0.4288 | 0.8021 | |

  29 and 31 add a shock, so their rows are not like-for-like (D10). The model gap is rounding
  (<= 4.6e-14) for every type whose forecast uses data of one date only. It is not rounding where
  the forecast uses two dates, because the model's lagged states are revised and the agents' data
  real time (the P1 note): 25a 13 (AR(2) on seven variables), 33 5.6 (`dn{-1}`), 25b 5.3 (M3,
  AR(2)), 17 0.2-0.9 (rules with `x{-2}` or `self{-1}`). These are the forecasts the ALM uses
  against the ones the agents record and score. P7 should report it for those variants.
- Options and docs: `defaults.m` and `load_options.m` lose the phase-guard comments; the empty
  `not_implemented` and its two helpers (`rule_expr`, `struct2cell_or_empty`) are gone. New: USER_GUIDE
  section 9 (options, one example per mechanism with its parameter source, stage matrix, outputs),
  FEATURES rows 200-224 (machinery) and 230-250 (mechanisms), and a README_PIPELINE log line. The
  USER_GUIDE baseline rows now give facility `'alm'`.
- Gates (new checks): `test_kalman` K6: the RE/BR pair spelled out equals the two-type Kalman run,
  max diff 0 in errors, l_t, F_t, filtered and predicted databanks, a and P at the origin,
  learning, paths, events and state. K7: a TB type at share 0 differs from the two-type run by
  1.9e-12 in the errors and 6.4e-12 in the log likelihood (larger state vector); a multiplier at 1
  differs by 0. K8: L0, L1, L2 and IO model gaps 6e-15 to 1.4e-14, share sums 2e-16. `test_density`
  D10 (pair = two-type density, 0; TB shares sum to 1 in every draw), `test_evaluate` V5 (pair =
  two-type, 0; TB = separate real-time runs, 0), `test_decompose` C7 (pair = two-type, 0; TB
  additive, rebuild 6.8e-14; both refusals), `test_options` BR4 (8 cases).
- Whole suite at the default thread count: `test_generator` alone, `test_re_info` alone, then
  `test_anchored`, the other suites of the first half and those of the second half in three
  parallel sessions. 403 checks in 25 suites, all pass (21, 24, 16, 142, 200; about 9 minutes
  of wall time). `test_br_regression` is exact (R1 byte-identical, R2 max diff 0 in all 30 runs),
  K1-K5 as in P1 (K1 8.7e-13, K4 log likelihood diff 4.6e-13).
- Left for P7: the portfolio runner with the Kalman RMSE tables (the rows above are this phase's
  check, not saved), the report section, and the flag for the model gap of 17, 25a, 25b and 33.

---------------------------------------------------------------------------------------------

## 7. Decisions for the main session

| # | Decision | Recommendation |
|---|---|---|
| D1 | Flex-price expectations under `scope 'all'` (Meggiorini says "all expectational variables") | keep the five flex expectations RE (they define potential output for the Taylor rule); P3 shows no change in the impact responses to em, epinf, eb |
| D2 | Scope of the learning-rule variants | source scope where the source is an SW07 paper (20 HMOZ, 25 SW: seven sticky expectations, all learners); the baseline slot (inflation, RE + learner) for 23, 24, 26, 27 |
| D3 | Facility `'none'` in the portfolio although some variants have unstable regions (P4: all-STR; De Grauwe literal) | keep `'none'` (the baseline rule) and report stops; add one flagged sensitivity with `'alm'` only for variants that stop |
| D4 | DE without LSY's current-variable terms, theta from a Rotemberg SW07 | accept; state it in the report |
| D5 | CD horizon profile with t-1 information | geometric m^h (Gabaix's operator) for CD, flat for shallow reasoning, so the two differ in mechanism as well as value |
| D6 | De Grauwe's base for optimists/pessimists | model-consistent E_t c_{t+1} plus or minus g (the literal steady-state base has no solution once extrapolators dominate) |
| D7 | Populations: level-k and FN replace the RE type or the learner; target believers are added | as in section 3 (EGM: levels replace RE; FN: a naive rule in the learner's place; HL beside RE) |
| D8 | Unsourced values: hyperbolic alpha 0.25; De Grauwe g = sigma(y - yf)/2; BMA sigma^2 (model-implied); ACD sigma (51% band share) and projection loadings; KF V mapping; wedge /4 mapping and zero mean; GHL-to-SW07 equation mapping; AH beta units; equal initial shares; switching chi/memory for 1, 18, 19 | approve as proposed, or name replacements |
| D9 | Name of the Kalman history mode | `'kalman'`; the reserved hook `'hetero_filter'` errors with a pointer to it |
| D10 | Wedge variants in the RMSE table | include, flagged, with the log-likelihood beside the RMSE |
| D11 | Anchor model when transforms are present | the variant's own RE limit (collapse tests hold, `'rational'` is the variant's RE benchmark); wedges off in it |
| D12 | Forecast start under `'kalman'` | the filtered state at the origin (one-sided, consistent); IRFs keep the baseline's `re_smoother` history |
| D13 | Estimation module | leave `estimation/` unchanged; use gate K4 as the cross-check |

Prototype files (in a session scratchpad folder outside the project, not versioned):
`<scratchpad>\br_design\`:
`br_proto1.m` (P1 GIRFs and gate, P2 solvability, P3 level-k, RE RMSE), `br_proto2.m` (Kalman
history, gates K1 and K2, baseline RMSE), `br_proto3.m` (transform determinacy), `br_proto4.m`
(heuristic rules), logs `proto1.log` to `proto4.log`, model files `out/p3_v*.model`,
`out/p4_v*.model`; they run on the copy `br_design/proj/` (toolbox, config, SW07 package and its
non-real-time caches as of 2026-10-20).

---------------------------------------------------------------------------------------------

## 8. Portfolio cut to seven variants (2026-10-22)

User decision after the audit (`docs/BR_audit.txt`, scores 1-5): keep the variants scored 4 or 5,
drop every variant scored 3 or below (the four "fix" candidates 5a, 17, 20 and 31 included, the
fixes were not attempted), and remove every option, code path, test and document entry that only
the dropped variants used. Copies of the code, tests, scenario files, runners, report builders,
`results/br_portfolio/` and the docs as they stood before the cut are in
`archive/2026-10-22_br_cleanup/` (with the dropped variants' `results/<id>/` folders).

**Kept (score):** 5b cognitive discounting on the learning set (4), 7 myopia and anchoring in the
price Phillips curve (4), 10 diagnostic expectations (4), 19 target believers (4), 23 intercept
learning on the RE forecast error (4), 24 mean-only learning (5), 26 constant gain 0.018 (4).

**Dropped:**

| Variant | Score | Reason (audit section 3) |
|---|---|---|
| 1a, 1b level-k on a learned level 0 | 2 | boom-bust paths (inflation 17.7 to -7.9%), five facility events in Application 1; the level-0 seed is explosive at the 2022Q2 origin |
| 4 shallow reasoning | 2 | monetary transmission almost gone, dLL -1960; GHL-to-SW07 equation mapping is ours |
| 5a CD on every expectation | 3 | dLL -4053; m estimated jointly with the structural parameters of another model; 5b represents CD |
| 6 hyperbolic discounting | 2 | indistinguishable from 5a at SW07's two horizons; alpha unsourced |
| 17 four heuristics | 3 | intensity in lab units, shares stuck at 0.16-0.33 (the switching does nothing); Kalman model gap 0.90 |
| 18 De Grauwe | 1 | explosive cycles in the IRFs; calibration picked by an outcome screen; g unsourced |
| 20 SAC learning | 3 | IRFs still rising at h = 19, monetary transmission near zero, dLL -1852; gain column and structural parameters not HMOZ's |
| 25a, 25b Kalman-filter learning | 1 | inflation falling 3.6-6.6 pp a year at the end, 7-8 facility events, non-decaying IRFs; V mapping proposed |
| 27 Bayesian model averaging | 1 | learners' share at 1.000, inflation to 22.7%, four facility events; sigma^2 proposed |
| 29 survey wedge | 2 | no survey observable to identify the wedge; shares at a corner in the forecast |
| 31 confidence shocks | 3 | sigma calibrated by us and loadings proposed (ACD's values not sourced) |
| 33 Farmer-Nicolo belief | 2 | collapses onto RE in Application 1; worst inflation RMSE (1.39x); FN's model change not built |

**Removed options and code** (each used only by dropped variants; checked against the kept list):

| Removed | Was used by | Where |
|---|---|---|
| type kind `'level'` (fields `base`, `k`), its per-quarter anchor iteration, event `projection_level`, error `levelNoSolution` | 1a, 1b | `+engine/anchor_update.m` deleted; `agent_types`, `extend_model` (lev coefficients), `load_model` (`nt.levels`), `ntypes`, `update_learning`, `facility` (5th argument of `make_params`), `forecast`, `kalman_history`, `decompose` |
| rule terms `self{-k}`, `mean`, `dn`, `re1(...)`; rule types' mean beliefs and own-lag seeding | 17, 33 | `+plm/rule_terms.m`, `extend_model`, `load_model` (`re1_values`), `ntypes` |
| `beliefs.update = 'kf'`, `beliefs.kf` | 25a, 25b | `+rls/kf.m` deleted; `update_learning` |
| `beliefs.update = 'sac'`, event `sac_bound` | 20 | `+rls/sac.m` deleted; `update_learning` |
| `gain.rule = 'decreasing'`, `gain.decreasing` | 17 (LAA anchor) | `+gain/decreasing.m` deleted |
| `switching.inertia`, `switching.costs`, type field `cost`, `switching.fitness = 'unnormalized'` (and memory 1) | 17, 27 | `+switching/discrete_choice_n.m` (now `(FE, Uprev, chi, omega)`), `init_fitness_n.m` (now `(n0, chi)`), `ntypes`, `update_learning` |
| `switching.intensity = 'model:bma'` | 27 | `load_model` (`model_values`), `ntypes`, `assemble` |
| transform kinds `'wedge'` (field `factor`, shocks, `xi_<shock>` states, `model:projection`, `model:acd51`, `model:sd_ygap_half`) and `'partial_adjustment'` | 18, 29, 31 (partial adjustment: no variant) | `extend_model` (`tf_*`), `load_model` (`tf_*`), `ntypes` score steps |
| multiplier field `profile` (`'flat'`, `'hyperbolic'`; the multiplier is m^h) | 4, 6 | `load_options`, `load_model` |
| per-type fields `variant`, `info`, `plm`, `update`, `gain`, `variables`; a second `'re'` type | 18, 25b, 17 | `load_options`, `agent_types` (every type now inherits), dead branches of `extend_model` |
| runner mode `run_br_app1('calib18')` and `app1_calib18.csv`; the wedge shocks `e_wpinf`, `e_xi` in the IRF portfolio; model-gap flags of 17, 25a, 25b, 33 | 18, 29, 31, 17, 25, 33 | `run_br_app1.m`, `run_br_portfolio.m`, both report builders |
| test suite `test_learning_rules.m`, test packages `tests/models/ah`, `tests/models/egm`, and the checks of the removed features in the other suites | | `tests/` |

Kept machinery (used by the seven): N agent types with kinds `'re'` (RE only), `'plm'`, `'rule'`
(numbers, `x{-k}`, other transition variables with lags, `params` constants) and `'re_mean'`;
`shares.init`, `shares.fixed` and the N-type mode semantics; the normalized N-type logit; transforms
`'multiplier'` (m^h), `'diagnostic'` (with the anchored reference `x_DEg_RE` and the memory states of
the generalised anchor) and `'myopia_anchoring'`, scopes, `exclude`, `types` and equation copies;
fitness on transformed forecasts; `hetlearn.anchor_coefficients`; the mean-only PLM; the Kalman
history with N types; density, evaluate and decompose with N types.

Compatibility: `load_options` raises `hetlearn:options:removed` for a removed option set to anything
but its old default, and drops the removed fields when a merged tree saved before the cut holds them
at their defaults (`res.cfg` of 2026-10-20/21 runs keeps loading). The generator's file key keeps its
2026-10-21 form, so the kept variants' generated files keep their names.

Checks of the cut: the five N-type files of the kept variants regenerated with `'force'` are
byte-identical to the 2026-10-21 files; the seven kept runs (Application 1, not saved) equal their
saved 2026-10-21 results with max difference 0 in paths, learning records and final state (the
state no longer carries `fh` and `pa`), events equal. Reruns on 2026-10-22: `run_br_app1` 9 of 9 ok with
average inflation 2022Q3-2026Q2 unchanged (RE(t-1) 2.59%, baseline 3.45%, 5b 4.09%, 7 3.42%, 10 4.75%,
19 3.38%, 23 2.94%, 24 3.08%, 26 3.06%); `run_br_portfolio` 126 shocked forecasts and 9 Kalman
histories ok, log likelihoods as on 2026-10-21, IRFs within 1e-10 of the 2026-10-21 CSVs (rounding in
the 12th digit), the 8 check pairs at diff 0; no facility event in any run. Tests at the default thread count in five
sessions (`test_generator`, `test_re_info`, `test_anchored`, then two halves): 364 checks in 24
suites, all pass (403 in 25 before the cut: `test_learning_rules` (15) removed, `test_ntypes` 20 to
13, `test_transforms` 31 to 19 with a new check F1 of fitness on transformed forecasts, `test_anchor`
8 to 3, the other suites adapted at equal counts); `test_br_regression` exact (R1 byte-identical, R2
max diff 0). The first pass failed two `test_transforms` checks, both mistakes in the test code (a
`struct` cell expansion in F1, an E1 case that does act on the other forward variables); fixed and
rerun alone, 19 of 19.
