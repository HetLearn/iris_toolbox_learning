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
%     report.variables = {}        reserved; no toolbox code reads it
%     gain.koz.gamma0 = []         gain.value (per_variable: gain.by_var.<x> where set)
%     gain.koz.master = ''         the first learning variable (structure 'common')
%
%   Free-form subtrees (merged but not validated by load_options):
%     beliefs.init.values, beliefs.plm.by_var, beliefs.plm.derived (checked
%     to hold strings), gain.by_var, shares.fixed_n2 (when a struct),
%     conditions, shocks.add, report.
%
%   Bounded-rationality extensions (docs/DESIGN_br_extensions.md; option
%   schema added 2026-10-20 in phase P0, before any engine code): the
%   options marked "BR" below. Every one defaults to off, so results are
%   unchanged. load_options validates them, and until the engine reads one
%   it stops with hetlearn:options:notImplemented naming the phase that
%   builds it (P1: history.mode 'kalman'; P2: expectations.types,
%   shares.init, shares.fixed, switching.inertia/costs/fitness, intensity
%   'model:bma'; P3: expectations.transforms; P4: type kinds 'level',
%   're_mean', rule term re1(...); P5: beliefs.update 'sac'/'kf', gain.rule
%   'decreasing', kind 're_mean'). Replaced as a whole, not merged:
%   expectations.types, expectations.transforms, shares.init, shares.fixed,
%   switching.costs.
%
%   See also hetlearn.load_options.

o = struct();

% Identification
o.id = '';
o.title = '';
o.description = '';
o.model = '';
o.model_params = '';           % parameter function of the model package for this run, e.g. 'sw07_params_original';
                               %   '' = the package's spec.params (2026-10-20; must be a .m file in the package folder)

% Forecast
o.forecast = struct( ...
    'origin', [], ...          % date: last period of data used
    'horizon', 16);            % number of forecast periods

% Expectations
o.expectations = struct( ...
    'mode', 'rational', ...    % 'rational' | 'learning' | 'fixed_shares' | 'switching'
    'variables', {{}}, ...     % cellstr of forward-looking variables, or 'all'
    're_variant', 'anchored', ...  % 'anchored' (baseline since 2026-10-18) | 'model_consistent' (DESIGN 11)
    're_info', 'current');     % RE agents' information set for the learning variables: 'current' (E_t x_{t+1})
                               %   | 'lagged' (E_{t-1} x_{t+1}, the RE counterpart of beliefs.info = 'lagged'; DESIGN 19)
% BR, N agent types (DESIGN_br_extensions 1.1; phase P2). Empty = off: the two types of today, RE and BR,
% on the existing code path. One struct per type (a struct array or a cell array of structs); name and
% kind are required, every other field [] = inherited:
%   name       letters and digits, starting with a letter ('RE', 'BR', 'L1', 'ADA'): suffix of the
%              forecast x_exp1_<name> and the share n_<name>_x; a type named 'RE' must be of kind 're'
%   kind       're' (RE forecast, as x_exp1_RE) | 'plm' (a learned PLM, as x_exp1_BR) | 'rule' (a fixed
%              linear rule) | 'level' (level k on type base; P4) | 're_mean' (RE forecast plus a learned
%              mean of its own error; P4, P5)
%   variant    're', 'level', 're_mean': 'anchored' | 'model_consistent'; [] = expectations.re_variant
%   info       'lagged' | 'current'; [] = expectations.re_info ('re', 'level', 're_mean') or beliefs.info
%   plm        'plm' only: a shorthand ('ar1', 'ar2', 'ar1_noconst', 'var1') or a partial beliefs.plm
%              subtree; [] = beliefs.plm
%   update     'plm', 'rule', 're_mean': 'rls' | 'fixed' | 'sac' | 'kf'; [] = beliefs.update
%   gain       'plm', 'rule', 're_mean': a partial gain subtree merged over gain, e.g.
%              struct('rule', 'decreasing'); [] = gain
%   rule       'rule' only, required: the expression, e.g. '0.65*x{-1} + 0.35*self{-1}', or
%              struct('expr', <expression>, 'params', struct of numbers); terms x (the variable), self
%              (this type's forecast), dn (nominal growth), mean (a learned mean), re1(...) (anchored
%              E_{t-1}, P4); lags >= 1 under 'lagged' information
%   base, k    'level' only, required: the level-0 type ('RE' allowed) and the level, an integer >= 1
%   variables  cellstr: the learning variables this type forecasts (share groups); [] = all of them
%   cost       Brock-Hommes cost C_k >= 0 in the logit; [] = switching.costs.<name>, else 0
o.expectations.types = struct('name', {}, 'kind', {}, 'variant', {}, 'info', {}, 'plm', {}, ...
    'update', {}, 'gain', {}, 'rule', {}, 'base', {}, 'k', {}, 'variables', {}, 'cost', {});
% BR, forecast transforms (DESIGN_br_extensions 1.3; phase P3). Empty = off. One struct per transform:
%   kind      'multiplier' | 'diagnostic' | 'myopia_anchoring' | 'partial_adjustment' | 'wedge'
%   types     'all' (also the model-consistent expectations outside the learning set) | type names;
%             [] = 'all'
%   scope     'learning' (the learning set) | 'all' (every forward-looking variable) | cellstr of
%             variables and 'x@<exact equation label>' entries; [] = 'learning'
%   exclude   cellstr of variables removed from the scope; [] = none
%   profile   'multiplier' only: 'geometric' (m^h) | 'flat' (lambda) | 'hyperbolic' (1/(1+alpha*h));
%             [] = 'geometric'
%   value     multiplier: m or lambda >= 0, alpha >= 0 (identity 1, 1, 0); diagnostic: theta (0);
%             myopia_anchoring: [omega_f, b] ([1 0]); partial_adjustment: g in [0, 1] (1); wedge: []
%   factor    'wedge' only: struct with rho (0; in (-1, 1)), std (0; >= 0 or 'model:<rule>'), mean (0; a
%             number or '[-]model:<rule>'), loadings ([] = 1; struct by variable or 'model:<rule>'),
%             shock (name of the new shock; needed when std is not 0)
o.expectations.transforms = struct('kind', {}, 'types', {}, 'scope', {}, 'exclude', {}, ...
    'profile', {}, 'value', {}, 'factor', {});

% Beliefs
o.beliefs = struct();
o.beliefs.update = 'rls';      % 'rls' | 'fixed' | BR (DESIGN_br_extensions 1.5; P5): 'sac' (SAC learning of mean,
                               %   autocorrelation and variance on the AR(1) PLM) | 'kf' (Kalman-filter learning)
o.beliefs.kf = struct( ...     % BR, beliefs.update = 'kf' only (DESIGN_br_extensions 1.5): coefficients a random walk
    'gamma', [], ...           % constant-gain equivalent in (0, 1): V = gamma^2/(1-gamma)*s2*inv(R0),
    ...                        %   P0 = gamma*s2*inv(R0); [] = gain.value
    's2', 're_moments');       % PLM residual variance: 're_moments' (at the RE moments) | a number > 0
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
    ...                        %   | BR 'decreasing' (g_t = 1/(t - t0 + n0), DESIGN_br_extensions 1.5; P5)
    'value', 0.0585, ...
    'by_var', struct());       % free-form: by_var.<x> = gain
o.gain.koz = struct( ...       % gain.rule = 'koz': Kostyshyna, Ozden and Zhang (2024), eq. (9)
    'mu', 0.001, ...           % step size of the gain process ("gain on the gain"), >= 0 (0 = constant)
    'gamma0', [], ...          % initial gain; [] = gain.value (per_variable: gain.by_var.<x> where set)
    'Rg0', 0, ...              % initial Rg (the paper is silent)
    'bounds', [0.001 0.25], ...    % [lower upper] projection interval of the gain, inside (0, 1]
    'error', 'rls', ...        % signed error: 'rls' (one-step PLM residual) | 'forecast' (x_t - f^BR_{t-1})
    'error_scale', 1, ...      % errors times this first (1 = the model's units, % per quarter; user decision 2026-10-19)
    'structure', 'common', ... % 'common' (one process, KOZ fn. 7) | 'per_variable' (one per PLM equation)
    'master', '');             % common: '' = first learning variable; name or cellstr (mean of their errors)
o.gain.decreasing = struct( ...   % BR, gain.rule = 'decreasing' only (P5): t0 = beliefs.init.date
    'n0', 1);                     % >= 1; 1 = the sample mean from t0 (Anufriev-Hommes LAA anchor)

% Shares
o.shares = struct( ...
    'structure', 'per_variable', ...   % 'per_variable' | 'universal'
    'master', {{}}, ...                % name or cellstr (universal only)
    'init_n2', 0.5, ...                % initial share of BR agents
    'fixed_n2', [], ...                % scalar or struct by variable (fixed_shares)
    'init', [], ...                    % BR, N types (DESIGN_br_extensions 1.2; P2): struct by type name of initial
    ...                                %   shares in [0, 1], summing to 1 per share group; [] = init_n2 for RE/BR,
    ...                                %   equal shares otherwise; an unlisted RE type gets 0
    'fixed', []);                      % BR, N types, mode 'fixed_shares' (P2): struct by type name, as init;
                                       %   [] = fixed_n2 (the two-type shorthand)

% Switching (IJCB eqs. 14-15)
o.switching = struct( ...
    'rule', 'discrete_choice', ...
    'intensity', 0.51, ...     % chi (IJCB estimate on quarterly data; user decision 2026-10-18, was 8);
    ...                        %   BR 'model:bma' = 1/(2 sigma^2) from the RE limit (DESIGN_br_extensions 3, var. 27; P2)
    'memory', 0.6, ...         % omega (switching.error_scale removed 2026-10-18); 1 allowed with fitness 'unnormalized'
    'inertia', 0, ...          % BR (DESIGN_br_extensions 1.2; P2) delta in [0, 1): n_t = delta*n_{t-1} + (1 - delta)*logit; 0 = off
    'costs', [], ...           % BR (P2): struct by type name of Brock-Hommes costs C_k >= 0 in the logit; [] = none
    'fitness', 'normalized');  % BR (P2): 'normalized' (U = omega*U - (1 - omega)*FE, IJCB) | 'unnormalized'
                               %   (U = omega*U - FE, Anufriev-Hommes; chi_normalized = beta/(1 - omega))

% Projection facility
o.projection = struct( ...
    'facility', 'plm_alm');    % 'plm_alm' (PLM blocks, then the ALM) | 'alm' (ALM only) | 'none' (DESIGN 4.4)

% History stage
o.history = struct( ...
    'learn', true, ...
    'mode', 're_smoother', ... % 're_smoother' | 'inversion' (DESIGN 15) | BR 'kalman' (time-varying Kalman filter of
    ...                        %   the ALM, one-step prediction errors; DESIGN_br_extensions 5; P1)
    're_states', 'smoothed', ... % 're_smoother' only: RE agents' forecasts and learners' data from the two-sided
    ...                        %   smoother ('smoothed') or the one-sided filter x_{t|t}, data up to t ('filtered'; DESIGN 5.2)
    'realtime', false, ...     % true: RE filter on data up to the origin only (DESIGN 17)
    'inversion', struct( ...   % history.mode = 'inversion' only
        'start', [], ...       % [] = beliefs.init.date
        'shocks', {{}}), ...   % endogenised shocks; {} = every transition shock
    'kalman', struct( ...      % BR, history.mode = 'kalman' only (P1)
        'init', 'stochastic'));   % 'stochastic' (asymptotic distribution, as IRIS) | 'smoothed' (P0 = 0 at the
                                  %   RE-smoothed state before the start)

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
    'step', 'fast', ...                % 'fast' (= IRIS to ~1e-12; 2-3x faster, ~20x with observables exogenised) | 'iris' (IRIS simulate)
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
