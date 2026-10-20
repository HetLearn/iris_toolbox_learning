function o = master_options()
%MASTER_OPTIONS  Project-wide hetlearn option overrides (edit this file).
%
%   o = master_options()
%
%   Returns a PARTIAL option tree. hetlearn.load_options merges
%       hetlearn.defaults()  <  master_options()  <  scenario cfg
%   so anything set here applies to every scenario unless the scenario
%   overrides it. Field names must exist in hetlearn.defaults(); a typo
%   is an error (removed names, e.g. projection.max_root, give an error that
%   names their replacement). Uncomment a line to change a project-wide default.

o = struct();

% --- Previous calibration, 2026-10-18 to 2026-10-19 (review M2/s1; chi revised 2026-10-18) ------
% Until 2026-10-19 this file set the four values below, equal to hetlearn.defaults(), so that
% the calibration was visible in one place. They are still the defaults; the baseline since
% 2026-10-20 is the block further down. IJCB = Ozden (2025), IJCB 21(1).
%
%   gain.value = 0.0585        IJCB Table 1, posterior mean of the constant gain in the
%                              heterogeneous-expectations (HE) model (90% band 0.0584-0.0587).
%   switching.memory = 0.6     IJCB sec. 4 text ("the estimated memory parameter omega ... is
%                              0.6"); the Table 1 posterior mean is 0.62 (band 0.49-0.74).
%   switching.intensity = 0.51 IJCB's estimate of chi as published. IJCB estimated it on
%                              quarterly data (percent per quarter), the units SW07 uses here,
%                              so no conversion applies (user decision 2026-10-18; the earlier
%                              value 8 = 0.51 x 16 assumed annualised IJCB data, which was
%                              wrong). Evidence (models/ijcb3/README.md, "Units"): the ELB
%                              trend 0.03 and the ELB shock sd 0.01 match FEDFUNDS/4 over
%                              2009-15 (mean 0.032, sd 0.0095); the RE-column rate trend 1.02
%                              matches the 1960-2019 mean of FEDFUNDS/4 (1.25); the user
%                              confirmed it.
%   shares.init_n2 = 0.5       hetlearn choice to start the share recursion, not from IJCB.
%
% Differences from IJCB that bear on these values:
%   - Fitness errors: IJCB's FE sums the squared errors of inflation and the output gap
%     (eq. 14, App. D). Here each learning variable's share uses only its own squared error
%     (shares.structure = 'per_variable'), unless shares.structure = 'universal' and
%     shares.master lists more variables (their squared errors are then summed).
%   - Information: IJCB learners use period-t information (eq. 12: E_t x_{t+1} =
%     alpha_{t-1} + beta_{t-1} x_t, jointly determined with x_t). The default here is
%     beliefs.info = 'lagged' (the user's spec: data up to t-1); beliefs.info = 'current'
%     gives the IJCB timing.
%   - Units: chi multiplies squared forecast errors, so its meaning depends on the units of
%     the model's variables. A package with annualised data needs chi 16 times smaller for
%     the same switching (squared errors in annual units are 4^2 = 16 times larger).
%   - KOZ (2024, BoC SWP 2024-14) uses chi = 0.51, omega = 0.62 and gamma0 = 0.059.
%
% The block above describes the calibration as it stood until 2026-10-19. The project baseline
% changed on 2026-10-20 (block below); the values above are now the defaults of
% hetlearn.defaults() and the "previous" column there.

% --- Baseline since 2026-10-20 (user decision 2026-10-20) -------------------------------------
% User's words: "Original calibration, and initial gain 0.05, chi=2, memory 0.8. ar1 rule. gain
% endogenous. original calibration. t-1 assumption for RE and learning. filtered values to form
% expectations, not smoothed. no projection facility."
%
%   option                      new                     previous (2026-10-18/19, = hetlearn.defaults)
%   model_params                'sw07_params_original'  '' (spec.params = sw07_params, swX1 mode 1966-2026)
%   gain.rule                   'koz'                   'constant'
%   gain.value                  0.05 (KOZ start gain)   0.0585 (constant gain)
%   switching.intensity (chi)   2                       0.51
%   switching.memory (omega)    0.8                     0.6
%   beliefs.plm.default         'ar1'                   'ar1' (unchanged, set here to be explicit)
%   beliefs.info                'lagged'                'lagged' (unchanged, set here to be explicit)
%   expectations.re_info        'lagged'                'current'
%   history.re_states           'filtered'              'smoothed'
%   projection.facility         'none'                  'plm_alm'
%   expectations.re_variant     'anchored'              'anchored' (unchanged, set here to be explicit)
%   shares.init_n2              0.5                     0.5 (unchanged)
%
% model_params: the published Smets-Wouters (2007) posterior mode for 1966Q1-2004Q4
% (models/sw07/sw07_params_original.m) instead of the swX1 re-estimate; it names a parameter
% function of the sw07 package, so scenarios of other packages (models/ijcb3, models/as07) set
% model_params = '' (their own published parameters) and pin their previous learning settings.
% gain.koz.*: every other KOZ option at its default (mu 0.001, gamma0 [] = gain.value, Rg0 0,
% bounds [0.001 0.25], error 'rls', error_scale 1, structure 'common').
% Known conflicts (scenario files): Ramsey policy is not supported with re_info = 'lagged', so
% application 4 (scenarios/sw07/app4_ramsey/) runs with re_info = 'current', the only deviation
% from this baseline; the inversion (a6_inv_learn) is one-sided by construction and keeps
% history.re_states = 'smoothed' (the option applies to the RE smoother only). With facility
% 'none' a quarter without a model solution stops the run (hetlearn:engine:noSolution): such a
% run is recorded as failed, not moved to another facility.
% Tests do not read this file: tests/run_tests.m puts tests/config/master_options.m (the previous
% values) first on the path.
o.model_params = 'sw07_params_original';   % published SW07 (2007) mode, models/sw07/sw07_params_original.m
o.gain.rule = 'koz';                       % endogenous gain, Kostyshyna, Ozden and Zhang (2024) eq. 9
o.gain.value = 0.05;                       % initial (KOZ start) gain; was 0.0585 (IJCB constant gain)
o.switching.intensity = 2;                 % chi, intensity of choice (IJCB eq. 15); was 0.51
o.switching.memory = 0.8;                  % omega, memory in the fitness measure (IJCB eq. 14); was 0.6
o.shares.init_n2 = 0.5;                    % initial share of BR (learning) agents (unchanged)
o.beliefs.plm.default = 'ar1';             % AR(1) PLM with constant (unchanged)
o.beliefs.info = 'lagged';                 % learners see data up to t-1 (unchanged)
o.expectations.re_info = 'lagged';         % RE agents: E_{t-1} x_{t+1} for the learning set; was 'current'
o.expectations.re_variant = 'anchored';    % (unchanged)
o.history.re_states = 'filtered';          % RE forecasts and learners' data from the one-sided filter; was 'smoothed'
o.projection.facility = 'none';            % no projection facility; was 'plm_alm'

% --- Other knobs (commented: the values above or the defaults apply) -------------------------
% o.gain.by_var.pinf = 0.02;        % gain for one variable
% o.beliefs.info = 'current';       % BR forecasts on period-t data (IJCB eq. 12)
% o.forecast.horizon = 16;          % quarters

end
