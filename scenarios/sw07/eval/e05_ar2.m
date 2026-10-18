function cfg = e05_ar2()
%E05_AR2  Forecast evaluation variant: learning on inflation, AR(2) PLM.
%
%   cfg = e05_ar2()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v2_ar2.

cfg = v2_ar2();
cfg.id = 'e05_ar2';
cfg.title = 'Evaluation variant: learning on inflation, AR(2) PLM';
cfg.description = 'Real-time forecasts of the learning model with an AR(2) PLM for inflation.';
cfg.compare_with = {};
end
