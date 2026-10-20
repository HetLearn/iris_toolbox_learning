function R = est_00_gates_live(root, gates)
%EST_00_GATES_LIVE  Gates G3, G4, a reduced G5 and the mode values against a copy of the hetlearn toolbox.
%
%   R = est_00_gates_live()               % root = the project folder, i.e. the live toolbox/
%   R = est_00_gates_live(root)           % any folder with setup_paths.m, toolbox/, config/, scenarios/, models/sw07
%   R = est_00_gates_live(root, {'L0', 'L1'})   % a subset of the gates (default: all five)
%
%   Checks that the estimator works with the toolbox in root. Since 2026-10-20 est_config.m
%   points at the live toolbox (c.project), so the default root is also the configured one; the
%   modes, Hessians and chains of 2026-10-19/20 were computed against a frozen snapshot that has
%   been retired. Run it in a fresh MATLAB process: it puts <root>/setup_paths on the path
%   itself and refuses to run if hetlearn already comes from somewhere else.
%   Gates (G3 and G4: the code of est_00_gates, copied verbatim; est_00_gates.m could not be
%   edited while the learning chains ran):
%     G3   learning filter in its RE special cases = RE filter; anchored coefficients, RE moments
%          and the fast RE ALM vs the toolbox functions (1e-8 / 1e-10)
%     G4   (a1) learning filter started from the engine's 1965Q4 state with P = 0 = the engine's
%          inversion history 1966Q1-2019Q4 (1e-8; the degenerate-start test of 2026-10-19 23:48),
%          (a2) information, (b) the lean recursion = hetlearn.engine.update_learning (1e-12)
%     G5r  fast solver = IRIS solve in every quarter at the calibration and 5 prior draws, for
%          'lagged' and 'current' (1e-9)
%     L0   log likelihoods at the RE and learning modes = the values stored in mode.mat (1e-8)
%     L1   log posteriors and log likelihoods at the four modes (re, learn, learn_current,
%          learn_calib, each under its own problem) = the values stored in their mode.mat (1e-8)
%   Appends "# live toolbox check <date> (toolbox root <root>; ...)" and one line per gate to
%   results/estimation/gates.txt; details in results/estimation/gates/live_<gate>.mat.

c = est_config();
if nargin < 1 || isempty(root)
    root = c.project;
end
if nargin < 2 || isempty(gates)
    gates = {'G3', 'G4', 'G5r', 'L0', 'L1'};
end
root = char(root);
w = which('hetlearn.load_model');
if ~isempty(w) && ~strncmpi(w, root, numel(root))
    error('est_00_gates_live:path', 'hetlearn is already on the path from %s; start a fresh MATLAB process.', w);
end
if isempty(w)
    old = cd(root);
    back = onCleanup(@() cd(old));
    setup_paths();
    clear back
end
w = which('hetlearn.load_model');
if ~strncmpi(w, root, numel(root))
    error('est_00_gates_live:path', 'hetlearn is taken from %s, not from %s.', w, root);
end
addpath(c.est_dir);
maxNumCompThreads(c.threads);
gdir = fullfile(c.results, 'gates');
fprintf('est_00_gates_live: toolbox %s\n', fileparts(fileparts(w)));
pbR = hlest.problem('re');
pbL = hlest.problem('learn');
lines = {};
R = struct();
G = cellstr(gates);
for k = 1:numel(G)
    g = G{k};
    t0 = tic;
    try
        switch g
            case 'G3', r = gate3(pbR, pbL);
            case 'G4', r = gate4(pbR, pbL);
            case 'G5r', r = gate5r(pbL, 5);
            case 'L0', r = gate_l0(c, pbR, pbL);
            case 'L1', r = gate_l1(c, pbR, pbL);
            otherwise, error('est_00_gates_live:gate', 'Unknown gate %s.', g);
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
    save(fullfile(gdir, sprintf('live_%s.mat', g)), 'r');
end
allPass = all(cellfun(@(g) R.(g).pass, G));
fid = fopen(fullfile(c.results, 'gates.txt'), 'a');
if isequal(G, {'G3', 'G4', 'G5r', 'L0'})
    what = 'G3, G4 degenerate-start, G5 reduced to the calibration + 5 prior draws';
else
    what = ['gates ' strjoin(G, ', ') '; G4 degenerate-start, G5 reduced to the calibration + 5 prior draws, ' ...
        'L1 log posteriors at the four modes'];
end
cfgNote = '';
if strcmpi(c.toolbox_root, root)
    cfgNote = '; est_config toolbox_root = this root';
end
fprintf(fid, '\n# live toolbox check %s (toolbox root %s; est_00_gates_live; %s%s)\n', ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), root, what, cfgNote); %#ok<TNOW1,DATST>
fprintf(fid, '%s\n', lines{:});
if allPass
    fprintf(fid, '# live toolbox check: all pass; the estimator works with this toolbox unchanged\n');
else
    fprintf(fid, '# live toolbox check: NOT all pass; see the lines above\n');
end
fclose(fid);
end


function r = gate5r(pbL, nDraw)
% G5 reduced: the calibration and nDraw prior draws with a finite likelihood, for each timing.
rs = RandStream('mt19937ar', 'Seed', 11);
txt = {};
pass = true;
for info = {'lagged', 'current'}
    if strcmp(info{1}, 'lagged')
        pb = pbL;
    else
        pb = hlest.problem('learn', 'info', 'current');
    end
    pts = {pb.tab.x0};
    nTry = 0;
    while numel(pts) < 1 + nDraw && nTry < 200
        nTry = nTry + 1;
        x = hlest.prior_draw(pb.tab, rs, 1);
        if isfinite(hlest.loglik_learn(pb, x))
            pts{end+1} = x; %#ok<AGROW>
        end
    end
    agg = struct('n', 0, 'mismatch', 0, 'dT', 0, 'dR', 0, 'dK', 0, 'n_cmp', 0, 'n_unstable', 0);
    for k = 1:numel(pts)
        [~, o] = hlest.loglik_learn(pb, pts{k}, 'check_iris', true);
        agg = add_g5(agg, o.g5);
    end
    mx = max([agg.dT, agg.dR, agg.dK]);
    pass = pass && mx < 1e-9 && agg.mismatch == 0 && numel(pts) == 1 + nDraw;
    txt{end+1} = sprintf(['%s, calibration + %d prior draws (%d tried): %d solves, %d IRIS-unstable, verdict ' ...
        'mismatches %d, max diff T %.2g R %.2g K %.2g'], info{1}, numel(pts) - 1, nTry, agg.n, agg.n_unstable, ...
        agg.mismatch, agg.dT, agg.dR, agg.dK); %#ok<AGROW>
end
r = struct('pass', pass, 'text', ['fast solver (static elimination 57 -> ' sprintf('%d', numel(pbL.sx.keepc)) ...
    ') vs IRIS solve: ' strjoin(txt, '; ') ' (tol 1e-9)']);
end


function r = gate_l0(c, pbR, pbL)
% Log likelihoods at the two modes with this toolbox = the values stored by the estimation runs.
MR = load(fullfile(c.results, 're', 'mode.mat'));
ML = load(fullfile(c.results, 'learn', 'mode.mat'));
llR = hlest.loglik_re(pbR, MR.xm);
[llL, oL] = hlest.loglik_learn(pbL, ML.xm);
dR = abs(llR - MR.ll);
dL = abs(llL - ML.ll);
r = struct('pass', dR < 1e-8 && dL < 1e-8 && strcmp(oL.sig, ML.out.sig), 'text', sprintf(['log likelihood at the ' ...
    'RE mode %.10f (stored %.10f, diff %.2g), at the learning mode %.10f (stored %.10f, diff %.2g), facility events ' ...
    '%s (stored %s) (tol 1e-8)'], llR, MR.ll, dR, llL, ML.ll, dL, oL.sig, ML.out.sig));
end


function r = gate_l1(c, pbR, pbL)
% Log posteriors (and likelihoods) at the four modes with this toolbox = the stored values.
cases = {'re', pbR; 'learn', pbL; 'learn_current', hlest.problem('learn', 'info', 'current'); ...
    'learn_calib', hlest.problem('learn', 'priors', 'calib')};
txt = cell(1, size(cases, 1));
pass = true;
dmax = 0;
for k = 1:size(cases, 1)
    M = load(fullfile(c.results, cases{k, 1}, 'mode.mat'), 'xm', 'lp', 'll');
    [lp, ll] = hlest.logpost(cases{k, 2}, M.xm);
    dp = abs(lp - M.lp);
    dl = abs(ll - M.ll);
    dmax = max([dmax, dp, dl]);
    pass = pass && dp < 1e-8 && dl < 1e-8;
    txt{k} = sprintf('%s %.10f (stored %.10f, diff %.2g; likelihood diff %.2g)', cases{k, 1}, lp, M.lp, dp, dl);
end
r = struct('pass', pass, 'text', sprintf('log posterior at the modes: %s (tol 1e-8)', strjoin(txt, '; ')), 'dmax', dmax);
end


% ---- copied verbatim from est_00_gates.m (2026-10-19) ----------------------------------


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


function a = add_g5(a, g)
a.n = a.n + g.n;
a.mismatch = a.mismatch + g.mismatch;
a.n_cmp = a.n_cmp + g.n_cmp;
a.n_unstable = a.n_unstable + g.n_unstable;
a.dT = max(a.dT, g.dT);
a.dR = max(a.dR, g.dR);
a.dK = max(a.dK, g.dK);
end
