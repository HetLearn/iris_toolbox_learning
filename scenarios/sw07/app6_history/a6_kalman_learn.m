function cfg = a6_kalman_learn()
%A6_KALMAN_LEARN  Application 6: history 1965Q1-2026Q2 from the Kalman filter of the learning model's ALM.
%
%   cfg = a6_kalman_learn()
%
%   As a6_smooth_learn with history.mode = 'kalman' (technical appendix,
%   "The Kalman history"): each quarter the ALM in force (beliefs and shares from the end of
%   the quarter before) is solved, the Kalman filter predicts and updates with that
%   quarter's data, and the agents learn from the filtered values in real time. The
%   default start, history.kalman.init = 'stochastic', is the asymptotic distribution of
%   the RE limit in 1965Q1. res.kalman and kalman_errors.csv hold the one-step prediction
%   errors of the 7 observables and the log likelihood; the in-sample RMSE benchmark is
%   a6_kalman_re (RE(t-1), same mode): hetlearn.engine.kalman_history('rmse', res).
%   The 4-quarter forecast starts from the filtered state at 2026Q2. Writes
%   compare_a6_kalman_re.csv.
%
%   history.re_states = 'smoothed': the baseline sets 'filtered', which applies to the
%   RE smoother only and is an error with 'kalman'. The Kalman history is one-sided by
%   construction, so this line only restores the value the option check accepts.

cfg = a6_smooth_learn();
cfg.id = 'a6_kalman_learn';
cfg.title = 'App 6: Kalman history 1965Q1-2026Q2 of the learning model';
cfg.description = ['The ALM of the learning-on-inflation model filtered quarter by quarter (time-varying ' ...
    'Kalman filter): one-step prediction errors and log likelihood 1966Q1-2026Q2.'];
cfg.history.mode = 'kalman';
cfg.history.re_states = 'smoothed';           % required with 'kalman' (one-sided already); baseline 'filtered'
cfg.compare_with = {'a6_kalman_re'};
end
