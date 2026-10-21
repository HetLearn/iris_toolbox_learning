function cfg = br01a_levelk_egm()
%BR01A_LEVELK_EGM  BR portfolio 1a: level-k on a learned level 0 (Evans, Gibbs and McGough 2025); levels 1 and 2 replace the RE agents.
%
%   cfg = br01a_levelk_egm()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 1 and the 01a
%   row of section 3. Inflation expectations come from three types: the
%   baseline AR(1) learner as level 0 (L0), and level-1 and level-2 reasoners
%   (L1, L2) whose forecast is the two-step forecast of the homogeneous
%   level-(k-1) economy from data up to t-1, re-solved every quarter. They
%   replace the RE type, which keeps a share of 0 and is still the RE limit
%   of the history stage. Shares switch as in the baseline (chi 2, memory
%   0.8) from equal initial shares. In a quarter in which a level economy has
%   no stable solution, the baseline's projection facility ('alm' since
%   2026-10-21) reverts every belief to its value before that quarter's
%   update and keeps the earlier levels (event projection_level); under
%   'none' the run stops (hetlearn:engine:levelNoSolution). Writes
%   compare_a1_learn.csv and compare_a1_re.csv when it completes.

cfg = a1_learn();
cfg.id = 'br01a_levelk_egm';
cfg.title = 'BR 1a: level-k on a learned level 0 (EGM), levels 1 and 2 replace RE';
cfg.description = 'As a1_learn, with inflation expectations from AR(1) learners (level 0) and level-1 and level-2 reasoners, whose shares switch; no RE agents.';
cfg.expectations.types = {struct('name', 'L0', 'kind', 'plm'), ...
    struct('name', 'L1', 'kind', 'level', 'base', 'L0', 'k', 1), ...
    struct('name', 'L2', 'kind', 'level', 'base', 'L0', 'k', 2)};
cfg.shares.init = struct('L0', 1/3, 'L1', 1/3, 'L2', 1/3);    % equal initial shares (proposed, D8)
cfg.compare_with = {'a1_learn', 'a1_re'};
end
