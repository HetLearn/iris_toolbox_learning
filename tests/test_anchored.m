function R = test_anchored(parts)
%TEST_ANCHORED  Anchored RE variant and the backward simulator (DESIGN 11): toy NK and SW07.
%
%   R = test_anchored()         all parts
%   R = test_anchored(parts)    subset of {'toy', 'sw07_collapse',
%                               'sw07_pinf', 'sw07_all', 'sw07_var_all'}
%   Returns a struct array of checks (name, pass, msg).
%
%   Toy (tests/toy_nk):
%   A1 extend_model collapse test incl. re_anchored = true with every n1 = 1
%      (< 1e-10); hetlearn.re_anchor_coefficients: sspace = unit perturbations
%   A2 anchored rational run = model-consistent rational run (random shocks);
%      RE filter history with the anchored toggle = model-consistent history
%   A3 nk3_lead1.model (nk3 without pie{+2}), every forward variable learning,
%      anchored: no leads left; with stable beliefs (AR(2) PLMs, constants,
%      n1 = 0.5) backward_simulate = IRIS simulate for every transition and
%      measurement variable; step with conditions on the backward path = step
%      with IRIS (targets, endogenised shocks)
%   A4 explosive case on nk3_lead1 (fixed shares 0.9, fixed beliefs beta 1.1):
%      IRIS solve fails, the run completes, one 'explosive' event per quarter
%      with largest root > 1
%   A5 VAR(1) learning with the anchored variant, switching: toy nk3 (y, pie
%      learning; leads remain) and nk3_lead1 (all learning; backward model)
%   A6 option error for an unknown re_variant
%   SW07 (results to tests/output/results/, never results/):
%   S1 collapse test incl. re_anchored, coefficient check; the anchored model
%      with all 12 learning has no leads and backward_simulate = IRIS simulate
%      at n1 = 1 from the smoothed 2022Q2 state (transition + measurement)
%   (S0, the bit-identity pin against results/, was removed on 2026-10-18;
%   the stored reference for the new defaults is tests/reference/, see test_gain G14)
%   S2 smoke runs from the 2022Q2 peak, zero shocks, switching (sw07_smoke_run):
%      anchored pinf only; anchored all 12 (per-variable shares); VAR(1) over
%      all 12, anchored

if nargin < 1 || isempty(parts)
    parts = {'toy', 'sw07_collapse', 'sw07_pinf', 'sw07_all', 'sw07_var_all'};
end
parts = cellstr(parts);
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, 'output', 'results');
addpath(here);
addpath(fullfile(here, 'scenarios'));          % test scenarios tsw07_* (not scenarios/)
if any(strcmp(parts, 'toy'))
    R = [R, toy_part(here, outDir)];
end
if any(strcmp(parts, 'sw07_collapse'))
    R = [R, sw07_collapse()];
end
if any(strcmp(parts, 'sw07_pinf'))
    cfg = tsw07_switch_pinf();
    cfg.id = 'sw07_test_anch_pinf';
    cfg.expectations.re_variant = 'anchored';
    cfg.compare_with = {};
    R = [R, sw07_smoke_run(cfg, 'anchored, pinf only', outDir)];
end
if any(strcmp(parts, 'sw07_all'))
    cfg = tsw07_switch_all();
    cfg.id = 'sw07_test_anch_all';
    cfg.expectations.re_variant = 'anchored';
    cfg.compare_with = {};
    R = [R, sw07_smoke_run(cfg, 'anchored, all 12 per-variable', outDir)];
end
if any(strcmp(parts, 'sw07_var_all'))
    cfg = tsw07_switch_all();
    cfg.id = 'sw07_test_var1_all_anch';
    cfg.expectations.re_variant = 'anchored';
    cfg.beliefs.plm.default = 'var1';
    cfg.compare_with = {};
    R = [R, sw07_smoke_run(cfg, 'VAR(1) all 12, anchored', outDir)];
end
end


% =========================================================================
function R = toy_part(here, outDir)
R = struct('name', {}, 'pass', {}, 'msg', {});
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
spec = hetlearn.load_spec(toyDir);
P = feval_in(toyDir, spec.params);
run = @(cfg, varargin) hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true, 'save', false, varargin{:});
hz = qq(2021, 1):qq(2023, 4);
rng(21);

% ---- A1 --------------------------------------------------------------------------
nm = 'anchored A1: collapse test with re_anchored = true and every n1 = 1 reproduces the RE IRFs (< 1e-10)';
try
    meta = hetlearn.extend_model(spec, 'ar1');
    cm = meta.collapse_maxdiff;
    ok = numel(cm) == 3 && all(cm < 1e-10) && meta.anchor_ok && ~isempty(meta.re_states);
    R = add(R, nm, ok, sprintf('br=1 %.1e, br=0 %.1e, anchored %.1e; states %s', cm(1), cm(2), cm(3), ...
        strjoin(meta.re_states, ' ')));
    [~, ai] = hetlearn.re_anchor_coefficients(spec, P);
    R = add(R, 'anchored A1: coefficients from sspace = unit-perturbation simulations', ...
        ai.check_maxdiff < 1e-10, sprintf('max diff %.1e; k_pie %.3g, c_pie %s', ai.check_maxdiff, ...
        ai.k.pie, mat2str(ai.c.pie', 3)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- A2 --------------------------------------------------------------------------
base = struct('model', toyDir);
base.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
base.expectations = struct('mode', 'rational', 'variables', {{'y', 'pie'}});
base.shocks.add = {{'e_g', hz, randn(12, 1)}, {'e_u', hz, 0.5 * randn(12, 1)}, {'e_r', hz, 0.25 * randn(12, 1)}};
nm = 'anchored A2: anchored rational run = model-consistent rational run (random shocks, < 1e-10)';
try
    cM = base;
    cM.id = 'toy_anch_a2_mc';
    cM.expectations.re_variant = 'model_consistent';   % anchored is the default since 2026-10-18
    cA = base;
    cA.id = 'toy_anch_a2_anch';
    cA.expectations.re_variant = 'anchored';
    rM = run(cM);
    rA = run(cA);
    xl = rM.meta.xList(~endsWith(rM.meta.xList, '_exp1_BR'));
    d = maxdiff(rM.paths, rA.paths, [xl, rM.meta.yList], hz);
    R = add(R, nm, d < 1e-10, sprintf('max abs diff %.1e', d));
    oM = hetlearn.load_options(cM, struct());
    oA = hetlearn.load_options(cA, struct());
    HM = hetlearn.re_filter(spec, oM);
    HA = hetlearn.re_filter(spec, oA);
    dh = maxdiff(HM.smooth, HA.smooth, xl, HM.range);
    R = add(R, 'anchored A2: RE filter history with the anchored toggle = model-consistent history (< 1e-9)', ...
        dh < 1e-9 && ~strcmp(HM.hash, HA.hash), sprintf('max abs diff %.1e over %d quarters, separate caches', ...
        dh, numel(HM.range)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- A3 --------------------------------------------------------------------------
spec1 = spec;
spec1.name = 'nk3l1';
spec1.model_file = 'nk3_lead1.model';
nm = 'anchored A3: nk3_lead1, every forward variable learning, anchored: no leads left';
try
    o1 = hetlearn.load_options(struct('model', toyDir, 'expectations', struct('variables', 'all', ...
        're_variant', 'anchored'), 'beliefs', struct('plm', struct('default', 'ar2'))), struct());
    [m1, info1] = hetlearn.load_model(spec1, o1);
    R = add(R, nm, ~info1.has_leads && get(m1, 'maxLead') == 0, sprintf('maxLead %d, learning %s', ...
        get(m1, 'maxLead'), strjoin(info1.learnVars, ',')));
    phi0 = hetlearn.init.re_moments(m1, info1.sys);
    f = fieldnames(phi0);
    for i = 1:numel(f)
        phi0.(f{i})(1) = 0.1 * randn;               % non-zero constants
    end
    Pb = hetlearn.plm.param_values(info1.sys, phi0);
    for i = 1:numel(info1.learnVars)
        x = info1.learnVars{i};
        Pb.(['n1_' x]) = 0.5;
        Pb.(['n2_' x]) = 0.5;
    end
    m1 = assign(m1, Pb);
    [m1, ok1] = hetlearn.engine.solve_model(m1, spec1);
    u = userdata(m1);
    irisSolved = ok1 && ~(isstruct(u) && isfield(u, 'hetlearn_backward'));
    t0 = qq(2001, 1);
    xl = cellstr(get(m1, 'xList'));
    yl = cellstr(get(m1, 'yList'));
    el = cellstr(get(m1, 'eList'));
    d = struct();
    for i = 1:numel(xl)
        d.(xl{i}) = Series(t0 - 6, randn(6, 1));
    end
    for i = 1:numel(yl)
        d.(yl{i}) = Series(t0 - 6, randn(6, 1));
    end
    for i = 1:numel(el)
        d.(el{i}) = Series(t0 - 6, [zeros(6, 1); randn]);
    end
    sI = simulate(m1, d, t0:t0, 'prependInput', true);
    bw = hetlearn.engine.backward_simulate(m1);
    sB = hetlearn.engine.backward_simulate(bw, d, t0);
    dd = maxdiff(sI, sB, [xl(:); yl(:)]', t0);
    R = add(R, ['anchored A3: backward_simulate = IRIS simulate (all transition and measurement ' ...
        'variables; AR(2) PLMs with constants, n1 = 0.5)'], irisSolved && dd < 1e-10, ...
        sprintf('max abs diff %.1e; %d states (%d auxiliary lags), largest root %.4f', dd, bw.nb, ...
        sum(bw.xb_lags > 0), bw.maxroot));
    cond = struct('vars', {{'obs_pie', 'r'}}, 'shocks', {{'e_u', 'e_r'}}, 'targets', [0.3; -0.2]);
    [sI2, dI2] = hetlearn.engine.step(m1, d, t0, cond);
    bw.flag = 'test';
    mB = userdata(m1, struct('hetlearn_backward', bw));
    [sB2, dB2, infoB] = hetlearn.engine.step(mB, d, t0, cond);
    dc = max([maxdiff(sI2, sB2, [xl(:); yl(:)]', t0), abs(dI2.e_u(t0) - dB2.e_u(t0)), abs(dI2.e_r(t0) - dB2.e_r(t0))]);
    ok = dc < 1e-10 && infoB.backward && numel(infoB.events) == 1 ...
        && strcmp(infoB.events(1).type, 'explosive') && abs(sB2.obs_pie(t0) - 0.3) < 1e-9;
    R = add(R, 'anchored A3: step with conditions (obs_pie, r) on the backward path = step with IRIS', ok, ...
        sprintf('max abs diff %.1e incl. endogenised shocks', dc));
catch err
    R = add(R, nm, false, err.message);
end

% ---- A4: explosive ---------------------------------------------------------------------
nm = 'anchored A4: explosive anchored model without leads: run completes, explosive events with root > 1';
try
    cfgX = struct('id', 'toy_anch_explosive', 'model', toyDir);
    cfgX.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
    cfgX.expectations = struct('mode', 'fixed_shares', 'variables', 'all', 're_variant', 'anchored');
    cfgX.shares.fixed_n2 = 0.9;
    cfgX.beliefs.update = 'fixed';
    b11 = struct('alpha', 0, 'beta', 1.1);
    cfgX.beliefs.init = struct('method', 'user', 'values', struct('y', b11, 'pie', b11, 'r', b11));
    cfgX.history.learn = false;
    cfgX.projection.facility = 'none';      % explosive paths are simulated only without restriction (DESIGN 4.4)
    oX = hetlearn.load_options(cfgX, struct());
    [mX, infoX] = hetlearn.load_model(spec1, oX);
    PX = hetlearn.plm.param_values(infoX.sys, struct('y', [0; 1.1], 'pie', [0; 1.1], 'r', [0; 1.1]));
    for i = 1:numel(infoX.learnVars)
        x = infoX.learnVars{i};
        PX.(['n1_' x]) = 0.1;
        PX.(['n2_' x]) = 0.9;
    end
    ws = warning('off', 'all');
    [~, flagX] = solve(assign(mX, PX));
    warning(ws);
    irisFails = ~hasSucceeded(flagX);
    rX = run(cfgX, 'model', struct('spec', spec1, 'm', mX, 'info', infoX));
    ev = rX.events;
    isX = strcmp(ev.type, 'explosive');
    roots = cellfun(@(s) str2double(regexp(s, 'largest abs root ([\d.eE+-]+)', 'tokens', 'once')), ev.detail(isX));
    p = rX.paths.pie(hz);
    ok = irisFails && sum(isX) == numel(hz) && all(roots > 1) && all(isfinite(p)) && abs(p(end)) > abs(p(1));
    R = add(R, nm, ok, sprintf('IRIS flag %s; %d explosive events, root %.4f; pie %.3g -> %.3g', ...
        char(string(flagX)), sum(isX), max([roots; NaN]), p(1), p(end)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- A5: VAR + anchored --------------------------------------------------------------------
nm = 'anchored A5: VAR(1) learning + anchored, switching (nk3: y, pie learning) completes, shares in [0,1]';
try
    cV = base;
    cV.id = 'toy_anch_var';
    cV.expectations.mode = 'switching';
    cV.expectations.re_variant = 'anchored';
    cV.beliefs.plm.default = 'var1';
    cV.switching.intensity = 0.25;
    rV = run(cV);
    rd = rV.dates.record;
    sh = [rV.learning.y.n2(rd); rV.learning.pie.n2(rd)];
    ok = all(sh >= 0 & sh <= 1) && isfield(rV.learning.pie, 'beta_pie__y_l1') && std(rV.learning.pie.n2(hz)) > 0;
    R = add(R, nm, ok, sprintf('n2 range [%.3g, %.3g], %d events', min(sh), max(sh), height(rV.events)));
    cV1 = cV;
    cV1.id = 'toy_anch_var_lead1';
    cV1.expectations.variables = 'all';
    o = hetlearn.load_options(cV1, struct());
    [mV1, iV1] = hetlearn.load_model(spec1, o);
    rV1 = run(cV1, 'model', struct('spec', spec1, 'm', mV1, 'info', iV1));
    sh = [];
    for i = 1:numel(iV1.learnVars)
        sh = [sh; rV1.learning.(iV1.learnVars{i}).n2(rV1.dates.record)]; %#ok<AGROW>
    end
    R = add(R, 'anchored A5: VAR(1) over all 3 forward variables + anchored on nk3_lead1 (backward model) completes', ...
        ~iV1.has_leads && all(sh >= 0 & sh <= 1), sprintf('%d events; n2 range [%.3g, %.3g]', ...
        height(rV1.events), min(sh), max(sh)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- A6 ------------------------------------------------------------------------------------
R = expect_error(R, 'anchored A6: unknown expectations.re_variant is rejected', ...
    @() hetlearn.load_options(struct('expectations', struct('re_variant', 'anchord')), struct()), 'anchored');
end


% =========================================================================
function R = sw07_collapse()
R = struct('name', {}, 'pass', {}, 'msg', {});
spec = hetlearn.load_spec('sw07');
nm = 'anchored S1: SW07 collapse test with re_anchored = true and every n1 = 1 (< 1e-10)';
try
    t0 = tic;
    meta = hetlearn.extend_model(spec, 'ar1');
    cm = meta.collapse_maxdiff;
    [~, ai] = hetlearn.re_anchor_coefficients(spec, []);
    ok = numel(cm) == 3 && all(cm < 1e-10) && ai.check_maxdiff < 1e-9;
    R = add(R, nm, ok, sprintf('br=1 %.1e, br=0 %.1e, anchored %.1e; %d states, coefficient check %.1e (%.1f s)', ...
        cm(1), cm(2), cm(3), numel(meta.re_states), ai.check_maxdiff, toc(t0)));
    fprintf('S1 SW07 states (%d): %s\n', numel(meta.re_states), strjoin(meta.re_states, ' '));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'anchored S1: SW07 anchored all-12 model has no leads; backward_simulate = IRIS simulate (transition + measurement)';
try
    opts = hetlearn.load_options(struct('model', 'sw07', 'expectations', ...
        struct('variables', 'all', 're_variant', 'anchored')));
    [m, info] = hetlearn.load_model(spec, opts);
    H = hetlearn.re_filter(spec, opts);
    origin = qq(2022, 2);
    t = origin + 1;
    d = struct();
    for n = [info.xList(:); info.yList(:); info.eList(:)]'
        x = H.smooth.(n{1});
        d.(n{1}) = clip(x, x.Start, origin);
    end
    rng(3);
    for n = info.eList(:)'
        d.(n{1})(t) = randn;
    end
    sI = simulate(m, d, t:t, 'prependInput', true);
    bw = hetlearn.engine.backward_simulate(m);
    sB = hetlearn.engine.backward_simulate(bw, d, t);
    dd = maxdiff(sI, sB, [info.xList(:); info.yList(:)]', t);
    R = add(R, nm, ~info.has_leads && bw.ok && dd < 1e-9, sprintf( ...
        'max abs diff %.1e; %d transition + %d measurement variables, %d states, largest root %.4f; filter fit %.1e', ...
        dd, numel(info.xList), numel(info.yList), bw.nb, bw.maxroot, H.fit_error));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function [dmax, n] = db_maxdiff(a, b)
% Largest abs difference over the series of a (NaN pattern must agree).
dmax = 0;
n = 0;
f = fieldnames(a);
for i = 1:numel(f)
    x = a.(f{i});
    if ~isa(x, 'Series')
        continue
    end
    n = n + 1;
    if ~isfield(b, f{i})
        dmax = Inf;
        continue
    end
    y = b.(f{i});
    rr = x.Start:x.End;
    u = x(rr);
    v = y(rr);
    if ~isequal(size(u), size(v)) || ~isequal(isnan(u), isnan(v)) || ~isequal(double(x.Start), double(y.Start))
        dmax = Inf;
        continue
    end
    w = abs(u - v);
    dmax = max([dmax; w(~isnan(w))]);
end
end


% =========================================================================
function dmax = maxdiff(a, b, names, hz)
dmax = 0;
for i = 1:numel(names)
    v = abs(a.(names{i})(hz) - b.(names{i})(hz));
    v(isnan(v)) = Inf;
    dmax = max([dmax; v(:)]);
end
end


function P = feval_in(folder, fname)
old = cd(folder);
c = onCleanup(@() cd(old));
P = feval(fname);
end


function R = expect_error(R, name, f, needle)
try
    f();
    R = add(R, name, false, 'no error raised');
catch err
    R = add(R, name, contains(err.message, needle), err.message);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
