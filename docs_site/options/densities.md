# Density forecasts

A density forecast runs the scenario many times with random shocks drawn on top of it and
reports quantiles of every observable and of the learning states.

| Option | Values (default first) | Meaning |
|---|---|---|
| `density.enabled` | `false` | Switch on |
| `density.shocks` | cellstr | Shocks to draw (required when enabled) |
| `density.sigma` | `'calibrated'`, `'smoothed'` | The model's `std_<shock>`, or the sample standard deviation of the RE-smoothed shocks over `sigma_range` |
| `density.sigma_range` | `[]` | `[]` = the filter range |
| `density.method` | `'normal'`, `'bootstrap'` | Normal draws, or resampled whole quarters of smoothed shocks |
| `density.demean` | `true` | Bootstrap: demean the pool first |
| `density.ndraws` | `200` | Number of draws |
| `density.seed` | `0` | Random seed |
| `density.quantiles` | `[0.05 0.16 0.5 0.84 0.95]` | Reported quantiles |
| `density.range` | `[]` | Quarters with draws; `[]` = the horizon |
| `density.keep_draws` | `false` | Store every draw in `density.mat` |
| `density.fast_path` | `true` | Mode `'rational'` without conditions: one linear simulation per draw |

## How it works

The draws come on top of the scenario's own shocks and conditions. With learning, each draw
re-runs the quarter-by-quarter forecast, so beliefs, gains and shares respond to the drawn
shocks; the projection facility applies in each draw. An RE scenario without conditions takes
the fast path, one linear simulation per draw. On SW07, 500 draws take about 30 seconds under
RE and 4-6 minutes with learning.

## Examples

```matlab
% Application 5: price and wage mark-up shocks, normal, calibrated sigma, 500 draws
cfg = a1_learn(); cfg.id = 'my_markup_learn';
cfg.density.enabled = true;
cfg.density.shocks = {'epinf', 'ew'};
cfg.density.sigma = 'calibrated';
cfg.density.method = 'normal';
cfg.density.ndraws = 500;
cfg.density.seed = 0;
res = hetlearn.run(cfg);

% Use the same draws for the RE run: copy the block
r = a1_re(); r.id = 'my_markup_re';
r.density = cfg.density;
hetlearn.run(r);

% Bootstrap whole quarters of smoothed shocks from 1984-2019, draws only in the first two years
cfg = a1_learn(); cfg.id = 'my_bootstrap';
cfg.density.enabled = true;
cfg.density.shocks = {'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'};
cfg.density.method = 'bootstrap';
cfg.density.sigma_range = [qq(1984, 1), qq(2019, 4)];
cfg.density.demean = true;
cfg.density.range = qq(2022, 3):qq(2024, 2);
cfg.density.quantiles = [0.1 0.5 0.9];
cfg.density.ndraws = 200;
```

## Outputs

| Output | Content |
|---|---|
| `res.density` | Quantiles, means, standard deviations and point forecasts of every summarised series, draw information, events |
| `results/<id>/density.mat` | The same, saved apart from `results.mat`; every draw too with `keep_draws = true` |
| `results/<id>/density_quantiles.csv` | variable, date, quantile, value_model, value_report |
| `results/<id>/density_events.csv` | One row per draw: draw, status, projection_plm, projection_alm, projection_alm_shares, explosive_events, rls_missing, shares_nan, gain_bound, max_abs, message |

A later run of the same id without density deletes the old density files.

```matlab
q = readtable(fullfile('results', 'my_markup_learn', 'density_quantiles.csv'));
q(strcmp(q.variable, 'pinfobs') & q.quantile == 0.95, :)
```

## In the project

Application 5 runs 500 draws for mark-up shocks and for demand shocks. With mark-up shocks the
average 90% inflation band is 14.59 pp with learning against 4.76 pp under RE; with demand shocks
the two are about the same (1.16 and 1.18 pp). See [Application 5](../applications/app5-density.md).
