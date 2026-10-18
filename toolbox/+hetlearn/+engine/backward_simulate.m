function out = backward_simulate(a, d, t)
%BACKWARD_SIMULATE  One-period simulation of a model without leads from IRIS's system matrices (DESIGN 11).
%
%   bw = hetlearn.engine.backward_simulate(m)          build the backward system of m
%   s  = hetlearn.engine.backward_simulate(bw, d, t)   simulate period t
%   s  = hetlearn.engine.backward_simulate(m, d, t)    both in one call
%
%   Build. The first-order system of the linear IRIS model m (solved or not;
%   IRIS rejects explosive solutions even in purely backward models) is
%     [A, B, C, D, F, G, H, J, list, nf] = system(m, 'MatrixFormat', 'plain')
%       A*[xf{+1}; xb] + B*[xf; xb{-1}] + C + D*e = 0   transition equations and
%                                                      IRIS identities of the
%                                                      auxiliary lags
%       F*y + G*xb + H + J*e = 0                       measurement equations
%   in levels, xf the non-predetermined and xb the predetermined transition
%   variables at t (list{2}: the first nf names are xf{+1}, the rest xb at t,
%   e.g. 'z' or 'z{-1}'). The model has no leads iff A(:,1:nf) = 0. Then the
%   period-t system M*[xf; xb] = -(Bb*xb{-1} + C + D*e), M = [B(:,1:nf),
%   A(:,nf+1:end)], Bb = B(:,nf+1:end), has one solution whenever M is
%   nonsingular, whatever the roots.
%   bw fields: .ok (false if nonlinear, leads, or singular M), .reason, .nf,
%   .nb, .xf_names, .xb_names, .xb_lags (0 = current value), .y_names,
%   .e_names, .M, .Bb, .C, .D, .F, .G, .H, .J, .Phi (xb_t = Phi*xb_{t-1} +
%   ...), .roots = eig(Phi), .maxroot (largest |root|; 0 without states),
%   .flag (filled by hetlearn.engine.solve_model).
%
%   Simulate. d is a databank with the history up to t-1 and the shocks at
%   t (NaN or missing shocks count as 0, as in IRIS). s is d with every
%   transition variable, measurement variable and shock at t set. It equals
%   period t of simulate(m, d, t:t, 'prependInput', true) whenever IRIS has
%   a solution (tests/test_anchored.m).
%
%   See also hetlearn.engine.solve_model, hetlearn.engine.step.

if isstruct(a)
    bw = a;
else
    bw = build(a);
    if nargin < 2
        out = bw;
        return
    end
end
if ~bw.ok
    error('hetlearn:engine:backward', 'No backward system: %s.', bw.reason);
end
out = simulate_one(bw, d, t);
end


% -------------------------------------------------------------------------
function bw = build(m)
bw = struct('ok', false, 'reason', '', 'flag', '', 'maxroot', NaN);
try
    lin = isLinear(m);
catch
    lin = true;
end
if ~lin
    bw.reason = 'nonlinear model';
    return
end
[A, B, C, D, F, G, H, J, list, nf] = system(m, 'MatrixFormat', 'plain');
A = A(:, :, 1); B = B(:, :, 1); C = C(:, 1, 1); D = D(:, :, 1);
F = F(:, :, 1); G = G(:, :, 1); H = H(:, 1, 1); J = J(:, :, 1);
x1 = cellstr(list{2});
nx = numel(x1);
nb = nx - nf;
if nf > 0 && any(any(A(:, 1:nf) ~= 0))
    bw.reason = 'the model has leads';
    return
end
xfN = cell(1, nf);
for i = 1:nf
    [v, k] = parse_name(x1{i});
    if k ~= 1
        bw.reason = sprintf('unexpected forward element %s', x1{i});
        return
    end
    xfN{i} = v;
end
xbN = cell(1, nb);
xbL = zeros(1, nb);
for i = 1:nb
    [v, k] = parse_name(x1{nf + i});
    if k > 0
        bw.reason = sprintf('unexpected predetermined element %s', x1{nf + i});
        return
    end
    xbN{i} = v;
    xbL(i) = -k;
end
M = [B(:, 1:nf), A(:, nf+1:end)];
if size(M, 1) ~= size(M, 2) || rcond(M) < 1e-14
    bw.reason = 'singular period-t system';
    return
end
Bb = B(:, nf+1:end);
Phi = -(M \ Bb);
Phi = Phi(nf+1:end, :);
if isempty(Phi)
    r = zeros(0, 1);
    mr = 0;
else
    r = eig(Phi);
    mr = max(abs(r));
end
bw.ok = true;
bw.nf = nf;
bw.nb = nb;
bw.xf_names = xfN;
bw.xb_names = xbN;
bw.xb_lags = xbL;
bw.y_names = reshape(cellstr(list{1}), 1, []);
bw.e_names = reshape(cellstr(list{3}), 1, []);
bw.M = M;
bw.Bb = Bb;
bw.C = C;
bw.D = D;
bw.F = F;
bw.G = G;
bw.H = H;
bw.J = J;
bw.Phi = Phi;
bw.roots = r;
bw.maxroot = mr;
end


function [v, k] = parse_name(s)
tl = regexp(s, '^([A-Za-z]\w*)\{([+-]?\d+)\}$', 'tokens', 'once');
t0 = regexp(s, '^([A-Za-z]\w*)$', 'tokens', 'once');
if ~isempty(tl)
    v = tl{1};
    k = str2double(tl{2});
elseif ~isempty(t0)
    v = t0{1};
    k = 0;
else
    error('hetlearn:engine:backward', ...
        'Cannot read the IRIS system vector element ''%s'' (log variables are not supported).', s);
end
end


% -------------------------------------------------------------------------
function s = simulate_one(bw, d, t)
xbPrev = NaN(bw.nb, 1);
for i = 1:bw.nb
    v = bw.xb_names{i};
    if isfield(d, v)
        xbPrev(i) = d.(v)(t - 1 - bw.xb_lags(i));
    end
end
miss = ~isfinite(xbPrev);
if any(miss)
    used = any(bw.Bb(:, miss) ~= 0, 1);
    if any(used)
        nm = strcat(bw.xb_names(miss), '{-', arrayfun(@(k) sprintf('%d', k + 1), bw.xb_lags(miss), ...
            'UniformOutput', false), '}');
        error('hetlearn:engine:backward', 'Period %s: missing initial condition(s) %s.', ...
            char(dat2str(t)), strjoin(nm(used), ', '));
    end
    xbPrev(miss) = 0;
end
ne = numel(bw.e_names);
e = zeros(ne, 1);
for j = 1:ne
    if isfield(d, bw.e_names{j})
        v = d.(bw.e_names{j})(t);
        if isfinite(v)
            e(j) = v;
        end
    end
end
u = -(bw.M \ (bw.Bb * xbPrev + bw.C + bw.D * e));
xb = u(bw.nf+1:end);
if isempty(bw.y_names)
    y = zeros(0, 1);
else
    y = -(bw.F \ (bw.G * xb + bw.H + bw.J * e));
end
s = d;
for i = 1:bw.nf
    s = setval(s, bw.xf_names{i}, t, u(i));
end
for i = 1:bw.nb
    if bw.xb_lags(i) == 0
        s = setval(s, bw.xb_names{i}, t, xb(i));
    end
end
for i = 1:numel(bw.y_names)
    s = setval(s, bw.y_names{i}, t, y(i));
end
for j = 1:ne
    s = setval(s, bw.e_names{j}, t, e(j));
end
end


function s = setval(s, name, t, v)
if isfield(s, name) && isa(s.(name), 'Series')
    s.(name)(t) = v;
else
    s.(name) = Series(t, v);
end
end
