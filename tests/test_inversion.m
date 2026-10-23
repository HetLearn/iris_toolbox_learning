function R = test_inversion(part)
%TEST_INVERSION  History backed out with the learning model (DESIGN 15) and the engine.step options.
%
%   R = test_inversion()            all checks
%   R = test_inversion('toy')       I1-I7 (toy NK)
%   R = test_inversion('sw07_re')   S1: SW07 RE inversion 1966Q1-2026Q2
%   R = test_inversion('sw07_learn')  S2: SW07 switching on pinf, model-consistent and anchored
%   R = test_inversion('sw07_fast') S3: SW07 fast step = IRIS, speed, density, regression vs tests/reference/
%   ('sw07' = all three SW07 parts.)
%
%   I1 RE inversion (mode 'rational') = RE-smoothed shocks and history (1e-8);
%      learning paths = those of the 're_smoother' history (1e-8)
%   I2 learning inversion (switching): every observable matched every period
%      (1e-9), the timing assert held, beliefs and shares move, the forecast
%      starts from the backed-out history
%   I3 inversion with engine.step 'fast' = 'iris' (1e-11), runtimes
%   I4 fast step = IRIS step, one period, without/with conditions (square and
%      minimum norm), transition and measurement targets (1e-11)
%   I5 evaluate with an inversion variant: forecasts from the stored state =
%      direct inversion runs at those origins (1e-10)
%   I6 DM with the Harvey-Leybourne-Newbold correction and t(n-1) p-values
%      (opts.dm_hln) = hand computation from errors_long
%   I7 density.demean: bootstrap pool demeaned, draws are its rows
%   SW07 runs write to tests/output/results/ (not results/).

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));              % test scenarios tsw07_* and ref_maxdiff
outDir = fullfile(here, 'output', 'results');
if any(strcmp(part, {'all', 'toy'}))
    R = toy_checks(R, here, outDir);
end
if any(strcmp(part, {'all', 'sw07', 'sw07_re'}))
    R = sw07_re(R, outDir);
end
if any(strcmp(part, {'all', 'sw07', 'sw07_learn'}))
    R = sw07_learn(R, outDir);
end
if any(strcmp(part, {'all', 'sw07', 'sw07_fast'}))
    R = sw07_fast(R, outDir);
end
end


% =========================================================================
function R = toy_checks(R, here, outDir)
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
run = @(cfg) hetlearn.run(cfg, 'save', false, 'quiet', true);
spec = hetlearn.load_spec(toyDir);
base = struct();
base.model = toyDir;
base.forecast = struct('origin', qq(2020, 4), 'horizon', 8);
base.expectations = struct('mode', 'rational', 'variables', {{'y', 'pie'}});
base.history.mode = 'inversion';
cSW = base;
cSW.expectations.mode = 'switching';
cSW.switching.intensity = 0.25;

% ---- I1 ----
nm = 'inversion I1: RE inversion = RE-smoothed shocks and history; learning = re_smoother learning';
try
    c = base;
    c.id = 'toy_inv_re';
    r1 = run(c);
    c.history.mode = 're_smoother';
    r0 = run(c);
    dl = learn_diff(r1, r0, r1.dates.init_date:r1.dates.origin);
    ok = r1.inversion.shock_diff_vs_smoothed < 1e-8 && r1.inversion.path_diff_vs_smoothed < 1e-8 ...
        && dl < 1e-8 && strcmp(r1.history_mode, 'inversion');
    R = add(R, nm, ok, sprintf('shocks %.2g, paths %.2g, learning %.2g', ...
        r1.inversion.shock_diff_vs_smoothed, r1.inversion.path_diff_vs_smoothed, dl));
catch err
    R = add(R, nm, false, err.message);
end

% ---- I2 ----
nm = 'inversion I2: switching inversion matches every observable every period, beliefs and shares move';
try
    c = cSW;
    c.id = 'toy_inv_sw';
    r2 = run(c);
    inv = r2.inversion;
    hd = r2.dates.init_date:r2.dates.origin;
    n2 = r2.learning.pie.n2(hd);
    al = r2.learning.pie.alpha_pie(hd);
    dbase = hetlearn.load_database(spec);
    worst = 0;
    for i = 1:numel(spec.observables)
        o = spec.observables{i};
        worst = max(worst, max(abs(r2.paths.(o)(hd) - dbase.(o)(hd))));
    end
    nm1 = r2.learning.pie.n1_model(hd);
    ok = inv.max_obs_miss < 1e-9 && worst < 1e-9 && all(inv.n_obs == numel(spec.observables)) ...
        && std(n2) > 1e-4 && (max(al) - min(al)) > 1e-6 && all(isfinite(nm1)) ...
        && abs(r2.paths.obs_pie(r2.dates.origin) - dbase.obs_pie(r2.dates.origin)) < 1e-9 ...
        && inv.shock_diff_vs_smoothed > 1e-6;
    R = add(R, nm, ok, sprintf(['max miss (engine) %.2g, paths vs data %.2g, std n2 %.3g, alpha range %.3g, ' ...
        'shocks differ from smoothed by up to %.3g, %d solves, %.2f s'], inv.max_obs_miss, worst, std(n2), ...
        max(al) - min(al), inv.shock_diff_vs_smoothed, inv.n_solve, inv.runtime_s));
catch err
    R = add(R, nm, false, err.message);
end

% ---- I3 ----
nm = 'inversion I3: engine.step fast = iris for a switching inversion (1e-11)';
try
    c = cSW;
    c.id = 'toy_inv_sw_iris';
    c.engine.step = 'iris';
    tI = tic;
    rI = run(c);
    tI = toc(tI);
    c.engine.step = 'fast';
    tF = tic;
    rF = run(c);
    tF = toc(tF);
    rng = rI.dates.init_date:rI.dates.horizon(end);
    dp = path_diff(rI.paths, rF.paths, [rI.meta.xList, rI.meta.yList, rI.meta.eList], rng);
    dl = learn_diff(rI, rF, rng);
    R = add(R, nm, dp < 1e-11 && dl < 1e-11 && rF.inversion.n_fast == numel(rF.inversion.dates) ...
        && rI.inversion.n_fast == 0, sprintf('paths %.2g, learning %.2g; run %.2f s (iris) vs %.2f s (fast)', ...
        dp, dl, tI, tF));
catch err
    R = add(R, nm, false, err.message);
end

% ---- I4 ----
nm = 'inversion I4: fast one-period step = IRIS simulate, without and with conditions (1e-11)';
try
    c = cSW;
    c.id = 'toy_step';
    c.history.mode = 're_smoother';
    opts = hetlearn.load_options(c);
    [m, info] = hetlearn.load_model(spec, opts);
    H = hetlearn.re_filter(spec, opts);
    P = struct('n1_y', 0.6, 'n2_y', 0.4, 'n1_pie', 0.45, 'n2_pie', 0.55, 'alpha_y', 0.05, ...
        'beta_y', 0.7, 'alpha_pie', 0.03, 'beta_pie', 0.8);
    m = assign(m, P);
    mF = hetlearn.engine.solve_model(flag(m, 'fast'), spec);
    mI = hetlearn.engine.solve_model(flag(m, 'iris'), spec);
    t = qq(2012, 3);
    d = struct();
    for n = [info.xList(:); info.yList(:); info.eList(:)]'
        x = H.smooth.(n{1});
        d.(n{1}) = clip(x, x.Start, t - 1);
    end
    d.e_g(t) = 0.3;
    d.e_u(t) = -0.2;
    d.e_r(t) = 0.1;
    names = [info.xList(:); info.yList(:); info.eList(:)]';
    conds = {[], struct('vars', {{'obs_pie', 'y'}}, 'shocks', {{'e_u', 'e_g'}}, 'targets', [1.5; -0.3]), ...
        struct('vars', {{'obs_r', 'pie'}}, 'shocks', {{'e_g', 'e_u', 'e_r'}}, 'targets', [0.4; 0.2])};
    worst = 0;
    for q = 1:numel(conds)
        [sF, dF, iF] = hetlearn.engine.step(mF, d, t, conds{q});
        [sI, dI, iI] = hetlearn.engine.step(mI, d, t, conds{q});
        worst = max([worst, at_diff(sF, sI, names, t), at_diff(dF, dI, info.eList, t)]);
        assert(iF.fast && ~iI.fast, 'step path flags');
    end
    nRep = 30;
    tic;
    for k = 1:nRep, hetlearn.engine.step(mI, d, t, conds{2}); end
    tI = toc / nRep;
    tic;
    for k = 1:nRep, hetlearn.engine.step(mF, d, t, conds{2}); end
    tF = toc / nRep;
    tic;
    for k = 1:nRep, hetlearn.engine.step(mI, d, t, []); end
    tI0 = toc / nRep;
    tic;
    for k = 1:nRep, hetlearn.engine.step(mF, d, t, []); end
    tF0 = toc / nRep;
    R = add(R, nm, worst < 1e-11, sprintf(['max diff %.2g; per period %.1f ms (iris) vs %.2f ms (fast) ' ...
        'without conditions, %.1f vs %.2f ms with 2 conditions'], worst, 1e3 * tI0, 1e3 * tF0, 1e3 * tI, 1e3 * tF));
catch err
    R = add(R, nm, false, err.message);
end

% ---- I5 / I6 ----
nm5 = 'inversion I5: evaluate with an inversion variant = direct inversion runs at each origin (1e-10)';
nm6 = 'inversion I6: DM with HLN correction and t(n-1) p-values = hand computation';
E = [];
try
    cR = base;
    cR.id = 'toy_ev_re';
    cR.history.mode = 're_smoother';
    cI = cSW;
    cI.id = 'toy_ev_inv';
    origins = [qq(2015, 1), qq(2020, 4)];
    H5 = 4;
    E = hetlearn.evaluate('toy_inv', {cR, cI}, origins, struct('horizon', H5, 'results_dir', outDir, ...
        'quiet', true, 'realtime', false));
    worst = 0;
    od = hetlearn.util.to_dates(origins);
    for o = [qq(2015, 1), qq(2018, 2), qq(2020, 4)]
        c = cI;
        c.forecast.origin = o;
        c.forecast.horizon = H5;
        r = run(c);
        i = find(abs(double(od) - double(o)) < 1e-6, 1);
        for k = 1:numel(spec.observables)
            f = reshape(r.paths.(spec.observables{k})(o + (1:H5)), 1, []);
            worst = max(worst, max(abs(f - E.forecasts.toy_ev_inv(i, :, k))));
        end
    end
    nf = size(E.settings.failures, 1);
    R = add(R, nm5, worst < 1e-10 && nf == 0, sprintf('max diff %.2g over 3 origins, %d failures', worst, nf));
catch err
    R = add(R, nm5, false, err.message);
end
try
    T = E.errors;
    Dm = E.dm(strcmp(E.dm.sample, 'full'), :);
    worst = 0;
    nChk = 0;
    for q = 1:height(Dm)
        h = Dm.h(q);
        v = Dm.variable{q};
        a = T(strcmp(T.variant, Dm.variant{q}) & strcmp(T.variable, v) & T.h == h, :);
        b = T(strcmp(T.variant, Dm.benchmark{q}) & strcmp(T.variable, v) & T.h == h, :);
        [~, ia, ib] = intersect(a.origin, b.origin);
        dd = a.error(ia) .^ 2 - b.error(ib) .^ 2;
        n = numel(dd);
        u = dd - mean(dd);
        L = min(h - 1, n - 1);
        lrv = (u' * u) / n;
        for k = 1:L                      % default kernel with dm_hln: uniform (review finding m2)
            lrv = lrv + 2 * (u(k+1:end)' * u(1:end-k)) / n;
        end
        if ~(lrv > 0)                    % fallback to Bartlett
            lrv = (u' * u) / n;
            for k = 1:L
                lrv = lrv + 2 * (1 - k / (L + 1)) * (u(k+1:end)' * u(1:end-k)) / n;
            end
        end
        st = mean(dd) / sqrt(lrv / n) * sqrt((n + 1 - 2 * h + h * (h - 1) / n) / n);
        p = betainc((n - 1) / (n - 1 + st ^ 2), (n - 1) / 2, 0.5);
        worst = max([worst, abs(st - Dm.dm_stat(q)), abs(p - Dm.p_value(q))]);
        nChk = nChk + 1;
    end
    p05 = betainc(10 / (10 + 2.228138852 ^ 2), 5, 0.5);      % t(10) 97.5% quantile -> p = 0.05
    R = add(R, nm6, worst < 1e-10 && nChk > 0 && abs(p05 - 0.05) < 1e-8 && E.settings.dm_hln, ...
        sprintf('%d tests, max diff %.2g; p(t10 = 2.2281) = %.6f', nChk, worst, p05));
catch err
    R = add(R, nm6, false, err.message);
end

% ---- I7 ----
nm = 'inversion I7: density.demean centres the bootstrap pool; draws are rows of the demeaned pool';
try
    c = base;
    c.id = 'toy_demean';
    c.history.mode = 're_smoother';
    opts = hetlearn.load_options(c);
    [m, info] = hetlearn.load_model(spec, opts);
    H = hetlearn.re_filter(spec, opts);
    ctx = struct('opts', opts, 'spec', spec, 'info', info, 'results_dir', outDir, 'quiet', true);
    [~, F] = hetlearn.engine.core(ctx, m, H);
    sr = [qq(2005, 1), qq(2015, 4)];
    shocks = {'e_g', 'e_u', 'e_r'};
    F.ctx.opts.density.shocks = shocks;
    F.ctx.opts.density.method = 'bootstrap';
    F.ctx.opts.density.ndraws = 50;
    F.ctx.opts.density.sigma_range = sr;
    [Ed, inf1] = hetlearn.density.draws(F, H);
    raw = zeros(numel(sr(1):sr(2)), 3);
    for s = 1:3
        raw(:, s) = H.smooth.(shocks{s})(sr(1):sr(2));
    end
    F.ctx.opts.density.demean = false;
    [Eu, inf0] = hetlearn.density.draws(F, H);
    pool = raw - mean(raw, 1);
    rowsOK = true;
    for j = 1:size(Ed, 3)
        rowsOK = rowsOK && isequal(Ed(:, :, j), pool(inf1.index(:, j), :));
    end
    ok = inf1.demean && ~inf0.demean && max(abs(mean(inf1.pool, 1))) < 1e-14 && rowsOK ...
        && max(abs(Ed(:) - Eu(:) + reshape(repmat(mean(raw, 1), size(Ed, 1), 1, size(Ed, 3)), [], 1))) < 1e-14;
    R = add(R, nm, ok, sprintf('pool mean before %s, after %.2g', mat2str(mean(raw, 1), 3), max(abs(mean(inf1.pool, 1)))));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = sw07_re(R, outDir)
nm = 'inversion S1: SW07 RE inversion 1966Q1-2026Q2 = RE-smoothed shocks';
try
    c = tsw07_peak_re();
    c.id = 'tinv_sw07_re';
    c.forecast.origin = qq(2026, 2);
    c.forecast.horizon = 4;
    c.history.mode = 'inversion';
    c.engine.step = 'fast';
    c.compare_with = {};
    t0 = tic;
    r = hetlearn.run(c, 'results_dir', outDir);
    tt = toc(t0);
    inv = r.inversion;
    fprintf('S1: %s-%s, %d periods: inversion %.1f s (run %.1f s), %d solves, %d fast periods\n', ...
        char(dat2str(inv.start)), char(dat2str(inv.origin)), numel(inv.dates), inv.runtime_s, tt, ...
        inv.n_solve, inv.n_fast);
    fprintf('S1: max |shock - smoothed| %.3g, max |path - smoothed| %.3g, max observable miss %.3g\n', ...
        inv.shock_diff_vs_smoothed, inv.path_diff_vs_smoothed, inv.max_obs_miss);
    growth = growth_profile(r, c);
    % Compare with the smoother up to the first quarter with a missing observable: the
    % SW07 database has no observations in 2020Q1-Q3. There the
    % inversion has nothing to hit and backs out zero shocks, so from then on the two differ.
    spec = hetlearn.load_spec(c.model);
    H = hetlearn.re_filter(spec, hetlearn.load_options(c));
    dts = inv.dates;
    full = arrayfun(@(t) all(cellfun(@(o) isfinite(H.data.(o)(t)), spec.observables)), dts);
    stop = find(~full, 1);
    if isempty(stop), pre = dts; else, pre = dts(1:stop-1); end
    wpre = 0;
    for j = 1:numel(inv.shocks)
        wpre = max([wpre; abs(r.paths.(inv.shocks{j})(pre) - H.smooth.(inv.shocks{j})(pre))]);
    end
    R = add(R, nm, wpre < 1e-8 && inv.max_obs_miss < 1e-9, sprintf( ...
        ['shocks %.2g up to %s (all quarters %.2g), paths %.2g, obs miss %.2g; %d periods in %.1f s; ' ...
        'shock error by decade %s'], wpre, char(dat2str(pre(end))), inv.shock_diff_vs_smoothed, ...
        inv.path_diff_vs_smoothed, inv.max_obs_miss, numel(inv.dates), inv.runtime_s, growth));
catch err
    R = add(R, nm, false, err.message);
end
end


function txt = growth_profile(r, c)
% Max abs shock difference vs the RE smoother by decade (rounding growth).
spec = hetlearn.load_spec(c.model);
opts = hetlearn.load_options(c);
H = hetlearn.re_filter(spec, opts);
inv = r.inversion;
dts = double(inv.dates);
yrs = floor(dts / 4);
out = {};
for y0 = 1960:10:2020
    sel = inv.dates(dts >= double(qq(y0, 1)) - 1e-6 & dts < double(qq(y0 + 10, 1)) - 1e-6);
    if isempty(sel), continue, end
    w = 0;
    for j = 1:numel(inv.shocks)
        w = max([w; abs(r.paths.(inv.shocks{j})(sel) - H.smooth.(inv.shocks{j})(sel))]);
    end
    out{end+1} = sprintf('%ds %.1e', y0, w); %#ok<AGROW>
end
txt = strjoin(out, ', ');
yrs = []; %#ok<NASGU>
end


% =========================================================================
function R = sw07_learn(R, outDir)
variants = {'tinv_sw07_switch_pinf', 'model_consistent'; 'tinv_sw07_switch_pinf_anch', 'anchored'};
spec = hetlearn.load_spec('sw07');
for q = 1:size(variants, 1)
    nm = sprintf('inversion S2: SW07 switching-on-pinf inversion (%s) matches the data', variants{q, 2});
    try
        c = tsw07_switch_pinf();
        c.id = variants{q, 1};
        c.forecast.origin = qq(2026, 2);
        c.forecast.horizon = 4;
        c.history.mode = 'inversion';
        c.engine.step = 'fast';
        c.expectations.re_variant = variants{q, 2};
        c.compare_with = {};
        r = hetlearn.run(c, 'results_dir', outDir);
        inv = r.inversion;
        ev = r.events;
        nFail = sum(strcmp(ev.type, 'projection_alm'));          % ALM reverts (DESIGN 4.4)
        nExp = sum(strcmp(ev.type, 'explosive'));
        nProj = sum(strcmp(ev.type, 'projection_plm'));
        n2 = r.learning.pinf.n2(qq(2022, 2));
        n2m = 1 - r.learning.pinf.n1_model(qq(2022, 2));
        H = hetlearn.re_filter(spec, hetlearn.load_options(c));
        fprintf('S2 %s: inversion %.1f s, %d solves; max observable miss %.3g; ALM reverts %d, explosive %d, PLM blocks kept %d\n', ...
            variants{q, 2}, inv.runtime_s, inv.n_solve, inv.max_obs_miss, nFail, nExp, nProj);
        fprintf('S2 %s: n2_pinf at 2022Q2 = %.4f (end of period), %.4f (in the model); alpha %.4f beta %.4f\n', ...
            variants{q, 2}, n2, n2m, r.learning.pinf.alpha_pinf(qq(2022, 2)), r.learning.pinf.beta_pinf(qq(2022, 2)));
        fprintf('S2 %s: backed-out shocks 2021Q1-2022Q4 (inversion / RE smoother)\n', variants{q, 2});
        rr = qq(2021, 1):qq(2022, 4);
        fprintf('%-8s', 'date');
        fprintf('%18s', inv.shocks{:});
        fprintf('\n');
        for t = rr
            fprintf('%-8s', char(dat2str(t)));
            for j = 1:numel(inv.shocks)
                fprintf('%9.3f/%8.3f', r.paths.(inv.shocks{j})(t), H.smooth.(inv.shocks{j})(t));
            end
            fprintf('\n');
        end
        dmax = 0;
        for j = 1:numel(inv.shocks)
            dmax = max([dmax; abs(r.paths.(inv.shocks{j})(rr) - H.smooth.(inv.shocks{j})(rr))]);
        end
        R = add(R, nm, inv.max_obs_miss < 1e-9, sprintf(['miss %.2g, fallbacks %d, explosive %d, ' ...
            'projection %d, n2_pinf 2022Q2 %.4f, max |shock - smoothed| 2021-22 %.3g, %.1f s'], ...
            inv.max_obs_miss, nFail, nExp, nProj, n2, dmax, inv.runtime_s));
    catch err
        R = add(R, nm, false, err.message);
    end
end
end


% =========================================================================
function R = sw07_fast(R, outDir)
spec = hetlearn.load_spec('sw07');
root = fileparts(fileparts(outDir));
root = fileparts(root);
% ---- direct step comparison and per-period speed ----
nm = 'inversion S3a: SW07 fast step = IRIS simulate, without and with conditions (1e-11)';
try
    c = tsw07_switch_pinf();
    opts = hetlearn.load_options(c);
    [m, info] = hetlearn.load_model(spec, opts);
    H = hetlearn.re_filter(spec, opts);
    m = assign(m, struct('n1_pinf', 0.4, 'n2_pinf', 0.6, 'alpha_pinf', 0.2, 'beta_pinf', 0.8));
    mF = hetlearn.engine.solve_model(flag(m, 'fast'), spec);
    mI = hetlearn.engine.solve_model(flag(m, 'iris'), spec);
    t = qq(2022, 3);
    names = [info.xList(:); info.yList(:); info.eList(:)]';
    d = struct();
    for n = names
        x = H.smooth.(n{1});
        d.(n{1}) = clip(x, x.Start, t - 1);
    end
    for j = 1:numel(info.eList)
        d.(info.eList{j})(t) = H.smooth.(info.eList{j})(qq(2022, 2));
    end
    obs = spec.observables;
    db = hetlearn.load_database(spec);
    vals = cellfun(@(o) db.(o)(qq(2022, 3)), obs);
    shk = info.eList;
    conds = {[], struct('vars', {{'pinfobs', 'robs'}}, 'shocks', {{'epinf', 'em'}}, 'targets', [2; 1.2]), ...
        struct('vars', {{'pinfobs'}}, 'shocks', {{'epinf', 'em', 'eb'}}, 'targets', 1.5), ...
        struct('vars', {obs}, 'shocks', {shk}, 'targets', vals(:))};
    worst = 0;
    for q = 1:numel(conds)
        [sF, dF] = hetlearn.engine.step(mF, d, t, conds{q});
        [sI, dI] = hetlearn.engine.step(mI, d, t, conds{q});
        worst = max([worst, at_diff(sF, sI, names, t), at_diff(dF, dI, info.eList, t)]);
    end
    nRep = 10;
    tm = zeros(2, 2);
    for q = [1, 4]
        tic;
        for k = 1:nRep, hetlearn.engine.step(mI, d, t, conds{q}); end
        tm(1, 1 + (q == 4)) = toc / nRep;
        tic;
        for k = 1:nRep, hetlearn.engine.step(mF, d, t, conds{q}); end
        tm(2, 1 + (q == 4)) = toc / nRep;
    end
    fprintf('S3a: per period, no conditions: %.1f ms (iris) vs %.2f ms (fast), x%.0f; 7 observables exogenised: %.1f vs %.2f ms, x%.0f\n', ...
        1e3 * tm(1, 1), 1e3 * tm(2, 1), tm(1, 1) / tm(2, 1), 1e3 * tm(1, 2), 1e3 * tm(2, 2), tm(1, 2) / tm(2, 2));
    R = add(R, nm, worst < 1e-11, sprintf('max diff %.2g; per period %.1f vs %.2f ms (no conditions), %.1f vs %.2f ms (7 conditions)', ...
        worst, 1e3 * tm(1, 1), 1e3 * tm(2, 1), 1e3 * tm(1, 2), 1e3 * tm(2, 2)));
catch err
    R = add(R, nm, false, err.message);
end
% ---- regression against the stored reference (tests/reference/) and density draws ----
nm = ['inversion S3b: tsw07_switch_pinf (re_smoother) with engine.step iris = tests/reference/tsw07_switch_pinf_iris.mat ' ...
    'exactly; fast = iris within 1e-10'];
try
    L = load(fullfile(root, 'tests', 'reference', 'tsw07_switch_pinf_iris.mat'), 'ref');
    c = tsw07_switch_pinf();
    c.compare_with = {};
    c.engine.step = 'iris';
    rI = hetlearn.run(c, 'save', false, 'quiet', true);
    c.engine.step = 'fast';
    rF = hetlearn.run(c, 'save', false, 'quiet', true);
    dI = ref_maxdiff(rI, L.ref);
    dF = ref_maxdiff(rF, L.ref);
    fprintf('S3b: max diff vs tests/reference: iris %.3g, fast %.3g\n', dI, dF);
    R = add(R, nm, dI == 0 && dF < 1e-10, sprintf('iris %.3g, fast %.3g', dI, dF));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'inversion S3c: SW07 density draws (general path) fast = iris; seconds per draw';
try
    c = tsw07_switch_pinf();
    c.id = 'tinv_sw07_density';
    c.compare_with = {};
    c.density = struct('enabled', true, 'shocks', {{'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'}}, ...
        'ndraws', 10, 'seed', 3);
    c.engine.step = 'iris';
    rI = hetlearn.run(c, 'save', false, 'quiet', true);
    c.engine.step = 'fast';
    rF = hetlearn.run(c, 'save', false, 'quiet', true);
    qd = max(abs(rI.density.series.pinfobs.q(:) - rF.density.series.pinfobs.q(:)));
    fprintf('S3c: density, 10 draws: %.3f s per draw (iris) vs %.3f s (fast), x%.1f; quantile diff %.2g\n', ...
        rI.density.s_per_draw, rF.density.s_per_draw, rI.density.s_per_draw / rF.density.s_per_draw, qd);
    R = add(R, nm, qd < 1e-10, sprintf('%.3f vs %.3f s per draw, quantile diff %.2g', ...
        rI.density.s_per_draw, rF.density.s_per_draw, qd));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function m = flag(m, mode)
u = userdata(m);
if ~isstruct(u)
    u = struct();
end
u.hetlearn_step = mode;
m = userdata(m, u);
end


function w = at_diff(a, b, names, t)
w = 0;
for i = 1:numel(names)
    if isfield(a, names{i}) && isfield(b, names{i})
        w = max(w, abs(a.(names{i})(t) - b.(names{i})(t)));
    else
        w = Inf;
    end
end
end


function w = path_diff(a, b, names, rng)
w = 0;
for i = 1:numel(names)
    x = a.(names{i})(rng);
    y = b.(names{i})(rng);
    both = isfinite(x) & isfinite(y);
    if any(isfinite(x) ~= isfinite(y))
        w = Inf;
        return
    end
    w = max([w; abs(x(both) - y(both))]);
end
end


function w = learn_diff(a, b, rng)
w = 0;
tg = fieldnames(a.learning);
for i = 1:numel(tg)
    A = a.learning.(tg{i});
    B = b.learning.(tg{i});
    f = fieldnames(A);
    for j = 1:numel(f)
        if ~isa(A.(f{j}), 'Series') || any(strcmp(f{j}, {'n1_model'}))
            continue
        end
        x = A.(f{j})(rng);
        y = B.(f{j})(rng);
        both = isfinite(x) & isfinite(y);
        w = max([w; abs(x(both) - y(both))]);
    end
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
if ~pass
    fprintf('FAILED %s: %s\n', name, msg);
end
end
