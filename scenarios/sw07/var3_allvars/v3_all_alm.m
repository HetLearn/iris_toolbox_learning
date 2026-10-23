function cfg = v3_all_alm()
%V3_ALL_ALM  Model variant 3: learning on all 12 variables, projection facility 'alm' (ALM check only).
%
%   cfg = v3_all_alm()
%
%   As v3_all, with projection.facility = 'alm' set explicitly (the baseline,
%   so the same run): PLMs are never restricted; an unstable
%   model reverts every belief (and, if needed, keeps last quarter's shares).
%   Writes compare_v3_all.csv (if v3_all has results).

cfg = v3_all();
cfg.id = 'v3_all_alm';
cfg.title = 'Variant 3: learning on all 12 forward-looking variables (facility alm)';
cfg.description = 'As v3_all, with only the model (ALM) checked each quarter and the PLMs of the learners left unrestricted.';
cfg.projection.facility = 'alm';
cfg.compare_with = {'v3_all'};
end
