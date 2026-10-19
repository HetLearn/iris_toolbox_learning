function R = test_re_info(part)
%TEST_RE_INFO  RE agents' information set: expectations.re_info = 'current' | 'lagged' (DESIGN 19; 2026-10-19).
%
%   R = test_re_info()               every check
%   R = test_re_info('toy')          T0, T3, T4 (toy), T6a (toy): options, closed form, collapse (about 1 min)
%   R = test_re_info('sw07_model')   T1, T2, T4 (SW07), T6a/T6b (SW07): model-level checks (about 1.5 min)
%   R = test_re_info('sw07_runs')    T5: end-to-end SW07 runs (about 3 min)
%   R = test_re_info('sw07_stages')  T5 (other stages): inversion, conditions, decomposition, density,
%                                    evaluation with 'lagged' (about 3 min)
%
%   T0 options: default 'current'; 'lagged' accepted (a string becomes char);
%      a bad value is hetlearn:options:value; 'lagged' with an empty learning
%      set is hetlearn:options:value; 'lagged' with policy.mode = 'ramsey' is
%      hetlearn:options:unsupported; a learning variable with a lead of 2 (toy
%      nk3 pie{+2}) is hetlearn:load_model:reInfo
%   T1 SW07, learning set {pinf}: the toolbox's RE model with re_info 'lagged'
%      (mode 'rational', anchored and model-consistent) = the hand-written
%      reference tests/models/sw07_re_lagged_pinf.model (every E_t pinf_{t+1}
%      replaced by E_{t-1} pinf_{t+1} by hand): IRFs of every original
%      variable to every shock, 40 periods, < 1e-10; steady state < 1e-10
%   T2 the same toolbox model = Dynare 4.6.1 with EXPECTATION(-1)(pinf(+1))
%      (tests/models/dynare/sw07_re_lagged_pinf.mod, run once by
%      run_dynare_check.m; tests/reference/re_info_dynare_irfs.mat): IRFs of
%      the 40 Dynare variables, 7 shocks, 40 periods, < 1e-8
%   T3 closed form (tests/models/nkpc): pi_t = bet E_{t-1} pi_{t+1} + kap x_t
%      + u_t, AR(1) x and u: the toolbox's lagged RE model (both variants) has
%      the analytic IRFs (1e-12); the lagged anchored coefficients equal
%      kap rho_x^2/(1-bet rho_x) and rho_u^2/(1-bet rho_u) on x_{t-1}, u_{t-1}
%      (1e-12); the current ones kap rho_x/(1-bet rho_x), rho_u/(1-bet rho_u)
%   T4 n1 = 1: anchored + 'lagged' = model-consistent + 'lagged' = the RE(t-1)
%      reference (SW07 {pinf}; toy nk3_lead1 {y, pie, r}; IRFs < 1e-10); the
%      generator's lagged collapse passes (meta of the _relag files: br =
%      false = original, anchored = model-consistent with every lead-1
%      variable learning, br_info_current, all < 1e-10; version 5); a full
%      'rational' run gives the same forecast under both variants (1e-9)
%   T5 end to end (SW07, tsw07_switch_pinf = a1_learn and tsw07_peak_re = a1_re
%      with 'lagged'): every combination of beliefs.info, re_variant and
%      history.re_states runs; the RE filter of the lagged model fits the data
%      (< 1e-8); f^RE_t (forecast made in t of pinf_{t+1} with information up
%      to t-1) = an independent two-step-ahead computation from the
%      hand-written RE(t-1) model: from its smoothed state at t-1 under
%      'smoothed', IRIS's two-step prediction ('ahead', 2) under 'filtered'
%      (1e-9); FE^RE_t = (pinf_t - f^RE_{t-1})^2 (1e-12); f^RE does not depend
%      on beliefs.info; history.realtime leaves the 'filtered' history
%      unchanged (1e-10); the first forecast quarter's RE expectation is the
%      smoothed one (predetermined, 1e-10); other stages: the RE inversion
%      reproduces the lagged RE-smoothed shocks (< 1e-8), the learning
%      inversion completes, conditions hit their targets, decompositions add
%      up (IRIS and 'tv'), the density fast path = the general path, the
%      evaluation runs a lagged variant and equals a direct real-time run
%   T6 defaults unchanged: (a) the generator's default output for the toy and
%      SW07 packages is byte-identical to the files the pre-change generator
%      wrote (fresh copies of the packages, MD5 equal; version 4, no re_info
%      fields); (b) tsw07_switch_pinf = tests/reference/tsw07_switch_pinf_fast.mat
%      (max diff 0, events equal)
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
if any(strcmp(part, {'all', 'sw07_model'}))
    R = sw07_model_checks(R, here);
end
if any(strcmp(part, {'all', 'sw07_runs'}))
    R = sw07_run_checks(R, here);
end
if any(strcmp(part, {'all', 'sw07_stages'}))
    R = sw07_stage_checks(R, here);
end
end


% =========================================================================
function R = toy_checks(R, here)
toyDir = fullfile(here, 'toy_nk');
nkDir = fullfile(here, 'models', 'nkpc');

% ---- T0: options ------------------------------------------------------------------------------
nm = 're_info T0: default ''current''; ''lagged'' accepted (string becomes char)';
try
    d = hetlearn.defaults();
    o = hetlearn.load_options(struct('expectations', struct('re_info', "lagged", 'variables', {{'pinf'}})), struct());
    ok = strcmp(d.expectations.re_info, 'current') && ischar(o.expectations.re_info) ...
        && strcmp(o.expectations.re_info, 'lagged');
    R = add(R, nm, ok, sprintf('default %s, set %s (%s)', d.expectations.re_info, o.expectations.re_info, ...
        class(o.expectations.re_info)));
catch err
    R = add(R, nm, false, err.message);
end
R = expect_error(R, 're_info T0: bad value rejected (hetlearn:options:value)', 'hetlearn:options:value', ...
    'expectations.re_info', @() hetlearn.load_options(struct('expectations', struct('re_info', 'lag')), struct()));
R = expect_error(R, 're_info T0: ''lagged'' with an empty learning set rejected', 'hetlearn:options:value', ...
    'learning set is empty', @() hetlearn.load_options(struct('expectations', struct('re_info', 'lagged')), struct()));
R = expect_error(R, 're_info T0: ''lagged'' with policy.mode = ''ramsey'' rejected (unsupported)', ...
    'hetlearn:options:unsupported', 'ramsey', @() hetlearn.load_options(struct('expectations', ...
    struct('re_info', 'lagged', 'variables', {{'pinf'}}), 'policy', struct('mode', 'ramsey')), struct()));
R = expect_error(R, 're_info T0: learning variable with a lead of 2 (toy nk3 pie{+2}) rejected', ...
    'hetlearn:load_model:reInfo', 'maximum lead of 1', @() hetlearn.load_model(hetlearn.load_spec(toyDir), ...
    struct('model', toyDir, 'expectations', struct('variables', {{'pie'}}, 're_info', 'lagged'))));

% ---- T3: closed form ------------------------------------------------------------------------------
nm = 're_info T3: closed form pi_t = bet E_{t-1} pi_{t+1} + kap x_t + u_t (IRFs and anchored coefficients, 1e-12)';
try
    spec = hetlearn.load_spec(nkDir);
    P = feval_in(nkDir, spec.params);
    k = (1:40)';
    xa = P.std_e_x * P.rho_x .^ (k - 1);
    ua = P.std_e_u * P.rho_u .^ (k - 1);
    bx = P.bet * P.kap * P.rho_x^2 / (1 - P.bet * P.rho_x);
    bu = P.bet * P.rho_u^2 / (1 - P.bet * P.rho_u);
    pix = P.kap * xa + bx * [0; xa(1:end-1)];          % response of pi to e_x (std size, as IRIS srf)
    piu = ua + bu * [0; ua(1:end-1)];
    dI = 0;
    for rv = {'anchored', 'model_consistent'}
        o = struct('model', nkDir, 'expectations', struct('variables', {{'pi'}}, 're_info', 'lagged', ...
            're_variant', rv{1}));
        m = hetlearn.load_model(spec, o);
        s = srf(m, 1:40);
        el = cellstr(get(m, 'eList'));
        dI = max([dI, max(abs(s.pi(1:40, strcmp(el, 'e_x')) - pix)), max(abs(s.pi(1:40, strcmp(el, 'e_u')) - piu))]);
    end
    [~, infoA] = hetlearn.load_model(spec, struct('model', nkDir, 'expectations', ...
        struct('variables', {{'pi'}}, 're_info', 'lagged')));
    cA = infoA.anchor.c.pi;
    st = infoA.anchor.states;
    cx = P.kap * P.rho_x^2 / (1 - P.bet * P.rho_x);
    cu = P.rho_u^2 / (1 - P.bet * P.rho_u);
    dC = max(abs([cA(strcmp(st, 'x')) - cx, cA(strcmp(st, 'u')) - cu, infoA.anchor.k.pi]));
    other = setdiff(st, {'x', 'u'});
    dO = 0;
    for j = 1:numel(other)
        dO = max(dO, abs(cA(strcmp(st, other{j}))));
    end
    [~, infoC] = hetlearn.load_model(spec, struct('model', nkDir, 'expectations', struct('variables', {{'pi'}})));
    cC = infoC.anchor.c.pi;
    stC = infoC.anchor.states;
    dCur = max(abs([cC(strcmp(stC, 'x')) - P.kap * P.rho_x / (1 - P.bet * P.rho_x), ...
        cC(strcmp(stC, 'u')) - P.rho_u / (1 - P.bet * P.rho_u)]));
    fprintf('RE_INFO-T3 | IRFs vs closed form %.3g; lagged anchored coefficients %.3g (others %.3g, states %s); current %.3g\n', ...
        dI, dC, dO, strjoin(st, ','), dCur);
    R = add(R, nm, dI < 1e-12 && dC < 1e-12 && dO < 1e-12 && dCur < 1e-12, sprintf(['IRFs %.3g; lagged ' ...
        'anchored: x_{t-1} %.12g (closed form %.12g), u_{t-1} %.12g (%.12g), max diff %.3g; current %.3g'], ...
        dI, cA(strcmp(st, 'x')), cx, cA(strcmp(st, 'u')), cu, dC, dCur));
catch err
    R = add(R, nm, false, err.message);
end

% ---- T4 (toy): nk3_lead1, every forward variable learning ----------------------------------------
nm = 're_info T4: toy nk3_lead1 {y, pie, r}: anchored = model-consistent at n1 = 1 (1e-10); generator lagged collapse passes';
try
    spec = hetlearn.load_spec(toyDir);
    spec1 = spec;
    spec1.name = 'nk3l1';
    spec1.model_file = 'nk3_lead1.model';
    o = struct('model', toyDir, 'expectations', struct('variables', 'all', 're_info', 'lagged'));
    [mA, iA] = hetlearn.load_model(spec1, o);
    o.expectations.re_variant = 'model_consistent';
    mM = hetlearn.load_model(spec1, o);
    d = irf_maxdiff(mA, mM, cellstr(get(mA, 'xList')));      % the anchored model has no chain variables
    meta = iA.meta;
    cm = [meta.collapse_maxdiff(2:3), meta.collapse_info_maxdiff];
    ok = d < 1e-10 && iA.re_info_check.anchored_vs_mc_maxdiff < 1e-10 && all(cm < 1e-10) ...
        && meta.generator_version == 5 && endsWith(meta.ext_file, '_relag.model') && strcmp(meta.re_info, 'lagged');
    R = add(R, nm, ok, sprintf(['loaded models: max IRF diff %.3g (load check %.3g); generator passes ' ...
        'br=false %.3g, anchored %.3g, br_info_current %.3g; version %d, %s'], d, ...
        iA.re_info_check.anchored_vs_mc_maxdiff, cm, meta.generator_version, file_name(meta.ext_file)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- T6a (toy): default generator output unchanged ------------------------------------------------
R = default_generator_check(R, here, toyDir, {'model_spec.m', 'nk3.model', 'nk3_params.m'}, ...
    fullfile(toyDir, 'generated', 'nk3_ext_ar1.model'), 're_info T6a: toy default generated file byte-identical to the pre-change one');
end


% =========================================================================
function R = sw07_model_checks(R, here)
spec = hetlearn.load_spec('sw07');
P = feval_in(spec.folder, spec.params);
ref = fullfile(here, 'models', 'sw07_re_lagged_pinf.model');
mr = [];
try
    mr = Model.fromFile(ref, 'linear', true);
    mr = assign(mr, P);
    [mr, flag] = solve(mr);
    assert(hasSucceeded(flag), 'the hand-written reference does not solve: %s', char(string(flag)));
    mr = sstate(mr);
catch err
    R = add(R, 're_info T1: hand-written reference loads and solves', false, err.message);
    return
end
mo = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true);
names = [reshape(cellstr(get(mo, 'xList')), 1, []), reshape(cellstr(get(mo, 'yList')), 1, [])];
M = struct();
I = struct();
for rv = {'anchored', 'model_consistent'}
    o = tsw07_peak_re();
    o.expectations.re_info = 'lagged';
    o.expectations.re_variant = rv{1};
    [M.(rv{1}), I.(rv{1})] = hetlearn.load_model(spec, o);
end

% ---- T1: hand-written reference ---------------------------------------------------------------------
nm = 're_info T1: SW07 {pinf} toolbox RE(t-1) model = hand-written reference (IRFs 40 periods, all shocks, steady state; 1e-10)';
try
    dI = struct();
    dS = struct();
    for rv = {'anchored', 'model_consistent'}
        dI.(rv{1}) = irf_maxdiff(M.(rv{1}), mr, names);
        dS.(rv{1}) = sstate_maxdiff(M.(rv{1}), mr, names);
    end
    fprintf('RE_INFO-T1 | vs hand-written: IRFs anchored %.3g, model-consistent %.3g; steady state %.3g, %.3g (%d variables)\n', ...
        dI.anchored, dI.model_consistent, dS.anchored, dS.model_consistent, numel(names));
    ok = max([dI.anchored, dI.model_consistent]) < 1e-10 && max([dS.anchored, dS.model_consistent]) < 1e-10;
    R = add(R, nm, ok, sprintf('IRFs: anchored %.3g, model-consistent %.3g; steady state %.3g, %.3g; %d variables x %d shocks', ...
        dI.anchored, dI.model_consistent, dS.anchored, dS.model_consistent, numel(names), numel(get(mr, 'eList'))));
catch err
    R = add(R, nm, false, err.message);
end

% ---- T2: Dynare ------------------------------------------------------------------------------------
nm = 're_info T2: SW07 {pinf} toolbox RE(t-1) model = Dynare 4.6.1 EXPECTATION(-1)(pinf(+1)) (IRFs, 1e-8)';
try
    D = load(fullfile(here, 'reference', 're_info_dynare_irfs.mat'));
    worst = 0;
    wn = '';
    nC = 0;
    for rv = {'anchored', 'model_consistent'}
        s = srf(M.(rv{1}), 1:40);
        el = cellstr(get(M.(rv{1}), 'eList'));
        for j = 1:numel(D.shocks)
            jj = find(strcmp(el, D.shocks{j}), 1);
            for i = 1:numel(D.endo)
                v = D.endo{i};
                if ~isfield(s, v)
                    error('Dynare variable %s is not in the toolbox model.', v);
                end
                a = s.(v)(1:40, jj);
                b = D.irfs.([v '_' D.shocks{j}]);
                e = max(abs(a(:) - b(:)));
                nC = nC + 1;
                if e > worst
                    worst = e;
                    wn = sprintf('%s/%s (%s)', v, D.shocks{j}, rv{1});
                end
            end
        end
    end
    fprintf('RE_INFO-T2 | vs Dynare %s: max abs IRF diff %.3g (%s), %d IRFs compared\n', D.dynare_version, worst, wn, nC);
    R = add(R, nm, worst < 1e-8, sprintf('max abs diff %.3g at %s; %d IRFs (%d variables x %d shocks x 2 variants), Dynare %s, file made %s', ...
        worst, wn, nC, numel(D.endo), numel(D.shocks), D.dynare_version, D.created));
catch err
    R = add(R, nm, false, err.message);
end

% ---- T4 (SW07): three RE(t-1) models agree; generator passes ------------------------------------
nm = 're_info T4: SW07 n1 = 1: anchored = model-consistent = reference (1e-10); lagged generator passes (all 12 learning) < 1e-10';
try
    d1 = irf_maxdiff(M.anchored, M.model_consistent, cellstr(get(M.anchored, 'xList')));
    meta = I.anchored.meta;
    cm = [meta.collapse_maxdiff(2:3), meta.collapse_info_maxdiff];
    sets = cellfun(@(s) numel(s), meta.collapse_lagged_sets);
    ok = d1 < 1e-10 && all(cm < 1e-10) && I.anchored.re_info_check.anchored_vs_mc_maxdiff < 1e-10 ...
        && meta.generator_version == 5 && isequal(sets, 12);
    R = add(R, nm, ok, sprintf(['anchored vs model-consistent %.3g (load check %.3g); generator: br=false %.3g, ' ...
        'anchored %.3g, br_info_current %.3g, learning set sizes %s; rcond(I - C_z) %.3g, C_z %.6g'], d1, ...
        I.anchored.re_info_check.anchored_vs_mc_maxdiff, cm, mat2str(sets), I.anchored.anchor.fixed_point_rcond, ...
        I.anchored.anchor.cz));
catch err
    R = add(R, nm, false, err.message);
end

% ---- T6a (SW07): default generator output unchanged ----------------------------------------------
R = default_generator_check(R, here, spec.folder, {'model_spec.m', 'sw07.model', 'sw07_params.m'}, ...
    fullfile(spec.folder, 'generated', 'sw07_ext_ar1.model'), 're_info T6a: SW07 default generated file byte-identical to the pre-change one');

% ---- T6b: default run = pre-change reference ------------------------------------------------------
nm = 're_info T6b: tsw07_switch_pinf (re_info default) = tests/reference/tsw07_switch_pinf_fast.mat (max diff 0, events equal)';
try
    cfg = tsw07_switch_pinf();
    cfg.compare_with = {};
    rs = hetlearn.run(cfg, 'save', false, 'quiet', true);
    B = load(fullfile(here, 'reference', 'tsw07_switch_pinf_fast.mat'), 'ref');
    [d, worst] = ref_maxdiff(rs, B.ref);
    evOk = isequal(rs.events, B.ref.events);
    R = add(R, nm, d == 0 && evOk && strcmp(rs.cfg.expectations.re_info, 'current'), ...
        sprintf('max abs diff %.3g (%s); events equal %d', d, worst, evOk));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = sw07_run_checks(R, here)
org = qq(2022, 2);
spec = hetlearn.load_spec('sw07');
P = feval_in(spec.folder, spec.params);
db = hetlearn.load_database(spec);
range = hetlearn.util.to_dates(spec.filter_range);

% independent RE(t-1) computations from the hand-written reference
fS = [];
fF = [];
fF2 = [];
try
    mr = Model.fromFile(fullfile(here, 'models', 'sw07_re_lagged_pinf.model'), 'linear', true);
    mr = assign(mr, P);
    [mr, flag] = solve(mr);
    assert(hasSucceeded(flag), 'reference solve failed');
    mr = sstate(mr);
    [~, Sm] = filter(mr, db, range, 'output', 'smooth', 'meanOnly', true);
    [~, Pr] = filter(mr, db, range, 'output', 'pred', 'ahead', 2, 'meanOnly', true);
    [~, Fi] = filter(mr, db, range, 'output', 'filter', 'meanOnly', true);
    xv = cellstr(get(mr, 'xVector'));
    xb = cellstr(get(mr, 'xbVector'));
    [T, ~, K] = sspace(mr, 'triangular', false);
    T = T(:, :, 1);
    K = K(:, 1, 1);
    nf = numel(xv) - numel(xb);
    ip = find(strcmp(xv, 'pinf'), 1);
    [~, sv, sl] = hetlearn.plm.anchor_names('pinf', xb);
    fS = @(t) two_step(T, K, nf, ip, Sm, sv, sl, t);             % E_{t-1} pinf_{t+1} from the smoothed state at t-1
    fF = @(t) column(Pr.pinf(t + 1), 2);                         % E[pinf_{t+1} | data up to t-1], IRIS 'ahead' 2
    fF2 = @(t) Fi.pinf_n2(t - 1);                                % filtered E_{t-1} pinf_{t+1} of the reference at t-1
catch err
    R = add(R, 're_info T5: independent RE(t-1) filter of the hand-written reference', false, err.message);
end

% ---- runs: every combination ---------------------------------------------------------------------
combos = {};
for bi = {'lagged', 'current'}
    for rv = {'anchored', 'model_consistent'}
        for rs = {'smoothed', 'filtered'}
            combos(end+1, :) = {bi{1}, rv{1}, rs{1}}; %#ok<AGROW>
        end
    end
end
RES = cell(size(combos, 1), 1);
nm = 're_info T5: tsw07_switch_pinf with re_info ''lagged'': all 8 combinations of beliefs.info, re_variant, re_states run';
try
    msg = {};
    for c = 1:size(combos, 1)
        cfg = tsw07_switch_pinf();
        cfg.id = sprintf('tsw07_reinfo_%d', c);
        cfg.compare_with = {};
        cfg.expectations.re_info = 'lagged';
        cfg.beliefs.info = combos{c, 1};
        cfg.expectations.re_variant = combos{c, 2};
        cfg.history.re_states = combos{c, 3};
        t = tic;
        RES{c} = hetlearn.run(cfg, 'save', false, 'quiet', true);
        L = RES{c}.learning.pinf;
        msg{end+1} = sprintf('%s/%s/%s: n2(2022Q2) %.4f, %.1f s', combos{c, :}, L.n2(org), toc(t)); %#ok<AGROW>
        fprintf('RE_INFO-T5 | %s\n', msg{end});
    end
    R = add(R, nm, true, strjoin(msg, '; '));
catch err
    R = add(R, nm, false, err.message);
end

% ---- fit of the lagged RE filters -----------------------------------------------------------------
nm = 're_info T5: RE filter of the lagged model fits the data (anchored and model-consistent, < 1e-8)';
try
    fe = cellfun(@(r) r.meta.refilter_fit_error, RES(~cellfun(@isempty, RES)));
    hs = cellfun(@(r) r.meta.refilter_hash, RES(~cellfun(@isempty, RES)), 'UniformOutput', false);
    R = add(R, nm, all(fe < 1e-8) && numel(fe) == 8, sprintf('max fit error %.3g over %d runs, %d distinct filter caches', ...
        max(fe), numel(fe), numel(unique(hs))));
catch err
    R = add(R, nm, false, err.message);
end

% ---- f^RE = independent two-step-ahead computation -------------------------------------------------
nm = 're_info T5: f^RE_t (made in t, information to t-1) = independent two-step computation from the RE(t-1) model (1e-9)';
try
    assert(~isempty(fS), 'needs the reference filter');
    td = RES{1}.dates.init_date:org;
    a = NaN(numel(td), 1);
    b = NaN(numel(td), 1);
    b2 = NaN(numel(td), 1);
    for k = 1:numel(td)
        a(k) = fS(td(k));
        b(k) = fF(td(k));
        b2(k) = fF2(td(k));
    end
    dS = 0;
    dF = 0;
    for c = 1:size(combos, 1)
        f = RES{c}.learning.pinf.fRE(td);
        if strcmp(combos{c, 3}, 'smoothed')
            dS = max(dS, max(abs(f(:) - a)));
        else
            dF = max(dF, max(abs(f(:) - b)));
        end
    end
    dRoutes = max(abs(b - b2));
    fprintf('RE_INFO-T5 | fRE vs reference: smoothed (T-iteration from s_{t-1|T}) %.3g; filtered (IRIS ahead 2) %.3g; two filtered routes %.3g\n', ...
        dS, dF, dRoutes);
    R = add(R, nm, dS < 1e-9 && dF < 1e-9 && dRoutes < 1e-9, sprintf(['smoothed: max diff %.3g (two-step ' ...
        'T-iteration from the reference''s smoothed state at t-1); filtered: %.3g (IRIS two-step prediction); the ' ...
        'reference''s filtered E_{t-1} pinf_{t+1} vs its two-step prediction %.3g; %d quarters'], dS, dF, dRoutes, numel(td)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- FE^RE is a two-step error; f^RE does not depend on beliefs.info --------------------------------
nm = 're_info T5: FE^RE_t = (pinf_t - f^RE_{t-1})^2 (1e-12); f^RE identical across beliefs.info (1e-12)';
try
    td = (RES{1}.dates.init_date + 1):org;
    dFE = 0;
    for c = 1:size(combos, 1)
        L = RES{c}.learning.pinf;
        H = hetlearn.re_filter(spec, hetlearn.load_options(RES{c}.cfg));
        D = hetlearn.engine.history_db(RES{c}.cfg, H);
        e = L.FE_RE(td) - (D.pinf(td) - L.fRE(td - 1)).^2;
        dFE = max(dFE, max(abs(e)));
    end
    dInfo = 0;
    for c = 1:4
        dInfo = max(dInfo, max(abs(RES{c}.learning.pinf.fRE(td) - RES{c + 4}.learning.pinf.fRE(td))));
    end
    R = add(R, nm, dFE < 1e-12 && dInfo < 1e-12, sprintf('FE identity %.3g; fRE beliefs.info lagged vs current %.3g', dFE, dInfo));
catch err
    R = add(R, nm, false, err.message);
end

% ---- realtime orthogonal; first forecast quarter predetermined ---------------------------------------
nm = 're_info T5: history.realtime leaves the ''filtered'' lagged history unchanged (1e-10); RE expectation in 2022Q3 predetermined (1e-10)';
try
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_reinfo_rt';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    cfg.history.re_states = 'filtered';
    cfg.history.realtime = true;
    rr = hetlearn.run(cfg, 'save', false, 'quiet', true);
    td = rr.dates.init_date:org;
    dH = 0;
    for f = {'fRE', 'fBR', 'FE_RE', 'FE_BR', 'n2', 'alpha_pinf', 'beta_pinf'}
        a = rr.learning.pinf.(f{1})(td);
        b = RES{2}.learning.pinf.(f{1})(td);
        e = abs(a - b);
        e(isnan(a) & isnan(b)) = 0;
        dH = max([dH; e(:)]);
    end
    hz = rr.dates.horizon;
    dF = max(abs(rr.paths.pinfobs(hz) - RES{2}.paths.pinfobs(hz)));
    dP = 0;
    for c = 1:size(combos, 1)
        H = hetlearn.re_filter(spec, hetlearn.load_options(RES{c}.cfg));
        dP = max(dP, abs(RES{c}.paths.pinf_exp1_RE(org + 1) - H.smooth.pinf_exp1_RE(org + 1)));
    end
    R = add(R, nm, dH < 1e-10 && dF > 1e-6 && dP < 1e-10, sprintf(['history realtime vs not %.3g (forecast ' ...
        'pinfobs differs by %.3g); pinf_exp1_RE(2022Q3) forecast vs smoothed %.3g'], dH, dF, dP));
catch err
    R = add(R, nm, false, err.message);
end

% ---- RE benchmark: both variants give the same forecast ---------------------------------------------
nm = 're_info T4/T5: tsw07_peak_re with ''lagged'': anchored = model-consistent forecast (1e-9), history identical';
try
    rr = cell(1, 2);
    rv = {'anchored', 'model_consistent'};
    for i = 1:2
        cfg = tsw07_peak_re();
        cfg.id = ['tsw07_peak_re_lagged_' rv{i}];
        cfg.compare_with = {};
        cfg.expectations.re_info = 'lagged';
        cfg.expectations.re_variant = rv{i};
        rr{i} = hetlearn.run(cfg, 'save', false, 'quiet', true);
    end
    mo = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true);
    names = [reshape(cellstr(get(mo, 'xList')), 1, []), reshape(cellstr(get(mo, 'yList')), 1, [])];
    full = rr{1}.dates.full;
    d = 0;
    for i = 1:numel(names)
        e = abs(rr{1}.paths.(names{i})(full) - rr{2}.paths.(names{i})(full));
        e(isnan(e)) = 0;
        d = max([d; e(:)]);
    end
    hz = rr{1}.dates.horizon;
    pa = mean(4 * rr{1}.paths.pinf(hz));
    R = add(R, nm, d < 1e-9, sprintf('max diff over history and forecast %.3g (%d variables); average inflation 2022Q3-2026Q2 %.3f%% (deviation from steady state, annualised)', ...
        d, numel(names), pa));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = sw07_stage_checks(R, here) %#ok<INUSD>
org = qq(2022, 2);
spec = hetlearn.load_spec('sw07');

% ---- inversion -----------------------------------------------------------------------------------------
nm = 're_info T5 stages: RE inversion with ''lagged'' reproduces the lagged RE-smoothed shocks (< 1e-8); learning inversion completes';
try
    cfg = tsw07_peak_re();
    cfg.id = 'tsw07_reinfo_inv_re';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    cfg.history.mode = 'inversion';
    ri = hetlearn.run(cfg, 'save', false, 'quiet', true);
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_reinfo_inv_learn';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    cfg.history.mode = 'inversion';
    rl = hetlearn.run(cfg, 'save', false, 'quiet', true);
    a = ri.inversion;
    b = rl.inversion;
    % as test_inversion S1: compare up to the first quarter with a missing observable (SW07
    % 2020Q1-Q3 have no data; there the inversion backs out zero shocks and the paths part)
    H = hetlearn.re_filter(spec, hetlearn.load_options(ri.cfg));
    dts = a.dates;
    full = arrayfun(@(t) all(cellfun(@(o) isfinite(H.data.(o)(t)), spec.observables)), dts);
    stop = find(~full, 1);
    if isempty(stop), pre = dts; else, pre = dts(1:stop-1); end
    wpre = 0;
    for j = 1:numel(a.shocks)
        wpre = max([wpre; abs(ri.paths.(a.shocks{j})(pre) - H.smooth.(a.shocks{j})(pre))]);
    end
    R = add(R, nm, wpre < 1e-8 && a.max_obs_miss < 1e-9 && b.max_obs_miss < 1e-9, ...
        sprintf(['RE: shocks vs the lagged RE-smoothed shocks %.3g up to %s (all quarters %.3g), observable ' ...
        'miss %.3g; learning: miss %.3g, n2 at 2022Q2 %.4f, %d events'], wpre, char(dat2str(pre(end))), ...
        a.shock_diff_vs_smoothed, a.max_obs_miss, b.max_obs_miss, rl.learning.pinf.n2(org), height(rl.events)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- conditions --------------------------------------------------------------------------------------------
nm = 're_info T5 stages: conditions with ''lagged'' (ms held 0.25 above its own path, em endogenised) hit the targets';
try
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_reinfo_cond';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    cfg.conditions = struct('variable', 'ms', 'shock', 'em', 'dates', [qq(2022, 3), qq(2023, 2)], ...
        'values', 0.25, 'type', 'delta', 'reference', 'self');
    rc = hetlearn.run(cfg, 'save', false, 'quiet', true);
    c0 = cfg;
    c0.id = 'tsw07_reinfo_cond_ref';
    c0.conditions = c0.conditions([]);
    r0 = hetlearn.run(c0, 'save', false, 'quiet', true);
    dd = qq(2022, 3):qq(2023, 2);
    miss = max(abs(rc.paths.ms(dd) - r0.paths.ms(dd) - 0.25));
    R = add(R, nm, miss < 1e-9, sprintf('max target miss %.3g; inflation 2022Q3 %.4f vs %.4f without the condition', ...
        miss, rc.paths.pinf(qq(2022, 3)), r0.paths.pinf(qq(2022, 3))));
catch err
    R = add(R, nm, false, err.message);
end

% ---- decompositions -----------------------------------------------------------------------------------------
nm = 're_info T5 stages: decompositions of lagged runs add up (RE: IRIS contributions; learning: ''tv''), paths rebuilt';
try
    cfg = tsw07_peak_re();
    cfg.id = 'tsw07_reinfo_dec_re';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    r1 = hetlearn.run(cfg, 'save', false, 'quiet', true);
    D1 = hetlearn.decompose(r1, {'pinfobs', 'dy'}, [qq(2019, 1), qq(2026, 2)], struct('save', false, 'quiet', true));
    D1t = hetlearn.decompose(r1, {'pinfobs', 'dy'}, [qq(2019, 1), qq(2026, 2)], struct('save', false, 'quiet', true, 'method', 'tv'));
    cfg = tsw07_switch_pinf();
    cfg.id = 'tsw07_reinfo_dec_learn';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    r2 = hetlearn.run(cfg, 'save', false, 'quiet', true);
    D2 = hetlearn.decompose(r2, {'pinfobs', 'dy'}, [qq(2019, 1), qq(2026, 2)], struct('save', false, 'quiet', true));
    dIT = 0;
    for v = {'pinfobs', 'dy'}
        dIT = max(dIT, max(max(abs(D1.values.(v{1}) - D1t.values.(v{1})))));
    end
    rec = NaN;
    if isfield(D2.check, 'recon_maxerr')
        rec = D2.check.recon_maxerr;
    end
    ok = D1.check.additivity_maxerr < 1e-10 && D2.check.additivity_maxerr < 1e-10 && dIT < 1e-9 && rec < 1e-8;
    R = add(R, nm, ok, sprintf(['RE (%s) additivity %.3g, IRIS vs ''tv'' %.3g; learning (%s) additivity %.3g, ' ...
        'path reconstruction %.3g'], D1.method, D1.check.additivity_maxerr, dIT, D2.method, ...
        D2.check.additivity_maxerr, rec));
catch err
    R = add(R, nm, false, err.message);
end

% ---- density -----------------------------------------------------------------------------------------------
nm = 're_info T5 stages: density with ''lagged'': RE fast path = general path (10 draws, 1e-9)';
try
    cfg = tsw07_peak_re();
    cfg.id = 'tsw07_reinfo_dens';
    cfg.compare_with = {};
    cfg.expectations.re_info = 'lagged';
    cfg.density = struct('enabled', true, 'shocks', {{'epinf', 'ew'}}, 'ndraws', 10, 'seed', 3);
    a = hetlearn.run(cfg, 'save', false, 'quiet', true);
    cfg.density.fast_path = false;
    b = hetlearn.run(cfg, 'save', false, 'quiet', true);
    qa = a.density.series.pinfobs.q;
    qb = b.density.series.pinfobs.q;
    d = max(abs(qa(:) - qb(:)));
    R = add(R, nm, d < 1e-9 && strcmp(a.density.path, 'fast') && ~strcmp(b.density.path, 'fast'), ...
        sprintf('pinfobs quantiles max diff %.3g (%s vs %s path), %d used draws', d, a.density.path, b.density.path, a.density.n_used));
catch err
    R = add(R, nm, false, err.message);
end

% ---- evaluation --------------------------------------------------------------------------------------------
nm = 're_info T5 stages: hetlearn.evaluate with ''lagged'' variants (2 origins, H = 4) = direct real-time runs (1e-10)';
try
    v1 = tsw07_peak_re();
    v1.id = 'ev_re_lagged';
    v1.expectations.re_info = 'lagged';
    v2 = tsw07_switch_pinf();
    v2.id = 'ev_learn_lagged';
    v2.expectations.re_info = 'lagged';
    v3 = tsw07_switch_pinf();
    v3.id = 'ev_learn_current';
    origins = [qq(2015, 1), qq(2018, 4)];
    od = fullfile(fileparts(mfilename('fullpath')), 'output', 'results');
    E = hetlearn.evaluate('reinfo_test', {v1, v2, v3}, origins, struct('horizon', 4, 'save', false, ...
        'quiet', true, 'results_dir', od));
    T = E.errors;
    c = v2;
    c.forecast.origin = origins(2);
    c.forecast.horizon = 4;
    c.compare_with = {};
    c.history.realtime = true;
    r = hetlearn.run(c, 'save', false, 'quiet', true);
    os = hetlearn.util.date_str(origins(2));
    sel = strcmp(T.variant, 'ev_learn_lagged') & strcmp(T.origin, os{1}) & strcmp(T.variable, 'pinfobs');
    tg = origins(2) + (1:4);
    fc = r.paths.pinfobs(tg) * 4;                % report units (spec.report.scale.pinfobs = 4)
    [~, ord] = sort(T.h(sel));
    ev = T.forecast(sel);
    ev = ev(ord);
    d = max(abs(ev(:) - fc(:)));
    R = add(R, nm, d < 1e-10 && ~isempty(ev), sprintf('learning lagged variant at %s: max diff vs direct run %.3g (%d horizons); %d error rows', ...
        char(dat2str(origins(2))), d, numel(ev), height(T)));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = default_generator_check(R, here, srcDir, files, cached, nm)
% The default generator output for a fresh copy of the package equals the cached file
% the pre-change generator wrote (MD5), with generator version 4 and no re_info fields.
try
    tmp = fullfile(here, 'output', 're_info_gen', char(java.util.UUID.randomUUID()));
    mkdir(tmp);
    c = onCleanup(@() rmdir(tmp, 's'));
    for i = 1:numel(files)
        copyfile(fullfile(srcDir, files{i}), fullfile(tmp, files{i}));
    end
    sp = hetlearn.load_spec(tmp);
    meta = hetlearn.extend_model(sp, 'ar1', 'validate', false);
    h1 = hetlearn.util.md5(hetlearn.util.file_bytes(meta.ext_file));
    h0 = hetlearn.util.md5(hetlearn.util.file_bytes(cached));
    ok = strcmp(h1, h0) && meta.generator_version == 4 && ~isfield(meta, 're_info') ...
        && ~contains(meta.ext_file, '_relag');
    R = add(R, nm, ok, sprintf('fresh %s md5 %s, cached md5 %s, version %d', file_name(meta.ext_file), h1, h0, ...
        meta.generator_version));
catch err
    R = add(R, nm, false, err.message);
end
end


function f = two_step(T, K, nf, ip, D, sv, sl, t)
% E_{t-1} pinf_{t+1} = K(ip) + T(ip,:)*(K_b + T_b*xb_{t-1}), xb_{t-1} from the databank D
% (element v{-k} of xb at t-1 = v at t-1-k).
xb = zeros(numel(sv), 1);
for j = 1:numel(sv)
    xb(j) = D.(sv{j})(t - 1 - sl(j));
end
Tb = T(nf+1:end, :);
Kb = K(nf+1:end);
f = K(ip) + T(ip, :) * (Kb + Tb * xb);
end


function v = column(x, j)
v = x(:, j);
end


function d = irf_maxdiff(m1, m2, names)
s1 = srf(m1, 1:40);
s2 = srf(m2, 1:40);
e1 = cellstr(get(m1, 'eList'));
e2 = cellstr(get(m2, 'eList'));
[~, i2] = ismember(e1, e2);
d = 0;
for i = 1:numel(names)
    a = s1.(names{i})(1:40, :);
    b = s2.(names{i})(1:40, i2);
    e = abs(a - b);
    e(isnan(e)) = Inf;
    d = max([d; e(:)]);
end
end


function d = sstate_maxdiff(m1, m2, names)
a = access(m1, 'steady-level');
b = access(m2, 'steady-level');
d = 0;
for i = 1:numel(names)
    e = abs(real(a.(names{i})) - real(b.(names{i})));
    if isnan(e)
        e = Inf;
    end
    d = max(d, e);
end
end


function n = file_name(f)
[~, a, b] = fileparts(f);
n = [a b];
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
