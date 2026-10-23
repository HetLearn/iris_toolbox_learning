function cfg = tsw07_peak_re()
%TSW07_PEAK_RE  Test scenario: SW07 forecast from the 2022Q2 inflation peak, zero shocks, all agents rational.
%
%   Defined inside tests/ so that the tests do not
%   depend on scenarios/ or results/. Same content as the earlier template
%   sw07_peak_re, with the calibration written out (the earlier values of
%   config/master_options.m, chi = 0.51), so a later change of the master
%   file does not move the test references. Defaults otherwise: anchored RE,
%   projection.facility = 'plm_alm', engine.step = 'fast'.

cfg = struct();
cfg.id = 'tsw07_peak_re';
cfg.title = 'Test: peak-inflation forecast from 2022Q2, rational expectations';
cfg.model = 'sw07';
cfg.forecast.origin = qq(2022, 2);
cfg.forecast.horizon = 16;
cfg.expectations.mode = 'rational';
cfg.expectations.variables = {'pinf'};
cfg.gain.value = 0.0585;             % earlier calibration of config/master_options.m
cfg.switching.intensity = 0.51;      % IJCB estimate
cfg.switching.memory = 0.6;
cfg.shares.init_n2 = 0.5;
% Settings the project baseline changed later, pinned at their previous values (= the
% defaults), so the references hold even with the live config/master_options.m on the path
% (the tests normally read tests/scenarios/master_options.m instead)
cfg.model_params = '';               % swX1 (spec.params), not the published SW07 mode
cfg.gain.rule = 'constant';
cfg.expectations.re_info = 'current';
cfg.history.re_states = 'smoothed';
cfg.projection.facility = 'plm_alm';
end
