function R = test_gain(part)
%TEST_GAIN  Endogenous gain gain.rule = 'koz' (KOZ 2024 eq. 9; DESIGN 18) and the gain-rule interface.
%
%   R = test_gain()          all checks
%   R = test_gain('unit')    G1-G6 (no model)
%   R = test_gain('toy')     G7-G13 (toy NK runs)
%   R = test_gain('sw07')    G14-G15 (SW07 runs into tests/output/results/)
%
%   G1  the recursion equals a hand-coded loop on a known error sequence:
%       gain used in t = gamma_{t-1}; gamma_t = gamma_{t-1} + mu Rg_{t-1} FE_t;
%       Rg_t = (1 - gamma_{t-1}) Rg_{t-1} + FE_t; error_scale multiplies FE
%   G2  mu = 0: the gain stays at gamma_0 bit for bit
%   G3  bounds hold and every binding period logs a 'gain_bound' event
%   G4  persistent same-sign errors raise the gain, alternating errors lower it
%   G5  'common' (master default, a master list = mean of the scaled errors) vs
%       'per_variable' (own errors, auxiliary equations own processes);
%       'forecast' errors for learning variables, residuals for auxiliary ones;
%       a missing error leaves the state unchanged; bad masters are errors
%   G6  load_options: defaults, enumerations, mu >= 0, bounds in (0, 1],
%       gamma0 and the resolved gain.value inside the bounds, master names
%   G7  toy end-to-end: mu = 0 equals the constant rule bit for bit ('common'
%       and 'per_variable'); constant runs record no gain_R
%   G8  toy switching (y, pie), error 'rls', beliefs.info 'current': FE_t
%       implied by the record (gain, gain_R) = y_t - (alpha_{t-1} + beta_{t-1}
%       y_{t-1}) over history and forecast; gamma_t recursion; one common gain;
%       learning.csv carries gain and gain_R; timing assert held (run completes)
%   G9  error 'forecast': implied FE_t = x_t - fBR_{t-1} (lagged: two-step);
%       under 'current' = x_t - (alpha_{t-2} + beta_{t-2} x_{t-1}), not the
%       'rls' residual
%   G10 per_variable on the toy with an auxiliary PLM (pinf on its lag and
%       r{-1}): each equation its own gain, the auxiliary one driven by its own
%       residual; 'common' gives the auxiliary equation the master's gain
%   G11 inversion history and hetlearn.evaluate: forecasts from the stored
%       states (gain state included) = direct runs at each origin, both history
%       modes
%   G12 density draws restart from the origin state: each kept draw = a direct
%       run with that draw's shocks added
%   G13 Ramsey (commitment), switching, KOZ gain: loss over a continuation from
%       res.state = loss of the longer forecast
%   G14 SW07: 'constant' unchanged: tsw07_switch_pinf with engine.step =
%       'iris' = tests/reference/tsw07_switch_pinf_iris.mat (max diff 0), 'fast' to 1e-10
%   G15 SW07 smoke: tsw07_switch_pinf with gain.rule = 'koz' (defaults)

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
outDir = fullfile(here, 'output', 'results');
if any(strcmp(part, {'all', 'unit'}))
    R = unit_checks(R);
end
if any(strcmp(part, {'all', 'toy'}))
    R = toy_checks(R, here, outDir);
end
if any(strcmp(part, {'all', 'sw07'}))
    R = sw07_checks(R, here, root, outDir);
end
end


% =========================================================================
function R = unit_checks(R)
sys = struct('eq', struct('target', {'a', 'b', 'c'}, 'isAux', {false, false, true}));
lv = {'a', 'b'};
e1 = [0.5 -0.2 0.3 0.4 -0.1 0.6 0.7 -0.3 0.2 0.1]';

% ---- G1 ----
nm = 'gain G1: KOZ recursion = hand-coded loop (gain used in t = gamma_{t-1}, gamma_t, Rg_t)';
try
    k = struct('mu', 0.01, 'gamma0', 0.05, 'Rg0', 0.2, 'bounds', [1e-6 1], 'master', 'a');
    [u, gm, rg] = drive(kopts(k), sys, lv, [e1, 0 * e1, 0 * e1], NaN(10, 2));
    [hu, hg, hr] = hand(e1, 0.01, 0.05, 0.2, 1e-6, 1);
    d = max(abs([u(:, 1) - hu; gm(:, 1) - hg; rg(:, 1) - hr]));
    R = add(R, nm, d == 0 && u(1, 1) == 0.05 && all(u(2:end, 1) == hg(1:end-1)), ...
        sprintf('max diff %.2g; gamma_10 %.6f, Rg_10 %.6f', d, gm(end, 1), rg(end, 1)));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'gain G1: error_scale multiplies FE_t in both updates (scale 4 = hand loop on 4*FE)';
try
    k = struct('mu', 0.01, 'gamma0', 0.05, 'Rg0', 0, 'bounds', [1e-6 1], 'master', 'a', 'error_scale', 4);
    [u, gm, rg] = drive(kopts(k), sys, lv, [e1, 0 * e1, 0 * e1], NaN(10, 2));
    [hu, hg, hr] = hand(4 * e1, 0.01, 0.05, 0, 1e-6, 1);
    d = max(abs([u(:, 1) - hu; gm(:, 1) - hg; rg(:, 1) - hr]));
    R = add(R, nm, d == 0, sprintf('max diff %.2g; gamma_10 %.6f', d, gm(end, 1)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G2 ----
nm = 'gain G2: mu = 0 keeps gamma at gamma_0 bit for bit (Rg still updated)';
try
    k = struct('mu', 0, 'Rg0', 0.3, 'master', 'a');
    [u, gm, rg] = drive(kopts(k), sys, lv, [e1, e1, e1], NaN(10, 2));
    R = add(R, nm, all(u(:) == 0.0585) && all(gm(:) == 0.0585) && rg(end, 1) ~= 0.3, ...
        sprintf('gains used %s; Rg_10 %.6f', mat2str(unique(u(:))'), rg(end, 1)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G3 ----
nm = 'gain G3: bounds [0.04, 0.06] hold; one gain_bound event per binding period (= hand loop)';
try
    T = 12;
    eUp = ones(T, 1);
    eAlt = (-1) .^ (1:T)';
    k = struct('mu', 1, 'gamma0', 0.05, 'bounds', [0.04 0.06], 'master', 'a');
    [~, gU, ~, nU, tU] = drive(kopts(k), sys, lv, [eUp, eUp, eUp], NaN(T, 2));
    [~, hgU, ~, nbU] = hand(eUp, 1, 0.05, 0, 0.04, 0.06);
    [~, gA, ~, nA, tA] = drive(kopts(k), sys, lv, [eAlt, eAlt, eAlt], NaN(T, 2));
    [~, hgA, ~, nbA] = hand(eAlt, 1, 0.05, 0, 0.04, 0.06);
    ok = all(gU(:) >= 0.04 & gU(:) <= 0.06) && all(gA(:) >= 0.04 & gA(:) <= 0.06) ...
        && max(abs(gU(:, 1) - hgU)) == 0 && max(abs(gA(:, 1) - hgA)) == 0 ...
        && nU == nbU && nA == nbA && nU > 0 && nA > 0 && all(strcmp([tU, tA], 'gain_bound')) ...
        && any(gU(:, 1) == 0.06) && any(gA(:, 1) == 0.04);
    R = add(R, nm, ok, sprintf('same-sign: %d events (hand %d), max gamma %.4g; alternating: %d events (hand %d), min gamma %.4g', ...
        nU, nbU, max(gU(:, 1)), nA, nbA, min(gA(:, 1))));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G4 ----
nm = 'gain G4: persistent same-sign errors raise the gain (monotone), alternating errors lower it';
try
    T = 40;
    k = struct('mu', 0.001, 'master', 'a');
    [~, gU] = drive(kopts(k), sys, lv, repmat(ones(T, 1), 1, 3), NaN(T, 2));
    [~, gN] = drive(kopts(k), sys, lv, repmat(-ones(T, 1), 1, 3), NaN(T, 2));
    [~, gA] = drive(kopts(k), sys, lv, repmat((-1) .^ (1:T)', 1, 3), NaN(T, 2));
    ok = all(diff(gU(:, 1)) >= 0) && gU(end, 1) > 0.0585 && all(diff(gN(:, 1)) >= 0) && gN(end, 1) > 0.0585 ...
        && gA(end, 1) < 0.0585 && all(diff(gA(2:end, 1)) <= 0);
    R = add(R, nm, ok, sprintf('after %d periods: +1 errors %.5f, -1 errors %.5f, alternating %.5f (gamma_0 0.0585)', ...
        T, gU(end, 1), gN(end, 1), gA(end, 1)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G5 ----
rng(3);
T = 15;
E = 0.5 * randn(T, 3);
F = 0.7 * randn(T, 2);
F(1, :) = NaN;
base = struct('mu', 0.02, 'Rg0', 0, 'bounds', [1e-6 1], 'error_scale', 2);
nm = 'gain G5: common, master default = first learning variable: one gain for a, b and auxiliary c';
try
    [u, gm] = drive(kopts(base), sys, lv, E, F);
    [~, hg] = hand(2 * E(:, 1), 0.02, 0.0585, 0, 1e-6, 1);
    d = max(abs(gm(:, 1) - hg));
    R = add(R, nm, d == 0 && all(all(u == u(:, 1))) && all(all(gm == gm(:, 1))), sprintf('max diff %.2g', d));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'gain G5: common, master {''a'', ''b''} = mean of the scaled errors';
try
    k = base;
    k.master = {'a', 'b'};
    [~, gm] = drive(kopts(k), sys, lv, E, F);
    [~, hg] = hand(mean([2 * E(:, 1), 2 * E(:, 2)], 2), 0.02, 0.0585, 0, 1e-6, 1);
    d = max(abs(gm(:, 1) - hg));
    R = add(R, nm, d == 0, sprintf('max diff %.2g', d));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'gain G5: per_variable: each equation (auxiliary c included) driven by its own residual';
try
    k = base;
    k.structure = 'per_variable';
    [~, gm, rg] = drive(kopts(k), sys, lv, E, F);
    d = 0;
    for i = 1:3
        [~, hg, hr] = hand(2 * E(:, i), 0.02, 0.0585, 0, 1e-6, 1);
        d = max([d; abs(gm(:, i) - hg); abs(rg(:, i) - hr)]);
    end
    R = add(R, nm, d == 0 && numel(unique(gm(end, :))) == 3, sprintf('max diff %.2g; gamma_T a/b/c %s', ...
        d, mat2str(gm(end, :), 5)));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'gain G5: error ''forecast'': learning variables use x_t - f^BR_{t-1} (NaN first: no update), auxiliary c its residual';
try
    k = base;
    k.structure = 'per_variable';
    k.error = 'forecast';
    [~, gm] = drive(kopts(k), sys, lv, E, F);
    [~, ha] = hand(2 * F(:, 1), 0.02, 0.0585, 0, 1e-6, 1);
    [~, hb] = hand(2 * F(:, 2), 0.02, 0.0585, 0, 1e-6, 1);
    [~, hc] = hand(2 * E(:, 3), 0.02, 0.0585, 0, 1e-6, 1);
    d = max(abs([gm(:, 1) - ha; gm(:, 2) - hb; gm(:, 3) - hc]));
    R = add(R, nm, d == 0 && gm(1, 1) == 0.0585 && gm(1, 3) == 0.0585, sprintf('max diff %.2g', d));
catch err
    R = add(R, nm, false, err.message);
end
k = base;
k.error = 'forecast';
k.master = 'c';
R = expect_error(R, 'gain G5: common with error ''forecast'' and an auxiliary master is an error', 'hetlearn:gain:master', ...
    @() hetlearn.gain.koz('init', sys, lv, kopts(k)));
k = base;
k.master = 'zz';
R = expect_error(R, 'gain G5: common with a master that is no PLM target is an error', 'hetlearn:gain:master', ...
    @() hetlearn.gain.koz('init', sys, lv, kopts(k)));

% ---- G6 ----
nm = 'gain G6: defaults mu 0.001, gamma0 [], Rg0 0, bounds [0.001 0.25], rls, scale 1, common, master {}';
try
    o = hetlearn.load_options(struct('id', 'x'), struct());
    q = o.gain.koz;
    ok = q.mu == 0.001 && isempty(q.gamma0) && q.Rg0 == 0 && isequal(q.bounds, [0.001 0.25]) ...
        && strcmp(q.error, 'rls') && q.error_scale == 1 && strcmp(q.structure, 'common') ...
        && iscell(q.master) && isempty(q.master) && strcmp(o.gain.rule, 'constant');
    o2 = hetlearn.load_options(struct('id', 'x', 'gain', struct('rule', 'koz', 'koz', struct('master', 'pinf', 'mu', 0))), struct());
    ok = ok && isequal(o2.gain.koz.master, {'pinf'}) && o2.gain.koz.mu == 0;
    o3 = hetlearn.load_options(struct('id', 'x', 'gain', struct('value', 0.5)), struct());   % constant: bounds not applied
    ok = ok && o3.gain.value == 0.5;
    R = add(R, nm, ok, 'master ''pinf'' -> {''pinf''}; mu = 0 accepted; constant rule ignores the bounds');
catch err
    R = add(R, nm, false, err.message);
end
bad = {
    'structure ''joint''', struct('structure', 'joint')
    'error ''squared''', struct('error', 'squared')
    'mu -0.1', struct('mu', -0.1)
    'mu Inf', struct('mu', Inf)
    'bounds [0 0.5]', struct('bounds', [0 0.5])
    'bounds [0.3 0.2]', struct('bounds', [0.3 0.2])
    'bounds [0.1 1.5]', struct('bounds', [0.1 1.5])
    'bounds scalar', struct('bounds', 0.1)
    'gamma0 0.3 outside [0.001 0.25]', struct('gamma0', 0.3)
    'error_scale 0', struct('error_scale', 0)
    'master ''1x''', struct('master', '1x')
    };
for i = 1:size(bad, 1)
    c = struct('id', 'x', 'gain', struct('rule', 'koz', 'koz', bad{i, 2}));
    R = expect_error(R, sprintf('gain G6: load_options rejects gain.koz.%s', bad{i, 1}), 'hetlearn:options', ...
        @() hetlearn.load_options(c, struct()));
end
R = expect_error(R, 'gain G6: gain.rule = ''koz'' rejects gain.value 0.5 outside the bounds', 'hetlearn:options', ...
    @() hetlearn.load_options(struct('id', 'x', 'gain', struct('rule', 'koz', 'value', 0.5)), struct()));
R = expect_error(R, 'gain G6: per_variable rejects a gain.by_var value outside the bounds', 'hetlearn:options', ...
    @() hetlearn.load_options(struct('id', 'x', 'gain', struct('rule', 'koz', 'by_var', struct('pinf', 0.4), ...
    'koz', struct('structure', 'per_variable'))), struct()));
end


% =========================================================================
function R = toy_checks(R, here, outDir)
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
run = @(cfg) hetlearn.run(cfg, 'save', false, 'quiet', true);
org = qq(2020, 4);
hz = qq(2021, 1):qq(2023, 4);
rng(11);
vg = randn(12, 1);
vu = 0.5 * randn(12, 1);
base = struct('model', toyDir);
base.forecast = struct('origin', org, 'horizon', 12);
base.expectations = struct('mode', 'switching', 'variables', {{'y', 'pie'}});
base.switching.intensity = 0.25;
base.shocks.add = {{'e_g', hz, vg}, {'e_u', hz, vu}};
muT = 0.002;                    % toy step size (errors of order 1 in model units)
koz = base;
koz.gain.rule = 'koz';
koz.gain.koz.mu = muT;

% ---- G7 ----
nm = 'gain G7: toy end-to-end, mu = 0 = constant rule bit for bit (common and per_variable)';
try
    c = base;
    c.id = 'toy_gain_const';
    r0 = run(c);
    c.gain.rule = 'koz';
    c.gain.koz.mu = 0;
    c.id = 'toy_gain_mu0';
    r1 = run(c);
    c.gain.koz.structure = 'per_variable';
    r2 = run(c);
    [d1, w1] = res_diff(r0, r1);
    [d2, w2] = res_diff(r0, r2);
    ok = d1 == 0 && d2 == 0 && ~isfield(r0.learning.pie, 'gain_R') && isfield(r1.learning.pie, 'gain_R') ...
        && height(r0.events) == height(r1.events);
    R = add(R, nm, ok, sprintf('common %g (%s), per_variable %g (%s); constant run records no gain_R', d1, w1, d2, w2));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G8 ----
nm = 'gain G8: toy, error rls, info current: implied FE_t = y_t - (alpha_{t-1} + beta_{t-1} y_{t-1}), history + forecast';
try
    c = koz;
    c.id = 'toy_gain_koz_rls_current';
    c.beliefs.info = 'current';
    res = hetlearn.run(c, 'results_dir', outDir, 'quiet', true);
    rd = res.dates.record;
    L = res.learning.y;
    [fe, g, Rg] = implied_fe(L, rd, 0, 1);
    y = res.paths.y;
    direct = y(rd) - (L.alpha_y(rd - 1) + L.beta_y(rd - 1) .* y(rd - 1));
    k = 2:numel(rd);
    dFE = max(abs(fe(k) - direct(k)));
    evd = {};
    if height(res.events) > 0
        evd = res.events.date(strcmp(res.events.type, 'gain_bound'));
    end
    rdS = cellstr(hetlearn.util.date_str(rd));
    kk = 1:numel(rd) - 1;
    kk = kk(~ismember(rdS(kk), evd));
    RgPrev = [0; Rg(1:end-1)];
    dG = max(abs(g(kk + 1) - (g(kk) + muT * RgPrev(kk) .* fe(kk))));
    nH = sum(double(rd) <= double(org));
    R = add(R, nm, dFE < 1e-9 && nH > 10 && numel(k) > nH, sprintf('max diff %.2g over %d history + %d forecast periods', ...
        dFE, nH - 1, numel(rd) - nH));
    gp = res.learning.pie.gain(rd);
    R = add(R, 'gain G8: gamma_t = gamma_{t-1} + mu Rg_{t-1} FE_t (record); one common gain for y and pie; gain moves', ...
        dG < 1e-12 && max(abs(gp - g)) == 0 && g(1) == 0.0585 && max(g) - min(g) > 1e-3, ...
        sprintf('recursion %.2g; gain range %.4f-%.4f; %d gain_bound events', dG, min(g), max(g), numel(evd)));
    T = readtable(fullfile(outDir, c.id, 'learning.csv'), 'TextType', 'string', 'Delimiter', ',');
    nR = sum(T.field == "gain_R");
    nGn = sum(T.field == "gain");
    R = add(R, 'gain G8: learning.csv carries gain and gain_R for every PLM equation and record date', ...
        nR == 2 * numel(rd) && nGn == 2 * numel(rd), sprintf('%d gain_R rows, %d gain rows, %d dates', nR, nGn, numel(rd)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G9 ----
nm = 'gain G9: error forecast, info lagged: implied FE_t = pie_t - fBR_{t-1} (two-step forecast)';
try
    c = koz;
    c.id = 'toy_gain_koz_fcst_lagged';
    c.gain.koz.error = 'forecast';
    c.gain.koz.master = 'pie';
    res = run(c);
    rd = res.dates.record;
    L = res.learning.pie;
    fe = implied_fe(L, rd, 0, 1);
    p = res.paths.pie;
    direct = p(rd) - L.fBR(rd - 1);
    k = 2:numel(rd);
    d = max(abs(fe(k) - direct(k)));
    R = add(R, nm, d < 1e-9 && abs(fe(1)) == 0, sprintf('max diff %.2g; no update in the first period', d));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'gain G9: error forecast, info current: FE_t = pie_t - (alpha_{t-2} + beta_{t-2} pie_{t-1}) and differs from the rls residual';
try
    c = koz;
    c.id = 'toy_gain_koz_fcst_current';
    c.gain.koz.error = 'forecast';
    c.gain.koz.master = 'pie';
    c.beliefs.info = 'current';
    res = run(c);
    rd = res.dates.record;
    L = res.learning.pie;
    fe = implied_fe(L, rd, 0, 1);
    p = res.paths.pie;
    direct = p(rd) - (L.alpha_pie(rd - 2) + L.beta_pie(rd - 2) .* p(rd - 1));
    resid = p(rd) - (L.alpha_pie(rd - 1) + L.beta_pie(rd - 1) .* p(rd - 1));
    k = 3:numel(rd);
    d = max(abs(fe(k) - direct(k)));
    gap = max(abs(direct(k) - resid(k)));
    R = add(R, nm, d < 1e-9 && gap > 1e-6, sprintf('max diff %.2g; largest gap to the rls residual %.3g', d, gap));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G10 ----
nm = 'gain G10: per_variable with an auxiliary PLM (r): own gains; r driven by r_t - (alpha_r + beta_r r_{t-1})';
try
    c = koz;
    c.id = 'toy_gain_koz_pv_aux';
    c.expectations.variables = {'pie'};
    c.beliefs.plm.by_var.pie = struct('regressors', {{'pie{-1}', 'r{-1}'}}, 'constant', true);
    c.gain.koz.structure = 'per_variable';
    rp = run(c);
    rd = rp.dates.record;
    Lr = rp.learning.r;
    fe = implied_fe(Lr, rd, 0, 1);
    r = rp.paths.r;
    direct = r(rd) - (Lr.alpha_r(rd - 1) + Lr.beta_r(rd - 1) .* r(rd - 1));
    k = 2:numel(rd);
    d = max(abs(fe(k) - direct(k)));
    gP = rp.learning.pie.gain(rd);
    gR = Lr.gain(rd);
    c.gain.koz.structure = 'common';
    c.id = 'toy_gain_koz_common_aux';
    rc = run(c);
    same = max(abs(rc.learning.r.gain(rd) - rc.learning.pie.gain(rd)));
    ok = d < 1e-9 && Lr.isAux && max(abs(gP - gR)) > 1e-4 && same == 0;
    R = add(R, nm, ok, sprintf(['aux residual max diff %.2g; per_variable gains pie %.4f-%.4f, r %.4f-%.4f; ' ...
        'common: r gain = pie gain (%g)'], d, min(gP), max(gP), min(gR), max(gR), same));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G11 ----
nm = 'gain G11: evaluate (inversion and re_smoother KOZ variants) = direct runs at each origin (1e-10)';
try
    cI = koz;
    cI.shocks.add = {};
    cI.history.mode = 'inversion';
    cI.id = 'toy_gain_ev_inv';
    cS = koz;
    cS.shocks.add = {};
    cS.id = 'toy_gain_ev_rs';
    origins = [qq(2019, 1), qq(2020, 4)];
    H = 4;
    E = hetlearn.evaluate('toy_gain', {cS, cI}, origins, struct('horizon', H, 'results_dir', outDir, ...
        'quiet', true, 'realtime', false));
    spec = hetlearn.load_spec(toyDir);
    od = hetlearn.util.to_dates(origins);
    worst = 0;
    gO = [];
    for o = [qq(2019, 1), qq(2019, 4), qq(2020, 4)]
        i = find(abs(double(od) - double(o)) < 1e-6, 1);
        for v = {cS, cI}
            c = v{1};
            c.forecast.origin = o;
            c.forecast.horizon = H;
            r = run(c);
            for q = 1:numel(spec.observables)
                f = reshape(r.paths.(spec.observables{q})(o + (1:H)), 1, []);
                worst = max(worst, max(abs(f - E.forecasts.(c.id)(i, :, q))));
            end
            if strcmp(c.id, cI.id)
                gO(end+1) = r.learning.y.gain(o); %#ok<AGROW>
            end
        end
    end
    nf = size(E.settings.failures, 1);
    R = add(R, nm, worst < 1e-10 && nf == 0 && numel(unique(gO)) == 3, sprintf( ...
        'max diff %.2g over 3 origins x 2 variants, %d failures; inversion gain at the origins %s', worst, nf, ...
        mat2str(gO, 5)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G12 ----
nm = 'gain G12: density draws restart from the origin state: each kept draw = direct run with its shocks (1e-10)';
try
    c = koz;
    c.id = 'toy_gain_dens';
    c.density = struct('enabled', true, 'shocks', {{'e_g', 'e_u'}}, 'ndraws', 3, 'seed', 1, 'keep_draws', true);
    res = run(c);
    D = res.density;
    Ed = D.draws.shocks;
    worst = 0;
    for j = 1:size(Ed, 3)
        cj = koz;
        cj.id = sprintf('toy_gain_dens_draw%d', j);
        cj.shocks.add = {{'e_g', hz, vg + Ed(:, 1, j)}, {'e_u', hz, vu + Ed(:, 2, j)}};
        rj = run(cj);
        a = [rj.learning.pie.alpha_pie(hz), rj.learning.pie.beta_pie(hz), 1 - rj.learning.pie.n1_model(hz), ...
            rj.paths.obs_y(hz)];
        b = [D.draws.series.alpha_pie(:, j), D.draws.series.beta_pie(:, j), D.draws.series.n2_model_pie(:, j), ...
            D.draws.series.obs_y(:, j)];
        worst = max(worst, max(abs(a(:) - b(:))));
    end
    sp = max(abs(D.draws.series.beta_pie(end, :) - D.draws.series.beta_pie(end, 1)));
    R = add(R, nm, worst < 1e-10 && D.n_used == 3 && sp > 1e-8, sprintf('max diff %.2g over 3 draws (%s path); draws differ by %.2g', ...
        worst, D.path, sp));
catch err
    R = add(R, nm, false, err.message);
end

% ---- G13 ----
nm = 'gain G13: Ramsey commitment, switching, KOZ gain: loss over a continuation from res.state = longer forecast';
try
    c = struct('model', toyDir);
    c.forecast = struct('origin', org, 'horizon', 8);
    c.expectations = struct('mode', 'switching', 'variables', {{'pie'}});
    c.switching.intensity = 0.25;
    c.gain.rule = 'koz';
    c.gain.koz.mu = muT;
    c.policy.mode = 'ramsey';
    c.policy.loss_horizon = 30;
    c.id = 'toy_gain_ramsey_cont';
    ra = run(c);
    c.id = 'toy_gain_ramsey_direct';
    c.forecast.horizon = 30;
    c.policy.loss_horizon = [];
    rdr = run(c);
    t2 = org + (1:30);
    gr = rdr.learning.pie.gain(t2);
    ok = ra.loss.continuation && abs(rdr.loss.total - ra.loss.total) < 1e-10 * max(1, rdr.loss.total) ...
        && max(gr) - min(gr) > 1e-5;
    R = add(R, nm, ok, sprintf('%.12g vs %.12g; gain over 30 quarters %.5f-%.5f', ra.loss.total, rdr.loss.total, ...
        min(gr), max(gr)));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = sw07_checks(R, here, root, outDir)
addpath(fullfile(here, 'scenarios'));          % test scenarios tsw07_* (not scenarios/), ref_maxdiff
addpath(here);
org = qq(2022, 2);
hz = qq(2022, 3):qq(2026, 2);
B = [];
try
    B = load(fullfile(here, 'reference', 'tsw07_switch_pinf_iris.mat'), 'ref');   % tests/scenarios/make_reference.m
catch
end
for stp = {'iris', 'fast'}
    nm = sprintf(['gain G14: tsw07_switch_pinf, constant gain, engine.step = ''%s'' = tests/reference/' ...
        'tsw07_switch_pinf_iris.mat (%s)'], stp{1}, ternary(strcmp(stp{1}, 'iris'), 'max diff 0', '1e-10'));
    try
        cfg = tsw07_switch_pinf();
        cfg.id = ['sw07_test_gain_const_' stp{1}];
        cfg.compare_with = {};
        cfg.engine.step = stp{1};
        r = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
        [d, worst] = ref_maxdiff(r, B.ref);
        tol = ternary(strcmp(stp{1}, 'iris'), 0, 1e-10);
        fprintf('GAIN-G14 | %s | max abs diff vs tests/reference %.3g (%s)\n', stp{1}, d, worst);
        R = add(R, nm, d <= tol && ~isfield(r.learning.pinf, 'gain_R'), sprintf('max abs diff %.3g (%s)', d, worst));
    catch err
        R = add(R, nm, false, err.message);
    end
end
nm = 'gain G15: SW07 smoke tsw07_switch_pinf with gain.rule = ''koz'' (defaults)';
try
    cfg = tsw07_switch_pinf();
    cfg.id = 'sw07_test_gain_koz';
    cfg.compare_with = {};
    cfg.gain.rule = 'koz';
    [r, row] = sw07_smoke_run(cfg, 'switch pinf, koz gain', outDir);
    R = [R, r];
    C = load(fullfile(outDir, cfg.id, 'results.mat'), 'res');
    L = C.res.learning.pinf;
    rd = C.res.dates.record;
    g = L.gain(rd);
    gh = L.gain(hz);
    ok = all(isfinite(g)) && all(g >= 0.001 & g <= 0.25) && all(isfinite(L.gain_R(rd))) && max(g) - min(g) > 1e-4;
    msg = sprintf(['gain at 2022Q2 %.5f (horizon %.5f-%.5f; 1966-2022 range %.5f-%.5f); n2_pinf at 2022Q2 %.6f; ' ...
        'avg infl %.2f%%'], L.gain(org), min(gh), max(gh), min(g), max(g), L.n2(org), row.avg_infl);
    fprintf('GAIN-G15 | %s\n', msg);
    R = add(R, 'gain G15: SW07 KOZ gain finite, inside the bounds, moving; gain_R recorded', ok, msg);
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function g = kopts(k)
% Gain options through hetlearn.load_options (defaults, no master file).
o = hetlearn.load_options(struct('id', 'x', 'gain', struct('rule', 'koz', 'koz', k)), struct());
g = o.gain;
end


function [used, gam, Rg, nev, types] = drive(g, sys, lv, E, F)
% Step hetlearn.gain.koz over residuals E (T x nEq) and forecast errors F (T x nLv).
G = hetlearn.gain.koz('init', sys, lv, g);
tg = {sys.eq.target};
T = size(E, 1);
used = NaN(T, numel(tg));
gam = used;
Rg = used;
nev = 0;
types = {};
for t = 1:T
    rls = struct();
    for i = 1:numel(tg)
        rls.(tg{i}) = E(t, i);
    end
    fc = struct();
    for i = 1:numel(lv)
        fc.(lv{i}) = F(t, i);
    end
    errs = struct('t', t, 'first', t == 1, 'targets', {tg}, 'rls', rls, 'forecast', fc, ...
        'fe_hist', struct(), 'phi_hist', struct());
    gg = hetlearn.gain.koz('gain', G, errs, g);
    [G, ev] = hetlearn.gain.koz('update', G, errs, g);
    for i = 1:numel(tg)
        used(t, i) = gg.(tg{i});
        gam(t, i) = G.proc(G.procOf.(tg{i})).gamma;
        Rg(t, i) = G.rec.gain_R.(tg{i});
    end
    nev = nev + numel(ev);
    types = [types, {ev.type}]; %#ok<AGROW>
end
end


function [used, gam, Rg, nb] = hand(e, mu, g0, Rg0, lo, hi)
% Hand-coded KOZ eq. (9) with projection onto [lo, hi].
T = numel(e);
used = NaN(T, 1);
gam = used;
Rg = used;
g = g0;
r = Rg0;
nb = 0;
for t = 1:T
    used(t) = g;
    if isfinite(e(t))
        gn = g + mu * r * e(t);
        rn = (1 - g) * r + e(t);
        if gn < lo
            gn = lo;
            nb = nb + 1;
        elseif gn > hi
            gn = hi;
            nb = nb + 1;
        end
        g = gn;
        r = rn;
    end
    gam(t) = g;
    Rg(t) = r;
end
end


function [fe, g, Rg] = implied_fe(L, rd, Rg0, scale)
% FE_t implied by the record: Rg_t = (1 - gamma_{t-1}) Rg_{t-1} + scale*FE_t,
% gamma_{t-1} = gain(t) (the gain used in t).
g = L.gain(rd);
Rg = L.gain_R(rd);
RgPrev = [Rg0; Rg(1:end-1)];
fe = (Rg - (1 - g) .* RgPrev) / scale;
end


function [d, worst] = res_diff(A, B)
% Max abs difference of every path and learning series of A against B over A's dates.
d = 0;
worst = '';
groups = {'paths', A.paths, B.paths};
f = fieldnames(A.learning);
for i = 1:numel(f)
    groups(end+1, :) = {['learning.' f{i}], A.learning.(f{i}), B.learning.(f{i})}; %#ok<AGROW>
end
for q = 1:size(groups, 1)
    a = groups{q, 2};
    b = groups{q, 3};
    fn = fieldnames(a);
    for j = 1:numel(fn)
        if ~isa(a.(fn{j}), 'Series') || ~isfield(b, fn{j})
            continue
        end
        rng_ = a.(fn{j}).Range;
        x = a.(fn{j})(rng_);
        y = b.(fn{j})(rng_);
        e = abs(x - y);
        e(isnan(x) & isnan(y)) = 0;
        e(isnan(e)) = Inf;
        if ~isempty(e) && max(e) > d
            d = max(e);
            worst = [groups{q, 1} '.' fn{j}];
        end
    end
end
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end


function R = expect_error(R, name, id, fun)
try
    fun();
    R = add(R, name, false, 'no error raised');
catch err
    R = add(R, name, contains(err.identifier, id), err.identifier);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
