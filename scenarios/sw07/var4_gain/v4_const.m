function cfg = v4_const()
%V4_CONST  Model variant 4: constant gain 0.05 instead of the baseline endogenous (KOZ) gain, forecast from the 2022Q2 peak.
%
%   cfg = v4_const()
%
%   Since 2026-10-20 the baseline gain is endogenous (gain.rule = 'koz',
%   Kostyshyna, Ozden and Zhang 2024, eq. 9, starting at gain.value = 0.05;
%   config/master_options.m). This variant holds the gain at 0.05, the KOZ
%   start value, so the comparison with a1_learn isolates what the endogenous
%   gain changes. It replaces v4_koz (KOZ gain against the constant-gain
%   baseline of 2026-10-18/19). Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v4_const';
cfg.title = 'Variant 4: learning on inflation with a constant gain of 0.05 (baseline: endogenous KOZ gain)';
cfg.description = 'As a1_learn, with the gain of the learners held at 0.05 (the KOZ start gain) instead of set each quarter by the Kostyshyna-Ozden-Zhang rule.';
cfg.gain.rule = 'constant';
cfg.gain.value = 0.05;                        % = the baseline's KOZ start gain (master_options)
cfg.compare_with = {'a1_learn'};
end
