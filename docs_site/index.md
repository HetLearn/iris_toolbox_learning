# hetlearn

> **Disclaimer.** This is a Claude-assisted project. The code, tests and documentation were
> developed with Anthropic's Claude, in particular Claude Opus 5.5, under the author's direction
> and review.

`hetlearn` is a MATLAB toolbox, built on the IRIS Toolbox for macroeconomic modeling (release
20230622), for forecasts and policy scenarios in dynamic stochastic general equilibrium (DSGE)
models where not everyone has rational expectations. Expectations of selected forward-looking
variables are a mix of two groups of agents:

- **rational expectations (RE) agents**, who forecast with the RE solution of the model, and
- **learners**, who forecast from a simple perceived law of motion (PLM), such as an AR(1) for
  inflation, and update its coefficients by recursive least squares each quarter. The code
  labels them BR, for bounded rationality.

The population shares of the two groups switch each quarter according to their recent
forecast errors, following Özden (2025, *International Journal of Central Banking* 21(1)).
The toolbox takes a linear IRIS model file and a database, writes the
heterogeneous-expectations version of the model, learns beliefs and shares over the history,
and runs a scenario forward one quarter at a time with the beliefs and shares updating as it
goes.

![Application 1: forecast from the 2022Q2 inflation peak](assets/figures/fig_app1.png){ .figure }

*Application 1, the main example of these pages: a forecast from the 2022Q2 inflation peak in
the Smets and Wouters (2007) model. Average inflation over 2022Q3-2026Q2 is 3.45% with learners
and 2.59% under RE. [Application 1](applications/app1-peak.md).*

## Scope

- **Linear IRIS models only.** Any linear model with forward-looking terms (`x{+1}`) works; no
  model-specific code is needed.
- **Published parameter values.** The model packages use the parameters published by their
  authors; the toolbox does not estimate them.
- **MATLAB R2025a and IRIS release 20230622.** The toolbox is developed and tested on these two
  versions and patches one IRIS file for R2025a ([Installation](getting-started/installation.md)).

## Who it is for

- Central-bank and policy economists who run DSGE forecasts and want a version of the same
  forecast in which expectations can drift away from rational expectations, without rewriting
  the model by hand.
- Researchers working on adaptive learning and heterogeneous expectations who want the
  standard machinery (recursive least-squares learning, discrete-choice switching, projection
  facilities, endogenous gains) in one place, tested against reference implementations.

## What it does

| Area | What it does | Page |
|---|---|---|
| Expectations | Heterogeneous expectations for any subset of forward-looking variables; all-RE, all-learner, fixed-share and switching modes | [Expectations](options/expectations.md) |
| RE agents | Anchored RE agents (pure-RE forecast) or model-consistent ones; information up to t or t-1 | [RE agents](options/re-agents.md) |
| Timing | What each agent sees when it forecasts; filtered or smoothed history; real-time filtering | [Timing and information](options/timing.md) |
| Learners | AR(1), AR(2), AR(1) without constant, regressions on other variables, VAR(1) PLMs (vector autoregressions); derived regressors | [Perceived laws of motion](options/plm.md) |
| Gains | Constant gain or the endogenous gain of Kostyshyna, Özden and Zhang (2024) | [Gains](options/gains.md) |
| Initial beliefs | From the RE model's moments, from ordinary least squares on a training sample, or given values | [Initial beliefs](options/initial-beliefs.md) |
| Switching | Discrete-choice shares per variable or one share for several variables; intensity of choice and memory | [Shares and switching](options/switching.md) |
| Stability | A projection facility on the PLMs and the actual law of motion, on the actual law of motion only, or none | [Projection facility](options/projection-facility.md) |
| History | Learning on the RE-smoothed or RE-filtered history; the history backed out with the learning model (inversion); a time-varying Kalman filter with a likelihood | [History modes](options/history-modes.md) |
| Scenarios | Zero or smoothed shocks, added shocks, conditions that put a variable on a path with a shock adjusting | [Forecasts, shocks and conditions](options/forecasts-conditions.md) |
| Policy | The model's own rule or Ramsey policy under commitment, with a policy loss for every run | [Monetary policy](options/policy.md) |
| Uncertainty | Density forecasts from normal or bootstrapped shock draws, with learning re-run in every draw | [Density forecasts](options/densities.md) |
| Diagnostics | Shock decompositions with time-varying beliefs; recursive real-time forecast evaluation with Diebold-Mariano tests | [Decompositions](options/decompositions.md), [Evaluation](options/evaluation.md) |
| Further rules | Seven bounded-rationality rules: cognitive discounting, myopia and anchoring, diagnostic expectations, target believers, intercept-only learners, mean-only learners, experience-based gain | [Further expectation rules](options/further-expectation-rules.md), [Application 7](applications/app7-rules.md) |

## How it is organized

A project consists of three kinds of files; the toolbox writes everything else.

| File | What it is |
|---|---|
| A **model package** `models/<name>/` | The IRIS model file, a parameter function, a database and a short `model_spec.m` contract. [Adding a model](adding-a-model.md) |
| **Scenario files** `scenarios/<name>/<folder>/<id>.m` | One MATLAB function per scenario. Each returns a partial option tree; a child scenario calls its parent and changes only what differs |
| **Project options** `config/master_options.m` | Values that every scenario of the project inherits |

The options are merged in a fixed order ([How options reach a run](options/index.md#how-options-reach-a-run)),
checked by name, and stored with every result. A run writes `results/<id>/` with the paths, the
learning series (beliefs, gains, shares, forecast errors), events and comparison tables.

## Where to start

1. [Installation](getting-started/installation.md): MATLAB R2025a, IRIS 20230622, `setup_paths`.
2. [Quick start](getting-started/quick-start.md): a first scenario in five minutes.
3. [Application 1](applications/app1-peak.md): the main tutorial, from the scenario files to
   the figures and numbers.
4. [Options](options/index.md): one page per option group, each with working code.
5. [Adding a model](adding-a-model.md): any IRIS model with forward-looking terms.

The methods, with every equation and timing convention, are in the
[technical appendix](reference/technical-appendix.md).

## License and citation

The code is released under the MIT License
([`LICENSE`](https://github.com/tolgaozden/iris_toolbox_learning/blob/main/LICENSE)). To cite
the method and the toolbox:

```bibtex
@article{ozden2025hetexp,
  author  = {{\"O}zden, Tolga},
  title   = {Heterogeneous Expectations and the Business Cycle},
  journal = {International Journal of Central Banking},
  volume  = {21},
  number  = {1},
  year    = {2025}
}

@misc{hetlearn,
  author       = {{\"O}zden, Tolga},
  title        = {hetlearn: a {MATLAB} toolbox for heterogeneous expectations in {IRIS} models},
  year         = {2026},
  howpublished = {\url{https://github.com/tolgaozden/iris_toolbox_learning}}
}
```

## References

- Özden, T. (2025). Heterogeneous expectations and the business cycle. *International Journal
  of Central Banking* 21(1).
- Kostyshyna, O., T. Özden and Y. Zhang (2024). Bank of Canada Staff Working Paper 2024-14
  (endogenous gain).
- Smets, F. and R. Wouters (2007). Shocks and frictions in US business cycles: a Bayesian DSGE
  approach. *American Economic Review* 97(3), 586-606.
- IRIS Toolbox, release 20230622: <https://github.com/IRIS-Solutions-Team/IRIS-Toolbox>.
