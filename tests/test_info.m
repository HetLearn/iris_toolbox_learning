function R = test_info(part)
%TEST_INFO  BR information set beliefs.info = 'lagged' | 'current' (review s5, user question D2).
%
%   R = test_info()         toy checks I1-I4, then the SW07 checks I5-I6
%   R = test_info('toy')    toy checks only
%   R = test_info('sw07')   SW07 checks only
%
%   I1 forecast_expr: 'current' gives alpha_x + beta_x*x (AR(1)), alpha + b1*x +
%      b2*x{-1} (AR(2)), alpha + B*X_t (VAR(1)), current-dated derived regressors;
%      'lagged' (the default) is the old text; a bad info set is an error
%   I2 generated toy file: both BR forms under !if br_info_current, generator
%      version 4, collapse test with br_info_current = true; load_model sets the
%      toggle from beliefs.info
%   I3 toy, 'current': hetlearn.plm.forecast_value = IRIS x_exp1_BR after a
%      one-period simulation (random beliefs, n2 = 0.5) for AR(1), AR(2), VAR(1)
%      and a derived regressor
%   I4 toy switching run with 'current' (y, pie): the engine's timing assert
%      holds; fBR_t = alpha_{t-1} + beta_{t-1}*x_t in the forecast and at the
%      origin (smoothed x_t); FE_BR_t = (x_t - fBR_{t-1})^2; beliefs at the
%      origin equal those of the 'lagged' run (RLS timing unchanged), shares differ
%   I5 SW07 tsw07_switch_pinf (default 'lagged') = tests/reference/ (max abs diff,
%      paths and learning states; the live master_options calibration)
%   I6 SW07 smoke: tsw07_switch_pinf with 'current' (n2 at the origin,
%      inflation path, average); beliefs at the origin equal the 'lagged' run
%   Runs go to tests/output/results/.

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
outDir = fullfile(here, 'output', 'results');
if any(strcmp(part, {'all', 'toy'}))
    R = toy_checks(R, here, outDir);
end
if any(strcmp(part, {'all', 'sw07'}))
    R = sw07_checks(R, here, root, outDir);
end
end


% =========================================================================
function R = toy_checks(R, here, outDir)
toyDir = fullfile(here, 'toy_nk');
spec = hetlearn.load_spec(toyDir);
allv = {'y', 'pie', 'r', 'g', 'u', 'dy_e', 'r_e'};
plmD = struct('default', 'ar1', 'by_var', struct('pie', struct('regressors', {{'pie{-1}', 'rgap{-1}'}})), ...
    'derived', struct('rgap', 'r - pie'));
plmV = struct('default', 'ar1', 'var', struct('variables', {{'y', 'pie'}}, 'lags', 1, 'constant', true));

% ---- I1: expression text ----------------------------------------------------------------
nm = 'info I1: forecast_expr current = alpha + beta*x (AR1), AR(2), VAR(1), derived; lagged unchanged';
try
    s1 = hetlearn.plm.build_system('ar1', {'pie'}, allv, 'current');
    s0 = hetlearn.plm.build_system('ar1', {'pie'}, allv);
    s2 = hetlearn.plm.build_system('ar2', {'pie'}, allv, 'current');
    sV = hetlearn.plm.build_system(plmV, {'y', 'pie'}, allv, 'current');
    sD = hetlearn.plm.build_system(plmD, {'pie'}, allv, 'current');
    want = {
        hetlearn.plm.forecast_expr(s1, 'pie'), 'alpha_pie + beta_pie*pie'
        hetlearn.plm.forecast_expr(s1, 'pie', 'lagged'), 'alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1})'
        hetlearn.plm.forecast_expr(s0, 'pie'), 'alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1})'
        hetlearn.plm.forecast_expr(s2, 'pie'), 'alpha_pie + beta_pie__pie_l1*pie + beta_pie__pie_l2*pie{-1}'
        hetlearn.plm.forecast_expr(sV, 'pie'), 'alpha_pie + beta_pie__y_l1*y + beta_pie__pie_l1*pie'
        hetlearn.plm.forecast_expr(sD, 'pie'), 'alpha_pie + beta_pie__pie_l1*pie + beta_pie__rgap_l1*rgap'
        };
    ok = all(cellfun(@strcmp, want(:, 1), want(:, 2))) && strcmp(s0.info, 'lagged') && strcmp(s1.info, 'current');
    bad = want(~cellfun(@strcmp, want(:, 1), want(:, 2)), 1);
    R = add(R, nm, ok, strjoin([{sprintf('%d of %d texts as expected', size(want, 1) - numel(bad), size(want, 1))}, bad'], ' | '));
catch err
    R = add(R, nm, false, err.message);
end
R = expect_error(R, 'info I1: build_system rejects an unknown information set', 'hetlearn:plm:info', ...
    @() hetlearn.plm.build_system('ar1', {'pie'}, allv, 'future'));
R = expect_error(R, 'info I1: load_options rejects beliefs.info = ''t+1''', 'hetlearn:options', ...
    @() hetlearn.load_options(struct('id', 'x', 'beliefs', struct('info', 't+1')), struct()));

% ---- I2: generated file and toggle -----------------------------------------------------------
nm = 'info I2: generated file has both BR forms under !if br_info_current; collapse with info current';
try
    meta = hetlearn.extend_model(spec, 'ar1');
    txt = fileread(meta.ext_file);
    blk = sprintf(['        !if br_info_current\n            pie_exp1_BR = alpha_pie + beta_pie*pie;\n', ...
        '        !else\n            pie_exp1_BR = alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1});\n        !end']);
    ok = contains(txt, blk) && meta.generator_version == 4 && strcmp(meta.info_toggle, 'br_info_current') ...
        && meta.validated && meta.collapse_info_maxdiff < 1e-10 && all(meta.collapse_maxdiff < 1e-10);
    R = add(R, nm, ok, sprintf('collapse %s, info current %.1e', mat2str(meta.collapse_maxdiff, 2), ...
        meta.collapse_info_maxdiff));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'info I2: load_model sets br_info_current from beliefs.info; sys.info recorded';
try
    o1 = base_opts(toyDir, {'pie'}, 'ar1', 'current');
    o0 = base_opts(toyDir, {'pie'}, 'ar1', '');
    [~, i1] = hetlearn.load_model(spec, o1);
    [~, i0] = hetlearn.load_model(spec, o0);
    ok = i1.assign.br_info_current == true && i0.assign.br_info_current == false ...
        && strcmp(i1.sys.info, 'current') && strcmp(i0.sys.info, 'lagged');
    R = add(R, nm, ok, sprintf('current: toggle %d, sys.info %s; default: toggle %d, sys.info %s', ...
        i1.assign.br_info_current, i1.sys.info, i0.assign.br_info_current, i0.sys.info));
catch err
    R = add(R, nm, false, err.message);
end

% ---- I3: forecast_value = IRIS x_exp1_BR under 'current' ---------------------------------------
cases = {'AR(1)', 'ar1', {'pie'}; 'AR(2)', struct('default', 'ar2'), {'pie'}; ...
    'VAR(1)', struct('default', 'var1'), {'y', 'pie'}; 'derived rgap = r - pie', plmD, {'pie'}};
rng(7);
for c = 1:size(cases, 1)
    nm = sprintf('info I3: forecast_value = IRIS x_exp1_BR under ''current'', %s (n2 = 0.5, random beliefs)', cases{c, 1});
    try
        lv = cases{c, 3};
        [m, info] = hetlearn.load_model(spec, base_opts(toyDir, lv, cases{c, 2}, 'current'));
        sys = info.sys;
        phi = struct();
        for i = 1:numel(sys.eq)
            e = sys.eq(i);
            v = 0.2 * randn(numel(e.param_names), 1);
            if e.constant
                v(1) = 0.1 * randn;
            end
            phi.(e.target) = v;
        end
        P = hetlearn.plm.param_values(sys, phi);
        for i = 1:numel(lv)
            P.(['n1_' lv{i}]) = 0.5;
            P.(['n2_' lv{i}]) = 0.5;
        end
        m = assign(m, P);
        [m, flag] = solve(m);
        t = qq(2021, 1);
        d = zerodb(m, t-4:t);
        xl = cellstr(get(m, 'xList'));
        for i = 1:numel(xl)
            d.(xl{i})(t-4:t-1) = 0.5 * randn(4, 1);
        end
        el = cellstr(get(m, 'eList'));
        for i = 1:numel(el)
            d.(el{i})(t) = randn;
        end
        s = simulate(m, d, t:t, 'anticipate', false, 'prependInput', true);
        dmax = 0;
        for i = 1:numel(lv)
            fm = s.([lv{i} '_exp1_BR'])(t);
            fv = hetlearn.plm.forecast_value(sys, phi, @(n, k) s.(n)(t + k), lv{i});
            fl = hetlearn.plm.forecast_value(sys, phi, @(n, k) s.(n)(t + k), lv{i}, 'lagged');
            dmax = max([dmax, abs(fm - fv)]);
        end
        ok = hasSucceeded(flag) && dmax < 1e-12 && abs(fl - fv) > 1e-6;
        R = add(R, nm, ok, sprintf('max |model - forecast_value| %.2g (lagged form differs by %.2g)', dmax, abs(fl - fv)));
    catch err
        R = add(R, nm, false, err.message);
    end
end

% ---- I4: end-to-end toy switching run --------------------------------------------------------------
nm = 'info I4: toy switching (y, pie) with ''current'': timing assert holds, fBR_t = alpha_{t-1} + beta_{t-1}*x_t';
try
    hz = qq(2021, 1):qq(2023, 4);
    org = qq(2020, 4);
    rng(11);
    cfg = struct();
    cfg.model = toyDir;
    cfg.forecast = struct('origin', org, 'horizon', 12);
    cfg.expectations = struct('mode', 'switching', 'variables', {{'y', 'pie'}});
    cfg.switching.intensity = 0.25;
    cfg.shocks.add = {{'e_g', hz, randn(12, 1)}, {'e_u', hz, 0.5 * randn(12, 1)}};
    cfg.id = 'toy_info_switch_lagged';
    resL = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
    cfg.id = 'toy_info_switch_current';
    cfg.beliefs.info = 'current';
    res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
    H = hetlearn.re_filter(spec, hetlearn.load_options(cfg, struct()));
    dB = 0;
    dFE = 0;
    dO = 0;
    dPhi = 0;
    for x = {'y', 'pie'}
        L = res.learning.(x{1});
        a = res.learning.(x{1}).(['alpha_' x{1}]);
        b = res.learning.(x{1}).(['beta_' x{1}]);
        xt = res.paths.(x{1});
        dB = max([dB; abs(L.fBR(hz) - (a(hz - 1) + b(hz - 1) .* xt(hz)))]);
        dFE = max([dFE; abs(L.FE_BR(hz) - (xt(hz) - L.fBR(hz - 1)).^2)]);
        dO = max([dO; abs(L.fBR(org) - (a(org - 1) + b(org - 1) * H.smooth.(x{1})(org)))]);
        aL = resL.learning.(x{1}).(['alpha_' x{1}]);
        bL = resL.learning.(x{1}).(['beta_' x{1}]);
        dPhi = max([dPhi, abs(a(org) - aL(org)), abs(b(org) - bL(org))]);
    end
    dn2 = abs(res.learning.pie.n2(org) - resL.learning.pie.n2(org));
    R = add(R, nm, dB < 1e-10 && dO < 1e-10, sprintf('forecast %.2g, origin (smoothed x_t) %.2g', dB, dO));
    R = add(R, 'info I4: FE_BR_t = (x_t - fBR_{t-1})^2 under ''current'' (forecast made in t-1)', ...
        dFE < 1e-10, sprintf('max diff %.2g', dFE));
    R = add(R, 'info I4: beliefs at the origin equal the ''lagged'' run (RLS unchanged); shares differ', ...
        dPhi < 1e-12 && dn2 > 1e-8, sprintf('phi diff %.2g, n2_pie at origin %.6f (current) vs %.6f (lagged)', ...
        dPhi, res.learning.pie.n2(org), resL.learning.pie.n2(org)));
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
nm = 'info I5: tsw07_switch_pinf (beliefs.info lagged, fast step) = tests/reference/tsw07_switch_pinf_iris.mat to 1e-10';
resL = [];
try
    cfg = tsw07_switch_pinf();
    cfg.compare_with = {};
    resL = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
    B = load(fullfile(here, 'reference', 'tsw07_switch_pinf_iris.mat'), 'ref');
    [d, worst] = ref_maxdiff(resL, B.ref);
    fprintf('INFO-I5 | tsw07_switch_pinf vs tests/reference: max abs diff %.3g (%s)\n', d, worst);
    R = add(R, nm, d < 1e-10, sprintf('max abs diff %.3g (%s)', d, worst));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'info I6: SW07 smoke tsw07_switch_pinf with beliefs.info = ''current''';
try
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_switch_pinf_info_current';
    cfg.compare_with = {};
    cfg.beliefs.info = 'current';
    [r, row] = sw07_smoke_run(cfg, 'switch pinf, info current', outDir);
    R = [R, r];
    C = load(fullfile(outDir, cfg.id, 'results.mat'), 'res');
    L = C.res.learning.pinf;
    msg = sprintf('n2_pinf at 2022Q2 %.6f (n1_model 2022Q3 %.6f); avg infl %.2f%%; path %s', L.n2(org), ...
        L.n1_model(hz(1)), row.avg_infl, strjoin(arrayfun(@(v) sprintf('%.2f', v), row.infl', 'UniformOutput', false), ' '));
    fprintf('INFO-I6 | %s\n', msg);
    if ~isempty(resL)
        LL = resL.learning.pinf;
        dPhi = max(abs([L.alpha_pinf(org) - LL.alpha_pinf(org), L.beta_pinf(org) - LL.beta_pinf(org)]));
        fprintf('INFO-I6 | lagged run: n2_pinf at 2022Q2 %.6f, avg infl %.2f%%; phi at origin diff %.3g\n', ...
            LL.n2(org), mean(4 * resL.paths.pinfobs(hz)), dPhi);
        R = add(R, 'info I6: SW07 beliefs at the origin equal the lagged run (RLS unchanged)', dPhi < 1e-10, ...
            sprintf('phi diff %.3g; n2 at origin %.6f current vs %.6f lagged', dPhi, L.n2(org), LL.n2(org)));
    end
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function o = base_opts(toyDir, lv, plm, info)
cfg = struct('id', 'toy_info', 'model', toyDir);
cfg.forecast = struct('origin', qq(2020, 4), 'horizon', 4);
cfg.expectations = struct('mode', 'fixed_shares', 'variables', {lv});
cfg.shares.fixed_n2 = 0.5;
if ischar(plm)
    plm = struct('default', plm);
end
cfg.beliefs.plm = plm;
if ~isempty(info)
    cfg.beliefs.info = info;
end
o = hetlearn.load_options(cfg, struct());
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
for g = 1:size(groups, 1)
    a = groups{g, 2};
    b = groups{g, 3};
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
            worst = [groups{g, 1} '.' fn{j}];
        end
    end
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
