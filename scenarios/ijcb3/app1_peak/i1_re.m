function cfg = i1_re()
%I1_RE  IJCB3 application 1: forecast from the 2022Q2 CPI inflation peak, rational expectations.
%
%   cfg = i1_re()
%
%   The three-equation NK model of Ozden (2025, IJCB), package models/ijcb3/,
%   at the posterior means of IJCB's heterogeneous-expectations model.
%   Unconditional forecast (zero shocks) over 16 quarters from the quarter of
%   peak q/q CPI inflation in 2020Q1-2024Q4. Inflation enters the
%   heterogeneous block (expectations.variables = {'pinf'}), but with mode
%   'rational' every agent is RE, so the forecast is the RE model's; learning
%   states still run as diagnostics. i1_learn.m inherits from this file.
%
%   Returns a PARTIAL option tree; hetlearn.run merges
%       hetlearn.defaults()  <  config/master_options.m  <  this cfg.
%   Commented lines show the knobs where IJCB's setup differs from the
%   defaults; see scenarios/sw07/base/sw07_re.m for the full list.
%   Run with:  res = hetlearn.run(i1_re());
%
%   Output gap (models/ijcb3/data/README.md): yobs is the Hamilton gap with
%   coefficients from IJCB's 1957Q1-2019Q4 sample and covid-adjusted
%   regressors, 1.00 at the 2022Q2 origin. The plain Hamilton gap (helper
%   series yobs_hamilton, not observed) is 9.0 there, an echo of the 2020Q2
%   lockdown trough (user decisions 2026-10-18).

cfg = struct();

% ---- identification ----------------------------------------------------------------
cfg.id = 'i1_re';                             % results go to results/<id>/
cfg.title = 'IJCB3: forecast from the 2022Q2 CPI inflation peak, rational expectations';
cfg.description = ['Unconditional forecast (zero shocks) from the 2022Q2 peak of CPI ' ...
    'inflation in the IJCB three-equation NK model (HE posterior means); all agents rational.'];
cfg.model = 'ijcb3';                          % folder models/ijcb3/

% ---- forecast origin and horizon -------------------------------------------------------
% The origin is the quarter of peak q/q CPI inflation (pinfobs) in 2020Q1-2024Q4:
% 2022Q2, 2.32% q/q (9.3% annualised), FRED vintage 2026-09-29.
spec = hetlearn.load_spec(cfg.model);
db = hetlearn.load_database(spec);
origin = hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4));
assert(strcmp(dat2char(origin), dat2char(qq(2022, 2))), ...
    'i1_re: expected the CPI inflation peak in 2022Q2, found %s.', dat2char(origin));
cfg.forecast.origin = origin;                 % last quarter of data used
cfg.forecast.horizon = 16;                    % quarters: 2022Q3-2026Q2

% ---- expectations ------------------------------------------------------------------------
cfg.expectations.mode = 'rational';           % 'rational' | 'learning' | 'fixed_shares' | 'switching'
cfg.expectations.variables = {'pinf'};        % forward-looking variables: y, pinf
% cfg.expectations.re_variant = 'anchored';  % toolbox default since 2026-10-18; with every agent RE,
%                                             % 'anchored' and 'model_consistent' give the same path

% ---- settings pinned against the SW07 project baseline of 2026-10-20 ------------------------
% config/master_options.m now sets the SW07 baseline (published SW07 parameters, KOZ gain, t-1
% RE information, filtered RE states, no facility). This application keeps the settings it was
% run with on 2026-10-18 (results/i1_re, i1_learn; report section 12), so they are written out:
cfg.model_params = '';                        % the package's own parameters (ijcb3_params, IJCB Table 1)
cfg.gain.rule = 'constant';
cfg.expectations.re_info = 'current';
cfg.history.re_states = 'smoothed';
cfg.projection.facility = 'plm_alm';
cfg.gain.value = 0.0585;                      % the previous master calibration (i1_learn sets its own values)
cfg.switching.memory = 0.6;
cfg.switching.intensity = 0.51;
cfg.shares.init_n2 = 0.5;

% ---- where IJCB's learning setup differs from the defaults (not switched on) ---------------
% cfg.beliefs.info = 'current';               % IJCB eq. 12: t-timing, E_t x_{t+1} = alpha + beta*x_t
% cfg.beliefs.plm.default = 'var1';           % IJCB eq. 12: VAR(1) PLM over y, pinf, r (all three learn there)
% cfg.shares.structure = 'universal';         % IJCB eq. 14: one share for both rules ...
% cfg.shares.master = {'pinf', 'y'};          % ... driven by the summed squared errors of inflation and the gap
%                                             %     (each must also be in expectations.variables)
% cfg.gain.value = 0.0585;                    % IJCB Table 1, HE: set in i1_learn
% cfg.switching.memory = 0.62;                % IJCB Table 1, HE: set in i1_learn
% cfg.switching.intensity = 0.51;             % IJCB Table 1, HE: set in i1_learn (data in IJCB's units)

% ---- shocks over the horizon ----------------------------------------------------------------
% cfg.shocks.source = 'none';                 % zero shocks over the horizon

% ---- comparisons and reporting ----------------------------------------------------------------
% cfg.compare_with = {};
end
