function cfg = a4_rule_re()
%A4_RULE_RE  Application 4: Taylor-rule benchmark from the 2022Q2 peak, RE, loss over 80 quarters.
%
%   cfg = a4_rule_re()
%
%   As a1_re (the model's Taylor rule), with the policy loss reported over 80
%   quarters: periods 17-80 continue the scenario with zero shocks. The loss
%   uses the default weights (pinf 1, ygap 0.5, r 0.1, dr 0); the summary
%   recomputes it for the other weight sets from the target paths in
%   res.loss.values.
%
%   Deviation from the baseline (2026-10-20, the only one): Ramsey policy is
%   not supported with expectations.re_info = 'lagged' (hetlearn:options:
%   unsupported, DESIGN 19), so application 4 runs with RE information
%   'current' (E_t pinf_{t+1}). It is set here and in a4_rule_learn.m, the
%   parents of every app-4 scenario, so the rule and the Ramsey runs share one
%   information set. Everything else is the baseline (published SW07
%   parameters, filtered RE states, KOZ gain, chi 2, memory 0.8, facility 'alm').

cfg = a1_re();
cfg.id = 'a4_rule_re';
cfg.title = 'App 4: Taylor rule from the 2022Q2 peak, rational expectations, loss over 80 quarters';
cfg.description = 'The Taylor-rule forecast of a1_re with the discounted policy loss reported over 80 quarters (zero-shock continuation); every agent rational; RE information current (app 4 only).';
cfg.policy.loss_horizon = 80;
cfg.expectations.re_info = 'current';         % app 4 only: Ramsey + 'lagged' is not supported (baseline 'lagged')
end
