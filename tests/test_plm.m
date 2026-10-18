function R = test_plm()
%TEST_PLM  PLM system, BR forecast (text vs numeric vs IRIS), companion, initial beliefs.
%
%   R = test_plm()   returns a struct array of checks (name, pass, msg).

R = struct('name', {}, 'pass', {}, 'msg', {});
rng(7);
here = fileparts(mfilename('fullpath'));
toyDir = fullfile(here, 'toy_nk');
spec = load_spec(toyDir);
P = feval_in(toyDir, spec.params);
allv = {'y', 'pie', 'r', 'g', 'u', 'dy_e', 'r_e'};

% ---- build_system ----------------------------------------------------------------
try
    s1 = hetlearn.plm.build_system('ar1', {'pie'}, allv);
    s2 = hetlearn.plm.build_system(struct('default', 'ar2'), {'pie'}, allv);
    s3 = hetlearn.plm.build_system('ar1_noconst', {'pie'}, allv);
    ok = isequal(s1.eq(1).param_names, {'alpha_pie', 'beta_pie'}) && s1.maxlag == 1 ...
        && isequal(s2.eq(1).param_names, {'alpha_pie', 'beta_pie__pie_l1', 'beta_pie__pie_l2'}) && s2.maxlag == 2 ...
        && isequal(s3.eq(1).param_names, {'beta_pie__pie_l1'}) && ~s3.eq(1).constant;
    R = add(R, 'plm: shorthands ar1, ar2, ar1_noconst and parameter names', ok, '');
catch err
    R = add(R, 'plm: shorthands ar1, ar2, ar1_noconst and parameter names', false, err.message);
end

plmV = struct('default', 'ar1', 'by_var', struct('pie', ...
    struct('regressors', {{'pie{-1}', 'y{-1}'}}, 'constant', true)));
try
    sV = hetlearn.plm.build_system(plmV, {'pie'}, allv);
    ok = numel(sV.eq) == 2 && isequal(sV.targets, {'pie', 'y'}) && ~sV.eq(1).isAux && sV.eq(2).isAux ...
        && isequal(sV.eq(1).param_names, {'alpha_pie', 'beta_pie__pie_l1', 'beta_pie__y_l1'}) ...
        && isequal(sV.eq(2).param_names, {'alpha_y', 'beta_y'});
    R = add(R, 'plm: VAR-style PLM (pie on pie{-1}, y{-1}) adds auxiliary AR(1) for y', ok, strjoin(sV.targets, ', '));
catch err
    R = add(R, 'plm: VAR-style PLM (pie on pie{-1}, y{-1}) adds auxiliary AR(1) for y', false, err.message);
end

R = expect_error(R, 'plm: regressor with a lead is rejected', @() hetlearn.plm.build_system( ...
    struct('by_var', struct('pie', struct('regressors', {{'pie{+1}'}}))), {'pie'}, allv), 'pie{+1}');
R = expect_error(R, 'plm: regressor on an unknown variable is rejected', @() hetlearn.plm.build_system( ...
    struct('by_var', struct('pie', struct('regressors', {{'w{-1}'}}))), {'pie'}, allv), 'w');

% ---- forecast_expr / forecast_value / text evaluation ---------------------------------
try
    txt = hetlearn.plm.forecast_expr(s1, 'pie');
    R = add(R, 'plm: forecast_expr(ar1) = alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1})', ...
        strcmp(txt, 'alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1})'), txt);
catch err
    R = add(R, 'plm: forecast_expr(ar1) = alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1})', false, err.message);
end

try
    plmRich = struct('default', 'ar1', 'by_var', struct( ...
        'pie', struct('regressors', {{'pie{-1}', 'y{-1}', 'u{-2}'}}, 'constant', true), ...
        'y', 'ar2'));
    sR = hetlearn.plm.build_system(plmRich, {'pie', 'r'}, allv);
    systems = {s1, s2, s3, sV, sR};
    worst = 0;
    for k = 1:numel(systems)
        S = systems{k};
        phi = rand_phi(S);
        Lg = struct();
        for v = allv
            Lg.(v{1}) = randn(10, 1);
        end
        getLag = @(n, j) Lg.(n)(-j);
        for x = S.learn
            fv = hetlearn.plm.forecast_value(S, phi, getLag, x{1});
            ft = eval_text(hetlearn.plm.forecast_expr(S, x{1}), hetlearn.plm.param_values(S, phi), getLag);
            worst = max(worst, abs(fv - ft));
        end
    end
    R = add(R, 'plm: forecast_value equals the text expression (5 PLM systems incl. aux, ar2, no constant)', ...
        worst < 1e-13, sprintf('max diff %.1e', worst));
catch err
    R = add(R, 'plm: forecast_value equals the text expression (5 PLM systems incl. aux, ar2, no constant)', false, err.message);
end

% ---- companion and param_values ------------------------------------------------
try
    [F1, r1] = hetlearn.plm.companion(s1, struct('pie', [0.3; 0.9]));
    [~, r2] = hetlearn.plm.companion(s2, struct('pie', [0; 0.5; 0.3]));
    [FV, rV] = hetlearn.plm.companion(sV, struct('pie', [0.1; 0.5; 0.2], 'y', [0.2; 0.6]));
    ok = isequal(F1, [1 0; 0.3 0.9]) && abs(r1 - 0.9) < 1e-14 ...
        && abs(r2 - (0.5 + sqrt(0.25 + 1.2)) / 2) < 1e-12 && abs(rV - 0.6) < 1e-14 ...
        && isequal(FV, [1 0 0; 0.1 0.5 0.2; 0.2 0 0.6]);
    R = add(R, 'plm: companion matrix and spectral radius (ar1, ar2, VAR)', ok, sprintf('%.4f %.4f %.4f', r1, r2, rV));
    Pv = hetlearn.plm.param_values(sV, struct('pie', [0.1; 0.5; 0.2], 'y', [0.2; 0.6]));
    ok = Pv.alpha_pie == 0.1 && Pv.beta_pie__pie_l1 == 0.5 && Pv.beta_pie__y_l1 == 0.2 ...
        && Pv.alpha_y == 0.2 && Pv.beta_y == 0.6;
    R = add(R, 'plm: param_values maps phi to IRIS parameter names', ok, '');
catch err
    R = add(R, 'plm: companion matrix and spectral radius (ar1, ar2, VAR)', false, err.message);
end

% ---- forecast_value against IRIS one-period simulation ------------------------------
plmU = struct('default', 'ar1', 'by_var', struct('pie', ...
    struct('regressors', {{'pie{-1}', 'u{-1}'}}, 'constant', true)));
plmCases = {'ar1', 'AR(1)'; struct('default', 'ar2'), 'AR(2)'; plmV, 'VAR pie on pie{-1}, y{-1}'; ...
    plmU, 'pie on pie{-1}, u{-1} (u auxiliary)'};
for k = 1:size(plmCases, 1)
    nm = ['plm: forecast_value = IRIS x_exp1_BR, ' plmCases{k, 2}];
    try
        meta = hetlearn.extend_model(spec, plmCases{k, 1});
        [d, n1used] = iris_check(meta, P);
        R = add(R, nm, d < 1e-10, sprintf('max diff %.1e (n1 = %g, plmtag %s, collapse %.1e)', ...
            d, n1used, meta.plmtag, max(meta.collapse_maxdiff)));
    catch err
        R = add(R, nm, false, err.message);
    end
end

% ---- initial beliefs ---------------------------------------------------------------
try
    meta = hetlearn.extend_model(spec, 'ar1');
    m0 = Model.fromFile(meta.ref_file, 'linear', true);
    m0 = put_params(m0, P);
    m0 = solve(m0);
    C = acf(m0, 'order', 1);
    nm = cellstr(C.RowNames);
    Cd = double(C);
    ip = find(strcmp(nm, 'pie'));
    iy = find(strcmp(nm, 'y'));
    [phi0, R0] = hetlearn.init.re_moments(m0, s1);
    b = Cd(ip, ip, 2) / Cd(ip, ip, 1);
    d1 = max(abs([phi0.pie - [0; b]; R0.pie(:) - [1; 0; 0; Cd(ip, ip, 1)]]));
    R = add(R, 'init: re_moments AR(1): alpha 0, beta = C(1)/C(0), R0 = [1 0; 0 var]', d1 < 1e-12, ...
        sprintf('beta %.4f, diff %.1e', b, d1));

    [phiV, RV] = hetlearn.init.re_moments(m0, sV);
    S = [1 0 0; 0 Cd(ip, ip, 1) Cd(ip, iy, 1); 0 Cd(iy, ip, 1) Cd(iy, iy, 1)];
    s = [0; Cd(ip, ip, 2); Cd(ip, iy, 2)];
    d2 = max(abs([phiV.pie - S \ s; RV.pie(:) - S(:)]));
    R = add(R, 'init: re_moments VAR-style PLM matches acf cross-moments', d2 < 1e-12, sprintf('diff %.1e', d2));

    % training OLS on a long simulated RE history is close to re_moments
    T = 5000;
    rng0 = qq(2000, 1);
    range = rng0 : rng0 + T - 1;
    db = zerodb(m0, range);
    db.e_g(range) = P.std_e_g * randn(T, 1);
    db.e_u(range) = P.std_e_u * randn(T, 1);
    db.e_r(range) = P.std_e_r * randn(T, 1);
    sim = simulate(m0, db, range, 'prependInput', true, 'anticipate', false);
    [phiO, RO] = hetlearn.init.training_ols(s1, sim, [range(10), range(end)]);
    d3 = abs(phiO.pie(2) - phi0.pie(2));
    R = add(R, 'init: training_ols on simulated RE data is close to re_moments', ...
        d3 < 0.05 && abs(RO.pie(1, 1) - 1) < 1e-12, sprintf('beta OLS %.4f vs RE %.4f', phiO.pie(2), phi0.pie(2)));

    ws = warning('off', 'hetlearn:init:unusedValues');
    [phiU, RU] = hetlearn.init.user(sV, struct('pie', struct('alpha', 0.1, 'beta', [0.7; 0.05]), ...
        'nonsense', struct('alpha', 1)), phiV, RV);
    warning(ws);
    ok = isequal(phiU.pie, [0.1; 0.7; 0.05]) && isequal(phiU.y, phiV.y) && isequal(RU.pie, RV.pie);
    R = add(R, 'init: user values override, the rest falls back', ok, '');
catch err
    R = add(R, 'init: re_moments / training_ols / user', false, err.message);
end
end


% =========================================================================
function [d, n1] = iris_check(meta, P)
% Simulate one period in IRIS from random lags; compare every x_exp1_BR
% with hetlearn.plm.forecast_value using the same beliefs.
a = struct();
for i = 1:numel(meta.toggles)
    a.(meta.toggles{i}) = true;
end
m = Model.fromFile(meta.ext_file, 'linear', true, 'assign', a);
m = put_params(m, P);
phi = rand_phi(meta.sys);
Pv = hetlearn.plm.param_values(meta.sys, phi);
f = fieldnames(Pv);
for i = 1:numel(f)
    m.(f{i}) = Pv.(f{i});
end
ok = false;
for n1 = [0, 0.5, 1]
    for i = 1:numel(meta.forward_vars)
        x = meta.forward_vars{i};
        m.(['n1_' x]) = n1;
        m.(['n2_' x]) = 1 - n1;
    end
    [m, flag] = solve(m);
    if hasSucceeded(flag)
        ok = true;
        break
    end
end
if ~ok
    error('test_plm:solve', 'Extended model does not solve for n1 in {0, 0.5, 1}.');
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
    fI = s.([x '_exp1_BR'])(t0);
    fV = hetlearn.plm.forecast_value(meta.sys, phi, getLag, x);
    d = max(d, abs(fI - fV));
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


function v = eval_text(txt, PV, getLag) %#ok<INUSD>
ex = regexprep(txt, '([A-Za-z]\w*)\{(-\d+)\}', 'getLag(''$1'',$2)');
ex = regexprep(ex, '(?<![\w''.])((alpha|beta)_\w+)', 'PV.$1');
v = eval(ex);
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


function spec = load_spec(folder)
old = cd(folder);
c = onCleanup(@() cd(old));
spec = model_spec();
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
