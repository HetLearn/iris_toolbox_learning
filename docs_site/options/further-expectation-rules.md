# Further expectation rules

Beyond the baseline pair of rational expectations (RE) agents and learners, three groups of
options build further expectation rules: more than two types of agents, shares over those
types, and transforms of the expectations as they enter the model. All are off by default.
[Application 7](../applications/app7-rules.md) uses them for seven rules from the
bounded-rationality literature, with the code and results of each.

| Options | What they do |
|---|---|
| `expectations.types` | the population of forecasting types |
| `shares.init`, `shares.fixed` | initial or fixed shares by type name |
| `expectations.transforms` | transforms of the expectations as they enter the model |

Two of the seven rules (mean-only learners and the experience-based gain) need none of these
options: they use the [perceived law of motion](plm.md) and [gain](gains.md) options. A
scenario that sets none of the three groups runs the two-type code unchanged; the test
`tests/test_br_regression.m` checks that its results are bit-identical.

## Agent types: `expectations.types`

A cell array of structs, one per type:

| Field | Values | Meaning |
|---|---|---|
| `name` | letters and digits, starting with a letter; required | Suffix of the type's forecast `<x>_exp1_<name>` and of its share `n_<name>_<x>` |
| `kind` | `'re'`, `'plm'`, `'rule'`, `'re_mean'`; required | The RE forecast (only the type named `RE`); a learned perceived law of motion (PLM); a fixed linear rule; the RE forecast plus a learned mean of its own error |
| `rule` | text, or `struct('expr', <text>, 'params', struct(...))` | `'rule'` types only: a linear expression in `x{-k}`, other transition variables with lags, numbers and named constants from `params` |

Each kind takes its settings from the global options: `'re'` from `expectations.re_variant`
and `.re_info`; `'plm'` from `beliefs.plm`, `beliefs.info`, `beliefs.update` and `gain`;
`'rule'` from `beliefs.info`; `'re_mean'` from the RE type and, for its learned mean, from
`beliefs.update` and `gain`. Every type forecasts every learning variable. The baseline
learners are the type named `BR` (bounded rationality) of kind `'plm'`.

```matlab
% Target believers beside RE agents and learners (Application 7)
cfg = a1_learn(); cfg.id = 'my_target_believers';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'BR', 'kind', 'plm'), ...
    struct('name', 'TB', 'kind', 'rule', 'rule', '0')};
cfg.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
res = hetlearn.run(cfg, 'save', false);
```

## Shares over N types

The baseline discrete choice extends to N types in each share group:

\[
\zeta_{k,t} = \omega\, \zeta_{k,t-1} - (1-\omega) FE_{k,t}, \qquad
n_{k,t} = \frac{\exp(\chi\, \zeta_{k,t})}{\sum_j \exp(\chi\, \zeta_{j,t})},
\]

with \(\zeta_{k,t}\) the fitness of type k, \(\chi\) = `switching.intensity`,
\(\omega\) = `switching.memory` and \(FE_{k,t}\) the squared error of type k's forecast as it
enters the model (after any transform).

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

The values are model parameters, so one generated file serves every value.

```matlab
% Cognitive discounting of both types' inflation expectations, m = 0.94,
% outside the flexible-price block of the Smets-Wouters model
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg = a1_learn(); cfg.id = 'my_cd';
cfg.expectations.transforms = struct('kind', 'multiplier', 'types', 'all', ...
    'value', 0.94, 'scope', 'learning', 'exclude', {FLEX});
res = hetlearn.run(cfg, 'save', false);
```

A diagnostic transform must be the first transform on its expectation and acts on RE types and
model-consistent expectations only. With period-t RE information the anchored reference is not
built: keep `expectations.re_info = 'lagged'` (the baseline) or use
`re_variant = 'model_consistent'`.

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
| `res.learning.<x>` | for each type k: `n_<k>` (share at the end of the quarter), `n_model_<k>` (share in the model), `U_<k>` (fitness \(\zeta_k\)), `FE_<k>` (squared error), `f_<k>` (forecast as it enters the model), `fb_<k>` (before transforms, with transforms only) |
| `res.learning.<target>__<k>` | beliefs, gain and moments of each learning type, e.g. `res.learning.pinf__BR.alpha_pinf__BR`, `res.learning.pinf_feRE__IO.alpha_pinf_feRE__IO` |
| `res.paths.<x>_exp1_<k>` | each type's forecasts |
| `res.meta.types`, `res.meta.model_values` | the resolved types and the transform values |

The generated model of a run with types or transforms is
`models/<name>/generated/<name>_ext_n<hash>.model`.

## Further reading

- `docs/USER_GUIDE.md`, section 9: every option of this page with its checks.
- [Technical appendix](../reference/technical-appendix.md): the formulas and timing of each
  rule.
