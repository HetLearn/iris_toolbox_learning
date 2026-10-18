function R = check_model()
% CHECK_MODEL  IRIS-only validation of the ijcb3 package (no hetlearn calls).
%
%   R = check_model()
%
% 1. Load ijcb3.model at ijcb3_params, solve, steady state; all eigenvalues and
%    the Blanchard-Kahn count (two leads, y{+1} and pinf{+1}).
% 2. Responses to 1-sd shocks over 20 quarters (srf): signs on impact, sizes,
%    and a cross-check against an independent solve of IJCB eqs. (3)-(6):
%    fixed-point iteration b = (A - C b)^-1 B, d = (A - C b)^-1 (C d rho + D).
% 3. Kalman filter and smoother over spec.filter_range on the package database
%    (yobs = the Hamilton gap with coefficients from IJCB's 1957Q1-2019Q4
%    sample and covid-adjusted regressors, data/README.md).
%    The measurement equations must rebuild the observables from the smoothed
%    states and shocks (lhsmrhs with the data on the left, NaN skipped, as in
%    hetlearn.re_filter): max abs error < 1e-8. The policy rule and the shock
%    processes must also hold at the smoothed values, so in ELB quarters the
%    smoothed rate is a shadow rate that follows the rule.
% 4. The CPI inflation peak in 2020Q1-2024Q4 (origin of application 1).
% Writes validation/RESULTS.txt, validation/irfs.csv and
% validation/smoothed_history.csv. Needs IRIS on the path.

here = fileparts(mfilename('fullpath'));
pkg = fileparts(here);
old = cd(pkg);
back = onCleanup(@() cd(old));
clear('model_spec');
spec = feval('model_spec');
P = feval(spec.params);
tol = 1e-8;
nPer = 20;
L = {};

L{end+1} = sprintf('ijcb3 validation: validation/check_model.m, %s, MATLAB %s', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version);
L{end+1} = sprintf('Model %s at %s (IJCB Table 1, HE posterior means); database %s', ...
    spec.model_file, spec.params, spec.database);

% ---- 1. solve and eigenvalues -----------------------------------------------------------
m = Model.fromFile(fullfile(pkg, spec.model_file), 'linear', spec.linear);
m = assign(m, P);
[m, flag] = solve(m);
assert(hasSucceeded(flag), 'check_model: IRIS solve failed');
m = sstate(m);
[lam, stab] = eig(m);
lam = lam(:);
stab = double(stab(:));
[~, ord] = sort(abs(lam), 'descend');
R.eig = lam(ord);
R.eig_stability = stab(ord);
R.n_unstable = sum(abs(lam) > 1 + 1e-10);
R.n_unit = sum(abs(abs(lam) - 1) <= 1e-10);
R.n_stable = sum(abs(lam) < 1 - 1e-10);
R.bk_pass = R.n_unstable == 2 && R.n_unit == 0;
R.ss = [real(m.yobs), real(m.pinfobs), real(m.robs)];
R.ss_pass = max(abs(R.ss - [0, P.pi_bar, P.r_bar_T])) < 1e-12;

L{end+1} = '';
L{end+1} = '1. SOLUTION';
L{end+1} = sprintf('IRIS solve: success. Steady state of yobs, pinfobs, robs: %.4f, %.4f, %.4f (= 0, pi_bar, r_bar_T: %d)', ...
    R.ss, R.ss_pass);
L{end+1} = sprintf('Eigenvalues (IRIS eig, all roots of the transition system; IRIS stability code 0 stable, 1 unit, 2 unstable):');
for i = 1:numel(R.eig)
    L{end+1} = sprintf('  %2d  %10.6f %+10.6fi   |%8.6f|   code %d', i, real(R.eig(i)), imag(R.eig(i)), ...
        abs(R.eig(i)), R.eig_stability(i)); %#ok<AGROW>
end
L{end+1} = sprintf('Stable %d, unit %d, unstable %d; leads y{+1}, pinf{+1}: 2. Blanchard-Kahn (unique stable solution): %d', ...
    R.n_stable, R.n_unit, R.n_unstable, R.bk_pass);

% ---- 2. impulse responses -----------------------------------------------------------------
eList = cellstr(get(m, 'eList'));
xList = cellstr(get(m, 'xList'));
vars = {'y', 'pinf', 'r', 'u_y', 'u_pinf'};
s = srf(m, 1:nPer);
IR = zeros(nPer, numel(vars), numel(eList));
for j = 1:numel(eList)
    for i = 1:numel(vars)
        X = s.(vars{i}).Data;
        IR(:, i, j) = X(end-nPer+1:end, j);
    end
end

% independent solve of IJCB eqs. (3)-(6): A X = B X{-1} + C E X{+1} + D u, X = [y; pinf; r]
A = [1, 0, 1/P.tau; ...
    -P.kappa, 1, 0; ...
    -(1 - P.rho_r)*P.phi_y - P.phi_dy, -(1 - P.rho_r)*P.phi_pi, 1];
B = [P.iota_y, 0, 0; 0, P.beta*P.iota_p, 0; -P.phi_dy, 0, P.rho_r];
C = [1 - P.iota_y, 1/P.tau, 0; 0, P.beta*(1 - P.iota_p), 0; 0, 0, 0];
D = eye(3);
rho = diag([P.rho_y, P.rho_pi, 0]);         % u = [u_y; u_pinf; eps_r]
b = zeros(3);
for it = 1:200000
    bNew = (A - C*b)\B;
    step = max(abs(bNew(:) - b(:)));
    b = bNew;
    if step < 1e-15, break, end
end
F = inv(A - C*b);
dd = zeros(3);
for k = 1:3
    dd(:, k) = (eye(3) - rho(k, k)*F*C) \ (F*D(:, k));
end
R.indep_iterations = it;
R.indep_res_b = max(max(abs(C*b*b - A*b + B)));
R.indep_res_d = max(max(abs((A - C*b)*dd - C*dd*rho - D)));
R.eig_b = sort(eig(b), 'descend');
sig = [P.std_eps_y, P.std_eps_pinf, P.std_eps_r];
col = struct('eps_y', 1, 'eps_pinf', 2, 'eps_r', 3);
R.irf_indep_maxdiff = 0;
for j = 1:numel(eList)
    k = col.(eList{j});
    u = zeros(3, 1);
    u(k) = sig(k);
    X = zeros(3, nPer);
    X(:, 1) = dd*u;
    for t = 2:nPer
        u = rho*u;
        X(:, t) = b*X(:, t-1) + dd*u;
    end
    R.irf_indep_maxdiff = max(R.irf_indep_maxdiff, max(max(abs(X' - IR(:, 1:3, j)))));
end
R.irf_indep_pass = R.irf_indep_maxdiff < 1e-10;

% expected signs on impact: textbook NK mechanics (IJCB reports no IRFs)
expect = struct( ...
    'eps_y',    [ 1,  1,  1], ...   % demand: gap up, inflation up, rate up
    'eps_pinf', [-1,  1,  1], ...   % cost push: inflation up, rate up, gap down
    'eps_r',    [-1, -1,  1]);      % policy: rate up, gap and inflation down
R.sign_pass = true;
L{end+1} = '';
L{end+1} = '2. IMPULSE RESPONSES (1-sd shocks, 20 quarters; srf)';
L{end+1} = sprintf(['Independent solve of IJCB eqs. (3)-(6) by fixed-point iteration: %d iterations, ' ...
    'residuals b %.2g, d %.2g; eig(b) = %s'], R.indep_iterations, R.indep_res_b, R.indep_res_d, ...
    strjoin(arrayfun(@(z) sprintf('%.6f', z), R.eig_b, 'UniformOutput', false), ', '));
L{end+1} = sprintf('IRIS srf vs independent solution, y/pinf/r, all shocks and quarters: max abs diff %.3g (pass %d)', ...
    R.irf_indep_maxdiff, R.irf_indep_pass);
L{end+1} = 'Units: y in % of trend output; pinf and r annualised (x4), percentage points. Extreme = largest |response|.';
L{end+1} = sprintf('%-9s %-5s %9s %9s %5s %9s %9s  %s', 'shock', 'var', 'impact', 'extreme', 'qtr', 'q20', 'cum20', 'sign on impact');
for j = 1:numel(eList)
    e = eList{j};
    for i = 1:3
        sc = 1 + 3*(i > 1);                  % annualise pinf and r
        v = sc*IR(:, i, j);
        [~, kx] = max(abs(v));
        ok = sign(v(1)) == expect.(e)(i);
        R.sign_pass = R.sign_pass && ok;
        R.irf.(e).(vars{i}) = v;
        L{end+1} = sprintf('%-9s %-5s %9.4f %9.4f %5d %9.4f %9.4f  %s (expected %+d)', e, vars{i}, v(1), v(kx), kx, ...
            v(end), sum(v), ternary(ok, 'ok', 'WRONG'), expect.(e)(i)); %#ok<AGROW>
    end
    % ex-ante real rate r - E pinf{+1} (perfect-foresight path), annualised
    rr = 4*(IR(1:end-1, 3, j) - IR(2:end, 2, j));
    L{end+1} = sprintf('%-9s %-5s %9.4f   (ex-ante real rate r - pinf{+1}, annualised, impact)', e, 'rr', rr(1)); %#ok<AGROW>
end
L{end+1} = sprintf('All impact signs as expected: %d', R.sign_pass);

% ---- 3. Kalman filter and smoother -------------------------------------------------------
d = databank.fromCSV(fullfile(pkg, spec.database));
range = spec.filter_range(1):spec.filter_range(2);
[~, f] = filter(m, d, range, 'output', 'smooth', 'meanOnly', true);
yList = spec.observables;
db = f;
for i = 1:numel(yList)
    db.(yList{i}) = d.(yList{i});
end
Q = lhsmrhs(m, db, range);
nY = numel(yList);
Qm = Q(1:nY, :);
R.n_obs_missing = sum(~isfinite(Qm(:)));
R.fit_error = max([0; abs(Qm(isfinite(Qm)))]);
% the same by hand: data minus measurement equations at the smoothed states
e1 = getData(d.yobs, range) - getData(f.y, range);
e2 = getData(d.pinfobs, range) - (P.pi_bar + getData(f.pinf, range));
e3 = getData(d.robs, range) - (P.r_bar_T + getData(f.r, range));
R.fit_error_hand = max(abs([e1; e2; e3(isfinite(e3))]));
% policy rule and shock processes at the smoothed values
labs = {};
try
    labs = cellstr(get(m, 'labels'));
catch
end
rowRule = find(strcmp(labs, 'Monetary policy rule, Taylor rule with smoothing (IJCB eq. 1)'));
rowUy = find(strcmp(labs, 'Demand shock, AR(1) (IJCB eq. 2)'));
rowUp = find(strcmp(labs, 'Cost-push shock, AR(1) (IJCB eq. 2)'));
if isempty(rowRule) || isempty(rowUy) || isempty(rowUp)
    rowRule = nY + 3;  rowUy = nY + 4;  rowUp = nY + 5;   % IRIS order: measurement, then transition
    R.rows_from_labels = false;
else
    R.rows_from_labels = true;
end
Qr = Q([rowRule, rowUy, rowUp], :);
R.rule_error = max([0; abs(Qr(isfinite(Qr)))]);
R.filter_pass = R.fit_error < tol && R.fit_error_hand < tol && R.rule_error < tol;

% shadow rate in ELB quarters (annualised level)
elb = getData(d.elb, range) == 1;
shadow = 4*(P.r_bar_T + getData(f.r, range));
ffAnn = 4*getData(d.ffr, range);
dstr = dat2str(range);
rd = double(range(:));
w1 = elb & rd <= double(qq(2015,4));
w2 = elb & rd >= double(qq(2020,2));
[R.shadow_min_gfc, k1] = min(shadow + 1e9*~w1);
[R.shadow_min_covid, k2] = min(shadow + 1e9*~w2);
R.shadow_min_gfc_date = dstr{k1};
R.shadow_min_covid_date = dstr{k2};
R.shadow_2010Q2 = shadow(strcmp(dstr, dat2char(qq(2010,2))));
R.shadow_mean_gfc = mean(shadow(w1));
R.shadow_mean_covid = mean(shadow(w2));

L{end+1} = '';
L{end+1} = '3. KALMAN FILTER AND SMOOTHER';
L{end+1} = sprintf('Range %s-%s, %d quarters, %d observables, %d shocks; IRIS default initial condition (asymptotic distribution).', ...
    dat2char(range(1)), dat2char(range(end)), numel(range), nY, numel(eList));
L{end+1} = sprintf('Missing observations (robs in ELB quarters): %d.', R.n_obs_missing);
L{end+1} = sprintf('Observables rebuilt through the measurement equations (lhsmrhs, data on the left, NaN skipped): max abs error %.3g', R.fit_error);
L{end+1} = sprintf('Same by hand (yobs - y, pinfobs - pi_bar - pinf, robs - r_bar_T - r): max abs error %.3g', R.fit_error_hand);
L{end+1} = sprintf('Policy rule and AR(1) shock processes at the smoothed values (rows from labels: %d): max abs residual %.3g', ...
    R.rows_from_labels, R.rule_error);
L{end+1} = sprintf('PASS (all < %.0e): %d', tol, R.filter_pass);
L{end+1} = 'Smoothed policy rate in ELB quarters = shadow rate, annualised level 4*(r_bar_T + r), % a year:';
L{end+1} = sprintf('  2009Q1-2015Q4: trough %.2f in %s, 2010Q2 %.2f, mean %.2f (fed funds mean %.2f)', R.shadow_min_gfc, ...
    R.shadow_min_gfc_date, R.shadow_2010Q2, R.shadow_mean_gfc, mean(ffAnn(w1)));
L{end+1} = sprintf('  2020Q2-2022Q1: trough %.2f in %s, mean %.2f (fed funds mean %.2f)', R.shadow_min_covid, ...
    R.shadow_min_covid_date, R.shadow_mean_covid, mean(ffAnn(w2)));
L{end+1} = '  (IJCB Fig. 2, HE model with ELB regime: trough in 2010Q2, compared with an annual rate of -4 percent.)';
yrs = [qq(2009,1), qq(2010,2), qq(2011,4), qq(2013,4), qq(2015,4), qq(2020,2), qq(2020,4), qq(2021,2), qq(2021,4), qq(2022,1)];
L{end+1} = sprintf('  %-7s %8s %8s', 'quarter', 'shadow', 'FF');
for t = yrs
    k = find(strcmp(dstr, dat2char(t)));
    L{end+1} = sprintf('  %-7s %8.2f %8.2f', dstr{k}, shadow(k), ffAnn(k)); %#ok<AGROW>
end
L{end+1} = 'Smoothed shocks (model units):';
L{end+1} = sprintf('  %-9s %8s %8s %8s %10s  %s', 'shock', 'mean', 'std', 'model sd', 'max|e|/sd', 'date');
for j = 1:numel(eList)
    v = getData(f.(eList{j}), range);
    sd = P.(['std_', eList{j}]);
    [mx, kx] = max(abs(v));
    L{end+1} = sprintf('  %-9s %8.4f %8.4f %8.4f %10.2f  %s', eList{j}, mean(v), std(v), sd, mx/sd, dstr{kx}); %#ok<AGROW>
end

% ---- 4. inflation peak and smoothed state at the origin -------------------------------------
win = qq(2020,1):qq(2024,4);
v = getData(d.pinfobs, win);
[R.peak_value, kp] = max(v);
R.peak_date = dat2char(win(kp));
ko = find(strcmp(dstr, R.peak_date));
L{end+1} = '';
L{end+1} = '4. APPLICATION-1 ORIGIN';
L{end+1} = sprintf('CPI inflation peak 2020Q1-2024Q4 (max of pinfobs): %s, %.4f %% q/q = %.2f %% annualised', ...
    R.peak_date, R.peak_value, 4*R.peak_value);
L{end+1} = sprintf('Smoothed state at %s: y %.3f, pinf %.3f (annualised %.2f), r %.3f (level %.2f %% a year), u_y %.3f, u_pinf %.3f', ...
    R.peak_date, getData(f.y, win(kp)), getData(f.pinf, win(kp)), 4*getData(f.pinf, win(kp)), ...
    getData(f.r, win(kp)), shadow(ko), getData(f.u_y, win(kp)), getData(f.u_pinf, win(kp)));
R.origin_shocks = [getData(f.eps_y, win(kp)), getData(f.eps_pinf, win(kp)), getData(f.eps_r, win(kp))];
L{end+1} = sprintf('Smoothed shocks at %s: eps_y %.3f, eps_pinf %.3f, eps_r %.3f (model sd %.2f, %.2f, %.2f)', ...
    R.peak_date, R.origin_shocks, P.std_eps_y, P.std_eps_pinf, P.std_eps_r);
R.origin_yobs = getData(d.yobs, win(kp));
R.origin_yobs_hamilton = getData(d.yobs_hamilton, win(kp));
R.origin_yobs_fullsample = getData(d.yobs_fullsample, win(kp));
L{end+1} = sprintf(['Data at %s: yobs %.3f (Hamilton gap, IJCB-sample coefficients, covid-adjusted regressors; ' ...
    'helpers, not observed: yobs_hamilton %.3f, yobs_fullsample %.3f), pinfobs %.4f, robs %.4f'], ...
    R.peak_date, R.origin_yobs, R.origin_yobs_hamilton, R.origin_yobs_fullsample, ...
    getData(d.pinfobs, win(kp)), getData(d.robs, win(kp)));

R.pass = R.ss_pass && R.bk_pass && R.irf_indep_pass && R.sign_pass && R.filter_pass;
L{end+1} = '';
L{end+1} = sprintf(['OVERALL PASS: %d  (steady state %d, Blanchard-Kahn %d, IRFs vs independent solve %d, ' ...
    'impact signs %d, filter %d)'], R.pass, R.ss_pass, R.bk_pass, R.irf_indep_pass, R.sign_pass, R.filter_pass);

% ---- outputs ---------------------------------------------------------------------------------
fid = fopen(fullfile(here, 'RESULTS.txt'), 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
fprintf('%s\n', L{:});

shockCol = {};  qCol = [];  Y = [];
for j = 1:numel(eList)
    shockCol = [shockCol; repmat(eList(j), nPer, 1)]; %#ok<AGROW>
    qCol = [qCol; (1:nPer)']; %#ok<AGROW>
    Y = [Y; IR(:, :, j)]; %#ok<AGROW>
end
Tirf = [table(shockCol, qCol, 'VariableNames', {'shock', 'quarter'}), array2table(Y, 'VariableNames', vars)];
writetable(Tirf, fullfile(here, 'irfs.csv'));

out = struct();
for n = [xList(:); eList(:)]'
    out.(n{1}) = f.(n{1});
end
out.shadow_rate_ann = Series(range(1), shadow);
databank.toCSV(out, fullfile(here, 'smoothed_history.csv'), range, 'Format', '%.17g');
end


function z = ternary(c, a, b)
if c, z = a; else, z = b; end
end
