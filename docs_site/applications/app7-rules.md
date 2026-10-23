# Application 7: further expectation rules

**Question.** Beyond the baseline pair of rational expectations (RE) agents and AR(1)
learners, how do seven expectation rules from the bounded-rationality literature change the
forecast from the 2022Q2 inflation peak, and how well does each fit the history?

Each rule is a scenario in `scenarios/sw07/br_portfolio/` that starts from `a1_learn` and adds a
few lines, so it inherits the project baseline and runs Application 1. The options they use
are on the [Further expectation rules](../options/further-expectation-rules.md) options page.

| Rule | Scenario | What it changes | Value and source |
|---|---|---|---|
| Cognitive discounting on the learning set | `br05b_cd_learn` | inflation expectations of both types multiplied by \(m^h\) | \(m = 0.94\), Meggiorini and Milani (2021) |
| Myopia and anchoring | `br07_myopia_anchoring` | the inflation expectation of the price Phillips curve | \((\omega_f, b) = (0.52, 0.434)\), Angeletos and Huo (2021) |
| Diagnostic expectations | `br10_diagnostic` | the RE agents' expectations become diagnostic | \(\theta = 0.44\), L'Huillier, Singh and Yoo (2024) |
| Target believers | `br19_target_believers` | a third type that always forecasts the steady state | shares 1/3 each at the start; Hommes and Lustenhouwer (2019) |
| Intercept-only learners | `br23_intercept_only` | learners forecast the RE forecast plus a learned mean of its error | baseline gain; Gáti (2023), Carvalho, Eusepi, Moench and Preston (2023) |
| Mean-only learners | `br24_mean_only` | the learners' perceived law of motion keeps only the constant | baseline gain |
| Experience-based gain | `br26_experience` | the AR(1) learners use a constant gain of 0.018 | Malmendier and Nagel (2016), Nagel and Xu (2022) |

The transforms leave the expectations of the flexible-price block of the Smets and Wouters
(2007) model (SW07) out of their scope, `FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'}`, so the
flexible-price economy behind potential output keeps its RE expectations.

## The seven rules

### Cognitive discounting on the learning set

Agents shrink their forecasts toward the steady state (Gabaix 2020). Here both types' inflation
expectations are multiplied by \(m^h\); with t-1 information \(h = 2\), so the factor is
\(0.94^2\). \(m = 0.94\) is Meggiorini and Milani's (2021) estimate for the US, 1960-2007, from
their own model rather than SW07.

```matlab
function cfg = br05b_cd_learn()
cfg = a1_learn();
cfg.id = 'br05b_cd_learn';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'multiplier', 'types', 'all', ...
    'value', 0.94, 'scope', 'learning', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### Myopia and anchoring

Angeletos and Huo (2021) show that sticky, noisy information makes the Phillips curve behave
as if expectations were myopic and anchored to the past: the expectation becomes
\(\omega_f E\pi_{t+1} + b\,\pi_{t-1}\). The transform acts only in the price Phillips curve, for
all types, with \((\omega_f, \omega_b) = (0.52, 0.43)\) from their Table 1 and
\(b = 0.43/0.99 = 0.434\). SW07 keeps its own price indexation, so this backward weight comes on
top of it.

```matlab
function cfg = br07_myopia_anchoring()
cfg = a1_learn();
cfg.id = 'br07_myopia_anchoring';
cfg.expectations.transforms = struct('kind', 'myopia_anchoring', 'types', 'all', 'value', [0.52 0.434], ...
    'scope', {{'pinf@Phillips curve, price setting'}});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### Diagnostic expectations

Diagnostic agents overreact to news: their forecast is
\((1+\theta) E_t x_{t+1} - \theta E_{t-1} x_{t+1}\) (one-period memory). Here they replace the RE
agents for every forward-looking expectation outside the flexible-price block; the learners
are unchanged. Because the baseline RE type uses t-1 information, the reference forecast of
inflation is the anchored \(E_{t-2}\pi_{t+1}\). \(\theta = 0.44\) is L'Huillier, Singh and Yoo's
(2024) estimate in SW07 with Rotemberg pricing.

```matlab
function cfg = br10_diagnostic()
cfg = a1_learn();
cfg.id = 'br10_diagnostic';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, ...
    'scope', 'all', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### Target believers

A third type of agent always forecasts the inflation target, the steady state (0 in
deviations); its share measures the credibility of the target (Hommes and Lustenhouwer 2019).
The three types switch as in the baseline (intensity of choice 2, memory 0.8), starting from a
third each.

```matlab
function cfg = br19_target_believers()
cfg = a1_learn();
cfg.id = 'br19_target_believers';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'BR', 'kind', 'plm'), ...
    struct('name', 'TB', 'kind', 'rule', 'rule', '0')};
cfg.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

`BR` is the code's name for the baseline learners (bounded rationality). The rule can be any
fixed linear expression, for example a naive forecaster
`struct('name', 'NV', 'kind', 'rule', 'rule', 'x{-1}')`, or one with named constants,
`'rule', struct('expr', 'a*x{-1}', 'params', struct('a', 0.5))`.

### Intercept-only learners

The learners know the structure of the economy (they use the RE forecast) but not its long-run
level: they forecast the RE forecast plus a learned mean \(\bar a\) of that forecast's own
error, \(x_t - E^{RE}_{t-1} x_t\) (Gáti 2023; Carvalho, Eusepi, Moench and Preston 2023). The
mean is learned with the baseline's endogenous gain of Kostyshyna, Özden and Zhang (2024). They
replace the AR(1) learners and switch against the RE agents as in the baseline. Gáti's smooth
anchoring function is not part of this rule, so the paths stay close to RE.

```matlab
function cfg = br23_intercept_only()
cfg = a1_learn();
cfg.id = 'br23_intercept_only';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'IO', 'kind', 're_mean')};
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

With \(\bar a\) held at 0 this type forecasts exactly as the RE type. Its learned mean is
`res.learning.pinf_feRE__IO.alpha_pinf_feRE__IO`.

### Mean-only learners

The learners' inflation perceived law of motion keeps only the constant, so their forecast is
the learned mean: adaptive expectations by exponential smoothing,
\(\alpha_t = \alpha_{t-1} + g_t(\pi_t - \alpha_{t-1})\), with the baseline's endogenous gain.
No new option is needed.

```matlab
function cfg = br24_mean_only()
cfg = a1_learn();
cfg.id = 'br24_mean_only';
cfg.beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

### Experience-based gain

In Malmendier and Nagel (2016) people weight the inflation they have lived through; in the
aggregate this is close to constant-gain learning with a gain of about 0.018 per quarter
(Nagel and Xu 2022; Malmendier and Nagel's best-matching constant gain is 0.0175). The AR(1)
learners use this gain instead of the baseline's endogenous gain. Cohorts are not modeled.

```matlab
function cfg = br26_experience()
cfg = a1_learn();
cfg.id = 'br26_experience';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.018;
cfg.compare_with = {'a1_learn', 'a1_re'};
end
```

## Running the rules

All seven and the two references:

```matlab
run_br_app1('run')          % a1_re, a1_learn, then the seven rules; about two minutes
run_br_app1('csv')          % results/br_portfolio/app1_*.csv
run_br_portfolio('irf')     % impulse responses from each rule's own 2019Q4 state
run_br_portfolio('rmse')    % Kalman histories: one-step RMSE and log likelihood, 1966Q1-2026Q2
run_br_portfolio('csv')     % results/br_portfolio/irf_*.csv, rmse_*.csv
```

Each rule on its own: `res = hetlearn.run(br19_target_believers());`.

## Results

Application 1 and the in-sample fit, from `results/br_portfolio/app1_summary.csv` and
`rmse_long.csv`. The gap is in percentage points (pp); the root-mean-square error (RMSE) is of
annualized inflation, in pp, from the Kalman history (`history.mode = 'kalman'`) over
1966Q1-2026Q2; RE(t-1) is the RE model with t-1 information for inflation.

| Rule | Avg. inflation 2022Q3-2026Q2 (%) | Peak gap to RE (pp) | Shares at the end of 2022Q2 | Inflation RMSE, one-step (pp) | RMSE / RE(t-1) | Log likelihood |
|---|---:|---:|---|---:|---:|---:|
| RE(t-1), `a1_re` | 2.59 | | | 1.483 | 1.000 | −2182.1 |
| Baseline, `a1_learn` | 3.45 | 3.54 (2023Q1) | RE 0.409, BR 0.591 | 1.237 | 0.834 | −1839.8 |
| Cognitive discounting | 4.09 | 3.23 (2023Q1) | RE 0.416, BR 0.584 | 1.120 | 0.755 | −1709.4 |
| Myopia and anchoring | 3.42 | 3.68 (2023Q1) | RE 0.483, BR 0.517 | 1.209 | 0.816 | −1825.3 |
| Diagnostic expectations | 4.75 | 4.74 (2023Q1) | RE 0.456, BR 0.544 | 1.325 | 0.894 | −2025.7 |
| Target believers | 3.38 | 2.36 (2022Q4) | RE 0.340, BR 0.491, TB 0.169 | 1.121 | 0.756 | −1723.2 |
| Intercept-only learners | 2.94 | 0.69 (2022Q4) | RE 0.388, IO 0.612 | 1.488 | 1.004 | −2192.8 |
| Mean-only learners | 3.08 | 0.89 (2023Q4) | RE 0.710, BR 0.290 | 1.125 | 0.759 | −1702.6 |
| Experience-based gain | 3.06 | 2.11 (2022Q4) | RE 0.425, BR 0.575 | 1.247 | 0.841 | −1857.6 |

The projection facility acts in none of these runs.
