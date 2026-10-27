# Applications

The project runs seven applications on the Smets and Wouters (2007) model (SW07), all from the
2022Q2 inflation peak or over the full history, each in a rational expectations (RE) version
and a learning version. They share the [project baseline](app1-peak.md#3-the-baseline-settings)
and differ only in the lines their scenario files set.

| Application | Question | Main option | Scenario folder | Runner | Time |
|---|---|---|---|---|---|
| [1. Peak forecast](app1-peak.md) | How fast does inflation fall from the peak with zero shocks? | `expectations.mode` | `scenarios/sw07/app1_peak/` | `app1` | ~30 s |
| [2. Shock replay](app2-replay.md) | Feed in the shocks the RE model says hit the economy: what does the learning economy make of them? | `shocks.source` | `app2_replay/` | `app2` | ~10 s |
| [3. Policy deviations](app3-policy.md) | Hold the rate 100 basis points (bp) below or above the Taylor rule for a year | `conditions` | `app3_policy/` | `app3` | ~30 s |
| [4. Ramsey policy](app4-ramsey.md) | Optimal policy under commitment against the rule, four sets of loss weights | `policy.*` | `app4_ramsey/` | `app4` | ~2.5 min |
| [5. Density forecasts](app5-density.md) | How uncertain is the forecast with mark-up or demand shocks? | `density.*` | `app5_density/` | `app5` | ~14 min |
| [6. History and decompositions](app6-history.md) | What history does the learning model back out, and which shocks drove inflation? | `history.mode`, `hetlearn.decompose` | `app6_history/` | `app6` | ~40 s |
| [7. Further expectation rules](app7-rules.md) | How do seven rules from the bounded-rationality literature change Application 1? | `expectations.types`, `expectations.transforms` | `br_portfolio/` | `run_br_app1('run')` | ~2 min |

Five model variants change one assumption of Application 1. They are described on the option
pages:

| Variant | Change | Page |
|---|---|---|
| `var1_re_variant/v1_mc_learn` | model-consistent instead of anchored RE agents | [RE agents](../options/re-agents.md) |
| `var2_plm/v2_*` | AR(2), AR(1) without constant, regression and VAR(1) perceived laws of motion | [Perceived laws of motion](../options/plm.md) |
| `var3_allvars/v3_*` | learning on all twelve forward-looking variables, under each facility | [Projection facility](../options/projection-facility.md) |
| `var4_gain/v4_*` | constant and decreasing gains against the endogenous gain | [Gains](../options/gains.md) |
| `var5_switching/v5_*` | intensity of choice 0.5 or 5, memory 0.5 or 0.95 | [Shares and switching](../options/switching.md) |

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
group table. Application 7 has its own runner, `run_br_app1` ([Application 7](app7-rules.md#running-the-rules)).

## Results used on these pages

All numbers on the application pages come from the summary tables of the baseline run
(`results/summary_v3/`). Inflation, output and consumption growth are in % quarter on quarter,
annualized, the policy rate in % a year, differences in percentage points (pp).

## Checks and reproduction

The summary script `results/summary_v3/build_summary_v3.m` checks the application runs and
writes every check, with its tolerance, to `results/summary_v3/checks_v3.txt`. For
Application 1:

- The RE run `a1_re` equals a hand-written RE version of SW07 with t-1 information
  (`tests/models/sw07_re_lagged_pinf.model`), filtered and simulated on its own, to 1.7e-12.
  That model was also checked against Dynare.
- In every forecast quarter of `a1_learn` the share in force equals the share computed at the
  end of the quarter before, so the projection facility never kept the shares.
- Every run completed, and the facility acted in no Application 1 run.

The checks on the other applications are stated on their pages. To reproduce every result:

```matlab
run_applications('all')                         % every group; about 3 hours, mostly the evaluation
run('results/summary_v3/build_summary_v3.m')    % summary tables and checks, about 3 minutes
```

The summary script reads the results of every scenario, so it needs all groups, not only
`app1`.
