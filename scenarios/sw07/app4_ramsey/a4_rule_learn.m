function cfg = a4_rule_learn()
%A4_RULE_LEARN  Application 4: Taylor-rule benchmark from the 2022Q2 peak, learning, loss over 80 quarters.
%
%   cfg = a4_rule_learn()
%
%   As a1_learn with the policy loss reported over 80 quarters (zero-shock
%   continuation; learning continues). Writes compare_a4_rule_re.csv.
%
%   Deviation from the baseline (2026-10-20, the only one): the RE agents use
%   information 'current' (E_t pinf_{t+1}) in application 4, because Ramsey
%   policy is not supported with expectations.re_info = 'lagged' (DESIGN 19);
%   see a4_rule_re.m. The learners keep t-1 data (beliefs.info = 'lagged').

cfg = a1_learn();
cfg.id = 'a4_rule_learn';
cfg.title = 'App 4: Taylor rule from the 2022Q2 peak, learning on inflation, loss over 80 quarters';
cfg.description = 'The Taylor-rule forecast of a1_learn with the discounted policy loss reported over 80 quarters (zero-shock continuation); RE information current (app 4 only).';
cfg.policy.loss_horizon = 80;
cfg.expectations.re_info = 'current';         % app 4 only: Ramsey + 'lagged' is not supported (baseline 'lagged')
cfg.compare_with = {'a4_rule_re'};
end
