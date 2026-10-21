function opts = load_options(cfg, master)
%LOAD_OPTIONS  Merge defaults < config/master_options.m < cfg and validate.
%
%   opts = hetlearn.load_options(cfg)
%   opts = hetlearn.load_options(cfg, master)
%
%   Inputs
%     cfg     struct (partial option tree) from a scenario file; may be
%             omitted or empty.
%     master  optional struct used instead of calling master_options() (for
%             tests). When omitted, master_options() is called if it is on
%             the path or in <project root>/config/.
%
%   Output
%     opts    the full merged option tree (same fields as hetlearn.defaults).
%
%   Merge rules
%     - Recursive, field by field. A field that does not exist in the
%       defaults raises an error naming the full path, e.g.
%       'Unknown option "beliefs.plm.defualt"'.
%     - Free-form subtrees are merged without checking names:
%       beliefs.init.values, beliefs.plm.by_var, beliefs.plm.derived,
%       gain.by_var, shares.fixed_n2 (when a struct), shocks.add, report.
%       conditions is replaced as a whole (struct array).
%     - Strings are converted to char; a char given where a cellstr is
%       expected (expectations.variables other than 'all', shares.master,
%       compare_with, shocks.exclude, report.variables) becomes {char}.
%
%   Validation (errors with identifier hetlearn:options:*)
%     enumerations (expectations.mode, expectations.re_variant,
%     expectations.re_info ('current' | 'lagged'),
%     beliefs.update, beliefs.plm.default, beliefs.init.method,
%     shares.structure, projection.facility ('plm_alm' | 'alm' | 'none'),
%     history.mode, history.re_states ('smoothed' | 'filtered'),
%     shocks.source); gain.rule and switching.rule must name an existing
%     function hetlearn.gain.<rule> / hetlearn.switching.<rule>; numeric
%     ranges (gain.value in (0,1], switching.memory in [0,1),
%     switching.intensity >= 0, shares.init_n2 in [0,1],
%     forecast.horizon positive integer); model_params '' or a valid
%     function name (that the package folder has it is checked by
%     hetlearn.load_model, 2026-10-20);
%     cross-field: 'fixed_shares' needs shares.fixed_n2, 'universal'
%     needs shares.master, 'training_ols' needs beliefs.init.training_range,
%     history.re_states = 'filtered' needs history.mode = 're_smoother'
%     (the inversion is one-sided already); expectations.re_info =
%     'lagged' needs a non-empty learning set and is not supported with
%     policy.mode = 'ramsey' (hetlearn:options:unsupported, DESIGN 19).
%     gain.koz.*: structure 'common' | 'per_variable', error 'rls' |
%     'forecast', mu >= 0, error_scale > 0, Rg0 finite, bounds [lower
%     upper] with 0 < lower <= upper <= 1, gamma0 [] or in (0, 1], master
%     valid names (normalised to a cellstr); with gain.rule = 'koz' the
%     initial gain (gamma0, or gain.value and with 'per_variable' the
%     gain.by_var values) must lie inside the bounds. That master names PLM
%     targets is checked by hetlearn.gain.koz (the model is not known here).
%     beliefs.plm.derived must hold non-empty strings under valid names;
%     beliefs.plm.var.variables a cellstr or 'learning', .lags a positive
%     integer, .constant true/false; default 'var1' with var.variables set
%     is an error. Names and expressions are checked against the model by
%     hetlearn.extend_model / hetlearn.plm.build_system.
%
%   Bounded-rationality extensions (docs/DESIGN_br_extensions.md, schema of
%   phase P0, 2026-10-20; every option defaults to off)
%     expectations.types: a struct array or a cell array of structs,
%     normalised to a 1xN struct array with every field (missing ones []);
%     unknown fields, names that are not letters and digits or not unique,
%     an unknown kind, fields that do not apply to the kind, missing
%     required fields (rule; base and k), bad values, variables outside a
%     cellstr learning set and a type 'RE' of another kind are errors
%     (hetlearn:options:types). A type's gain is merged over gain and
%     checked like it. expectations.transforms: normalised the same way
%     (types [] = 'all', scope [] = 'learning', profile [] = 'geometric'
%     for a multiplier, factor completed for a wedge); kind, types (names of
%     the population, 'RE' always allowed), scope entries ('x' or
%     'x@<label>'), values by kind, wedge factors and unique wedge shocks
%     are checked (hetlearn:options:transforms). shares.init, shares.fixed,
%     switching.costs: structs by type name (population: the types, or RE
%     and BR when none are given; an unlisted RE type takes share 0), shares
%     in [0, 1] summing to 1 per share group where the groups are known,
%     costs >= 0 and not also set in the type. switching.inertia in [0, 1),
%     switching.fitness 'normalized' | 'unnormalized' (memory may be 1 only
%     with 'unnormalized'), switching.intensity also 'model:<rule>';
%     beliefs.update also 'sac' | 'kf', beliefs.kf.gamma [] or in (0, 1),
%     beliefs.kf.s2 're_moments' or > 0; gain.rule also 'decreasing',
%     gain.decreasing.n0 >= 1; history.mode also 'kalman' (history.re_states
%     must then stay 'smoothed', as with 'inversion'), history.kalman.init
%     'stochastic' | 'smoothed'; 'fixed_shares' takes shares.fixed_n2 or
%     shares.fixed (not both). Combinations that are not supported
%     (hetlearn:options:unsupported, naming the options that put the run on
%     the N-type path: expectations.types, expectations.transforms or a
%     switching option of DESIGN_br_extensions 1.2): policy.mode = 'ramsey'
%     and history.mode = 'inversion'. Density forecasts, hetlearn.evaluate
%     and the Kalman history take N types; hetlearn.decompose refuses its own
%     cases (level types with method 'tv', Kalman results).
%
%   See also hetlearn.defaults.

if nargin < 1 || isempty(cfg)
    cfg = struct();
end
if ~isstruct(cfg) || ~isscalar(cfg)
    error('hetlearn:options:type', 'cfg must be a scalar struct.');
end

if nargin < 2
    master = call_master();
end
if isempty(master)
    master = struct();
end

opts = hetlearn.defaults();
opts = merge(opts, master, '');
opts = merge(opts, cfg, '');
opts = normalise(opts);
validate(opts);

end


% -------------------------------------------------------------------------
function removed_option(full)
% Options removed on 2026-10-18 (user decision: the projection facility is
% the only stabilising device): a helpful error instead of "Unknown option".
proj = {'projection.on_failure', 'projection.max_root', 'projection.method', 'projection.scope'};
swi = {'switching.error_scale', 'switching.error_scale_ref'};
if any(strcmp(full, proj))
    error('hetlearn:options:removed', ['Option "%s" was removed on 2026-10-18: use projection.facility ' ...
        '(''plm_alm'' | ''alm'' | ''none'').'], full);
elseif any(strcmp(full, swi))
    error('hetlearn:options:removed', ['Option "%s" was removed on 2026-10-18: switching uses the ' ...
        'unscaled squared errors, and the only stabilising device is projection.facility ' ...
        '(''plm_alm'' | ''alm'' | ''none'').'], full);
end
end


% -------------------------------------------------------------------------
function m = call_master()
m = struct();
if isempty(which('master_options'))
    here = fileparts(mfilename('fullpath'));      % toolbox/+hetlearn
    root = fileparts(fileparts(here));             % project root
    cfgDir = fullfile(root, 'config');
    if exist(fullfile(cfgDir, 'master_options.m'), 'file') == 2
        addpath(cfgDir);
    else
        return
    end
end
m = master_options();
if ~isstruct(m)
    error('hetlearn:options:type', 'master_options() must return a struct.');
end
end


% -------------------------------------------------------------------------
function base = merge(base, over, path)
% Recursive merge with name checking.
FREE = {'beliefs.init.values', 'beliefs.plm.by_var', 'beliefs.plm.derived', 'gain.by_var', ...
    'shares.fixed_n2', 'shocks.add', 'report'};
REPLACE = {'conditions', 'policy.loss', ...
    'expectations.types', 'expectations.transforms', 'shares.init', 'shares.fixed', 'switching.costs'};   % BR (P0)
if ~isstruct(over) || ~isscalar(over)
    error('hetlearn:options:type', 'Option "%s" must be a scalar struct.', strip_path(path));
end
f = fieldnames(over);
for i = 1:numel(f)
    name = f{i};
    full = [path '.' name];
    full = full(2:end);   % drop the leading '.'
    val = over.(name);
    if ~isfield(base, name)
        removed_option(full);
        error('hetlearn:options:unknown', 'Unknown option "%s".', full);
    end
    if any(strcmp(full, REPLACE))
        base.(name) = val;
    elseif any(strcmp(full, FREE))
        if isstruct(val) && isscalar(val) && isstruct(base.(name)) && isscalar(base.(name))
            base.(name) = merge_free(base.(name), val);
        else
            base.(name) = val;
        end
    elseif isstruct(base.(name)) && isscalar(base.(name))
        if ~(isstruct(val) && isscalar(val))
            error('hetlearn:options:type', ...
                'Option "%s" is a group of options and must be a struct.', full);
        end
        base.(name) = merge(base.(name), val, ['.' full]);
    else
        base.(name) = val;
    end
end
end


function s = strip_path(p)
if isempty(p)
    s = '<root>';
elseif p(1) == '.'
    s = p(2:end);
else
    s = p;
end
end


% -------------------------------------------------------------------------
function base = merge_free(base, over)
% Merge without name checks (free-form subtrees).
f = fieldnames(over);
for i = 1:numel(f)
    v = over.(f{i});
    if isfield(base, f{i}) && isstruct(v) && isscalar(v) ...
            && isstruct(base.(f{i})) && isscalar(base.(f{i}))
        base.(f{i}) = merge_free(base.(f{i}), v);
    else
        base.(f{i}) = v;
    end
end
end


% -------------------------------------------------------------------------
function o = normalise(o)
o.id = tochar(o.id, 'id');
o.title = tochar(o.title, 'title');
o.description = tochar(o.description, 'description');
o.model = tochar(o.model, 'model');
o.model_params = tochar(o.model_params, 'model_params');
o.expectations.mode = tochar(o.expectations.mode, 'expectations.mode');
o.expectations.re_variant = tochar(o.expectations.re_variant, 'expectations.re_variant');
o.expectations.re_info = tochar(o.expectations.re_info, 'expectations.re_info');
v = o.expectations.variables;
if isstring(v), v = cellstr(v); end
if ischar(v)
    if ~strcmpi(v, 'all')
        v = {v};
    else
        v = 'all';
    end
end
o.expectations.variables = v;
o.beliefs.update = tochar(o.beliefs.update, 'beliefs.update');
o.beliefs.info = tochar(o.beliefs.info, 'beliefs.info');
if ischar(o.beliefs.plm.default) || isstring(o.beliefs.plm.default)
    o.beliefs.plm.default = char(o.beliefs.plm.default);
end
if isstruct(o.beliefs.plm.derived) && isscalar(o.beliefs.plm.derived)
    df = fieldnames(o.beliefs.plm.derived);
    for i = 1:numel(df)
        if isstring(o.beliefs.plm.derived.(df{i})) && isscalar(o.beliefs.plm.derived.(df{i}))
            o.beliefs.plm.derived.(df{i}) = char(o.beliefs.plm.derived.(df{i}));
        end
    end
end
vv = o.beliefs.plm.var.variables;
if isstring(vv), vv = cellstr(vv); end
if ischar(vv) && ~strcmpi(vv, 'learning')
    if isempty(vv), vv = {}; else, vv = {vv}; end
end
if ischar(vv), vv = 'learning'; elseif iscell(vv), vv = reshape(vv, 1, []); end
o.beliefs.plm.var.variables = vv;
o.beliefs.init.method = tochar(o.beliefs.init.method, 'beliefs.init.method');
o.gain.rule = tochar(o.gain.rule, 'gain.rule');
o.gain.koz.structure = tochar(o.gain.koz.structure, 'gain.koz.structure');
o.gain.koz.error = tochar(o.gain.koz.error, 'gain.koz.error');
o.gain.koz.master = tocell(o.gain.koz.master, 'gain.koz.master');
o.shares.structure = tochar(o.shares.structure, 'shares.structure');
o.shares.master = tocell(o.shares.master, 'shares.master');
o.switching.rule = tochar(o.switching.rule, 'switching.rule');
o.projection.facility = tochar(o.projection.facility, 'projection.facility');
o.history.mode = tochar(o.history.mode, 'history.mode');
o.history.re_states = tochar(o.history.re_states, 'history.re_states');
o.history.inversion.shocks = tocell(o.history.inversion.shocks, 'history.inversion.shocks');
o.engine.step = tochar(o.engine.step, 'engine.step');
o.engine.conditions_weighting = tochar(o.engine.conditions_weighting, 'engine.conditions_weighting');
o.shocks.source = tochar(o.shocks.source, 'shocks.source');
o.shocks.exclude = tocell(o.shocks.exclude, 'shocks.exclude');
o.density.shocks = tocell(o.density.shocks, 'density.shocks');
o.density.sigma = tochar(o.density.sigma, 'density.sigma');
o.density.method = tochar(o.density.method, 'density.method');
o.policy.mode = tochar(o.policy.mode, 'policy.mode');
o.policy.type = tochar(o.policy.type, 'policy.type');
o.compare_with = tocell(o.compare_with, 'compare_with');
if isfield(o.report, 'variables')
    o.report.variables = tocell(o.report.variables, 'report.variables');
end
% bounded-rationality extensions (DESIGN_br_extensions, schema of phase P0)
o.switching.fitness = tochar(o.switching.fitness, 'switching.fitness');
if isstring(o.switching.intensity) && isscalar(o.switching.intensity)
    o.switching.intensity = char(o.switching.intensity);
end
if isstring(o.beliefs.kf.s2) && isscalar(o.beliefs.kf.s2)
    o.beliefs.kf.s2 = char(o.beliefs.kf.s2);
end
o.history.kalman.init = tochar(o.history.kalman.init, 'history.kalman.init');
o.expectations.types = normalise_types(o.expectations.types);
o.expectations.transforms = normalise_transforms(o.expectations.transforms);
end


% -------------------------------------------------------------------------
function T = normalise_types(T)
% expectations.types (DESIGN_br_extensions 1.1): -> 1xN struct array with every field
F = {'name', 'kind', 'variant', 'info', 'plm', 'update', 'gain', 'rule', 'base', 'k', 'variables', 'cost'};
T = struct_list(T, F, 'expectations.types', 'hetlearn:options:types');
for i = 1:numel(T)
    for f = {'name', 'kind', 'variant', 'info', 'update', 'base', 'plm', 'rule'}
        if isstring(T(i).(f{1})) && isscalar(T(i).(f{1}))
            T(i).(f{1}) = char(T(i).(f{1}));
        end
    end
    T(i).variables = cell_or_empty(T(i).variables);
end
end


function X = normalise_transforms(X)
% expectations.transforms (DESIGN_br_extensions 1.3): -> 1xN struct array, defaults filled in
F = {'kind', 'types', 'scope', 'exclude', 'profile', 'value', 'factor'};
X = struct_list(X, F, 'expectations.transforms', 'hetlearn:options:transforms');
for i = 1:numel(X)
    for f = {'kind', 'profile'}
        if isstring(X(i).(f{1})) && isscalar(X(i).(f{1}))
            X(i).(f{1}) = char(X(i).(f{1}));
        end
    end
    X(i).types = all_or_cell(X(i).types, 'all', {'all'});
    X(i).scope = all_or_cell(X(i).scope, 'learning', {'learning', 'all'});
    X(i).exclude = cell_or_empty(X(i).exclude);
    if isempty(X(i).exclude)
        X(i).exclude = {};
    end
    if isempty(X(i).profile)
        X(i).profile = '';
        if ischar(X(i).kind) && strcmp(X(i).kind, 'multiplier')
            X(i).profile = 'geometric';
        end
    end
    if ischar(X(i).kind) && strcmp(X(i).kind, 'wedge')
        fac = X(i).factor;
        if isempty(fac)
            fac = struct();
        end
        if isstruct(fac) && isscalar(fac)
            def = struct('rho', 0, 'std', 0, 'mean', 0, 'loadings', [], 'shock', '');
            for g = fieldnames(def)'
                if ~isfield(fac, g{1})
                    fac.(g{1}) = def.(g{1});
                elseif isstring(fac.(g{1})) && isscalar(fac.(g{1}))
                    fac.(g{1}) = char(fac.(g{1}));
                end
            end
        end
        X(i).factor = fac;
    end
end
end


function S = struct_list(X, F, name, id)
% a struct array or a cell array of scalar structs -> 1xN struct array with fields F (missing = []);
% empty -> the 0x0 struct array of hetlearn.defaults
S = repmat(cell2struct(cell(numel(F), 1), F, 1), 0, 0);
if isempty(X)
    return
end
if isstruct(X)
    C = num2cell(reshape(X, 1, []));
elseif iscell(X) && all(cellfun(@(c) isstruct(c) && isscalar(c), X(:)))
    C = reshape(X, 1, []);
else
    error(id, 'Option "%s" must be a struct array or a cell array of structs.', name);
end
S = repmat(cell2struct(cell(numel(F), 1), F, 1), 1, numel(C));
for i = 1:numel(C)
    f = fieldnames(C{i});
    bad = setdiff(f, F);
    if ~isempty(bad)
        error(id, 'Unknown field(s) in option "%s(%d)": %s (fields: %s).', name, i, ...
            strjoin(bad', ', '), strjoin(F, ', '));
    end
    for j = 1:numel(f)
        S(i).(f{j}) = C{i}.(f{j});
    end
end
end


function v = cell_or_empty(v)
% [] or a cellstr row; char -> {char}; strings -> cellstr; {} -> []
if isstring(v)
    v = cellstr(v);
end
if ischar(v) && ~isempty(v)
    v = {v};
end
if isempty(v)
    v = [];
elseif iscell(v)
    v = reshape(v, 1, []);
end
end


function v = all_or_cell(v, dflt, words)
% [] -> dflt; one of words stays char; another char -> {char}; strings -> char or cellstr
if isstring(v)
    if isscalar(v)
        v = char(v);
    else
        v = cellstr(v);
    end
end
if isempty(v)
    v = dflt;
elseif ischar(v) && ~any(strcmp(v, words))
    v = {v};
elseif iscell(v)
    v = reshape(v, 1, []);
end
end


function c = tochar(c, name)
if isstring(c) && isscalar(c)
    c = char(c);
end
if ~(ischar(c) && (isrow(c) || isempty(c)))
    error('hetlearn:options:type', 'Option "%s" must be a character string.', name);
end
end


function c = tocell(c, name)
if isstring(c), c = cellstr(c); end
if ischar(c)
    if isempty(c), c = {}; else, c = {c}; end
end
if isempty(c) && ~iscell(c), c = {}; end
if ~iscellstr(c)
    error('hetlearn:options:type', 'Option "%s" must be a cellstr.', name);
end
c = reshape(c, 1, []);
end


% -------------------------------------------------------------------------
function validate(o)
if ~isempty(o.model_params) && ~isvarname(o.model_params)
    error('hetlearn:options:value', ['Option "model_params" = ''%s'' must be '''' (the package''s ' ...
        'spec.params) or the name of a parameter function in the model package.'], o.model_params);
end
enum(o.expectations.mode, {'rational', 'learning', 'fixed_shares', 'switching'}, 'expectations.mode');
enum(o.expectations.re_variant, {'model_consistent', 'anchored'}, 'expectations.re_variant');
enum(o.expectations.re_info, {'current', 'lagged'}, 'expectations.re_info');
v = o.expectations.variables;
if ~(iscellstr(v) || (ischar(v) && strcmpi(v, 'all')))
    error('hetlearn:options:type', ...
        'Option "expectations.variables" must be a cellstr or ''all''.');
end
if strcmp(o.expectations.re_info, 'lagged')
    % DESIGN 19: only the learning set's RE expectations are dated t-1, so an empty set
    % would leave the option without effect (an error rather than a silently ignored option)
    if iscell(v) && isempty(v)
        error('hetlearn:options:value', ['expectations.re_info = ''lagged'' dates the RE expectations ' ...
            'of the learning set (expectations.variables) at t-1; the learning set is empty.']);
    end
    if strcmp(o.policy.mode, 'ramsey')
        error('hetlearn:options:unsupported', ['expectations.re_info = ''lagged'' with policy.mode = ' ...
            '''ramsey'' is not supported: the Ramsey plan with predetermined RE expectations has not been ' ...
            'derived or tested (DESIGN 19). Use policy.mode = ''rule'' or re_info = ''current''.']);
    end
end
enum(o.beliefs.update, {'rls', 'fixed', 'sac', 'kf'}, 'beliefs.update');   % 'sac', 'kf': DESIGN_br_extensions 1.5 (P5)
kf = o.beliefs.kf;
if ~isempty(kf.gamma)
    num(kf.gamma, @(x) x > 0 && x < 1, 'beliefs.kf.gamma', 'in (0, 1), or [] (= gain.value)');
end
if ischar(kf.s2)
    enum(kf.s2, {'re_moments'}, 'beliefs.kf.s2');
else
    num(kf.s2, @(x) x > 0 && isfinite(x), 'beliefs.kf.s2', '> 0, or ''re_moments''');
end
enum(o.beliefs.info, {'lagged', 'current'}, 'beliefs.info');
d = o.beliefs.plm.default;
if ~ischar(d)
    error('hetlearn:options:type', 'Option "beliefs.plm.default" must be a shorthand string.');
end
enum(d, {'ar1', 'ar2', 'ar1_noconst', 'var1'}, 'beliefs.plm.default');
if ~isstruct(o.beliefs.plm.by_var)
    error('hetlearn:options:type', 'Option "beliefs.plm.by_var" must be a struct.');
end
dv = o.beliefs.plm.derived;
if ~isstruct(dv) || ~isscalar(dv)
    error('hetlearn:options:type', 'Option "beliefs.plm.derived" must be a struct of strings.');
end
df = fieldnames(dv);
for i = 1:numel(df)
    if ~(ischar(dv.(df{i})) && isrow(dv.(df{i})) && ~isempty(strtrim(dv.(df{i}))))
        error('hetlearn:options:type', ...
            'Option "beliefs.plm.derived.%s" must be a non-empty string (a linear expression).', df{i});
    end
end
pv = o.beliefs.plm.var;
if ~(iscellstr(pv.variables) || (ischar(pv.variables) && strcmpi(pv.variables, 'learning')))
    error('hetlearn:options:type', ...
        'Option "beliefs.plm.var.variables" must be a cellstr or ''learning''.');
end
num(pv.lags, @(x) x >= 1 && x == round(x), 'beliefs.plm.var.lags', 'a positive integer');
if ~((islogical(pv.constant) || isnumeric(pv.constant)) && isscalar(pv.constant))
    error('hetlearn:options:type', 'Option "beliefs.plm.var.constant" must be true or false.');
end
if strcmp(d, 'var1') && ~isempty(pv.variables)
    error('hetlearn:options:value', ['Options "beliefs.plm.default" = ''var1'' and ' ...
        '"beliefs.plm.var.variables" are both set; use one of them.']);
end
enum(o.beliefs.init.method, {'re_moments', 'training_ols', 'user'}, 'beliefs.init.method');
if strcmp(o.beliefs.init.method, 'training_ols') && isempty(o.beliefs.init.training_range)
    error('hetlearn:options:missing', ...
        'beliefs.init.method = ''training_ols'' needs beliefs.init.training_range.');
end
if ~isstruct(o.beliefs.init.values)
    error('hetlearn:options:type', 'Option "beliefs.init.values" must be a struct.');
end
fn(o.gain.rule, 'gain');
num(o.gain.value, @(x) x > 0 && x <= 1, 'gain.value', 'in (0, 1]');
num(o.gain.decreasing.n0, @(x) x >= 1 && isfinite(x), 'gain.decreasing.n0', '>= 1');
if ~isstruct(o.gain.by_var)
    error('hetlearn:options:type', 'Option "gain.by_var" must be a struct.');
end
gv = struct2cell(o.gain.by_var);
for i = 1:numel(gv)
    num(gv{i}, @(x) x > 0 && x <= 1, 'gain.by_var.<x>', 'in (0, 1]');
end
validate_gain(o);
enum(o.shares.structure, {'per_variable', 'universal'}, 'shares.structure');
if strcmp(o.shares.structure, 'universal') && isempty(o.shares.master)
    error('hetlearn:options:missing', ...
        'shares.structure = ''universal'' needs shares.master.');
end
num(o.shares.init_n2, @(x) x >= 0 && x <= 1, 'shares.init_n2', 'in [0, 1]');
f2 = o.shares.fixed_n2;
if strcmp(o.expectations.mode, 'fixed_shares') && isempty(f2) && isempty(o.shares.fixed)
    error('hetlearn:options:missing', ...
        'expectations.mode = ''fixed_shares'' needs shares.fixed_n2 (or, with N types, shares.fixed).');
end
if ~isempty(f2) && ~isempty(o.shares.fixed)
    error('hetlearn:options:value', ['Options "shares.fixed_n2" and "shares.fixed" are both set; use one ' ...
        '(fixed_n2 is the two-type shorthand of shares.fixed).']);
end
if ~isempty(f2)
    if isnumeric(f2)
        num(f2, @(x) x >= 0 && x <= 1, 'shares.fixed_n2', 'in [0, 1]');
    elseif isstruct(f2)
        c = struct2cell(f2);
        for i = 1:numel(c)
            num(c{i}, @(x) x >= 0 && x <= 1, 'shares.fixed_n2.<x>', 'in [0, 1]');
        end
    else
        error('hetlearn:options:type', ...
            'Option "shares.fixed_n2" must be a scalar or a struct by variable.');
    end
end
fn(o.switching.rule, 'switching');
if ischar(o.switching.intensity)       % 'model:<rule>', computed from the RE limit (P2)
    if isempty(regexp(o.switching.intensity, '^model:[A-Za-z]\w*$', 'once'))
        error('hetlearn:options:value', ['Option "switching.intensity" must be a numeric scalar >= 0 or ' ...
            '''model:<rule>'' (e.g. ''model:bma''); got ''%s''.'], o.switching.intensity);
    end
else
    num(o.switching.intensity, @(x) x >= 0, 'switching.intensity', '>= 0');
end
enum(o.switching.fitness, {'normalized', 'unnormalized'}, 'switching.fitness');
if strcmp(o.switching.fitness, 'unnormalized')
    % cumulative errors without forgetting (memory 1) are the Bayesian model averaging case (variant 27)
    num(o.switching.memory, @(x) x >= 0 && x <= 1, 'switching.memory', 'in [0, 1] (fitness ''unnormalized'')');
else
    num(o.switching.memory, @(x) x >= 0 && x < 1, 'switching.memory', 'in [0, 1)');
end
num(o.switching.inertia, @(x) x >= 0 && x < 1, 'switching.inertia', 'in [0, 1) (0 = off)');
enum(o.projection.facility, {'plm_alm', 'alm', 'none'}, 'projection.facility');
if ~(islogical(o.history.learn) || isnumeric(o.history.learn)) || ~isscalar(o.history.learn)
    error('hetlearn:options:type', 'Option "history.learn" must be true or false.');
end
if strcmp(o.history.mode, 'hetero_filter')
    error('hetlearn:options:notImplemented', ['history.mode = ''hetero_filter'' is a planned hook and is ' ...
        'not implemented: the Kalman history of the heterogeneous-expectations model is history.mode = ' ...
        '''kalman'' (docs/DESIGN_br_extensions.md sec. 5, phase P1).']);
end
enum(o.history.mode, {'re_smoother', 'inversion', 'kalman'}, 'history.mode');
enum(o.history.re_states, {'smoothed', 'filtered'}, 'history.re_states');
if strcmp(o.history.re_states, 'filtered') && strcmp(o.history.mode, 'inversion')
    % an error rather than a silently ignored option: the run would equal the 'smoothed' one
    error('hetlearn:options:value', ['history.re_states = ''filtered'' applies to history.mode = ' ...
        '''re_smoother'' only. The inversion is one-sided by construction (period t uses data up to t); ' ...
        'leave history.re_states at ''smoothed'' there.']);
end
if strcmp(o.history.re_states, 'filtered') && strcmp(o.history.mode, 'kalman')
    error('hetlearn:options:value', ['history.re_states = ''filtered'' applies to history.mode = ' ...
        '''re_smoother'' only. The Kalman history is one-sided by construction (forecasts from the ' ...
        'predicted and filtered states of the ALM); leave history.re_states at ''smoothed'' there.']);
end
enum(o.history.kalman.init, {'stochastic', 'smoothed'}, 'history.kalman.init');
enum(o.engine.step, {'fast', 'iris'}, 'engine.step');
enum(o.engine.conditions_weighting, {'std', 'none'}, 'engine.conditions_weighting');
enum(o.shocks.source, {'none', 'smoothed'}, 'shocks.source');
validate_density(o);
validate_policy(o);
flag(o.density.demean, 'density.demean');
if ~iscell(o.shocks.add)
    error('hetlearn:options:type', 'Option "shocks.add" must be a cell array {{name, dates, values}, ...}.');
end
num(o.forecast.horizon, @(x) x >= 1 && x == round(x), 'forecast.horizon', 'a positive integer');
if ~isstruct(o.conditions)
    error('hetlearn:options:type', 'Option "conditions" must be a struct array.');
end
% bounded-rationality extensions (DESIGN_br_extensions, schema of phase P0)
validate_types(o);
validate_transforms(o);
validate_by_type(o);
validate_ntype_stages(o);
end


% -------------------------------------------------------------------------
function validate_ntype_stages(o)
% Stages that do not take the N-type engine path (docs/DESIGN_br_extensions.md sec. 6, phase P6):
% policy.mode = 'ramsey' and history.mode = 'inversion' with N agent types, forecast transforms or the
% switching options of DESIGN_br_extensions 1.2 stop here, naming the options involved
if ~(strcmp(o.policy.mode, 'ramsey') || strcmp(o.history.mode, 'inversion'))
    return
end
A = hetlearn.agent_types(o);
if ~A.engine
    return
end
c = {};
if ~isempty(o.expectations.types)
    c{end+1} = 'N agent types (expectations.types)';
end
if ~isempty(o.expectations.transforms)
    c{end+1} = 'forecast transforms (expectations.transforms)';
end
if isempty(c)
    c{end+1} = ['the switching options of DESIGN_br_extensions 1.2 (switching.inertia, .costs, .fitness, ' ...
        'intensity ''model:<rule>'', shares.init, shares.fixed), which take the N-type engine path'];
end
what = strjoin(c, ' and ');
if strcmp(o.policy.mode, 'ramsey')
    error('hetlearn:options:unsupported', ['policy.mode = ''ramsey'' with %s is not supported: the Ramsey wrap ' ...
        'of the N-type model and its rule model have not been built (docs/DESIGN_br_extensions.md sec. 6, P6). ' ...
        'Use policy.mode = ''rule''.'], what);
end
error('hetlearn:options:unsupported', ['history.mode = ''inversion'' with %s is not supported: the inversion ' ...
    'reads the two-type forecasts from the model (docs/DESIGN_br_extensions.md sec. 6, P6). Use history.mode = ' ...
    '''re_smoother'' or ''kalman''.'], what);
end


% -------------------------------------------------------------------------
function validate_types(o)
% expectations.types (DESIGN_br_extensions 1.1); model-dependent checks (forward-looking variables,
% share groups of 'all', mode semantics) are left to the engine
T = o.expectations.types;
if isempty(T)
    return
end
ID = 'hetlearn:options:types';
kinds = {'re', 'plm', 'rule', 'level', 're_mean'};
applies = struct('re', {{'variant', 'info', 'variables', 'cost'}}, ...
    'plm', {{'info', 'plm', 'update', 'gain', 'variables', 'cost'}}, ...
    'rule', {{'info', 'rule', 'update', 'gain', 'variables', 'cost'}}, ...
    'level', {{'variant', 'info', 'base', 'k', 'variables', 'cost'}}, ...
    're_mean', {{'variant', 'info', 'update', 'gain', 'variables', 'cost'}});
optional = {'variant', 'info', 'plm', 'update', 'gain', 'rule', 'base', 'k', 'variables', 'cost'};
names = cell(1, numel(T));
for i = 1:numel(T)
    t = T(i);
    if ~(ischar(t.name) && ~isempty(regexp(t.name, '^[A-Za-z][A-Za-z0-9]*$', 'once')))
        error(ID, 'Option "expectations.types(%d).name" must be letters and digits, starting with a letter.', i);
    end
    names{i} = t.name;
end
dup = unique(names(cellfun(@(n) sum(strcmp(names, n)) > 1, names)));
if ~isempty(dup)
    error(ID, 'Option "expectations.types": type names must be unique; repeated: %s.', strjoin(dup, ', '));
end
lv = o.expectations.variables;
for i = 1:numel(T)
    t = T(i);
    p = sprintf('expectations.types(%d) (''%s'')', i, t.name);
    if ~(ischar(t.kind) && any(strcmp(t.kind, kinds)))
        error(ID, 'Option "%s.kind" must be one of: %s.', p, strjoin(kinds, ', '));
    end
    if strcmp(t.name, 'RE') && ~strcmp(t.kind, 're')
        error(ID, ['Option "%s": the type named RE is the always-generated RE type and must be of kind ''re'' ' ...
            '(name the other type differently).'], p);
    end
    given = optional(cellfun(@(f) ~isempty(t.(f)), optional));
    bad = setdiff(given, applies.(t.kind));
    if ~isempty(bad)
        error(ID, 'Option "%s": field(s) %s do not apply to kind ''%s''.', p, strjoin(bad, ', '), t.kind);
    end
    if ~isempty(t.variant)
        check_enum(t.variant, {'anchored', 'model_consistent'}, [p '.variant'], ID);
    end
    if ~isempty(t.info)
        check_enum(t.info, {'lagged', 'current'}, [p '.info'], ID);
    end
    if ~isempty(t.update)
        check_enum(t.update, {'rls', 'fixed', 'sac', 'kf'}, [p '.update'], ID);
    end
    if ~isempty(t.plm)
        check_type_plm(t.plm, [p '.plm'], ID);
    end
    if ~isempty(t.gain)
        check_type_gain(o, t.gain, [p '.gain'], ID);
    end
    if strcmp(t.kind, 'rule')
        check_rule(t.rule, [p '.rule'], ID);
    end
    if strcmp(t.kind, 'level')
        if ~(ischar(t.base) && any(strcmp(t.base, [names, {'RE'}])) && ~strcmp(t.base, t.name))
            error(ID, 'Option "%s.base" must name another type of the list (or ''RE'').', p);
        end
        if ~(isnumeric(t.k) && isscalar(t.k) && isreal(t.k) && t.k >= 1 && t.k == round(t.k))
            error(ID, 'Option "%s.k" must be an integer >= 1.', p);
        end
    end
    if ~isempty(t.variables)
        v = t.variables;
        if ~(iscellstr(v) && all(cellfun(@isvarname, v)))
            error(ID, 'Option "%s.variables" must be a cellstr of variable names, or [] (every learning variable).', p);
        end
        if iscell(lv) && ~all(ismember(v, lv))
            error(ID, 'Option "%s.variables": %s not in expectations.variables (%s).', p, ...
                strjoin(setdiff(v, lv), ', '), strjoin(lv, ', '));
        end
    end
    if ~isempty(t.cost)
        if ~(isnumeric(t.cost) && isscalar(t.cost) && isreal(t.cost) && isfinite(t.cost) && t.cost >= 0)
            error(ID, 'Option "%s.cost" must be a number >= 0 (Brock-Hommes cost), or [].', p);
        end
        if isstruct(o.switching.costs) && isfield(o.switching.costs, t.name)
            error(ID, 'The cost of type %s is set twice, in "%s.cost" and in "switching.costs.%s"; use one.', ...
                t.name, p, t.name);
        end
    end
end
end


function check_enum(v, allowed, name, id)
if ~(ischar(v) && any(strcmp(v, allowed)))
    error(id, 'Option "%s" must be one of: %s.', name, strjoin(allowed, ', '));
end
end


function check_type_plm(p, name, id)
% a PLM shorthand or a partial beliefs.plm subtree (names checked against the defaults)
if ischar(p)
    check_enum(p, {'ar1', 'ar2', 'ar1_noconst', 'var1'}, name, id);
    return
end
d = hetlearn.defaults();
try
    q = merge(d.beliefs.plm, p, '.beliefs.plm');
catch err
    error(id, 'Option "%s": %s', name, err.message);
end
if ~ischar(q.default)
    error(id, 'Option "%s.default" must be a shorthand string.', name);
end
check_enum(q.default, {'ar1', 'ar2', 'ar1_noconst', 'var1'}, [name '.default'], id);
if ~isstruct(q.by_var) || ~isstruct(q.derived) || ~isstruct(q.var)
    error(id, 'Option "%s": by_var, derived and var must be structs.', name);
end
end


function check_type_gain(o, g, name, id)
% a partial gain subtree, merged over gain and checked as gain
if ~(isstruct(g) && isscalar(g))
    error(id, 'Option "%s" must be a partial gain subtree (a struct), or [].', name);
end
try
    q = merge(o.gain, g, '.gain');
    q.rule = tochar(q.rule, 'gain.rule');
    q.koz.structure = tochar(q.koz.structure, 'gain.koz.structure');
    q.koz.error = tochar(q.koz.error, 'gain.koz.error');
    q.koz.master = tocell(q.koz.master, 'gain.koz.master');
    fn(q.rule, 'gain');
    num(q.value, @(x) x > 0 && x <= 1, 'gain.value', 'in (0, 1]');
    num(q.decreasing.n0, @(x) x >= 1 && isfinite(x), 'gain.decreasing.n0', '>= 1');
    ot = o;
    ot.gain = q;
    validate_gain(ot);
catch err
    error(id, 'Option "%s": %s', name, err.message);
end
end


function check_rule(r, name, id)
% 'rule' types: the expression, or struct('expr', ..., 'params', struct of numbers)
if isstruct(r) && isscalar(r)
    bad = setdiff(fieldnames(r), {'expr', 'params'});
    if ~isempty(bad)
        error(id, 'Unknown field(s) in option "%s": %s (fields: expr, params).', name, strjoin(bad', ', '));
    end
    if ~isfield(r, 'expr')
        error(id, 'Option "%s" needs the field expr.', name);
    end
    e = r.expr;
    if isfield(r, 'params') && ~isempty(r.params)
        pr = r.params;
        if ~(isstruct(pr) && isscalar(pr) && all(cellfun(@(f) isnumeric(pr.(f)) && isscalar(pr.(f)) ...
                && isreal(pr.(f)) && isfinite(pr.(f)), fieldnames(pr))))
            error(id, 'Option "%s.params" must be a struct of finite numbers.', name);
        end
    end
else
    e = r;
end
if isstring(e) && isscalar(e)
    e = char(e);
end
if ~(ischar(e) && ~isempty(strtrim(e)) && ~isempty(regexp(e, '^[\w\s\.\+\-\*/\(\)\{\},]+$', 'once')))
    error(id, ['Option "%s" must hold the rule expression (names, numbers, + - * / ( ) and lags x{-k}), ' ...
        'e.g. ''0.65*x{-1} + 0.35*self{-1}'', or struct(''expr'', ..., ''params'', ...).'], name);
end
end


% -------------------------------------------------------------------------
function validate_transforms(o)
% expectations.transforms (DESIGN_br_extensions 1.3); equation labels and variables are checked
% against the model by the generator
X = o.expectations.transforms;
if isempty(X)
    return
end
ID = 'hetlearn:options:transforms';
kinds = {'multiplier', 'diagnostic', 'myopia_anchoring', 'partial_adjustment', 'wedge'};
pop = population(o);
shocks = {};
for i = 1:numel(X)
    x = X(i);
    p = sprintf('expectations.transforms(%d)', i);
    if ~(ischar(x.kind) && any(strcmp(x.kind, kinds)))
        error(ID, 'Option "%s.kind" must be one of: %s.', p, strjoin(kinds, ', '));
    end
    p = sprintf('%s (''%s'')', p, x.kind);
    if iscell(x.types)
        if ~iscellstr(x.types) || ~all(ismember(x.types, [pop, {'RE'}]))
            error(ID, 'Option "%s.types" must be ''all'' or names of the population (%s).', p, ...
                strjoin(unique([pop, {'RE'}], 'stable'), ', '));
        end
    elseif ~strcmp(x.types, 'all')
        error(ID, 'Option "%s.types" must be ''all'' or a cellstr of type names.', p);
    end
    if iscell(x.scope)
        ok = iscellstr(x.scope) && all(cellfun(@(s) ~isempty(regexp(s, '^[A-Za-z]\w*(@.*\S.*)?$', 'once')), x.scope));
        if ~ok
            error(ID, ['Option "%s.scope" must be ''learning'', ''all'' or a cellstr of variables and ' ...
                '''x@<exact equation label>'' entries.'], p);
        end
    elseif ~any(strcmp(x.scope, {'learning', 'all'}))
        error(ID, 'Option "%s.scope" must be ''learning'', ''all'' or a cellstr.', p);
    end
    if ~isempty(x.exclude) && ~(iscellstr(x.exclude) && all(cellfun(@isvarname, x.exclude)))
        error(ID, 'Option "%s.exclude" must be a cellstr of variable names.', p);
    end
    if strcmp(x.kind, 'multiplier')
        check_enum(x.profile, {'geometric', 'flat', 'hyperbolic'}, [p '.profile'], ID);
    elseif ~isempty(x.profile)
        error(ID, 'Option "%s.profile" applies to kind ''multiplier'' only.', p);
    end
    v = x.value;
    isnum = @(v, n) isnumeric(v) && isreal(v) && numel(v) == n && all(isfinite(v(:)));
    switch x.kind
        case 'multiplier'
            ok = isnum(v, 1) && v >= 0;
            what = 'a number >= 0 (m or lambda; alpha for ''hyperbolic'')';
        case 'diagnostic'
            ok = isnum(v, 1);
            what = 'a number (theta; 0 = identity)';
        case 'myopia_anchoring'
            ok = isnum(v, 2);
            what = '[omega_f, b] ([1 0] = identity)';
        case 'partial_adjustment'
            ok = isnum(v, 1) && v >= 0 && v <= 1;
            what = 'a number g in [0, 1] (1 = identity)';
        otherwise    % wedge
            ok = isempty(v);
            what = 'empty (a wedge is set by its factor)';
    end
    if ~ok
        error(ID, 'Option "%s.value" must be %s.', p, what);
    end
    if strcmp(x.kind, 'wedge')
        shocks = check_factor(x.factor, [p '.factor'], ID, shocks);
    elseif ~isempty(x.factor)
        error(ID, 'Option "%s.factor" applies to kind ''wedge'' only.', p);
    end
end
end


function shocks = check_factor(f, name, id, shocks)
if ~(isstruct(f) && isscalar(f))
    error(id, 'Option "%s" must be a struct (rho, std, mean, loadings, shock).', name);
end
bad = setdiff(fieldnames(f), {'rho', 'std', 'mean', 'loadings', 'shock'});
if ~isempty(bad)
    error(id, 'Unknown field(s) in option "%s": %s (fields: rho, std, mean, loadings, shock).', name, strjoin(bad', ', '));
end
isModel = @(v, sign) ischar(v) && ~isempty(regexp(v, ['^' sign 'model:[A-Za-z]\w*$'], 'once'));
fin = @(v) isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v);
if ~(fin(f.rho) && abs(f.rho) < 1)
    error(id, 'Option "%s.rho" must be a number in (-1, 1).', name);
end
if ~((fin(f.std) && f.std >= 0) || isModel(f.std, ''))
    error(id, 'Option "%s.std" must be a number >= 0 or ''model:<rule>''.', name);
end
if ~(fin(f.mean) || isModel(f.mean, '-?'))
    error(id, 'Option "%s.mean" must be a number or ''model:<rule>'' (''-model:<rule>'' for minus that value).', name);
end
L = f.loadings;
okL = isempty(L) || isModel(L, '') || (isstruct(L) && isscalar(L) && all(cellfun(@(g) fin(L.(g)), fieldnames(L))));
if ~okL
    error(id, 'Option "%s.loadings" must be [] (1 for every variable), a struct of numbers by variable or ''model:<rule>''.', name);
end
s = f.shock;
if ~(ischar(s) && (isempty(s) || isvarname(s)))
    error(id, 'Option "%s.shock" must be a shock name, or '''' for a constant wedge.', name);
end
if isempty(s) && ~(fin(f.std) && f.std == 0)
    error(id, 'Option "%s": a wedge with std other than 0 needs factor.shock (the name of its new shock).', name);
end
if ~isempty(s)
    if any(strcmp(shocks, s))
        error(id, 'Option "%s.shock" = ''%s'' is used by another wedge; use one name per factor.', name, s);
    end
    shocks{end+1} = s;
end
end


function pop = population(o)
% type names of the population: the listed types, or the default pair
T = o.expectations.types;
if isempty(T)
    pop = {'RE', 'BR'};
else
    pop = {T.name};
end
end


% -------------------------------------------------------------------------
function validate_by_type(o)
% shares.init, shares.fixed, switching.costs: structs by type name (DESIGN_br_extensions 1.1-1.2)
ID = 'hetlearn:options:value';
T = o.expectations.types;
pop = population(o);
known = unique([pop, {'RE'}], 'stable');
for nm = {'init', 'fixed'}
    s = o.shares.(nm{1});
    p = ['shares.' nm{1}];
    if isempty(s)
        continue
    end
    if ~(isstruct(s) && isscalar(s))
        error(ID, 'Option "%s" must be a struct by type name, or [].', p);
    end
    f = fieldnames(s)';
    bad = setdiff(f, known);
    if ~isempty(bad)
        error(ID, 'Option "%s": %s not a type of the population (%s).', p, strjoin(bad, ', '), strjoin(known, ', '));
    end
    for j = 1:numel(f)
        num(s.(f{j}), @(x) x >= 0 && x <= 1, sprintf('%s.%s', p, f{j}), 'in [0, 1]');
    end
    miss = setdiff(pop, f);
    if ~isempty(miss)
        error(ID, 'Option "%s" gives no share for type(s) %s.', p, strjoin(miss, ', '));
    end
    % share groups: all types forecast every learning variable, or per variable of a cellstr set
    lv = o.expectations.variables;
    hasVars = ~isempty(T) && any(arrayfun(@(t) ~isempty(t.variables), T));
    if ~hasVars
        groups = {f};
        gname = {'all learning variables'};
    elseif iscell(lv)
        groups = cell(1, numel(lv));
        gname = lv;
        for j = 1:numel(lv)
            mem = arrayfun(@(t) isempty(t.variables) || any(strcmp(t.variables, lv{j})), T);
            groups{j} = intersect(f, [{T(mem).name}, setdiff({'RE'}, pop)]);
        end
    else
        groups = {};    % types with own variables and expectations.variables = 'all': checked by the engine
        gname = {};
    end
    for j = 1:numel(groups)
        tot = sum(cellfun(@(n) double(s.(n)), groups{j}));
        if abs(tot - 1) > 1e-10
            error(ID, 'Option "%s": the shares of %s (%s) sum to %.12g, not 1.', p, gname{j}, ...
                strjoin(groups{j}, ', '), tot);
        end
    end
end
c = o.switching.costs;
if ~isempty(c)
    if ~(isstruct(c) && isscalar(c))
        error(ID, 'Option "switching.costs" must be a struct by type name, or [].');
    end
    f = fieldnames(c)';
    bad = setdiff(f, known);
    if ~isempty(bad)
        error(ID, 'Option "switching.costs": %s not a type of the population (%s).', strjoin(bad, ', '), strjoin(known, ', '));
    end
    for j = 1:numel(f)
        num(c.(f{j}), @(x) x >= 0 && isfinite(x), ['switching.costs.' f{j}], '>= 0');
    end
end
end


function enum(val, allowed, name)
if ~any(strcmp(val, allowed))
    error('hetlearn:options:value', 'Option "%s" = ''%s'' is not one of: %s.', ...
        name, val, strjoin(allowed, ', '));
end
end


function num(val, test, name, what)
if ~(isnumeric(val) && isscalar(val) && isreal(val) && ~isnan(val) && test(double(val)))
    error('hetlearn:options:value', 'Option "%s" must be a numeric scalar %s.', name, what);
end
end


function fn(rule, pkg)
if isempty(which(['hetlearn.' pkg '.' rule]))
    error('hetlearn:options:value', ...
        'Option "%s.rule" = ''%s'': no function hetlearn.%s.%s found.', pkg, rule, pkg, rule);
end
end


function validate_gain(o)
% gain.koz.* (DESIGN 18); master names are checked against the PLM by hetlearn.gain.koz
k = o.gain.koz;
enum(k.structure, {'common', 'per_variable'}, 'gain.koz.structure');
enum(k.error, {'rls', 'forecast'}, 'gain.koz.error');
num(k.mu, @(x) x >= 0 && isfinite(x), 'gain.koz.mu', '>= 0 (0 = constant gain)');
num(k.error_scale, @(x) x > 0 && isfinite(x), 'gain.koz.error_scale', '> 0');
num(k.Rg0, @(x) isfinite(x), 'gain.koz.Rg0', '(finite)');
b = k.bounds;
if ~(isnumeric(b) && isreal(b) && numel(b) == 2 && all(isfinite(b(:))) && b(1) > 0 ...
        && b(1) <= b(2) && b(2) <= 1)
    error('hetlearn:options:value', ...
        'Option "gain.koz.bounds" must be [lower, upper] with 0 < lower <= upper <= 1.');
end
if ~isempty(k.gamma0)
    num(k.gamma0, @(x) x > 0 && x <= 1, 'gain.koz.gamma0', 'in (0, 1], or []');
end
bad = k.master(~cellfun(@isvarname, k.master));
if ~isempty(bad)
    error('hetlearn:options:value', 'Option "gain.koz.master" must hold variable names; not valid: %s.', ...
        strjoin(bad, ', '));
end
if strcmp(o.gain.rule, 'koz')
    if isempty(k.gamma0)
        g0 = o.gain.value;
        src = 'gain.value';
        if strcmp(k.structure, 'per_variable')
            gv = cell2mat(struct2cell(o.gain.by_var));
            g0 = [g0; gv(:)];
            src = 'gain.value and gain.by_var';
        end
    else
        g0 = k.gamma0;
        src = 'gain.koz.gamma0';
    end
    if any(g0 < b(1) | g0 > b(2))
        error('hetlearn:options:value', ...
            'gain.rule = ''koz'': the initial gain (%s = %s) must lie inside gain.koz.bounds [%g, %g].', ...
            src, mat2str(g0(:)', 4), b(1), b(2));
    end
end
end


function validate_policy(o)
% policy.* (DESIGN 13); target names are checked against spec.policy by
% hetlearn.policy.setup
p = o.policy;
enum(p.mode, {'rule', 'ramsey'}, 'policy.mode');
enum(p.type, {'commitment', 'discretion'}, 'policy.type');
if ~isstruct(p.loss) || ~isscalar(p.loss) || ~all(cellfun(@(f) isnumeric(p.loss.(f)) ...
        && isscalar(p.loss.(f)) && isfinite(p.loss.(f)) && p.loss.(f) >= 0, fieldnames(p.loss)))
    error('hetlearn:options:value', 'Option "policy.loss" must be a struct of non-negative weights by target name.');
end
if ~isempty(p.discount)
    num(p.discount, @(x) x > 0 && x <= 1, 'policy.discount', 'in (0, 1]');
end
if ~isempty(p.loss_horizon)
    num(p.loss_horizon, @(x) x >= 1 && x == round(x), 'policy.loss_horizon', 'a positive integer');
end
end


function validate_density(o)
% history.realtime and density.* (DESIGN 14, 17)
flag(o.history.realtime, 'history.realtime');
d = o.density;
flag(d.enabled, 'density.enabled');
flag(d.keep_draws, 'density.keep_draws');
flag(d.fast_path, 'density.fast_path');
enum(d.sigma, {'calibrated', 'smoothed'}, 'density.sigma');
enum(d.method, {'normal', 'bootstrap'}, 'density.method');
num(d.ndraws, @(x) x >= 1 && x == round(x), 'density.ndraws', 'a positive integer');
num(d.seed, @(x) x >= 0 && x == round(x), 'density.seed', 'a non-negative integer');
q = d.quantiles;
if ~(isnumeric(q) && isvector(q) && isreal(q) && all(q > 0 & q < 1))
    error('hetlearn:options:value', 'Option "density.quantiles" must be a vector of numbers in (0, 1).');
end
if logical(d.enabled) && isempty(d.shocks)
    error('hetlearn:options:missing', 'density.enabled = true needs density.shocks.');
end
end


function flag(val, name)
if ~(islogical(val) || isnumeric(val)) || ~isscalar(val)
    error('hetlearn:options:type', 'Option "%s" must be true or false.', name);
end
end
