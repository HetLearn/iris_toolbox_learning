function cfg = e04_learn_all_learners()
%E04_LEARN_ALL_LEARNERS  Forecast evaluation variant: every agent a learner (share of learners fixed at 1).
%
%   cfg = e04_learn_all_learners()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. As e02_learn with mode learning (n2 = 1).

cfg = e02_learn();
cfg.id = 'e04_learn_all_learners';
cfg.title = 'Evaluation variant: every agent a learner (share of learners fixed at 1)';
cfg.description = 'Real-time forecasts with every agent forming inflation expectations from the learned AR(1).';
cfg.expectations.mode = 'learning';
cfg.compare_with = {};
end
