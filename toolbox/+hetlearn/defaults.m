function o = defaults()
%DEFAULTS  Full hetlearn option tree with default values (DESIGN sec. 6.3).
%
%   o = hetlearn.defaults()
%
%   Output
%     o   struct, the complete option tree. Every option a scenario file or
%         config/master_options.m may set is a field of this tree; any other
%         field name is rejected by hetlearn.load_options.
%
%   Precedence: hetlearn.defaults() < config/master_options.m < scenario cfg.
%
%   Defaults that mean "resolved later by the engine":
%     forecast.origin = []         must be set by the scenario
%     beliefs.init.date = []       first filter date + 4 quarters
%     beliefs.init.training_range = []   required for method 'training_ols'
%     shares.master = {}           required for shares.structure 'universal'
%     shares.fixed_n2 = []         required for mode 'fixed_shares'
%     shocks.range = []            the forecast horizon
%     report.variables = {}        spec.observables
%     gain.koz.gamma0 = []         gain.value (per_variable: gain.by_var.<x> where set)
%     gain.koz.master = ''         the first learning variable (structure 'common')
%
%   Free-form subtrees (merged but not validated by load_options):
%     beliefs.init.values, beliefs.plm.by_var, beliefs.plm.derived (checked
%     to hold strings), gain.by_var, shares.fixed_n2 (when a struct),
%     conditions, shocks.add, report.
%
%   See also hetlearn.load_options.

o = struct();

% Identification
o.id = '';
o.title = '';
o.description = '';
o.model = '';

% Forecast
o.forecast = struct( ...
    'origin', [], ...          % date: last period of data used
    'horizon', 16);            % number of forecast periods

% Expectations
o.expectations = struct( ...
    'mode', 'rational', ...    % 'rational' | 'learning' | 'fixed_shares' | 'switching'
    'variables', {{}}, ...     % cellstr of forward-looking variables, or 'all'
    're_variant', 'anchored');   % 'anchored' (baseline since 2026-10-18) | 'model_consistent' (DESIGN 11)

% Beliefs
o.beliefs = struct();
o.beliefs.update = 'rls';      % 'rls' | 'fixed'
o.beliefs.info = 'lagged';     % BR information set: 'lagged' (data up to t-1) | 'current' (period t, IJCB eq. 12)
o.beliefs.plm = struct( ...
    'default', 'ar1', ...      % 'ar1' | 'ar2' | 'ar1_noconst' | 'var1' (VAR(1) over the learning set)
    'by_var', struct(), ...    % free-form: by_var.<x>.regressors, .constant
    'derived', struct(), ...   % free-form: derived.<name> = 'linear expression' (DESIGN 12)
    'var', struct('variables', {{}}, ...   % VAR members: cellstr or 'learning'; {} = no VAR
        'lags', 1, 'constant', true));
o.beliefs.init = struct( ...
    'method', 're_moments', ...    % 're_moments' | 'training_ols' | 'user'
    'date', [], ...                % [] = first filter date + 4 quarters
    'values', struct(), ...        % free-form: values.<x>.alpha/.beta/.phi/.R
    'training_range', []);

% Gain
o.gain = struct( ...
    'rule', 'constant', ...    % function hetlearn.gain.<rule>: 'constant' | 'koz' (endogenous, DESIGN 18)
    'value', 0.0585, ...
    'by_var', struct());       % free-form: by_var.<x> = gain
o.gain.koz = struct( ...       % gain.rule = 'koz': Kostyshyna, Ozden and Zhang (2024), eq. (9)
    'mu', 0.001, ...           % step size of the gain process ("gain on the gain"), >= 0 (0 = constant)
    'gamma0', [], ...          % initial gain; [] = gain.value (per_variable: gain.by_var.<x> where set)
    'Rg0', 0, ...              % initial Rg (the paper is silent)
    'bounds', [0.001 0.25], ...    % [lower upper] projection interval of the gain, inside (0, 1]
    'error', 'rls', ...        % signed error: 'rls' (one-step PLM residual) | 'forecast' (x_t - f^BR_{t-1})
    'error_scale', 1, ...      % errors times this first (SW07 KOZ scenarios: 4, annualised percent)
    'structure', 'common', ... % 'common' (one process, KOZ fn. 7) | 'per_variable' (one per PLM equation)
    'master', '');             % common: '' = first learning variable; name or cellstr (mean of their errors)

% Shares
o.shares = struct( ...
    'structure', 'per_variable', ...   % 'per_variable' | 'universal'
    'master', {{}}, ...                % name or cellstr (universal only)
    'init_n2', 0.5, ...                % initial share of BR agents
    'fixed_n2', []);                   % scalar or struct by variable (fixed_shares)

% Switching (IJCB eqs. 14-15)
o.switching = struct( ...
    'rule', 'discrete_choice', ...
    'intensity', 0.51, ...     % chi (IJCB estimate on quarterly data; user decision 2026-10-18, was 8)
    'memory', 0.6);            % omega (switching.error_scale removed 2026-10-18)

% Projection facility
o.projection = struct( ...
    'facility', 'plm_alm');    % 'plm_alm' (PLM blocks, then the ALM) | 'alm' (ALM only) | 'none' (DESIGN 4.4)

% History stage
o.history = struct( ...
    'learn', true, ...
    'mode', 're_smoother', ... % 're_smoother' | 'inversion' (DESIGN 15)
    'realtime', false, ...     % true: RE filter on data up to the origin only (DESIGN 17)
    'inversion', struct( ...   % history.mode = 'inversion' only
        'start', [], ...       % [] = beliefs.init.date
        'shocks', {{}}));      % endogenised shocks; {} = every transition shock

% Shocks over the forecast horizon
o.shocks = struct( ...
    'source', 'none', ...      % 'none' | 'smoothed'
    'range', [], ...
    'exclude', {{}}, ...
    'add', {{}});              % free-form: {{name, dates, values}, ...}

% Conditions (exogenise/endogenise pairs, DESIGN 5.5): empty struct array
o.conditions = struct('variable', {}, 'shock', {}, 'dates', {}, ...
    'values', {}, 'type', {}, 'reference', {});

% Density forecasts (DESIGN 14): shock draws on top of the scenario
o.density = struct( ...
    'enabled', false, ...
    'shocks', {{}}, ...        % cellstr of shocks drawn (required when enabled)
    'sigma', 'calibrated', ... % 'calibrated' (model std_<shock>) | 'smoothed'
    'sigma_range', [], ...     % [] = the filter range ('smoothed', 'bootstrap')
    'method', 'normal', ...    % 'normal' | 'bootstrap' (whole dates of smoothed shocks)
    'ndraws', 200, ...
    'seed', 0, ...
    'quantiles', [0.05 0.16 0.5 0.84 0.95], ...
    'range', [], ...           % [] = the horizon
    'keep_draws', false, ...
    'fast_path', true, ...     % 'rational' without conditions: one simulate per draw
    'demean', true);           % bootstrap: demean the smoothed shocks over sigma_range

% Engine: one-period step from the cached state-space solution or IRIS simulate
o.engine = struct( ...
    'step', 'fast', ...                % 'fast' (= IRIS to ~1e-12, 3-20x faster) | 'iris' (bit-identical IRIS simulate)
    'conditions_weighting', 'std');    % more shocks than targets: min norm in std units ('std') | unweighted ('none')

% Monetary policy (DESIGN 13): the package's rule or Ramsey optimal policy
o.policy = struct( ...
    'mode', 'rule', ...            % 'rule' | 'ramsey' (needs spec.policy)
    'type', 'commitment', ...      % 'commitment' | 'discretion' (Ramsey only)
    'loss', struct('pinf', 1, 'ygap', 0.5, 'r', 0.1, 'dr', 0), ...  % weights by spec.policy.targets name; replaced, not merged
    'discount', [], ...            % [] = spec.policy.discount; or a number in (0, 1]
    'loss_horizon', []);           % [] = forecast.horizon; longer: zero-shock continuation

% Comparisons
o.compare_with = {};

% Reporting (free-form)
o.report = struct('variables', {{}});

end
