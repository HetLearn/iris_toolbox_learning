# Gains

The gain sets how much weight the learners put on the newest observation when they update
their beliefs. With a gain \(g_t\) and regressors \(z_{t-1}\), recursive least squares is

\[
R_t = R_{t-1} + g_t\left(z_{t-1} z_{t-1}' - R_{t-1}\right), \qquad
\phi_t = \phi_{t-1} + g_t R_t^{-1} z_{t-1}\left(v_t - \phi_{t-1}' z_{t-1}\right),
\]

equation by equation, each with its own \(R\). A constant gain \(g\) means the learners weight
past data with a geometric decay; \(1/g\) is roughly their memory in quarters (0.05: about five
years).

| Option | Values (default first) | Meaning |
|---|---|---|
| `gain.rule` | `'constant'`, `'koz'` | Constant gain, or the endogenous gain of Kostyshyna, Özden and Zhang (2024). The name is a function in `toolbox/+hetlearn/+gain/`. Project baseline: `'koz'` |
| `gain.value` | `0.0585` | The constant gain (Özden 2025, posterior mean), and the start of `'koz'`. In (0, 1]. Project baseline: 0.05 |
| `gain.by_var.<x>` | number | Gain of one variable: with `'constant'` its gain, with `'koz'` and `'per_variable'` its start value (ignored with a warning under `'common'`) |
| `gain.koz.mu` | `0.001` | Step size of the gain process; 0 gives the constant gain exactly |
| `gain.koz.gamma0` | `[]` | Start gain; `[]` = `gain.value` |
| `gain.koz.Rg0` | `0` | Start value of \(R^g\) |
| `gain.koz.bounds` | `[0.001 0.25]` | The gain stays inside; a `gain_bound` event each quarter a bound binds |
| `gain.koz.error` | `'rls'`, `'forecast'` | Signed error that drives the gain: the PLM's one-step residual, or the learners' expectation error \(x_t - F^{BR}_{t-1}\) |
| `gain.koz.error_scale` | `1` | Factor on that error; 1 = model units (percent per quarter for SW07) |
| `gain.koz.structure` | `'common'`, `'per_variable'` | One gain process for every PLM equation, or one per equation driven by its own error |
| `gain.koz.master` | `''` | `'common'` only: the variable whose error drives the gain; `''` = the first learning variable; a list = the mean of their errors, so a quarter in which any of them is missing skips the gain update |

## The endogenous gain

Kostyshyna, Özden and Zhang (2024, eq. 9), the adaptive step-size algorithm of Kostyshyna
(2012). After \(x_t\) is observed, with \(e_t\) the signed error (times `error_scale`) and
\(P\) the projection on `bounds`:

\[
\gamma_t = P\left[\gamma_{t-1} + \mu R^g_{t-1} e_t\right], \qquad
R^g_t = (1 - \gamma_{t-1}) R^g_{t-1} + e_t .
\]

The RLS update at the end of t uses \(g_t = \gamma_{t-1}\). The gain rises when errors keep the
same sign and falls when they alternate. It updates from the observed error whatever the
projection facility does with the beliefs.

Things to know:

- `mu = 0` reproduces the constant gain bit for bit.
- `mu` is scale dependent: the error enters both equations, so `mu` acts roughly with the
  square of `error_scale`. An `error_scale` of 4 (annualised percent) works like a 16 times
  larger `mu`.
- With `'koz'`, `res.learning.<x>` also holds `gain_R` (\(R^g_t\)).
- KOZ's Table 1 "R0 = 0.001" is the initial RLS moment matrix, not \(R^g_0\). To use it, set
  `beliefs.init.method = 'user'` and only `beliefs.init.values.<x>.R` (example below).

## Examples

```matlab
% Constant gain at the toolbox default (the previous project baseline)
cfg = a1_learn(); cfg.id = 'a1_const0585';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.0585;

% Constant gain 0.05, the baseline's start gain (model variant v4_const)
cfg = a1_learn(); cfg.id = 'v4_const';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.05;

% A different constant gain for one variable
cfg = a1_learn(); cfg.id = 'a1_pinf_gain';
cfg.gain.rule = 'constant';
cfg.gain.by_var.pinf = 0.02;

% Endogenous gain with a larger step and the learners' forecast error as the driver
cfg = a1_learn(); cfg.id = 'a1_koz_fast';
cfg.gain.rule = 'koz';
cfg.gain.value = 0.05;
cfg.gain.koz.mu = 0.01;
cfg.gain.koz.error = 'forecast';

% One gain process per PLM equation
cfg = a1_learn(); cfg.id = 'a1_koz_pervar';
cfg.gain.koz.structure = 'per_variable';

% One common process driven by inflation and wage errors
cfg = a1_learn(); cfg.id = 'a1_koz_master';
cfg.expectations.variables = {'pinf', 'w'};
cfg.gain.koz.master = {'pinf', 'w'};

% KOZ's initial moment matrix R0 = 0.001*I (AR(1): two coefficients)
cfg = a1_learn(); cfg.id = 'a1_koz_R0';
cfg.beliefs.init.method = 'user';
cfg.beliefs.init.values.pinf.R = 0.001*eye(2);
```

Inspect the gain after a run:

```matlab
res = hetlearn.run(a1_learn(), 'save', false);
g = res.learning.pinf.gain;
g(qq(2022, 2))                       % 0.0499
[min(g(qq(1966,1):qq(2022,2))), max(g(qq(1966,1):qq(2022,2)))]
```

## In the project

The baseline KOZ gain starts at 0.05 in 1966Q1 and stays within 0.047-0.052 over
1966Q1-2026Q2 (mean 0.049); it never hits a bound. It is 0.0499 at the 2022Q2 origin and
averages 0.0489 over the forecast. Model variant 4 holds it at 0.05:

| | `a1_learn` (KOZ) | `v4_const` (0.05) |
|---|---:|---:|
| Average inflation 2022Q3-2026Q2 (%) | 3.45 | 3.50 |
| Learners' share at the end of 2022Q2 | 0.591 | 0.595 |
| Largest difference in \(\beta\), 1966-2026 | | 0.012 |
| Largest difference in the share, 1966-2026 | | 0.004 |

With `mu = 0.001` and errors in percent per quarter the gain moves little, so the endogenous
and the constant gain give nearly the same results on SW07.
