function cfg = e10_allvars()
%E10_ALLVARS  Forecast evaluation variant: learning on all 12 forward-looking variables (anchored RE).
%
%   cfg = e10_allvars()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to v3_all.

cfg = v3_all();
cfg.id = 'e10_allvars';
cfg.title = 'Evaluation variant: learning on all 12 forward-looking variables (anchored RE)';
cfg.description = 'Real-time forecasts with RE agents and AR(1) learners on every forward-looking variable.';
cfg.compare_with = {};
end
