function cfg = br05a_cd()
%BR05A_CD  BR portfolio 5a: cognitive discounting (Gabaix 2020), m = 0.62 on every forward expectation (Meggiorini 2023).
%
%   cfg = br05a_cd()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 5 and the 05a
%   row of section 3: every forward expectation of every type is multiplied
%   by m^h (geometric profile, h = 2 for the inflation forecasts made with
%   t-1 information), the reference point is the steady state, expected
%   inflation in the real rate included. m = 0.62 is Meggiorini's estimate in
%   a behavioral SW07 (US 1982-2004). The five flex-price expectations stay
%   RE (D1). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br05a_cd';
cfg.title = 'BR 5a: cognitive discounting, m = 0.62 on every forward expectation';
cfg.description = 'As a1_learn, with every forward expectation (flex block excluded) discounted by m^h, m = 0.62.';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'multiplier', 'profile', 'geometric', 'types', 'all', ...
    'value', 0.62, 'scope', 'all', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
