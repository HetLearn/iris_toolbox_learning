function [s, d, info] = step(m, d, t, cond)
%STEP  One-period simulation t:t with this period's shocks and conditions (DESIGN 5.5, 11).
%
%   [s, d, info] = hetlearn.engine.step(m, d, t, cond)
%   ss = hetlearn.engine.step('build', m, previous)    fast-step system of a solved model
%
%   Inputs
%     m     solved IRIS Model for period t (hetlearn.engine.solve_model)
%     d     databank: history up to t-1, shocks at t (and later)
%     t     period (IRIS date)
%     cond  conditions active at t: struct with .vars (cellstr, transition
%           or measurement variables), .shocks (cellstr, endogenised
%           shocks), .targets (column vector, one per variable); [] or
%           empty .vars for none
%
%   Outputs
%     s     output databank of simulate(m, d, t:t, 'prependInput', true)
%     d     input databank with the endogenised shocks at t set to the
%           values that put the variables on target
%     info  .n (number of targets), .maxerr (max abs target miss),
%           .backward (true if the backward system was used), .fast (true
%           if the fast state-space step was used), .events (struct array
%           date/type/variable/detail; one 'explosive' event when the
%           backward system was used, else empty)
%
%   With conditions: s0 = simulation with the scheduled shocks; for each
%   endogenised shock j a simulation with that shock +1 gives the response
%   matrix M(k,j); M*delta = target - s0 is solved exactly (square) or with
%   minimum norm (more shocks than targets); fewer shocks than targets, or a
%   rank-deficient M, is an error. The final simulation must hit every
%   target within 1e-9 (else error hetlearn:engine:conditions).
%   Minimum norm (review finding m10): with engine.conditions_weighting =
%   'std' (default; flag hetlearn_cond_weighting in the model's user data,
%   set by hetlearn.engine.core, missing = 'std') the norm is taken in units
%   of each shock's standard deviation, delta = S*pinv(M*S)*gap with
%   S = diag(std_<shock>) of m (min sum_j (delta_j/sigma_j)^2); every
%   endogenised shock then needs a positive std. 'none': delta =
%   pinv(M)*gap. The exactly identified case (M \ gap) is the same for both.
%
%   Backward models (DESIGN 11): when hetlearn.engine.solve_model stored a
%   backward system in the model's user data (no IRIS solution, no leads),
%   every simulation here, including the unit-shock simulations for the
%   conditions, is hetlearn.engine.backward_simulate instead of IRIS
%   simulate.
%
%   Fast step (B2, option engine.step = 'fast'). When solve_model cached the
%   state-space system of the IRIS solution in the model's user data (field
%   hetlearn_sspace, built by step('build', m, previous) from
%   sspace(m, 'triangular', false); names are reused from previous), period
%   t is computed directly:
%     [xf_t; xb_t] = T*xb_{t-1} + R*e_t + K,   y_t = Z*xb_t + H*e_t + D
%   with xb_{t-1} read from d (element v{-k} = v at t-1-k), NaN or missing
%   shocks = 0. Conditions use the exact response matrix (rows of R for
%   transition variables, Z*R_b + H for measurement variables) instead of
%   unit-shock simulations, with the same exact/minimum-norm solve, rank
%   check and 1e-9 target check. s is d with every transition variable
%   (current date), measurement variable and shock set at t. It equals IRIS
%   simulate to rounding (tests/test_inversion.m). A stored backward system
%   has priority and is unchanged; with engine.step = 'iris' no system is
%   cached and every simulation is IRIS simulate as before.

if ischar(m) || isstring(m)
    if ~strcmp(char(m), 'build')
        error('hetlearn:engine:step', 'Unknown call hetlearn.engine.step(''%s'', ...).', char(m));
    end
    if nargin < 3
        t = [];
    end
    s = build_fast(d, t);
    return
end
TOL = 1e-9;
bw = [];
ss = [];
u = userdata(m);
if isstruct(u) && isfield(u, 'hetlearn_backward')
    bw = u.hetlearn_backward;
elseif isstruct(u) && isfield(u, 'hetlearn_sspace') && ~isempty(u.hetlearn_sspace)
    ss = u.hetlearn_sspace;
end
w = 'std';
if isstruct(u) && isfield(u, 'hetlearn_cond_weighting') && ~isempty(u.hetlearn_cond_weighting)
    w = char(u.hetlearn_cond_weighting);
end
info = struct('n', 0, 'maxerr', 0, 'backward', ~isempty(bw), 'fast', ~isempty(ss), ...
    'events', struct('date', {}, 'type', {}, 'variable', {}, 'detail', {}));
if ~isempty(ss)
    [s, d, info] = fast_step(ss, d, t, cond, info, TOL, m, w);
    return
end
if isempty(bw)
    sim = @(dd) simulate(m, dd, t:t, 'prependInput', true);
else
    sim = @(dd) hetlearn.engine.backward_simulate(bw, dd, t);
    info.events = struct('date', double(t), 'type', 'explosive', 'variable', '', 'detail', sprintf( ...
        ['no stable IRIS solution (%s); period simulated with the backward system ' ...
        '(hetlearn.engine.backward_simulate), largest abs root %.6g'], bw.flag, bw.maxroot));
end
s = sim(d);
if isempty(cond) || isempty(cond.vars)
    return
end
vars = cond.vars;
shocks = cond.shocks;
target = cond.targets(:);
nk = numel(vars);
nj = numel(shocks);
if nj < nk
    error('hetlearn:engine:conditions', ...
        'Period %s: %d exogenised variables but only %d endogenised shocks.', ...
        char(dat2str(t)), nk, nj);
end
base = values_at(s, vars, t);
M = zeros(nk, nj);
for j = 1:nj
    dj = d;
    dj.(shocks{j})(t) = dj.(shocks{j})(t) + 1;
    sj = sim(dj);
    M(:, j) = values_at(sj, vars, t) - base;
end
if rank(M) < nk
    error('hetlearn:engine:conditions', ...
        'Period %s: the shocks {%s} cannot move {%s} independently (rank %d < %d).', ...
        char(dat2str(t)), strjoin(shocks, ','), strjoin(vars, ','), rank(M), nk);
end
gap = target - base;
delta = solve_shocks(M, gap, m, shocks, t, w);
for j = 1:nj
    d.(shocks{j})(t) = d.(shocks{j})(t) + delta(j);
end
s = sim(d);
miss = max(abs(values_at(s, vars, t) - target));
info.n = nk;
info.maxerr = miss;
if ~(miss < TOL)
    error('hetlearn:engine:conditions', 'Period %s: conditions missed by %.3g.', char(dat2str(t)), miss);
end
end


function v = values_at(s, names, t)
v = zeros(numel(names), 1);
for i = 1:numel(names)
    v(i) = s.(names{i})(t);
end
end


function delta = solve_shocks(M, gap, m, shocks, t, w)
% Shock changes that put the targets on target: exactly identified M \ gap;
% more shocks than targets: minimum norm, in std units of each shock ('std')
% or unweighted ('none').
[nk, nj] = size(M);
if nj == nk
    delta = M \ gap;
    return
end
switch w
    case 'none'
        delta = pinv(M) * gap;
    case 'std'
        sd = get(m, 'std');
        sig = NaN(nj, 1);
        for j = 1:nj
            f = ['std_' shocks{j}];
            if isfield(sd, f)
                sig(j) = double(sd.(f));
            end
        end
        bad = ~(isfinite(sig) & sig > 0);
        if any(bad)
            txt = arrayfun(@(j) sprintf('std_%s = %g', shocks{j}, sig(j)), find(bad), 'UniformOutput', false);
            error('hetlearn:engine:conditions', ['Period %s: engine.conditions_weighting = ''std'' needs ' ...
                'positive standard deviations of the endogenised shocks (%s); set it to ''none'' to use ' ...
                'the unweighted minimum norm.'], char(dat2str(t)), strjoin(txt, ', '));
        end
        delta = sig .* (pinv(M .* sig.') * gap);
    otherwise
        error('hetlearn:engine:conditions', ...
            'engine.conditions_weighting must be ''std'' or ''none'', not ''%s''.', w);
end
end


% =========================================================================
% Fast step from the state-space form of the IRIS solution (B2)
% =========================================================================
function ss = build_fast(m, prev)
% State-space system of a solved model; names reused from prev (same model).
[T, R, K, Z, H, D] = sspace(m, 'triangular', false);
T = T(:, :, 1);
R = R(:, :, 1);
K = K(:, 1, 1);
Z = Z(:, :, 1);
H = H(:, :, 1);
D = D(:, 1, 1);
if isstruct(prev) && isfield(prev, 'names') && size(T, 1) == prev.names.nx ...
        && size(T, 2) == prev.names.nb
    nm = prev.names;
else
    nm = build_names(m, size(T, 1), size(T, 2));
end
ne = numel(nm.e_names);
R = R(:, 1:ne);                     % current-dated shocks (no expansion)
H = H(:, 1:ne);
ss = struct('T', T, 'R', R, 'K', K, 'Z', Z, 'H', H, 'D', D, 'names', nm);
ss.Rb = R(nm.nf+1:end, :);
end


function nm = build_names(m, nx, nb)
xv = reshape(cellstr(access(m, 'transition-vector')), 1, []);
if numel(xv) ~= nx
    error('hetlearn:engine:step', 'Transition vector has %d names but the solution %d rows.', ...
        numel(xv), nx);
end
base = cell(1, nx);
lag = zeros(1, nx);
for i = 1:nx
    tok = regexp(xv{i}, '^([A-Za-z]\w*)\{-(\d+)\}$', 'tokens', 'once');
    if ~isempty(tok)
        base{i} = tok{1};
        lag(i) = str2double(tok{2});
    elseif ~isempty(regexp(xv{i}, '^[A-Za-z]\w*$', 'once'))
        base{i} = xv{i};
    else
        error('hetlearn:engine:step', ...
            'Cannot read transition vector element ''%s'' (log variables are not supported).', xv{i});
    end
end
nm = struct();
nm.nx = nx;
nm.nb = nb;
nm.nf = nx - nb;
nm.x_names = base;
nm.x_lags = lag;
nm.xb_names = base(nm.nf+1:end);
nm.xb_lags = lag(nm.nf+1:end);
nm.cur = find(lag == 0);            % elements written at t
nm.y_names = reshape(cellstr(get(m, 'yList')), 1, []);
nm.e_names = reshape(cellstr(get(m, 'eList')), 1, []);
nm.x_index = struct();
for i = nm.cur
    nm.x_index.(base{i}) = i;
end
nm.y_index = struct();
for i = 1:numel(nm.y_names)
    nm.y_index.(nm.y_names{i}) = i;
end
nm.e_index = struct();
for j = 1:numel(nm.e_names)
    nm.e_index.(nm.e_names{j}) = j;
end
end


function [s, d, info] = fast_step(ss, d, t, cond, info, TOL, m, w)
nm = ss.names;
xbPrev = zeros(nm.nb, 1);
for i = 1:nm.nb
    v = nm.xb_names{i};
    if isfield(d, v)
        xbPrev(i) = d.(v)(t - 1 - nm.xb_lags(i));
    else
        xbPrev(i) = NaN;
    end
end
miss = ~isfinite(xbPrev);
if any(miss)
    used = any(ss.T(:, miss) ~= 0, 1);
    if any(used)
        bad = find(miss);
        bad = bad(used);
        nmb = arrayfun(@(i) sprintf('%s{-%d}', nm.xb_names{i}, nm.xb_lags(i) + 1), bad, ...
            'UniformOutput', false);
        error('hetlearn:engine:step', 'Period %s: missing initial condition(s) %s.', ...
            char(dat2str(t)), strjoin(nmb, ', '));
    end
    xbPrev(miss) = 0;
end
ne = numel(nm.e_names);
e = zeros(ne, 1);
for j = 1:ne
    if isfield(d, nm.e_names{j})
        v = d.(nm.e_names{j})(t);
        if isfinite(v)
            e(j) = v;
        end
    end
end
Txb = ss.T * xbPrev + ss.K;
x = Txb + ss.R * e;
y = ss.Z * x(nm.nf+1:end) + ss.H * e + ss.D;
if ~(isempty(cond) || isempty(cond.vars))
    vars = cond.vars;
    shocks = cond.shocks;
    target = cond.targets(:);
    nk = numel(vars);
    nj = numel(shocks);
    if nj < nk
        error('hetlearn:engine:conditions', ...
            'Period %s: %d exogenised variables but only %d endogenised shocks.', ...
            char(dat2str(t)), nk, nj);
    end
    jj = zeros(1, nj);
    for j = 1:nj
        if ~isfield(nm.e_index, shocks{j})
            error('hetlearn:engine:conditions', 'Period %s: %s is not a shock of the model.', ...
                char(dat2str(t)), shocks{j});
        end
        jj(j) = nm.e_index.(shocks{j});
    end
    M = zeros(nk, nj);
    base = zeros(nk, 1);
    isY = false(nk, 1);
    idx = zeros(nk, 1);
    for k = 1:nk
        v = vars{k};
        if isfield(nm.y_index, v)
            isY(k) = true;
            idx(k) = nm.y_index.(v);
            M(k, :) = ss.Z(idx(k), :) * ss.Rb(:, jj) + ss.H(idx(k), jj);
            base(k) = y(idx(k));
        elseif isfield(nm.x_index, v)
            idx(k) = nm.x_index.(v);
            M(k, :) = ss.R(idx(k), jj);
            base(k) = x(idx(k));
        else
            error('hetlearn:engine:conditions', 'Period %s: %s is not a variable of the model.', ...
                char(dat2str(t)), v);
        end
    end
    if rank(M) < nk
        error('hetlearn:engine:conditions', ...
            'Period %s: the shocks {%s} cannot move {%s} independently (rank %d < %d).', ...
            char(dat2str(t)), strjoin(shocks, ','), strjoin(vars, ','), rank(M), nk);
    end
    gap = target - base;
    delta = solve_shocks(M, gap, m, shocks, t, w);
    for j = 1:nj
        e(jj(j)) = e(jj(j)) + delta(j);
        d.(shocks{j})(t) = d.(shocks{j})(t) + delta(j);
    end
    x = Txb + ss.R * e;
    y = ss.Z * x(nm.nf+1:end) + ss.H * e + ss.D;
    got = zeros(nk, 1);
    got(isY) = y(idx(isY));
    got(~isY) = x(idx(~isY));
    missT = max(abs(got - target));
    info.n = nk;
    info.maxerr = missT;
    if ~(missT < TOL)
        error('hetlearn:engine:conditions', 'Period %s: conditions missed by %.3g.', ...
            char(dat2str(t)), missT);
    end
end
s = d;
for i = nm.cur
    s = setval(s, nm.x_names{i}, t, x(i));
end
for i = 1:numel(nm.y_names)
    s = setval(s, nm.y_names{i}, t, y(i));
end
for j = 1:ne
    s = setval(s, nm.e_names{j}, t, e(j));
end
end


function s = setval(s, name, t, v)
if isfield(s, name) && isa(s.(name), 'Series')
    s.(name) = setData(s.(name), t, v);
else
    s.(name) = Series(t, v);
end
end
