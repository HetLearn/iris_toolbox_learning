# Monetary policy

By default the model's own policy rule sets the policy rate. With `policy.mode = 'ramsey'` the
rule is switched off and the instrument follows optimal policy under commitment from the
forecast origin.

| Option | Values (default first) | Meaning |
|---|---|---|
| `policy.mode` | `'rule'`, `'ramsey'` | The model's own rule, or Ramsey optimal policy (needs `spec.policy`) |
| `policy.type` | `'commitment'`, `'discretion'` | Ramsey under commitment; discretion is indeterminate in IRIS for the Smets and Wouters (2007) model (SW07) |
| `policy.loss` | `struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0)` | Non-negative weights by target name. Replaced as a whole: targets left out get weight 0 |
| `policy.discount` | `[]` or a number in (0, 1] | `[]` = `spec.policy.discount` |
| `policy.loss_horizon` | `[]` or a number of quarters | Horizon of the reported loss; `[]` = the forecast horizon. A longer one continues the scenario with zero shocks and no conditions |

## The policy section of a model package

Ramsey policy and the loss need a `policy` field in `model_spec.m`. For SW07:

```matlab
spec.policy = struct( ...
    'instrument', 'r', ...                                                   % policy instrument
    'rule_label', 'Monetary policy rule, Taylor rule on the output gap y-yf', ...  % exact equation label
    'targets', struct('pinf', '4*pinf', 'ygap', 'y - yf', 'r', '4*r', 'dr', '4*(r - r{-1})'), ...
    'discount', '$cbetabar$*$cgamma$');                                     % expression in parameters
```

The rule equation is found by its exact label in the model file and switched off under Ramsey
policy. The targets are linear expressions in model variables; `policy.loss` gives their
weights by name. The discounted loss is

\[
L = \sum_{h=1}^{H} \delta^{h} \sum_{j} w_j\, \text{target}_{j,h}^2 .
\]

Every run of a package with a policy section reports this loss with the `policy.loss` weights,
rule runs included, so rule and Ramsey runs are compared on the same weights:
`res.loss` and `results/<id>/loss.csv` (target, expression, weight, contribution, share,
discount, horizon, continuation, mode, type).

## Examples

```matlab
% Ramsey policy under commitment, balanced weights, loss over 80 quarters
cfg = a4_rule_learn(); cfg.id = 'my_ramsey_learn';
cfg.policy.mode = 'ramsey';
cfg.policy.type = 'commitment';
cfg.policy.loss = struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0);
cfg.policy.loss_horizon = 80;
res = hetlearn.run(cfg);

% The rule, with the loss reported under other weights (the path does not change)
cfg = a1_learn(); cfg.id = 'a1_rule_loss';
cfg.policy.loss = struct('pinf', 1, 'ygap', 1, 'r', 0, 'dr', 0.5);
cfg.policy.discount = 0.99;
res = hetlearn.run(cfg, 'save', false);
res.loss                                   % total and contributions
```

Under learning the planner treats the current beliefs and shares as permanent, re-optimizes
every quarter with the beliefs and shares in force, and honors its past commitments. The plan
starts at the origin with zero Lagrange multipliers.

## Restrictions

- Ramsey policy needs period-t rational expectations (RE) information,
  `expectations.re_info = 'current'`: with `'lagged'` the run stops with
  `hetlearn:options:unsupported`. The project's Application 4 sets `'current'` for this reason.
- Ramsey policy is not available with the agent types and transforms of
  [Further expectation rules](further-expectation-rules.md).
- A package without `spec.policy` cannot run `'ramsey'`, and its runs report no loss.

## Anchored RE agents and Ramsey policy

Anchored RE agents forecast with the RE solution of the model **under the rule**, also in mode
`'rational'`. So a Ramsey run with anchored RE agents is not an RE Ramsey plan. The RE
benchmark uses model-consistent RE agents:

```matlab
cfg = a4_ramsey_balanced_re(); cfg.id = 'a4_ramsey_balanced_re_mc';
cfg.expectations.re_variant = 'model_consistent';
```

In a learning Ramsey run the anchored RE agents also keep the rule's forecast, so its loss is
not a clean measure of the gain from optimal policy. Under the rule the two variants give the
same RE path.

## In the project

Application 4 compares the rule and Ramsey policy for four weight sets under RE and learning.
With balanced weights over 80 quarters the loss falls from 230.1 to 127.7 under RE and from
359.4 to 184.5 under learning. Details and figure: [Application 4](../applications/app4-ramsey.md).
