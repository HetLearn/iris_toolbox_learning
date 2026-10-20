function cfg = v3_all_plm_alm()
%V3_ALL_PLM_ALM  Model variant 3: learning on all 12 variables, projection facility 'plm_alm' (PLM blocks, then the ALM).
%
%   cfg = v3_all_plm_alm()
%
%   As v3_all with projection.facility = 'plm_alm' (the facility of the
%   previous baseline, to 2026-10-19): a PLM block whose largest root would
%   exceed 1 keeps its previous beliefs, then the model (ALM) is checked; an
%   unstable model reverts every belief (and, if needed, keeps last quarter's
%   shares). Replaces v3_all_none (2026-10-20), now that 'none' is the
%   baseline. Writes compare_v3_all.csv (if v3_all has results).

cfg = v3_all();
cfg.id = 'v3_all_plm_alm';
cfg.title = 'Variant 3: learning on all 12 forward-looking variables (facility plm_alm)';
cfg.description = 'As v3_all, with the PLM blocks and then the model (ALM) checked each quarter (the previous baseline facility).';
cfg.projection.facility = 'plm_alm';
cfg.compare_with = {'v3_all'};
end
