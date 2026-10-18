function cfg = e06_ar1nc()
%E06_AR1NC  Forecast evaluation variant: learning on inflation, AR(1) PLM without constant.
%
%   cfg = e06_ar1nc()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v2_ar1nc.

cfg = v2_ar1nc();
cfg.id = 'e06_ar1nc';
cfg.title = 'Evaluation variant: learning on inflation, AR(1) PLM without constant';
cfg.description = 'Real-time forecasts of the learning model with an AR(1) PLM without constant.';
cfg.compare_with = {};
end
