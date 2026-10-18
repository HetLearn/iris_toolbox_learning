function cfg = a4_ramsey_balanced_re()
%A4_RAMSEY_BALANCED_RE  Application 4: Ramsey policy (commitment), balanced weights, RE.
%
%   cfg = a4_ramsey_balanced_re()
%
%   Optimal policy under commitment from the 2022Q2 origin (zero Lagrange
%   multipliers at the origin) in place of the Taylor rule, loss weights
%   pinf 1, ygap 0.5, r 0.1, dr 0 (targets 4*pinf, y - yf, 4*r, 4*(r - r{-1})),
%   reported over 80 quarters. The parent of the other three weight sets.
%   Writes compare_a4_rule_re.csv.

cfg = a4_rule_re();
cfg.id = 'a4_ramsey_balanced_re';
cfg.title = 'App 4: Ramsey policy, balanced weights, rational expectations';
cfg.description = 'Ramsey policy under commitment from the 2022Q2 peak with loss weights inflation 1, output gap 0.5, rate 0.1, rate change 0; every agent rational.';
cfg.policy.mode = 'ramsey';
cfg.policy.type = 'commitment';
cfg.policy.loss = struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0);
cfg.compare_with = {'a4_rule_re'};
end
