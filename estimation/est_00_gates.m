function R = est_00_gates(which)
%EST_00_GATES  Validation gates G0-G6 of the estimator (G7 is run by est_01_mode_re).
%
%   R = est_00_gates()                 % every gate
%   R = est_00_gates({'G1', 'G5'})     % a subset
%
%   Needs results/estimation/gates/g0_dynare.mat from est_00_g0_dynare (a session without
%   IRIS). Writes results/estimation/gates.txt (one line per gate, newest run appended under
%   a header) and gates/gates_<gate>.mat with the details. No estimation may run before
%   G0-G6 pass.
%
%   G0  own log prior = Dynare 4.6.1 priordens at the swX1 mode and 200 random points (1e-10)
%   G1  own RE Kalman filter = IRIS loglik(..., 'relative', false) at swX1, full range and
%       objFuncRange 1966Q1-, per quarter, and at 8 perturbed thetas (1e-6)
%   G2  own Dynare-style filter (lik_init 2, presample 4, covid quarters kept) + own prior =
%       Dynare's swX1 log posterior -1578.2488144054 (1e-6)
%   G3  learning filter in mode 'rational', 'fixed_shares' with fixed_n2 = 0 and 'switching'
%       with init_n2 = 0 = the RE likelihood (1e-8), at the calibration and a perturbed theta;
%       plus the building blocks: RE moments = hetlearn.init.re_moments, anchored
%       coefficients = hetlearn.re_anchor_coefficients, fast RE ALM = original model (1e-10)
%   G4  (a1) learning filter started from the engine's RE-smoothed 1965Q4 state with P = 0 =
%       the engine's inversion history (history.mode 'inversion') over 1966Q1-2019Q4: beliefs,
%       n2, n1_model, f^RE, f^BR, shocks (1e-8) and event dates; (a2, information only) the
%       same with the estimation's stochastic start: differences by decade (they do not die
%       out: four observables are first differences, P_{t|t} does not collapse); (b) the lean
%       recursion = hetlearn.engine.update_learning fed with the filter's path (1e-12), at the
%       calibration, a high-gain point and a prior draw with ALM reverts/kept shares
%   G5  fast solver (static elimination + QZ) = IRIS solve in every quarter of one evaluation
%       at the calibration and 20 prior draws ('lagged') plus 5 ('current'): T, R, K 1e-9, same
%       stability verdict
%   G6  RWMH, diagnostics and marginal-likelihood machinery on a 39-dimensional Gaussian

if nargin < 1 || isempty(which)
    which = {'G0', 'G1', 'G2', 'G3', 'G4', 'G5', 'G6'};
end
which = cellstr(which);
c = setup_est();
maxNumCompThreads(c.threads);
gdir = fullfile(c.results, 'gates');
lines = {};
R = struct();
pbR = [];
pbL = [];
if any(ismember(which, {'G1', 'G2', 'G3', 'G4', 'G5'}))
    pbR = hlest.problem('re');
end
if any(ismember(which, {'G3', 'G4', 'G5'}))
    pbL = hlest.problem('learn');
end
for k = 1:numel(which)
    g = which{k};
    t0 = tic;
    try
        switch g
            case 'G0', r = gate0(c, gdir);
            case 'G1', r = gate1(pbR);
            case 'G2', r = gate2(c, pbR, gdir);
            case 'G3', r = gate3(pbR, pbL);
            case 'G4', r = gate4(pbR, pbL);
            case 'G5', r = gate5(pbL);
            case 'G6', r = gate6();
        end
    catch err
        r = struct('pass', false, 'text', sprintf('ERROR %s', err.message), 'err', getReport(err));
        fprintf('%s\n', getReport(err));
    end
    r.time_s = toc(t0);
    R.(g) = r;
    st = 'FAIL';
    if r.pass
        st = 'PASS';
    end
    lines{end+1} = sprintf('%s %s  %s  [%.0f s]', g, st, r.text, r.time_s); %#ok<AGROW>
    fprintf('%s\n', lines{end});
    save(fullfile(gdir, sprintf('gates_%s.mat', g)), 'r');
end
fid = fopen(fullfile(c.results, 'gates.txt'), 'a');
fprintf(fid, '\n# est_00_gates %s (toolbox root %s)\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), c.toolbox_root); %#ok<TNOW1,DATST>
fprintf(fid, '%s\n', lines{:});
fclose(fid);
end


% =========================================================================
function r = gate0(c, gdir)
G = load(fullfile(gdir, 'g0_dynare.mat'));
P0 = sw07_params_from(c);
T = hlest.param_table('re', 'ijcb', P0);
names = cellstr(G.names);
assert(isequal(names(:), T.name(:)), 'G0: parameter order differs from Dynare''s bayestopt_.name');
assert(max(abs(G.bounds(:, 1) - T.lb)) == 0 && max(abs(G.bounds(:, 2) - T.ub)) == 0, 'G0: bounds differ');
dHyp = max([abs(G.p6(:) - T.h1(:)); abs(G.p7(:) - T.h2(:))]./max(1, abs([G.p6(:); G.p7(:)])));
lpm = hlest.prior_logpdf(T, G.xmode);
d1 = abs(lpm - G.lp_mode);
d2 = 0;
for k = 1:size(G.X, 2)
    d2 = max(d2, abs(hlest.prior_logpdf(T, G.X(:, k)) - G.lp_rand(k)));
end
r = struct('pass', d1 < 1e-10 && d2 < 1e-10, 'text', sprintf(['own log prior vs Dynare priordens: at the swX1 mode ' ...
    '%.12f vs %.12f (diff %.2g), 200 random points max diff %.2g; hyperparameters p6/p7 max rel diff %.2g (tol 1e-10)'], ...
    lpm, G.lp_mode, d1, d2, dHyp), 'd_mode', d1, 'd_rand', d2);
end


function r = gate1(pbR)
x = pbR.tab.x0;
[ll, out] = hlest.loglik_re(pbR, x);
spec = pbR.spec;
d = hetlearn.load_database(spec);
fr = hetlearn.util.to_dates(spec.filter_range);
rng = fr(1):fr(end);
L1 = loglik(pbR.mo, d, rng, 'relative', false);
Lc = loglik(pbR.mo, d, rng, 'relative', false, 'returnObjFuncContribs', true);
Ls = loglik(pbR.mo, d, rng, 'relative', false, 'objFuncRange', qq(1966, 1):rng(end));
cc = -Lc(:)';
if numel(cc) == numel(out.llt) + 1
    cc = cc(2:end);
end
dFull = abs(sum(out.llt) + L1);
d66 = abs(ll + Ls);
dq = max(abs(cc - out.llt));
rs = RandStream('mt19937ar', 'Seed', 3);
dP = 0;
for k = 1:8
    xk = min(max(x.*(1 + 0.01*randn(rs, size(x))), pbR.lb + 1e-6), pbR.ub - 1e-6);
    llk = hlest.loglik_re(pbR, xk);
    mk = assign(pbR.mo, hlest.theta_struct(pbR, xk));
    [mk, fl] = solve(mk, 'Warning', false);
    assert(hasSucceeded(fl));
    Lk = loglik(mk, d, rng, 'relative', false, 'objFuncRange', qq(1966, 1):rng(end));
    dP = max(dP, abs(llk + Lk));
end
r = struct('pass', max([dFull, d66, dq, dP]) < 1e-6, 'text', sprintf(['own RE KF vs IRIS loglik(relative false): ' ...
    '-loglik 1965Q1- %.10f (diff %.2g), 1966Q1- %.10f (diff %.2g), per quarter %.2g, 8 perturbed thetas %.2g (tol 1e-6)'], ...
    -sum(out.llt), dFull, -ll, d66, dq, dP), 'll_1966', ll, 'll_full', sum(out.llt));
end


function r = gate2(c, pbR, gdir)
G = load(fullfile(gdir, 'g0_dynare.mat'));
[ok, ss] = hlest.solve_orig(pbR, hlest.theta_struct(pbR, pbR.tab.x0));
assert(ok);
mo = pbR.mo;
[T, R, ~, Z, ~, D, ~, Omg] = sspace(mo, 'triangular', false);
T = T(:, :, 1); ne = size(Omg, 1); R = R(:, 1:ne, 1); Z = Z(:, :, 1); D = D(:, 1, 1); Omg = Omg(:, :, 1);
nb = size(T, 2); nf = size(T, 1) - nb;
xv = cellstr(get(mo, 'xVector'));
xbn = xv(nf+1:end);
yl = pbR.yl;
Tb = T(nf+1:end, :); Rb = R(nf+1:end, :);
rn = cellstr(G.restrict_names);
mm = numel(rn);
Td = zeros(mm); Rd = zeros(mm, ne);
bad = 0;
for i = 1:mm
    v = rn{i};
    iy = find(strcmp(yl, v));
    if ~isempty(iy)
        cb = Z(iy, :)*Tb; ce = Z(iy, :)*Rb;
    else
        ix = find(strcmp(xv, v));
        assert(isscalar(ix), 'G2: no current-dated row for %s', v);
        cb = T(ix, :); ce = R(ix, :);
    end
    for j = 1:nb
        jd = find(strcmp(rn, xbn{j}));
        if isempty(jd)
            bad = max(bad, abs(cb(j)));
        else
            Td(i, jd) = Td(i, jd) + cb(j);
        end
    end
    Rd(i, :) = ce;
end
Tt = readtable(fullfile(pbR.spec.folder, 'data', 'sw_ext_1966_latest.csv'), 'TextType', 'string');
varobs = {'dy', 'dc', 'dinve', 'labobs', 'pinfobs', 'dw', 'robs'};
Y = zeros(numel(varobs), height(Tt));
mf = zeros(1, numel(varobs));
for k = 1:numel(varobs)
    Y(k, :) = Tt.(varobs{k})' - D(strcmp(yl, varobs{k}));
    mf(k) = find(strcmp(rn, varobs{k}));
end
QQ = Rd*Omg*Rd';
LIK = dyn_kf(Y, Td, QQ, mf, 10*eye(mm), G.riccati_tol, G.presample);
lpr = hlest.prior_logpdf(pbR.tab, pbR.tab.x0);
lpost = -LIK + lpr;
dynLP = -G.fval;
dd = abs(lpost - dynLP);
r = struct('pass', dd < 1e-6 && bad < 1e-12 && G.lik_init == 2, 'text', sprintf(['own Dynare-style filter (lik_init 2, ' ...
    'presample %d, riccati_tol %g, swX1 data with covid) + own prior = %.10f vs Dynare log posterior %.10f (diff %.2g; ' ...
    '-loglik %.10f; restricted-form residual %.1g; tol 1e-6)'], G.presample, G.riccati_tol, lpost, dynLP, dd, LIK, bad), ...
    'lpost', lpost, 'lik', LIK);
clear ss
end


function LIK = dyn_kf(Y, T, QQ, Zi, P, riccati_tol, presample)
% Dynare 4.6.1 kalman_filter.m (Zflag = 0, H = 0) with the steady-state (riccati) switch.
[pp, smpl] = size(Y);
a = zeros(size(T, 1), 1);
likk = zeros(smpl, 1);
oldK = Inf;
notsteady = true;
t = 1;
while notsteady && t <= smpl
    v = Y(:, t) - a(Zi);
    F = P(Zi, Zi);
    log_dF = log(det(F));
    iF = inv(F);
    likk(t) = log_dF + v'*iF*v;
    Kg = P(:, Zi)*iF;
    Ptmp = T*(P - Kg*P(Zi, :))*T' + QQ;
    a = T*(a + Kg*v);
    P = Ptmp;
    if riccati_tol > 0
        notsteady = max(abs(Kg(:) - oldK)) > riccati_tol;
    end
    oldK = Kg(:);
    t = t + 1;
end
likk(1:t-1) = 0.5*(likk(1:t-1) + pp*log(2*pi));
if t <= smpl
    for s = t:smpl
        v = Y(:, s) - a(Zi);
        likk(s) = 0.5*(log_dF + v'*iF*v + pp*log(2*pi));
        a = T*(a + Kg*v);
    end
end
LIK = sum(likk(1+presample:end));
end


function r = gate3(pbR, pbL)
xc = pbL.tab.x0;
rs = RandStream('mt19937ar', 'Seed', 7);
xp = xc;
xp(1:36) = min(max(xc(1:36).*(1 + 0.01*randn(rs, 36, 1)), pbL.lb(1:36) + 1e-6), pbL.ub(1:36) - 1e-6);
xp(37:39) = [0.03; 0.5; 4];
dmax = 0;
txt = {};
for xx = {xc, xp}
    x = xx{1};
    llRE = hlest.loglik_re(pbR, x(1:36));
    cases = {{'mode', 'rational'}, {'mode', 'fixed_shares', 'fixed_n2', 0}, {'mode', 'switching', 'init_n2', 0}};
    for q = 1:numel(cases)
        pb2 = pbL;
        cs = cases{q};
        for j = 1:2:numel(cs)
            pb2.learn.(cs{j}) = cs{j+1};
        end
        ll = hlest.loglik_learn(pb2, x);
        dmax = max(dmax, abs(ll - llRE));
    end
end
txt{end+1} = sprintf('rational / fixed_n2 = 0 / init_n2 = 0 vs RE KF: max diff %.2g at the calibration and a perturbed theta (tol 1e-8)', dmax);
% building blocks
P = hlest.theta_struct(pbL, xc);
[~, ss] = hlest.solve_orig(pbL, P);
[A, ainfo] = hetlearn.re_anchor_coefficients(pbL.spec, P, 'vars', {'pinf'}, 'states', pbL.info.meta.re_states, ...
    'model', pbL.mo, 'check', true); %#ok<ASGLU>
dA = max([abs(ainfo.k.pinf - ss.k); abs(ainfo.c.pinf - ss.c)]);
[phi0, R0] = hetlearn.init.re_moments(pbL.mL, pbL.info.sys);
[~, o1] = hlest.loglik_learn(pbL, xc);
dM = max([abs(phi0.pinf(:) - o1.phi0(:)); abs(R0.pinf(:) - o1.R0(:))]);
% fast solver at the RE point (n1 = 1 forced through the QZ) vs the original model
PA = P;
an = pbL.anchor_names;
PA.(an{1}) = ss.k;
for j = 1:numel(pbL.xb)
    PA.(an{1 + j}) = ss.c(j);
end
mLt = assign(pbL.mL, PA);
[A0, B0, C0, D0] = system(mLt, 'MatrixFormat', 'plain', 'Normalize', false);
Rd = hlest.reduce_static(pbL.sx, A0, B0, C0, D0);
[Tb, Rb, Kb, fl] = hlest.qz_xb(Rd, 1 - 1e-300, 0, 0);
dS = max([max(abs(Tb(:) - ss.Tb(:))), max(abs(Rb(:) - ss.Rb(:))), max(abs(Kb - ss.Kb))]);
txt{end+1} = sprintf('anchored coefficients vs re_anchor_coefficients %.2g; RE moments vs init.re_moments %.2g; fast RE ALM vs original model %.2g (flag %g; tol 1e-10)', ...
    dA, dM, dS, fl);
r = struct('pass', dmax < 1e-8 && dA < 1e-10 && dM < 1e-10 && dS < 1e-10 && fl == 1, 'text', strjoin(txt, '; '));
end


function r = gate4(pbR, pbL) %#ok<INUSL>
% (a) learning filter vs the engine's inversion history over 1966Q1-2019Q4
xc = pbL.tab.x0;
cfg = a1_learn();
cfg.id = 'est_g4_inversion';
cfg.history.mode = 'inversion';
cfg.forecast.origin = qq(2019, 4);
cfg.forecast.horizon = 1;
cfg.compare_with = {};
res = hetlearn.run(cfg, 'save', false, 'quiet', true);
rng = qq(1966, 1):qq(2019, 4);
i0 = pbL.t0;
i1 = find(abs(pbL.dates - double(qq(2019, 4))) < 1e-6);
idx = i0:i1;
Lg = res.learning.pinf;
eng = struct('alpha', reshape(Lg.alpha_pinf(rng), 1, []), 'beta', reshape(Lg.beta_pinf(rng), 1, []), ...
    'n2', reshape(Lg.n2(rng), 1, []), 'n1m', reshape(Lg.n1_model(rng), 1, []), 'fRE', reshape(Lg.fRE(rng), 1, []), ...
    'fBR', reshape(Lg.fBR(rng), 1, []));
eng.e = zeros(numel(pbL.el), numel(idx));
for j = 1:numel(pbL.el)
    eng.e(j, :) = reshape(res.paths.(pbL.el{j})(rng), 1, []);
end
dE = {};
if ~isempty(res.events)
    keepE = ismember(res.events.type, {'projection_plm', 'projection_alm', 'projection_alm_shares'});
    dE = sort(res.events.date(keepE));
end
dE = dE(:)';
% (a1) exact: start from the engine's state at 1965Q4 (RE-smoothed) with P = 0. With 7 shocks
% for 7 observables and no measurement error the Kalman update is then the inversion.
t65 = qq(1965, 4);
a65 = zeros(numel(pbL.xb), 1);
for j = 1:numel(pbL.xb)
    nm = pbL.xb{j};
    tok = regexp(nm, '^(\w+)\{-(\d+)\}$', 'tokens', 'once');
    if isempty(tok)
        a65(j) = res.paths.(nm)(t65);
    else
        a65(j) = res.paths.(tok{1})(t65 - str2double(tok{2}));
    end
end
st0 = struct('a', a65, 'P', zeros(numel(pbL.xb)));
[~, o1] = hlest.loglik_learn(pbL, xc, 'paths', true, 'start_state', st0);
cmp = @(o) [max(abs(eng.alpha - o.phi(1, idx))), max(abs(eng.beta - o.phi(2, idx))), ...
    max(abs(eng.n2 - (1 - o.n1(idx)))), max(abs(eng.n1m - o.n1m(idx))), max(abs(eng.fRE - o.fRE(idx))), ...
    max(abs(eng.fBR - o.fBR(idx))), max(max(abs(eng.e - o.e(:, idx))))];
d1 = cmp(o1);
dM1 = ev_dates(o1, i0, i1);
passA = max(d1) < 1e-8 && isequal(dE, dM1);
txtA = sprintf(['(a1) engine inversion 1966Q1-2019Q4 vs learning filter started from the engine''s 1965Q4 state ' ...
    'with P = 0: max diff alpha %.1e beta %.1e n2 %.1e n1_model %.1e fRE %.1e fBR %.1e shocks %.1e (tol 1e-8); ' ...
    'events engine {%s} filter {%s}'], d1, strjoin(dE, ','), strjoin(dM1, ','));
% (a2) information: the estimation's stochastic start. P_{t|t} does not collapse (dy, dc, dinve,
% dw are first differences of stationary model variables: unit MA roots), so the filtered
% states do not converge to the inversion, which carries its initial condition forever.
[~, o2] = hlest.loglik_learn(pbL, xc, 'paths', true);
yr = floor((idx - 1)/4) + 1965;
edges = [1966 1970 1980 1990 2000 2010 2020];
dec = zeros(3, numel(edges) - 1);
for k = 1:numel(edges) - 1
    s = yr >= edges(k) & yr < edges(k + 1);
    dec(:, k) = [max(abs(eng.n2(s) - (1 - o2.n1(idx(s))))); max(abs(eng.fRE(s) - o2.fRE(idx(s)))); ...
        max(max(abs(eng.e(:, s) - o2.e(:, idx(s)))))];
end
txtA2 = sprintf(['(a2, information) stochastic start: beliefs max diff %.1e; max diff by decade 1966/70s/80s/90s/00s/10s ' ...
    'n2 %s fRE %s shocks %s; max diag P_{t|t} at 2019Q4 %.3g (no collapse)'], ...
    max([abs(eng.alpha - o2.phi(1, idx)), abs(eng.beta - o2.phi(2, idx))]), sprintf('%.1e ', dec(1, :)), ...
    sprintf('%.1e ', dec(2, :)), sprintf('%.1e ', dec(3, :)), o2.Pmax(i1));
% (b) lean recursion vs update_learning fed with the filter's path
[db1, ~, t1] = gate4b(pbL, xc);
xh = xc;
xh(37:39) = [0.15; 0.5; 5];
[db2, ~, t2] = gate4b(pbL, xh);
% a point with ALM reverts or kept shares (prior draws)
rs = RandStream('mt19937ar', 'Seed', 31);
xa = [];
for k = 1:200
    x = hlest.prior_draw(pbL.tab, rs, 1);
    [ll, o] = hlest.loglik_learn(pbL, x);
    if isfinite(ll) && (o.ev_alm + o.ev_keep) > 0
        xa = x;
        break
    end
end
if isempty(xa)
    db3 = NaN; t3 = 'no prior draw with ALM events in 200';
else
    [db3, ~, t3] = gate4b(pbL, xa);
end
passB = db1 < 1e-12 && db2 < 1e-12 && (isnan(db3) || db3 < 1e-12);
txtB = sprintf(['(b) lean recursion vs hetlearn.engine.update_learning on the filtered path 1966Q1-2026Q2: max diff ' ...
    '%.1e (calibration; events %s), %.1e (gain 0.15, omega 0.5, chi 5; events %s), %.1e (prior draw with ALM events; ' ...
    'events %s) (tol 1e-12; event codes 1 plm, 2 alm revert, 3 kept shares)'], db1, t1, db2, t2, db3, t3);
r = struct('pass', passA && passB, 'text', [txtA '; ' txtA2 '; ' txtB], 'd_exact', d1, 'dec', dec);
end


function c = ev_dates(o, i0, i1)
c = {};
for q = 1:size(o.events, 2)
    tq = o.events(1, q);
    if tq >= i0 && tq <= i1 && o.events(2, q) <= 3
        c{end+1} = char(dat2str(qq(1965, 1) + tq - 1)); %#ok<AGROW>
    end
end
c = sort(c);
c = c(:)';
end


function [dmax, nev, txt] = gate4b(pbL, th)
[~, out] = hlest.loglik_learn(pbL, th, 'paths', true);
assert(strcmp(out.status, 'ok'), 'G4b: likelihood failed (%s)', out.status);
o = pbL.opts;
o.gain.value = th(pbL.ig);
o.switching.memory = th(pbL.iom);
o.switching.intensity = th(pbL.ichi);
P = hlest.theta_struct(pbL, th);
[~, ss] = hlest.solve_orig(pbL, P);
PA = P;
an = pbL.anchor_names;
PA.(an{1}) = ss.k;
for j = 1:numel(pbL.xb)
    PA.(an{1 + j}) = ss.c(j);
end
mA = assign(pbL.mL, PA);
[mA, fl] = solve(mA, 'Warning', false);
assert(hasSucceeded(fl));
u = userdata(mA);
if ~isstruct(u), u = struct(); end
u.hetlearn_step = 'iris';
if isfield(u, 'hetlearn_sspace'), u = rmfield(u, 'hetlearn_sspace'); end
mA = userdata(mA, u);
ctx = struct('opts', o, 'sys', pbL.info.sys, 'learnVars', {pbL.info.learnVars}, 'spec', pbL.spec, 'info', pbL.info);
ctx.blocks = hetlearn.plm.blocks(ctx.sys);
[S, ctx] = hetlearn.engine.state_init(ctx, mA, []);
dmax = max([abs(S.phi.pinf(:) - out.phi0(:)); abs(S.R.pinf(:) - out.R0(:))]);
pin = out.pinf;
mH = mA;
codes = {'projection_plm', 'projection_alm', 'projection_alm_shares', 'shares_nan'};
evE = zeros(2, 0);
for t = pbL.t0:pbL.nT
    getVal = @(name, k) pin(t + k);
    fRE = struct('pinf', out.fRE(t));
    fBR = struct('pinf', out.fBR(t));
    A = struct('m', mH, 'stage', 'history');
    tD = qq(1965, 1) + (t - 1);
    [S, o2, e] = hetlearn.engine.update_learning(ctx, S, tD, getVal, fRE, fBR, t == pbL.t0, A);
    if ~isempty(o2.alm) && o2.alm.checked
        mH = o2.alm.m;
    end
    for q = 1:numel(e)
        cq = find(strcmp(codes, e(q).type));
        if ~isempty(cq)
            evE(:, end+1) = [t; cq]; %#ok<AGROW>
        end
    end
    n1next = hetlearn.engine.shares_for_mode(ctx, S);
    dd = [abs(S.phi.pinf(:) - out.phi(:, t)); abs(diag(S.R.pinf) - out.Rdiag(:, t)); abs(S.n1 - out.n1(t)); ...
        abs(S.zetaRE - out.zRE(t)); abs(S.zetaBR - out.zBR(t))];
    if t < pbL.nT
        dd = [dd; abs(n1next.pinf - out.n1m(t + 1))]; %#ok<AGROW>
    end
    dd(~isfinite(dd) & isinf(S.zetaBR)) = 0;
    dmax = max([dmax; dd]);
end
if ~isequal(evE, out.events)
    dmax = Inf;
end
nev = size(evE, 2);
txt = sprintf('%d.%d;', evE);
end


function r = gate5(pbL)
rs = RandStream('mt19937ar', 'Seed', 11);
pts = {pbL.tab.x0};
nTry = 0;
while numel(pts) < 21 && nTry < 400
    nTry = nTry + 1;
    x = hlest.prior_draw(pbL.tab, rs, 1);
    ll = hlest.loglik_learn(pbL, x);
    if isfinite(ll)
        pts{end+1} = x; %#ok<AGROW>
    end
end
agg = struct('n', 0, 'mismatch', 0, 'dT', 0, 'dR', 0, 'dK', 0, 'n_cmp', 0, 'n_unstable', 0);
for k = 1:numel(pts)
    [~, o] = hlest.loglik_learn(pbL, pts{k}, 'check_iris', true);
    agg = add_g5(agg, o.g5);
end
pbC = hlest.problem('learn', 'info', 'current');
ptsC = {pbC.tab.x0};
nTryC = 0;
while numel(ptsC) < 6 && nTryC < 200
    nTryC = nTryC + 1;
    x = hlest.prior_draw(pbC.tab, rs, 1);
    if isfinite(hlest.loglik_learn(pbC, x))
        ptsC{end+1} = x; %#ok<AGROW>
    end
end
aggC = struct('n', 0, 'mismatch', 0, 'dT', 0, 'dR', 0, 'dK', 0, 'n_cmp', 0, 'n_unstable', 0);
for k = 1:numel(ptsC)
    [~, o] = hlest.loglik_learn(pbC, ptsC{k}, 'check_iris', true);
    aggC = add_g5(aggC, o.g5);
end
mx = max([agg.dT, agg.dR, agg.dK, aggC.dT, aggC.dR, aggC.dK]);
r = struct('pass', mx < 1e-9 && agg.mismatch == 0 && aggC.mismatch == 0 && numel(pts) == 21 && numel(ptsC) == 6, ...
    'text', sprintf(['fast solver (static elimination 57 -> %d) vs IRIS solve: lagged, calibration + %d prior draws ' ...
    '(%d tried): %d solves, %d IRIS-unstable, verdict mismatches %d, max diff T %.2g R %.2g K %.2g; current, ' ...
    'calibration + %d draws: %d solves, mismatches %d, T %.2g R %.2g K %.2g (tol 1e-9)'], numel(pbL.sx.keepc), ...
    numel(pts) - 1, nTry, agg.n, agg.n_unstable, agg.mismatch, agg.dT, agg.dR, agg.dK, numel(ptsC) - 1, aggC.n, ...
    aggC.mismatch, aggC.dT, aggC.dR, aggC.dK), 'agg', agg, 'aggC', aggC);
end


function a = add_g5(a, g)
a.n = a.n + g.n;
a.mismatch = a.mismatch + g.mismatch;
a.n_cmp = a.n_cmp + g.n_cmp;
a.n_unstable = a.n_unstable + g.n_unstable;
a.dT = max(a.dT, g.dT);
a.dR = max(a.dR, g.dR);
a.dK = max(a.dK, g.dK);
end


function r = gate6()
d = 39;
rs = RandStream('mt19937ar', 'Seed', 21);
sd = exp(randn(rs, d, 1));
Q = orth(randn(rs, d));
lam = exp(0.8*randn(rs, d, 1));
Cm = Q*diag(lam)*Q';
Cm = Cm./sqrt(diag(Cm)*diag(Cm)');
Sg = diag(sd)*Cm*diag(sd);
Sg = (Sg + Sg')/2;
mu = randn(rs, d, 1);
Rc = chol(Sg);
lz = 0.5*d*log(2*pi) + sum(log(diag(Rc)));          % exact log normaliser
lpf = @(x) -0.5*sum(((x - mu)'/Rc).^2);
% Laplace through the production Hessian code
f = @(x) deal(-lpf(x), '');
[H, hinfo] = hlest.hessian_fd('full', f, mu, 0.1*sd, mu - 100*sd, mu + 100*sd);
lapl = hlest.mdd_laplace(lpf(mu), H);
dLap = abs(lapl - lz);
% RWMH: 4 chains, proposal = target covariance, scale 2.38/sqrt(d)
target = @(x) tgt(x, lpf);
L = chol(Sg, 'lower');
nC = 4;
nPer = 2000000;
thin = 20;
keep = nPer/2/thin;
X = zeros(keep, nC, d);
LPk = zeros(keep, nC);
acc = zeros(1, nC);
for ch = 1:nC
    rsc = RandStream('mt19937ar', 'Seed', 100 + ch);
    x0 = mu + 2*L*randn(rsc, d, 1);
    st = struct('x', x0, 'lp', lpf(x0), 'll', 0, 'ev', [], 'paths', [], 'n_done', 0);
    kk = 0;
    for b = 1:nPer/100000
        [B, st] = hlest.rwmh_core(target, st, L, 2.38/sqrt(d), 100000, rsc, thin, false);
        acc(ch) = acc(ch) + nnz(B.acc);
        if b > nPer/200000
            sel = thin:thin:100000;
            X(kk+1:kk+numel(sel), ch, :) = reshape(B.draws(sel, :), numel(sel), 1, d);
            LPk(kk+1:kk+numel(sel), ch) = B.lp(sel);
            kk = kk + numel(sel);
        end
    end
end
acc = acc/nPer;
Dg = hlest.diagnostics(X);
Xp = reshape(permute(X, [1 2 3]), [], d);
eMean = max(abs(mean(Xp, 1)' - mu)./sd);
eSd = max(abs(std(Xp, 0, 1)'./sd - 1));
mhm = hlest.mdd_mhm(Xp, LPk(:));
dMhm = max(abs(mhm - lz));
pass = dLap < 1e-8 && eMean < 0.02 && eSd < 0.02 && max(Dg.rhat) < 1.01 && dMhm < 0.05;
r = struct('pass', pass, 'text', sprintf(['39-dim Gaussian: Laplace %.10f vs exact %.10f (diff %.2g, tol 1e-8; Hessian PD %d); ' ...
    'RWMH 4 x %d draws (acceptance %.3f), post burn-in thinned by %d: max |mean error|/sd %.4f, max |sd ratio - 1| %.4f ' ...
    '(tol 0.02), max split R-hat %.4f (tol 1.01), min bulk ESS %.0f; MHM p = 0.1..0.9 max diff %.4f (tol 0.05)'], ...
    lapl, lz, dLap, hinfo.pd, nPer, mean(acc), thin, eMean, eSd, max(Dg.rhat), min(Dg.ess_bulk), dMhm), ...
    'rhat', Dg.rhat, 'ess', Dg.ess_bulk, 'mhm', mhm, 'lz', lz);
end


function [lp, ll, ex] = tgt(x, lpf)
lp = lpf(x);
ll = 0;
ex = struct('ev', [], 'paths', []);
end


function P0 = sw07_params_from(c)
folder = fullfile(c.toolbox_root, 'models', 'sw07');
addpath(folder);
P0 = sw07_params();
rmpath(folder);
end
