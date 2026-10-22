# Applications

The project runs six applications on the Smets-Wouters (2007) model, all from the 2022Q2
inflation peak or over the full history, each in an RE version and a learning version. They
share the [project baseline](../tutorial/application-1.md#3-the-baseline-settings) and differ
only in the lines their scenario files set.

| Application | Question | Main option | Scenario folder | Runner group | Time |
|---|---|---|---|---|---|
| [1. Peak forecast](../tutorial/application-1.md) | How fast does inflation fall from the peak with zero shocks? | `expectations.mode` | `scenarios/sw07/app1_peak/` | `app1` | ~30 s |
| [2. Shock replay](app2-replay.md) | Feed in the shocks the RE model says hit the economy: what does the learning economy make of them? | `shocks.source` | `app2_replay/` | `app2` | ~10 s |
| [3. Policy deviations](app3-policy.md) | Hold the rate 100 bp below or above the Taylor rule for a year | `conditions` | `app3_policy/` | `app3` | ~30 s |
| [4. Ramsey policy](app4-ramsey.md) | Optimal policy under commitment against the rule, four sets of loss weights | `policy.*` | `app4_ramsey/` | `app4` | ~2.5 min |
| [5. Density forecasts](app5-density.md) | How uncertain is the forecast with mark-up or demand shocks? | `density.*` | `app5_density/` | `app5` | ~14 min |
| [6. History and decompositions](app6-history.md) | What history does the learning model back out, and which shocks drove inflation? | `history.mode`, `hetlearn.decompose` | `app6_history/` | `app6` | ~40 s |

Four model variants change one assumption of Application 1. They are described on the option
pages:

| Variant | Change | Page |
|---|---|---|
| `var1_re_variant/v1_mc_learn` | model-consistent instead of anchored RE agents | [RE agents](../options/re-agents.md) |
| `var2_plm/v2_*` | AR(2), AR(1) without constant, regression and VAR(1) PLMs | [Perceived laws of motion](../options/plm.md) |
| `var3_allvars/v3_*` | learning on all twelve forward-looking variables, under each facility | [Projection facility](../options/projection-facility.md) |
| `var4_gain/v4_*` | constant gain against the endogenous gain | [Gains](../options/gains.md) |

The recursive forecast evaluation (`scenarios/sw07/eval/`, group `eval`, about 2.7 hours of
compute) is on the [Forecast evaluation](../options/evaluation.md) page.

## Running them

```matlab
setup_paths
run_applications('app3')                 % one group
run_applications({'app1', 'app2'})       % several groups, in this order
run_applications('a5_markup_learn')      % one scenario, logged under its group
run_applications('all')                  % every group, the evaluation included (~3 hours)
```

Every run writes `results/<id>/` and adds a row to `results/run_log.csv`. A run that fails is
printed, logged as `error` and skipped; the next one runs. `help run_applications` gives the
group table.

## Results used on these pages

All numbers on the application pages come from the baseline run of 2026-10-21
(`results/summary_v3/key_numbers.csv`) and the paper figures in `paper/figures/`
(`FIGURE_NOTES.txt`). Inflation, output and consumption growth are in % q/q annualised, the
policy rate in % a year, differences in percentage points (pp).
