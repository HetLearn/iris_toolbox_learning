# Shock decompositions

`hetlearn.decompose` splits the path of a variable, as a deviation from its RE steady state,
into the contributions of each shock (or group of shocks), the initial conditions and, under
learning, the moving perceived means.

```matlab
D = hetlearn.decompose(res)                      % a result struct, default variables {'pinfobs', 'dy'}
D = hetlearn.decompose(id, vars, range, opts)    % a saved scenario id
```

| Input | Meaning |
|---|---|
| `res` or `id` | A result of `hetlearn.run`, or a scenario id with results in `results/<id>/` |
| `vars` | cellstr of variables; default `{'pinfobs', 'dy'}` |
| `range` | Reporting dates, a vector or `[start, end]`; default every computed date |
| `opts.groups` | struct of shock groups; each group is one summed component, shocks in no group stay single |
| `opts.method` | `'auto'` (default: `'iris'` for mode `'rational'`, else `'tv'`), `'iris'`, `'tv'` |
| `opts.model` | A preloaded `struct('spec', spec, 'm', m, 'info', info)` for the run's options |
| `opts.save` | Write the CSV (default `true`) |
| `opts.results_dir` | Parent folder of `<id>/` (default `results/`) |
| `opts.file` | CSV path (default `results/<id>/decomposition.csv`) |
| `opts.quiet` | No progress line (default `false`) |

## Methods

**`'iris'`** (RE runs). IRIS contributions of the RE model, from the first date with initial
conditions.

**`'tv'`** (learning runs). A time-varying linear decomposition with the model in force each
quarter: the RE model where the history is the RE-smoothed one, the parameters recorded by
the inversion over an inverted history, and over the forecast the beliefs and model shares in
force (after the projection facility). Each shock's component is its propagation through the
models in force, so slope beliefs and shares act inside every shock component. The extra
component `beliefs_constants` is the intercept channel: the moving perceived means and their
propagation.

The decomposition is additive: the components sum to the total. `D.check` reports the
additivity error and how well the matrices rebuild the run's paths (`recon_maxerr`).

## Example: Application 6

```matlab
groups = struct('demand', {{'eb', 'eg', 'eqs'}}, 'monetary', {{'em'}}, 'supply', {{'ea'}}, ...
    'price_markup', {{'epinf'}}, 'wage_markup', {{'ew'}});
D = hetlearn.decompose('a6_inv_learn', {'pinfobs', 'dy'}, [qq(1966, 1), qq(2026, 2)], ...
    struct('groups', groups));
D.check                                          % additivity_maxerr, recon_maxerr, ...
```

`run_applications('decompose')` runs this for `a6_smooth_re`, `a6_smooth_learn` and
`a6_inv_learn` (about 15 seconds; their results must exist).

The CSV `results/<id>/decomposition.csv` has the columns scenario, date, variable, component,
value_model, value_report and label (with `total` rows); `value_report` is in report units
(inflation annualised).

```matlab
T = readtable(fullfile('results', 'a6_inv_learn', 'decomposition.csv'));
k = strcmp(T.variable, 'pinfobs') & strcmp(T.date, '2022Q2');
T(k, {'component', 'value_report'})
```

## Restrictions

- Results of `history.mode = 'kalman'` cannot be decomposed (`hetlearn:options:unsupported`).
- Without the inversion, the history of a learning run is the RE history, so the learning
  decomposition equals the RE one before the origin (the project checks this to 1e-14).

## In the project

Average contribution to inflation over 2021Q1-2023Q4 (pp, annualised; total 1.72 pp): price
mark-up shocks 3.42 under the RE smoother and 6.24 in the history backed out with the learning
model; the intercept channel adds 0.30 under learning. Full table: [Application
6](../applications/app6-history.md#results).
