function P = sw07_params()
% SW07_PARAMS  Posterior mode of the re-estimated Smets-Wouters (2007) model.
%
% Provenance: Dynare run swX1 (C:\dynare_work\sw_ext\swX1.mod), 2026-09-29,
% Dynare 4.6.1, mode_compute=4, likelihood sample 1966Q1-2026Q2 (242 quarters,
% presample 1965Q1-Q4), log posterior at the mode -1578.2488.
% Values: xparam1 in estimation/swX1_mode.mat, mapped by name via parameter_names;
% the 7 stderr entries become std_<shock>. Cross-checked against column
% ext_mode_1966_2026 of estimation/mode_original_vs_extended.csv (max abs diff 4.2e-15).
% Fixed in the estimation: ctou, clandaw, cg, curvp, curvw.
% Generated from the .mat file; do not edit by hand.

P = struct();

% fixed parameters
P.ctou = 0.025000000000000001;
P.clandaw = 1.5;
P.cg = 0.17999999999999999;
P.curvp = 10;
P.curvw = 10;

% estimated parameters (posterior mode)
P.crhoa = 0.96238746480813209;
P.crhob = 0.13467593447558063;
P.crhog = 0.97227134030659579;
P.crhoqs = 0.83566132905979851;
P.crhoms = 0.34168293561505697;
P.crhopinf = 0.97622656167550048;
P.crhow = 0.9424065745022735;
P.cmap = 0.79242719536010808;
P.cmaw = 0.92531756095838236;
P.csadjcost = 6.7524812465270667;
P.csigma = 1.3261616997876691;
P.chabb = 0.74720292611652828;
P.cprobw = 0.84890427913070543;
P.csigl = 1.67721709235925;
P.cprobp = 0.75398420862045146;
P.cindw = 0.76622226576952857;
P.cindp = 0.17580405523244746;
P.czcap = 0.86903373875584955;
P.cfc = 1.2245679532807743;
P.crpi = 1.5074224529265636;
P.crr = 0.80017951686365296;
P.cry = 0.014697490280219565;
P.crdy = 0.093755244984420227;
P.constepinf = 0.78357495291164314;
P.constebeta = 0.11856323013137104;
P.constelab = -3.0023624246637168;
P.ctrend = 0.38614055512126066;
P.cgy = 0.31013429417357358;
P.calfa = 0.21755846035864676;

% shock standard deviations (posterior mode)
P.std_ea = 0.60870680262055066;
P.std_eb = 0.42943006265801525;
P.std_eg = 0.49058498447672;
P.std_eqs = 0.28526663525136359;
P.std_em = 0.23240285391339766;
P.std_epinf = 0.13559780075345579;
P.std_ew = 0.41687587188230113;

end
