# Forecasts, shocks and conditions

These options set where the forecast starts, how long it runs, which shocks hit the economy
over it, and which variables are put on a path.

## Origin and horizon

| Option | Values (default first) | Meaning |
|---|---|---|
| `forecast.origin` | a date (required) | Last quarter of data used; the forecast starts the quarter after |
| `forecast.horizon` | `16` | Number of forecast quarters, a positive integer |
| `id` | text | Results folder name `results/<id>/`; use the scenario function name |
| `title`, `description` | text | Shown in summaries and reports |
| `model` | text | Model package folder under `models/`, or a folder path |
| `model_params` | `''` | Parameter function of the package to use instead of `spec.params`. Project baseline: `'sw07_params_original'` |

```matlab
cfg = a1_learn(); cfg.id = 'a1_from_2023Q4';
cfg.forecast.origin = qq(2023, 4);
cfg.forecast.horizon = 12;
res = hetlearn.run(cfg, 'save', false);
```

An origin found from the data, as `sw07_re` does:

```matlab
spec = hetlearn.load_spec('sw07');
db = hetlearn.load_database(spec);
origin = hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4));   % 2022Q2
```

`model_params` switches the parameter set of the package for one run. Each parameter set has
its own RE filter cache:

```matlab
cfg = a1_learn(); cfg.id = 'a1_swX1';
cfg.model_params = '';                    % '' = spec.params (sw07_params, the swX1 re-estimate)
```

## Shocks over the horizon

| Option | Values (default first) | Meaning |
|---|---|---|
| `shocks.source` | `'none'`, `'smoothed'` | Zero shocks, or the RE-smoothed shocks |
| `shocks.range` | `[]` | Quarters that get smoothed shocks; `[]` = the horizon |
| `shocks.exclude` | `{}` | Shocks set to zero, e.g. `{'em'}` |
| `shocks.add` | `{}` | Shocks added on top: `{{name, dates, values}, ...}`; values scalar or one per date |

All shocks are unanticipated: every quarter is a new one-quarter simulation with the beliefs
and shares in force.

```matlab
% A one-off monetary tightening of 0.25 (model units) in 2022Q3, on top of zero shocks
cfg = a1_learn(); cfg.id = 'a1_em_shock';
cfg.shocks.add = {{'em', qq(2022, 3), 0.25}};

% Two shocks, the second over four quarters
cfg = a1_learn(); cfg.id = 'a1_two_shocks';
cfg.shocks.add = {{'em', qq(2022, 3), 0.25}, {'epinf', qq(2022, 3):qq(2023, 2), [0.1 0.1 0.05 0.05]}};

% Replay the RE-smoothed shocks except the monetary ones (Application 2 without em)
cfg = a2_learn(); cfg.id = 'a2_learn_nom';
cfg.shocks.exclude = {'em'};
```

## Conditions

A condition puts a variable on a path and lets a shock adjust each quarter to hit it.
`cfg.conditions` is a struct array, one element per variable-shock pair, and it replaces the
inherited value as a whole.

| Field | Values | Meaning |
|---|---|---|
| `variable` | name | Transition or measurement variable to put on a path, e.g. `'robs'`, `'ms'` |
| `shock` | name | The shock that adjusts |
| `dates` | dates, or `[start, end]` | Quarters of the condition, inside the horizon; two dates are read as a range |
| `values` | number or vector | Targets, scalar or one per date |
| `type` | `'level'` (default), `'delta'` | The target is the value itself, or the value added to a reference path |
| `reference` | `'self'` (default) or a scenario id | For `'delta'`: the same scenario without conditions, or another scenario's path |

```matlab
% Application 3: the monetary shock process 0.25 below its own path for four quarters
cfg = a1_learn(); cfg.id = 'a3_loose_learn_copy';
cfg.conditions = struct('variable', 'ms', 'shock', 'em', ...
    'dates', [qq(2022, 3), qq(2023, 2)], 'values', -0.25, ...
    'type', 'delta', 'reference', 'self');

% The observed policy rate on a path (% per quarter)
cfg = a1_learn(); cfg.id = 'a1_rate_path';
cfg.conditions = struct('variable', 'robs', 'shock', 'em', ...
    'dates', qq(2022, 3):qq(2023, 2), 'values', [0.5 0.8 1.1 1.2], ...
    'type', 'level', 'reference', 'self');

% Two conditions at once: rate path and inflation 0.1 above the RE path, with the price mark-up shock
c1 = struct('variable', 'robs', 'shock', 'em', 'dates', qq(2022, 3):qq(2023, 2), ...
    'values', [0.5 0.8 1.1 1.2], 'type', 'level', 'reference', 'self');
c2 = struct('variable', 'pinfobs', 'shock', 'epinf', 'dates', [qq(2022, 3), qq(2022, 4)], ...
    'values', 0.1, 'type', 'delta', 'reference', 'a1_re');
cfg = a1_learn(); cfg.id = 'a1_two_conditions';
cfg.conditions = [c1, c2];
```

Rules: a variable conditioned twice in the same quarter is an error. A `'delta'` reference to a
scenario id that has no results runs that scenario first. With more adjusting shocks than
targets, the toolbox uses the smallest shocks in standard-deviation units
(`engine.conditions_weighting = 'std'`).

## Comparisons

| Option | Values | Meaning |
|---|---|---|
| `compare_with` | `{}`, cellstr of scenario ids | Writes `results/<id>/compare_<other>.csv`: this run minus the other, observables over the horizon, model units |

A comparison target without results is run first. Outside a scenario,
`hetlearn.compare(ids, vars, range)` builds the same kind of table from saved results:

```matlab
T = hetlearn.compare({'a1_re', 'a1_learn', 'v2_ar2'}, {'pinfobs', 'robs'}, qq(2022, 3):qq(2026, 2));
```

## Engine

| Option | Values (default first) | Meaning |
|---|---|---|
| `engine.step` | `'fast'`, `'iris'` | One-quarter step from the cached state-space solution (equal to IRIS `simulate` to about 1e-12, 2-3 times faster), or IRIS `simulate` itself |
| `engine.conditions_weighting` | `'std'`, `'none'` | With more shocks than targets: minimum norm in standard-deviation units, or unweighted |

```matlab
cfg = a1_learn(); cfg.id = 'a1_iris_step';
cfg.engine.step = 'iris';                 % slower; bit-identical to IRIS simulate
```

## Reserved

`report.variables` (default `{}`) is accepted and stored but no toolbox code reads it.
