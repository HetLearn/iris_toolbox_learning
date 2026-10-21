function R = test_kalman(part)
%TEST_KALMAN  history.mode = 'kalman': time-varying Kalman filter of the ALM (DESIGN_br_extensions 5, phase P1).
%
%   R = test_kalman()            every check
%   R = test_kalman('options')   KO only (a few seconds)
%   R = test_kalman('sw07')      K1-K5 (SW07 runs, about 2 min)
%
%   KO options: history.mode = 'kalman' loads (the P1 guard of load_options is gone),
%      history.kalman.init 'stochastic' (default) | 'smoothed', a bad init and
%      history.re_states = 'filtered' with 'kalman' are hetlearn:options:value
%   K1 every agent RE (mode 'rational', baseline tsw07_a1_re, 'stochastic' start): the
%      one-step prediction errors = those of the IRIS filter of the RE(t-1) model
%      (data - H.predicted of hetlearn.re_filter), every observation 1965Q1-2026Q2, same
%      missing pattern (< 1e-9); history.learn = false is hetlearn:engine:kalman
%   K2 'smoothed' start (P = 0 at the RE-smoothed 1965Q4 state), baseline tsw07_a1_learn:
%      beliefs alpha, beta, shares n1, model shares and the forecasts fRE, fBR = those of
%      the inversion history (history.mode = 'inversion') 1966Q1-2019Q4 (< 1e-10)
%   K3 fixed beliefs (beliefs.update = 'fixed') and shares (mode 'fixed_shares', fixed_n2
%      0.5), 'smoothed' start, to 2026Q2: one-step errors and filtered transition variables
%      = IRIS filter of that fixed ALM from the same state (InitCond = H.smooth: the
%      RE-smoothed 1965Q4 state, MSE 0) (< 1e-9); P > 0 after the 2020 gap
%   K4 expectations.re_info = 'current' with the a1_learn settings of the test calibration
%      (constant gain 0.0585, chi 0.51, memory 0.6, facility 'plm_alm', swX1 parameters),
%      'stochastic' start, 1965Q1-2026Q2: l_t, the log likelihood from 1966Q1, beliefs,
%      shares, model shares, forecasts and facility events = hlest.loglik_learn at the same
%      parameters (estimation/, read only; < 1e-8)
%   K5 outputs: the forecast starts from the filtered state at the origin (D12: res.paths
%      at the origin, lags included, = res.kalman.a_origin, exact; <x>_exp1_BR to 1e-12,
%      since res.paths holds the learners' recorded forecasts there); res.kalman fields;
%      hetlearn.run writes kalman_errors.csv when it saves (tests/output/results/; values
%      = res.kalman to 1e-12) and a later 're_smoother' run of the id deletes it
%   SW07 runs are not saved, except the K5 pair (tests/output/results/).

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));          % tsw07_* test scenarios and the test master_options
if any(strcmp(part, {'all', 'options'}))
    R = option_checks(R);
end
if any(strcmp(part, {'all', 'sw07'}))
    R = sw07_checks(R, here);
end
end


% =========================================================================
function R = option_checks(R)
nm = 'kalman KO: history.mode ''kalman'' loads; init ''stochastic'' (default) | ''smoothed''';
try
    o = hetlearn.load_options(struct('history', struct('mode', 'kalman')), struct());
    o2 = hetlearn.load_options(struct('history', struct('mode', 'kalman', 'kalman', struct('init', "smoothed"))), struct());
    ok = strcmp(o.history.mode, 'kalman') && strcmp(o.history.kalman.init, 'stochastic') ...
        && ischar(o2.history.kalman.init) && strcmp(o2.history.kalman.init, 'smoothed');
    R = add(R, nm, ok, sprintf('init %s / %s', o.history.kalman.init, o2.history.kalman.init));
catch err
    R = add(R, nm, false, err.message);
end
R = expect_error(R, 'kalman KO: history.re_states = ''filtered'' with ''kalman'' rejected', 'hetlearn:options:value', ...
    'one-sided', @() hetlearn.load_options(struct('history', struct('mode', 'kalman', 're_states', 'filtered')), struct()));
R = expect_error(R, 'kalman KO: unknown history.kalman.init rejected', 'hetlearn:options:value', ...
    'history.kalman.init', @() hetlearn.load_options(struct('history', struct('mode', 'kalman', ...
    'kalman', struct('init', 'zero'))), struct()));
end


% =========================================================================
function R = sw07_checks(R, here)
spec = hetlearn.load_spec('sw07');
run = @(c) hetlearn.run(c, 'save', false, 'quiet', true);
gap = qq(2020, 1):qq(2020, 3);

% ---- K1: every agent RE = IRIS filter of the RE(t-1) model ------------------------------------
nm = 'kalman K1: mode rational, stochastic start: one-step errors = IRIS filter of the RE(t-1) model (< 1e-9)';
try
    c = kalman_cfg(tsw07_a1_re(), 'tk_k1', qq(2026, 2), 'stochastic');
    r1 = run(c);
    H = hetlearn.re_filter(spec, hetlearn.load_options(c));
    K = r1.kalman;
    vI = NaN(size(K.err));
    for i = 1:numel(K.observables)
        n = K.observables{i};
        vI(i, :) = reshape(H.data.(n)(K.dates) - H.predicted.(n)(K.dates), 1, []);
    end
    same = isequal(isfinite(vI), isfinite(K.err));
    okv = isfinite(vI) & isfinite(K.err);
    d1 = max(abs(K.err(okv) - vI(okv)));
    fprintf('KALMAN-K1 | %d observations %s-%s: max |v_kalman - v_iris| %.3g; missing pattern equal %d; %d solves; log lik %.4f\n', ...
        nnz(okv), char(dat2str(K.dates(1))), char(dat2str(K.dates(end))), d1, same, K.n_solve, K.loglik);
    R = add(R, nm, same && d1 < 1e-9 && nnz(okv) > 1600 && all(K.llt(K.n_obs > 0) < 0), ...
        sprintf('%d observations, max diff %.3g, missing pattern equal %d', nnz(okv), d1, same));
catch err
    R = add(R, nm, false, err.message);
end
c = kalman_cfg(tsw07_a1_learn(), 'tk_nolearn', qq(2022, 2), 'stochastic');
c.history.learn = false;
R = expect_error(R, 'kalman K1: history.learn = false with ''kalman'' is hetlearn:engine:kalman', ...
    'hetlearn:engine:kalman', 'history.learn', @() run(c));

% ---- K2: smoothed start = inversion -----------------------------------------------------------
nm = 'kalman K2: smoothed start (P = 0 at the RE-smoothed 1965Q4 state) = inversion history 1966Q1-2019Q4 (< 1e-10)';
try
    c = kalman_cfg(tsw07_a1_learn(), 'tk_k2', qq(2019, 4), 'smoothed');
    r2 = run(c);
    ci = c;
    ci.id = 'tk_k2_inv';
    ci.history.mode = 'inversion';
    rI = run(ci);
    td = qq(1966, 1):qq(2019, 4);
    f = {'alpha_pinf', 'beta_pinf', 'n1', 'n1_model', 'fRE', 'fBR', 'FE_RE', 'FE_BR'};
    dd = zeros(1, numel(f));
    for i = 1:numel(f)
        a = r2.learning.pinf.(f{i})(td);
        b = rI.learning.pinf.(f{i})(td);
        e = abs(a - b);
        e(isnan(a) & isnan(b)) = 0;
        e(isnan(e)) = Inf;
        dd(i) = max(e);
    end
    dx = max(abs(r2.kalman.filtered.pinf(td) - rI.paths.pinf(td)));
    txt = strjoin(cellfun(@(a, b) sprintf('%s %.2g', a, b), f, num2cell(dd), 'UniformOutput', false), ', ');
    fprintf('KALMAN-K2 | %s-%s: %s; filtered pinf vs inversion %.2g; n2 at 2019Q4 %.4f\n', char(dat2str(td(1))), ...
        char(dat2str(td(end))), txt, dx, r2.learning.pinf.n2(td(end)));
    R = add(R, nm, all(dd < 1e-10) && dx < 1e-10 && strcmp(r2.kalman.init, 'smoothed'), sprintf('%s; pinf %.2g', txt, dx));
catch err
    R = add(R, nm, false, err.message);
end

% ---- K3: fixed beliefs and shares = IRIS filter of the fixed ALM --------------------------------
nm = 'kalman K3: fixed beliefs and shares, smoothed start: errors and filtered states = IRIS filter of that ALM (< 1e-9)';
try
    c = kalman_cfg(tsw07_a1_learn(), 'tk_k3', qq(2026, 2), 'smoothed');
    c.expectations.mode = 'fixed_shares';
    c.shares.fixed_n2 = 0.5;
    c.beliefs.update = 'fixed';
    r3 = run(c);
    o = hetlearn.load_options(c);
    [m, info] = hetlearn.load_model(spec, o);
    H = hetlearn.re_filter(spec, o);
    n1m = struct('pinf', 0.5);
    P = hetlearn.engine.facility('params', info.sys, r3.state.phi, info.learnVars, n1m);
    m = assign(m, P);
    [m, flag] = solve(m);
    assert(hasSucceeded(flag), 'the fixed ALM does not solve');
    t0 = r3.kalman.start;
    td = t0:r3.kalman.origin;
    [~, F] = filter(m, H.data, td, 'initCond', H.smooth, 'output', 'pred,filter', 'meanOnly', true);
    K = r3.kalman;
    vI = NaN(size(K.err));
    for i = 1:numel(K.observables)
        n = K.observables{i};
        vI(i, :) = reshape(H.data.(n)(td) - F.pred.(n)(td), 1, []);
    end
    okv = isfinite(vI) & isfinite(K.err);
    dv = max(abs(K.err(okv) - vI(okv)));
    dx = 0;
    xl = reshape(cellstr(get(m, 'xList')), 1, []);
    for i = 1:numel(xl)
        a = K.filtered.(xl{i})(td);
        b = F.filter.(xl{i})(td);
        dx = max(dx, max(abs(a - b)));
    end
    beta = r3.learning.pinf.beta_pinf(td);
    pmax = max(diag(K.P_origin));
    fprintf(['KALMAN-K3 | %s-%s: one-step errors vs IRIS filter of the fixed ALM %.3g (%d obs), filtered states %.3g ' ...
        '(%d variables); beliefs constant %d; max diag P at the origin %.3g\n'], char(dat2str(td(1))), char(dat2str(td(end))), ...
        dv, nnz(okv), dx, numel(xl), all(beta == beta(1)), pmax);
    R = add(R, nm, dv < 1e-9 && dx < 1e-9 && all(beta == beta(1)) && nnz(okv) > 1600 && pmax > 0, ...
        sprintf('errors %.3g, filtered states %.3g, %d observations, max diag P at the origin %.3g', dv, dx, nnz(okv), pmax));
catch err
    R = add(R, nm, false, err.message);
end

% ---- K4: = hlest.loglik_learn (re_info 'current', a1_learn settings) ------------------------------
nm = 'kalman K4: re_info current, a1_learn settings, stochastic start = hlest.loglik_learn at the same parameters (< 1e-8)';
try
    est = fullfile(fileparts(here), 'estimation');
    addpath(est);
    cl = onCleanup(@() rmpath(est));
    pb = hlest.problem('learn');                 % a1_learn under the test master_options
    x0 = pb.tab.x0;
    [ll, out] = hlest.loglik_learn(pb, x0, 'paths', true);
    c = kalman_cfg(a1_learn(), 'tk_k4', qq(2026, 2), 'stochastic');
    c.expectations.re_info = 'current';
    c.gain.rule = 'constant';
    c.gain.value = x0(pb.ig);
    c.switching.memory = x0(pb.iom);
    c.switching.intensity = x0(pb.ichi);
    c.projection.facility = 'plm_alm';
    r4 = run(c);
    K = r4.kalman;
    % the same parameters: the 36 estimated SW07 entries in the run's model
    P = hlest.theta_struct(pb, x0);
    [mR, ~] = hetlearn.load_model(spec, hetlearn.load_options(c));
    pm = get(mR, 'parameters');
    sd = get(mR, 'std');
    dp = 0;
    for j = 1:pb.nstruct
        g = pb.tab.target{j};
        if isfield(pm, g)
            dp = max(dp, abs(pm.(g) - P.(g)));
        else
            dp = max(dp, abs(sd.(g) - P.(g)));
        end
    end
    assert(isequal(round(100*double(K.dates)), round(100*pb.dates)), 'filter dates differ');
    dl = max(abs(K.llt - out.llt));
    dL = abs(K.loglik - ll);
    td = qq(1966, 1):qq(2026, 2);
    idx = pb.t0:pb.nT;
    Lg = r4.learning.pinf;
    cmp = @(a, b) max(abs(reshape(a, 1, []) - reshape(b, 1, [])));
    d = [cmp(Lg.alpha_pinf(td), out.phi(1, idx)), cmp(Lg.beta_pinf(td), out.phi(2, idx)), cmp(Lg.n1(td), out.n1(idx)), ...
        cmp(Lg.n1_model(td), out.n1m(idx)), cmp(Lg.fRE(td), out.fRE(idx)), cmp(Lg.fBR(td), out.fBR(idx))];
    evE = {};
    if ~isempty(r4.events)
        keep = ismember(r4.events.type, {'projection_plm', 'projection_alm', 'projection_alm_shares'});
        evE = reshape(sort(r4.events.date(keep)), 1, []);
    end
    evL = {};
    for q = 1:size(out.events, 2)
        if out.events(2, q) <= 3
            evL{end+1} = char(dat2str(qq(1965, 1) + out.events(1, q) - 1)); %#ok<AGROW>
        end
    end
    evL = sort(evL);
    evOk = isequal(evE, evL);
    fprintf(['KALMAN-K4 | parameters max diff %.2g; l_t max diff %.3g; log lik 1966Q1-2026Q2 kalman %.8f, loglik_learn ' ...
        '%.8f (diff %.3g); alpha %.2g beta %.2g n1 %.2g n1_model %.2g fRE %.2g fBR %.2g; events kalman {%s} ' ...
        'loglik_learn {%s}\n'], dp, dl, K.loglik, ll, dL, d, strjoin(evE, ','), strjoin(evL, ','));
    R = add(R, nm, dp == 0 && dl < 1e-8 && dL < 1e-7 && all(d < 1e-8) && evOk && strcmp(out.status, 'ok'), ...
        sprintf('l_t %.3g, log lik %.10g vs %.10g (diff %.3g), paths max %.3g, events equal %d (%d)', dl, K.loglik, ll, ...
        dL, max(d), evOk, numel(evE)));
catch err
    R = add(R, nm, false, getReport(err, 'basic'));
end

% ---- K5: forecast start (D12), res.kalman, kalman_errors.csv --------------------------------------
nm = 'kalman K5: forecast from the filtered state at the origin (D12); res.kalman; kalman_errors.csv written / removed';
try
    outDir = fullfile(here, 'output', 'results');
    c = kalman_cfg(tsw07_a1_learn(), 'tk_k5', qq(2022, 2), 'stochastic');
    c.forecast.horizon = 4;
    r5 = hetlearn.run(c, 'save', true, 'quiet', true, 'results_dir', outDir);
    K = r5.kalman;
    org = r5.dates.origin;
    da = 0;
    dBR = 0;                                       % <x>_exp1_BR: res.paths holds the learners' forecasts (assemble)
    for i = 1:numel(K.state_names)
        tok = regexp(K.state_names{i}, '^(\w+)\{-(\d+)\}$', 'tokens', 'once');
        if isempty(tok)
            n = K.state_names{i};
            v = r5.paths.(n)(org);
        else
            n = tok{1};
            v = r5.paths.(n)(org - str2double(tok{2}));
        end
        if endsWith(n, '_exp1_BR')
            dBR = max(dBR, abs(v - K.a_origin(i)));
        else
            da = max(da, abs(v - K.a_origin(i)));
        end
    end
    f = {'init', 'start', 'origin', 'dates', 'loglik_start', 'observables', 'y', 'pred', 'err', 'F', 'llt', 'n_obs', ...
        'loglik', 'filtered', 'predicted', 'state_names', 'a_origin', 'P_origin', 'n_solve', 'runtime_s', 'fbr_model_maxdiff'};
    fieldsOk = all(isfield(K, f)) && size(K.F, 3) == numel(K.dates) && isequal(size(K.err), [numel(K.observables), numel(K.dates)]);
    gapOk = all(K.n_obs(ismember(round(100*double(K.dates)), round(100*double(gap)))) == 0);
    file = fullfile(outDir, c.id, 'kalman_errors.csv');
    T = readtable(file, 'TextType', 'string');
    obs = K.observables;
    E = NaN(numel(obs), height(T));
    for i = 1:numel(obs)
        E(i, :) = T.(['err_' obs{i}])';
    end
    okE = isfinite(K.err) | isfinite(E);
    dE = max(abs(E(okE) - K.err(okE)));
    csvOk = height(T) == numel(K.dates) && width(T) == 3 + 3*numel(obs) && dE < 1e-12 ...
        && max(abs(T.llt' - K.llt)) < 1e-9;
    c2 = c;
    c2.history.mode = 're_smoother';
    hetlearn.run(c2, 'save', true, 'quiet', true, 'results_dir', outDir);
    gone = exist(file, 'file') ~= 2;
    fprintf(['KALMAN-K5 | state at %s: max |paths - a_origin| %.3g over %d elements (pinf_exp1_BR, the learners'' ' ...
        'forecast in res.paths, %.2g); fields %d; gap quarters without data %d; kalman_errors.csv %dx%d, max diff %.3g; ' ...
        'removed by the re_smoother run %d; fBR vs model %.2g\n'], char(dat2str(org)), da, numel(K.state_names), dBR, ...
        fieldsOk, gapOk, height(T), width(T), dE, gone, K.fbr_model_maxdiff);
    R = add(R, nm, da == 0 && dBR < 1e-12 && fieldsOk && gapOk && csvOk && gone && K.fbr_model_maxdiff < 1e-12, ...
        sprintf('paths vs a_origin %.3g (exp1_BR %.2g); fields %d; csv %d (max diff %.3g); removed %d; fBR vs model %.2g', ...
        da, dBR, fieldsOk, csvOk, dE, gone, K.fbr_model_maxdiff));
catch err
    R = add(R, nm, false, getReport(err, 'basic'));
end
end


% =========================================================================
function c = kalman_cfg(c, id, origin, init)
c.id = id;
c.compare_with = {};
c.forecast.origin = origin;
c.forecast.horizon = 1;
c.history.mode = 'kalman';
c.history.re_states = 'smoothed';             % required with 'kalman' (the baseline sets 'filtered')
c.history.kalman.init = init;
end


function R = expect_error(R, name, id, needle, fun)
try
    fun();
    R = add(R, name, false, 'no error raised');
catch err
    R = add(R, name, strcmp(err.identifier, id) && contains(err.message, needle), ...
        sprintf('%s: %s', err.identifier, err.message));
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
