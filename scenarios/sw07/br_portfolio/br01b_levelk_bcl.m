function cfg = br01b_levelk_bcl()
%BR01B_LEVELK_BCL  BR portfolio 1b: everyone reasons at level 2 on the learned seed (Beaudry, Carter and Lahiri 2023).
%
%   cfg = br01b_levelk_bcl()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 1 and the 01b
%   row of section 3: the baseline AR(1) learner is level 0 (L0, share 0) and
%   every agent forms the level-2 forecast on it (L2, share 1, mode
%   'fixed_shares'); K = 2 is BCL's calibration. The level economies are
%   re-solved every quarter from data up to t-1. In a quarter in which a
%   level economy has no stable solution, the baseline's projection facility
%   ('alm' since 2026-10-21) reverts the beliefs and keeps the earlier levels
%   (event projection_level); under 'none' the run stops
%   (hetlearn:engine:levelNoSolution). Writes compare_a1_learn.csv and
%   compare_a1_re.csv when it completes.

cfg = a1_learn();
cfg.id = 'br01b_levelk_bcl';
cfg.title = 'BR 1b: level-2 reasoning on the learned seed (BCL), fixed shares';
cfg.description = 'As a1_learn, with every agent forming the level-2 inflation forecast on the AR(1) learners'' level 0; shares fixed.';
cfg.expectations.mode = 'fixed_shares';
cfg.expectations.types = {struct('name', 'L0', 'kind', 'plm'), ...
    struct('name', 'L2', 'kind', 'level', 'base', 'L0', 'k', 2)};
cfg.shares.fixed = struct('L0', 0, 'L2', 1);
cfg.compare_with = {'a1_learn', 'a1_re'};
end
