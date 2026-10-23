function R = test_ntypes(part)
%TEST_NTYPES  N agent types (docs/USER_GUIDE.md sections 7.1-7.2; rule 19 of the portfolio).
%
%   R = test_ntypes()        every part
%   R = test_ntypes(part)    'units' | 'r3' | 'hl' | 'modes'
%
%   13 checks. B1-B2, S1 and A1-A4 were removed with the features they tested;
%   the other labels are unchanged.
%   U1-U5  hetlearn.switching.discrete_choice_n and init_fitness_n: the two-type
%          case equals discrete_choice/init_fitness, the N-type logit with
%          normalized fitness (hand formula), edge cases, initial fitness through
%          the logit; hetlearn.plm.rule_terms on the rule grammar (numbers,
%          + - * / ( ), x{-k}, other transition variables with lags, constants)
%          and the rejected rules (malformed, or using terms that no longer exist)
%   R3     the baseline in N-type syntax (types RE and BR spelled out) equals the
%          two-type run: the frozen SW07 baseline (tsw07_a1_learn) and its RE(t-1)
%          benchmark (tsw07_a1_re), the toy switching run; the two-type file on the
%          N-type engine path (shares.init given); <= 1e-12 in paths, shares,
%          fitness, forecasts, beliefs, gains, events and final state. The RE
%          filters are recomputed in this session for both runs (not read from the
%          caches, whose values depend on the thread count of the session that wrote
%          them, about 2e-11 on SW07)
%   H1-H2  Hommes-Lustenhouwer target believers (variant 19): a TB type at share 0
%          leaves the baseline unchanged (learning and state <= 1e-12; paths 1e-10:
%          the extra variable changes the state space, so the RE filter differs at
%          rounding level, about 2e-11 on SW07); a TB-only population (share 1)
%          is the SW07 model with every pinf{+1} replaced by 0, written from the
%          source text (IRFs, 1e-10)
%   M1-M2  mode semantics with N types (toy): 'fixed_shares' with shares.fixed,
%          'learning' on the single non-RE type (a rule type), 'rational' without a
%          listed RE type = the RE run, 'learning' with two non-RE types an error;
%          history.learn = false with RE and BR spelled out = the two-type run
%
%   Runs are not saved (hetlearn.run 'save', false). Toy results only in
%   memory. About 2 minutes; the first call generates the N-type model files.

if nargin < 1 || isempty(part)
    part = {'units', 'r3', 'hl', 'modes'};
end
part = cellstr(part);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));
R = struct('name', {}, 'pass', {}, 'msg', {});
if any(strcmp(part, 'units'))
    R = units(R);
end
if any(strcmp(part, 'r3'))
    R = r3(R, here);
end
if any(strcmp(part, 'hl'))
    R = hl(R, here);
end
if any(strcmp(part, 'modes'))
    R = modes(R, here);
end
end


% =========================================================================================
function R = units(R)
nm = 'nt U1: discrete_choice_n with two types = discrete_choice, init_fitness_n = init_fitness (3 groups)';
try
    rs = RandStream('mt19937ar', 'Seed', 1);
    FE = rand(rs, 3, 2) * 2;
    U = -rand(rs, 3, 2);
    [n1, zr, zb] = hetlearn.switching.discrete_choice(FE(:, 1)', FE(:, 2)', U(:, 1)', U(:, 2)', 1.7, 0.6);
    [n, Un] = hetlearn.switching.discrete_choice_n(FE, U, 1.7, 0.6);
    d = max(abs([n(:, 1)' - n1, n(:, 2)' - (1 - n1), Un(:, 1)' - zr, Un(:, 2)' - zb]));
    [z0, z1] = hetlearn.switching.init_fitness([0.2 0.5 0.9], 1.7);
    U0 = hetlearn.switching.init_fitness_n([0.8 0.2; 0.5 0.5; 0.1 0.9], 1.7);
    d0 = max(abs([U0(:, 1)' - z0, U0(:, 2)' - z1]));
    R = add(R, nm, d <= 1e-15 && d0 <= 1e-15, sprintf('shares/fitness %.2g, initial fitness %.2g', d, d0));
catch err
    R = add(R, nm, false, err.message);
end

nm = 'nt U2: the N-type logit with normalized fitness follows the hand formula (4 types, 30 periods)';
try
    rs = RandStream('mt19937ar', 'Seed', 2);
    chi = 0.7; om = 0.6;
    FE = rand(rs, 1, 4); U = -rand(rs, 1, 4);
    [n, Un] = hetlearn.switching.discrete_choice_n(FE, U, chi, om);
    Uh = om * U - (1 - om) * FE;
    e = exp(chi * Uh);
    d1 = max(abs([n - e / sum(e), Un - Uh]));
    % the recursion over 30 periods from zero fitness, against the hand recursion
    Ua = zeros(1, 4); Uh = zeros(1, 4); d2 = 0;
    for t = 1:30
        fe = rand(rs, 1, 4) * 4;
        [na, Ua] = hetlearn.switching.discrete_choice_n(fe, Ua, chi, om);
        Uh = om * Uh - (1 - om) * fe;
        e = exp(chi * (Uh - max(Uh)));
        d2 = max([d2, abs(na - e / sum(e)), abs(Ua - Uh)]);
    end
    R = add(R, nm, d1 <= 1e-15 && d2 <= 1e-12, sprintf('one step %.2g, 30 periods %.2g', d1, d2));
catch err
    R = add(R, nm, false, err.message);
end

nm = 'nt U3: discrete_choice_n edge cases (share 0 stays 0, memory 0, chi = 0, chi*U ~ 1e7, NaN error)';
try
    U0 = hetlearn.switching.init_fitness_n([0.5 0.5 0], 2);
    [n, U] = hetlearn.switching.discrete_choice_n([1 2 0], U0, 2, 0.8);
    a = n(3) == 0 && U(3) == -Inf && abs(sum(n) - 1) < 1e-15;
    [n, U] = hetlearn.switching.discrete_choice_n([1 2 0], U0, 2, 0);
    b = all(isfinite(U)) && all(isfinite(n)) && n(3) > n(1);          % memory 0: the type re-enters
    n = hetlearn.switching.discrete_choice_n([1 2 0], [-5 -1 3], 0, 0.6);
    c = max(abs(n - 1/3)) < 1e-15;
    n = hetlearn.switching.discrete_choice_n([0 1e6 0], [0 0 -1e6], 8, 0.6);
    dd = all(isfinite(n)) && abs(n(1) - 1) < 1e-15;
    n = hetlearn.switching.discrete_choice_n([NaN 1 1], [0 0 0], 1, 0.5);
    e = all(isnan(n));
    R = add(R, nm, a && b && c && dd && e, sprintf('%d %d %d %d %d', a, b, c, dd, e));
catch err
    R = add(R, nm, false, err.message);
end

nm = 'nt U4: init_fitness_n returns the initial shares through the logit (three groups, one chi each)';
try
    n0 = [0.25 0.25 0.25 0.25; 0.1 0.2 0.3 0.4; 0 0.5 0.25 0.25];
    chi = [0.4; 2; 1.3];
    U0 = hetlearn.switching.init_fitness_n(n0, chi);
    d = 0;
    for g = 1:3
        a = chi(g) * U0(g, :);
        e = exp(a - max(a));
        d = max([d, abs(e / sum(e) - n0(g, :))]);
    end
    R = add(R, nm, d < 1e-15, sprintf('max diff %.2g', d));
catch err
    R = add(R, nm, false, err.message);
end

nm = ['nt U5: rule_terms: text, terms and timing of rules in x{-k}, other variables and constants; ' ...
    'output fields; malformed rules and the terms self, mean, dn, re1(...) rejected'];
try
    tv = {'pinf', 'y', 'r'};
    a = hetlearn.plm.rule_terms('x{-1} + 0.4*(x{-1} - x{-2})', 'pinf', 'WTR', 'lagged', tv);
    b = hetlearn.plm.rule_terms('0', 'pinf', 'TB', 'lagged', tv);
    c = hetlearn.plm.rule_terms(struct('expr', 'c1*x{-1} + c2*r{-1}', 'params', struct('c1', 0.5, 'c2', 2)), ...
        'pinf', 'FN', 'lagged', tv);
    ok = strcmp(a.text, 'pinf{-1} + 0.4*(pinf{-1} - pinf{-2})') && a.maxlag == 2 ...
        && strcmp(b.text, '0') && isempty(b.terms) && b.maxlag == 0 ...
        && strcmp(c.text, 'c1__FN*pinf{-1} + c2__FN*r{-1}') && c.maxlag == 1 ...
        && strcmp(c.param_names.c1, 'c1__FN') && c.param_values.c2 == 2;
    % the output fields and term kinds of the rule grammar (no own-forecast, mean or re1 terms)
    fl = {'text', 'mexpr', 'terms', 'param_names', 'param_values', 'maxlag', 'expr'};
    kinds = unique([{a.terms.kind}, {c.terms.kind}]);
    okf = isempty(setxor(fieldnames(a), fl)) && isempty(setxor(fieldnames(c), fl)) ...
        && all(ismember(kinds, {'var', 'param'}));
    f = str2func(['@(v) ' c.mexpr]);
    v = zeros(numel(c.terms), 1);
    for j = 1:numel(c.terms)
        switch c.terms(j).kind
            case 'param'
                v(j) = c.param_values.(c.terms(j).name);
            otherwise
                v(j) = j;
        end
    end
    ok = ok && okf && isfinite(f(v));
    % malformed rules, and rules in the terms that are not supported (own forecast, learned mean,
    % nominal growth, anchored RE forecast)
    bad = {'x', 'lagged'; 'x{-1}*x{-2}', 'lagged'; 'x{+1}', 'current'; 'q{-1}', 'lagged'; ...
        '0.65*x{-1} + 0.35*self{-1}', 'lagged'; 'self + x{-1}', 'lagged'; ...
        '0.5*(mean + x{-1}) + (x{-1} - x{-2})', 'lagged'; 'mean{-1}', 'lagged'; ...
        'dn{-1}', 'lagged'; 'dn{-1} - re1(y{+1} - y)', 'lagged'; 're1(y{-1})', 'lagged'};
    nbad = 0;
    miss = {};
    for i = 1:size(bad, 1)
        try
            hetlearn.plm.rule_terms(bad{i, 1}, 'pinf', 'K', bad{i, 2}, tv);
            miss{end+1} = bad{i, 1}; %#ok<AGROW>
        catch err
            nbad = nbad + strcmp(err.identifier, 'hetlearn:types:rule');
        end
    end
    cur = hetlearn.plm.rule_terms('0.5*x + 0.5*x{-1}', 'pinf', 'K', 'current', tv);
    ok = ok && nbad == size(bad, 1) && strcmp(cur.text, '0.5*pinf + 0.5*pinf{-1}');
    R = add(R, nm, ok, sprintf('fields and term kinds %d; %d of %d rejected rules rejected (accepted: %s)', okf, ...
        nbad, size(bad, 1), strjoin(miss, ' | ')));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================================
function R = r3(R, here)
T = @(varargin) struct(varargin{:});
pair = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm')};
tol = 1e-12;

nm = 'nt R3a: SW07 baseline (tsw07_a1_learn) with types RE and BR spelled out = the two-type run (<= 1e-12)';
try
    a = tsw07_a1_learn();
    ra = fresh_run(a);
    b = a;
    b.expectations.types = pair;
    rb = fresh_run(b);
    [d, msg] = compare_runs(ra, rb, {'pinf'}, 'BR');
    ok = d <= tol && rb.meta.generator_version_ok;
    R = add(R, nm, ok, sprintf('%s; N-type file %s', msg, short(rb.meta.ext_file)));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'nt R3b: SW07 RE(t-1) benchmark (tsw07_a1_re, mode rational) with RE and BR spelled out = the two-type run';
try
    a = tsw07_a1_re();
    ra = fresh_run(a);
    b = a;
    b.expectations.types = pair;
    rb = fresh_run(b);
    [d, msg] = compare_runs(ra, rb, {'pinf'}, 'BR');
    R = add(R, nm, d <= tol, msg);
catch err
    R = add(R, nm, false, where(err));
end

nm = 'nt R3c: the two-type file on the N-type engine path (shares.init given, tsw07_a1_learn) = the two-type run';
try
    a = tsw07_a1_learn();
    ra = hetlearn.run(a, 'save', false, 'quiet', true);
    b = a;
    b.shares.init = struct('RE', 0.5, 'BR', 0.5);
    rb = hetlearn.run(b, 'save', false, 'quiet', true);
    [d, msg] = compare_runs(ra, rb, {'pinf'}, 'BR');
    same = strcmp(ra.meta.ext_file, rb.meta.ext_file) && isfield(rb.learning.pinf, 'n_BR');
    R = add(R, nm, d <= tol && same, sprintf('%s; same generated file %d', msg, same));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'nt R3d: toy switching run on y and pie (period-t RE information) with RE and BR spelled out = the two-type run';
try
    a = toy_cfg(here);
    ra = fresh_run(a);
    b = a;
    b.expectations.types = pair;
    rb = fresh_run(b);
    [d, msg] = compare_runs(ra, rb, {'y', 'pie'}, 'BR');
    R = add(R, nm, d <= tol, msg);
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = hl(R, here) %#ok<INUSD>
T = @(varargin) struct(varargin{:});
three = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm'), T('name', 'TB', 'kind', 'rule', 'rule', '0')};

nm = 'nt H1: target believers at share 0 ({RE, BR, TB}, shares.init TB = 0) leave the SW07 baseline unchanged';
try
    a = tsw07_a1_learn();
    ra = fresh_run(a);
    b = a;
    b.expectations.types = three;
    b.shares.init = struct('RE', 0.5, 'BR', 0.5, 'TB', 0);
    rb = fresh_run(b);
    % the extra variable pinf_exp1_TB changes the state space of the model, so the RE filter differs at
    % rounding level (paths 1e-10, the tolerance of the collapse tests); learning and state 1e-12
    [d, msg, dd] = compare_runs(ra, rb, {'pinf'}, 'BR', {'pinf_exp1_TB'});
    z = max(abs(rb.learning.pinf.n_TB(rb.dates.record)));
    ok = isfinite(d) && dd.paths <= 1e-10 && dd.learning <= 1e-12 && dd.state <= 1e-12 && z == 0;
    R = add(R, nm, ok, sprintf('%s; max TB share %.3g', msg, z));
catch err
    R = add(R, nm, false, where(err));
end

nm = ['nt H2: a TB-only population (n_TB_pinf = 1) is the SW07 model with pinf{+1} replaced by 0 ' ...
    '(source text; IRFs of every variable, 40 periods, 1e-10)'];
try
    c3 = tsw07_a1_learn();
    c3.expectations.types = three;
    o = hetlearn.load_options(c3);
    spec = hetlearn.load_spec('sw07');
    [m, info] = hetlearn.load_model(spec, o);
    m.n_RE_pinf = 0;
    m.n_BR_pinf = 0;
    m.n_TB_pinf = 1;
    [m, ok] = hetlearn.engine.solve_model(m, spec);
    txt = fileread(fullfile(spec.folder, spec.model_file));
    nrep = numel(strfind(txt, 'pinf{+1}'));
    tmp = tempname;
    mkdir(tmp);
    c = onCleanup(@() rmdir(tmp, 's'));
    f = fullfile(tmp, 'sw07_tb.model');
    fid = fopen(f, 'w');
    fprintf(fid, '%s', strrep(txt, 'pinf{+1}', '0'));
    fclose(fid);
    mh = Model.fromFile(f, 'linear', true, 'assign', spec.assign);
    P = info.params;
    pn = fieldnames(get(mh, 'parameters'));
    q = fieldnames(P);
    for i = 1:numel(q)
        if any(strcmp(pn, q{i})) || strncmp(q{i}, 'std_', 4)
            mh.(q{i}) = P.(q{i});
        end
    end
    [mh, okh] = hetlearn.engine.solve_model(mh, spec);
    sa = srf(m, 1:40);
    sh = srf(mh, 1:40);
    xl = cellstr(get(mh, 'xList'));
    dd = 0;
    for i = 1:numel(xl)
        e = abs(sa.(xl{i})(1:40, :) - sh.(xl{i})(1:40, :));
        e(isnan(e)) = Inf;
        dd = max([dd; e(:)]);
    end
    R = add(R, nm, ok && okh && nrep == 4 && dd < 1e-10, sprintf(['%d occurrences of pinf{+1} replaced; both ' ...
        'solve %d %d; max IRF diff %.3g over %d variables'], nrep, ok, okh, dd, numel(xl)));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = modes(R, here)
T = @(varargin) struct(varargin{:});
nm = ['nt M1: mode semantics with N types (toy, pie): fixed_shares = shares.fixed in the model and the ' ...
    'aggregate; learning = share 1 on the single non-RE type; rational with RE not listed = the RE run; ' ...
    'learning with two non-RE types is an error'];
try
    c = toy_cfg(here);
    c.expectations.variables = {'pie'};
    % (a) fixed shares over three types
    a = c;
    a.expectations.mode = 'fixed_shares';
    a.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm'), ...
        T('name', 'TB', 'kind', 'rule', 'rule', '0')};
    a.shares.fixed = struct('RE', 0.3, 'BR', 0.5, 'TB', 0.2);
    ra = hetlearn.run(a, 'save', false, 'quiet', true);
    hz = ra.dates.horizon;
    L = ra.learning.pie;
    da = max(abs([L.n_model_RE(hz) - 0.3; L.n_model_BR(hz) - 0.5; L.n_model_TB(hz) - 0.2]));
    P = ra.paths;
    agg = 0.3 * P.pie_exp1_RE(hz) + 0.5 * P.pie_exp1_BR(hz) + 0.2 * P.pie_exp1_TB(hz);
    da = max([da; abs(P.pie_exp1(hz) - agg); abs(P.pie_exp1_TB(hz))]);
    % (b) learning: share 1 on the one non-RE type (a rule)
    b = c;
    b.expectations.mode = 'learning';
    b.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'LR', 'kind', 'rule', 'rule', ...
        '0.65*x{-1} + 0.35*x{-2}')};
    rb = hetlearn.run(b, 'save', false, 'quiet', true);
    Lb = rb.learning.pie;
    db = max(abs([Lb.n_model_LR(hz) - 1; Lb.n_model_RE(hz); rb.paths.pie_exp1(hz) - rb.paths.pie_exp1_LR(hz)]));
    % the rule in the simulated paths: f_t = 0.65 pie_{t-1} + 0.35 pie_{t-2}
    f = rb.paths.pie_exp1_LR;
    p = rb.paths.pie;
    db = max([db; abs(f(hz) - (0.65 * p(hz - 1) + 0.35 * p(hz - 2)))]);
    % (c) rational with RE not listed: the RE run (common variables)
    r = c;
    r.expectations.mode = 'rational';
    rr = fresh_run(r);
    q = r;
    q.expectations.types = {T('name', 'LR', 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*x{-2}'), ...
        T('name', 'WTR', 'kind', 'rule', 'rule', 'x{-1} + 0.4*(x{-1} - x{-2})')};
    rq = fresh_run(q);
    dc = 0;
    f = fieldnames(rr.paths);
    for i = 1:numel(f)
        if endsWith(f{i}, '_exp1_BR')
            continue
        end
        dc = max(dc, sdiff(rr.paths.(f{i}), rq.paths.(f{i})));
    end
    nRE = max(abs(rq.learning.pie.n_model_RE(hz) - 1));
    % (d) learning with two non-RE types
    e = c;
    e.expectations.mode = 'learning';
    e.expectations.types = q.expectations.types;
    try
        hetlearn.run(e, 'save', false, 'quiet', true);
        de = false;
    catch err
        de = strcmp(err.identifier, 'hetlearn:engine:types');
    end
    ok = da < 1e-12 && db < 1e-12 && dc < 1e-12 && nRE == 0 && de;
    R = add(R, nm, ok, sprintf(['fixed shares and aggregate %.3g; learning %.3g; rational without a listed RE ' ...
        'type vs the RE run %.3g (n_model_RE 1: %d); error for two non-RE types %d'], da, db, dc, nRE == 0, de));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'nt M2: history.learn = false with RE and BR spelled out = the two-type run (toy, pie; <= 1e-12)';
try
    c = toy_cfg(here);
    c.expectations.variables = {'pie'};
    a = c;
    a.history.learn = false;
    ra = fresh_run(a);
    b = a;
    b.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm')};
    rb = fresh_run(b);
    [d1, msg] = compare_runs(ra, rb, {'pie'}, 'BR');
    R = add(R, nm, d1 <= 1e-12, sprintf('learn = false: %s', msg));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
% helpers
function c = toy_cfg(here)
c = struct();
c.id = 'nt_toy';
c.model = fullfile(here, 'toy_nk');
c.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
c.expectations = struct('mode', 'switching', 'variables', {{'y', 'pie'}});
end


function res = fresh_run(cfg)
% hetlearn.run with the RE filter recomputed in this session (fresh_filter), not read from a cache
opts = hetlearn.load_options(cfg);
spec = hetlearn.load_spec(opts.model);
[m, info] = hetlearn.load_model(spec, opts);
H = fresh_filter(spec, opts);
res = hetlearn.run(cfg, 'save', false, 'quiet', true, 'model', struct('spec', spec, 'm', m, 'info', info), ...
    'filter', H);
res.meta.generator_version_ok = isfield(info.meta, 'generator_version') && (info.meta.generator_version == 6) ...
    == (isfield(info.meta, 'ntype') && info.meta.ntype);
end


function H = fresh_filter(spec, opts)
% the IRIS filter call of hetlearn.re_filter, without its cache file
lagged = strcmp(opts.expectations.re_info, 'lagged');
o = opts;
if ~lagged
    o.expectations.variables = 'all';
end
o.policy.mode = 'rule';
[m, info] = hetlearn.load_model(spec, o);
d = hetlearn.load_database(spec);
range = hetlearn.util.to_dates(spec.filter_range);
H = struct();
if lagged
    [~, f] = filter(m, d, range, 'output', 'pred,filter,smooth', 'meanOnly', true);
    H.predicted = f.pred;
else
    [~, f] = filter(m, d, range, 'output', 'filter,smooth', 'meanOnly', true);
end
H.smooth = f.smooth;
H.filtered = f.filter;
H.range = range;
H.data = d;
H.fit_error = 0;
H.hash = ['fresh:' info.meta.ext_file];
H.file = '';
H.cached = false;
H.model = m;
H.realtime = false;
H.end_date = range(end);
end


function [dmax, msg, d] = compare_runs(ra, rb, lv, k, extra)
% two-type run ra against an N-type run rb whose types are RE and k (and the paths extra of other types):
% max abs difference
if nargin < 5
    extra = {};
end
d = struct('paths', 0, 'learning', 0, 'state', 0);
w = struct('paths', '', 'learning', '', 'state', '');
bad = {};
pa = fieldnames(ra.paths);
pb = setdiff(fieldnames(rb.paths), extra);
if ~isempty(setxor(pa, pb))
    bad{end+1} = ['path names differ: ' strjoin(reshape(setxor(pa, pb), 1, []), ', ')];
end
for i = 1:numel(pa)
    if isfield(rb.paths, pa{i})
        [d, w] = upd(d, w, 'paths', sdiff(ra.paths.(pa{i}), rb.paths.(pa{i})), pa{i});
    end
end
map = {'n1', 'n_RE'; 'n2', ['n_' k]; 'n1_model', 'n_model_RE'; 'zetaRE', 'U_RE'; 'zetaBR', ['U_' k]; ...
    'FE_RE', 'FE_RE'; 'FE_BR', ['FE_' k]; 'fRE', 'f_RE'; 'fBR', ['f_' k]};
tg = fieldnames(ra.learning);
for i = 1:numel(tg)
    A = ra.learning.(tg{i});
    if any(strcmp(lv, tg{i}))
        B = rb.learning.(tg{i});
        for j = 1:size(map, 1)
            [d, w] = upd(d, w, 'learning', sdiff(A.(map{j, 1}), B.(map{j, 2})), [tg{i} '.' map{j, 1}]);
        end
    end
    K = rb.learning.([tg{i} '__' k]);
    f = setdiff(fieldnames(A), [map(:, 1)', {'isAux', 'params'}]);
    for j = 1:numel(f)
        g = f{j};
        if ~isfield(K, g)
            g = regexprep(g, '^(R_)?(.*)$', ['$1$2__' k]);
        end
        [d, w] = upd(d, w, 'learning', sdiff(A.(f{j}), K.(g)), [tg{i} '.' f{j}]);
    end
end
Ea = ra.events;
Eb = rb.events;
if height(Ea) ~= height(Eb)
    bad{end+1} = sprintf('%d vs %d events', height(Ea), height(Eb));
else
    s = @(c) regexprep(c, ['__' k '\>'], '');
    if ~isequal(Ea.date, Eb.date) || ~isequal(Ea.type, Eb.type) || ~isequal(Ea.stage, Eb.stage) ...
            || ~isequal(Ea.variable, s(Eb.variable)) || ~isequal(Ea.detail, s(Eb.detail))
        bad{end+1} = 'events differ';
    end
end
Sa = ra.state;
Sb = rb.state;
for i = 1:numel(tg)
    q = [tg{i} '__' k];
    [d, w] = upd(d, w, 'state', maxabs(Sa.phi.(tg{i}) - Sb.phi.(q)), ['phi.' tg{i}]);
    [d, w] = upd(d, w, 'state', maxabs(Sa.R.(tg{i}) - Sb.R.(q)), ['R.' tg{i}]);
    [d, w] = upd(d, w, 'state', maxabs(Sa.fe_hist.(tg{i}) - Sb.fe_hist.(q)), ['fe_hist.' tg{i}]);
    [d, w] = upd(d, w, 'state', maxabs(Sa.phi_hist.(tg{i}) - Sb.phi_hist.(q)), ['phi_hist.' tg{i}]);
end
for g = 1:numel(Sa.n1)
    [d, w] = upd(d, w, 'state', maxabs([Sa.n1(g), Sa.zetaRE(g), Sa.zetaBR(g)] - [Sb.n{g}(1), Sb.U{g}(1), Sb.U{g}(2)]), 'shares');
end
for i = 1:numel(lv)
    [d, w] = upd(d, w, 'state', maxabs([Sa.fRE.(lv{i}), Sa.fBR.(lv{i})] - [Sb.f.(lv{i}).RE, Sb.f.(lv{i}).(k)]), 'forecasts');
end
[gd, ok] = numdiff(Sa.gain, Sb.gain.(k));
if ~ok
    bad{end+1} = 'gain states differ in structure';
end
[d, w] = upd(d, w, 'state', gd, 'gain');
dmax = max([d.paths, d.learning, d.state]);
if ~isempty(bad)
    dmax = Inf;
end
msg = sprintf('max diff paths %.3g (%s), learning %.3g (%s), final state %.3g (%s); %d events', d.paths, ...
    w.paths, d.learning, w.learning, d.state, w.state, height(Ea));
if ~isempty(bad)
    msg = [msg '; ' strjoin(bad, '; ')];
end
end


function [d, w] = upd(d, w, f, v, name)
if ~(v <= d.(f))
    d.(f) = v;
    w.(f) = name;
end
end


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


function [d, ok] = numdiff(a, b)
% max abs difference of the numeric leaves of two structs of the same layout
d = 0;
ok = true;
if isstruct(a)
    if ~isstruct(b) || ~isequal(sort(fieldnames(a)), sort(fieldnames(b))) || ~isequal(size(a), size(b))
        ok = false;
        return
    end
    f = fieldnames(a);
    for i = 1:numel(a)
        for j = 1:numel(f)
            [e, o] = numdiff(a(i).(f{j}), b(i).(f{j}));
            d = max(d, e);
            ok = ok && o;
        end
    end
elseif isnumeric(a) || islogical(a)
    if ~isequal(size(a), size(b))
        ok = false;
        return
    end
    d = maxabs(double(a) - double(b));
elseif iscell(a)
    if ~iscell(b) || ~isequal(size(a), size(b))
        ok = false;
        return
    end
    for i = 1:numel(a)
        [e, o] = numdiff(a{i}, b{i});
        d = max(d, e);
        ok = ok && o;
    end
else
    ok = isequal(a, b);
end
end


function s = short(f)
[~, n, x] = fileparts(f);
s = [n x];
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
