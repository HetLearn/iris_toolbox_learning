function R = test_engine()
%TEST_ENGINE  Engine tests on the toy NK model (DESIGN 8): E1-E4, E6-E9, E11-E12 and outputs.
%
%   R = test_engine()   returns a struct array of checks (name, pass, msg).
%
%   E1 rational mode = one IRIS simulate (zero and random shocks)
%   E2 switching runs, shares in (0,1) and move, timing assert holds
%   E3 conditions = per-period IRIS Plan loop; delta conditions; measurement
%      variable condition
%   E4 learning mode: x_exp1 = x_exp1_BR; fixed_shares uses 1 - fixed_n2
%   (E5, E10, E13, E14 tested removed devices: tiny max_root, partial updates, shrink,
%   system scope; the projection facility is tested in tests/test_facility.m)
%   E6 history-stage beliefs = hand-coded RLS loop
%   E7 history.learn = false: initial beliefs apply at the origin
%   E8 universal shares (summed errors); beliefs.update = 'fixed'
%   E9 toy switching run (re_variant pinned 'model_consistent', the old default)
%      = tests/toy_nk/reference/e2_switch_v1.mat to 1e-10 (iris step reference)
%   Results go to tests/output/results/ (not the project results/).

R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
toyDir = fullfile(here, 'toy_nk');
outDir = fullfile(here, 'output', 'results');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
run = @(cfg) hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);

base = struct();
base.model = toyDir;
base.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
base.expectations = struct('mode', 'rational', 'variables', {{'y', 'pie'}});
hz = qq(2021, 1):qq(2023, 4);

spec = hetlearn.load_spec(toyDir);
opts0 = hetlearn.load_options(setfield(base, 'id', 'toy'), struct()); %#ok<SFLD>
[m0, info0] = hetlearn.load_model(spec, opts0);
H = hetlearn.re_filter(spec, opts0);
R = add(R, 'engine: toy re_filter fit error < 1e-8 (observables rebuilt via measurement equations)', ...
    H.fit_error < 1e-8, sprintf('%.2g', H.fit_error));

notBR = info0.xList(~endsWith(info0.xList, '_exp1_BR'));
cmpNames = [notBR(:); info0.yList(:)]';

% ---- E1: rational = one IRIS simulate ---------------------------------------------------
rng(11);
shk = {zeros(12, 1), zeros(12, 1), zeros(12, 1); randn(12, 1), 0.5 * randn(12, 1), 0.25 * randn(12, 1)};
lab = {'zero shocks', 'random shocks'};
for c = 1:2
    try
        cfg = base;
        cfg.id = sprintf('toy_e1_%d', c);
        cfg.shocks.add = {{'e_g', hz, shk{c, 1}}, {'e_u', hz, shk{c, 2}}, {'e_r', hz, shk{c, 3}}};
        res = run(cfg);
        d0 = start_db(H, info0, qq(2020, 4), hz);
        d0.e_g(hz) = shk{c, 1};
        d0.e_u(hz) = shk{c, 2};
        d0.e_r(hz) = shk{c, 3};
        s = simulate(m0, d0, hz, 'anticipate', false, 'prependInput', true);
        dmax = maxdiff(res.paths, s, cmpNames, hz);
        R = add(R, ['engine E1: rational mode = one IRIS simulate (anticipate=false), ' lab{c}], ...
            dmax < 1e-10, sprintf('max abs diff %.2g', dmax));
    catch err
        R = add(R, ['engine E1: rational mode = one IRIS simulate (anticipate=false), ' lab{c}], false, err.message);
    end
end

% ---- E2: switching -------------------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_e2_switch';
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;     % toy shocks have unit variance: keep chi*FE moderate
    cfg.shocks.add = {{'e_g', hz, shk{2, 1}}, {'e_u', hz, shk{2, 2}}};
    res = run(cfg);
    L = res.learning.pie;
    rd = res.dates.record;
    n1 = L.n1(rd);
    n1f = L.n1(hz);
    inside = all(n1 > 0 & n1 < 1);
    moves = std(n1f) > 1e-6 && std(n1) > 1e-6;
    lagOK = max(abs(L.n1_model(hz(2:end)) - L.n1(hz(1:end-1)))) < 1e-15 ...
        && abs(L.n1_model(hz(1)) - L.n1(qq(2020, 4))) < 1e-15;
    agg = max(abs(res.paths.pie_exp1(hz) - (L.n1_model(hz) .* res.paths.pie_exp1_RE(hz) ...
        + (1 - L.n1_model(hz)) .* res.paths.pie_exp1_BR(hz))));
    R = add(R, 'engine E2: switching runs, shares in (0,1) and move, f^BR timing assert never fired', ...
        inside && moves, sprintf('n1 range [%.6g, %.6g], std over horizon %.3g', min(n1), max(n1), std(n1f)));
    R = add(R, 'engine E2: model share in t = n1_{t-1}; pie_exp1 = n1*RE + n2*BR', ...
        lagOK && agg < 1e-12, sprintf('aggregation error %.2g', agg));
catch err
    R = add(R, 'engine E2: switching runs, shares in (0,1) and move, f^BR timing assert never fired', false, err.message);
end

% ---- E3: conditions --------------------------------------------------------------------------
try
    cdates = hz(2:5);
    cfg = base;
    cfg.id = 'toy_e3_plan';
    cfg.shocks.add = {{'e_g', hz, shk{2, 1}}};
    cfg.conditions = struct('variable', 'pie', 'shock', 'e_u', 'dates', cdates, ...
        'values', [0.5; 0.4; 0.3; 0.2], 'type', 'level', 'reference', 'self');
    res = run(cfg);
    dd = start_db(H, info0, qq(2020, 4), hz);
    dd.e_g(hz) = shk{2, 1};
    names = [info0.xList(:); info0.yList(:); info0.eList(:)]';
    tg = [0.5; 0.4; 0.3; 0.2];
    for k = 1:numel(hz)
        t = hz(k);
        q = find(hetlearn.util.date_eq(cdates, t));
        if isempty(q)
            s = simulate(m0, dd, t:t, 'prependInput', true);
        else
            p = Plan.forModel(m0, t:t);
            p = exogenize(p, t, 'pie');
            p = endogenize(p, t, 'e_u');
            dd.pie(t) = tg(q);
            s = simulate(m0, dd, t:t, 'plan', p, 'prependInput', true);
        end
        for i = 1:numel(names)
            dd.(names{i})(t) = s.(names{i})(t);
        end
    end
    dmax = maxdiff(res.paths, dd, [cmpNames, info0.eList(:)'], hz);
    hit = max(abs(res.paths.pie(cdates) - tg));
    R = add(R, 'engine E3: level conditions (pie via e_u, 4 periods) = per-period IRIS Plan loop', ...
        dmax < 1e-10 && hit < 1e-9, sprintf('max abs diff %.2g, target miss %.2g', dmax, hit));
catch err
    R = add(R, 'engine E3: level conditions (pie via e_u, 4 periods) = per-period IRIS Plan loop', false, err.message);
end
try
    cfgB = base;
    cfgB.id = 'toy_e3_base';
    cfgB.expectations.mode = 'switching';
    cfgB.shocks.add = {{'e_u', hz, shk{2, 2}}};
    resB = run(cfgB);
    cfgD = cfgB;
    cfgD.id = 'toy_e3_delta';
    cfgD.conditions = struct('variable', 'y', 'shock', 'e_g', 'dates', hz(3:4), ...
        'values', 0.3, 'type', 'delta', 'reference', 'self');
    resD = run(cfgD);
    dd = resD.paths.y(hz(3:4)) - resB.paths.y(hz(3:4));
    same = max(abs(resD.paths.y(hz(1:2)) - resB.paths.y(hz(1:2))));
    R = add(R, 'engine E3: delta conditions hit reference (self, switching) + delta', ...
        max(abs(dd - 0.3)) < 1e-9 && same < 1e-12, sprintf('deltas %s', mat2str(dd', 12)));
    cfgI = cfgB;
    cfgI.id = 'toy_e3_delta_id';
    cfgI.conditions = struct('variable', 'y', 'shock', 'e_g', 'dates', hz(3:4), ...
        'values', -0.2, 'type', 'delta', 'reference', 'toy_e3_base');
    resI = run(cfgI);
    di = resI.paths.y(hz(3:4)) - resB.paths.y(hz(3:4));
    R = add(R, 'engine E3: delta conditions with a scenario id as reference', ...
        max(abs(di + 0.2)) < 1e-9, sprintf('deltas %s', mat2str(di', 12)));
catch err
    R = add(R, 'engine E3: delta conditions hit reference (self, switching) + delta', false, err.message);
end
try
    cfg = base;
    cfg.id = 'toy_e3_meas';
    cfg.expectations.mode = 'switching';
    cfg.conditions = struct('variable', 'obs_r', 'shock', 'e_r', 'dates', hz(1:2), ...
        'values', [0.2; 0.4], 'type', 'level', 'reference', 'self');
    res = run(cfg);
    hit = max(abs(res.paths.obs_r(hz(1:2)) - [0.2; 0.4]));
    R = add(R, 'engine E3: measurement-variable condition (obs_r via e_r) hits its target', ...
        hit < 1e-9, sprintf('miss %.2g', hit));
catch err
    R = add(R, 'engine E3: measurement-variable condition (obs_r via e_r) hits its target', false, err.message);
end
try
    cfg = base;
    cfg.id = 'toy_e3_bad';
    cfg.conditions = struct('variable', {'y', 'pie'}, 'shock', {'e_g', 'e_g'}, 'dates', {hz(1), hz(1)}, ...
        'values', {0.1, 0.1}, 'type', {'level', 'level'}, 'reference', {'self', 'self'});
    run(cfg);
    R = add(R, 'engine E3: fewer shocks than targets is an error', false, 'no error');
catch err
    R = add(R, 'engine E3: fewer shocks than targets is an error', ...
        contains(err.message, 'endogenised shocks'), err.message);
end

% ---- E4: learning mode, fixed shares --------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_e4_learning';
    cfg.expectations.mode = 'learning';
    cfg.shocks.add = {{'e_g', hz, shk{2, 1}}};
    res = run(cfg);
    d1 = max(abs(res.paths.pie_exp1(hz) - res.paths.pie_exp1_BR(hz)));
    d2 = max(abs(res.paths.y_exp1(hz) - res.paths.y_exp1_BR(hz)));
    R = add(R, 'engine E4: learning mode: x_exp1 = x_exp1_BR (pie, y)', ...
        max(d1, d2) < 1e-12, sprintf('max abs diff %.2g', max(d1, d2)));
    cfg.id = 'toy_e4_fixed';
    cfg.expectations.mode = 'fixed_shares';
    cfg.shares.fixed_n2 = struct('y', 0.3, 'pie', 0.6);
    res = run(cfg);
    L = res.learning.pie;
    agg = max(abs(res.paths.pie_exp1(hz) - (0.4 * res.paths.pie_exp1_RE(hz) + 0.6 * res.paths.pie_exp1_BR(hz))));
    ok = all(abs(L.n1_model(hz) - 0.4) < 1e-15) && all(abs(res.learning.y.n1_model(hz) - 0.7) < 1e-15);
    R = add(R, 'engine E4: fixed_shares by variable: n1 = 1 - fixed_n2 in the model', ok && agg < 1e-12, ...
        sprintf('aggregation error %.2g', agg));
catch err
    R = add(R, 'engine E4: learning mode: x_exp1 = x_exp1_BR (pie, y)', false, err.message);
end


% ---- E6: history beliefs = hand-coded RLS ---------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_e6_history';
    cfg.expectations.variables = {'pie'};
    res = run(cfg);
    optsP = hetlearn.load_options(setfield(cfg, 'id', 'x'), struct()); %#ok<SFLD>
    [mP, infoP] = hetlearn.load_model(spec, optsP);
    [phi, Rm] = hetlearn.init.re_moments(mP, infoP.sys);
    phi = phi.pie;
    Rm = Rm.pie;
    g = 0.0585;
    hd = (H.range(1) + 4):qq(2020, 4);
    P = NaN(2, numel(hd));
    pie = H.smooth.pie;
    nrej = 0;
    for k = 1:numel(hd)
        t = hd(k);
        z = [1; pie(t - 1)];
        y = pie(t);
        R1 = Rm + g * (z * z' - Rm);
        p1 = phi + g * (R1 \ (z * (y - phi' * z)));
        if abs(p1(2)) < 0.995
            phi = p1;
            Rm = R1;
        else
            nrej = nrej + 1;
        end
        P(:, k) = phi;
    end
    E = [res.learning.pie.alpha_pie(hd), res.learning.pie.beta_pie(hd)]';
    dmax = max(abs(E(:) - P(:)));
    R = add(R, 'engine E6: history-stage beliefs = hand-coded constant-gain RLS loop', ...
        dmax < 1e-12, sprintf('%d periods, max abs diff %.2g, %d rejections', numel(hd), dmax, nrej));
catch err
    R = add(R, 'engine E6: history-stage beliefs = hand-coded constant-gain RLS loop', false, err.message);
end

% ---- E7: history.learn = false ---------------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_e7_nolearn';
    cfg.expectations.mode = 'switching';
    cfg.history.learn = false;
    cfg.shares.init_n2 = 0.3;
    res = run(cfg);
    [phi0, ~] = hetlearn.init.re_moments(m0, info0.sys);
    L = res.learning.pie;
    ok = hetlearn.util.date_eq(res.dates.record(1), qq(2020, 4)) ...
        && max(abs([L.alpha_pie(qq(2020, 4)); L.beta_pie(qq(2020, 4))] - phi0.pie)) == 0 ...
        && abs(L.n1_model(hz(1)) - 0.7) < 1e-15;
    R = add(R, 'engine E7: history.learn = false: initial beliefs and shares apply at the origin', ok, '');
catch err
    R = add(R, 'engine E7: history.learn = false: initial beliefs and shares apply at the origin', false, err.message);
end

% ---- E8: universal shares, fixed beliefs ------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_e8_universal';
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;
    cfg.shares.structure = 'universal';
    cfg.shares.master = {'pie', 'y'};
    res = run(cfg);
    rd = res.dates.record;
    Lp = res.learning.pie;
    Ly = res.learning.y;
    om = 0.6;
    zr = -(1 - om) * (Lp.FE_RE(rd(2:end)) + Ly.FE_RE(rd(2:end))) + om * Lp.zetaRE(rd(1:end-1));
    zb = -(1 - om) * (Lp.FE_BR(rd(2:end)) + Ly.FE_BR(rd(2:end))) + om * Lp.zetaBR(rd(1:end-1));
    n1 = 1 ./ (1 + exp(-0.25 * (zr - zb)));
    dz = max(abs([zr - Lp.zetaRE(rd(2:end)); zb - Lp.zetaBR(rd(2:end)); n1 - Lp.n1(rd(2:end))]));
    same = isequal(Lp.n1(rd), Ly.n1(rd)) && isequal(Lp.n1_model(hz), Ly.n1_model(hz));
    R = add(R, 'engine E8: universal shares (master {pie, y}): one share, fitness from summed errors', ...
        same && dz < 1e-12, sprintf('max abs diff %.2g', dz));
catch err
    R = add(R, 'engine E8: universal shares (master {pie, y}): one share, fitness from summed errors', false, err.message);
end
try
    cfg = base;
    cfg.id = 'toy_e8_fixed';
    cfg.expectations.mode = 'switching';
    cfg.beliefs.update = 'fixed';
    res = run(cfg);
    [phi0, ~] = hetlearn.init.re_moments(m0, info0.sys);
    rd = res.dates.record;
    L = res.learning.pie;
    dphi = max(max(abs([L.alpha_pie(rd), L.beta_pie(rd)] - phi0.pie')));
    R = add(R, 'engine E8: beliefs.update = fixed: phi constant at the initial beliefs, no events', ...
        dphi == 0 && height(res.events) == 0 && all(isnan(L.gain(rd))), sprintf('max phi change %.2g', dphi));
catch err
    R = add(R, 'engine E8: beliefs.update = fixed: phi constant at the initial beliefs, no events', false, err.message);
end

% ---- outputs ------------------------------------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_out_cmp';
    cfg.expectations.mode = 'switching';
    cfg.compare_with = {'toy_e1_1'};
    res = run(cfg);
    f = fullfile(outDir, 'toy_out_cmp');
    files = {'results.mat', 'observables.csv', 'paths.csv', 'learning.csv', 'events.csv', 'compare_toy_e1_1.csv'};
    have = cellfun(@(x) exist(fullfile(f, x), 'file') == 2, files);
    T = readtable(fullfile(f, 'compare_toy_e1_1.csv'), 'TextType', 'char');
    other = load(fullfile(outDir, 'toy_e1_1', 'results.mat'));
    dc = max(abs(T.obs_pie - (res.paths.obs_pie(hz) - other.res.paths.obs_pie(hz))));
    Tc = hetlearn.compare({'toy_e1_1', 'toy_out_cmp'}, {'obs_pie'}, hz, 'results_dir', outDir);
    dc2 = max(abs(Tc.obs_pie__toy_out_cmp_minus_toy_e1_1 - (res.paths.obs_pie(hz) - other.res.paths.obs_pie(hz))));
    R = add(R, 'engine outputs: results.mat and CSVs written; compare_<id>.csv and hetlearn.compare agree', ...
        all(have) && strcmp(T.date{1}, '2021Q1') && dc < 1e-12 && dc2 == 0, ...
        sprintf('files %s, diff %.2g', mat2str(have), dc));
catch err
    R = add(R, 'engine outputs: results.mat and CSVs written; compare_<id>.csv and hetlearn.compare agree', false, err.message);
end

try
    % E9: the toy switching run equals the stored reference (made before the 2026-10-18 changes)
    cfg = base;
    cfg.id = 'toy_e9_ref';
    cfg.expectations.re_variant = 'model_consistent';   % the reference was made with the old default
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;
    cfg.shocks.add = {{'e_g', hz, shk{2, 1}}, {'e_u', hz, shk{2, 2}}};
    res = run(cfg);
    ref = load(fullfile(toyDir, 'reference', 'e2_switch_v1.mat'));
    ref = ref.res;
    dp = 0;
    for n = fieldnames(ref.paths)'
        a = res.paths.(n{1})(ref.dates.full);
        b = ref.paths.(n{1})(ref.dates.full);
        k = ~(isnan(a) & isnan(b));
        dp = max([dp; abs(a(k) - b(k))]);
    end
    dl = 0;
    for x = fieldnames(ref.learning)'
        for f = fieldnames(ref.learning.(x{1}))'
            s = ref.learning.(x{1}).(f{1});
            if isa(s, 'Series')
                a = res.learning.(x{1}).(f{1})(ref.dates.record);
                b = s(ref.dates.record);
                k = ~(isnan(a) & isnan(b));
                dl = max([dl; abs(a(k) - b(k))]);
            end
        end
    end
    % the reference was made with engine.step = 'iris'; the fast default equals it to rounding
    R = add(R, 'engine E9: toy switching run (model-consistent, plm_alm) = stored reference tests/toy_nk/reference/e2_switch_v1.mat to 1e-10', ...
        dp < 1e-10 && dl < 1e-10, sprintf('paths %.2g, learning %.2g', dp, dl));
catch err
    R = add(R, 'engine E9: toy switching run (model-consistent, plm_alm) = stored reference tests/toy_nk/reference/e2_switch_v1.mat to 1e-10', false, err.message);
end


R = review_checks(R, run, base, hz, shk, spec, m0, info0, H);
end


% =========================================================================
function R = review_checks(R, run, base, hz, shk, spec, m0, info0, H)
% E11-E12 (review findings m7, m10; E13-E14 tested removed devices).

% ---- E11: timing from res.paths alone (m7) ----------------------------------------------------
nm = ['engine E11: FE_RE/FE_BR = (x_t - x_exp1_RE/BR_{t-1})^2 from res.paths (history and horizon); ' ...
    'n1_model(t) = n1(t-1); model BR forecast in t uses the beliefs recorded at t-1'];
try
    cfg = base;
    cfg.id = 'toy_e11_timing';
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;
    cfg.shocks.add = {{'e_g', hz, shk{2, 1}}, {'e_u', hz, shk{2, 2}}};
    res = run(cfg);
    rd = res.dates.record;
    t2 = rd(2:end);
    P = res.paths;
    w = zeros(1, 4);
    for x = {'y', 'pie'}
        v = x{1};
        L = res.learning.(v);
        a = P.(v)(t2);
        w(1) = max([w(1); nan2inf(L.FE_RE(t2) - (a - P.([v '_exp1_RE'])(t2 - 1)) .^ 2)]);
        w(2) = max([w(2); nan2inf(L.FE_BR(t2) - (a - P.([v '_exp1_BR'])(t2 - 1)) .^ 2)]);
        al = L.(['alpha_' v])(t2 - 1);
        be = L.(['beta_' v])(t2 - 1);
        w(3) = max([w(3); nan2inf(P.([v '_exp1_BR'])(t2) - (al + be .* (al + be .* P.(v)(t2 - 1))))]);
        w(4) = max([w(4); nan2inf(L.n1_model(hz) - L.n1(hz - 1))]);
    end
    nHist = sum(double(t2) <= double(res.dates.origin) + 1e-6);
    R = add(R, nm, all(w < 1e-12) && nHist > 10 && numel(t2) - nHist == numel(hz), sprintf( ...
        'max abs diff FE_RE %.2g, FE_BR %.2g, BR forecast %.2g, n1 lag %.2g; %d history + %d horizon periods', ...
        w, nHist, numel(t2) - nHist));
catch err
    R = add(R, nm, false, err.message);
end

% ---- E12: over-identified conditions weighted by shock std (m10) -------------------------------
nm = ['engine E12: 2 shocks, 1 target: minimum norm in std units (analytic), ''none'' = pinv; ' ...
    'IRIS and fast step; exactly identified unaffected'];
try
    t = hz(1);
    d = start_db(H, info0, qq(2020, 4), hz);
    mI = ud(m0, 'hetlearn_step', 'iris');
    u = userdata(mI);
    if isfield(u, 'hetlearn_sspace')
        mI = userdata(mI, rmfield(u, 'hetlearn_sspace'));
    end
    [mF, okF] = hetlearn.engine.solve_model(ud(m0, 'hetlearn_step', 'fast'), spec);
    sh = {'e_u', 'e_g'};
    sig = [m0.std_e_u; m0.std_e_g];
    s0 = simulate(mI, d, t:t, 'prependInput', true);
    mv = zeros(2, 1);
    for j = 1:2
        dj = d;
        dj.(sh{j})(t) = dj.(sh{j})(t) + 1;
        sj = simulate(mI, dj, t:t, 'prependInput', true);
        mv(j) = sj.pie(t) - s0.pie(t);
    end
    target = s0.pie(t) + 0.7;
    gap = 0.7;
    dStd = sig .^ 2 .* mv * gap / sum(sig .^ 2 .* mv .^ 2);
    dNone = mv * gap / sum(mv .^ 2);
    cond = struct('vars', {{'pie'}}, 'shocks', {sh}, 'targets', target);
    worst = 0;
    hit = 0;
    for mm = {mI, mF}
        for wmode = {'std', 'none'}
            mw = mm{1};
            if strcmp(wmode{1}, 'none')
                mw = ud(mw, 'hetlearn_cond_weighting', 'none');
            end
            [s, dOut, inf1] = hetlearn.engine.step(mw, d, t, cond);
            got = [dOut.e_u(t) - d.e_u(t); dOut.e_g(t) - d.e_g(t)];
            ref = dStd;
            if strcmp(wmode{1}, 'none')
                ref = dNone;
            end
            worst = max(worst, max(abs(got - ref)));
            hit = max(hit, abs(s.pie(t) - target));
        end
    end
    % exactly identified: one shock, one target, std and none identical
    c1 = struct('vars', {{'pie'}}, 'shocks', {{'e_u'}}, 'targets', target);
    [~, dA] = hetlearn.engine.step(mF, d, t, c1);
    [~, dB] = hetlearn.engine.step(ud(mF, 'hetlearn_cond_weighting', 'none'), d, t, c1);
    same = dA.e_u(t) == dB.e_u(t) && abs(dA.e_u(t) - gap / mv(1)) < 1e-10;
    differ = max(abs(dStd - dNone)) > 1e-3 && abs(sig(1) - sig(2)) > 0;
    o = hetlearn.load_options(setfield(base, 'id', 'x'), struct()); %#ok<SFLD>
    R = add(R, nm, okF && worst < 1e-10 && hit < 1e-9 && same && differ ...
        && strcmp(o.engine.conditions_weighting, 'std'), sprintf( ...
        'std %s, deltas std %s vs none %s; max diff to analytic %.2g, target miss %.2g', ...
        mat2str(sig', 3), mat2str(dStd', 4), mat2str(dNone', 4), worst, hit));
catch err
    R = add(R, nm, false, err.message);
end

end


function e = plm_eq(target, regs)
% PLM equation of hetlearn.plm.build_system: target_t = alpha + sum beta_u * u_{t-1}.
pn = [{['alpha_' target]}, cellfun(@(u) ['beta_' target '__' u '_l1'], regs, 'UniformOutput', false)];
e = struct('target', target, 'isAux', false, 'constant', true, 'reg_names', {regs}, ...
    'reg_lags', ones(1, numel(regs)), 'param_names', {pn});
end


function m = ud(m, field, value)
u = userdata(m);
if ~isstruct(u)
    u = struct();
end
u.(field) = value;
m = userdata(m, u);
end


function v = nan2inf(v)
v = abs(v(:));
v(isnan(v)) = Inf;
end


% =========================================================================
function d = start_db(H, info, origin, hz)
d = struct();
names = [info.xList(:); info.yList(:); info.eList(:)]';
for i = 1:numel(names)
    x = H.smooth.(names{i});
    d.(names{i}) = clip(x, x.Start, origin);
end
for i = 1:numel(info.eList)
    d.(info.eList{i})(hz) = 0;
end
end


function dmax = maxdiff(a, b, names, hz)
dmax = 0;
for i = 1:numel(names)
    v = abs(a.(names{i})(hz) - b.(names{i})(hz));
    v(isnan(v)) = Inf;
    dmax = max([dmax; v(:)]);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
