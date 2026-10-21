function R = test_anchor(part)
%TEST_ANCHOR  Generalised anchor, phase P4 of docs/DESIGN_br_extensions.md (1.4; mechanisms 1, 10, 23, 33).
%
%   R = test_anchor()        every part
%   R = test_anchor(part)    'gate' | 'egm' | 'levels' | 'de' | 'io' | 're1' | 'score'
%
%   A1  fixed-point gate: hetlearn.anchor_coefficients on the anchored RE(t-1)
%       limit of the SW07 test baseline (tsw07_a1_learn) returns the model's own
%       anchored coefficients, and the level-k T-map with level 0 = RE
%       (hetlearn.engine.anchor_update, levels 1 and 2) returns them too (1e-12)
%   A2  EGM closed form on the scalar economy y = mu + b*E y{+1} + u, u AR(1)
%       (tests/models/egm): with a constant level-0 forecast a, level k has
%       constant mu*(1 + ... + b^(k-1)) + b^k*a and coefficient
%       rho^2*(1 + b*rho + ... + (b*rho)^(k-1)) on u_{t-1} ('lagged'; rho*(...)
%       on u_t with 'current' information), k = 1, 2, 3 (1e-12)
%   A3  K = 0 equals the level-0 rule: the learner L0 with a level type L1 at
%       share 0 (fixed_shares) = the two-type run with mode 'learning' (SW07, origin
%       2019Q4, horizon 8; paths, beliefs and forecasts 1e-10: the two runs filter
%       different model files, so their RE histories differ at rounding level)
%   A4  level k on level 0 = RE equals RE: types RE, L1, L2 (base RE), share 1 on
%       L2: the level forecasts equal the RE forecast in every quarter (1e-12) and
%       the run equals the RE(t-1) run tsw07_a1_re (paths 1e-10)
%   A5  anchored DE = model-consistent DE at n_RE = 1 (variant 10 on the anchored
%       baseline): the load check (IRFs, every shock, 1e-10), an independent IRF
%       comparison with the model-consistent load (1e-10), and nonzero anchored
%       coefficients on the memory states c_REt2, ... and on pinf_DEg_RE{-1}
%   A6  variant 23 with abar fixed at 0 ('user' initial belief, update 'fixed'):
%       the IO forecast equals the RE forecast in every quarter (1e-14), shares stay
%       at 0.5 and the run equals the RE(t-1) run tsw07_a1_re (paths 1e-10)
%   A7  variant 33: the re1 term = E_{t-1}(y_{t+1} - y_t) by a two-period IRIS
%       simulation of the RE limit from the state at t-1 with zero shocks, and the
%       FN forecast = dn_{t-1} - re1 from the recorded paths, at every forecast
%       quarter (1e-10)
%   A8  scoring on transformed forecasts (variant 18): the OPT and PES forecasts
%       that fitness uses differ by 2g (1e-12), their errors differ, and their
%       shares leave 0.5
%
%   Runs are not saved. About 2 minutes; the first call generates the model files.

if nargin < 1 || isempty(part)
    part = {'gate', 'egm', 'levels', 'de', 'io', 're1', 'score'};
end
part = cellstr(part);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));
R = struct('name', {}, 'pass', {}, 'msg', {});
if any(strcmp(part, 'gate'))
    R = gate(R);
end
if any(strcmp(part, 'egm'))
    R = egm(R, here);
end
if any(strcmp(part, 'levels'))
    R = levels(R);
end
if any(strcmp(part, 'de'))
    R = de(R);
end
if any(strcmp(part, 'io'))
    R = io(R);
end
if any(strcmp(part, 're1'))
    R = re1(R);
end
if any(strcmp(part, 'score'))
    R = score(R);
end
end


% =========================================================================================
function T = ty(varargin)
T = struct(varargin{:});
end


function [m, info, ctx, S] = init_state(cfg)
% the loaded model and the engine's initial state (levels included) of a configuration
o = hetlearn.load_options(cfg);
spec = hetlearn.load_spec(o.model);
[m, info] = hetlearn.load_model(spec, o);
ctx = struct('opts', o, 'info', info, 'sys', info.sys, 'learnVars', {info.learnVars}, 'spec', spec, ...
    'init_date', qq(2000, 1));
[S, ctx] = hetlearn.engine.state_init(ctx, m, []);
end


function R = gate(R)
nm = ['an A1: fixed-point gate: anchor_coefficients on the anchored RE(t-1) limit = its own anchored ' ...
    'coefficients; the level-k T-map with level 0 = RE returns them at levels 1 and 2 (1e-12)'];
try
    c = tsw07_a1_learn();
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec(o.model);
    [m, info] = hetlearn.load_model(spec, o);
    st = info.meta.re_states;
    pn = hetlearn.plm.anchor_names('pinf', st);
    pv = get(m, 'parameters');
    are = cellfun(@(n) pv.(n), pn)';
    [Rc, ic] = hetlearn.anchor_coefficients(m, {'pinf'}, st, 'lag', 1, 'check', true);
    d1 = max(abs([Rc.k; Rc.C(:)] - are) ./ max(1, abs(are)));
    c.expectations.types = {ty('name', 'RE', 'kind', 're'), ty('name', 'L1', 'kind', 'level', 'base', 'RE', 'k', 1), ...
        ty('name', 'L2', 'kind', 'level', 'base', 'RE', 'k', 2)};
    c.expectations.mode = 'fixed_shares';
    c.shares.fixed = struct('RE', 0, 'L1', 0, 'L2', 1);
    [m2, ~, ~, S] = init_state(c);
    pv2 = get(m2, 'parameters');
    are2 = cellfun(@(n) pv2.(n), pn)';
    d2 = max(abs(S.levels.L1.pinf - are2) ./ max(1, abs(are2)));
    d3 = max(abs(S.levels.L2.pinf - are2) ./ max(1, abs(are2)));
    ok = d1 < 1e-12 && d2 < 1e-12 && d3 < 1e-12 && ic.check_maxdiff < 1e-9;
    R = add(R, nm, ok, sprintf(['anchored limit vs its coefficients %.3g (unit check %.3g); level 1 %.3g, level 2 ' ...
        '%.3g (max relative difference over %d coefficients)'], d1, ic.check_maxdiff, d2, d3, numel(are)));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = egm(R, here)
nm = ['an A2: EGM closed form (tests/models/egm, y = mu + b*E y{+1} + u): level k on a constant level-0 ' ...
    'forecast, k = 1..3, with information up to t-1 and with period-t information (1e-12)'];
try
    P = struct('mu', 0.5, 'b', 0.8, 'rho', 0.6, 'a', 2);
    worst = 0;
    txt = {};
    for info = {'lagged', 'current'}
        c = struct();
        c.id = 'an_egm';
        c.model = fullfile(here, 'models', 'egm');
        c.model_params = '';
        c.forecast = struct('origin', qq(2000, 4), 'horizon', 4);
        c.expectations = struct('mode', 'fixed_shares', 'variables', {{'y'}}, 're_variant', 'anchored', ...
            're_info', info{1});
        c.beliefs = struct('info', 'lagged');
        c.expectations.types = {ty('name', 'L0', 'kind', 'rule', 'rule', struct('expr', 'a', 'params', struct('a', P.a))), ...
            ty('name', 'L1', 'kind', 'level', 'base', 'L0', 'k', 1), ty('name', 'L2', 'kind', 'level', 'base', 'L0', 'k', 2), ...
            ty('name', 'L3', 'kind', 'level', 'base', 'L0', 'k', 3)};
        c.shares.fixed = struct('L0', 1, 'L1', 0, 'L2', 0, 'L3', 0);
        [~, inf0, ~, S] = init_state(c);
        iu = 1 + find(strcmp(inf0.meta.re_states, 'u'));
        for k = 1:3
            v = S.levels.(sprintf('L%d', k)).y;
            kk = P.mu * sum(P.b .^ (0:k-1)) + P.b^k * P.a;
            if strcmp(info{1}, 'lagged')
                ck = P.rho^2 * sum((P.b * P.rho) .^ (0:k-1));
            else
                ck = P.rho * sum((P.b * P.rho) .^ (0:k-1));
            end
            others = v;
            others([1, iu]) = [];
            worst = max([worst, abs(v(1) - kk), abs(v(iu) - ck), max([0; abs(others)])]);
            txt{end+1} = sprintf('%s L%d %.6f/%.6f', info{1}(1), k, v(1), v(iu)); %#ok<AGROW>
        end
    end
    R = add(R, nm, worst < 1e-12, sprintf('max diff from the closed form %.3g (constant/coefficient: %s)', worst, ...
        strjoin(txt, ', ')));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = levels(R)
nm = ['an A3: K = 0 equals the level-0 rule: the learner L0 beside a level type at share 0 = the two-type ' ...
    'run in mode learning (SW07, origin 2019Q4; paths, beliefs and forecasts 1e-10)'];
try
    a = tsw07_a1_learn();
    a.expectations.mode = 'learning';
    a.forecast.origin = qq(2019, 4);
    a.forecast.horizon = 8;
    ra = hetlearn.run(a, 'save', false, 'quiet', true);
    b = a;
    b.expectations.types = {ty('name', 'L0', 'kind', 'plm'), ty('name', 'L1', 'kind', 'level', 'base', 'L0', 'k', 1)};
    b.expectations.mode = 'fixed_shares';
    b.shares.fixed = struct('L0', 1, 'L1', 0);
    rb = hetlearn.run(b, 'save', false, 'quiet', true);
    dp = 0;
    for v = {'pinfobs', 'dy', 'robs', 'dc', 'pinf', 'y', 'pinf_exp1'}
        dp = max(dp, sdiff(ra.paths.(v{1}), rb.paths.(v{1})));
    end
    La = ra.learning.pinf;
    Lb = rb.learning.pinf__L0;
    dl = max([sdiff(La.alpha_pinf, Lb.alpha_pinf__L0), sdiff(La.beta_pinf, Lb.beta_pinf__L0), ...
        sdiff(La.gain, Lb.gain), sdiff(ra.learning.pinf.fBR, rb.learning.pinf.f_L0)]);
    nL1 = max(abs(rb.learning.pinf.n_model_L1(rb.dates.horizon)));
    % the two runs filter different model files (the N-type file has the level variable), so the RE
    % histories differ at rounding level (about 2e-11 on SW07, test_ntypes H1): 1e-10 on both
    ok = dp <= 1e-10 && dl <= 1e-10 && nL1 == 0;
    R = add(R, nm, ok, sprintf('paths %.3g, beliefs, gain and forecasts %.3g; L1 model share %g; events %d / %d', ...
        dp, dl, nL1, height(ra.events), height(rb.events)));
catch err
    R = add(R, nm, false, where(err));
end

nm = ['an A4: level k on level 0 = RE equals RE: L1 and L2 forecasts = the RE forecast in every quarter (1e-12), ' ...
    'the run with share 1 on L2 = the RE(t-1) run tsw07_a1_re (paths 1e-10)'];
try
    re = tsw07_a1_re();
    rr = hetlearn.run(re, 'save', false, 'quiet', true);
    c = tsw07_a1_learn();
    c.expectations.types = {ty('name', 'RE', 'kind', 're'), ty('name', 'L1', 'kind', 'level', 'base', 'RE', 'k', 1), ...
        ty('name', 'L2', 'kind', 'level', 'base', 'RE', 'k', 2)};
    c.expectations.mode = 'fixed_shares';
    c.shares.fixed = struct('RE', 0, 'L1', 0, 'L2', 1);
    rc = hetlearn.run(c, 'save', false, 'quiet', true);
    L = rc.learning.pinf;
    rd = rc.dates.record;
    df = max([maxabs(L.f_L1(rd) - L.f_RE(rd)), maxabs(L.f_L2(rd) - L.f_RE(rd))]);
    dp = 0;
    for v = {'pinfobs', 'dy', 'robs', 'dc', 'pinf', 'y', 'pinf_exp1'}
        dp = max(dp, sdiff(rr.paths.(v{1}), rc.paths.(v{1})));
    end
    ok = df <= 1e-12 && dp <= 1e-10;
    R = add(R, nm, ok, sprintf('level forecasts vs RE %.3g over %d quarters; paths vs tsw07_a1_re %.3g', df, ...
        numel(rd), dp));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = de(R)
nm = ['an A5: anchored DE = model-consistent DE at n_RE = 1 (variant 10 on the anchored baseline): load check ' ...
    'and independent IRFs (1e-10); the anchored expression loads on the memory states and pinf_DEg_RE{-1}'];
try
    c = tsw07_a1_learn();
    c.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', ...
        'exclude', {{'invef', 'pkf', 'rkf', 'cf', 'labf'}});
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec(o.model);
    [ma, ia] = hetlearn.load_model(spec, o);
    k1 = ia.re_info_check.anchored_vs_mc_maxdiff;
    c2 = c;
    c2.expectations.re_variant = 'model_consistent';
    [mm, ~] = hetlearn.load_model(spec, hetlearn.load_options(c2));
    el = cellstr(get(mm, 'eList'));
    sa = srf(ma, 1:40, 'select', el);
    sm = srf(mm, 1:40, 'select', el);
    d = 0;
    for v = {'pinf', 'y', 'r', 'c', 'inve', 'w', 'lab', 'pinf_exp1'}
        e = abs(sa.(v{1})(1:40, :) - sm.(v{1})(1:40, :));
        e(isnan(e)) = Inf;
        d = max([d; e(:)]);
    end
    pv = get(ma, 'parameters');
    xs = ia.meta.anchor_xstates.pinf;
    pn = ia.meta.anchor_params.pinf;
    ex = xs(numel(ia.meta.re_states) + 1:end);
    ce = cellfun(@(s) pv.(pn{1 + find(strcmp(xs, s), 1)}), ex);
    cmem = max(abs(ce(~strcmp(ex, 'pinf_DEg_RE'))));
    cdeg = abs(ce(strcmp(ex, 'pinf_DEg_RE')));
    ok = k1 < 1e-10 && d < 1e-10 && cmem > 1e-6 && ~isempty(cdeg) && cdeg > 1e-6 && ia.meta.generator_version >= 7;
    R = add(R, nm, ok, sprintf(['load check %.3g; independent IRFs %.3g; %d extra anchored terms (%s), largest ' ...
        'memory coefficient %.4g, on pinf_DEg_RE{-1} %.4g'], k1, d, numel(ex), strjoin(ex, ', '), cmem, cdeg));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = io(R)
nm = ['an A6: variant 23 with abar fixed at 0 (types RE and IO): the IO forecast = the RE forecast in every ' ...
    'quarter, shares stay at 0.5, the run = the RE(t-1) run tsw07_a1_re (paths 1e-10)'];
try
    rr = hetlearn.run(tsw07_a1_re(), 'save', false, 'quiet', true);
    c = tsw07_a1_learn();
    c.expectations.types = {ty('name', 'RE', 'kind', 're'), ty('name', 'IO', 'kind', 're_mean', 'update', 'fixed')};
    c.beliefs.init.method = 'user';
    c.beliefs.init.values = struct('pinf_feRE', struct('alpha', 0));
    rc = hetlearn.run(c, 'save', false, 'quiet', true);
    L = rc.learning.pinf;
    rd = rc.dates.record;
    df = maxabs(L.f_IO(rd) - L.f_RE(rd));
    ab = maxabs(rc.learning.pinf_feRE__IO.alpha_pinf_feRE__IO(rd));
    dn = maxabs(L.n_IO(rd) - 0.5);
    dp = 0;
    for v = {'pinfobs', 'dy', 'robs', 'dc', 'pinf', 'y', 'pinf_exp1'}
        dp = max(dp, sdiff(rr.paths.(v{1}), rc.paths.(v{1})));
    end
    % IRIS solves pinf_exp1_IO on its own row of the forecast-stage model: rounding (about 2e-15)
    ok = df < 1e-14 && ab == 0 && dn < 1e-15 && dp <= 1e-10;
    R = add(R, nm, ok, sprintf('IO vs RE forecasts %.3g, max |abar| %.3g, shares - 0.5 %.3g; paths vs tsw07_a1_re %.3g', ...
        df, ab, dn, dp));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = re1(R)
nm = ['an A7: variant 33: re1(y{+1} - y) = E_{t-1}(y_{t+1} - y_t) by a two-period simulation of the RE limit ' ...
    'from the state at t-1, and the FN forecast = dn_{t-1} - re1, every forecast quarter (1e-10)'];
try
    c = tsw07_a1_learn();
    c.expectations.types = {ty('name', 'RE', 'kind', 're'), ty('name', 'FN', 'kind', 'rule', 'rule', ...
        'dn{-1} - re1(y{+1} - y)')};
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec(o.model);
    [m, info] = hetlearn.load_model(spec, o);
    res = hetlearn.run(c, 'save', false, 'quiet', true, 'model', struct('spec', spec, 'm', m, 'info', info));
    p = res.paths;
    hz = res.dates.horizon;
    xl = cellstr(get(m, 'xList'));
    el = cellstr(get(m, 'eList'));
    worst1 = 0;
    worst2 = 0;
    for k = 1:numel(hz)
        t = hz(k);
        db = struct();
        for i = 1:numel(xl)
            db.(xl{i}) = clip(p.(xl{i}), p.(xl{i}).Start, t - 1);
        end
        for i = 1:numel(el)
            db.(el{i}) = Series(t - 8:t + 1, 0);
        end
        s = simulate(m, db, t:t + 1, 'prependInput', true, 'anticipate', false);
        r1 = s.y(t + 1) - s.y(t);
        dn = p.y(t - 1) - p.y(t - 2) + p.pinf(t - 1);
        f = p.pinf_exp1_FN(t);
        worst1 = max(worst1, abs(f - (dn - r1)));
        worst2 = max(worst2, abs(res.learning.pinf.f_FN(t) - f));
    end
    v = info.nt.model_values.re1.re1FN1_pinf;
    ok = worst1 < 1e-10 && worst2 == 0 && v.check_maxdiff < 1e-9;
    R = add(R, nm, ok, sprintf(['FN forecast vs dn - simulated re1 %.3g over %d quarters; recorded vs path %.3g; ' ...
        're1 unit check %.3g'], worst1, numel(hz), worst2, v.check_maxdiff));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = score(R)
nm = ['an A8: fitness on transformed forecasts (variant 18): f_OPT - f_PES = 2g in every quarter (1e-12), ' ...
    'their squared errors differ and their shares leave 0.5'];
try
    T = @ty;
    c = tsw07_a1_learn();
    c.expectations.variables = {'pinf', 'c'};
    c.expectations.types = {T('name', 'TAR', 'kind', 'rule', 'rule', '0', 'variables', {{'pinf'}}), ...
        T('name', 'EXT', 'kind', 'rule', 'rule', 'x{-1}', 'variables', {{'pinf'}}), ...
        T('name', 'OPT', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}}), ...
        T('name', 'PES', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}})};
    c.expectations.transforms = [struct('kind', 'wedge', 'types', {{'OPT'}}, 'factor', struct('mean', 'model:sd_ygap_half')), ...
        struct('kind', 'wedge', 'types', {{'PES'}}, 'factor', struct('mean', '-model:sd_ygap_half'))];
    c.forecast.horizon = 4;
    res = hetlearn.run(c, 'save', false, 'quiet', true);
    g = res.meta.model_values.sd_ygap_half.value;
    L = res.learning.c;
    rd = res.dates.record;
    d2g = maxabs(L.f_OPT(rd) - L.f_PES(rd) - 2 * g);
    dbase = maxabs(L.fb_OPT(rd) - L.fb_PES(rd));
    fe = L.FE_OPT(rd) - L.FE_PES(rd);
    nOPT = L.n_OPT(qq(2022, 2));
    ok = d2g < 1e-12 && dbase < 1e-12 && max(abs(fe(isfinite(fe)))) > 1e-6 && abs(nOPT - 0.5) > 1e-3;
    R = add(R, nm, ok, sprintf(['g %.4f; f_OPT - f_PES - 2g %.3g; base forecasts equal (%.3g); max |FE_OPT - ' ...
        'FE_PES| %.4g; OPT share at 2022Q2 %.4f'], g, d2g, dbase, max(abs(fe(isfinite(fe)))), nOPT));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function v = sdiff(a, b)
% max abs difference of two Series on the dates of either (NaN in one only counts as Inf)
v = 0;
for r = {a.Range, b.Range}
    x = a(r{1});
    y = b(r{1});
    e = abs(x(:) - y(:));
    e(isnan(x(:)) & isnan(y(:))) = 0;
    e(isnan(e)) = Inf;
    v = max([v; e]);
end
end


function v = maxabs(x)
x = x(:);
x(isnan(x)) = 0;
v = max([0; abs(x)]);
end


function s = where(err)
s = err.message;
if ~isempty(err.stack)
    s = sprintf('%s (%s, line %d)', s, err.stack(1).name, err.stack(1).line);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
