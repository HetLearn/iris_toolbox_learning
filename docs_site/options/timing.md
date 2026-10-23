# Timing and information

Four options decide what each agent knows when it forecasts, and which estimates of the past
the agents learn from. RE stands for rational expectations.

| Option | Values (default first) | Meaning |
|---|---|---|
| `beliefs.info` | `'lagged'`, `'current'` | Learners see data up to t-1, or up to t |
| `expectations.re_info` | `'current'`, `'lagged'` | RE agents use \(E_t x_{t+1}\) or \(E_{t-1} x_{t+1}\) for the learning variables. Project baseline: `'lagged'` |
| `history.re_states` | `'smoothed'`, `'filtered'` | Source of the RE forecasts, the learners' data and the realized values in the fitness errors over the history: the two-sided smoother or the one-sided filter. Project baseline: `'filtered'` |
| `history.realtime` | `false`, `true` | RE filter on data up to the forecast origin only; `history.mode = 're_smoother'` only (ignored by the inversion and the Kalman history, which are one-sided already) |

## What each type forecasts in quarter t

With an AR(1) perceived law of motion and beliefs \(\phi_{t-1} = (\alpha_{t-1}, \beta_{t-1})\):

| | `'lagged'` | `'current'` |
|---|---|---|
| Learners (`beliefs.info`) | \(\alpha_{t-1} + \beta_{t-1}(\alpha_{t-1} + \beta_{t-1} x_{t-1})\) | \(\alpha_{t-1} + \beta_{t-1} x_t\), determined jointly with \(x_t\) (Özden 2025, eq. 12) |
| RE agents (`expectations.re_info`) | \(E_{t-1} x_{t+1}\) | \(E_t x_{t+1}\) |

In both cases the learners use the beliefs formed at the end of t-1, and the belief update is
the same. What changes is the forecast, and through the forecast errors, the shares.

## The order of events in quarter t

1. The model with beliefs \(\phi_{t-1}\) and shares \(n_{t-1}\) is in force; \(x_t\) is
   observed (history) or simulated (forecast).
2. Each type's squared error on \(x_t\), of the forecast it made in t-1, updates its fitness;
   the discrete choice gives the shares \(n_t\).
3. The gain rule gives the gain; recursive least squares updates the beliefs to \(\phi_t\).
4. The projection facility checks the model with \(\phi_t\) and \(n_t\), which will be in force
   in t+1.

So the shares and beliefs in force in t are always those computed at the end of t-1. In every
forecast quarter of `a1_learn`, the learners' share in the model equals the share computed the
quarter before.

## Examples

```matlab
% Learners see period-t data, as in Ozden (2025)
cfg = a1_learn(); cfg.id = 'a1_info_current';
cfg.beliefs.info = 'current';
res = hetlearn.run(cfg, 'save', false);

% RE agents with period-t information (and the matching RE benchmark)
cfg = a1_learn(); cfg.id = 'a1_reinfo_current';
cfg.expectations.re_info = 'current';
re  = a1_re();    re.id  = 'a1_re_reinfo_current';
re.expectations.re_info = 'current';
```

A run is compared with its RE benchmark under the same `re_info`: with `'lagged'` the RE
benchmark is the RE model with t-1 information for the learning set, not the original model
([RE agents](re-agents.md#information-period-t-or-t-1)).

## Filtered or smoothed history

Over the history (from `beliefs.init.date` to the forecast origin) the agents learn on the
RE model's estimates of the states, because most model variables are not observed.

- `'smoothed'` uses the Kalman smoother, which estimates \(x_t\) with data after t. The RE
  agents' forecast made in t then benefits from hindsight, which helps them in the fitness
  race.
- `'filtered'` (the project baseline) uses the one-sided filter \(x_{t|t}\), data up to t only.

For an observed variable the two agree (inflation in the Smets and Wouters (2007) model, outside
the COVID-19 quarters 2020Q1-2020Q3), so the option mainly moves the RE forecasts and, in
quarters with missing data, the learners' data. In either case the forecast itself starts from
the smoothed state at the origin.

```matlab
cfg = a1_learn(); cfg.id = 'a1_smoothed';
cfg.history.re_states = 'smoothed';          % baseline 'filtered'
res = hetlearn.run(cfg, 'save', false);
```

`'filtered'` applies to `history.mode = 're_smoother'` only. The inversion and Kalman histories
are one-sided already, and combining them with `'filtered'` is an error; their scenarios set
`'smoothed'`.

## Real-time filtering

By default the RE filter runs on the whole sample (to 2026Q2 for the Smets and Wouters model),
so the state at a 2022Q2 origin is estimated with data after 2022Q2. `history.realtime = true`
clips the data at the origin:

```matlab
cfg = a1_learn(); cfg.id = 'a1_realtime';
cfg.history.realtime = true;
res = hetlearn.run(cfg, 'save', false);
```

`history.re_states = 'filtered'` with `history.realtime = true` is the fully real-time setup.
The forecast evaluation uses real-time filtering by default. Real-time filter results are cached
per end date in `models/<name>/generated/refilter_rt_<date>_<hash>.mat`.

For Application 1 the difference is small: the largest gap between the real-time and the
full-sample forecast from 2022Q2, over horizons 1-8, is 0.36 percentage points for RE inflation
and 0.26 percentage points for learning inflation (annualized).
