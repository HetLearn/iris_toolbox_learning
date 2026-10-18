function cfg = e03_learn_mc()
%E03_LEARN_MC  Forecast evaluation variant: learning on inflation, model-consistent RE agents.
%
%   cfg = e03_learn_mc()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v1_mc_learn.

cfg = v1_mc_learn();
cfg.id = 'e03_learn_mc';
cfg.title = 'Evaluation variant: learning on inflation, model-consistent RE agents';
cfg.description = 'Real-time forecasts of the learning model with model-consistent instead of anchored RE agents.';
cfg.compare_with = {};
end
