function R = test_density(part)
%TEST_DENSITY  Density forecasts (DESIGN 14): toy NK checks D1-D8, SW07 smoke test D9.
%
%   R = test_density()          all checks
%   R = test_density('toy')     D1-D8 only;  test_density('sw07')  D9 only
%
%   Returns a struct array of checks (name, pass, msg).
%
%   D1 seed reproducibility: same seed = identical draws and paths; another
%      seed gives other draws
%   D2 sigma 'calibrated' = the model's std_<shock>; 'smoothed' = sample std
%      of the RE-smoothed shocks over sigma_range; pooled draw stds within
%      4 s.e. of the target (hetlearn.density.draws, 2000 draws)
%   D3 'bootstrap' draws whole dates: every drawn shock vector is the
%      RE-smoothed vector of one date in sigma_range
%   D4 RE fast path (one simulate per draw) = general path (period loop), 1e-9
%   D5 quantiles ordered; hetlearn.density.quantile on a known sample
%   D6 RE: mean of 300 draws within 4 s.e. of the point forecast
%   D7 switching (general path, bootstrap): files, CSV columns, n2 in [0,1],
%      event counts
%   D8 conditions stay in force: every draw hits the conditioned target
%   D10 N agent types: the switching density with RE and BR spelled
%      out = the two-type density (observables, the BR model share against
%      n2_model, beliefs alpha/beta against alpha/beta__BR; quantiles, point
%      and draws, 1e-9); {RE, BR, TB} on the general path, model shares
%      summing to 1 in every draw
%   D9 SW07 smoke: tsw07_peak_re and tsw07_switch_pinf, all 7 shocks,
%      'calibrated', 100 draws (and 10 general-path RE draws = fast path);
%      prints seconds per draw, 5/50/95% bands of annualised inflation in
%      2023Q2 and 2024Q4 and the n2 bands
%   Results go to tests/output/results/ (not the project results/).

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));          % test scenarios tsw07_* (not scenarios/)
outDir = fullfile(here, 'output', 'results');
if any(strcmp(part, {'all', 'toy'}))
    R = toy_checks(R, here, outDir);
end
if any(strcmp(part, {'all', 'sw07'}))
    R = sw07_checks(R, here, outDir);
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
base = struct();
base.model = toyDir;
base.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
base.expectations = struct('mode', 'rational', 'variables', {{'y', 'pie'}});
shocks = {'e_g', 'e_u', 'e_r'};
spec = hetlearn.load_spec(toyDir);

% ---- D1: seed reproducibility ------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_d1';
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 20, 'seed', 7, 'keep_draws', true);
    r1 = run(cfg);
    r2 = run(cfg);
    cfg.density.seed = 8;
    r3 = run(cfg);
    same = isequal(r1.density.draws.shocks, r2.density.draws.shocks) ...
        && isequal(r1.density.draws.series, r2.density.draws.series);
    other = ~isequal(r1.density.draws.shocks, r3.density.draws.shocks);
    R = add(R, 'density D1: same seed = identical draws and paths; other seed differs', same && other, ...
        sprintf('same %d, other differs %d', same, other));
catch err
    R = add(R, 'density D1: same seed = identical draws and paths; other seed differs', false, err.message);
end

% ---- D2/D3: draws directly from the forecast-stage bundle -----------------------------------
try
    cfg = base;
    cfg.id = 'toy_d2';
    opts = hetlearn.load_options(cfg);
    [m, info] = hetlearn.load_model(spec, opts);
    H = hetlearn.re_filter(spec, opts);
    ctx = struct('opts', opts, 'spec', spec, 'info', info, 'results_dir', outDir, 'quiet', true);
    [~, F] = hetlearn.engine.core(ctx, m, H);
    sd = get(m, 'std');
    N = 2000;
    % calibrated
    F.ctx.opts.density = setf(opts.density, 'shocks', shocks, 'ndraws', N, 'sigma', 'calibrated');
    [E, inf1] = hetlearn.density.draws(F, H);
    tgt = cellfun(@(e) sd.(['std_' e]), shocks);
    [okC, txtC] = std_ok(E, tgt);
    exact = max(abs(inf1.sigma - tgt)) == 0;
    R = add(R, 'density D2: sigma ''calibrated'' = model std; draw stds within 4 s.e.', okC && exact, txtC);
    % smoothed, default range (filter range) and a sub-range
    F.ctx.opts.density.sigma = 'smoothed';
    [E, inf2] = hetlearn.density.draws(F, H);
    tgtS = cellfun(@(e) std(rmnan(H.smooth.(e)(H.range))), shocks);
    [okS, txtS] = std_ok(E, tgtS);
    sr = [qq(2005, 1), qq(2015, 4)];
    F.ctx.opts.density.sigma_range = sr;
    [~, inf3] = hetlearn.density.draws(F, H);
    tgtR = cellfun(@(e) std(rmnan(H.smooth.(e)(sr(1):sr(2)))), shocks);
    exactS = max(abs(inf2.sigma - tgtS)) < 1e-12 && max(abs(inf3.sigma - tgtR)) < 1e-12;
    R = add(R, 'density D2: sigma ''smoothed'' = sample std of RE-smoothed shocks (filter range, sigma_range); draw stds within 4 s.e.', ...
        okS && exactS, sprintf('%s; sigma error %.2g / %.2g', txtS, max(abs(inf2.sigma - tgtS)), max(abs(inf3.sigma - tgtR))));
    % bootstrap
    F.ctx.opts.density = setf(F.ctx.opts.density, 'method', 'bootstrap', 'ndraws', 200, 'demean', false);
    [E, inf4] = hetlearn.density.draws(F, H);
    pool = zeros(numel(sr(1):sr(2)), numel(shocks));
    for s = 1:numel(shocks)
        pool(:, s) = H.smooth.(shocks{s})(sr(1):sr(2));
    end
    rowsE = reshape(permute(E, [1 3 2]), [], numel(shocks));
    inPool = all(ismember(rowsE, pool, 'rows'));
    idxOK = true;
    for j = 1:size(E, 3)
        idxOK = idxOK && isequal(E(:, :, j), inf4.pool(inf4.index(:, j), :));
    end
    poolOK = isequal(inf4.pool, pool) && numel(unique(inf4.index(:))) > 10;
    R = add(R, 'density D3: bootstrap draws whole dates of the RE-smoothed shocks in sigma_range', ...
        inPool && idxOK && poolOK, sprintf('%d draw dates, all in pool %d, index %d, pool = smoothed %d', ...
        size(rowsE, 1), inPool, idxOK, poolOK));
catch err
    R = add(R, 'density D2/D3: draws (calibrated, smoothed, bootstrap)', false, err.message);
end

% ---- D4: fast path = general path -------------------------------------------------------------
try
    cfg = base;
    cfg.id = 'toy_d4';
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 15, 'keep_draws', true);
    rf = run(cfg);
    cfg.density.fast_path = false;
    rg = run(cfg);
    nm = rf.density.names;
    mx = 0;
    for i = 1:numel(nm)
        mx = max(mx, max(abs(rf.density.draws.series.(nm{i})(:) - rg.density.draws.series.(nm{i})(:))));
    end
    ok = strcmp(rf.density.path, 'fast') && strcmp(rg.density.path, 'general') && mx < 1e-9;
    R = add(R, 'density D4: RE fast path (one simulate per draw) = general path', ok, ...
        sprintf('%s vs %s, max abs diff %.2g over %d series; %.3f vs %.3f s per draw', rf.density.path, ...
        rg.density.path, mx, numel(nm), rf.density.s_per_draw, rg.density.s_per_draw));
catch err
    R = add(R, 'density D4: RE fast path (one simulate per draw) = general path', false, err.message);
end

% ---- D6 (and D5): RE mean -> point forecast; quantiles ordered ---------------------------------
try
    cfg = base;
    cfg.id = 'toy_d6';
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 300, 'seed', 1);
    r6 = run(cfg);
    D = r6.density;
    worst = 0;
    for i = 1:numel(spec.observables)
        z = D.series.(spec.observables{i});
        se = z.std / sqrt(D.n_used);
        worst = max(worst, max(abs(z.mean - z.point) ./ max(se, 1e-12)));
    end
    R = add(R, 'density D6: RE mean of 300 draws within 4 s.e. of the point forecast (all observables, dates)', ...
        worst <= 4 && D.n_used == 300, sprintf('max |mean - point| = %.2f s.e.', worst));
    qOrd = ordered(D);
    qk = hetlearn.density.quantile([5 3 1 4 2; 10 30 20 50 40], [0.05 0.1 0.25 0.5 0.9 0.95]);
    known = isequal(qk(1, :), [1 1 1.75 3 5 5]) && isequal(qk(2, :), [10 10 17.5 30 50 50]);
    R = add(R, 'density D5: quantiles ordered; quantile helper = toolbox definition on a known sample', ...
        qOrd && known, sprintf('ordered %d, known sample %d (%s)', qOrd, known, mat2str(qk(1, :))));
catch err
    R = add(R, 'density D5/D6: RE mean and quantiles', false, err.message);
end

% ---- D7: switching, general path, bootstrap, saved outputs ----------------------------------
try
    cfg = base;
    cfg.id = 'toy_d7';
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 20, 'method', 'bootstrap', 'seed', 2);
    r7 = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
    D = r7.density;
    od = fullfile(outDir, 'toy_d7');
    files = all(cellfun(@(f) exist(fullfile(od, f), 'file') == 2, ...
        {'results.mat', 'density.mat', 'density_quantiles.csv', 'density_events.csv'}));
    hdr = first_line(fullfile(od, 'density_quantiles.csv'));
    L = load(fullfile(od, 'results.mat'));
    notInRes = ~isfield(L.res, 'density');
    n2 = [D.series.n2_model_y.q(:); D.series.n2_model_pie.q(:)];
    n2ok = all(n2 >= 0 & n2 <= 1) && std(n2) > 0;
    cnt = D.n_used + D.n_explosive + D.n_error == 20 && height(D.events) == 20;
    evCols = {'draw', 'status', 'projection_plm', 'projection_alm', 'projection_alm_shares', 'explosive_events', 'rls_missing', ...
        'shares_nan', 'gain_bound', 'max_abs', 'message'};
    evHdr = first_line(fullfile(od, 'density_events.csv'));
    evOk = isequal(D.events.Properties.VariableNames, evCols) && strcmp(evHdr, strjoin(evCols, ','));
    ok = files && strcmp(hdr, 'variable,date,quantile,value_model,value_report') && notInRes ...
        && n2ok && cnt && evOk && strcmp(D.path, 'general') && ordered(D);
    R = add(R, 'density D7: switching density (general path, bootstrap): files, CSV columns, n2 in [0,1], events', ok, ...
        sprintf('files %d, header ok %d, event columns ok %d, n2 [%.3f, %.3f], used %d, PLM hits %d, ALM reverts %d, %.3f s per draw', files, ...
        strcmp(hdr, 'variable,date,quantile,value_model,value_report'), evOk, min(n2), max(n2), D.n_used, ...
        sum(D.events.projection_plm), sum(D.events.projection_alm), D.s_per_draw));
catch err
    R = add(R, 'density D7: switching density (general path, bootstrap): files, CSV columns, n2 in [0,1], events', false, err.message);
end

% ---- D8: conditions hold in every draw ---------------------------------------------------------
try
    cdates = qq(2021, 2):qq(2021, 3);
    cfg = base;
    cfg.id = 'toy_d8';
    cfg.conditions = struct('variable', 'pie', 'shock', 'e_u', 'dates', cdates, ...
        'values', [0.5; 0.4], 'type', 'level', 'reference', 'self');
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 10, 'keep_draws', true);
    r8 = run(cfg);
    X = r8.density.draws.series.obs_pie;            % obs_pie = pie
    k = find(hetlearn.util.date_eq(r8.dates.horizon, cdates(1))) + [0 1];
    miss = max(max(abs(X(k, :) - [0.5; 0.4])));
    spread = std(X(1, :));
    R = add(R, 'density D8: conditions stay in force in every draw (general path)', ...
        miss < 1e-9 && spread > 0 && strcmp(r8.density.path, 'general'), ...
        sprintf('max target miss %.2g, draw std in the first period %.3g', miss, spread));
catch err
    R = add(R, 'density D8: conditions stay in force in every draw (general path)', false, err.message);
end

% ---- D10: N agent types ---------------------------------------------------------------------------
nm = ['density D10: N agent types: RE and BR spelled out = the two-type density (observables, BR model share = ' ...
    'n2_model, beliefs; <= 1e-9); {RE, BR, TB} runs on the general path, model shares sum to 1 in every draw'];
try
    T = @(varargin) struct(varargin{:});
    cfg = base;
    cfg.id = 'toy_d10';
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 15, 'seed', 4, 'keep_draws', true);
    ra = run(cfg);
    cb = cfg;
    cb.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm')};
    rb = run(cb);
    Da = ra.density;
    Db = rb.density;
    pairs = {};
    for i = 1:numel(Da.names)
        n = Da.names{i};
        if strcmp(Da.series.(n).kind, 'observable')
            pairs(end+1, :) = {n, n}; %#ok<AGROW>
        elseif startsWith(n, 'n2_model_')
            pairs(end+1, :) = {n, ['n_model_BR_' n(10:end)]}; %#ok<AGROW>
        else
            pairs(end+1, :) = {n, [n '__BR']}; %#ok<AGROW>
        end
    end
    d = 0;
    miss = setdiff(pairs(:, 2), Db.names);
    for i = 1:size(pairs, 1) * isempty(miss)
        a = Da.series.(pairs{i, 1});
        b = Db.series.(pairs{i, 2});
        d = max([d, max(abs(a.q(:) - b.q(:))), max(abs(a.point(:) - b.point(:))), ...
            max(abs(Da.draws.series.(pairs{i, 1})(:) - Db.draws.series.(pairs{i, 2})(:)))]);
    end
    cc = cfg;
    cc.expectations.types = [cb.expectations.types, {T('name', 'TB', 'kind', 'rule', 'rule', '0')}];
    cc.shares.init = struct('RE', 0.4, 'BR', 0.4, 'TB', 0.2);
    rc = run(cc);
    Dc = rc.density;
    S = Dc.draws.series;
    s = 0;
    for x = {'y', 'pie'}
        s = max(s, max(max(abs(S.(['n_model_RE_' x{1}]) + S.(['n_model_BR_' x{1}]) + S.(['n_model_TB_' x{1}]) - 1))));
    end
    hasB = all(ismember({'alpha_pie__BR', 'beta_pie__BR', 'n_model_TB_pie'}, Dc.names));
    ok = isempty(miss) && d <= 1e-9 && strcmp(Db.path, 'general') && strcmp(Dc.path, 'general') && Dc.n_used == 15 ...
        && s < 1e-12 && hasB && ordered(Dc);
    R = add(R, nm, ok, sprintf(['pair vs two-type max diff %.3g over %d series (missing %s); TB: %d of 15 draws used, ' ...
        'share sums %.2g, series %d, %.3f s per draw'], d, size(pairs, 1), strjoin(miss, ','), Dc.n_used, s, numel(Dc.names), ...
        Dc.s_per_draw));
catch err
    R = add(R, nm, false, sprintf('%s (%s, line %d)', err.message, err.stack(1).name, err.stack(1).line));
end
end


% =========================================================================
function R = sw07_checks(R, here, outDir)
shocks = {'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'};
dts = [qq(2023, 2), qq(2024, 4)];
try
    out = struct();
    ids = {'tsw07_peak_re', 'tsw07_switch_pinf'};
    for i = 1:numel(ids)
        cfg = feval(ids{i});
        cfg.density = struct('enabled', true, 'shocks', {shocks}, 'sigma', 'calibrated', ...
            'ndraws', 100, 'keep_draws', i == 1);
        t = tic;
        res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
        out.(ids{i}) = res.density;
        fprintf('D9 %s: %s path, %.3f s per draw, run %.1f s, used %d/%d\n', ids{i}, ...
            res.density.path, res.density.s_per_draw, toc(t), res.density.n_used, res.density.ndraws);
    end
    % general path for RE: 10 draws, same seed -> equal to the first 10 fast draws
    cfg = feval('tsw07_peak_re');
    cfg.id = 'sw07_test_density_re_general';
    cfg.density = struct('enabled', true, 'shocks', {shocks}, 'ndraws', 10, 'keep_draws', true, ...
        'fast_path', false);
    rg = hetlearn.run(cfg, 'save', false, 'quiet', true);
    Df = out.tsw07_peak_re;
    mx = 0;
    for i = 1:numel(Df.names)
        a = Df.draws.series.(Df.names{i})(:, 1:10);
        mx = max(mx, max(abs(a(:) - reshape(rg.density.draws.series.(Df.names{i}), [], 1))));
    end
    fprintf('D9 tsw07_peak_re general path: %.3f s per draw; max diff to the fast path (10 draws) %.2g\n', ...
        rg.density.s_per_draw, mx);
    % bands
    ok = mx < 1e-8;
    for i = 1:numel(ids)
        D = out.(ids{i});
        p = D.quantiles;
        iq = [find(abs(p - 0.05) < 1e-12), find(abs(p - 0.5) < 1e-12), find(abs(p - 0.95) < 1e-12)];
        z = D.series.pinfobs;
        n2 = D.series.n2_model_pinf;
        for t = dts
            k = find(hetlearn.util.date_eq(D.dates, t));
            fprintf('D9 %-22s %s: 4*pinfobs 5/50/95%% = %6.2f %6.2f %6.2f (point %6.2f); n2 5/50/95%% = %.3f %.3f %.3f\n', ...
                ids{i}, char(dat2str(t)), z.q_report(k, iq), z.point_report(k), n2.q(k, iq));
        end
        ok = ok && D.n_used >= 95 && ordered(D) && all(isfinite(z.q(:))) ...
            && all(n2.q(:) >= 0 & n2.q(:) <= 1);
        od = fullfile(outDir, ids{i});
        ok = ok && exist(fullfile(od, 'density.mat'), 'file') == 2 ...
            && exist(fullfile(od, 'density_quantiles.csv'), 'file') == 2 ...
            && exist(fullfile(od, 'density_events.csv'), 'file') == 2;
    end
    Dr = out.tsw07_peak_re;
    z = Dr.series.pinfobs;
    worst = max(abs(z.mean - z.point) ./ max(z.std / sqrt(Dr.n_used), 1e-12));
    ok = ok && worst <= 4 && strcmp(Dr.path, 'fast') && strcmp(out.tsw07_switch_pinf.path, 'general');
    R = add(R, 'density D9: SW07 smoke (tsw07_peak_re fast path, tsw07_switch_pinf general path; 7 shocks, 100 draws)', ok, ...
        sprintf(['%.3f / %.3f s per draw (RE fast / switching general), RE general %.3f s per draw (= fast to %.1g); ' ...
        'RE mean within %.2f s.e.; used %d / %d'], Dr.s_per_draw, out.tsw07_switch_pinf.s_per_draw, ...
        rg.density.s_per_draw, mx, worst, Dr.n_used, out.tsw07_switch_pinf.n_used));
catch err
    R = add(R, 'density D9: SW07 smoke (tsw07_peak_re fast path, tsw07_switch_pinf general path; 7 shocks, 100 draws)', ...
        false, err.message);
end
end


% =========================================================================
function o = setf(o, varargin)
for i = 1:2:numel(varargin)
    o.(varargin{i}) = varargin{i + 1};
end
end


function [ok, txt] = std_ok(E, tgt)
ok = true;
z = zeros(1, numel(tgt));
for s = 1:numel(tgt)
    v = E(:, s, :);
    n = numel(v);
    se = tgt(s) / sqrt(2 * n);
    z(s) = (std(v(:)) - tgt(s)) / se;
    ok = ok && abs(z(s)) <= 4;
end
txt = sprintf('std errors in s.e. units: %s', mat2str(z, 3));
end


function ok = ordered(D)
ok = true;
for i = 1:numel(D.names)
    q = D.series.(D.names{i}).q;
    ok = ok && all(all(diff(q, 1, 2) >= -1e-12));
end
end


function v = rmnan(v)
v = v(isfinite(v));
end


function s = first_line(file)
fid = fopen(file, 'r');
c = onCleanup(@() fclose(fid));
s = fgetl(fid);
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
