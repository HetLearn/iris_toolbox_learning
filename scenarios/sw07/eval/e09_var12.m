function cfg = e09_var12()
%E09_VAR12  Forecast evaluation variant: learning on inflation, VAR(1) PLM in the 12 forward-looking variables.
%
%   cfg = e09_var12()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v2_var12.

cfg = v2_var12();
cfg.id = 'e09_var12';
cfg.title = 'Evaluation variant: learning on inflation, VAR(1) PLM in the 12 forward-looking variables';
cfg.description = 'Real-time forecasts of the learning model with a 12-variable VAR(1) PLM.';
cfg.compare_with = {};
end
