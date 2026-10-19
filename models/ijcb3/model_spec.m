function spec = model_spec()
% MODEL_SPEC  Package contract for the three-equation NK model of Ozden (2025, IJCB).
%
% See docs/USER_GUIDE.md sec. 4.6 and README.md. Paths are relative to
% spec.folder. Needs IRIS on the path (qq).

spec = struct();
spec.name = 'ijcb3';
spec.folder = fileparts(mfilename('fullpath'));
spec.model_file = 'ijcb3.model';
spec.params = 'ijcb3_params';
spec.sstate = '';
spec.linear = true;
spec.assign = struct();
spec.database = 'data/ijcb3_database.csv';
% IJCB's likelihood starts in 1960Q1 (burn-in 1957Q1-1959Q4, which the
% database also holds). robs is NaN in the 36 ELB quarters, where the filter
% infers the shadow rate.
spec.filter_range = [qq(1960,1), qq(2026,2)];
spec.observables = {'yobs', 'pinfobs', 'robs'};

% spec.policy is left out for now (no Ramsey runs yet). When it is needed:
% instrument 'r'; rule_label 'Monetary policy rule, Taylor rule with smoothing
% (IJCB eq. 1)'; targets in annualised percent, e.g. pinf: '4*pinf', ygap: 'y',
% r: '4*r'; discount 'beta' (the discount on expected inflation in the
% Phillips curve).

% Reporting: model units are % per quarter for pinfobs and robs, percent of
% trend output for yobs; reports multiply by scale.
report = struct();
report.labels = struct( ...
    'yobs',    'Output gap (Hamilton filter, covid-adjusted)', ...
    'pinfobs', 'Inflation (CPI)', ...
    'robs',    'Federal funds rate');
report.units = struct( ...
    'yobs',    '% of trend output (100 x log)', ...
    'pinfobs', '% q/q annualised', ...
    'robs',    '% annualised');
report.scale = struct('yobs', 1, 'pinfobs', 4, 'robs', 4);
spec.report = report;

end
