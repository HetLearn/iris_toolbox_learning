function cfg = a4_rule_learn()
%A4_RULE_LEARN  Application 4: Taylor-rule benchmark from the 2022Q2 peak, learning, loss over 80 quarters.
%
%   cfg = a4_rule_learn()
%
%   As a1_learn with the policy loss reported over 80 quarters (zero-shock
%   continuation; learning continues). Writes compare_a4_rule_re.csv.

cfg = a1_learn();
cfg.id = 'a4_rule_learn';
cfg.title = 'App 4: Taylor rule from the 2022Q2 peak, learning on inflation, loss over 80 quarters';
cfg.description = 'The Taylor-rule forecast of a1_learn with the discounted policy loss reported over 80 quarters (zero-shock continuation).';
cfg.policy.loss_horizon = 80;
cfg.compare_with = {'a4_rule_re'};
end
