function cfg = i1_learn()
%I1_LEARN  IJCB3 application 1: peak forecast, switching RE/learning on inflation, anchored RE.
%
%   cfg = i1_learn()
%
%   Inherits i1_re (model ijcb3, origin 2022Q2, 16 quarters, zero shocks) and
%   switches on endogenous shares of RE agents and adaptive learners in
%   inflation expectations (IJCB eqs. 14-15). RE agents are anchored (IJCB
%   sec. 2.3.1): they forecast with the pure-RE model's decision rule at the
%   current state. Beliefs and shares are learned over the RE-smoothed
%   history and carried into the forecast. Writes compare_i1_re.csv.
%
%   The learning parameters are the posterior means of IJCB Table 1,
%   heterogeneous-expectations column. They are set here so that the
%   scenario does not depend on config/master_options.m:
%     gain.value          0.0585  gamma [0.0584, 0.0587]
%     switching.memory    0.62    omega [0.49, 0.74] (IJCB's text rounds it to 0.6)
%     switching.intensity 0.51    chi   [0.38, 0.66]
%   chi applies as IJCB estimated it, with no rescaling: IJCB's data are in
%   percent per quarter, and so are the package data
%   (models/ijcb3/README.md, "Units"). SW07 uses 0.51 too.
%
%   Other IJCB features stay at the defaults (see i1_re.m): learners use
%   t-1 data ('lagged'; IJCB uses t-timing), an AR(1) PLM for inflation
%   (IJCB: VAR(1) over y, pinf, r), and a share driven by inflation errors
%   only (IJCB: inflation plus output-gap errors).

cfg = i1_re();                                % start from the RE scenario
cfg.id = 'i1_learn';
cfg.title = 'IJCB3: forecast from the 2022Q2 CPI inflation peak, switching on inflation, anchored RE';
cfg.description = ['As i1_re, with inflation expectations a mix of anchored RE agents and ' ...
    'adaptive learners whose shares switch on past forecast errors (IJCB HE learning parameters).'];
cfg.expectations.mode = 'switching';
cfg.expectations.variables = {'pinf'};
cfg.expectations.re_variant = 'anchored';
cfg.gain.value = 0.0585;                      % gamma, IJCB Table 1 (HE)
cfg.switching.memory = 0.62;                  % omega, IJCB Table 1 (HE)
cfg.switching.intensity = 0.51;               % chi, IJCB Table 1 (HE), no rescaling
cfg.compare_with = {'i1_re'};
end
