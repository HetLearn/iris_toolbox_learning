function spec = model_spec()
%MODEL_SPEC  Model package contract (DESIGN sec. 2) for the toy NK test model.
%
%   spec = model_spec()   (call with this folder as the current folder)
%
%   The database is simulated from the RE model by build_toy_database.m
%   (fixed seed); test_engine builds it if it is missing. Needs IRIS (qq).

spec = struct();
spec.name = 'nk3';
spec.folder = fileparts(mfilename('fullpath'));
spec.model_file = 'nk3.model';
spec.params = 'nk3_params';
spec.sstate = '';
spec.linear = true;
spec.assign = struct();
spec.database = 'data/nk3_database.csv';   % simulated data, build_toy_database.m
spec.filter_range = [qq(2000,1), qq(2029,4)];
spec.observables = {'obs_y', 'obs_pie', 'obs_r'};
% Policy section (DESIGN 2, 13): the rule switched off under Ramsey policy,
% loss targets (same names as the SW07 package, quarterly units) and the
% planner's discount.
spec.policy = struct( ...
    'instrument', 'r', ...
    'rule_label', 'Taylor rule', ...
    'targets', struct('pinf', 'pie', 'ygap', 'y', 'r', 'r', 'dr', 'r - r{-1}'), ...
    'discount', 'bet');
spec.report = struct();
end
