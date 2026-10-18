function cfg = v3_all()
%V3_ALL  Model variant 3: learning on all 12 forward-looking variables, projection facility 'plm_alm'.
%
%   cfg = v3_all()
%
%   As a1_learn with expectations.variables = 'all': every forward-looking
%   variable (invef, rkf, pkf, cf, labf, inve, pinf, rk, pk, c, lab, w) has its
%   own AR(1) learners and its own switching share. The projection facility
%   stays at its default, 'plm_alm'. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v3_all';
cfg.title = 'Variant 3: learning on all 12 forward-looking variables (facility plm_alm)';
cfg.description = 'As a1_learn, but every forward-looking variable has RE agents and AR(1) learners with switching shares; PLM and ALM checks as by default.';
cfg.expectations.variables = 'all';
% cfg.projection.facility = 'plm_alm';        % the default, inherited
cfg.compare_with = {'a1_learn'};
end
