function R = test_ntypes(part)
%TEST_NTYPES  N agent types, phase P2 of docs/DESIGN_br_extensions.md (1.1-1.2, 1.7 R3, sec. 2 variants 17, 19, 27).
%
%   R = test_ntypes()        every part
%   R = test_ntypes(part)    'units' | 'r3' | 'hl' | 'bma' | 'shares' | 'modes' | 'ah'
%
%   U1-U5  hetlearn.switching.discrete_choice_n and init_fitness_n: the two-type
%          case equals discrete_choice/init_fitness, inertia, costs, the fitness
%          normalisation (unnormalized at beta = normalized at beta/(1 - omega)),
%          edge cases; hetlearn.plm.rule_terms
%   R3     the baseline in N-type syntax (types RE and BR spelled out) equals the
%          two-type run: SW07 2026-10-20 baseline (tsw07_a1_learn) and its RE(t-1)
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
%   B1-B2  Bayesian model averaging (variant 27, fitness 'unnormalized', memory 1,
%          intensity 'model:bma'): shares = prior x exp(-chi*SSE) / sum from the
%          recorded errors (1e-12); chi = 1/(2 sigma^2) with sigma^2 the h-step
%          forecast-error variance from IRIS srf (toy h = 1, SW07 RE(t-1) h = 2)
%   S1     engine shares with inertia, a cost and unnormalized fitness = the hand
%          recursion from the recorded errors (toy, 1e-12)
%   M1-M2  mode semantics with N types (toy): 'fixed_shares' with shares.fixed,
%          'learning' on the single non-RE type, 'rational' without a listed RE type
%          = the RE run, 'learning' with two non-RE types an error; history.learn =
%          false with RE and BR spelled out = the two-type run; two PLM types (AR(1),
%          AR(2)) with RE under the projection facility
%   A1-A4  Anufriev-Hommes four heuristics (variant 17; tests/models/ah, the LAA
%          anchor on the test gain rule ah_sample_mean = the sample mean): the
%          engine's forecast stage equals an independent loop of the AH equations
%          (prices and shares, 1e-10) from three initial price and share settings
%          that give monotone convergence, damped and persistent oscillation;
%          four identical rules keep shares at 0.25 (1e-15)
%
%   Runs are not saved (hetlearn.run 'save', false). Toy and AH results only in
%   memory. About 3 minutes; the first call generates the N-type model files.

if nargin < 1 || isempty(part)
    part = {'units', 'r3', 'hl', 'bma', 'shares', 'modes', 'ah'};
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
if any(strcmp(part, 'bma'))
    R = bma(R, here);
end
if any(strcmp(part, 'shares'))
    R = shares_engine(R, here);
end
if any(strcmp(part, 'modes'))
    R = modes(R, here);
end
if any(strcmp(part, 'ah'))
    R = ah(R, here);
end
end


% =========================================================================================
function R = units(R)
nm = 'nt U1: discrete_choice_n with two types, no inertia, no costs, normalized = discrete_choice (3 groups)';
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

nm = 'nt U2: inertia, costs and the fitness normalisation follow DESIGN_br_extensions 1.2 (hand formulas)';
try
    rs = RandStream('mt19937ar', 'Seed', 2);
    chi = 0.7; om = 0.6; dl = 0.9; C = [0 0.3 0.1 0.5];
    FE = rand(rs, 1, 4); U = -rand(rs, 1, 4); np = [0.1 0.2 0.3 0.4];
    [n, Un] = hetlearn.switching.discrete_choice_n(FE, U, chi, om, 'inertia', dl, 'nprev', np, 'costs', C);
    Uh = om * U - (1 - om) * FE;
    e = exp(chi * (Uh - C));
    nh = dl * np + (1 - dl) * e / sum(e);
    d1 = max(abs([n - nh, Un - Uh]));
    [n, Un] = hetlearn.switching.discrete_choice_n(FE, U, chi, om, 'fitness', 'unnormalized');
    Uh = om * U - FE;
    e = exp(chi * Uh);
    d2 = max(abs([n - e / sum(e), Un - Uh]));
    % unnormalized at beta = normalized at beta/(1 - omega), from zero fitness, 30 periods
    beta = 0.4;
    Ua = zeros(1, 3); Ub = zeros(1, 3); d3 = 0;
    for t = 1:30
        fe = rand(rs, 1, 3) * 4;
        [na, Ua] = hetlearn.switching.discrete_choice_n(fe, Ua, beta, 0.7, 'fitness', 'unnormalized');
        [nb, Ub] = hetlearn.switching.discrete_choice_n(fe, Ub, beta / (1 - 0.7), 0.7);
        d3 = max([d3, abs(na - nb)]);
    end
    % equal fitness: shares proportional to exp(-chi*C); a common cost does nothing
    n4 = hetlearn.switching.discrete_choice_n(zeros(1, 3), zeros(1, 3), 2, 0.5, 'costs', [0 0.2 0.5]);
    n5 = hetlearn.switching.discrete_choice_n(FE(1:3), U(1:3), 2, 0.5, 'costs', [1 1 1]);
    n6 = hetlearn.switching.discrete_choice_n(FE(1:3), U(1:3), 2, 0.5);
    e4 = exp(-2 * [0 0.2 0.5]);
    d4 = max(abs([n4 - e4 / sum(e4), n5 - n6]));
    ok = d1 <= 1e-15 && d2 <= 1e-15 && d3 <= 1e-12 && d4 <= 1e-15;
    R = add(R, nm, ok, sprintf(['inertia+costs %.2g, unnormalized %.2g, beta vs beta/(1-omega) over 30 periods ' ...
        '%.2g, cost logit %.2g'], d1, d2, d3, d4));
catch err
    R = add(R, nm, false, err.message);
end

nm = 'nt U3: discrete_choice_n edge cases (share 0 stays 0, memory 0, chi = 0, chi*U ~ 1e7, NaN error, memory 1)';
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
    U = zeros(1, 2); sse = zeros(1, 2);
    for t = 1:5
        fe = [t, 2];
        sse = sse + fe;
        [n, U] = hetlearn.switching.discrete_choice_n(fe, U, 0.3, 1, 'fitness', 'unnormalized');
    end
    w = exp(-0.3 * sse);
    f = max(abs([U + sse, n - w / sum(w)])) < 1e-14;
    R = add(R, nm, a && b && c && dd && e && f, sprintf('%d %d %d %d %d %d', a, b, c, dd, e, f));
catch err
    R = add(R, nm, false, err.message);
end

nm = 'nt U4: init_fitness_n returns the initial shares through the logit, costs included';
try
    n0 = [0.25 0.25 0.25 0.25; 0.1 0.2 0.3 0.4; 0 0.5 0.25 0.25];
    C = [0 0.1 0.4 0.2];
    U0 = hetlearn.switching.init_fitness_n(n0, [0.4; 2; 1.3], C);
    chi = [0.4; 2; 1.3];
    d = 0;
    for g = 1:3
        a = chi(g) * (U0(g, :) - C);
        e = exp(a - max(a));
        d = max([d, abs(e / sum(e) - n0(g, :))]);
    end
    R = add(R, nm, d < 1e-15, sprintf('max diff %.2g', d));
catch err
    R = add(R, nm, false, err.message);
end

nm = 'nt U5: rule_terms: text, terms and timing of the AH rules, dn, constants; malformed rules rejected';
try
    tv = {'pinf', 'y', 'r'};
    a = hetlearn.plm.rule_terms('0.65*x{-1} + 0.35*self{-1}', 'pinf', 'ADA', 'lagged', tv);
    b = hetlearn.plm.rule_terms('0.5*(mean + x{-1}) + (x{-1} - x{-2})', 'pinf', 'LAA', 'lagged', tv);
    c = hetlearn.plm.rule_terms(struct('expr', 'c1*dn{-1} + c2*r{-1}', 'params', struct('c1', 0.5, 'c2', 2)), ...
        'pinf', 'FN', 'lagged', tv);
    ok = strcmp(a.text, '0.65*pinf{-1} + 0.35*pinf_exp1_ADA{-1}') && a.self_maxlag == 1 && a.maxlag == 1 ...
        && strcmp(b.text, '0.5*(alpha_pinf__LAA + pinf{-1}) + (pinf{-1} - pinf{-2})') && b.uses_mean ...
        && b.maxlag == 2 && strcmp(c.text, 'c1__FN*(y{-1} - y{-2} + pinf{-1}) + c2__FN*r{-1}') ...
        && c.maxlag == 2;
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
    ok = ok && isfinite(f(v));
    bad = {'x', 'lagged'; 'self + x{-1}', 'lagged'; 'x{-1}*x{-2}', 'lagged'; 're1(y{+1} - y)', 'lagged'; ...
        'x{+1}', 'current'; 'q{-1}', 'lagged'; 'mean{-1}', 'lagged'};
    nbad = 0;
    for i = 1:size(bad, 1)
        try
            hetlearn.plm.rule_terms(bad{i, 1}, 'pinf', 'K', bad{i, 2}, tv);
        catch err
            nbad = nbad + strcmp(err.identifier, 'hetlearn:types:rule');
        end
    end
    cur = hetlearn.plm.rule_terms('0.5*x + 0.5*x{-1}', 'pinf', 'K', 'current', tv);
    ok = ok && nbad == size(bad, 1) && strcmp(cur.text, '0.5*pinf + 0.5*pinf{-1}');
    R = add(R, nm, ok, sprintf('%d of %d malformed rules rejected', nbad, size(bad, 1)));
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
function R = bma(R, here)
nm = ['nt B1: BMA (unnormalized fitness, memory 1, intensity model:bma; toy, pie): shares = prior x ' ...
    'exp(-chi*SSE) / sum from the recorded errors, chi = 1/(2 sigma^2) with sigma^2 from srf'];
try
    c = toy_cfg(here);
    c.expectations.variables = {'pie'};
    c.switching = struct('fitness', 'unnormalized', 'memory', 1, 'intensity', 'model:bma');
    res = hetlearn.run(c, 'save', false, 'quiet', true);
    mv = res.meta.model_values.bma;
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec(o.model);
    m = hetlearn.load_model(spec, o);
    s = srf(m, 1:1);
    s2 = sum(s.pie(1, :).^2);                       % h = 1 (re_info 'current'), shocks at one sd
    dchi = abs(mv.chi - 1 / (2 * s2)) / mv.chi;
    L = res.learning.pie;
    r = res.dates.record;
    fe = [L.FE_RE(r), L.FE_BR(r)];
    fe(1, :) = 0;                                   % first period: no errors
    sse = cumsum(fe, 1);
    w = 0.5 * exp(-mv.chi * sse);
    nh = w ./ sum(w, 2);
    dn = max(max(abs(nh - [L.n_RE(r), L.n_BR(r)])));
    ok = mv.horizon == 1 && dchi < 1e-12 && dn < 1e-12;
    R = add(R, nm, ok, sprintf('sigma^2 %.6g (srf %.6g), chi %.6g; max share diff %.3g over %d quarters; final n_RE %.3g', ...
        mv.sigma2.pie, s2, mv.chi, dn, numel(r), L.n_RE(r(end))));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'nt B2: model:bma on the SW07 RE(t-1) benchmark: sigma^2 = the two-step forecast-error variance of pinf (srf)';
try
    c = tsw07_a1_learn();
    c.switching = struct('fitness', 'unnormalized', 'memory', 1, 'intensity', 'model:bma');
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec('sw07');
    [m, info] = hetlearn.load_model(spec, o);
    mv = info.nt.model_values.bma;
    s = srf(m, 1:2);
    s2 = sum(s.pinf(1, :).^2) + sum(s.pinf(2, :).^2);
    d = abs(mv.sigma2.pinf - s2) / s2;
    R = add(R, nm, mv.horizon == 2 && d < 1e-12, sprintf('sigma^2 %.8g, srf %.8g, chi %.6g', mv.sigma2.pinf, s2, ...
        1 / (2 * mv.sigma2.pinf)));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = shares_engine(R, here)
nm = ['nt S1: engine shares with inertia 0.6, a cost on BR (0.02) and unnormalized fitness (memory 0.5, chi 0.8) ' ...
    '= the hand recursion from the recorded errors (toy)'];
try
    c = toy_cfg(here);
    c.expectations.variables = {'pie'};
    c.switching = struct('intensity', 0.8, 'memory', 0.5, 'inertia', 0.6, 'fitness', 'unnormalized', ...
        'costs', struct('BR', 0.02));
    res = hetlearn.run(c, 'save', false, 'quiet', true);
    L = res.learning.pie;
    r = res.dates.record;
    C = [0 0.02];
    n = [0.5 0.5];
    U = hetlearn.switching.init_fitness_n(n, 0.8, C);
    d = max(abs([n - [L.n_RE(r(1)), L.n_BR(r(1))], U - [L.U_RE(r(1)), L.U_BR(r(1))]]));
    for t = 2:numel(r)
        fe = [L.FE_RE(r(t)), L.FE_BR(r(t))];
        U = 0.5 * U - fe;
        a = 0.8 * (U - C);
        e = exp(a - max(a));
        n = 0.6 * n + 0.4 * e / sum(e);
        d = max([d, abs(n - [L.n_RE(r(t)), L.n_BR(r(t))]), abs(U - [L.U_RE(r(t)), L.U_BR(r(t))])]);
    end
    hz = res.dates.horizon;
    m1 = max(abs(L.n_model_RE(hz(2:end)) - L.n_RE(hz(1:end-1))));     % model shares of t = shares at the end of t-1
    R = add(R, nm, d < 1e-12 && m1 < 1e-15, sprintf('max diff %.3g over %d quarters; model shares lag %.3g', d, numel(r), m1));
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
    b.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'ADA', 'kind', 'rule', 'rule', ...
        '0.65*x{-1} + 0.35*self{-1}')};
    rb = hetlearn.run(b, 'save', false, 'quiet', true);
    Lb = rb.learning.pie;
    db = max(abs([Lb.n_model_ADA(hz) - 1; Lb.n_model_RE(hz); rb.paths.pie_exp1(hz) - rb.paths.pie_exp1_ADA(hz)]));
    % ADA's own recursion in the simulated paths: f_t = 0.65 pie_{t-1} + 0.35 f_{t-1}
    f = rb.paths.pie_exp1_ADA;
    p = rb.paths.pie;
    db = max([db; abs(f(hz) - (0.65 * p(hz - 1) + 0.35 * f(hz - 1)))]);
    % (c) rational with RE not listed: the RE run (common variables)
    r = c;
    r.expectations.mode = 'rational';
    rr = fresh_run(r);
    q = r;
    q.expectations.types = {T('name', 'ADA', 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*self{-1}'), ...
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

nm = ['nt M2: history.learn = false with RE and BR spelled out = the two-type run; two PLM types (AR(1) and ' ...
    'AR(2) learners) switch with RE under the projection facility (toy)'];
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
    q = c;
    q.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm'), ...
        T('name', 'B2', 'kind', 'plm', 'plm', 'ar2')};
    rq = hetlearn.run(q, 'save', false, 'quiet', true);
    L = rq.learning.pie;
    r = rq.dates.record;
    s = L.n_RE(r) + L.n_BR(r) + L.n_B2(r);
    d2 = max(abs(s - 1));
    k2 = rq.learning.pie__B2;
    np = numel(k2.params);
    mv = max(abs(diff(L.n_B2(r))));
    ok = d1 <= 1e-12 && d2 < 1e-14 && np == 3 && mv > 0 && strcmp(rq.cfg.projection.facility, 'plm_alm');
    R = add(R, nm, ok, sprintf(['learn = false: %s; three types: shares sum to 1 within %.2g, the AR(2) type has ' ...
        '%d belief parameters (%s), its share moves (max change %.3g)'], msg, d2, np, strjoin(k2.params, ', '), mv));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = ah(R, here)
ahDir = fullfile(here, 'models', 'ah');
addpath(ahDir);                                    % the test gain rule hetlearn.gain.ah_sample_mean
cAH = onCleanup(@() rmpath(ahDir));
T = @(varargin) struct(varargin{:});
rules = {T('name', 'ADA', 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*self{-1}'), ...
    T('name', 'WTR', 'kind', 'rule', 'rule', 'x{-1} + 0.4*(x{-1} - x{-2})'), ...
    T('name', 'STR', 'kind', 'rule', 'rule', 'x{-1} + 1.3*(x{-1} - x{-2})'), ...
    T('name', 'LAA', 'kind', 'rule', 'rule', '0.5*(mean + x{-1}) + (x{-1} - x{-2})', ...
    'gain', struct('rule', 'ah_sample_mean'))};
cases = {'monotone convergence', [0.25 0.25 0.25 0.25], [-5 0 -10], 1
    'damped oscillation', [0.05 0.05 0.05 0.85], [-5 -10 -5], 2
    'persistent oscillation', [0.1 0.1 0.7 0.1], [-10 -5 0], 3};
names = {'ADA', 'WTR', 'STR', 'LAA'};
for i = 1:size(cases, 1)
    nm = sprintf(['nt A%d: Anufriev-Hommes four heuristics (beta 0.4, eta 0.7, delta 0.9), initial prices %s, ' ...
        'shares %s: engine = hand loop of the AH equations (1e-10), %s'], i, mat2str(60 + cases{i, 3}), ...
        mat2str(cases{i, 2}), cases{i, 1});
    try
        res = ah_run(ahDir, rules, cases{i, 2}, cases{i, 3}, sprintf('nt_ah%d', i));
        hz = res.dates.horizon;
        [ph, nh] = ah_loop(cases{i, 3}, cases{i, 2}, numel(hz));
        pe = res.paths.p(hz);
        L = res.learning.p;
        ne = zeros(numel(hz), 4);
        for k = 1:4
            ne(:, k) = L.(['n_' names{k}])(hz);
        end
        dp = max(abs(pe - ph));
        dn = max(abs(ne(:) - nh(:)));
        cls = ah_classify(pe);
        ok = dp < 1e-10 && dn < 1e-10 && cls == cases{i, 4};
        R = add(R, nm, ok, sprintf(['price diff %.3g, share diff %.3g; pattern %d (expected %d); prices 2001Q1-2003Q4 ' ...
            '%s; final shares %s'], dp, dn, cls, cases{i, 4}, mat2str(round(60 + pe(2:12)', 1)), mat2str(round(ne(end, :), 3))));
    catch err
        R = add(R, nm, false, where(err));
    end
end

nm = 'nt A4: four identical rules keep shares at 0.25 (inertia 0.9, unnormalized fitness; AH economy; 1e-15)';
try
    same = cellfun(@(k) T('name', k, 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*self{-1}'), ...
        {'A1', 'A2', 'A3', 'A4'}, 'UniformOutput', false);
    res = ah_run(ahDir, same, [0.25 0.25 0.25 0.25], [-10 -5 0], 'nt_ah4');
    L = res.learning.p;
    r = res.dates.record;
    d = 0;
    for k = 1:4
        d = max([d; abs(L.(sprintf('n_A%d', k))(r) - 0.25)]);
    end
    R = add(R, nm, d <= 1e-15, sprintf('max |n - 0.25| %.3g over %d quarters', d, numel(r)));
catch err
    R = add(R, nm, false, where(err));
end
clear cAH
end


function res = ah_run(ahDir, types, n0, p0, id)
% one AH run: data p_obs = 60 + p0 over 2000Q1-Q3, origin 2000Q3, 50 quarters, zero shocks
dates = qq(2000, 1):qq(2000, 3);
if exist(fullfile(ahDir, 'data'), 'dir') ~= 7
    mkdir(fullfile(ahDir, 'data'));
end
databank.toCSV(struct('p_obs', Series(dates, 60 + p0(:))), fullfile(ahDir, 'data', 'ah_database.csv'), dates, ...
    'Format', '%.17g');
c = struct();
c.id = id;
c.model = ahDir;
c.forecast = struct('origin', qq(2000, 3), 'horizon', 50);
c.expectations = struct('mode', 'switching', 'variables', {{'p'}}, 'types', {types});
c.beliefs.init.date = qq(2000, 3);
c.switching = struct('intensity', 0.4, 'memory', 0.7, 'inertia', 0.9, 'fitness', 'unnormalized');
nm = cellfun(@(t) t.name, types, 'UniformOutput', false);
c.shares.init = cell2struct(num2cell(n0(:)), nm(:), 1);
c.projection.facility = 'none';
res = hetlearn.run(c, 'save', false, 'quiet', true);
end


function [p, N] = ah_loop(p0, n0, H)
% Anufriev and Hommes (2012) eqs. (KER 4-10) in deviations from p^f = 60, from three initial prices and
% the engine's conventions for the first learning period (2000Q3): ADA's previous forecast 0.65*p1 (the
% filter recursion from 0), the LAA anchor 0 there and then the sample mean from p3 on, shares n0 in
% force in the first simulated quarter. Returns the H simulated prices and the shares at the end of each.
r = 0.05; beta = 0.4; eta = 0.7; delta = 0.9;
x = [p0(:); zeros(H, 1)];
F = [0.65 * x(2) + 0.35 * 0.65 * x(1), x(2) + 0.4 * (x(2) - x(1)), x(2) + 1.3 * (x(2) - x(1)), ...
    0.5 * (0 + x(2)) + (x(2) - x(1))];
mu = x(3);
cnt = 1;
n = n0;
U = log(n0) / beta;
U = U - U(1);
N = zeros(H, 4);
for t = 4:3 + H
    Fn = [0.65 * x(t-1) + 0.35 * F(1), x(t-1) + 0.4 * (x(t-1) - x(t-2)), x(t-1) + 1.3 * (x(t-1) - x(t-2)), ...
        0.5 * (mu + x(t-1)) + (x(t-1) - x(t-2))];
    x(t) = (n * Fn') / (1 + r);
    U = eta * U - (x(t) - F).^2;
    a = beta * U;
    e = exp(a - max(a));
    n = delta * n + (1 - delta) * e / sum(e);
    N(t - 3, :) = n;
    F = Fn;
    cnt = cnt + 1;
    mu = mu + (x(t) - mu) / cnt;
end
p = x(4:end);
end


function c = ah_classify(p)
% 1 monotone convergence, 2 damped oscillation, 3 persistent oscillation, 4 other (deviations from p^f)
s = sign(p);
s(s == 0) = 1;
ch = sum(abs(diff(s(5:end))) > 0);
early = max(abs(p(5:15)));
late = max(abs(p(end-9:end)));
if ch == 0 && late < 0.5 * early && late < 1
    c = 1;
elseif ch >= 3 && late < 0.2 * early
    c = 2;
elseif ch >= 6 && late >= 0.5 * early && late > 0.5
    c = 3;
else
    c = 4;
end
end


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
