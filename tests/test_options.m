function R = test_options()
%TEST_OPTIONS  Option tree, merge order and validation (hetlearn.defaults, load_options).
%
%   R = test_options()   returns a struct array of checks (name, pass, msg).

R = struct('name', {}, 'pass', {}, 'msg', {});

% defaults
try
    d = hetlearn.defaults();
    ok = d.gain.value == 0.0585 && d.switching.memory == 0.6 && d.switching.intensity == 0.51 ...
        && isequal(fieldnames(d.projection), {'facility'}) && strcmp(d.projection.facility, 'plm_alm') ...
        && ~isfield(d.switching, 'error_scale') && ~isfield(d.switching, 'error_scale_ref') ...
        && d.forecast.horizon == 16 && d.shares.init_n2 == 0.5 ...
        && strcmp(d.expectations.mode, 'rational') && strcmp(d.beliefs.plm.default, 'ar1') ...
        && strcmp(d.beliefs.init.method, 're_moments') && isempty(d.beliefs.init.date) ...
        && d.history.learn && strcmp(d.history.mode, 're_smoother') && strcmp(d.shocks.source, 'none') ...
        && isequal(size(d.conditions), [0 0]) ...
        && isequal(sort(fieldnames(d.conditions))', sort({'variable', 'shock', 'dates', 'values', 'type', 'reference'})) ...
        && iscell(d.compare_with) && isempty(d.compare_with) && strcmp(d.model, '') ...
        && strcmp(d.gain.rule, 'constant') ...
        && strcmp(d.switching.rule, 'discrete_choice') && strcmp(d.shares.structure, 'per_variable') ...
        && strcmp(d.expectations.re_variant, 'anchored') && strcmp(d.beliefs.update, 'rls');
    R = add(R, 'opt: defaults match DESIGN 6.3 (anchored RE, projection.facility = plm_alm)', ok, '');
catch err
    R = add(R, 'opt: defaults match DESIGN 6.3 (anchored RE, projection.facility = plm_alm)', false, err.message);
end

% removed options (2026-10-18): a helpful error naming projection.facility
removed = {'projection', 'on_failure', 'keep_previous'; 'projection', 'max_root', 0.99; ...
    'projection', 'method', 'shrink'; 'projection', 'scope', 'system'; ...
    'switching', 'error_scale', 'innovation_variance'; 'switching', 'error_scale_ref', ''};
for i = 1:size(removed, 1)
    nm = sprintf('opt: removed option %s.%s -> hetlearn:options:removed naming projection.facility', removed{i, 1:2});
    try
        hetlearn.load_options(struct(removed{i, 1}, struct(removed{i, 2}, removed{i, 3})), struct());
        R = add(R, nm, false, 'no error');
    catch err
        full = sprintf('%s.%s', removed{i, 1:2});
        ok = strcmp(err.identifier, 'hetlearn:options:removed') ...
            && contains(err.message, sprintf('Option "%s" was removed on 2026-10-18', full)) ...
            && contains(err.message, 'projection.facility (''plm_alm'' | ''alm'' | ''none'')');
        R = add(R, nm, ok, err.message);
    end
end
try
    hetlearn.load_options(struct('projection', struct('facility', 'shrink')), struct());
    R = add(R, 'opt: projection.facility must be plm_alm, alm or none', false, 'no error');
catch err
    R = add(R, 'opt: projection.facility must be plm_alm, alm or none', ...
        strcmp(err.identifier, 'hetlearn:options:value') || contains(err.message, 'projection.facility'), err.message);
end
try
    o = hetlearn.load_options(struct('projection', struct('facility', "alm")), struct());
    R = add(R, 'opt: projection.facility string input becomes char', ischar(o.projection.facility), class(o.projection.facility));
catch err
    R = add(R, 'opt: projection.facility string input becomes char', false, err.message);
end

% merge order: defaults < master < cfg
try
    master = struct('gain', struct('value', 0.03), 'switching', struct('intensity', 4));
    cfg = struct('gain', struct('value', 0.05));
    o = hetlearn.load_options(cfg, master);
    ok = o.gain.value == 0.05 && o.switching.intensity == 4 && o.switching.memory == 0.6;
    R = add(R, 'opt: merge order defaults < master < cfg', ok, ...
        sprintf('gain %.2f, chi %g, omega %.1f', o.gain.value, o.switching.intensity, o.switching.memory));
catch err
    R = add(R, 'opt: merge order defaults < master < cfg', false, err.message);
end

% the real config/master_options.m is found and merges (the test copy tests/scenarios/master_options.m,
% which shadows it during the tests, is taken off the path for this check, 2026-10-20)
ts = fullfile(fileparts(mfilename('fullpath')), 'scenarios');
onp = any(strcmpi(strsplit(path, pathsep), ts));
try
    if onp
        rmpath(ts);
    end
    % the live baseline sets expectations.re_info = 'lagged' (2026-10-20), which needs a learning set
    o = hetlearn.load_options(struct('id', 'x', 'expectations', struct('variables', {{'pinf'}})));
    live = which('master_options');
    if onp
        addpath(ts);
    end
    R = add(R, 'opt: config/master_options.m loads', strcmp(o.id, 'x') ...
        && contains(live, [filesep 'config' filesep 'master_options.m']), live);
catch err
    if onp
        addpath(ts);
    end
    R = add(R, 'opt: config/master_options.m loads', false, err.message);
end
% model_params (2026-10-20): '' by default, a function name, or an error for a bad name
try
    o = hetlearn.load_options(struct('model_params', "sw07_params_original"), struct());
    d = hetlearn.defaults();
    R = add(R, 'opt: model_params default '''' and string input becomes char', ...
        ischar(o.model_params) && strcmp(o.model_params, 'sw07_params_original') && isempty(d.model_params), '');
catch err
    R = add(R, 'opt: model_params default '''' and string input becomes char', false, err.message);
end
R = expect_error(R, 'opt: model_params must be a function name', ...
    @() hetlearn.load_options(struct('model_params', 'sw07 params'), struct()), 'model_params');

% unknown fields
R = expect_error(R, 'opt: typo beliefs.plm.defualt rejected with full path', ...
    @() hetlearn.load_options(struct('beliefs', struct('plm', struct('defualt', 'ar2'))), struct()), ...
    'beliefs.plm.defualt');
R = expect_error(R, 'opt: unknown top-level field rejected', ...
    @() hetlearn.load_options(struct('horizon', 8), struct()), '"horizon"');
R = expect_error(R, 'opt: typo in master rejected', ...
    @() hetlearn.load_options(struct(), struct('switching', struct('intensty', 3))), 'switching.intensty');
R = expect_error(R, 'opt: group given as a number rejected', ...
    @() hetlearn.load_options(struct('gain', 0.05), struct()), 'gain');

% enumerations and ranges
R = expect_error(R, 'opt: bad expectations.mode rejected', ...
    @() hetlearn.load_options(struct('expectations', struct('mode', 'switchng')), struct()), 'expectations.mode');
R = expect_error(R, 'opt: bad shares.structure rejected', ...
    @() hetlearn.load_options(struct('shares', struct('structure', 'global')), struct()), 'shares.structure');
R = expect_error(R, 'opt: bad gain.rule rejected', ...
    @() hetlearn.load_options(struct('gain', struct('rule', 'decreasing')), struct()), 'gain.rule');
R = expect_error(R, 'opt: switching.memory = 1 rejected', ...
    @() hetlearn.load_options(struct('switching', struct('memory', 1)), struct()), 'switching.memory');
R = expect_error(R, 'opt: hetero_filter reported as not implemented', ...
    @() hetlearn.load_options(struct('history', struct('mode', 'hetero_filter')), struct()), 'not implemented');
R = expect_error(R, 'opt: fixed_shares without shares.fixed_n2 rejected', ...
    @() hetlearn.load_options(struct('expectations', struct('mode', 'fixed_shares')), struct()), 'fixed_n2');

% free-form subtrees and conversions
try
    cfg = struct();
    cfg.beliefs.plm.by_var.pinf = struct('regressors', {{'pinf{-1}', 'w{-1}'}}, 'constant', true);
    cfg.beliefs.init.values.pinf = struct('alpha', 0.1, 'beta', 0.5);
    cfg.gain.by_var.pinf = 0.02;
    cfg.shares.fixed_n2 = struct('pinf', 0.3);
    cfg.expectations.mode = 'fixed_shares';
    cfg.expectations.variables = "pinf";
    cfg.report = struct('variables', 'pinf', 'anything', 1);
    cfg.shocks.add = {{'e_r', 1, 0.25}};
    cfg.conditions = struct('variable', 'robs', 'shock', 'e_r', 'dates', 1, 'values', 0, ...
        'type', 'level', 'reference', 'self');
    o = hetlearn.load_options(cfg, struct('gain', struct('by_var', struct('y', 0.01))));
    ok = isfield(o.beliefs.plm.by_var, 'pinf') && o.gain.by_var.pinf == 0.02 && o.gain.by_var.y == 0.01 ...
        && o.shares.fixed_n2.pinf == 0.3 && isequal(o.expectations.variables, {'pinf'}) ...
        && isequal(o.report.variables, {'pinf'}) && o.report.anything == 1 && numel(o.conditions) == 1;
    R = add(R, 'opt: free-form subtrees merge unvalidated; strings converted', ok, '');
catch err
    R = add(R, 'opt: free-form subtrees merge unvalidated; strings converted', false, err.message);
end
end


% -------------------------------------------------------------------------
function R = expect_error(R, name, f, needle)
try
    f();
    R = add(R, name, false, 'no error raised');
catch err
    R = add(R, name, contains(err.message, needle), err.message);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
