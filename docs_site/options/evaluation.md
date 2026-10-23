# Forecast evaluation

`hetlearn.evaluate` runs recursive out-of-sample forecasts of several scenario variants from a
series of origins and compares their accuracy with a benchmark: root-mean-square errors (RMSE),
relative RMSE and Diebold-Mariano (DM) tests.

```matlab
E = hetlearn.evaluate(name, variants, origins, opts)
```

| Input | Meaning |
|---|---|
| `name` | Evaluation name; outputs go to `results/eval_<name>/` |
| `variants` | cellstr of scenario function names |
| `origins` | A date vector, or `[start, end]` |
| `opts.horizon` | Forecast horizon H (default 8) |
| `opts.benchmark` | Variant id for relative RMSE and DM tests (default: the first) |
| `opts.dm` | Diebold-Mariano tests (default `true`) |
| `opts.dm_hln` | Harvey-Leybourne-Newbold (HLN) small-sample correction and t(n-1) p-values (default `true`) |
| `opts.dm_kernel` | `''` (default: `'uniform'` with HLN, else `'bartlett'`), `'uniform'`, `'bartlett'` |
| `opts.subsamples` | struct of `[start, end]` target-date ranges; every table is also given for each |
| `opts.realtime` | `history.realtime` of every run (default `true`: the rational expectations (RE) filter sees data up to the origin only) |
| `opts.results_dir` | Parent folder (default `results/`) |
| `opts.save` | Write `eval_<name>/` (default `true`) |
| `opts.quiet` | No progress lines (default `false`) |

For every origin, each variant runs with the origin and horizon set, zero future shocks, no
conditions, no density and no comparisons, and a real-time RE filter. So only the expectations
side of a scenario file matters. Errors are actual minus forecast in report units (inflation
annualized), for every observable and h = 1..H; targets without data are skipped.

## Example

```matlab
E = hetlearn.evaluate('my_eval', {'e01_re', 'e02_learn', 'e05_ar2'}, [qq(2010, 1), qq(2024, 2)], ...
    struct('horizon', 8, 'subsamples', struct('post2008', [qq(2008, 1), qq(2019, 4)])));
E.relative_rmse(strcmp(E.relative_rmse.variable, 'pinfobs') & strcmp(E.relative_rmse.sample, 'full'), :)
```

## Outputs (`results/eval_<name>/`)

| File | Content |
|---|---|
| `errors_long.csv` | variant, origin, target, h, variable, actual, forecast, error |
| `metrics.csv` | sample, variant, variable, h, n, rmse, me (bias), mae |
| `relative_rmse.csv` | sample, variant, benchmark, variable, h, n, rmse, rmse_benchmark, relative_rmse |
| `dm.csv` | sample, variant, benchmark, variable, h, n, mean_loss_diff, dm_stat, p_value, kernel |
| `settings.mat` | variants, origins, horizon, benchmark, subsamples, failed runs, events per run |

`hetlearn.evaluate_tables` rebuilds the metrics, relative RMSE and DM tables from saved errors
without re-running any forecast, for example with other subsamples or another kernel:

```matlab
T = hetlearn.evaluate_tables(fullfile('results', 'eval_my_eval', 'errors_long.csv'), ...
    struct('benchmark', 'e01_re', 'dm_kernel', 'bartlett'));
T.relative_rmse                            % also T.metrics, T.dm, T.info
```

The first input is an error table, the path of an `errors_long.csv`, or an `eval_<name>`
folder. Every field of the options struct is optional; defaults come from the `settings.mat`
next to the errors when there is one:

| Field | Default | Meaning |
|---|---|---|
| `variants`, `variables` | from `settings.mat`, else order of appearance | Output order |
| `horizon`, `origins` | from `settings.mat`, else from the table | H and the origin dates |
| `benchmark` | from `settings.mat`, else the first variant | Benchmark of relative RMSE and DM |
| `subsamples` | from `settings.mat`, else none | struct of `[start, end]` target-date ranges |
| `dm`, `dm_hln`, `dm_kernel` | `true`, `true`, `''` | As in `hetlearn.evaluate` |
| `settings` | `[]` | A settings struct used instead of `settings.mat` |
| `save` | `false` | Write `metrics.csv`, `relative_rmse.csv`, `dm.csv` |
| `folder` | the folder of the errors file | Output folder |
| `write_errors` | `false` | Also write `errors_long.csv` |

## The DM test

The loss differential is \(d_t = e^2_{variant,t} - e^2_{benchmark,t}\) (negative mean: the variant
is more accurate). The statistic is \(\bar d / \sqrt{\widehat{LRV}/n}\), with \(\widehat{LRV}\) the estimated long-run variance (LRV)
of \(d_t\) from h-1 autocovariances.
The `'uniform'` kernel uses \(\gamma_0 + 2\sum_{k<h}\gamma_k\), with a Bartlett fallback where
that is not positive; `'bartlett'` uses Newey-West weights. With the HLN correction the
statistic is multiplied by \(\sqrt{(n + 1 - 2h + h(h-1)/n)/n}\) and compared with a Student t
with n-1 degrees of freedom.

## The project's evaluation

Ten variants in `scenarios/sw07/eval/` (`e01_re` ... `e10_allvars`), 138 origins
1990Q1-2024Q2, horizon 8, benchmark `e01_re`, subsamples by target date 1990-2007, 2008-2019 and
2020-2026. The runner splits each variant's origins into six parts so that parts can run in
parallel MATLAB sessions:

```matlab
run_applications('eval')                                           % everything, about 2.7 hours
run_applications('eval_part', {'e01_re', 'e02_learn'}, 1:6)        % some variants, some parts
run_applications('eval_part', 'e09_var12', 7:12, 12)               % finer parts for a slow variant
run_applications('eval_merge')                                     % merge parts into the tables
```

The settings are in `run_applications.m`, function `eval_settings`. Before a rerun with other
origins, horizon or variants, move `results/eval_sw07_v3/parts/` aside: the merge reads every
part folder and stops on parts with other settings or overlapping origins.

Inflation, full sample, relative RMSE against the RE model with t-1 information (`e01_re`; RE
RMSE 1.42, 1.65 and 1.68 percentage points at h = 1, 4, 8):

| Variant | h = 1 | h = 4 | h = 8 |
|---|---:|---:|---:|
| `e02_learn` (baseline learning) | 0.753 | 1.000 | 1.030 |
| `e03_learn_mc` (model-consistent RE agents) | 0.747 | 1.161 | 1.564 |
| `e04_learn_all_learners` (share of learners 1) | 0.720 | 1.210 | 1.681 |
| `e05_ar2` | 0.754 | 1.015 | 1.031 |
| `e06_ar1nc` | 0.756 | 0.994 | 1.017 |
| `e07_reg` | 0.774 | 0.989 | 1.043 |
| `e08_var3` | 0.775 | 0.984 | 1.038 |
| `e09_var12` | 0.766 | 0.915 | 1.046 |
| `e10_allvars` (all 12 variables learn) | 0.812 | 1.323 | 1.620 |

The learning variants beat RE one quarter ahead (for `e02_learn` the DM p-value is 0.0004) and
are about as accurate or worse at longer horizons.
