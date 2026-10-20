function P = sw07_params_original()
% SW07_PARAMS_ORIGINAL  Published Smets-Wouters (2007) posterior mode, sample 1966Q1-2004Q4.
%
% Source: Smets, F. and R. Wouters (2007), "Shocks and Frictions in US Business Cycles: A
% Bayesian DSGE Approach", American Economic Review 97(3), 586-606. The values are xparam1 of
% usmodel_mode.mat in the authors' replication files (Tables 1A and 1B of the paper report the
% same mode, rounded), copied from column published_sw07 of
% estimation/mode_original_vs_extended.csv (Desktop/ucur-dsge/sw07-extended/validation/collect_ext.m);
% the same set as results/app1_t1_filtered_koz/sw07orig/sw07orig_params.m. Not estimated here.
% Fixed parameters (ctou, clandaw, cg, curvp, curvw) as in sw07_params.m (swX1), which they equal.
%
% Select it per run with the option model_params = 'sw07_params_original' (the project baseline
% since 2026-10-20, config/master_options.m); model_params = '' uses spec.params = sw07_params (swX1).
% constelab (-0.103) is the published value: labobs is demeaned over 1947Q2-2026Q2 here, so the
% hours constant is not comparable across samples (estimation/FINDINGS_estimates.md).
% Generated from the CSV; do not edit by hand.

P = struct();

% fixed parameters (as in swX1)
P.ctou = 0.025000000000000001;
P.clandaw = 1.5;
P.cg = 0.17999999999999999;
P.curvp = 10;
P.curvw = 10;

% estimated parameters (published posterior mode)
P.crhoa = 0.958774095336246;
P.crhob = 0.18243934512556;
P.crhog = 0.976161415046499;
P.crhoqs = 0.709569323873602;
P.crhoms = 0.127131476313068;
P.crhopinf = 0.903807340558011;
P.crhow = 0.971853774024447;
P.cmap = 0.744871846683131;
P.cmaw = 0.888145926618249;
P.csadjcost = 5.48819700906062;
P.csigma = 1.39519289795144;
P.chabb = 0.712400635178752;
P.cprobw = 0.737541323772002;
P.csigl = 1.9198838416864;
P.cprobp = 0.65626626029755;
P.cindw = 0.591998309497386;
P.cindp = 0.228354019115349;
P.czcap = 0.547213129238992;
P.cfc = 1.61497958797633;
P.crpi = 2.02946740344113;
P.crr = 0.815324872021385;
P.cry = 0.0846869053285818;
P.crdy = 0.222925708063948;
P.constepinf = 0.817982220538172;
P.constebeta = 0.160654114713215;
P.constelab = -0.103065166985808;
P.ctrend = 0.432026374810516;
P.cgy = 0.526121219470843;
P.calfa = 0.192800456418155;

% shock standard deviations (published posterior mode)
P.std_ea = 0.451788281662122;
P.std_eb = 0.24246070101377;
P.std_eg = 0.520010319208288;
P.std_eqs = 0.450106906080831;
P.std_em = 0.239839325484002;
P.std_epinf = 0.141123850778673;
P.std_ew = 0.2443916012335;

end
