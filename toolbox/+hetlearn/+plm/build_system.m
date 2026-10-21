function sys = build_system(plm, learnVars, allVarNames, info, suffix)
%BUILD_SYSTEM  Normalise a PLM spec and build the closed PLM system (DESIGN 4.2, 12).
%
%   sys = hetlearn.plm.build_system(plm, learnVars, allVarNames)
%   sys = hetlearn.plm.build_system(plm, learnVars, allVarNames, info)
%   sys = hetlearn.plm.build_system(plm, learnVars, allVarNames, info, suffix)
%
%   info (optional, default 'lagged') is the BR information set,
%   beliefs.info: 'lagged' (data up to t-1) or 'current' (period-t data,
%   IJCB eq. 12). It is recorded as sys.info, which hetlearn.plm.forecast_expr
%   and hetlearn.plm.forecast_value use by default; the equations, RLS
%   regressors and companion matrix do not depend on it.
%
%   suffix (optional, default '' = none): the name of an agent type
%   (expectations.types, DESIGN_br_extensions 1.1). Every parameter name gets
%   '__<suffix>' appended (alpha_pinf__BR, beta_pinf__BR,
%   beta_pinf__w_l2__BR), so that several learning types can hold their own
%   beliefs in one model; sys.suffix records it. Targets, regressors and
%   everything else are unchanged. Without a suffix the output has no field
%   suffix and is the same as before (2026-10-20).
%
%   Inputs
%     plm          PLM spec: a shorthand char ('ar1' | 'ar2' | 'ar1_noconst' |
%                  'var1'), or a struct with fields
%                    .default  shorthand char (default 'ar1'); 'var1' = a
%                              VAR(1) with constant over the learning set
%                    .by_var   struct; by_var.<x> is a shorthand char or a
%                              struct with .regressors (cellstr such as
%                              {'pinf{-1}','w{-2}'}; lags >= 1 only) and
%                              .constant (logical, default true).
%                    .derived  struct of strings: derived.<name> = linear
%                              expression in current-dated model variables
%                              (DESIGN 12). <name> is a valid regressor and
%                              PLM target here; hetlearn.extend_model adds
%                              the variable and its equation to the model.
%                    .var      struct('variables', <cellstr | 'learning'>,
%                              'lags', p, 'constant', true|false): every
%                              member v gets v_t = alpha_v + sum over members
%                              u and l = 1..p of beta_v__u_l<l> * u{-l};
%                              members that are not learning variables are
%                              auxiliary equations of the VAR. Empty
%                              .variables = no VAR. 'learning' = learnVars.
%                  by_var entries may name any transition variable except a
%                  VAR member (error hetlearn:plm:varByVar); an entry for a
%                  non-learning variable sets its auxiliary PLM.
%     learnVars    cellstr of learning (forward-looking) variables; each gets
%                  a primary PLM (VAR equation if a member, else by_var.<x>
%                  if given, else plm.default).
%     allVarNames  cellstr of all transition variables (regressor names are
%                  checked against it); derived names are added to it.
%
%   Output
%     sys  struct with
%       .eq(i)        one PLM equation per target, fields
%           target      variable name
%           isAux       true for auxiliary PLMs added to close the system
%           constant    logical
%           reg_names   cellstr of regressor variable names
%           reg_lags    row vector of lags (>= 1), aligned with reg_names
%           param_names cellstr: 'alpha_<x>' (if constant) then the beta
%                       names. AR(1) with constant on the own lag only:
%                       {'alpha_x','beta_x'}; any other PLM:
%                       'beta_<x>__<u>_l<l>' per regressor.
%       .targets      cellstr of eq targets (same order as .eq)
%       .learn        learnVars (row cellstr)
%       .maxlag       largest regressor lag in the system
%       .var          struct: .variables (resolved member list, {} if no
%                     VAR), .lags, .constant
%       .derived      struct of derived-variable expressions (char)
%       .info         'lagged' | 'current' (BR information set, see above)
%
%   Auxiliary PLMs: every regressor variable without its own PLM gets
%   by_var.<u> if given, else an AR(1) with constant; repeated until the
%   system is closed (VAR members always get the VAR equation). Coefficient
%   vectors phi.<target> are ordered like param_names (constant first when
%   present). VAR regressors are ordered lag first, then members in
%   .var.variables order.
%
%   See also hetlearn.plm.forecast_expr, hetlearn.plm.forecast_value,
%   hetlearn.plm.companion, hetlearn.plm.param_values.

if nargin < 1 || isempty(plm)
    plm = 'ar1';
end
if ischar(plm) || isstring(plm)
    plm = struct('default', char(plm), 'by_var', struct());
end
if ~isstruct(plm)
    error('hetlearn:plm:type', 'PLM spec must be a shorthand string or a struct.');
end
if ~isfield(plm, 'default') || isempty(plm.default)
    plm.default = 'ar1';
end
if ~isfield(plm, 'by_var') || isempty(plm.by_var)
    plm.by_var = struct();
end
learnVars = reshape(cellstr(learnVars), 1, []);
allVarNames = reshape(cellstr(allVarNames), 1, []);

% derived regressors are variables of the extended model
derived = derived_spec(plm);
derNames = fieldnames(derived)';
allVarNames = [allVarNames, setdiff(derNames, allVarNames, 'stable')];

bad = setdiff(learnVars, allVarNames);
if ~isempty(bad)
    error('hetlearn:plm:unknownVar', 'Learning variable(s) not in the model: %s.', strjoin(bad, ', '));
end
bad = setdiff(fieldnames(plm.by_var)', allVarNames);
if ~isempty(bad)
    error('hetlearn:plm:unknownVar', 'beliefs.plm.by_var names variable(s) not in the model: %s.', ...
        strjoin(bad, ', '));
end

% VAR learning (DESIGN 12)
[V, vLags, vConst, defNonVar] = var_spec(plm, learnVars, allVarNames);
inVar = intersect(fieldnames(plm.by_var)', V);
if ~isempty(inVar)
    error('hetlearn:plm:varByVar', ...
        'beliefs.plm.by_var sets a PLM for VAR member(s) %s; VAR members use the VAR equation.', ...
        strjoin(inVar, ', '));
end

queue = learnVars;
isAuxQ = false(size(queue));
eq = struct('target', {}, 'isAux', {}, 'constant', {}, 'reg_names', {}, ...
    'reg_lags', {}, 'param_names', {});
done = {};
k = 0;
while k < numel(queue)
    k = k + 1;
    x = queue{k};
    if any(strcmp(done, x))
        continue
    end
    if any(strcmp(V, x))
        e = var_eq(x, V, vLags, vConst);
    elseif isfield(plm.by_var, x)
        e = one_spec(plm.by_var.(x), x, allVarNames);
    elseif ~isAuxQ(k)
        e = one_spec(defNonVar, x, allVarNames);
    else
        e = one_spec('ar1', x, allVarNames);
    end
    e.target = x;
    e.isAux = isAuxQ(k);
    e.param_names = param_names(e);
    eq(end+1) = orderfields(e, eq); %#ok<AGROW>
    done{end+1} = x; %#ok<AGROW>
    for j = 1:numel(e.reg_names)
        u = e.reg_names{j};
        if ~any(strcmp(queue, u))
            queue{end+1} = u; %#ok<AGROW>
            isAuxQ(end+1) = true; %#ok<AGROW>
        end
    end
end

sys = struct();
sys.eq = eq;
sys.targets = {eq.target};
sys.learn = learnVars;
lags = [eq.reg_lags];
if isempty(lags)
    sys.maxlag = 0;
else
    sys.maxlag = max(lags);
end
sys.var = struct('variables', {V}, 'lags', vLags, 'constant', vConst);
sys.derived = derived;
if nargin < 4 || isempty(info)
    info = 'lagged';
end
info = char(info);
if ~any(strcmp(info, {'lagged', 'current'}))
    error('hetlearn:plm:info', 'beliefs.info must be ''lagged'' or ''current'' (got ''%s'').', info);
end
sys.info = info;
if nargin >= 5 && ~isempty(suffix)
    % agent type (DESIGN_br_extensions 1.1): type-suffixed parameter names
    suffix = char(suffix);
    for i = 1:numel(sys.eq)
        sys.eq(i).param_names = strcat(sys.eq(i).param_names, ['__' suffix]);
    end
    sys.suffix = suffix;
end
end


% -------------------------------------------------------------------------
function d = derived_spec(plm)
% beliefs.plm.derived: struct of strings, field names = new variable names.
d = struct();
if ~isfield(plm, 'derived') || isempty(plm.derived)
    return
end
if ~isstruct(plm.derived) || ~isscalar(plm.derived)
    error('hetlearn:plm:derived', 'beliefs.plm.derived must be a struct of strings.');
end
f = fieldnames(plm.derived);
for i = 1:numel(f)
    v = plm.derived.(f{i});
    if isstring(v) && isscalar(v)
        v = char(v);
    end
    if ~ischar(v) || isempty(strtrim(v))
        error('hetlearn:plm:derived', ...
            'beliefs.plm.derived.%s must be a non-empty string (a linear expression).', f{i});
    end
    d.(f{i}) = strtrim(reshape(v, 1, []));
end
end


% -------------------------------------------------------------------------
function [V, p, cst, defNonVar] = var_spec(plm, learnVars, allVarNames)
% Resolve beliefs.plm.var and the shorthand default 'var1'.
V = {};
p = 1;
cst = true;
defNonVar = plm.default;
vs = struct('variables', {{}}, 'lags', 1, 'constant', true);
if isfield(plm, 'var') && ~isempty(plm.var)
    if ~isstruct(plm.var) || ~isscalar(plm.var)
        error('hetlearn:plm:var', 'beliefs.plm.var must be a struct (variables, lags, constant).');
    end
    extra = setdiff(fieldnames(plm.var), fieldnames(vs));
    if ~isempty(extra)
        error('hetlearn:plm:var', 'beliefs.plm.var has unknown field(s): %s.', strjoin(extra, ', '));
    end
    f = fieldnames(plm.var);
    for i = 1:numel(f)
        if ~isempty(plm.var.(f{i})) || strcmp(f{i}, 'variables')
            vs.(f{i}) = plm.var.(f{i});
        end
    end
end
vv = vs.variables;
if isstring(vv)
    vv = cellstr(vv);
end
if ischar(plm.default) && strcmp(plm.default, 'var1')
    if ~isempty(vv)
        error('hetlearn:plm:var', ['beliefs.plm.default = ''var1'' and beliefs.plm.var.variables ' ...
            'are both set; use one of them.']);
    end
    V = learnVars;
    defNonVar = 'ar1';
    return
end
if ischar(vv) && strcmpi(vv, 'learning')
    V = learnVars;
elseif ischar(vv) && ~isempty(vv)
    V = {vv};
elseif iscellstr(vv)
    V = reshape(vv, 1, []);
elseif ~isempty(vv)
    error('hetlearn:plm:var', 'beliefs.plm.var.variables must be a cellstr or ''learning''.');
end
p = vs.lags;
if ~(isnumeric(p) && isscalar(p) && p >= 1 && p == round(p))
    error('hetlearn:plm:var', 'beliefs.plm.var.lags must be a positive integer.');
end
c = vs.constant;
if ~((islogical(c) || isnumeric(c)) && isscalar(c))
    error('hetlearn:plm:var', 'beliefs.plm.var.constant must be true or false.');
end
cst = logical(c);
if numel(unique(V)) < numel(V)
    error('hetlearn:plm:var', 'beliefs.plm.var.variables lists a variable twice.');
end
bad = setdiff(V, allVarNames);
if ~isempty(bad)
    error('hetlearn:plm:unknownVar', 'beliefs.plm.var.variables: not in the model: %s.', strjoin(bad, ', '));
end
end


% -------------------------------------------------------------------------
function e = var_eq(x, V, p, cst)
% VAR equation of member x: all members at lags 1..p (lag first).
n = numel(V);
e = struct('target', x, 'isAux', false, 'constant', cst, ...
    'reg_names', {repmat(V, 1, p)}, 'reg_lags', kron(1:p, ones(1, n)), 'param_names', {{}});
end


% -------------------------------------------------------------------------
function e = one_spec(s, x, allVarNames)
e = struct('target', x, 'isAux', false, 'constant', true, ...
    'reg_names', {{}}, 'reg_lags', zeros(1, 0), 'param_names', {{}});
if isstring(s), s = char(s); end
if ischar(s)
    switch s
        case 'ar1'
            e.reg_names = {x}; e.reg_lags = 1; e.constant = true;
        case 'ar2'
            e.reg_names = {x, x}; e.reg_lags = [1 2]; e.constant = true;
        case 'ar1_noconst'
            e.reg_names = {x}; e.reg_lags = 1; e.constant = false;
        otherwise
            error('hetlearn:plm:shorthand', ...
                ['Unknown PLM shorthand ''%s'' for %s (use ar1, ar2, ar1_noconst; ' ...
                '''var1'' only as beliefs.plm.default).'], s, x);
    end
    return
end
if ~isstruct(s)
    error('hetlearn:plm:type', 'beliefs.plm.by_var.%s must be a shorthand or a struct.', x);
end
extra = setdiff(fieldnames(s), {'regressors', 'constant'});
if ~isempty(extra)
    error('hetlearn:plm:field', 'beliefs.plm.by_var.%s has unknown field(s): %s.', x, strjoin(extra, ', '));
end
if isfield(s, 'constant') && ~isempty(s.constant)
    e.constant = logical(s.constant);
end
regs = {};
if isfield(s, 'regressors') && ~isempty(s.regressors)
    regs = cellstr(s.regressors);
end
for j = 1:numel(regs)
    tok = regexp(regs{j}, '^\s*([A-Za-z]\w*)\s*[\{\(\[]\s*(?:t\s*)?-\s*(\d+)\s*[\}\)\]]\s*$', 'tokens', 'once');
    if isempty(tok)
        error('hetlearn:plm:regressor', ...
            'PLM regressor ''%s'' for %s is not of the form name{-l} with l >= 1.', regs{j}, x);
    end
    l = str2double(tok{2});
    if l < 1
        error('hetlearn:plm:regressor', 'PLM regressor ''%s'' for %s must have a lag >= 1.', regs{j}, x);
    end
    if ~any(strcmp(allVarNames, tok{1}))
        error('hetlearn:plm:regressor', 'PLM regressor ''%s'' for %s: %s is not a transition variable.', ...
            regs{j}, x, tok{1});
    end
    e.reg_names{end+1} = tok{1};
    e.reg_lags(end+1) = l;
end
if ~isempty(e.reg_names)       % (a mean-only PLM, regressors {}, has none: 2026-10-21 fix, strcat failed)
    key = strcat(e.reg_names, '_', arrayfun(@num2str, e.reg_lags, 'UniformOutput', false));
    if numel(unique(key)) < numel(key)
        error('hetlearn:plm:regressor', 'Duplicate PLM regressors for %s.', x);
    end
end
if ~e.constant && isempty(e.reg_names)
    error('hetlearn:plm:empty', 'The PLM for %s has neither a constant nor regressors.', x);
end
end


% -------------------------------------------------------------------------
function p = param_names(e)
x = e.target;
simple = e.constant && numel(e.reg_names) == 1 && strcmp(e.reg_names{1}, x) && e.reg_lags(1) == 1;
p = {};
if e.constant
    p{end+1} = ['alpha_' x];
end
if simple
    p{end+1} = ['beta_' x];
    return
end
for j = 1:numel(e.reg_names)
    p{end+1} = sprintf('beta_%s__%s_l%d', x, e.reg_names{j}, e.reg_lags(j)); %#ok<AGROW>
end
end
