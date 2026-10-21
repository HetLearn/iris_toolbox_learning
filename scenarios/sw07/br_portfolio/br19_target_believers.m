function cfg = br19_target_believers()
%BR19_TARGET_BELIEVERS  BR portfolio 19: target believers beside RE agents and learners (Hommes and Lustenhouwer 2019).
%
%   cfg = br19_target_believers()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 19 and the 19
%   row of section 3: a third inflation type, target believers (TB), always
%   forecasts the steady state (0 in deviations); its share is the
%   credibility of the target. Switching as the baseline (chi 2, memory 0.8)
%   from 1/3 each. Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br19_target_believers';
cfg.title = 'BR 19: target believers added beside RE agents and learners';
cfg.description = 'As a1_learn, with a third inflation type that always forecasts the steady state; three-way switching from 1/3 each.';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'BR', 'kind', 'plm'), ...
    struct('name', 'TB', 'kind', 'rule', 'rule', '0')};
cfg.shares.init = struct('RE', 1/3, 'BR', 1/3, 'TB', 1/3);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
