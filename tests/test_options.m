function R = test_options()
%TEST_OPTIONS  Option tree, merge order and validation (hetlearn.defaults, load_options).
%
%   R = test_options()   returns a struct array of checks (name, pass, msg).
%
%   28 checks: defaults, removed and unknown options, enumerations and ranges, merge
%   order, free-form subtrees; BR1-BR4 the bounded-rationality options of the
%   seven further expectation rules: defaults, the
%   seven rules and their scenario files load, malformed and removed settings are
%   rejected, Ramsey and the inversion refuse the N-type path.

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

% options that are no longer supported: a helpful error naming projection.facility
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
            && contains(err.message, sprintf('Option "%s" is no longer supported', full)) ...
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
% which shadows it during the tests, is taken off the path for this check)
ts = fullfile(fileparts(mfilename('fullpath')), 'scenarios');
onp = any(strcmpi(strsplit(path, pathsep), ts));
try
    if onp
        rmpath(ts);
    end
    % the live baseline sets expectations.re_info = 'lagged', which needs a learning set
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
% model_params: '' by default, a function name, or an error for a bad name
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
    @() hetlearn.load_options(struct('gain', struct('rule', 'no_such_rule')), struct()), 'gain.rule');
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

% bounded-rationality extensions (the seven further expectation rules, docs/USER_GUIDE.md section 7)
R = br_schema(R);
end


% -------------------------------------------------------------------------
function R = br_schema(R)
% BR1 defaults off and idempotent; BR2 the seven portfolio variants (written out here and read
% from their scenario files) and the RE/BR pair spelled out pass validation and load; BR3 bad values,
% and the options, kinds, fields and values that are no longer supported, are rejected by the
% validation; BR4 Ramsey and the inversion with the N-type path stop with hetlearn:options:unsupported.
nm = 'opt BR1: BR options present and off by default; load_options(struct()) passes and is idempotent';
try
    d = hetlearn.defaults();
    ok = isempty(d.expectations.types) && isstruct(d.expectations.types) ...
        && isequal(fieldnames(d.expectations.types)', {'name', 'kind', 'rule'}) && isempty(d.expectations.transforms) ...
        && isequal(fieldnames(d.expectations.transforms)', {'kind', 'types', 'scope', 'exclude', 'value'}) ...
        && isempty(d.shares.init) && isempty(d.shares.fixed) ...
        && isequal(sort(fieldnames(d.switching))', sort({'rule', 'intensity', 'memory'})) ...
        && ~isfield(d.beliefs, 'kf') && isequal(d.gain.decreasing, struct('t0', 0)) ...
        && strcmp(d.history.kalman.init, 'stochastic') && strcmp(d.beliefs.update, 'rls') ...
        && strcmp(d.gain.rule, 'constant') && strcmp(d.history.mode, 're_smoother');
    o = hetlearn.load_options(struct(), struct());
    o2 = hetlearn.load_options(o, struct());
    ok = ok && isequaln(o2, o) && isequaln(o.expectations.types, d.expectations.types) ...
        && isequaln(o.expectations.transforms, d.expectations.transforms) ...
        && isequaln(o.shares.init, d.shares.init) && isequaln(o.shares.fixed, d.shares.fixed) ...
        && isequaln(o.switching, d.switching) && isequaln(o.history.kalman, d.history.kalman);
    R = add(R, nm, ok, '');
catch err
    R = add(R, nm, false, err.message);
end

FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
T = @(varargin) struct(varargin{:});
c = struct('expectations', struct('mode', 'switching', 'variables', {{'pinf'}}));
V = {};      % {name, cfg}: the settings of the seven rules (docs/USER_GUIDE.md section 7.7)
x = c; x.expectations.transforms = struct('kind', 'multiplier', 'types', 'all', 'value', 0.94, 'scope', 'learning', ...
    'exclude', {FLEX});
V(end+1, :) = {'br05b', x};
x = c; x.expectations.transforms = struct('kind', 'myopia_anchoring', 'types', 'all', 'value', [0.52 0.434], ...
    'scope', {{'pinf@Phillips curve, price setting'}});
V(end+1, :) = {'br07', x};
x = c; x.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', ...
    'exclude', {FLEX});
V(end+1, :) = {'br10', x};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm'), ...
    T('name', 'TB', 'kind', 'rule', 'rule', '0')};
x.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
V(end+1, :) = {'br19', x};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'IO', 'kind', 're_mean')};
V(end+1, :) = {'br23', x};
x = c; x.beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true);
V(end+1, :) = {'br24', x};
x = c; x.gain = struct('rule', 'constant', 'value', 0.018);
V(end+1, :) = {'br26', x};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm')};
x.history.kalman.init = 'smoothed';
V(end+1, :) = {'RE/BR spelled out', x};
bad = {};
for i = 1:size(V, 1)
    try
        hetlearn.load_options(V{i, 2}, struct());
    catch err
        bad{end+1} = sprintf('%s: %s %s', V{i, 1}, err.identifier, err.message); %#ok<AGROW>
    end
end
% the scenario files: scenarios/sw07/br_portfolio holds exactly the seven variants, and each loads
keep = {'br05b_cd_learn', 'br07_myopia_anchoring', 'br10_diagnostic', 'br19_target_believers', ...
    'br23_intercept_only', 'br24_mean_only', 'br26_experience'};
pf = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'scenarios', 'sw07', 'br_portfolio');
f = dir(fullfile(pf, 'br*.m'));
have = sort(regexprep({f.name}, '\.m$', ''));
if ~isequal(have, sort(keep))
    bad{end+1} = sprintf('scenarios/sw07/br_portfolio holds {%s}, not the seven variants', strjoin(have, ', '));
end
for i = 1:numel(keep)
    if exist(fullfile(pf, [keep{i} '.m']), 'file') ~= 2
        continue                                   % reported above
    end
    try
        hetlearn.load_options(feval(keep{i}));
    catch err
        bad{end+1} = sprintf('%s.m: %s %s', keep{i}, err.identifier, err.message); %#ok<AGROW>
    end
end
R = add(R, sprintf(['opt BR2: %d configurations (the portfolio variants %s written out, RE/BR spelled out) ' ...
    'and the %d scenario files of scenarios/sw07/br_portfolio pass validation and load'], size(V, 1), ...
    strjoin(V(1:end-1, 1)', ', '), numel(keep)), isempty(bad), strjoin(bad, ' | '));

E = {};      % {name, cfg, accepted identifiers}
idT = {'hetlearn:options:types'};
idX = {'hetlearn:options:transforms'};
idV = {'hetlearn:options:value'};
rm = 'hetlearn:options:removed';                 % a helpful error for a removed name is also accepted
idU = {'hetlearn:options:unknown', rm};          % options that are no longer supported: unknown fields
x = c; x.expectations.types = T('name', 'A', 'kind', 'heuristic');
E(end+1, :) = {'unknown kind', x, idT};
x = c; x.expectations.types = T('name', 'A', 'kind', 'plm', 'gainn', 0.1);
E(end+1, :) = {'unknown type field', x, idT};
x = c; x.expectations.types = {T('name', 'A', 'kind', 'plm'), T('name', 'A', 'kind', 'plm')};
E(end+1, :) = {'repeated name', x, idT};
x = c; x.expectations.types = T('name', 'B_R', 'kind', 'plm');
E(end+1, :) = {'name with underscore', x, idT};
x = c; x.expectations.types = T('name', 'RE', 'kind', 'plm');
E(end+1, :) = {'RE of kind plm', x, idT};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'OPT', 'kind', 're')};
E(end+1, :) = {'a second type of kind re', x, idT};
x = c; x.expectations.types = T('name', 'A', 'kind', 'plm', 'rule', '0');
E(end+1, :) = {'rule on a plm type', x, idT};
x = c; x.expectations.types = T('name', 'A', 'kind', 'rule');
E(end+1, :) = {'rule type without rule', x, idT};
x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'L1', 'kind', 'level')};
E(end+1, :) = {'kind level (removed)', x, [idT, {rm}]};
% the per-type fields that are no longer supported (every type inherits the global settings)
gone = {'variant', 'model_consistent'; 'info', 'current'; 'plm', 'ar2'; 'update', 'fixed'; ...
    'gain', struct('value', 0.01); 'variables', {'pinf'}; 'cost', 0.1; 'base', 'RE'; 'k', 1};
for i = 1:size(gone, 1)
    t = T('name', 'BR', 'kind', 'plm');
    t.(gone{i, 1}) = gone{i, 2};
    x = c; x.expectations.types = {T('name', 'RE', 'kind', 're'), t};
    E(end+1, :) = {sprintf('type field %s (removed)', gone{i, 1}), x, [idT, {rm}]}; %#ok<AGROW>
end
x = c; x.expectations.transforms = struct('kind', 'multiplier', 'types', {{'XX'}}, 'value', 0.5);
E(end+1, :) = {'transform on an unknown type', x, idX};
x = c; x.expectations.transforms = struct('kind', 'wedge', 'value', []);
E(end+1, :) = {'transform kind wedge (removed)', x, [idX, {rm}]};
x = c; x.expectations.transforms = struct('kind', 'partial_adjustment', 'value', 0.5);
E(end+1, :) = {'transform kind partial_adjustment (removed)', x, [idX, {rm}]};
x = c; x.expectations.transforms = struct('kind', 'multiplier', 'value', 0.9, 'profile', 'flat');
E(end+1, :) = {'transform field profile = flat (removed; [] and geometric are dropped)', x, [idX, {rm}]};
x = c; x.expectations.transforms = struct('kind', 'multiplier', 'value', 0.9, 'factor', struct('mean', 0));
E(end+1, :) = {'transform field factor (removed)', x, [idX, {rm}]};
x = c; x.shares.init = struct('RE', 0.6, 'BR', 0.6);
E(end+1, :) = {'shares.init not summing to 1', x, idV};
x = c; x.shares.init = struct('BR', 1);
E(end+1, :) = {'shares.init without RE (default pair)', x, idV};
x = c; x.switching.costs = struct('BR', 0.1);
E(end+1, :) = {'switching.costs (removed)', x, idU};
x = c; x.switching.inertia = 0.5;
E(end+1, :) = {'switching.inertia (removed)', x, idU};
x = c; x.switching.fitness = 'unnormalized';
E(end+1, :) = {'switching.fitness (removed)', x, idU};
x = c; x.switching.intensity = 'model:bma';
E(end+1, :) = {'switching.intensity model:bma (removed)', x, [idV, {rm}]};
x = c; x.beliefs.update = 'sac';
E(end+1, :) = {'beliefs.update sac (removed)', x, [idV, {rm}]};
x = c; x.beliefs.update = 'kf';
E(end+1, :) = {'beliefs.update kf (removed)', x, [idV, {rm}]};
x = c; x.beliefs.kf = struct('gamma', 0.031);
E(end+1, :) = {'beliefs.kf (removed)', x, idU};
x = c; x.gain.rule = 'decreasing'; x.gain.decreasing.t0 = -1;
E(end+1, :) = {'gain.decreasing.t0 negative', x, idV};
x = c; x.gain.decreasing = struct('n0', 5);
E(end+1, :) = {'gain.decreasing.n0 off its old default (removed)', x, idU};
x = c; x.history.mode = 'kalman'; x.history.re_states = 'filtered';
E(end+1, :) = {'kalman with filtered RE states', x, idV};
x = c; x.history.kalman.init = 'zero';
E(end+1, :) = {'unknown kalman init', x, idV};
x = c; x.expectations.mode = 'fixed_shares'; x.shares.fixed_n2 = 0.5; x.shares.fixed = struct('RE', 0.5, 'BR', 0.5);
E(end+1, :) = {'fixed_n2 and fixed both set', x, idV};
bad = {};
for i = 1:size(E, 1)
    try
        hetlearn.load_options(E{i, 2}, struct());
        bad{end+1} = [E{i, 1} ': no error']; %#ok<AGROW>
    catch err
        if ~ismember(err.identifier, E{i, 3})
            bad{end+1} = sprintf('%s: %s %s', E{i, 1}, err.identifier, err.message); %#ok<AGROW>
        end
    end
end
R = add(R, sprintf(['opt BR3: %d malformed BR settings and settings no longer supported rejected by the ' ...
    'validation (types, transforms, value, unknown option)'], size(E, 1)), isempty(bad), strjoin(bad, ' | '));

% BR4: stages without the N-type path stop with hetlearn:options:unsupported, naming the options
U = {};      % {name, cfg, expected word in the message ('' = loads)}
tb = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm'), T('name', 'TB', 'kind', 'rule', 'rule', '0')};
cd10 = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', 'exclude', {FLEX});
x = c; x.policy.mode = 'ramsey'; x.expectations.types = tb;
U(end+1, :) = {'Ramsey with N types', x, 'expectations.types'};
x = c; x.policy.mode = 'ramsey'; x.expectations.transforms = cd10;
U(end+1, :) = {'Ramsey with a transform', x, 'expectations.transforms'};
x = c; x.policy.mode = 'ramsey'; x.shares.init = struct('RE', 0.5, 'BR', 0.5);
U(end+1, :) = {'Ramsey with shares.init', x, 'shares.init'};
x = c; x.history.mode = 'inversion'; x.expectations.types = tb;
U(end+1, :) = {'inversion with N types', x, 'expectations.types'};
x = c; x.history.mode = 'inversion'; x.shares.init = struct('RE', 0.5, 'BR', 0.5);
U(end+1, :) = {'inversion with shares.init', x, 'shares.init'};
x = c; x.policy.mode = 'ramsey';
U(end+1, :) = {'Ramsey, two types (loads)', x, ''};
x = c; x.history.mode = 'inversion';
U(end+1, :) = {'inversion, two types (loads)', x, ''};
x = c; x.history.mode = 'kalman'; x.expectations.types = tb; x.density.enabled = true; x.density.shocks = {'em'};
U(end+1, :) = {'Kalman and density with N types (load)', x, ''};
bad = {};
for i = 1:size(U, 1)
    try
        hetlearn.load_options(U{i, 2}, struct());
        if ~isempty(U{i, 3})
            bad{end+1} = [U{i, 1} ': no error']; %#ok<AGROW>
        end
    catch err
        if isempty(U{i, 3}) || ~strcmp(err.identifier, 'hetlearn:options:unsupported') || ~contains(err.message, U{i, 3})
            bad{end+1} = sprintf('%s: %s %s', U{i, 1}, err.identifier, err.message); %#ok<AGROW>
        end
    end
end
R = add(R, sprintf(['opt BR4: Ramsey and the inversion with N types, transforms or shares.init stop with ' ...
    'hetlearn:options:unsupported naming them; %d cases (the two-type runs and the Kalman and density stages ' ...
    'with N types load)'], size(U, 1)), isempty(bad), strjoin(bad, ' | '));
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
