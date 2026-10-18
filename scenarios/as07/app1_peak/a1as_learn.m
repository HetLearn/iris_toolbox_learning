function cfg = a1as_learn()
%A1AS_LEARN  AS07 application 1: peak forecast, switching RE/learning on inflation, anchored RE.
%
%   cfg = a1as_learn()
%
%   Inherits a1as_re (model as07, origin 2022Q2, 16 quarters, zero shocks)
%   and switches on endogenous shares of RE agents and adaptive learners in
%   inflation expectations (IJCB eqs. 14-15). RE agents are anchored (IJCB
%   sec. 2.3.1): they forecast with the pure-RE model's decision rule at the
%   current state. Beliefs and shares are learned over the RE-smoothed
%   history and carried into the forecast. Writes compare_a1as_re.csv.
%
%   An and Schorfheide (2007) and Herbst and Schorfheide (2016) estimate no
%   learning parameters, so the learning calibration is the project's, from
%   config/master_options.m (IJCB = Ozden 2025, IJCB 21(1)). It is set here
%   as well, so that the scenario does not depend on the master options:
%     gain.value          0.0585  IJCB Table 1, HE posterior mean
%     switching.memory    0.6     IJCB sec. 4 text (Table 1 mean 0.62)
%     switching.intensity 0.51    IJCB's chi, estimated on percent-per-quarter data
%     shares.init_n2      0.5     initial share of learners
%   chi applies without rescaling: the learners forecast the model variable
%   pinf, which is in percent per quarter here as in IJCB, SW07 and IJCB3
%   (models/as07/README.md, "Units"); only the observable pinfobs is
%   annualised.
%
%   Other settings stay at the defaults: learners use t-1 data ('lagged'),
%   an AR(1) PLM for inflation, and a share driven by inflation errors only.
%   Output expectations y{+1} stay rational.

cfg = a1as_re();                              % start from the RE scenario
cfg.id = 'a1as_learn';
cfg.title = 'AS07: forecast from the 2022Q2 CPI inflation peak, switching on inflation, anchored RE';
cfg.description = ['As a1as_re, with inflation expectations a mix of anchored RE agents and ' ...
    'adaptive learners whose shares switch on past forecast errors (project learning calibration).'];
cfg.expectations.mode = 'switching';
cfg.expectations.variables = {'pinf'};
cfg.expectations.re_variant = 'anchored';
cfg.gain.value = 0.0585;                      % gamma, IJCB Table 1 (HE); = config/master_options.m
cfg.switching.memory = 0.6;                   % omega, IJCB sec. 4; = config/master_options.m
cfg.switching.intensity = 0.51;               % chi, IJCB (% per quarter data), no rescaling; = master
cfg.shares.init_n2 = 0.5;                     % initial BR share; = config/master_options.m
cfg.compare_with = {'a1as_re'};
end
