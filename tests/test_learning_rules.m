function R = test_learning_rules(part)
%TEST_LEARNING_RULES  New learning rules, phase P5 of docs/DESIGN_br_extensions.md (1.5; variants 17, 20, 25).
%
%   R = test_learning_rules()        every part
%   R = test_learning_rules(part)    'unit' | 'toy' | 'ah' (or a cellstr of them)
%
%   Unit checks (no model):
%   L1   SAC batch identity: hetlearn.rls.sac with the finite-sample terms and
%        gain 1/(t+1) = the batch mean, variance and sample autocorrelation of
%        x_0..x_t (HMOZ eq. 2.6) at every t (1e-12); the engine's recursion
%        (finite-sample terms dropped, design 1.5) with the same gain = its own
%        batch moments: the sample mean, and sum e^2 and sum e*u over t+1 of the
%        deviations from the running mean (1e-12). Its gap to HMOZ 2.6 is
%        reported (order 1/t).
%   L2   SAC constant gain: the engine form (phi and R of the AR(1) PLM) = a hand
%        loop of the design's recursion (gains 0.006 and 0.05, 1e-12); alpha =
%        a(1 - b), beta = b, so the generated forecast alpha + beta (alpha + beta
%        x) = a + b^2 (x - a)
%   L3   SAC bound: b outside [-1, 1] is clipped, event 'sac_bound'; a PLM that is
%        not an AR(1) on the own lag is an error (hetlearn:rls:sacPlm)
%   L4   KF: the engine form (state M = gamma s2 inv(P) in S.R, constants in
%        S.kf) = a hand loop of the design's covariance recursion, three
%        regressors (1e-10 relative); V and P0 as specified
%   L5   KF reaches the RLS limit (design 25): z = 1 from P0 = gamma s2 / R0 has
%        gain gamma in every period and phi = constant-gain RLS (1e-13); from
%        50 times that P0 the scalar gain converges to gamma (1e-12); for any
%        PLM the first update from M0 = R0 is the constant-gain RLS step (1e-14)
%   L6   KF: s2 scales P only (beliefs for s2 = 0.3 and 7 agree, 1e-12); s2
%        're_moments' = E[x^2] - phi0' R0 phi0 with E[x^2] at the own lag (an
%        AR(1) at its moments gives sigma^2); its errors (no own lag,
%        beliefs.init.method other than 're_moments')
%   L7   decreasing gain: the gain interface = hand loop (1/(k - 1 + n0),
%        quarters with missing data not counted, n0 = 1 and 4); n0 = t0 + 1 after
%        OLS on t0 observations gives the gains 1/t exactly and RLS ends at
%        full-sample OLS (the 1/t case of test_rls, 1e-9)
%   Toy NK engine runs (tests/toy_nk, switching on y and pie, facility 'none'):
%   L8   beliefs.update = 'sac' (gain 0.05): recorded alpha, beta and R = a hand
%        loop of the SAC recursion on the run's data from the RE moments,
%        history and forecast (1e-12)
%   L9   SAC from user initial beliefs (variance 1e-8, the mean set from the data
%        so that u/e = 11 in the first update): the bound binds; recorded beliefs
%        and the number of 'sac_bound' events = a hand loop with the clipping
%        (1e-12); |beta| <= 1 (a high gain alone does not bind: the mean then
%        tracks the data and the autocorrelation shrinks)
%   L10  beliefs.update = 'kf', AR(2) PLMs (gamma 0.05): recorded beliefs = hand
%        loop of the covariance recursion from the RE moments (1e-10); recorded
%        R = diag of gamma s2 inv(P) (1e-8 relative)
%   L11  KF on mean-only PLMs (s2 = 1) = RLS with constant gain gamma: the RLS
%        limit in the engine (paths, beliefs, shares; 1e-12)
%   L12  KF: s2 're_moments' and s2 = 2.5 give the same run (1e-10)
%   L13  gain.rule = 'decreasing': mean-only PLMs = the running sample mean of the
%        data from beliefs.init.date (1e-12); AR(1) PLMs with n0 = 8 = hand RLS
%        loop with gains 1/(k + 7) (1e-12)
%   L14  N-type path: types RE and BR spelled out, BR with update 'sac' or 'kf' =
%        the two-type run (RE filters recomputed in the session; 1e-12)
%   AH package (tests/models/ah, variant 17):
%   L15  the LAA anchor with gain.rule = 'decreasing' = the P2 test rule
%        ah_sample_mean (prices and shares, max diff 0; the three AH cases of
%        test_ntypes A1-A3, which hold those runs to the hand loop of the AH
%        equations)
%
%   Runs are not saved. About 1-2 minutes; the first call generates the toy
%   model files of the new PLMs.

if nargin < 1 || isempty(part)
    part = {'unit', 'toy', 'ah'};
end
part = cellstr(part);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));
R = struct('name', {}, 'pass', {}, 'msg', {});
if any(strcmp(part, 'unit'))
    R = unit_sac(R);
    R = unit_kf(R);
    R = unit_decreasing(R);
end
if any(strcmp(part, 'toy'))
    R = toy(R, here);
end
if any(strcmp(part, 'ah'))
    R = ah(R, here);
end
end


% =========================================================================================
function R = unit_sac(R)
rng(20261021);
nm = 'lr L1: SAC batch identity, gain 1/(t+1): finite-sample recursion = HMOZ 2.6 batch moments; engine recursion = its batch moments';
try
    T = 400;
    x = zeros(T + 1, 1);
    x(1) = 0.3;
    for t = 2:T + 1
        x(t) = 0.2 + 0.6 * x(t - 1) + randn;
    end
    sX = struct('a', x(1), 'b', 0, 'R', 0);          % x(1) = x_0: a_0 = x_0, R_0 = 0
    sD = sX;
    d = zeros(1, 5);
    gap = NaN(1, T);
    e = zeros(T, 1);
    u = zeros(T, 1);
    for t = 1:T
        g = 1 / (t + 1);
        e(t) = x(t + 1) - sD.a;                       % deviations from the running mean (sD.a = mean of x_0..x_{t-1})
        u(t) = x(t) - sD.a;
        sX = hetlearn.rls.sac('step', sX, x(t + 1), x(t), g, x(1));
        sD = hetlearn.rls.sac('step', sD, x(t + 1), x(t), g);
        w = x(1:t + 1);
        m = mean(w);
        dv = w - m;
        Rb = sum(dv .^ 2) / (t + 1);
        bb = sum(dv(1:end-1) .* dv(2:end)) / sum(dv .^ 2);
        d(1) = max(d(1), abs(sX.a - m));
        d(2) = max(d(2), abs(sX.R - Rb));
        d(3) = max(d(3), abs(sX.b - bb));
        d(4) = max([d(4), abs(sD.a - m), abs(sD.R - sum(e(1:t) .^ 2) / (t + 1))]);
        d(5) = max(d(5), abs(sD.b - sum(e(1:t) .* u(1:t)) / sum(e(1:t) .^ 2)));
        gap(t) = abs(sD.b - bb);
    end
    ok = all(d <= 1e-12);
    R = add(R, nm, ok, sprintf(['finite-sample form vs HMOZ 2.6 over t = 1..%d: mean %.2g, variance %.2g, ' ...
        'autocorrelation %.2g; engine form vs its batch moments: mean and variance %.2g, autocorrelation %.2g; ' ...
        'gap of the engine form to HMOZ 2.6 (finite-sample terms): %.3g at t = 10, %.3g at t = 100, %.3g at t = %d'], ...
        T, d(1), d(2), d(3), d(4), d(5), gap(10), gap(100), gap(T), T));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L2: SAC constant gain, engine form on the AR(1) PLM = hand loop of the design recursion (0.006, 0.05; 1e-12)';
try
    T = 2000;
    x = zeros(T, 1);
    x(1) = 0.5;
    for t = 2:T
        x(t) = 0.2 + 0.7 * x(t - 1) + 0.5 * randn;
    end
    eq = struct('target', 'x', 'reg_names', {{'x'}}, 'reg_lags', 1, 'constant', true);
    dmax = 0;
    nb = 0;
    for gam = [0.006, 0.05]
        a = 0.6; b = 0.65; Rv = 0.4;                  % initial mean, autocorrelation, variance
        phi = [a * (1 - b); b];
        Rm = [1, a; a, a^2 + Rv];
        ev = empty_ev();
        S = struct();
        for t = 2:T
            [phi, Rm, S, ev] = hetlearn.rls.sac(phi, Rm, [1; x(t - 1)], x(t), gam, S, eq, [], [], t, ev);
            e = x(t) - a;
            u = x(t - 1) - a;
            a = a + gam * e;
            Rv = Rv + gam * (e^2 - Rv);
            b = min(1, max(-1, b + gam * ((e * u - b * e^2) / Rv)));
            dmax = max([dmax; abs(phi - [a * (1 - b); b]); abs(Rm(:) - [1; a; a; a^2 + Rv])]);
        end
        nb = nb + numel(ev);
    end
    xs = linspace(-2, 2, 9);
    f1 = phi(1) + phi(2) * (phi(1) + phi(2) * xs);
    f2 = a + b^2 * (xs - a);
    df = max(abs(f1 - f2));
    R = add(R, nm, dmax <= 1e-12 && df <= 1e-14 && nb == 0, sprintf(['max diff %.2g over %d periods per gain; ' ...
        'forecast alpha + beta (alpha + beta x) vs a + b^2 (x - a): %.2g; %d sac_bound events'], dmax, T - 1, df, nb));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L3: SAC bound, b clipped to [-1, 1] with event sac_bound; a PLM other than AR(1) on the own lag is an error';
try
    s = struct('a', 0, 'b', 0.9, 'R', 0.01);
    [s1, f1] = hetlearn.rls.sac('step', s, 1, 3, 0.5);
    [s2, f2] = hetlearn.rls.sac('step', s, 1, -3, 0.5);
    eq = struct('target', 'pinf', 'reg_names', {{'pinf'}}, 'reg_lags', 1, 'constant', true);
    [phi, Rm] = hetlearn.rls.sac('to_plm', s);
    [phiE, ~, ~, ev] = hetlearn.rls.sac(phi, Rm, [1; 3], 1, 0.5, struct(), eq, [], [], qq(2020, 1), empty_ev());
    okE = numel(ev) == 1 && strcmp(ev(1).type, 'sac_bound') && strcmp(ev(1).variable, 'pinf') && phiE(2) == 1 ...
        && abs(phiE(1)) == 0 && ev(1).date == double(qq(2020, 1));
    eqN = struct('target', 'pinf__BR', 'reg_names', {{'pinf__BR'}}, 'reg_lags', 1, 'constant', true, 'type', 'BR', ...
        'var', 'pinf', 'reg_vars', {{'pinf'}});
    hetlearn.rls.sac(phi, Rm, [1; 0.1], 0.2, 0.05, struct(), eqN, [], [], 1, empty_ev());   % keyed AR(1): accepted
    bad = {struct('target', 'pinf', 'reg_names', {{'pinf', 'pinf'}}, 'reg_lags', [1 2], 'constant', true), ...
        struct('target', 'pinf', 'reg_names', {{'pinf'}}, 'reg_lags', 1, 'constant', false), ...
        struct('target', 'pinf', 'reg_names', {{'r'}}, 'reg_lags', 1, 'constant', true), ...
        struct('target', 'pinf', 'reg_names', {{}}, 'reg_lags', zeros(1, 0), 'constant', true)};
    nErr = 0;
    for i = 1:numel(bad)
        try
            hetlearn.rls.sac([0; 0.5; 0], eye(3), [1; 0; 0], 0, 0.05, struct(), bad{i}, [], [], 1, empty_ev());
        catch err
            nErr = nErr + strcmp(err.identifier, 'hetlearn:rls:sacPlm');
        end
    end
    ok = strcmp(f1, 'upper') && s1.b == 1 && strcmp(f2, 'lower') && s2.b == -1 && okE && nErr == numel(bad);
    R = add(R, nm, ok, sprintf('flags %s, %s; engine event: %s; %d of %d bad PLMs rejected', f1, f2, ...
        ev_text(ev), nErr, numel(bad)));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = unit_kf(R)
rng(20261022);
eq3 = struct('target', 'v', 'reg_names', {{'u1', 'u2'}}, 'reg_lags', [1 1], 'constant', true);
gopts = struct('rule', 'constant', 'value', 0.05, 'by_var', struct());
nm = 'lr L4: KF engine form (M = gamma s2 inv(P) in S.R) = hand loop of the design covariance recursion (3 regressors, 1e-10)';
try
    T = 500;
    Z = [ones(T, 1), randn(T, 2)];
    Y = Z * [0.2; 0.5; -0.3] + 0.3 * randn(T, 1);
    R0 = [1 0.1 -0.2; 0.1 1.3 0.2; -0.2 0.2 0.9];
    phi0 = [0.1; 0.3; 0];
    gam = 0.031;
    s2 = 0.4;
    bopts = struct('kf', struct('gamma', gam, 's2', s2), 'init', struct('method', 're_moments'));
    phi = phi0;
    Rm = R0;
    S = struct();
    ev = empty_ev();
    P = gam * s2 * inv(R0); %#ok<MINV>
    V = gam^2 / (1 - gam) * s2 * inv(R0); %#ok<MINV>
    ph = phi0;
    dp = 0;
    dM = 0;
    for t = 1:T
        z = Z(t, :)';
        [phi, Rm, S, ev] = hetlearn.rls.kf(phi, Rm, z, Y(t), 0.05, S, eq3, bopts, gopts, t, ev);
        Pp = P + V;
        K = Pp * z / (z' * Pp * z + s2);
        ph = ph + K * (Y(t) - z' * ph);
        P = Pp - K * z' * Pp;
        dp = max(dp, max(abs(phi - ph)) / max(abs(ph)));
        M = gam * s2 * inv(P); %#ok<MINV>
        dM = max(dM, max(abs(Rm(:) - M(:))) / max(abs(M(:))));
    end
    c = S.kf.v;
    dc = max([abs(c.V(:) - V(:)); abs(c.R0(:) - R0(:)); abs(c.gamma - gam); abs(c.s2 - s2)]);
    dP0 = max(max(abs(hetlearn.rls.kf('P0', gam, s2, R0) - gam * s2 * inv(R0)))); %#ok<MINV>
    ok = dp <= 1e-10 && dM <= 1e-9 && dc <= 1e-15 && dP0 <= 1e-15 && isempty(ev);
    R = add(R, nm, ok, sprintf(['%d steps: max relative diff phi %.2g, M %.2g; S.kf constants %.2g; P0 %.2g; ' ...
        'final phi %s'], T, dp, dM, dc, dP0, mat2str(phi', 4)));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L5: KF reaches the RLS limit: z = 1 from P0 = gamma s2/R0 is constant-gain RLS; the scalar gain converges to gamma; first step = RLS';
try
    T = 1000;
    y = 0.4 + randn(T, 1);
    gam = 0.05;
    s2 = 0.7;
    eq1 = struct('target', 'm', 'reg_names', {{}}, 'reg_lags', zeros(1, 0), 'constant', true);
    bopts = struct('kf', struct('gamma', gam, 's2', s2), 'init', struct('method', 're_moments'));
    phiK = 0; RK = 1; S = struct(); ev = empty_ev();
    phiR = 0; RR = 1;
    P = gam * s2;
    V = hetlearn.rls.kf('V', gam, s2, 1);
    da = 0;
    dK = 0;
    for t = 1:T
        [phiK, RK, S, ev] = hetlearn.rls.kf(phiK, RK, 1, y(t), 0.05, S, eq1, bopts, gopts, t, ev);
        [phiR, RR] = hetlearn.rls.update(phiR, RR, 1, y(t), gam);
        [~, P, K] = hetlearn.rls.kf('step', 0, P, 1, y(t), V, s2);
        da = max(da, abs(phiK - phiR));
        dK = max(dK, abs(K - gam));
    end
    P = 50 * gam * s2;                                % far from the fixed point
    for t = 1:2000
        [~, P, K] = hetlearn.rls.kf('step', 0, P, 1, y(1 + mod(t - 1, T)), V, s2);
    end
    dConv = abs(K - gam);
    % any PLM: the first update from M0 = R0 is the constant-gain RLS step
    A = randn(3);
    R0 = A * A' + eye(3);
    phi0 = randn(3, 1);
    z = [1; randn(2, 1)];
    bo3 = struct('kf', struct('gamma', 0.031, 's2', 1.7), 'init', struct('method', 're_moments'));
    [pk, Rk] = hetlearn.rls.kf(phi0, R0, z, 0.8, 0.05, struct(), eq3, bo3, gopts, 1, empty_ev());
    [pr, Rr] = hetlearn.rls.update(phi0, R0, z, 0.8, 0.031);
    d1 = max([abs(pk - pr) / max(abs(pr)); abs(Rk(:) - Rr(:)) / max(abs(Rr(:)))]);
    ok = da <= 1e-13 && dK <= 1e-14 && dConv <= 1e-12 && d1 <= 1e-14;
    R = add(R, nm, ok, sprintf(['z = 1, %d periods: |phi_KF - phi_RLS| %.2g, |K_t - gamma| %.2g; from 50 x P0: ' ...
        '|K - gamma| %.2g after 2000 steps; first step, 3 regressors: %.2g'], T, da, dK, dConv, d1));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L6: KF, s2 scales P only (beliefs for s2 0.3 and 7 agree); s2 re_moments = E[x^2] - phi0 R0 phi0 at the own lag; its errors';
try
    T = 400;
    Z = [ones(T, 1), randn(T, 2)];
    Y = Z * [0.2; 0.5; -0.3] + 0.3 * randn(T, 1);
    R0 = [1 0.1 -0.2; 0.1 1.3 0.2; -0.2 0.2 0.9];
    pa = [0.1; 0.3; 0]; Ra = R0; Sa = struct();
    pb = pa; Rb = R0; Sb = struct();
    ba = struct('kf', struct('gamma', 0.031, 's2', 0.3), 'init', struct('method', 're_moments'));
    bb = ba;
    bb.kf.s2 = 7;
    dp = 0;
    dR = 0;
    for t = 1:T
        z = Z(t, :)';
        [pa, Ra, Sa] = hetlearn.rls.kf(pa, Ra, z, Y(t), 0.05, Sa, eq3, ba, gopts, t, empty_ev());
        [pb, Rb, Sb] = hetlearn.rls.kf(pb, Rb, z, Y(t), 0.05, Sb, eq3, bb, gopts, t, empty_ev());
        dp = max(dp, max(abs(pa - pb)));
        dR = max(dR, max(abs(Ra(:) - Rb(:))) / max(abs(Ra(:))));
    end
    % an AR(1) at its moments: s2 're_moments' = the innovation variance
    rho = 0.8; mu = 0.5; sig2 = 0.09;
    vx = sig2 / (1 - rho^2);
    R1 = [1, mu; mu, mu^2 + vx];
    p1 = [mu * (1 - rho); rho];
    eqA = struct('target', 'x', 'reg_names', {{'x'}}, 'reg_lags', 1, 'constant', true);
    s2re = hetlearn.rls.kf('s2_re', p1, R1, eqA);
    ds = abs(s2re - sig2);
    eqK = struct('target', 'x__M2', 'reg_names', {{'r__M2', 'x__M2'}}, 'reg_lags', [1 1], 'constant', true, ...
        'type', 'M2', 'var', 'x', 'reg_vars', {{'r', 'x'}});
    R2 = [1 0 mu; 0 2 0.3; mu 0.3 mu^2 + vx];
    s2k = hetlearn.rls.kf('s2_re', [mu * (1 - rho); 0; rho], R2, eqK);   % own lag in position 2: E[x^2] = R2(3, 3)
    dk = abs(s2k - (mu^2 + vx - [mu * (1 - rho); 0; rho]' * R2 * [mu * (1 - rho); 0; rho]));
    e1 = expect_id(@() hetlearn.rls.kf('s2_re', 0.5, 1, struct('target', 'm', 'reg_names', {{}}, 'reg_lags', ...
        zeros(1, 0), 'constant', true)), 'hetlearn:rls:kfS2');
    bt = struct('kf', struct('gamma', 0.031, 's2', 're_moments'), 'init', struct('method', 'training_ols'));
    e2 = expect_id(@() hetlearn.rls.kf('constants', p1, R1, eqA, bt, gopts), 'hetlearn:rls:kfS2');
    bg = struct('kf', struct('gamma', [], 's2', 1), 'init', struct('method', 're_moments'));
    e3 = expect_id(@() hetlearn.rls.kf('constants', p1, R1, eqA, bg, struct('value', 1, 'by_var', struct())), ...
        'hetlearn:rls:kfGamma');
    cg = hetlearn.rls.kf('constants', p1, R1, eqA, bg, struct('value', 0.05, 'by_var', struct('x', 0.02)));
    ok = dp <= 1e-12 && dR <= 1e-12 && ds <= 1e-15 && dk <= 1e-15 && e1 && e2 && e3 && cg.gamma == 0.02;
    R = add(R, nm, ok, sprintf(['s2 0.3 vs 7 over %d steps: phi %.2g, M %.2g (relative); AR(1) s2_re - sigma^2 %.2g; ' ...
        'keyed PLM %.2g; errors (no own lag, training_ols, gamma 1) %d%d%d; gamma [] -> gain.by_var %g'], T, dp, dR, ...
        ds, dk, e1, e2, e3, cg.gamma));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = unit_decreasing(R)
nm = 'lr L7: decreasing gain = 1/(k - 1 + n0) (missing data not counted; n0 1 and 4); n0 = t0 + 1 after OLS = gains 1/t and full-sample OLS';
try
    sys = struct('eq', struct('target', {'a', 'b'}));
    T = 30;
    miss = false(T, 1);
    miss([4 5 17]) = true;
    dg = 0;
    for n0 = [1 4]
        go = struct('rule', 'decreasing', 'value', 0.05, 'by_var', struct(), 'decreasing', struct('n0', n0));
        G = hetlearn.gain.decreasing('init', sys, {'a', 'b'}, go);
        ka = 0;
        kb = 0;
        for t = 1:T
            rb = 0.3;
            if miss(t)
                rb = NaN;
            end
            er = struct('t', t, 'first', t == 1, 'targets', {{'a', 'b'}}, 'rls', struct('a', -0.1, 'b', rb));
            g = hetlearn.gain.decreasing('gain', G, er, go);
            dg = max([dg, abs(g.a - 1 / (ka + n0)), abs(g.b - 1 / (kb + n0))]);
            [G, ev] = hetlearn.gain.decreasing('update', G, er, go);
            ka = ka + 1;
            kb = kb + ~miss(t);
            dg = max(dg, double(~isempty(ev)));
        end
    end
    % the 1/t case of test_rls: OLS on t0 observations, then the rule's gains with n0 = t0 + 1
    rng(20261023);
    T = 500; t0 = 10;
    Z = [ones(T, 1), randn(T, 2)];
    Y = Z * [1; 0.8; -0.4] + randn(T, 1);
    phi = (Z(1:t0, :)' * Z(1:t0, :)) \ (Z(1:t0, :)' * Y(1:t0));
    Rm = (Z(1:t0, :)' * Z(1:t0, :)) / t0;
    go = struct('rule', 'decreasing', 'value', 0.05, 'by_var', struct(), 'decreasing', struct('n0', t0 + 1));
    G = hetlearn.gain.decreasing('init', struct('eq', struct('target', 'v')), {'v'}, go);
    g1t = 0;
    for t = t0 + 1:T
        er = struct('t', t, 'first', false, 'targets', {{'v'}}, 'rls', struct('v', Y(t) - Z(t, :) * phi));
        g = hetlearn.gain.decreasing('gain', G, er, go);
        g1t = max(g1t, abs(g.v - 1 / t));
        [phi, Rm] = hetlearn.rls.update(phi, Rm, Z(t, :)', Y(t), g.v);
        G = hetlearn.gain.decreasing('update', G, er, go);
    end
    ols = (Z' * Z) \ (Z' * Y);
    dols = max(abs(phi - ols));
    f = hetlearn.gain.decreasing('fields');
    ok = dg == 0 && g1t == 0 && dols <= 1e-9 && isempty(f);
    R = add(R, nm, ok, sprintf(['gain vs hand count: %.2g (n0 1 and 4, 3 missing quarters); gains vs 1/t: %.2g; ' ...
        'RLS with them vs full-sample OLS: %.2g'], dg, g1t, dols));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = toy(R, here)
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
run = @(cfg) hetlearn.run(cfg, 'save', false, 'quiet', true);
base = struct('model', toyDir);
base.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
base.expectations = struct('mode', 'switching', 'variables', {{'y', 'pie'}});
base.switching.intensity = 0.25;
base.projection.facility = 'none';
hz = qq(2021, 1):qq(2023, 4);
rng(11);
base.shocks.add = {{'e_g', hz, randn(12, 1)}, {'e_u', hz, 0.5 * randn(12, 1)}};
lv = {'y', 'pie'};
mean_only = struct('y', struct('regressors', {{}}, 'constant', true), 'pie', struct('regressors', {{}}, 'constant', true));

nm = 'lr L8: toy, beliefs.update sac (gain 0.05): recorded alpha, beta, R = hand loop of the SAC recursion from the RE moments (1e-12)';
try
    c = base;
    c.id = 'lr_toy_sac';
    c.beliefs.update = 'sac';
    c.gain = struct('rule', 'constant', 'value', 0.05);
    res = run(c);
    [phi0, R0] = initial_beliefs(c);
    rd = res.dates.record;
    d = 0;
    for i = 1:numel(lv)
        x = lv{i};
        p = res.paths.(x);
        L = res.learning.(x);
        a = R0.(x)(1, 2); b = phi0.(x)(2); Rv = R0.(x)(2, 2) - a^2;
        for k = 1:numel(rd)
            t = rd(k);
            e = p(t) - a;
            u = p(t - 1) - a;
            a = a + 0.05 * e;
            Rv = Rv + 0.05 * (e^2 - Rv);
            b = min(1, max(-1, b + 0.05 * ((e * u - b * e^2) / Rv)));
            d = max([d, abs(L.(['alpha_' x])(t) - a * (1 - b)), abs(L.(['beta_' x])(t) - b), ...
                abs(L.(['R_beta_' x])(t) - (a^2 + Rv)), abs(L.(['R_alpha_' x])(t) - 1)]);
        end
    end
    nEv = height(res.events);
    nH = sum(double(rd) <= double(qq(2020, 4)) + 1e-6);
    R = add(R, nm, d <= 1e-12 && nEv == 0, sprintf('max diff %.2g over %d history + %d forecast quarters (y, pie); %d events', ...
        d, nH, numel(rd) - nH, nEv));
catch err
    R = add(R, nm, false, where(err));
end

nm = ['lr L9: toy, SAC from user beliefs (variance 1e-8, mean set so that u/e = 11 in the first update): the bound ' ...
    'binds; recorded beliefs and the sac_bound events = hand loop with clipping (1e-12), |beta| <= 1'];
try
    c = base;
    c.id = 'lr_toy_sac_bound';
    c.beliefs.update = 'sac';
    c.gain = struct('rule', 'constant', 'value', 0.05);
    r0 = run(c);                         % the history data (they do not depend on the beliefs)
    t0 = r0.dates.record(1);
    vals = struct();
    for i = 1:numel(lv)
        x = lv{i};
        p = r0.paths.(x);
        a0 = p(t0) + 0.1 * (p(t0) - p(t0 - 1));      % e = -0.1 d, u = -1.1 d: b_1 = u/e = 11 for a tiny variance
        vals.(x) = struct('phi', [0.5 * a0; 0.5], 'R', [1, a0; a0, a0^2 + 1e-8]);
    end
    c.beliefs.init.method = 'user';
    c.beliefs.init.values = vals;
    res = run(c);
    rd = res.dates.record;
    d = 0;
    nHand = 0;
    for i = 1:numel(lv)
        x = lv{i};
        p = res.paths.(x);
        L = res.learning.(x);
        a = vals.(x).R(1, 2); b = 0.5; Rv = vals.(x).R(2, 2) - a^2;   % the engine's reading of (phi, R)
        for k = 1:numel(rd)
            t = rd(k);
            e = p(t) - a;
            u = p(t - 1) - a;
            a = a + 0.05 * e;
            Rv = Rv + 0.05 * (e^2 - Rv);
            bn = b + 0.05 * ((e * u - b * e^2) / Rv);
            b = min(1, max(-1, bn));
            nHand = nHand + (bn ~= b);
            d = max([d, abs(L.(['alpha_' x])(t) - a * (1 - b)), abs(L.(['beta_' x])(t) - b), ...
                abs(L.(['R_beta_' x])(t) - (a^2 + Rv))]);
        end
    end
    bmax = max([abs(res.learning.y.beta_y(rd)); abs(res.learning.pie.beta_pie(rd))]);
    E = res.events;
    nB = sum(strcmp(E.type, 'sac_bound'));
    R = add(R, nm, nB > 0 && nB == nHand && d <= 1e-12 && bmax <= 1, sprintf(['%d sac_bound events, hand loop %d ' ...
        '(first: %s); max diff %.2g; max |beta| %.6g'], nB, nHand, first_detail(E, 'sac_bound'), d, bmax));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L10: toy, beliefs.update kf, AR(2) PLMs (gamma 0.05): recorded beliefs = hand loop of the covariance recursion (1e-10)';
try
    c = base;
    c.id = 'lr_toy_kf_ar2';
    c.beliefs.update = 'kf';
    c.beliefs.plm.default = 'ar2';
    c.beliefs.kf = struct('gamma', 0.05);
    res = run(c);
    [phi0, R0] = initial_beliefs(c);
    rd = res.dates.record;
    gam = 0.05;
    dp = 0;
    dM = 0;
    for i = 1:numel(lv)
        x = lv{i};
        p = res.paths.(x);
        L = res.learning.(x);
        ph = phi0.(x);
        s2 = R0.(x)(2, 2) - ph' * R0.(x) * ph;
        P = gam * s2 * inv(R0.(x)); %#ok<MINV>
        V = gam^2 / (1 - gam) * s2 * inv(R0.(x)); %#ok<MINV>
        for k = 1:numel(rd)
            t = rd(k);
            z = [1; p(t - 1); p(t - 2)];
            Pp = P + V;
            K = Pp * z / (z' * Pp * z + s2);
            ph = ph + K * (p(t) - z' * ph);
            P = Pp - K * z' * Pp;
            rec = cellfun(@(n) L.(n)(t), L.params)';
            dp = max(dp, max(abs(rec - ph)));
            Md = diag(gam * s2 * inv(P)); %#ok<MINV>
            Rd = cellfun(@(n) L.(['R_' n])(t), L.params)';
            dM = max(dM, max(abs(Rd - Md) ./ abs(Md)));
        end
    end
    R = add(R, nm, dp <= 1e-10 && dM <= 1e-8, sprintf(['max diff phi %.2g, recorded R vs diag(gamma s2 inv(P)) %.2g ' ...
        '(relative), %d quarters (y, pie); s2 at the RE moments'], dp, dM, numel(rd)));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L11: toy, KF on mean-only PLMs (s2 = 1) = RLS with constant gain gamma = 0.05 (the RLS limit in the engine; 1e-12)';
try
    c = base;
    c.beliefs.plm.by_var = mean_only;
    c.gain = struct('rule', 'constant', 'value', 0.05);
    c.id = 'lr_toy_mean_rls';
    rA = run(c);
    c.id = 'lr_toy_mean_kf';
    c.beliefs.update = 'kf';
    c.beliefs.kf = struct('gamma', 0.05, 's2', 1);
    rB = run(c);
    [d, w] = run_diff(rA, rB, lv);
    R = add(R, nm, d <= 1e-12, sprintf('max diff %.2g (%s); alpha_pie at the origin %.6g', d, w, ...
        rB.learning.pie.alpha_pie(qq(2020, 4))));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L12: toy, KF (AR(1), gamma 0.05): s2 re_moments and s2 = 2.5 give the same run (1e-10)';
try
    c = base;
    c.beliefs.update = 'kf';
    c.beliefs.kf = struct('gamma', 0.05);
    c.id = 'lr_toy_kf_re';
    rA = run(c);
    c.beliefs.kf.s2 = 2.5;
    c.id = 'lr_toy_kf_25';
    rB = run(c);
    [d, w] = run_diff(rA, rB, lv);
    rd = rA.dates.record;
    db = max(abs(rA.learning.pie.beta_pie(rd) - rA.learning.pie.beta_pie(rd(1))));
    R = add(R, nm, d <= 1e-10 && db > 1e-3, sprintf('max diff %.2g (%s); beta_pie moves by %.3g', d, w, db));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L13: toy, gain.rule decreasing: mean-only = running sample mean from beliefs.init.date; AR(1), n0 = 8 = hand RLS loop (1e-12)';
try
    c = base;
    c.id = 'lr_toy_dec_mean';
    c.beliefs.plm.by_var = mean_only;
    c.gain = struct('rule', 'decreasing');
    res = run(c);
    rd = res.dates.record;
    dm = 0;
    dg = 0;
    for i = 1:numel(lv)
        x = lv{i};
        p = res.paths.(x);
        cs = cumsum(p(rd)) ./ (1:numel(rd))';
        dm = max(dm, max(abs(res.learning.(x).(['alpha_' x])(rd) - cs)));
        dg = max(dg, max(abs(res.learning.(x).gain(rd) - 1 ./ (1:numel(rd))')));
    end
    c = base;
    c.id = 'lr_toy_dec_ar1';
    c.gain = struct('rule', 'decreasing', 'decreasing', struct('n0', 8));
    res = run(c);
    [phi0, R0] = initial_beliefs(c);
    rd = res.dates.record;
    dr = 0;
    for i = 1:numel(lv)
        x = lv{i};
        p = res.paths.(x);
        L = res.learning.(x);
        ph = phi0.(x);
        Rm = R0.(x);
        for k = 1:numel(rd)
            t = rd(k);
            g = 1 / (k - 1 + 8);
            z = [1; p(t - 1)];
            Rm = Rm + g * (z * z' - Rm);
            ph = ph + g * (Rm \ (z * (p(t) - ph' * z)));
            dr = max([dr, abs(L.(['alpha_' x])(t) - ph(1)), abs(L.(['beta_' x])(t) - ph(2)), abs(L.gain(t) - g)]);
        end
    end
    R = add(R, nm, dm <= 1e-12 && dg == 0 && dr <= 1e-12, sprintf(['mean-only: alpha vs running mean %.2g, gains vs 1/k ' ...
        '%.2g, %d quarters; AR(1) n0 = 8 vs hand loop %.2g'], dm, dg, numel(rd), dr));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'lr L14: toy, N-type path: RE and BR spelled out, BR with update sac and kf = the two-type runs (fresh RE filters; 1e-12)';
try
    msg = {};
    dAll = 0;
    for u = {'sac', 'kf'}
        c = base;
        c.beliefs.update = u{1};
        c.gain = struct('rule', 'constant', 'value', 0.05);
        c.id = ['lr_toy_two_' u{1}];
        r2 = fresh_run(c);
        c.id = ['lr_toy_nt_' u{1}];
        c.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'BR', 'kind', 'plm')};
        rN = fresh_run(c);
        [d, w] = nt_diff(r2, rN, lv);
        dAll = max(dAll, d);
        msg{end+1} = sprintf('%s %.2g (%s)', u{1}, d, w); %#ok<AGROW>
    end
    R = add(R, nm, dAll <= 1e-12, ['max diff ' strjoin(msg, '; ')]);
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = ah(R, here)
ahDir = fullfile(here, 'models', 'ah');
addpath(ahDir);                                    % the P2 test gain rule hetlearn.gain.ah_sample_mean
cAH = onCleanup(@() rmpath(ahDir));
nm = 'lr L15: AH four heuristics, LAA anchor with gain.rule decreasing = the P2 test rule ah_sample_mean (3 cases, max diff 0)';
try
    T = @(varargin) struct(varargin{:});
    rules = @(gr) {T('name', 'ADA', 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*self{-1}'), ...
        T('name', 'WTR', 'kind', 'rule', 'rule', 'x{-1} + 0.4*(x{-1} - x{-2})'), ...
        T('name', 'STR', 'kind', 'rule', 'rule', 'x{-1} + 1.3*(x{-1} - x{-2})'), ...
        T('name', 'LAA', 'kind', 'rule', 'rule', '0.5*(mean + x{-1}) + (x{-1} - x{-2})', 'gain', struct('rule', gr))};
    cases = {[0.25 0.25 0.25 0.25], [-5 0 -10]; [0.05 0.05 0.05 0.85], [-5 -10 -5]; [0.1 0.1 0.7 0.1], [-10 -5 0]};
    names = {'ADA', 'WTR', 'STR', 'LAA'};
    d = 0;
    msg = {};
    for i = 1:size(cases, 1)
        rA = ah_run(ahDir, rules('ah_sample_mean'), cases{i, 1}, cases{i, 2}, sprintf('lr_ah%da', i));
        rB = ah_run(ahDir, rules('decreasing'), cases{i, 1}, cases{i, 2}, sprintf('lr_ah%db', i));
        rd = rA.dates.record;
        di = max(abs(rA.paths.p(rd) - rB.paths.p(rd)));
        for k = 1:4
            di = max([di; abs(rA.learning.p.(['n_' names{k}])(rd) - rB.learning.p.(['n_' names{k}])(rd)); ...
                abs(rA.learning.p.(['f_' names{k}])(rd) - rB.learning.p.(['f_' names{k}])(rd))]);
        end
        di = max([di; abs(rA.learning.p__LAA.alpha_p__LAA(rd) - rB.learning.p__LAA.alpha_p__LAA(rd))]);
        d = max(d, di);
        msg{end+1} = sprintf('case %d: %.2g, final LAA share %.3f', i, di, rB.learning.p.n_LAA(rd(end))); %#ok<AGROW>
    end
    R = add(R, nm, d == 0, strjoin(msg, '; '));
catch err
    R = add(R, nm, false, where(err));
end
clear cAH
end


function res = ah_run(ahDir, types, n0, p0, id)
% one AH run as in test_ntypes: data p_obs = 60 + p0 over 2000Q1-Q3, origin 2000Q3, 50 quarters, zero shocks
dates = qq(2000, 1):qq(2000, 3);
if exist(fullfile(ahDir, 'data'), 'dir') ~= 7
    mkdir(fullfile(ahDir, 'data'));
end
databank.toCSV(struct('p_obs', Series(dates, 60 + p0(:))), fullfile(ahDir, 'data', 'ah_database.csv'), dates, ...
    'Format', '%.17g');
c = struct();
c.id = id;
c.model = ahDir;
c.forecast = struct('origin', qq(2000, 3), 'horizon', 50);
c.expectations = struct('mode', 'switching', 'variables', {{'p'}}, 'types', {types});
c.beliefs.init.date = qq(2000, 3);
c.switching = struct('intensity', 0.4, 'memory', 0.7, 'inertia', 0.9, 'fitness', 'unnormalized');
nm = cellfun(@(t) t.name, types, 'UniformOutput', false);
c.shares.init = cell2struct(num2cell(n0(:)), nm(:), 1);
c.projection.facility = 'none';
res = hetlearn.run(c, 'save', false, 'quiet', true);
end


% =========================================================================================
function [phi0, R0] = initial_beliefs(cfg)
% the RE-moment initial beliefs of hetlearn.engine.state_init for a two-type run
opts = hetlearn.load_options(cfg);
spec = hetlearn.load_spec(opts.model);
[m, info] = hetlearn.load_model(spec, opts);
[phi0, R0] = hetlearn.init.re_moments(m, info.sys);
end


function res = fresh_run(cfg)
% hetlearn.run with the RE filter recomputed in this session (as tests/test_ntypes.m)
opts = hetlearn.load_options(cfg);
spec = hetlearn.load_spec(opts.model);
[m, info] = hetlearn.load_model(spec, opts);
H = fresh_filter(spec, opts);
res = hetlearn.run(cfg, 'save', false, 'quiet', true, 'model', struct('spec', spec, 'm', m, 'info', info), ...
    'filter', H);
end


function H = fresh_filter(spec, opts)
% the IRIS filter call of hetlearn.re_filter, without its cache file (as tests/test_ntypes.m)
lagged = strcmp(opts.expectations.re_info, 'lagged');
o = opts;
if ~lagged
    o.expectations.variables = 'all';
end
o.policy.mode = 'rule';
[m, info] = hetlearn.load_model(spec, o);
d = hetlearn.load_database(spec);
range = hetlearn.util.to_dates(spec.filter_range);
H = struct();
if lagged
    [~, f] = filter(m, d, range, 'output', 'pred,filter,smooth', 'meanOnly', true);
    H.predicted = f.pred;
else
    [~, f] = filter(m, d, range, 'output', 'filter,smooth', 'meanOnly', true);
end
H.smooth = f.smooth;
H.filtered = f.filter;
H.range = range;
H.data = d;
H.fit_error = 0;
H.hash = ['fresh:' info.meta.ext_file];
H.file = '';
H.cached = false;
H.model = m;
H.realtime = false;
H.end_date = range(end);
end


function [d, w] = run_diff(a, b, lv)
% max abs difference of two two-type runs: every path, the learning series of every PLM target, events
d = 0;
w = '';
f = fieldnames(a.paths);
for i = 1:numel(f)
    [d, w] = upd(d, w, sdiff(a.paths.(f{i}), b.paths.(f{i})), ['paths.' f{i}]);
end
tg = fieldnames(a.learning);
for i = 1:numel(tg)
    A = a.learning.(tg{i});
    B = b.learning.(tg{i});
    g = fieldnames(A);
    for j = 1:numel(g)
        if isa(A.(g{j}), 'Series') && ~strcmp(g{j}, 'gain')
            [d, w] = upd(d, w, sdiff(A.(g{j}), B.(g{j})), ['learning.' tg{i} '.' g{j}]);
        end
    end
end
for i = 1:numel(lv)
    [d, w] = upd(d, w, sdiff(a.learning.(lv{i}).n2, b.learning.(lv{i}).n2), ['n2.' lv{i}]);
end
if height(a.events) ~= height(b.events)
    d = Inf;
    w = sprintf('%d vs %d events', height(a.events), height(b.events));
end
end


function [d, w] = nt_diff(r2, rN, lv)
% two-type run r2 against the same run with types RE and BR spelled out
d = 0;
w = '';
f = fieldnames(r2.paths);
for i = 1:numel(f)
    if isfield(rN.paths, f{i})
        [d, w] = upd(d, w, sdiff(r2.paths.(f{i}), rN.paths.(f{i})), ['paths.' f{i}]);
    else
        d = Inf;
        w = ['missing path ' f{i}];
        return
    end
end
for i = 1:numel(lv)
    x = lv{i};
    A = r2.learning.(x);
    B = rN.learning.([x '__BR']);
    for j = 1:numel(A.params)
        p = A.params{j};
        [d, w] = upd(d, w, sdiff(A.(p), B.([p '__BR'])), ['learning.' p]);
        [d, w] = upd(d, w, sdiff(A.(['R_' p]), B.(['R_' p '__BR'])), ['learning.R_' p]);
    end
    [d, w] = upd(d, w, sdiff(A.n2, rN.learning.(x).n_BR), ['n2.' x]);
    [d, w] = upd(d, w, sdiff(A.fBR, rN.learning.(x).f_BR), ['fBR.' x]);
end
if height(r2.events) ~= height(rN.events)
    d = Inf;
    w = sprintf('%d vs %d events', height(r2.events), height(rN.events));
end
end


function [d, w] = upd(d, w, v, name)
if ~(v <= d)
    d = v;
    w = name;
end
end


function v = sdiff(a, b)
% max abs difference of two Series on the dates of either (NaN in one only counts as Inf)
v = 0;
for r = {a.Range, b.Range}
    x = a(r{1});
    y = b(r{1});
    e = abs(x(:) - y(:));
    e(isnan(x(:)) & isnan(y(:))) = 0;
    e(isnan(e)) = Inf;
    v = max([v; e]);
end
end


function ok = expect_id(f, id)
ok = false;
try
    f();
catch err
    ok = strcmp(err.identifier, id);
end
end


function s = first_detail(E, type)
s = '';
i = find(strcmp(E.type, type), 1);
if ~isempty(i)
    s = sprintf('%s %s: %s', char(E.date(i)), char(E.variable(i)), char(E.detail(i)));
end
end


function s = ev_text(ev)
if isempty(ev)
    s = 'none';
else
    s = sprintf('%s %s (%s)', ev(1).type, ev(1).variable, ev(1).detail);
end
end


function ev = empty_ev()
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
end


function s = where(err)
s = err.message;
if ~isempty(err.stack)
    s = sprintf('%s (%s, line %d)', s, err.stack(1).name, err.stack(1).line);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
