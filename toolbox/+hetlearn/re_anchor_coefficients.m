function [A, info] = re_anchor_coefficients(spec, P, varargin)
%RE_ANCHOR_COEFFICIENTS  Coefficients of the anchored RE forecast E_t x_{t+1} = k_x + c_x' s_t (DESIGN 11).
%
%   [A, info] = hetlearn.re_anchor_coefficients(spec, P)
%   [A, info] = hetlearn.re_anchor_coefficients(spec, P, 'vars', fwd, ...
%                   'states', states, 'ref_file', file, 'model', mo, 'check', true)
%
%   Inputs
%     spec  model spec (hetlearn.load_spec); linear models only
%     P     struct of parameter values (output of spec.params); [] calls
%           spec.params
%   Options
%     'vars'      cellstr of forward-looking variables (default: forward_vars
%                 of hetlearn.extend_model(spec, 'ar1', 'validate', false))
%     'states'    expected state list (meta.re_states of the generated file);
%                 error hetlearn:anchor:stale if the model's list differs
%     'ref_file'  model file of the original model (default: meta.ref_file)
%     'model'     IRIS model of the ORIGINAL model, parameters assigned and
%                 solved (skips loading)
%     'check'     unit-perturbation check (default true)
%     'tol'       check tolerance (default 1e-9, times max(1, |coefficient|))
%
%   Outputs
%     A     struct of parameter values: are_<x>__const = k_x and, for each
%           state, are_<x>__<v> (current value) or are_<x>__<v>_l<k> (lag k)
%           (names from hetlearn.plm.anchor_names)
%     info  struct: .states (cellstr, get(m,'xbVector') of the original
%           model), .vars, .k.<x>, .c.<x> (column, aligned with .states),
%           .param_names.<x>, .check_maxdiff (NaN if not checked)
%
%   Method. With sspace(m, 'triangular', false) the RE solution is
%   [xf; xb]_t = T*xb_{t-1} + K + R*e_t, xb the predetermined states incl.
%   auxiliary lags (get(m,'xbVector')), so E_t x_{t+1} = K(i) + T(i,:)*xb_t
%   with i the position of x in get(m,'xVector'). Check: a databank with
%   nb+1 columns sets the state at t to 0 (column 1) and to each unit vector
%   (column 1+j); one IRIS simulate of t+1 with zero shocks must return k_x
%   and k_x + c_x(j) (error hetlearn:anchor:check otherwise).
%
%   Lagged RE information ('re_info', 'lagged'; DESIGN 19). The RE agents
%   forecast with the RE(t-1) model: the original model with E_{t-1} x_{t+1}
%   in place of E_t x_{t+1} for the learning set, given as 'model' (the
%   model-consistent lagged RE model of the lagged generated file at n1 = 1,
%   solved; its predetermined vector holds the original states and the chain
%   state x_REt2 of each learning variable, x_REt2_{t-1} = E_{t-1} x_{t+1}).
%   'vars' = the learning set, 'chain' = meta.re_chain, 'states' = the
%   original model's states (meta.re_states, required). Then
%     E_{t-1} x_{t+1} = K(i) + T(i,:)*(K_b + T_b*xb_{t-1}) = k_x + C_s(x,:)*s_{t-1} + C_z(x,:)*z_{t-1}
%   (T_b, K_b the rows of xb; s = original states, z = chain states). The
%   chain state z_{t-1} is the RE agents' own forecast formed with
%   information up to t-1, which in the heterogeneous economy is x_exp1_RE_t
%   itself, so f = k + C_s*s_{t-1} + C_z*f gives
%     x_exp1_RE_t = (I - C_z)^{-1} (k + C_s*s_{t-1}),
%   a linear function of the original states dated t-1 (on the RE(t-1) path
%   z_{t-1} satisfies the same equation, so the anchored model at n1 = 1 is
%   the RE(t-1) model). A are the same parameter names as for 'current', with
%   these values for the learning set (0 for the other variables); the
%   expression in the lagged generated file dates every state one period
%   earlier. Other states of 'model' (PLM lags, derived regressors) must have
%   coefficients below 1e-12 (error hetlearn:anchor:lagged). Check: a
%   two-period IRIS simulate of 'model' from each unit state with zero shocks
%   returns k_x + c_x(j) for x_{t+1} (the coefficients on xb_{t-1}).
%   info also holds .re_info, .cz (C_z), .k_full/.c_full (on xb_{t-1} of
%   'model'), .xb (its xbVector) and .fixed_point_rcond.
%
%   This is a wrapper:
%   the coefficients and the check come from hetlearn.anchor_coefficients
%   (j = 0, h = 1 on the original model; j = 1, h = 1 with the chain x_REt2 on
%   the lagged RE model), computed with the same operations, so A and info are
%   unchanged.
%
%   See also hetlearn.anchor_coefficients, hetlearn.extend_model, hetlearn.load_model,
%   hetlearn.plm.anchor_names.

ip = inputParser;
ip.addParameter('vars', {});
ip.addParameter('states', []);
ip.addParameter('ref_file', '');
ip.addParameter('model', []);
ip.addParameter('check', true);
ip.addParameter('tol', 1e-9);
ip.addParameter('re_info', 'current');
ip.addParameter('chain', struct());
ip.parse(varargin{:});
o = ip.Results;

if ~logical(spec.linear)
    error('hetlearn:anchor:linear', ...
        'The anchored RE variant is implemented for linear models only (%s is nonlinear).', spec.name);
end
if strcmp(char(o.re_info), 'lagged')
    [A, info] = lagged_coefficients(o);
    return
end
vars = o.vars;
refFile = o.ref_file;
if isempty(vars) || (isempty(refFile) && isempty(o.model))
    meta = hetlearn.extend_model(spec, 'ar1', 'validate', false);
    if isempty(vars)
        vars = meta.forward_vars;
    end
    if isempty(refFile)
        refFile = meta.ref_file;
    end
end
vars = reshape(cellstr(vars), 1, []);

% ---- solved original model ----------------------------------------------------------
mo = o.model;
if isempty(mo)
    if nargin < 2 || isempty(P)
        P = call_params(spec);
    end
    assign0 = struct();
    if isfield(spec, 'assign') && isstruct(spec.assign) && ~isempty(spec.assign)
        assign0 = spec.assign;
    end
    mo = Model.fromFile(refFile, 'linear', true, 'assign', assign0);
    names = fieldnames(get(mo, 'parameters'));
    eList = cellstr(get(mo, 'eList'));
    f = fieldnames(P);
    keep = ismember(f, names) | ismember(f, strcat('std_', eList)) | strncmp(f, 'corr_', 5);
    Pm = struct();
    for i = find(keep)'
        Pm.(f{i}) = P.(f{i});
    end
    mo = assign(mo, Pm);
    [mo, flag] = solve(mo);
    if ~hasSucceeded(flag)
        error('hetlearn:anchor:solve', 'The original RE model does not solve: %s.', char(string(flag)));
    end
end
mo = sstate(mo);


% ---- coefficients: hetlearn.anchor_coefficients, j = 0, h = 1 (DESIGN 11) -------------------
states = reshape(cellstr(get(mo, 'xbVector')), 1, []);
if ~isempty(o.states) && ~isequal(reshape(cellstr(o.states), 1, []), states)
    error('hetlearn:anchor:stale', ...
        ['The state vector of the original model differs from the one in the generated ' ...
        'file (regenerate with hetlearn.extend_model(..., ''force'', true)).']);
end
xv = cellstr(get(mo, 'xVector'));
for i = 1:numel(vars)
    if ~any(strcmp(xv, vars{i}))
        error('hetlearn:anchor:noVar', '%s is not a transition variable of the original model.', vars{i});
    end
end
[Rc, ic] = hetlearn.anchor_coefficients(mo, vars, states, 'lag', 0, 'horizon', 1, ...
    'check', logical(o.check) && ~isempty(vars), 'tol', o.tol, 'what', 'anchored RE forecast');
A = struct();
info = struct('states', {states}, 'vars', {vars}, 'k', struct(), 'c', struct(), ...
    'param_names', struct(), 'check_maxdiff', ic.check_maxdiff);
for i = 1:numel(vars)
    x = vars{i};
    pn = hetlearn.plm.anchor_names(x, states);
    info.k.(x) = Rc.k(i);
    info.c.(x) = Rc.C(i, :)';
    info.param_names.(x) = pn;
    A.(pn{1}) = Rc.k(i);
    for j = 1:numel(states)
        A.(pn{1 + j}) = Rc.C(i, j);
    end
end
end


% =========================================================================
function [A, info] = lagged_coefficients(o)
% Anchored coefficients with information up to t-1 (DESIGN 19): hetlearn.anchor_coefficients with
% j = 1, h = 1 and the lagged RE chain x_REt2 of each learning variable as its lag-0 chain state.
mo = o.model;
if isempty(mo)
    error('hetlearn:anchor:lagged', ['re_info = ''lagged'' needs ''model'': the solved model-consistent ' ...
        'lagged RE model (lagged generated file, re_anchored = false, n1 = 1).']);
end
vars = reshape(cellstr(o.vars), 1, []);
states = reshape(cellstr(o.states), 1, []);
if isempty(vars) || isempty(states)
    error('hetlearn:anchor:lagged', 're_info = ''lagged'' needs ''vars'' (the learning set) and ''states''.');
end
xb = reshape(cellstr(get(mo, 'xbVector')), 1, []);
for j = 1:numel(states)
    if ~any(strcmp(xb, states{j}))
        error('hetlearn:anchor:lagged', 'State %s of the original model is not a state of the lagged RE model.', states{j});
    end
end
nL = numel(vars);
ch = struct('state', cell(1, nL), 'target', cell(1, nL), 'lag', cell(1, nL));
for i = 1:nL
    if ~isfield(o.chain, vars{i})
        error('hetlearn:anchor:lagged', 'No lagged RE chain for %s (meta.re_chain).', vars{i});
    end
    ch(i) = struct('state', o.chain.(vars{i}){2}, 'target', i, 'lag', 0);
end
[Rc, ic] = hetlearn.anchor_coefficients(mo, vars, states, 'lag', 1, 'horizon', 1, 'chain', ch, ...
    'check', logical(o.check), 'tol', o.tol, 'error_id', 'hetlearn:anchor:lagged', ...
    'what', 'lagged RE forecast');
A = struct();
info = struct('states', {states}, 'vars', {vars}, 'k', struct(), 'c', struct(), ...
    'param_names', struct(), 'check_maxdiff', ic.check_maxdiff, 're_info', 'lagged', 'cz', ic.cz, ...
    'k_full', ic.k_full, 'c_full', ic.c_full, 'xb', {ic.xb}, 'fixed_point_rcond', ic.fixed_point_rcond);
for i = 1:nL
    x = vars{i};
    pn = hetlearn.plm.anchor_names(x, states);
    info.k.(x) = Rc.k(i);
    info.c.(x) = Rc.C(i, :)';
    info.param_names.(x) = pn;
    A.(pn{1}) = Rc.k(i);
    for j = 1:numel(states)
        A.(pn{1 + j}) = Rc.C(i, j);
    end
end
end



function P = call_params(spec)
added = false;
if ~any(strcmpi(strsplit(path, pathsep), spec.folder))
    addpath(spec.folder);
    added = true;
end
c = onCleanup(@() cleanup(added, spec.folder));
P = feval(spec.params);
end


function cleanup(added, folder)
if added
    rmpath(folder);
end
end
