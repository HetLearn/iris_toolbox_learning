function R = test_evaluate(part)
%TEST_EVALUATE  Recursive forecast evaluation (DESIGN 17): toy checks V1-V3, SW07 smoke V4.
%
%   R = test_evaluate()          all checks
%   R = test_evaluate('toy')     V1-V3 only;  test_evaluate('sw07')  V4 only
%
%   Returns a struct array of checks (name, pass, msg).
%
%   V1 toy evaluation (2 variants, 24 origins, H = 4, a subsample): output
%      files; errors = hand-computed actual - forecast of separate real-time
%      runs for three origins; RMSE/ME/MAE and relative RMSE from errors_long;
%      benchmark relative RMSE = 1
%   V2 Diebold-Mariano: h = 1 statistic and p-value by hand (no lags); h = 3
%      with the Newey-West (2 lags) variance by hand
%   V3 real-time property: changing the data after an origin leaves that
%      origin's forecast unchanged (history.realtime = true), changing the
%      data at the origin changes it; the truncated-filter cache key ignores
%      data after the origin
%   V4 SW07 smoke: origins 2010Q1-2024Q2, H = 8, variants tsw07_peak_re and
%      tsw07_switch_pinf; prints the inflation RMSE at h = 1, 4, 8 and the
%      runtime
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
    R = sw07_checks(R, outDir);
end
end


% =========================================================================
function R = toy_checks(R, here, outDir)
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
spec = hetlearn.load_spec(toyDir);
db = hetlearn.load_database(spec);
base = struct();
base.model = toyDir;
base.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
base.expectations = struct('mode', 'rational', 'variables', {{'y', 'pie'}});
cRE = base;
cRE.id = 'toy_ev_re';
cSW = base;
cSW.id = 'toy_ev_sw';
cSW.expectations.mode = 'switching';
cSW.switching.intensity = 0.25;
origins = [qq(2015, 1), qq(2020, 4)];
H = 4;

% ---- V1 -----------------------------------------------------------------------------------
E = [];
try
    E = hetlearn.evaluate('toy_v1', {cRE, cSW}, origins, struct('horizon', H, 'dm_hln', false, ...
        'results_dir', outDir, 'quiet', true, 'subsamples', struct('late', [qq(2019, 1), qq(2021, 4)])));
    od = fullfile(outDir, 'eval_toy_v1');
    files = all(cellfun(@(f) exist(fullfile(od, f), 'file') == 2, ...
        {'errors_long.csv', 'metrics.csv', 'relative_rmse.csv', 'dm.csv', 'settings.mat'}));
    % hand-computed errors of separate real-time runs
    worst = 0;
    nChk = 0;
    for o = [qq(2015, 1), qq(2017, 3), qq(2020, 4)]
        for c = {cRE, cSW}
            cfg = c{1};
            cfg.forecast.origin = o;
            cfg.forecast.horizon = H;
            cfg.history.realtime = true;
            res = hetlearn.run(cfg, 'save', false, 'quiet', true);
            for i = 1:numel(spec.observables)
                v = spec.observables{i};
                for h = 1:H
                    e = db.(v)(o + h) - res.paths.(v)(o + h);       % toy report scale = 1
                    sel = strcmp(E.errors.variant, cfg.id) & strcmp(E.errors.origin, char(dat2str(o))) ...
                        & E.errors.h == h & strcmp(E.errors.variable, v);
                    if sum(sel) ~= 1
                        worst = Inf;
                    else
                        worst = max(worst, abs(E.errors.error(sel) - e));
                    end
                    nChk = nChk + 1;
                end
            end
        end
    end
    % metrics from errors_long
    sel = strcmp(E.errors.variant, 'toy_ev_sw') & strcmp(E.errors.variable, 'obs_pie') & E.errors.h == 2;
    e = E.errors.error(sel);
    m = E.metrics(strcmp(E.metrics.sample, 'full') & strcmp(E.metrics.variant, 'toy_ev_sw') ...
        & strcmp(E.metrics.variable, 'obs_pie') & E.metrics.h == 2, :);
    mOK = abs(m.rmse - sqrt(mean(e .^ 2))) < 1e-12 && abs(m.me - mean(e)) < 1e-12 ...
        && abs(m.mae - mean(abs(e))) < 1e-12 && m.n == 24;
    selB = strcmp(E.errors.variant, 'toy_ev_re') & strcmp(E.errors.variable, 'obs_pie') & E.errors.h == 2;
    rr = E.relative_rmse(strcmp(E.relative_rmse.sample, 'full') & strcmp(E.relative_rmse.variable, 'obs_pie') ...
        & E.relative_rmse.h == 2, :);
    relOK = abs(rr.relative_rmse(strcmp(rr.variant, 'toy_ev_sw')) ...
        - sqrt(mean(e .^ 2)) / sqrt(mean(E.errors.error(selB) .^ 2))) < 1e-12 ...
        && all(E.relative_rmse.relative_rmse(strcmp(E.relative_rmse.variant, 'toy_ev_re') ...
        & E.relative_rmse.n > 0) == 1);
    late = E.metrics(strcmp(E.metrics.sample, 'late') & strcmp(E.metrics.variant, 'toy_ev_re') ...
        & strcmp(E.metrics.variable, 'obs_y'), :);
    lateOK = isequal(late.n', [9 10 11 12]);      % targets 2019Q1-2021Q4 from origins 2015Q1-2020Q4
    ok = files && worst < 1e-12 && nChk == 72 && mOK && relOK && lateOK && isempty(E.settings.failures);
    R = add(R, 'evaluate V1: outputs; errors = actual - forecast of separate real-time runs; metrics and relative RMSE', ok, ...
        sprintf('files %d, %d errors checked (max diff %.2g), metrics %d, relative %d, subsample n %s', files, ...
        nChk, worst, mOK, relOK, mat2str(late.n')));
catch err
    R = add(R, 'evaluate V1: outputs; errors = actual - forecast of separate real-time runs; metrics and relative RMSE', ...
        false, err.message);
end

% ---- V2: DM by hand -------------------------------------------------------------------------------
try
    ok = ~isempty(E);
    txt = '';
    for h = [1 3]
        a = E.errors(strcmp(E.errors.variant, 'toy_ev_sw') & strcmp(E.errors.variable, 'obs_y') & E.errors.h == h, :);
        bm = E.errors(strcmp(E.errors.variant, 'toy_ev_re') & strcmp(E.errors.variable, 'obs_y') & E.errors.h == h, :);
        assert(isequal(a.origin, bm.origin), 'origins differ');
        d = a.error .^ 2 - bm.error .^ 2;
        n = numel(d);
        u = d - mean(d);
        lrv = sum(u .^ 2) / n;
        for k = 1:h - 1
            lrv = lrv + 2 * (1 - k / h) * sum(u(k + 1:end) .* u(1:end - k)) / n;
        end
        st = mean(d) / sqrt(lrv / n);
        pv = erfc(abs(st) / sqrt(2));
        row = E.dm(strcmp(E.dm.sample, 'full') & strcmp(E.dm.variable, 'obs_y') & E.dm.h == h, :);
        ok = ok && height(row) == 1 && abs(row.dm_stat - st) < 1e-10 && abs(row.p_value - pv) < 1e-10 ...
            && row.n == n;
        txt = sprintf('%sh=%d: DM %.4f p %.4f (n %d); ', txt, h, st, pv, n);
    end
    pOK = all(E.dm.p_value >= 0 & E.dm.p_value <= 1) && all(strcmp(E.dm.kernel, 'bartlett'));
    R = add(R, 'evaluate V2a: Bartlett path (dm_hln false): DM statistic and p-value = hand computation (h=1; h=3 with NW, 2 lags)', ...
        ok && pOK, txt);
catch err
    R = add(R, 'evaluate V2a: Bartlett path (dm_hln false): DM statistic and p-value = hand computation (h=1; h=3 with NW, 2 lags)', false, err.message);
end
% ---- V2b: new default (dm_hln true -> uniform kernel), tables rebuilt from errors_long ----------
nm = ['evaluate V2b: evaluate_tables from errors_long.csv: default uniform kernel + HLN = hand computation ' ...
    '(h=1, 3); metrics and the Bartlett DM rebuilt exactly'];
try
    od = fullfile(outDir, 'eval_toy_v1');
    T2 = hetlearn.evaluate_tables(fullfile(od, 'errors_long.csv'));
    T3 = hetlearn.evaluate_tables(od, struct('dm_hln', false, 'dm_kernel', 'bartlett'));
    ok = strcmp(T2.info.dm_kernel, 'uniform') && T2.info.dm_hln;
    txt = '';
    for h = [1 3]
        a = E.errors(strcmp(E.errors.variant, 'toy_ev_sw') & strcmp(E.errors.variable, 'obs_y') & E.errors.h == h, :);
        bm = E.errors(strcmp(E.errors.variant, 'toy_ev_re') & strcmp(E.errors.variable, 'obs_y') & E.errors.h == h, :);
        d = a.error .^ 2 - bm.error .^ 2;
        n = numel(d);
        u = d - mean(d);
        lrv = sum(u .^ 2) / n;
        for k = 1:h - 1
            lrv = lrv + 2 * sum(u(k + 1:end) .* u(1:end - k)) / n;     % rectangular weights
        end
        kern = 'uniform';
        if ~(lrv > 0)
            kern = 'bartlett_fallback';
            lrv = sum(u .^ 2) / n;
            for k = 1:h - 1
                lrv = lrv + 2 * (1 - k / h) * sum(u(k + 1:end) .* u(1:end - k)) / n;
            end
        end
        st = mean(d) / sqrt(lrv / n) * sqrt((n + 1 - 2 * h + h * (h - 1) / n) / n);
        pv = betainc((n - 1) / (n - 1 + st ^ 2), (n - 1) / 2, 0.5);
        row = T2.dm(strcmp(T2.dm.sample, 'full') & strcmp(T2.dm.variable, 'obs_y') & T2.dm.h == h, :);
        ok = ok && height(row) == 1 && abs(row.dm_stat - st) < 1e-10 && abs(row.p_value - pv) < 1e-10 ...
            && strcmp(row.kernel{1}, kern);
        txt = sprintf('%sh=%d: DM %.4f p %.4f (%s); ', txt, h, st, pv, kern);
    end
    dMet = max(abs([T2.metrics.rmse - E.metrics.rmse; T2.metrics.me - E.metrics.me]), [], 'omitnan');
    sameN = isequal(T2.metrics.n, E.metrics.n) && isequal(T2.relative_rmse.relative_rmse(isfinite(E.relative_rmse.relative_rmse)), ...
        E.relative_rmse.relative_rmse(isfinite(E.relative_rmse.relative_rmse)));
    dB = max(abs([T3.dm.dm_stat - E.dm.dm_stat; T3.dm.p_value - E.dm.p_value]), [], 'omitnan');
    ok = ok && dMet == 0 && sameN && dB == 0 && T2.info.dm_fallbacks == sum(strcmp(T2.dm.kernel, 'bartlett_fallback'));
    R = add(R, nm, ok, sprintf('%smetrics diff %.2g, Bartlett DM rebuilt diff %.2g, %d fallbacks of %d', ...
        txt, dMet, dB, T2.info.dm_fallbacks, height(T2.dm)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- V3: real-time property ---------------------------------------------------------------------
try
    % A = the toy data, B = A + 1 on every value dated after the origin,
    % C = A + 0.1 on the values dated at the origin (positive control). In
    % the toy model (3 shocks, 3 observables, no measurement error) the
    % full-sample smoother at dates <= t does not use later data either
    % (differences ~1e-14), so the full-sample contrast is only reported;
    % control C gives the check its power.
    o = qq(2018, 4);
    src = fullfile(toyDir, spec.database);
    csv = fullfile(here, 'output', {'toy_rt_a.csv', 'toy_rt_b.csv', 'toy_rt_c.csv'});
    perturb_csv(src, csv{1}, o + 1, Inf, 0);
    perturb_csv(src, csv{2}, o + 1, Inf, 1);
    perturb_csv(src, csv{3}, o, o, 0.1);
    cfg = cRE;
    cfg.id = 'toy_ev_rt';
    cfg.expectations.mode = 'switching';
    cfg.switching.intensity = 0.25;
    cfg.forecast.origin = o;
    cfg.forecast.horizon = 8;
    opts = hetlearn.load_options(cfg);
    [m, info] = hetlearn.load_model(spec, opts);
    r = cell(1, 3);
    rf = cell(1, 2);
    for j = 1:3
        sj = spec;
        sj.database = csv{j};
        Mj = struct('spec', sj, 'm', m, 'info', info);
        clear_rt_cache(spec.folder);
        cfg.history.realtime = true;
        r{j} = hetlearn.run(cfg, 'save', false, 'quiet', true, 'model', Mj);
        if j <= 2
            cfg.history.realtime = false;
            rf{j} = hetlearn.run(cfg, 'save', false, 'quiet', true, 'model', Mj);
        end
    end
    hz = r{1}.dates.horizon;
    names = [info.xList(:); info.yList(:)]';
    dAfter = maxdiff(r{1}.paths, r{2}.paths, names, hz);
    dAt = maxdiff(r{1}.paths, r{3}.paths, names, hz);
    dFull = maxdiff(rf{1}.paths, rf{2}.paths, names, hz);
    sB = spec;
    sB.database = csv{2};
    dbB = hetlearn.load_database(sB);
    dataChanged = abs(dbB.obs_pie(o + 1) - db.obs_pie(o + 1) - 1) < 1e-9 ...
        && dbB.obs_pie(o) == db.obs_pie(o);
    sameKey = strcmp(r{1}.meta.refilter_hash, r{2}.meta.refilter_hash) ...
        && ~strcmp(r{1}.meta.refilter_hash, r{3}.meta.refilter_hash);
    endOK = hetlearn.util.date_eq(r{1}.meta.refilter_end, o) && r{1}.meta.refilter_realtime ...
        && ~rf{1}.meta.refilter_realtime;
    ok = dAfter == 0 && dAt > 1e-6 && dataChanged && sameKey && endOK;
    R = add(R, 'evaluate V3: real time: data changed after the origin leave its forecast unchanged; data at the origin change it', ok, ...
        sprintf(['max diff: data after the origin %.2g, data at the origin %.3g (control), full-sample ' ...
        'filter with data after the origin %.2g (info); same cache key %d, filter end %s'], dAfter, dAt, ...
        dFull, sameKey, char(dat2str(r{1}.meta.refilter_end))));
catch err
    R = add(R, 'evaluate V3: real time: data changed after the origin leave its forecast unchanged; data at the origin change it', ...
        false, err.message);
end
end


% =========================================================================
function R = sw07_checks(R, outDir)
try
    t = tic;
    E = hetlearn.evaluate('sw07_smoke', {'tsw07_peak_re', 'tsw07_switch_pinf'}, ...
        [qq(2010, 1), qq(2024, 2)], struct('horizon', 8, 'results_dir', outDir));
    rt = toc(t);
    T = E.metrics(strcmp(E.metrics.sample, 'full') & strcmp(E.metrics.variable, 'pinfobs'), :);
    ids = {'tsw07_peak_re', 'tsw07_switch_pinf'};
    txt = '';
    ok = isempty(E.settings.failures) && E.settings.n_runs == 116;
    for v = 1:2
        x = T(strcmp(T.variant, ids{v}), :);
        r = x.rmse([1 4 8]);
        fprintf('V4 %-22s inflation RMSE (annualised pp): h=1 %.3f, h=4 %.3f, h=8 %.3f (n %s)\n', ...
            ids{v}, r, mat2str(x.n([1 4 8])'));
        txt = sprintf('%s%s RMSE h1/h4/h8 %.3f/%.3f/%.3f; ', txt, ids{v}, r);
        ok = ok && all(x.n == 58) && all(isfinite(x.rmse) & x.rmse > 0);
    end
    rel = E.relative_rmse.relative_rmse(strcmp(E.relative_rmse.variant, 'tsw07_peak_re'));
    ok = ok && all(abs(rel - 1) < 1e-12 | isnan(rel));
    fprintf('V4 evaluation runtime %.1f s (filters %.1f s, runs %.1f s)\n', rt, ...
        E.settings.runtime_filters_s, E.settings.runtime_runs_s);
    R = add(R, 'evaluate V4: SW07 smoke, origins 2010Q1-2024Q2, H = 8, tsw07_peak_re vs tsw07_switch_pinf', ok, ...
        sprintf('%s%.1f s', txt, rt));
catch err
    R = add(R, 'evaluate V4: SW07 smoke, origins 2010Q1-2024Q2, H = 8, tsw07_peak_re vs tsw07_switch_pinf', ...
        false, err.message);
end
end


% =========================================================================
function perturb_csv(src, dst, d1, d2, delta)
% Copy a databank.toCSV file, adding delta to every value dated in
% [d1, d2] (d2 may be Inf); all other text is copied unchanged.
txt = fileread(src);
lines = regexp(txt, '\r?\n', 'split');
for i = 1:numel(lines)
    tok = regexp(lines{i}, '^"?(\d{4})Q([1-4])"?,', 'tokens', 'once');
    if isempty(tok) || delta == 0
        continue
    end
    t = double(qq(str2double(tok{1}), str2double(tok{2})));
    if t < double(d1) - 1e-6 || t > double(d2) + 1e-6
        continue
    end
    parts = strsplit(lines{i}, ',');
    for j = 2:numel(parts)
        v = str2double(parts{j});
        if isfinite(v)
            parts{j} = sprintf('%.17g', v + delta);
        end
    end
    lines{i} = strjoin(parts, ',');
end
fid = fopen(dst, 'w');
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', strjoin(lines, newline));
end


function clear_rt_cache(folder)
f = dir(fullfile(folder, 'generated', 'refilter_rt_*.mat'));
for i = 1:numel(f)
    delete(fullfile(f(i).folder, f(i).name));
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
