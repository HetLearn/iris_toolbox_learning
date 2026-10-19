# Findings, SW07 with anchored RE and learning on inflation (2026-10-18)

Track H1, 2026-10-18. SW07 (swX1 mode), RE agents anchored (`re_variant = 'anchored'`), learning on
inflation only, switching with chi = 0.51, gain 0.0585, memory 0.6, BR information `'lagged'`,
projection facility `'plm_alm'`; forecasts from the 2022Q2 inflation peak (asserted with
`hetlearn.find_peak`), 16 quarters (2022Q3-2026Q2), zero future shocks unless stated. Scenario files:
`scenarios/sw07/<folder>/`; runner: `run_applications.m`; tables: `results/summary_v3/` (built by
`build_summary_v3.m`). Inflation, rates and growth are annualised percent; "pp" = percentage points.
Updated 2026-10-19 (KOZ errors in quarterly units, saved RE Ramsey benchmarks, review fixes). All 50
SW07 scenarios ran (40 runs, 10 evaluation variants), status ok; 15 of 15 checks in `checks_v3.txt`
pass. Every SW07 number below is in `key_numbers.csv`. Two share measures appear: `n2_model` is the
learners' share in force in the model in a quarter, `n2` the discrete-choice share computed at the end
of a quarter (in force in the next one).

| Result | RE | Learning |
|---|---|---|
| Average inflation 2022Q3-2026Q2 (app 1) | 3.24% | 3.64% |
| Largest learning-minus-RE inflation gap | | +1.02 pp (2022Q4) |
| Learners' share in force (`n2_model`), 2022Q3 / 2026Q2 | 0 | 0.416 / 0.498 |
| Replay of the RE-smoothed shocks, gap to the data, inflation (app 2) | 6e-13 (max) | 0.62 pp (RMS) |
| Policy 100 bp looser / tighter, peak inflation effect (app 3) | +1.01 / -1.01 pp | +0.91 / -0.89 pp |
| 90% inflation band, average width, mark-up / demand shocks (app 5) | 4.67 / 3.01 pp | 4.50 / 2.62 pp |
| Learners' share at the end of 2022Q2 (`n2`), RE-smoothed history / inversion (app 6) | | 0.416 / 0.395 |
| Inflation RMSE relative to RE, full sample, h = 1 / 4 / 8 (evaluation) | 1 | 0.992 / 1.005 / 1.004 |

## App 1. Forecast from the 2022Q2 peak: does learning raise the inflation path?

Yes: by 0.40 pp on average over the 16 quarters, with the gap positive through 2025Q3.

- Average inflation 2022Q3-2026Q2: 3.64% with learning, 3.24% under RE (data at the origin: 8.94%).
- Quarter by quarter: 8.00% vs 6.99% in 2022Q3, 5.33% vs 4.61% in 2023Q2, 3.16% vs 2.78% in 2024Q2.
  The gap peaks at +1.02 pp in 2022Q4, is +0.39 pp in 2024Q2 and +0.06 pp in 2025Q3, and turns
  slightly negative from 2025Q4 (2026Q2: 1.54% vs 1.64%).
- The policy rate follows inflation up: 4.32% vs 3.99% on average. Output growth is lower:
  -0.30% vs +0.11%.
- The learners' share in force (`n2_model`) is 0.416 in 2022Q3 (the `n2` computed at the end of
  2022Q2) and rises to 0.474 in 2023Q2, 0.493 in 2024Q2 and 0.498 in 2026Q2: the drift to 0.5 with zero
  shocks (Notes). Over the history 1966Q1-2022Q2 the end-of-quarter share `n2` averaged 0.494 (range
  0.362-0.589); it was 0.500 at the end of 2019Q4 and 0.452 at the end of 2021Q2.
- Beliefs at the origin: alpha 0.084, beta 0.927, so the learners' perceived mean inflation is 7.75%
  (steady state 3.13%). It falls to 2.48% by 2026Q2.
- No projection-facility events in the history or the forecast.

## App 2. Replay of the RE-smoothed shocks: how far is the learning replay from the data?

- Under RE the replay reproduces the data (max abs error 6e-13, check C1).
- With learning, the same shocks give, over 2022Q3-2026Q2: inflation RMS gap 0.62 pp, largest +1.67 pp
  in 2022Q3; policy rate 0.34 pp (largest +0.59 pp, 2022Q4); output growth 0.47 pp (largest -0.88 pp,
  2022Q4); consumption growth 0.44 pp (largest -0.76 pp, 2022Q4).
- Average inflation 3.45% in the learning replay vs 3.21% in the data (+0.24 pp). The gap is
  front-loaded: 77% of the squared inflation gap falls in 2022Q3-2023Q2 (+1.67, +1.11, +0.53,
  +0.68 pp); after that it alternates in sign within about +-0.7 pp.
- The learners' share in force (`n2_model`) goes from 0.416 in 2022Q3 to 0.505 in 2026Q2 (highest
  0.510).

## App 3. Policy 100 bp a year looser or tighter in 2022Q3-2023Q2: is the response asymmetric?

- Under RE the responses are exactly symmetric (largest |loose + tight| over 7 series 5e-14) and
  linear: the original SW07 model hit by the backed-out em shocks reproduces both runs to 3e-13
  (check C3). Looser policy raises inflation by up to 1.01 pp (2023Q2; +0.62 pp on average), lowers
  the rate by up to 1.78 pp (2023Q2, including the rule's response) and raises output growth by up to
  1.95 pp.
- Under learning the response is asymmetric, but only slightly: inflation +0.913 pp (loose) vs
  -0.887 pp (tight) at the peak, 2023Q4; the largest asymmetry is +0.025 pp (2023Q4), about 3% of the
  effect. Average effects +0.602 vs -0.599 pp. Rate: -1.905 vs +1.906 pp at 2023Q2 (asymmetry
  +0.014 pp, 2024Q2); output growth +2.07 vs -2.08 pp (asymmetry -0.021 pp, 2023Q4).
- The asymmetry comes from the learning states, which respond nonlinearly to the paths: for example,
  looser policy raises the learners' share in force (`n2_model`) by up to 0.006 and tighter policy
  lowers it by up to 0.008 (both 2023Q3).
- Learning delays and slightly damps the inflation effect (peak 0.91 pp in 2023Q4 vs 1.01 pp in
  2023Q2 under RE) and enlarges the rate effect (1.90 vs 1.78 pp). The delay has the timing reason
  given in app 5: the learners' expectation reacts to the policy deviation only a quarter later.

## App 4. Taylor rule vs Ramsey policy: losses by weight set

Discounted losses (pinf 4*pinf, ygap y - yf, r 4*r, dr 4*(r - r{-1}); discount 0.99756), 80 quarters
(16 in brackets). The RE Ramsey benchmark is `a4_ramsey_<w>_re_mc`: the `a4_ramsey_<w>_re` files with
`re_variant = 'model_consistent'`, run and saved like every other scenario (they reproduce the earlier
in-script diagnostic exactly, check C12).

| Weights | RE rule | RE Ramsey (anchored block) | RE Ramsey, model-consistent (`_re_mc`) | Learning rule | Learning Ramsey |
|---|---|---|---|---|---|
| balanced (1, 0.5, 0.1, 0) | 763.7 (256.4) | 38.9 (33.0) | 631.3 (241.0) | 977.4 (405.7) | 80.2 (67.5) |
| hawk (1, 0.1, 0.1, 0) | 219.8 (89.5) | 28.1 (22.9) | 183.7 (98.0) | 284.1 (137.4) | 61.1 (51.8) |
| dove (1, 1, 0.1, 0) | 1443.5 (465.1) | 43.8 (37.7) | 1051.8 (372.3) | 1844.0 (741.1) | 87.3 (73.8) |
| smooth (1, 0.5, 0.1, 0.5) | 766.1 (258.8) | 54.4 (48.3) | 637.6 (247.1) | 980.5 (408.8) | 101.4 (88.3) |

- Rule losses are the same under anchored and model-consistent RE (check C11: inflation paths to
  3e-13, loss to 6e-13). With model-consistent RE agents, Ramsey beats the rule over 80 quarters for
  every weight set (balanced 631 vs 764) and loses over 16 quarters with hawk weights (98.0 vs 89.5);
  these equal the Track A2 and round-2 RE numbers (241.0 and 631).
- The RE Ramsey plans run inflation higher than the rule over 2022Q3-2026Q2 (average 5.47% balanced,
  3.86% hawk, 6.65% dove, 5.44% smooth, vs 3.24%), with a higher rate (6.10%, 5.30%, 7.12%, 5.72% vs
  3.99%); output growth is higher except with hawk weights (0.54%, 0.00%, 0.82%, 0.52% vs 0.11%). The 80-quarter target paths of
  every app-4 run are in `app4_targets_long.csv`.
- Caveat, and an open design question: anchored RE agents forecast with the RE solution under the
  Taylor rule, not under the Ramsey policy (IJCB's anchored agents use the RE solution of the active
  policy). This affects the RE Ramsey runs too, not only learning: in mode `'rational'` the pinf block
  is still the anchored forecast, so `a4_ramsey_*_re` are not RE Ramsey plans. Inflation
  expectations stay on the Taylor-rule forecast function while the planner moves the rate, and the
  loss drops by a factor of 16 (balanced, 38.9 vs 631.3). The Ramsey paths differ a lot from the rule
  paths (balanced, RE: average inflation 4.17% vs 3.24%, rate 6.24% vs 3.99%, output growth 1.77% vs
  0.11%).
- Under learning, Ramsey has the lower loss for every weight set, but the anchored RE agents (a share
  1 - `n2_model` = 0.584 in 2022Q3) carry the same exploitable forecast, so these losses and their
  ratios are not read as the gain from optimal policy.

## App 5. Density forecasts: how does learning change the inflation bands?

500 normal draws, calibrated sigma, seed 0; 500 used, none explosive; learning on the general path
(0.71 s per draw), RE on the fast path (equal to the general path to 1.5e-12 on a 10-draw check, C5).

- Mark-up shock uncertainty (epinf, ew): learning narrows the average 90% inflation band a little,
  4.50 vs 4.67 pp (ratio 0.96); it is wider at h = 4 (4.77 vs 4.61) and h = 16 (5.07 vs 4.95), narrower
  at h = 8 (4.48 vs 4.67). The output-growth band widens: 5.31 vs 4.88 pp (ratio 1.09).
- Demand shock uncertainty (eb, eg, eqs): learning narrows the inflation band by 13%, 2.62 vs 3.01 pp
  (h = 4: 2.17 vs 2.69; h = 8: 2.83 vs 3.32; h = 16: 3.33 vs 3.54), and the rate band
  (3.91 vs 4.17 pp). The output-growth band is about the same (13.64 vs 13.38 pp).
- The learners' share in force (`n2_model`) moves with the draws: its 90% band averages 0.045 wide
  under mark-up shocks and 0.013 under demand shocks. The median inflation path (3.65% and 3.64% on
  average) stays close to the point forecast (3.64%).
- Why the bands narrow (one unit of each shock in 2022Q3, `app5_mechanism.csv`): in the quarter a shock
  hits, the learners' expectation does not move, because they forecast from data up to t-1, so the
  aggregate inflation expectation moves about half as much as under RE (epinf 1.91 vs 3.53 pp, ew 0.59
  vs 1.09, eqs 0.70 vs 1.27) and inflation responds less on impact (epinf 5.41 vs 6.79 pp, ew 0.64 vs
  1.06, eb 0.22 vs 0.37, eg 0.14 vs 0.24, eqs 0.61 vs 1.10). From h = 2-4 on the learning response is
  the larger one; summed over 16 quarters the absolute responses are close (learning / RE 0.98-1.09),
  and `n2_model` moves by at most 0.027. A band at horizon h adds up the squared responses to all
  earlier draws, so the smaller impact responses narrow it. The result depends on
  `beliefs.info = 'lagged'` (the user's spec); the same one-quarter delay explains the later inflation
  peak in app 3 (2023Q4 vs 2023Q2).

## App 6. History backed out with the learning model

- Which shocks change: mainly the price mark-up shock. Inversion minus RE-smoothed shocks, in standard
  deviations: epinf RMS 0.55 over 1966Q1-2026Q2 and 0.89 over 2021Q1-2023Q4, largest -2.27 in 2022Q3;
  ew 0.19 (0.40; -0.74 in 2022Q3); eqs 0.10 (0.19; -0.51 in 2022Q3); eb 0.045 (largest +0.16, 1980Q4);
  em 0.007, ea 0.002, eg 0.001. In 2022Q3, when inflation fell while the learners still expected
  high inflation (perceived mean 7.75% at the origin), the learning model needs a price mark-up shock
  2.27 sd lower than the RE smoother does; over 2021-2023 it gives mark-ups a smaller part of the
  surge (table below).
- The inversion fits the 7 observables to 2.2e-15 (C9). The end-of-quarter share `n2` is 0.395 at the
  end of 2022Q2 (RE-smoothed history: 0.416), 0.516 vs 0.510 at the end of 2026Q2, and averages 0.494
  vs 0.493 over 1966Q1-2026Q2.
- Decompositions, average contribution in pp (deviation from the steady state):

| Window, variable | Case | demand | monetary | supply | price mark-up | wage mark-up | intercept channel | total |
|---|---|---|---|---|---|---|---|---|
| 2021Q1-2023Q4, inflation | RE smoother | -0.61 | +2.18 | -0.70 | +1.52 | -0.52 | 0 | +1.86 |
| 2021Q1-2023Q4, inflation | learning inversion | -0.59 | +1.80 | -0.67 | +1.24 | -0.08 | +0.17 | +1.86 |
| 2021Q1-2023Q4, output growth | RE smoother | +2.70 | +0.75 | +0.26 | -2.23 | -0.46 | 0 | +1.02 |
| 2021Q1-2023Q4, output growth | learning inversion | +3.25 | +0.81 | +0.33 | -2.02 | -0.70 | -0.64 | +1.02 |
| 2008Q1-2019Q4, inflation | RE smoother | -1.45 | +1.02 | -0.55 | +0.04 | -0.66 | 0 | -1.61 |
| 2008Q1-2019Q4, inflation | learning inversion | -1.08 | +0.74 | -0.43 | +0.06 | -0.54 | -0.35 | -1.61 |

  (init is between -0.02 and 0 in these windows.) In the 2021-2023 surge the learning decomposition gives
  less to price mark-ups (1.24 vs 1.52) and monetary shocks (1.80 vs 2.18), almost nothing to wage
  mark-ups (-0.08 vs -0.52), and 0.17 pp to the intercept channel (the learners' moving perceived
  mean). For output growth it gives more to demand (3.25 vs 2.70) and -0.64 pp to the intercept
  channel. Slope beliefs and shares act inside every shock component.
- The decomposition of `a6_smooth_learn` equals the RE one over 1966Q1-2026Q2 (1e-14, C6b): without
  the inversion the history is the RE-smoothed one and is decomposed with the RE model. All three
  decompositions rebuild their paths (C6: 2e-13 to 1.2e-12).

## Variant 1. Anchored vs model-consistent RE agents

- With model-consistent RE agents learning raises average inflation by 3.39 pp over RE instead of
  0.40 pp: 6.63% vs 3.64% (anchored) and 3.24% (RE); policy rate 6.95% vs 4.32%; output growth
  -3.39% vs -0.30%.
- The average hides a boom and bust: inflation is 10.05% in 2022Q3, 12.98% in 2023Q2, 9.24% in 2024Q2,
  1.91% in 2025Q2 and -3.06% in 2026Q2. The learners' perceived mean inflation goes from 23.5% (end of
  2022Q3) to 27.3% (2023Q2, its high) and -15.0% (2026Q2). The facility holds the beliefs in 2022Q4 and
  2023Q1 (candidate inflation roots 1.039 and 1.009).
- Mechanism: model-consistent RE agents forecast the heterogeneous economy as if the learners' current
  beliefs were permanent, so they first amplify the learners' high perceived mean and then its fall.
- Same end-of-2022Q2 share `n2` (0.416: the history is the same RE-smoothed history), but a different
  path of `n2_model`: 0.452 in 2022Q4, 0.486 in 2024Q1, down to 0.414 in 2025Q2, 0.442 in 2026Q2.
- In the evaluation it is the weakest inflation variant (relative RMSE 1.085 / 1.245 / 1.074 at
  h = 1 / 4 / 8, p 0.30-0.45) and worse on output growth at h = 1 (1.033, p 0.03).

## Variant 2. Perceived laws of motion (learning on inflation; the other VAR members are auxiliary)

| PLM | Avg inflation | `n2`, end of 2022Q2 | Largest root 2022Q2 | Perceived mean 2022Q2 | Coefficients at 2022Q2 | Facility events (history / forecast) |
|---|---|---|---|---|---|---|
| AR(1) (a1_learn) | 3.64% | 0.416 | 0.927 | 7.75% | alpha 0.084, beta 0.927 | 0 / 0 |
| AR(2) | 3.63% | 0.494 | 0.976 | 12.06% | alpha 0.081, lags 0.467, 0.497 | 4 / 0 |
| AR(1), no constant | 3.58% | 0.440 | 0.915 | 3.13% (fixed at the steady state) | beta 0.915 | 1 / 0 |
| pinf on pinf{-1}, ygap{-1}, r{-1} | 3.52% | 0.435 | 0.941 | 5.00% | alpha 0.303, pinf 0.895, ygap -0.064, r 0.213 | 17 / 3 |
| VAR(1) pinf, ygap, r | 4.16% | 0.442 | 0.975 | 3.82% | pinf equation: alpha 0.340, pinf 0.894, ygap -0.064, r 0.241 | 13 / 10 + 5 kept shares |
| VAR(1), 12 variables | 3.21% | 0.485 | 0.989 | 2.29% | pinf equation: alpha 0.458, own lag 0.727, largest others lab 0.81, labf -0.59, cf 0.46, c -0.43 | 65 / 3 |

- The PLM changes the learners' share at the origin (`n2` 0.416-0.494) and the perceived mean
  (2.3-12.1%) far more than average inflation (3.2-4.2%).
- The AR(2) beliefs in force at the origin are those of 2021Q3: three of its four history facility
  events are the three quarters before the origin (2021Q4, 2022Q1, 2022Q2, candidate roots 1.006,
  1.061, 1.064; the fourth is 1974Q3), so the coefficients in the table did not change after 2021Q3.
- The VAR(1) in {pinf, ygap, r} leans on the facility: its beliefs are kept in 10 of the 16 forecast
  quarters (2022Q3-2024Q4, roots 1.01-1.08) and the model shares in force (`n2_model`) are held at
  0.467 in 5 (2022Q4-2023Q4). Its `n2_model` then falls to 0.114 in 2025Q3. Read its path with that in
  mind.

## Variant 3. Learning on all 12 variables, and the projection facility options

- Inflation only: 3.64% average inflation. All 12 variables: 4.63% (`'plm_alm'`), 4.71% (`'alm'`),
  4.51% (`'none'`).
- `'plm_alm'` keeps a block's previous beliefs when its root would exceed 1: 127 times in the history
  (226 quarters x 12 AR(1) blocks) and 13 in the forecast. `'alm'` lets PLMs go explosive and reverts
  every belief only when the model has no stable solution: once (history), no forecast event.
  `'none'` restricts nothing: `v3_all_none` did not stop (no `noSolution`): with anchored RE and every
  forward-looking variable learning the model has no leads, so it is simulated as it is, and no
  quarter was explosive.
- End-of-2022Q2 shares (`n2`), mean over the 12 variables: 0.258 / 0.264 / 0.220 (largest 0.436 /
  0.457 / 0.435); inflation 0.416 / 0.426 / 0.416.
- The facility moves average inflation by at most 0.2 pp here. The `'plm_alm'` run depends on 140
  PLM-block events.

## Variant 4. Endogenous gain (KOZ 2024, errors in quarterly units)

- The errors enter in model units, percent per quarter (`gain.koz.error_scale = 1`, user decision
  2026-10-19; the first version used 4, annualised, and mu effectively scales with the square of the
  factor). With scale 1 the gain stays close to the constant 0.0585, as expected: on the RE-smoothed
  history it averages 0.0598 over 1966Q1-2026Q2, from 0.0576 (1972Q3) to 0.0652 (2022Q3); 0.0591 in
  2020Q2, 0.0613 in 2021Q4, 0.0641 in 2022Q2, 0.0608 in 2023Q4, 0.0602 in 2026Q2. No bound binds.
- At the peak: gain 0.0641 at the origin, 0.0628 on average over the forecast, 0.0619 in 2026Q2.
  Beliefs at the origin: alpha 0.088, beta 0.935 (constant gain: 0.084, 0.927), perceived mean 8.54%
  (7.75%).
- The forecast is the constant-gain one: average inflation 3.638% vs 3.640%, policy rate 4.32% in both,
  output growth -0.29% vs -0.30%; `n2` at the end of 2022Q2 0.417 vs 0.416, `n2_model` 0.498 in 2026Q2
  in both. One PLM-block event in the history (none with the constant gain).

## Evaluation. Real-time forecasts, 1990Q1-2024Q2, H = 8

1380 runs (10 variants x 138 origins), no failures; benchmark RE; DM with the uniform kernel and the HLN
correction (24 cells fall back to Bartlett). RE RMSE, full sample, h = 1 / 4 / 8: inflation 1.02 /
1.40 / 1.62 pp, output growth 4.58 / 4.48 / 4.54 pp.

| Variant | Inflation, full | Inflation 1990-2007 | Inflation 2008-2019 | Inflation 2020-2026 | Output growth, full |
|---|---|---|---|---|---|
| Learning (inflation) | 0.992 / 1.005 / 1.004 | 0.986 / 0.934 / 0.973 | 0.964 / 0.979 / 1.024 | 1.009 / 1.033 / 1.008 | 1.013 / 1.005 / 1.001 |
| Model-consistent RE | 1.085 / 1.245 / 1.074 | 1.085 / 0.981 / 0.898 | 0.986 / 0.966 / 1.058 | 1.136 / 1.388 / 1.128 | 1.033 / 1.047 / 1.027 |
| All agents learn | 1.056 / 1.149 / 1.082 | 1.055 / 0.967 / 0.912 | 0.986 / 0.960 / 1.035 | 1.093 / 1.251 / 1.143 | 1.035 / 1.041 / 1.036 |
| AR(2) | 0.962 / 0.996 / 1.009 | 0.986 / 0.913 / 0.972 | 0.963 / 0.978 / 1.028 | 0.954 / 1.024 / 1.015 | 1.012 / 1.006 / 1.001 |
| AR(1), no constant | 1.026 / 1.005 / 0.996 | 1.000 / 0.954 / 0.987 | 1.052 / 1.070 / 1.089 | 1.020 / 0.997 / 0.974 | 0.999 / 1.002 / 1.004 |
| Regression | 1.007 / 0.998 / 1.001 | 1.005 / 0.927 / 0.973 | 0.992 / 0.948 / 1.017 | 1.016 / 1.034 / 1.006 | 1.012 / 1.012 / 1.002 |
| VAR(1), 3 variables | 0.995 / 0.993 / 1.028 | 0.993 / 0.915 / 0.962 | 0.974 / 0.937 / 1.011 | 1.007 / 1.031 / 1.053 | 1.012 / 1.012 / 1.016 |
| VAR(1), 12 variables | 1.042 / 0.990 / 0.998 | 1.081 / 1.043 / 1.007 | 1.108 / 1.077 / 0.994 | 0.991 / 0.942 / 0.995 | 1.005 / 1.006 / 1.003 |
| All 12 variables | 0.995 / 1.011 / 1.011 | 0.991 / 0.892 / 0.901 | 0.966 / 0.966 / 1.072 | 1.012 / 1.056 / 1.028 | 0.972 / 0.997 / 0.987 |

(relative RMSE at h = 1 / 4 / 8; below 1 = better than RE; samples by target date)

- Inflation: no variant beats RE in the full sample (best: AR(2) 0.962 at h = 1, p 0.45; baseline
  learning p 0.83-0.89). In 1990-2007 most learning variants are below 1 at h = 4-8 (all 12 variables
  0.892 / 0.901, VAR(1) 3 variables 0.915 / 0.962), none at p < 0.05. Significant differences are
  rare: AR(1) without constant is worse in 2008-2019 at h = 8 (1.089, p 0.01); VAR(1) in 12 variables
  is worse in 2008-2019 at h = 1 (1.108, p 0.04).
- Output growth: the learning variants are slightly worse at h = 1 (baseline 1.013, p 0.09;
  model-consistent 1.033, p 0.03; all agents learn 1.035, p 0.04). Only all 12 variables is clearly
  below 1 at h = 1 (0.972, p 0.14; 0.900 in 2008-2019, p 0.01); AR(1) without constant is at 0.999.
- DM p < 0.10 counts over h = 1-8 x 4 samples (32 cells per variable): inflation, baseline learning 1
  better / 0 worse, AR(1) without constant 3 / 4, VAR(1) 12 variables 1 / 3, every other variant at
  most 1 / 1; output growth, VAR(1) 12 variables 0 / 5, model-consistent 0 / 3, all agents learn 0 / 3,
  every other variant at most 1 / 2.
- In 2020-2026 the AR(2) is worse at h = 4 (1.024, p < 0.01) and VAR(1) in 12 variables better at
  h = 8 (0.995, p 0.01): differences of 0.5-2.4% on few targets (19 at h = 1, 26 at h = 8), so these
  p-values are fragile.

## Application 1 on two other models

Track M3, 2026-10-18. Application 1 as above (2022Q2 peak, 16 quarters, zero future shocks, anchored RE
agents, switching on inflation only, facility `'plm_alm'`) on two more packages at published parameter
values, with no estimation: `ijcb3`, the three-equation NK model of IJCB at its heterogeneous-expectations
posterior means, and `as07`, An and Schorfheide (2007) at the Herbst-Schorfheide (2016) posterior means for
1983Q1-2002Q4. Learning parameters: IJCB's estimates for ijcb3 (gain 0.0585, memory 0.62, chi 0.51, set in
`i1_learn.m`), the toolbox calibration for as07 (gain 0.0585, memory 0.6, chi 0.51). Scenarios `i1_re`,
`i1_learn` (`scenarios/ijcb3/app1_peak/`) and `a1as_re`, `a1as_learn` (`scenarios/as07/app1_peak/`), run
with `hetlearn.run`, all ok (2.9, 2.0, 1.2 and 2.4 s). Tables and checks come from
`build_other_models.m`; 11 of 11 checks in `other_models_checks.txt` pass. The ijcb3 and as07 numbers are in
`other_models_key_numbers.csv`, the SW07 column in `key_numbers.csv`.

Both packages ran without toolbox changes. The collapse tests pass (largest IRF difference 1e-14 in ijcb3,
6e-15 in as07). The RE filter rebuilds the data to 6e-15 and 7e-14, with the policy rate missing in the 36
ELB quarters in both packages and, in as07, three measurement errors, which no earlier package had. The RE
runs equal the original models: each model's own Kalman smoother gives the run's history (6e-15 and
3.7e-12), and its zero-shock simulation from the 2022Q2 state gives the forecast (1.5e-15 and 8.1e-13).

| Result | SW07 | ijcb3 | as07 |
|---|---|---|---|
| Average inflation 2022Q3-2026Q2, RE / learning | 3.24% / 3.64% | 2.45% / 3.03% | 3.57% / 3.67% |
| Learning minus RE, average / largest | +0.40 / +1.02 pp (2022Q4) | +0.58 / +1.92 pp (2022Q3) | +0.10 / +0.74 pp (2022Q3) |
| Learning minus RE in 2026Q2 | -0.10 pp | +0.30 pp | +0.03 pp |
| Learners' share, `n2` at the end of 2022Q2 / `n2_model` in 2026Q2 | 0.416 / 0.498 | 0.495 / 0.500 | 0.386 / 0.500 |
| Inflation PLM at the origin: beta / perceived mean (steady state) | 0.927 / 7.75% (3.13%) | 0.714 / 4.40% (2.32%) | 0.701 / 4.26% (3.30%) |
| Inflation in 2022Q2, data / RE forecast for 2022Q3 | 8.94% / 6.99% | 9.30% / 3.81% | 9.30% / 5.78% |
| Facility events, history / forecast | 0 / 0 | 2 / 0 | 2 / 0 |

Learning raises the inflation path after the peak in all three models. The gap is largest in the first one
or two forecast quarters; only in SW07 does it turn negative late in the horizon, and in ijcb3 it is still
+0.30 pp in 2026Q2. ijcb3 and as07 observe CPI inflation, SW07 the GDP deflator.

### ijcb3 (IJCB three-equation model)

Yes, learning raises the path: by 0.58 pp on average, with the gap positive in all 16 quarters.

- Average inflation 2022Q3-2026Q2: 3.03% with learning, 2.45% under RE (data at the origin: 9.30%; data
  average over the 16 quarters, not used by the forecasts: 3.32%).
- Quarter by quarter: 5.73% vs 3.81% in 2022Q3, 2.96% vs 2.36% in 2023Q2, 2.75% vs 2.34% in 2024Q2, 2.62%
  vs 2.33% in 2026Q2. The gap is +1.92 pp in 2022Q3, +1.33 in 2022Q4, +0.82 in 2023Q1 and +0.59 in 2023Q2,
  then shrinks slowly: +0.41 pp in 2024Q2, +0.35 in 2025Q2, +0.30 in 2026Q2. 2022Q3 holds 21% of the summed
  gap.
- The policy rate follows inflation: 1.43% vs 0.99% on average (largest gap +0.63 pp, 2022Q3). The output gap
  averages 0.11 vs 0.19: higher in 2022Q3 (1.23 vs 0.58), lower later (0.18 vs 0.29 in 2023Q2, -0.12 vs 0.04
  in 2026Q2).
- The learners' share is 0.495 at the end of 2022Q2 (`n2`, in force in 2022Q3); in force (`n2_model`) 0.508 in 2022Q4, 0.482 in 2023Q1
  (its low), 0.497 in 2024Q2 and 0.500 in 2026Q2. It starts close to 0.5, where the zero-shock drift ends
  (Notes), so it barely moves. Over 1961Q1-2022Q2 `n2` averaged 0.519 (from 0.337 in 1983Q1 to 0.896 in
  1980Q1); it was 0.501 at the end of 2019Q4, 0.479 in 2021Q2 and 0.446 in 2022Q1.
- Beliefs at the origin: alpha 0.149, beta 0.714 (inflation in % per quarter, as a deviation from pi_bar),
  so the learners' perceived mean inflation is 4.40% (steady state 2.32%). By 2026Q2 it is 3.07% (alpha
  0.066, beta 0.648), still 0.75 pp above the steady state.
- Origin state: no measurement errors, so the smoothed state reproduces the data: output gap 1.00,
  inflation 1.74% per quarter above pi_bar, policy rate 0.07% per quarter below r_bar_T (funds rate 0.77%).
  The filter reads the peak as a cost-push shock: the cost-push process is 1.19 of the 1.74 (innovation 1.15,
  3.0 sd); policy shock -0.22 (-0.9 sd), demand innovation 0.06 (0.2 sd).
- Steady state: the RE forecast returns to inflation of 2.32%, a policy rate of 1.04% and a zero output gap.
  With rho_pi = 0.04 the cost-push process is gone after a quarter: RE inflation falls from 9.30% to 3.81%
  in 2022Q3, closing 79% of the gap between model inflation and its steady state, and 99.9% by 2026Q2
  (2.33%). The RE rate goes from 0.85% in 2022Q3 to 1.05% in 2026Q2.
- Reading the parameters: with kappa = 0.0032 the output gap moves inflation very little, so the higher
  policy rate does little to pull inflation back towards the RE path. This fits the slow decline of the gap.
- Events: two PLM-block events in the history, 1974Q1 and 1980Q1 (the candidate AR(1) coefficient exceeded
  1; previous beliefs kept); none in the forecast; no ALM events. The RE run's diagnostic learning has the
  same two.
- Caveats. (1) ELB: the package has no ELB regime. The funds rate is missing in the 36 ELB quarters, and the
  filter infers a shadow rate from the rule: -2.85% at its trough in 2010Q2 (average -1.00% over
  2009Q1-2015Q4), -2.24% in 2020Q2 (average -0.60% over 2020Q2-2022Q1), +0.52% in 2022Q1 against a funds rate
  of 0.12%. RE agents expect the rule to hold in every quarter, and the shadow rate reaches the learners'
  shares through the RE forecasts on the smoothed history. The rate is observed at the origin. (2) Trend
  real rate: r_bar_T - pi_bar = -1.28% a year at IJCB's HE estimates, so the RE forecast settles at a 1.04%
  funds rate with 2.32% inflation; the funds rate averaged 4.41% over 2022Q3-2026Q2 in the data. In IJCB's
  HE model the learners' perceived means absorb this gap; here the RE filter needs positive cost-push shocks
  on average instead (`models/ijcb3/README.md`, open issue 1). Read both rate paths with this in mind.
  The package keeps IJCB's HE column (user decision 2026-10-19): in IJCB's HE model the learners' moving
  perceived means absorb part of the trends (IJCB p. 296), and the RE column (0.66, 1.02) would give a
  real-rate trend of +1.4% a year.

### as07 (An and Schorfheide 2007)

Yes, but by little: 0.10 pp on average, most of it in the first three quarters.

- Average inflation 2022Q3-2026Q2: 3.67% with learning, 3.57% under RE (data at the origin: 9.30%; data
  average: 3.32%).
- Quarter by quarter: 6.52% vs 5.78% in 2022Q3, 3.51% vs 3.50% in 2023Q2, 3.34% vs 3.30% in 2024Q2, 3.33%
  vs 3.30% in 2026Q2. The gap is +0.74 pp in 2022Q3, +0.35 in 2022Q4 and +0.09 in 2023Q1; from 2023Q2 it
  stays between +0.009 (2023Q3) and +0.042 pp (2024Q3). 2022Q3 holds 46% of the summed gap; the gap never
  turns negative.
- Policy rate 5.70% vs 5.56% on average (largest gap +0.37 pp, 2022Q4); output growth 1.48% in both runs
  (largest gap -0.15 pp, 2022Q4).
- The learners' share is 0.386 at the end of 2022Q2 (`n2`), its lowest value in force over the horizon, then (`n2_model`) 0.464
  in 2023Q2, 0.495 in 2024Q2 and 0.500 in 2026Q2 (the zero-shock drift). It had been falling into the
  origin: 0.503 at the end of 2019Q4, 0.458 in 2021Q2, 0.383 in 2021Q4, 0.359 in 2022Q1. Over 1966Q1-2022Q2
  `n2` averaged 0.495 (from 0.352 in 1983Q1 to 0.645 in 1980Q1).
- Beliefs at the origin: alpha 0.072, beta 0.701, so the learners' perceived mean inflation is 4.26%
  (steady state 3.30%); 3.49% by 2026Q2 (alpha 0.017, beta 0.651).
- Origin state: the filter splits the data into model variables and measurement errors. Model inflation is
  8.96% (data 9.30%; measurement error +0.33 pp, 1.1 sd), the model rate 1.74% (funds rate 0.77%; error
  -0.97 pp, -2.2 sd) and model output growth -0.15% (data -0.20%). The smoothed policy shock is -1.19
  (-5.4 sd): the filter reads the surge as policy far below the rule. Government spending innovation -0.55
  (-0.8 sd), technology -0.13 (-0.4 sd); the gap y - g is 1.02 (y 5.44, g 4.42).
- Steady state: the RE forecast returns to the 1983Q1-2002Q4 steady state, inflation 3.30%, a funds rate of
  5.80% (real rate 2.50%) and output growth of 2.08%. RE inflation falls to 5.78% in 2022Q3, closing 56% of
  the gap between model inflation and its steady state, and is at 3.30% by 2024Q2. The RE rate rises from
  3.96% in 2022Q3 to 5.79% in 2026Q2.
- Events: the same two history PLM-block events as in ijcb3 (1974Q1, 1980Q1), none in the forecast, no ALM
  events.
- Caveats. (1) Steady state: the forecast inherits the 1983-2002 levels; in the data the funds rate averaged
  4.41% over 2022Q3-2026Q2. With a 5.80% steady-state rate the shadow rate in the ELB quarters stays mostly
  above zero: 3.44% on average over 2009Q1-2015Q4 (trough -1.15% in 2009Q1), 2.74% over 2020Q2-2022Q1
  (trough 0.40% in 2020Q2), 2.87% in 2022Q1 against a funds rate of 0.12%. (2) Measurement errors: fixed
  std devs from the book's replication code (0.46 for output growth annualised, 0.29 for inflation, 0.45
  for the rate). Over 1965Q1-2022Q2 the smoothed errors have std 0.17, 0.12 and 0.24. The learners learn
  model inflation, the smoothed state net of the error: 8.96% at the origin, not the 9.30% in the data. The
  forecasts set the errors to zero, so forecast inflation is 3.30 + 4 x model inflation (check M6).

Files (`results/summary_v3/`, written by `build_other_models.m`): `other_models_paths_long.csv` (model,
scenario, date, variable, value, source, stage; pinfobs, robs and the output measure, `yobs` for ijcb3 and
`dy` for as07, in report units, 2015Q1-2026Q2; scenario rows hold the RE-smoothed history to 2022Q2, with the
smoothed shadow rate in ELB quarters; data rows leave out robs in the 12 ELB quarters of 2015Q1-2022Q1 and add
`ffr`, the funds rate in every quarter), `other_models_learning_long.csv` (model, scenario, date, variable,
field, value, stage; the learning runs from the start of learning, 1961Q1 for ijcb3 and 1966Q1 for as07, to
2026Q2: n2, n2_model in the forecast quarters, alpha_pinf, beta_pinf, persistence, perceived_mean in model
units and perceived_mean_report annualised), `other_models_key_numbers.csv`, `other_models_checks.txt`.
Report units are model units x `spec.report.scale`: ijcb3 inflation and rate x 4, output gap x 1; as07
output growth x 4, inflation and rate x 1 (already annualised).

## Notes

- Share drift to 0.5 with zero shocks: with no new errors both fitness measures decay towards zero,
  so the discrete-choice shares tend to 0.5 by construction (no cost term for RE). The rising shares
  in the zero-shock forecasts are this mechanism, not a finding.
- The peak forecasts start from the full-sample smoothed state. Against the real-time evaluation
  forecasts from the same origin (2022Q2), the largest difference over h = 1-8 is 0.067 / 0.095 / 0.109 /
  0.100 pp under RE (inflation, rate, output growth, consumption growth), 0.057 / 0.087 / 0.123 /
  0.108 pp with learning, and up to 0.29 pp (output growth) with model-consistent RE agents. The
  evaluation itself uses real-time filters.
- chi = 0.51 is IJCB's estimate on quarterly data (the user confirmed on 2026-10-18 that IJCB's data
  are in percent per quarter). Rounds 1-2 used chi = 8, 16 times stronger switching: the learners'
  end-of-2022Q2 share `n2` was 0.005 then and is 0.416 now, so shares are not comparable with the
  archived results.
- Results that lean on the projection facility: `v2_var3` (beliefs kept in 10 of 16 forecast
  quarters, model shares kept in 5), `v3_all` (127 history and 13 forecast PLM-block events),
  `v2_var12` (65 history, 3 forecast), `v2_reg` (17 history, 3 forecast), `v2_ar2` (beliefs kept in
  the three quarters before the origin, so the 2021Q3 beliefs are in force at 2022Q2). In the evaluation the event
  totals over 138 runs (all types; `hetlearn.evaluate` does not record types) are 13164 for all 12
  variables, 5517 for VAR(1) in 12 variables, 1907 for the regression PLM, 1261 for VAR(1) in 3
  variables, 168 for AR(2), 139 for AR(1) without constant, 2 for model-consistent RE and 0 otherwise.
  No other scenario kept model shares.
- App 4: the Ramsey losses with anchored RE agents (RE and learning) rest on the open design question
  above; only the model-consistent runs `a4_ramsey_<w>_re_mc` are RE Ramsey plans.

## Files (`results/summary_v3/`)

`scenarios.csv` (id, folder, app, label, description, status, runtime_s, error_message, n_events, and
projection_plm / projection_alm / projection_alm_shares counts by stage), `paths_long.csv` (pinfobs,
robs, dy, dc, 2015Q1-2026Q2, scenarios and data), `learning_long.csv` (1966Q1 to the end of each
horizon: n2_model, n2, belief parameters, persistence, perceived_mean in model units and
perceived_mean_report, annualised, for pinf and r; gain and gain_R; rows without a finite value
omitted, so on the RE-smoothed history n2_model starts in the first forecast quarter), `events_long.csv`,
`app3_policy.csv` (also ygap, ms x 4 and n2_model_pinf), `app4_losses.csv` (`RE_model_consistent`
rows from the saved `a4_ramsey_<w>_re_mc` runs), `app4_targets_long.csv` (scenario, h, date, target,
value: the 80-quarter loss targets of every app-4 run), `app5_density.csv`, `app5_widths.csv`,
`app5_mechanism.csv` (shock, case, expectations, variable, h, date, response: one unit of each
density shock in 2022Q3, RE and learning), `app6_decomp_long.csv`
(component `intercept_channel` = toolbox `beliefs_constants`; `label` column), `app6_shocks_long.csv`
(inversion vs smoothed shocks, also in sd units), `v3_facility.csv`, `eval_metrics.csv`,
`eval_relative.csv`, `eval_dm.csv` (with `label`), `key_numbers.csv`, `checks_v3.txt`.
