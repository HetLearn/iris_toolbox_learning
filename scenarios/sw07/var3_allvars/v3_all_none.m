function cfg = v3_all_none()
%V3_ALL_NONE  Model variant 3: learning on all 12 variables, no projection facility.
%
%   cfg = v3_all_none()
%
%   As v3_all with projection.facility = 'none': nothing is restricted. If the
%   model cannot be solved in a quarter it must simulate, the run stops with
%   hetlearn:engine:noSolution (date, stage, shares, PLM roots); that stop is
%   the result. With anchored RE and every forward-looking variable learning
%   the model has no leads, so it is simulated as it is (explosive events).
%   Writes compare_v3_all.csv when it completes.

cfg = v3_all();
cfg.id = 'v3_all_none';
cfg.title = 'Variant 3: learning on all 12 forward-looking variables (no projection facility)';
cfg.description = 'As v3_all, with no restriction on beliefs or the model; a quarter without a model solution stops the run.';
cfg.projection.facility = 'none';
cfg.compare_with = {'v3_all'};
end
