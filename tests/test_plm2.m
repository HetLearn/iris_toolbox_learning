function R = test_plm2(parts)
%TEST_PLM2  More PLMs (DESIGN 12): VAR learning, derived regressors, AR(2) on SW07.
%
%   R = test_plm2()         all parts
%   R = test_plm2(parts)    subset of {'toy', 'sw07_ar2', 'sw07_derived', 'sw07_var3'}
%   Returns a struct array of checks (name, pass, msg).
%
%   Toy (tests/toy_nk):
%   P1 build_system: VAR(1) over the learning set ('var1' = explicit .var),
%      beta_x__u_l1 names, 13 coefficients per equation in a 12-member VAR(1);
%      VAR(2) without constant, lag-first order, non-learning member auxiliary
%   P2 errors: by_var for a VAR member, 'var1' together with .var.variables,
%      unknown member, derived name collision / lead / unknown name, option
%      validation (unknown field, lags, default, derived type)
%   P3 forecast_value = IRIS x_exp1_BR: VAR(1) over all toy forward variables
%      (y, pie, r); pie on {pie{-1}, gap{-1}} with derived gap = y - 0.5*g;
%      VAR(1) over {pie, gap}; the derived variable equals its expression
%   P4 re_moments for the VAR {pie, gap}: E[zz'] and phi0 = acf cross-moments
%      including the derived member
%   P5 re_filter: derived variable in the smoothed history (= its
%      expression), separate cache key
%   P6 toy switching run with the VAR {pie, gap}: completes, shares in [0,1]
%   SW07 smoke runs from the 2022Q2 peak, zero shocks, switching on pinf
%   (tests/output/results/; sw07_smoke_run): AR(2); pinf on {pinf{-1},
%   ygap{-1}, r{-1}} with derived.ygap = 'y - yf'; VAR(1) over {pinf, ygap, r}

if nargin < 1 || isempty(parts)
    parts = {'toy', 'sw07_ar2', 'sw07_derived', 'sw07_var3'};
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
if any(strcmp(parts, 'sw07_ar2'))
    cfg = tsw07_switch_pinf();
    cfg.id = 'sw07_test_ar2_pinf';
    cfg.beliefs.plm.default = 'ar2';
    cfg.compare_with = {};
    R = [R, sw07_smoke_run(cfg, 'AR(2), pinf', outDir)];
end
if any(strcmp(parts, 'sw07_derived'))
    cfg = tsw07_switch_pinf();
    cfg.id = 'sw07_test_pinf_ygap_r';
    cfg.beliefs.plm.derived.ygap = 'y - yf';
    cfg.beliefs.plm.by_var.pinf = struct('regressors', {{'pinf{-1}', 'ygap{-1}', 'r{-1}'}}, 'constant', true);
    cfg.compare_with = {};
    R = [R, sw07_smoke_run(cfg, 'pinf on pinf, ygap, r (derived ygap)', outDir)];
end
if any(strcmp(parts, 'sw07_var3'))
    cfg = tsw07_switch_pinf();
    cfg.id = 'sw07_test_var_pinf_ygap_r';
    cfg.beliefs.plm.derived.ygap = 'y - yf';
    cfg.beliefs.plm.var = struct('variables', {{'pinf', 'ygap', 'r'}}, 'lags', 1, 'constant', true);
    cfg.compare_with = {};
    R = [R, sw07_smoke_run(cfg, 'VAR(1) {pinf, ygap, r}, pinf', outDir)];
end
end


% =========================================================================
function R = toy_part(here, outDir)
R = struct('name', {}, 'pass', {}, 'msg', {});
rng(5);
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
spec = hetlearn.load_spec(toyDir);
P = feval_in(toyDir, spec.params);
allv = {'y', 'pie', 'r', 'g', 'u', 'dy_e', 'r_e'};
v3 = {'y', 'pie', 'r'};
plmVar3 = struct('var', struct('variables', {v3}, 'lags', 1, 'constant', true));
plmGap = struct('derived', struct('gap', 'y - 0.5*g'), 'by_var', struct('pie', ...
    struct('regressors', {{'pie{-1}', 'gap{-1}'}}, 'constant', true)));
plmVG = struct('derived', struct('gap', 'y - 0.5*g'), 'var', ...
    struct('variables', {{'pie', 'gap'}}, 'lags', 1, 'constant', true));

% ---- P1 --------------------------------------------------------------------------------
nm = 'plm2 P1: VAR(1) over the learning set: ''var1'' = explicit .var, beta_x__u_l1 names, closed system';
try
    sA = hetlearn.plm.build_system(struct('default', 'var1'), v3, allv);
    sB = hetlearn.plm.build_system(plmVar3, v3, allv);
    ok = isequal(sA.eq, sB.eq) && numel(sA.eq) == 3 && ~any([sA.eq.isAux]) && sA.maxlag == 1 ...
        && isequal(sA.eq(2).param_names, {'alpha_pie', 'beta_pie__y_l1', 'beta_pie__pie_l1', 'beta_pie__r_l1'}) ...
        && isequal(sA.var.variables, v3);
    R = add(R, nm, ok, strjoin(sA.eq(2).param_names, ', '));
    names12 = arrayfun(@(k) sprintf('v%d', k), 1:12, 'UniformOutput', false);
    s12 = hetlearn.plm.build_system('var1', names12, names12);
    txt = hetlearn.plm.forecast_expr(s12, 'v1');
    nterm = numel(strfind(txt, '*'));
    ok = numel(s12.eq) == 12 && all(arrayfun(@(e) numel(e.param_names), s12.eq) == 13) && nterm == 12 + 12 * 12;
    R = add(R, 'plm2 P1: 12-member VAR(1): 13 coefficients per equation, nested forecast with 156 products', ...
        ok, sprintf('%d equations, %d products, %d characters', numel(s12.eq), nterm, numel(txt)));
    s2 = hetlearn.plm.build_system(struct('var', struct('variables', {{'pie', 'g'}}, 'lags', 2, ...
        'constant', false)), {'pie'}, allv);
    ok = numel(s2.eq) == 2 && s2.eq(2).isAux && strcmp(s2.eq(2).target, 'g') ...
        && isequal(s2.eq(1).reg_names, {'pie', 'g', 'pie', 'g'}) && isequal(s2.eq(1).reg_lags, [1 1 2 2]) ...
        && isequal(s2.eq(1).param_names, {'beta_pie__pie_l1', 'beta_pie__g_l1', 'beta_pie__pie_l2', 'beta_pie__g_l2'}) ...
        && s2.maxlag == 2;
    [F, rho] = hetlearn.plm.companion(s2, struct('pie', [0.5; 0.1; 0.2; 0], 'g', [0; 0.8; 0; 0]));
    ok = ok && size(F, 1) == 5 && abs(rho - max(abs(eig(F(2:end, 2:end))))) < 1e-14;
    R = add(R, 'plm2 P1: VAR(2) without constant: lag-first regressors, non-learning member auxiliary, companion', ...
        ok, sprintf('rho %.4f', rho));
catch err
    R = add(R, nm, false, err.message);
end

% ---- P2 --------------------------------------------------------------------------------
R = expect_error(R, 'plm2 P2: by_var entry for a VAR member is an error', @() hetlearn.plm.build_system( ...
    struct('var', struct('variables', {{'pie', 'y'}}), 'by_var', struct('y', 'ar2')), {'pie'}, allv), 'VAR member');
R = expect_error(R, 'plm2 P2: default ''var1'' together with var.variables is an error', ...
    @() hetlearn.plm.build_system(struct('default', 'var1', 'var', struct('variables', {{'pie'}})), {'pie'}, allv), ...
    'both set');
R = expect_error(R, 'plm2 P2: VAR member that is not a model variable is an error', ...
    @() hetlearn.plm.build_system(struct('var', struct('variables', {{'pie', 'w'}})), {'pie'}, allv), 'w');
R = expect_error(R, 'plm2 P2: derived name that collides with a model name is an error', ...
    @() hetlearn.extend_model(spec, struct('derived', struct('g', 'y - r')), 'validate', false), 'already used');
R = expect_error(R, 'plm2 P2: derived expression with a lead is an error', ...
    @() hetlearn.extend_model(spec, struct('derived', struct('gap', 'y{+1} - g')), 'validate', false), 'no time subscripts');
R = expect_error(R, 'plm2 P2: derived expression with an unknown name is an error', ...
    @() hetlearn.extend_model(spec, struct('derived', struct('gap', 'yy - g')), 'validate', false), 'yy');
R = expect_error(R, 'plm2 P2: unknown field beliefs.plm.var.lagz is an error', @() hetlearn.load_options( ...
    struct('beliefs', struct('plm', struct('var', struct('lagz', 2))))), 'beliefs.plm.var.lagz');
R = expect_error(R, 'plm2 P2: beliefs.plm.var.lags = 0 is an error', @() hetlearn.load_options( ...
    struct('beliefs', struct('plm', struct('var', struct('variables', 'learning', 'lags', 0))))), 'positive integer');
R = expect_error(R, 'plm2 P2: beliefs.plm.default = ''var2'' is an error', @() hetlearn.load_options( ...
    struct('beliefs', struct('plm', struct('default', 'var2')))), 'var1');
R = expect_error(R, 'plm2 P2: beliefs.plm.derived.gap = 3 is an error', @() hetlearn.load_options( ...
    struct('beliefs', struct('plm', struct('derived', struct('gap', 3))))), 'derived.gap');
R = expect_error(R, 'plm2 P2: options default ''var1'' with var.variables is an error', @() hetlearn.load_options( ...
    struct('beliefs', struct('plm', struct('default', 'var1', 'var', struct('variables', {{'pie'}}))))), 'both set');

% ---- P3 --------------------------------------------------------------------------------
cases = {plmVar3, 'VAR(1) over y, pie, r (all toy forward variables)'; ...
    plmGap, 'pie on pie{-1}, gap{-1}, derived gap = y - 0.5*g'; ...
    plmVG, 'VAR(1) over pie and derived gap'};
for k = 1:size(cases, 1)
    nm = ['plm2 P3: forecast_value = IRIS x_exp1_BR, ' cases{k, 2}];
    try
        meta = hetlearn.extend_model(spec, cases{k, 1});
        [d, n1, dg] = iris_check(meta, P);
        R = add(R, nm, d < 1e-10 && dg < 1e-12 && all(meta.collapse_maxdiff < 1e-10), sprintf( ...
            'max diff %.1e (n1 = %g); derived identity %.1e; collapse %s; tag %s', d, n1, dg, ...
            mat2str(meta.collapse_maxdiff, 2), meta.plmtag));
    catch err
        R = add(R, nm, false, err.message);
    end
end

% ---- P4 --------------------------------------------------------------------------------
nm = 'plm2 P4: re_moments for the VAR {pie, gap}: E[zz''] and phi0 from acf cross-moments incl. the derived member';
try
    o = hetlearn.load_options(struct('model', toyDir, 'expectations', struct('variables', {{'pie'}}), ...
        'beliefs', struct('plm', plmVG)), struct());
    [m, info] = hetlearn.load_model(spec, o);
    [phi0, R0] = hetlearn.init.re_moments(m, info.sys);
    C = acf(m, 'order', 1);
    nmz = cellstr(C.RowNames);
    Cd = double(C);
    ip = find(strcmp(nmz, 'pie'));
    ig = find(strcmp(nmz, 'gap'));
    S = [1 0 0; 0 Cd(ip, ip, 1) Cd(ip, ig, 1); 0 Cd(ig, ip, 1) Cd(ig, ig, 1)];
    s = [0; Cd(ip, ip, 2); Cd(ip, ig, 2)];
    sg = [0; Cd(ig, ip, 2); Cd(ig, ig, 2)];
    dd = max(abs([phi0.pie - S \ s; phi0.gap - S \ sg; R0.pie(:) - S(:); R0.gap(:) - S(:)]));
    R = add(R, nm, dd < 1e-12 && isequal(info.sys.targets, {'pie', 'gap'}), sprintf('max diff %.1e; phi0.pie %s', ...
        dd, mat2str(phi0.pie', 3)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- P5 --------------------------------------------------------------------------------
nm = 'plm2 P5: re_filter: derived variable in the smoothed history (= its expression), own cache key';
try
    o0 = hetlearn.load_options(struct('model', toyDir, 'expectations', struct('variables', {{'pie'}})), struct());
    H0 = hetlearn.re_filter(spec, o0);
    H = hetlearn.re_filter(spec, o);
    fr = H.range;
    dg = max(abs(H.smooth.gap(fr) - (H.smooth.y(fr) - 0.5 * H.smooth.g(fr))));
    dy = max(abs(H.smooth.y(fr) - H0.smooth.y(fr)));
    R = add(R, nm, dg < 1e-10 && dy < 1e-9 && ~strcmp(H.hash, H0.hash), sprintf( ...
        'gap identity %.1e; y vs base filter %.1e; hashes %s / %s', dg, dy, H.hash(1:8), H0.hash(1:8)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- P6 --------------------------------------------------------------------------------
nm = 'plm2 P6: toy switching run with the VAR {pie, gap} (derived member) completes, shares in [0,1]';
try
    cfg = struct('id', 'toy_plm2_var_gap', 'model', toyDir);
    cfg.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
    cfg.expectations = struct('mode', 'switching', 'variables', {{'pie'}});
    cfg.switching.intensity = 0.25;
    cfg.beliefs.plm = plmVG;
    res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true, 'save', false);
    n2 = res.learning.pie.n2(res.dates.record);
    ok = all(n2 >= 0 & n2 <= 1) && isfield(res.learning, 'gap') && isfield(res.learning.pie, 'beta_pie__gap_l1');
    R = add(R, nm, ok, sprintf('n2 range [%.3g, %.3g]; %d events', min(n2), max(n2), height(res.events)));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function [d, n1, dg] = iris_check(meta, P)
% One-period IRIS simulation from random lags with random beliefs; compare
% every x_exp1_BR with hetlearn.plm.forecast_value; check derived identities.
a = struct();
for i = 1:numel(meta.toggles)
    a.(meta.toggles{i}) = true;
end
a.(meta.anchor_toggle) = false;
m = Model.fromFile(meta.ext_file, 'linear', true, 'assign', a);
m = put_params(m, P);
phi = rand_phi(meta.sys);
Pv = hetlearn.plm.param_values(meta.sys, phi);
f = fieldnames(Pv);
for i = 1:numel(f)
    m.(f{i}) = Pv.(f{i});
end
ok = false;
for n1 = [0.5, 0, 1]
    for i = 1:numel(meta.forward_vars)
        x = meta.forward_vars{i};
        m.(['n1_' x]) = n1;
        m.(['n2_' x]) = 1 - n1;
    end
    ws = warning('off', 'all');
    [m, flag] = solve(m);
    warning(ws);
    if hasSucceeded(flag)
        ok = true;
        break
    end
end
if ~ok
    error('test_plm2:solve', 'Extended model does not solve for n1 in {0.5, 0, 1}.');
end
t0 = qq(2001, 1);
db = zerodb(m, t0-6:t0);
xl = get(m, 'xList');
for i = 1:numel(xl)
    db.(xl{i})(t0-6:t0-1) = randn(6, 1);
end
s = simulate(m, db, t0:t0, 'prependInput', true);
getLag = @(n, k) db.(n)(t0 + k);
d = 0;
for i = 1:numel(meta.forward_vars)
    x = meta.forward_vars{i};
    d = max(d, abs(s.([x '_exp1_BR'])(t0) - hetlearn.plm.forecast_value(meta.sys, phi, getLag, x)));
end
dg = 0;
dn = fieldnames(meta.derived);
for i = 1:numel(dn)
    ex = regexprep(meta.derived.(dn{i}), '([A-Za-z]\w*)', 's.$1(t0)');
    dg = max(dg, abs(s.(dn{i})(t0) - eval(ex)));
end
end


function phi = rand_phi(S)
phi = struct();
for i = 1:numel(S.eq)
    e = S.eq(i);
    nb = numel(e.reg_names);
    b = (0.2 + 0.5 * rand(nb, 1)) / max(nb, 1);
    if e.constant
        phi.(e.target) = [0.1 * randn; b];
    else
        phi.(e.target) = b;
    end
end
end


function m = put_params(m, P)
names = fieldnames(get(m, 'parameters'));
f = fieldnames(P);
for i = 1:numel(f)
    if any(strcmp(names, f{i}))
        m.(f{i}) = P.(f{i});
    end
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
