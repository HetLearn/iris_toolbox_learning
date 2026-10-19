function cfg = v4_koz()
%V4_KOZ  Model variant 4: endogenous gain (Kostyshyna, Ozden and Zhang 2024), forecast from the 2022Q2 peak.
%
%   cfg = v4_koz()
%
%   As a1_learn with gain.rule = 'koz' (KOZ eq. 9, the adaptive step-size
%   algorithm of Kostyshyna 2012): the gain rises while the errors of the
%   learners keep their sign and falls when they alternate. The errors enter
%   in model units, percent per quarter (gain.koz.error_scale = 1), the units
%   of the SW07 data and of chi = 0.51 (user decision 2026-10-19; the earlier 4
%   converted to annualised percent, and mu effectively scales with its
%   square). Every other KOZ option at its default (mu 0.001, start gain
%   0.0585, bounds [0.001 0.25], one common process driven by the inflation
%   PLM residual). USER_GUIDE 5.4, DESIGN 18. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v4_koz';
cfg.title = 'Variant 4: learning on inflation with an endogenous gain (KOZ 2024)';
cfg.description = 'As a1_learn, with the gain of the learners set each quarter by the Kostyshyna-Ozden-Zhang rule instead of held at 0.0585.';
cfg.gain.rule = 'koz';
cfg.gain.koz.error_scale = 1;                 % quarterly units, as the data and chi (user decision 2026-10-19; was 4)
cfg.compare_with = {'a1_learn'};
end
