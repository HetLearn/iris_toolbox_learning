function cfg = e01_re()
%E01_RE  Forecast evaluation variant: rational expectations (the benchmark).
%
%   cfg = e01_re()
%
%   A variant of the recursive forecast evaluation (run_applications('eval')):
%   hetlearn.evaluate sets the origin (1990Q1-2024Q2), the horizon (8), zero
%   future shocks, no conditions, no density, no comparisons and real-time RE
%   filters, so only the expectations model below matters. Identical to sw07_re.

cfg = sw07_re();
cfg.id = 'e01_re';
cfg.title = 'Evaluation variant: rational expectations (the benchmark)';
cfg.description = 'Real-time forecasts with every agent rational; the benchmark of the evaluation.';
cfg.compare_with = {};
end
