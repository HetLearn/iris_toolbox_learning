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

% bounded-rationality extensions (docs/DESIGN_br_extensions.md; option schema of phase P0, 2026-10-20)
R = br_schema(R);
end


% -------------------------------------------------------------------------
function R = br_schema(R)
% BR1 defaults off and idempotent; BR2 the portfolio variants of DESIGN_br_extensions sec. 3 pass
% validation and stop with hetlearn:options:notImplemented naming exactly their phases; BR3 bad
% values are rejected by the validation, before the not-implemented guard.
nm = 'opt BR1: BR options present and off by default; load_options(struct()) passes and is idempotent';
try
    d = hetlearn.defaults();
    ok = isempty(d.expectations.types) && isstruct(d.expectations.types) ...
        && isequal(fieldnames(d.expectations.types)', {'name', 'kind', 'variant', 'info', 'plm', 'update', ...
        'gain', 'rule', 'base', 'k', 'variables', 'cost'}) && isempty(d.expectations.transforms) ...
        && isequal(fieldnames(d.expectations.transforms)', {'kind', 'types', 'scope', 'exclude', 'profile', ...
        'value', 'factor'}) && isempty(d.shares.init) && isempty(d.shares.fixed) && d.switching.inertia == 0 ...
        && isempty(d.switching.costs) && strcmp(d.switching.fitness, 'normalized') ...
        && isempty(d.beliefs.kf.gamma) && strcmp(d.beliefs.kf.s2, 're_moments') && d.gain.decreasing.n0 == 1 ...
        && strcmp(d.history.kalman.init, 'stochastic') && strcmp(d.beliefs.update, 'rls') ...
        && strcmp(d.gain.rule, 'constant') && strcmp(d.history.mode, 're_smoother');
    o = hetlearn.load_options(struct(), struct());
    o2 = hetlearn.load_options(o, struct());
    ok = ok && isequaln(o2, o) && isequaln(o.expectations.types, d.expectations.types) ...
        && isequaln(o.expectations.transforms, d.expectations.transforms) && isequaln(o.beliefs.kf, d.beliefs.kf) ...
        && isequaln(o.shares.init, d.shares.init) && isequaln(o.shares.fixed, d.shares.fixed) ...
        && isequaln(o.switching, d.switching) && isequaln(o.gain.decreasing, d.gain.decreasing) ...
        && isequaln(o.history.kalman, d.history.kalman);
    R = add(R, nm, ok, '');
catch err
    R = add(R, nm, false, err.message);
end

ST7 = {'inve', 'pk', 'rk', 'c', 'lab', 'pinf', 'w'};
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
T = @(varargin) struct(varargin{:});
reg = @(r) struct('by_var', struct('pinf', struct('regressors', {r}, 'constant', true)));
mult = @(v, sc) struct('kind', 'multiplier', 'profile', 'flat', 'types', {{'RE'}}, 'value', v, 'scope', {sc});
V = {};      % {name, cfg, expected phases ({} = loads)}
c = struct('expectations', struct('mode', 'switching', 'variables', {{'pinf'}}));
x = c; x.expectations.types = {T('name', 'L0', 'kind', 'plm'), T('name', 'L1', 'kind', 'level', 'base', 'L0', 'k', 1), ...
    T('name', 'L2', 'kind', 'level', 'base', 'L0', 'k', 2)};
x.shares.init = struct('L0', 1/3, 'L1', 1/3, 'L2', 1/3);
V(end+1, :) = {'br01a', x, {'P2', 'P4'}};
x = c; x.expectations.mode = 'fixed_shares';
x.expectations.types = {T('name', 'L0', 'kind', 'plm'), T('name', 'L2', 'kind', 'level', 'base', 'L0', 'k', 2)};
x.shares.fixed = struct('L0', 0, 'L2', 1);
V(end+1, :) = {'br01b', x, {'P2', 'P4'}};
x = c; x.expectations.transforms = [mult(0.76, {'c', 'lab', 'inve', 'pk', 'rk'}), ...
    mult(0.86, {'w', 'pinf@Phillips curve, price setting', 'pinf@Wage Phillips curve, wage setting'}), ...
    mult(0.08, {'pinf@Consumption Euler equation', 'pinf@Arbitrage equation for the value of capital'})];
V(end+1, :) = {'br04', x, {'P3'}};
cd5 = struct('kind', 'multiplier', 'profile', 'geometric', 'types', 'all', 'value', 0.62, 'scope', 'all', ...
    'exclude', {FLEX});
x = c; x.expectations.transforms = cd5;
V(end+1, :) = {'br05a', x, {'P3'}};
x = c; x.expectations.transforms = setfield(setfield(cd5, 'value', 0.94), 'scope', 'learning'); %#ok<SFLD>
V(end+1, :) = {'br05b', x, {'P3'}};
x = c; x.expectations.transforms = setfield(setfield(cd5, 'profile', 'hyperbolic'), 'value', 0.25); %#ok<SFLD>
V(end+1, :) = {'br06', x, {'P3'}};
x = c; x.expectations.transforms = struct('kind', 'myopia_anchoring', 'types', 'all', 'value', [0.52 0.434], ...
    'scope', {{'pinf@Phillips curve, price setting'}});
V(end+1, :) = {'br07', x, {'P3'}};
x = c; x.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', ...
    'exclude', {FLEX});
V(end+1, :) = {'br10', x, {'P3'}};
x = c; x.expectations.types = {T('name', 'ADA', 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*self{-1}'), ...
    T('name', 'WTR', 'kind', 'rule', 'rule', 'x{-1} + 0.4*(x{-1} - x{-2})'), ...
    T('name', 'STR', 'kind', 'rule', 'rule', 'x{-1} + 1.3*(x{-1} - x{-2})'), ...
    T('name', 'LAA', 'kind', 'rule', 'rule', '0.5*(mean + x{-1}) + (x{-1} - x{-2})', 'gain', struct('rule', 'decreasing'))};
x.switching = struct('intensity', 0.4, 'memory', 0.7, 'inertia', 0.9, 'fitness', 'unnormalized');
x.shares.init = struct('ADA', 0.25, 'WTR', 0.25, 'STR', 0.25, 'LAA', 0.25);
V(end+1, :) = {'br17', x, {'P2', 'P5'}};
x = c; x.expectations.variables = {'pinf', 'c'};
x.expectations.types = {T('name', 'TAR', 'kind', 'rule', 'rule', '0', 'variables', {{'pinf'}}), ...
    T('name', 'EXT', 'kind', 'rule', 'rule', 'x{-1}', 'variables', {{'pinf'}}), ...
    T('name', 'OPT', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}}), ...
    T('name', 'PES', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}})};
x.expectations.transforms = [struct('kind', 'wedge', 'types', {{'OPT'}}, 'factor', struct('mean', 'model:sd_ygap_half')), ...
    struct('kind', 'wedge', 'types', {{'PES'}}, 'factor', struct('mean', '-model:sd_ygap_half'))];
V(end+1, :) = {'br18', x, {'P2', 'P3'}};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm'), ...
    T('name', 'TB', 'kind', 'rule', 'rule', '0')};
x.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
V(end+1, :) = {'br19', x, {'P2'}};
x = c; x.expectations.variables = ST7; x.expectations.mode = 'learning';
x.beliefs.update = 'sac'; x.gain = struct('rule', 'constant', 'value', 0.006);
V(end+1, :) = {'br20', x, {'P5'}};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'IO', 'kind', 're_mean')};
V(end+1, :) = {'br23', x, {'P2', 'P4', 'P5'}};
x = c; x.beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true);
V(end+1, :) = {'br24 (existing options)', x, {}};
x = c; x.expectations.variables = ST7; x.expectations.mode = 'learning';
x.beliefs.plm.default = 'ar2'; x.beliefs.update = 'kf'; x.beliefs.kf = struct('gamma', 0.031);
V(end+1, :) = {'br25a', x, {'P5'}};
x = c; x.expectations.variables = ST7; x.expectations.mode = 'fixed_shares';
x.expectations.types = {T('name', 'M1', 'kind', 'plm', 'update', 'kf'), ...
    T('name', 'M2', 'kind', 'plm', 'plm', reg({'pinf{-1}', 'r{-1}'}), 'update', 'kf'), ...
    T('name', 'M3', 'kind', 'plm', 'plm', 'ar2', 'update', 'kf'), ...
    T('name', 'M4', 'kind', 'plm', 'plm', reg({'pinf{-1}'}), 'update', 'kf'), ...
    T('name', 'M5', 'kind', 'plm', 'plm', reg({'pinf{-1}', 'r{-1}', 'y{-1}'}), 'update', 'kf')};
x.shares.fixed = struct('M1', 0.2, 'M2', 0.2, 'M3', 0.2, 'M4', 0.2, 'M5', 0.2);
V(end+1, :) = {'br25b', x, {'P2', 'P5'}};
x = c; x.gain = struct('rule', 'constant', 'value', 0.018);
V(end+1, :) = {'br26 (existing options)', x, {}};
x = c; x.switching = struct('fitness', 'unnormalized', 'memory', 1, 'intensity', 'model:bma');
V(end+1, :) = {'br27', x, {'P2'}};
x = c; x.expectations.transforms = struct('kind', 'wedge', 'types', 'all', 'scope', {{'pinf'}}, ...
    'factor', struct('rho', 0.714, 'std', 0.182, 'mean', 0, 'shock', 'e_wpinf'));
V(end+1, :) = {'br29', x, {'P3'}};
x = c; x.expectations.transforms = struct('kind', 'wedge', 'types', 'all', 'scope', {{'c', 'inve', 'lab'}}, ...
    'factor', struct('rho', 0.833, 'std', 'model:acd51', 'loadings', 'model:projection', 'shock', 'e_xi'));
V(end+1, :) = {'br31', x, {'P3'}};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'FN', 'kind', 'rule', 'rule', 'dn{-1} - re1(y{+1} - y)')};
V(end+1, :) = {'br33', x, {'P2', 'P4'}};
x = c; x.history.mode = 'kalman';
V(end+1, :) = {'kalman', x, {'P1'}};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm')};
x.switching.costs = struct('BR', 0.1);
x.history.kalman.init = 'smoothed';
V(end+1, :) = {'RE/BR spelled out, BR cost', x, {'P2'}};
bad = {};
for i = 1:size(V, 1)
    try
        hetlearn.load_options(V{i, 2}, struct());
        if ~isempty(V{i, 3})
            bad{end+1} = [V{i, 1} ': no error']; %#ok<AGROW>
        end
    catch err
        ph = unique(regexp(err.message, 'P\d', 'match'));
        if ~(strcmp(err.identifier, 'hetlearn:options:notImplemented') && isequal(ph, sort(V{i, 3})))
            bad{end+1} = sprintf('%s: %s [%s] %s', V{i, 1}, err.identifier, strjoin(ph, ','), err.message); %#ok<AGROW>
        end
    end
end
R = add(R, sprintf(['opt BR2: %d configurations (the portfolio variants of DESIGN_br_extensions sec. 3, ' ...
    'history.mode kalman, RE/BR spelled out) pass validation and stop with notImplemented naming exactly ' ...
    'their phases (br24, br26: existing options, they load)'], size(V, 1)), isempty(bad), strjoin(bad, ' | '));

E = {};      % {name, cfg, expected identifier}
x = c; x.expectations.types = T('name', 'A', 'kind', 'heuristic');
E(end+1, :) = {'unknown kind', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'A', 'kind', 'plm', 'gainn', 0.1);
E(end+1, :) = {'unknown type field', x, 'hetlearn:options:types'};
x = c; x.expectations.types = {T('name', 'A', 'kind', 'plm'), T('name', 'A', 'kind', 're')};
E(end+1, :) = {'repeated name', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'R_E', 'kind', 're');
E(end+1, :) = {'name with underscore', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'RE', 'kind', 'plm');
E(end+1, :) = {'RE of kind plm', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'A', 'kind', 'plm', 'rule', '0');
E(end+1, :) = {'rule on a plm type', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'A', 'kind', 'rule');
E(end+1, :) = {'rule type without rule', x, 'hetlearn:options:types'};
x = c; x.expectations.types = {T('name', 'L1', 'kind', 'level', 'base', 'L0', 'k', 1)};
E(end+1, :) = {'level base not a type', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'A', 'kind', 'plm', 'variables', {{'y'}});
E(end+1, :) = {'type variable outside the learning set', x, 'hetlearn:options:types'};
x = c; x.expectations.types = T('name', 'A', 'kind', 'plm', 'gain', struct('value', 2));
E(end+1, :) = {'type gain out of range', x, 'hetlearn:options:types'};
x = c; x.expectations.transforms = struct('kind', 'multiplier', 'types', {{'XX'}}, 'value', 0.5);
E(end+1, :) = {'transform on an unknown type', x, 'hetlearn:options:transforms'};
x = c; x.expectations.transforms = struct('kind', 'wedge', 'factor', struct('std', 0.1));
E(end+1, :) = {'wedge with std > 0 and no shock', x, 'hetlearn:options:transforms'};
x = c; x.expectations.transforms = struct('kind', 'diagnostic', 'value', 0.44, 'profile', 'flat');
E(end+1, :) = {'profile on a diagnostic', x, 'hetlearn:options:transforms'};
x = c; x.shares.init = struct('RE', 0.6, 'BR', 0.6);
E(end+1, :) = {'shares.init not summing to 1', x, 'hetlearn:options:value'};
x = c; x.shares.init = struct('BR', 1);
E(end+1, :) = {'shares.init without RE (default pair)', x, 'hetlearn:options:value'};
x = c; x.switching.costs = struct('XX', 0.1);
E(end+1, :) = {'cost of an unknown type', x, 'hetlearn:options:value'};
x = c; x.switching.inertia = 1;
E(end+1, :) = {'inertia 1', x, 'hetlearn:options:value'};
x = c; x.switching.fitness = 'raw';
E(end+1, :) = {'unknown fitness', x, 'hetlearn:options:value'};
x = c; x.switching.intensity = 'bma';
E(end+1, :) = {'intensity string without model:', x, 'hetlearn:options:value'};
x = c; x.beliefs.kf.gamma = 1;
E(end+1, :) = {'kf gamma 1', x, 'hetlearn:options:value'};
x = c; x.gain.decreasing.n0 = 0.5;
E(end+1, :) = {'decreasing n0 < 1', x, 'hetlearn:options:value'};
x = c; x.history.mode = 'kalman'; x.history.re_states = 'filtered';
E(end+1, :) = {'kalman with filtered RE states', x, 'hetlearn:options:value'};
x = c; x.history.kalman.init = 'zero';
E(end+1, :) = {'unknown kalman init', x, 'hetlearn:options:value'};
x = c; x.expectations.mode = 'fixed_shares'; x.shares.fixed_n2 = 0.5; x.shares.fixed = struct('RE', 0.5, 'BR', 0.5);
E(end+1, :) = {'fixed_n2 and fixed both set', x, 'hetlearn:options:value'};
bad = {};
for i = 1:size(E, 1)
    try
        hetlearn.load_options(E{i, 2}, struct());
        bad{end+1} = [E{i, 1} ': no error']; %#ok<AGROW>
    catch err
        if ~strcmp(err.identifier, E{i, 3})
            bad{end+1} = sprintf('%s: %s %s', E{i, 1}, err.identifier, err.message); %#ok<AGROW>
        end
    end
end
R = add(R, sprintf('opt BR3: %d malformed BR settings rejected by the validation (types, transforms, value)', ...
    size(E, 1)), isempty(bad), strjoin(bad, ' | '));
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
