function cfg = sw07_learn()
%SW07_LEARN  Parent of the learning scenarios: as sw07_re, with RE agents and inflation learners whose shares switch.
%
%   cfg = sw07_learn()
%
%   The baseline learning model (since 2026-10-20, config/master_options.m):
%   inflation expectations are a mix of RE agents (anchored: they use the
%   pure-RE forecast of the RE(t-1) model, E_{t-1} pinf_{t+1}) and adaptive
%   learners with an AR(1) PLM on data up to t-1, RLS with the endogenous KOZ
%   gain (start 0.05), whose shares switch on past squared forecast errors
%   (IJCB eqs. 14-15, chi = 2, memory 0.8). The RE forecasts, the learners'
%   data and the realised values in the fitness errors come from the one-sided
%   RE filter (history.re_states = 'filtered') over 1966Q1-2022Q2; beliefs and
%   shares are carried into the forecast, which starts from the smoothed
%   state. Facility 'alm' (since 2026-10-21): an unstable ALM reverts the
%   beliefs, then keeps last quarter's shares. Parameters: the published SW07
%   (2007) mode. Every other option is inherited from sw07_re.m (all listed).

cfg = sw07_re();
cfg.id = 'sw07_learn';
cfg.title = 'Forecast from the 2022Q2 inflation peak, learning on inflation';
cfg.description = 'As sw07_re, but inflation expectations mix RE agents and AR(1) learners (endogenous gain) whose shares switch on past forecast errors.';
cfg.expectations.mode = 'switching';
cfg.compare_with = {'sw07_re'};
end
