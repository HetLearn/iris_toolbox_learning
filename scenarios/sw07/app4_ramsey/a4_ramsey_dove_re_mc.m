function cfg = a4_ramsey_dove_re_mc()
%A4_RAMSEY_DOVE_RE_MC  Application 4: Ramsey policy (commitment), dovish weights, RE with model-consistent RE agents.
%
%   cfg = a4_ramsey_dove_re_mc()
%
%   The RE Ramsey benchmark for these weights. As a4_ramsey_dove_re with
%   expectations.re_variant = 'model_consistent': the RE agents' inflation
%   expectation is x{+1} of the model under the Ramsey policy, so the plan is
%   an RE Ramsey plan. In a4_ramsey_dove_re the anchored pinf block keeps
%   forecasting with the RE solution under the Taylor rule. Under the rule the
%   two RE variants coincide (check C11 in results/summary_v3/checks_v3.txt).
%   Writes compare_a4_rule_re.csv.

cfg = a4_ramsey_dove_re();
cfg.id = 'a4_ramsey_dove_re_mc';
cfg.title = 'App 4: Ramsey policy, dovish weights, rational expectations (model-consistent RE agents)';
cfg.description = 'The RE Ramsey benchmark with loss weights inflation 1, output gap 1, rate 0.1: RE agents forecast the model under the Ramsey policy instead of using the Taylor-rule RE solution.';
cfg.expectations.re_variant = 'model_consistent';
end
