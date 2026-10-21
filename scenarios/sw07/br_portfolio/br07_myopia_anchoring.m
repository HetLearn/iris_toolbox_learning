function cfg = br07_myopia_anchoring()
%BR07_MYOPIA_ANCHORING  BR portfolio 7: myopia and anchoring in the price Phillips curve (Angeletos and Huo 2021).
%
%   cfg = br07_myopia_anchoring()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 7 and the 07
%   row of section 3: in the price Phillips curve only (equation copy), the
%   inflation expectation becomes omega_f*E pinf_{t+1} + b*pinf_{t-1}, with
%   (omega_f, omega_b) = (0.52, 0.43) from AH Table 1 (Coibion-Gorodnichenko
%   K_CG = 1.193) and b = omega_b/0.99 = 0.434. All types. SW07 keeps its own
%   price indexation and habit. Writes compare_a1_learn.csv and
%   compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br07_myopia_anchoring';
cfg.title = 'BR 7: myopia and anchoring in the price Phillips curve (0.52, 0.434)';
cfg.description = 'As a1_learn, with the inflation expectation of the price Phillips curve replaced by 0.52 times itself plus 0.434 times lagged inflation.';
cfg.expectations.transforms = struct('kind', 'myopia_anchoring', 'types', 'all', 'value', [0.52 0.434], ...
    'scope', {{'pinf@Phillips curve, price setting'}});
cfg.compare_with = {'a1_learn', 'a1_re'};
end
