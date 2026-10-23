# RE agents

Two options decide how the rational expectations (RE) agents of a learning variable forecast.

| Option | Values (default first) | Meaning |
|---|---|---|
| `expectations.re_variant` | `'anchored'`, `'model_consistent'` | Use the forecast of the pure-RE model at the current state, or forecast the heterogeneous economy itself |
| `expectations.re_info` | `'current'`, `'lagged'` | Information up to t (\(E_t x_{t+1}\)) or up to t-1 (\(E_{t-1} x_{t+1}\)). Project baseline: `'lagged'` |

## Anchored or model-consistent

**Anchored** (default; Özden 2025, sec. 2.3.1). RE agents forecast as if everyone were
rational: their forecast of \(x_{t+1}\) is the RE model's decision rule evaluated at the current
state, a fixed linear function of the state variables. `hetlearn.re_anchor_coefficients`
computes the coefficients once per parameter set, and they enter the generated model as
parameters (`are_pinf__const`, `are_pinf__c`, ...). The model stays easy to solve whatever the
learners believe.

**Model-consistent.** RE agents know that learners are present and forecast the
heterogeneous economy: \(f^{RE}_t(x) = x_{t+1}\) in the model with the current beliefs and
shares, re-solved every quarter (beliefs and shares are treated as permanent when the model is
solved). With many learners or explosive beliefs this model can lose its stable solution.

```matlab
% Model variant 1: model-consistent RE agents
cfg = a1_learn();
cfg.id = 'v1_mc_learn';
cfg.expectations.re_variant = 'model_consistent';
cfg.compare_with = {'a1_learn'};
res = hetlearn.run(cfg);
```

Project-wide: add `o.expectations.re_variant = 'model_consistent';` to
`config/master_options.m`.

Under the model's own policy rule the two variants give the same RE run (mode `'rational'`),
to 4e-14 in the project. They differ under Ramsey policy, where anchored agents keep the
forecast of the RE model under the rule
([Monetary policy](policy.md#anchored-re-agents-and-ramsey-policy)).

### In the project

`v1_mc_learn` against the baseline `a1_learn` (Application 1):

| | `a1_learn` (anchored) | `v1_mc_learn` (model-consistent) |
|---|---:|---:|
| Average inflation 2022Q3-2026Q2 (%) | 3.45 | 8.14 |
| Inflation 2024Q2 (%) | 2.39 | 14.00 |
| Inflation 2026Q2 (%) | 1.25 | −3.72 |
| Facility events (beliefs reverted) | 0 | 4 |

With model-consistent RE agents the forecast is a boom and bust: inflation rises to 14% in
2024 and falls below zero by 2026. The projection facility reverts the learners' beliefs at
the end of 2022Q2 and in 2023Q1-Q3; under facility `'none'` this run stops in 2022Q3 with no
model solution. In the real-time forecast evaluation the model-consistent variant
(`e03_learn_mc`) has inflation relative root-mean-square errors of 0.747, 1.161 and 1.564 at
horizons 1, 4 and 8, against 0.753, 1.000 and 1.030 for the anchored baseline.

## Information: period t or t-1

```matlab
cfg = a1_learn();
cfg.id = 'a1_learn_reinfo_t';
cfg.expectations.re_info = 'current';     % baseline 'lagged'
res = hetlearn.run(cfg, 'save', false);
```

With `'lagged'` the RE expectation of each learning variable is formed with data up to t-1:
\(E_{t-1} x_{t+1}\) replaces \(E_t x_{t+1}\). Expectations of other variables keep \(E_t\).
Combined with `beliefs.info = 'lagged'`, both types then forecast \(x_{t+1}\) with the same
information, and both fitness errors are two-step errors.

Everything RE in a lagged scenario uses the RE model with t-1 information for the learning
set: the RE benchmark (mode `'rational'`), the anchored forecast, the RE filter and smoother,
the RE agents' forecasts in the history and the RE moments for the initial beliefs. So a lagged
learning run is compared with a lagged RE run:

```matlab
c = a1_re(); c.expectations.re_info = 'lagged';   % already the project baseline
```

The toolbox writes a separate generated file for it, `<name>_ext_<tag>_relag.model`. The
anchored lagged forecast solves out the RE agents' own lagged forecast as a fixed point.

Restrictions (each stops the run with an error):

- `'lagged'` needs a non-empty learning set (`expectations.variables`), so
  `hetlearn.load_options(struct())` fails under the project baseline.
- Learning variables must have a maximum lead of 1.
- Ramsey policy: see [Monetary policy](policy.md#restrictions).

Timing of both types side by side: [Timing and information](timing.md).
