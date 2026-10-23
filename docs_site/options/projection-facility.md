# Projection facility

Learning can push beliefs to values at which the model has no stable solution. The projection
facility is the toolbox's only stabilizing device. Terms: the **perceived law of motion (PLM)**
is the learners' forecasting rule; the **actual law of motion (ALM)** is the model with the
current beliefs and shares plugged in.

| Option | Values (default first) | Meaning |
|---|---|---|
| `projection.facility` | `'plm_alm'`, `'alm'`, `'none'` | Check each PLM block, then the ALM; check the ALM only; no restriction. Project baseline: `'alm'` |

## What each value does

**`'alm'`** (the project baseline). The PLMs are never touched; they may be explosive as long
as the model stays solvable. Each quarter, after the belief update, the model with the new
beliefs and shares is solved. If it has no stable solution, every belief (coefficients and
moment matrices of every PLM equation) goes back to its value before this quarter's update,
event `projection_alm`.

**`'plm_alm'`** (the default). First each PLM block is checked: a block whose new beliefs have
a root above 1 in modulus (AR(1): \(|\beta| > 1\)) keeps its previous beliefs, event
`projection_plm`; the other blocks update. Then the ALM is checked as under `'alm'`. A PLM block
is a set of PLM equations linked through their regressors: a vector autoregression is one
block, an auxiliary PLM belongs to the block that uses it, separate AR(1)s are separate blocks.

**`'none'`**. No restriction. A quarter that must be simulated without a model solution stops
the run with `hetlearn:engine:noSolution` (date, stage, shares, each PLM block's largest root,
the IRIS flag). Exception: an anchored model in which every forward-looking variable learns has
no leads at all; it is simulated as it is, with `explosive` events.

**Shares kept as the last step.** Under `'alm'` and `'plm_alm'`, if the model is still unstable
with every belief at its previous value, the shares alone are the problem: last quarter's model
shares stay in force for this quarter, event `projection_alm_shares`. Switching carries on
underneath, and the next quarter tries the new shares again
([share names](switching.md#share-names-in-the-outputs)).

**When `'alm'` and `'plm_alm'` stop.** Only when there is no earlier solved model to fall back
on: the initial beliefs and shares are already unstable at the first check. The error is
`hetlearn:engine:almUnstable`.

The same rules apply in every stage that updates beliefs: the history (where the model is
solved each quarter only for this check; 3-10 seconds for the Smets and Wouters (2007) model
over 1966-2022), the inversion, the forecast, density draws, evaluation runs and Ramsey runs.
Mode `'rational'` skips the check. The endogenous gain updates from the forecast error whatever
the facility does.

## Examples

```matlab
% The default: PLM blocks, then the ALM (variant v3_all_plm_alm)
cfg = v3_all(); cfg.id = 'v3_all_plm_alm';
cfg.projection.facility = 'plm_alm';

% The ALM only (the project baseline; variant v3_all_alm)
cfg = v3_all(); cfg.id = 'v3_all_alm';
cfg.projection.facility = 'alm';

% No facility: the run stops if the model loses its solution
cfg = a1_learn(); cfg.id = 'a1_nofacility';
cfg.projection.facility = 'none';
res = hetlearn.run(cfg, 'save', false);
```

Project-wide: `o.projection.facility = 'alm';` in `config/master_options.m`.

## Reading the events

```matlab
res = hetlearn.run(v3_all(), 'save', false);
res.events                                       % date, type, variable, detail, stage
sum(strcmp(res.events.type, 'projection_alm'))   % beliefs reverted
```

| Event | Meaning |
|---|---|
| `projection_plm` | `'plm_alm'`: a PLM block kept its beliefs (detail: block and root) |
| `projection_alm` | No stable model solution; every belief went back to its value before the update |
| `projection_alm_shares` | Still unstable with the old beliefs; last quarter's model shares stayed in force |
| `explosive` | A model without leads was simulated without a stable solution |

`events.csv` is worth checking before reading a run that leans on the facility: a run whose
shares are held for many quarters is mostly the facility's doing.

## In the project

The facility never acts in Applications 1-6 (point forecasts) or in model variants 2 and 4. It
matters for learning on all twelve forward-looking variables (model variant 3):

| Scenario | Facility | Average inflation 2022Q3-2026Q2 (%) | Events |
|---|---|---:|---|
| `a1_learn` | `'alm'` | 3.45 | none |
| `v3_all` = `v3_all_alm` | `'alm'` | 14.50 | 4 belief reverts, 17 kept shares |
| `v3_all_plm_alm` | `'plm_alm'` | 2.72 | 87 PLM blocks kept |

With no facility the same all-variable run averaged 33.48%. Elsewhere the facility acts in
`v1_mc_learn` (model-consistent rational expectations agents, 4 belief reverts), in 23 of the
500 learning mark-up density draws of Application 5, and in some real-time evaluation runs.
