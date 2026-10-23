function out = independent_learning_check()
%INDEPENDENT_LEARNING_CHECK  The toolbox's learning and switching recursion against plain MATLAB code.
%
%   out = independent_learning_check()     (from the repository root, after setup_paths)
%
%   What it compares. Three toolbox runs of the three-equation New Keynesian
%   package models/ijcb3 (learning on inflation only, AR(1) PLM with a
%   constant, anchored RE agents, learners and RE agents on information up
%   to t-1, initial beliefs from the RE moments, no projection facility,
%   48 quarters of fixed shocks from the RE-smoothed state at 2019Q4):
%     constant   constant gain, fixed shares (half learners)
%     koz        endogenous gain of Kostyshyna, Ozden and Zhang, fixed shares
%     switching  endogenous gain and discrete-choice switching
%   are compared with an implementation written here from the equations of
%   docs/technical_appendix (expectation block, anchored RE forecast with
%   t-1 information, RLS, gain rules, fitness and shares, the sequence of
%   one quarter). It calls nothing in the toolbox: it solves the RE(t-1)
%   model and each quarter's actual law of motion with its own QZ solver,
%   computes the RE moments with its own Lyapunov equation and runs its own
%   loop. The only inputs taken from the toolbox run are the RE-smoothed
%   values at the origin and one quarter before it (the starting state).
%
%   Compared paths: inflation, output gap and policy rate; the learners' and
%   the RE agents' forecasts; the beliefs (constant and AR coefficient) and
%   the diagonal of R; the gain and the gain state Rg; the fitness values,
%   the discrete-choice shares and the shares in force in the model; the
%   squared forecast errors. PASS when every maximum absolute difference is
%   below 1e-10.
%
%   Output out: struct array, one element per configuration, with the
%   maximum absolute difference per series (.maxdiff), the overall maximum
%   (.max) and .pass; out(1).all_pass for the whole check.
%
%   Writes nothing except what a normal run writes (the generated model
%   files and the RE filter cache under models/ijcb3/generated/); the runs
%   are not saved.

tol = 1e-10;
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
pkg = fullfile(root, 'models', 'ijcb3');
P = package_params(pkg);

origin = qq(2019, 4);
H = 48;
hz = origin + 1 : origin + H;
shockNames = {'eps_y', 'eps_pinf', 'eps_r'};
sd = [P.std_eps_y, P.std_eps_pinf, P.std_eps_r];
stream = RandStream('mt19937ar', 'Seed', 20261023);
E = randn(stream, H, 3) .* sd;                 % fixed shock history, H x 3

cases = struct( ...
    'name', {'constant', 'koz', 'switching'}, ...
    'mode', {'fixed_shares', 'fixed_shares', 'switching'}, ...
    'gain', {'constant', 'koz', 'koz'});
L = struct('gain0', 0.0585, 'mu', 0.005, 'Rg0', 0, 'bounds', [0.001 0.25], ...
    'chi', 5, 'omega', 0.8, 'init_n2', 0.5, 'fixed_n2', 0.5);

fprintf('Independent check of the learning recursion: model ijcb3, origin %s, %d quarters\n', ...
    char(dat2str(origin)), H);
tAll = tic;
re = re_lagged_solution(P);                    % anchored coefficients and RE moments
out = struct('name', {}, 'range', {}, 'maxdiff', {}, 'max', {}, 'pass', {}, 'runtime_s', {});
for k = 1:numel(cases)
    c = cases(k);
    t0 = tic;
    cfg = toolbox_cfg(c, L, origin, H, hz, shockNames, E);
    res = hetlearn.run(cfg, 'save', false, 'quiet', true);
    tb = toolbox_paths(res, origin, hz);
    ind = independent_run(P, re, c, L, tb.x0, tb.xm1, E);
    [md, mx] = compare(tb, ind);
    ev = res.events;
    if ~isempty(ev)
        bad = ~strcmp(ev.type, 'gain_bound');
        if any(bad)
            error('independent_learning_check:events', 'Run %s has events other than gain_bound: %s.', ...
                c.name, strjoin(unique(ev.type(bad)), ', '));
        end
    end
    out(k).name = c.name;
    out(k).range = struct('beta', [min(tb.beta), max(tb.beta)], 'gain', [min(tb.gain), max(tb.gain)], ...
        'n1', [min(tb.n1), max(tb.n1)]);
    out(k).maxdiff = md;
    out(k).max = mx;
    out(k).pass = mx < tol;
    out(k).runtime_s = toc(t0);
end

% ---- report ------------------------------------------------------------------------------
f = fieldnames(out(1).maxdiff);
fprintf('\n%-12s', 'series');
for k = 1:numel(out)
    fprintf('%14s', out(k).name);
end
fprintf('\n');
for j = 1:numel(f)
    fprintf('%-12s', f{j});
    for k = 1:numel(out)
        fprintf('%14.2e', out(k).maxdiff.(f{j}));
    end
    fprintf('\n');
end
fprintf('%-12s', 'max');
for k = 1:numel(out)
    fprintf('%14.2e', out(k).max);
end
fprintf('\n\nRange over the record (toolbox values):\n');
for k = 1:numel(out)
    g = out(k).range;
    fprintf('  %-10s beta %.4f to %.4f, gain %.4f to %.4f, RE share %.4f to %.4f\n', out(k).name, ...
        g.beta, g.gain, g.n1);
end
allPass = all([out.pass]);
out(1).all_pass = allPass;
if allPass
    fprintf('PASS  independent_learning_check: every difference below %.0e (%.1f s)\n', tol, toc(tAll));
else
    fprintf('FAIL  independent_learning_check: largest difference %.2e, tolerance %.0e (%.1f s)\n', ...
        max([out.max]), tol, toc(tAll));
end
end


% =========================================================================
function P = package_params(pkg)
% Parameter values of the package, read from its parameter file.
old = addpath(pkg);
c = onCleanup(@() path(old));
P = ijcb3_params();
end


function cfg = toolbox_cfg(c, L, origin, H, hz, shockNames, E)
% Every option that matters is set here, so the check does not depend on
% config/master_options.m.
cfg = struct();
cfg.id = ['independent_check_' c.name];
cfg.model = 'ijcb3';
cfg.model_params = '';
cfg.forecast.origin = origin;
cfg.forecast.horizon = H;
cfg.expectations.mode = c.mode;
cfg.expectations.variables = {'pinf'};
cfg.expectations.re_variant = 'anchored';
cfg.expectations.re_info = 'lagged';
cfg.beliefs.update = 'rls';
cfg.beliefs.info = 'lagged';
cfg.beliefs.plm.default = 'ar1';
cfg.beliefs.init.method = 're_moments';
cfg.gain.rule = c.gain;
cfg.gain.value = L.gain0;
cfg.gain.koz.mu = L.mu;
cfg.gain.koz.gamma0 = [];
cfg.gain.koz.Rg0 = L.Rg0;
cfg.gain.koz.bounds = L.bounds;
cfg.gain.koz.error = 'rls';
cfg.gain.koz.error_scale = 1;
cfg.gain.koz.structure = 'common';
cfg.gain.koz.master = '';
cfg.switching.rule = 'discrete_choice';
cfg.switching.intensity = L.chi;
cfg.switching.memory = L.omega;
cfg.shares.structure = 'per_variable';
cfg.shares.init_n2 = L.init_n2;
if strcmp(c.mode, 'fixed_shares')
    cfg.shares.fixed_n2 = L.fixed_n2;
end
cfg.projection.facility = 'none';
cfg.history.learn = false;
cfg.history.mode = 're_smoother';
cfg.history.re_states = 'smoothed';
cfg.history.realtime = false;
cfg.engine.step = 'fast';
cfg.shocks.source = 'none';
cfg.shocks.add = cell(1, numel(shockNames));
for j = 1:numel(shockNames)
    cfg.shocks.add{j} = {shockNames{j}, hz, E(:, j)'};
end
end


function tb = toolbox_paths(res, origin, hz)
% Series of a toolbox run on the record dates (origin first, then the horizon).
rd = [origin, hz];
x = {'y', 'pinf', 'r', 'u_y', 'u_pinf'};
tb = struct();
tb.x0 = zeros(5, 1);
tb.xm1 = zeros(5, 1);
for i = 1:5
    s = res.paths.(x{i});
    tb.x0(i) = s(origin);
    tb.xm1(i) = s(origin - 1);
end
tb.y = res.paths.y(hz);
tb.pinf = res.paths.pinf(hz);
tb.r = res.paths.r(hz);
Lp = res.learning.pinf;
tb.fBR = Lp.fBR(rd);
tb.fRE = Lp.fRE(rd);
tb.alpha = Lp.alpha_pinf(rd);
tb.beta = Lp.beta_pinf(rd);
tb.R11 = Lp.R_alpha_pinf(rd);
tb.R22 = Lp.R_beta_pinf(rd);
tb.gain = Lp.gain(hz);
if isfield(Lp, 'gain_R')
    tb.gain_R = Lp.gain_R(hz);
else
    tb.gain_R = NaN(numel(hz), 1);
end
tb.n1 = Lp.n1(rd);
tb.n1_model = Lp.n1_model(hz);
tb.zetaRE = Lp.zetaRE(rd);
tb.zetaBR = Lp.zetaBR(rd);
tb.FE_RE = Lp.FE_RE(hz);
tb.FE_BR = Lp.FE_BR(hz);
end


function [md, mx] = compare(tb, ind)
f = {'pinf', 'y', 'r', 'fBR', 'fRE', 'alpha', 'beta', 'R11', 'R22', 'gain', 'gain_R', ...
    'n1', 'n1_model', 'zetaRE', 'zetaBR', 'FE_RE', 'FE_BR'};
md = struct();
mx = 0;
for j = 1:numel(f)
    a = tb.(f{j})(:);
    b = ind.(f{j})(:);
    if numel(a) ~= numel(b)
        error('independent_learning_check:size', 'Series %s: %d toolbox values, %d independent.', ...
            f{j}, numel(a), numel(b));
    end
    both = isnan(a) & isnan(b);
    if any(isnan(a) ~= isnan(b))
        d = Inf;
    else
        d = max([0; abs(a(~both) - b(~both))]);
    end
    md.(f{j}) = d;
    mx = max(mx, d);
end
end


% =========================================================================
% Independent implementation (no toolbox calls below this line)
% =========================================================================
function re = re_lagged_solution(P)
% The RE(t-1) model: the ijcb3 equations with E_{t-1} pinf_{t+1} in place of
% E_t pinf_{t+1} in the IS curve and the Phillips curve. Variables
% X = (y, pinf, r, u_y, u_pinf, w, z) with w_t = E_t pinf_{t+1} and
% z_t = E_t w_{t+1} = E_t pinf_{t+2}, so z_{t-1} = E_{t-1} pinf_{t+1}.
% The anchored RE forecast made in t is c' s_{t-1}, with s the five states
% (y, pinf, r, u_y, u_pinf): on the RE(t-1) solution z_t = c' s_t.
n = 7;
iy = 1; ip = 2; ir = 3; iuy = 4; iup = 5; iw = 6; iz = 7;
F = zeros(n);
G = zeros(n);
Hm = zeros(n);
D = zeros(n, 3);
% IS curve: y = (1-iota_y) E y{+1} + iota_y y{-1} - (1/tau)(r - z{-1}) + u_y
G(1, iy) = 1; F(1, iy) = -(1 - P.iota_y); Hm(1, iy) = -P.iota_y;
G(1, ir) = 1 / P.tau; Hm(1, iz) = -1 / P.tau; G(1, iuy) = -1;
% Phillips curve: pinf = beta((1-iota_p) z{-1} + iota_p pinf{-1}) + kappa y + u_pinf
G(2, ip) = 1; Hm(2, iz) = -P.beta * (1 - P.iota_p); Hm(2, ip) = -P.beta * P.iota_p;
G(2, iy) = -P.kappa; G(2, iup) = -1;
% Taylor rule
[G, Hm, D] = taylor_rows(P, G, Hm, D, 3, iy, ip, ir);
% shocks
G(4, iuy) = 1; Hm(4, iuy) = -P.rho_y; D(4, 1) = -1;
G(5, iup) = 1; Hm(5, iup) = -P.rho_pi; D(5, 2) = -1;
% expectation chain
G(6, iw) = 1; F(6, ip) = -1;
G(7, iz) = 1; F(7, iw) = -1;
[Pm, ~, Qm] = solve_quadratic(F, G, Hm, zeros(n, 1), D);
% z_t = c' s_t: from z_t = Pz X_{t-1} + Qz e_t and s_t = Ps X_{t-1} + Qs e_t
s = 1:5;
A = [Pm(s, :), Qm(s, :)]';
b = [Pm(iz, :), Qm(iz, :)]';
c = A \ b;
if norm(A * c - b, Inf) > 1e-12
    error('independent_learning_check:anchor', 'z_t is not a function of s_t (residual %.2g).', ...
        norm(A * c - b, Inf));
end
% Fixed-point check: in the economy where every agent uses c, E_{t-1} pinf_{t+1} = c' s_{t-1}
[Ps, ~, Qs] = solve_alm(P, 0, c);
e2 = zeros(5, 1);
e2(2) = 1;
if norm((e2' * Ps^2)' - c, Inf) > 1e-12
    error('independent_learning_check:anchor', 'Anchored coefficients are not a fixed point.');
end
% RE moments of inflation in the RE(t-1) economy: Sigma = Ps Sigma Ps' + Qs Omega Qs'
Om = diag([P.std_eps_y, P.std_eps_pinf, P.std_eps_r] .^ 2);
V = Qs * Om * Qs';
Sig = reshape((eye(25) - kron(Ps, Ps)) \ V(:), 5, 5);
Sig = (Sig + Sig') / 2;
G1 = Ps * Sig;                                % Cov(s_t, s_{t-1})
re = struct('c', c, 'var_pinf', Sig(2, 2), 'rho1', G1(2, 2) / Sig(2, 2));
end


function [G, Hm, D] = taylor_rows(P, G, Hm, D, row, iy, ip, ir)
% r = rho_r r{-1} + (1-rho_r)(phi_pi pinf + phi_y y) + phi_dy (y - y{-1}) + eps_r
G(row, ir) = 1; Hm(row, ir) = -P.rho_r;
G(row, ip) = -(1 - P.rho_r) * P.phi_pi;
G(row, iy) = -(1 - P.rho_r) * P.phi_y - P.phi_dy;
Hm(row, iy) = P.phi_dy;
D(row, 3) = -1;
end


function [Pm, cm, Qm] = solve_alm(P, a, b)
% Actual law of motion of one quarter. The aggregate inflation expectation
% is predetermined, Pe_t = a + b' s_{t-1}; output-gap expectations are
% model consistent under anticipated utility (beliefs and shares held
% fixed). s = (y, pinf, r, u_y, u_pinf); s_t = Pm s_{t-1} + cm + Qm e_t.
n = 5;
iy = 1; ip = 2; ir = 3; iuy = 4; iup = 5;
F = zeros(n);
G = zeros(n);
Hm = zeros(n);
K = zeros(n, 1);
D = zeros(n, 3);
b = b(:)';
% IS curve: y = (1-iota_y) E y{+1} + iota_y y{-1} - (1/tau)(r - Pe) + u_y
G(1, iy) = 1; F(1, iy) = -(1 - P.iota_y); Hm(1, iy) = -P.iota_y;
G(1, ir) = 1 / P.tau; G(1, iuy) = -1;
Hm(1, :) = Hm(1, :) - b / P.tau; K(1) = -a / P.tau;
% Phillips curve: pinf = beta((1-iota_p) Pe + iota_p pinf{-1}) + kappa y + u_pinf
G(2, ip) = 1; Hm(2, ip) = -P.beta * P.iota_p; G(2, iy) = -P.kappa; G(2, iup) = -1;
Hm(2, :) = Hm(2, :) - P.beta * (1 - P.iota_p) * b; K(2) = -P.beta * (1 - P.iota_p) * a;
[G, Hm, D] = taylor_rows(P, G, Hm, D, 3, iy, ip, ir);
G(4, iuy) = 1; Hm(4, iuy) = -P.rho_y; D(4, 1) = -1;
G(5, iup) = 1; Hm(5, iup) = -P.rho_pi; D(5, 2) = -1;
[Pm, cm, Qm] = solve_quadratic(F, G, Hm, K, D);
end


function [Pm, cm, Qm] = solve_quadratic(F, G, Hm, K, D)
% Unique stable solution x_t = Pm x_{t-1} + cm + Qm e_t of
% F E_t x_{t+1} + G x_t + Hm x_{t-1} + K + D e_t = 0: Pm from the stable
% deflating subspace of the companion pencil (QZ), then the constant and
% the impact matrix.
n = size(G, 1);
A = [eye(n), zeros(n); zeros(n), F];
B = [zeros(n), eye(n); -Hm, -G];
[AA, BB, Q, Z] = qz(B, A, 'complex');          % B v = lambda A v, lambda = AA(i,i)/BB(i,i)
sel = abs(diag(AA)) < abs(diag(BB));
if nnz(sel) ~= n
    error('independent_learning_check:bk', '%d stable roots for %d variables.', nnz(sel), n);
end
[~, ~, ~, Z] = ordqz(AA, BB, Q, Z, sel);
Pm = real(Z(n+1:end, 1:n) / Z(1:n, 1:n));
if norm(F * Pm^2 + G * Pm + Hm, Inf) > 1e-11
    error('independent_learning_check:qz', 'Matrix quadratic residual %.2g.', norm(F * Pm^2 + G * Pm + Hm, Inf));
end
cm = -(F * (Pm + eye(n)) + G) \ K;
Qm = -(F * Pm + G) \ D;
end


function ind = independent_run(P, re, c, L, x0, xm1, E)
% The forecast-stage loop, quarter by quarter, as in the appendix's
% sequence of one quarter. x0, xm1: the five states at the origin T0 and at
% T0-1 (RE-smoothed history). Record index 1 is the origin, 2..H+1 the
% horizon.
H = size(E, 1);
ip = 2;
c_re = re.c;
koz = strcmp(c.gain, 'koz');
switching = strcmp(c.mode, 'switching');

% initial state at the origin
phi = [0; re.rho1];                            % RE moments: alpha_0 = 0, beta_0 = rho_1(pinf)
R = diag([1, re.var_pinf]);
zRE = 0;
zBR = (log(L.init_n2) - log(1 - L.init_n2)) / L.chi;
n1 = 1 - L.init_n2;
gam = L.gain0;
Rg = L.Rg0;
fREp = c_re' * xm1;                            % forecasts of pinf_{T0+1} made in T0 (history)
fBRp = phi(1) + phi(2) * (phi(1) + phi(2) * xm1(ip));

T = H + 1;
ind = struct();
[ind.alpha, ind.beta, ind.R11, ind.R22, ind.n1, ind.zetaRE, ind.zetaBR, ind.fRE, ind.fBR] = ...
    deal(NaN(T, 1));
[ind.pinf, ind.y, ind.r, ind.gain, ind.gain_R, ind.n1_model, ind.FE_RE, ind.FE_BR] = deal(NaN(H, 1));
ind.alpha(1) = phi(1); ind.beta(1) = phi(2); ind.R11(1) = R(1, 1); ind.R22(1) = R(2, 2);
ind.n1(1) = n1; ind.zetaRE(1) = zRE; ind.zetaBR(1) = zBR; ind.fRE(1) = fREp; ind.fBR(1) = fBRp;

xp = x0;
e2 = zeros(5, 1);
e2(ip) = 1;
for k = 1:H
    % (1) shares in force and beliefs phi_{t-1}
    if switching
        n1m = n1;                              % n1_{t-1}
    else
        n1m = 1 - L.fixed_n2;
    end
    al = phi(1);
    be = phi(2);
    % aggregate expectation Pe_t = n1 (c' s_{t-1}) + n2 (alpha + beta (alpha + beta pinf_{t-1}))
    a = (1 - n1m) * al * (1 + be);
    b = n1m * c_re + (1 - n1m) * be^2 * e2;
    % (2) solve, (3) simulate quarter t
    [Pm, cm, Qm] = solve_alm(P, a, b);
    x = Pm * xp + cm + Qm * E(k, :)';
    % (4) forecasts of pinf_{t+1} made in t, both on data up to t-1
    fRE = c_re' * xp;
    fBR = al + be * (al + be * xp(ip));
    % (5) end of t: errors of the forecasts made in t-1, fitness, shares
    FEr = (x(ip) - fREp)^2;
    FEb = (x(ip) - fBRp)^2;
    zRE = -(1 - L.omega) * FEr + L.omega * zRE;
    zBR = -(1 - L.omega) * FEb + L.omega * zBR;
    n1 = 1 / (1 + exp(-L.chi * (zRE - zBR)));
    % RLS with the gain of the process before this quarter's update
    zr = [1; xp(ip)];
    res = x(ip) - phi' * zr;
    if koz
        g = gam;
    else
        g = L.gain0;
    end
    R = R + g * (zr * zr' - R);
    phi = phi + g * (R \ (zr * res));
    % gain state at the end of t
    if koz
        gNew = gam + L.mu * Rg * res;
        Rg = (1 - gam) * Rg + res;
        gam = min(max(gNew, L.bounds(1)), L.bounds(2));
    end
    % store
    ind.pinf(k) = x(ip); ind.y(k) = x(1); ind.r(k) = x(3);
    ind.gain(k) = g;
    if koz
        ind.gain_R(k) = Rg;
    end
    ind.n1_model(k) = n1m;
    ind.FE_RE(k) = FEr; ind.FE_BR(k) = FEb;
    ind.alpha(k+1) = phi(1); ind.beta(k+1) = phi(2); ind.R11(k+1) = R(1, 1); ind.R22(k+1) = R(2, 2);
    ind.n1(k+1) = n1; ind.zetaRE(k+1) = zRE; ind.zetaBR(k+1) = zBR;
    ind.fRE(k+1) = fRE; ind.fBR(k+1) = fBR;
    fREp = fRE;
    fBRp = fBR;
    xp = x;
end
end
