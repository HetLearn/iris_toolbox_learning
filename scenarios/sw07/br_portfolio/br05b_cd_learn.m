function cfg = br05b_cd_learn()
%BR05B_CD_LEARN  BR portfolio 5b: cognitive discounting stacked on the learning set, m = 0.94 (Meggiorini and Milani 2021).
%
%   cfg = br05b_cd_learn()
%
%   As a1_learn, with rule 5b of the portfolio (docs/USER_GUIDE.md
%   section 7.7): the inflation expectation of both types (RE and
%   learners) is multiplied by m^h (geometric profile, h = 2 under t-1
%   information); the other expectations are unchanged. m = 0.94 is
%   Meggiorini and Milani's estimate with Euler-equation learning (US
%   1960-2007). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br05b_cd_learn';
cfg.title = 'BR 5b: cognitive discounting on the learning set, m = 0.94';
cfg.description = 'As a1_learn, with the inflation expectations of RE agents and learners discounted by m^h, m = 0.94.';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'multiplier', 'types', 'all', ...
    'value', 0.94, 'scope', 'learning', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
