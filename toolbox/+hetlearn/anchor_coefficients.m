function [R, info] = anchor_coefficients(m, targets, states, varargin)
%ANCHOR_COEFFICIENTS  Anchored forecasts E_{t-j} z_{t+h} = k + C s_{t-j} in a solved economy (DESIGN_br_extensions 1.4, E4).
%
%   [R, info] = hetlearn.anchor_coefficients(m, targets, states)
%   [R, info] = hetlearn.anchor_coefficients(m, targets, states, 'lag', j, 'horizon', h, ...
%                   'chain', chain, 'check', true, 'tol', 1e-9)
%
%   Inputs
%     m        solved IRIS model of the anchor economy (linear, sstate done)
%     targets  cellstr of transition variables (all at 'horizon'), or a struct
%              array with fields .var and .h (h >= 0 periods after t; j + h >= 1)
%     states   cellstr of entries of get(m, 'xbVector') the forecasts may load on,
%              dated t - j (original states, and states that exist in both the
%              anchor economy and the economy that uses the forecast)
%   Options
%     'lag'      j: forecasts made with information up to t - j (0, 1, 2); default 0
%     'horizon'  h of a cellstr of targets (default 1)
%     'chain'    struct array (.state, .target, .lag): the xbVector entry .state of
%                m dated t - j is the anchored forecast of targets(.target) made
%                .lag periods earlier, F^target_{t-lag} (lag 0: the forecast being
%                computed; DESIGN 19's lagged RE chain x_REt2 is {x_REt2, i, 0}).
%                The chain is solved out (fixed point below).
%     'check'    unit-perturbation check of the coefficients before the fixed point
%                (default true)
%     'tol'      tolerance of the check, relative (default 1e-9)
%     'big'      a loading on an xbVector entry outside states and chain must stay
%                below this (default 1e-12)
%     'error_id' identifier of the structural errors (default hetlearn:anchor:states)
%     'what'     wording of the forecast in error messages
%
%   Method. sspace(m, 'triangular', false) gives [xf; xb]_t = T xb_{t-1} + K + R e_t.
%   With T_z the row of z, T_b, K_b the rows of xb and p = j + h - 1 >= 0,
%       E_{t-j} z_{t+h} = T_z T_b^p xb_{t-j} + K_z + T_z (I + T_b + ... + T_b^(p-1)) K_b,
%   accumulated as k = K_z; c = T_z; repeat p times: k = c K_b + k, c = c T_b (so
%   p = 1 gives DESIGN 19's T_z T_b and T_z K_b + K_z in that order). Stacking the
%   targets, F_t = k_full + C_s s_{t-j} + C_0 F_t + sum_l C_l F_{t-l} + C_o o_{t-j},
%   where the chain entries give C_0 (lag 0) and C_l (lag l >= 1); the loadings
%   C_o on every other entry must stay below 'big'. Then
%       F_t = (I - C_0)^{-1} (k_full + C_s s_{t-j} + sum_l C_l F_{t-l})
%   (rcond(I - C_0) > 1e-12; without lag-0 chain entries no solve is made).
%
%   Outputs
%     R     struct: .targets (struct array var, h), .states, .lag (j),
%           .k (nT x 1), .C (nT x numel(states)), .own_lags (row of l >= 1 with a
%           chain entry), .L (cell, .L{q} the nT x nT coefficients on F_{t -
%           own_lags(q)})
%     info  struct: .xb (xbVector of m), .k_full, .c_full (before the fixed point,
%           on xb), .cz (C_0), .fixed_point_rcond (NaN without lag-0 chain),
%           .other_max (largest loading outside states and chain),
%           .check_maxdiff (NaN if not checked)
%
%   Check: a databank with nb + 1 columns sets xb at t0 to 0 (column 1) and to
%   each unit vector (column 1 + i); an IRIS simulate of t0+1 .. t0+j+h with zero
%   shocks returns k_full and k_full + c_full(:, i) for z at t0 + j + h (error
%   hetlearn:anchor:check otherwise). hetlearn.re_anchor_coefficients is the
%   wrapper of DESIGN 11 (j = 0) and DESIGN 19 (j = 1, chain x_REt2).
%
%   See also hetlearn.re_anchor_coefficients, hetlearn.engine.anchor_update.

ip = inputParser;
ip.addParameter('lag', 0);
ip.addParameter('horizon', 1);
ip.addParameter('chain', []);
ip.addParameter('check', true);
ip.addParameter('tol', 1e-9);
ip.addParameter('big', 1e-12);
ip.addParameter('error_id', 'hetlearn:anchor:states');
ip.addParameter('what', 'anchored forecast');
ip.parse(varargin{:});
o = ip.Results;
ID = o.error_id;
j = double(o.lag);
if iscell(targets) || ischar(targets) || isstring(targets)
    tv = reshape(cellstr(targets), 1, []);
    tg = struct('var', tv, 'h', num2cell(repmat(double(o.horizon), 1, numel(tv))));
else
    tg = reshape(targets, 1, []);
end
nT = numel(tg);
if isempty(states)
    states = {};
end
states = reshape(cellstr(states), 1, []);
ch = o.chain;
if isempty(ch)
    ch = struct('state', {}, 'target', {}, 'lag', {});
end
ch = reshape(ch, 1, []);

xv = cellstr(get(m, 'xVector'));
xb = reshape(cellstr(get(m, 'xbVector')), 1, []);
nx = numel(xv);
nb = numel(xb);
nf = nx - nb;
[T, ~, K] = sspace(m, 'triangular', false);
T = T(:, :, 1);
K = K(:, 1, 1);
if size(T, 1) ~= nx || size(T, 2) ~= nb
    error('hetlearn:anchor:size', 'sspace: %d x %d transition matrix for %d x %d names.', size(T, 1), size(T, 2), nx, nb);
end
Tb = T(nf+1:end, :);
Kb = K(nf+1:end);
kf = zeros(nT, 1);
Cf = zeros(nT, nb);
for i = 1:nT
    pos = find(strcmp(xv, tg(i).var), 1);
    if isempty(pos)
        error('hetlearn:anchor:noVar', '%s is not a transition variable of the anchor economy.', tg(i).var);
    end
    p = j + tg(i).h - 1;
    if p < 0 || p ~= round(p)
        error(ID, 'Target %s: information lag %d and horizon %d give no forecast (j + h must be >= 1).', ...
            tg(i).var, j, tg(i).h);
    end
    row = T(pos, :);
    kk = K(pos);
    for s = 1:p
        kk = row * Kb + kk;
        row = row * Tb;
    end
    Cf(i, :) = row;
    kf(i) = kk;
end

% ---- columns: states, chain entries, the rest -------------------------------------------------
iS = zeros(1, numel(states));
for q = 1:numel(states)
    p = find(strcmp(xb, states{q}), 1);
    if isempty(p)
        error(ID, 'State %s is not a state of the anchor economy.', states{q});
    end
    iS(q) = p;
end
iZ = zeros(1, numel(ch));
for q = 1:numel(ch)
    p = find(strcmp(xb, ch(q).state), 1);
    if isempty(p)
        error(ID, 'The chain state %s is not a state of the anchor economy.', ch(q).state);
    end
    iZ(q) = p;
end
iO = setdiff(1:nb, [iS, iZ]);
big = max([0, max(max(abs(Cf(:, iO))))]);
if big >= o.big
    [~, w] = max(max(abs(Cf(:, iO)), [], 1));
    error(ID, ['The %s loads on %s (coefficient %.3g), a state that is neither in the anchored expression ' ...
        'nor a chain state.'], o.what, xb{iO(w)}, big);
end
Cs = Cf(:, iS);
lag0 = [ch.lag] == 0;
C0 = zeros(nT, nT);
set0 = false(1, nT);
for q = find(lag0)
    c = ch(q).target;
    if set0(c)
        C0(:, c) = C0(:, c) + Cf(:, iZ(q));
    else
        C0(:, c) = Cf(:, iZ(q));
        set0(c) = true;
    end
end
ownLags = unique([ch(~lag0).lag]);
Lr = cell(1, numel(ownLags));
for a = 1:numel(ownLags)
    Ca = zeros(nT, nT);
    for q = find([ch.lag] == ownLags(a))
        c = ch(q).target;
        Ca(:, c) = Ca(:, c) + Cf(:, iZ(q));
    end
    Lr{a} = Ca;
end
rc = NaN;
if any(lag0)
    M = eye(nT) - C0;
    rc = rcond(M);
    if ~(rc > 1e-12)
        error(ID, ['I - C_0 is singular (rcond %.3g): the anchored agents'' own forecasts do not pin down the ' ...
            '%s.'], rc, o.what);
    end
    kt = M \ kf;
    Ct = M \ Cs;
    for a = 1:numel(Lr)
        Lr{a} = M \ Lr{a};
    end
else
    kt = kf;
    Ct = Cs;
end
R = struct('targets', tg, 'states', {states}, 'lag', j, 'k', kt, 'C', Ct, 'own_lags', ownLags, 'L', {Lr});
info = struct('xb', {xb}, 'k_full', kf, 'c_full', Cf, 'cz', C0, 'fixed_point_rcond', rc, 'other_max', big, ...
    'check_maxdiff', NaN);

% ---- check: simulations from each unit state, zero shocks ------------------------------------
if logical(o.check) && nT > 0
    [~, sv, sl] = hetlearn.plm.anchor_names('x', xb);
    nc = nb + 1;
    Lg = max([sl, 0]);
    npd = max(j + [tg.h]);
    t0 = qq(2000, 4);
    rng = t0 - Lg : t0 + npd;
    db = struct();
    xl = cellstr(get(m, 'xList'));
    el = cellstr(get(m, 'eList'));
    Z0 = zeros(numel(rng), nc);
    for i = 1:numel(xl)
        X = Z0;
        for q = find(strcmp(sv, xl{i}))
            X(Lg + 1 - sl(q), 1 + q) = 1;        % row of date t0 - lag
        end
        db.(xl{i}) = Series(rng(1), X);
    end
    for i = 1:numel(el)
        db.(el{i}) = Series(rng(1), Z0);
    end
    s = simulate(m, db, t0 + 1 : t0 + npd, 'prependInput', true, 'anticipate', false);
    worst = 0;
    for i = 1:nT
        v = reshape(s.(tg(i).var)(t0 + j + tg(i).h), 1, []);
        if numel(v) ~= nc
            error('hetlearn:anchor:check', 'Unit-perturbation simulation returned %d columns, expected %d.', numel(v), nc);
        end
        dk = abs(v(1) - kf(i)) / max(1, abs(kf(i)));
        dc = abs((v(2:end) - v(1)) - Cf(i, :)) ./ max(1, abs(Cf(i, :)));
        worst = max([worst, dk, dc]);
    end
    info.check_maxdiff = worst;
    if ~(worst < o.tol)
        error('hetlearn:anchor:check', ['The %s coefficients from sspace differ from the unit-perturbation ' ...
            'simulations by %.3g (tolerance %g).'], o.what, worst, o.tol);
    end
end
end
