# as07: An and Schorfheide (2007) small New Keynesian model

The small-scale NK model of An and Schorfheide (2007, Econometric Reviews) in the version that
Herbst and Schorfheide (2016, "Bayesian Estimation of DSGE Models", Princeton UP, Ch. 4.1-4.2)
estimate on US data for 1983Q1-2002Q4: an Euler equation, a Phillips curve and a Taylor rule
with smoothing, technology-growth and government-spending shocks, a policy shock, and three
observables (per capita output growth, CPI inflation, federal funds rate) with measurement
errors. Equations and measurement come from the book's replication code; the parameters are
the published posterior means. Nothing is estimated or sampled in this package (user decision
2026-10-18). This is the third model of the `hetlearn` portfolio (template `models/ijcb3/`) and
a model for application 1: the forecast from the 2022Q2 inflation peak, RE against learning on
inflation with anchored RE agents (`scenarios/as07/app1_peak/`).

## Files

| file | what |
|---|---|
| `model_spec.m` | package contract: filter range 1965Q1-2026Q2, observables `dy`, `pinfobs`, `robs`, report labels/units/scale (4 annualises `dy`; `pinfobs` and `robs` are already annualised); no `spec.policy` yet |
| `as07.model` | IRIS model file, linear; leads as `x{+1}`; every equation labelled |
| `as07_params.m` | published posterior means (Herbst-Schorfheide Ch. 4 slides); 5-95% intervals and priors in comments; measurement errors from `sysmat.m` |
| `estimation/hs2016/` | the book's replication files, unchanged, as provenance for the equations, the measurement and the data: `DSGE-Estimation.zip` (folder "DSGE Estimation": `Mfiles/`, `LRE/`, `Matfiles/`, `Optimization Routines/`, `us.txt`, `ReadMe.txt`, `Candidate.m`, `MetropolisHastings.m`, figures) and, in `book_data/`, `README`, `dsge1_data.csv`, `dsge1_great_rec_data.csv` from `book-data.zip`. Source: https://web.sas.upenn.edu/schorf/companion-web-site-bayesian-estimation-of-dsge-models/. The package does not use `Matfiles/` |
| `data/` | `build_database.m` -> `as07_database.csv/.mat`, `us_txt_match.csv`; FRED raw file in `raw/`; `README.md` |
| `validation/` | `check_model.m` (IRIS and the book's code, no hetlearn engine) -> `RESULTS.txt`, `irfs.csv`, `smoothed_history.csv` |

The book's code is not on the MATLAB path (`setup_paths` does not add `models/`).
`check_model.m` adds `hs2016/Mfiles` and `hs2016/LRE` and removes them on exit, so the book's
`gensys`, `prior`, `kalman` and `moment` shadow nothing else.

## Model

Transition variables are deviations from the steady state: y output over the technology level
(%), π inflation and R the policy rate (% per quarter), g the government spending shock (%), z
the technology growth shock (% per quarter). β = 1/(1 + r_A/400).

```
Euler equation  y_t  = E_t y_{t+1} - (1/tau)(R_t - E_t pi_{t+1} - rho_z z_t) + (1 - rho_g) g_t
Phillips curve  pi_t = beta E_t pi_{t+1} + kappa (y_t - g_t)
Policy rule     R_t  = rho_R R_{t-1} + (1 - rho_R)(psi1 pi_t + psi2 (y_t - g_t)) + eps_R,t
Shocks          g_t = rho_g g_{t-1} + eps_g,t;   z_t = rho_z z_{t-1} + eps_z,t;   eps_R,t i.i.d.
Measurement     dy_t      = gamma_Q + y_t - y_{t-1} + z_t + me_dy,t             (% q/q)
                pinfobs_t = pi_A + 4 pi_t + me_pinfobs,t                        (% a year)
                robs_t    = pi_A + r_A + 4 gamma_Q + 4 R_t + me_robs,t          (% a year)
```

These are rows eq_1 to eq_6 of `Mfiles/model_solution.m` and the A, B and H matrices of
`Mfiles/sysmat.m`, term by term. The code writes E_t z_{t+1} = rho_z z_t and
E_t g_{t+1} = rho_g g_t into the Euler equation, so y{+1} and pinf{+1} are its only leads; the
model file keeps that form.

| model file | book code | meaning |
|---|---|---|
| `y`, `pinf`, `r`, `g`, `z` | `y_t`, `pi_t`, `R_t`, `g_t`, `z_t` | transition variables (`y1_t` is `y{-1}`; `Ey_t1`, `Epi_t1` are the leads) |
| `eps_z`, `eps_g`, `eps_r` | `z_sh`, `g_sh`, `R_sh` | transition shocks, std `std_eps_*` = sigma_z, sigma_g, sigma_R |
| `me_dy`, `me_pinfobs`, `me_robs` | diagonal of `H` | measurement errors |
| `dy`, `pinfobs`, `robs` | YGR, INFL, INT (us.txt columns ygr, infl, int) | observables |
| `tau`, `kappa`, `psi1`, `psi2`, `rA`, `piA`, `gammaQ`, `rho_r`, `rho_g`, `rho_z` | `para(1:10)`, `rho_R` is `rho_r` | parameters; `$beta$` is a substitution |

Forward-looking variables: `y` and `pinf`. Policy-rule label, for a later
`spec.policy.rule_label`: `Monetary policy rule, Taylor rule with smoothing (AS07)`. The g shock
moves y and potential output one for one: it leaves the gap y - g, inflation and the rate
unchanged. The model has no cost-push shock; inflation moves through z and the policy shock.

## Parameters

Source: the table "Posterior Estimates of DSGE Model Parameters" in Herbst and Schorfheide's
Chapter 4 slides on the companion website,
https://web.sas.upenn.edu/schorf/files/2017/05/chapter4_sl_0-1sxxi8g.pdf. The table reports
posterior means with [5th, 95th] percentiles, and no medians; its note says that 100,000 draws
were generated and the first 50,000 discarded. These are the values the authors report, and the
package uses them as published, at the table's two decimals. The table's symbols map one to one
to the parameter order of the replication code's `prior.m` (τ, κ, ψ1, ψ2, r^(A), π^(A), γ^(Q),
ρ_R, ρ_g, ρ_z, σ_R, σ_g, σ_z). Package units equal the book's units (next section), so each
published value applies as it stands. Priors are those of `prior.m`.

| name | table | value | 5%-95% | prior | units |
|---|---|---|---|---|---|
| `tau` | τ | 2.83 | 1.95-3.82 | Gamma(2.00, 0.50) | |
| `kappa` | κ | 0.78 | 0.51-0.98 | Uniform[0, 1] | |
| `psi1` | ψ1 | 1.80 | 1.43-2.20 | Gamma(1.50, 0.25) | |
| `psi2` | ψ2 | 0.63 | 0.23-1.21 | Gamma(0.50, 0.25) | |
| `rA` | r^(A) | 0.42 | 0.04-0.95 | Gamma(0.50, 0.50) | % a year |
| `piA` | π^(A) | 3.30 | 2.78-3.80 | Gamma(7.00, 2.00) | % a year |
| `gammaQ` | γ^(Q) | 0.52 | 0.28-0.74 | Normal(0.40, 0.20) | % per quarter |
| `rho_r` | ρ_r | 0.77 | 0.71-0.82 | Uniform[0, 1) | |
| `rho_g` | ρ_g | 0.98 | 0.96-1.00 | Uniform[0, 1) | |
| `rho_z` | ρ_z | 0.88 | 0.84-0.92 | Uniform[0, 1) | |
| `std_eps_r` | σ_r | 0.22 | 0.18-0.26 | InvGamma(0.40, 4) | % per quarter |
| `std_eps_g` | σ_g | 0.71 | 0.61-0.84 | InvGamma(1.00, 4) | % |
| `std_eps_z` | σ_z | 0.31 | 0.26-0.36 | InvGamma(0.50, 4) | % per quarter |
| `$beta$` | β | 0.998951 | from r^(A) | none | |
| `std_me_dy` | (`sysmat.m`) | 0.1160 | fixed | none | % per quarter |
| `std_me_pinfobs` | (`sysmat.m`) | 0.2942 | fixed | none | % a year |
| `std_me_robs` | (`sysmat.m`) | 0.4476 | fixed | none | % a year |

Gamma and Normal priors are (mean, sd), as `prior.m` codes them (its header calls the π^(A)
prior's 2.00 a variance; the code uses it as the sd). The inverse gamma priors are An and
Schorfheide's (s, ν): p(σ) ∝ σ^-(ν+1) exp(-ν s²/(2σ²)), `prior.m`'s `lnpdfig`. β is not in the
table; it follows from r^(A) as in `model_solution.m`. The three measurement-error std devs come
from the replication code, not from the table (next sections but one).

## Units: no rescaling

The An-Schorfheide paper writes the measurement with factors 100 and 400 on decimal log
deviations. The book's code does not: `sysmat.m` has B = 1 on y and z and 4 on π and R, so its
variables are already in percent, with π and R in percent per quarter. The package therefore
uses the code's model as it stands. The scale factor is 1, every impulse response equals the
code's (validated to 5e-15), and σ_R, σ_g, σ_z apply as published. The slides' notes give the
same units for the data (output growth in q/q percent, inflation and the funds rate annualised).
These are the units of SW07 and IJCB3 (inflation in % per quarter), so the learners forecast
`pinf` in % per quarter and χ = 0.51 applies without conversion. Only the observables `pinfobs`
and `robs` are annualised, as in the book's data; `model_spec.report.scale` is 1 for them and 4
for `dy`.

## Measurement errors

The replication code's likelihood (`dsgeliki.m` through `sysmat.m`) has measurement errors with
fixed variances, (0.20 x the us.txt sample std)², std devs 0.579923, 1.470832 and 2.237937,
marked "from dsge1_me.yaml". They are not estimated. The published table lists no
measurement-error parameters and the slides do not mention them. The package keeps the code's
errors as IRIS measurement shocks with these fixed std devs (decision 2026-10-18). Setting
`std_me_dy`, `std_me_pinfobs` and `std_me_robs` to 0 in `as07_params.m` gives the model without
them; the IRIS likelihood then matches `kalman.m` with H = 0 (Validation).

## Data

1964Q1-2026Q2, FRED vintage 2026-09-29 (`data/README.md`); the filter starts in 1965Q1 and
1964 is a presample.

| observable | definition | match with us.txt, 1983Q1-2002Q4 |
|---|---|---|
| `dy` | 100 Δlog GDPC1 minus 100 Δ of the HP trend (λ = 1600) of log CNP16OV, % q/q | corr 0.982, mean diff +0.009, max 0.30 |
| `pinfobs` | 400 Δlog CPIAUCSL (quarterly average), % a year | corr 0.998, mean diff +0.003, max 0.44 |
| `robs` | FEDFUNDS (quarterly average), % a year; NaN in the 36 ELB quarters | equal to 3e-7 |

The Chapter 4 slides describe the observables as per capita output growth in q/q percent, CPI
inflation in annualised q/q percent, and the average annualised effective funds rate of each
quarter. They do not name the population series, and the replication files do not contain the
book's data appendix. The match with us.txt settles the rest. CPI inflation beats the GDP
deflator (corr 0.68) and core CPI (0.61). Per capita growth has the right mean (total GDP growth
is 0.30 pp too high), but with the raw CNP16OV the January population-control steps show up as
misses (0.98 pp in 2000Q1; corr 0.950). us.txt has no such steps; the HP-smoothed population
removes them (corr 0.982). The remaining gaps are revisions to GDP and to CPI seasonal factors
since the book's vintage. `dy_rawpop` (raw CNP16OV, the SW07 convention) is kept in the database
as a helper.

## ELB treatment

As in IJCB3: `robs` is NaN when FEDFUNDS is below 0.25% a year, 2009Q1-2015Q4 and
2020Q2-2022Q1, 36 quarters (asserted in `build_database.m`). The rule holds in those quarters
and the Kalman filter infers the rate from inflation and output growth; the smoothed
piA + rA + 4 gammaQ + 4 r is the shadow rate. RE agents expect the rule to keep holding. The
book's sample ends in 2002 and has no ELB quarters.

With the 1983-2002 steady state (funds rate 5.80% a year), the shadow rate stays well above
zero: its 2009Q1-2015Q4 mean is 3.44% (trough -1.15% in 2009Q1, 5.14% in 2011Q4) and its
2020Q2-2022Q1 mean 2.74% (trough 0.40% in 2020Q2).

## Validation

2026-10-18, at the published values; all pass. Numbers from `validation/RESULTS.txt`.

- Parameters: `as07_params` equals the published means; the measurement-error std devs equal
  0.2 x std(us.txt) to 1e-7. β = 0.998951.
- Solution: eight roots. Unstable 1.4593 and 1.1979 for the two leads (Blanchard-Kahn holds);
  stable 0.98 (ρ_g), 0.88 (ρ_z), 0.4409 and three zeros. The book's gensys at the same
  parameters has the same two unstable roots and the same nonzero roots of T1. Steady state of
  the observables: γ^(Q) = 0.52, π^(A) = 3.30, π^(A) + r^(A) + 4γ^(Q) = 5.80.
- Impulse responses: IRIS `srf` against the book's solution (`model_solution.m`, gensys:
  s_t = T1 s_{t-1} + T0 e_t; observables through `sysmat.m`'s B), all five variables and three
  observables, three shocks, 20 quarters: max abs difference 5.3e-15 with no rescaling. Impact
  responses to 1-sd shocks:

  | shock | y | pinf (% q/q) | r (% per quarter) | dy | pinfobs | robs |
  |---|---|---|---|---|---|---|
  | technology growth (0.31) | +0.201 | +0.361 | +0.178 (peak 0.242, q3) | +0.511 | +1.442 | +0.714 |
  | government spending (0.71) | +0.710 | 0 | 0 | +0.710 | 0 | 0 |
  | policy (0.22) | -0.130 | -0.182 | +0.126 | -0.130 | -0.726 | +0.504 |

- Likelihood on us.txt, 1983Q1-2002Q4, at the published values (a model-equivalence check, not
  an estimation). Both filters start from the stationary distribution (`kalman.m`: s_0 = 0,
  P_0 = the unconditional variance; IRIS `loglik` default initial condition, `relative` false).
  With measurement errors: book `dsgeliki.m` -315.91557171, IRIS -315.91557171, gap 1.1e-13.
  Without them: -304.23974054 in both, gap 1.1e-13.
- Filter and smoother, 1965Q1-2026Q2 (246 quarters, 36 missing `robs`): the measurement
  equations rebuild the observables from the smoothed states and measurement errors to 7.3e-14
  (lhsmrhs, data on the left, NaN skipped, as in `hetlearn.re_filter`); the IRIS output
  includes the smoothed measurement errors. The policy rule and the shock processes hold to
  6.4e-14. The Euler equation and the Phillips curve hold only up to expectational errors, which
  lhsmrhs cannot separate (largest 7.4, 2020Q1); they are not tested.
- Smoothed shocks, 1965Q1-2026Q2 (mean, std, model std): eps_z 0.000, 0.323, 0.31; eps_g
  -0.264, 1.341, 0.71; eps_r -0.092, 0.277, 0.22; me_dy std 0.042 (0.116), me_pinfobs 0.120
  (0.294), me_robs 0.232 (0.448). Largest: eps_g 2020Q2 (8.4 sd), eps_z 2008Q4 (7.0 sd), eps_r
  1974Q4 (5.5 sd).
- Application-1 origin: CPI inflation peaks in 2022Q2 at 9.30% a year (2.32% q/q);
  `hetlearn.find_peak` (through `load_spec` and `load_database`) gives the same quarter. Smoothed
  state there: y 5.44, g 4.42 (gap y - g 1.02), pinf 1.416 (model inflation 8.96% a year),
  r -1.015 (model rate 1.74% a year against a funds rate of 0.77%), z -0.02. Smoothed shocks:
  eps_z -0.13, eps_g -0.55, eps_r -1.19 (5.4 sd), me_dy -0.01, me_pinfobs 0.33, me_robs -0.97.
  The filter reads the 2022 surge as policy far below the rule. Only output growth is observed,
  so the levels of y and g are loosely pinned down; the gap y - g drives inflation and the rule.

## Open issues

1. Precision: the published values have two decimals, the precision of the table, and β follows
   from the rounded r^(A).
2. Measurement errors: the published means come with the replication code's fixed measurement
   errors, which the table does not mention (Measurement errors). SW07 and IJCB3 have none.
   `hetlearn.extend_model` parses `!measurement_shocks`, and the IRIS filter output carries the
   smoothed errors, and the engine has now run the package (track M3, application 1: 11/11
   checks in `results/summary_v3/other_models_checks.txt`). Std 0 for the three errors removes them.
3. Steady state of the 1983-2002 sample: inflation 3.30% and a funds rate of 5.80% a year,
   output growth 2.08% a year. The RE forecast from 2022Q2 reverts to these levels.
4. Population. `dy` uses an HP trend of log CNP16OV, inferred from the match with us.txt. The
   two-sided trend spreads the January steps over nearby quarters instead of removing them: in
   2025Q1 `dy` is -0.43 against -1.41 with the raw series; at the 2022Q2 origin the two differ by
   0.07. The trend also moves when new data arrive.
5. Book-code quirk: `model_solution.m` never checks gensys's eu (its retcode is always 0);
   `check_model.m` counts the unstable roots itself.
6. Scenario names `a1as_re` and `a1as_learn` are unique on the path today (checked with
   `which -all`).
