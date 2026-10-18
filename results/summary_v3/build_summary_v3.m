%BUILD_SUMMARY_V3  Summary tables, checks and memo numbers of the SW07 applications (track H1, 2026-10-18).
%
%   run('results/summary_v3/build_summary_v3.m')      from the project root, after run_applications
%
%   Reads   results/<id>/results.mat (+ density.mat, decomposition.csv, decomposition_check.csv),
%           results/run_log.csv, results/eval_sw07_v3/ (merged tables and parts), the database and
%           the original SW07 model (models/sw07/sw07.model, for the RE checks). Runs two 10-draw
%           density checks (not saved).
%   Writes  results/summary_v3/: scenarios.csv, paths_long.csv, learning_long.csv, events_long.csv,
%           app3_policy.csv, app4_losses.csv, app5_density.csv, app5_widths.csv,
%           app6_decomp_long.csv, app6_shocks_long.csv, v3_facility.csv, eval_metrics.csv,
%           eval_relative.csv, eval_dm.csv, key_numbers.csv, checks_v3.txt.
%   Units   report units = model units x spec.report.scale (pinfobs, robs, dy, dc: x 4, annualised).
%           learning_long: shares, belief parameters and gains in model units; persistence = the
%           largest root of the PLM block; perceived_mean = the mean implied by the PLM block, model
%           units (deviation from the steady state, as the PLM sees it); perceived_mean_report
%           (targets pinf and r only) = scale x (perceived mean + steady state), annualised percent.
%           Rows whose value is not finite are left out (n2_model on the RE-smoothed history).

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % run() executes from the script folder
if exist(fullfile(root, 'run_applications.m'), 'file') ~= 2
    root = pwd;
end
if exist(fullfile(root, 'run_applications.m'), 'file') ~= 2
    error('build_summary_v3: cannot find the project root (run it from the root).');
end
addpath(root);
setup_paths;
tAll = tic;
out = fullfile(root, 'results', 'summary_v3');
rdir = fullfile(root, 'results');
gdir = fullfile(rdir, 'eval_sw07_v3');
spec = hetlearn.load_spec('sw07');
db = hetlearn.load_database(spec);
sc = spec.report.scale;
addpath(spec.folder);                            % sw07_params.m
P = feval(spec.params);
m0 = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', spec.linear);
m0 = assign(m0, P);
[m0, flag0] = solve(m0); %#ok<ASGLU>
m0 = sstate(m0);
SSv = struct('pinf', ss_value(m0, 'pinfobs', P.constepinf), 'r', ss_value(m0, 'robs', NaN));
SSobs = struct('pinf', 'pinfobs', 'r', 'robs');
rep = @(s, n) repmat({s}, n, 1);
col = @(c) reshape(c, [], 1);
dstr = @(d) reshape(hetlearn.util.date_str(d), [], 1);
K = cell(0, 4);                                  % key numbers: name, value, unit, description
CH = cell(0, 3);                                 % checks: name, pass, detail

% ---- scenarios -------------------------------------------------------------------------------
SC = {
    'a1_re', 'app1_peak', 'app1', 'RE'
    'a1_learn', 'app1_peak', 'app1', 'Learning (inflation)'
    'a2_re', 'app2_replay', 'app2', 'RE replay'
    'a2_learn', 'app2_replay', 'app2', 'Learning replay'
    'a3_loose_re', 'app3_policy', 'app3', 'RE, 100 bp looser'
    'a3_tight_re', 'app3_policy', 'app3', 'RE, 100 bp tighter'
    'a3_loose_learn', 'app3_policy', 'app3', 'Learning, 100 bp looser'
    'a3_tight_learn', 'app3_policy', 'app3', 'Learning, 100 bp tighter'
    'a4_rule_re', 'app4_ramsey', 'app4', 'RE, Taylor rule'
    'a4_rule_learn', 'app4_ramsey', 'app4', 'Learning, Taylor rule'
    'a4_ramsey_balanced_re', 'app4_ramsey', 'app4', 'RE, Ramsey (balanced)'
    'a4_ramsey_hawk_re', 'app4_ramsey', 'app4', 'RE, Ramsey (hawk)'
    'a4_ramsey_dove_re', 'app4_ramsey', 'app4', 'RE, Ramsey (dove)'
    'a4_ramsey_smooth_re', 'app4_ramsey', 'app4', 'RE, Ramsey (smooth)'
    'a4_ramsey_balanced_learn', 'app4_ramsey', 'app4', 'Learning, Ramsey (balanced)'
    'a4_ramsey_hawk_learn', 'app4_ramsey', 'app4', 'Learning, Ramsey (hawk)'
    'a4_ramsey_dove_learn', 'app4_ramsey', 'app4', 'Learning, Ramsey (dove)'
    'a4_ramsey_smooth_learn', 'app4_ramsey', 'app4', 'Learning, Ramsey (smooth)'
    'a5_markup_re', 'app5_density', 'app5', 'RE, mark-up shocks'
    'a5_demand_re', 'app5_density', 'app5', 'RE, demand shocks'
    'a5_markup_learn', 'app5_density', 'app5', 'Learning, mark-up shocks'
    'a5_demand_learn', 'app5_density', 'app5', 'Learning, demand shocks'
    'a6_smooth_re', 'app6_history', 'app6', 'RE smoother'
    'a6_smooth_learn', 'app6_history', 'app6', 'Learning on the RE-smoothed history'
    'a6_inv_learn', 'app6_history', 'app6', 'Learning, history backed out'
    'v1_mc_learn', 'var1_re_variant', 'var1', 'Learning, model-consistent RE'
    'v2_ar2', 'var2_plm', 'var2', 'AR(2) PLM'
    'v2_ar1nc', 'var2_plm', 'var2', 'AR(1) PLM without constant'
    'v2_reg', 'var2_plm', 'var2', 'Regression PLM (pinf, ygap, r)'
    'v2_var3', 'var2_plm', 'var2', 'VAR(1) PLM (pinf, ygap, r)'
    'v2_var12', 'var2_plm', 'var2', 'VAR(1) PLM (12 variables)'
    'v3_all', 'var3_allvars', 'var3', 'All 12 variables (plm_alm)'
    'v3_all_alm', 'var3_allvars', 'var3', 'All 12 variables (alm)'
    'v3_all_none', 'var3_allvars', 'var3', 'All 12 variables (none)'
    'v4_koz', 'var4_gain', 'var4', 'Endogenous gain (KOZ)'
    'v4_koz_full', 'var4_gain', 'var4', 'Endogenous gain, history to 2026Q2'
    'e01_re', 'eval', 'eval', 'RE'
    'e02_learn', 'eval', 'eval', 'Learning (inflation)'
    'e03_learn_mc', 'eval', 'eval', 'Learning, model-consistent RE'
    'e04_learn_all_learners', 'eval', 'eval', 'All agents learn'
    'e05_ar2', 'eval', 'eval', 'AR(2) PLM'
    'e06_ar1nc', 'eval', 'eval', 'AR(1) PLM without constant'
    'e07_reg', 'eval', 'eval', 'Regression PLM (pinf, ygap, r)'
    'e08_var3', 'eval', 'eval', 'VAR(1) PLM (pinf, ygap, r)'
    'e09_var12', 'eval', 'eval', 'VAR(1) PLM (12 variables)'
    'e10_allvars', 'eval', 'eval', 'All 12 variables'
    };
ids = SC(:, 1);
nS = numel(ids);
isEval = strcmp(SC(:, 3), 'eval');
appOf = containers.Map(ids, SC(:, 3));
labOf = containers.Map(ids, SC(:, 4));
R = struct();
for i = find(~isEval)'
    f = fullfile(rdir, ids{i}, 'results.mat');
    if exist(f, 'file') == 2
        tmp = load(f, 'res');
        R.(ids{i}) = tmp.res;
    end
end
LG = readtable(fullfile(rdir, 'run_log.csv'), 'Delimiter', ',', 'TextType', 'char', ...
    'Format', '%s%s%s%s%f%f%q');
evT = {'projection_plm', 'projection_alm', 'projection_alm_shares'};
evS = {'history', 'inversion', 'forecast'};
evCols = {};
for a = 1:numel(evT)
    for b = 1:numel(evS)
        evCols{end+1} = sprintf('%s_%s', evT{a}, evS{b}); %#ok<SAGROW>
    end
end
stt = cell(nS, 1);
rts = NaN(nS, 1);
ems = cell(nS, 1);
des = cell(nS, 1);
EVC = NaN(nS, numel(evCols));
nev = NaN(nS, 1);
for i = 1:nS
    id = ids{i};
    c = feval(id);
    des{i} = c.description;
    if isEval(i)
        r = LG(startsWith(LG.id, ['eval:' id '_p']), :);
        [~, ia] = unique(r.id, 'last');
        r = r(ia, :);
        if height(r) == 0
            stt{i} = 'missing';
            ems{i} = 'no evaluation parts in run_log.csv';
        else
            stt{i} = 'ok';
            if any(~strcmp(r.status, 'ok'))
                stt{i} = 'error';
            end
            rts(i) = sum(r.runtime_s);
            ems{i} = strjoin(r.message(~strcmp(r.status, 'ok')), '; ');
            nev(i) = sum(r.events, 'omitnan');
        end
        continue
    end
    r = LG(strcmp(LG.id, id), :);
    if height(r) == 0
        stt{i} = 'missing';
        ems{i} = 'not in run_log.csv';
    else
        stt{i} = r.status{end};
        rts(i) = r.runtime_s(end);
        ems{i} = r.message{end};
    end
    if isfield(R, id)
        E = R.(id).events;
        nev(i) = height(E);
        k = 0;
        for a = 1:numel(evT)
            for b = 1:numel(evS)
                k = k + 1;
                EVC(i, k) = sum(strcmp(E.type, evT{a}) & strcmp(E.stage, evS{b}));
            end
        end
    end
end
cols = [{ids, SC(:, 2), SC(:, 3), SC(:, 4), des, stt, rts, ems, nev}, num2cell(EVC, 1)];
write_cols(fullfile(out, 'scenarios.csv'), [{'id', 'folder', 'app', 'label', 'description', 'status', ...
    'runtime_s', 'error_message', 'n_events'}, evCols], cols);

% ---- paths_long ------------------------------------------------------------------------------
pv = {'pinfobs', 'robs', 'dy', 'dc'};
pd = qq(2015, 1):qq(2026, 2);
pds = dstr(pd);
n = numel(pd);
B = {};
for i = find(~isEval)'
    id = ids{i};
    if ~isfield(R, id)
        continue
    end
    res = R.(id);
    stg = stage_of(res, pd, false);
    for v = 1:numel(pv)
        x = res.paths.(pv{v})(pd) * sc.(pv{v});
        B{end+1} = {rep(appOf(id), n), rep(id, n), pds, rep(pv{v}, n), x(:), rep('scenario', n), stg}; %#ok<SAGROW>
    end
end
for v = 1:numel(pv)
    x = db.(pv{v})(pd) * sc.(pv{v});
    B{end+1} = {rep('data', n), rep('data', n), pds, rep(pv{v}, n), x(:), rep('data', n), rep('history', n)}; %#ok<SAGROW>
end
write_cols(fullfile(out, 'paths_long.csv'), {'app', 'scenario', 'date', 'variable', 'value', 'source', 'stage'}, ...
    cat_blocks(B));

% ---- learning_long ---------------------------------------------------------------------------
B = {};
PS = struct();                                   % persistence / perceived mean by scenario (memo)
for i = find(~isEval)'
    id = ids{i};
    if ~isfield(R, id) || strcmp(R.(id).cfg.expectations.mode, 'rational')
        continue
    end
    res = R.(id);
    dts = res.dates.record;
    dS = dstr(dts);
    stg = stage_of(res, dts, true);
    sys = sys_from_learning(res.learning);
    [rho, mu] = plm_stats(sys, res.learning, dts);
    PS.(id) = struct('targets', {sys.targets}, 'dates', {dS}, 'rho', rho, 'mu', mu);
    for j = 1:numel(sys.targets)
        x = sys.targets{j};
        L = res.learning.(x);
        fl = {};
        vl = {};
        if isfield(L, 'n1_model')
            fl{end+1} = 'n2_model'; vl{end+1} = 1 - L.n1_model(dts); %#ok<SAGROW>
        end
        if isfield(L, 'n2')
            fl{end+1} = 'n2'; vl{end+1} = L.n2(dts); %#ok<SAGROW>
        end
        for p = 1:numel(L.params)
            fl{end+1} = L.params{p}; vl{end+1} = L.(L.params{p})(dts); %#ok<SAGROW>
        end
        fl{end+1} = 'persistence'; vl{end+1} = rho(:, j); %#ok<SAGROW>
        fl{end+1} = 'perceived_mean'; vl{end+1} = mu(:, j); %#ok<SAGROW>
        if isfield(SSv, x)
            fl{end+1} = 'perceived_mean_report'; vl{end+1} = sc.(SSobs.(x)) * (mu(:, j) + SSv.(x)); %#ok<SAGROW>
        end
        fl{end+1} = 'gain'; vl{end+1} = L.gain(dts); %#ok<SAGROW>
        if isfield(L, 'gain_R')
            fl{end+1} = 'gain_R'; vl{end+1} = L.gain_R(dts); %#ok<SAGROW>
        end
        for f = 1:numel(fl)
            y = vl{f}(:);
            kp = isfinite(y);
            m = nnz(kp);
            B{end+1} = {rep(appOf(id), m), rep(id, m), dS(kp), rep(x, m), rep(fl{f}, m), y(kp), stg(kp)}; %#ok<SAGROW>
        end
    end
end
write_cols(fullfile(out, 'learning_long.csv'), {'app', 'scenario', 'date', 'variable', 'field', 'value', 'stage'}, ...
    cat_blocks(B));

% ---- events_long -----------------------------------------------------------------------------
B = {};
for i = find(~isEval)'
    id = ids{i};
    if ~isfield(R, id) || height(R.(id).events) == 0
        continue
    end
    E = R.(id).events;
    m = height(E);
    B{end+1} = {rep(appOf(id), m), rep(id, m), col(E.date), col(E.stage), col(E.type), col(E.variable), ...
        col(E.detail)}; %#ok<SAGROW>
end
write_cols(fullfile(out, 'events_long.csv'), {'app', 'scenario', 'date', 'stage', 'type', 'variable', 'detail'}, ...
    cat_blocks(B));

% ---- app 3: policy deviations ----------------------------------------------------------------
hz = R.a1_re.dates.horizon;
hs = dstr(hz);
nh = numel(hz);
pairs = {'RE', 'a1_re', 'a3_loose_re', 'a3_tight_re'; 'learning', 'a1_learn', 'a3_loose_learn', 'a3_tight_learn'};
v3 = {'pinfobs', 'robs', 'dy', 'dc', 'ygap', 'ms', 'n2_model_pinf'};
B = {};
A3 = struct();
for e = 1:2
    for v = 1:numel(v3)
        xb = getv(R.(pairs{e, 2}), v3{v}, hz, sc);
        dl = getv(R.(pairs{e, 3}), v3{v}, hz, sc) - xb;
        dt = getv(R.(pairs{e, 4}), v3{v}, hz, sc) - xb;
        A3.(lower(pairs{e, 1})).(v3{v}) = [dl, dt, dl + dt];
        B{end+1} = {rep(pairs{e, 1}, nh), rep(v3{v}, nh), hs, dl, dt, dl + dt}; %#ok<SAGROW>
    end
end
write_cols(fullfile(out, 'app3_policy.csv'), {'expectations', 'variable', 'date', 'loose_minus_base', ...
    'tight_minus_base', 'asymmetry'}, cat_blocks(B));

% ---- app 4: losses ---------------------------------------------------------------------------
W = struct('balanced', [1 0.5 0.1 0], 'hawk', [1 0.1 0.1 0], 'dove', [1 1 0.1 0], 'smooth', [1 0.5 0.1 0.5]);
tn = {'pinf', 'ygap', 'r', 'dr'};
wn = fieldnames(W);
ex = {'re', 'RE'; 'learn', 'learning'};
rows = cell(0, 9);
for e = 1:2
    Lr = R.(['a4_rule_' ex{e, 1}]).loss;
    for w = 1:numel(wn)
        Lm = R.(sprintf('a4_ramsey_%s_%s', wn{w}, ex{e, 1})).loss;
        for N = [16 80]
            [tot, con] = loss_rebuild(Lr, W.(wn{w}), tn, N);
            rows(end+1, :) = [{wn{w}, ex{e, 2}, 'rule', N, tot}, num2cell(con)]; %#ok<SAGROW>
            [tot, con] = loss_rebuild(Lm, W.(wn{w}), tn, N);
            rows(end+1, :) = [{wn{w}, ex{e, 2}, 'ramsey', N, tot}, num2cell(con)]; %#ok<SAGROW>
        end
    end
end
% Diagnostic (not saved): the same RE runs with model-consistent RE agents. In mode 'rational' the
% anchored pinf block forecasts with the RE solution under the Taylor rule even when policy is Ramsey,
% so a4_ramsey_*_re are not RE Ramsey plans; with re_variant = 'model_consistent' they are.
MCR = struct();
for w = 1:numel(wn)
    cf = feval(sprintf('a4_ramsey_%s_re', wn{w}));
    cf.id = ['chk_mc_ramsey_' wn{w}];
    cf.expectations.re_variant = 'model_consistent';
    cf.compare_with = {};
    rr = hetlearn.run(cf, 'save', false, 'quiet', true);
    MCR.(wn{w}) = rr.loss;
end
cf = feval('a4_rule_re');
cf.id = 'chk_mc_rule';
cf.expectations.re_variant = 'model_consistent';
cf.compare_with = {};
rmc = hetlearn.run(cf, 'save', false, 'quiet', true);
for w = 1:numel(wn)
    for N = [16 80]
        [tot, con] = loss_rebuild(rmc.loss, W.(wn{w}), tn, N);
        rows(end+1, :) = [{wn{w}, 'RE_model_consistent', 'rule', N, tot}, num2cell(con)]; %#ok<SAGROW>
        [tot, con] = loss_rebuild(MCR.(wn{w}), W.(wn{w}), tn, N);
        rows(end+1, :) = [{wn{w}, 'RE_model_consistent', 'ramsey', N, tot}, num2cell(con)]; %#ok<SAGROW>
    end
end
e11 = max(abs(rmc.paths.pinfobs(hz) - R.a4_rule_re.paths.pinfobs(hz)));
e11b = abs(rmc.loss.total - R.a4_rule_re.loss.total) / R.a4_rule_re.loss.total;
write_cols(fullfile(out, 'app4_losses.csv'), {'weights', 'expectations', 'policy', 'horizon', 'total', ...
    'pinf', 'ygap', 'r', 'dr'}, cells_to_cols(rows));
A4 = rows;

% ---- app 5: densities ------------------------------------------------------------------------
cases = {'markup', 'demand'};
v5 = {'pinfobs', 'robs', 'dy', 'dc', 'n2_model_pinf'};
B = {};
BW = {};
DN = struct();
for c = 1:2
    for e = 1:2
        id = sprintf('a5_%s_%s', cases{c}, ex{e, 1});
        tmp = load(fullfile(rdir, id, 'density.mat'));
        DN.(id) = tmp.density;
    end
end
for c = 1:2
    for e = 1:2
        id = sprintf('a5_%s_%s', cases{c}, ex{e, 1});
        D = DN.(id);
        dd = dstr(D.dates);
        p = D.quantiles(:)';
        i05 = find(abs(p - 0.05) < 1e-9, 1);
        i95 = find(abs(p - 0.95) < 1e-9, 1);
        for v = 1:numel(v5)
            Sx = D.series.(v5{v});
            Q = Sx.q_report;
            for k = 1:numel(p)
                B{end+1} = {rep(cases{c}, numel(dd)), rep(ex{e, 2}, numel(dd)), rep(v5{v}, numel(dd)), ...
                    dd, repmat(p(k), numel(dd), 1), Q(:, k)}; %#ok<SAGROW>
            end
            wd = Q(:, i95) - Q(:, i05);
            Dre = DN.(sprintf('a5_%s_re', cases{c}));
            wre = Dre.series.(v5{v}).q_report(:, i95) - Dre.series.(v5{v}).q_report(:, i05);
            BW{end+1} = {rep(cases{c}, numel(dd)), rep(ex{e, 2}, numel(dd)), rep(v5{v}, numel(dd)), dd, ...
                wd, wd ./ wre}; %#ok<SAGROW>
        end
    end
end
write_cols(fullfile(out, 'app5_density.csv'), {'case', 'expectations', 'variable', 'date', 'quantile', 'value'}, ...
    cat_blocks(B));
write_cols(fullfile(out, 'app5_widths.csv'), {'case', 'expectations', 'variable', 'date', 'width_90', ...
    'ratio_to_re'}, cat_blocks(BW));

% ---- app 6: decompositions and backed-out shocks ---------------------------------------------
dcase = {'re_smooth', 'a6_smooth_re'; 'learn_smooth', 'a6_smooth_learn'; 'learn_inv', 'a6_inv_learn'};
B = {};
DC = struct();
for c = 1:3
    T = readtable(fullfile(rdir, dcase{c, 2}, 'decomposition.csv'), 'Delimiter', ',', 'TextType', 'char', ...
        'DatetimeType', 'text');
    T.date = cellstr(T.date);
    comp = T.component;
    comp(strcmp(comp, 'beliefs_constants')) = {'intercept_channel'};
    T.component = comp;
    DC.(dcase{c, 1}) = T;
    m = height(T);
    B{end+1} = {rep(dcase{c, 1}, m), T.date, T.variable, T.component, T.value_report, T.label}; %#ok<SAGROW>
end
write_cols(fullfile(out, 'app6_decomp_long.csv'), {'case', 'date', 'variable', 'component', 'value', 'label'}, ...
    cat_blocks(B));
hd = qq(1966, 1):qq(2026, 2);
hds = dstr(hd);
shk = R.a6_smooth_re.meta.eList;
B = {};
SH = struct();
for s = 1:numel(shk)
    a = R.a6_smooth_re.paths.(shk{s})(hd);
    b = R.a6_inv_learn.paths.(shk{s})(hd);
    sd = P.(['std_' shk{s}]);
    SH.(shk{s}) = (b - a) / sd;
    B{end+1} = {hds, rep(shk{s}, numel(hd)), a, b, b - a, (b - a) / sd}; %#ok<SAGROW>
end
write_cols(fullfile(out, 'app6_shocks_long.csv'), {'date', 'shock', 'smoothed', 'inversion', 'diff', 'diff_sd'}, ...
    cat_blocks(B));

% ---- variant 3: facility table ---------------------------------------------------------------
fids = {'a1_learn', 'v3_all', 'v3_all_alm', 'v3_all_none'};
evT2 = [evT, {'explosive'}];
fc = {};
for a = 1:numel(evT2)
    for b = 1:numel(evS)
        fc{end+1} = sprintf('%s_%s', evT2{a}, evS{b}); %#ok<SAGROW>
    end
end
rows = cell(0, 6 + numel(fc) + 3);
for i = 1:numel(fids)
    id = fids{i};
    k = find(strcmp(ids, id), 1);
    edate = regexp(ems{k}, '\d{4}Q\d', 'match', 'once');
    vr = c_or(feval(id), 'expectations', 'variables');
    if iscell(vr)
        vr = strjoin(vr, ' ');
    end
    cnt = NaN(1, numel(fc));
    avg = NaN(1, 3);
    if isfield(R, id)
        E = R.(id).events;
        q = 0;
        for a = 1:numel(evT2)
            for b = 1:numel(evS)
                q = q + 1;
                cnt(q) = sum(strcmp(E.type, evT2{a}) & strcmp(E.stage, evS{b}));
            end
        end
        avg = [mean(R.(id).paths.pinfobs(hz)) * sc.pinfobs, mean(R.(id).paths.robs(hz)) * sc.robs, ...
            mean(R.(id).paths.dy(hz)) * sc.dy];
    end
    rows(end+1, :) = [{id, R_facility(R, id), vr, stt{k}, ems{k}, edate}, num2cell(cnt), num2cell(avg)]; %#ok<SAGROW>
end
write_cols(fullfile(out, 'v3_facility.csv'), [{'scenario', 'facility', 'variables', 'status', 'error_message', ...
    'error_date'}, fc, {'avg_pinfobs_2022Q3_2026Q2', 'avg_robs_2022Q3_2026Q2', 'avg_dy_2022Q3_2026Q2'}], ...
    cells_to_cols(rows));

% ---- evaluation copies -----------------------------------------------------------------------
EVT = struct();
ef = {'metrics', 'eval_metrics'; 'relative_rmse', 'eval_relative'; 'dm', 'eval_dm'};
for k = 1:3
    T = readtable(fullfile(gdir, [ef{k, 1} '.csv']), 'Delimiter', ',', 'TextType', 'char', 'DatetimeType', 'text');
    lab = cellfun(@(v) labOf(v), T.variant, 'UniformOutput', false);
    T = addvars(T, lab, 'After', 'variant', 'NewVariableNames', 'label');
    EVT.(ef{k, 1}) = T;
    write_cols(fullfile(out, [ef{k, 2} '.csv']), T.Properties.VariableNames, table2cols(T));
end

% =============================================================================================
% CHECKS
% =============================================================================================
obs = spec.observables;
% C1 RE replay = data
e1 = 0;
for v = 1:numel(obs)
    e1 = max(e1, max(abs(R.a2_re.paths.(obs{v})(hz) - db.(obs{v})(hz))));
end
CH(end+1, :) = {'C1 RE replay of the smoothed shocks = data (a2_re, 7 observables, 2022Q3-2026Q2, max abs, model units)', ...
    e1 < 1e-9, sprintf('%.3g', e1)};
% C2 RE scenario with learning blocks = the RE model
s0 = simulate(m0, R.a1_re.paths, hz, 'anticipate', false);
e2 = 0;
for v = 1:numel(obs)
    e2 = max(e2, max(abs(s0.(obs{v})(hz) - R.a1_re.paths.(obs{v})(hz))));
end
CH(end+1, :) = {'C2 RE scenario with the pinf learning block (a1_re) = original SW07 model simulated from the same state (max abs)', ...
    e2 < 1e-9, sprintf('%.3g', e2)};
% C3 app 3 under RE: symmetric and linear
asy = 0;
for v = 1:numel(v3)
    asy = max(asy, max(abs(A3.re.(v3{v})(:, 3))));
end
emL = R.a3_loose_re.paths.em(hz);
emT = R.a3_tight_re.paths.em(hz);
dlin = 0;
for k = 1:2
    nm = pairs{1, 2 + k};
    d = R.a1_re.paths;
    d.em(hz) = R.(nm).paths.em(hz);
    s1 = simulate(m0, d, hz, 'anticipate', false);
    for v = 1:numel(obs)
        dlin = max(dlin, max(abs(s1.(obs{v})(hz) - R.(nm).paths.(obs{v})(hz))));
    end
end
msd = max(abs([A3.re.ms(1:4, 1) + 1, A3.re.ms(1:4, 2) - 1]), [], 'all');   % ms in report units (x4): -1 / +1
CH(end+1, :) = {'C3a App 3 under RE is symmetric: max |loose + tight - 2 base| over 7 series (report units)', ...
    asy <= 1e-10, sprintf('%.3g', asy)};
CH(end+1, :) = {'C3b App 3 under RE is linear: the original model hit by the backed-out em shocks reproduces both runs; em_loose = -em_tight; ms = base -/+ 0.25 in 2022Q3-2023Q2', ...
    dlin < 1e-9 && max(abs(emL + emT)) < 1e-10 && msd < 1e-10, ...
    sprintf('simulation %.3g, em sum %.3g, ms target %.3g', dlin, max(abs(emL + emT)), msd)};
% C4 losses rebuilt from the paths
e4a = 0;
e4b = 0;
for i = find(strcmp(SC(:, 3), 'app4'))'
    res = R.(ids{i});
    Lx = res.loss;
    tg = struct('pinf', 4 * res.paths.pinf(hz), 'ygap', res.paths.y(hz) - res.paths.yf(hz), ...
        'r', 4 * res.paths.r(hz), 'dr', 4 * (res.paths.r(hz) - res.paths.r(hz - 1)));
    for k = 1:numel(tn)
        e4a = max(e4a, max(abs(tg.(tn{k}) - Lx.values.(tn{k})(1:nh))));
    end
    wv = cellfun(@(k) getfield_or(Lx.weights, k, 0), tn);
    tot = loss_rebuild(Lx, wv, tn, Lx.horizon);
    e4b = max(e4b, abs(tot - Lx.total) / max(1, abs(Lx.total)));
end
CH(end+1, :) = {'C4 Loss rebuilt from the paths equals res.loss (10 app-4 runs: targets over 16 quarters from res.paths; 80-quarter total from the targets and weights, relative)', ...
    e4a < 1e-9 && e4b < 1e-12, sprintf('targets %.3g, totals %.3g', e4a, e4b)};
% C5 density: RE fast path and a 10-draw fast vs general check
fastOK = strcmp(DN.a5_markup_re.path, 'fast') && strcmp(DN.a5_demand_re.path, 'fast');
e5 = 0;
p5 = '';
for c = 1:2
    cf = feval(sprintf('a5_%s_re', cases{c}));
    cf.id = ['chk10_' cases{c}];
    cf.compare_with = {};
    cf.density.ndraws = 10;
    r1 = hetlearn.run(cf, 'save', false, 'quiet', true);
    cf.density.fast_path = false;
    r2 = hetlearn.run(cf, 'save', false, 'quiet', true);
    p5 = [p5, sprintf('%s: %s vs %s; ', cases{c}, r1.density.path, r2.density.path)]; %#ok<AGROW>
    for v = 1:numel(obs)
        e5 = max(e5, max(abs(r1.density.series.(obs{v}).q(:) - r2.density.series.(obs{v}).q(:))));
    end
end
CH(end+1, :) = {'C5 RE densities use the fast path; 10-draw quantiles fast = general path (both cases, 7 observables)', ...
    fastOK && e5 < 1e-9, sprintf('fast path in the 500-draw runs: %d; %smax abs %.3g', fastOK, p5, e5)};
% C6 decompositions rebuild their totals
e6 = '';
ok6 = true;
for c = 1:3
    ck = readtable(fullfile(rdir, dcase{c, 2}, 'decomposition_check.csv'), 'TextType', 'char');
    T = DC.(dcase{c, 1});
    if strcmp(ck.method{1}, 'iris')
        x = max(abs(T.value_model(strcmp(T.component, 'intercept_channel'))));
        e6 = [e6, sprintf('%s (iris): shocks + init rebuild the total to %.3g; ', dcase{c, 1}, x)]; %#ok<AGROW>
    else
        x = ck.recon_maxerr(1);
        e6 = [e6, sprintf('%s (tv): path reconstruction %.3g; ', dcase{c, 1}, x)]; %#ok<AGROW>
    end
    ok6 = ok6 && x < 1e-8;
end
CH(end+1, :) = {'C6 Every decomposition rebuilds its total (path reconstruction)', ok6, e6};
Tre = DC.re_smooth;
Tls = DC.learn_smooth;
[~, ia, ib] = intersect(strcat(Tre.date, Tre.variable, Tre.component), strcat(Tls.date, Tls.variable, Tls.component));
e6b = max(abs(Tre.value_model(ia) - Tls.value_model(ib)));
CH(end+1, :) = {'C6b The learn_smooth decomposition equals re_smooth over 1966Q1-2026Q2 (the RE-smoothed history is decomposed with the RE model)', ...
    e6b < 1e-8, sprintf('%.3g over %d rows', e6b, numel(ia))};
% C7 evaluation: partition and merge
S = load(fullfile(gdir, 'settings.mat'));
es = S.settings;
d = dir(fullfile(gdir, 'parts', 'eval_*'));
d = d([d.isdir]);
oS = col(es.origin_str);
cov = zeros(numel(oS), numel(es.ids));
perr = {};
for p = 1:numel(d)
    ps = load(fullfile(d(p).folder, d(p).name, 'settings.mat'));
    v = find(strcmp(es.ids, ps.settings.ids{1}));
    [~, io] = ismember(col(ps.settings.origin_str), oS);
    cov(io, v) = cov(io, v) + 1;
    T = readtable(fullfile(d(p).folder, d(p).name, 'errors_long.csv'), 'Delimiter', ',', 'TextType', 'char', ...
        'DatetimeType', 'text');
    T.origin = cellstr(T.origin);
    perr{end+1} = T(:, {'variant', 'origin', 'h', 'variable', 'error'}); %#ok<SAGROW>
end
partOK = all(cov(:) == 1);
TE = readtable(fullfile(gdir, 'errors_long.csv'), 'Delimiter', ',', 'TextType', 'char', 'DatetimeType', 'text');
TE.origin = cellstr(TE.origin);
PE = vertcat(perr{:});
kA = strcat(TE.variant, '|', TE.origin, '|', string(TE.h), '|', TE.variable);
kB = strcat(PE.variant, '|', PE.origin, '|', string(PE.h), '|', PE.variable);
[okB, ib] = ismember(kA, kB);
e7a = max(abs(TE.error - PE.error(ib(okB))));
T2 = hetlearn.evaluate_tables(fullfile(gdir, 'errors_long.csv'));
e7b = [table_maxdiff(T2.metrics, EVT.metrics), table_maxdiff(T2.relative_rmse, EVT.relative_rmse), ...
    table_maxdiff(T2.dm, EVT.dm)];
CH(end+1, :) = {sprintf('C7a Evaluation parts partition the origins (%d parts; each of %d variants x %d origins covered once)', ...
    numel(d), numel(es.ids), numel(oS)), partOK, sprintf('coverage min %d, max %d', min(cov(:)), max(cov(:)))};
CH(end+1, :) = {'C7b Merged errors = union of the part errors; merged tables = hetlearn.evaluate_tables on the merged errors (metrics, relative RMSE, DM; max abs)', ...
    all(okB) && height(TE) == height(PE) && e7a == 0 && all(e7b < 1e-12), ...
    sprintf('rows %d vs %d, errors %.3g, tables %.3g / %.3g / %.3g', height(TE), height(PE), e7a, e7b)};
% C8 statuses
bad = ids(~strcmp(stt, 'ok') & ~strcmp(ids, 'v3_all_none'));
msg8 = 'every scenario ok';
if ~isempty(bad)
    msg8 = strjoin(cellfun(@(x) sprintf('%s: %s %s', x, stt{strcmp(ids, x)}, ems{strcmp(ids, x)}), bad, ...
        'UniformOutput', false), '; ');
end
CH(end+1, :) = {sprintf('C8 Every scenario except v3_all_none has status ok (%d scenarios incl. 10 evaluation variants; v3_all_none: %s)', ...
    nS, stt{strcmp(ids, 'v3_all_none')}), isempty(bad), msg8};
% C9 inversion fits the data; C10 share timing
e9 = NaN;
if isfield(R.a6_inv_learn, 'inversion') && isfield(R.a6_inv_learn.inversion, 'max_obs_miss')
    e9 = R.a6_inv_learn.inversion.max_obs_miss;
end
CH(end+1, :) = {'C9 The inversion a6_inv_learn reproduces the 7 observables 1966Q1-2026Q2 (max miss, model units)', ...
    e9 < 1e-10, sprintf('%.3g', e9)};
Lp = R.a1_learn.learning.pinf;
kept = R.a1_learn.events(strcmp(R.a1_learn.events.type, 'projection_alm_shares'), :);
e10 = max(abs(Lp.n1_model(hz) - Lp.n1(hz - 1)));
CH(end+1, :) = {'C10 Share timing in a1_learn: n2_model(t) = n2(t-1) in every forecast quarter (no kept shares)', ...
    e10 < 1e-12 && height(kept) == 0, sprintf('%.3g, %d kept-share events', e10, height(kept))};

CH(end+1, :) = {'C11 Under the Taylor rule anchored and model-consistent RE agents give the same RE path and loss (a4_rule_re vs an unsaved model-consistent copy; inflation max abs, loss relative)', ...
    e11 < 1e-9 && e11b < 1e-9, sprintf('inflation %.3g, 80-quarter loss %.3g', e11, e11b)};

fid = fopen(fullfile(out, 'checks_v3.txt'), 'w');
fprintf(fid, 'checks_v3.txt: build_summary_v3.m, %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM')); %#ok<TNOW1,DATST>
for k = 1:size(CH, 1)
    fprintf(fid, '%s  %s\n      %s\n', ternary(CH{k, 2}, 'PASS', 'FAIL'), CH{k, 1}, CH{k, 3});
end
fprintf(fid, '\n%d of %d checks pass\n', sum([CH{:, 2}]), size(CH, 1));
fclose(fid);
fprintf('\n%s\n', fileread(fullfile(out, 'checks_v3.txt')));

% =============================================================================================
% KEY NUMBERS (every number the memo quotes)
% =============================================================================================
d22 = qq(2022, 2);
avgp = @(id, v) mean(R.(id).paths.(v)(hz)) * sc.(v);
for i = find(~isEval)'
    id = ids{i};
    if ~isfield(R, id) || ~hetlearn.util.date_eq(R.(id).dates.origin, d22)
        continue
    end
    K = addk(K, ['avg_pinfobs__' id], avgp(id, 'pinfobs'), '% annualised', ['Average inflation 2022Q3-2026Q2, ' id]);
    K = addk(K, ['avg_robs__' id], avgp(id, 'robs'), '% annualised', ['Average policy rate 2022Q3-2026Q2, ' id]);
    K = addk(K, ['avg_dy__' id], avgp(id, 'dy'), '% annualised', ['Average output growth 2022Q3-2026Q2, ' id]);
    if ~strcmp(R.(id).cfg.expectations.mode, 'rational') && isfield(R.(id).learning, 'pinf')
        L = R.(id).learning.pinf;
        K = addk(K, ['n2_origin__' id], L.n2(d22), 'share', ['Learners'' share of inflation expectations at the end of 2022Q2, ' id]);
        nm = 1 - L.n1_model(hz);
        K = addk(K, ['n2_model_2022Q3__' id], nm(1), 'share', ['Learners'' share in force in 2022Q3, ' id]);
        K = addk(K, ['n2_model_2026Q2__' id], nm(end), 'share', ['Learners'' share in force in 2026Q2, ' id]);
        K = addk(K, ['n2_model_min__' id], min(nm), 'share', ['Lowest learners'' share in force 2022Q3-2026Q2, ' id]);
        K = addk(K, ['n2_model_max__' id], max(nm), 'share', ['Highest learners'' share in force 2022Q3-2026Q2, ' id]);
    end
end
% app 1
x = (R.a1_learn.paths.pinfobs(hz) - R.a1_re.paths.pinfobs(hz)) * sc.pinfobs;
[mx, im] = max(abs(x));
K = addk(K, 'a1_gap_pinf_max', x(im), 'pp annualised', ['Largest learning-minus-RE inflation gap, at ' hs{im}]);
for dq = {'2022Q3', '2023Q2', '2024Q2', '2026Q2'}
    t = find(strcmp(hs, dq{1}));
    K = addk(K, ['a1_pinf_re_' dq{1}], R.a1_re.paths.pinfobs(hz(t)) * 4, '% annualised', ['RE inflation in ' dq{1}]);
    K = addk(K, ['a1_pinf_learn_' dq{1}], R.a1_learn.paths.pinfobs(hz(t)) * 4, '% annualised', ['Learning inflation in ' dq{1}]);
    K = addk(K, ['a1_n2_model_' dq{1}], 1 - R.a1_learn.learning.pinf.n1_model(hz(t)), 'share', ['Learners'' share in force in ' dq{1} ', a1_learn']);
end
K = addk(K, 'a1_pinf_data_2022Q2', db.pinfobs(d22) * 4, '% annualised', 'Inflation in 2022Q2 (data, the origin)');
Lh = R.a1_learn.learning.pinf;
hh = qq(1966, 1):d22;
K = addk(K, 'a1_n2_hist_mean', mean(Lh.n2(hh)), 'share', 'Average learners'' share 1966Q1-2022Q2 (discrete choice, RE-smoothed history)');
K = addk(K, 'a1_n2_hist_min', min(Lh.n2(hh)), 'share', 'Lowest learners'' share 1966Q1-2022Q2');
K = addk(K, 'a1_n2_hist_max', max(Lh.n2(hh)), 'share', 'Highest learners'' share 1966Q1-2022Q2');
K = addk(K, 'a1_n2_2021Q2', Lh.n2(qq(2021, 2)), 'share', 'Learners'' share at the end of 2021Q2');
K = addk(K, 'a1_n2_2019Q4', Lh.n2(qq(2019, 4)), 'share', 'Learners'' share at the end of 2019Q4');
ps = PS.a1_learn;
t = find(strcmp(ps.dates, '2022Q2'));
K = addk(K, 'a1_alpha_origin', Lh.alpha_pinf(d22), 'model units', 'alpha_pinf at 2022Q2');
K = addk(K, 'a1_beta_origin', Lh.beta_pinf(d22), 'coefficient', 'beta_pinf at 2022Q2');
K = addk(K, 'a1_pmean_origin', sc.pinfobs * (ps.mu(t, 1) + SSv.pinf), '% annualised', 'Perceived mean inflation at 2022Q2 (AR(1) PLM), annualised level');
K = addk(K, 'a1_pmean_2026Q2', sc.pinfobs * (ps.mu(end, 1) + SSv.pinf), '% annualised', 'Perceived mean inflation at 2026Q2, annualised level');
K = addk(K, 'ss_pinf', sc.pinfobs * SSv.pinf, '% annualised', 'Steady-state inflation of the model');
K = addk(K, 'ss_robs', sc.robs * SSv.r, '% annualised', 'Steady-state policy rate of the model');
% app 2
for v = 1:numel(pv)
    g = (R.a2_learn.paths.(pv{v})(hz) - db.(pv{v})(hz)) * sc.(pv{v});
    [~, im] = max(abs(g));
    K = addk(K, ['a2_rmse_' pv{v}], sqrt(mean(g.^2)), 'pp annualised', ['RMS gap of the learning replay to the data, ' pv{v}]);
    K = addk(K, ['a2_maxgap_' pv{v}], g(im), 'pp annualised', ['Largest gap of the learning replay to the data, ' pv{v} ', at ' hs{im}]);
end
K = addk(K, 'a2_avg_pinf_data', mean(db.pinfobs(hz)) * 4, '% annualised', 'Average inflation 2022Q3-2026Q2, data');
% app 3
for e = {'re', 'learning'}
    for v = {'pinfobs', 'robs', 'dy'}
        M = A3.(e{1}).(v{1});
        [~, il] = max(abs(M(:, 1)));
        [~, it] = max(abs(M(:, 2)));
        [~, ia] = max(abs(M(:, 3)));
        K = addk(K, sprintf('a3_%s_loose_peak_%s', e{1}, v{1}), M(il, 1), 'pp annualised', sprintf('Largest loose-minus-base effect, %s, %s, at %s', v{1}, e{1}, hs{il}));
        K = addk(K, sprintf('a3_%s_tight_peak_%s', e{1}, v{1}), M(it, 2), 'pp annualised', sprintf('Largest tight-minus-base effect, %s, %s, at %s', v{1}, e{1}, hs{it}));
        K = addk(K, sprintf('a3_%s_asym_peak_%s', e{1}, v{1}), M(ia, 3), 'pp annualised', sprintf('Largest asymmetry (loose + tight), %s, %s, at %s', v{1}, e{1}, hs{ia}));
        K = addk(K, sprintf('a3_%s_loose_avg_%s', e{1}, v{1}), mean(M(:, 1)), 'pp annualised', sprintf('Average loose-minus-base effect 2022Q3-2026Q2, %s, %s', v{1}, e{1}));
        K = addk(K, sprintf('a3_%s_tight_avg_%s', e{1}, v{1}), mean(M(:, 2)), 'pp annualised', sprintf('Average tight-minus-base effect 2022Q3-2026Q2, %s, %s', v{1}, e{1}));
    end
end
M = A3.learning.n2_model_pinf;
[~, il] = max(abs(M(:, 1)));
[~, it] = max(abs(M(:, 2)));
K = addk(K, 'a3_learning_loose_peak_n2', M(il, 1), 'share', ['Largest loose-minus-base change in the learners'' share, at ' hs{il}]);
K = addk(K, 'a3_learning_tight_peak_n2', M(it, 2), 'share', ['Largest tight-minus-base change in the learners'' share, at ' hs{it}]);
% app 4
for k = 1:size(A4, 1)
    K = addk(K, sprintf('a4_loss_%s_%s_%s_%d', A4{k, 1}, lower(A4{k, 2}), A4{k, 3}, A4{k, 4}), A4{k, 5}, 'loss', ...
        sprintf('Discounted loss, %s weights, %s, %s, %d quarters', A4{k, 1}, A4{k, 2}, A4{k, 3}, A4{k, 4}));
end
% app 5
for c = 1:2
    for v = 1:numel(v5)
        for e = 1:2
            D = DN.(sprintf('a5_%s_%s', cases{c}, ex{e, 1}));
            Q = D.series.(v5{v}).q_report;
            p = D.quantiles(:)';
            w90 = Q(:, abs(p - 0.95) < 1e-9) - Q(:, abs(p - 0.05) < 1e-9);
            K = addk(K, sprintf('a5_w90_avg_%s_%s_%s', cases{c}, ex{e, 1}, v5{v}), mean(w90), 'pp annualised', ...
                sprintf('Average 90%% band width 2022Q3-2026Q2, %s shocks, %s, %s', cases{c}, ex{e, 2}, v5{v}));
            for hq = [4 8 16]
                K = addk(K, sprintf('a5_w90_h%d_%s_%s_%s', hq, cases{c}, ex{e, 1}, v5{v}), w90(hq), 'pp annualised', ...
                    sprintf('90%% band width at h = %d, %s shocks, %s, %s', hq, cases{c}, ex{e, 2}, v5{v}));
            end
            if e == 2 && strcmp(v5{v}, 'pinfobs')
                K = addk(K, sprintf('a5_med_avg_%s_learn_pinfobs', cases{c}), mean(Q(:, abs(p - 0.5) < 1e-9)), '% annualised', ...
                    sprintf('Average median inflation 2022Q3-2026Q2, %s shocks, learning', cases{c}));
                K = addk(K, sprintf('a5_n_used_%s_learn', cases{c}), D.n_used, 'draws', sprintf('Draws used, %s shocks, learning', cases{c}));
                K = addk(K, sprintf('a5_s_per_draw_%s_learn', cases{c}), D.s_per_draw, 's', sprintf('Seconds per draw, %s shocks, learning', cases{c}));
            end
        end
    end
end
% app 6
Lsm = R.a6_smooth_learn.learning.pinf;
Liv = R.a6_inv_learn.learning.pinf;
K = addk(K, 'a6_n2_2022Q2_smooth', Lsm.n2(d22), 'share', 'Learners'' share at the end of 2022Q2, learning on the RE-smoothed history');
K = addk(K, 'a6_n2_2022Q2_inv', Liv.n2(d22), 'share', 'Learners'' share at the end of 2022Q2, history backed out with the learning model');
K = addk(K, 'a6_n2_2026Q2_smooth', Lsm.n2(qq(2026, 2)), 'share', 'Learners'' share at the end of 2026Q2, RE-smoothed history');
K = addk(K, 'a6_n2_2026Q2_inv', Liv.n2(qq(2026, 2)), 'share', 'Learners'' share at the end of 2026Q2, inversion');
K = addk(K, 'a6_n2_hist_mean_inv', mean(Liv.n2(hd)), 'share', 'Average learners'' share 1966Q1-2026Q2, inversion');
K = addk(K, 'a6_n2_hist_mean_smooth', mean(Lsm.n2(hd)), 'share', 'Average learners'' share 1966Q1-2026Q2, RE-smoothed history');
for s = 1:numel(shk)
    z = SH.(shk{s});
    [~, im] = max(abs(z));
    K = addk(K, ['a6_shock_rms_sd_' shk{s}], sqrt(mean(z.^2)), 'sd', ['RMS of inversion minus smoothed shock 1966Q1-2026Q2, ' shk{s}]);
    K = addk(K, ['a6_shock_max_sd_' shk{s}], z(im), 'sd', ['Largest inversion minus smoothed shock, ' shk{s} ', at ' hds{im}]);
    K = addk(K, ['a6_shock_rms_sd_2021_2023_' shk{s}], sqrt(mean(z(double(hd) >= double(qq(2021, 1)) - 1e-6 & double(hd) <= double(qq(2023, 4)) + 1e-6).^2)), 'sd', ...
        ['RMS of inversion minus smoothed shock 2021Q1-2023Q4, ' shk{s}]);
end
compsD = {'demand', 'monetary', 'supply', 'price_markup', 'wage_markup', 'init', 'intercept_channel', 'total'};
win = {'2021Q1_2023Q4', '2021Q1', '2023Q4'; '1966Q1_2026Q2', '1966Q1', '2026Q2'; '2008Q1_2019Q4', '2008Q1', '2019Q4'};
for c = [1 3]
    T = DC.(dcase{c, 1});
    [~, ti] = ismember(T.date, hds);              % position in 1966Q1-2026Q2
    for v = {'pinfobs', 'dy'}
        for w = 1:size(win, 1)
            for k = 1:numel(compsD)
                sel = strcmp(T.variable, v{1}) & strcmp(T.component, compsD{k}) & ti >= find(strcmp(hds, win{w, 2})) & ti <= find(strcmp(hds, win{w, 3}));
                K = addk(K, sprintf('a6_dec_%s_%s_%s_%s', dcase{c, 1}, v{1}, win{w, 1}, compsD{k}), mean(T.value_report(sel)), ...
                    'pp annualised', sprintf('Average contribution to %s, %s, %s, %s', v{1}, compsD{k}, win{w, 1}, dcase{c, 1}));
            end
        end
    end
end
% variants
for id = {'v1_mc_learn', 'v2_ar2', 'v2_ar1nc', 'v2_reg', 'v2_var3', 'v2_var12', 'v3_all', 'v3_all_alm', 'v3_all_none', 'v4_koz', 'a1_learn'}
    ps = PS.(id{1});
    t = find(strcmp(ps.dates, '2022Q2'));
    jp = find(strcmp(ps.targets, 'pinf'));
    K = addk(K, ['persist_origin__' id{1}], ps.rho(t, jp), 'root', ['Largest root of the inflation PLM block at 2022Q2, ' id{1}]);
    K = addk(K, ['pmean_origin__' id{1}], sc.pinfobs * (ps.mu(t, jp) + SSv.pinf), '% annualised', ['Perceived mean inflation at 2022Q2, ' id{1}]);
    L = R.(id{1}).learning.pinf;
    for p = 1:numel(L.params)
        K = addk(K, sprintf('coef_origin__%s__%s', id{1}, L.params{p}), L.(L.params{p})(d22), 'coefficient', ...
            sprintf('%s at 2022Q2, %s', L.params{p}, id{1}));
    end
    k = find(strcmp(ids, id{1}));
    for q = 1:numel(evCols)
        K = addk(K, sprintf('ev_%s__%s', evCols{q}, id{1}), EVC(k, q), 'events', sprintf('%s events, %s', evCols{q}, id{1}));
    end
end
for id = {'v3_all', 'v3_all_alm', 'v3_all_none'}
    lv = R.(id{1}).meta.learnVars;
    n0 = cellfun(@(x) R.(id{1}).learning.(x).n2(d22), lv);
    K = addk(K, ['n2_origin_mean_all__' id{1}], mean(n0), 'share', ['Average learners'' share over the 12 variables at 2022Q2, ' id{1}]);
    K = addk(K, ['n2_origin_max_all__' id{1}], max(n0), 'share', ['Highest learners'' share over the 12 variables at 2022Q2, ' id{1}]);
    E = R.(id{1}).events;
    K = addk(K, ['ev_explosive__' id{1}], sum(strcmp(E.type, 'explosive')), 'events', ['explosive events, ' id{1}]);
end
Lk = R.v4_koz_full.learning.pinf;
gk = Lk.gain(hd);
[gmx, imx] = max(gk);
[gmn, imn] = min(gk);
K = addk(K, 'v4_gain_origin', R.v4_koz.learning.pinf.gain(d22), 'gain', 'KOZ gain used in 2022Q2 (v4_koz)');
K = addk(K, 'v4_gain_2022Q3_2026Q2_mean', mean(R.v4_koz.learning.pinf.gain(hz)), 'gain', 'Average KOZ gain 2022Q3-2026Q2 (forecast, v4_koz)');
K = addk(K, 'v4_gain_end_forecast', R.v4_koz.learning.pinf.gain(hz(end)), 'gain', 'KOZ gain in 2026Q2 (forecast, v4_koz)');
K = addk(K, 'v4_gain_hist_max', gmx, 'gain', ['Highest KOZ gain 1966Q1-2026Q2, at ' hds{imx}]);
K = addk(K, 'v4_gain_hist_min', gmn, 'gain', ['Lowest KOZ gain 1966Q1-2026Q2, at ' hds{imn}]);
K = addk(K, 'v4_gain_hist_mean', mean(gk), 'gain', 'Average KOZ gain 1966Q1-2026Q2');
K = addk(K, 'v4_gain_2026Q2_full', Lk.gain(qq(2026, 2)), 'gain', 'KOZ gain in 2026Q2 on the RE-smoothed history');
K = addk(K, 'v4_gain_bound_events', sum(strcmp(R.v4_koz_full.events.type, 'gain_bound')), 'events', 'gain_bound events 1966Q1-2026Q2');
for dq = {'1975Q1', '1980Q4', '1990Q1', '2008Q4', '2020Q2', '2021Q4', '2022Q2', '2023Q4'}
    K = addk(K, ['v4_gain_' dq{1}], gk(strcmp(hds, dq{1})), 'gain', ['KOZ gain in ' dq{1} ' (RE-smoothed history)']);
end
K = addk(K, 'v4_n2_origin_koz', R.v4_koz.learning.pinf.n2(d22), 'share', 'Learners'' share at 2022Q2 with the KOZ gain');
% evaluation
Tm = EVT.metrics;
Tr = EVT.relative_rmse;
Td = EVT.dm;
samp = {'full', 's1990_2007', 's2008_2019', 's2020_2026'};
for s = 1:numel(samp)
    for v = {'pinfobs', 'dy'}
        for hq = [1 4 8]
            sel = strcmp(Tm.sample, samp{s}) & strcmp(Tm.variant, 'e01_re') & strcmp(Tm.variable, v{1}) & Tm.h == hq;
            K = addk(K, sprintf('ev_rmse_re_%s_%s_h%d', samp{s}, v{1}, hq), Tm.rmse(sel), 'pp annualised', ...
                sprintf('RMSE of the RE benchmark, %s, h = %d, %s', v{1}, hq, samp{s}));
            for vid = es.ids(2:end)
                sr = strcmp(Tr.sample, samp{s}) & strcmp(Tr.variant, vid{1}) & strcmp(Tr.variable, v{1}) & Tr.h == hq;
                sd = strcmp(Td.sample, samp{s}) & strcmp(Td.variant, vid{1}) & strcmp(Td.variable, v{1}) & Td.h == hq;
                K = addk(K, sprintf('ev_rel_%s_%s_%s_h%d', vid{1}, samp{s}, v{1}, hq), Tr.relative_rmse(sr), 'ratio', ...
                    sprintf('Relative RMSE vs RE, %s, %s, h = %d, %s', vid{1}, v{1}, hq, samp{s}));
                K = addk(K, sprintf('ev_dmp_%s_%s_%s_h%d', vid{1}, samp{s}, v{1}, hq), Td.p_value(sd), 'p-value', ...
                    sprintf('DM p-value vs RE, %s, %s, h = %d, %s', vid{1}, v{1}, hq, samp{s}));
            end
        end
    end
end
for vid = es.ids(2:end)
    for v = {'pinfobs', 'dy'}
        sd = strcmp(Td.variant, vid{1}) & strcmp(Td.variable, v{1});
        K = addk(K, sprintf('ev_dm_better_%s_%s', vid{1}, v{1}), sum(Td.p_value(sd) < 0.10 & Td.mean_loss_diff(sd) < 0), ...
            'cells', sprintf('Cells (h = 1-8 x 4 samples) where %s beats RE on %s at p < 0.10', vid{1}, v{1}));
        K = addk(K, sprintf('ev_dm_worse_%s_%s', vid{1}, v{1}), sum(Td.p_value(sd) < 0.10 & Td.mean_loss_diff(sd) > 0), ...
            'cells', sprintf('Cells (h = 1-8 x 4 samples) where %s is worse than RE on %s at p < 0.10', vid{1}, v{1}));
    end
end
K = addk(K, 'ev_n_runs', es.n_runs, 'runs', 'Evaluation runs (variants x origins)');
K = addk(K, 'ev_failures', height(es.failures), 'runs', 'Evaluation runs that failed');
K = addk(K, 'ev_dm_fallbacks', es.dm_fallbacks, 'cells', 'DM cells with the Bartlett fallback');
K = addk(K, 'ev_runtime_parts_s', sum(es.parts.runtime_s), 's', 'Evaluation compute time, sum over parts');
% further numbers quoted in FINDINGS_v3.md
g1 = (R.a1_learn.paths.pinfobs(hz) - R.a1_re.paths.pinfobs(hz)) * sc.pinfobs;
for dq = {'2024Q2', '2025Q3', '2025Q4', '2026Q2'}
    K = addk(K, ['a1_gap_pinf_' dq{1}], g1(strcmp(hs, dq{1})), 'pp annualised', ['Learning-minus-RE inflation gap in ' dq{1}]);
end
g2 = (R.a2_learn.paths.pinfobs(hz) - db.pinfobs(hz)) * sc.pinfobs;
K = addk(K, 'a2_sqgap_share_first4', sum(g2(1:4).^2) / sum(g2.^2), 'share', 'Share of the squared inflation gap of the learning replay in 2022Q3-2023Q2');
for k = 1:4
    K = addk(K, ['a2_gap_pinf_' hs{k}], g2(k), 'pp annualised', ['Learning replay minus data, inflation, ' hs{k}]);
end
K = addk(K, 'a2_gap_pinf_absmax_after_2023Q2', max(abs(g2(5:end))), 'pp annualised', 'Largest absolute inflation gap of the learning replay after 2023Q2');
Lm = R.v1_mc_learn.learning.pinf;
for dq = {'2022Q4', '2024Q1', '2025Q2'}
    K = addk(K, ['v1_n2_model_' dq{1}], 1 - Lm.n1_model(hz(strcmp(hs, dq{1}))), 'share', ['Learners'' share in force in ' dq{1} ', model-consistent RE']);
end
for id = {'v1_mc_learn', 'v2_var3'}
    E = R.(id{1}).events;
    sel = strcmp(E.type, 'projection_plm') & strcmp(E.stage, 'forecast');
    rt = cellfun(@(s) str2double(regexp(s, 'largest root ([0-9.]+)', 'tokens', 'once')), E.detail(sel));
    K = addk(K, ['plm_root_forecast_min__' id{1}], min(rt), 'root', ['Smallest rejected PLM root in the forecast, ' id{1}]);
    K = addk(K, ['plm_root_forecast_max__' id{1}], max(rt), 'root', ['Largest rejected PLM root in the forecast, ' id{1}]);
    K = addk(K, ['plm_quarters_forecast__' id{1}], numel(unique(E.date(sel))), 'quarters', ['Forecast quarters with beliefs kept, ' id{1}]);
end
nm3 = 1 - R.v2_var3.learning.pinf.n1_model(hz);
K = addk(K, 'v2_var3_n2_model_2023Q1', nm3(strcmp(hs, '2023Q1')), 'share', 'Learners'' share in force in 2023Q1 (shares kept 2022Q4-2023Q4), v2_var3');
for hq = [1 8]
    sel = strcmp(Tm.sample, 's2020_2026') & strcmp(Tm.variant, 'e01_re') & strcmp(Tm.variable, 'pinfobs') & Tm.h == hq;
    K = addk(K, sprintf('ev_n_targets_s2020_2026_h%d', hq), Tm.n(sel), 'targets', sprintf('Targets in the 2020-2026 sample at h = %d', hq));
end
for i = find(isEval)'
    K = addk(K, ['ev_events_total__' ids{i}], nev(i), 'events', ['Facility and other engine events over the 138 evaluation runs (all types), ' ids{i}]);
end
write_cols(fullfile(out, 'key_numbers.csv'), {'name', 'value', 'unit', 'description'}, cells_to_cols(K));
fprintf('build_summary_v3: %d key numbers, %d checks (%d pass), %.1f s\n', size(K, 1), size(CH, 1), ...
    sum([CH{:, 2}]), toc(tAll));


% =============================================================================================
function v = ss_value(m, name, fallback)
v = fallback;
try
    s = get(m, 'sstate');
    v = real(s.(name));
catch
    try
        s = get(m, 'steady');
        v = real(s.(name));
    catch
    end
end
end


function st = stage_of(res, dts, withInv)
org = double(res.dates.origin);
dd = double(dts(:));
st = repmat({'forecast'}, numel(dd), 1);
st(dd <= org + 1e-6) = {'history'};
if withInv && strcmp(res.cfg.history.mode, 'inversion')
    s0 = res.cfg.history.inversion.start;
    if isempty(s0)
        s0 = res.dates.init_date;
    end
    st(dd <= org + 1e-6 & dd >= double(s0) - 1e-6) = {'inversion'};
end
end


function x = getv(res, v, dts, sc)
switch v
    case 'ygap'
        x = res.paths.y(dts) - res.paths.yf(dts);
    case 'ms'
        x = 4 * res.paths.ms(dts);
    case 'n2_model_pinf'
        x = 1 - res.learning.pinf.n1_model(dts);
    otherwise
        x = res.paths.(v)(dts) * sc.(v);
end
x = x(:);
end


function sys = sys_from_learning(Lall)
% Minimal closed PLM system from the belief parameter names of res.learning (alpha_<x>,
% beta_<x>, beta_<x>__<u>_l<k>), for hetlearn.plm.blocks and hetlearn.plm.companion.
tg = fieldnames(Lall)';
sys = struct('targets', {tg}, 'maxlag', 1);
for i = 1:numel(tg)
    x = tg{i};
    pn = Lall.(x).params;
    e = struct('target', x, 'isAux', Lall.(x).isAux, 'constant', any(strcmp(pn, ['alpha_' x])), ...
        'reg_names', {{}}, 'reg_lags', zeros(1, 0), 'param_names', {pn});
    for j = 1:numel(pn)
        if strcmp(pn{j}, ['beta_' x])
            e.reg_names{end+1} = x;
            e.reg_lags(end+1) = 1;
        else
            tok = regexp(pn{j}, ['^beta_' x '__(\w+)_l(\d+)$'], 'tokens', 'once');
            if ~isempty(tok)
                e.reg_names{end+1} = tok{1};
                e.reg_lags(end+1) = str2double(tok{2});
            end
        end
    end
    if i == 1
        sys.eq = e;
    else
        sys.eq(i) = e;
    end
    if ~isempty(e.reg_lags)
        sys.maxlag = max(sys.maxlag, max(e.reg_lags));
    end
end
end


function [rho, mu] = plm_stats(sys, Lall, dts)
% Largest root of each target's PLM block and the mean the block implies, by date.
n = numel(dts);
tg = sys.targets;
rho = NaN(n, numel(tg));
mu = NaN(n, numel(tg));
Bk = hetlearn.plm.blocks(sys);
C = cell(1, numel(tg));
for j = 1:numel(tg)
    L = Lall.(tg{j});
    C{j} = zeros(n, numel(L.params));
    for k = 1:numel(L.params)
        C{j}(:, k) = L.(L.params{k})(dts);
    end
end
for t = 1:n
    phi = struct();
    for j = 1:numel(tg)
        phi.(tg{j}) = C{j}(t, :)';
    end
    for b = 1:numel(Bk)
        eqs = Bk(b).eqs;
        [F, r] = hetlearn.plm.companion(sys, phi, eqs);
        rho(t, eqs) = r;
        if isfinite(r) && r < 1
            A = F(2:end, 2:end);
            c = F(2:end, 1);
            m = (eye(size(A)) - A) \ c;
            mu(t, eqs) = m(1:numel(eqs));
        end
    end
end
end


function [tot, con] = loss_rebuild(L, wv, tn, N)
con = zeros(1, numel(tn));
for k = 1:numel(tn)
    v = L.values.(tn{k});
    con(k) = wv(k) * sum(L.disc_factor(1:N) .* v(1:N).^2);
end
tot = sum(con);
end


function v = getfield_or(s, f, d)
v = d;
if isfield(s, f)
    v = s.(f);
end
end


function v = c_or(c, a, b)
v = '';
if isfield(c, a) && isfield(c.(a), b)
    v = c.(a).(b);
end
end


function f = R_facility(R, id)
f = '';
if isfield(R, id)
    f = R.(id).cfg.projection.facility;
else
    c = feval(id);
    if isfield(c, 'projection')
        f = c.projection.facility;
    end
end
end


function d = table_maxdiff(A, B)
% Max abs difference over the numeric columns both tables share (same row order); Inf if the
% rows or text columns differ.
if height(A) ~= height(B)
    d = Inf;
    return
end
d = 0;
vn = intersect(A.Properties.VariableNames, B.Properties.VariableNames, 'stable');
for j = 1:numel(vn)
    x = A.(vn{j});
    y = B.(vn{j});
    if isnumeric(x) && isnumeric(y)
        z = abs(x - y);
        z(isnan(x) & isnan(y)) = 0;
        z(isnan(z)) = Inf;
        d = max([d; z(:)]);
    elseif ~isequal(cellstr(string(x)), cellstr(string(y)))
        d = Inf;
    end
end
end


function K = addk(K, name, value, unit, desc)
if isempty(value)
    value = NaN;
end
K(end+1, :) = {name, double(value(1)), unit, desc};
end


function v = ternary(c, a, b)
if c
    v = a;
else
    v = b;
end
end


function cols = table2cols(T)
cols = cell(1, width(T));
for j = 1:width(T)
    cols{j} = T.(T.Properties.VariableNames{j});
end
end


function cols = cells_to_cols(C)
cols = cell(1, size(C, 2));
for j = 1:size(C, 2)
    c = C(:, j);
    if all(cellfun(@(x) isnumeric(x) || islogical(x), c))
        cols{j} = cellfun(@double, c);
    else
        cols{j} = cellfun(@char, c, 'UniformOutput', false);
    end
end
end


function T = cat_blocks(B)
nC = numel(B{1});
T = cell(1, nC);
for j = 1:nC
    parts = cellfun(@(b) b{j}, B, 'UniformOutput', false);
    T{j} = vertcat(parts{:});
end
end


function write_cols(file, header, cols)
% CSV with one header row; numbers %.10g (NaN empty), text quoted when it holds a comma or quote.
n = numel(cols{1});
S = strings(n, numel(cols));
for j = 1:numel(cols)
    c = cols{j};
    if isnumeric(c) || islogical(c)
        c = double(c(:));
        s = compose("%.10g", c);
        s(isnan(c)) = "";
    else
        s = string(c(:));
        s(ismissing(s)) = "";
        q = contains(s, ",") | contains(s, """");
        s(q) = """" + replace(s(q), """", """""") + """";
    end
    S(:, j) = s;
end
fid = fopen(file, 'w');
if fid < 0
    error('build_summary_v3: cannot write %s', file);
end
fprintf(fid, '%s\n', strjoin(header, ','));
if n > 0
    lines = cellstr(join(S, ",", 2));
    fprintf(fid, '%s\n', lines{:});
end
fclose(fid);
end
