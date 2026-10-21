function cfg = br10_diagnostic()
%BR10_DIAGNOSTIC  BR portfolio 10: diagnostic expectations with one-period memory (L'Huillier, Singh and Yoo 2024), theta = 0.44.
%
%   cfg = br10_diagnostic()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 10 and the 10
%   row of section 3: diagnostic agents replace the RE agents. Every forward
%   expectation of the RE type becomes (1 + theta) E_t x_{t+1} - theta
%   E_{t-1} x_{t+1}; the inflation type is t-1 dated, so its reference is the
%   anchored E_{t-2} pinf_{t+1}. theta = 0.44 is LSY's estimate in SW07 with
%   Rotemberg pricing (no survey data). The learners and the flex block are
%   unchanged (D1, D4). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br10_diagnostic';
cfg.title = 'BR 10: diagnostic expectations replace RE, theta = 0.44';
cfg.description = 'As a1_learn, with the RE agents'' forward expectations made diagnostic with one-period memory, theta = 0.44.';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, ...
    'scope', 'all', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
