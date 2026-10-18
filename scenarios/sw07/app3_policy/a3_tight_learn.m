function cfg = a3_tight_learn()
%A3_TIGHT_LEARN  Application 3: policy 100 bp a year tighter than the Taylor rule in 2022Q3-2023Q2, learning.
%
%   cfg = a3_tight_learn()
%
%   As a3_loose_learn with ms held 0.25 ABOVE its path without the condition.

cfg = a3_loose_learn();
cfg.id = 'a3_tight_learn';
cfg.title = 'App 3: policy 100 bp tighter than the Taylor rule in 2022Q3-2023Q2, learning on inflation';
cfg.description = 'From the 2022Q2 peak, the rate is held 100 bp a year above the Taylor rule for four quarters, with inflation expectations a switching mix of RE agents and learners.';
cfg.conditions.values = 0.25;
end
