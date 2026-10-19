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
%   See also hetlearn.extend_model, hetlearn.load_model, hetlearn.plm.anchor_names.

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

% ---- coefficients from the state-space form ---------------------------------------------
xv = cellstr(get(mo, 'xVector'));
states = reshape(cellstr(get(mo, 'xbVector')), 1, []);
if ~isempty(o.states) && ~isequal(reshape(cellstr(o.states), 1, []), states)
    error('hetlearn:anchor:stale', ...
        ['The state vector of the original model differs from the one in the generated ' ...
        'file (regenerate with hetlearn.extend_model(..., ''force'', true)).']);
end
[T, ~, K] = sspace(mo, 'triangular', false);
T = T(:, :, 1);
K = K(:, 1, 1);
if size(T, 2) ~= numel(states)
    error('hetlearn:anchor:size', 'sspace: %d state columns but %d xb names.', size(T, 2), numel(states));
end
A = struct();
info = struct('states', {states}, 'vars', {vars}, 'k', struct(), 'c', struct(), ...
    'param_names', struct(), 'check_maxdiff', NaN);
for i = 1:numel(vars)
    x = vars{i};
    pos = find(strcmp(xv, x), 1);
    if isempty(pos)
        error('hetlearn:anchor:noVar', '%s is not a transition variable of the original model.', x);
    end
    pn = hetlearn.plm.anchor_names(x, states);
    info.k.(x) = K(pos);
    info.c.(x) = T(pos, :)';
    info.param_names.(x) = pn;
    A.(pn{1}) = K(pos);
    for j = 1:numel(states)
        A.(pn{1 + j}) = T(pos, j);
    end
end

% ---- unit-perturbation check -----------------------------------------------------------------
if logical(o.check) && ~isempty(vars)
    [~, sv, sl] = hetlearn.plm.anchor_names(vars{1}, states);
    nb = numel(states);
    nc = nb + 1;
    L = max([sl, 0]);
    t0 = qq(2000, 4);
    rng = t0 - L : t0 + 1;
    db = struct();
    xl = cellstr(get(mo, 'xList'));
    el = cellstr(get(mo, 'eList'));
    Z = zeros(numel(rng), nc);
    for i = 1:numel(xl)
        X = Z;
        if any(strcmp(sv, xl{i}))
            for j = find(strcmp(sv, xl{i}))
                X(L + 1 - sl(j), 1 + j) = 1;     % row of date t0 - lag
            end
        end
        db.(xl{i}) = Series(rng(1), X);
    end
    for i = 1:numel(el)
        db.(el{i}) = Series(rng(1), Z);
    end
    s = simulate(mo, db, t0 + 1 : t0 + 1, 'prependInput', true, 'anticipate', false);
    worst = 0;
    for i = 1:numel(vars)
        x = vars{i};
        v = reshape(s.(x)(t0 + 1), 1, []);
        if numel(v) ~= nc
            error('hetlearn:anchor:check', 'Unit-perturbation simulation returned %d columns, expected %d.', numel(v), nc);
        end
        kx = info.k.(x);
        cx = info.c.(x)';
        dk = abs(v(1) - kx) / max(1, abs(kx));
        dc = abs((v(2:end) - v(1)) - cx) ./ max(1, abs(cx));
        worst = max([worst, dk, dc]);
    end
    info.check_maxdiff = worst;
    if ~(worst < o.tol)
        error('hetlearn:anchor:check', ...
            ['Anchored RE coefficients from sspace differ from the unit-perturbation ' ...
            'simulations by %.3g (tolerance %g).'], worst, o.tol);
    end
end
end


% =========================================================================
function [A, info] = lagged_coefficients(o)
% Anchored coefficients with information up to t-1 (DESIGN 19).
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
xv = cellstr(get(mo, 'xVector'));
xb = reshape(cellstr(get(mo, 'xbVector')), 1, []);
nx = numel(xv);
nb = numel(xb);
nf = nx - nb;
[T, ~, K] = sspace(mo, 'triangular', false);
T = T(:, :, 1);
K = K(:, 1, 1);
if size(T, 1) ~= nx || size(T, 2) ~= nb
    error('hetlearn:anchor:size', 'sspace: %d x %d transition matrix for %d x %d names.', size(T, 1), size(T, 2), nx, nb);
end
Tb = T(nf+1:end, :);
Kb = K(nf+1:end);
nL = numel(vars);
kf = zeros(nL, 1);
Cf = zeros(nL, nb);
for i = 1:nL
    pos = find(strcmp(xv, vars{i}), 1);
    if isempty(pos)
        error('hetlearn:anchor:noVar', '%s is not a transition variable of the lagged RE model.', vars{i});
    end
    Cf(i, :) = T(pos, :) * Tb;               % E_{t-1} x_{t+1} on xb_{t-1}
    kf(i) = T(pos, :) * Kb + K(pos);
end
% columns: original states, chain states (x_REt2 of each learning variable), the rest
iS = zeros(1, numel(states));
for j = 1:numel(states)
    q = find(strcmp(xb, states{j}), 1);
    if isempty(q)
        error('hetlearn:anchor:lagged', 'State %s of the original model is not a state of the lagged RE model.', states{j});
    end
    iS(j) = q;
end
iZ = zeros(1, nL);
for i = 1:nL
    if ~isfield(o.chain, vars{i})
        error('hetlearn:anchor:lagged', 'No lagged RE chain for %s (meta.re_chain).', vars{i});
    end
    z = o.chain.(vars{i}){2};
    q = find(strcmp(xb, z), 1);
    if isempty(q)
        error('hetlearn:anchor:lagged', 'The chain state %s is not a state of the lagged RE model.', z);
    end
    iZ(i) = q;
end
iO = setdiff(1:nb, [iS, iZ]);
big = max([0, max(max(abs(Cf(:, iO))))]);
if big >= 1e-12
    [~, w] = max(max(abs(Cf(:, iO)), [], 1));
    error('hetlearn:anchor:lagged', ['The lagged RE forecast loads on %s (coefficient %.3g), a state that is ' ...
        'neither an original state nor a lagged RE chain state.'], xb{iO(w)}, big);
end
Cs = Cf(:, iS);
Cz = Cf(:, iZ);
M = eye(nL) - Cz;
rc = rcond(M);
if ~(rc > 1e-12)
    error('hetlearn:anchor:lagged', ['I - C_z is singular (rcond %.3g): the RE agents'' own lagged forecasts ' ...
        'do not pin down the anchored forecast.'], rc);
end
kt = M \ kf;
Ct = M \ Cs;
A = struct();
info = struct('states', {states}, 'vars', {vars}, 'k', struct(), 'c', struct(), ...
    'param_names', struct(), 'check_maxdiff', NaN, 're_info', 'lagged', 'cz', Cz, ...
    'k_full', kf, 'c_full', Cf, 'xb', {xb}, 'fixed_point_rcond', rc);
for i = 1:nL
    x = vars{i};
    pn = hetlearn.plm.anchor_names(x, states);
    info.k.(x) = kt(i);
    info.c.(x) = Ct(i, :)';
    info.param_names.(x) = pn;
    A.(pn{1}) = kt(i);
    for j = 1:numel(states)
        A.(pn{1 + j}) = Ct(i, j);
    end
end
% ---- check: two-period simulations from each unit state, zero shocks ------------------
if logical(o.check)
    [~, sv, sl] = hetlearn.plm.anchor_names(vars{1}, xb);
    nc = nb + 1;
    Lg = max([sl, 0]);
    t0 = qq(2000, 4);
    rng = t0 - Lg : t0 + 2;
    db = struct();
    xl = cellstr(get(mo, 'xList'));
    el = cellstr(get(mo, 'eList'));
    Z0 = zeros(numel(rng), nc);
    for i = 1:numel(xl)
        X = Z0;
        for j = find(strcmp(sv, xl{i}))
            X(Lg + 1 - sl(j), 1 + j) = 1;        % row of date t0 - lag
        end
        db.(xl{i}) = Series(rng(1), X);
    end
    for i = 1:numel(el)
        db.(el{i}) = Series(rng(1), Z0);
    end
    s = simulate(mo, db, t0 + 1 : t0 + 2, 'prependInput', true, 'anticipate', false);
    worst = 0;
    for i = 1:nL
        v = reshape(s.(vars{i})(t0 + 2), 1, []);
        if numel(v) ~= nc
            error('hetlearn:anchor:check', 'Unit-perturbation simulation returned %d columns, expected %d.', numel(v), nc);
        end
        dk = abs(v(1) - kf(i)) / max(1, abs(kf(i)));
        dc = abs((v(2:end) - v(1)) - Cf(i, :)) ./ max(1, abs(Cf(i, :)));
        worst = max([worst, dk, dc]);
    end
    info.check_maxdiff = worst;
    if ~(worst < o.tol)
        error('hetlearn:anchor:check', ['Lagged anchored RE coefficients from sspace differ from the two-period ' ...
            'unit-perturbation simulations by %.3g (tolerance %g).'], worst, o.tol);
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
