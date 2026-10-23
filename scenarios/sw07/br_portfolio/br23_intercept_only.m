function cfg = br23_intercept_only()
%BR23_INTERCEPT_ONLY  BR portfolio 23: intercept-only learners with RE slopes replace the AR(1) learners (Gati 2023; Carvalho, Eusepi, Moench and Preston 2023).
%
%   cfg = br23_intercept_only()
%
%   As a1_learn, with rule 23 of the portfolio (docs/USER_GUIDE.md
%   section 7.7): the learner type (IO) forecasts the anchored RE(t-1)
%   forecast plus a learned mean of that forecast's own error (the KOZ gain
%   of the baseline, from 0.05); it switches against the RE agents as in the
%   baseline. Gati's smooth anchoring function is not used (knots not in the
%   notes). Writes compare_a1_learn.csv and compare_a1_re.csv.

cfg = a1_learn();
cfg.id = 'br23_intercept_only';
cfg.title = 'BR 23: intercept-only learners with RE slopes replace the AR(1) learners';
cfg.description = 'As a1_learn, with the learners forecasting the RE forecast plus a learned mean of its error, switching against RE agents.';
cfg.expectations.types = {struct('name', 'RE', 'kind', 're'), struct('name', 'IO', 'kind', 're_mean')};
cfg.compare_with = {'a1_learn', 'a1_re'};
end
