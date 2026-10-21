function cfg = br33_farmer()
%BR33_FARMER  BR portfolio 33: naive nominal-growth belief function as an inflation type (Farmer and Nicolo 2018).
%
%   cfg = br33_farmer()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 33 and the 33
%   row of section 3: the learner is replaced by a naive type (FN) that
%   expects nominal growth to stay at its last value, so its inflation
%   forecast is last quarter's nominal growth minus the anchored RE(t-1)
%   forecast of real growth, dn_{t-1} - E_{t-1}(y_{t+1} - y_t). It switches
%   against the RE agents as in the baseline. Only expectations change (the
%   Phillips curve stays). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br33_farmer';
cfg.title = 'BR 33: naive nominal-growth believers (Farmer-Nicolo) replace the AR(1) learners';
cfg.description = 'As a1_learn, with the learners replaced by agents who expect nominal GDP growth to stay at its last value, switching against RE agents.';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), ...
    struct('name', 'FN', 'kind', 'rule', 'rule', 'dn{-1} - re1(y{+1} - y)')};
cfg.compare_with = {'a1_learn', 'a1_re'};
end
