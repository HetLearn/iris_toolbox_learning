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

% --- Calibration (live, review M2/s1; chi revised by the user on 2026-10-18) -------------
% The four values below are set here so that the calibration is visible in one place.
% They equal hetlearn.defaults(), so results are unchanged. IJCB = Ozden (2025), IJCB 21(1).
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
o.gain.value = 0.0585;            % constant gain (IJCB eq. 13)
o.switching.intensity = 0.51;     % chi, intensity of choice (IJCB eq. 15; IJCB estimate, quarterly data)
o.switching.memory = 0.6;         % omega, memory in the fitness measure (IJCB eq. 14)
o.shares.init_n2 = 0.5;           % initial share of BR (learning) agents

% --- Other knobs (commented: the defaults apply) ---------------------------------------
% o.gain.by_var.pinf = 0.02;        % gain for one variable
% o.beliefs.info = 'current';       % BR forecasts on period-t data (IJCB eq. 12)
% o.projection.facility = 'alm';    % 'plm_alm' (default) | 'alm' | 'none' (DESIGN 4.4)
% o.forecast.horizon = 16;          % quarters

end
