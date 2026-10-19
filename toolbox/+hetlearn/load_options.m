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
%     forecast.horizon positive integer);
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
REPLACE = {'conditions', 'policy.loss'};
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
enum(o.beliefs.update, {'rls', 'fixed'}, 'beliefs.update');
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
if strcmp(o.expectations.mode, 'fixed_shares') && isempty(f2)
    error('hetlearn:options:missing', ...
        'expectations.mode = ''fixed_shares'' needs shares.fixed_n2.');
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
num(o.switching.intensity, @(x) x >= 0, 'switching.intensity', '>= 0');
num(o.switching.memory, @(x) x >= 0 && x < 1, 'switching.memory', 'in [0, 1)');
enum(o.projection.facility, {'plm_alm', 'alm', 'none'}, 'projection.facility');
if ~(islogical(o.history.learn) || isnumeric(o.history.learn)) || ~isscalar(o.history.learn)
    error('hetlearn:options:type', 'Option "history.learn" must be true or false.');
end
if strcmp(o.history.mode, 'hetero_filter')
    error('hetlearn:options:notImplemented', ...
        'history.mode = ''hetero_filter'' is a planned hook and is not implemented.');
end
enum(o.history.mode, {'re_smoother', 'inversion'}, 'history.mode');
enum(o.history.re_states, {'smoothed', 'filtered'}, 'history.re_states');
if strcmp(o.history.re_states, 'filtered') && strcmp(o.history.mode, 'inversion')
    % an error rather than a silently ignored option: the run would equal the 'smoothed' one
    error('hetlearn:options:value', ['history.re_states = ''filtered'' applies to history.mode = ' ...
        '''re_smoother'' only. The inversion is one-sided by construction (period t uses data up to t); ' ...
        'leave history.re_states at ''smoothed'' there.']);
end
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
