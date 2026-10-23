# ijcb3: three-equation New Keynesian model of Özden (2025, IJCB)

The skeleton model of Özden (2025), "Heterogeneous Expectations and the Business Cycle",
IJCB 21(1), sec. 2.1, eqs. (1)-(2): a hybrid IS curve, a hybrid Phillips curve and a Taylor
rule with smoothing, three shocks and three US observables (output gap, CPI inflation, federal
funds rate). Parameters are the posterior means of IJCB's heterogeneous-expectations (HE)
model. IJCB's ELB regime switching and its inflation-expectations observables are left out.
This is the second model of the HetLearn portfolio, built on the `models/sw07/` template, and
the model of application 1: a forecast from the 2022Q2 inflation peak, RE against learning
(`scenarios/ijcb3/app1_peak/`).

## Files

| file | what |
|---|---|
| `model_spec.m` | package contract: filter range 1960Q1-2026Q2, observables `yobs`, `pinfobs`, `robs`, report labels/units/scale (4 annualises inflation and the rate); no `spec.policy` yet |
| `ijcb3.model` | IRIS model file, linear; leads as `x{+1}`; every equation labelled |
| `ijcb3_params.m` | HE posterior means from IJCB Table 1; 90% bands and the HE learning parameters in comments |
| `data/` | `build_database.m` -> `ijcb3_database.csv/.mat`; FRED raw file in `raw/`; `README.md` |
| `validation/` | `check_model.m` (IRIS only) -> `RESULTS.txt`, `irfs.csv` (model units), `smoothed_history.csv` |

## Model

Transition variables are deviations from trend: y output gap (%), π inflation and r policy rate
(% per quarter). The toolbox replaces E_t x_{t+1} by the RE/learning mix where a scenario asks
for it.

```
IS curve        y_t  = (1 - iota_y) E_t y_{t+1} + iota_y y_{t-1} - (1/tau)(r_t - E_t pi_{t+1}) + u_y,t
Phillips curve  pi_t = beta [(1 - iota_p) E_t pi_{t+1} + iota_p pi_{t-1}] + kappa y_t + u_pi,t
Policy rule     r_t  = rho_r r_{t-1} + (1 - rho_r)(phi_pi pi_t + phi_y y_t) + phi_dy (y_t - y_{t-1}) + eps_r,t
Shocks          u_y,t = rho_y u_y,t-1 + eps_y,t;   u_pi,t = rho_pi u_pi,t-1 + eps_pi,t;   eps_r,t i.i.d.
Measurement     yobs_t = y_t;   pinfobs_t = pi_bar + pi_t;   robs_t = r_bar_T + r_t
```

Names in the model file: variables `y`, `pinf`, `r`, `u_y`, `u_pinf`; shocks `eps_y`, `eps_pinf`,
`eps_r`; forward-looking variables `y` and `pinf`. Policy-rule label, for a later
`spec.policy.rule_label`: `Monetary policy rule, Taylor rule with smoothing (IJCB eq. 1)`.
IJCB's eq. (21) puts the model variable on the left (π_t = π̄ + π^obs_t); read literally, the
data would have mean -π̄, so the package uses the usual direction.

## Parameters

IJCB Table 1 gives LB / mean / UB for four models: RE, RE with switching in monetary policy,
HE, and adaptive learning (AL). Every value here is an HE mean.

| name | IJCB | value | 90% HPD | note |
|---|---|---|---|---|
| `beta` | β | 0.99 | fixed | not estimated (no prior in Table C.1); value from footnote 18 |
| `tau` | τ | 1.13 | 1.03-1.30 | |
| `kappa` | κ | 0.0032 | 0.0017-0.0052 | |
| `iota_y` | ι_y | 0.06 | 0.03-0.12 | |
| `iota_p` | ι_p | 0.15 | 0.09-0.20 | |
| `phi_pi` | φ_π | 1.53 | 1.24-1.79 | |
| `phi_y` | φ_y | 0.42 | 0.34-0.51 | |
| `phi_dy` | φ_Δy | 0.12 | 0.09-0.14 | |
| `rho_r` | ρ_r | 0.92 | 0.90-0.94 | |
| `rho_y` | ρ_y | 0.95 | 0.93-0.96 | |
| `rho_pi` | ρ_π | 0.04 | 0.01-0.08 | |
| `pi_bar` | π̄ | 0.58 | 0.55-0.60 | % per quarter |
| `r_bar_T` | r̄_T | 0.26 | 0.25-0.27 | Taylor-regime trend; the ELB trend r̄_E (0.03) has no role here |
| `std_eps_y` | η_y | 0.32 | 0.28-0.36 | |
| `std_eps_pinf` | η_π | 0.38 | 0.35-0.41 | |
| `std_eps_r` | η_r,T | 0.24 | 0.22-0.27 | Taylor-regime value; η_r,E (0.01) not used |

The HE column has every parameter of the skeleton model, so nothing comes from another column;
where it gives two regime-specific values, the package takes the Taylor-regime one. Not used:
r̄_E, η_r,E, the ATSIX measurement-error std devs (0.11, 0.08) and the regime-switching
parameters Φ1 (0.10) and Φ2 (0.16).

Learning parameters (HE column; HetLearn options, set in `i1_learn.m`): gain γ = 0.0585
(0.0584-0.0587), memory ω = 0.62 (0.49-0.74), intensity of choice χ = 0.51 (0.38-0.66).

## Units: percent per quarter

IJCB's inflation and policy rate are in quarterly, not annualised, percent. The database uses
the same units (`pinfobs` = 100 Δlog CPI, `robs` = FEDFUNDS/4), so χ = 0.51 applies as
estimated.

| IJCB estimate | data in % per quarter | data in % a year |
|---|---|---|
| ELB trend r̄_E 0.03 (HE), 0.032 (AL); ELB policy-shock std η_r,E 0.01 (HE) | FEDFUNDS/4 over 2009Q1-2015Q4: mean 0.032, std 0.0095 | mean 0.13, std 0.038 |
| RE model: π̄ 0.66, r̄_T 1.02 (band 0.67-1.43) | FEDFUNDS/4 mean 1960-2019: 1.25, inside the band; π̄ = 2.6% a year | FEDFUNDS mean 5.0, far outside; π̄ = 0.66% a year |
| Cost-push std η_π 0.38 with ρ_π 0.04 | std of the change in q/q CPI inflation, 1960-2019: 0.52 | 2.1 |
| Priors (Table C.1): both trends uniform with mean 0.5; κ Beta(0.05, 0.025); policy and shock priors from SW (2007), whose rates are quarterly. β fixed at 0.99 (footnote 18) | a quarterly calibration | an inflation-trend prior centred on 0.5% a year |

Against this: App. B writes r^obs_t = R_t (FEDFUNDS as published) and π^obs_t = P_t/P_{t-1} (a
gross ratio, so App. B is shorthand, not the literal transformation). Table 2's expectation
RMSEs (1.4-2.5 for short-run expectations), the shadow-rate trough in Fig. 2 (compared with
"an annual rate of -4 percent") and the 2.5 percent line in Fig. 3 are in annual terms: the
paper annualises for presentation.

The data are in quarterly units, as IJCB's. SW07, whose data are also in percent per
quarter, now uses χ = 0.51 as well; the earlier χ = 8 (0.51 x 16) rested on the annualised
reading. `i1_learn.m` sets 0.51 explicitly, so this package does not depend on the master
options.

## Data

1957Q1-2026Q2, FRED vintage 2026-09-29 (`data/README.md`). The filter range starts in 1960Q1,
like IJCB's likelihood; 1957Q1-1959Q4 is IJCB's burn-in.

| observable | definition |
|---|---|
| `yobs` | Hamilton (2018) cycle of 100 log GDPC1, h = 8, p = 4, with the coefficients of IJCB's sample (OLS over the gap dates 1957Q1-2019Q4) applied at every date; the 2020Q1-Q3 GDP values in the regressors are interpolated (covid adjustment) |
| `pinfobs` | 100 Δlog CPIAUCSL (quarterly average), % q/q |
| `robs` | FEDFUNDS (quarterly average) / 4, % per quarter; NaN in the 36 ELB quarters |

The database also holds `ffr` (FEDFUNDS/4 in every quarter), `elb` (dummy), `yobs_hamilton`
(the plain full-sample Hamilton gap) and `yobs_fullsample` (covid-adjusted regressors with a
full-sample regression). None of them is an observable.

Output gap. The plain Hamilton gap at t+8 is the error of a
projection made at t, so the 2020Q2 lockdown trough comes back eight quarters later: the plain
gap is +9.0 in 2022Q2, the application-1 origin. `yobs` takes its coefficients from IJCB's own
sample (gap dates 1957Q1-2019Q4, no covid quarters) and applies them at every date, with the
2020Q1-Q3 GDP values in the regressors (not in the dependent variable) on a straight line
between 2019Q4 and 2020Q4. Over 1960Q1-2019Q4, `yobs` is identical to IJCB's construction on
this vintage; from 2020Q1 it extends it. It is 1.00 in 2022Q2, and the smoothed demand shock at
the origin is u_y = 0.014 instead of 0.99 with the plain gap. Coefficients and a comparison of
the three constructions: `data/README.md`.

## ELB treatment

IJCB models the ELB as a policy regime (eqs. 8-10): in ELB quarters the observed rate is r̄_E
plus a small shock, and a shadow rate follows the rule, smoothed over its own lag. This package
has no regime. `robs` is NaN when FEDFUNDS is below 0.25% a year: 2009Q1-2015Q4 and
2020Q2-2022Q1, 36 quarters (asserted in `build_database.m`). The rule still holds in those
quarters, so the Kalman filter infers r from inflation and the gap. The result is a shadow
rate smoothed over the previous quarter's shadow rate: the package's analogue of IJCB's. RE
agents expect the rule to keep holding, which is what IJCB's anchored RE agents assume
(sec. 2.3.1). What is lost: the observed rate in ELB quarters, the regime probabilities and
IJCB's expectations data.

The RE smoother gives a shadow-rate trough of -2.9% a year in 2010Q2, the trough quarter of IJCB
Fig. 2. IJCB's band there is 3.9-5.56 (read as negative: the text compares it with -4 percent).
In the covid episode the shadow rate bottoms out at -2.2% in 2020Q2 and turns positive in
2021Q4; in 2022Q1, the last ELB quarter, it is +0.5% against a funds rate of 0.12%.

## Validation

2026-10-18, all pass, re-run with the final `yobs` (IJCB-sample coefficients, covid-adjusted
regressors); numbers from `validation/RESULTS.txt`. The solution and impulse responses do not
depend on the data.

- Solution: seven roots, unstable 1.2348 and 1.0177 for two leads (Blanchard-Kahn holds),
  stable 0.95 (ρ_y), 0.8371, 0.1742, 0.0565 and 0.04 (ρ_π). Steady state of the observables:
  0, π̄, r̄_T.
- Impulse responses match an independent solve of IJCB eqs. (3)-(6) (fixed-point iteration on
  b and d) to 3.3e-15. IJCB reports no IRFs, so the signs are checked against the model's
  mechanics; every impact sign is as expected. Impact responses to 1-sd shocks, inflation and
  rate annualised:

  | shock | output gap | inflation | policy rate |
  |---|---|---|---|
  | demand (0.32) | +1.31 | +0.17 (peak 0.18, q2) | +0.83 (peak 0.91, q4) |
  | cost push (0.38) | -0.13 (trough -0.19, q2) | +1.83 | +0.14 |
  | policy (0.24) | -0.77 | -0.07 | +0.48 |

  The flat Phillips curve (κ = 0.0032) keeps inflation's response to demand and policy small.
  The policy shock moves the rate by 0.12 per quarter on impact, half its size: the rule's
  reaction to the fall in the gap, mostly through φ_Δy, offsets the rest. After a cost-push
  shock the ex-ante real rate falls on impact (-0.23 a year), because the smoothed nominal rate
  rises by less than expected inflation.
- Filter and smoother, 1960Q1-2026Q2 (266 quarters, 36 missing `robs`): the measurement
  equations rebuild the observables from the smoothed states to 4.4e-15 (lhsmrhs, data on the
  left, NaN skipped, as in `hetlearn.re_filter`); the policy rule and the shock processes hold
  to 2.7e-15.
- Smoothed shocks: means 0.03 (demand), 0.19 (cost push), 0.03 (policy); std 0.28, 0.52, 0.23
  against model values 0.32, 0.38, 0.24. Largest: demand 2020Q2 (5.2 sd), cost push 2008Q4
  (6.4 sd), policy 1980Q4 (6.0 sd).
- Application-1 origin: CPI inflation peaks in 2022Q2 at 2.32% q/q (9.3% annualised);
  `hetlearn.find_peak` gives the same quarter. Smoothed state there: y 1.00, pinf 1.74
  (7.0 annualised, as a deviation from π̄), r -0.07 (0.77% a year), u_y 0.014, u_pinf 1.19;
  smoothed shocks eps_y 0.06, eps_pinf 1.15 (3.0 sd), eps_r -0.22.

## Open issues

The output gap is the Hamilton gap with IJCB-sample coefficients and
covid-adjusted regressors (Data), and χ = 0.51 applies in IJCB's quarterly units (Units).

1. HE trends. r̄_T - π̄ = -0.32% per quarter (-1.3% a year), so the RE forecast converges to
   inflation of 2.3% and a policy rate of 1.0% a year. In IJCB's HE model the learners'
   perceived means absorb the gap; the RE filter at these values needs smoothed cost-push shocks
   with mean 0.19 (half a std dev) instead. The RE column (π̄ 0.66, r̄_T 1.02) gives +1.4% a year.
2. Missing `robs`. Learners whose PLM includes `r` (IJCB's VAR(1)) would learn from the shadow
   rate in ELB quarters. `history.mode = 'inversion'` exogenises the observables each quarter
   and has to handle the NaNs; untested.
3. Not IJCB's filter: no regime switching, no ATSIX data, no measurement errors, so the smoothed
   states differ from IJCB's (see the shadow-rate trough above).
4. Scenario names. `i1_re` and `i1_learn` are called through `feval`, so the names must stay
   unique on the path (one of each today).
