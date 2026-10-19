%BUILD_OTHER_MODELS  Application 1 on the ijcb3 and as07 packages: tables, checks, memo numbers (track M3, 2026-10-18).
%
%   run('results/summary_v3/build_other_models.m')      from the project root, after the four runs
%
%   The runs (not done here): res = hetlearn.run(feval(id)) for i1_re, i1_learn (models/ijcb3,
%           scenarios/ijcb3/app1_peak/) and a1as_re, a1as_learn (models/as07,
%           scenarios/as07/app1_peak/); they write results/<id>/.
%   Reads   results/<id>/results.mat of the four scenarios; the package specs and databases; the
%           generated-model metadata (collapse tests, hetlearn.load_model) and the RE filter caches
%           (hetlearn.re_filter); the original model files (models/<name>/<name>.model) for the RE
%           checks, filtered and simulated with IRIS directly.
%   Writes  results/summary_v3/: other_models_paths_long.csv, other_models_learning_long.csv,
%           other_models_key_numbers.csv, other_models_checks.txt.
%   Units   report units = model units x spec.report.scale: ijcb3 pinfobs and robs x 4 (model
%           units % per quarter), yobs x 1; as07 dy x 4, pinfobs and robs x 1 (already % a year).
%           learning_long: shares and belief parameters in model units (pinf, % per quarter, as a
%           deviation from the steady state); persistence = the largest root of the PLM block;
%           perceived_mean = alpha / (1 - beta), model units; perceived_mean_report =
%           scale x (steady state of pinfobs + L x perceived_mean), annualised percent, with L the
%           loading of pinf in the pinfobs measurement equation (ijcb3 1, as07 4; check M6).
%           Rows whose value is not finite are left out (n2_model on the RE-smoothed history; the
%           robs data in the ELB quarters, where the scenario rows hold the smoothed shadow rate).

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % run() executes from the script folder
if exist(fullfile(root, 'run_applications.m'), 'file') ~= 2
    root = pwd;
end
if exist(fullfile(root, 'run_applications.m'), 'file') ~= 2
    error('build_other_models: cannot find the project root (run it from the root).');
end
addpath(root);
setup_paths;
tAll = tic;
out = fullfile(root, 'results', 'summary_v3');
rdir = fullfile(root, 'results');
rep = @(s, n) repmat({s}, n, 1);
dstr = @(d) reshape(hetlearn.util.date_str(d), [], 1);
K = cell(0, 4);                                  % key numbers: name, value, unit, description
CH = cell(0, 3);                                 % checks: name, pass, detail
BP = {};                                         % paths_long blocks
BL = {};                                         % learning_long blocks
TOLC = 1e-10;                                    % collapse test (hetlearn.extend_model)
TOLF = 1e-8;                                     % filter fit (hetlearn.re_filter)

% model, RE scenario, learning scenario, output measure, loading of pinf in pinfobs
MD = {'ijcb3', 'i1_re', 'i1_learn', 'yobs', 1
      'as07', 'a1as_re', 'a1as_learn', 'dy', 4};
LF = {'expectations.mode', 'expectations.variables', 'expectations.re_variant', 'beliefs.info', ...
    'beliefs.plm.default', 'beliefs.update', 'gain.rule', 'gain.value', 'switching.rule', 'switching.memory', ...
    'switching.intensity', 'shares.structure', 'shares.init_n2', 'projection.facility', 'history.mode', ...
    'history.learn', 'history.realtime', 'shocks.source', 'forecast.horizon'};
pd = qq(2015, 1):qq(2026, 2);
pds = dstr(pd);
np = numel(pd);
d22 = qq(2022, 2);
evT = {'projection_plm', 'projection_alm', 'projection_alm_shares', 'explosive', 'rls_missing', 'shares_nan'};
evS = {'history', 'forecast'};
RUNS = cell(0, 5);                               % model, id, ok, detail, runtime

for k = 1:size(MD, 1)
    mn = MD{k, 1};
    idRE = MD{k, 2};
    idL = MD{k, 3};
    ov = MD{k, 4};
    Lp = MD{k, 5};
    spec = hetlearn.load_spec(mn);
    db = hetlearn.load_database(spec);
    sc = spec.report.scale;
    vars = {'pinfobs', 'robs', ov};
    optsL = hetlearn.load_options(feval(idL));

    % ---- M1 collapse test (generated model of the learning scenario; same file for RE) --------
    [~, infoL] = hetlearn.load_model(spec, optsL);
    [~, infoR] = hetlearn.load_model(spec, hetlearn.load_options(feval(idRE)));
    mt = infoL.meta;
    cm = [mt.collapse_maxdiff(:)', mt.collapse_info_maxdiff];
    okC = mt.validated && all(isfinite(cm)) && all(cm < TOLC) && strcmp(infoR.meta.ext_file, mt.ext_file);
    CH(end+1, :) = {sprintf(['M1 %s: collapse test of the extended model (IRFs 40 quarters, every shock; RE shares 1, ' ...
        'beliefs 0: br = true, br = false, anchored, br_info_current) < %g; RE and learning scenario use the same file'], ...
        mn, TOLC), okC, sprintf('%s; max abs %s; anchored-coefficient check %.3g; same file %d', ...
        fname(mt.ext_file), sprintf('%.3g ', cm), getf(infoL.anchor, 'check_maxdiff', NaN), ...
        strcmp(infoR.meta.ext_file, mt.ext_file))};
    P = infoL.params;
    K = addk(K, [mn '_collapse_maxdiff'], max(cm), 'max abs', ['Collapse test, largest IRF difference, ' mn]);

    % ---- M2 RE filter fit -----------------------------------------------------------------
    okF = false;
    try
        H = hetlearn.re_filter(spec, optsL);
        rng = H.range;
        nObs = numel(spec.observables);
        miss = zeros(1, nObs);
        for i = 1:nObs
            miss(i) = sum(isnan(H.data.(spec.observables{i})(rng)));
        end
        elb = isnan(db.robs(rng));
        dff = db.ffr(rng) - db.robs(rng);
        okF = H.fit_error < TOLF && numel(infoL.eList) >= numel(infoL.yList) && miss(strcmp(spec.observables, 'robs')) == 36 ...
            && sum(miss) == 36 && max(abs(dff(~elb))) < 1e-12;
        detF = sprintf(['fit error %.3g; %d shocks (%s) for %d observables; missing observations %s (%s); ' ...
            'ffr = robs outside the ELB quarters to %.3g'], H.fit_error, numel(infoL.eList), strjoin(infoL.eList, ' '), ...
            numel(infoL.yList), sprintf('%d ', miss), strjoin(spec.observables, ' '), max(abs(dff(~elb))));
        K = addk(K, [mn '_filter_fit_error'], H.fit_error, 'max abs', ['RE filter fit error (hetlearn.re_filter), ' mn]);
        K = addk(K, [mn '_filter_missing_robs'], sum(elb), 'quarters', ['Quarters with robs missing (ELB) in the filter range, ' mn]);
    catch e
        detF = ['hetlearn.re_filter failed: ' e.message];
    end
    CH(end+1, :) = {sprintf(['M2 %s: RE filter fit check passes (observables rebuilt through the measurement ' ...
        'equations < %g; at least as many shocks as observables; the only missing data are the 36 ELB quarters of robs)'], ...
        mn, TOLF), okF, detF};

    % ---- M4 runs ok -----------------------------------------------------------------------
    have = true;
    for id = {idRE, idL}
        f = fullfile(rdir, id{1}, 'results.mat');
        if exist(f, 'file') ~= 2
            RUNS(end+1, :) = {mn, id{1}, false, 'results.mat missing', NaN}; %#ok<SAGROW>
            have = false;
            continue
        end
        tmp = load(f, 'res');
        res = tmp.res;
        R.(id{1}) = res;
        c = hetlearn.load_options(feval(id{1}));
        bad = {};
        for q = 1:numel(LF)
            [a, fa] = getpath(res.cfg, LF{q});
            [b, fb] = getpath(c, LF{q});
            if ~(fa && fb && isequal(a, b))
                bad{end+1} = LF{q}; %#ok<SAGROW>
            end
        end
        E = res.events;
        nStop = sum(ismember(E.type, {'explosive', 'shares_nan', 'rls_missing'}));
        okR = isempty(bad) && strcmp(res.cfg.id, id{1}) && strcmp(res.cfg.model, mn) && ~isempty(res.meta.finished) ...
            && hetlearn.util.date_eq(res.dates.origin, d22) && numel(res.dates.horizon) == 16 && nStop == 0 ...
            && hetlearn.util.date_eq(res.dates.origin, hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4)));
        det = sprintf('finished %s, %.1f s, origin %s (= find_peak), %d quarters, %d events, %d explosive/shares_nan/rls_missing', ...
            res.meta.finished, res.meta.runtime_s, char(dat2str(res.dates.origin)), numel(res.dates.horizon), height(E), nStop);
        if ~isempty(bad)
            det = [det, '; options differ from the scenario file: ', strjoin(bad, ', ')]; %#ok<AGROW>
        end
        RUNS(end+1, :) = {mn, id{1}, okR, det, res.meta.runtime_s}; %#ok<SAGROW>
    end
    if ~have
        CH(end+1, :) = {sprintf('M3 %s: RE run = original model', mn), false, 'results missing'};
        continue
    end
    Rre = R.(idRE);
    Rl = R.(idL);
    hz = Rre.dates.horizon;
    hs = dstr(hz);
    nh = numel(hz);

    % ---- M3 RE run = the original model ------------------------------------------------------
    m0 = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', logical(spec.linear));
    m0 = assign(m0, P);
    [m0, fl0] = solve(m0);
    m0 = sstate(m0);
    x0 = get(m0, 'xList');
    y0 = get(m0, 'yList');
    e0 = get(m0, 'eList');
    rng = hetlearn.util.to_dates(spec.filter_range);
    rng = rng(1):rng(end);
    hist = rng(1):d22;
    [~, f0] = filter(m0, db, rng, 'output', 'smooth', 'meanOnly', true);
    eS = 0;
    for v = [x0(:); e0(:)]'
        eS = max(eS, max(abs(f0.(v{1})(hist) - Rre.paths.(v{1})(hist))));
    end
    d0 = f0;
    for i = 1:numel(e0)
        d0.(e0{i})(hz) = 0;
    end
    s0 = simulate(m0, d0, hz, 'anticipate', false);
    eF = 0;
    for v = [x0(:); y0(:)]'
        eF = max(eF, max(abs(s0.(v{1})(hz) - Rre.paths.(v{1})(hz))));
    end
    eZ = 0;
    nN = 0;
    for i = 1:numel(e0)
        z = Rre.paths.(e0{i})(hz);
        nN = nN + sum(isnan(z));
        eZ = max([eZ; abs(z(isfinite(z)))]);
    end
    n2re = max(abs(1 - Rre.learning.pinf.n1_model(hz)));
    CH(end+1, :) = {sprintf(['M3 %s: RE run %s = original model (%s): its own Kalman smoother gives the run''s history ' ...
        '%s-2022Q2 (transition variables and shocks), and its zero-shock simulation from the 2022Q2 state gives the ' ...
        'forecast 2022Q3-2026Q2 (transition and measurement variables); the run''s horizon shocks are 0 and its learners'' ' ...
        'share in the model is 0'], mn, idRE, spec.model_file, char(dat2str(rng(1)))), ...
        hasSucceeded(fl0) && eS < 1e-8 && eF < 1e-9 && eZ == 0 && nN == 0 && n2re == 0, ...
        sprintf('smoother %.3g, forecast %.3g, horizon shocks %.3g (%d NaN), learners'' share %.3g', eS, eF, eZ, nN, n2re)};
    K = addk(K, [mn '_re_vs_original_smoother'], eS, 'max abs', ['Original-model smoother minus the run''s history, ' idRE]);
    K = addk(K, [mn '_re_vs_original_forecast'], eF, 'max abs', ['Original-model zero-shock forecast minus ' idRE ', 2022Q3-2026Q2']);

    % ---- steady state, M6 report conversion ------------------------------------------------
    ssv = struct();
    for v = vars
        ssv.(v{1}) = ss_value(m0, v{1});
    end
    e6 = 0;
    for id = {idRE, idL}
        rr = R.(id{1});
        e6 = max(e6, max(abs(rr.paths.pinfobs(hz) - (ssv.pinfobs + Lp * rr.paths.pinf(hz)))));
    end
    CH(end+1, :) = {sprintf(['M6 %s: report conversion of model inflation: pinfobs = %.4g + %d x pinf in every forecast ' ...
        'quarter of both runs (used for perceived_mean_report)'], mn, ssv.pinfobs, Lp), e6 < 1e-10, sprintf('%.3g', e6)};
    for v = vars
        K = addk(K, sprintf('%s_ss_%s', mn, v{1}), sc.(v{1}) * ssv.(v{1}), 'report units', ...
            sprintf('Steady state of %s (%s), %s', v{1}, spec.report.units.(v{1}), mn));
    end

    % ---- M5 share timing -----------------------------------------------------------------
    L = Rl.learning.pinf;
    E = Rl.events;
    kd = E.date(strcmp(E.type, 'projection_alm_shares') & strcmp(E.stage, 'forecast'));
    use = ~ismember(hs, kd);
    a = L.n1_model(hz);
    b = L.n1(hz - 1);
    e5 = max(abs(a(use) - b(use)));
    CH(end+1, :) = {sprintf(['M5 %s: share timing in %s: n2_model(t) = n2(t-1) in every forecast quarter without ' ...
        'kept shares'], mn, idL), e5 < 1e-12 && any(use), sprintf('%.3g over %d quarters, %d kept-share quarters', ...
        e5, nnz(use), numel(kd))};

    % ---- paths_long ------------------------------------------------------------------------
    for id = {idRE, idL}
        rr = R.(id{1});
        stg = stage_of(rr, pd);
        for v = vars
            x = rr.paths.(v{1})(pd) * sc.(v{1});
            BP{end+1} = {rep(mn, np), rep(id{1}, np), pds, rep(v{1}, np), x(:), rep('scenario', np), stg}; %#ok<SAGROW>
        end
    end
    for v = [vars, {'ffr'}]
        s = 'robs';
        if ~strcmp(v{1}, 'ffr')
            s = v{1};
        end
        x = db.(v{1})(pd) * sc.(s);
        kp = isfinite(x(:));
        BP{end+1} = {rep(mn, nnz(kp)), rep('data', nnz(kp)), pds(kp), rep(v{1}, nnz(kp)), x(kp), ...
            rep('data', nnz(kp)), rep('history', nnz(kp))}; %#ok<SAGROW>
    end

    % ---- learning_long (learning run; the RE run's learning states are diagnostics) ------------
    dts = Rl.dates.record;
    dS = dstr(dts);
    stg = stage_of(Rl, dts);
    sys = sys_from_learning(Rl.learning);
    [rho, mu] = plm_stats(sys, Rl.learning, dts);
    jp = find(strcmp(sys.targets, 'pinf'));
    for j = 1:numel(sys.targets)
        x = sys.targets{j};
        Lx = Rl.learning.(x);
        fl = {};
        vl = {};
        if isfield(Lx, 'n1_model')
            fl{end+1} = 'n2_model'; vl{end+1} = 1 - Lx.n1_model(dts); %#ok<SAGROW>
        end
        if isfield(Lx, 'n2')
            fl{end+1} = 'n2'; vl{end+1} = Lx.n2(dts); %#ok<SAGROW>
        end
        for p = 1:numel(Lx.params)
            fl{end+1} = Lx.params{p}; vl{end+1} = Lx.(Lx.params{p})(dts); %#ok<SAGROW>
        end
        fl{end+1} = 'persistence'; vl{end+1} = rho(:, j); %#ok<SAGROW>
        fl{end+1} = 'perceived_mean'; vl{end+1} = mu(:, j); %#ok<SAGROW>
        if strcmp(x, 'pinf')
            fl{end+1} = 'perceived_mean_report'; vl{end+1} = sc.pinfobs * (ssv.pinfobs + Lp * mu(:, j)); %#ok<SAGROW>
        end
        for f = 1:numel(fl)
            y = vl{f}(:);
            kp = isfinite(y);
            m = nnz(kp);
            BL{end+1} = {rep(mn, m), rep(idL, m), dS(kp), rep(x, m), rep(fl{f}, m), y(kp), stg(kp)}; %#ok<SAGROW>
        end
    end

    % ---- key numbers -------------------------------------------------------------------------
    for id = {idRE, idL}
        rr = R.(id{1});
        for v = vars
            K = addk(K, sprintf('avg_%s__%s', v{1}, id{1}), mean(rr.paths.(v{1})(hz)) * sc.(v{1}), 'report units', ...
                sprintf('Average %s 2022Q3-2026Q2 (%s), %s', v{1}, spec.report.units.(v{1}), id{1}));
        end
        for dq = {'2022Q3', '2023Q2', '2024Q2', '2026Q2'}
            t = find(strcmp(hs, dq{1}));
            for v = vars
                K = addk(K, sprintf('%s_%s__%s', v{1}, dq{1}, id{1}), rr.paths.(v{1})(hz(t)) * sc.(v{1}), 'report units', ...
                    sprintf('%s in %s, %s', v{1}, dq{1}, id{1}));
            end
        end
        K = addk(K, ['runtime_s__' id{1}], rr.meta.runtime_s, 's', ['Runtime of hetlearn.run, ' id{1}]);
        E = rr.events;
        for a = 1:numel(evT)
            for b = 1:numel(evS)
                K = addk(K, sprintf('ev_%s_%s__%s', evT{a}, evS{b}, id{1}), sum(strcmp(E.type, evT{a}) & strcmp(E.stage, evS{b})), ...
                    'events', sprintf('%s events in the %s, %s', evT{a}, evS{b}, id{1}));
            end
        end
        K = addk(K, ['n_events__' id{1}], height(E), 'events', ['All events, ' id{1} ': ' strjoin(strcat(E.date, {' '}, E.type)', '; ')]);
    end
    for v = vars
        g = (Rl.paths.(v{1})(hz) - Rre.paths.(v{1})(hz)) * sc.(v{1});
        [~, im] = max(abs(g));
        K = addk(K, sprintf('gap_avg_%s__%s', v{1}, mn), mean(g), 'pp', sprintf('Average learning-minus-RE gap 2022Q3-2026Q2, %s, %s', v{1}, mn));
        K = addk(K, sprintf('gap_max_%s__%s', v{1}, mn), g(im), 'pp', sprintf('Largest learning-minus-RE gap, %s, %s, at %s', v{1}, mn, hs{im}));
        if strcmp(v{1}, 'pinfobs')
            for dq = {'2022Q3', '2022Q4', '2023Q1', '2023Q2', '2024Q2', '2025Q2', '2026Q2'}
                K = addk(K, sprintf('gap_pinfobs_%s__%s', dq{1}, mn), g(strcmp(hs, dq{1})), 'pp', ...
                    sprintf('Learning-minus-RE inflation gap in %s, %s', dq{1}, mn));
            end
            t4 = find(strcmp(hs, '2023Q2')):nh;
            [~, i4] = max(abs(g(t4)));
            K = addk(K, ['gap_pinfobs_absmax_from_2023Q2__' mn], g(t4(i4)), 'pp', ...
                sprintf('Largest learning-minus-RE inflation gap 2023Q2-2026Q2, at %s, %s', hs{t4(i4)}, mn));
            K = addk(K, ['gap_pinfobs_share_2022Q3__' mn], g(1) / sum(g), 'share', ...
                ['Share of the summed learning-minus-RE inflation gap 2022Q3-2026Q2 that falls in 2022Q3, ' mn]);
            ineg = find(g < 0, 1);
            K = addk(K, ['gap_pinfobs_first_negative_h__' mn], first_or_nan(ineg), 'quarter of the horizon', ...
                sprintf('First forecast quarter with a negative learning-minus-RE inflation gap (%s), %s', ...
                date_or_none(hs, ineg), mn));
            K = addk(K, ['gap_pinfobs_min__' mn], min(g), 'pp', sprintf('Smallest learning-minus-RE inflation gap, %s, at %s', ...
                mn, hs{find(g == min(g), 1)}));
        end
    end
    % shares and beliefs
    nm = 1 - L.n1_model(hz);
    K = addk(K, ['n2_origin__' idL], L.n2(d22), 'share', ['Learners'' share computed at the end of 2022Q2 (in force in 2022Q3), ' idL]);
    for dq = {'2022Q3', '2023Q2', '2024Q2', '2026Q2'}
        K = addk(K, sprintf('n2_model_%s__%s', dq{1}, idL), nm(strcmp(hs, dq{1})), 'share', sprintf('Learners'' share in force in %s, %s', dq{1}, idL));
    end
    K = addk(K, ['n2_model_min__' idL], min(nm), 'share', ['Lowest learners'' share in force 2022Q3-2026Q2, at ' ...
        hs{find(nm == min(nm), 1)} ', ' idL]);
    K = addk(K, ['n2_model_max__' idL], max(nm), 'share', ['Highest learners'' share in force 2022Q3-2026Q2, at ' ...
        hs{find(nm == max(nm), 1)} ', ' idL]);
    hh = Rl.dates.record(1):d22;
    nh2 = L.n2(hh);
    hhs = dstr(hh);
    [mn2, i1] = min(nh2);
    [mx2, i2] = max(nh2);
    K = addk(K, ['n2_hist_mean__' idL], mean(nh2), 'share', sprintf('Average learners'' share %s-2022Q2 (discrete choice, RE-smoothed history), %s', hhs{1}, idL));
    K = addk(K, ['n2_hist_min__' idL], mn2, 'share', sprintf('Lowest learners'' share %s-2022Q2, at %s, %s', hhs{1}, hhs{i1}, idL));
    K = addk(K, ['n2_hist_max__' idL], mx2, 'share', sprintf('Highest learners'' share %s-2022Q2, at %s, %s', hhs{1}, hhs{i2}, idL));
    for dq = {'2019Q4', '2021Q2', '2021Q4', '2022Q1'}
        K = addk(K, sprintf('n2_%s__%s', dq{1}, idL), L.n2(str2dat_q(dq{1})), 'share', sprintf('Learners'' share at the end of %s, %s', dq{1}, idL));
    end
    tr = find(strcmp(dS, '2022Q2'));
    K = addk(K, ['alpha_origin__' idL], L.alpha_pinf(d22), 'model units', ['alpha_pinf at the end of 2022Q2 (% per quarter, deviation from the steady state), ' idL]);
    K = addk(K, ['beta_origin__' idL], L.beta_pinf(d22), 'coefficient', ['beta_pinf at the end of 2022Q2, ' idL]);
    K = addk(K, ['persistence_origin__' idL], rho(tr, jp), 'root', ['Largest root of the inflation PLM at 2022Q2, ' idL]);
    K = addk(K, ['pmean_origin__' idL], sc.pinfobs * (ssv.pinfobs + Lp * mu(tr, jp)), '% annualised', ['Perceived mean inflation at 2022Q2, annualised level, ' idL]);
    K = addk(K, ['pmean_2026Q2__' idL], sc.pinfobs * (ssv.pinfobs + Lp * mu(end, jp)), '% annualised', ['Perceived mean inflation at 2026Q2, annualised level, ' idL]);
    K = addk(K, ['alpha_2026Q2__' idL], L.alpha_pinf(qq(2026, 2)), 'model units', ['alpha_pinf at 2026Q2, ' idL]);
    K = addk(K, ['beta_2026Q2__' idL], L.beta_pinf(qq(2026, 2)), 'coefficient', ['beta_pinf at 2026Q2, ' idL]);
    K = addk(K, ['gain__' idL], Rl.cfg.gain.value, 'gain', ['Constant gain, ' idL]);
    K = addk(K, ['memory__' idL], Rl.cfg.switching.memory, 'memory', ['Memory omega, ' idL]);
    K = addk(K, ['intensity__' idL], Rl.cfg.switching.intensity, 'chi', ['Intensity of choice chi, ' idL]);
    % origin state (data, smoothed state and shocks, model units unless stated)
    for v = vars
        K = addk(K, sprintf('%s_data_avg_%s_2022Q3_2026Q2', mn, v{1}), mean(db.(v{1})(hz)) * sc.(v{1}), 'report units', ...
            sprintf('Average %s 2022Q3-2026Q2, data (not used by the forecasts), %s', v{1}, mn));
        K = addk(K, sprintf('%s_data_%s_2022Q2', mn, v{1}), db.(v{1})(d22) * sc.(v{1}), 'report units', sprintf('%s in 2022Q2, data, %s', v{1}, mn));
        mi = f0.(v{1})(d22);
        for i = 1:numel(e0)
            if startsWith(e0{i}, 'me_') && strcmp(e0{i}, ['me_' v{1}])
                mi = mi - f0.(e0{i})(d22);       % model-implied value: the observable without its measurement error
            end
        end
        K = addk(K, sprintf('%s_model_%s_2022Q2', mn, v{1}), mi * sc.(v{1}), 'report units', ...
            sprintf('%s implied by the smoothed state at 2022Q2 (without measurement error), %s', v{1}, mn));
    end
    for i = 1:numel(x0)
        K = addk(K, sprintf('%s_state_%s_2022Q2', mn, x0{i}), f0.(x0{i})(d22), 'model units', sprintf('Smoothed %s at 2022Q2, %s', x0{i}, mn));
    end
    for i = 1:numel(e0)
        sd = P.(['std_' e0{i}]);
        K = addk(K, sprintf('%s_shock_%s_2022Q2', mn, e0{i}), f0.(e0{i})(d22), 'model units', sprintf('Smoothed %s at 2022Q2, %s', e0{i}, mn));
        K = addk(K, sprintf('%s_shock_sd_%s_2022Q2', mn, e0{i}), f0.(e0{i})(d22) / sd, 'sd', sprintf('Smoothed %s at 2022Q2 in std units (std %.4g), %s', e0{i}, sd, mn));
    end
    % RE return to the steady state
    pre = Rre.paths.pinfobs(hz) * sc.pinfobs;
    pm0 = (f0.pinfobs(d22) - get_or0(f0, 'me_pinfobs', d22)) * sc.pinfobs;
    K = addk(K, ['re_pinf_gap_closed_2026Q2__' mn], 1 - (pre(end) - sc.pinfobs * ssv.pinfobs) / (pm0 - sc.pinfobs * ssv.pinfobs), 'share', ...
        ['Share of the 2022Q2 gap of model inflation to its steady state closed by 2026Q2 under RE, ' mn]);
    K = addk(K, ['re_pinf_gap_closed_2022Q3__' mn], 1 - (pre(1) - sc.pinfobs * ssv.pinfobs) / (pm0 - sc.pinfobs * ssv.pinfobs), 'share', ...
        ['Share of the 2022Q2 gap of model inflation to its steady state closed in 2022Q3 under RE, ' mn]);
    % shadow rate (smoothed robs in the ELB quarters) and episode troughs
    rs = Rre.paths.robs(rng) * sc.robs;
    rss = dstr(rng);
    for ep = {'2009Q1', '2015Q4'; '2020Q2', '2022Q1'}'
        sel = find(strcmp(rss, ep{1})):find(strcmp(rss, ep{2}));
        [mv, im] = min(rs(sel));
        K = addk(K, sprintf('%s_shadow_min_%s_%s', mn, ep{1}, ep{2}), mv, '% annualised', ...
            sprintf('Lowest smoothed (shadow) policy rate %s-%s, at %s, %s', ep{1}, ep{2}, rss{sel(im)}, mn));
        K = addk(K, sprintf('%s_shadow_mean_%s_%s', mn, ep{1}, ep{2}), mean(rs(sel)), '% annualised', ...
            sprintf('Average smoothed (shadow) policy rate %s-%s, %s', ep{1}, ep{2}, mn));
    end
    K = addk(K, [mn '_shadow_2022Q1'], rs(strcmp(rss, '2022Q1')), '% annualised', ['Smoothed (shadow) policy rate in 2022Q1, the last ELB quarter, ' mn]);
    K = addk(K, [mn '_ffr_2022Q1'], db.ffr(qq(2022, 1)) * sc.robs, '% annualised', ['Federal funds rate in 2022Q1, ' mn]);
    if isfield(P, 'r_bar_T') && isfield(P, 'pi_bar')
        K = addk(K, [mn '_trend_real_rate'], sc.robs * (P.r_bar_T - P.pi_bar), '% annualised', ...
            ['r_bar_T - pi_bar, annualised (IJCB HE posterior means): the real rate the RE forecast returns to, ' mn]);
    end
    if isfield(P, 'rA') && isfield(P, 'gammaQ')
        K = addk(K, [mn '_ss_real_rate'], P.rA + 4 * P.gammaQ, '% annualised', ...
            ['rA + 4 gammaQ: steady-state real rate of the 1983-2002 estimates, ' mn]);
    end
    if any(startsWith(e0, 'me_'))
        hm = rng(1):d22;
        for i = find(startsWith(e0, 'me_'))
            vv = e0{i}(4:end);
            z = f0.(e0{i})(hm);
            K = addk(K, sprintf('%s_me_std_%s', mn, vv), std(z, 'omitnan') * sc.(vv), 'report units', sprintf('Std of the smoothed measurement error of %s %s-2022Q2 (model std %.4g, report units), %s', ...
                vv, char(dat2str(rng(1))), P.(['std_' e0{i}]) * sc.(vv), mn));
            K = addk(K, sprintf('%s_me_%s_2022Q2', mn, vv), f0.(e0{i})(d22) * sc.(vv), 'report units', sprintf('Smoothed measurement error of %s at 2022Q2, report units, %s', vv, mn));
        end
    end
end

% ---- runs check -------------------------------------------------------------------------------
okRuns = all(cell2mat(RUNS(:, 3))) && size(RUNS, 1) == 4;
CH(end+1, :) = {['M4 The four runs are ok: results.mat present and finished, options as in the scenario files (' ...
    strjoin(LF, ', ') '), origin 2022Q2 = the CPI inflation peak (hetlearn.find_peak 2020Q1-2024Q4), 16 quarters, ' ...
    'no explosive, shares_nan or rls_missing events'], okRuns, strjoin(strcat(RUNS(:, 2), {': '}, ...
    cellfun(@(b) ternary(b, 'ok', 'FAIL'), RUNS(:, 3), 'UniformOutput', false), {', '}, RUNS(:, 4))', ' | ')};

% ---- write ------------------------------------------------------------------------------------
write_cols(fullfile(out, 'other_models_paths_long.csv'), {'model', 'scenario', 'date', 'variable', 'value', 'source', 'stage'}, ...
    cat_blocks(BP));
write_cols(fullfile(out, 'other_models_learning_long.csv'), {'model', 'scenario', 'date', 'variable', 'field', 'value', 'stage'}, ...
    cat_blocks(BL));
write_cols(fullfile(out, 'other_models_key_numbers.csv'), {'name', 'value', 'unit', 'description'}, cells_to_cols(K));
[~, ord] = sort(cellfun(@(s) s(1:2), CH(:, 1), 'UniformOutput', false));
CH = CH(ord, :);
fid = fopen(fullfile(out, 'other_models_checks.txt'), 'w');
fprintf(fid, 'other_models_checks.txt: build_other_models.m, %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM')); %#ok<TNOW1,DATST>
for k = 1:size(CH, 1)
    fprintf(fid, '%s  %s\n      %s\n', ternary(CH{k, 2}, 'PASS', 'FAIL'), CH{k, 1}, CH{k, 3});
end
fprintf(fid, '\n%d of %d checks pass\n', sum([CH{:, 2}]), size(CH, 1));
fclose(fid);
fprintf('\n%s\n', fileread(fullfile(out, 'other_models_checks.txt')));
for k = 1:size(K, 1)
    fprintf('%-48s %14.6g  %s\n', K{k, 1}, K{k, 2}, K{k, 4});
end
fprintf('build_other_models: %d key numbers, %d checks (%d pass), %.1f s\n', size(K, 1), size(CH, 1), ...
    sum([CH{:, 2}]), toc(tAll));


% =============================================================================================
function v = ss_value(m, name)
s = get(m, 'sstate');
v = real(s.(name));
end


function x = get_or0(d, name, t)
x = 0;
if isfield(d, name)
    x = d.(name)(t);
end
end


function t = str2dat_q(s)
t = qq(str2double(s(1:4)), str2double(s(6)));
end


function v = first_or_nan(i)
v = NaN;
if ~isempty(i)
    v = i;
end
end


function s = date_or_none(hs, i)
s = 'none';
if ~isempty(i)
    s = hs{i};
end
end


function s = fname(f)
[~, a, b] = fileparts(f);
s = [a, b];
end


function v = getf(s, f, d)
v = d;
if isstruct(s) && isfield(s, f)
    v = s.(f);
end
end


function [v, ok] = getpath(s, p)
% Value at a dotted option path; ok false if a level is missing.
v = [];
ok = true;
parts = strsplit(p, '.');
for i = 1:numel(parts)
    if ~isstruct(s) || ~isfield(s, parts{i})
        ok = false;
        return
    end
    s = s.(parts{i});
end
v = s;
end


function st = stage_of(res, dts)
org = double(res.dates.origin);
dd = double(dts(:));
st = repmat({'forecast'}, numel(dd), 1);
st(dd <= org + 1e-6) = {'history'};
end


function sys = sys_from_learning(Lall)
% Minimal closed PLM system from the belief parameter names of res.learning (as build_summary_v3.m).
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
% Largest root of each target's PLM block and the mean the block implies, by date (as build_summary_v3.m).
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
    error('build_other_models: cannot write %s', file);
end
fprintf(fid, '%s\n', strjoin(header, ','));
if n > 0
    lines = cellstr(join(S, ",", 2));
    fprintf(fid, '%s\n', lines{:});
end
fclose(fid);
end
