function cfg = br17_heuristics()
%BR17_HEURISTICS  BR portfolio 17: heuristic switching between four rules (Anufriev and Hommes 2012).
%
%   cfg = br17_heuristics()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 17 and the 17
%   row of section 3: four forecasting rules replace both baseline types for
%   inflation (t-1 information, AH's timing): adaptive ADA 0.65*pinf_{t-1} +
%   0.35*f_{t-1}; weak trend WTR pinf_{t-1} + 0.4*dpinf_{t-1}; strong trend
%   STR pinf_{t-1} + 1.3*dpinf_{t-1}; anchoring and adjustment LAA
%   0.5*(pbar + pinf_{t-1}) + dpinf_{t-1}, the anchor pbar the sample mean of
%   inflation (decreasing gain from 1966Q1). Shares: AH's benchmark switching,
%   intensity 0.4, memory 0.7, inertia 0.9, unnormalized fitness, from 0.25
%   each (beta in squared lab-price units used as is in (% per quarter)^2,
%   flagged in the design). All-STR has no stable solution: if the shares
%   move there, the baseline's projection facility ('alm') keeps the previous
%   quarter's shares in the model (event projection_alm_shares). Writes
%   compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br17_heuristics';
cfg.title = 'BR 17: four Anufriev-Hommes heuristics replace RE agents and learners';
cfg.description = 'As a1_learn, with inflation forecast by the adaptive, weak-trend, strong-trend and anchoring-and-adjustment rules, shares switching as in Anufriev and Hommes.';
cfg.expectations.types = { ...
    struct('name', 'ADA', 'kind', 'rule', 'rule', '0.65*x{-1} + 0.35*self{-1}'), ...
    struct('name', 'WTR', 'kind', 'rule', 'rule', 'x{-1} + 0.4*(x{-1} - x{-2})'), ...
    struct('name', 'STR', 'kind', 'rule', 'rule', 'x{-1} + 1.3*(x{-1} - x{-2})'), ...
    struct('name', 'LAA', 'kind', 'rule', 'rule', '0.5*(mean + x{-1}) + (x{-1} - x{-2})', ...
        'gain', struct('rule', 'decreasing'))};       % LAA anchor: the sample mean (gain 1/(t - t0 + 1))
cfg.switching.intensity = 0.4;
cfg.switching.memory = 0.7;
cfg.switching.inertia = 0.9;
cfg.switching.fitness = 'unnormalized';
cfg.shares.init = struct('ADA', 0.25, 'WTR', 0.25, 'STR', 0.25, 'LAA', 0.25);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
