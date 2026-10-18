function cfg = e08_var3()
%E08_VAR3  Forecast evaluation variant: learning on inflation, VAR(1) PLM in inflation, output gap and rate.
%
%   cfg = e08_var3()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v2_var3.

cfg = v2_var3();
cfg.id = 'e08_var3';
cfg.title = 'Evaluation variant: learning on inflation, VAR(1) PLM in inflation, output gap and rate';
cfg.description = 'Real-time forecasts of the learning model with a three-variable VAR(1) PLM.';
cfg.compare_with = {};
end
