# Further expectation rules

Beyond the baseline pair of RE agents and AR(1) learners, the toolbox has seven further
expectation rules from the bounded-rationality literature. Each one is a scenario in
`scenarios/sw07/br_portfolio/` that starts from `a1_learn` and adds a few lines, so it inherits
the project baseline and runs Application 1 (the forecast from the 2022Q2 peak).

| No. | Rule | Scenario | What it changes | Value and source |
|---|---|---|---|---|
| 5b | Cognitive discounting on the learning set | `br05b_cd_learn` | inflation expectations of both types multiplied by \(m^h\) | \(m = 0.94\), Meggiorini and Milani (2021) |
| 7 | Myopia and anchoring | `br07_myopia_anchoring` | the inflation expectation of the price Phillips curve | \((\omega_f, b) = (0.52, 0.434)\), Angeletos and Huo (2021) |
| 10 | Diagnostic expectations | `br10_diagnostic` | the RE agents' expectations become diagnostic | \(\theta = 0.44\), L'Huillier, Singh and Yoo (2024) |
| 19 | Target believers | `br19_target_believers` | a third type that always forecasts the steady state | shares 1/3 each at the start; Hommes and Lustenhouwer (2019) |
| 23 | Intercept-only learners | `br23_intercept_only` | learners forecast the RE forecast plus a learned mean of its error | baseline gain; Gáti (2023), Carvalho, Eusepi, Moench and Preston (2023) |
| 24 | Mean-only learners | `br24_mean_only` | the learners' PLM keeps only the constant | baseline gain |
| 26 | Experience-based gain | `br26_experience` | the AR(1) learners use a constant gain of 0.018 | Malmendier and Nagel (2016), Nagel and Xu (2022) |

Rules 24 and 26 use the PLM and gain options of the earlier pages. The other five use three
groups of options, all off by default:

| Options | What they do |
|---|---|
| `expectations.types` | the population of forecasting types (rules 19 and 23) |
| `shares.init`, `shares.fixed` | initial or fixed shares by type name |
| `expectations.transforms` | transforms of the expectations as they enter the model (rules 5b, 7, 10) |

A scenario that sets none of them runs the two-type code unchanged; the test
`tests/test_br_regression.m` checks that its results are bit-identical.

## Agent types: `expectations.types`

A cell array of structs, one per type:

| Field | Values | Meaning |
|---|---|---|
| `name` | letters and digits, starting with a letter; required | Suffix of the type's forecast `<x>_exp1_<name>` and of its share `n_<name>_<x>` |
| `kind` | `'re'`, `'plm'`, `'rule'`, `'re_mean'`; required | The RE forecast (only the type named `RE`); a learned PLM; a fixed linear rule; the RE forecast plus a learned mean of its own error |
| `rule` | text, or `struct('expr', <text>, 'params', struct(...))` | `'rule'` types only: a linear expression in `x{-k}`, other transition variables with lags, numbers and named constants from `params` |

Each kind takes its settings from the global options: `'re'` from `expectations.re_variant`
and `.re_info`; `'plm'` from `beliefs.plm`, `beliefs.info`, `beliefs.update` and `gain`;
`'rule'` from `beliefs.info`; `'re_mean'` from the RE type and, for its learned mean, from
`beliefs.update` and `gain`. Every type forecasts every learning variable.

## Shares over N types

The baseline discrete choice extends to N types in each share group:

\[
U_{k,t} = \omega U_{k,t-1} - (1-\omega) FE_{k,t}, \qquad
n_{k,t} = \frac{\exp(\chi U_{k,t})}{\sum_j \exp(\chi U_{j,t})},
\]

with \(\chi\) = `switching.intensity`, \(\omega\) = `switching.memory` and \(FE_{k,t}\) the squared
error of type k's forecast as it enters the model (after any transform).

| Option | Values (default first) | Meaning |
|---|---|---|
| `shares.init` | `[]`, struct by type name | Initial shares, summing to 1; `[]` = `shares.init_n2` for the RE/BR pair, equal shares otherwise |
| `shares.fixed` | `[]`, struct by type name | Mode `'fixed_shares'`; not together with `shares.fixed_n2` |

## Forecast transforms: `expectations.transforms`

One struct per transform, applied to the one-step expectations as they enter the model:

| `kind` | Expectation of a base forecast \(f\) | `value` (identity) |
|---|---|---|
| `'multiplier'` | \(m^h f\), with \(h = 2\) for a forecast made on t-1 information, else 1 | \(m\) (1) |
| `'diagnostic'` | \((1+\theta) f - \theta f^{ref}\), \(f^{ref}\) = the same forecast made one quarter earlier | \(\theta\) (0) |
| `'myopia_anchoring'` | \(\omega_f f + b\, x_{t-1}\) | `[omega_f b]` (`[1 0]`) |

| Field | Values | Meaning |
|---|---|---|
| `types` | `'all'` or type names | Which types' forecasts are transformed; `'all'` also covers the model-consistent expectations outside the learning set |
| `scope` | `'learning'` (default), `'all'`, or a cellstr of variables and `'x@<label>'` entries | Which expectations; `'x@<label>'` acts in one equation only, named by its exact label in the model file |
| `exclude` | cellstr | Variables taken out of the scope |

The values are model parameters, so one generated file serves every value. The scenarios
exclude the SW07 flexible-price block, `FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'}`, so
the flexible-price economy behind potential output keeps its RE expectations.

## The seven rules

### 5b. Cognitive discounting on the learning set

Agents shrink their forecasts toward the steady state (Gabaix 2020). Here both types' inflation
expectations are multiplied by \(m^h\); with t-1 information \(h = 2\), so the factor is
\(0.94^2\). \(m = 0.94\) is Meggiorini and Milani's (2021) estimate for the US, 1960-2007, from
their own model rather than SW07.

```matlab
function cfg = br05b_cd_learn()
cfg = a1_learn();
cfg.id = 'br05b_cd_learn';
cfg.title = 'BR 5b: cognitive discounting on the learning set, m = 0.94';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'multiplier', 'types', 'all', ...
    'value', 0.94, 'scope', 'learning', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### 7. Myopia and anchoring

Angeletos and Huo (2021) show that sticky, noisy information makes the Phillips curve behave
as if expectations were myopic and anchored to the past: the expectation becomes
\(\omega_f E\pi_{t+1} + b\,\pi_{t-1}\). The transform acts only in the price Phillips curve, for
all types, with \((\omega_f, \omega_b) = (0.52, 0.43)\) from their Table 1 and
\(b = 0.43/0.99 = 0.434\). SW07 keeps its own price indexation, so this backward weight comes on
top of it.

```matlab
function cfg = br07_myopia_anchoring()
cfg = a1_learn();
cfg.id = 'br07_myopia_anchoring';
cfg.title = 'BR 7: myopia and anchoring in the price Phillips curve (0.52, 0.434)';
cfg.expectations.transforms = struct('kind', 'myopia_anchoring', 'types', 'all', 'value', [0.52 0.434], ...
    'scope', {{'pinf@Phillips curve, price setting'}});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### 10. Diagnostic expectations

Diagnostic agents overreact to news: their forecast is
\((1+\theta) E_t x_{t+1} - \theta E_{t-1} x_{t+1}\) (one-period memory). Here they replace the RE
agents for every forward-looking expectation outside the flexible-price block; the learners
are unchanged. Because the baseline RE type uses t-1 information, the reference forecast of
inflation is the anchored \(E_{t-2}\pi_{t+1}\). \(\theta = 0.44\) is L'Huillier, Singh and Yoo's
(2024) estimate in SW07 with Rotemberg pricing.

```matlab
function cfg = br10_diagnostic()
cfg = a1_learn();
cfg.id = 'br10_diagnostic';
cfg.title = 'BR 10: diagnostic expectations replace RE, theta = 0.44';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, ...
    'scope', 'all', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

A diagnostic transform must be the first transform on its expectation and acts on RE types and
model-consistent expectations only. With period-t RE information the anchored reference is not
built: keep `expectations.re_info = 'lagged'` (the baseline) or use
`re_variant = 'model_consistent'`.

### 19. Target believers

A third type of agent always forecasts the inflation target, the steady state (0 in
deviations); its share measures the credibility of the target (Hommes and Lustenhouwer 2019).
The three types switch as in the baseline (\(\chi = 2\), memory 0.8), starting from a third
each.

```matlab
function cfg = br19_target_believers()
cfg = a1_learn();
cfg.id = 'br19_target_believers';
cfg.title = 'BR 19: target believers added beside RE agents and learners';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'BR', 'kind', 'plm'), ...
    struct('name', 'TB', 'kind', 'rule', 'rule', '0')};
cfg.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

The rule can be any fixed linear expression, for example a naive forecaster
`struct('name', 'NV', 'kind', 'rule', 'rule', 'x{-1}')`, or one with named constants,
`'rule', struct('expr', 'a*x{-1}', 'params', struct('a', 0.5))`.

### 23. Intercept-only learners

The learners know the structure of the economy (they use the RE forecast) but not its long-run
level: they forecast the RE forecast plus a learned mean \(\bar a\) of that forecast's own
error, \(x_t - E^{RE}_{t-1} x_t\) (Gáti 2023; Carvalho, Eusepi, Moench and Preston 2023). The
mean is learned with the baseline's KOZ gain. They replace the AR(1) learners and switch
against the RE agents as in the baseline. Gáti's smooth anchoring function is not part of this
rule, so the paths stay close to RE.

```matlab
function cfg = br23_intercept_only()
cfg = a1_learn();
cfg.id = 'br23_intercept_only';
cfg.title = 'BR 23: intercept-only learners with RE slopes replace the AR(1) learners';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'IO', 'kind', 're_mean')};
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

With \(\bar a\) held at 0 this type forecasts exactly as the RE type. Its learned mean is
`res.learning.pinf_feRE__IO.alpha_pinf_feRE__IO`.

### 24. Mean-only learners

The learners' inflation PLM keeps only the constant, so their forecast is the learned mean:
adaptive expectations by exponential smoothing, \(\alpha_t = \alpha_{t-1} + g_t(\pi_t -
\alpha_{t-1})\), with the baseline's KOZ gain. No new option is needed.

```matlab
function cfg = br24_mean_only()
cfg = a1_learn();
cfg.id = 'br24_mean_only';
cfg.title = 'BR 24: mean-only inflation learners (exponential smoothing)';
cfg.beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### 26. Experience-based gain

In Malmendier and Nagel (2016) people weight the inflation they have lived through; in the
aggregate this is close to constant-gain learning with a gain of about 0.018 per quarter
(Nagel and Xu 2022; Malmendier and Nagel's best-matching constant gain is 0.0175). The AR(1)
learners use this gain instead of the KOZ gain. Cohorts are not modelled.

```matlab
function cfg = br26_experience()
cfg = a1_learn();
cfg.id = 'br26_experience';
cfg.title = 'BR 26: experience-based learning in aggregate, constant gain 0.018';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.018;
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

## Results

Run all seven and the two references:

```matlab
run_br_app1('run')          % a1_re, a1_learn, then the seven rules; about two minutes
run_br_app1('csv')          % results/br_portfolio/app1_*.csv
run_br_portfolio('irf')     % impulse responses from each rule's own 2019Q4 state
run_br_portfolio('rmse')    % Kalman histories: one-step RMSE and log likelihood, 1966Q1-2026Q2
run_br_portfolio('csv')     % results/br_portfolio/irf_*.csv, rmse_*.csv
```

Each rule on its own: `res = hetlearn.run(br19_target_believers());`.

Application 1 and the in-sample fit, from `results/br_portfolio/app1_summary.csv` and
`rmse_long.csv` (runs of 2026-10-22):

| Rule | Avg. inflation 2022Q3-2026Q2 (%) | Peak gap to RE (pp) | Shares at the end of 2022Q2 | Inflation RMSE, one-step (pp) | RMSE / RE(t-1) | Log likelihood |
|---|---:|---:|---|---:|---:|---:|
| RE(t-1), `a1_re` | 2.59 | | | 1.483 | 1.000 | −2182.1 |
| Baseline, `a1_learn` | 3.45 | 3.54 (2023Q1) | RE 0.409, BR 0.591 | 1.237 | 0.834 | −1839.8 |
| 5b cognitive discounting | 4.09 | 3.23 (2023Q1) | RE 0.416, BR 0.584 | 1.120 | 0.755 | −1709.4 |
| 7 myopia and anchoring | 3.42 | 3.68 (2023Q1) | RE 0.483, BR 0.517 | 1.209 | 0.816 | −1825.3 |
| 10 diagnostic | 4.75 | 4.74 (2023Q1) | RE 0.456, BR 0.544 | 1.325 | 0.894 | −2025.7 |
| 19 target believers | 3.38 | 2.36 (2022Q4) | RE 0.340, BR 0.491, TB 0.169 | 1.121 | 0.756 | −1723.2 |
| 23 intercept-only | 2.94 | 0.69 (2022Q4) | RE 0.388, IO 0.612 | 1.488 | 1.004 | −2192.8 |
| 24 mean-only | 3.08 | 0.89 (2023Q4) | RE 0.710, BR 0.290 | 1.125 | 0.759 | −1702.6 |
| 26 experience-based gain | 3.06 | 2.11 (2022Q4) | RE 0.425, BR 0.575 | 1.247 | 0.841 | −1857.6 |

The RMSE is of annualised inflation (percentage points), from the Kalman history
(`history.mode = 'kalman'`) over 1966Q1-2026Q2. The projection facility acts in none of these
runs.

The two portfolio reports draw these results: `reports/sw07_br_app1_report.html` (Application 1:
paths, shares, settings of each rule) and `reports/sw07_br_portfolio_report.html` (impulse
responses to each SW07 shock from 2019Q4, and the RMSE by subsample). They are built locally by
`python reports/build_br_app1_report.py` and `python reports/build_br_portfolio_report.py` from
`results/br_portfolio/`; generated HTML is not kept in the repository.

## Where the rules can be used

| Stage | With types or transforms |
|---|---|
| History, `history.mode = 're_smoother'` or `'kalman'` | supported |
| Forecast and scenario stage, conditions, shocks | supported |
| Density forecasts | supported (each draw re-runs the forecast) |
| `hetlearn.evaluate` | supported |
| `hetlearn.decompose` | supported, except for results of `history.mode = 'kalman'` |
| History, `history.mode = 'inversion'` | not supported (`hetlearn:options:unsupported`) |
| Ramsey policy | not supported (`hetlearn:options:unsupported`) |

## Outputs

| Output | Content |
|---|---|
| `res.learning.<x>` | for each type k: `n_<k>` (share at the end of the quarter), `n_model_<k>` (share in the model), `U_<k>` (fitness), `FE_<k>` (squared error), `f_<k>` (forecast as it enters the model), `fb_<k>` (before transforms, with transforms only) |
| `res.learning.<target>__<k>` | beliefs, gain and moments of each learning type, e.g. `res.learning.pinf__BR.alpha_pinf__BR`, `res.learning.pinf_feRE__IO.alpha_pinf_feRE__IO` |
| `res.paths.<x>_exp1_<k>` | each type's forecasts |
| `res.meta.types`, `res.meta.model_values` | the resolved types and the transform values |

The generated model of a run with types or transforms is
`models/<name>/generated/<name>_ext_n<hash>.model`.

## Further reading

- `docs/USER_GUIDE.md`, section 9: every option of this page with its checks.
- `docs/DESIGN_br_extensions.md`: the formulas, timing and units of each rule (section 2), the
  scenario rows (section 3) and the evidence for each parameter value.
- [Technical appendix](../reference/technical-appendix.md).
