function o = defaults()
%DEFAULTS  Full HetLearn option tree with default values (DESIGN sec. 6.3).
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
%     report.variables = {}        reserved; no toolbox code reads it
%     gain.koz.gamma0 = []         gain.value (per_variable: gain.by_var.<x> where set)
%     gain.koz.master = ''         the first learning variable (structure 'common')
%
%   Free-form subtrees (merged without name checks by load_options):
%     beliefs.init.values, beliefs.plm.by_var, beliefs.plm.derived (checked
%     to hold strings), gain.by_var, shares.fixed_n2 (when a struct),
%     shocks.add, report.
%
%   Replaced as a whole, not merged (the scenario's value replaces the
%   master's or the default): conditions (a struct array, validated by
%   load_options), policy.loss, and the BR options listed below.
%
%   Bounded-rationality extensions (the options marked "BR" below, used by
%   the seven further expectation rules of scenarios/sw07/br_portfolio/).
%   Every one defaults to off, so results are unchanged. load_options validates them; the engine reads all of them.
%   Not supported with N agent types or forecast transforms (an error
%   naming the combination): policy.mode = 'ramsey' and history.mode =
%   'inversion'. docs/USER_GUIDE.md (expectation rules) has examples.
%   Replaced as a whole, not merged: expectations.types,
%   expectations.transforms, shares.init, shares.fixed.
%
%   See also hetlearn.load_options.

o = struct();

% Identification
o.id = '';
o.title = '';
o.description = '';
o.model = '';
o.model_params = '';           % parameter function of the model package for this run, e.g. 'sw07_params_original';
                               %   '' = the package's spec.params (must be a .m file in the package folder)

% Forecast
o.forecast = struct( ...
    'origin', [], ...          % date: last period of data used
    'horizon', 16);            % number of forecast periods

% Expectations
o.expectations = struct( ...
    'mode', 'rational', ...    % 'rational' | 'learning' | 'fixed_shares' | 'switching'
    'variables', {{}}, ...     % cellstr of forward-looking variables, or 'all'
    're_variant', 'anchored', ...  % 'anchored' | 'model_consistent' (DESIGN 11)
    're_info', 'current');     % RE agents' information set for the learning variables: 'current' (E_t x_{t+1})
                               %   | 'lagged' (E_{t-1} x_{t+1}, the RE counterpart of beliefs.info = 'lagged'; DESIGN 19)
% BR, N agent types. Empty = off: the two types RE and BR on the two-type code path. One struct per
% type (a struct array or a cell array of structs); name and kind are required:
%   name       letters and digits, starting with a letter ('RE', 'BR', 'TB', 'IO'): suffix of the forecast
%              x_exp1_<name> and the share n_<name>_x; the type named 'RE' must be of kind 're'
%   kind       're' (the RE type only: expectations.re_variant, .re_info) | 'plm' (a learned PLM, as
%              x_exp1_BR: beliefs.plm, .info, .update, gain) | 'rule' (a fixed linear rule, beliefs.info)
%              | 're_mean' (RE forecast plus a learned mean of its own error; beliefs.update, gain)
%   rule       'rule' only, required: the expression, e.g. '0' or '0.5*x{-1}', or struct('expr',
%              <expression>, 'params', struct of numbers); terms x (the variable), other transition
%              variables, the constants in params; lags >= 1 under 'lagged' information
% Every type forecasts every learning variable. No longer available: kind 'level', the fields variant,
% info, plm, update, gain, base, k, variables, cost, and the rule terms self, mean, dn, re1(...).
o.expectations.types = struct('name', {}, 'kind', {}, 'rule', {});
% BR, forecast transforms. Empty = off. One struct per transform:
%   kind      'multiplier' (m^h, h = 2 for t-1 information) | 'diagnostic' | 'myopia_anchoring'
%   types     'all' (also the model-consistent expectations outside the learning set) | type names;
%             [] = 'all'
%   scope     'learning' (the learning set) | 'all' (every forward-looking variable) | cellstr of
%             variables and 'x@<exact equation label>' entries; [] = 'learning'
%   exclude   cellstr of variables removed from the scope; [] = none
%   value     multiplier: m >= 0 (identity 1); diagnostic: theta (0); myopia_anchoring: [omega_f, b]
%             ([1 0])
% No longer available: kinds 'partial_adjustment' and 'wedge', the fields profile and factor.
o.expectations.transforms = struct('kind', {}, 'types', {}, 'scope', {}, 'exclude', {}, 'value', {});

% Beliefs
o.beliefs = struct();
o.beliefs.update = 'rls';      % 'rls' | 'fixed' ('sac' and 'kf' are no longer available)
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
    'Rg0', 0, ...              % initial Rg (KOZ do not give one)
    'bounds', [0.001 0.25], ...    % [lower upper] projection interval of the gain, inside (0, 1]
    'error', 'rls', ...        % signed error: 'rls' (one-step PLM residual) | 'forecast' (x_t - f^BR_{t-1})
    'error_scale', 1, ...      % errors times this first (1 = the model's units, % per quarter)
    'structure', 'common', ... % 'common' (one process, KOZ fn. 7) | 'per_variable' (one per PLM equation)
    'master', '');             % common: '' = first learning variable; name or cellstr (mean of their errors)

% Shares
o.shares = struct( ...
    'structure', 'per_variable', ...   % 'per_variable' | 'universal'
    'master', {{}}, ...                % name or cellstr (universal only)
    'init_n2', 0.5, ...                % initial share of BR agents
    'fixed_n2', [], ...                % scalar or struct by variable (fixed_shares)
    'init', [], ...                    % BR, N types: struct by type name of initial
    ...                                %   shares in [0, 1], summing to 1 per share group; [] = init_n2 for RE/BR,
    ...                                %   equal shares otherwise; an unlisted RE type gets 0
    'fixed', []);                      % BR, N types, mode 'fixed_shares': struct by type name, as init;
                                       %   [] = fixed_n2 (the two-type shorthand)

% Switching (IJCB eqs. 14-15)
o.switching = struct( ...
    'rule', 'discrete_choice', ...
    'intensity', 0.51, ...     % chi (IJCB estimate on quarterly data, % per quarter)
    'memory', 0.6);            % omega in [0, 1) (switching.error_scale, BR inertia, costs, fitness and
                               %   intensity 'model:bma' are no longer available)

% Projection facility
o.projection = struct( ...
    'facility', 'plm_alm');    % 'plm_alm' (PLM blocks, then the ALM) | 'alm' (ALM only) | 'none' (DESIGN 4.4)

% History stage
o.history = struct( ...
    'learn', true, ...
    'mode', 're_smoother', ... % 're_smoother' | 'inversion' (DESIGN 15) | BR 'kalman' (time-varying Kalman filter of
    ...                        %   the ALM, one-step prediction errors)
    're_states', 'smoothed', ... % 're_smoother' only: RE agents' forecasts and learners' data from the two-sided
    ...                        %   smoother ('smoothed') or the one-sided filter x_{t|t}, data up to t ('filtered'; DESIGN 5.2)
    'realtime', false, ...     % true: RE filter on data up to the origin only (DESIGN 17)
    'inversion', struct( ...   % history.mode = 'inversion' only
        'start', [], ...       % [] = beliefs.init.date
        'shocks', {{}}), ...   % endogenized shocks; {} = every transition shock
    'kalman', struct( ...      % BR, history.mode = 'kalman' only
        'init', 'stochastic'));   % 'stochastic' (asymptotic distribution, as IRIS) | 'smoothed' (P0 = 0 at the
                                  %   RE-smoothed state before the start)

% Shocks over the forecast horizon
o.shocks = struct( ...
    'source', 'none', ...      % 'none' | 'smoothed'
    'range', [], ...
    'exclude', {{}}, ...
    'add', {{}});              % free-form: {{name, dates, values}, ...}

% Conditions (exogenize/endogenize pairs, DESIGN 5.5): empty struct array
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
    'step', 'fast', ...                % 'fast' (= IRIS to ~1e-12; 2-3x faster, ~20x with observables exogenized) | 'iris' (IRIS simulate)
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
