function cfg = a6_kalman_re()
%A6_KALMAN_RE  Application 6: Kalman history 1965Q1-2026Q2 of the RE(t-1) model (benchmark of a6_kalman_learn).
%
%   cfg = a6_kalman_re()
%
%   As a6_smooth_re with history.mode = 'kalman' (docs/DESIGN_br_extensions.md sec. 5):
%   every agent is RE, so the ALM is the RE(t-1) model in every quarter and the filter
%   equals the IRIS filter of that model (gate K1 of tests/test_kalman.m). Its one-step
%   prediction errors and log likelihood are the RE(t-1) benchmark of the in-sample RMSE
%   comparison. history.re_states = 'smoothed' as in a6_kalman_learn.

cfg = a6_smooth_re();
cfg.id = 'a6_kalman_re';
cfg.title = 'App 6: Kalman history 1965Q1-2026Q2, RE(t-1) benchmark';
cfg.description = 'The RE(t-1) model filtered quarter by quarter: one-step prediction errors and log likelihood 1966Q1-2026Q2.';
cfg.history.mode = 'kalman';
cfg.history.re_states = 'smoothed';           % required with 'kalman' (one-sided already); baseline 'filtered'
end
