function R = check_model()
% CHECK_MODEL  IRIS-only validation of the as07 package (no HetLearn engine calls).
%
%   R = check_model()
%
% 0. as07_params equals the published table (Herbst and Schorfheide 2016,
%    Ch. 4 slides, "Posterior Estimates of DSGE Model Parameters": means), and
%    the measurement-error std devs equal 0.2 x the us.txt std (sysmat.m).
%    Nothing is estimated or sampled here.
% 1. Load as07.model at as07_params, solve, steady state of the observables;
%    all eigenvalues and the Blanchard-Kahn count (two leads, y{+1}, pinf{+1}).
% 2. Responses to 1-sd shocks over 20 quarters (srf) against the book's own
%    solution: model_solution.m (gensys) at the same parameters, s(t) =
%    T1 s(t-1) + T0 e(t), observables through the B matrix of sysmat.m. The
%    book's variables are in the package units, so the comparison has no
%    rescaling (factor 1). Tolerance 1e-10.
% 3. Log likelihood on us.txt, 1983Q1-2002Q4: IRIS loglik ('relative' false,
%    default initial condition: steady-state mean, asymptotic MSE) against the
%    book's dsgeliki.m (kalman.m: state at its stationary distribution), with
%    the measurement errors of sysmat.m and without them (std 0 in IRIS,
%    H = 0 in kalman.m).
% 4. Kalman filter and smoother over spec.filter_range on the package
%    database. The measurement equations must rebuild the observables from the
%    smoothed states and shocks (lhsmrhs with the data on the left, NaN
%    skipped, as in hetlearn.re_filter): max abs error < 1e-8; the policy rule
%    and the shock processes must hold at the smoothed values.
% 5. Application-1 origin: the CPI inflation peak in 2020Q1-2024Q4, by max()
%    and by hetlearn.find_peak (with hetlearn.load_spec/load_database, which
%    do not run the engine).
% Writes validation/RESULTS.txt, validation/irfs.csv and
% validation/smoothed_history.csv. Needs IRIS on the path; the book's code is
% put on the path here and removed at the end.

here = fileparts(mfilename('fullpath'));
pkg = fileparts(here);
hs = fullfile(pkg, 'estimation', 'hs2016');
old = cd(pkg);
back = onCleanup(@() cd(old));
addpath(fullfile(hs, 'Mfiles'), fullfile(hs, 'LRE'));
backPath = onCleanup(@() rmpath(fullfile(hs, 'Mfiles'), fullfile(hs, 'LRE')));
clear('model_spec');
spec = feval('model_spec');
P = feval(spec.params);
tol = 1e-8;
nPer = 20;
L = {};
L{end+1} = sprintf('as07 validation: validation/check_model.m, %s, MATLAB %s', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), version);
L{end+1} = sprintf(['Model %s at %s (published posterior means, Herbst and Schorfheide 2016, Ch. 4 slides, ' ...
    '"Posterior Estimates of DSGE Model Parameters"); database %s'], spec.model_file, spec.params, spec.database);

% ---- 0. parameters ------------------------------------------------------------------------
% the published table in prior.m order: package name, mean, 5th and 95th percentiles
pub = {'tau', 2.83, 1.95, 3.82; 'kappa', 0.78, 0.51, 0.98; 'psi1', 1.80, 1.43, 2.20; ...
    'psi2', 0.63, 0.23, 1.21; 'rA', 0.42, 0.04, 0.95; 'piA', 3.30, 2.78, 3.80; ...
    'gammaQ', 0.52, 0.28, 0.74; 'rho_r', 0.77, 0.71, 0.82; 'rho_g', 0.98, 0.96, 1.00; ...
    'rho_z', 0.88, 0.84, 0.92; 'std_eps_r', 0.22, 0.18, 0.26; 'std_eps_g', 0.71, 0.61, 0.84; ...
    'std_eps_z', 0.31, 0.26, 0.36};
R.param_maxdiff = max(cellfun(@(n, v) abs(P.(n) - v), pub(:, 1), pub(:, 2)));
us = load(fullfile(hs, 'us.txt'));
sdUS = std(us, 0, 1);
R.me_maxdiff = max(abs([P.std_me_dy, P.std_me_pinfobs, P.std_me_robs] - 0.2*sdUS));
R.param_pass = R.param_maxdiff < 1e-12 && R.me_maxdiff < 1e-6;
para = [P.tau, P.kappa, P.psi1, P.psi2, P.rA, P.piA, P.gammaQ, P.rho_r, P.rho_g, P.rho_z, ...
    P.std_eps_r, P.std_eps_g, P.std_eps_z];          % order of prior.m
L{end+1} = '';
L{end+1} = '0. PARAMETERS';
L{end+1} = sprintf('as07_params vs the published means: max abs diff %.3g; measurement-error std (sysmat.m) vs 0.2 x std(us.txt): %.3g (pass %d)', ...
    R.param_maxdiff, R.me_maxdiff, R.param_pass);
for i = 1:size(pub, 1)
    L{end+1} = sprintf('  %-10s %6.2f  [%.2f, %.2f]', pub{i, 1}, P.(pub{i, 1}), pub{i, 3}, pub{i, 4}); %#ok<AGROW>
end
L{end+1} = sprintf('  measurement errors (sysmat.m, not in the table): me_dy %.4f, me_pinfobs %.4f, me_robs %.4f', ...
    P.std_me_dy, P.std_me_pinfobs, P.std_me_robs);
L{end+1} = sprintf('beta = 1/(1 + rA/400) = %.8f', 1/(1 + P.rA/400));

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
R.ss = [real(m.dy), real(m.pinfobs), real(m.robs)];
R.ss_expected = [P.gammaQ, P.piA, P.piA + P.rA + 4*P.gammaQ];
R.ss_pass = max(abs(R.ss - R.ss_expected)) < 1e-12;
% model_solution.m returns gensys's gev as its 4th output (TETA) and never
% returns eu (its retcode is always 0), so count the roots with gensys's own
% rule: unstable if |b| > div*|a|, div = 1 + 1e-8 as in model_solution.m.
[T1, ~, T0, GEV] = model_solution(para);
gRoot = abs(GEV(:, 2))./abs(GEV(:, 1));
R.gensys_n_unstable = sum(abs(GEV(:, 2)) > (1 + 1e-8)*abs(GEV(:, 1)));
gFin = sort(gRoot(isfinite(gRoot) & gRoot > 1 + 1e-8), 'descend');
iUn = sort(abs(R.eig(abs(R.eig) > 1 + 1e-10)), 'descend');
R.gensys_unstable_match = numel(gFin) == numel(iUn) && max(abs(gFin - iUn)) < 1e-8;
eT1 = eig(T1);
eT1 = sort(eT1(abs(eT1) > 1e-10), 'descend');
eIris = R.eig(abs(R.eig) < 1 - 1e-10);
eIris = sort(eIris(abs(eIris) > 1e-10), 'descend');
R.eig_match = numel(eT1) == numel(eIris) && max(abs(eT1 - eIris)) < 1e-8;

L{end+1} = '';
L{end+1} = '1. SOLUTION';
L{end+1} = sprintf('IRIS solve: success. Steady state of dy, pinfobs, robs: %.4f, %.4f, %.4f (= gammaQ, piA, piA+rA+4gammaQ: %d)', ...
    R.ss, R.ss_pass);
L{end+1} = 'Eigenvalues (IRIS eig, all roots of the transition system; IRIS stability code 0 stable, 1 unit, 2 unstable):';
for i = 1:numel(R.eig)
    L{end+1} = sprintf('  %2d  %10.6f %+10.6fi   |%8.6f|   code %d', i, real(R.eig(i)), imag(R.eig(i)), ...
        abs(R.eig(i)), R.eig_stability(i)); %#ok<AGROW>
end
L{end+1} = sprintf('Stable %d, unit %d, unstable %d; leads y{+1}, pinf{+1}: 2. Blanchard-Kahn (unique stable solution): %d', ...
    R.n_stable, R.n_unit, R.n_unstable, R.bk_pass);
L{end+1} = sprintf(['Book gensys at the same parameters (model_solution.m): %d unstable generalised eigenvalues for 2 expectational errors; ' ...
    'finite unstable roots %s = IRIS unstable roots: %d'], R.gensys_n_unstable, ...
    strjoin(arrayfun(@(z) sprintf('%.6f', z), gFin, 'UniformOutput', false), ', '), R.gensys_unstable_match);
L{end+1} = sprintf('Nonzero roots of the book''s T1 (%s) = IRIS stable nonzero roots: %d', ...
    strjoin(arrayfun(@(z) sprintf('%.6f', z), real(eT1), 'UniformOutput', false), ', '), R.eig_match);
R.eig_match = R.eig_match && R.gensys_unstable_match && R.gensys_n_unstable == 2;

% ---- 2. impulse responses -----------------------------------------------------------------
eList = cellstr(get(m, 'eList'));
xList = cellstr(get(m, 'xList'));
vars = {'y', 'pinf', 'r', 'g', 'z'};
obs = {'dy', 'pinfobs', 'robs'};
shocks = {'eps_z', 'eps_g', 'eps_r'};                 % book order z_sh, g_sh, R_sh
sig = [P.std_eps_z, P.std_eps_g, P.std_eps_r];
s = srf(m, 1:nPer);
hasObs = all(isfield(s, obs));
IR = zeros(nPer, numel(vars) + numel(obs), numel(shocks));
HS = IR;
for j = 1:numel(shocks)
    c = find(strcmp(eList, shocks{j}));
    names = [vars, obs];
    for i = 1:numel(names)
        if i <= numel(vars) || hasObs
            X = s.(names{i}).Data;
            IR(:, i, j) = X(end-nPer+1:end, c);
        end
    end
    if ~hasObs
        IR(:, 6, j) = IR(:, 1, j) - [0; IR(1:end-1, 1, j)] + IR(:, 5, j);
        IR(:, 7, j) = 4*IR(:, 2, j);
        IR(:, 8, j) = 4*IR(:, 3, j);
    end
    st = zeros(8, nPer);
    st(:, 1) = T0(:, j)*sig(j);
    for t = 2:nPer
        st(:, t) = T1*st(:, t-1);
    end
    % book state order: y, pi, R, y(-1), g, z, E y(+1), E pi(+1); sysmat.m B matrix
    HS(:, :, j) = [st([1 2 3 5 6], :); st(1, :) - st(4, :) + st(6, :); 4*st(2, :); 4*st(3, :)]';
end
R.irf_hs_maxdiff = max(abs(IR(:) - HS(:)));
R.irf_hs_pass = R.irf_hs_maxdiff < 1e-10;
R.irf_obs_from_srf = hasObs;
L{end+1} = '';
L{end+1} = '2. IMPULSE RESPONSES (1-sd shocks, 20 quarters; srf)';
L{end+1} = sprintf(['IRIS srf vs the book''s gensys solution (model_solution.m, T1 and T0; observables by sysmat.m''s B), ' ...
    'y/pinf/r/g/z and dy/pinfobs/robs, all three shocks and quarters, no rescaling: max abs diff %.3g (pass %d; observables from srf %d)'], ...
    R.irf_hs_maxdiff, R.irf_hs_pass, hasObs);
L{end+1} = 'Units: y, g in %; pinf, r, z in % per quarter; dy % per quarter; pinfobs, robs % a year. Extreme = largest |response|.';
L{end+1} = sprintf('%-6s %-8s %9s %9s %5s %9s %9s', 'shock', 'var', 'impact', 'extreme', 'qtr', 'q20', 'cum20');
names = [vars, obs];
for j = 1:numel(shocks)
    for i = 1:numel(names)
        v = IR(:, i, j);
        [~, kx] = max(abs(v));
        R.irf.(shocks{j}).(names{i}) = v;
        L{end+1} = sprintf('%-6s %-8s %9.4f %9.4f %5d %9.4f %9.4f', shocks{j}, names{i}, v(1), v(kx), kx, ...
            v(end), sum(v)); %#ok<AGROW>
    end
end
% policy shock: rate up, output and inflation down (the only signs the model pins down a priori)
R.sign_pass = IR(1, 3, 3) > 0 && IR(1, 1, 3) < 0 && IR(1, 2, 3) < 0;
L{end+1} = sprintf('Policy shock: r up, y down, pinf down on impact: %d', R.sign_pass);

% ---- 3. likelihood on us.txt -------------------------------------------------------------------
rUS = qq(1983,1):qq(2002,4);
dUS = struct('dy', Series(rUS(1), us(:, 1)), 'pinfobs', Series(rUS(1), us(:, 2)), 'robs', Series(rUS(1), us(:, 3)));
R.ll_iris_me = -loglik(m, dUS, rUS, 'relative', false);
cd(hs);
R.ll_book_me = dsgeliki(para);
[A, B, ~, Rm, Se, Phi] = sysmat(T1, T0, para);
R.ll_book_nome = sum(kalman(A, B, zeros(3), Rm, Se, Phi, us));
cd(pkg);
m0 = assign(m, struct('std_me_dy', 0, 'std_me_pinfobs', 0, 'std_me_robs', 0));
R.ll_iris_nome = -loglik(m0, dUS, rUS, 'relative', false);
R.ll_gap_me = R.ll_iris_me - R.ll_book_me;
R.ll_gap_nome = R.ll_iris_nome - R.ll_book_nome;
R.ll_pass = abs(R.ll_gap_me) < 1e-6 && abs(R.ll_gap_nome) < 1e-6;
L{end+1} = '';
L{end+1} = '3. LOG LIKELIHOOD ON us.txt, 1983Q1-2002Q4 (80 quarters, 3 observables)';
L{end+1} = 'Both start from the stationary distribution: kalman.m sets s(0) = 0 and P(0) = the unconditional variance;';
L{end+1} = 'IRIS loglik default initial condition (steady-state mean, asymptotic MSE), relative = false (no variance scaling).';
L{end+1} = sprintf('With sysmat.m measurement errors: book dsgeliki %.8f, IRIS %.8f, gap %.3g', R.ll_book_me, R.ll_iris_me, R.ll_gap_me);
L{end+1} = sprintf('Without measurement errors:      book kalman(H=0) %.8f, IRIS (std_me = 0) %.8f, gap %.3g', ...
    R.ll_book_nome, R.ll_iris_nome, R.ll_gap_nome);
L{end+1} = sprintf('PASS (|gap| < 1e-6): %d', R.ll_pass);

% ---- 4. Kalman filter and smoother -------------------------------------------------------
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
R.me_in_output = all(isfield(f, {'me_dy', 'me_pinfobs', 'me_robs'}));
gt = @(name) getData(f.(name), range);
e1 = getData(d.dy, range) - (P.gammaQ + gt('y') - getData(f.y, range - 1) + gt('z') + gt('me_dy'));
e2 = getData(d.pinfobs, range) - (P.piA + 4*gt('pinf') + gt('me_pinfobs'));
e3 = getData(d.robs, range) - (P.piA + P.rA + 4*P.gammaQ + 4*gt('r') + gt('me_robs'));
R.fit_error_hand = max(abs([e1; e2; e3(isfinite(e3))]));
labs = {};
try
    labs = cellstr(get(m, 'labels'));
catch
end
rowRule = find(strcmp(labs, 'Monetary policy rule, Taylor rule with smoothing (AS07)'));
rowG = find(strcmp(labs, 'Government spending shock, AR(1) (model_solution.m eq_5)'));
rowZ = find(strcmp(labs, 'Technology growth shock, AR(1) (model_solution.m eq_6)'));
if isempty(rowRule) || isempty(rowG) || isempty(rowZ)
    rowRule = nY + 3;  rowG = nY + 4;  rowZ = nY + 5;   % IRIS order: measurement, then transition
    R.rows_from_labels = false;
else
    R.rows_from_labels = true;
end
Qr = Q([rowRule, rowG, rowZ], :);
R.rule_error = max([0; abs(Qr(isfinite(Qr)))]);
% The Euler equation and the Phillips curve hold with expectations, which
% lhsmrhs replaces by the smoothed future values: their residuals are the
% expectational errors, reported but not tested.
rowFwd = [find(strcmp(labs, 'Consumption Euler equation (model_solution.m eq_1)')), ...
    find(strcmp(labs, 'New Keynesian Phillips curve (model_solution.m eq_2)'))];
if numel(rowFwd) ~= 2, rowFwd = nY + [1, 2]; end
Qf = Q(rowFwd, :);
Qf(~isfinite(Qf)) = 0;
[R.fwd_resid_max, kf] = max(max(abs(Qf), [], 1));
R.fwd_resid_date = dat2char(range(kf));
R.filter_pass = R.fit_error < tol && R.fit_error_hand < tol && R.rule_error < tol;

elb = getData(d.elb, range) == 1;
shadow = P.piA + P.rA + 4*P.gammaQ + 4*gt('r');      % model rate level, % a year (robs without the error)
ffAnn = getData(d.ffr, range);
dstr = dat2str(range);
rd = double(range(:));
w1 = elb & rd <= double(qq(2015,4));
w2 = elb & rd >= double(qq(2020,2));
[R.shadow_min_gfc, k1] = min(shadow + 1e9*~w1);
[R.shadow_min_covid, k2] = min(shadow + 1e9*~w2);
R.shadow_min_gfc_date = dstr{k1};
R.shadow_min_covid_date = dstr{k2};
R.shadow_mean_gfc = mean(shadow(w1));
R.shadow_mean_covid = mean(shadow(w2));
okR = isfinite(getData(d.robs, range));
R.rate_fit_rmse = sqrt(mean((shadow(okR) - ffAnn(okR)).^2));

L{end+1} = '';
L{end+1} = '4. KALMAN FILTER AND SMOOTHER';
L{end+1} = sprintf('Range %s-%s, %d quarters, %d observables, %d transition + 3 measurement shocks; IRIS default initial condition.', ...
    dat2char(range(1)), dat2char(range(end)), numel(range), nY, numel(shocks));
L{end+1} = sprintf('Missing observations (robs in ELB quarters): %d. Smoothed measurement errors in the filter output: %d.', ...
    R.n_obs_missing, R.me_in_output);
L{end+1} = sprintf('Observables rebuilt through the measurement equations (lhsmrhs, data on the left, NaN skipped): max abs error %.3g', R.fit_error);
L{end+1} = sprintf('Same by hand (dy, pinfobs, robs from the smoothed y, y{-1}, z, pinf, r and measurement errors): max abs error %.3g', R.fit_error_hand);
L{end+1} = sprintf('Policy rule and AR(1) shock processes at the smoothed values (rows from labels: %d): max abs residual %.3g', ...
    R.rows_from_labels, R.rule_error);
L{end+1} = sprintf(['Euler equation and Phillips curve with the smoothed t+1 values in place of expectations (not tested): ' ...
    'residual = expectational error, largest %.3f in %s'], R.fwd_resid_max, R.fwd_resid_date);
L{end+1} = sprintf('PASS (all < %.0e): %d', tol, R.filter_pass);
L{end+1} = 'Smoothed model rate in ELB quarters = shadow rate, piA + rA + 4 gammaQ + 4 r, % a year:';
L{end+1} = sprintf('  2009Q1-2015Q4: trough %.2f in %s, mean %.2f (fed funds mean %.2f)', R.shadow_min_gfc, ...
    R.shadow_min_gfc_date, R.shadow_mean_gfc, mean(ffAnn(w1)));
L{end+1} = sprintf('  2020Q2-2022Q1: trough %.2f in %s, mean %.2f (fed funds mean %.2f)', R.shadow_min_covid, ...
    R.shadow_min_covid_date, R.shadow_mean_covid, mean(ffAnn(w2)));
L{end+1} = sprintf('  Outside the ELB, model rate minus fed funds rate (= -me_robs): rmse %.3f pp', R.rate_fit_rmse);
yrs = [qq(2009,1), qq(2010,2), qq(2011,4), qq(2013,4), qq(2015,4), qq(2020,2), qq(2020,4), qq(2021,2), qq(2021,4), qq(2022,1)];
L{end+1} = sprintf('  %-7s %8s %8s', 'quarter', 'shadow', 'FF');
for t = yrs
    k = find(strcmp(dstr, dat2char(t)));
    L{end+1} = sprintf('  %-7s %8.2f %8.2f', dstr{k}, shadow(k), ffAnn(k)); %#ok<AGROW>
end
L{end+1} = 'Smoothed shocks (model units):';
L{end+1} = sprintf('  %-11s %8s %8s %8s %10s  %s', 'shock', 'mean', 'std', 'model sd', 'max|e|/sd', 'date');
allShocks = [shocks, {'me_dy', 'me_pinfobs', 'me_robs'}];
for j = 1:numel(allShocks)
    v = gt(allShocks{j});
    sd = P.(['std_', allShocks{j}]);
    [mx, kx] = max(abs(v));
    L{end+1} = sprintf('  %-11s %8.4f %8.4f %8.4f %10.2f  %s', allShocks{j}, mean(v), std(v), sd, mx/sd, dstr{kx}); %#ok<AGROW>
end

% ---- 5. inflation peak and smoothed state at the origin -------------------------------------
win = qq(2020,1):qq(2024,4);
v = getData(d.pinfobs, win);
[R.peak_value, kp] = max(v);
R.peak_date = dat2char(win(kp));
R.find_peak_date = '';
try
    spec2 = hetlearn.load_spec('as07');
    db2 = hetlearn.load_database(spec2);
    R.find_peak_date = dat2char(hetlearn.find_peak(db2, 'pinfobs', qq(2020,1), qq(2024,4)));
    R.load_spec_ok = true;
catch err
    R.load_spec_ok = false;
    R.find_peak_error = err.message;
end
R.peak_pass = strcmp(R.peak_date, R.find_peak_date);
ko = find(strcmp(dstr, R.peak_date));
L{end+1} = '';
L{end+1} = '5. APPLICATION-1 ORIGIN';
L{end+1} = sprintf('CPI inflation peak 2020Q1-2024Q4 (max of pinfobs): %s, %.4f %% a year (%.4f %% q/q); hetlearn.find_peak via load_spec/load_database: %s (same %d)', ...
    R.peak_date, R.peak_value, R.peak_value/4, R.find_peak_date, R.peak_pass);
L{end+1} = sprintf(['Smoothed state at %s: y %.3f, pinf %.3f (annualised %.2f, level %.2f %% a year without me), r %.3f ' ...
    '(level %.2f %% a year), g %.3f, z %.3f'], R.peak_date, getData(f.y, win(kp)), getData(f.pinf, win(kp)), ...
    4*getData(f.pinf, win(kp)), P.piA + 4*getData(f.pinf, win(kp)), getData(f.r, win(kp)), shadow(ko), ...
    getData(f.g, win(kp)), getData(f.z, win(kp)));
R.origin_shocks = cellfun(@(e) getData(f.(e), win(kp)), allShocks);
L{end+1} = sprintf('Smoothed shocks at %s: %s', R.peak_date, strjoin(cellfun(@(e, x) sprintf('%s %.3f', e, x), ...
    allShocks, num2cell(R.origin_shocks), 'UniformOutput', false), ', '));
L{end+1} = sprintf('Data at %s: dy %.3f, pinfobs %.3f, robs %.3f (ffr %.3f)', R.peak_date, getData(d.dy, win(kp)), ...
    getData(d.pinfobs, win(kp)), getData(d.robs, win(kp)), getData(d.ffr, win(kp)));

R.pass = R.param_pass && R.ss_pass && R.bk_pass && R.eig_match && R.irf_hs_pass && R.sign_pass && R.ll_pass ...
    && R.filter_pass && R.peak_pass;
L{end+1} = '';
L{end+1} = sprintf(['OVERALL PASS: %d  (parameters %d, steady state %d, Blanchard-Kahn %d, roots vs gensys %d, ' ...
    'IRFs vs gensys %d, policy-shock signs %d, likelihood vs dsgeliki %d, filter %d, peak %d)'], R.pass, R.param_pass, ...
    R.ss_pass, R.bk_pass, R.eig_match, R.irf_hs_pass, R.sign_pass, R.ll_pass, R.filter_pass, R.peak_pass);

% ---- outputs ---------------------------------------------------------------------------------
fid = fopen(fullfile(here, 'RESULTS.txt'), 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
fprintf('%s\n', L{:});

shockCol = {};  qCol = [];  Y = [];
for j = 1:numel(shocks)
    shockCol = [shockCol; repmat(shocks(j), nPer, 1)]; %#ok<AGROW>
    qCol = [qCol; (1:nPer)']; %#ok<AGROW>
    Y = [Y; IR(:, :, j), HS(:, :, j)]; %#ok<AGROW>
end
Tirf = [table(shockCol, qCol, 'VariableNames', {'shock', 'quarter'}), ...
    array2table(Y, 'VariableNames', [names, strcat(names, '_hs')])];
writetable(Tirf, fullfile(here, 'irfs.csv'));

out = struct();
for n = [xList(:); eList(:)]'
    out.(n{1}) = f.(n{1});
end
out.shadow_rate_ann = Series(range(1), shadow);
databank.toCSV(out, fullfile(here, 'smoothed_history.csv'), range, 'Format', '%.17g');
end
