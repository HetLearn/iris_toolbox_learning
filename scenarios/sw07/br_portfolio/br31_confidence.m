function cfg = br31_confidence()
%BR31_CONFIDENCE  BR portfolio 31: confidence shocks on expected activity, approximate (Angeletos, Collard and Dellas 2018).
%
%   cfg = br31_confidence()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 31 and the 31
%   row of section 3: the model-consistent household expectations of c, inve
%   and lab get a common bias Lambda_z*xi_t, xi_t = 0.833*xi_{t-1} + e_xi
%   (ACD sticky-price posterior). Loadings Lambda_z = Cov(z, y)/Var(y) in the
%   RE limit ('model:projection'), so xi = 1 means expected output 1% above
%   the model forecast; the shock std is calibrated so that xi explains 51%
%   of output variance at 6-32 quarters in the RE limit ('model:acd51', ACD
%   Table 2). Both are proposed in the design. Inflation is untouched.
%   Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br31_confidence';
cfg.title = 'BR 31: confidence shocks on expected consumption, investment and hours (ACD, approximate)';
cfg.description = 'As a1_learn, with a common AR(1) confidence factor (rho 0.833) biasing the household expectations of consumption, investment and hours.';
cfg.expectations.transforms = struct('kind', 'wedge', 'types', 'all', 'scope', {{'c', 'inve', 'lab'}}, ...
    'factor', struct('rho', 0.833, 'std', 'model:acd51', 'loadings', 'model:projection', 'shock', 'e_xi'));
cfg.compare_with = {'a1_learn', 'a1_re'};
end
