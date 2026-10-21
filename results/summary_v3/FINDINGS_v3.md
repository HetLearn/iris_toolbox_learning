# Findings, SW07 with anchored RE and learning on inflation (2026-10-18)

> **2026-10-21: projection facility `'alm'`.** The user set `projection.facility = 'alm'` (was
> `'none'`) in `config/master_options.m`: "impose the projection facility on the actual law of motion
> across the board". Every other baseline setting is unchanged. Every SW07 run, the decompositions,
> the evaluation and `build_summary_v3.m` were rerun; `checks_v3.txt` 15 of 15 pass (C8 now expects
> every run to complete and lists the facility events). The tables, this memo and the report of
> 2026-10-20 are in `archive/2026-10-21_facility_none/`. Headlines, from `key_numbers.csv`:
>
> - Every run completes: 40 of 40 runs, 1380 of 1380 evaluation runs, 500 of 500 draws in both
>   density cases (on 2026-10-20: `v1_mc_learn`, 5 evaluation origins and 23 mark-up draws stopped).
> - The facility never acts in the point forecasts of applications 1-6 and variants 2 and 4, so they
>   are unchanged. App 1: average inflation 2022Q3-2026Q2 3.45% with learning and 2.59% under RE with
>   t-1 information; learners' end-of-quarter share 0.467 at the end of 2021Q2 and 0.591 at the end
>   of 2022Q2; AR(1) coefficient 1.061 at the origin (explosive PLM, kept: the facility checks only the
>   model).
> - App 5: with mark-up shocks the facility acts in 23 of the 500 learning draws (46 reverts, 13 kept
>   shares); with every draw in, the average 90% inflation band is 14.59 pp with learning against
>   4.76 pp under RE (10.85 pp on 2026-10-20 without the 23 stopped draws). Demand shocks unchanged
>   (1.16 vs 1.18 pp). The price mark-up impulse run completes (beliefs reverted in 2022Q3, 2023Q2-Q4).
> - Variant 1 (model-consistent RE agents) now has a forecast: the facility reverts the beliefs at the
>   end of 2022Q2 (beta 1.033, the 2022Q1 value, against 1.061 in `a1_learn`) and in 2023Q1-Q3;
>   average inflation 8.14% (a boom to 14.02% in 2024Q1, then a bust to -3.72% in 2026Q2).
> - Variant 3: `v3_all` (now = `v3_all_alm`) 14.50% average inflation (33.48% without a facility),
>   `plm_alm` 2.72%; the facility acts in 9 of its 16 forecast quarters.
> - Evaluation: no stops; the relative RMSEs change only for model-consistent RE (inflation, h = 1 / 4
>   / 8: 0.747 / 1.161 / 1.564, was 0.734 / 0.918 / 1.153 on fewer origins), all agents learn
>   (0.720 / 1.210 / 1.681, was 0.626 / 0.862 / 1.147) and all 12 variables (0.812 / 1.323 / 1.620);
>   baseline learning is unchanged at 0.753 / 1.000 / 1.030.
>
> The 2026-10-20 note below is kept as written (facility `'none'`); where it reports stops or the
> 33.48%, the 2026-10-21 note above replaces it.

> **2026-10-20: new baseline.** The project baseline changed on 2026-10-20 (user decision,
> `config/master_options.m`): the published Smets-Wouters (2007) parameters (1966Q1-2004Q4 mode,
> `models/sw07/sw07_params_original.m`), t-1 information for both RE agents and learners, filtered RE
> values in the history, the KOZ endogenous gain from 0.05, chi 2, memory 0.8 and no projection
> facility; application 4 runs with period-t RE information (Ramsey policy is not supported with t-1
> RE information). Every SW07 run, the evaluation and `build_summary_v3.m` were rerun:
> `key_numbers.csv`, `checks_v3.txt` (15 of 15 pass) and the report describe the new baseline. The
> sections from "App 1" to "Before and after" below were written for the previous swX1 baseline and
> are kept as they were, marked [previous baseline]; this memo and every file of that baseline are in
> `archive/2026-10-20_swX1_baseline/results/summary_v3/`. The Notes section is current (the report's
> caveats read it). Headlines of the new baseline, from `key_numbers.csv`:
>
> - App 1: average inflation 2022Q3-2026Q2 is 3.45% with learning and 2.59% under RE with t-1
>   information (+0.86 pp; the gap peaks at +3.54 pp in 2023Q1 and turns negative in 2024Q4). The
>   learners' end-of-quarter share is 0.527 at the end of 2019Q4, 0.467 at the end of 2021Q2 and
>   0.591 at the end of 2022Q2; their AR(1) coefficient is 1.061 at the origin, so their PLM is
>   explosive there.
> - App 2: the learning replay of the RE-smoothed shocks misses the data by 1.62 pp RMS on inflation
>   (average 4.64% against 3.21% in the data).
> - App 3: 100 bp looser policy raises inflation by up to 0.72 pp under learning (2024Q1, RE 0.67 pp
>   in 2023Q3); the largest asymmetry is 0.014 pp.
> - App 4 (period-t RE information): the model-consistent RE Ramsey plan has a loss of 127.7 against
>   230.1 for the rule (balanced weights, 80 quarters).
> - App 5: average 90% inflation band 10.85 pp with learning against 4.76 pp under RE with mark-up
>   shocks, 1.16 against 1.18 pp with demand shocks; 23 of the 500 learning mark-up draws stop with
>   no model solution.
> - App 6: the learners' share at the end of 2022Q2 is 0.811 in the inversion and 0.591 on the RE
>   history.
> - Variant 1 (model-consistent RE agents): the forecast stops in 2022Q3 with no model solution.
> - Variant 2: average inflation 2.56-3.69% across the six PLMs; every PLM has a largest root of 1 or
>   more at the origin.
> - Variant 3: learning on all 12 variables gives 33.48% average inflation (explosive in 12 of the 16
>   forecast quarters); 2.72% with `plm_alm`, 14.50% with `alm`.
> - Variant 4: a constant gain of 0.05 gives 3.50% against 3.45% with the KOZ gain, which stays
>   within 0.0471-0.0521 over 1966Q1-2026Q2.
> - Evaluation: 5 of 1380 runs stop (model-consistent RE 3 origins, every agent a learner 2); baseline
>   learning has a relative RMSE for inflation of 0.753 / 1.000 / 1.030 at h = 1 / 4 / 8.

Track H1, 2026-10-18. SW07 (swX1 mode), RE agents anchored (`re_variant = 'anchored'`), learning on
inflation only, switching with chi = 0.51, gain 0.0585, memory 0.6, BR information `'lagged'`,
projection facility `'plm_alm'`; forecasts from the 2022Q2 inflation peak (asserted with
`hetlearn.find_peak`), 16 quarters (2022Q3-2026Q2), zero future shocks unless stated. Scenario files:
`scenarios/sw07/<folder>/`; runner: `run_applications.m`; tables: `results/summary_v3/` (built by
`build_summary_v3.m`). Inflation, rates and growth are annualised percent; "pp" = percentage points.
Updated 2026-10-19 (KOZ errors in quarterly units, saved RE Ramsey benchmarks, review fixes) and
rebuilt the same day with the covid quarters ignored: **every SW07 observable is missing (NaN) in
2020Q1-2020Q3** (user decision 2026-10-19; `covid_nan_quarters` in `models/sw07/data/build_database.m`).
The RE filter treats those quarters as missing; the swX1 parameters and every other setting are
unchanged. All numbers below are from the rebuild; the before/after table at the end compares the
headline numbers with the covid quarters in the data. All 50 SW07 scenarios ran (40 runs, 10
evaluation variants), status ok; 15 of 15 checks in `checks_v3.txt` pass. Every SW07 number below is
in `key_numbers.csv` (the pre-rebuild file is `pre_covid_nan/key_numbers.csv`). Two share measures
appear: `n2_model` is the learners' share in force in the model in a quarter, `n2` the
discrete-choice share computed at the end of a quarter (in force in the next one).

| Result | RE | Learning |
|---|---|---|
| Average inflation 2022Q3-2026Q2 (app 1) | 3.24% | 3.61% |
| Largest learning-minus-RE inflation gap | | +1.45 pp (2022Q4) |
| Learners' share in force (`n2_model`), 2022Q3 / 2026Q2 | 0 | 0.494 / 0.499 |
| Replay of the RE-smoothed shocks, gap to the data, inflation (app 2) | 3e-13 (max) | 0.73 pp (RMS) |
| Policy 100 bp looser / tighter, peak inflation effect (app 3) | +1.01 / -1.01 pp | +0.96 / -0.92 pp |
| 90% inflation band, average width, mark-up / demand shocks (app 5) | 4.67 / 3.01 pp | 4.55 / 2.63 pp |
| Learners' share at the end of 2022Q2 (`n2`), RE-smoothed history / inversion (app 6) | | 0.494 / 0.506 |
| Inflation RMSE relative to RE, full sample, h = 1 / 4 / 8 (evaluation) | 1 | 1.000 / 1.005 / 1.007 |

## App 1. Forecast from the 2022Q2 peak: does learning raise the inflation path? [previous baseline]

Yes: by 0.37 pp on average over the 16 quarters, front-loaded, with the gap positive through 2025Q1.

- Average inflation 2022Q3-2026Q2: 3.61% with learning, 3.24% under RE (data at the origin: 8.94%).
- Quarter by quarter: 8.40% vs 6.97% in 2022Q3, 5.37% vs 4.57% in 2023Q2, 2.96% vs 2.76% in 2024Q2.
  The gap peaks at +1.45 pp in 2022Q4, is +0.20 pp in 2024Q2, turns negative in 2025Q2 and ends at
  -0.17 pp (2026Q2: 1.54% vs 1.71%).
- The policy rate follows inflation up: 4.32% vs 4.00% on average. Output growth is lower:
  -0.07% vs +0.28%.
- The learners' share in force (`n2_model`) is 0.494 in 2022Q3 (the `n2` computed at the end of
  2022Q2) and stays near it: 0.491 in 2023Q2, 0.495 in 2024Q2, 0.499 in 2026Q2 (range 0.490-0.503).
  Over the history 1966Q1-2022Q2 the end-of-quarter share `n2` averaged 0.494 (range 0.362-0.534).
- The share during the surge: `n2` is 0.500 at the end of 2019Q4 and stays at 0.500 through 2020Q4
  (no data in 2020Q1-Q3, and the smoothed path gives both forecasts small errors), dips to 0.445 at the
  end of 2021Q2, then rises: 0.440 (2021Q3), 0.470 (2021Q4), 0.483 (2022Q1), 0.494 (2022Q2). With the
  covid quarters in the data it fell from 0.589 (2020Q3) to 0.409 (2022Q1). So the share now falls
  only in 2021H1 and recovers while inflation rises; the learners' near-unit-root AR(1) tracks the
  persistent surge about as well as the RE forecast.
- Beliefs at the origin: alpha 0.063, beta 0.988, so the learners' perceived mean inflation is 23.6%
  (steady state 3.13%; with beta this close to 1 the implied mean is a poor guide). It falls to 2.02% by
  2026Q2.
- Facility: the candidate inflation beliefs have a root above 1 in 2022Q1 and 2022Q2 (1.051, 1.041),
  so the facility keeps them: the beliefs in force at the origin are those of the end of 2021Q4. No
  events in the forecast. With the covid quarters in the data there were none.

## App 2. Replay of the RE-smoothed shocks: how far is the learning replay from the data? [previous baseline]

- Under RE the replay reproduces the data (max abs error 3e-13, check C1).
- With learning, the same shocks give, over 2022Q3-2026Q2: inflation RMS gap 0.73 pp, largest +2.20 pp
  in 2022Q3; policy rate 0.38 pp (largest +0.74 pp, 2022Q4); output growth 0.50 pp (largest -1.04 pp,
  2022Q3); consumption growth 0.45 pp (largest -0.89 pp, 2022Q4).
- Average inflation 3.39% in the learning replay vs 3.21% in the data (+0.18 pp). The gap is
  front-loaded: 83% of the squared inflation gap falls in 2022Q3-2023Q2 (+2.20, +1.30, +0.49,
  +0.53 pp); after that it stays within about +-0.75 pp.
- The learners' share in force (`n2_model`) is 0.494 in 2022Q3 and 0.502 in 2026Q2; in between it
  goes down to 0.437 and up to 0.508.

## App 3. Policy 100 bp a year looser or tighter in 2022Q3-2023Q2: is the response asymmetric? [previous baseline]

- Under RE the responses are exactly symmetric (largest |loose + tight| over 7 series 5e-14) and
  linear: the original SW07 model hit by the backed-out em shocks reproduces both runs to 3e-13
  (check C3). Looser policy raises inflation by up to 1.01 pp (2023Q2; +0.62 pp on average), lowers
  the rate by up to 1.78 pp (2023Q2, including the rule's response) and raises output growth by up to
  1.95 pp. These RE effects are unchanged by the covid treatment (the response does not depend on the
  state).
- Under learning the response is asymmetric, but only slightly: inflation +0.956 pp (loose) vs
  -0.919 pp (tight) at the peak, 2023Q3; the largest asymmetry is +0.045 pp (2023Q4), about 5% of the
  effect. Average effects +0.607 vs -0.597 pp. Rate: -1.896 vs +1.899 pp at 2023Q2 (asymmetry
  +0.025 pp, 2024Q2); output growth +2.03 vs -2.07 pp (asymmetry -0.038 pp, 2023Q4).
- The asymmetry comes from the learning states, which respond nonlinearly to the paths: for example,
  looser policy raises the learners' share in force (`n2_model`) by up to 0.008 and tighter policy
  lowers it by up to 0.010 (both 2023Q3).
- Learning delays and slightly damps the inflation effect (peak 0.96 pp in 2023Q3 vs 1.01 pp in
  2023Q2 under RE) and enlarges the rate effect (1.90 vs 1.78 pp). The delay has the timing reason
  given in app 5: the learners' expectation reacts to the policy deviation only a quarter later.

## App 4. Taylor rule vs Ramsey policy: losses by weight set [previous baseline]

Discounted losses (pinf 4*pinf, ygap y - yf, r 4*r, dr 4*(r - r{-1}); discount 0.99756), 80 quarters
(16 in brackets). The RE Ramsey benchmark is `a4_ramsey_<w>_re_mc`: the `a4_ramsey_<w>_re` files with
`re_variant = 'model_consistent'`, run and saved like every other scenario (they reproduce the earlier
in-script diagnostic exactly, check C12).

| Weights | RE rule | RE Ramsey (anchored block) | RE Ramsey, model-consistent (`_re_mc`) | Learning rule | Learning Ramsey |
|---|---|---|---|---|---|
| balanced (1, 0.5, 0.1, 0) | 736.1 (242.0) | 40.4 (31.2) | 610.9 (226.8) | 924.3 (400.9) | 85.4 (70.5) |
| hawk (1, 0.1, 0.1, 0) | 207.4 (85.4) | 29.3 (21.9) | 176.8 (92.9) | 275.6 (144.2) | 66.5 (55.9) |
| dove (1, 1, 0.1, 0) | 1397.1 (437.7) | 45.2 (35.5) | 1023.5 (350.6) | 1735.3 (721.7) | 92.5 (76.6) |
| smooth (1, 0.5, 0.1, 0.5) | 738.5 (244.4) | 55.8 (46.3) | 617.2 (232.8) | 927.8 (404.3) | 109.5 (94.1) |

- Rule losses are the same under anchored and model-consistent RE (check C11: inflation paths to
  2e-13, loss to 5e-13). With model-consistent RE agents, Ramsey beats the rule over 80 quarters for
  every weight set (balanced 611 vs 736) and loses over 16 quarters with hawk weights (92.9 vs 85.4).
  With the covid quarters in the data these were 631 vs 764 and 98.0 vs 89.5 (the Track A2 and round-2
  numbers); the covid treatment changes the 2022Q2 state, not the ranking.
- The RE Ramsey plans run inflation higher than the rule over 2022Q3-2026Q2 (average 5.39% balanced,
  3.84% hawk, 6.54% dove, 5.37% smooth, vs 3.24%), with a higher rate (6.06%, 5.30%, 7.05%, 5.68% vs
  4.00%); output growth is higher except with hawk weights (0.70%, 0.20%, 0.97%, 0.69% vs 0.28%). The
  80-quarter target paths of every app-4 run are in `app4_targets_long.csv`.
- Caveat, and an open design question: anchored RE agents forecast with the RE solution under the
  Taylor rule, not under the Ramsey policy (IJCB's anchored agents use the RE solution of the active
  policy). This affects the RE Ramsey runs too, not only learning: in mode `'rational'` the pinf block
  is still the anchored forecast, so `a4_ramsey_*_re` are not RE Ramsey plans. Inflation
  expectations stay on the Taylor-rule forecast function while the planner moves the rate, and the
  loss drops by a factor of 15 (balanced, 40.4 vs 610.9). The Ramsey paths differ a lot from the rule
  paths (balanced, RE: average inflation 4.14% vs 3.24%, rate 6.21% vs 4.00%, output growth 1.90% vs
  0.28%).
- Under learning, Ramsey has the lower loss for every weight set, but the anchored RE agents (a share
  1 - `n2_model` = 0.506 in 2022Q3) carry the same exploitable forecast, so these losses and their
  ratios are not read as the gain from optimal policy.

## App 5. Density forecasts: how does learning change the inflation bands? [previous baseline]

500 normal draws, calibrated sigma, seed 0; 500 used, none explosive; learning on the general path
(0.47-0.59 s per draw), RE on the fast path (equal to the general path to 1.8e-12 on a 10-draw check,
C5). The RE bands do not change with the covid treatment (they do not depend on the state).

- Mark-up shock uncertainty (epinf, ew): learning narrows the average 90% inflation band a little,
  4.55 vs 4.67 pp (ratio 0.98); it is wider at h = 4 (5.13 vs 4.61) and h = 16 (5.02 vs 4.95), narrower
  at h = 8 (4.55 vs 4.67). The output-growth band widens: 5.37 vs 4.88 pp (ratio 1.10).
- Demand shock uncertainty (eb, eg, eqs): learning narrows the inflation band by 13%, 2.63 vs 3.01 pp
  (h = 4: 2.29 vs 2.69; h = 8: 2.85 vs 3.32; h = 16: 3.31 vs 3.54), and the rate band
  (3.91 vs 4.17 pp). The output-growth band is about the same (13.65 vs 13.38 pp).
- The learners' share in force (`n2_model`) moves with the draws: its 90% band averages 0.047 wide
  under mark-up shocks and 0.013 under demand shocks. The median inflation path (3.63% and 3.62% on
  average) stays close to the point forecast (3.61%).
- Why the bands narrow (one unit of each shock in 2022Q3, `app5_mechanism.csv`): in the quarter a shock
  hits, the learners' expectation does not move, because they forecast from data up to t-1, so the
  aggregate inflation expectation moves about half as much as under RE (epinf 1.62 vs 3.53 pp, ew 0.51
  vs 1.09, eqs 0.60 vs 1.27) and inflation responds less on impact (epinf 5.16 vs 6.79 pp, ew 0.56 vs
  1.06, eb 0.19 vs 0.37, eg 0.12 vs 0.24, eqs 0.53 vs 1.10). From h = 2-3 on the learning response is
  the larger one; summed over 16 quarters the absolute responses are close (learning / RE 0.99-1.18),
  and `n2_model` moves by at most 0.046. A band at horizon h adds up the squared responses to all
  earlier draws, so the smaller impact responses narrow it. The result depends on
  `beliefs.info = 'lagged'` (the user's spec); the same one-quarter delay explains the later inflation
  peak in app 3 (2023Q3 vs 2023Q2).

## App 6. History backed out with the learning model [previous baseline]

- Covid quarters in the inversion: with no observable in 2020Q1-Q3 there is nothing to exogenise, so
  the engine simulates those quarters with every backed-out shock at exactly 0 (the RE smoother instead
  spreads the information: eb -0.67 to -0.84, ew +0.30 to +0.41, ea +0.19 to +0.41 there). In 2020Q4,
  the first quarter with data, the inversion must close the whole gap at once: ea +6.01 (9.3 sd above
  the smoothed value), eg -2.30 (-3.1 sd), epinf +0.42 (+3.7 sd). From 2020 on the inversion no longer
  equals the RE smoother, so `test_inversion` S1 now compares shocks only up to 2019Q4, the last
  quarter before the gap (they agree to 2.8e-13).
- Which shocks change, inversion minus RE-smoothed shocks in standard deviations: epinf RMS 0.61 over
  1966Q1-2026Q2 and 1.26 over 2021Q1-2023Q4 (largest +3.68, 2020Q4); ea 0.61 (0.24; +9.33, 2020Q4);
  eb 0.26 (0.53; +1.96, 2020Q3); eg 0.21 (0.03; -3.13, 2020Q4); ew 0.20 (0.35; -1.05, 2022Q3); eqs
  0.15 (0.32; -0.90, 2020Q4); em 0.08 (0.21; -0.70, 2020Q1). Most of the change is the covid
  catch-up of 2020Q1-Q4; mark-up shocks still differ most in 2021-2023.
- The inversion fits the 7 observables to 3.6e-15 where they exist (C9). The end-of-quarter share
  `n2` is 0.506 at the end of 2022Q2 (RE-smoothed history: 0.494), 0.511 vs 0.504 at the end of
  2026Q2, and averages 0.495 vs 0.493 over 1966Q1-2026Q2.
- Decompositions, average contribution in pp (deviation from the steady state):

| Window, variable | Case | demand | monetary | supply | price mark-up | wage mark-up | intercept channel | total |
|---|---|---|---|---|---|---|---|---|
| 2021Q1-2023Q4, inflation | RE smoother | -0.71 | +2.13 | -0.56 | +1.66 | -0.65 | 0 | +1.86 |
| 2021Q1-2023Q4, inflation | learning inversion | -0.18 | +1.69 | -2.01 | +2.95 | -0.75 | +0.17 | +1.86 |
| 2021Q1-2023Q4, output growth | RE smoother | +3.02 | +0.66 | +0.08 | -2.54 | -0.21 | 0 | +1.02 |
| 2021Q1-2023Q4, output growth | learning inversion | +3.54 | +0.33 | +2.18 | -4.57 | +0.22 | -0.68 | +1.02 |
| 2008Q1-2019Q4, inflation | RE smoother | -1.43 | +1.02 | -0.60 | +0.02 | -0.61 | 0 | -1.61 |
| 2008Q1-2019Q4, inflation | learning inversion | -1.07 | +0.75 | -0.46 | +0.04 | -0.51 | -0.35 | -1.61 |

  (init is between -0.02 and 0 in these windows.) In the 2021-2023 surge the learning decomposition now
  gives more to price mark-ups (2.95 vs 1.66) and offsets it with supply (-2.01 vs -0.56), less to
  monetary shocks (1.69 vs 2.13), and 0.17 pp to the intercept channel (the learners' moving perceived
  mean). For output growth it gives more to demand (3.54 vs 3.02) and supply (2.18 vs 0.08), much more
  negative mark-ups (-4.57 vs -2.54), and -0.68 pp to the intercept channel. The large supply and
  mark-up swings carry the 2020Q4 catch-up shocks of the inversion (ea +9.3 sd), which persist
  (crhoa 0.96); read the 2021-2023 split of the inversion with that in mind. 2008-2019 hardly changes.
  Slope beliefs and shares act inside every shock component.
- The decomposition of `a6_smooth_learn` equals the RE one over 1966Q1-2026Q2 (1e-14, C6b): without
  the inversion the history is the RE-smoothed one and is decomposed with the RE model. All three
  decompositions rebuild their paths (C6: 1.7e-13 to 1.1e-12).

## Variant 1. Anchored vs model-consistent RE agents [previous baseline]

- With model-consistent RE agents learning raises average inflation by 2.62 pp over RE instead of
  0.37 pp: 5.87% vs 3.61% (anchored) and 3.24% (RE); policy rate 6.30% vs 4.32%; output growth
  -2.46% vs -0.07%.
- The average hides a boom and bust: inflation is 10.82% in 2022Q3, 12.57% in 2023Q2, 6.96% in 2024Q2,
  0.85% in 2025Q2 and -2.01% in 2026Q2. The learners' perceived mean inflation is 23.6% at the end of
  2022Q3 (its high, the origin's beliefs held) and -3.0% in 2026Q2. The facility holds the beliefs in
  2022Q1-2022Q2 (history, as in a1_learn) and in 2022Q3, 2022Q4 and 2023Q1 (candidate roots 1.017 to
  1.110).
- Mechanism: model-consistent RE agents forecast the heterogeneous economy as if the learners' current
  beliefs were permanent, so they first amplify the learners' high perceived mean and then its fall.
- Same end-of-2022Q2 share `n2` (0.494: the history is the same RE-smoothed history), but a different
  path of `n2_model`: 0.525 in 2022Q4, 0.489 in 2024Q1, down to 0.436 in 2025Q2, 0.473 in 2026Q2.
- In the evaluation it is still the weakest inflation variant (relative RMSE 1.148 / 1.396 / 1.174 at
  h = 1 / 4 / 8, p 0.33-0.36) and worse on output growth at h = 1 (1.082, p 0.055).

## Variant 2. Perceived laws of motion (learning on inflation; the other VAR members are auxiliary) [previous baseline]

| PLM | Avg inflation | `n2`, end of 2022Q2 | Largest root 2022Q2 | Perceived mean 2022Q2 | Coefficients at 2022Q2 | Facility events (history / forecast) |
|---|---|---|---|---|---|---|
| AR(1) (a1_learn) | 3.61% | 0.494 | 0.988 | 23.6% | alpha 0.063, beta 0.988 | 2 / 0 |
| AR(2) | 3.47% | 0.487 | 0.928 | 5.38% | alpha 0.040, lags 0.928, 0.000 | 4 / 0 |
| AR(1), no constant | 3.59% | 0.484 | 0.932 | 3.13% (fixed at the steady state) | beta 0.932 | 3 / 0 |
| pinf on pinf{-1}, ygap{-1}, r{-1} | 3.47% | 0.492 | 0.991 | 38.2% | alpha 0.045, pinf 0.991, ygap -0.029, r -0.017 | 18 / 6 |
| VAR(1) pinf, ygap, r | 3.63% | 0.486 | 0.995 | 4.26% | pinf equation: alpha 0.097, pinf 1.015, ygap -0.030, r 0.018 | 14 / 13 |
| VAR(1), 12 variables | 3.16% | 0.314 | 0.997 | 2.60% | pinf equation: alpha -0.002, own lag 0.441, largest others labf 2.46, lab -1.87, c 0.90, cf -0.70 | 51 / 7 |

- The PLM changes the learners' share at the origin (`n2` 0.314-0.494) and the perceived mean
  (2.6-38.2%; near a unit root the implied mean is a poor guide) far more than average inflation
  (3.2-3.6%). Every PLM except the AR(2) is close to a unit root at the origin (0.93-1.00).
- The AR(2) beliefs in force at the origin are still those of 2021Q3: three of its four history
  facility events are the three quarters before the origin (2021Q4, 2022Q1, 2022Q2, candidate roots
  1.014, 1.065, 1.049; the fourth is 1974Q3). The AR(1) baseline now has the same problem for two
  quarters (2022Q1-Q2, beliefs of 2021Q4).
- The VAR(1) in {pinf, ygap, r} leans on the facility: its beliefs are kept in 13 of the 16 forecast
  quarters (candidate roots 1.0006-1.015); no model shares are kept now (5 quarters before). Its
  `n2_model` stays between 0.476 and 0.501. Read its path with that in mind.

## Variant 3. Learning on all 12 variables, and the projection facility options [previous baseline]

- Inflation only: 3.61% average inflation. All 12 variables: 4.40% (`'plm_alm'`), 4.53% (`'alm'`),
  4.53% (`'none'`).
- `'plm_alm'` keeps a block's previous beliefs when its root would exceed 1: 131 times in the history
  (226 quarters x 12 AR(1) blocks) and 15 in the forecast. `'alm'` lets PLMs go explosive and reverts
  every belief only when the model has no stable solution: it never had to (0 events, one before), so
  `'alm'` and `'none'` give the same run. `'none'` restricts nothing: `v3_all_none` did not stop (no
  `noSolution`): with anchored RE and every forward-looking variable learning the model has no leads,
  so it is simulated as it is, and no quarter was explosive. Under both the inflation PLM is explosive
  at the origin (root 1.072), while the model stays stable.
- End-of-2022Q2 shares (`n2`), mean over the 12 variables: 0.245 / 0.223 / 0.223 (largest 0.494 in
  all three, inflation).
- The facility moves average inflation by about 0.1 pp here. The `'plm_alm'` run depends on 146
  PLM-block events.

## Variant 4. Endogenous gain (KOZ 2024, errors in quarterly units) [previous baseline]

- The errors enter in model units, percent per quarter (`gain.koz.error_scale = 1`, user decision
  2026-10-19; the first version used 4, annualised, and mu effectively scales with the square of the
  factor). With scale 1 the gain stays close to the constant 0.0585, as expected: on the RE-smoothed
  history it averages 0.0596 over 1966Q1-2026Q2, from 0.0576 (1972Q3) to 0.0627 (1981Q2); 0.0591 in
  2020Q2, 0.0599 in 2021Q4, 0.0606 in 2022Q2, 0.0587 in 2023Q4, 0.0585 in 2026Q2. No bound binds.
  (With the covid quarters in the data its high was 0.0652 in 2022Q3.)
- At the peak: gain 0.0606 at the origin, 0.0599 on average over the forecast, 0.0597 in 2026Q2.
  Beliefs at the origin: alpha 0.064, beta 0.989 (constant gain: 0.063, 0.988), perceived mean 25.6%
  (23.6%).
- The forecast is the constant-gain one: average inflation 3.612% in both, policy rate 4.32% in both,
  output growth -0.07% in both; `n2` at the end of 2022Q2 0.495 vs 0.494, `n2_model` 0.499 in 2026Q2
  in both. Three PLM-block events in the history (1974Q3, 2022Q1, 2022Q2; two with the constant gain).

## Evaluation. Real-time forecasts, 1990Q1-2024Q2, H = 8 [previous baseline]

1380 runs (10 variants x 138 origins), no failures; benchmark RE; DM with the uniform kernel and the HLN
correction. With the covid quarters missing, every target dated 2020Q1-Q3 drops out: 1,680 of 77,280
errors (3 targets x 8 horizons x 7 observables x 10 variants), so 75,600 remain. RE RMSE, full
sample, h = 1 / 4 / 8: inflation 0.89 / 1.33 / 1.55 pp, output growth 2.28 / 2.37 / 2.46 pp (with the
covid targets: 1.02 / 1.40 / 1.62 and 4.58 / 4.48 / 4.54). The 1990-2007 and 2008-2019 samples are
unchanged (their origins and targets have the same data); 2020-2026 has 16 targets at h = 1 and 23 at
h = 8.

| Variant | Inflation, full | Inflation 1990-2007 | Inflation 2008-2019 | Inflation 2020-2026 | Output growth, full |
|---|---|---|---|---|---|
| Learning (inflation) | 1.000 / 1.005 / 1.007 | 0.986 / 0.934 / 0.973 | 0.964 / 0.979 / 1.024 | 1.046 / 1.039 / 1.015 | 1.009 / 1.011 / 1.000 |
| Model-consistent RE | 1.148 / 1.396 / 1.174 | 1.085 / 0.981 / 0.898 | 0.986 / 0.966 / 1.058 | 1.335 / 1.648 / 1.296 | 1.082 / 1.263 / 1.143 |
| All agents learn | 1.076 / 1.235 / 1.329 | 1.055 / 0.967 / 0.912 | 0.986 / 0.960 / 1.035 | 1.179 / 1.409 / 1.530 | 1.069 / 1.226 / 1.303 |
| AR(2) | 0.993 / 0.992 / 1.006 | 0.986 / 0.913 / 0.972 | 0.963 / 0.978 / 1.028 | 1.029 / 1.023 / 1.013 | 1.011 / 1.004 / 0.997 |
| AR(1), no constant | 1.012 / 0.992 / 0.990 | 1.000 / 0.954 / 0.987 | 1.052 / 1.070 / 1.089 | 0.974 / 0.970 / 0.958 | 0.997 / 1.017 / 1.016 |
| Regression | 1.029 / 0.991 / 0.988 | 1.005 / 0.927 / 0.973 | 0.992 / 0.948 / 1.017 | 1.083 / 1.028 / 0.984 | 1.020 / 1.029 / 1.002 |
| VAR(1), 3 variables | 1.033 / 0.993 / 1.002 | 0.993 / 0.915 / 0.962 | 0.974 / 0.937 / 1.011 | 1.118 / 1.041 / 1.014 | 1.013 / 1.029 / 1.020 |
| VAR(1), 12 variables | 1.070 / 1.032 / 0.999 | 1.081 / 1.043 / 1.007 | 1.108 / 1.077 / 0.994 | 1.020 / 1.009 / 0.997 | 0.991 / 0.996 / 1.004 |
| All 12 variables | 1.005 / 1.014 / 1.020 | 0.991 / 0.892 / 0.901 | 0.966 / 0.966 / 1.072 | 1.055 / 1.071 / 1.047 | 0.942 / 0.981 / 0.947 |

(relative RMSE at h = 1 / 4 / 8; below 1 = better than RE; samples by target date)

- Inflation: no variant beats RE in the full sample (best: AR(1) without constant, the regression PLM
  and AR(2) at 0.988-0.992 for h = 4-8; AR(1) without constant p 0.62-0.76; baseline learning
  1.000 / 1.005 / 1.007, p 0.72-1.00). The
  VAR(1) in 12 variables is worse at h = 1-3 (1.070 at h = 1, p 0.07). In 1990-2007 most learning
  variants are below 1 at h = 4-8 (all 12 variables 0.892 / 0.901, VAR(1) 3 variables 0.915 / 0.962),
  none at p < 0.05. AR(1) without constant is worse in 2008-2019 at h = 8 (1.089, p 0.01); VAR(1) in 12
  variables is worse in 2008-2019 at h = 1 (1.108, p 0.04).
- Output growth: all 12 variables now beats RE (0.942 at h = 1, p 0.04; 0.947 at h = 8, p 0.11; 7 of
  32 cells at p < 0.10). Model-consistent RE and all agents learn are worse (1.08 / 1.07 at h = 1,
  p 0.055 / 0.059; 1.14-1.30 at h = 8); baseline learning is at 1.00-1.01.
- DM p < 0.10 counts over h = 1-8 x 4 samples (32 cells per variable): inflation, baseline learning 1
  better / 1 worse, AR(1) without constant 3 / 4, VAR(1) 12 variables 2 / 6, VAR(1) 3 variables 0 / 2,
  every other variant at most 1 / 1; output growth, all 12 variables 7 / 1, AR(1) without constant
  1 / 8, all agents learn 0 / 4, model-consistent 0 / 3, every other variant at most 1 / 1.
- In 2020-2026 (16 targets at h = 1, 23 at h = 8) the learning variants are mostly worse than RE on
  inflation (model-consistent 1.30-1.65, all agents learn 1.18-1.53); AR(1) without constant is below
  1 at every horizon shown (0.958-0.974; p 0.05 at h = 8) but worse on output growth there (p < 0.10
  at h = 2-8). With so few targets these p-values are fragile.

## Application 1 on two other models [removed from the report 2026-10-21]

2026-10-21: removed from the report and the pipeline (user decision); the packages, scenario files, runs
and `other_models_*` files are kept, unused. The text below is the record of 2026-10-18.

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
| Average inflation 2022Q3-2026Q2, RE / learning | 3.24% / 3.61% | 2.45% / 3.03% | 3.57% / 3.67% |
| Learning minus RE, average / largest | +0.37 / +1.45 pp (2022Q4) | +0.58 / +1.92 pp (2022Q3) | +0.10 / +0.74 pp (2022Q3) |
| Learning minus RE in 2026Q2 | -0.17 pp | +0.30 pp | +0.03 pp |
| Learners' share, `n2` at the end of 2022Q2 / `n2_model` in 2026Q2 | 0.494 / 0.499 | 0.495 / 0.500 | 0.386 / 0.500 |
| Inflation PLM at the origin: beta / perceived mean (steady state) | 0.988 / 23.6% (3.13%) | 0.714 / 4.40% (2.32%) | 0.701 / 4.26% (3.30%) |
| Inflation in 2022Q2, data / RE forecast for 2022Q3 | 8.94% / 6.97% | 9.30% / 3.81% | 9.30% / 5.78% |
| Facility events, history / forecast | 2 / 0 | 2 / 0 | 2 / 0 |

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

## Before and after ignoring the covid quarters (SW07, 2026-10-19) [previous baseline]

"Before" = every observable in the data (the results of the morning of 2026-10-19, kept in
`results/summary_v3/pre_covid_nan/` and `results/eval_sw07_v3_preCovidNaN/`); "after" = 2020Q1-Q3 NaN.

| Result | Before | After |
|---|---|---|
| App 1: average inflation 2022Q3-2026Q2, RE / learning | 3.24% / 3.64% | 3.24% / 3.61% |
| App 1: largest learning-minus-RE gap | +1.02 pp (2022Q4) | +1.45 pp (2022Q4) |
| App 1: inflation beliefs at the origin, beta / perceived mean | 0.927 / 7.75% | 0.988 / 23.6% (2021Q4 beliefs, facility) |
| `n2` at the end of 2019Q4 / 2020Q3 / 2021Q2 / 2021Q3 / 2021Q4 / 2022Q1 / 2022Q2 | 0.500 / 0.589 / 0.452 / 0.418 / 0.413 / 0.409 / 0.416 | 0.500 / 0.500 / 0.445 / 0.440 / 0.470 / 0.483 / 0.494 |
| `n2_model` 2022Q3 / 2023Q2 / 2023Q4 | 0.416 / 0.474 / 0.487 | 0.494 / 0.491 / 0.491 |
| App 2: learning replay, RMS inflation gap / average inflation (data 3.21%) | 0.62 pp / 3.45% | 0.73 pp / 3.39% |
| App 3: learning, peak loose / tight effect / largest asymmetry (inflation) | +0.91 / -0.89 / +0.025 pp | +0.96 / -0.92 / +0.045 pp |
| App 4: balanced, 80 quarters: RE rule / RE Ramsey (`_re_mc`) / learning rule / learning Ramsey | 763.7 / 631.3 / 977.4 / 80.2 | 736.1 / 610.9 / 924.3 / 85.4 |
| App 5: 90% inflation band, learning / RE, mark-up / demand shocks | 4.50 / 4.67, 2.62 / 3.01 | 4.55 / 4.67, 2.63 / 3.01 |
| App 6: 2021-2023 inflation, learning inversion: price mark-up / supply / monetary | +1.24 / -0.67 / +1.80 | +2.95 / -2.01 / +1.69 |
| App 6: 2021-2023 inflation, RE smoother: price mark-up / monetary | +1.52 / +2.18 | +1.66 / +2.13 |
| App 6: `n2` at the end of 2022Q2, inversion | 0.395 | 0.506 |
| V1: average inflation, model-consistent RE | 6.63% | 5.87% |
| V2: average inflation over the five PLMs | 3.21-4.16% | 3.16-3.63% |
| V3: all 12 variables, `plm_alm` / `alm` / `none` | 4.63 / 4.71 / 4.51% | 4.40 / 4.53 / 4.53% |
| V4: KOZ gain, history range / at the origin; average inflation | 0.0576-0.0652 / 0.0641; 3.638% | 0.0576-0.0627 / 0.0606; 3.612% |
| Evaluation: RE RMSE, inflation, h = 1 / 4 / 8 | 1.02 / 1.40 / 1.62 | 0.89 / 1.33 / 1.55 |
| Evaluation: RE RMSE, output growth, h = 1 / 4 / 8 | 4.58 / 4.48 / 4.54 | 2.28 / 2.37 / 2.46 |
| Evaluation: baseline learning, relative RMSE, inflation | 0.992 / 1.005 / 1.004 | 1.000 / 1.005 / 1.007 |
| Evaluation: all 12 variables, relative RMSE, output growth | 0.972 / 0.997 / 0.987 | 0.942 / 0.981 / 0.947 |

The learners' share no longer falls through the surge: before, the large covid swings in the smoothed
data first raised `n2` to 0.589 (2020Q3) and the surge then pulled it down to 0.409 (2022Q1); now it
dips to 0.445 in 2021H1 and recovers to 0.494 by 2022Q2. The forecast paths change less than the
shares and beliefs: average inflation moves by at most 0.03 pp under baseline learning.

## Notes

- Baseline (2026-10-20, `config/master_options.m`): published SW07 parameters, t-1 information for
  RE agents and learners, filtered RE values in the history, KOZ gain from 0.05, chi 2, memory 0.8,
  projection facility `'alm'` (user decision 2026-10-21; `'none'` on 2026-10-20). Two scenario
  files differ: application 4 sets `expectations.re_info = 'current'` (Ramsey policy is not
  supported with t-1 RE information; the only deviation), and
  `a6_inv_learn` sets `history.re_states = 'smoothed'`, the only value the option check accepts with
  the inversion, which is one-sided already. Under t-1 RE information the RE benchmark is the RE
  model with E_{t-1} pinf_{t+1}, not `models/sw07/sw07.model` (checks C2 and C3b use the hand-written
  RE(t-1) model).
- Parameters: the published mode was estimated on 1966Q1-2004Q4 and is applied here to data to
  2026Q2. Its hours constant `constelab` (-0.103) belongs to the authors' hours series; `labobs` is
  demeaned over 1947Q2-2026Q2 in this database (the swX1 estimate on it is -3.00), so the RE filter
  puts part of that level difference into the hours states. The filter still fits every observable.
- Covid quarters (user decision 2026-10-19): every SW07 observable is NaN in 2020Q1-2020Q3, so the
  RE filter treats them as missing. The learners learn on the filtered values there (the filter's
  prediction); the evaluation drops those targets (1,680 errors; since the facility became `'alm'`
  every origin runs); the inversion backs out zero shocks in those quarters and catches up in 2020Q4.
- Share drift to 0.5 with zero shocks: with no new errors both fitness measures decay towards zero,
  so the discrete-choice shares tend to 0.5 by construction (no cost term for RE). The shares near 0.5
  at the end of the zero-shock forecasts are this mechanism, not a finding.
- The peak forecasts start from the full-sample smoothed state. (The report computes this caveat
  from the look-ahead key numbers.)
- chi = 2 and memory 0.8 are the user's choice of 2026-10-20. The previous baseline used IJCB's
  estimates, 0.51 and 0.6; with chi = 2 the shares respond about four times as strongly to the same
  gap in squared errors, so shares are not comparable with the archived results.
- Projection facility `'alm'` (since 2026-10-21): only the model is checked, never the PLM. The
  learners' AR(1) coefficient in `a1_learn` is 1.061 at the 2022Q2 origin (above 1 in 1974Q3, 2022Q1
  and 2022Q2), so the learning runs built on it start from an explosive PLM, and every PLM of variant
  2 has a largest root of 1 or more there; the facility keeps such beliefs while the model solves,
  which it does in every point forecast of applications 1-6 and variants 2 and 4 (no facility events,
  so those runs are the ones of 2026-10-20). It reverts the beliefs, or keeps last quarter's shares,
  where the model has no stable solution: `v1_mc_learn` (end of 2022Q2, so its forecast starts from
  the 2022Q1 beliefs, and 2023Q1-Q3), 23 of the 500 learning mark-up density draws (46 reverts, 13
  kept shares), the application 5 impulse run with one unit of the price mark-up shock (2022Q3,
  2023Q2-Q4), learning on all 12 variables (`v3_all` = `v3_all_alm`: 4 reverts and 17 kept shares,
  9 of the 16 forecast quarters) and 151 of the 1380 evaluation runs (11 origins of `e03_learn_mc`, 2
  of `e04_learn_all_learners`, all 138 of `e10_allvars`). Every run completes. On 2026-10-20, without
  a facility, `v1_mc_learn` (2022Q3), 5 evaluation origins, 23 mark-up draws and the impulse run
  (2022Q4) stopped with no model solution, and `v3_all` was explosive in 12 of the 16 forecast quarters
  (33.48% average inflation; 14.50% now). The paths of the runs with facility events depend on the
  beliefs the facility holds.
- App 4: the Ramsey losses with anchored RE agents (RE and learning) rest on the open design question
  above; only the model-consistent runs `a4_ramsey_<w>_re_mc` are RE Ramsey plans. All of application
  4 uses period-t RE information.

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
`pre_covid_nan/`: the same files as built before the covid treatment (2026-10-19 morning) and the old
run log; the old evaluation is in `results/eval_sw07_v3_preCovidNaN/`.
