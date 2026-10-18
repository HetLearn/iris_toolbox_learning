function cfg = tsw07_peak_re()
%TSW07_PEAK_RE  Test scenario: SW07 forecast from the 2022Q2 inflation peak, zero shocks, all agents rational.
%
%   Defined inside tests/ (2026-10-18, track G) so that the tests do not
%   depend on scenarios/ or results/. Same content as the round 1-2 template
%   sw07_peak_re, with the calibration written out (the values of
%   config/master_options.m on 2026-10-18, chi = 0.51), so a later change of the master
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
cfg.gain.value = 0.0585;             % calibration of config/master_options.m (2026-10-18)
cfg.switching.intensity = 0.51;      % IJCB estimate (user decision 2026-10-18)
cfg.switching.memory = 0.6;
cfg.shares.init_n2 = 0.5;
end
