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
%   See also hetlearn.extend_model, hetlearn.load_model, hetlearn.plm.anchor_names.

ip = inputParser;
ip.addParameter('vars', {});
ip.addParameter('states', []);
ip.addParameter('ref_file', '');
ip.addParameter('model', []);
ip.addParameter('check', true);
ip.addParameter('tol', 1e-9);
ip.parse(varargin{:});
o = ip.Results;

if ~logical(spec.linear)
    error('hetlearn:anchor:linear', ...
        'The anchored RE variant is implemented for linear models only (%s is nonlinear).', spec.name);
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
