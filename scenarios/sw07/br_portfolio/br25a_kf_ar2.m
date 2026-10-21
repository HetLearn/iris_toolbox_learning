function cfg = br25a_kf_ar2()
%BR25A_KF_AR2  BR portfolio 25a: Kalman-filter learning of AR(2) rules on the seven sticky forward expectations (Slobodyan and Wouters 2012a).
%
%   cfg = br25a_kf_ar2()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 25 and the 25a
%   row of section 3: every agent learns an AR(2) PLM for each sticky forward
%   expectation (inve, pk, rk, c, lab, pinf, w; mode 'learning', no RE
%   agents), the coefficients a random walk learned by the Kalman filter with
%   the constant-gain equivalent gamma = 0.031 (SW 2008 draft; the mapping to
%   V is proposed in the design). gain.rule = 'constant' with gain.value =
%   0.031 so that the recorded gain shows gamma; the KF step does not use the
%   gain rule (P5 note). The flex block stays RE (D2). Writes
%   compare_a1_learn.csv and compare_a1_re.csv when it completes.

cfg = a1_learn();
cfg.id = 'br25a_kf_ar2';
cfg.title = 'BR 25a: Kalman-filter learning of AR(2) rules on the seven sticky expectations';
cfg.description = 'As a1_learn, with all agents learning AR(2) rules for the seven sticky-economy forward expectations by the Kalman filter, gamma = 0.031.';
cfg.expectations.variables = {'inve', 'pk', 'rk', 'c', 'lab', 'pinf', 'w'};
cfg.expectations.mode = 'learning';
cfg.beliefs.plm.default = 'ar2';
cfg.beliefs.update = 'kf';
cfg.beliefs.kf.gamma = 0.031;
cfg.gain.rule = 'constant';
cfg.gain.value = 0.031;                       % the recorded gain column shows gamma
cfg.compare_with = {'a1_learn', 'a1_re'};
end
