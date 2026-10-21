function cfg = br29_wedge()
%BR29_WEDGE  BR portfolio 29: survey belief wedge on inflation expectations, reduced form (Bhandari, Borovicka and Ho 2025; Milani 2011, 2017).
%
%   cfg = br29_wedge()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 29 and the 29
%   row of section 3: the aggregate inflation expectation gets an additive
%   wedge w_t = xi_t, xi_t = 0.714*xi_{t-1} + e_wpinf (rho from BBH's first
%   principal component of the wedges; std 0.182, i.e. an unconditional std
%   of 0.26% per quarter from BBH's 1.03 pp annualised inflation-wedge
%   volatility divided by 4, a mapping flagged in the design; mean 0). The RE
%   filter infers xi over the history; the forecast has no future wedge
%   shocks. Anchored RE agents do not foresee the wedge (D11). Writes
%   compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br29_wedge';
cfg.title = 'BR 29: AR(1) belief wedge on the inflation expectation (BBH, reduced form)';
cfg.description = 'As a1_learn, with an AR(1) belief wedge (rho 0.714, shock std 0.182) added to the inflation expectation of every type.';
cfg.expectations.transforms = struct('kind', 'wedge', 'types', 'all', 'scope', {{'pinf'}}, ...
    'factor', struct('rho', 0.714, 'std', 0.182, 'mean', 0, 'shock', 'e_wpinf'));
cfg.compare_with = {'a1_learn', 'a1_re'};
end
