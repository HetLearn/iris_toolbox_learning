function cfg = sw07_learn()
%SW07_LEARN  Parent of the learning scenarios: as sw07_re, with RE agents and inflation learners whose shares switch.
%
%   cfg = sw07_learn()
%
%   The baseline learning model: inflation expectations are a mix of RE
%   agents (anchored: they use the pure-RE forecast at the current state) and
%   adaptive learners with an AR(1) PLM, constant-gain RLS, whose shares
%   switch on past squared forecast errors (IJCB eqs. 14-15, chi = 0.51).
%   Beliefs and shares are learned over the RE-smoothed history 1966Q1-2022Q2
%   and carried into the forecast. Every other option is inherited from
%   sw07_re.m, where all of them are listed.

cfg = sw07_re();
cfg.id = 'sw07_learn';
cfg.title = 'Forecast from the 2022Q2 inflation peak, learning on inflation';
cfg.description = 'As sw07_re, but inflation expectations mix RE agents and AR(1) learners whose shares switch on past forecast errors.';
cfg.expectations.mode = 'switching';
cfg.compare_with = {'sw07_re'};
end
