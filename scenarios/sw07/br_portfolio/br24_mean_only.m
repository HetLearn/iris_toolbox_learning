function cfg = br24_mean_only()
%BR24_MEAN_ONLY  BR portfolio 24: mean-only learners (adaptive expectations by exponential smoothing).
%
%   cfg = br24_mean_only()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 24 and the 24
%   row of section 3: the learners' inflation PLM keeps only the constant,
%   so their forecast is the learned mean, updated with the baseline's KOZ
%   gain (from 0.05). Existing options only. Writes compare_a1_learn.csv and
%   compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br24_mean_only';
cfg.title = 'BR 24: mean-only inflation learners (exponential smoothing)';
cfg.description = 'As a1_learn, with the learners'' inflation PLM restricted to a constant: the forecast is the learned mean.';
cfg.beliefs.plm.by_var.pinf = struct('regressors', {{}}, 'constant', true);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
