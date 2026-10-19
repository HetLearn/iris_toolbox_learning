function R = test_re_states(part)
%TEST_RE_STATES  RE states of the history stage: history.re_states = 'smoothed' | 'filtered' (DESIGN 5.1, 5.2; 2026-10-19).
%
%   R = test_re_states()         every check
%   R = test_re_states('toy')    T1-T2 only (options, cache refresh; a few seconds)
%   R = test_re_states('sw07')   S1-S8 only (SW07 runs, about 1 min)
%
%   T1 options: default 'smoothed'; 'filtered' accepted (string input becomes
%      char); a bad value is hetlearn:options:value; 'filtered' with
%      history.mode = 'inversion' is hetlearn:options:value (the inversion is
%      one-sided by construction)
%   T2 cache: a cached RE filter without the filtered databank (the format
%      written before 2026-10-19) is refreshed, not crashed on: re-filtered,
%      H.filtered present, H.smooth identical to the cached one (max diff 0),
%      the file rewritten; the next call reads it (toy, real-time filter at
%      2011Q3, a cache no other suite uses)
%   S1 'smoothed' (default) reproduces the run made before the option existed:
%      tsw07_switch_pinf (= scenarios/sw07/app1_peak/a1_learn: anchored RE,
%      AR(1) learners on inflation, chi 0.51, engine.step 'fast') against
%      tests/reference/tsw07_switch_pinf_fast.mat (made 2026-10-19 with the
%      pre-change code): every path and learning series max diff 0, events equal
%   S2 re_filter on SW07: H.filtered holds every transition variable and shock of
%      H.smooth; on the last filter date filtered = smoothed (1e-9), for the
%      full-sample filter (2026Q2) and the real-time filter at 2022Q2
%   S3 'filtered': the RE agents' forecast f^RE_t (res.learning.pinf.fRE, made in
%      t) equals E[pinf_{t+1} | data up to t] from an independent IRIS filter
%      call ('output', 'pred') on the ORIGINAL models/sw07/sw07.model, i.e. the RE
%      forecast from the filtered state s_{t|t}; max abs diff over every history
%      quarter < 1e-9
%   S4 covid gap 2020Q1-Q3 (every observable NaN): filtered pinf differs from
%      smoothed pinf (> 1e-3); the 'filtered' run's fitness errors use the
%      filtered values (FE_BR_t = (pinf_{t|t} - fBR_{t-1})^2, FE_RE_t =
%      (pinf_{t|t} - fRE_{t-1})^2, 1e-12; FE_RE_t = 0 in the gap: without data
%      pinf_{t|t} is the RE prediction) and the 'smoothed' run's the smoothed
%      ones; outside the gap filtered pinf = smoothed pinf (observed, 1e-9)
%   S5 history.realtime is orthogonal: 'filtered' with realtime = true has the
%      same history record (fRE, fBR, FE, n2, beliefs) as with realtime = false
%      (1e-10); the forecasts differ (real-time smoothed starting state)
%   S6 history.learn = false with 'filtered': f^RE at the origin = H.filtered
%   S7 the forecast stage starts from the smoothed state under 'filtered' too:
%      the history part of res.paths (every series but <x>_exp1_BR) equals the
%      'smoothed' run's (max diff 0); mode 'rational' gives the same forecast
%      with either setting (1e-10)
%   S8 beliefs.init.method = 'training_ols' reads the same databank: with a
%      training range over the gap (2015Q1-2021Q4) the initial beliefs equal OLS
%      on H.filtered under 'filtered' and on H.smooth by default (1e-10), and
%      the two differ
%   SW07 runs are not saved (hetlearn.run 'save', false).

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));          % tsw07_* test scenarios, ref_maxdiff
if any(strcmp(part, {'all', 'toy'}))
    R = toy_checks(R, here);
end
if any(strcmp(part, {'all', 'sw07'}))
    R = sw07_checks(R, here);
end
end


% =========================================================================
function R = toy_checks(R, here)
toyDir = fullfile(here, 'toy_nk');

% ---- T1: options ---------------------------------------------------------------------------
nm = 're_states T1: default ''smoothed''; ''filtered'' accepted (string becomes char)';
try
    d = hetlearn.defaults();
    o = hetlearn.load_options(struct('history', struct('re_states', "filtered")), struct());
    ok = strcmp(d.history.re_states, 'smoothed') && ischar(o.history.re_states) ...
        && strcmp(o.history.re_states, 'filtered');
    R = add(R, nm, ok, sprintf('default %s, set %s (%s)', d.history.re_states, o.history.re_states, class(o.history.re_states)));
catch err
    R = add(R, nm, false, err.message);
end
R = expect_error(R, 're_states T1: bad value rejected (hetlearn:options:value)', 'hetlearn:options:value', ...
    'history.re_states', @() hetlearn.load_options(struct('history', struct('re_states', 'filter')), struct()));
R = expect_error(R, 're_states T1: ''filtered'' with history.mode = ''inversion'' rejected', 'hetlearn:options:value', ...
    'one-sided', @() hetlearn.load_options(struct('history', struct('re_states', 'filtered', 'mode', 'inversion')), struct()));

% ---- T2: old cache format refreshed ----------------------------------------------------------
nm = 're_states T2: cached RE filter without H.filtered is refreshed (smooth identical, file rewritten)';
try
    spec = hetlearn.load_spec(toyDir);
    o = hetlearn.load_options(struct('id', 'toy_re_states', 'model', toyDir), struct());
    endDate = qq(2011, 3);
    H1 = hetlearn.re_filter(spec, o, 'end', endDate);
    f = H1.file;
    L = load(f, 'H');
    H = L.H;
    if isfield(H, 'filtered')
        H = rmfield(H, 'filtered');                 % the format written before 2026-10-19
    end
    old = H;
    save(f, 'H');
    H2 = hetlearn.re_filter(spec, o, 'end', endDate);
    L2 = load(f, 'H');
    H3 = hetlearn.re_filter(spec, o, 'end', endDate);
    dS = db_maxdiff(H2.smooth, old.smooth);
    ok = ~H2.cached && isfield(H2, 'filtered') && ~isempty(fieldnames(H2.filtered)) && dS == 0 ...
        && isfield(L2.H, 'filtered') && H3.cached && isfield(H3, 'filtered') ...
        && strcmp(H2.hash, old.hash);
    R = add(R, nm, ok, sprintf('refreshed %d, smooth max diff %.3g, file has filtered %d, next call cached %d', ...
        ~H2.cached, dS, isfield(L2.H, 'filtered'), H3.cached));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = sw07_checks(R, here)
org = qq(2022, 2);
gap = qq(2020, 1):qq(2020, 3);
spec = hetlearn.load_spec('sw07');

% ---- S1: 'smoothed' = the pre-change run -------------------------------------------------------
nm = 're_states S1: ''smoothed'' (default) = run made before the option existed (max diff 0, events equal)';
rs = [];
try
    cfg = tsw07_switch_pinf();
    cfg.compare_with = {};
    rs = hetlearn.run(cfg, 'save', false, 'quiet', true);
    B = load(fullfile(here, 'reference', 'tsw07_switch_pinf_fast.mat'), 'ref');
    [d, worst] = ref_maxdiff(rs, B.ref);
    evOk = isequal(rs.events, B.ref.events);
    fprintf('RE_STATES-S1 | tsw07_switch_pinf vs tsw07_switch_pinf_fast.mat: max abs diff %.3g (%s), events equal %d, n2 at 2022Q2 %.6f\n', ...
        d, worst, evOk, rs.learning.pinf.n2(org));
    R = add(R, nm, d == 0 && evOk && strcmp(rs.cfg.history.re_states, 'smoothed'), ...
        sprintf('max abs diff %.3g (%s); events equal %d (%d)', d, worst, evOk, height(rs.events)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S2: the filter output --------------------------------------------------------------------
nm = 're_states S2: H.filtered has every variable and shock of H.smooth; last filter date filtered = smoothed (1e-9)';
H = [];
try
    o = hetlearn.load_options(tsw07_switch_pinf(), struct());
    H = hetlearn.re_filter(spec, o);
    Hrt = hetlearn.re_filter(spec, o, 'end', org);
    names = series_names(H.smooth);
    missing = setdiff(names, series_names(H.filtered));
    d1 = last_date_diff(H, names);
    d2 = last_date_diff(Hrt, names);
    ok = isempty(missing) && d1 < 1e-9 && d2 < 1e-9;
    R = add(R, nm, ok, sprintf('%d series, %d missing in H.filtered; max |filtered - smoothed| at %s %.3g, at %s (real time) %.3g', ...
        numel(names), numel(missing), char(dat2str(H.range(end))), d1, char(dat2str(org)), d2));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S3: f^RE from the filtered state = independent IRIS prediction ----------------------------
nm = 're_states S3: ''filtered'' f^RE_t = E[pinf_{t+1} | data to t], independent IRIS filter of sw07.model (< 1e-9)';
rf = [];
try
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_switch_pinf_filtered';
    cfg.compare_with = {};
    cfg.history.re_states = 'filtered';
    rf = hetlearn.run(cfg, 'save', false, 'quiet', true);
    mo = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true);
    mo = assign(mo, feval_in(spec.folder, spec.params));
    [mo, flag] = solve(mo);
    assert(hasSucceeded(flag), 'solve failed for the original model');
    mo = sstate(mo);
    db = hetlearn.load_database(spec);
    [~, P] = filter(mo, db, hetlearn.util.to_dates(spec.filter_range), 'output', 'pred', 'meanOnly', true);
    td = rf.dates.init_date:org;
    a = rf.learning.pinf.fRE(td);
    b = P.pinf(td + 1);
    dd = abs(a(:) - b(:));
    [dmax, k] = max(dd);
    dvs = 0;
    if ~isempty(rs)
        dvs = max(abs(rs.learning.pinf.fRE(td) - a));
    end
    fprintf('RE_STATES-S3 | fRE (filtered) vs IRIS pred of sw07.model: max abs diff %.3g at %s over %d quarters; fRE filtered vs smoothed max diff %.3g\n', ...
        dmax, char(dat2str(td(k))), numel(td), dvs);
    R = add(R, nm, dmax < 1e-9 && all(isfinite(a)), sprintf('max abs diff %.3g (%s), %d quarters; |filtered - smoothed fRE| up to %.3g', ...
        dmax, char(dat2str(td(k))), numel(td), dvs));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S4: covid gap -------------------------------------------------------------------------------
nm = 're_states S4: covid gap uses the filtered values (filtered != smoothed; FE from H.filtered; FE_RE 0 in the gap)';
try
    assert(~isempty(H) && ~isempty(rf) && ~isempty(rs), 'needs S1-S3');
    dGap = max(abs(H.filtered.pinf(gap) - H.smooth.pinf(gap)));
    obs = [rf.dates.init_date:qq(2019, 4), qq(2020, 4):H.range(end)];
    dObs = max(abs(H.filtered.pinf(obs) - H.smooth.pinf(obs)));
    tt = [gap, qq(2020, 4)];
    Lf = rf.learning.pinf;
    Ls = rs.learning.pinf;
    eF = max(abs(Lf.FE_BR(tt) - (H.filtered.pinf(tt) - Lf.fBR(tt - 1)).^2)) ...
        + max(abs(Lf.FE_RE(tt) - (H.filtered.pinf(tt) - Lf.fRE(tt - 1)).^2));
    eS = max(abs(Ls.FE_BR(tt) - (H.smooth.pinf(tt) - Ls.fBR(tt - 1)).^2)) ...
        + max(abs(Ls.FE_RE(tt) - (H.smooth.pinf(tt) - Ls.fRE(tt - 1)).^2));
    feReGap = max(Lf.FE_RE(gap));
    fprintf('RE_STATES-S4 | gap: max |pinf filtered - smoothed| %.4f (outside the gap %.2g); FE identities %.2g / %.2g; FE_RE filtered in the gap max %.2g\n', ...
        dGap, dObs, eF, eS, feReGap);
    fprintf('RE_STATES-S4 | %s\n', strjoin(arrayfun(@(t) sprintf('%s pinf f %.4f s %.4f', char(dat2str(t)), ...
        H.filtered.pinf(t), H.smooth.pinf(t)), gap, 'UniformOutput', false), '; '));
    ok = dGap > 1e-3 && dObs < 1e-9 && eF < 1e-12 && eS < 1e-12 && feReGap < 1e-16;
    R = add(R, nm, ok, sprintf('gap |f - s| %.4f, outside %.2g; FE checks %.2g, %.2g; FE_RE in the gap %.2g', ...
        dGap, dObs, eF, eS, feReGap));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S5: realtime orthogonal -------------------------------------------------------------------
nm = 're_states S5: ''filtered'' history identical with history.realtime true/false (1e-10); forecasts differ';
try
    assert(~isempty(rf), 'needs S3');
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_switch_pinf_filtered_rt';
    cfg.compare_with = {};
    cfg.history.re_states = 'filtered';
    cfg.history.realtime = true;
    rr = hetlearn.run(cfg, 'save', false, 'quiet', true);
    td = rf.dates.init_date:org;
    dH = 0;
    fl = {'fRE', 'fBR', 'FE_RE', 'FE_BR', 'n2', 'alpha_pinf', 'beta_pinf'};
    for i = 1:numel(fl)
        a = rr.learning.pinf.(fl{i})(td);
        b = rf.learning.pinf.(fl{i})(td);
        e = abs(a - b);
        e(isnan(a) & isnan(b)) = 0;
        dH = max([dH; e(:)]);
    end
    hz = rf.dates.horizon;
    dF = max(abs(rr.paths.pinfobs(hz) - rf.paths.pinfobs(hz)));
    fprintf('RE_STATES-S5 | filtered history realtime vs not: max diff %.3g; forecast pinfobs max diff %.3g\n', dH, dF);
    R = add(R, nm, dH < 1e-10 && dF > 1e-6, sprintf('history max diff %.3g; forecast pinfobs diff %.3g', dH, dF));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S6: history.learn = false -------------------------------------------------------------------
nm = 're_states S6: history.learn = false with ''filtered'': f^RE at the origin = H.filtered.pinf_exp1_RE';
try
    assert(~isempty(H), 'needs S2');
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_switch_pinf_filtered_nolearn';
    cfg.compare_with = {};
    cfg.history.re_states = 'filtered';
    cfg.history.learn = false;
    rn = hetlearn.run(cfg, 'save', false, 'quiet', true);
    a = rn.learning.pinf.fRE(org);
    b = H.filtered.pinf_exp1_RE(org);
    c = H.smooth.pinf_exp1_RE(org);
    R = add(R, nm, abs(a - b) < 1e-12, sprintf('fRE %.12g, filtered %.12g, smoothed %.12g', a, b, c));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S7: the forecast starts from the smoothed state ---------------------------------------------
nm = 're_states S7: forecast starts from the smoothed state (history databank equal, max diff 0; rational forecast equal)';
try
    assert(~isempty(rf) && ~isempty(rs), 'needs S1 and S3');
    hd = rs.dates.full(1):org;
    dPre = 0;
    for n = reshape(fieldnames(rs.paths), 1, [])
        if ~isa(rs.paths.(n{1}), 'Series') || endsWith(n{1}, '_exp1_BR')   % _exp1_BR holds the learners' forecasts
            continue
        end
        a = rf.paths.(n{1})(hd);
        b = rs.paths.(n{1})(hd);
        e = abs(a - b);
        e(isnan(a) & isnan(b)) = 0;
        e(isnan(e)) = Inf;
        dPre = max([dPre; e(:)]);
    end
    c0 = tsw07_peak_re();
    c0.compare_with = {};
    c1 = c0;
    c1.id = 'tsw07_peak_re_filtered';
    c1.history.re_states = 'filtered';
    r0 = hetlearn.run(c0, 'save', false, 'quiet', true);
    r1 = hetlearn.run(c1, 'save', false, 'quiet', true);
    hz = r0.dates.horizon;
    dRe = 0;
    for n = reshape(spec.observables, 1, [])
        dRe = max(dRe, max(abs(r1.paths.(n{1})(hz) - r0.paths.(n{1})(hz))));
    end
    R = add(R, nm, dPre == 0 && dRe < 1e-10, sprintf(['history databank to %s, filtered vs smoothed run: max diff %.3g; ' ...
        'mode rational forecast (observables): max diff %.3g'], char(dat2str(org)), dPre, dRe));
catch err
    R = add(R, nm, false, err.message);
end

% ---- S8: training_ols on the same databank ----------------------------------------------------------
nm = 're_states S8: training_ols initial beliefs = OLS on H.filtered (''filtered'') / H.smooth (default), range over the gap';
try
    assert(~isempty(H), 'needs S2');
    tr = qq(2015, 1):qq(2021, 4);
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_switch_pinf_ols';
    cfg.compare_with = {};
    cfg.history.learn = false;                   % the initial beliefs are recorded at the origin
    cfg.beliefs.init.method = 'training_ols';
    cfg.beliefs.init.training_range = [tr(1), tr(end)];
    r0 = hetlearn.run(cfg, 'save', false, 'quiet', true);
    cfg.history.re_states = 'filtered';
    r1 = hetlearn.run(cfg, 'save', false, 'quiet', true);
    ols = @(D) [ones(numel(tr), 1), D.pinf(tr - 1)] \ D.pinf(tr);   % AR(1) PLM: pinf_t on [1, pinf_{t-1}]
    bF = ols(H.filtered);
    bS = ols(H.smooth);
    p1 = [r1.learning.pinf.alpha_pinf(org); r1.learning.pinf.beta_pinf(org)];
    p0 = [r0.learning.pinf.alpha_pinf(org); r0.learning.pinf.beta_pinf(org)];
    d1 = max(abs(p1 - bF));
    d0 = max(abs(p0 - bS));
    dFS = max(abs(bF - bS));
    R = add(R, nm, d1 < 1e-10 && d0 < 1e-10 && dFS > 1e-4, sprintf(['filtered: alpha %.6f beta %.6f (vs OLS %.2g); ' ...
        'smoothed: alpha %.6f beta %.6f (vs OLS %.2g); filtered - smoothed OLS %.3g'], p1, d1, p0, d0, dFS));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function n = series_names(db)
f = fieldnames(db);
n = f(cellfun(@(x) isa(db.(x), 'Series'), f))';
end


function d = last_date_diff(H, names)
t = H.range(end);
d = 0;
for i = 1:numel(names)
    a = H.filtered.(names{i})(t);
    b = H.smooth.(names{i})(t);
    if isnan(a) && isnan(b)
        continue
    end
    e = abs(a - b);
    if isnan(e)
        e = Inf;
    end
    d = max(d, e);
end
end


function d = db_maxdiff(a, b)
% Max abs difference of every Series of a and b over a's range (NaN = NaN counts as equal).
d = 0;
for n = series_names(a)
    x = a.(n{1});
    if ~isfield(b, n{1})
        d = Inf;
        return
    end
    r = x.Range;
    u = x(r);
    v = b.(n{1})(r);
    e = abs(u - v);
    e(isnan(u) & isnan(v)) = 0;
    e(isnan(e)) = Inf;
    d = max([d; e(:)]);
end
end


function P = feval_in(folder, fname)
addpath(folder);
c = onCleanup(@() rmpath(folder));
P = feval(fname);
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
