function cfg = br26_experience()
%BR26_EXPERIENCE  BR portfolio 26: experience-based learning in aggregate, constant gain 0.018 (Malmendier and Nagel 2016; Nagel and Xu 2022).
%
%   cfg = br26_experience()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 26 and the 26
%   row of section 3: the AR(1) inflation learners use a constant gain of
%   0.018 per quarter (Nagel and Xu's fading-memory gain, from Malmendier and
%   Nagel's best-matching constant gain 0.0175) instead of the KOZ gain.
%   Cohorts are out of scope. Existing options only. Writes
%   compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br26_experience';
cfg.title = 'BR 26: experience-based learning in aggregate, constant gain 0.018';
cfg.description = 'As a1_learn, with the AR(1) inflation learners on a constant gain of 0.018 per quarter (experience-based learning, aggregate).';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.018;
cfg.compare_with = {'a1_learn', 'a1_re'};
end
