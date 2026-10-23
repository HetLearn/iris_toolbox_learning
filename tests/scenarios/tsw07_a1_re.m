function cfg = tsw07_a1_re()
%TSW07_A1_RE  Test scenario: the frozen project baseline a1_re with every baseline setting written out.
%
%   cfg = tsw07_a1_re()
%
%   Test copy of scenarios/sw07/app1_peak/a1_re.m merged with the project baseline at the
%   time of the freeze: published SW07 mode, RE agents on t-1 information for the
%   learning set {pinf} (the RE(t-1) model), KOZ gain from 0.05, chi 2, memory 0.8, AR(1),
%   filtered RE states in the history, no projection facility. Zero future shocks from the
%   2022Q2 inflation peak, horizon 16. Every baseline value is set here, so the BR-extension
%   regression references (tests/reference/br_freeze.mat)
%   depend neither on scenarios/ nor on any master_options file. make_br_freeze checks, when it
%   freezes, that the merged option tree equals that of a1_re under the live config/master_options.m
%   (apart from id, title, description and compare_with).

cfg = struct();
cfg.id = 'tsw07_a1_re';
cfg.title = 'Test: baseline a1_re (frozen), forecast from the 2022Q2 peak, RE(t-1)';
cfg.model = 'sw07';
cfg.model_params = 'sw07_params_original';   % published SW07 (2007) mode
cfg.forecast.origin = qq(2022, 2);           % the inflation peak (sw07_re asserts it with find_peak)
cfg.forecast.horizon = 16;
cfg.expectations.mode = 'rational';
cfg.expectations.variables = {'pinf'};
cfg.expectations.re_variant = 'anchored';
cfg.expectations.re_info = 'lagged';
cfg.beliefs.plm.default = 'ar1';
cfg.beliefs.info = 'lagged';
cfg.gain.rule = 'koz';
cfg.gain.value = 0.05;
cfg.switching.intensity = 2;
cfg.switching.memory = 0.8;
cfg.shares.init_n2 = 0.5;
cfg.history.re_states = 'filtered';
cfg.projection.facility = 'none';
end
