function cfg = br20_sac()
%BR20_SAC  BR portfolio 20: SAC learning on the seven sticky forward expectations, no RE agents (Hommes, Mavromatis, Ozden and Zhu 2023).
%
%   cfg = br20_sac()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 20 and the 20
%   row of section 3: every forward expectation of the sticky-price economy
%   (inve, pk, rk, c, lab, pinf, w) is formed by learners (mode 'learning')
%   whose AR(1) beliefs track the mean, first-order autocorrelation and
%   variance (SAC update, autocorrelation kept in [-1, 1]), with a constant
%   gain of 0.006 (HMOZ Table 1, SAC column, as read in the design). The flex
%   block stays RE (D1, D2). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br20_sac';
cfg.title = 'BR 20: SAC learning on the seven sticky forward expectations, gain 0.006';
cfg.description = 'As a1_learn, with all agents learning the seven sticky-economy forward expectations by sample-autocorrelation (SAC) learning, constant gain 0.006.';
cfg.expectations.variables = {'inve', 'pk', 'rk', 'c', 'lab', 'pinf', 'w'};
cfg.expectations.mode = 'learning';
cfg.beliefs.update = 'sac';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.006;
cfg.compare_with = {'a1_learn', 'a1_re'};
end
