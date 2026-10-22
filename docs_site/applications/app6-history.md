# Application 6: the history backed out with the learning model

**Question.** In Applications 1-5 the history before the forecast origin is the one the RE
model sees: the RE filter and smoother estimate the states and shocks, and the learners learn
on those estimates. What history does the learning model itself back out of the data, and
which shocks drove inflation in each version?

## Three ways to run the history

| Scenario | `history.mode` | What it does |
|---|---|---|
| `a6_smooth_re` | `'re_smoother'` | RE model; states and shocks from the RE smoother. Base of the RE decomposition |
| `a6_smooth_learn` | `'re_smoother'` | Learning on the RE-filtered history to 2026Q2 (the baseline history, as in Application 1) |
| `a6_inv_learn` | `'inversion'` | The learning model backs out the shocks one quarter at a time: observables exogenised, shocks endogenised, beliefs and shares updated on the result |
| `a6_kalman_learn`, `a6_kalman_re` | `'kalman'` | A time-varying Kalman filter of the model in force each quarter, with one-step prediction errors and a log likelihood |

All of them move the origin to the last data quarter, 2026Q2, with a 4-quarter horizon:

```matlab
function cfg = a6_smooth_learn()
cfg = a1_learn();
cfg.id = 'a6_smooth_learn';
cfg.forecast.origin = qq(2026, 2);
cfg.forecast.horizon = 4;
cfg.compare_with = {'a6_smooth_re'};
end

function cfg = a6_inv_learn()
cfg = a6_smooth_learn();
cfg.id = 'a6_inv_learn';
cfg.history.mode = 'inversion';
cfg.history.re_states = 'smoothed';   % required with 'inversion' (it is one-sided already)
cfg.compare_with = {'a6_smooth_learn'};
end

function cfg = a6_kalman_learn()
cfg = a6_smooth_learn();
cfg.id = 'a6_kalman_learn';
cfg.history.mode = 'kalman';
cfg.history.re_states = 'smoothed';   % required with 'kalman'
cfg.compare_with = {'a6_kalman_re'};
end
```

`run_applications('app6')` runs `a6_smooth_re`, `a6_smooth_learn` and `a6_inv_learn`, then
the shock decompositions of inflation and output growth. The Kalman scenarios are run
directly: `hetlearn.run(a6_kalman_re()); hetlearn.run(a6_kalman_learn());`.

## The decompositions

The runner calls `hetlearn.decompose` for each of the three runs with five shock groups:

```matlab
groups = struct('demand', {{'eb', 'eg', 'eqs'}}, 'monetary', {{'em'}}, 'supply', {{'ea'}}, ...
    'price_markup', {{'epinf'}}, 'wage_markup', {{'ew'}});
ids = {'a6_smooth_re', 'a6_smooth_learn', 'a6_inv_learn'};
rng = [qq(1966, 1), qq(2026, 2)];
for i = 1:numel(ids)
    D = hetlearn.decompose(ids{i}, {'pinfobs', 'dy'}, rng, struct('groups', groups));
end
```

Each call writes `results/<id>/decomposition.csv`. RE runs use IRIS contributions; learning
runs use a time-varying decomposition with the model in force each quarter, plus a component
`beliefs_constants` for the moving perceived means. Details: [Shock decompositions](../options/decompositions.md).

## Results

| | Filtered history (`a6_smooth_learn`) | Inversion (`a6_inv_learn`) |
|---|---:|---:|
| Learners' share, end of 2022Q2 | 0.591 | 0.811 |
| Learners' share, end of 2026Q2 | 0.632 | 0.999 |
| Average share 1966Q1-2026Q2 | 0.523 | 0.558 |

- **The inversion reproduces the data**: the seven observables to 4e-15 over 1966Q1-2026Q2
  (check C9).
- **It needs different shocks.** The backed-out price mark-up shocks `epinf` differ from the
  RE-smoothed ones by 1.25 standard deviations (RMS) over the whole sample and by 2.58 in
  2021-2023; wage mark-up shocks by 0.63 and 1.10.
- **The learners' share is higher** in the inverted history, and close to 1 by 2026Q2.

Average contribution to inflation over 2021Q1-2023Q4 (pp, annualised deviation from the
steady state; total 1.72 pp in both):

| Component | RE smoother | Learning, inversion |
|---|---:|---:|
| Price mark-up | 3.42 | 6.24 |
| Demand | −1.52 | −1.08 |
| Monetary | 0.95 | 0.36 |
| Supply (productivity) | −0.36 | −1.88 |
| Wage mark-up | −0.77 | −2.23 |
| Intercept channel (perceived means) | 0.00 | 0.30 |

Under learning, price mark-up shocks explain more of the 2021-2023 inflation, offset by larger
negative supply and wage mark-up contributions.

The learners' share and beliefs over the filtered history are drawn in the
[Application 1 tutorial](../tutorial/application-1.md#9-step-5-the-learners-over-the-history).

## The Kalman history

`history.mode = 'kalman'` filters the data with the model in force each quarter (the beliefs
and shares from the end of the quarter before), so it gives one-step prediction errors and a
log likelihood for the learning model. On the 2026-10-20 runs, over 1966Q1-2026Q2:

| | RE(t-1), `a6_kalman_re` | Learning, `a6_kalman_learn` |
|---|---:|---:|
| One-step RMSE, inflation (% q/q) | 0.371 | 0.309 |
| Log likelihood | −2182.12 | −1839.75 |

```matlab
res = hetlearn.run(a6_kalman_learn(), 'save', false);
T = hetlearn.engine.kalman_history('rmse', res);    % T.table: RMSE by observable and subsample
```

A saved Kalman run also writes `results/<id>/kalman_errors.csv` (date, number of observables,
log-likelihood contribution, errors, predictions and variances by observable). More in
[History modes](../options/history-modes.md).
