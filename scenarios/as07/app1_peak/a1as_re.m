function cfg = a1as_re()
%A1AS_RE  AS07 application 1: forecast from the 2022Q2 CPI inflation peak, rational expectations.
%
%   cfg = a1as_re()
%
%   The small New Keynesian model of An and Schorfheide (2007), package
%   models/as07/, at the published posterior means of Herbst and Schorfheide
%   (2016, Ch. 4 slides, "Posterior Estimates of DSGE Model Parameters") and
%   the replication code's measurement errors. Unconditional forecast (zero
%   shocks) over 16 quarters from the quarter of peak CPI inflation in
%   2020Q1-2024Q4. Inflation enters the heterogeneous block
%   (expectations.variables = {'pinf'}), but with mode 'rational' every
%   agent is RE, so the forecast is the RE model's; learning states still
%   run as diagnostics. a1as_learn.m inherits from this file.
%
%   Returns a PARTIAL option tree; hetlearn.run merges
%       hetlearn.defaults()  <  config/master_options.m  <  this cfg.
%   Run with:  res = hetlearn.run(a1as_re());
%
%   Units (models/as07/README.md, "Units"): the model variable pinf is in
%   percent per quarter, as in SW07 and IJCB3; the observable pinfobs is
%   annualised (the book's INFL = piA + 4*pinf), so pinfobs at the origin is
%   4 x the q/q rate. The RE forecast reverts to the steady state of the
%   book's 1983Q1-2002Q4 sample: inflation piA = 3.3% and a funds rate of
%   5.8% a year (README.md, "Open issues").

cfg = struct();

% ---- identification ----------------------------------------------------------------
cfg.id = 'a1as_re';                           % results go to results/<id>/
cfg.title = 'AS07: forecast from the 2022Q2 CPI inflation peak, rational expectations';
cfg.description = ['Unconditional forecast (zero shocks) from the 2022Q2 peak of CPI ' ...
    'inflation in the An-Schorfheide (2007) small NK model (Herbst-Schorfheide posterior means); all agents rational.'];
cfg.model = 'as07';                           % folder models/as07/

% ---- forecast origin and horizon -------------------------------------------------------
% The origin is the quarter of peak CPI inflation (pinfobs, % a year) in
% 2020Q1-2024Q4: 2022Q2, 9.30% a year (2.32% q/q), FRED vintage 2026-09-29.
spec = hetlearn.load_spec(cfg.model);
db = hetlearn.load_database(spec);
origin = hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4));
assert(strcmp(dat2char(origin), dat2char(qq(2022, 2))), ...
    'a1as_re: expected the CPI inflation peak in 2022Q2, found %s.', dat2char(origin));
cfg.forecast.origin = origin;                 % last quarter of data used
cfg.forecast.horizon = 16;                    % quarters: 2022Q3-2026Q2

% ---- expectations ------------------------------------------------------------------------
cfg.expectations.mode = 'rational';           % 'rational' | 'learning' | 'fixed_shares' | 'switching'
cfg.expectations.variables = {'pinf'};        % forward-looking variables: y, pinf
% cfg.expectations.re_variant = 'anchored';  % toolbox default since 2026-10-18; with every agent RE,
%                                             % 'anchored' and 'model_consistent' give the same path

% ---- shocks over the horizon ----------------------------------------------------------------
% cfg.shocks.source = 'none';                 % zero shocks over the horizon

% ---- comparisons and reporting ----------------------------------------------------------------
% cfg.compare_with = {};
end
