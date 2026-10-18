function R = check_irfs()
% CHECK_IRFS  IRIS srf of sw07.model at sw07_params against Dynare swX1 IRFs.
%
% Reads  validation/dynare_irfs_swX1.csv (export_dynare_dr_irfs.py on
%        C:\dynare_work\sw_ext\swX1_out.mat, 1-sd shocks, 40 periods)
% Writes validation/irf_comparison.csv (shock, variable, peak_abs, max_abs_diff)
% Pass: max_abs_diff < 1e-10 for every shock and every transition variable.
%
% IRIS srf uses Size=@auto by default, i.e. each shock is set to its std dev
% in the model (Legacy/@model/srf.m), so both sides are 1-sd impulses hitting
% in period 1. Needs IRIS on the path.

here = fileparts(mfilename('fullpath'));
pkg = fileparts(here);
addpath(pkg);
tol = 1e-10;
nPer = 40;

spec = model_spec();
m = Model.fromFile(fullfile(pkg, spec.model_file), 'linear', spec.linear);
m = assign(m, feval(spec.params));
[m, flag] = solve(m);
assert(hasSucceeded(flag), 'IRIS solve failed');
m = sstate(m);

xList = cellstr(get(m, 'xList'));
yList = cellstr(get(m, 'yList'));
eList = cellstr(get(m, 'eList'));

% steady-state check: robs = conster (Dynare steady_state_model formula)
P = feval(spec.params);
consterDynare = (((1+P.constepinf/100)/((1/(1+P.constebeta/100))*(1+P.ctrend/100)^(-P.csigma)))-1)*100;
R.ss_robs_diff = abs(real(m.robs) - consterDynare);
R.ss_dy_diff = abs(real(m.dy) - P.ctrend);
fprintf('steady state: robs IRIS %.15g vs Dynare formula %.15g (diff %.3g); dy diff %.3g\n', ...
    real(m.robs), consterDynare, R.ss_robs_diff, R.ss_dy_diff);

% IRIS responses
s = srf(m, 1:nPer);
fprintf('srf output: %d rows x %d columns for y; std_em in model %.15g\n', ...
    size(s.y.Data, 1), size(s.y.Data, 2), m.std_em);

% Dynare responses: name = <variable>_<shock>
D = readtable(fullfile(here, 'dynare_irfs_swX1.csv'), 'TextType', 'string');
under = strlength(D.name) - strlength(extractAfter(D.name, regexpPattern('.*_')));
D.variable = extractBefore(D.name, under);
D.shock = extractAfter(D.name, under);
dynVars = unique(D.variable, 'stable');

rows = {};
maxMeas = 0;
nCompared = 0;
for j = 1:numel(eList)
    sh = eList{j};
    for listType = 1:2
        if listType == 1, names = xList; else, names = yList; end
        for i = 1:numel(names)
            v = names{i};
            if ~any(dynVars == v), continue; end
            X = s.(v).Data;
            xi = X(end-nPer+1:end, j);
            sel = D.variable == v & D.shock == sh;
            [~, ord] = sort(D.period(sel));
            dv = D.value(sel);
            dv = dv(ord);
            assert(numel(dv) == nPer, 'Dynare IRF %s_%s has %d periods', v, sh, numel(dv));
            md = max(abs(xi - dv));
            if listType == 1
                rows(end+1, :) = {sh, v, max(abs(dv)), md}; %#ok<AGROW>
                nCompared = nCompared + 1;
            else
                maxMeas = max(maxMeas, md);
            end
        end
    end
end

T = cell2table(rows, 'VariableNames', {'shock', 'variable', 'peak_abs', 'max_abs_diff'});
writetable(T, fullfile(here, 'irf_comparison.csv'));

missing = setdiff(xList, cellstr(dynVars));
R.n_shocks = numel(eList);
R.n_transition_compared = nCompared / numel(eList);
R.missing_in_dynare = missing;
R.max_abs_diff = max(T.max_abs_diff);
R.max_abs_diff_measurement = maxMeas;
[~, iw] = max(T.max_abs_diff);
R.worst = sprintf('%s to %s', T.variable{iw}, T.shock{iw});
R.max_peak = max(T.peak_abs);
R.pass = R.max_abs_diff < tol;
fprintf(['check_irfs: %d shocks x %d transition variables x %d periods; max abs diff %.3g ' ...
    '(worst %s); measurement variables %.3g; largest |IRF| %.3g; PASS = %d\n'], ...
    R.n_shocks, R.n_transition_compared, nPer, R.max_abs_diff, R.worst, ...
    R.max_abs_diff_measurement, R.max_peak, R.pass);
if ~isempty(missing)
    fprintf('IRIS transition variables not in the Dynare file: %s\n', strjoin(missing, ', '));
end

end
