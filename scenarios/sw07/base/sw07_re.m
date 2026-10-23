function cfg = sw07_re()
%SW07_RE  Parent of every SW07 scenario: forecast from the 2022Q2 inflation peak, rational expectations.
%
%   cfg = sw07_re()
%
%   Every scenario in scenarios/sw07/ inherits from this file (directly, or
%   through sw07_learn.m). It returns a PARTIAL option tree; hetlearn.run merges
%       hetlearn.defaults()  <  config/master_options.m  <  this cfg.
%   The commented lines list every other option at the value a scenario
%   inherits: the project baseline of config/master_options.m where it sets
%   one (marked "master", with the hetlearn.defaults value), else the default.
%   Leave them commented to inherit; uncomment a line to change it for this
%   scenario and everything that inherits from it. Unknown field names are an
%   error. Run with:  res = hetlearn.run(sw07_re());
%
%   The project baseline (config/master_options.m): the published SW07 (2007)
%   parameters, RE agents and learners on t-1 information, RE states of the
%   history from the one-sided filter, KOZ gain (Kostyshyna, Ozden and Zhang
%   2024) from 0.05, chi 2, memory 0.8, facility 'alm'.
%
%   Inflation is in the heterogeneous block (expectations.variables =
%   {'pinf'}), but with mode 'rational' every agent is RE (n1_pinf = 1), so the
%   run is the RE model with information up to t-1 for inflation (the RE(t-1)
%   model, expectations.re_info = 'lagged'; the learning set {'pinf'} is what
%   'lagged' dates at t-1); beliefs and shares are tracked as diagnostics.

cfg = struct();

% ---- identification ------------------------------------------------------------------------
cfg.id = 'sw07_re';                           % results go to results/<id>/; use the file name
cfg.title = 'Forecast from the 2022Q2 inflation peak, rational expectations';
cfg.description = 'Unconditional forecast (zero future shocks) from the 2022Q2 inflation peak; every agent rational.';
cfg.model = 'sw07';                           % model package models/sw07/
% cfg.model_params = 'sw07_params_original';  % master: published SW07 mode 1966-2004; '' = spec.params (sw07_params, the package's second parameter set; the default)

% ---- forecast origin and horizon -----------------------------------------------------------
% The origin is the quarter of peak q/q GDP-deflator inflation (pinfobs) in 2020Q1-2024Q4.
spec = hetlearn.load_spec(cfg.model);
db = hetlearn.load_database(spec);
origin = hetlearn.find_peak(db, 'pinfobs', qq(2020, 1), qq(2024, 4));
assert(hetlearn.util.date_eq(origin, qq(2022, 2)), ...
    'sw07_re: expected the inflation peak in 2022Q2, found %s.', char(dat2str(origin)));
cfg.forecast.origin = origin;                 % last quarter of data used
cfg.forecast.horizon = 16;                    % quarters: 2022Q3-2026Q2

% ---- expectations --------------------------------------------------------------------------
cfg.expectations.mode = 'rational';           % 'rational' | 'learning' (all learners) | 'fixed_shares' | 'switching'
cfg.expectations.variables = {'pinf'};        % forward-looking variables in the RE/BR mix, or 'all' (12 in SW07)
% cfg.expectations.re_variant = 'anchored';   % master (= default): 'anchored' (RE agents use the pure-RE forecast) | 'model_consistent'
% cfg.expectations.re_info = 'lagged';        % master (default 'current'): 'current' (E_t x_{t+1}) | 'lagged' (E_{t-1} x_{t+1}: RE agents see data up to t-1)

% ---- beliefs of the BR (adaptive learning) agents ------------------------------------------
% cfg.beliefs.update = 'rls';                 % 'rls' (RLS with the gain below) | 'fixed'
% cfg.beliefs.info = 'lagged';                % master (= default): 'lagged' (data up to t-1) | 'current' (period t, IJCB eq. 12)
% cfg.beliefs.plm.default = 'ar1';            % master (= default): 'ar1' | 'ar2' | 'ar1_noconst' | 'var1' (VAR(1) over the learning set)
% cfg.beliefs.plm.by_var.pinf = struct('regressors', {{'pinf{-1}', 'ygap{-1}', 'r{-1}'}}, 'constant', true);   % default: none
% cfg.beliefs.plm.derived.ygap = 'y - yf';    % derived regressor (linear expression); default: none
% cfg.beliefs.plm.var = struct('variables', {{}}, 'lags', 1, 'constant', true);   % VAR members (cellstr or 'learning'); {} = no VAR
% cfg.beliefs.init.method = 're_moments';     % 're_moments' | 'training_ols' | 'user'
% cfg.beliefs.init.date = [];                 % [] = first filter date + 4 quarters (1966Q1)
% cfg.beliefs.init.values = struct();         % 'user': values.<x>.alpha/.beta (or .phi), optional .R
% cfg.beliefs.init.training_range = [];       % 'training_ols': [start, end]

% ---- gain (IJCB eq. 13; endogenous gain: Kostyshyna, Ozden and Zhang 2024, eq. 9) ----------
% cfg.gain.rule = 'koz';                      % master (default 'constant'): 'constant' | 'koz'
% cfg.gain.value = 0.05;                      % master (default 0.0585, IJCB posterior mean): constant gain; start of 'koz'
% cfg.gain.by_var = struct();                 % e.g. by_var.pinf = 0.02
% cfg.gain.koz.mu = 0.001;                    % 'koz': step size of the gain process (0 = constant gain)
% cfg.gain.koz.gamma0 = [];                   % 'koz': initial gain; [] = gain.value
% cfg.gain.koz.Rg0 = 0;                       % 'koz': initial Rg
% cfg.gain.koz.bounds = [0.001 0.25];         % 'koz': the gain stays inside (gain_bound events)
% cfg.gain.koz.error = 'rls';                 % 'koz': 'rls' (PLM one-step residual) | 'forecast' (x_t - f^BR_{t-1})
% cfg.gain.koz.error_scale = 1;               % 'koz': factor on the error (1 = model units, % per quarter)
% cfg.gain.koz.structure = 'common';          % 'koz': 'common' (one process) | 'per_variable'
% cfg.gain.koz.master = '';                   % 'koz' common: '' = the first learning variable

% ---- population shares and switching (IJCB eqs. 14-15) -------------------------------------
% cfg.shares.structure = 'per_variable';      % 'per_variable' | 'universal'
% cfg.shares.master = {};                     % 'universal' only: variables whose squared errors drive the share
% cfg.shares.init_n2 = 0.5;                   % master (= default): initial share of BR agents at beliefs.init.date
% cfg.shares.fixed_n2 = [];                   % mode 'fixed_shares': scalar or struct by variable
% cfg.switching.rule = 'discrete_choice';
% cfg.switching.intensity = 2;                % master (default 0.51, IJCB estimate on % per quarter data): chi
% cfg.switching.memory = 0.8;                 % master (default 0.6): omega

% ---- projection facility (the only stabilizing device) ------------------------------------
% cfg.projection.facility = 'alm';            % master (default 'plm_alm'): 'plm_alm' (PLM blocks, then the ALM) | 'alm' (ALM only) | 'none'

% ---- history stage ---------------------------------------------------------------------------
% cfg.history.learn = true;                   % false: the initial beliefs apply at the origin
% cfg.history.mode = 're_smoother';           % 're_smoother' | 'inversion' (history backed out with the learning model)
% cfg.history.re_states = 'filtered';         % master (default 'smoothed'): 're_smoother': RE forecasts and learners' data smoothed (two-sided) | 'filtered' (data up to t)
% cfg.history.inversion.start = [];           % 'inversion': [] = beliefs.init.date
% cfg.history.inversion.shocks = {};          % 'inversion': endogenized shocks; {} = every transition shock
% cfg.history.realtime = false;               % true: RE filter on data up to the origin only

% ---- shocks over the horizon (all unanticipated) -------------------------------------------
% cfg.shocks.source = 'none';                 % 'none' | 'smoothed' (RE-smoothed shocks)
% cfg.shocks.range = [];                      % [] = the horizon
% cfg.shocks.exclude = {};                    % e.g. {'em'}
% cfg.shocks.add = {};                        % e.g. {{'em', qq(2022,3), 0.25}}: name, dates, values added on top

% ---- conditions (exogenize a variable, endogenize a shock) ----------------------------------
% cfg.conditions = struct('variable', 'ms', 'shock', 'em', ...
%     'dates', [qq(2022, 3), qq(2023, 2)], 'values', -0.25, ...
%     'type', 'delta', 'reference', 'self');  % default: none; 'level' | 'delta'; 'self' | scenario id

% ---- density forecasts: shock draws on top of the scenario ---------------------------------
% cfg.density.enabled = false;
% cfg.density.shocks = {};                    % shocks drawn (required when enabled), e.g. {'epinf', 'ew'}
% cfg.density.sigma = 'calibrated';           % 'calibrated' (model std_<shock>) | 'smoothed'
% cfg.density.sigma_range = [];               % [] = the filter range
% cfg.density.method = 'normal';              % 'normal' | 'bootstrap' (whole dates of smoothed shocks)
% cfg.density.demean = true;                  % bootstrap: demean the pool first
% cfg.density.ndraws = 200;
% cfg.density.seed = 0;
% cfg.density.quantiles = [0.05 0.16 0.5 0.84 0.95];
% cfg.density.range = [];                     % [] = the horizon
% cfg.density.keep_draws = false;
% cfg.density.fast_path = true;               % 'rational' without conditions: one simulation per draw

% ---- monetary policy: the model's Taylor rule or Ramsey ------------------------------------
% cfg.policy.mode = 'rule';                   % 'rule' | 'ramsey' (needs spec.policy)
% cfg.policy.type = 'commitment';             % 'commitment' | 'discretion' (indeterminate on SW07)
% cfg.policy.loss = struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0);   % weights; replaced as a whole, not merged
% cfg.policy.discount = [];                   % [] = spec.policy.discount; or a number in (0, 1]
% cfg.policy.loss_horizon = [];               % [] = forecast.horizon; longer = zero-shock continuation

% ---- engine ----------------------------------------------------------------------------------
% cfg.engine.step = 'fast';                   % 'fast' (= IRIS to ~1e-12) | 'iris' (IRIS simulate)
% cfg.engine.conditions_weighting = 'std';    % more shocks than targets: min norm in std units | 'none'

% ---- comparisons and reporting ---------------------------------------------------------------
% cfg.compare_with = {};                      % ids; writes compare_<id>.csv (this minus that, observables)
% cfg.report.variables = {};                  % reserved for reports
end
