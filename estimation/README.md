# Estimation module (`estimation/`)

Bayesian estimation of SW07 under rational expectations (RE) and of the a1_learn model:
anchored RE agents and AR(1) inflation learners. The learners use a constant gain,
per-variable shares and `beliefs.info = 'lagged'`, with the projection facility
`'plm_alm'`. Design: `DESIGN_estimation.txt` (session scratchpad, 2026-10-19).
Nothing in `toolbox/`, `models/`, `scenarios/` or `tests/` is changed.

## Toolbox root
`est_config.m` sets `toolbox_root`. **Since 2026-10-20 the default is the live project
(`c.project`); the frozen snapshot was retired.** The mode searches, Hessians and chains of
2026-10-19/20 ran against a snapshot of commit 95ecebd in a temporary session folder that no
longer exists. `setup_est.m` runs `<root>/setup_paths` and adds this folder. It refuses to
run if `hetlearn` comes from anywhere else. After any change to `toolbox/` or `models/sw07`,
run `est_00_gates_live` in a fresh process before resuming a chain (G4 ties the estimator to
the engine). The estimator uses only `load_spec`, `load_model`, `load_options`,
`load_database`, `re_anchor_coefficients`, `init.re_moments`, `plm.*` and, in gate G4 only,
`engine.*`. It carries its own solver, filter and learning recursion.
Live toolbox checks: 2026-10-20 02:22 (snapshot still configured) and 12:05, after the switch
(`est_00_gates_live`, with the new gate L1): G3, G4 (degenerate start), G5 at the calibration
and 5 prior draws (both timings), L0 (log likelihoods at the RE and learning modes, diff 0) and
L1 (log posteriors and log likelihoods at all four modes, re, learn, learn_current,
learn_calib, diff 0; tol 1e-8) pass. G8 also passes against the live toolbox (12:12). Lines
in `gates.txt` under "# live toolbox check" and "# est_00_g8".

## Run order (each line is one `matlab -batch` process; run from this folder)
| step | call | writes (under `results/estimation/`) |
|---|---|---|
| 0a | `est_00_g0_dynare` (session **without** IRIS) | `gates/g0_dynare.mat` (Dynare priordens, swX1 settings) |
| 0b | `est_00_gates` (or a subset, `est_00_gates({'G4'})`) | `gates.txt` (appended), `gates/gates_G*.mat` |
| 1 | `est_01_mode_re` | `re/mode.mat`, `re/pilot.mat`, `re/mode_params.csv`, G7 line in `gates.txt` |
| 2 | `est_02_mcmc_re(k)`, k = 1..4, in parallel (`est_02_mcmc_re(k, 200000)` extends); then `est_02_mcmc_re('post')` | `re/chains/chain_0k/`; `re/posterior.mat` (MHM, diagnostics), `re/posterior_summary.csv` (mode, mean, sd, 5/50/95%, R-hat, ESS) |
| 3 | `est_03_mode_learn('learn3', [], v)`, then `('full', k, v)` for k = 1..3, then `('pick', [], v)` | `<v>/mode3.mat`, `<v>/mode_full_k.mat`, `<v>/mode.mat`, `<v>/hess_steps.mat` |
| 4 | `est_04_hess_learn(p, n, v)` for p = 1..n in parallel, then `est_04_hess_learn('merge', [], v)` | `<v>/hess_part_*.mat`, `<v>/hessian.mat`, `<v>/mode_params.csv` |
| 4b | `est_03_mode_learn('robust')` (after the baseline merge) | `learn/robust.mat`: variants (c) fixed initial beliefs and (d) 'freeze' |
| 5 | pilots `est_05_mcmc_learn(100+i, 2000, scale_i)`; then `learn/pilot.mat` (field `scale`); then `est_05_mcmc_learn(k, ndraws)` for k = 1..K | `learn/pilot/chain_1xx/`, `learn/chains/chain_0k/` |
| 5b | only if `est_gonogo2` says stage 2 is needed, after the stage-1 chains are done: `est_07_mcmc_stage2('prepare')` (one process, about 8 min: proposal, pilots, pick), then `est_07_mcmc_stage2(k, ndraws)` for k = 1..6 in parallel (`launch.ps1`; a larger `ndraws` extends) | `learn/stage2_proposal.mat`, `learn/stage2_pilot/`, `learn/stage2_pilot.mat`, `learn/chains2/chain_0k/` |
| 6 | `est_06_post('interim')` while the learning chains run, `est_06_post('final')` after them (parts: `est_06_post(mode, 'parts', {'params', 'mdd'})`; options `'draws'` `'stage1'`/`'stage2'`, `'n_fx'` 600, `'n_re'` 4000, `'min_age_s'` 120, `'max_blocks'` Inf) | `tables/*.csv` (below); `app1/e1_*/` (hetlearn.run results); generates `estimation/models/sw07_est_{re,learn}/` and `estimation/scenarios/e1_*.m` |
| 6b | part `app1_post` of step 6 (default), or on its own: `est_06b_app1_post('interim')` / `('final')` (same `'draws'`, `'max_blocks'` options; `'n_post'` 200; parts `'post'`, `'sens'`); after step 6 part `app1` has written `app1/e1_*` (part `sens` reads them); about 4 min | `tables/app1_post_long.csv`, `app1_post_summary.csv`, `share_sensitivity.csv` |
| 6m | `est_06_post('modes')`: posterior modes only, **no learning chain is read** (about 1 min; runs `est_06b_app1_post('modes')` as its part `app1_post`, which reads the finished RE chains once for the RE posterior of application 1) | the same `tables/*.csv` with status `modes` (formats below), `app1/e1_*/`, the generated packages and scenarios |
| 7 | `python reports/build_estimation_report.py` (project root or any folder; about 5 s; options `--tables`, `--gates`, `--out`) | `reports/sw07_estimation_report.html` (reads only `tables/*.csv` and `gates.txt`; the status in `post_meta.csv` picks the chain-based page or the modes page) |
| 0c | `est_00_gates_live()` (fresh process; optional root argument; `est_00_gates_live([], {'L0', 'L1'})` for the mode values only, seconds) | `gates.txt` (appended, "# live toolbox check"), `gates/live_*.mat` |
| 0d | `est_00_g8` (about 1 min; after step 6 has generated the `e1_*` scenarios and packages) | `gates.txt` (appended, "# est_00_g8"), `gates/gates_G8.mat` |
| - | `est_status2` (any time, no IRIS; `est_status` without stage 2) | prints chain progress, acceptance, ETA of stage 1 and stage 2 |
| - | `est_gonogo2` (no IRIS; never opens `state.mat`) / `est_gonogo2('stage1')`, `('stage2')`; old: `est_gonogo`, `est_gonogo('re')` | `learn/gonogo2.txt` and `.mat` (R-hat, ESS, the design rule, "converged", whether stage 2 is needed); `learn/gonogo.txt` |

**MCMC paused (2026-10-20, shortly before 12:00, at the user's request: modes first, chains
later if everything else looks good).** Stage 1 (`learn/chains`) holds 71,000-72,000 of 75,000
draws per chain in complete blocks; stage 2 (`learn/chains2`, prepared 11:41-11:45) 1,000 of
40,000. Both are kept unchanged; their `progress.txt` still says `running`. The record is
`results/estimation/learn/mcmc_paused.txt` (key = value lines, shown in the report). The
report shows the modes only (`est_06_post('modes')`, then the builder). To resume, one batch
process per chain (each resumes from its `state.mat`, the end of its last complete block, with
its saved random stream; it now runs against the live toolbox, whose likelihoods match the
snapshot's to 0 at every mode; PowerShell, `$est` = this folder):
`1..6 | ForEach-Object { & powershell -NoProfile -File "$est\launch.ps1" -Cmd "est_05_mcmc_learn($_, 75000)" -Log "mcmc_learn_resume_$_.txt" }` (stage 1, about 25 min at 0.37 s per draw), and
`1..6 | ForEach-Object { & powershell -NoProfile -File "$est\launch.ps1" -Cmd "est_07_mcmc_stage2($_, 40000)" -Log "mcmc2_resume_$_.txt" }` (stage 2, about 4 h).
Then `est_status2`, `est_gonogo2`, and the final pass below. Rebuild the modes-only tables
and page at any time (no learning chain is read): `est_06_post('modes')`, then
`python reports/build_estimation_report.py`.

**Final pass** (after the 6 learning chains finish, `est_status2` shows `done`): (1)
`est_gonogo2` (about 1 min, no IRIS): the line `STAGE 2: needed` or `not needed` decides; if
needed, run step 5b and do the rest when the stage-2 chains are done, with `'draws', 'stage2'`;
(2) `est_06_post('final')` (or `est_06_post('final', 'draws', 'stage2')`; about 15-20 min with
6 x 75,000 draws: reading 450 blocks, 4,000 RE re-evaluations about 1.5 min, `n_fx` = 600
learning re-evaluations about 5 min, application 1 through the engine about 1 min, then part
`app1_post` = `est_06b_app1_post` about 4 min; it stops with an error if a chain is not `done`);
(3) `python reports/build_estimation_report.py`. `est_06b_app1_post` can also run on its own
(same options) to refresh only the application 1 tables. Each MATLAB step is one batch process, e.g.
`Start-Process -FilePath "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -ArgumentList @('-batch', "`"try, cd('<this folder>'), est_06_post('final'), catch e, disp(getReport(e)), exit(1), end`"", '-logfile', "`"<log>`"") -WindowStyle Hidden`.
`est_06_post` runs with one thread (`threads_learn`; the learning re-evaluations are faster
that way). `est_06_post('interim')` never opens `state.mat` of a learning chain
(`hlest.read_blocks` lists the block files, skips any younger than `min_age_s` and stops at the
first that does not load), so it is safe while the chains run; its part `app1_post`,
`est_gonogo2` and `est_07_mcmc_stage2` read `progress.txt` (as `est_status` does, inside
try/catch) only to see whether a chain is done.

**Runbook for the end of the stage-1 chains** (PowerShell; `$est` = this folder, `$log` =
`results\estimation\logs`; `$mat = "C:\Program Files\MATLAB\R2025a\bin\matlab.exe"`):
1. Decide: `Start-Process -FilePath $mat -ArgumentList @('-batch', "`"try, cd('$est'), est_status2, est_gonogo2, catch e, disp(getReport(e)), exit(1), end`"", '-logfile', "`"$log\gonogo2_final.txt`"") -WindowStyle Hidden -Wait`,
   then read `results\estimation\learn\gonogo2.txt`: `STAGE 2: not needed` -> step 3 with stage-1
   draws; `STAGE 2: needed` -> step 2.
2. Stage 2: `Start-Process -FilePath $mat -ArgumentList @('-batch', "`"try, cd('$est'), est_07_mcmc_stage2('prepare'), catch e, disp(getReport(e)), exit(1), end`"", '-logfile', "`"$log\mcmc2_prepare.txt`"") -WindowStyle Hidden`
   (about 8 min, so not in the foreground; done when the log shows `chosen scale`; check the pilot
   acceptance there), then
   `1..6 | ForEach-Object { & powershell -NoProfile -File "$est\launch.ps1" -Cmd "est_07_mcmc_stage2($_, 30000)" -Log "mcmc2_$_.txt" }`
   (about 3 h at 0.37 s per draw; `est_status2` monitors; extend with a larger number). When they
   are done: `est_gonogo2` again (its `STAGE2 CONVERGED` line), then step 3 with `'draws', 'stage2'`.
3. Final tables and report: `Start-Process -FilePath $mat -ArgumentList @('-batch', "`"try, cd('$est'), est_06_post('final'), catch e, disp(getReport(e)), exit(1), end`"", '-logfile', "`"$log\est_06_post_final.txt`"") -WindowStyle Hidden`
   (stage 2: `est_06_post('final', 'draws', 'stage2')`; 15-20 min in the background; done when the
   log shows `est_06_post('final') finished`), then
   `& "C:\Program Files\Python314\python.exe" reports\build_estimation_report.py` from the project root.

Variant folder `<v>`: `learn` ('lagged', baseline), `learn_current` (`beliefs.info =
'current'`) and `learn_calib` (priors centred on the calibration). Launch from PowerShell
with `Start-Process` and the whole `-batch` command quoted (the path has spaces):
`Start-Process -FilePath "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -ArgumentList @('-batch', "`"cd('<this folder>'); est_02_mcmc_re(1)`"", '-logfile', "`"<log>`"") -WindowStyle Hidden`.
Every process sets `maxNumCompThreads(2)`. Logs go to `results/estimation/logs/`.
To extend a chain, call it again with a larger `ndraws`: it resumes from `state.mat` and
its saved random stream.

## Files of the package `+hlest`
`problem` (data, models, indices), `param_table` and `prior_*` (swX1.mod priors and IJCB
learning priors, Dynare 4.6.1 parameterisation), `transform`, `theta_struct`,
`solve_orig` (IRIS RE solution, anchored coefficients), `init_state` (Lyapunov start),
`kf` and `loglik_re` (RE filter), `reduce_static` and `qz_xb` (fast ALM solver:
static-variable elimination 57 -> 36, then QZ), `qz_full` (reference port of IRIS),
`loglik_learn` (time-varying filter with the learning recursion and facility), `logpost`,
`csminwel`, `hessian_fd`, `rwmh_core`, `rwmh`, `read_chain`, `diagnostics` (split R-hat,
bulk ESS), `mdd_laplace`, `mdd_mhm`. Added 2026-10-20 03:30 for application 1 (new files):
`forecast_learn` (the likelihood's learning filter, its code line for line, on the data up to
the origin, then the same recursion without data = the engine's forecast stage with zero
shocks; checks at every theta that its history equals `loglik_learn` on the full sample, 0 in
every run so far; option `'origin_state'` starts from a given state, used by gate G8) and
`forecast_re` (RE filter to the origin, then the RE law of motion). Added 2026-10-20 for step 6 (new files only, written
while the chains ran, so no existing function was edited): `read_blocks` (completed blocks
without `state.mat`), `alm_setup` (the per-theta set-up of `loglik_learn`, for the ALM at
fixed beliefs), `loglik_learn_pe` (a copy of `loglik_learn` that also records the
prediction errors `v` and `diag(F)`; `est_06_post` checks its l_t against `loglik_learn` at
the mode, difference 0). Gate wrapper `est_00_gates_live.m` holds verbatim copies of gates G3
and G4 from `est_00_gates.m` for the same reason; merge them back when convenient. Since
2026-10-20 it also has gate L1 (log posteriors at the four modes) and an optional list of
gates to run.

## Application 1 consistent with the likelihood (`est_06b_app1_post`, primary since 2026-10-20 03:30)
The forecast starts from what the estimated model itself says about 2022Q2: `hlest.forecast_learn`
runs the likelihood's learning filter to the origin (data after it play no part; asserted at every
theta against `loglik_learn` on the full sample) and then simulates 2022Q3-2026Q2 with zero
shocks exactly as the engine's forecast stage (gate G8, 2e-12 from the same origin state, at the
calibration and at the learning mode); `hlest.forecast_re` does the same for RE. Modes and 200
thinned posterior draws per model; interim headline (6 x 29,000 learning draws, 04:12): average
inflation learning 3.60% at the mode (median 3.18%, 90% 2.47-3.98%), RE 4.98% (median 3.80%,
3.04-5.23%); calibrated 3.61% and 3.24%; learners' share at the origin 0.21 (median 0.23,
0.09-0.39).

## Estimated model packages and the engine-based application 1 (`est_06_post`, part `app1`; now a sensitivity)
- `models/sw07_est_re/`, `models/sw07_est_learn/`: copies of `models/sw07` (model file,
  database) whose `model_spec.m` names `sw07_est_<x>_params`, which returns the RE or the
  learning posterior mode (36 SW07 parameters; the fixed five as swX1). Their `generated/`
  caches are gitignored. Nothing is added to the project's `models/` or `scenarios/`.
- `scenarios/e1_re.m` (a1_re at the RE mode), `e1_learn.m` (a1_learn at the learning mode with
  the estimated gain, memory and intensity, `history.mode = 'inversion'`), and two added runs
  that split the e1 gap: `e1_learn_re.m` (the learning mode's SW07 parameters, every agent RE)
  and `e1_learn_smoothed.m` (e1_learn with `history.mode = 're_smoother'`, the method of the
  calibrated a1_learn). Results in `results/estimation/app1/<id>/`. To run one by hand:
  `setup_est; addpath('scenarios'); res = hetlearn.run(e1_learn(), 'save', false);`

## Tables (`results/estimation/tables/`, written by `est_06_post` and `est_06b_app1_post`)
Long format. Every file also has `status` (`interim` | `final` | `modes`), `learn_draws` (learning
draws read, all chains, before burn-in; 0 for `modes`) and `draws` (`stage1` | `stage2` | `none`: which learning chains;
`post_meta.csv` has the keys `learn_draws_source`, `learn_sample`, `learn_burn_share`, `burn_in`).
Burn-in: stage 1 the first half of every chain, stage 2 the first 10% (stage 1 = adaptation); RE
always the first half; R-hat and ESS on the chains truncated to the shortest. Quarters as `1966Q1`.
Interim runs of the two scripts read the same blocks only if they start together; pass
`'max_blocks', k` to both (the smallest number of completed blocks) so the report shows one draw
count.
| file | columns | content |
|---|---|---|
| `params.csv` | name, group, label, source, stat, value, text | 39 parameters x sources `published_sw07` (mode), `swx1` (mode, sd_hessian), `re` and `learn` (mode, sd_hessian, mean, sd, q05, q50, q95), `learn_current`, `learn_calib` (mode, sd_hessian), `prior` (mean, sd, lb, ub; text = shape), `prior_calib`, `ijcb_survey` and `ijcb_nosurvey` (mean, lo, hi; learning rows), `calibration` (value), `compare` (diff_mean_in_re_sd, flag_mean_2sd, diff_mode_in_re_sd, flag_mode_2sd, mover_rank) |
| `mdd.csv` | model, method, p, value, note | `laplace`, `mhm` (p = 0.1..0.9), `log_posterior/likelihood/prior_at_mode` for re, learn, learn_current, learn_calib; `laplace_baseline_hessian` (approximation) for learn_fixed_beliefs and learn_freeze; swX1 under these conventions; log Bayes factors `laplace_logbf`, `laplace_log10bf`, `mhm_logbf`, `mhm_log10bf` (like with like) |
| `prior_post_long.csv` | param, density, x, value | prior and kernel posterior densities (`prior`, `re`, `learn`) on a 201-point grid for gain, omega, chi and the 4 movers (largest |mode difference| in RE posterior sds) |
| `lpd_long.csv` | date, series, value | `llt_re_mode`, `llt_learn_mode`, `llt_diff_mode`, `cum_diff_mode`, `cum_diff_q05/q50/q95` (learning path draws paired with re-evaluated RE draws), `llt_re_post_mean`, `llt_learn_post_mean`; 1966Q1-2026Q2 |
| `rmse.csv` | model, variable, sample, rmse, n, units | one-step-ahead prediction-error RMSE at the modes (report units: x 4 except hours), samples 1966Q1-2026Q2, 1966Q1-1983Q4, 1984Q1-2007Q4, 2008Q1-2019Q4, 2020Q4-2026Q2 |
| `paths_long.csv` | date, variable, source, stat, value | n2, n2_model, alpha, beta, pmean (4 (alpha/(1-beta) + constepinf)), fRE, fBR (4 (f + constepinf), forecasts made in t), pinf_filtered: `mode`/value and `post`/q05, q50, q95; `calibrated` (a1_learn history of `results/summary_v3/learning_long.csv`); `data` pinfobs (annualised) |
| `irfs_long.csv` | model, shock, variable, h, value, units | one-sd em and epinf, h = 0..20, pinfobs, dy, robs in pp annualised: `re`, `learn_all_re`, `learn_2019Q4`, `learn_2022Q2` (ALM at the beliefs and model shares in force, held fixed); shock `setting` rows: n2_model, alpha, beta, sd_em, sd_epinf |
| `app1_long.csv` | scenario, source, variable, date, stage, value | e1_re, e1_learn, e1_learn_re, e1_learn_smoothed (`estimated`), a1_re, a1_learn (`calibrated`, from `results/summary_v3`), data: pinfobs, robs, dy, dc (% annualised), n2, n2_model, fRE, fBR, 2018Q1-2026Q2; `events_<stage>_<type>` rows (value = count, date = the dates) |
| `diagnostics.csv` | model, chain, parameter, metric, value, text | draws and acceptance by chain; rhat, ess_bulk by parameter; rhat_max, ess_min, counts, burn_share; facility shares (`share_draws_plm/alm/alm_shares`, `mean_events_*`); events, starts and Hessian checks at the modes; `gonogo` rows when `learn/gonogo.txt` exists, `gonogo_override` rows from `learn/gonogo_override.txt` (key = value lines: the main session's decision on a go/no-go result), `gonogo2` rows from `learn/gonogo2.txt` |
| `app1_post_long.csv` (est_06b) | variable, date, model, statistic, value | application 1 consistent with the likelihood, 2018Q1-2026Q2: model `data` (statistic `value`), `re`, `learn` (`mode`, `median`, `p05`, `p95` over 200 thinned posterior draws); the 7 observables in report units, `n2`, `n2_model`, `alpha`, `beta`, `pmean`, `fRE`, `fBR` (learning), `fRE` (RE); `avg_<obs>` (date `2022Q3-2026Q2`, the average per draw) and `n2_origin` (date `2022Q2`) |
| `app1_post_summary.csv` (est_06b) | one row per model | average inflation 2022Q3-2026Q2 (mode, median, p05, p95), learners' share at the origin (same), n_draws, n_failed, max_history_check (largest difference of the forecast's history from the likelihood filter, 0), draws_label |
| `share_sensitivity.csv` (est_06b) | one row per history | learners' share at the end of 2019Q4, 2020Q4, 2021Q2, 2021Q4, 2022Q2 at the learning mode under the likelihood filter, the engine's inversion and RE-smoothed histories (`app1/e1_learn*`), `'freeze'` and the filter with the 2020Q1-Q3 data put back (raw panel `models/sw07/data/sw_ext_1966_latest.csv`; the database is not changed); RE agents' and learners' forecasts made in 2020Q4, beta and perceived mean at 2022Q2, the forecast's average inflation, log likelihood (filter, freeze), `why` (one line) |
| `post_meta.csv` | key, value | status, time, draws per chain, path draws, movers, checks (`rmse_check_llt_pe_vs_learn`, `paths_check_n2_stored_vs_recomputed`), application 1 averages, runtime; keys of earlier part-runs are kept (a `modes` run keeps only earlier `modes` keys) |

**Modes-only tables** (`est_06_post('modes')`, status `modes`, learn_draws 0, draws `none`; same
files and columns, only what the modes give; every number of the modes page comes from them):
- `params.csv`: `re`, `learn`, `learn_current`, `learn_calib` with `mode` and `sd_hessian` only;
  `compare` rows `diff_mode_in_re_sd_hessian`, `flag_mode_2sd_hessian` (|learning mode - RE mode|
  > 2 RE Hessian sds) and `mover_rank` (movers ranked in RE Hessian sds); `prior`
  `sd_local_learn_mode` (1/sqrt(-d2 log p/dx2) of the marginal prior at the learning mode);
  `re_posterior` (mean, sd, q05, q50, q95 of the converged RE chains, copied from
  `re/posterior_summary.csv`; the page quotes the crhopinf mean once).
- `mdd.csv`: modes rows and `laplace` only (no MHM); `laplace_logbf`/`laplace_log10bf`; the
  variants (c) `learn_fixed_beliefs` and (d) `learn_freeze` as likelihoods at the baseline mode
  (`log_likelihood_at_baseline_mode`, `log_posterior_at_baseline_mode`,
  `log_likelihood_minus_baseline`), not as marginal likelihoods.
- `prior_post_long.csv`: densities `prior`, `re_laplace`, `learn_laplace` (the normal
  N(mode, Hessian sd^2), not truncated; grid mode +- 4 sd of both models, cut at the bounds).
- `lpd_long.csv`: `llt_re_mode`, `llt_learn_mode`, `llt_diff_mode`, `cum_diff_mode` (no band).
- `paths_long.csv`: `mode`, `data` and `calibrated`, the last with `fRE` and `fBR` from
  `results/a1_learn/learning.csv` (checked against summary_v3: n2 to 5e-11; annualised with
  the swX1 constepinf 0.783575, which the perceived mean of summary_v3 implies).
- `app1_post_long.csv` / `app1_post_summary.csv`: learning model statistic `mode` only (median
  and band columns NaN, n_draws 0); RE model `mode` plus `median`, `p05`, `p95` over 200 thinned
  draws of the finished RE chains (option `'re_post'`, default true; the same draws as in
  'interim'/'final': median 3.80%, 90% 3.04-5.23% for average inflation 2022Q3-2026Q2, quoted once on
  the page). `rmse.csv`, `irfs_long.csv`, `app1_long.csv`,
  `share_sensitivity.csv`: as always (they are at the modes in every mode).
- `diagnostics.csv`: per model (re, learn, learn_current, learn_calib) `mode_starts`,
  `mode_starts_reached` (within 0.01 of the best log posterior), `hessian_pd`,
  `mode_events_*`; the variants' events at the baseline mode; per chain
  `<re|stage1|stage2>_draws_in_blocks` (number of block files x 1,000) and `_ndraws` (target),
  read from `progress.txt` and the folder listing only; rows `mcmc_paused` from
  `learn/mcmc_paused.txt`. No acceptance, R-hat, ESS or go/no-go rows.

## Output formats (for post-processing)
- `*/mode.mat`: `xm` (mode, order of `names`), `lp`, `ll`, `lpr` (log posterior, likelihood,
  prior), `laplace`. RE also has `H`, `Sigma`, and `x_swx1`, `lp_swx1`, `ll_swx1` (swX1
  under the new conventions). The learning files also hold `out` (filtered paths at the
  mode: `n1`, `n1m`, `phi`, `fRE`, `fBR`, `llt`, `events` [quarter index; 1 plm, 2 alm
  revert, 3 kept shares], `sig`) and `starts` (every full search).
- `*/hessian.mat`: `H` (of minus the log posterior, original space), `Sigma`, `info`.
- Chains, `*/chains/chain_k/`: `state.mat` (`st`: current state, proposal `Sigma`, `scale`,
  `L`, random-stream state, `names`, `nblocks`, `meta`). Then `block_00001.mat` and so on,
  one per 1,000 draws: `draws` (1000 x d), `lp`, `ll`, `acc`, `ev` (facility event counts
  of the current state), `first`, `last`, `pidx`, `paths` (learning: every 50th draw,
  struct with single rows `n2`, `n1m`, `alpha`, `beta`, `llt` over the 246 quarters
  1965Q1-2026Q2). Read with `hlest.read_chain(dir, withPaths)`. Burn-in (50%) is applied
  in post-processing, not in the files.
- Quarter index t = 1 is 1965Q1. The likelihood sums t = 5..246 (1966Q1-2026Q2) for
  both models. Learning starts at t = 5.
- Stage 2 (`est_07_mcmc_stage2`): `learn/stage2_proposal.mat` (`Sigma` = 0.9 `Sigma_emp` + 0.1
  diag, `Sigma_emp` of the pooled stage-1 draws after dropping the first 25% of each chain,
  `chains`, `n_read`, `n_used`, `xlast`/`lplast` = the last state of each stage-1 chain, `created`);
  `learn/stage2_pilot/pilot_<scale>.mat` (n, acc, s_per_draw, draws); `learn/stage2_pilot.mat`
  (`scale` for 27.5% acceptance, `scales`, `acc`); `learn/chains2/chain_0k/` in the chain format
  above (`meta.stage` = 2, `meta.start_chain`, `meta.proposal_created`).

## Settings used in the first run (2026-10-20)
- Threads: RE processes `maxNumCompThreads(2)`, learning processes 1 (`threads_learn`).
  Under full machine load, 2 threads cost 1.6-1.8 s per learning evaluation from MKL thread
  contention in the small QZ calls; 1 thread costs 0.46-0.52 s.
- Proposal: the inverse Hessian at each mode. A widened variant (`'wide'`, persistence sds
  scaled up to the RE posterior's) was piloted and dropped: lower acceptance (8-20%) and a
  lower expected squared jump distance than the plain proposal.
- Scales: RE 0.327 (acceptance 27.6-28.3%); learning 0.21 (pilots `learn/pilot/chain_111-113`
  at 0.16/0.22/0.30: 45/25/20%).
- Learning mode searches: start 1 sat on a facility "cliff" (the event pattern changes within
  the gradient step) and is retried from small perturbations. All three starts reach the same
  mode.

## Conventions
- Likelihood: stochastic initialisation (mean and Lyapunov MSE of the RE model) at 1964Q4,
  presample 1965Q1-Q4 with the RE ALM, current database with the covid quarters
  2020Q1-Q3 NaN. In quarters without data the learners use the filtered (predicted) values
  (`'gap', 'filter'`).
- Hard bounds as swX1 (`param_table`); gain [0.001, 0.25], memory [0, 0.999], chi [0, 50].
  The prior is not renormalised for the truncation (as in Dynare).
- No ELB in either model.
- History method matters at the estimated intensity of choice (chi 6.67 at the mode): the
  estimation filter and the engine's inversion history (`e1_learn`) agree on the learners'
  share to 0.007 up to 2020Q4, then split (RE agents' forecast made in 2020Q4: 3.28% in the
  filter, 0.94% in the inversion; share at 2022Q2 0.21 against 0.46; five histories at the mode
  give 0.18-0.46, `share_sensitivity.csv`). The likelihood uses the filter, and since
  2026-10-20 03:30 so does application 1 (`hlest.forecast_learn` / `forecast_re`, step 6b,
  gate G8); the engine runs `e1_*` (inversion or RE-smoothed history) are kept as a sensitivity.
- The RE mode has `crhopinf` 0.990 (posterior mean 0.945), so the forecast at the RE mode has a
  near unit-root price mark-up (average inflation 2022Q3-2026Q2 4.98% from the filter, 4.97% in
  `e1_re`, against 3.24% for the calibrated a1_re; posterior median 3.80% on the interim draws).
- Go/no-go: the design's 2-hour check (`est_gonogo`, 03:05, 19,000 draws per chain) said NO-GO;
  the main session overrode it and the chains run to 75,000 draws (`learn/gonogo_override.txt`,
  shown in the report). The fallback (`'cond'`) was not run. Stage 2 (`est_07_mcmc_stage2`) is the
  plan if `est_gonogo2` says the stage-1 chains have not converged.
- Stage 2 (test 2026-10-20 03:17-03:38 on the interim draws, folder deleted): with the covariance
  of the stage-1 draws, 2.38/sqrt(39) = 0.381 gives 9% acceptance; 0.21 gives 27-31%. Against
  stage 1 the mean squared jump per draw is 7x (crhow), 5x (cmaw), 1.6x (gain), about 1x
  (crhopinf, cmap) and 0.65x (chi); details in the help of `est_07_mcmc_stage2.m`.
