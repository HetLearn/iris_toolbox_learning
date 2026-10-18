function cfg = e02_learn()
%E02_LEARN  Forecast evaluation variant: learning on inflation.
%
%   cfg = e02_learn()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to sw07_learn.

cfg = sw07_learn();
cfg.id = 'e02_learn';
cfg.title = 'Evaluation variant: learning on inflation';
cfg.description = 'Real-time forecasts with inflation expectations a switching mix of anchored RE agents and AR(1) learners.';
cfg.compare_with = {};
end
