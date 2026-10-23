# Installation

## Requirements

| Software | Version | Needed for |
|---|---|---|
| MATLAB | R2025a (the version the toolbox is developed and tested on) | everything |
| IRIS Toolbox | release **20230622** exactly | model parsing, solution, Kalman filter, simulation |
| MkDocs Material | see `docs_site/requirements.txt` | only to build these pages locally |

No other MATLAB toolbox is required by `hetlearn` itself. Dynare is not needed; it was used
once to validate the Smets and Wouters (2007) package (SW07) and the rational expectations
(RE) model with t-1 information.

## Step 1: get the code

```powershell
git clone https://github.com/tolgaozden/iris_toolbox_learning.git
cd iris_toolbox_learning
```

The repository is public under the MIT License. A fresh clone has the toolbox, the model
packages with their data, every scenario file and the tests. It has no `results/` and no
`generated/` folders: the toolbox writes them on the first run.

## Step 2: get IRIS 20230622

Download the IRIS Toolbox release tagged `Release-20230622` from
<https://github.com/IRIS-Solutions-Team/IRIS-Toolbox/releases> and unzip it, for example
next to the project folder (step 3). `setup_paths` adds it to the MATLAB path and runs its
startup; neither is done by hand.

!!! note "Why this exact release"
    The toolbox is tested against IRIS 20230622. One IRIS file needed a fix to run optimal
    (Ramsey) policy on MATLAB R2025a; the fixed copy is
    `toolbox/iris_patches/+model/Insertable.m`, which `setup_paths` puts in front of the IRIS
    original. The IRIS installation is not changed. Another IRIS release may work for simple
    runs, but the patch and the tests assume 20230622.

## Step 3: tell `setup_paths` where IRIS is

`setup_paths` looks for IRIS in this order:

1. the folder in the environment variable `HETLEARN_IRIS_DIR`, if it is set;
2. a folder `IRIS-Toolbox-Release-20230622` next to the project folder, for example
   `C:\work\IRIS-Toolbox-Release-20230622` beside `C:\work\iris_toolbox_learning`.

If IRIS is somewhere else, set the variable before `setup_paths`, in the session, in
`startup.m` or as a system environment variable:

```matlab
setenv('HETLEARN_IRIS_DIR', 'C:\path\to\IRIS-Toolbox-Release-20230622')
```

No file in the project needs editing.

## Step 4: start a session

In MATLAB, from the project root:

```matlab
cd('C:\path\to\iris_toolbox_learning')
setup_paths        % once per MATLAB session
```

`setup_paths` does four things:

1. starts IRIS (`iris.startup('--silent')`) unless it is already running;
2. adds `toolbox/` (the `+hetlearn` package);
3. puts the R2025a patch `toolbox/iris_patches/` first on the path;
4. adds `config/` (the project options) and `scenarios/` with every subfolder (the scenario
   functions).

Model folders are not added to the path: the toolbox finds them through `models/<name>/model_spec.m`.

!!! tip
    Run `setup_paths` again after a new subfolder is created under `scenarios/` in an open
    session, so that MATLAB sees the new scenario functions.

## Step 5: check the installation

Run a scenario. The first run of a model writes its generated files and RE filter cache to
`models/sw07/generated/`, so it takes longer than later runs, which take 10-20 seconds.

```matlab
res = hetlearn.run(a1_learn());     % Application 1, learning economy
```

The run prints progress lines and ends with the folder it wrote, `results/a1_learn/`. The
error `setup_paths:noIris` means IRIS is neither in `HETLEARN_IRIS_DIR` nor next to the project
folder (step 3).

Part of the test suite is a second check. It runs in a separate MATLAB session: the tests put
their own `master_options.m` first on the path, so project runs in the same session would pick
up the test settings.

```matlab
addpath(fullfile(pwd, 'tests'))
run_tests({'test_options', 'test_rls', 'test_switching'})   % a few seconds; one PASS/FAIL line per check
```

The full suite (`run_tests()` with no argument) takes more than 9 minutes; see
[FAQ: tests](../help/faq.md#tests).

## Running from PowerShell without a MATLAB window

```powershell
& "C:\Program Files\MATLAB\R2025a\bin\matlab.exe" -batch "try, cd('C:\path\to\iris_toolbox_learning'), setup_paths, res = hetlearn.run(a1_learn()); catch e, disp(getReport(e)), exit(1), end" -logfile run.log
```

`matlab -batch` does not start in the PowerShell folder, so the command starts with `cd`. A
path with spaces stays inside the MATLAB single quotes. `exit(1)` in the `catch` block gives
PowerShell a nonzero exit code when the run fails. `run_applications` calls `setup_paths`
itself; anything else needs `setup_paths` first. MATLAB and IRIS take about 15 seconds to
start. Several sessions can run in parallel, one PowerShell window each with its own
`-logfile` ([FAQ](../help/faq.md#questions)).

## Optional: build these pages

```powershell
pip install -r docs_site/requirements.txt
mkdocs serve          # preview at http://127.0.0.1:8000
mkdocs build --strict # static site in site/
```

`.github/workflows/docs.yml` builds the site with `--strict` and publishes it to GitHub Pages
on every push to `main` that changes `docs_site/`, `mkdocs.yml` or the workflow.

## Project layout

```
iris_toolbox_learning/
  setup_paths.m              IRIS and project paths (IRIS: step 3)
  run_applications.m         runner for the SW07 applications, model variants and evaluation
  run_br_app1.m              the seven further expectation rules in Application 1
  run_br_portfolio.m         their impulse responses and Kalman RMSE
  config/master_options.m    project-wide option values (the baseline)
  toolbox/+hetlearn/         the toolbox
  toolbox/iris_patches/      the R2025a fix for IRIS 20230622
  models/sw07/               Smets-Wouters (2007): model, two parameter sets, data, spec, validation
  models/ijcb3/, models/as07/  two smaller packages, kept as templates
  scenarios/sw07/            scenario files: base/, app1_peak/ ... app6_history/, var1-var4, eval/, br_portfolio/
  results/summary_v3/        summary script (the CSV tables are rebuilt, not versioned)
  reports/                   report builder of the estimation module
  tests/                     test suites, toy New Keynesian package, test models, reference results
  docs/                      user guide, design specification, technical appendix (LaTeX)
  docs_site/                 these pages (MkDocs)
```

Not versioned (`.gitignore`): `results/` except the summary script, every `generated/`
folder, `tests/output/`, `reports/*.html` and `archive/`. A fresh clone rebuilds them by running
the applications ([Applications](../applications/index.md)).
