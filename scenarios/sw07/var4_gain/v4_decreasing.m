function cfg = v4_decreasing()
%V4_DECREASING  Model variant 4: decreasing gain 1/t instead of the baseline endogenous (KOZ) gain, forecast from the 2022Q2 peak.
%
%   cfg = v4_decreasing()
%
%   As a1_learn, with gain.rule = 'decreasing': the k-th update of the
%   learners' beliefs has gain 1/(k + 1), the initial beliefs (RE moments,
%   1966Q1) counting as one observation (gain.decreasing.t0 = 0). The learners
%   then run least squares with equal weights on all data since 1966Q1, so
%   their gain is 1/227 at the 2022Q2 origin and their beliefs barely move over
%   the forecast. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v4_decreasing';
cfg.title = 'Variant 4: learning on inflation with a decreasing gain 1/t (baseline: endogenous KOZ gain)';
cfg.description = 'As a1_learn, with the learners updating by least squares with equal weights on all data since 1966Q1 (gain 1/t) instead of the Kostyshyna-Ozden-Zhang gain.';
cfg.gain.rule = 'decreasing';
cfg.gain.decreasing.t0 = 0;                   % the initial beliefs count as one observation
cfg.compare_with = {'a1_learn'};
end
