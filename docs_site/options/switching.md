# Shares and switching

In mode `'switching'` the shares of RE agents and learners move each quarter with their
recent forecast performance (Özden 2025, eqs. 14-15).

| Option | Values (default first) | Meaning |
|---|---|---|
| `switching.rule` | `'discrete_choice'` | The switching rule; a function in `toolbox/+hetlearn/+switching/` |
| `switching.intensity` | `0.51` | Intensity of choice \(\chi\), >= 0. Project baseline: 2 |
| `switching.memory` | `0.6` | Memory \(\omega\) of the fitness measure, in [0, 1). Project baseline: 0.8 |
| `shares.structure` | `'per_variable'`, `'universal'` | One learners' share per learning variable, or one share for all |
| `shares.master` | name or cellstr | `'universal'` only (required there): the variables whose squared errors drive the share |
| `shares.init_n2` | `0.5` | Learners' share at `beliefs.init.date` |
| `shares.fixed_n2` | number, or struct by variable | Mode `'fixed_shares'` (required there): the learners' share |

## The rule

For each share group \(G\) (one learning variable, or the master list), with \(F^i_{v,t-1}\)
type \(i\)'s forecast of \(v_t\) made in t-1:

\[
FE^i_t = \sum_{v \in G}\left(v_t - F^i_{v,t-1}\right)^2, \qquad
U^i_t = \omega U^i_{t-1} - (1-\omega) FE^i_t ,
\]

\[
n_{1,t} = \frac{\exp(\chi U^{RE}_t)}{\exp(\chi U^{RE}_t) + \exp(\chi U^{BR}_t)}, \qquad
n_{2,t} = 1 - n_{1,t}.
\]

The shares computed at the end of t are in force in t+1. Initial fitness: \(U^{RE}_0 = 0\) and
\(U^{BR}_0\) such that \(n_{2,0}\) = `shares.init_n2`.

- \(\chi = 0\) gives equal shares whatever the errors; a large \(\chi\) sends almost everyone to
  the type with the better recent record.
- \(\omega\) close to 1 means a long memory of past errors.

!!! warning "Units of the intensity of choice"
    \(\chi\) multiplies squared forecast errors, so its meaning depends on the units of the model
    variables. SW07 and the data of Özden (2025) are in percent per quarter, so the estimate
    0.51 applies as published. With annualised variables, divide \(\chi\) by 16 for the same
    switching.

## Examples

```matlab
% Intensity of choice and memory (Ozden 2025, Table 1: chi 0.51, memory 0.62)
cfg = a1_learn(); cfg.id = 'a1_ijcb_switching';
cfg.switching.intensity = 0.51;
cfg.switching.memory = 0.62;
res = hetlearn.run(cfg, 'save', false);

% Start the share recursion at 0.3 learners
cfg = a1_learn(); cfg.id = 'a1_init03';
cfg.shares.init_n2 = 0.3;

% Fixed shares: 30% learners in every quarter
cfg = a1_learn(); cfg.id = 'a1_fixed30';
cfg.expectations.mode = 'fixed_shares';
cfg.shares.fixed_n2 = 0.3;

% Fixed shares that differ by variable
cfg = a1_learn(); cfg.id = 'a1_fixed_byvar';
cfg.expectations.variables = {'pinf', 'w'};
cfg.expectations.mode = 'fixed_shares';
cfg.shares.fixed_n2 = struct('pinf', 0.3, 'w', 0.6);
```

## One share for several variables

By default each learning variable has its own share, driven by its own errors. As in Özden
(2025), where one share is driven by the summed squared errors of inflation and the output
gap, you can use one share for all learning variables:

```matlab
cfg = a1_learn(); cfg.id = 'a1_universal';
cfg.expectations.variables = {'pinf', 'w'};
cfg.shares.structure = 'universal';
cfg.shares.master = {'pinf', 'w'};      % squared errors of both drive the one share
res = hetlearn.run(cfg, 'save', false);
```

Every master variable must be a learning variable (error `hetlearn:engine:master` otherwise).

## Share names in the outputs

Type 1 is the RE agents, type 2 the learners; the shares sum to 1.

| Name | Where | Meaning |
|---|---|---|
| `n1_<x>`, `n2_<x>` | model parameters | RE and learners' shares of x's expectation in the model |
| `n1`, `n2` | `res.learning.<x>` | Discrete-choice shares computed at the end of each quarter |
| `n1_model` | `res.learning.<x>` | RE share actually in the model that quarter (= `n1` of the quarter before, unless the projection facility kept the shares) |
| `zetaRE`, `zetaBR` | `res.learning.<x>` | Fitness \(U^{RE}\), \(U^{BR}\) |
| `FE_RE`, `FE_BR` | `res.learning.<x>` | Squared one-step errors |
| `fRE`, `fBR` | `res.learning.<x>` | The one-step forecasts |

```matlab
res = hetlearn.run(a1_learn(), 'save', false);
L = res.learning.pinf;
L.n2(qq(2022, 2))              % 0.591, computed at the end of 2022Q2
1 - L.n1_model(qq(2022, 3))    % 0.591, in force in 2022Q3
```

In modes other than `'switching'`, `n1` and `n2` are still computed as a diagnostic; the
model uses the fixed shares.

## With zero future shocks

With no shocks over the forecast, both types' errors shrink and both fitness measures decay
toward zero, so the shares drift back toward 0.5 by construction. There is no cost term that
would favour one type. In Application 1 the learners' share falls from its peak of 0.685
toward 0.516 by 2026Q2 for this reason.

## More than two types

N types of agents with their own rules and shares, `shares.init` and `shares.fixed` by type
name, as in the target-believers rule: [Further expectation rules](further-expectation-rules.md).
