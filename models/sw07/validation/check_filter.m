function R = check_filter()
% CHECK_FILTER  IRIS Kalman filter/smoother of sw07 on the 1965Q1-2026Q2 database.
%
% Reads  data/sw07_database.csv (build_database.m)
% Writes validation/smoothed_history.csv: smoothed transition variables and
%        shocks, 1965Q1-2026Q2
% Pass: smoothed observables equal the data (max abs error < 1e-8); the model
% has no measurement errors, so this must hold. Default IRIS initial
% conditions (asymptotic distribution; all variables are stationary). The
% Dynare estimation instead used presample=4 and lik_init=2, which only
% changes the first few quarters. Needs IRIS on the path.

here = fileparts(mfilename('fullpath'));
pkg = fileparts(here);
addpath(pkg);
tol = 1e-8;

spec = model_spec();
m = Model.fromFile(fullfile(pkg, spec.model_file), 'linear', spec.linear);
m = assign(m, feval(spec.params));
[m, flag] = solve(m);
assert(hasSucceeded(flag), 'IRIS solve failed');
m = sstate(m);

d = databank.fromCSV(fullfile(pkg, spec.database));
range = spec.filter_range(1):spec.filter_range(2);
[~, f] = filter(m, d, range, 'output', 'smooth', 'meanOnly', true);

% smoothed observables must reproduce the data
R.fit_error = 0;
for i = 1:numel(spec.observables)
    o = spec.observables{i};
    e = max(abs(getData(f.(o), range) - getData(d.(o), range)));
    R.fit_error = max(R.fit_error, e);
end
% IRIS copies observed data into the smoothed measurement variables, so the
% test above is mechanical. The real test rebuilds each observable from the
% smoothed transition variables through the measurement equations.
P = feval(spec.params);
rng2 = range(2:end);    % growth observables need the lag
rebuilt = { ...
    'dy',      f.y - f.y{-1} + P.ctrend,       rng2; ...
    'dc',      f.c - f.c{-1} + P.ctrend,       rng2; ...
    'dinve',   f.inve - f.inve{-1} + P.ctrend, rng2; ...
    'dw',      f.w - f.w{-1} + P.ctrend,       rng2; ...
    'labobs',  f.lab + P.constelab,            range; ...
    'pinfobs', f.pinf + P.constepinf,          range; ...
    'robs',    f.r + real(m.robs),             range};
R.fit_error_equations = 0;
for i = 1:size(rebuilt, 1)
    o = rebuilt{i, 1};
    rr = rebuilt{i, 3};
    e = max(abs(getData(rebuilt{i, 2}, rr) - getData(d.(o), rr)));
    R.fit_error_equations = max(R.fit_error_equations, e);
end
R.pass = R.fit_error < tol && R.fit_error_equations < tol;

% save smoothed transition variables and shocks
xList = cellstr(get(m, 'xList'));
eList = cellstr(get(m, 'eList'));
out = struct();
for n = [xList(:); eList(:)]'
    out.(n{1}) = f.(n{1});
end
databank.toCSV(out, fullfile(here, 'smoothed_history.csv'), range, 'Format', '%.17g');

% numbers for RESULTS.md
gap = f.y - f.yf;
R.gap_2022Q2 = getData(gap, qq(2022,2));
R.gap_2026Q2 = getData(gap, qq(2026,2));
win = qq(2021,1):qq(2022,4);
R.window = dat2str(win);
R.em = getData(f.em, win);
R.epinf = getData(f.epinf, win);
R.ms = getData(f.ms, win);

fprintf(['check_filter: %d quarters, smoothed observables vs data max abs error %.3g, ' ...
    'observables rebuilt from smoothed states %.3g, PASS = %d\n'], ...
    numel(range), R.fit_error, R.fit_error_equations, R.pass);
fprintf('output gap y - yf: 2022Q2 %.4f, 2026Q2 %.4f\n', R.gap_2022Q2, R.gap_2026Q2);
fprintf('%-8s %10s %10s %10s\n', 'quarter', 'em', 'epinf', 'ms');
for t = 1:numel(win)
    fprintf('%-8s %10.4f %10.4f %10.4f\n', R.window{t}, R.em(t), R.epinf(t), R.ms(t));
end
fprintf('std: em %.4f, epinf %.4f\n', m.std_em, m.std_epinf);

end
