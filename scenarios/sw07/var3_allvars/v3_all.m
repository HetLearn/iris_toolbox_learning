function cfg = v3_all()
%V3_ALL  Model variant 3: learning on all 12 forward-looking variables, no projection facility (the baseline).
%
%   cfg = v3_all()
%
%   As a1_learn with expectations.variables = 'all': every forward-looking
%   variable (invef, rkf, pkf, cf, labf, inve, pinf, rk, pk, c, lab, w) has its
%   own AR(1) learners and its own switching share. The projection facility
%   stays at the baseline, 'none' (config/master_options.m, since 2026-10-20):
%   if the model cannot be solved in a quarter it must simulate, the run stops
%   with hetlearn:engine:noSolution, and that stop is the result.
%   v3_all_plm_alm and v3_all_alm are the same run under the two facilities.
%   Writes compare_a1_learn.csv when it completes.

cfg = a1_learn();
cfg.id = 'v3_all';
cfg.title = 'Variant 3: learning on all 12 forward-looking variables (no projection facility, the baseline)';
cfg.description = 'As a1_learn, but every forward-looking variable has RE agents and AR(1) learners with switching shares; no projection facility, as in the baseline.';
cfg.expectations.variables = 'all';
% cfg.projection.facility = 'none';           % the baseline, inherited
cfg.compare_with = {'a1_learn'};
end
