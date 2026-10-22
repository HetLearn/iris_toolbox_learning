# History modes

Before the forecast starts, the agents learn over the history, from `beliefs.init.date` to
the forecast origin. Most model variables are not observed, so the toolbox needs estimates of
the past states. `history.mode` decides where they come from.

| Option | Values (default first) | Meaning |
|---|---|---|
| `history.learn` | `true`, `false` | Learn over the history; `false` = the initial beliefs and shares apply at the origin |
| `history.mode` | `'re_smoother'`, `'inversion'`, `'kalman'` | The RE model's filter or smoother; the history backed out with the learning model; a time-varying Kalman filter of the learning model |
| `history.re_states` | `'smoothed'`, `'filtered'` | `'re_smoother'` only: two-sided smoother or one-sided filter ([Timing](timing.md#filtered-or-smoothed-history)). Project baseline: `'filtered'` |
| `history.realtime` | `false`, `true` | RE filter on data up to the origin only ([Timing](timing.md#real-time-filtering)) |
| `history.inversion.start` | `[]` | First inversion quarter; `[]` = `beliefs.init.date` |
| `history.inversion.shocks` | `{}` | Shocks backed out; `{}` = every transition shock |
| `history.kalman.init` | `'stochastic'`, `'smoothed'` | `'kalman'` only: start from the asymptotic distribution of the first quarter's model, or at `beliefs.init.date` from the RE-smoothed state |

## `'re_smoother'`: learn on the RE estimates (default)

The RE model is filtered and smoothed once over the whole sample (`hetlearn.re_filter`, cached
in `models/<name>/generated/refilter_*.mat`). Each history quarter, the RE agents' forecasts,
the learners' data and the realised values in the forecast errors are read from that output;
beliefs and shares are updated, and the model with the new beliefs is solved only to apply the
projection facility. The data are not re-explained by the learning model. This is the mode of
every application except 6.

```matlab
cfg = a1_learn();                         % history.mode = 're_smoother' (default)
```

## `'inversion'`: back out the history with the learning model

One quarter at a time, from `history.inversion.start`, the learning model in force that
quarter explains the data: the observables are exogenised, the shocks endogenised, and then
beliefs and shares are updated on the resulting states. The history is real time by
construction (quarter t uses data up to t). It needs at least as many shocks as observables.

```matlab
function cfg = a6_inv_learn()
cfg = a6_smooth_learn();                  % a1_learn with origin 2026Q2
cfg.id = 'a6_inv_learn';
cfg.history.mode = 'inversion';
cfg.history.re_states = 'smoothed';       % required: 'filtered' is an error with 'inversion'
cfg.compare_with = {'a6_smooth_learn'};
end
```

Options:

```matlab
cfg.history.inversion.start = qq(1985, 1);           % start later; the RE smoother before it
cfg.history.inversion.shocks = {'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'};   % SW07: all seven
```

Under the RE model the inversion equals the RE smoother (to 2e-13 for SW07). In quarters where
every observable is missing (SW07, 2020Q1-Q3) there is nothing to exogenise, so from 2020 on the
inverted RE history no longer equals the smoother. The backed-out model parameters of each
quarter are kept in the result, and `hetlearn.decompose` uses them.

In the project, the inversion reproduces the seven SW07 observables over 1966Q1-2026Q2 to
4e-15, and the learners' share at the end of 2022Q2 is 0.811 against 0.591 on the filtered RE
history ([Application 6](../applications/app6-history.md)).

## `'kalman'`: a time-varying Kalman filter of the learning model

Each quarter, the model with the beliefs and shares from the end of the quarter before is
solved, and the Kalman filter predicts and updates with that quarter's data (a quarter without
data is a prediction only). The agents then learn from the filtered values in real time. This
gives one-step prediction errors and a log likelihood of the learning model.

```matlab
function cfg = a6_kalman_learn()
cfg = a6_smooth_learn();
cfg.id = 'a6_kalman_learn';
cfg.history.mode = 'kalman';
cfg.history.re_states = 'smoothed';       % required: 'filtered' is an error with 'kalman'
cfg.compare_with = {'a6_kalman_re'};
end
```

```matlab
res = hetlearn.run(a6_kalman_learn(), 'save', false);
T = hetlearn.engine.kalman_history('rmse', res);   % RMSE by observable and subsample, log likelihood
res.kalman                                          % predictions, errors, F_t, l_t, filtered and predicted data

cfg = a6_kalman_learn(); cfg.id = 'a6_kalman_smoothed_start';
cfg.history.kalman.init = 'smoothed';               % start at beliefs.init.date from the RE-smoothed state
```

What the agents see in the Kalman history: a forecast made in t with data to t-1 uses the
prediction \(x_{t|t-1}\); a forecast with period-t data uses \(x_{t|t}\); realised values and PLM
regressors are the filtered values as they were when each quarter was filtered, not revised
later. Before `beliefs.init.date` the model is the RE limit. The forecast starts from the
filtered state at the origin.

A saved run writes `results/<id>/kalman_errors.csv`: date, number of observables, the
log-likelihood contribution, and the error, prediction and variance of each observable.

In the project, over 1966Q1-2026Q2:

| | RE(t-1), `a6_kalman_re` | Learning, `a6_kalman_learn` |
|---|---:|---:|
| One-step RMSE, inflation (% q/q) | 0.371 | 0.309 |
| Log likelihood | −2182.12 | −1839.75 |

The seven [further expectation rules](further-expectation-rules.md#results) are compared the
same way.

## No learning over the history

```matlab
cfg = a1_learn(); cfg.id = 'a1_nolearn';
cfg.history.learn = false;                % initial beliefs and shares apply at the origin
```

With `history.learn = false` the beliefs at the origin are the initial beliefs (RE moments by
default), and the share is `shares.init_n2`. Combine it with `beliefs.init.method = 'user'` to
impose beliefs at the origin ([Initial beliefs](initial-beliefs.md#impose-beliefs-at-the-origin)).
`'inversion'` and `'kalman'` need `history.learn = true`.

## Which mode to use

| Purpose | Mode |
|---|---|
| Forecasts and scenarios from a given origin, comparable to the RE forecast | `'re_smoother'` |
| A history consistent with the learning model, shocks for a decomposition under learning | `'inversion'` |
| In-sample fit: one-step errors and a likelihood of the learning model | `'kalman'` |
