# hetlearn: heterogeneous expectations for IRIS models

> **Disclaimer.** This is a Claude-assisted project. The code, tests and documentation were
> developed with Anthropic's Claude, in particular Claude Opus 5.5, under the author's direction
> and review.

`hetlearn` is a MATLAB toolbox, built on the [IRIS Toolbox](https://github.com/IRIS-Solutions-Team/IRIS-Toolbox)
(release 20230622), for forecasts and policy scenarios in dynamic stochastic general
equilibrium (DSGE) models where not everyone has rational expectations. The expectations of
chosen forward-looking variables are a mix of **rational expectations (RE) agents**, who use
the RE solution, and **adaptive learners**, who forecast from a simple perceived law of motion
(PLM) and update it by recursive least squares. The shares of the two groups switch each
quarter with their recent forecast errors, following Özden (2025, *International Journal of
Central Banking* 21(1)).

The toolbox takes a linear IRIS model file and a database, writes the
heterogeneous-expectations version of the model, learns beliefs and shares over the history,
and runs a scenario forward one quarter at a time with beliefs and shares updating as it goes.
The project's main model is Smets and Wouters (2007), SW07, on US data 1965Q1-2026Q2.

**Documentation website:** <https://tolgaozden.net/iris_toolbox_learning/>, with every option,
the seven applications and the [technical appendix](docs_site/assets/technical_appendix.pdf)
(PDF). **License:** MIT, see [`LICENSE`](LICENSE).

## 1. What it does

| Area | What it does |
|---|---|
| Expectations | Heterogeneous expectations for any subset of forward-looking variables; all-RE, all-learner, fixed-share and switching modes |
| RE agents | Anchored (pure-RE forecast) or model-consistent; information up to t or t-1 |
| Learners | AR(1), AR(2), AR(1) without constant, regressions on other variables, vector autoregressive PLMs; derived regressors; data up to t or t-1 |
| Gains | Constant gain or the endogenous gain of Kostyshyna, Özden and Zhang (2024) |
| Initial beliefs | From the RE model's moments, ordinary least squares on a training sample, or given values |
| Switching | Discrete choice on discounted squared forecast errors, per variable or one share for several variables |
| Stability | Projection facility on the PLMs and the actual law of motion, on the actual law of motion only, or none |
| History | Learning on the RE-filtered or RE-smoothed history; the history backed out with the learning model (inversion); a time-varying Kalman filter with a log likelihood |
| Scenarios | Zero or smoothed shocks, added shocks, conditions that put a variable on a path with a shock adjusting |
| Policy | The model's own rule or Ramsey policy under commitment; a discounted policy loss for every run |
| Uncertainty | Density forecasts (normal or bootstrapped shocks), with learning re-run in every draw |
| Diagnostics | Shock decompositions with time-varying beliefs; recursive real-time forecast evaluation with Diebold-Mariano tests |
| Further rules | Seven bounded-rationality rules: cognitive discounting, myopia and anchoring, diagnostic expectations, target believers, intercept-only learners, mean-only learners, experience-based gain |

Every option is checked by name and value, and every result stores the options that made it.

## 2. Requirements and scope

| Software | Version | Needed for |
|---|---|---|
| MATLAB | R2025a | everything |
| IRIS Toolbox | release 20230622 | model parsing, solution, filtering, simulation |
| MkDocs Material | `docs_site/requirements.txt` | only to build the documentation site |

No other MATLAB toolbox and no Dynare are needed. The toolbox handles linear IRIS models only,
and the model packages use published parameter values: it does not estimate them.

## 3. Installation

1. **Clone** the repository: `git clone https://github.com/tolgaozden/iris_toolbox_learning.git`.
2. **Get IRIS 20230622** from the [IRIS releases page](https://github.com/IRIS-Solutions-Team/IRIS-Toolbox/releases)
   (tag `Release-20230622`) and unzip it beside `iris_toolbox_learning/`, or anywhere else
   with `setenv('HETLEARN_IRIS_DIR', 'C:\path\to\IRIS-Toolbox-Release-20230622')`. Do not add
   it to the path; `setup_paths` does that.
3. **Start a session** from the project root with `setup_paths` (it starts IRIS and adds
   `toolbox/`, the R2025a IRIS patch, `config/` and `scenarios/`).
4. **Check**: `res = hetlearn.run(a1_learn());` should end by writing `results/a1_learn/`. The
   first run of a model writes its generated files and RE filter cache, so it takes longer;
   later runs take 10-20 seconds.

Details and the repository layout:
[Installation](https://tolgaozden.net/iris_toolbox_learning/getting-started/installation/).

## 4. Quick start

```matlab
setup_paths
res_re = hetlearn.run(a1_re());        % every agent rational
res    = hetlearn.run(a1_learn());     % RE agents and AR(1) inflation learners, switching shares

T = hetlearn.compare({'a1_re', 'a1_learn'}, {'pinfobs', 'robs'})   % levels and differences, model units

h = qq(2022, 3):qq(2026, 2);
mean(4*res.paths.pinfobs(h))           % average inflation, annualized: 3.45
res.learning.pinf.n2(qq(2022, 2))      % learners' share at the end of 2022Q2: 0.591

% change one assumption, without a new file
cfg = a1_learn();
cfg.id = 'a1_learn_chi1';
cfg.switching.intensity = 1;
res1 = hetlearn.run(cfg, 'save', false);
```

A scenario is a MATLAB function returning a partial option tree that is merged over the
toolbox defaults and the project options; a child scenario calls its parent and changes only
what differs. To run the project's groups and log them: `run_applications('app1')`.

## 5. Example: Application 1

US inflation peaked in 2022Q2 at 8.9% annualized. With no further shocks, how fast does it
come down under rational expectations, and how fast when part of the population learns?
`a1_learn` is `sw07_learn` (SW07, origin at the 2022Q2 peak, 16 quarters, switching shares on
inflation) under its own name. The project baseline (`config/master_options.m`): published
SW07 parameters, AR(1) learners on inflation with the endogenous gain from 0.05, intensity of
choice 2, memory 0.8, RE agents (anchored) and learners on t-1 information, the RE-filtered
history, projection facility on the actual law of motion.

![Application 1: forecast from the 2022Q2 inflation peak](docs_site/assets/figures/fig_app1.png)

*Data (black), RE benchmark (blue, dashed) and learning economy (orange), annualized; panel e:
the learners' share of inflation expectations.*

| Average 2022Q3-2026Q2 (%) | Data | RE | Learning | Learning − RE |
|---|---:|---:|---:|---:|
| Inflation | 3.21 | 2.59 | 3.45 | +0.86 |
| Policy rate | 4.41 | 4.53 | 5.42 | +0.88 |
| Output growth | 1.44 | 3.69 | 3.39 | −0.29 |
| Consumption growth | 1.42 | 2.27 | 1.96 | −0.31 |

At the origin the learners' AR(1) coefficient is 1.061: after the 2021-22 surge they perceive
inflation as explosive and extrapolate the peak. The full walkthrough:
[Application 1](https://tolgaozden.net/iris_toolbox_learning/applications/app1-peak/).

## 6. The applications

| Application | Question | Key result (baseline) |
|---|---|---|
| [1. Peak forecast](https://tolgaozden.net/iris_toolbox_learning/applications/app1-peak/) | Disinflation from 2022Q2 with zero shocks | inflation 3.45% learning vs 2.59% RE |
| [2. Shock replay](https://tolgaozden.net/iris_toolbox_learning/applications/app2-replay/) | Feed in the RE-smoothed shocks of 2022Q3-2026Q2 | RE replay = data; learning replay 4.64% vs 3.21% data |
| [3. Policy deviations](https://tolgaozden.net/iris_toolbox_learning/applications/app3-policy/) | Rate 100 basis points below/above the rule for a year | inflation effect +0.72 percentage points (learning) vs +0.67 (RE) |
| [4. Ramsey policy](https://tolgaozden.net/iris_toolbox_learning/applications/app4-ramsey/) | Optimal policy under commitment vs the rule | 80-quarter loss 127.7 vs 230.1 (RE), 184.5 vs 359.4 (learning) |
| [5. Density forecasts](https://tolgaozden.net/iris_toolbox_learning/applications/app5-density/) | 500 draws of mark-up or demand shocks | 90% inflation band 14.6 vs 4.8 percentage points (learning vs RE) with mark-up shocks |
| [6. History](https://tolgaozden.net/iris_toolbox_learning/applications/app6-history/) | The history backed out with the learning model; decompositions; Kalman likelihood | learners' share 0.811 (inversion) vs 0.591 at 2022Q2 |
| [7. Further expectation rules](https://tolgaozden.net/iris_toolbox_learning/applications/app7-rules/) | Seven bounded-rationality rules in Application 1 | average inflation from 2.94% (intercept-only learners) to 4.75% (diagnostic expectations) |

`run_applications('app3')` runs one group and `run_applications('all')` every group and the
evaluation (about 3 hours); `run_br_app1('run')` runs Application 7 (about two minutes).

## 7. Adding a model

Any linear IRIS model with leads (`x{+1}`) works. A model package is a folder
`models/<name>/` with the model file, a parameter function, a database and a `model_spec.m`
contract; then:

```matlab
spec = hetlearn.load_spec('<name>');
cfg = struct('model', '<name>');
cfg.expectations.variables = {'pinf'};
opts = hetlearn.load_options(cfg, struct());
[m, info] = hetlearn.load_model(spec, opts);   % writes the extended model, runs the collapse test
```

Step by step: [Adding a model](https://tolgaozden.net/iris_toolbox_learning/adding-a-model/).

## 8. Tests

```matlab
addpath(fullfile(pwd, 'tests'))
run_tests({'test_options', 'test_rls', 'test_switching'})   % a subset, seconds
run_tests()                                                  % every suite, more than 9 minutes
```

The 24 suites (listed in `tests/run_tests.m`; 364 checks) cover the options, the learning and
switching code, the model generator, the engine, every history mode, Ramsey policy and the
further expectation rules; several compare against references made with Dynare or
hand-written models. The tests use their own option file (the toolbox defaults) and run in a
separate MATLAB session at the default thread count
([FAQ: tests](https://tolgaozden.net/iris_toolbox_learning/help/faq/#tests)).

## 9. Documentation

- The website, built from [`docs_site/`](docs_site/) by
  [`.github/workflows/docs.yml`](.github/workflows/docs.yml) on every push to `main` that
  changes the site.
- The [technical appendix](docs_site/assets/technical_appendix.pdf) (PDF; LaTeX source in
  [`docs/technical_appendix/`](docs/technical_appendix/)): methods, equations, timing, algorithms.
- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) (every option with its checks) and
  [`docs/DESIGN.md`](docs/DESIGN.md) (the design specification).

## 10. Citation

To cite the toolbox and the method:

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

Related references: Kostyshyna, O., T. Özden and Y. Zhang (2024), Bank of Canada Staff Working
Paper 2024-14 (endogenous gain); Smets, F. and R. Wouters (2007), *American Economic Review*
97(3), 586-606; the IRIS Toolbox, <https://github.com/IRIS-Solutions-Team/IRIS-Toolbox>.
