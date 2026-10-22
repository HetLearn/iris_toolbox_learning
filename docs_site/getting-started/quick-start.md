# Quick start

This page runs the project's main example, compares the learning economy with the RE
benchmark, and changes one assumption. It assumes you have done the
[installation](installation.md).

## 1. Start a session

```matlab
cd('C:\path\to\iris_toolbox_learning')
setup_paths
```

## 2. Run the two scenarios of Application 1

```matlab
res_re = hetlearn.run(a1_re());      % every agent rational
res    = hetlearn.run(a1_learn());   % RE agents and AR(1) inflation learners, switching shares
```

Each call reads a scenario file (`scenarios/sw07/app1_peak/a1_re.m`, `a1_learn.m`), merges it
with the project options, runs the history and the 16-quarter forecast from the 2022Q2
inflation peak, and writes `results/a1_re/` and `results/a1_learn/`. On a warm cache each run
takes 10-20 seconds.

The same two runs, logged in `results/run_log.csv`:

```matlab
run_applications('app1')
```

## 3. Compare the forecasts

```matlab
T = hetlearn.compare({'a1_re', 'a1_learn'}, {'pinfobs', 'robs'})
```

`T` is a table with one row per forecast quarter, the level of each variable in each scenario
(`pinfobs__a1_re`, `pinfobs__a1_learn`) and the difference from the first scenario
(`pinfobs__a1_learn_minus_a1_re`). Values are in model units: inflation and the policy rate in
percent per quarter, so multiply by 4 for annual rates.

Averages over the forecast, annualised:

```matlab
h = qq(2022, 3):qq(2026, 2);
mean(4*res_re.paths.pinfobs(h))     % 2.59
mean(4*res.paths.pinfobs(h))        % 3.45
```

## 4. Look at the learners

```matlab
L = res.learning.pinf;              % learning series of the inflation PLM
L.beta_pinf(qq(2022, 2))            % perceived AR(1) coefficient at the origin: 1.061
L.n2(qq(2022, 2))                   % learners' share at the end of 2022Q2: 0.591
```

Plot the learners' share over the history and the forecast:

```matlab
figure
plot(qq(2018, 1):qq(2026, 2), L.n2)
title('Learners'' share of inflation expectations, end of quarter')
```

## 5. Change one assumption

A scenario is a MATLAB function that returns a struct, so you can change it in memory and
run it without creating a file:

```matlab
cfg = a1_learn();
cfg.id = 'a1_learn_chi1';             % results go to results/a1_learn_chi1/
cfg.switching.intensity = 1;          % intensity of choice (baseline 2)
res1 = hetlearn.run(cfg);
T = hetlearn.compare({'a1_learn', 'a1_learn_chi1'}, {'pinfobs'});
```

Pass `'save', false` to keep a run out of `results/`:

```matlab
res1 = hetlearn.run(cfg, 'save', false);
```

## 6. Make it permanent

Save a scenario as a file under `scenarios/` (any subfolder). The file name, the function
name and `cfg.id` should be the same:

```matlab
function cfg = a1_learn_chi1()
%A1_LEARN_CHI1  Application 1 with a lower intensity of choice.
cfg = a1_learn();
cfg.id = 'a1_learn_chi1';
cfg.title = 'App 1 with chi = 1';
cfg.switching.intensity = 1;
cfg.compare_with = {'a1_learn'};      % also writes compare_a1_learn.csv
end
```

Then `hetlearn.run(a1_learn_chi1())` or `run_applications('a1_learn_chi1')`.

## Where next

- The [Application 1 walkthrough](../tutorial/application-1.md) explains what the two runs do,
  step by step, with the figures and numbers.
- The [options pages](../options/index.md) show every setting with working code.
- [Functions and outputs](../reference/functions-outputs.md) lists what a run writes.
