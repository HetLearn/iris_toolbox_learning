function P = as07_params()
% AS07_PARAMS  Published posterior means of the An-Schorfheide (2007) model, Herbst and Schorfheide (2016).
%
% Source: Herbst and Schorfheide (2016), "Bayesian Estimation of DSGE Models",
% Princeton UP, Ch. 4, table "Posterior Estimates of DSGE Model Parameters" in
% the authors' Chapter 4 slides on the companion website,
% https://web.sas.upenn.edu/schorf/files/2017/05/chapter4_sl_0-1sxxi8g.pdf
% (small-scale NK model, US data 1983Q1-2002Q4). The table reports posterior
% means and [5th, 95th] percentiles, no medians; its note: 100,000 draws from
% the posterior, the first 50,000 discarded. The values are used as published
% (two decimals); nothing is estimated or sampled in this package (user
% decision 2026-10-18).
%
% Units: the book's code measures y, pi and R in percent (pi and R in % per
% quarter: INFL = piA + 4*pi), so the published values apply as they stand
% (scale factor 1; README.md, "Units"). rA and piA are in % a year, gammaQ in
% % per quarter, the shock std devs in percent (sigma_R and sigma_z in % per
% quarter).
%
% Order and names of the replication code's prior.m. Each line: published mean,
% [5th, 95th] percentiles, prior from prior.m (Gamma and Normal: mean, sd;
% inverse gamma: An-Schorfheide (s, nu), p(sigma) ~ sigma^-(nu+1) exp(-nu s^2/(2 sigma^2))).

P = struct();

% structural parameters (table symbol in brackets)
P.tau = 2.83;       % (tau)       [1.95, 3.82]  Gamma(2.00, 0.50)
P.kappa = 0.78;     % (kappa)     [0.51, 0.98]  Uniform[0, 1]
P.psi1 = 1.80;      % (psi_1)     [1.43, 2.20]  Gamma(1.50, 0.25)
P.psi2 = 0.63;      % (psi_2)     [0.23, 1.21]  Gamma(0.50, 0.25)
P.rA = 0.42;        % (r^(A))     [0.04, 0.95]  Gamma(0.50, 0.50); % a year
P.piA = 3.30;       % (pi^(A))    [2.78, 3.80]  Gamma(7.00, 2.00); % a year
P.gammaQ = 0.52;    % (gamma^(Q)) [0.28, 0.74]  Normal(0.40, 0.20); % per quarter
P.rho_r = 0.77;     % (rho_r)     [0.71, 0.82]  Uniform[0, 1)
P.rho_g = 0.98;     % (rho_g)     [0.96, 1.00]  Uniform[0, 1)
P.rho_z = 0.88;     % (rho_z)     [0.84, 0.92]  Uniform[0, 1)

% fixed: beta = 1/(1 + rA/400) = 0.998951 at rA = 0.42, a substitution in
% as07.model (model_solution.m: bet = 1/(1+rA/400)); nothing else is fixed.

% shock standard deviations
P.std_eps_r = 0.22;   % (sigma_r)  [0.18, 0.26]  InvGamma(s 0.40, nu 4); % per quarter
P.std_eps_g = 0.71;   % (sigma_g)  [0.61, 0.84]  InvGamma(s 1.00, nu 4); %
P.std_eps_z = 0.31;   % (sigma_z)  [0.26, 0.36]  InvGamma(s 0.50, nu 4); % per quarter

% measurement errors: from the replication code, not from the published table
% (the table lists no measurement errors and the slides do not mention them).
% Mfiles/sysmat.m fixes their variances at (0.20 x the us.txt sample std)^2,
% std 0.579923 (ygr), 1.470832 (infl), 2.237937 (int), "from dsge1_me.yaml".
% Set all three to 0 for a model without measurement errors (README.md,
% "Measurement errors").
P.std_me_dy = 0.20*0.579923;       % 0.1160, % per quarter
P.std_me_pinfobs = 0.20*1.470832;  % 0.2942, % a year
P.std_me_robs = 0.20*2.237937;     % 0.4476, % a year

end
