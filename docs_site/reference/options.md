# Options reference

Every field of the option tree returned by `hetlearn.defaults()`
(`toolbox/+hetlearn/defaults.m`). Values are listed default first. "Baseline" is the value the
project sets in `config/master_options.m` where it differs from the default.
`scenarios/sw07/base/sw07_re.m` lists every option as a commented line, a convenient template.

Precedence: `hetlearn.defaults()` < `config/master_options.m` < the scenario. Unknown names stop
the run (`hetlearn:options:unknown`).

## Identification

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `id` | `''` | text | Results folder `results/<id>/`; required | [Forecasts](../options/forecasts-conditions.md) |
| `title` | `''` | text | Title for summaries and reports | |
| `description` | `''` | text | Description for summaries and reports | |
| `model` | `''` | text | Model package under `models/`, or a folder path; required | [Your own model](../your-own-model.md) |
| `model_params` | `''` | `''` or a function name | Parameter file of the package; `''` = `spec.params`. Baseline `'sw07_params_original'` | [Forecasts](../options/forecasts-conditions.md#origin-and-horizon) |

## Forecast

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `forecast.origin` | `[]` | a date (required) | Last quarter of data used | [Forecasts](../options/forecasts-conditions.md) |
| `forecast.horizon` | `16` | positive integer | Forecast quarters | |

## Expectations

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `expectations.mode` | `'rational'` | `'rational'`, `'learning'`, `'fixed_shares'`, `'switching'` | Who forecasts how | [Expectations](../options/expectations.md) |
| `expectations.variables` | `{}` | cellstr or `'all'` | Variables with heterogeneous expectations | [Expectations](../options/expectations.md) |
| `expectations.re_variant` | `'anchored'` | `'anchored'`, `'model_consistent'` | RE agents' forecast | [RE agents](../options/re-agents.md) |
| `expectations.re_info` | `'current'` | `'current'`, `'lagged'` | RE agents' information. Baseline `'lagged'` | [RE agents](../options/re-agents.md) |
| `expectations.types` | empty | struct array or cell of structs with `name`, `kind` (`'re'`, `'plm'`, `'rule'`, `'re_mean'`), `rule` | Population of forecasting types; replaced as a whole | [Further rules](../options/further-expectation-rules.md) |
| `expectations.transforms` | empty | structs with `kind` (`'multiplier'`, `'diagnostic'`, `'myopia_anchoring'`), `types`, `scope`, `exclude`, `value` | Transforms of the expectations; replaced as a whole | [Further rules](../options/further-expectation-rules.md) |

## Beliefs

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `beliefs.update` | `'rls'` | `'rls'`, `'fixed'` | Learn, or hold the initial beliefs | [Initial beliefs](../options/initial-beliefs.md) |
| `beliefs.info` | `'lagged'` | `'lagged'`, `'current'` | Learners' information | [Timing](../options/timing.md) |
| `beliefs.plm.default` | `'ar1'` | `'ar1'`, `'ar2'`, `'ar1_noconst'`, `'var1'` | Default PLM | [PLMs](../options/plm.md) |
| `beliefs.plm.by_var.<x>` | none | shorthand or `struct('regressors', {...}, 'constant', true)` | PLM of one variable (free-form) | [PLMs](../options/plm.md) |
| `beliefs.plm.derived.<name>` | none | text | Derived regressor (free-form) | [PLMs](../options/plm.md) |
| `beliefs.plm.var.variables` | `{}` | cellstr or `'learning'` | VAR members | [PLMs](../options/plm.md) |
| `beliefs.plm.var.lags` | `1` | positive integer | VAR lags | |
| `beliefs.plm.var.constant` | `true` | logical | VAR constant | |
| `beliefs.init.method` | `'re_moments'` | `'re_moments'`, `'training_ols'`, `'user'` | Initial beliefs | [Initial beliefs](../options/initial-beliefs.md) |
| `beliefs.init.date` | `[]` | a date | `[]` = first filter date + 4 quarters | |
| `beliefs.init.values.<x>` | none | `.alpha`, `.beta` or `.phi`, `.R` | Your values (free-form) | |
| `beliefs.init.training_range` | `[]` | `[start, end]` | Required for `'training_ols'` | |

## Gain

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `gain.rule` | `'constant'` | `'constant'`, `'koz'` | Gain rule. Baseline `'koz'` | [Gains](../options/gains.md) |
| `gain.value` | `0.0585` | (0, 1] | Constant gain; start of `'koz'`. Baseline 0.05 | |
| `gain.by_var.<x>` | none | number | Gain of one variable (free-form) | |
| `gain.koz.mu` | `0.001` | >= 0 | Step size of the gain process | |
| `gain.koz.gamma0` | `[]` | `[]` or (0, 1] | Start gain; `[]` = `gain.value` | |
| `gain.koz.Rg0` | `0` | finite | Start of \(R^g\) | |
| `gain.koz.bounds` | `[0.001 0.25]` | `[lower upper]`, 0 < lower <= upper <= 1 | Projection interval | |
| `gain.koz.error` | `'rls'` | `'rls'`, `'forecast'` | Error that drives the gain | |
| `gain.koz.error_scale` | `1` | > 0 | Factor on the error | |
| `gain.koz.structure` | `'common'` | `'common'`, `'per_variable'` | One process or one per equation | |
| `gain.koz.master` | `''` | name or cellstr | Driver of the common process | |

## Shares and switching

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `shares.structure` | `'per_variable'` | `'per_variable'`, `'universal'` | One share per variable or one for all | [Switching](../options/switching.md) |
| `shares.master` | `{}` | name or cellstr | Drivers of the universal share | |
| `shares.init_n2` | `0.5` | [0, 1] | Initial learners' share | |
| `shares.fixed_n2` | `[]` | number or struct by variable | Learners' share in `'fixed_shares'` | |
| `shares.init` | `[]` | struct by type name | Initial shares over N types; replaced as a whole | [Further rules](../options/further-expectation-rules.md) |
| `shares.fixed` | `[]` | struct by type name | Fixed shares over N types; replaced as a whole | [Further rules](../options/further-expectation-rules.md) |
| `switching.rule` | `'discrete_choice'` | function name | Switching rule | [Switching](../options/switching.md) |
| `switching.intensity` | `0.51` | >= 0 | Intensity of choice. Baseline 2 | |
| `switching.memory` | `0.6` | [0, 1) | Memory of the fitness. Baseline 0.8 | |

## Projection facility

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `projection.facility` | `'plm_alm'` | `'plm_alm'`, `'alm'`, `'none'` | Stabilising device. Baseline `'alm'` | [Projection facility](../options/projection-facility.md) |

## History

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `history.learn` | `true` | logical | Learn over the history | [History modes](../options/history-modes.md) |
| `history.mode` | `'re_smoother'` | `'re_smoother'`, `'inversion'`, `'kalman'` | Source of the history | [History modes](../options/history-modes.md) |
| `history.re_states` | `'smoothed'` | `'smoothed'`, `'filtered'` | `'re_smoother'` only. Baseline `'filtered'` | [Timing](../options/timing.md) |
| `history.realtime` | `false` | logical | RE filter on data up to the origin | [Timing](../options/timing.md) |
| `history.inversion.start` | `[]` | a date | First inversion quarter | [History modes](../options/history-modes.md) |
| `history.inversion.shocks` | `{}` | cellstr | Shocks backed out | |
| `history.kalman.init` | `'stochastic'` | `'stochastic'`, `'smoothed'` | Start of the Kalman history | |

## Shocks and conditions

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `shocks.source` | `'none'` | `'none'`, `'smoothed'` | Shocks over the horizon | [Forecasts](../options/forecasts-conditions.md#shocks-over-the-horizon) |
| `shocks.range` | `[]` | dates | Quarters with smoothed shocks | |
| `shocks.exclude` | `{}` | cellstr | Shocks set to zero | |
| `shocks.add` | `{}` | `{{name, dates, values}, ...}` | Shocks added on top (free-form) | |
| `conditions` | empty | struct array: `variable`, `shock`, `dates`, `values`, `type` (`'level'`, `'delta'`), `reference` (`'self'` or an id) | Exogenise a variable, endogenise a shock; replaced as a whole | [Forecasts](../options/forecasts-conditions.md#conditions) |

## Density forecasts

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `density.enabled` | `false` | logical | Switch on | [Density forecasts](../options/densities.md) |
| `density.shocks` | `{}` | cellstr | Shocks drawn (required when enabled) | |
| `density.sigma` | `'calibrated'` | `'calibrated'`, `'smoothed'` | Standard deviations | |
| `density.sigma_range` | `[]` | `[start, end]` | Range for `'smoothed'` and the bootstrap pool | |
| `density.method` | `'normal'` | `'normal'`, `'bootstrap'` | Draws | |
| `density.ndraws` | `200` | positive integer | Number of draws | |
| `density.seed` | `0` | integer | Random seed | |
| `density.quantiles` | `[0.05 0.16 0.5 0.84 0.95]` | vector in (0, 1) | Reported quantiles | |
| `density.range` | `[]` | dates | Quarters with draws | |
| `density.keep_draws` | `false` | logical | Store every draw | |
| `density.fast_path` | `true` | logical | Linear fast path for RE runs | |
| `density.demean` | `true` | logical | Demean the bootstrap pool | |

## Engine

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `engine.step` | `'fast'` | `'fast'`, `'iris'` | One-quarter step | [Forecasts](../options/forecasts-conditions.md#engine) |
| `engine.conditions_weighting` | `'std'` | `'std'`, `'none'` | Shock weighting with more shocks than targets | |

## Monetary policy

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `policy.mode` | `'rule'` | `'rule'`, `'ramsey'` | Policy | [Monetary policy](../options/policy.md) |
| `policy.type` | `'commitment'` | `'commitment'`, `'discretion'` | Ramsey type | |
| `policy.loss` | `struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0)` | weights by target name | Loss weights; replaced as a whole | |
| `policy.discount` | `[]` | `[]` or (0, 1] | `[]` = `spec.policy.discount` | |
| `policy.loss_horizon` | `[]` | `[]` or quarters | Loss horizon | |

## Comparisons and reporting

| Option | Default | Values | Meaning | Page |
|---|---|---|---|---|
| `compare_with` | `{}` | cellstr of ids | Writes `compare_<id>.csv` | [Forecasts](../options/forecasts-conditions.md#comparisons) |
| `report.variables` | `{}` | cellstr | Reserved; read by no code | |

## Option errors

| Identifier | Cause |
|---|---|
| `hetlearn:options:unknown` | A name that is not in the defaults |
| `hetlearn:options:type` | Wrong type, e.g. a struct where a value is expected |
| `hetlearn:options:value` | A value outside its list or range |
| `hetlearn:options:missing` | `'fixed_shares'` without fixed shares, `'universal'` without `shares.master`, `'training_ols'` without a training range, density without shocks |
| `hetlearn:options:unsupported` | A combination that is not supported, e.g. Ramsey with `re_info = 'lagged'` |
| `hetlearn:options:removed` | An option name that the toolbox no longer has; the message names the replacement |
| `hetlearn:options:types`, `hetlearn:options:transforms` | An invalid `expectations.types` or `expectations.transforms` entry |
