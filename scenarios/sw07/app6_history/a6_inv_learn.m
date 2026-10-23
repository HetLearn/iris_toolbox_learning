function cfg = a6_inv_learn()
%A6_INV_LEARN  Application 6: history 1966Q1-2026Q2 backed out with the learning model.
%
%   cfg = a6_inv_learn()
%
%   As a6_smooth_learn with history.mode = 'inversion': every history quarter
%   is simulated with the learning model, the 7 observables exogenised at
%   their data values and the 7 shocks endogenised, so the shocks, beliefs and
%   shares are those of the learning economy. Writes compare_a6_smooth_learn.csv.
%
%   history.re_states = 'smoothed': the baseline sets 'filtered',
%   which applies to the RE smoother only and is an error with the inversion.
%   The inversion is one-sided by construction (quarter t uses data up to t),
%   so this line only restores the value the option check accepts.

cfg = a6_smooth_learn();
cfg.id = 'a6_inv_learn';
cfg.title = 'App 6: history 1966Q1-2026Q2 backed out with the learning model';
cfg.description = 'The shocks of 1966Q1-2026Q2 backed out quarter by quarter with the learning-on-inflation model instead of the RE smoother.';
cfg.history.mode = 'inversion';
cfg.history.re_states = 'smoothed';           % required with 'inversion' (one-sided already); baseline 'filtered'
cfg.compare_with = {'a6_smooth_learn'};
end
