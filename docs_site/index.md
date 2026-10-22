# hetlearn

`hetlearn` is a MATLAB toolbox, built on the IRIS macroeconomic modelling toolbox, for
forecasts and policy scenarios in DSGE models where not everyone has rational expectations.
Expectations of selected forward-looking variables are a mix of two groups of agents:

- **RE agents**, who forecast with the rational-expectations solution of the model, and
- **adaptive learners (BR agents)**, who forecast from a simple perceived law of motion (PLM),
  such as an AR(1) for inflation, and update its coefficients by recursive least squares
  each quarter.

The population shares of the two groups switch each quarter according to their recent
forecast errors, following Özden (2025, *International Journal of Central Banking* 21(1)).
You bring a linear IRIS model and a database; `hetlearn` writes the heterogeneous-expectations
version of the model, learns beliefs and shares over the history, and runs your scenario
forward one quarter at a time with the beliefs and shares updating as it goes.

![Application 1: forecast from the 2022Q2 inflation peak](assets/figures/fig_app1.png){ .figure }

*Application 1, the main example of these pages: a forecast from the 2022Q2 inflation peak in
the Smets-Wouters (2007) model. With learners in the economy, average inflation over
2022Q3-2026Q2 is 3.45% against 2.59% under rational expectations, and the learners' share of
inflation expectations rises from 0.59 at the origin to 0.68 in 2023Q1.
[Step-by-step walkthrough](tutorial/application-1.md).*

## Who it is for

- Central-bank and policy economists who run DSGE forecasts and want a version of the same
  forecast in which expectations can drift away from rational expectations, without rewriting
  the model by hand.
- Researchers working on adaptive learning and heterogeneous expectations who want the
  standard machinery (RLS learning, discrete-choice switching, projection facilities,
  endogenous gains) in one place, tested against reference implementations.
- Anyone with an IRIS model file. The toolbox reads any linear IRIS model with forward-looking
  terms (`x{+1}`); no model-specific code is needed.

## What it does

| Area | What you can do | Page |
|---|---|---|
| Expectations | Choose which forward-looking variables have heterogeneous expectations; run all-RE, all-learners, fixed shares or switching shares | [Expectations](options/expectations.md) |
| RE agents | Anchored RE agents (pure-RE forecast) or model-consistent ones; information up to t or t-1 | [RE agents](options/re-agents.md) |
| Timing | What each agent sees when it forecasts; filtered or smoothed history; real-time filtering | [Timing and information](options/timing.md) |
| Learning | AR(1), AR(2), AR(1) without constant, regressions on other variables, VAR(1) PLMs; derived regressors | [Perceived laws of motion](options/plm.md) |
| Gains | Constant gain or the endogenous gain of Kostyshyna, Özden and Zhang (2024) | [Gains](options/gains.md) |
| Initial beliefs | From the RE model's moments, from OLS on a training sample, or your own values | [Initial beliefs](options/initial-beliefs.md) |
| Switching | Discrete-choice shares per variable or one share for several variables; intensity of choice and memory | [Shares and switching](options/switching.md) |
| Stability | A projection facility on the PLMs, on the actual law of motion, or none | [Projection facility](options/projection-facility.md) |
| History | Learn over the RE-smoothed or RE-filtered history, back out the history with the learning model (inversion), or run a time-varying Kalman filter with a likelihood | [History modes](options/history-modes.md) |
| Scenarios | Zero or smoothed shocks, added shocks, conditions that put a variable on a path with a shock adjusting | [Forecasts, shocks and conditions](options/forecasts-conditions.md) |
| Policy | The model's own rule or Ramsey policy under commitment, with a policy loss for every run | [Monetary policy](options/policy.md) |
| Uncertainty | Density forecasts from normal or bootstrapped shock draws, with learning re-run in every draw | [Density forecasts](options/densities.md) |
| Diagnostics | Shock decompositions with time-varying beliefs; recursive real-time forecast evaluation with Diebold-Mariano tests | [Decompositions](options/decompositions.md), [Evaluation](options/evaluation.md) |
| Further rules | Seven bounded-rationality rules: cognitive discounting, myopia and anchoring, diagnostic expectations, target believers, intercept-only learners, mean-only learners, experience-based gain | [Further expectation rules](options/further-expectation-rules.md) |

## How it is organised

You write three kinds of files; the toolbox writes everything else.

| You write | What it is |
|---|---|
| A **model package** `models/<name>/` | The IRIS model file, a parameter function, a database and a short `model_spec.m` contract. [Your own model](your-own-model.md) |
| **Scenario files** `scenarios/<name>/<folder>/<id>.m` | One MATLAB function per scenario. Each returns a partial option tree; a child scenario calls its parent and changes only what differs |
| **Project options** `config/master_options.m` | Values that every scenario of the project inherits |

Options are merged as `hetlearn.defaults()` < `config/master_options.m` < the scenario, checked
by name, and stored with every result. A run writes `results/<id>/` with the paths, the
learning series (beliefs, gains, shares, forecast errors), events and comparison tables.

## Where to start

1. [Installation](getting-started/installation.md): MATLAB R2025a, IRIS 20230622, `setup_paths`.
2. [Quick start](getting-started/quick-start.md): run your first scenario in five minutes.
3. [Application 1 walkthrough](tutorial/application-1.md): the main tutorial, from the scenario
   files to the figures and numbers.
4. [Options](options/index.md): one page per option group, each with working code.
5. [Your own model](your-own-model.md): plug in any IRIS model with forward-looking terms.

## References

- Özden, T. (2025). Heterogeneous expectations and the business cycle. *International Journal
  of Central Banking* 21(1).
- Kostyshyna, O., T. Özden and Y. Zhang (2024). Bank of Canada Staff Working Paper 2024-14
  (endogenous gain).
- Smets, F. and R. Wouters (2007). Shocks and frictions in US business cycles: a Bayesian DSGE
  approach. *American Economic Review* 97(3), 586-606.
- IRIS Toolbox, release 20230622: <https://github.com/IRIS-Solutions-Team/IRIS-Toolbox>.
