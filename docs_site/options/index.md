# Options

Every setting of a run is a field of one option tree. `hetlearn.defaults()` returns the full
tree with its default values; [Options reference](../reference/options.md) lists every field.
The pages in this section take one group at a time and show working code.

## How options reach a run

```
hetlearn.defaults()  <  config/master_options.m  <  the scenario's cfg
```

`hetlearn.load_options` merges the three field by field (later wins) and checks every name
and value. A misspelled field stops the run with `hetlearn:options:unknown` and the full option
path; a removed option stops it with `hetlearn:options:removed` and names the replacement.
The merged tree is stored with every result as `res.cfg`.

Three ways to set an option:

```matlab
% 1. For the whole project: config/master_options.m
o.switching.intensity = 2;

% 2. For a scenario and everything that inherits from it: in its file
function cfg = my_scenario()
cfg = a1_learn();
cfg.id = 'my_scenario';
cfg.switching.intensity = 1;
end

% 3. For one run, in memory
cfg = a1_learn(); cfg.id = 'try_chi1'; cfg.switching.intensity = 1;
res = hetlearn.run(cfg, 'save', false);
```

Some groups are replaced as a whole rather than merged: `conditions`, `policy.loss`,
`expectations.types`, `expectations.transforms`, `shares.init`, `shares.fixed`. Free-form
subtrees are merged without name checks: `beliefs.init.values`, `beliefs.plm.by_var`,
`beliefs.plm.derived`, `gain.by_var`, `shares.fixed_n2` (as a struct), `shocks.add`, `report`.

The options a scenario ends up with:

```matlab
opts = hetlearn.load_options(a1_learn());
opts.gain
```

## The pages

One page per group of options (RE: rational expectations):

| Page | Options and functions |
|---|---|
| [Expectations](expectations.md) | `expectations.mode`, `expectations.variables` |
| [RE agents](re-agents.md) | `expectations.re_variant`, `expectations.re_info` |
| [Timing and information](timing.md) | `beliefs.info`, `expectations.re_info`, `history.re_states`, `history.realtime` |
| [Perceived laws of motion](plm.md) | `beliefs.plm.default`, `.by_var`, `.derived`, `.var` |
| [Gains](gains.md) | `gain.rule`, `gain.value`, `gain.by_var`, `gain.koz.*` |
| [Initial beliefs](initial-beliefs.md) | `beliefs.init.*`, `beliefs.update`, `history.learn` |
| [Shares and switching](switching.md) | `shares.*`, `switching.*` |
| [Projection facility](projection-facility.md) | `projection.facility` |
| [History modes](history-modes.md) | `history.mode`, `history.inversion.*`, `history.kalman.init`, `history.learn` |
| [Forecasts, shocks and conditions](forecasts-conditions.md) | `forecast.*`, `shocks.*`, `conditions`, `compare_with`, `engine.*` |
| [Monetary policy](policy.md) | `policy.*` |
| [Density forecasts](densities.md) | `density.*` |
| [Shock decompositions](decompositions.md) | `hetlearn.decompose` |
| [Forecast evaluation](evaluation.md) | `hetlearn.evaluate`, `hetlearn.evaluate_tables` |
| [Further expectation rules](further-expectation-rules.md) | `expectations.types`, `expectations.transforms`, `shares.init`, `shares.fixed` |

!!! note "Defaults and the project baseline"
    The examples use the scenarios of the project's Smets and Wouters (2007) model, which
    inherit the project baseline of `config/master_options.m`
    ([Application 1, section 3](../applications/app1-peak.md#3-the-baseline-settings)). Where
    a page quotes a default, it is the value in `hetlearn.defaults()`; the baseline value is
    given next to it when they differ.
