function cfg = v3_all()
%V3_ALL  Model variant 3: learning on all 12 forward-looking variables, projection facility 'alm' (the baseline).
%
%   cfg = v3_all()
%
%   As a1_learn with expectations.variables = 'all': every forward-looking
%   variable (invef, rkf, pkf, cf, labf, inve, pinf, rk, pk, c, lab, w) has its
%   own AR(1) learners and its own switching share. The projection facility
%   stays at the baseline, 'alm' (config/master_options.m, since 2026-10-21;
%   'none' on 2026-10-20, archived in archive/2026-10-21_facility_none/): an
%   unstable ALM reverts every belief, then keeps last quarter's shares.
%   v3_all_plm_alm and v3_all_alm set 'plm_alm' and 'alm' explicitly, so
%   v3_all_alm is the same run as v3_all. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v3_all';
cfg.title = 'Variant 3: learning on all 12 forward-looking variables (facility alm, the baseline)';
cfg.description = 'As a1_learn, but every forward-looking variable has RE agents and AR(1) learners with switching shares; projection facility alm on the actual law of motion, as in the baseline.';
cfg.expectations.variables = 'all';
% cfg.projection.facility = 'alm';            % the baseline (since 2026-10-21), inherited
cfg.compare_with = {'a1_learn'};
end
