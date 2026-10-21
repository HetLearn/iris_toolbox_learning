function cfg = br06_hyperbolic()
%BR06_HYPERBOLIC  BR portfolio 6: as-if hyperbolic discounting (Gabaix and Laibson, NBER WP 23254), alpha = 0.25.
%
%   cfg = br06_hyperbolic()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 6 and the 06
%   row of section 3: as 5a with the hyperbolic horizon profile, every
%   forward expectation multiplied by 1/(1 + alpha*h). alpha = 0.25 is
%   proposed in the design (an as-if half-life of one year, D(4) = 0.5; no
%   macro calibration found), so D(1) = 0.80 and D(2) = 0.67. The flex block
%   stays RE (D1). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br06_hyperbolic';
cfg.title = 'BR 6: as-if hyperbolic discounting, alpha = 0.25';
cfg.description = 'As a1_learn, with every forward expectation (flex block excluded) multiplied by 1/(1 + 0.25 h).';
FLEX = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
cfg.expectations.transforms = struct('kind', 'multiplier', 'profile', 'hyperbolic', 'types', 'all', ...
    'value', 0.25, 'scope', 'all', 'exclude', {FLEX});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
