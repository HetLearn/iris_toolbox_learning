# Expectations

Two options decide **whose** expectations are heterogeneous and **how** the population is
split between rational expectations (RE) agents and learners.

| Option | Values (default first) | Meaning |
|---|---|---|
| `expectations.mode` | `'rational'`, `'learning'`, `'fixed_shares'`, `'switching'` | Every agent RE; every agent a learner; fixed shares (`shares.fixed_n2`); shares that switch on forecast performance |
| `expectations.variables` | `{}`, a cellstr, or `'all'` | Forward-looking variables whose expectation is the RE/learner mix; the rest stay RE. `'all'` = every forward-looking variable of the model |

## What the toolbox does with the model

For every variable `x` in `expectations.variables`, the generated model replaces `x{+1}` by an
expectation variable `x_exp1` and adds the block

\[
\tilde E_t x_{t+1} = n_{1,x}\, f^{RE}_t(x) + n_{2,x}\, f^{BR}_t(x), \qquad n_{1,x} + n_{2,x} = 1 ,
\]

where \(\tilde E_t x_{t+1}\) is the aggregate expectation in the model, \(f^{RE}_t(x)\) the RE
agents' forecast and \(f^{BR}_t(x)\) the learners' forecast (BR, for bounded rationality, is
the code's label for the learners). Here is the block the toolbox writes for the inflation of
the Smets and Wouters (2007) model (SW07), in `models/sw07/generated/sw07_ext_ar1.model`
(`sw07_ext_ar1_relag.model` under the baseline's t-1 RE information):

```text
!if br_pinf
    pinf_exp1 = n1_pinf*pinf_exp1_RE + n2_pinf*pinf_exp1_BR;
    !if re_anchored
        pinf_exp1_RE = are_pinf__const + are_pinf__cf*cf + ... ;   % anchored RE forecast
    !else
        pinf_exp1_RE = pinf{+1};                                   % model-consistent RE
    !end
    !if br_info_current
        pinf_exp1_BR = alpha_pinf + beta_pinf*pinf;                % learners see period t
    !else
        pinf_exp1_BR = alpha_pinf + beta_pinf*(alpha_pinf + beta_pinf*pinf{-1});   % t-1
    !end
!else
    pinf_exp1 = pinf{+1};
!end
```

The `!if` switches are set from the options at load time, so one generated file serves many
scenarios. The shares `n1_pinf`, `n2_pinf` and the beliefs `alpha_pinf`, `beta_pinf` are
model parameters that the engine changes each quarter.

## The four modes

| Mode | Learners' share | Shares updated | Beliefs updated |
|---|---|---|---|
| `'rational'` | 0 | no (fitness tracked as a diagnostic) | yes, as a diagnostic |
| `'learning'` | 1 | no | yes |
| `'fixed_shares'` | `shares.fixed_n2` | no | yes |
| `'switching'` | endogenous | yes | yes |

In mode `'rational'` the learning variables keep their blocks with an RE share of 1, so the RE
run has the same model structure as the learning runs it is compared with, and it equals the
original model exactly (the collapse test checks this to 1e-10 every time a file is generated).

```matlab
% Every agent RE (the RE benchmark of Application 1)
cfg = a1_re();                                    % mode 'rational', variables {'pinf'}

% Every agent a learner (evaluation variant e04)
cfg = a1_learn(); cfg.id = 'a1_all_learners';
cfg.expectations.mode = 'learning';
res = hetlearn.run(cfg, 'save', false);

% A fixed split: 30% learners
cfg = a1_learn(); cfg.id = 'a1_fixed30';
cfg.expectations.mode = 'fixed_shares';
cfg.shares.fixed_n2 = 0.3;
res = hetlearn.run(cfg, 'save', false);

% Switching shares (the baseline learning economy)
cfg = a1_learn();                                 % mode 'switching'
```

## Which variables learn

```matlab
cfg = a1_learn(); cfg.id = 'a1_learn_pinf_w';
cfg.expectations.variables = {'pinf', 'w'};       % inflation and the real wage
res = hetlearn.run(cfg, 'save', false);

cfg = a1_learn(); cfg.id = 'a1_learn_all';
cfg.expectations.variables = 'all';               % all 12 forward-looking variables of SW07 (variant v3_all)
res = hetlearn.run(cfg, 'save', false);
```

- Each learning variable gets its own learners (its own perceived law of motion and beliefs)
  and, by default, its own share (`shares.structure = 'per_variable'`). One share for several
  variables: [Shares and switching](switching.md#one-share-for-several-variables).
- A name that is not forward-looking stops the load with `hetlearn:load_model:notForward`.
  The candidates:

```matlab
spec = hetlearn.load_spec('sw07');
opts = hetlearn.load_options(a1_learn());
[m, info] = hetlearn.load_model(spec, opts);
info.meta.forward_vars
% SW07: invef, rkf, pkf, cf, labf, inve, pinf, rk, pk, c, lab, w
```

- Leads of two or more periods are handled too: `x{+2}` becomes `x_exp2 = x_exp1{+1}`, so the
  one-step expectation carries the heterogeneity.

## In the project

Learning on all twelve forward-looking variables (`v3_all`, model variant 3) is much less
stable than learning on inflation alone: average inflation over 2022Q3-2026Q2 is 14.50% with
facility `'alm'` and 2.72% with `'plm_alm'`, against 3.45% for inflation-only learning. See
[Projection facility](projection-facility.md#in-the-project).

## Related

- RE agents' forecasts: [RE agents](re-agents.md).
- More than two types of agents and transforms of the expectations:
  [Further expectation rules](further-expectation-rules.md).
