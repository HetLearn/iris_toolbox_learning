function cfg = e07_reg()
%E07_REG  Forecast evaluation variant: learning on inflation, PLM on lagged inflation, output gap and rate.
%
%   cfg = e07_reg()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v2_reg.

cfg = v2_reg();
cfg.id = 'e07_reg';
cfg.title = 'Evaluation variant: learning on inflation, PLM on lagged inflation, output gap and rate';
cfg.description = 'Real-time forecasts of the learning model with inflation regressed on lagged inflation, output gap and rate.';
cfg.compare_with = {};
end
