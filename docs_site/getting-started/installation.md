# Installation

## Requirements

| Software | Version | Needed for |
|---|---|---|
| MATLAB | R2025a (the version the toolbox is developed and tested on) | everything |
| IRIS Toolbox | release **20230622** exactly | model parsing, solution, Kalman filter, simulation |
| Python 3 with pandas | any recent version | only the report and figure builders in `reports/` and `paper/figures/` |
| MkDocs Material | see `docs_site/requirements.txt` | only to build these pages locally |

No other MATLAB toolbox is required by `hetlearn` itself. Dynare is not needed; it was used
once to validate the SW07 package and the RE(t-1) model.

## Step 1: get the code

```powershell
git clone https://github.com/tolgaozden/iris_toolbox_learning.git
cd iris_toolbox_learning
```

The repository is private for now; ask the owner for access. A fresh clone has the toolbox,
the model packages with their data, every scenario file and the tests. It has no `results/`
and no `generated/` folders: the toolbox writes them on the first run.

## Step 2: get IRIS 20230622

Download the IRIS Toolbox release tagged `Release-20230622` from
<https://github.com/IRIS-Solutions-Team/IRIS-Toolbox/releases> and unzip it anywhere, for
example to `C:\Users\<you>\Desktop\IRIS-Toolbox-Release-20230622`. Do not add it to the MATLAB
path yourself and do not run its startup; `setup_paths` does both.

!!! note "Why this exact release"
    The toolbox is tested against IRIS 20230622. One IRIS file needed a fix to run optimal
    (Ramsey) policy on MATLAB R2025a; the fixed copy is
    `toolbox/iris_patches/+model/Insertable.m`, which `setup_paths` puts in front of the IRIS
    original. Your IRIS installation is not changed. Another IRIS release may work for
    simple runs, but the patch and the tests assume 20230622.

## Step 3: point `setup_paths.m` at IRIS

Open `setup_paths.m` in the project root and set the IRIS folder on line 12:

```matlab
irisDir = 'C:\Users\<you>\Desktop\IRIS-Toolbox-Release-20230622';
```

This is the only machine-specific line in the project.

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
    Run `setup_paths` again after you create a new subfolder under `scenarios/` in an open
    session, so that MATLAB sees the new scenario functions.

## Step 5: check the installation

Run a scenario. The first run of a model writes its generated files and RE filter cache to
`models/sw07/generated/`, so it takes longer than later runs, which take 10-20 seconds.

```matlab
res = hetlearn.run(a1_learn());     % Application 1, learning economy
```

The run prints progress lines and ends with the folder it wrote, `results/a1_learn/`. If you
see `setup_paths:noIris`, line 12 of `setup_paths.m` points to the wrong folder.

You can also run part of the test suite. Use a separate MATLAB session for the tests: they
put their own `master_options.m` first on the path, so project runs in the same session would
pick up the test settings.

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

`matlab -batch` does not start in the PowerShell folder, so the command starts with `cd`. Keep
a path with spaces inside the MATLAB single quotes. `exit(1)` in the `catch` block gives
PowerShell a nonzero exit code when the run fails. `run_applications` calls `setup_paths`
itself; anything else needs `setup_paths` first.

## Optional: Python

The HTML report (`reports/build_report_v3.py`) and the paper figures
(`paper/figures/make_figures.py`) are Python scripts that read the CSV summary tables. They
need Python 3 with pandas (and matplotlib for the figures). The toolbox itself does not use
Python.

## Optional: build these pages

```powershell
pip install -r docs_site/requirements.txt
mkdocs serve          # preview at http://127.0.0.1:8000
mkdocs build          # static site in site/
```

## Project layout

```
iris_toolbox_learning/
  setup_paths.m              IRIS and project paths (edit line 12)
  run_applications.m         runner for the SW07 applications, variants and evaluation
  config/master_options.m    project-wide option values (the baseline)
  toolbox/+hetlearn/         the toolbox
  toolbox/iris_patches/      the R2025a fix for IRIS 20230622
  models/sw07/               Smets-Wouters (2007) package: model, parameters, data, spec
  scenarios/sw07/            scenario files, one function per file, by application
  tests/                     test suites, toy NK package, reference results
  results/                   written by runs (not versioned)
  docs/                      user guide, design notes, feature register
  docs_site/                 these pages (MkDocs)
```
