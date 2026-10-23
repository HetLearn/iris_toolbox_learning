# FAQ and troubleshooting

RE stands for rational expectations, SW07 for the Smets and Wouters (2007) model.

## Errors

| Message or identifier | Cause | Fix |
|---|---|---|
| `setup_paths:noIris` | IRIS is not in the folder of the environment variable `HETLEARN_IRIS_DIR`, nor in `IRIS-Toolbox-Release-20230622` next to the project folder | Set `HETLEARN_IRIS_DIR` to the IRIS 20230622 folder ([Installation](../getting-started/installation.md), step 3) |
| `Undefined function 'a1_learn'` (or any scenario) | `setup_paths` not run, or a new scenario folder created after it ran | Run `setup_paths` again |
| `hetlearn:options:unknown` | A misspelled option; the message gives the full path, e.g. `beliefs.plm.defualt` | Correct the name; see [Options reference](../reference/options.md) |
| `hetlearn:options:value` | A value outside its list or range, e.g. `switching.memory = 1` | Use an allowed value |
| `hetlearn:options:missing` | `'fixed_shares'` without `shares.fixed_n2`; `'universal'` without `shares.master`; `'training_ols'` without a training range; density without shocks | Set the missing option |
| `hetlearn:options:unsupported` | A combination that is not supported; the message names it ([Option errors](../reference/options.md#option-errors)) | Change one of the two options |
| An error that `re_info = 'lagged'` needs a learning set | `hetlearn.load_options(struct())` under a master that sets `'lagged'` | Set `expectations.variables`, or pass a master: `hetlearn.load_options(cfg, struct())` |
| `'filtered'` is an error with `'inversion'` or `'kalman'` | `history.re_states = 'filtered'` applies to the RE smoother only | Set `cfg.history.re_states = 'smoothed'` in that scenario |
| `hetlearn:load_model:notForward` | A name in `expectations.variables` that has no lead in the model | Check `info.meta.forward_vars` from `hetlearn.load_model` |
| `hetlearn:load_model:plmMismatch` | A non-AR(1) `beliefs.plm.default` and a learning variable's perceived law of motion that uses a forward-looking variable outside the learning set as a regressor: the generated file and the run give that regressor different perceived laws of motion | Set `beliefs.plm.by_var.<u>` for that regressor |
| `hetlearn:load_model:params` | `model_params` names a file that is not in the package folder | Fix the name, or set `cfg.model_params = ''` |
| `hetlearn:load_model:anchored` | Anchored RE agents need a linear model with plain state names | See [Adding a model](../adding-a-model.md#limits) |
| `hetlearn:engine:noSolution` | Facility `'none'` and a quarter without a stable model solution | Use facility `'alm'` or `'plm_alm'`, or accept the stop as the result |
| `hetlearn:engine:almUnstable` | The initial beliefs and shares are already unstable, so there is no earlier solved model to fall back on | Change the initial beliefs or shares (often with `history.learn = false`) |
| `hetlearn:engine:master` | A `shares.master` variable that does not learn | Add it to `expectations.variables` |
| `sw07_re: expected the inflation peak in 2022Q2` | The database changed and the peak moved | Update the assert in `scenarios/sw07/base/sw07_re.m`, or set a fixed origin |

## Questions

**Why does the learners' share drift back to 0.5 in a zero-shock forecast?**
With no shocks both types' forecast errors shrink, so both fitness measures decay toward zero
and the logit gives equal shares. See
[Shares and switching](../options/switching.md#with-zero-future-shocks).

**Why does an RE run not equal the original model?**
Under `expectations.re_info = 'lagged'` (the project baseline) the RE benchmark is the RE model
with t-1 information for the learning set, not the original model. `re_info = 'current'` gives
the original model's RE forecast. In mode `'rational'` with `'current'` the run equals the
original model to about 1e-12.

**What units is \(\chi\) in?**
It multiplies squared forecast errors in model units. SW07 and Özden (2025) use percent per
quarter, so 0.51 applies as published. For a model in annualized percent, \(\chi\) is divided by
16.

**Are the results in `results/` up to date after a scenario is edited?**
No. Saved results never update themselves. The scenario and everything that inherits from it
must be rerun; `run_applications` reruns whole groups in order. A comparison target that
already has results is not rerun automatically.

**Why does `scenarios.csv` list a run as `missing`?**
The summary takes each status from `results/run_log.csv`, which only `run_applications` writes.
SW07 scenarios that should appear in the summary are run through `run_applications('<id>')`.

**How are a re-filter and new model files forced?**
By deleting the relevant files in `models/<name>/generated/` (or the folder). Cache names carry
a hash of the model text, parameters, data and range, so a stale cache is never used; deleting
is only needed to force a rebuild.

**Can several MATLAB sessions run in parallel?**
Yes, once the model caches exist (run any group once first). Two sessions must never write the
same `results/<id>/` or the same evaluation part, and comparison targets should have results
before the sessions start. One PowerShell window per session, each with its own `-logfile`
([Running from PowerShell](../getting-started/installation.md#running-from-powershell-without-a-matlab-window)).

**Why is the density forecast slow with learning?**
Each draw re-runs the quarter-by-quarter forecast so that beliefs and shares respond to the
drawn shocks (about 0.5 seconds per draw on SW07). RE densities without conditions use a linear
fast path.

**What is the difference between `n2` and `n1_model`?**
`n2` is the learners' share computed by the discrete choice at the end of a quarter;
`n1_model` is the RE share actually in the model in a quarter, normally `n1` of the quarter
before. They differ when the projection facility keeps last quarter's shares.

**Which IRIS release?**
20230622. The R2025a patch in `toolbox/iris_patches/` is written for it.

## Tests

The tests are in `tests/`. They use their own option file, `tests/scenarios/master_options.m`
(the toolbox defaults), so the project baseline does not reach them. They run in a separate
MATLAB session: they put that file first on the path.

```matlab
addpath(fullfile(pwd, 'tests'))
run_tests({'test_options', 'test_rls', 'test_switching'})   % a subset
run_tests()                                                  % every suite; more than 9 minutes
```

- Four checks compare with stored references exactly (`test_inversion` S3b, `test_gain` G14,
  `test_re_states` S1, `test_re_info` T6b), and so does `test_br_regression`. They run at the
  default thread count: with `maxNumCompThreads(2)` the results differ by about 1e-12.
- `test_generator` runs in a session of its own.
- `test_re_info` takes about 8 minutes; `test_re_info('toy')`, `('sw07_model')`,
  `('sw07_runs')` and `('sw07_stages')` run its parts.
- The tests never read `scenarios/` or `results/`; they write to `tests/output/`.

A batch run from PowerShell, with the error report and exit code:
[Installation](../getting-started/installation.md#running-from-powershell-without-a-matlab-window).
