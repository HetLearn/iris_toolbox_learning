function spec = model_spec()
% MODEL_SPEC  Package contract for the An-Schorfheide (2007) small NK model, Herbst-Schorfheide (2016) estimates.
%
% See docs/USER_GUIDE.md sec. 4.6 and README.md. Paths are relative to
% spec.folder. Needs IRIS on the path (qq).

spec = struct();
spec.name = 'as07';
spec.folder = fileparts(mfilename('fullpath'));
spec.model_file = 'as07.model';
spec.params = 'as07_params';
spec.sstate = '';
spec.linear = true;
spec.assign = struct();
spec.database = 'data/as07_database.csv';
% The three series exist from 1955Q1 (FEDFUNDS starts in July 1954), but the
% filter starts in 1965Q1, like SW07's, so that histories and comparisons line
% up across packages. The filter starts from the stationary distribution, as
% the book's kalman.m does, so it needs no burn-in; the database also holds
% the presample year 1964. robs is NaN in the 36 ELB quarters, where the
% filter infers the shadow rate.
spec.filter_range = [qq(1965,1), qq(2026,2)];
spec.observables = {'dy', 'pinfobs', 'robs'};

% spec.policy is left out for now (no Ramsey runs yet). When it is needed:
% instrument 'r'; rule_label 'Monetary policy rule, Taylor rule with smoothing
% (AS07)'; targets in annualised percent, e.g. pinf: '4*pinf', ygap: 'y - g'
% (the rule's output gap), r: '4*r'; discount '$beta$' (substitution
% 1/(1 + rA/400) in as07.model).

% Reporting: dy is in % per quarter, pinfobs and robs in % a year (the book's
% units, README.md "Units"); reports multiply by scale, so scale 4 annualises
% output growth and scale 1 keeps the annualised series.
report = struct();
report.labels = struct( ...
    'dy',      'Output growth, per capita', ...
    'pinfobs', 'Inflation (CPI)', ...
    'robs',    'Federal funds rate');
report.units = struct( ...
    'dy',      '% q/q annualised, per capita', ...
    'pinfobs', '% q/q annualised', ...
    'robs',    '% annualised');
report.scale = struct('dy', 4, 'pinfobs', 1, 'robs', 1);
spec.report = report;

end
