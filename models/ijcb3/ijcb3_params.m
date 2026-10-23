function P = ijcb3_params()
% IJCB3_PARAMS  Posterior means of the heterogeneous-expectations model, Ozden (2025, IJCB).
%
% Source: Ozden (2025), IJCB 21(1), Table 1, column "Hetero Expectations" (HE),
% posterior means; the 90% HPD bounds [LB, UB] are in the comments. Estimated by
% Kim-Nelson filter and RWMH on US data 1960Q1-2019Q4 (burn-in 1957Q1-1959Q4),
% with inflation and the policy rate in percent per quarter (README.md, "Units").
% Table 1 has four columns: RE (no switching), RE with switching in monetary
% policy, HE, and adaptive learning (AL). Every value below is the HE mean, except:
%   beta       not estimated (no prior in Table C.1); fixed at 0.99, the value
%              the paper states (footnote 18, "standard parameterization").
%   r_bar_T    the HE column has two rate trends, r_bar_T (Taylor regime, 0.26)
%              and r_bar_E (ELB regime, 0.03); without the ELB regime the
%              package uses the Taylor-regime trend.
%   std_eps_r  likewise the Taylor-regime policy-shock std eta_r,T (0.24), not
%              the ELB-regime eta_r,E (0.01).
% So no parameter is taken from another column.
%
% HE estimates not used by this package (no regime switching, no expectations
% observables): r_bar_E 0.03 [0.03, 0.04]; eta_r,E 0.01 [0.01, 0.01];
% eta_SR_pi,exp 0.11 [0.09, 0.12] and eta_LR_pi,exp 0.08 [0.07, 0.09] (measurement
% errors of the ATSIX short- and long-run expectations); Phi1 0.10 [0.06, 0.15]
% and Phi2 0.16 [0.07, 0.31] (policy-regime switching).
%
% HE learning and switching parameters. They are HetLearn options, not model
% parameters, and are set in scenarios/ijcb3/app1_peak/i1_learn.m:
%   gamma, constant gain (eq. 13)          0.0585  [0.0584, 0.0587]   -> gain.value
%   omega, memory (eq. 14)                 0.62    [0.49, 0.74]       -> switching.memory
%   chi, intensity of choice (eq. 15)      0.51    [0.38, 0.66]       -> switching.intensity
% chi applies as estimated: the package data have IJCB's units. The AL column's
% gain is 0.0579 [0.0575, 0.0581]. Marginal log-likelihoods: RE -479.63,
% RE-switching -435.86, HE -410.06, AL -432.66.
%
% Caution: the HE trends imply a negative real-rate trend, r_bar_T - pi_bar =
% -0.32% per quarter (-1.3% a year); the RE column's trends (pi_bar 0.66,
% r_bar_T 1.02) imply +0.36. Under RE the forecast reverts to these trends
% (README.md, "Open issues").

P = struct();

% fixed
P.beta = 0.99;          % not estimated; IJCB footnote 18

% structural parameters, HE posterior mean [90% HPD]
P.tau = 1.13;           % [1.03, 1.30]   risk aversion (IS curve elasticity 1/tau)
P.kappa = 0.0032;       % [0.0017, 0.0052] NKPC slope
P.iota_y = 0.06;        % [0.03, 0.12]   indexation, IS curve
P.iota_p = 0.15;        % [0.09, 0.20]   indexation, NKPC
P.phi_pi = 1.53;        % [1.24, 1.79]   policy reaction to inflation
P.phi_y = 0.42;         % [0.34, 0.51]   policy reaction to the output gap
P.phi_dy = 0.12;        % [0.09, 0.14]   policy reaction to output-gap growth
P.rho_r = 0.92;         % [0.90, 0.94]   policy smoothing
P.rho_y = 0.95;         % [0.93, 0.96]   persistence, demand shock
P.rho_pi = 0.04;        % [0.01, 0.08]   persistence, cost-push (supply) shock

% trends in the measurement equations, % per quarter
P.pi_bar = 0.58;        % [0.55, 0.60]   inflation trend
P.r_bar_T = 0.26;       % [0.25, 0.27]   policy-rate trend, Taylor regime

% shock standard deviations
P.std_eps_y = 0.32;     % [0.28, 0.36]   eta_y, demand
P.std_eps_pinf = 0.38;  % [0.35, 0.41]   eta_pi, cost-push (supply)
P.std_eps_r = 0.24;     % [0.22, 0.27]   eta_r,T, policy shock in the Taylor regime

end
